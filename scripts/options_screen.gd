class_name OptionsScreen
extends CanvasLayer

# Schermata OPZIONI del menu principale. Costruita in CODICE come le altre
# sovrimpressioni del gioco (pause_screen.gd, death_screen.gd) e non nella scena del
# menu: quella scena e' del proprietario, e il menu si limita ad aprire questa.
#
# Dentro c'e' UNA sola impostazione, la LINGUA (richiesta del proprietario, 19/09/2026).
# Il resto (volume, sensibilita') arrivera' con M6: la schermata e' fatta per crescere --
# _riga() aggiunge una riga "etichetta + comandi" e basta.
#
# Perche' la lingua si cambia SOLO dal menu: il testo DENTRO il gioco (nomi dei file,
# contenuto dei file, pagine web) viene generato quando parte il run, percio' cambiarla a
# meta' partita non riscriverebbe il PC. Dal menu la scelta arriva prima dello "Start" e
# vale per tutto il run che segue.

# La lingua e' cambiata: chi ha aperto la schermata (il menu) deve rifare le sue scritte,
# che erano state assegnate con tr() quando era la lingua di prima.
signal lingua_cambiata
signal chiusa

var _gruppo := ButtonGroup.new()     # una lingua sola per volta, e si vede quale
var _pulsanti: Dictionary = {}       # codice lingua -> Button
var _titolo: Label
var _etichetta_lingua: Label
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

	_etichetta_lingua = Label.new()
	_etichetta_lingua.name = "EtichettaLingua"
	_etichetta_lingua.add_theme_font_size_override("font_size", 44)
	_etichetta_lingua.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	vb.add_child(_riga(_etichetta_lingua, _pulsanti_lingua()))

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

# Una riga di impostazione: etichetta a sinistra, comandi a destra, il tutto centrato.
func _riga(etichetta: Control, comandi: Array) -> HBoxContainer:
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 28)
	hb.add_child(etichetta)
	for c in comandi:
		hb.add_child(c)
	return hb

# Un pulsante per lingua. Il NOME del nodo e' il codice della lingua (identificatore:
# i test lo cercano e non deve dipendere dalla lingua in corso), il TESTO e' l'endonimo
# -- "Italiano", non "Italian": in un elenco di lingue ognuna si scrive nella propria,
# o chi cerca la sua non la riconosce.
func _pulsanti_lingua() -> Array:
	var out: Array = []
	for codice in GameManager.LINGUE:
		var c := str(codice)
		var b := Button.new()
		b.name = c
		b.text = GameManager.nome_lingua(c)
		b.toggle_mode = true
		b.button_group = _gruppo
		b.button_pressed = (c == GameManager.lingua)
		b.custom_minimum_size = Vector2(260, 96)
		b.add_theme_font_size_override("font_size", 40)
		b.toggled.connect(_su_lingua.bind(c))
		_pulsanti[c] = b
		out.append(b)
	return out

# Quale lingua e' attiva si disegna A MANO, testo E cornice, invece di lasciarlo allo
# stato "premuto" del tema di base: quello scurisce appena il pulsante, e nello scatto
# di prova il pulsante scelto perdeva persino la cornice, sembrando testo qualunque
# accanto a uno vero. Tutte le varianti (premuto, sopra, fuoco) prendono lo stesso
# aspetto, o passarci il mouse cambierebbe il significato di quello che si vede.
func _aggiorna_selezione() -> void:
	for codice in _pulsanti:
		var b: Button = _pulsanti[codice]
		var attiva := str(codice) == GameManager.lingua
		var col := Color(1.0, 1.0, 1.0) if attiva else Color(0.55, 0.55, 0.55)
		for voce in ["font_color", "font_pressed_color", "font_hover_color",
				"font_hover_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(voce, col)
		for voce in ["normal", "pressed", "hover", "focus"]:
			b.add_theme_stylebox_override(voce, _cornice(attiva))

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
	_etichetta_lingua.text = tr("UI_LANGUAGE")
	_indietro.text = tr("UI_BACK")
