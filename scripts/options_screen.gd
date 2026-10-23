class_name OptionsScreen
extends CanvasLayer

# Schermata OPZIONI del menu principale. Costruita in CODICE come le altre
# sovrimpressioni del gioco (pause_screen.gd, death_screen.gd) e non nella scena del
# menu: quella scena e' del proprietario, e il menu si limita ad aprire questa.
#
# Dentro: la LINGUA (richiesta del proprietario, 19/09/2026) e il VIDEO -- schermo intero,
# V-Sync, risoluzione della finestra (23/10/2026). Le scelte video le tiene e le salva
# GameManager (set_schermo_intero / set_vsync / set_risoluzione). Il resto (volume,
# sensibilita') arrivera' con M6: _aggiungi_riga() aggiunge una riga e basta.
#
# Perche' la lingua si cambia SOLO dal menu: il testo DENTRO il gioco (nomi dei file,
# contenuto dei file, pagine web) viene generato quando parte il run, percio' cambiarla a
# meta' partita non riscriverebbe il PC. Dal menu la scelta arriva prima dello "Start" e
# vale per tutto il run che segue.

# La lingua e' cambiata: chi ha aperto la schermata (il menu) deve rifare le sue scritte,
# che erano state assegnate con tr() quando era la lingua di prima.
signal lingua_cambiata
signal chiusa

# Ogni riga di scelte: {"pulsanti": {valore -> Button}, "attuale": Callable che da' il valore
# scelto}. _aggiorna_selezione() le ridisegna tutte.
var _righe: Array[Dictionary] = []
var _pulsanti: Dictionary = {}       # codice lingua -> Button (la riga della lingua)
var _pulsanti_ris: Dictionary = {}   # Vector2i -> Button (spenti a schermo intero)
var _etichette: Dictionary = {}      # Label -> chiave di locale/ui.csv
var _testi_si_no: Array[Button] = [] # i pulsanti Si'/No, ritradotti col cambio di lingua
var _titolo: Label
var _indietro: Button

func _ready() -> void:
	layer = 10                                 # il menu non usa layer: qui sopra e' libero
	_costruisci()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):   # ESC: come il pulsante Indietro
		get_viewport().set_input_as_handled()
		chiudi()

func chiudi() -> void:
	chiusa.emit()
	queue_free()

# ---------------- costruzione ----------------

func _costruisci() -> void:
	var radice := Control.new()
	radice.name = "Radice"
	radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.mouse_filter = Control.MOUSE_FILTER_STOP   # nessun clic ai pulsanti del menu sotto
	add_child(radice)

	# nero PIENO, per la stessa ragione della schermata di pausa: con un nero
	# trasparente il titolo e i pulsanti del menu traspaiono attraverso il pannello e
	# sembra un difetto di disegno, non una schermata
	var sfondo := ColorRect.new()
	sfondo.color = Color.BLACK
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.add_child(sfondo)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 24)
	radice.add_child(vb)

	_titolo = Label.new()
	_titolo.name = "Titolo"
	_titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titolo.add_theme_font_size_override("font_size", 80)
	_titolo.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vb.add_child(_titolo)

	vb.add_child(_stacco(40))

	# etichette in una colonna, pulsanti nell'altra: le righe restano allineate
	var griglia := GridContainer.new()
	griglia.columns = 2
	griglia.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	griglia.add_theme_constant_override("h_separation", 40)
	griglia.add_theme_constant_override("v_separation", 24)
	vb.add_child(griglia)

	_aggiungi_riga(griglia, "EtichettaLingua", "UI_LANGUAGE", _pulsanti_lingua())
	_aggiungi_riga(griglia, "EtichettaSchermoIntero", "UI_VIDEO_FULLSCREEN",
			_scelte_si_no("SchermoIntero", func(): return GameManager.schermo_intero, _su_schermo_intero))
	_aggiungi_riga(griglia, "EtichettaVSync", "UI_VIDEO_VSYNC",
			_scelte_si_no("VSync", func(): return GameManager.vsync, _su_vsync))
	_aggiungi_riga(griglia, "EtichettaRisoluzione", "UI_VIDEO_RESOLUTION", _pulsanti_risoluzione())

	vb.add_child(_stacco(60))

	_indietro = Button.new()
	_indietro.name = "Indietro"
	_indietro.custom_minimum_size = Vector2(360, 96)
	_indietro.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_indietro.add_theme_font_size_override("font_size", 44)
	_indietro.pressed.connect(chiudi)
	vb.add_child(_indietro)

	_aggiorna_testi()
	_aggiorna_selezione()

# Una riga di impostazione: l'etichetta nella prima colonna, i pulsanti nella seconda.
func _aggiungi_riga(griglia: GridContainer, nome: String, chiave: String, comandi: Array) -> void:
	var et := Label.new()
	et.name = nome
	et.add_theme_font_size_override("font_size", 44)
	et.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	et.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	et.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_etichette[et] = chiave
	griglia.add_child(et)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	for c in comandi:
		hb.add_child(c)
	griglia.add_child(hb)

# Un pulsante di una riga a scelta unica. Il NOME del nodo e' un identificatore (i test lo
# cercano: non deve dipendere dalla lingua in corso).
func _pulsante_scelta(nome: String, gruppo: ButtonGroup, premuto: bool, larghezza: int) -> Button:
	var b := Button.new()
	b.name = nome
	b.toggle_mode = true
	b.button_group = gruppo
	b.button_pressed = premuto
	b.custom_minimum_size = Vector2(larghezza, 96)
	b.add_theme_font_size_override("font_size", 40)
	return b

# Una riga Si'/No (schermo intero, V-Sync).
func _scelte_si_no(nome: String, attuale: Callable, su_scelta: Callable) -> Array:
	var gruppo := ButtonGroup.new()
	var pulsanti := {}
	for valore in [true, false]:
		var b := _pulsante_scelta(nome + ("Si" if valore else "No"), gruppo, valore == attuale.call(), 180)
		b.set_meta("chiave", "UI_ON" if valore else "UI_OFF")
		b.toggled.connect(func(premuto: bool):
			if premuto and valore != attuale.call():
				su_scelta.call(valore)
				_aggiorna_selezione())
		pulsanti[valore] = b
		_testi_si_no.append(b)
	_righe.append({"pulsanti": pulsanti, "attuale": attuale})
	return pulsanti.values()

# La risoluzione della FINESTRA: solo quelle che stanno nello schermo. A schermo intero non
# conta (la finestra e' lo schermo) e i pulsanti si spengono, visibilmente.
func _pulsanti_risoluzione() -> Array:
	var gruppo := ButtonGroup.new()
	var attuale := func(): return GameManager.risoluzione_attuale()
	for r in GameManager.risoluzioni_possibili():
		var ris: Vector2i = r
		var b := _pulsante_scelta("Ris%dx%d" % [ris.x, ris.y], gruppo, ris == attuale.call(), 230)
		b.add_theme_font_size_override("font_size", 32)
		b.toggled.connect(func(premuto: bool):
			if premuto and ris != GameManager.risoluzione_attuale():
				GameManager.set_risoluzione(ris)
				_aggiorna_selezione())
		_pulsanti_ris[ris] = b
	_righe.append({"pulsanti": _pulsanti_ris, "attuale": attuale})
	return _pulsanti_ris.values()

# Un pulsante per lingua. Il NOME del nodo e' il codice della lingua (identificatore:
# i test lo cercano e non deve dipendere dalla lingua in corso), il TESTO e' l'endonimo
# -- "Italiano", non "Italian": in un elenco di lingue ognuna si scrive nella propria,
# o chi cerca la sua non la riconosce.
func _pulsanti_lingua() -> Array:
	var gruppo := ButtonGroup.new()
	var out: Array = []
	for codice in GameManager.LINGUE:
		var c := str(codice)
		var b := _pulsante_scelta(c, gruppo, c == GameManager.lingua, 260)
		b.text = GameManager.nome_lingua(c)
		b.toggled.connect(_su_lingua.bind(c))
		_pulsanti[c] = b
		out.append(b)
	_righe.append({"pulsanti": _pulsanti, "attuale": func(): return GameManager.lingua})
	return out

# Quale lingua e' attiva si disegna A MANO, testo E cornice, invece di lasciarlo allo
# stato "premuto" del tema di base: quello scurisce appena il pulsante, e nello scatto
# di prova il pulsante scelto perdeva persino la cornice, sembrando testo qualunque
# accanto a uno vero. Tutte le varianti (premuto, sopra, fuoco) prendono lo stesso
# aspetto, o passarci il mouse cambierebbe il significato di quello che si vede.
func _aggiorna_selezione() -> void:
	var spente := GameManager.schermo_intero    # la risoluzione non conta a schermo intero
	for b in _pulsanti_ris.values():
		(b as Button).disabled = spente
	for riga in _righe:
		var scelto = riga["attuale"].call()
		for valore in riga["pulsanti"]:
			var b: Button = riga["pulsanti"][valore]
			var attiva: bool = valore == scelto
			b.set_pressed_no_signal(attiva)
			var col := Color(1.0, 1.0, 1.0) if attiva else Color(0.55, 0.55, 0.55)
			if b.disabled:
				col = Color(0.3, 0.3, 0.3)
			for voce in ["font_color", "font_pressed_color", "font_hover_color",
					"font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
				b.add_theme_color_override(voce, col)
			for voce in ["normal", "pressed", "hover", "focus", "disabled"]:
				b.add_theme_stylebox_override(voce, _cornice(attiva and not b.disabled))

# La cornice di un pulsante lingua: piena e chiara quella scelta, spenta le altre.
func _cornice(attiva: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.22, 0.22) if attiva else Color(0.07, 0.07, 0.07)
	sb.border_color = Color(0.95, 0.95, 0.95) if attiva else Color(0.3, 0.3, 0.3)
	sb.set_border_width_all(3 if attiva else 1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	return sb

func _stacco(altezza: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, altezza)
	return s

# ---------------- reazioni ----------------

func _su_schermo_intero(on: bool) -> void:
	GameManager.set_schermo_intero(on)

func _su_vsync(on: bool) -> void:
	GameManager.set_vsync(on)

func _su_lingua(premuto: bool, codice: String) -> void:
	if not premuto or codice == GameManager.lingua:
		return
	GameManager.set_lingua(codice)      # cambia E salva: qui e' una scelta di chi gioca
	_aggiorna_testi()
	_aggiorna_selezione()
	lingua_cambiata.emit()

# Le scritte di QUESTA schermata dopo un cambio di lingua. I nomi delle lingue no:
# sono endonimi e restano come sono.
func _aggiorna_testi() -> void:
	_titolo.text = tr("UI_OPTIONS_TITLE")
	for et in _etichette:
		(et as Label).text = tr(_etichette[et])
	for b in _testi_si_no:
		b.text = tr(str(b.get_meta("chiave")))
	for r in _pulsanti_ris:
		var ris: Vector2i = r
		(_pulsanti_ris[r] as Button).text = tr("UI_RESOLUTION_FMT") % [ris.x, ris.y]
	_indietro.text = tr("UI_BACK")
