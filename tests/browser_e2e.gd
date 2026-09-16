extends Node

# Test end-to-end del browser VERO (BrowserApp) dentro una SubViewport, con le
# pagine reali di web/pages/ e la chiave del run iniettata da WebRuntime.
# E' una SCENA (non uno script -s): cosi' gli autoload (GameManager) esistono
# prima che venga compilata la catena BrowserApp -> WebRuntime -> GameManager.
#
# Esecuzione (FINESTRA, non headless: serve il rasterizzatore per get_image()):
#   & $godot --path $proj res://tests/browser_e2e.tscn
# ============================================================

const OUT_DIR := "C:/Users/ffria/AppData/Local/Temp/claude/z--Progetti-Search-Through-the-Files/1536785d-988b-4eed-baf2-48564844db2c/scratchpad"
const VP_SIZE := Vector2i(1440, 1080)

var _sub: SubViewport
var _browser: BrowserApp
var _host: Control
var _fails: Array = []

func _ready() -> void:
	await get_tree().process_frame
	GameManager.start_new_run(12345)   # seme fisso: run riproducibile

	_sub = SubViewport.new()
	_sub.size = VP_SIZE
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)
	_host = Control.new()
	_host.theme = Win95.make_theme()
	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub.add_child(_host)
	_browser = BrowserApp.new()
	_host.add_child(_browser)
	_browser.launch(null)          # home generata
	_sub.notify_mouse_entered()    # come player.gd: input inoltrato -> hover attivo

	# --- home ---
	var txt := await _snap("web_home.png")
	_check("HOME", txt.find("LOCALNET") >= 0 or txt.find("GATEWAY") >= 0, "la home generata non contiene il logo del gateway")

	# --- forum (vetrina complessa) ---
	_browser._load("forum")
	txt = await _snap("web_forum.png")
	_check("FORUM", txt.find("RetroForum") >= 0 and txt.find("floppy graffiato") >= 0, "forum.html non renderizzato")

	# --- pagina thread (avatar <img> + blockquote) ---
	_browser._load("forum_thread")
	txt = await _snap("web_thread.png")
	_check("THREAD", txt.find("mario_64") >= 0 and txt.find("DISKCOPY") >= 0, "forum_thread.html non renderizzato")

	# --- misteri (vetrina scura minimale) ---
	_browser._load("misteri")
	txt = await _snap("web_misteri.png")
	_check("MISTERI", txt.find("LORO GUARDANO") >= 0, "misteri.html non renderizzato")
	# lo sfondo pagina deve essere nero (body bgcolor)
	await RenderingServer.frame_post_draw
	var img := _sub.get_texture().get_image()
	var c := img.get_pixel(720, 700)
	_check("MISTERI_SCURA", c.r < 0.15 and c.g < 0.15 and c.b < 0.15, "sfondo non scuro: %s" % str(c))

	# --- blog: il banner <table width="92%"> deve arrivare davvero al 92% della
	# pagina (la larghezza delle [table] BBCode e' guidata dal contenuto: la impone
	# la "spacer" trasparente di HtmlBB._spacer_row) ---
	_browser._load("blog")
	txt = await _snap("web_blog.png")
	_check("BLOG", txt.find("Jack99") >= 0, "blog.html non renderizzato")
	await RenderingServer.frame_post_draw
	var bimg := _sub.get_texture().get_image()
	var banda := 0
	for y in range(100, 260):
		var conta := 0
		for x in range(0, VP_SIZE.x):
			var bp := bimg.get_pixel(x, y)
			if absf(bp.r - 0.188) < 0.07 and absf(bp.g - 0.188) < 0.07 and absf(bp.b - 0.188) < 0.07:
				conta += 1
		banda = maxi(banda, conta)
	_check("TABELLA_LARGHEZZA", banda > 1100, "il banner width=92%% risulta largo %d px su %d" % [banda, VP_SIZE.x])

	# --- la WIKI (home) non deve MAI contenere la chiave del run ---
	_browser._load("home")
	for i in range(3):
		await get_tree().process_frame
	var kl0: String = GameManager.key_label(OSContent.KEY_WEB)
	var wiki_txt: String = _browser._rtl.get_parsed_text()
	var wiki_src: String = _browser._html_text
	_check("WIKI_SENZA_CHIAVE", kl0 != "" and wiki_txt.find(kl0) < 0 and wiki_src.find(kl0) < 0,
			"la chiave %s compare nella wiki" % kl0)

	# --- selezione col drag sulla pagina del forum ---
	_browser._load("forum")
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	# il PRESS fissa l'ancora solo SUI GLIFI: trova una riga di testo scuro nella pagina
	var page := _sub.get_texture().get_image()
	var a := Vector2(150, 260)
	for y in range(180, 800, 2):
		var xs: Array = []
		for x in range(60, 1200, 2):
			var pc := page.get_pixel(x, y)
			if pc.r < 0.25 and pc.g < 0.25 and pc.b < 0.25:
				xs.append(x)
		if xs.size() >= 8:
			a = Vector2(float(xs[xs.size() / 2]), float(y))
			break
	print("drag: parte dal glifo a ", a)
	# NOTA 4.6: la selezione la estende un Timer interno da 0.05s (click_select_held)
	# che legge la posizione mouse corrente del viewport: il drag deve durare in
	# TEMPO REALE piu' del tick (un drag umano dura sempre centinaia di ms).
	var b := a + Vector2(600.0, 350.0)
	_push_press(a)
	await get_tree().create_timer(0.05).timeout
	for k in range(8):
		_push_motion(a.lerp(b, float(k + 1) / 8.0))
		await get_tree().create_timer(0.03).timeout
	_push_release(b)
	await get_tree().process_frame
	var sel: String = _browser._rtl.get_selected_text()
	_check("DRAG_SELEZIONE", sel.length() > 20, "selezione vuota o troppo corta: '%s'" % sel.substr(0, 60))
	await _snap("web_forum_selezione.png")

	# --- chiave web del run: su UNA pagina sola, e NELLA MODALITA' DICHIARATA ---
	# La modalita' la si chiede a WebRuntime invece di dedurla da dove si trova la
	# stringa: dedurla nascondeva un buco -- una frase visibile finita in un punto
	# morto (dentro una tabella ma fuori dalle celle non viene resa) passava per
	# "solo sorgente" e il test restava verde con la chiave introvabile in partita.
	var kl: String = GameManager.key_label(OSContent.KEY_WEB)
	var portatore := WebRuntime.carrier()
	var visibile := WebRuntime.is_visible()
	var ancora := WebRuntime.anchor_info()
	_check("CHIAVE_GENERATA", kl != "" and portatore != "", "key_label o portatore vuoti")
	print("chiave %s su '%s' -- %s (%s)" % [kl, portatore,
			"visibile" if visibile else "solo sorgente", str(ancora["nota"])])
	var trovate := 0
	for f in ["news", "meteo", "giochi", "blog", "forum", "shop", "mail", "misteri"]:
		_browser._load(f)
		for i in range(2):
			await get_tree().process_frame
		var parsed: String = _browser._rtl.get_parsed_text()
		var src: String = _browser._html_text
		if src.find(kl) >= 0:
			trovate += 1
		if f != portatore:
			continue
		# il portatore: titolo intatto, modalita' rispettata, e in modalita'
		# sorgente la chiave deve comparire nel "visualizza sorgente"
		_check("TITOLO_INTATTO",
				_browser.window == null or str(_browser.window.win_title) == _titolo_pulito(f),
				"il titolo della finestra e' cambiato: '%s'" % (str(_browser.window.win_title) if _browser.window else ""))
		if visibile:
			_check("CHIAVE_VISIBILE_A_SCHERMO", parsed.find(kl) >= 0,
					"modalita' visibile ma a schermo non c'e' (%s)" % str(ancora["tipo"]))
			await _snap("web_chiave.png")
		else:
			_check("CHIAVE_NON_VISIBILE", parsed.find(kl) < 0,
					"modalita' sorgente ma la chiave si legge a schermo (%s)" % str(ancora["tipo"]))
			_browser._view_source()
			for i in range(3):
				await get_tree().process_frame
			_check("SORGENTE_MOSTRA_CHIAVE", _browser._inspector_edit.text.find(kl) >= 0,
					"il 'visualizza sorgente' non mostra la chiave (%s)" % str(ancora["tipo"]))
			await _snap("web_chiave_sorgente.png")
			_browser._view_source()
	_check("CHIAVE_SU_UNA_PAGINA", trovate == 1, "pagine col codice nel sorgente: %d" % trovate)

	# --- e la modalita' SORGENTE, che col seme fisso qui sopra non capita mai ---
	# Due semi scelti perche' nascondono la chiave in un attributo e in un commento
	# a meta' del markup: sono i due modi nuovi, e vanno visti col browser vero.
	for seme in [4242, 1]:
		GameManager.start_new_run(seme)
		var k2: String = GameManager.key_label(OSContent.KEY_WEB)
		var p2 := WebRuntime.carrier()
		var a2 := WebRuntime.anchor_info()
		if WebRuntime.is_visible():
			print("[diag] il seme %d non e' piu' in modalita' sorgente: controllo saltato" % seme)
			continue
		_browser._load(p2)
		for i in range(3):
			await get_tree().process_frame
		var suffisso := "%s_%d" % [str(a2["tipo"]).to_lower(), seme]
		_check("SORGENTE_INVISIBILE_" + suffisso, _browser._rtl.get_parsed_text().find(k2) < 0,
				"la chiave si legge a schermo (%s su %s)" % [str(a2["tipo"]), p2])
		_browser._view_source()
		for i in range(3):
			await get_tree().process_frame
		_check("SORGENTE_MOSTRA_" + suffisso, _browser._inspector_edit.text.find(k2) >= 0,
				"il 'visualizza sorgente' non mostra %s (%s su %s)" % [k2, str(a2["tipo"]), p2])
		print("   %s: %s -- %s" % [p2, k2, str(a2["nota"])])
		await _snap("web_sorgente_%s.png" % suffisso)
		_browser._view_source()

	# --- esito ---
	if _fails.is_empty():
		print("RISULTATO: PASS (browser end-to-end ok)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# Il titolo del file d'autore, senza passare da WebRuntime: serve a provare che
# l'iniezione non ha toccato <title> (finirebbe nella barra della finestra).
func _titolo_pulito(pagina: String) -> String:
	var raw := BrowserApp.read_page(pagina)
	var a := raw.findn("<title>")
	var b := raw.findn("</title>")
	return raw.substr(a + 7, b - a - 7).strip_edges() if a >= 0 and b > a else ""

# Attende il rendering, salva lo screenshot e ritorna il testo della pagina.
func _snap(fname: String) -> String:
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	_sub.get_texture().get_image().save_png(OUT_DIR + "/" + fname)
	return _browser._rtl.get_parsed_text()

func _check(name: String, ok: bool, why: String) -> void:
	if ok:
		print("PASS  " + name)
	else:
		print("FAIL  " + name + " — " + why)
		_fails.append(name)

func _push_press(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_sub.push_input(ev, true)

func _push_release(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = 0
	_sub.push_input(ev, true)

func _push_motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_sub.push_input(ev, true)
