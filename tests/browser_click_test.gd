extends Node

# Test dei COMPORTAMENTI DEL MOUSE nel browser (PageView), dentro una SubViewport
# con l'input inoltrato a mano, cioe' esattamente come gira nel gioco. Copre i
# casi che col RichTextLabel nudo erano rotti:
#   1 clic fermo su un link       -> naviga, nessuna selezione
#   2 clic con tremolio di 3 px   -> naviga comunque (la mano trema sempre)
#   3 clic fermo su testo         -> NESSUNA selezione, ne' durante ne' dopo
#     (prima un clic solo selezionava un'intera frase)
#   4 doppio clic su un paragrafo -> seleziona UNA PAROLA
#   5 trascinamento vero          -> seleziona un intervallo e NON naviga
#   6 cursore                     -> mano sul link, I-beam sul testo, freccia nel vuoto
#
# NOTA sui tempi: gli eventi vanno spinti con i tempi di una mano umana
# (~90 ms di pressione, ~110 ms tra i due clic di un doppio clic). Con eventi
# troppo ravvicinati il doppio clic nativo del RichTextLabel non scatta.
#
# Esecuzione (FINESTRA: serve il rasterizzatore per individuare i glifi):
#   & $godot --path $proj res://tests/browser_click_test.tscn
# ============================================================

const VP_SIZE := Vector2i(1440, 1080)
const TABELLE := "forum"        # pagina ricca: tabelle, link, righe colorate
const PARAGRAFI := "blog"       # pagina a paragrafi semplici su sfondo chiaro

var _sub: SubViewport
var _browser: BrowserApp
var _pagina: PageView
var _meta: Array = []
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(_timeout)   # salvagente
	await get_tree().process_frame
	GameManager.start_new_run(12345)

	_sub = SubViewport.new()
	_sub.size = VP_SIZE
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)
	var host := Control.new()
	host.theme = Win95.make_theme()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub.add_child(host)
	_browser = BrowserApp.new()
	host.add_child(_browser)
	_browser.launch(null)
	# Come player.gd: una SubViewport con input inoltrato deve sapere che il mouse
	# e' nella sua area, altrimenti i movimenti arrivano ai controlli solo mentre
	# un tasto e' premuto (niente hover).
	_sub.notify_mouse_entered()
	_pagina = _browser._rtl
	_pagina.meta_clicked.connect(func(m): _meta.append(str(m)))

	var link_pt := await _trova(TABELLE, true)
	var cella_pt := await _trova(TABELLE, false)
	var para_pt := await _trova(PARAGRAFI, false, 300)   # sotto l'intestazione
	print("[punti] link=", link_pt, " cella=", cella_pt, " paragrafo=", para_pt)
	if link_pt.x < 0 or cella_pt.x < 0 or para_pt.x < 0:
		print("RISULTATO: FAIL -> non ho trovato glifi da cliccare")
		get_tree().quit(1)
		return

	# --- 1) clic fermo su un link: naviga, senza selezione ---
	await _reset(TABELLE)
	await _clic(link_pt, [])
	_check("LINK_FERMO", _meta.size() == 1, "meta=%s" % str(_meta))
	_check("LINK_FERMO_NO_SEL", _pagina.get_selected_text() == "", "selezione=%s" % _pagina.get_selected_text())

	# --- 2) clic su link con tremolio della mano (3 px col tasto premuto) ---
	await _reset(TABELLE)
	await _clic(link_pt, [Vector2(2, 1), Vector2(3, 2)])
	_check("LINK_TREMOLIO", _meta.size() == 1, "il link non scatta col tremolio: meta=%s" % str(_meta))
	_check("LINK_TREMOLIO_NO_SEL", _pagina.get_selected_text() == "", "selezione=%s" % _pagina.get_selected_text())

	# --- 3) clic fermo su testo: nessuna selezione, ne' durante ne' dopo ---
	await _reset(TABELLE)
	_motion(cella_pt)
	await get_tree().process_frame
	_press(cella_pt)
	await get_tree().create_timer(0.25).timeout      # tieni premuto, fermo
	var durante: String = _pagina.get_selected_text()
	_release(cella_pt)
	await get_tree().process_frame
	var dopo: String = _pagina.get_selected_text()
	_check("TESTO_NO_SEL_MENTRE_PREMI", durante == "", "durante la pressione: %d caratteri (%s)" % [durante.length(), durante.substr(0, 30)])
	_check("TESTO_CLIC_NO_SEL", dopo == "", "dopo il clic: %d caratteri (%s)" % [dopo.length(), dopo.substr(0, 30)])

	# --- 4) doppio clic su un paragrafo: una parola ---
	var s4 := await _doppio_clic(para_pt, PARAGRAFI)
	var pulita := s4.strip_edges()
	var una_parola: bool = pulita != "" and pulita.length() <= 30 and not pulita.contains("\n") and not pulita.contains(" ")
	_check("DOPPIO_CLIC_PAROLA", una_parola, "selezione(%d)=%s" % [s4.length(), s4.substr(0, 40)])
	# diagnostica: dentro una cella di tabella l'engine usa il frame della cella
	var s4t := await _doppio_clic(cella_pt, TABELLE)
	print("[diag] doppio clic in cella di tabella -> ", s4t.strip_edges())

	# --- 5) trascinamento vero: seleziona e NON naviga ---
	await _reset(TABELLE)
	var a := cella_pt
	var b := a + Vector2(420, 120)
	_press(a)
	await get_tree().create_timer(0.05).timeout
	for k in range(8):
		_motion(a.lerp(b, float(k + 1) / 8.0), true)
		await get_tree().create_timer(0.03).timeout
	_release(b)
	await get_tree().process_frame
	var s5: String = _pagina.get_selected_text()
	_check("TRASCINA_SELEZIONA", s5.length() > 15, "selezione troppo corta: %s" % s5.substr(0, 40))

	await _reset(TABELLE)
	_press(link_pt)
	await get_tree().create_timer(0.05).timeout
	for k in range(6):
		_motion(link_pt + Vector2(40.0 * (k + 1), 0), true)
		await get_tree().create_timer(0.03).timeout
	_release(link_pt + Vector2(240, 0))
	await get_tree().process_frame
	_check("TRASCINA_NON_NAVIGA", _meta.is_empty(), "trascinando sul link ha navigato: %s" % str(_meta))

	# --- 6) cursore: mano sul link, I-beam sul testo, freccia nel vuoto ---
	await _reset(TABELLE)
	var c_link := await _forma_dopo_hover(link_pt)
	var c_testo := await _forma_dopo_hover(cella_pt)
	# un punto sicuramente sotto la fine del contenuto della pagina
	var rect := _pagina.get_global_rect()
	var y_vuoto: float = rect.position.y + float(_pagina.get_content_height()) + 60.0
	var vuoto := Vector2(720.0, minf(y_vuoto, rect.end.y - 4.0))
	var c_vuoto := await _forma_dopo_hover(vuoto)
	print("[cursore] link=", c_link, " testo=", c_testo, " vuoto=", c_vuoto, " (punto vuoto ", vuoto, ")  0=ARROW 1=IBEAM 2=MANO")
	_check("CURSORE_LINK", c_link == Control.CURSOR_POINTING_HAND, "sul link vale %d" % c_link)
	_check("CURSORE_TESTO", c_testo == Control.CURSOR_IBEAM, "sul testo vale %d" % c_testo)
	_check("CURSORE_VUOTO", c_vuoto == Control.CURSOR_ARROW, "nel vuoto vale %d" % c_vuoto)

	if _fails.is_empty():
		print("RISULTATO: PASS (comportamenti del mouse ok)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

func _timeout() -> void:
	print("RISULTATO: FAIL -> timeout")
	get_tree().quit(1)

# Ricarica la pagina e azzera lo stato tra un caso e l'altro.
func _reset(pagina: String) -> void:
	_meta.clear()
	_browser._load(pagina)
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

# Un clic completo con tempi umani: hover, pressione ~90 ms, tremolio, rilascio.
func _clic(pos: Vector2, jitter: Array, doppio := false) -> void:
	_motion(pos)
	await get_tree().process_frame
	_press(pos, doppio)
	await get_tree().create_timer(0.09).timeout
	var ultimo := pos
	for d in jitter:
		ultimo = pos + d
		_motion(ultimo, true)
		await get_tree().create_timer(0.04).timeout
	_release(ultimo)
	await get_tree().process_frame
	await get_tree().process_frame

# Doppio clic (due clic separati da ~110 ms, come una mano); ritorna la selezione.
func _doppio_clic(pos: Vector2, pagina: String) -> String:
	await _reset(pagina)
	await _clic(pos, [])
	await get_tree().create_timer(0.11).timeout
	await _clic(pos, [], true)
	var sel: String = _pagina.get_selected_text()
	print("[diag] doppio clic su ", pagina, " in ", pos, " -> '", sel, "'")
	return sel

# Cerca un punto su un GLIFO (o su un link) confrontando i pixel col colore di
# sfondo della pagina: cosi' funziona anche sulle pagine con sfondo scuro.
func _trova(pagina: String, cerca_link: bool, y_da := 120) -> Vector2:
	await _reset(pagina)
	var img := _sub.get_texture().get_image()
	var sfondo: Color = _browser._page_bg.color
	for y in range(y_da, 1000, 2):
		var xs: Array = []
		for x in range(40, 1300, 2):
			var c := img.get_pixel(x, y)
			var diverso: bool = absf(c.r - sfondo.r) + absf(c.g - sfondo.g) + absf(c.b - sfondo.b) > 0.45
			var ok := false
			if cerca_link:
				ok = c.b > 0.45 and c.r < 0.30 and c.g < 0.30 and diverso
			else:
				ok = diverso
			if ok:
				xs.append(x)
		var soglia := 6 if cerca_link else 12
		if xs.size() >= soglia:
			return Vector2(float(xs[xs.size() / 2]), float(y))
	return Vector2(-1, -1)

func _forma_dopo_hover(p: Vector2) -> int:
	_motion(p)
	await get_tree().process_frame
	await get_tree().process_frame
	return _pagina.get_cursor_shape(p - _pagina.get_global_rect().position)

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		_fails.append(nome)

func _press(pos: Vector2, doppio := false) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.double_click = doppio
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_sub.push_input(ev, true)

func _release(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = 0
	_sub.push_input(ev, true)

func _motion(pos: Vector2, premuto := false) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if premuto else 0
	_sub.push_input(ev, true)
