extends Node

# Test della CORNICE di Esplora risorse: barra dei menu, barra strumenti, barra indirizzo.
#
# Perche' esiste: e' lo stesso difetto che aveva il browser. "File / Modifica / Visualizza
# / Strumenti / ?" erano cinque scritte senza alcun callback, e meta' della barra strumenti
# (taglia, copia, incolla, proprieta', viste) erano pulsanti a colori pieni che non
# facevano niente. Il proprietario ha chiesto la stessa cura data al browser: o funziona,
# o e' visibilmente grigio.
#
# Si pretende che:
#   1 ogni voce della barra dei menu apra una tendina non vuota;
#   2 esistano voci attive E voci disabilitate (se fossero tutte di un tipo, il test non
#     proverebbe niente); "Modifica" e' tutta grigia di proposito -- niente blocco appunti
#     per i file, e la selezione e' di uno alla volta;
#   3 i pulsanti finti (taglia/copia/incolla/proprieta'/viste) siano disabilitati E senza
#     callback: un pulsante grigio che reagisce comunque e' peggio di uno acceso;
#   4 "Indietro", "Su", "Elimina" e la freccia dell'indirizzo dicano la VERITA' sullo
#     stato: grigi in cima all'albero e senza selezione, accesi quando hanno dove andare;
#   5 la cartella PROTETTA non si possa eliminare. Era il buco serio: il menu contestuale
#     offriva "Elimina" su tutto, e mandarla nel Cestino rendeva il run invincibile;
#   6 nessun pulsante della cornice resti acceso senza callback;
#   7 la cornice STIA DENTRO le sue strisce, e a qualunque larghezza. Due difetti veri,
#     segnalati dal proprietario ("si e' rotto tutto", 20/09/2026) e misurati: la barra
#     dei menu era alta 26 px con dentro pulsanti da 31, quindi le voci sbordavano di 7 px
#     sulla barra sotto e le due barre sembravano schiacciate; e in una finestra stretta
#     la barra strumenti usciva di 29 px dal bordo, tagliando gli ultimi pulsanti;
#   8 tre difetti segnalati provandolo (20/09/2026), tutti e tre riprodotti prima di
#     essere corretti:
#     - "Informazioni su" non si apriva. La voce chiamava _riempi_menu() DA DENTRO il
#       proprio segnale "pressed", e il vecchio free() sul pulsante che stava emettendo
#       faceva fallire Godot ("Object is locked and can't be freed"): la tendina restava
#       a meta'. Qualunque voce che riapra un menu ricadrebbe nello stesso buco.
#       E poi (21/09/2026) il riquadro si SPOSTAVA con la finestra: ognuno se lo disegnava
#       dentro la propria, cosi' ingrandita finiva in un punto e piccola in un altro, e in
#       una finestra stretta veniva tagliato dal bordo. Adesso lo apre il DESKTOP ed e'
#       sempre al centro dello schermo: si prova in due stati della finestra e anche dal
#       browser, o non si proverebbe la cosa che era rotta;
#     - "Icone grandi" non faceva niente: era l'unica vista e cliccarla ridisegnava la
#       stessa cosa. Adesso le viste sono due davvero e la tendina segna quella in uso;
#     - un file appena creato si vedeva storto: nasce SELEZIONATO, e _draw() leggeva la
#       posizione dell'etichetta prima che il contenitore l'avesse impaginata, cosi' il
#       riquadro blu finiva sopra l'icona e il nome (bianco) spariva. Qui si guardano i
#       PIXEL, perche' era un difetto di pixel: lo stato interno era giusto anche prima;
#   9 l'ACCELERATORE della barra dei menu (21/09/2026): la lettera sottolineata come su
#     Win95. La & del CSV non deve arrivare a schermo, le lettere devono essere UNICHE
#     dentro la barra (in inglese "Favorites" prende la A perche' la F e' di "File", come
#     faceva Internet Explorer), ALT+lettera deve aprire quella tendina -- una lettera
#     sottolineata che non risponde sarebbe una promessa non mantenuta -- e la riga deve
#     essere DISEGNATA: si guardano i pixel sotto la lettera, e sotto il "?" (che non ha
#     acceleratore) non ci deve essere.
#
# Va eseguito come SCENA (serve l'autoload GameManager). A FINESTRA, non headless: il
# controllo 8 legge i pixel.
#   & $godot --path $proj res://tests/esplora_chrome_test.tscn
# ============================================================

var _vp: SubViewport
var _os = null
var _win: OSWindow = null
var _app: FileExplorerApp = null
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func(): _timeout())
	await get_tree().process_frame
	GameManager.start_new_run(4242)
	GameManager.pc_on = true
	GameManager.logged_in = true

	_vp = SubViewport.new()
	_vp.size = Vector2i(1440, 1080)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS   # servono i pixel veri
	_vp.disable_3d = true
	add_child(_vp)
	_os = load("res://scripts/os/desktop.gd").new()
	_os.position = Vector2.ZERO
	_os.size = Vector2(1440, 1080)
	_vp.add_child(_os)
	for i in range(4):
		await get_tree().process_frame

	_win = _os.open_app("explorer", null)      # si parte da "Risorse del computer"
	for c in _win.content_root.get_children():
		if c is FileExplorerApp:
			_app = c
	if _app == null:
		print("RISULTATO: FAIL -> Esplora non aperto")
		get_tree().quit(1)
		return
	for i in range(3):
		await get_tree().process_frame

	_prova_barra_menu()
	_prova_pulsanti_finti()
	await _prova_stato_pulsanti()
	_prova_menu_file_con_selezione()
	_prova_cartella_protetta()
	_prova_nessun_pulsante_morto()
	await _prova_geometria()
	await _prova_about_centrato()
	_prova_viste()
	await _prova_file_nuovo()
	await _prova_acceleratori()

	if _fails.is_empty():
		print("RISULTATO: PASS (la cornice risponde, e cio' che non fa niente lo dichiara)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

func _timeout() -> void:
	print("RISULTATO: FAIL -> timeout")
	get_tree().quit(1)

# ---------- 1 e 2: le tendine ----------

func _prova_barra_menu() -> void:
	# la & dell'acceleratore sta nel CSV ma NON deve arrivare a schermo
	var attese := [Win95.testo_semplice(tr("MENU_FILE")), Win95.testo_semplice(tr("MENU_EDIT")),
			Win95.testo_semplice(tr("MENU_VIEW")), Win95.testo_semplice(tr("MENU_TOOLS")), "?"]
	var trovate: Array = []
	for b in _bottoni_menu():
		trovate.append((b as Button).text)
	_check("VOCI_BARRA_MENU", trovate == attese,
			"la barra dei menu ha %s invece di %s" % [str(trovate), str(attese)])

	var totale_attive := 0
	var totale_spente := 0
	var menu_con_attive := 0
	var attive_modifica := -1
	for b in _bottoni_menu():
		var btn := b as Button
		btn.pressed.emit()
		if _app._ctx_layer == null or not _app._ctx_layer.visible:
			_check("TENDINA_" + btn.text.to_upper(), false, "'%s' non apre niente" % btn.text)
			continue
		var voci := _voci_tendina()
		if voci.is_empty():
			_check("TENDINA_" + btn.text.to_upper(), false, "la tendina di '%s' e' vuota" % btn.text)
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
		if attive > 0:
			menu_con_attive += 1
		if btn.text == Win95.testo_semplice(tr("MENU_EDIT")):
			attive_modifica = attive
		print("   %-12s %d voci: %d attive, %d disabilitate" % [btn.text, voci.size(), attive, spente])
		_check("TENDINA_" + btn.text.to_upper(), true, "")
		_app._chiudi_menu()

	_check("CI_SONO_VOCI_SPENTE", totale_spente >= 8,
			"solo %d voci disabilitate: o si finge che tutto funzioni, o il test non prova niente"
			% totale_spente)
	# In cima all'albero (Risorse del computer, senza selezione) MOLTE voci sono grigie a
	# ragione: non si crea un file dentro "Risorse del computer" e non c'e' niente di
	# aperto o da eliminare. Che tornino attive quando ha senso lo prova
	# _prova_menu_file_con_selezione(), qui sotto: e' quella la meta' che conta.
	_check("CI_SONO_VOCI_ATTIVE", totale_attive >= 3,
			"solo %d voci attive in tutta la barra dei menu" % totale_attive)
	_check("MENU_UTILI", menu_con_attive >= 3,
			"solo %d tendine su 5 hanno qualcosa di attivo" % menu_con_attive)
	# "Modifica" e' grigia per intero DI PROPOSITO: se un giorno arrivasse un blocco
	# appunti per i file, questo controllo va aggiornato -- non tolto in silenzio.
	_check("MODIFICA_TUTTA_GRIGIA", attive_modifica == 0,
			"la tendina Modifica ha %d voci attive: non c'e' un blocco appunti per i file"
			% attive_modifica)

# ---------- 3: i pulsanti finti ----------

func _prova_pulsanti_finti() -> void:
	# "Viste" NON e' piu' in questo elenco: adesso cambia davvero vista (icone grandi /
	# piccole). Taglia, copia, incolla e proprieta' restano finti per scelta.
	var finti := [tr("NP_CUT"), tr("NP_COPY"), tr("NP_PASTE"), tr("EX_PROPERTIES")]
	var visti := 0
	for nome in finti:
		var b := _pulsante_con_didascalia(str(nome))
		if b == null:
			_check("FINTO_" + str(nome).to_upper(), false, "manca il pulsante '%s'" % str(nome))
			continue
		visti += 1
		_check("FINTO_" + str(nome).to_upper(), b.disabled and b.pressed.get_connections().is_empty(),
				"'%s': disabled=%s, callback=%d" % [str(nome), str(b.disabled),
				b.pressed.get_connections().size()])
	_check("PULSANTI_FINTI_PRESENTI", visti == finti.size(),
			"trovati %d pulsanti finti su %d" % [visti, finti.size()])

# ---------- 4: lo stato dice la verita' ----------

func _prova_stato_pulsanti() -> void:
	# in cima all'albero: non si sale, non si torna indietro, non c'e' selezione
	_check("SU_SPENTO_IN_CIMA", _app._btn_up.disabled,
			"'Su' e' attivo in Risorse del computer, dove non c'e' niente sopra")
	_check("INDIETRO_SPENTO_ALL_APERTURA", _app._btn_back.disabled,
			"'Indietro' e' attivo appena aperta la finestra")
	_check("ELIMINA_SPENTO_SENZA_SELEZIONE", _app._btn_del.disabled,
			"'Elimina' e' attivo senza niente di selezionato")
	_check("FRECCIA_SPENTA_IN_CIMA", _app._btn_drop.disabled,
			"la freccia dell'indirizzo e' attiva in cima all'albero")

	# si scende in C:
	_entra(OSContent._t("VFS_C_DRIVE"))
	await get_tree().process_frame
	_check("SU_ATTIVO_DENTRO", not _app._btn_up.disabled, "sceso in C:, 'Su' e' ancora grigio")
	_check("INDIETRO_ATTIVO_DOPO", not _app._btn_back.disabled,
			"dopo aver navigato, 'Indietro' e' ancora grigio")
	_check("FRECCIA_ATTIVA_DENTRO", not _app._btn_drop.disabled,
			"sceso in C:, la freccia dell'indirizzo e' grigia")

	# la freccia elenca le cartelle di sopra e ci porta
	_app._btn_drop.pressed.emit()
	var voci := _voci_tendina()
	_check("FRECCIA_ELENCA", voci.size() >= 1 and not (voci[0] as Button).disabled,
			"la freccia dell'indirizzo non elenca niente di raggiungibile")
	_app._chiudi_menu()

	# un file selezionato si puo' eliminare
	var scelto := _seleziona_primo_file()
	await get_tree().process_frame
	_check("ELIMINA_ATTIVO_CON_FILE", scelto != "" and not _app._btn_del.disabled,
			"selezionato '%s', 'Elimina' e' ancora grigio" % scelto)

# ---------- 4b: le voci si accendono quando ha senso ----------
# Il seguito di _prova_barra_menu: adesso si e' dentro una cartella e un file e'
# selezionato, quindi "Nuovo", "Apri" ed "Elimina" DEVONO essere attive. Senza questo
# controllo un menu File tutto grigio passerebbe per corretto.
func _prova_menu_file_con_selezione() -> void:
	var file_btn: Button = null
	for b in _bottoni_menu():
		if (b as Button).text == Win95.testo_semplice(tr("MENU_FILE")):
			file_btn = b
	if file_btn == null:
		_check("MENU_FILE_CON_SELEZIONE", false, "non trovo la voce File")
		return
	file_btn.pressed.emit()
	var attive: Array = []
	for v in _voci_tendina():
		var b2: Button = v
		if not b2.disabled:
			attive.append(b2.text)
	_check("MENU_FILE_SI_ACCENDE", attive.has(tr("EX_NEW_TEXT")) and attive.has(tr("EX_OPEN"))
			and attive.has(tr("EX_DELETE")),
			"con un file selezionato dentro C: le voci attive sono %s" % str(attive))
	print("   File con selezione: %d voci attive (%s)" % [attive.size(), ", ".join(attive)])
	_app._chiudi_menu()

# ---------- 5: la cartella protetta non si elimina ----------

func _prova_cartella_protetta() -> void:
	# Risorse del computer -> C: -> WHALE -> Desktop, dove vive la cartella protetta
	_app._folder = VFS.get_desktop()
	_app._refresh()
	var protetta: DesktopItem = null
	for it in _app._items:
		var item: DesktopItem = it
		if str(item.data.get("type", "")) == "secret":
			protetta = item
	if protetta == null:
		_check("PROTETTA_TROVATA", false, "sul Desktop non c'e' la cartella protetta")
		return
	_app._on_picked(protetta)
	_check("ELIMINA_SPENTO_SU_PROTETTA", _app._btn_del.disabled,
			"la cartella protetta si puo' eliminare: mandarla nel Cestino rende il run invincibile")
	# ...e nemmeno dal menu contestuale
	_app._on_item_context(protetta)
	var canc := _voce_tendina(tr("EX_DELETE"))
	_check("MENU_ELIMINA_SPENTO_SU_PROTETTA", canc != null and canc.disabled,
			"nel menu contestuale della cartella protetta 'Elimina' non e' grigia")
	_app._chiudi_menu()
	# e la prova del nove: il nodo e' ancora dov'era
	_check("PROTETTA_ANCORA_LI", str(VFS.get_desktop().get("children", [])[0].get("type", "")) == "secret",
			"la cartella protetta non e' piu' sul Desktop")

# ---------- 6: niente pulsanti morti ----------

func _prova_nessun_pulsante_morto() -> void:
	_app._chiudi_menu()
	var morti: Array = []
	var spenti := 0
	for b in _app.find_children("*", "Button", true, false):
		var btn := b as Button
		if _app._ctx_layer != null and _app._ctx_layer.is_ancestor_of(btn):
			continue          # le voci delle tendine nascono e muoiono: qui conta la CORNICE
		if btn.disabled:
			spenti += 1
			continue
		if btn.pressed.get_connections().is_empty():
			morti.append(btn.text if btn.text != "" else _icona_di(btn))
	_check("NIENTE_PULSANTI_MORTI", morti.is_empty(),
			"pulsanti attivi che non fanno niente: %s" % str(morti))
	_check("SPENTI_DICHIARATI", spenti >= 4,
			"solo %d pulsanti disabilitati: taglia/copia/incolla/proprieta' lo sono" % spenti)
	print("   cornice: %d pulsanti disabilitati, nessuno morto" % spenti)

# ---------- 7: la cornice sta dentro le sue strisce ----------

func _prova_geometria() -> void:
	_app._chiudi_menu()
	# la finestra non si deve poter stringere sotto la larghezza della barra strumenti
	var minimo: float = _win.custom_minimum_size.x
	_win.size = Vector2(240, 380)
	await get_tree().process_frame
	_check("LARGHEZZA_MINIMA", minimo > 240.0 and _win.size.x >= minimo - 1.0,
			"chiesti 240 px di larghezza, la finestra e' %.0f (minimo dichiarato %.0f)"
			% [_win.size.x, minimo])
	# ...e a nessuna larghezza il contenuto di una barra esce dalla sua striscia
	for larghezza in [minimo, 600.0, 900.0, 1300.0]:
		_win.size = Vector2(float(larghezza), 400.0)
		await get_tree().process_frame
		await get_tree().process_frame
		var peggio := -9999.0
		var dove := ""
		for c in (_app.get_child(0) as Control).get_children():
			var striscia: Control = c
			for f in striscia.get_children():
				if f is Control:
					var box: Control = f
					var fuori: float = maxf(box.size.x - striscia.size.x, box.size.y - striscia.size.y)
					if fuori > peggio:
						peggio = fuori
						dove = striscia.get_class()
					break
		if peggio > 0.0:
			_ko("CORNICE_DENTRO", "a %.0f px di finestra una barra sborda di %.0f px (%s)"
					% [_win.size.x, peggio, dove])
	_check("CORNICE_DENTRO_OK", not _fails.has("CORNICE_DENTRO"),
			"una barra della cornice esce dalla sua striscia")

# ---------- 8a: "Informazioni su" e' un dialogo CENTRATO sullo schermo ----------

func _prova_about_centrato() -> void:
	_app._chiudi_menu()
	var schermo: Vector2 = _os.size
	var centro: Vector2 = (schermo * 0.5).floor()

	# LA FINESTRA PICCOLA IN UN ANGOLO e poi la stessa INGRANDITA: era esattamente la
	# differenza segnalata, quindi il dialogo va guardato in tutti e due gli stati.
	_win.size = Vector2(470, 300)
	_win.position = Vector2(30, 700)
	await get_tree().process_frame
	_about_qui("PICCOLA", centro, tr("EX_ABOUT"), func(): _app._informazioni())

	_win.toggle_max()
	await get_tree().process_frame
	_about_qui("INGRANDITA", centro, tr("EX_ABOUT"), func(): _app._informazioni())
	_win.toggle_max()
	await get_tree().process_frame

	# ...e dal BROWSER, che ha il suo About e deve finire nello stesso posto
	var wb: OSWindow = _os.open_app("browser", "start")
	wb.position = Vector2(860, 40)
	var br = null
	for ch in wb.content_root.get_children():
		if ch is BrowserApp:
			br = ch
	for i in range(4):
		await get_tree().process_frame
	if br == null:
		_check("ABOUT_BROWSER", false, "browser non aperto")
	else:
		_about_qui("BROWSER", centro, tr("BR_ABOUT"), func(): br._informazioni())
	wb.close()
	await get_tree().process_frame

# Apre l'About con la funzione data e pretende: che esista, che il suo pannello sia
# CENTRATO sullo schermo, che NON stia dentro la finestra del programma (o un bordo lo
# taglierebbe), che il titolo sia quello giusto, e che OK lo chiuda.
func _about_qui(caso: String, centro: Vector2, titolo: String, apri: Callable) -> void:
	apri.call()
	var strato: Control = _os._modal_chiudibile
	if strato == null or not is_instance_valid(strato):
		_check("ABOUT_" + caso, false, "l'About non si e' aperto")
		return
	var p: Panel = null
	for c in strato.get_children():
		if c is Panel:
			p = c
	if p == null:
		_check("ABOUT_" + caso, false, "il dialogo non ha un pannello")
		return
	var suo_centro: Vector2 = p.position + p.size * 0.5
	_check("ABOUT_CENTRATO_" + caso, (suo_centro - centro).length() <= 1.5,
			"il dialogo e' centrato in %s invece di %s" % [str(suo_centro), str(centro)])
	_check("ABOUT_SUL_DESKTOP_" + caso, not _win.is_ancestor_of(p),
			"il dialogo sta dentro la finestra del programma: un bordo lo taglierebbe")
	_check("ABOUT_TITOLO_" + caso, _titolo_di(p) == titolo,
			"il titolo dice '%s' invece di '%s'" % [_titolo_di(p), titolo])
	# il nome del programma dev'essere scritto dentro, non solo nel titolo
	var righe := PackedStringArray()
	for c in p.get_children():
		if c is Label:
			righe.append((c as Label).text)
	_check("ABOUT_CONTENUTO_" + caso, righe.size() >= 3,
			"nel dialogo ci sono %d righe: %s" % [righe.size(), str(righe)])
	# e OK lo chiude
	var ok: Button = p.get_node_or_null("OK")
	if ok == null:
		_check("ABOUT_OK_" + caso, false, "il dialogo non ha il pulsante OK")
		return
	ok.pressed.emit()
	_check("ABOUT_OK_" + caso, not is_instance_valid(strato) or strato.is_queued_for_deletion(),
			"premendo OK il dialogo resta aperto")

func _titolo_di(p: Panel) -> String:
	for c in p.get_children():
		if c is ColorRect:
			for l in (c as ColorRect).get_children():
				if l is Label:
					return (l as Label).text
	return ""

# ---------- 8b: le viste sono due e si vede quale ----------

func _prova_viste() -> void:
	_app._imposta_vista(FileExplorerApp.VISTA_GRANDI)
	var cella_grandi: int = _app._cella_w()
	var icona_grandi: float = _icona_primo_elemento()
	_app._imposta_vista(FileExplorerApp.VISTA_PICCOLE)
	var cella_piccole: int = _app._cella_w()
	var icona_piccole: float = _icona_primo_elemento()
	_check("VISTE_DIVERSE", cella_piccole < cella_grandi and icona_piccole < icona_grandi,
			"cella %d -> %d, icona %.0f -> %.0f: la vista non cambia niente"
			% [cella_grandi, cella_piccole, icona_grandi, icona_piccole])
	# ...e la tendina segna quella in uso, cosi' "l'ho cliccata e non succede niente"
	# ha una risposta scritta: succede gia'
	var segnata := ""
	for v in _voci_menu(_app._voci_visualizza()):
		if str(v).find(tr("EX_SMALL_ICONS")) >= 0:
			segnata = str(v)
	_check("VISTA_SEGNATA", segnata != "" and segnata.strip_edges() != tr("EX_SMALL_ICONS"),
			"con le icone piccole attive la voce e' '%s': nessun segno" % segnata)
	_app._imposta_vista(FileExplorerApp.VISTA_GRANDI)

# ---------- 8c: un file appena creato si vede giusto ----------

func _prova_file_nuovo() -> void:
	# La finestra torna GRANDE: le prove dell'About l'hanno lasciata piccola in un angolo,
	# e in 300 px di altezza l'elemento nuovo cade nella seconda riga, fuori dall'area
	# visibile -- i pixel letti sarebbero quelli del fondo e il controllo non direbbe
	# niente. Che l'elemento sia davvero visibile si pretende qui sotto.
	_win.size = Vector2(740, 520)
	_win.position = Vector2(40, 40)
	for i in range(2):
		await get_tree().process_frame
	# si va in una cartella dove si puo' creare
	_app._folder = VFS.resolve_node([OSContent._t("VFS_MY_COMPUTER"),
			OSContent._t("VFS_C_DRIVE"), OSContent._t("VFS_DOCUMENTS")])
	_app._refresh()
	for i in range(3):
		await get_tree().process_frame
	_app._new_text_file()
	for i in range(4):
		await get_tree().process_frame
	var nuovo: DesktopItem = null
	for it in _app._items:
		var item: DesktopItem = it
		if item.selected:
			nuovo = item
	if nuovo == null:
		_check("FILE_NUOVO_SELEZIONATO", false, "il file appena creato non risulta selezionato")
		return
	# lo stato: il riquadro blu sta sull'ETICHETTA, che sta SOTTO l'icona
	var r: Rect2 = nuovo.rett_selezione()
	_check("SELEZIONE_SULL_ETICHETTA", r.position.y >= 20.0 and r.size.y > 4.0,
			"il riquadro della selezione e' in %s: dovrebbe stare sotto l'icona" % str(r))

	# l'elemento deve stare DENTRO l'area visibile, o i pixel qui sotto non sono i suoi
	var visibile: Rect2 = _app._scroll.get_global_rect()
	_check("FILE_NUOVO_VISIBILE", visibile.encloses(nuovo.get_global_rect()),
			"l'elemento nuovo (%s) non sta dentro l'area visibile (%s)"
			% [str(nuovo.get_global_rect()), str(visibile)])

	# i PIXEL: sopra (l'icona) niente blu, sul nome blu. E' qui che si vedeva storto.
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	var org: Vector2 = nuovo.get_global_rect().position
	var su := img.get_pixelv(Vector2i(org + Vector2(r.position.x + r.size.x * 0.5, 8.0)))
	_check("PIXEL_ICONA_NON_BLU", not _e_blu(su),
			"sopra l'icona c'e' il blu della selezione: %s" % str(su))
	# sul nome si campiona in PIU' PUNTI: uno solo cadeva su una lettera, che e' bianca
	# (testo bianco su fondo blu), e il controllo falliva pur essendo tutto giusto
	var blu := 0
	var provati := 0
	for fx in [0.08, 0.2, 0.35, 0.5, 0.65, 0.8, 0.92]:
		for fy in [0.3, 0.7]:
			var p := Vector2i(org + r.position + Vector2(r.size.x * fx, r.size.y * fy))
			provati += 1
			if _e_blu(img.get_pixelv(p)):
				blu += 1
	_check("PIXEL_NOME_BLU", blu >= 4,
			"il nome non e' evidenziato: solo %d punti blu su %d dentro l'etichetta"
			% [blu, provati])

func _e_blu(c: Color) -> bool:
	return c.b > 0.35 and c.r < 0.25 and c.g < 0.25

func _icona_primo_elemento() -> float:
	if _app._items.is_empty():
		return 0.0
	var it: DesktopItem = _app._items[0]
	for c in it.get_children():
		if c is OSIcon:
			return (c as OSIcon).custom_minimum_size.x
	return 0.0

# I testi delle voci di una tendina, senza costruirla.
func _voci_menu(voci: Array) -> Array:
	var out: Array = []
	for v in voci:
		out.append(str(v[0]))
	return out

# ---------- 9: l'acceleratore sottolineato ----------

func _prova_acceleratori() -> void:
	_app._chiudi_menu()
	_os.focus_window(_win)        # la tastiera va alla finestra ATTIVA
	_win.size = Vector2(740, 520)
	for i in range(3):
		await get_tree().process_frame

	# la & non arriva a schermo, e ogni voce (tranne "?") ha la sua lettera
	var lettere: Array = []
	var senza: Array = []
	for b in _bottoni_menu():
		var btn := b as Button
		if btn.text.find("&") >= 0:
			_ko("NIENTE_AMPERSAND", "la voce '%s' mostra la & del CSV" % btn.text)
		var acc := str(btn.get_meta("acceleratore", ""))
		if acc == "":
			senza.append(btn.text)
		else:
			lettere.append(acc)
			if btn.text.to_lower().find(acc) < 0:
				_ko("LETTERA_NEL_TESTO", "'%s' dice di avere l'acceleratore '%s'" % [btn.text, acc])
	_check("NIENTE_AMPERSAND_OK", not _fails.has("NIENTE_AMPERSAND"), "la & arriva a schermo")
	_check("ACCELERATORI_CI_SONO", lettere.size() >= 4,
			"solo %d voci su %d hanno l'acceleratore" % [lettere.size(), _bottoni_menu().size()])
	# UNICHE: due voci con la stessa lettera renderebbero ALT ambiguo
	var viste := {}
	var doppie: Array = []
	for l in lettere:
		if viste.has(l):
			doppie.append(str(l))
		viste[l] = true
	_check("ACCELERATORI_UNICI", doppie.is_empty(),
			"lettere ripetute nella barra: %s" % ", ".join(doppie))
	print("   acceleratori: %s   senza: %s" % [", ".join(lettere), str(senza)])

	# ALT+lettera apre QUELLA tendina (e non una qualunque)
	var vista := _voce_menu_con_acceleratore(Win95.testo_semplice(tr("MENU_VIEW")))
	if vista == "":
		_check("ALT_APRE", false, "la voce Visualizza non ha acceleratore")
		return
	await _alt(vista)
	var aperto := _app._ctx_layer != null and _app._ctx_layer.visible
	var e_visualizza := false
	for v in _voci_tendina():
		if (v as Button).text.find(Win95.testo_semplice(tr("EX_LARGE_ICONS"))) >= 0:
			e_visualizza = true
	_check("ALT_APRE", aperto and e_visualizza,
			"ALT+%s: tendina aperta=%s, ed e' quella di Visualizza=%s"
			% [vista.to_upper(), str(aperto), str(e_visualizza)])
	_app._chiudi_menu()
	await get_tree().process_frame

	# ...e la riga sotto la lettera e' DISEGNATA (pixel), mentre sotto il "?" non c'e'
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	for b in _bottoni_menu():
		var btn := b as Button
		var acc := str(btn.get_meta("acceleratore", ""))
		var riga := _riga_sottolineata(img, btn.get_global_rect())
		if acc == "":
			_check("NIENTE_RIGA_SU_" + btn.text, not riga,
					"'%s' non ha acceleratore ma ha una riga sotto" % btn.text)
		else:
			_check("RIGA_SU_" + btn.text.to_upper(), riga,
					"sotto '%s' non c'e' la sottolineatura" % btn.text)

# Una riga orizzontale continua (>= 5 px scuri di fila) nella parte BASSA del pulsante,
# sotto la base del testo: li' nessun glifo di queste parole ha inchiostro, quindi una
# corsa lunga puo' essere solo la sottolineatura.
func _riga_sottolineata(img: Image, r: Rect2) -> bool:
	var y0 := int(r.position.y + r.size.y * 0.60)
	var y1 := int(r.position.y + r.size.y) - 2
	for y in range(y0, y1):
		var corsa := 0
		for x in range(int(r.position.x) + 2, int(r.end.x) - 2):
			var c := img.get_pixel(x, y)
			if c.r < 0.45 and c.g < 0.45 and c.b < 0.45:
				corsa += 1
				if corsa >= 5:
					return true
			else:
				corsa = 0
	return false

func _voce_menu_con_acceleratore(testo: String) -> String:
	for b in _bottoni_menu():
		var btn := b as Button
		if btn.text == testo:
			return str(btn.get_meta("acceleratore", ""))
	return ""

# ALT+lettera spinto nel SubViewport come lo spingerebbe una tastiera vera.
func _alt(lettera: String) -> void:
	var e := InputEventKey.new()
	e.keycode = int(lettera.to_upper().unicode_at(0))
	e.alt_pressed = true
	e.pressed = true
	_vp.push_input(e, true)
	for i in range(2):
		await get_tree().process_frame

# ---------- helper ----------

func _entra(nome: String) -> void:
	for c in _app._folder.get("children", []):
		if c is Dictionary and str(c.get("name", "")) == nome:
			_app._on_activated(c)
			return

func _seleziona_primo_file() -> String:
	for it in _app._items:
		var item: DesktopItem = it
		if str(item.data.get("type", "")) == "file":
			_app._on_picked(item)
			return str(item.data.get("name", "?"))
	return ""

func _bottoni_menu() -> Array:
	var attese := [Win95.testo_semplice(tr("MENU_FILE")), Win95.testo_semplice(tr("MENU_EDIT")),
			Win95.testo_semplice(tr("MENU_VIEW")), Win95.testo_semplice(tr("MENU_TOOLS")), "?"]
	var out: Array = []
	for b in _app.find_children("*", "Button", true, false):
		var btn := b as Button
		if btn.flat and attese.has(btn.text):
			if _app._ctx_layer == null or not _app._ctx_layer.is_ancestor_of(btn):
				out.append(btn)
	return out

# Un pulsante della barra strumenti si riconosce dalla DIDASCALIA, che e' una Label figlia.
func _pulsante_con_didascalia(testo: String) -> Button:
	for b in _app.find_children("*", "Button", true, false):
		var btn := b as Button
		if _app._ctx_layer != null and _app._ctx_layer.is_ancestor_of(btn):
			continue
		for l in btn.find_children("*", "Label", true, false):
			if (l as Label).text == testo:
				return btn
	return null

func _voci_tendina() -> Array:
	var out: Array = []
	for c in _app._ctx_vbox.get_children():
		if c is Button:
			out.append(c)
	return out

func _voce_tendina(testo: String) -> Button:
	for v in _voci_tendina():
		if (v as Button).text == testo:
			return v
	return null

func _icona_di(b: Button) -> String:
	for c in b.find_children("*", "OSIcon", true, false):
		return "icona:" + str((c as OSIcon).kind)
	return "senza testo"

func _ko(nome: String, perche: String) -> void:
	print("FAIL  %s -- %s" % [nome, perche])
	if not _fails.has(nome):
		_fails.append(nome)

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		if not _fails.has(nome):
			_fails.append(nome)
