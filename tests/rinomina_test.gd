extends Node

# Test della RINOMINA di file e cartelle (18/10/2026, richiesta del proprietario: "cosi'
# posso copiare il codice se si trova nel nome di una cartella o file").
#
# Si prova il percorso VERO: la stanza istanziata, dentro il PC, i tasti spinti nella coda
# d'input reale (Input.parse_input_event) -- quindi passano da player.gd, che e' dove ESC
# e P vengono decisi -- e gli appunti di sistema veri per CTRL+C / CTRL+V.
# Si pretende che:
#   1 IL CASO PER CUI ESISTE: sulla cartella che porta la chiave del run, F2 apra il
#     riquadro col nome tutto selezionato; selezionato il solo codice, CTRL+C lo metta
#     negli appunti; ESC annulli senza cambiare niente E SENZA FAR USCIRE DAL PC (prima
#     ESC usciva sempre, e l'OS non lo vedeva mai); e nel dialogo della cartella segreta
#     CTRL+V incolli proprio quel codice;
#   2 scrivere un nome nuovo e Invio lo applichi, lasciando l'icona selezionata col nome
#     nuovo -- e che la "p" scritta nel riquadro sia una lettera, non la pausa;
#   3 i caratteri vietati da Windows ( \ / : * ? " < > | ) si tolgano mentre si scrive;
#   4 un nome gia' presente nella cartella (anche con maiuscole diverse, come su un disco
#     Windows) venga RIFIUTATO con un dialogo, e il file tenga il suo nome; e ESC chiuda
#     quel dialogo restando nel PC (e' lo stesso difetto di ESC: valeva anche per l'About);
#   5 un nome vuoto non cambi niente;
#   6 un clic FUORI dal riquadro confermi, come in Win95;
#   7 NON si possano rinominare: le unita', il Cestino, cio' che sta nel Cestino, la
#     cartella protetta, e la strada del Desktop (C:\WHALE\Desktop) -- quella il gioco la
#     cerca per NOME, e rinominarla farebbe sparire tutte le icone della scrivania. Voce
#     del menu grigia e F2 che non fa niente; e alla fine il Desktop si trova ancora;
#   8 sulla SCRIVANIA: la voce nel menu contestuale e F2 senza finestre attive;
#   9 dopo tutto questo, ESC (senza rinomine ne' dialoghi) faccia ancora uscire dal PC;
#  10 le scritte nuove esistano in tutte e due le lingue.
#
# Va eseguito come SCENA e A FINESTRA (gli appunti di sistema non esistono headless).
#   & $godot --path $proj res://tests/rinomina_test.tscn
# ============================================================

var _room: Node = null
var _player: Node = null
var _os = null
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func(): _timeout())
	await get_tree().process_frame
	GameManager.room_threats_enabled = false
	GameManager.pc_threats_enabled = false
	# la chiave 1 sta nel nome di una cartella solo meta' delle volte (l'altra meta' in un
	# file, dal 18/10/2026): si parte dal primo seme dove e' una cartella
	var seme := 8080
	GameManager.start_new_run(seme)
	while str(GameManager.key_kinds.get(OSContent.KEY_DISCO, "")) != "FOLDER":
		seme += 1
		GameManager.start_new_run(seme)
	print("seme %d (chiave 1 nel nome di una cartella)" % seme)
	GameManager.pc_on = true
	GameManager.logged_in = true
	_room = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_room)
	await get_tree().create_timer(1.6).timeout       # la dissolvenza d'ingresso della stanza
	_player = _room.find_child("Camera3D", true, false)
	_player._show_pc_overlay()
	_os = _player._os
	for i in range(4):
		await get_tree().process_frame

	await _prova_copia_codice()
	await _prova_rinomina_e_invio()
	await _prova_caratteri_vietati()
	await _prova_doppione()
	await _prova_vuoto()
	await _prova_clic_fuori()
	await _prova_protetti()
	await _prova_scrivania()
	await _prova_esc_esce_ancora()
	_prova_lingue()

	if _fails.is_empty():
		print("RISULTATO: PASS (si rinomina come in Win95, e il codice si copia e si incolla)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	GameManager.room_threats_enabled = true
	GameManager.pc_threats_enabled = true
	get_tree().quit(0 if _fails.is_empty() else 1)

func _timeout() -> void:
	print("RISULTATO: FAIL -> timeout")
	get_tree().quit(1)

# ---------- 1: il caso per cui esiste ----------

func _prova_copia_codice() -> void:
	var etichetta := GameManager.key_label(OSContent.KEY_DISCO)   # nel NOME di una cartella
	var codice := GameManager.key_code(OSContent.KEY_DISCO)
	var nodo = _cerca(VFS.get_root(), func(n): return str(n.get("name", "")).contains(etichetta))
	if nodo == null:
		_check("CARTELLA_CHIAVE", false, "non trovo la cartella col codice %s" % etichetta)
		return
	var app := await _esplora(nodo.get("_parent"))
	var item := _item(app, nodo)
	app._on_picked(item)
	await _tasto(KEY_F2)
	var campo := item.campo_rinomina()
	_check("F2_APRE_IL_RIQUADRO", campo != null, "F2 sulla cartella della chiave non apre niente")
	if campo == null:
		return
	_check("NOME_TUTTO_SELEZIONATO", campo.get_selected_text() == nodo["name"],
			"selezionato '%s' invece di tutto il nome '%s'" % [campo.get_selected_text(), nodo["name"]])
	var da := str(nodo["name"]).find(codice)
	campo.select(da, da + codice.length())
	DisplayServer.clipboard_set("")
	await _tasto(KEY_C, "", true)
	# gli appunti di Windows a volte si aggiornano con un frame di ritardo: si aspetta un
	# poco (visto rosso una volta con "c'e' 'EE45' invece di 'EE45'", letto un istante dopo)
	for i in range(10):
		if DisplayServer.clipboard_get() == codice:
			break
		await get_tree().process_frame
	_check("CTRL_C_COPIA_IL_CODICE", DisplayServer.clipboard_get() == codice,
			"negli appunti c'e' '%s' invece di '%s'" % [DisplayServer.clipboard_get(), codice])
	var nome_prima: String = nodo["name"]
	await _tasto(KEY_ESCAPE)
	_check("ESC_ANNULLA", not item.in_rinomina() and nodo["name"] == nome_prima,
			"dopo ESC: riquadro aperto=%s, nome '%s'" % [str(item.in_rinomina()), nodo["name"]])
	_check("ESC_RESTA_NEL_PC", _player._in_pc and not _player.entering,
			"ESC durante la rinomina ha fatto uscire dal PC")

	# ...e il codice copiato arriva nel dialogo della cartella segreta, riga 1
	_os.open_secret_folder({})
	await get_tree().process_frame
	var g: SecretGlitch = _os._glitch_cartella
	g._prossima = 1.0e9
	var pannello: Panel = null
	for c in (_os._modal_layer as Control).get_children():
		if c is Panel:
			pannello = c
	var campi := pannello.find_children("*", "LineEdit", true, false)
	(campi[0] as LineEdit).grab_focus()
	await get_tree().process_frame
	await _tasto(KEY_V, "", true)
	_check("CTRL_V_NEL_DIALOGO", (campi[0] as LineEdit).text == codice,
			"incollato nella riga 1: '%s' invece di '%s'" % [(campi[0] as LineEdit).text, codice])
	for b in pannello.find_children("*", "Button", true, false):
		if (b as Button).text == tr("UI_CANCEL"):
			(b as Button).pressed.emit()
	for i in range(3):
		await get_tree().process_frame

# ---------- 2 ----------

var _app_doc: FileExplorerApp = null
var _nodo_prova: Dictionary = {}

func _prova_rinomina_e_invio() -> void:
	var doc = _cerca(VFS.get_root(), func(n): return n.get("name", "") == tr("VFS_DOCUMENTS"))
	_app_doc = await _esplora(doc)
	_app_doc._new_text_file()
	await get_tree().process_frame
	_nodo_prova = _app_doc._selected.data
	await _tasto(KEY_F2)
	await _scrivi("prova")
	await _tasto(KEY_ENTER)
	_check("INVIO_APPLICA", _nodo_prova.get("name", "") == "prova",
			"il file si chiama '%s'" % _nodo_prova.get("name", ""))
	_check("P_E_UNA_LETTERA", not get_tree().paused, "la 'p' scritta nel riquadro ha messo in pausa")
	var sel = _app_doc._selected
	_check("RESTA_SELEZIONATO", sel != null and is_same(sel.data, _nodo_prova)
			and (sel._label as Label).text == "prova",
			"dopo la rinomina l'icona non e' selezionata col nome nuovo")

# ---------- 3 ----------

func _prova_caratteri_vietati() -> void:
	_seleziona(_app_doc, _nodo_prova)
	await _tasto(KEY_F2)
	var campo := _app_doc._selected.campo_rinomina()
	await _scrivi("a/b:c*d")
	_check("VIETATI_TOLTI", campo != null and campo.text == "abcd",
			"scrivendo 'a/b:c*d' il riquadro dice '%s'" % (campo.text if campo != null else "(niente)"))
	await _tasto(KEY_ESCAPE)

# ---------- 4 ----------

func _prova_doppione() -> void:
	_app_doc._new_text_file()
	await get_tree().process_frame
	var secondo: Dictionary = _app_doc._selected.data
	var nome: String = secondo["name"]
	await _tasto(KEY_F2)
	await _scrivi("PROVA")                 # uguale a "prova" per un disco Windows
	await _tasto(KEY_ENTER)
	_check("DOPPIONE_RIFIUTATO", secondo["name"] == nome,
			"rinominato in un nome gia' presente: ora si chiama '%s'" % secondo["name"])
	var dlg = _os._modal_chiudibile
	_check("DOPPIONE_AVVISA", dlg != null and is_instance_valid(dlg),
			"nessun messaggio d'errore")
	await _tasto(KEY_ESCAPE)
	_check("ESC_CHIUDE_IL_MESSAGGIO", not (dlg != null and is_instance_valid(dlg) and not dlg.is_queued_for_deletion())
			and _player._in_pc and not _player.entering,
			"ESC sul messaggio: il messaggio e' rimasto o si e' usciti dal PC")
	for i in range(2):
		await get_tree().process_frame

# ---------- 5 ----------

func _prova_vuoto() -> void:
	_seleziona(_app_doc, _nodo_prova)
	await _tasto(KEY_F2)
	await _tasto(KEY_BACKSPACE)            # tutto selezionato: lo cancella
	await _tasto(KEY_ENTER)
	_check("VUOTO_NON_CAMBIA", _nodo_prova.get("name", "") == "prova",
			"un nome vuoto ha cambiato il file in '%s'" % _nodo_prova.get("name", ""))

# ---------- 6 ----------

func _prova_clic_fuori() -> void:
	_seleziona(_app_doc, _nodo_prova)
	await _tasto(KEY_F2)
	await _scrivi("fuori")
	# un clic sullo sfondo del desktop, lontano da tutto, spinto nel SubViewport dell'OS
	var vp: SubViewport = _player._os_viewport
	for giu in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = giu
		e.position = Vector2(1300, 900)
		e.global_position = e.position
		vp.push_input(e, true)
		await get_tree().process_frame
	await get_tree().process_frame
	_check("CLIC_FUORI_CONFERMA", _nodo_prova.get("name", "") == "fuori",
			"dopo un clic fuori il file si chiama '%s'" % _nodo_prova.get("name", ""))

# ---------- 7 ----------

func _prova_protetti() -> void:
	var radice := VFS.get_root()
	var c_drive = _cerca(radice, func(n): return n.get("name", "") == tr("VFS_C_DRIVE"))
	var whale = _cerca(radice, func(n): return n.get("name", "") == OSContent.DIR_SISTEMA)
	var desktop := VFS.get_desktop()
	var segreta = _cerca(radice, func(n): return str(n.get("type", "")) == "secret")
	var cestino := VFS.get_trash()
	# qualcosa NEL Cestino
	_app_doc._new_text_file()
	var buttato: Dictionary = _app_doc._selected.data
	VFS.move_to_trash(buttato)
	var casi := {"unita' C:": c_drive, "Cestino": cestino, "nel Cestino": buttato,
			"WHALE": whale, "Desktop": desktop, "cartella protetta": segreta}
	var no := PackedStringArray()
	for k in casi:
		if VFS.rinominabile(casi[k]):
			no.append(k)
	_check("PROTETTI_NON_RINOMINABILI", no.is_empty(), "si possono rinominare: " + ", ".join(no))
	# e nell'interfaccia: voce grigia e F2 che non fa niente, su WHALE dentro C:
	var app := await _esplora(c_drive)
	var item := _item(app, whale)
	app._on_item_context(item)
	var voce: Button = null
	for b in app._ctx_vbox.get_children():
		if b is Button and (b as Button).text == tr("EX_RENAME"):
			voce = b
	_check("VOCE_GRIGIA_SUI_PROTETTI", voce != null and voce.disabled,
			"la voce Rinomina su WHALE manca o e' attiva")
	app._chiudi_menu()
	app._on_picked(item)
	await _tasto(KEY_F2)
	_check("F2_NIENTE_SUI_PROTETTI", not item.in_rinomina(), "F2 su WHALE apre il riquadro")
	_check("DESKTOP_SI_TROVA", not is_same(VFS.get_desktop(), radice)
			and VFS.get_desktop().get("children", []).has(segreta),
			"il Desktop non si trova piu' (o non contiene la cartella protetta)")

# ---------- 8 ----------

func _prova_scrivania() -> void:
	for w in _os.window_layer.get_children():
		if w is OSWindow:
			(w as OSWindow).close()
	for i in range(3):
		await get_tree().process_frame
	_os._new_desktop_file()
	await get_tree().process_frame
	var item: DesktopItem = null
	for c in _os.icons_layer.get_children():
		if c is DesktopItem and str((c as DesktopItem).data.get("name", "")).begins_with(tr("VFS_NEW_DOC")):
			item = c
	if item == null:
		_check("SCRIVANIA_FILE", false, "il file nuovo non compare sulla scrivania")
		return
	var nodo: Dictionary = item.data
	_os._on_desktop_item_context(item)
	var voce: Button = null
	for b in _os._ctx_vbox.get_children():
		if b is Button and (b as Button).text == tr("EX_RENAME"):
			voce = b
	_check("SCRIVANIA_VOCE", voce != null and not voce.disabled, "sulla scrivania manca la voce Rinomina")
	if voce != null:
		voce.pressed.emit()
		await get_tree().process_frame
		await _scrivi("appunti")
		await _tasto(KEY_ENTER)
		_check("SCRIVANIA_RINOMINA", nodo.get("name", "") == "appunti",
				"il file della scrivania si chiama '%s'" % nodo.get("name", ""))
	# F2 sulla scrivania, senza finestre attive
	var nuovo: DesktopItem = null
	for c in _os.icons_layer.get_children():
		if c is DesktopItem and is_same((c as DesktopItem).data, nodo):
			nuovo = c
	if nuovo != null:
		_os._on_desktop_picked(nuovo)
		await _tasto(KEY_F2)
		_check("SCRIVANIA_F2", nuovo.in_rinomina(), "F2 sulla scrivania non apre il riquadro")
		await _tasto(KEY_ESCAPE)
	_check("SCRIVANIA_DESKTOP_INTATTO", not is_same(VFS.get_desktop(), VFS.get_root()),
			"dopo le rinomine il Desktop non si trova piu'")

# ---------- 9 e 10 ----------

func _prova_esc_esce_ancora() -> void:
	await _tasto(KEY_ESCAPE)
	await get_tree().create_timer(0.6).timeout
	_check("ESC_ESCE_ANCORA", not _player._in_pc,
			"senza rinomine ne' dialoghi ESC deve ancora far uscire dal PC")

func _prova_lingue() -> void:
	var prima: String = GameManager.lingua
	var mancanti := PackedStringArray()
	for lingua in GameManager.LINGUE:
		GameManager.set_lingua(lingua, false)
		for k in ["EX_RENAME", "RN_ERR_TITLE", "RN_ERR_EXISTS", "RN_ERR_CHARS"]:
			if tr(k) == k or tr(k).strip_edges() == "":
				mancanti.append("%s/%s" % [lingua, k])
		if not tr("RN_ERR_EXISTS").contains("%s"):
			mancanti.append("%s/RN_ERR_EXISTS senza %%s" % lingua)
	GameManager.set_lingua(prima, false)
	_check("SCRITTE_IN_OGNI_LINGUA", mancanti.is_empty(), "mancano: " + ", ".join(mancanti))

# ---------- strumenti ----------

# Un tasto nella coda d'input VERA: passa da player._input come in partita.
func _tasto(codice: Key, carattere := "", ctrl := false) -> void:
	for giu in [true, false]:
		var e := InputEventKey.new()
		e.keycode = codice
		e.physical_keycode = codice
		e.pressed = giu
		e.ctrl_pressed = ctrl
		if giu and carattere != "":
			e.unicode = carattere.unicode_at(0)
		Input.parse_input_event(e)
	Input.flush_buffered_events()
	for i in range(3):
		await get_tree().process_frame

func _scrivi(testo: String) -> void:
	for ch in testo:
		var codice: Key = OS.find_keycode_from_string(ch.to_upper()) as Key
		if ch == "/":
			codice = KEY_SLASH
		elif ch == ":":
			codice = KEY_COLON
		elif ch == "*":
			codice = KEY_ASTERISK
		await _tasto(codice, ch)

func _esplora(cartella) -> FileExplorerApp:
	var w: OSWindow = _os.open_app("explorer", cartella)
	for i in range(3):
		await get_tree().process_frame
	_os.focus_window(w)
	for c in w.content_root.get_children():
		if c is FileExplorerApp:
			return c
	return null

func _item(app: FileExplorerApp, nodo) -> DesktopItem:
	for it in app._items:
		if is_same(it.data, nodo):
			return it
	return null

func _seleziona(app: FileExplorerApp, nodo) -> void:
	var it := _item(app, nodo)
	if it != null:
		app._on_picked(it)

func _cerca(n: Dictionary, prova: Callable):
	if prova.call(n):
		return n
	for c in n.get("children", []):
		var r = _cerca(c, prova)
		if r != null:
			return r
	return null

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		if not _fails.has(nome):
			_fails.append(nome)
