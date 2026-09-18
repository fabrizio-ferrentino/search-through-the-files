extends Node

# Test della BARRA DELLE APPLICAZIONI, che deve comportarsi come su Win95/98.
#
# Difetti da cui nasce (segnalati il 19/09/2026): con UNA sola finestra aperta il pulsante
# si prendeva tutta la barra (erano SIZE_EXPAND_FILL), e con tante finestre i pulsanti
# uscivano dalla barra invece di stringersi e poi scorrere.
#
# Qui si pretende che:
#   1 un pulsante da solo NON riempia la barra: c'e' una larghezza massima;
#   2 aggiungendo finestre i pulsanti si STRINGANO, restando tutti uguali;
#   3 non scendano mai sotto la larghezza minima, e quando non ci starebbero piu'
#     compaiano le due frecce e se ne mostri una finestra alla volta;
#   4 i pulsanti mostrati stiano SEMPRE dentro la barra, con qualunque numero di finestre
#     (e' la meta' "escono fuori dallo schermo" della segnalazione);
#   5 le frecce scorrano davvero, e ai capi non si possa andare oltre.
#
# Va eseguito come SCENA (serve l'autoload GameManager).
#   & $godot --headless --path $proj res://tests/taskbar_test.tscn
# ============================================================

const OS_SIZE := Vector2i(1440, 1080)

var _vp: SubViewport
var _os = null
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.start_new_run(12345)
	GameManager.pc_on = true
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
	for i in range(4):
		await get_tree().process_frame

	await _prova_una_sola()
	await _prova_si_stringono()
	await _prova_scorrimento()

	if _fails.is_empty():
		print("RISULTATO: PASS (la barra si comporta come su Win95)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# ---------- 1: una sola finestra ----------
func _prova_una_sola() -> void:
	await _apri(1)
	var b: Button = _bottoni()[0]
	_check("UNA_NON_RIEMPIE", b.size.x <= _os.TASK_MAX_W + 1.0,
			"con una finestra sola il pulsante e' largo %.0f (massimo %d)" % [b.size.x, _os.TASK_MAX_W])
	_check("UNA_LASCIA_SPAZIO", b.size.x < _os.tasks_box.size.x * 0.9,
			"il pulsante occupa quasi tutta la barra (%.0f su %.0f)" % [b.size.x, _os.tasks_box.size.x])
	_check("NIENTE_FRECCE_CON_UNA", not _os._task_spin.visible,
			"con una finestra sola compaiono le frecce di scorrimento")
	print("   1 finestra: pulsante largo %.0f su %.0f di barra" % [b.size.x, _os.tasks_box.size.x])

# ---------- 2: si stringono ----------
func _prova_si_stringono() -> void:
	var prima: float = _bottoni()[0].size.x
	await _apri(4)                 # 5 in tutto
	var dopo: float = _bottoni()[0].size.x
	_check("SI_STRINGONO", dopo < prima,
			"da 1 a 5 finestre i pulsanti non si stringono (%.0f -> %.0f)" % [prima, dopo])
	_check("TUTTI_UGUALI", _tutti_uguali(),
			"i pulsanti visibili non sono tutti della stessa larghezza")
	_check("TUTTI_VISIBILI_A_5", _visibili().size() == 5,
			"con 5 finestre se ne vedono %d" % _visibili().size())
	_check("DENTRO_LA_BARRA_A_5", _stanno_dentro(),
			"con 5 finestre i pulsanti escono dalla barra")
	print("   5 finestre: pulsante largo %.0f" % dopo)

# ---------- 3, 4, 5: troppe -> si scorre ----------
func _prova_scorrimento() -> void:
	await _apri(11)                # 16 in tutto: di sicuro non ci stanno
	var vis := _visibili()
	_check("MAI_SOTTO_IL_MINIMO", vis.size() > 0 and float(vis[0].size.x) >= _os.TASK_MIN_W - 1.0,
			"i pulsanti sono scesi sotto la larghezza minima (%.0f)" % (float(vis[0].size.x) if vis.size() > 0 else -1.0))
	_check("COMPAIONO_LE_FRECCE", _os._task_spin.visible,
			"con 16 finestre non compaiono le frecce di scorrimento")
	_check("NON_LI_MOSTRA_TUTTI", vis.size() < 16,
			"dice di mostrarli tutti e 16, ma non ci starebbero")
	_check("DENTRO_LA_BARRA_A_16", _stanno_dentro(),
			"con 16 finestre i pulsanti escono dalla barra")
	print("   16 finestre: %d visibili, larghi %.0f" % [vis.size(), float(vis[0].size.x)])

	# Le frecce scorrono davvero. Si confronta il PULSANTE, non il suo titolo: qui le
	# finestre sono tutte cartelle con lo stesso nome, e sul testo il controllo non
	# distinguerebbe niente (ci sono cascato).
	var primo_prima: Button = vis[0]
	var indice_prima: int = _os._task_primo
	_freccia(false).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	var primo_dopo: Button = _visibili()[0]
	_check("FRECCIA_SCORRE", primo_dopo != primo_prima and _os._task_primo == indice_prima + 1,
			"premendo la freccia in giu' la barra non scorre (indice %d -> %d)"
			% [indice_prima, _os._task_primo])
	_check("DENTRO_ANCHE_DOPO", _stanno_dentro(), "dopo lo scorrimento i pulsanti escono dalla barra")

	# ai capi non si va oltre
	for i in range(30):
		_freccia(true).pressed.emit()
	await get_tree().process_frame
	_check("NON_SI_VA_PRIMA_DELL_INIZIO", _os._task_primo == 0,
			"salendo oltre l'inizio l'indice va a %d" % _os._task_primo)
	for i in range(40):
		_freccia(false).pressed.emit()
	await get_tree().process_frame
	_check("NON_SI_VA_OLTRE_LA_FINE", _visibili().size() == vis.size(),
			"scendendo oltre la fine restano %d pulsanti visibili invece di %d"
			% [_visibili().size(), vis.size()])

# ---------- helper ----------
func _apri(quante: int) -> void:
	for i in range(quante):
		_os.open_app("explorer", VFS.get_root())
		await get_tree().process_frame
	for i in range(3):
		await get_tree().process_frame

func _bottoni() -> Array:
	var out: Array = []
	for c in _os.tasks_box.get_children():
		if c is Button:
			out.append(c)
	return out

func _visibili() -> Array:
	var out: Array = []
	for b in _bottoni():
		if (b as Button).visible:
			out.append(b)
	return out

func _tutti_uguali() -> bool:
	var vis := _visibili()
	if vis.size() < 2:
		return true
	var w: float = float(vis[0].size.x)
	for b in vis:
		if absf(float(b.size.x) - w) > 1.0:
			return false
	return true

# I pulsanti mostrati devono stare dentro tasks_box: e' la prova che non "escono".
func _stanno_dentro() -> bool:
	var vis := _visibili()
	if vis.is_empty():
		return true
	var sep: int = _os.tasks_box.get_theme_constant("separation")
	var somma: float = float(sep * (vis.size() - 1))
	for b in vis:
		somma += float(b.size.x)
	return somma <= _os.tasks_box.size.x + 1.0

func _freccia(su: bool) -> Button:
	var f: Node = _os._task_spin.get_child(0 if su else 1)
	return f as Button

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		_fails.append(nome)
