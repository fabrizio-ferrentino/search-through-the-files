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
#   9 i MODULI come in un browser vero -> stanghetta su tutto il campo (anche vicino al
#     bordo), freccia su tendina e pulsante; un clic vicino al bordo del campo lo attiva;
#     la tendina si apre PROPRIO sotto la sua casella, larga uguale, e la voce cliccata
#     diventa il valore (prima: la mano sul campo, e la tendina era il menu del tasto
#     destro aperto dove si cliccava).
#
# NOTA sui tempi: gli eventi vanno spinti con i tempi di una mano umana
# (~90 ms di pressione, ~110 ms tra i due clic di un doppio clic). Con eventi
# troppo ravvicinati il doppio clic nativo del RichTextLabel non scatta.
#
# Esecuzione (FINESTRA: serve il rasterizzatore per individuare i glifi):
#   & $godot --path $proj res://tests/browser_click_test.tscn
# ============================================================

const VP_SIZE := Vector2i(1440, 1080)
# Le pagine di prova sono FISSE e stanno qui, non nei siti: il test trova i punti da
# cliccare guardando i pixel (il blu dei link, il testo neutro), e un sito ridisegnato
# lo faceva fallire senza che il browser avesse niente (24/10/2026: la fascia blu notte
# del forum nuovo, col testo bianco sfumato ai bordi, sembrava un link). Sono le
# versioni del forum e della gazzetta com'erano fino al 23/10/2026.
const TABELLE := "res://tests/pagine_prova/tabelle.html"     # tabelle, link, righe colorate
const PARAGRAFI := "res://tests/pagine_prova/paragrafi.html" # paragrafi semplici su sfondo chiaro

var _sub: SubViewport
var _browser: BrowserApp
var _pagina: PageView
var _meta: Array = []
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(150.0).timeout.connect(_timeout)   # salvagente
	await get_tree().process_frame
	GameManager.start_new_run(12345)
	GameManager.debug_tutti_i_siti = true   # le pagine sono fisse: devono rispondere in ogni partita
	# il caricamento della pagina resta (velo, barra di stato, segnale) ma quasi
	# istantaneo: qui si provano i clic, non l'attesa (quella e' page_load_test)
	BrowserApp.attesa_scala = 0.05

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
	var para_pt := await _trova(PARAGRAFI, false, 40)    # 40 px dentro la pagina: sotto il titolo
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

	# --- 9) i moduli ---
	await _prova_moduli()

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
	# un clic di prima su un link ha fatto navigare davvero il browser: si aspetta che quel
	# caricamento finisca, o il suo velo resterebbe sopra la pagina di prova a prendersi i clic
	await _browser.attendi_caricamento()
	var html := FileAccess.get_file_as_string(pagina)
	_browser._html_text = html
	_browser._render_html(HtmlBB.strip_comments(HtmlBB.body_inner(html)))
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
# "salta" e' quanti pixel scendere DENTRO la pagina prima di cercare (per esempio per
# saltare l'intestazione), non una coordinata dello schermo: la cornice del browser e'
# cresciuta due volte e ogni altezza scritta a mano si e' rotta -- una volta la scansione
# partiva dentro il banner, un'altra il punto "sotto l'intestazione" cadeva nel vuoto.
# Il centro del tratto continuo piu' lungo fra le x trovate (campionate ogni 2 px; un buco
# fino a 10 px, lo spazio fra due lettere della stessa parola, non spezza il tratto).
func _centro_tratto_lungo(xs: Array) -> int:
	var da: int = xs[0]
	var meglio_da: int = da
	var meglio_a: int = da
	var prima: int = da
	for k in range(1, xs.size()):
		var x: int = xs[k]
		if x - prima > 10:
			da = x
		prima = x
		if x - da > meglio_a - meglio_da:
			meglio_da = da
			meglio_a = x
	return (meglio_da + meglio_a) / 2

func _trova(pagina: String, cerca_link: bool, salta := 0) -> Vector2:
	await _reset(pagina)
	var img := _sub.get_texture().get_image()
	var sfondo: Color = _browser._page_bg.color
	var da: int = int(_pagina.get_global_rect().position.y) + 4 + salta
	for y in range(da, 1000, 2):
		var xs: Array = []
		var forza_max := -1.0
		var x_forte := -1
		for x in range(40, 1300, 2):
			var c := img.get_pixel(x, y)
			var ok := false
			if cerca_link:
				var diverso: bool = absf(c.r - sfondo.r) + absf(c.g - sfondo.g) + absf(c.b - sfondo.b) > 0.45
				ok = c.b > 0.45 and c.r < 0.30 and c.g < 0.30 and diverso
			else:
				# Il testo cercato deve essere NEUTRO: i link sono blu, e un punto su un link
				# manda il primo clic a navigare, quindi il secondo non seleziona piu' nulla
				# (visto: il doppio clic finiva su "Torna al portale" e tornava stringa vuota).
				var sat: float = maxf(maxf(c.r, c.g), c.b) - minf(minf(c.r, c.g), c.b)
				ok = sat < 0.15 and _tratto(img, x, y)
			if ok:
				xs.append(x)
				if not cerca_link:
					# Si tiene il pixel col contrasto PIU' FORTE della riga, cioe' il centro
					# di un tratto. Prendendo la mediana si finiva a 1-2 px di fianco a una
					# lettera: il cursore era giustamente la I (la maschera del testo ha un
					# margine) ma il doppio clic non trovava nessuna parola.
					var f: float = _forza(img, x, y)
					if f > forza_max:
						forza_max = f
						x_forte = x
		var soglia := 6 if cerca_link else 12
		# Il TESTO va distinto da un BORDO: una riga che attraversa il bordo di una cella o
		# di un banner ha contrasto locale su ogni pixel, quindi passava il controllo e il
		# punto "sul testo" cadeva su una linea -- dove il cursore e' giustamente una freccia.
		# Le lettere invece danno tanti gruppetti separati da spazi: se ne servono almeno 3.
		if xs.size() >= soglia and (cerca_link or _gruppi(xs) >= 3):
			if cerca_link:
				# il centro del tratto blu PIU' LUNGO della riga, cioe' di un solo link: la
				# mediana di tutti i pixel blu poteva cadere nello stacco fra due link (una
				# barra "Indice | Hardware | ..."), e 3 px di tremolio uscivano dal link
				return Vector2(float(_centro_tratto_lungo(xs)), float(y))
			if x_forte < 0:
				return Vector2(float(xs[xs.size() / 2]), float(y))
			return Vector2(float(x_forte), float(y))
	return Vector2(-1, -1)

# Quanto un pixel si stacca da quello che ha attorno: al centro di un tratto e' massimo.
func _forza(img: Image, x: int, y: int) -> float:
	var qui := img.get_pixel(x, y)
	var l0: float = qui.r * 0.3 + qui.g * 0.6 + qui.b * 0.1
	var peggio := 0.0
	for d in [-4, 4]:
		for asse in range(2):
			var xx: int = clampi(x + (d if asse == 0 else 0), 0, VP_SIZE.x - 1)
			var yy: int = clampi(y + (0 if asse == 0 else d), 0, VP_SIZE.y - 1)
			var c := img.get_pixel(xx, yy)
			peggio = maxf(peggio, absf(l0 - (c.r * 0.3 + c.g * 0.6 + c.b * 0.1)))
	return peggio

# Quanti tratti separati (distanti piu' di 3 px) ci sono in una riga di ascisse.
func _gruppi(xs: Array) -> int:
	if xs.is_empty():
		return 0
	var n := 1
	for i in range(1, xs.size()):
		if int(xs[i]) - int(xs[i - 1]) > 3:
			n += 1
	return n

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

# La forma che il gioco mostrerebbe: la chiede OSDesktop.cursor_shape_at alla pagina
# (cursore_a), non al RichTextLabel nudo, che metterebbe la mano su ogni link.
func _forma_dopo_hover(p: Vector2) -> int:
	_motion(p)
	await get_tree().process_frame
	await get_tree().process_frame
	return _pagina.cursore_a(p - _pagina.get_global_rect().position)

const MODULO := "<body bgcolor=\"#FFFFFF\"><p>Cerca nel sito:</p><form action=\"/cgi-bin/cerca.pl\">" 		+ "<p>Nome: <input type=\"text\" name=\"q\" size=\"24\"></p>" 		+ "<p>Sezione: <select name=\"s\"><option value=\"a\">Tutte le sezioni<option value=\"b\">Hardware<option value=\"c\">Software</select></p>" 		+ "<p><input type=\"submit\" value=\"Cerca\"></p></form><p><a href=\"rules.html\">Regolamento</a></p></body>"

func _prova_moduli() -> void:
	await _browser.attendi_caricamento()
	_browser._html_text = MODULO
	_browser._current = "forum/index"
	_browser._render_html(HtmlBB.strip_comments(HtmlBB.body_inner(MODULO)))
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var base := _pagina.get_global_rect().position
	var campo: Rect2 = await _pagina.rettangolo_di("__campo:m0_0")
	var tendina: Rect2 = await _pagina.rettangolo_di("__tendina:m0_1")
	var bottone: Rect2 = await _pagina.rettangolo_di("__invia:0")
	print("[moduli] campo=", campo, " tendina=", tendina, " pulsante=", bottone)
	if campo.size.x < 20.0 or tendina.size.x < 20.0 or bottone.size.x < 10.0:
		_check("MODULI_TROVATI", false, "non trovo i controlli: %s %s %s" % [campo, tendina, bottone])
		return
	# il cursore: stanghetta sul campo, anche a 3 px dal bordo sinistro; freccia altrove
	var c_campo := await _forma_dopo_hover(base + campo.get_center())
	var c_bordo := await _forma_dopo_hover(base + Vector2(campo.position.x + 3.0, campo.get_center().y))
	var c_tend := await _forma_dopo_hover(base + tendina.get_center())
	var c_bott := await _forma_dopo_hover(base + bottone.get_center())
	print("[moduli] cursore campo=", c_campo, " bordo=", c_bordo, " tendina=", c_tend, " pulsante=", c_bott)
	_check("CURSORE_CAMPO", c_campo == Control.CURSOR_IBEAM, "sul campo vale %d" % c_campo)
	_check("CURSORE_CAMPO_BORDO", c_bordo == Control.CURSOR_IBEAM, "vicino al bordo del campo vale %d" % c_bordo)
	_check("CURSORE_TENDINA", c_tend == Control.CURSOR_ARROW, "sulla tendina vale %d" % c_tend)
	_check("CURSORE_PULSANTE", c_bott == Control.CURSOR_POINTING_HAND, "sul pulsante vale %d" % c_bott)
	# premuto, il pulsante si abbassa; lasciato, torna su (il mouse ci e' gia' passato sopra:
	# la pagina sa dove sta)
	for i in range(6):
		await get_tree().process_frame
	_press(base + bottone.get_center())
	await get_tree().process_frame
	var giu := _pagina.pulsante_premuto()
	_release(base + Vector2(bottone.position.x - 40.0, bottone.get_center().y))
	await get_tree().process_frame
	_check("PULSANTE_SI_ABBASSA", giu and not _pagina.pulsante_premuto(),
			"premuto si vede abbassato: %s, lasciato torna su: %s" % [str(giu), str(not _pagina.pulsante_premuto())])
	await _browser.attendi_caricamento()
	# un clic vicino al bordo sinistro attiva il campo
	await _clic(base + Vector2(campo.position.x + 3.0, campo.get_center().y), [])
	_check("CAMPO_CLIC_BORDO", _browser._campo == "m0_0", "campo attivo: '%s'" % _browser._campo)
	_browser._scrivi_in("")
	_browser._ridisegna()
	await get_tree().process_frame
	# la tendina: si apre sotto la casella, larga uguale
	await _clic(base + tendina.get_center(), [])
	for i in range(20):
		if _browser._tend_panel.visible:
			break
		await get_tree().process_frame
	var origine: Vector2 = _pagina.global_position - _browser.global_position
	var atteso := origine + Vector2(tendina.position.x, tendina.end.y)
	_check("TENDINA_SOTTO_LA_CASELLA", _browser._tend_panel.visible
			and _browser._tend_panel.position.distance_to(atteso) < 2.0
			and absf(_browser._tend_panel.size.x - tendina.size.x) < 2.0,
			"casella %s, elenco in %s largo %d (visibile %s)" % [tendina, _browser._tend_panel.position,
			int(_browser._tend_panel.size.x), str(_browser._tend_panel.visible)])
	# clic sulla seconda voce: diventa il valore e l'elenco si chiude
	var voci := _browser._tend_lista.get_children()
	if voci.size() == 3:
		var v2 := voci[1] as Button
		await get_tree().process_frame
		await _clic(v2.get_global_rect().get_center(), [])
		await get_tree().process_frame
	_check("TENDINA_SCEGLIE", str(_browser._valori.get("m0_1", "")) == "b" and not _browser._tend_panel.visible,
			"valore '%s', elenco visibile %s" % [str(_browser._valori.get("m0_1", "")), str(_browser._tend_panel.visible)])

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
