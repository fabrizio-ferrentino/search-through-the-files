class_name CreditsScreen
extends CanvasLayer

# Schermata RICONOSCIMENTI, aperta dalle Impostazioni (23/10/2026): chi ha fatto gli asset presi da
# fuori e con che licenza. Costruita in codice come OptionsScreen, con la stessa faccia.
# I modelli CC-BY (il quadro e i tre libri) DEVONO essere citati: e' la condizione della
# licenza. Gli altri (CC0, Sketchfab Standard, OFL) si citano per correttezza.
# Ogni riga e' una chiave di locale/ui.csv (CR_*); le fonti per esteso stanno nei
# CREDITS.md delle cartelle in assets/. Per aggiungere un asset: una chiave nel CSV e il
# suo nome in SEZIONI.

signal chiusa

# [titolo della sezione, [righe]]
const SEZIONI := [
	["CR_SEC_GAME", ["CR_GAME"]],
	["CR_SEC_MODELS", ["CR_M_HOUSEHOLD", "CR_M_COMPUTER", "CR_M_QUATERNIUS",
		"CR_M_OPART", "CR_M_BOOKSTACK", "CR_M_BOOKS1", "CR_M_BOOKS2"]],
	["CR_SEC_FONTS", ["CR_FONTS", "CR_FONTS_COMIC"]],
	["CR_SEC_ENGINE", ["CR_ENGINE", "CR_ENGINE_COPY"]],
]

func _ready() -> void:
	_costruisci()   # layer: lo fissa chi la apre (le Impostazioni, una sopra di se')

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):   # ESC: come il pulsante Indietro
		get_viewport().set_input_as_handled()
		chiudi()

func chiudi() -> void:
	chiusa.emit()
	queue_free()

func _costruisci() -> void:
	var radice := Control.new()
	radice.name = "Radice"
	radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.mouse_filter = Control.MOUSE_FILTER_STOP   # nessun clic ai pulsanti del menu sotto
	add_child(radice)

	var sfondo := ColorRect.new()
	sfondo.color = Color.BLACK
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.add_child(sfondo)

	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vb.offset_top = 60
	vb.offset_bottom = -60
	vb.add_theme_constant_override("separation", 30)
	radice.add_child(vb)

	var titolo := Label.new()
	titolo.name = "Titolo"
	titolo.text = tr("UI_CREDITS_TITLE")
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titolo.add_theme_font_size_override("font_size", 80)
	titolo.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vb.add_child(titolo)

	# l'elenco scorre (rotella) se non sta nello schermo
	var scorri := ScrollContainer.new()
	scorri.name = "Elenco"
	scorri.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scorri)
	var elenco := VBoxContainer.new()
	elenco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elenco.add_theme_constant_override("separation", 10)
	scorri.add_child(elenco)

	for sezione in SEZIONI:
		var testa := _testo(tr(str(sezione[0])), 46, Color(1, 1, 1))
		testa.custom_minimum_size = Vector2(0, 80)
		testa.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		elenco.add_child(testa)
		for chiave in sezione[1]:
			elenco.add_child(_testo(tr(str(chiave)), 32, Color(0.7, 0.7, 0.7)))

	var indietro := Button.new()
	indietro.name = "Indietro"
	indietro.text = tr("UI_BACK")
	indietro.custom_minimum_size = Vector2(360, 96)
	indietro.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	indietro.add_theme_font_size_override("font_size", 44)
	indietro.pressed.connect(chiudi)
	vb.add_child(indietro)

func _testo(t: String, dimensione: int, colore: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", dimensione)
	l.add_theme_color_override("font_color", colore)
	return l
