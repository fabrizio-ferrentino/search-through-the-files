extends Node

# Test del PANNELLO DI DEBUG F12 (DEV-ONLY) rispetto al ciclo di vita della partita.
# Il pannello vive sulla RADICE (deve coprire stanza e vista PC, e regge il cambio di
# scena): proprio per questo, se restava aperto, dopo la morte mostrava i dati della
# partita precedente anche nel menu. Qui si pretende che:
#   1 nel menu (nessuna partita) F12 non apra niente
#   2 in partita F12 apra il pannello con il seme giusto
#   3 iniziando una partita nuova col pannello aperto, i dati si aggiornino
#   4 la morte chiuda il pannello e disattivi i tasti di debug
#   5 dopo la morte F12 non riapra niente
#   6 F10 fuori partita non faccia comparire la schermata di morte
#
# Esecuzione:
#   & $godot --path $proj res://tests/debug_panel_test.tscn
# ============================================================

var _fails: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # game_over mette in pausa l'albero
	get_tree().create_timer(60.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame

	# 1) siamo come nel menu: nessuna partita iniziata
	_check("MENU_SENZA_PARTITA", not GameManager.run_active, "run_active dovrebbe essere false all'avvio")
	# tasti veri, non chiamate dirette: e' _input di GameManager che deve filtrarli
	_premi(KEY_F12)
	await get_tree().process_frame
	_check("MENU_NON_APRE", not _aperto(), "nel menu F12 ha aperto il pannello")
	_premi(KEY_F10)
	for i in range(3):
		await get_tree().process_frame
	_check("MENU_F10_IGNORATO", _quante_morti() == 0 and not GameManager._game_over_active,
			"nel menu F10 ha fatto comparire la schermata di morte")

	# 2) partita in corso: il pannello si apre e mostra QUESTA partita
	GameManager.start_new_run(111)
	await get_tree().process_frame
	_premi(KEY_F12)
	await get_tree().process_frame
	_check("IN_PARTITA_APRE", _aperto(), "in partita F12 non apre il pannello")
	var testo_a := _testo()
	_check("MOSTRA_SEME", testo_a.find("111") >= 0, "il pannello non mostra il seme 111: %s" % testo_a.split("\n")[0])

	# 3) partita nuova col pannello aperto: i dati devono aggiornarsi
	GameManager.start_new_run(222)
	await get_tree().process_frame
	var testo_b := _testo()
	_check("AGGIORNA_DATI", testo_b.find("222") >= 0 and testo_b.find("111") < 0,
			"il pannello mostra ancora i dati vecchi: %s" % testo_b.split("\n")[0])

	# 4) morte: il pannello si chiude e i tasti si disattivano
	GameManager.game_over("test")
	for i in range(4):
		await get_tree().process_frame
	_check("MORTE_CHIUDE", not _aperto(), "dopo la morte il pannello e' ancora aperto")
	_check("MORTE_DISATTIVA", not GameManager.run_active, "dopo la morte run_active e' ancora true")

	# 5) e non si riapre
	_premi(KEY_F12)
	await get_tree().process_frame
	_check("DOPO_MORTE_NON_APRE", not _aperto(), "dopo la morte F12 riapre il pannello coi dati vecchi")

	get_tree().paused = false
	if _fails.is_empty():
		print("RISULTATO: PASS (il pannello di debug segue la partita)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# Premi un tasto per davvero: l'evento passa dal viewport, quindi da GameManager._input.
func _premi(codice: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codice
	ev.physical_keycode = codice
	ev.pressed = true
	get_tree().root.push_input(ev)

func _aperto() -> bool:
	return GameManager._keys_panel != null and is_instance_valid(GameManager._keys_panel)

func _testo() -> String:
	if GameManager._keys_label != null and is_instance_valid(GameManager._keys_label):
		return GameManager._keys_label.text
	return ""

# quante schermate di morte ci sono sulla radice
func _quante_morti() -> int:
	var n := 0
	for c in get_tree().root.get_children():
		if c is CanvasLayer and str(c.name).findn("death") >= 0:
			n += 1
	return n

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		_fails.append(nome)
