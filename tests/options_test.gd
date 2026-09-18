extends Node

# Test del menu OPZIONI (scripts/options_screen.gd) e della scelta della LINGUA.
#
# Perche' esiste: il pulsante "Options" del menu era DISABILITATO nella scena e il suo
# callback chiamava get_tree().quit() -- un pulsante Opzioni che spegne il gioco. Adesso
# apre la schermata, e questo test tiene fermi i due lati della cosa:
#   1 il pulsante e' attivo e premerlo APRE la schermata (se tornasse a chiudere il gioco
#     il test morirebbe senza stampare il risultato, che e' esattamente il segnale);
#   2 una schermata per volta (il doppio clic non ne apre due);
#   3 c'e' un pulsante per ogni lingua dichiarata, con dentro il suo ENDONIMO, e quello
#     della lingua in corso risulta premuto;
#   4 sceglierne una cambia il locale, ritraduce la schermata E le scritte del menu dietro
#     -- il menu le aveva prese da tr() quando la lingua era un'altra, e senza rifarle
#     resterebbe mezzo tradotto;
#   5 la scelta viene SALVATA (user://impostazioni.cfg): un'impostazione che si perde a
#     ogni avvio non e' un'impostazione;
#   6 "Indietro" la chiude, e si puo' riaprire.
#
# Il test rimette com'era la lingua salvata prima di partire: gira sul file di
# impostazioni VERO, e non deve cambiare quella di chi gioca.
#
# Va eseguito come SCENA (serve l'autoload GameManager). Headless va bene: qui si
# premono pulsanti, non si guardano pixel.
#   & $godot --headless --path $proj res://tests/options_test.tscn
# ============================================================

const MENU := "res://scenes/main_menu.tscn"

var _fails: Array = []
var _menu: Node = null
var _lingua_iniziale := ""

func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(
			func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	_lingua_iniziale = GameManager.lingua
	await get_tree().process_frame

	_menu = load(MENU).instantiate()
	add_child(_menu)
	await get_tree().process_frame

	var bottone: Button = _menu.get_node("button_manager/Option")
	_check("PULSANTE_ATTIVO", not bottone.disabled,
			"il pulsante Opzioni e' ancora disabilitato nella scena")
	_check("PULSANTE_COLLEGATO", bottone.pressed.get_connections().size() > 0,
			"il pulsante Opzioni non e' collegato a niente")

	# 1. premere apre la schermata (e NON chiude il gioco)
	bottone.pressed.emit()
	await get_tree().process_frame
	var op: OptionsScreen = _menu.opzioni
	_check("APRE", op != null and is_instance_valid(op) and op.is_inside_tree(),
			"premere Opzioni non ha aperto niente")
	if op == null:
		_fine()
		return

	# 2. una sola alla volta
	bottone.pressed.emit()
	await get_tree().process_frame
	_check("UNA_SOLA", _conta_schermate() == 1,
			"schermate Opzioni aperte insieme: %d" % _conta_schermate())

	# 3. un pulsante per lingua, con l'endonimo, e quello in corso premuto
	var mancanti: Array = []
	for codice in GameManager.LINGUE:
		var b := _pulsante_lingua(op, str(codice))
		if b == null:
			mancanti.append(str(codice))
			continue
		if b.text != GameManager.nome_lingua(str(codice)):
			_ko("ENDONIMO", "il pulsante %s dice '%s'" % [str(codice), b.text])
		if (str(codice) == GameManager.lingua) != b.button_pressed:
			_ko("LINGUA_IN_CORSO", "il pulsante %s risulta premuto=%s con lingua '%s'"
					% [str(codice), str(b.button_pressed), GameManager.lingua])
	_check("PULSANTI_LINGUA", mancanti.is_empty(), "lingue senza pulsante: %s"
			% ", ".join(mancanti))

	# 4. sceglierne un'altra: locale, schermata e menu dietro
	var altra := _altra_lingua()
	var b_altra := _pulsante_lingua(op, altra)
	if b_altra == null:
		_ko("CAMBIO", "nessun pulsante per '%s'" % altra)
		_fine()
		return
	b_altra.button_pressed = true          # come un clic: emette "toggled"
	await get_tree().process_frame
	_check("CAMBIA_LINGUA", GameManager.lingua == altra
			and TranslationServer.get_locale().begins_with(altra),
			"lingua '%s', locale '%s' (attesa '%s')"
			% [GameManager.lingua, TranslationServer.get_locale(), altra])
	var atteso_titolo := tr("UI_OPTIONS_TITLE")
	_check("SCHERMATA_RITRADOTTA", op.get_node("Radice").find_child("Titolo", true, false).text
			== atteso_titolo, "il titolo della schermata non ha seguito la lingua")
	_check("MENU_RITRADOTTO", _menu.get_node("button_manager/Start").text == tr("UI_START"),
			"il menu dietro e' rimasto nella lingua di prima: '%s' invece di '%s'"
			% [_menu.get_node("button_manager/Start").text, tr("UI_START")])

	# 5. la scelta e' salvata su disco
	var cfg := ConfigFile.new()
	var err := cfg.load(GameManager.FILE_IMPOSTAZIONI)
	_check("SALVATA", err == OK and str(cfg.get_value("gioco", "lingua", "")) == altra,
			"nel file c'e' '%s' (errore %d)" % [str(cfg.get_value("gioco", "lingua", "")), err])

	# 6. "Indietro" chiude, e si riapre
	op.get_node("Radice").find_child("Indietro", true, false).pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("CHIUDE", _conta_schermate() == 0, "la schermata non si e' chiusa")
	bottone.pressed.emit()
	await get_tree().process_frame
	_check("RIAPRE", _conta_schermate() == 1, "non si riapre dopo averla chiusa")

	_fine()

func _fine() -> void:
	# si rimette la lingua che c'era prima del test, sul file vero
	GameManager.set_lingua(_lingua_iniziale)
	if _fails.is_empty():
		print("RISULTATO: PASS (le Opzioni si aprono e la lingua si cambia e si ricorda)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# ---------------- utilita' ----------------

func _conta_schermate() -> int:
	var n := 0
	for c in _menu.get_children():
		if c is OptionsScreen and is_instance_valid(c) and not c.is_queued_for_deletion():
			n += 1
	return n

func _pulsante_lingua(op: OptionsScreen, codice: String) -> Button:
	var n := op.get_node("Radice").find_child(codice, true, false)
	return n as Button

func _altra_lingua() -> String:
	for codice in GameManager.LINGUE:
		if str(codice) != GameManager.lingua:
			return str(codice)
	return GameManager.lingua

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
