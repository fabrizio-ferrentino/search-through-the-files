extends Node

# Test della PAUSA (tasto P, azione "pause" di project.godot).
#
# L'azione esisteva da sempre ma nessuno l'ascoltava: premere P non faceva niente.
# Qui si prova la catena vera, con la stanza istanziata e i tasti spinti nella coda
# di input reale (Input.parse_input_event), non chiamando le funzioni a mano:
#   1 all'inizio il gioco non e' in pausa;
#   2 P apre la schermata e FERMA l'albero (stanza, minacce e OS);
#   3 la schermata ha il titolo e i tre pulsanti;
#   4 P e ESC riprendono;
#   5 mentre si SCRIVE nell'OS (blocco note, barra indirizzo, campi della cartella
#     protetta) la "p" e' una lettera e NON deve mettere in pausa -- e' il caso che
#     rende il tasto usabile insieme a una tastiera dentro il gioco.
#
# La stanza viene aggiunta alla radice invece di cambiare scena, altrimenti questo
# script verrebbe liberato insieme alla scena corrente.
#
# Esecuzione (FINESTRA: la stanza e' 3D):
#   & $godot --path $proj res://tests/pause_test.tscn
# ============================================================

const OUT := "user://pausa/"

var _fails: Array = []
var _room: Node = null
var _player: Node = null

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.start_new_run(12345)
	_room = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_room)
	for i in range(6):
		await get_tree().process_frame
	_player = _room.find_child("Camera3D", true, false)
	if _player == null:
		for c in _room.get_children():
			if c is Camera3D:
				_player = c
	if _player == null:
		print("RISULTATO: FAIL -> non trovo la camera con player.gd")
		get_tree().quit(1)
		return

	_check("NIENTE_PAUSA_ALL_INIZIO", not get_tree().paused and _overlay() == null,
			"il gioco parte in pausa")

	# ---------- 1) P mette in pausa ----------
	await _premi(KEY_P)
	var ps := _overlay()
	_check("P_METTE_IN_PAUSA", ps != null and get_tree().paused,
			"dopo P: overlay=%s, paused=%s" % [str(ps), str(get_tree().paused)])
	if ps != null:
		_check("OVERLAY_GIRA_IN_PAUSA", ps.process_mode == Node.PROCESS_MODE_ALWAYS,
				"l'overlay e' in pausa anche lui: i pulsanti non risponderebbero")
		_check("OVERLAY_SOPRA_TUTTO", int(ps.layer) >= 60, "layer troppo basso: %d" % int(ps.layer))
		var titolo := ps.find_child("Titolo", true, false)
		_check("TITOLO", titolo != null and str(titolo.text).find("PAUSA") >= 0,
				"manca la scritta di pausa")
		var manca: Array = []
		for nome in ["Riprendi", "Torna al menu", "Chiudi il gioco"]:
			var b := ps.find_child(nome, true, false)
			if b == null or b.pressed.get_connections().is_empty():
				manca.append(nome)
		_check("TRE_PULSANTI", manca.is_empty(), "pulsanti mancanti o non collegati: %s" % str(manca))
		await _foto()

	# ---------- 2) P riprende ----------
	await _premi(KEY_P)
	_check("P_RIPRENDE", not get_tree().paused and _overlay() == null,
			"dopo il secondo P: paused=%s, overlay=%s" % [str(get_tree().paused), str(_overlay())])

	# ---------- 3) ESC riprende ----------
	await _premi(KEY_P)
	await _premi(KEY_ESCAPE)
	_check("ESC_RIPRENDE", not get_tree().paused and _overlay() == null,
			"ESC non riprende: paused=%s" % str(get_tree().paused))

	# ---------- 4) mentre si scrive nell'OS, P e' una lettera ----------
	var os_node = _player._os
	if os_node == null:
		_check("OS_PRESENTE", false, "l'OS non e' stato creato dalla stanza")
	else:
		var campo := LineEdit.new()
		os_node.add_child(campo)
		campo.grab_focus()
		await get_tree().process_frame
		_check("TYPING_VEDE_IL_FUOCO", os_node.typing(),
				"col fuoco su un LineEdit dell'OS typing() dice no")
		_player._in_pc = true          # come se fosse dentro il PC
		await _premi(KEY_P)
		_check("SCRIVENDO_NON_PAUSA", not get_tree().paused and _overlay() == null,
				"scrivendo 'p' nell'OS il gioco va in pausa")
		# e appena il fuoco lascia il campo, P torna a funzionare
		campo.release_focus()
		campo.queue_free()
		await get_tree().process_frame
		await _premi(KEY_P)
		_check("FUORI_DAL_CAMPO_PAUSA", get_tree().paused and _overlay() != null,
				"senza fuoco sul testo P non mette piu' in pausa")
		var o := _overlay()
		if o != null:
			o.riprendi()
		_player._in_pc = false
		await get_tree().process_frame

	get_tree().paused = false
	if _fails.is_empty():
		print("RISULTATO: PASS (la pausa funziona e non ruba le lettere all'OS)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# Foto della schermata, per guardarla a occhio (il percorso lo stampa alla fine).
func _foto() -> void:
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	var img := get_viewport().get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(OUT + "pausa.png")
		print("   foto della pausa in: ", ProjectSettings.globalize_path(OUT))

# La schermata di pausa, se c'e'.
func _overlay() -> Node:
	return get_tree().root.get_node_or_null("PauseScreen")

# Tasto spinto nella coda di input VERA: passa da player._input come in partita.
func _premi(codice: Key) -> void:
	for giu in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = codice
		ev.physical_keycode = codice
		ev.pressed = giu
		Input.parse_input_event(ev)
	Input.flush_buffered_events()
	for i in range(3):
		await get_tree().process_frame

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		_fails.append(nome)
