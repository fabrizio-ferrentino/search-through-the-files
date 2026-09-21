extends Node

# Test della GRIGLIA di Esplora risorse: le icone si ridispongono con la larghezza della
# finestra, come facevano loro.
#
# Perche' esiste: con la struttura nuova del disco i nomi sono quelli di sistema, in 8.3
# maiuscolo, e a 92 px per casella "AUTOEXEC.BAT" andava a capo in mezzo all'estensione
# ("CONFIG.SY / S"). Allargando la casella pero' un numero FISSO di colonne non ci sta
# piu' in una finestra stretta: l'ultima colonna finiva tagliata e compariva una barra di
# scorrimento orizzontale, che in vista a icone non si e' mai vista.
#
# Si pretende che:
#   1 in una finestra stretta ci siano MENO colonne che in una larga;
#   2 la griglia non sia mai piu' larga dell'area visibile (niente icone tagliate);
#   3 ci sia sempre almeno una colonna, anche in una finestra ridotta al minimo;
#   4 e che tutto questo non si impianti: cambiare le colonne cambia l'ingombro del
#     contenitore, che puo' riemettere "resized" -- e' la trappola che ha bloccato il
#     gioco con la barra delle applicazioni (desktop.gd::_disponi_barra). Se il giro si
#     riaprisse, questo test non arriverebbe mai in fondo.
#
# Va eseguito come SCENA (serve l'autoload GameManager). Headless va bene: la
# disposizione si calcola anche senza disegnare.
#   & $godot --headless --path $proj res://tests/esplora_griglia_test.tscn
# ============================================================

var _vp: SubViewport
var _os = null
var _win: OSWindow = null
var _app: FileExplorerApp = null
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func(): _timeout())
	await get_tree().process_frame
	GameManager.start_new_run(4242)
	GameManager.pc_on = true
	GameManager.logged_in = true

	_vp = SubViewport.new()
	_vp.size = Vector2i(1440, 1080)
	_vp.disable_3d = true
	add_child(_vp)
	_os = load("res://scripts/os/desktop.gd").new()
	_os.position = Vector2.ZERO
	_os.size = Vector2(1440, 1080)
	_vp.add_child(_os)
	for i in range(4):
		await get_tree().process_frame

	_win = _os.open_app("explorer", null)
	for c in _win.content_root.get_children():
		if c is FileExplorerApp:
			_app = c
	if _app == null:
		print("RISULTATO: FAIL -> Esplora non aperto")
		get_tree().quit(1)
		return

	var stretta := await _colonne_a(420.0)
	var media := await _colonne_a(740.0)
	var larga := await _colonne_a(1200.0)
	print("   colonne: 420px -> %d,  740px -> %d,  1200px -> %d" % [stretta, media, larga])

	_check("SI_RIDISPONE", stretta < media and media < larga,
			"le colonne non seguono la larghezza (%d / %d / %d)" % [stretta, media, larga])
	_check("ALMENO_UNA", stretta >= 1, "in una finestra stretta restano %d colonne" % stretta)

	# e a ogni larghezza la griglia deve STARE dentro l'area visibile
	for larghezza in [380.0, 520.0, 740.0, 1000.0, 1360.0]:
		await _colonne_a(float(larghezza))
		var dentro: float = _app._scroll.size.x
		var grid: float = _app._grid.get_combined_minimum_size().x
		if grid > dentro + 1.0:
			_ko("NIENTE_TAGLIO", "a %.0f px la griglia e' larga %.0f dentro %.0f"
					% [larghezza, grid, dentro])
	_check("NIENTE_TAGLIO_OK", not _fails.has("NIENTE_TAGLIO"), "griglia piu' larga della finestra")

	if _fails.is_empty():
		print("RISULTATO: PASS (le icone si ridispongono con la finestra)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# Se la disposizione riaprisse il giro infinito il gioco si bloccherebbe e questo test
# non arriverebbe mai in fondo: il timeout e' il modo in cui lo dice.
func _timeout() -> void:
	print("RISULTATO: FAIL -> timeout (giro infinito nella disposizione?)")
	get_tree().quit(1)

# Porta la finestra a una larghezza e restituisce quante colonne ha la griglia.
func _colonne_a(larghezza: float) -> int:
	_win.size = Vector2(larghezza, 460.0)
	for i in range(3):
		await get_tree().process_frame
	return _app._grid.columns

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		if not _fails.has(nome):
			_fails.append(nome)

func _ko(nome: String, perche: String) -> void:
	print("FAIL  %s -- %s" % [nome, perche])
	if not _fails.has(nome):
		_fails.append(nome)
