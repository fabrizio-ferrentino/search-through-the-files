class_name DesktopItem
extends VBoxContainer

# Icona + etichetta selezionabile, usata sul desktop e dentro l'esplora risorse.
signal activated(data)        # doppio click / Invio
signal picked(item)           # singolo click (per la selezione singola del contenitore)
signal context_requested(item)  # tasto destro

var data: Dictionary = {}
var selected := false
var _icon: OSIcon
var _label: Label
var _label_color := Win95.C_TEXT

func setup(node_data: Dictionary, icon_size: int, label_w: int, label_color: Color) -> void:
	data = node_data
	custom_minimum_size = Vector2(label_w, icon_size + 40)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_icon = OSIcon.new()
	_icon.kind = node_data.get("icon", "file")
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_icon)

	_label = Label.new()
	_label.text = node_data.get("name", "")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 16)
	_label_color = label_color
	_label.add_theme_color_override("font_color", label_color)
	_label.custom_minimum_size = Vector2(label_w, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ridisegnare QUANDO l'etichetta si sistema: _draw() legge la sua posizione, che al
	# primo disegno non e' ancora stata calcolata dal contenitore. Su un file appena
	# creato -- che nasce gia' selezionato -- il riquadro blu finiva sopra l'icona e il
	# testo bianco spariva sul fondo chiaro (segnalato dal proprietario, 20/09/2026), e
	# li' restava, perche' niente chiedeva un altro disegno.
	_label.item_rect_changed.connect(queue_redraw)
	add_child(_label)

func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(self)
			if event.double_click:
				activated.emit(data)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			picked.emit(self)
			context_requested.emit(self)
			accept_event()

# Il riquadro della selezione: in Win95 abbracciava il TESTO, non tutta la casella. Se il
# nome sta su una riga si stringe attorno a lui; se va a capo si prende tutta la larghezza,
# che e' quanto occupa davvero.
func rett_selezione() -> Rect2:
	var r := _label.get_rect()
	var f := _label.get_theme_font("font")
	if f != null:
		var dim := _label.get_theme_font_size("font_size")
		var larga: float = f.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_CENTER,
				-1, dim).x + 6.0
		if larga < r.size.x:
			r.position.x += (r.size.x - larga) * 0.5
			r.size.x = larga
	return r

func _draw() -> void:
	if selected and _label:
		# evidenziazione blu dietro l'etichetta
		var lr := rett_selezione()
		draw_rect(lr, Win95.C_SELECT)
		_label.add_theme_color_override("font_color", Win95.C_TITLE_TEXT)
	elif _label:
		_label.add_theme_color_override("font_color", _label_color)
