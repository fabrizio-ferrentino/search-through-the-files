extends Node

# Test delle FINESTRE dell'OS: cosa succede all'input quando una finestra viene ridotta a
# icona. Nasce da un guasto vero, segnalato il 19/09/2026: con la finestra del browser
# RIDOTTA, il tasto destro sul desktop non apriva piu' niente -- il clic continuava ad
# andare alla pagina nascosta.
#
# Come stanno insieme le due cause:
#   - _on_window_min nascondeva la finestra ma NON toglieva "active", quindi per il browser
#     era ancora quella in primo piano;
#   - BrowserApp intercetta il tasto destro da _input (input GLOBALE, non _gui_input: serve
#     perche' funzioni senza che la pagina abbia il fuoco), e _input arriva SEMPRE, anche a
#     finestra nascosta. Trovandosi "attivo", apriva il suo menu e chiamava
#     set_input_as_handled(): l'evento moriva li'. E _input gira PRIMA dell'input della GUI,
#     quindi lo sfondo del desktop non lo vedeva mai.
#
# Qui si pretende che:
#   1 col browser in primo piano il tasto destro sulla pagina apra il menu della PAGINA
#     (se questo non vale, il resto del test non proverebbe niente);
#   2 ridotta a icona, la finestra non sia piu' "attiva";
#   3 ridotta a icona, il tasto destro NEL PUNTO DOVE STAVA LA PAGINA apra il menu del
#     DESKTOP (e' li' che si vede: il browser decide in base al rettangolo della pagina,
#     che resta dov'era anche a finestra nascosta -- altrove non ruberebbe niente);
#   4 e non apra quello della pagina;
#   5 riducendo la finestra DAVANTI, il fuoco passi a quella SOTTO -- altrimenti resta
#     visibile ma "spenta" e il tasto destro su di lei non fa niente finche' non ci si
#     clicca col sinistro (stesso guasto, secondo modo di vederlo);
#   6 con DUE finestre visibili, il destro su quella non attiva la attivi e apra il menu
#     in un colpo solo, come in Windows.
#
# Va eseguito come SCENA (serve l'autoload GameManager).
#   & $godot --headless --path $proj res://tests/os_finestre_test.tscn
# ============================================================

const OS_SIZE := Vector2i(1440, 1080)

var _vp: SubViewport
var _os = null              # OSDesktop
var _win = null             # OSWindow del browser
var _app: BrowserApp
var _punto_pagina := Vector2.ZERO    # dove stava la pagina prima di ridurre la finestra
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.start_new_run(12345)
	# si salta avvio e login: qui l'oggetto del test sono le finestre
	GameManager.pc_on = true
	GameManager.logged_in = true
	BrowserApp.attesa_scala = 0.05

	_vp = SubViewport.new()
	_vp.size = OS_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.disable_3d = true
	add_child(_vp)
	_os = load("res://scripts/os/desktop.gd").new()
	_os.position = Vector2.ZERO
	_os.size = Vector2(OS_SIZE)
	_vp.add_child(_os)
	# senza questo il SubViewport non crede di avere il mouse e non consegna i movimenti
	_vp.notify_mouse_entered()
	for i in range(4):
		await get_tree().process_frame

	_win = _os.open_app("browser", "start")
	for c in _win.content_root.get_children():
		if c is BrowserApp:
			_app = c
	if _app == null:
		print("RISULTATO: FAIL -> browser non aperto")
		get_tree().quit(1)
		return
	await _app.attendi_caricamento()
	for i in range(3):
		await get_tree().process_frame

	await _prova_in_primo_piano()
	await _prova_ridotta()
	await _prova_fuoco_alla_sotto()
	await _prova_destro_su_non_attiva()

	if _fails.is_empty():
		print("RISULTATO: PASS (una finestra ridotta non si prende piu' l'input)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# ---------- 1: col browser davanti, il tasto destro sulla pagina e' suo ----------
func _prova_in_primo_piano() -> void:
	# Si tiene da parte il centro della pagina: e' PROPRIO LI' che poi si prova il tasto
	# destro a finestra ridotta. Con un punto qualsiasi del desktop il test non provava
	# niente -- il browser non se lo prendeva comunque, perche' il suo controllo e' "il
	# mouse e' dentro il rettangolo della pagina?", e quel rettangolo resta dov'era anche
	# quando la finestra sparisce. Il guasto si vede solo dove la finestra stava.
	_punto_pagina = _app._rtl.get_global_rect().get_center()
	await _destro(_punto_pagina)
	_check("PAGINA_MENU_SUO", _app._ctx_layer.visible,
			"col browser in primo piano il tasto destro sulla pagina non apre il suo menu")
	_app._chiudi_menu()
	await get_tree().process_frame

# ---------- 2, 3, 4: ridotta a icona ----------
func _prova_ridotta() -> void:
	# si riduce dalla stessa strada del pulsante della barra del titolo
	_win.minimized.emit(_win)
	for i in range(3):
		await get_tree().process_frame

	_check("RIDOTTA_NON_ATTIVA", not _win.active,
			"la finestra e' ridotta a icona ma si dichiara ancora attiva")
	_check("RIDOTTA_NASCOSTA", not _win.visible, "la finestra ridotta e' ancora visibile")
	_check("APP_FUORI_DALL_ALBERO_VISIBILE", not _app.is_visible_in_tree(),
			"il browser si considera ancora visibile")

	await _destro(_punto_pagina)
	_check("DESKTOP_MENU_SI_APRE", _os._ctx_layer != null and _os._ctx_layer.visible,
			"col browser ridotto il tasto destro dove stava la pagina non apre il menu del desktop")
	_check("PAGINA_NON_RUBA", not _app._ctx_layer.visible,
			"il browser ridotto apre comunque il suo menu")

# ---------- 5: riducendo la finestra davanti, il fuoco passa a quella SOTTO ----------
# Il secondo modo in cui si presentava lo stesso guasto (segnalato il 19/09/2026): si apre
# una cartella sopra il browser, la si riduce, e sul browser il tasto destro non fa niente
# finche' non ci si clicca sopra col sinistro. Non e' il browser a sbagliare: e' il desktop
# che restava senza NESSUNA finestra attiva, uno stato che su Win95 non esiste.
func _prova_fuoco_alla_sotto() -> void:
	# si rimette in piedi il browser e gli si mette sopra una cartella
	_os._on_taskbar_pressed(_win)
	for i in range(3):
		await get_tree().process_frame
	var cartella = _os.open_app("explorer", VFS.get_root())
	for i in range(4):
		await get_tree().process_frame
	_check("CARTELLA_DAVANTI", _os.active_window == cartella,
			"aprendo la cartella non e' lei quella attiva")

	# si riduce la cartella: il browser, che e' visibile, deve prendersi il fuoco
	cartella.minimized.emit(cartella)
	for i in range(3):
		await get_tree().process_frame
	_check("FUOCO_ALLA_SOTTO", _os.active_window == _win and _win.active,
			"ridotta la cartella, la finestra sotto non diventa attiva (attiva=%s)"
			% str(_os.active_window))

	# ...e il tasto destro sulla pagina deve funzionare SUBITO, senza un sinistro prima
	_app._chiudi_menu()
	await get_tree().process_frame
	await _destro(_app._rtl.get_global_rect().get_center())
	_check("DESTRO_SENZA_SINISTRO", _app._ctx_layer.visible,
			"sul browser rimasto sotto il tasto destro non apre il menu senza un clic sinistro prima")
	_app._chiudi_menu()

# ---------- 6: due finestre VISIBILI, destro su quella non attiva ----------
# Stessa famiglia: con la cartella davanti e il browser dietro (tutte e due visibili), il
# primo tasto destro sul browser serviva solo a dargli il fuoco e il menu non usciva.
# In Windows il destro attiva la finestra E apre il menu, in un colpo solo.
func _prova_destro_su_non_attiva() -> void:
	var cartella = _os.open_app("explorer", VFS.get_root())
	for i in range(4):
		await get_tree().process_frame
	# la cartella si sposta via, cosi' il punto della pagina resta scoperto
	cartella.position = Vector2(20, 20)
	cartella.size = Vector2(300, 220)
	_os.focus_window(cartella)
	for i in range(3):
		await get_tree().process_frame
	var punto: Vector2 = _app._rtl.get_global_rect().get_center()
	_check("DUE_VISIBILI", _win.visible and cartella.visible and _os.active_window == cartella,
			"la prova non vale: servono due finestre visibili con la cartella attiva")
	_check("PUNTO_SCOPERTO", not cartella.get_global_rect().has_point(punto),
			"la cartella copre il punto della pagina: la prova non distinguerebbe niente")

	_app._chiudi_menu()
	await get_tree().process_frame
	await _destro(punto)
	_check("DESTRO_ATTIVA_E_APRE", _app._ctx_layer.visible and _os.active_window == _win,
			"il destro su una finestra visibile ma non attiva non apre il menu al primo colpo")
	_app._chiudi_menu()

# ---------- helper ----------

# Un clic destro VERO dentro il SubViewport: prima il movimento (il browser legge la
# posizione del mouse, non quella dell'evento), poi premuta e rilascio.
func _destro(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	_vp.push_input(m, true)
	await get_tree().process_frame
	for giu in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_RIGHT
		e.pressed = giu
		e.position = pos
		e.global_position = pos
		_vp.push_input(e, true)
		await get_tree().process_frame
	await get_tree().process_frame

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		_fails.append(nome)
