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
#   7 I-beam SOLO sul testo        -> nel vuoto DENTRO la pagina (lo stacco fra due
#     paragrafi, il vuoto a destra di una riga corta) ci va la freccia. Prima
#     bastava stare sopra la fine del contenuto e l'I-beam restava acceso su
#     tutta la pagina, anche dove non c'era una lettera.
#   8 lo stesso DENTRO UNA TABELLA  -> il caso peggiore: per l'engine una tabella
#     e' una riga sola alta tutto il blocco, quindi senza la maschera del testo
#     (page_view.gd::_prepara_maschera) l'I-beam copriva la tabella intera.
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

	# --- 7) I-beam solo sul testo: il vuoto DENTRO la pagina vuole la freccia ---
	await _reset(PARAGRAFI)
	var c_para := await _forma_dopo_hover(para_pt)
	_check("CURSORE_PARAGRAFO", c_para == Control.CURSOR_IBEAM, "sul paragrafo vale %d" % c_para)
	var buco := _vuoto_interno()
	if buco.x < 0:
		print("[diag] nessun vuoto interno trovato: controllo saltato")
	else:
		var c_buco := await _forma_dopo_hover(buco)
		print("[cursore] vuoto DENTRO la pagina ", buco, " -> ", c_buco)
		_check("CURSORE_VUOTO_INTERNO", c_buco == Control.CURSOR_ARROW,
				"nel vuoto dentro la pagina vale %d" % c_buco)

	# --- 8) e dentro una tabella, che e' il caso peggiore ---
	await _reset(TABELLE)
	var c_cella := await _forma_dopo_hover(cella_pt)
	_check("CURSORE_TESTO_IN_CELLA", c_cella == Control.CURSOR_IBEAM,
			"sul testo di una cella vale %d" % c_cella)
	var buco_tab := _vuoto_in_tabella()
	if buco_tab.x < 0:
		print("[diag] nessun vuoto trovato dentro la tabella: controllo saltato")
	else:
		var c_tab := await _forma_dopo_hover(buco_tab)
		print("[cursore] vuoto DENTRO la tabella ", buco_tab, " -> ", c_tab)
		_check("CURSORE_VUOTO_IN_TABELLA", c_tab == Control.CURSOR_ARROW,
				"nel vuoto dentro una tabella vale %d" % c_tab)

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

# Cerca un punto su un GLIFO (o su un link). Per il testo si guarda il CONTRASTO
# LOCALE, non la differenza col fondo della pagina: su una cella colorata (la
# barra del titolo del forum) tutto differisce dal fondo della pagina, e un punto
# scelto cosi' cadeva sullo sfondo della cella invece che su una lettera -- il
# controllo del cursore sarebbe una prova finta.
func _trova(pagina: String, cerca_link: bool, y_da := 120) -> Vector2:
	await _reset(pagina)
	var img := _sub.get_texture().get_image()
	var sfondo: Color = _browser._page_bg.color
	for y in range(y_da, 1000, 2):
		var xs: Array = []
		for x in range(40, 1300, 2):
			var c := img.get_pixel(x, y)
			var ok := false
			if cerca_link:
				var diverso: bool = absf(c.r - sfondo.r) + absf(c.g - sfondo.g) + absf(c.b - sfondo.b) > 0.45
				ok = c.b > 0.45 and c.r < 0.30 and c.g < 0.30 and diverso
			else:
				ok = _tratto(img, x, y)
			if ok:
				xs.append(x)
		var soglia := 6 if cerca_link else 12
		if xs.size() >= soglia:
			return Vector2(float(xs[xs.size() / 2]), float(y))
	return Vector2(-1, -1)

# Vero se il pixel fa parte di un tratto: molto piu' scuro o piu' chiaro di quello
# che ha attorno a 4 px (le lettere), non un fondo pieno (le celle colorate).
func _tratto(img: Image, x: int, y: int) -> bool:
	var qui := img.get_pixel(x, y)
	var l0: float = qui.r * 0.3 + qui.g * 0.6 + qui.b * 0.1
	var mn := 2.0
	var mx := -1.0
	for d in [-4, 4]:
		for asse in range(2):
			var xx: int = clampi(x + (d if asse == 0 else 0), 0, VP_SIZE.x - 1)
			var yy: int = clampi(y + (0 if asse == 0 else d), 0, VP_SIZE.y - 1)
			var c := img.get_pixel(xx, yy)
			var l: float = c.r * 0.3 + c.g * 0.6 + c.b * 0.1
			mn = minf(mn, l)
			mx = maxf(mx, l)
	return absf(l0 - mn) > 0.22 or absf(l0 - mx) > 0.22

# Un punto di sfondo pulito DENTRO il blocco di contenuto: sotto la prima riga di
# testo, sopra la fine del contenuto, e con 11x11 pixel tutti di sfondo attorno
# (cosi' e' vuoto davvero, non il bordo di una lettera). E' il punto dove prima
# usciva l'I-beam a torto.
func _vuoto_interno() -> Vector2:
	var img := _sub.get_texture().get_image()
	var rect := _pagina.get_global_rect()
	var sfondo: Color = _browser._page_bg.color
	var fondo: float = minf(rect.position.y + float(_pagina.get_content_height()), rect.end.y)
	var y := int(rect.position.y) + 90
	while float(y) < fondo - 6.0:
		var x := int(rect.position.x) + 30
		while x < int(rect.end.x) - 30:
			var pulito := true
			for dy in range(-5, 6, 2):
				for dx in range(-5, 6, 2):
					var c := img.get_pixel(x + dx, y + dy)
					if absf(c.r - sfondo.r) + absf(c.g - sfondo.g) + absf(c.b - sfondo.b) > 0.20:
						pulito = false
			if pulito:
				return Vector2(float(x), float(y))
			x += 8
		y += 6
	return Vector2(-1, -1)

# Come sopra, ma il punto deve cadere dentro la BANDA DELLA TABELLA: si prende la
# riga piu' alta della pagina (per l'engine una tabella e' una riga sola, alta
# tutto il blocco) e si cerca lo sfondo pulito dentro quella fascia.
func _vuoto_in_tabella() -> Vector2:
	var alta := -1
	var max_h := 0.0
	for l in range(_pagina.get_line_count()):
		var h: float = _pagina.get_line_height(l)
		if h > max_h:
			max_h = h
			alta = l
	if alta < 0 or max_h < 40.0:
		return Vector2(-1, -1)
	var rect := _pagina.get_global_rect()
	var cima: float = rect.position.y + _pagina.get_line_offset(alta) + 18.0
	var img := _sub.get_texture().get_image()
	var sfondo: Color = _browser._page_bg.color
	var y := int(cima) + 4
	while float(y) < cima + max_h - 4.0:
		var x := int(rect.position.x) + 30
		while x < int(rect.end.x) - 30:
			var pulito := true
			for dy in range(-5, 6, 2):
				for dx in range(-5, 6, 2):
					var c := img.get_pixel(x + dx, y + dy)
					if absf(c.r - sfondo.r) + absf(c.g - sfondo.g) + absf(c.b - sfondo.b) > 0.20:
						pulito = false
			if pulito:
				return Vector2(float(x), float(y))
			x += 6
		y += 5
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
