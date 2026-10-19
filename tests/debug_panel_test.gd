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
#   7 F11 accenda/spenga SOLO le minacce della stanza e F8 SOLO quelle del PC, e il
#     pannello lo dica; e che il debug sia sempre in INGLESE, anche a gioco in italiano
#
# Esecuzione:
#   & $godot --path $proj res://tests/debug_panel_test.tscn
# ============================================================

var _fails: Array = []

# Le parole delle vecchie note di debug in italiano: nessuna deve tornare nel pannello.
# (Non "commento", "foto" e simili da sole: potrebbero stare nel NOME di un file del gioco,
# che resta nella lingua di chi gioca.)
const PAROLE_ITALIANE := ["CHIAVI", "seme", "minacce", "nome cartella", "NEL FILE",
		"nei pixel", "rapporto", "sfocata", "generata", "visibile", "sorgente",
		"in coda", "in mezzo", "intestazione", "nuova voce", "riga dopo", "riga in",
		"nella tabella", "da risolvere", "nessun aggancio", "morte", "chiudi"]

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

	# 2b) F11 = minacce della STANZA, F8 = minacce del PC: ognuno il suo, e il pannello lo dice
	_premi(KEY_F11)
	await get_tree().process_frame
	_check("F11_SOLO_STANZA", not GameManager.room_threats_enabled and GameManager.pc_threats_enabled
			and _testo().contains("room threats OFF") and _testo().contains("PC threats ON"),
			"dopo F11: stanza %s, PC %s, pannello '%s'" % [str(GameManager.room_threats_enabled),
			str(GameManager.pc_threats_enabled), _testo().split("\n")[0]])
	_premi(KEY_F8)
	await get_tree().process_frame
	_check("F8_SOLO_PC", not GameManager.room_threats_enabled and not GameManager.pc_threats_enabled
			and _testo().contains("PC threats OFF"),
			"dopo F8: stanza %s, PC %s, pannello '%s'" % [str(GameManager.room_threats_enabled),
			str(GameManager.pc_threats_enabled), _testo().split("\n")[0]])
	_premi(KEY_F11)
	_premi(KEY_F8)
	await get_tree().process_frame
	_check("RIACCENDE", GameManager.room_threats_enabled and GameManager.pc_threats_enabled,
			"premuti di nuovo, F11 e F8 non riaccendono le minacce")

	# 2c) il debug e' SEMPRE in inglese (owner, 18/10/2026), anche a gioco in italiano:
	# nessuna parola delle vecchie note italiane, su piu' semi (vie e nascondigli diversi)
	var lingua_prima: String = GameManager.lingua
	var italiano: Array = []
	# ...e i TIPI delle chiavi (18/10/2026): la 1 e' FILE o FOLDER secondo il seme, la 2 e
	# la 3 WEB, la 4 IMAGE -- la mappa fissa di prima avrebbe chiamato FOLDER una chiave web
	var tipi_sbagliati: Array = []
	for lingua in ["it", "en"]:
		GameManager.set_lingua(lingua, false)
		for seme in [111, 222, 333, 444, 555, 666]:
			GameManager.start_new_run(seme)
			var t := GameManager.keys_report()
			for parola in PAROLE_ITALIANE:
				if t.contains(parola) and not italiano.has(parola):
					italiano.append(parola)
			var righe := t.split("\n")
			var tipi := []
			for i in range(1, 5):
				tipi.append(righe[i].split(" ", false)[1] if righe.size() > i else "?")
			if not ["FILE", "FOLDER"].has(tipi[0]) or tipi.slice(1) != ["WEB", "WEB", "IMAGE"]:
				tipi_sbagliati.append("seme %d: %s" % [seme, str(tipi)])
	GameManager.set_lingua(lingua_prima, false)
	_check("TIPI_DELLE_CHIAVI", tipi_sbagliati.is_empty(), str(tipi_sbagliati))
	await get_tree().process_frame
	_check("SEMPRE_IN_INGLESE", italiano.is_empty() and _testo().contains("KEYS")
			and _testo().contains("F8 PC threats"), "parole italiane nel debug: %s" % str(italiano))
	GameManager.start_new_run(111)

	# 2d) il pannello ha i PULSANTI (proprietario, 18/10/2026: "non riesco a ricreare tutti i
	# bug"): ogni apparizione vera E falsa, nessun pulsante prende il fuoco (lo spazio scritto
	# nel Blocco note lo premerebbe), si compatta alle sole chiavi, e qui fuori dalla stanza un
	# pulsante risponde invece di rompersi
	var p: DebugPanel = GameManager._keys_panel
	var mancano := []
	for t in Apparizione.TIPI:
		var b := p.riga_apparizione(t)
		if b.size() != 2 or (b[0] as Button).text != "REAL" or (b[1] as Button).text != "FALSE":
			mancano.append(t)
	for nome in ["Lethal (random)", "YouAreStupid", "Blue screen", "Stop current", "Jester: peek now",
			"HaloMan: peek now", "Peek: send away", "Ghosty: come now", "Ghosty: go away",
			"Boot to desktop"]:
		if p.pulsante(nome) == null:
			mancano.append(nome)
	_check("PULSANTI_PER_TUTTO", mancano.is_empty(), "mancano i pulsanti di %s" % str(mancano))
	var col_fuoco := []
	for b in p.find_children("*", "Button", true, false):
		if (b as Button).focus_mode != Control.FOCUS_NONE:
			col_fuoco.append((b as Button).text)
	_check("PULSANTI_SENZA_FUOCO", col_fuoco.is_empty(), "prendono il fuoco: %s" % str(col_fuoco))
	p.riga_apparizione("sangue")[0].pressed.emit()
	_check("FUORI_STANZA_RISPONDE", _testo().contains("refused: not in the room"),
			"fuori dalla stanza il pulsante non lo dice: '%s'" % p._esito.text)
	var alto_pieno: float = p._box.size.y
	p.pulsante("-").pressed.emit()
	await get_tree().process_frame
	var alto_compatto: float = p._box.size.y
	var destra: float = p._box.get_global_rect().end.x
	_check("SI_COMPATTA", alto_compatto < alto_pieno * 0.5 and _testo().contains("KEYS")
			and absf(destra - (p._box.get_viewport_rect().size.x - DebugPanel.MARGINE)) < 1.0,
			"compatto: alto %.0f su %.0f, bordo destro a %.0f" % [alto_compatto, alto_pieno, destra])
	p.pulsante("+").pressed.emit()
	await get_tree().process_frame

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

# tutto il testo del pannello (chiavi, stato, pulsanti, tasti)
func _testo() -> String:
	return GameManager.debug_testo()

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
