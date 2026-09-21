extends Node

# Test della CORNICE del browser: barra dei menu, barra strumenti, tendine.
#
# Perche' esiste. Le voci "File / Modifica / Visualizza / Preferiti / ?" erano pulsanti
# piatti senza nessun callback: sembravano attive e non facevano niente. Il proprietario ha
# chiesto che tutto cio' che si puo' premere faccia qualcosa, e che cio' che non fara' mai
# niente abbia il classico aspetto DISABILITATO invece di fingere.
#
# Qui si pretende che:
#   1 ogni voce della barra dei menu apra una tendina;
#   2 dentro le tendine le voci attive abbiano un callback e quelle finte siano disabled
#     (grigie) -- e che ne esistano di entrambi i tipi, o il test non proverebbe nulla;
#   3 "Preferiti" sia DISABILITATO, voce di menu e pulsante: e' una scelta di gioco
#     (18/09/2026), non una dimenticanza -- un elenco cliccabile di tutti i siti rende la
#     navigazione troppo comoda, e il giocatore deve girare per le pagine;
#   4 "indietro"/"avanti"/"interrompi" siano disabilitati quando non hanno senso e attivi
#     quando ce l'hanno (e' il "disabilitato" che porta informazione);
#   5 il pulsante stampa sia disabilitato (non ci sara' mai una stampante);
#   6 nessun pulsante della cornice resti senza callback e abilitato: e' esattamente il
#     difetto da cui e' nato questo test.
#
# Va eseguito come SCENA (serve l'autoload GameManager).
#   & $godot --headless --path $proj res://tests/browser_chrome_test.tscn
# ============================================================

const VP_SIZE := Vector2i(1440, 1080)

var _sub: SubViewport
var _app: BrowserApp
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.start_new_run(12345)
	BrowserApp.attesa_scala = 0.05        # qui il caricamento non e' l'oggetto del test

	_sub = SubViewport.new()
	_sub.size = VP_SIZE
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)
	var host := Control.new()
	host.theme = Win95.make_theme()
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.size = Vector2(900, 640)
	_sub.add_child(host)
	_app = BrowserApp.new()
	host.add_child(_app)
	_app.launch(null)
	_sub.notify_mouse_entered()
	await _app.attendi_caricamento()
	await get_tree().process_frame

	_prova_barra_menu()
	await _prova_preferiti()
	await _prova_stato_pulsanti()
	_prova_nessun_pulsante_morto()

	if _fails.is_empty():
		print("RISULTATO: PASS (la cornice risponde, e cio' che non fa niente lo dichiara)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# ---------- 1 e 2: le tendine si aprono e hanno voci attive E disabilitate ----------
func _prova_barra_menu() -> void:
	# Le voci sono TRADOTTE: si confrontano con tr(), non con le parole italiane, o il test
	# fallirebbe per la lingua invece che per un guasto.
	# Le scritte hanno la & dell'acceleratore nel CSV ("F&avorites"): a schermo la & NON
	# deve arrivare, quindi si confronta col testo semplice.
	var attese := [Win95.testo_semplice(tr("MENU_FILE")), Win95.testo_semplice(tr("MENU_EDIT")),
			Win95.testo_semplice(tr("MENU_VIEW")), Win95.testo_semplice(tr("MENU_FAVORITES")), "?"]
	var trovate: Array = []
	for b in _bottoni_menu():
		trovate.append(b.text)
	_check("VOCI_BARRA_MENU", trovate == attese,
			"la barra dei menu ha %s invece di %s" % [str(trovate), str(attese)])

	var totale_attive := 0
	var totale_spente := 0
	var menu_spenti := 0
	for b in _bottoni_menu():
		if b.disabled:
			# una voce di menu grigia non deve aprire niente: e' il punto
			menu_spenti += 1
			_check("MENU_SPENTO_" + b.text.to_upper(), b.pressed.get_connections().is_empty(),
					"'%s' e' grigia ma ha ancora un callback" % b.text)
			continue
		b.pressed.emit()
		var strato := _strato()
		if strato == null or not strato.visible:
			_check("TENDINA_" + b.text.to_upper(), false, "la voce '%s' non apre niente" % b.text)
			continue
		var voci := _voci_tendina()
		if voci.is_empty():
			_check("TENDINA_" + b.text.to_upper(), false, "la tendina di '%s' e' vuota" % b.text)
			continue
		var attive := 0
		var spente := 0
		for v in voci:
			if (v as Button).disabled:
				spente += 1
			else:
				attive += 1
		totale_attive += attive
		totale_spente += spente
		print("   %-12s %d voci: %d attive, %d disabilitate" % [b.text, voci.size(), attive, spente])
		_check("TENDINA_" + b.text.to_upper(), attive > 0,
				"la tendina di '%s' non ha nemmeno una voce che fa qualcosa" % b.text)
		_app._chiudi_menu()
	_check("CI_SONO_VOCI_SPENTE", totale_spente > 0,
			"nessuna voce disabilitata: o si e' finto che tutto funzioni, o il test non prova niente")
	_check("CI_SONO_VOCI_ATTIVE", totale_attive >= 5,
			"solo %d voci attive in tutta la barra dei menu" % totale_attive)
	_check("PREFERITI_MENU_SPENTO", menu_spenti >= 1,
			"nessuna voce della barra dei menu e' disabilitata: 'Preferiti' dovrebbe esserlo")

# ---------- 3: Preferiti e' spento, e resta spento ----------
func _prova_preferiti() -> void:
	# Il PULSANTE della barra strumenti
	_check("PREFERITI_PULSANTE_SPENTO", _app._btn_pref != null and _app._btn_pref.disabled,
			"il pulsante Preferiti non e' disabilitato")
	if _app._btn_pref != null:
		_check("PREFERITI_SENZA_CALLBACK", _app._btn_pref.pressed.get_connections().is_empty(),
				"il pulsante Preferiti e' grigio ma ha ancora un callback")
	# ...e nessuna scorciatoia rimasta in giro: premerlo non deve aprire niente
	_app._chiudi_menu()
	if _app._btn_pref != null:
		_app._btn_pref.pressed.emit()
	_check("PREFERITI_NON_APRE", not _app._ctx_layer.visible,
			"premendo Preferiti si apre comunque una tendina")

	# L'elenco esiste ancora (lo usa la wiki) ma non e' agganciato alla cornice: se un
	# giorno lo si riattiva, deve navigare con _go -- qui si verifica solo che non sia
	# raggiungibile dall'interfaccia.
	var siti := WebRuntime.sites()
	_check("SITI_DEL_RUN", siti.size() > 0, "WebRuntime non elenca nessun sito")

	# serve comunque una navigazione per le prove sulla cronologia qui sotto
	_app._go("misteri")
	await _app.attendi_caricamento()
	await get_tree().process_frame

# ---------- 4: indietro/avanti/interrompi dicono la verita' ----------
func _prova_stato_pulsanti() -> void:
	# si e' appena navigato, quindi "indietro" DEVE essere attivo e "avanti" no
	_check("INDIETRO_ATTIVO", not _app._btn_back.disabled,
			"dopo aver navigato, 'indietro' e' ancora grigio")
	_check("AVANTI_SPENTO", _app._btn_fwd.disabled,
			"'avanti' e' attivo ma non c'e' nulla davanti")
	_app._go_back()
	await _app.attendi_caricamento()
	await get_tree().process_frame
	_check("AVANTI_ATTIVO_DOPO_INDIETRO", not _app._btn_fwd.disabled,
			"tornati indietro, 'avanti' dovrebbe essere attivo")
	# "interrompi" solo mentre si carica
	_check("INTERROMPI_SPENTO_A_RIPOSO", _app._btn_stop.disabled,
			"'interrompi' e' attivo a pagina ferma")
	_app._go("forum")
	_check("INTERROMPI_ATTIVO_IN_CARICA", not _app._btn_stop.disabled,
			"'interrompi' e' grigio mentre la pagina carica")
	await _app.attendi_caricamento()

# ---------- 5 e 6: niente pulsanti morti ----------
func _prova_nessun_pulsante_morto() -> void:
	var morti: Array = []
	var spenti := 0
	for b in _app.find_children("*", "Button", true, false):
		var btn := b as Button
		# le voci delle tendine si creano e distruggono: qui interessa la CORNICE
		if _app._ctx_layer != null and _app._ctx_layer.is_ancestor_of(btn):
			continue
		if btn.disabled:
			spenti += 1
			continue
		if btn.pressed.get_connections().is_empty():
			morti.append(btn.text if btn.text != "" else _icona_di(btn))
	_check("NIENTE_PULSANTI_MORTI", morti.is_empty(),
			"pulsanti attivi che non fanno niente: %s" % str(morti))
	_check("SPENTI_DICHIARATI", spenti >= 2,
			"solo %d pulsanti disabilitati: stampa e Preferiti dovrebbero esserlo" % spenti)
	print("   cornice: %d pulsanti disabilitati, nessuno morto" % spenti)

# ---------- helper ----------
func _bottoni_menu() -> Array:
	var out: Array = []
	for b in _app.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.flat and [Win95.testo_semplice(tr("MENU_FILE")),
				Win95.testo_semplice(tr("MENU_EDIT")), Win95.testo_semplice(tr("MENU_VIEW")),
				Win95.testo_semplice(tr("MENU_FAVORITES")), "?"].has(btn.text):
			if _app._ctx_layer == null or not _app._ctx_layer.is_ancestor_of(btn):
				out.append(btn)
	return out

func _strato() -> Control:
	return _app._ctx_layer

func _voci_tendina() -> Array:
	var out: Array = []
	for c in _app._ctx_menu.get_children():
		if c is Button:
			out.append(c)
	return out

func _voci_di(voci: Array) -> Array:
	var out: Array = []
	for v in voci:
		out.append(str(v[0]))
	return out

func _icona_di(b: Button) -> String:
	for c in b.get_children():
		if c is OSIcon:
			return "icona:" + str((c as OSIcon).kind)
	return "senza testo"

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		_fails.append(nome)
