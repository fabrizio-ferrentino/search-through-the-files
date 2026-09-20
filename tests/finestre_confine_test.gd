extends Node

# Test del CONFINE DELLO SCHERMO: una finestra dell'OS non puo' uscire dal monitor.
#
# Il monitor del gioco e' un 4:3 fisso (1440x1080 nel SubViewport): quello che una
# finestra si porta oltre il bordo non si vede piu' e col mouse non si recupera -- non
# c'e' un secondo schermo ne' un desktop piu' grande. Prima si poteva trascinare via una
# finestra lasciandone dentro 40 px, e RIDIMENSIONANDOLA si usciva senza alcun limite.
#
# Si pretende che:
#   1 una finestra appena aperta stia tutta dentro l'area utile;
#   2 trascinandola oltre un bordo si FERMI al bordo, da tutti e quattro i lati;
#   3 in basso il confine sia la barra delle applicazioni, non il fondo dello schermo:
#     sotto la barra la finestra sarebbe coperta, che e' l'altra meta' di "sparisce";
#   4 anche TIRANDO UN BORDO non si esca: il lato trascinato si ferma, quello opposto
#     non si muove (o la finestra scivolerebbe mentre la si allarga);
#   5 una finestra piu' grande dello schermo resti attaccata in alto a sinistra -- la
#     barra del titolo e' la sua unica presa, e' il bordo destro che si sacrifica;
#   6 l'ingrandimento riempia esattamente quell'area utile, cosi' "ingrandita" e
#     "spinta in un angolo" arrivano allo stesso punto.
#
# I trascinamenti sono VERI: eventi spinti nel SubViewport, non chiamate alle funzioni
# interne, altrimenti si proverebbe l'aritmetica e non il comportamento.
#
# Va eseguito come SCENA (serve l'autoload GameManager). Headless va bene.
#   & $godot --headless --path $proj res://tests/finestre_confine_test.tscn
# ============================================================

const OS_SIZE := Vector2i(1440, 1080)
const LONTANO := 3000.0      # oltre il bordo di sicuro, da qualunque punto si parta
const EPS := 1.0

var _vp: SubViewport
var _os = null               # OSDesktop
var _win: OSWindow = null    # tipizzata: da un Variant "var x := _win.position.x" non compila
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(
			func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.start_new_run(777)
	GameManager.pc_on = true          # si salta avvio e login: qui contano le finestre
	GameManager.logged_in = true

	_vp = SubViewport.new()
	_vp.size = OS_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.disable_3d = true
	add_child(_vp)
	_os = load("res://scripts/os/desktop.gd").new()
	_os.position = Vector2.ZERO
	_os.size = Vector2(OS_SIZE)
	_vp.add_child(_os)
	_vp.notify_mouse_entered()        # senza, il SubViewport non consegna i movimenti
	for i in range(4):
		await get_tree().process_frame

	_win = _os.open_app("explorer", null)
	for i in range(3):
		await get_tree().process_frame
	if _win == null:
		print("RISULTATO: FAIL -> finestra non aperta")
		get_tree().quit(1)
		return

	var a: Rect2 = _win.area_utile()
	print("   area utile: %s   finestra: %s" % [str(a), str(_rett())])
	_check("APERTA_DENTRO", _e_dentro(), "appena aperta e' gia' fuori: %s" % str(_rett()))

	await _prova_trascinamenti(a)
	await _prova_ridimensionamenti(a)
	_prova_piu_grande_dello_schermo(a)
	_prova_ingrandimento(a)

	if _fails.is_empty():
		print("RISULTATO: PASS (le finestre restano dentro lo schermo)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# ---------------- 2 e 3: trascinamento ----------------

func _prova_trascinamenti(a: Rect2) -> void:
	# in basso a destra: deve appoggiarsi ai due bordi, esattamente
	await _trascina_titolo(Vector2(LONTANO, LONTANO))
	_check("TRASCINA_DESTRA", absf(_rett().end.x - a.end.x) <= EPS,
			"il bordo destro si ferma a %.0f invece che a %.0f" % [_rett().end.x, a.end.x])
	_check("TRASCINA_BASSO", absf(_rett().end.y - a.end.y) <= EPS,
			"il bordo basso si ferma a %.0f invece che a %.0f (barra applicazioni)"
			% [_rett().end.y, a.end.y])
	_check("SOPRA_LA_BARRA", _rett().end.y <= float(OS_SIZE.y) - OSDesktop.TASKBAR_H + EPS,
			"la finestra finisce sotto la barra delle applicazioni")

	# in alto a sinistra: deve appoggiarsi all'origine
	await _trascina_titolo(Vector2(-LONTANO, -LONTANO))
	_check("TRASCINA_SINISTRA", absf(_win.position.x - a.position.x) <= EPS,
			"il bordo sinistro si ferma a %.0f invece che a %.0f" % [_win.position.x, a.position.x])
	_check("TRASCINA_ALTO", absf(_win.position.y - a.position.y) <= EPS,
			"la barra del titolo si ferma a %.0f invece che a %.0f" % [_win.position.y, a.position.y])

# ---------------- 4: ridimensionamento ----------------

func _prova_ridimensionamenti(a: Rect2) -> void:
	# si rimette la finestra al centro, cosi' ogni bordo ha strada da fare
	_win.position = Vector2(400, 300)
	_win.size = Vector2(500, 400)
	await get_tree().process_frame

	# bordo DESTRO tirato fuori dallo schermo
	var sinistro := _win.position.x
	await _trascina_bordo(Vector2(_rett().end.x - 2.0, _win.position.y + _win.size.y * 0.5),
			Vector2(LONTANO, 0.0))
	_check("RIDIM_DESTRA", absf(_rett().end.x - a.end.x) <= EPS,
			"allargando a destra si arriva a %.0f (bordo %.0f)" % [_rett().end.x, a.end.x])
	_check("RIDIM_DESTRA_FERMO", absf(_win.position.x - sinistro) <= EPS,
			"allargando a destra si e' mosso anche il lato sinistro")

	# bordo BASSO tirato sotto la barra
	var alto := _win.position.y
	await _trascina_bordo(Vector2(_win.position.x + _win.size.x * 0.5, _rett().end.y - 2.0),
			Vector2(0.0, LONTANO))
	_check("RIDIM_BASSO", absf(_rett().end.y - a.end.y) <= EPS,
			"allargando in basso si arriva a %.0f (bordo %.0f)" % [_rett().end.y, a.end.y])
	_check("RIDIM_BASSO_FERMO", absf(_win.position.y - alto) <= EPS,
			"allargando in basso si e' mosso anche il lato alto")

	# bordo SINISTRO tirato fuori a sinistra: si ferma a 0 e il destro non si muove
	var destro := _rett().end.x
	await _trascina_bordo(Vector2(_win.position.x + 2.0, _win.position.y + _win.size.y * 0.5),
			Vector2(-LONTANO, 0.0))
	_check("RIDIM_SINISTRA", absf(_win.position.x - a.position.x) <= EPS,
			"allargando a sinistra si arriva a %.0f (bordo %.0f)" % [_win.position.x, a.position.x])
	_check("RIDIM_SINISTRA_FERMO", absf(_rett().end.x - destro) <= EPS,
			"allargando a sinistra si e' mosso anche il lato destro")

# ---------------- 5: piu' grande dello schermo ----------------

func _prova_piu_grande_dello_schermo(a: Rect2) -> void:
	_win.position = Vector2(200, 200)
	_win.size = a.size + Vector2(600, 600)
	_win.assesta()
	_check("PIU_GRANDE_IN_ALTO_A_SINISTRA",
			_win.position.is_equal_approx(a.position) and _win.size.is_equal_approx(a.size),
			"una finestra piu' grande dello schermo finisce in %s (%s)"
			% [str(_win.position), str(_win.size)])

# ---------------- 6: ingrandimento ----------------

func _prova_ingrandimento(a: Rect2) -> void:
	_win.position = Vector2(300, 200)
	_win.size = Vector2(500, 400)
	_win.toggle_max()
	_check("INGRANDITA_RIEMPIE", _win.position.is_equal_approx(a.position)
			and _win.size.is_equal_approx(a.size),
			"ingrandita occupa %s %s invece di %s" % [str(_win.position), str(_win.size), str(a)])
	_win.toggle_max()
	_check("RIPRISTINO_DENTRO", _e_dentro(), "tornata piccola e' fuori: %s" % str(_rett()))

# ---------------- utilita' ----------------

func _rett() -> Rect2:
	return Rect2(_win.position, _win.size)

func _e_dentro() -> bool:
	var a: Rect2 = _win.area_utile()
	var r := _rett()
	return r.position.x >= a.position.x - EPS and r.position.y >= a.position.y - EPS \
			and r.end.x <= a.end.x + EPS and r.end.y <= a.end.y + EPS

# Trascina la BARRA DEL TITOLO di uno spostamento dato. Il punto di presa e' a 200 px
# dal bordo sinistro e a meta' della barra: lontano dai bordi (o sarebbe un
# ridimensionamento) e dai pulsanti di destra.
func _trascina_titolo(spostamento: Vector2) -> void:
	var presa := _win.position + Vector2(200.0, OSWindow.BORDER + OSWindow.TITLE_H * 0.5)
	await _trascina(presa, presa + spostamento)

# Trascina un BORDO (il punto di presa lo sceglie chi chiama).
func _trascina_bordo(presa: Vector2, spostamento: Vector2) -> void:
	await _trascina(presa, presa + spostamento)

# Un trascinamento vero dentro il SubViewport: movimento, premuta, movimento (in due
# passi, come farebbe una mano) e rilascio.
func _trascina(da: Vector2, a: Vector2) -> void:
	await _muovi(da)
	await _bottone(da, true)
	await _muovi(da.lerp(a, 0.5))
	await _muovi(a)
	await _bottone(a, false)
	await get_tree().process_frame

func _muovi(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	_vp.push_input(m, true)
	await get_tree().process_frame

func _bottone(pos: Vector2, giu: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = giu
	e.position = pos
	e.global_position = pos
	_vp.push_input(e, true)
	await get_tree().process_frame

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		if not _fails.has(nome):
			_fails.append(nome)
