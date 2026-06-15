class_name OSWindow
extends Control

# Finestra in stile Win95: cornice 3D, barra titolo trascinabile, pulsanti, area contenuto.
signal closed(win)
signal minimized(win)
signal title_changed(win)

const BORDER := 4
const TITLE_H := 30
const RESIZE_MARGIN := 8     # spessore del bordo "afferrabile" per ridimensionare
const RESIZE_CORNER := 24    # vicino agli angoli la zona di presa si allarga (resize diagonale)

# Lati toccati per il ridimensionamento (combinabili come flag).
enum { EDGE_L = 1, EDGE_R = 2, EDGE_T = 4, EDGE_B = 8 }

var os                      # riferimento al desktop (OSDesktop)
var win_title := "Finestra"
var icon_kind := "file"
var active := false

var content_root: Control   # qui le app aggiungono la loro UI
var _title_label: Label
var _icon: OSIcon
var _btn_min: GlyphButton
var _btn_max: GlyphButton
var _btn_close: GlyphButton

var _dragging := false
var _drag_off := Vector2.ZERO
var _maximized := false
var _restore_rect := Rect2()

var _resizing := false
var _resize_edges := 0
var _resize_start_mouse := Vector2.ZERO
var _resize_start_rect := Rect2()

func setup(title: String, win_size: Vector2, ikind: String) -> void:
	win_title = title
	icon_kind = ikind
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(220, 120)
	size = win_size
	clip_contents = true

	_icon = OSIcon.new()
	_icon.kind = ikind
	add_child(_icon)

	_title_label = Label.new()
	_title_label.text = title
	_title_label.add_theme_color_override("font_color", Win95.C_TITLE_TEXT)
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.clip_text = true
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	_btn_min = GlyphButton.new()
	_btn_min.glyph = "min"
	_btn_min.pressed.connect(_on_min)
	add_child(_btn_min)

	_btn_max = GlyphButton.new()
	_btn_max.glyph = "max"
	_btn_max.pressed.connect(toggle_max)
	add_child(_btn_max)

	_btn_close = GlyphButton.new()
	_btn_close.glyph = "close"
	_btn_close.pressed.connect(close)
	add_child(_btn_close)

	content_root = Control.new()
	content_root.clip_contents = true
	content_root.anchor_right = 1.0
	content_root.anchor_bottom = 1.0
	# inset = RESIZE_MARGIN: lascia scoperto un bordo abbastanza largo da afferrare
	# per il ridimensionamento (il contenuto non copre la zona di presa)
	content_root.offset_left = RESIZE_MARGIN
	content_root.offset_top = BORDER + TITLE_H
	content_root.offset_right = -RESIZE_MARGIN
	content_root.offset_bottom = -RESIZE_MARGIN
	add_child(content_root)

	_layout_titlebar()

func set_title(t: String) -> void:
	win_title = t
	if _title_label:
		_title_label.text = t
	title_changed.emit(self)

func set_active(v: bool) -> void:
	active = v
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_titlebar()

func _layout_titlebar() -> void:
	if not _btn_close:
		return
	var bs := Vector2(22, 20)
	var by := BORDER + (TITLE_H - bs.y) / 2.0
	var bx := size.x - BORDER - 3 - bs.x
	_btn_close.position = Vector2(bx, by)
	_btn_close.size = bs
	bx -= bs.x + 2
	_btn_max.position = Vector2(bx, by)
	_btn_max.size = bs
	bx -= bs.x
	_btn_min.position = Vector2(bx, by)
	_btn_min.size = bs

	_icon.position = Vector2(BORDER + 5, BORDER + (TITLE_H - 18) / 2.0)
	_icon.size = Vector2(18, 18)
	_title_label.position = Vector2(BORDER + 28, BORDER)
	_title_label.size = Vector2(max(0.0, bx - (BORDER + 30)), TITLE_H)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Win95.C_FACE)
	# barra titolo
	var tcol := Win95.C_TITLE if active else Win95.C_TITLE_OFF
	draw_rect(Rect2(BORDER, BORDER, size.x - 2 * BORDER, TITLE_H), tcol)
	Win95.bevel_rid(get_canvas_item(), r, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if event.pressed:
			# 1) bordo della finestra -> ridimensionamento (disattivo se ingrandita)
			var edges := 0 if _maximized else _edges_at(mb.position)
			if edges != 0:
				_resizing = true
				_resize_edges = edges
				_resize_start_mouse = get_global_mouse_position()
				_resize_start_rect = Rect2(position, size)
				accept_event()
				return
			# 2) barra titolo -> trascina (doppio click = ingrandisci/ripristina)
			var in_title: bool = mb.position.y >= BORDER and mb.position.y <= BORDER + TITLE_H \
				and mb.position.x > BORDER and mb.position.x < size.x - BORDER
			if in_title:
				if event.double_click:
					toggle_max()
				else:
					_dragging = true
					_drag_off = get_global_mouse_position() - global_position
				accept_event()
		else:
			_dragging = false
			_resizing = false
	elif event is InputEventMouseMotion:
		if _resizing:
			_apply_resize(get_global_mouse_position())
			accept_event()
		elif _dragging:
			var p := get_global_mouse_position() - _drag_off
			# tieni la barra titolo dentro lo schermo
			var screen: Vector2 = get_parent_control().size if get_parent_control() else size
			p.x = clamp(p.x, -size.x + 80, screen.x - 40)
			p.y = clamp(p.y, 0.0, screen.y - 36)
			global_position = p
			accept_event()

# --- Ridimensionamento in stile Win95: si "afferra" il bordo 3D della finestra ---

# Lati toccati dal punto (combinazione di EDGE_*). I bordi hanno spessore
# RESIZE_MARGIN; vicino agli angoli la zona si allarga (RESIZE_CORNER) per il
# trascinamento diagonale.
func _edges_at(pos: Vector2) -> int:
	var w := size.x
	var h := size.y
	var e := 0
	if pos.x <= RESIZE_MARGIN:
		e |= EDGE_L
	elif pos.x >= w - RESIZE_MARGIN:
		e |= EDGE_R
	if pos.y <= RESIZE_MARGIN:
		e |= EDGE_T
	elif pos.y >= h - RESIZE_MARGIN:
		e |= EDGE_B
	# se siamo gia' su un lato, estendi all'angolo piu' vicino
	if e != 0:
		if pos.x <= RESIZE_CORNER:
			e |= EDGE_L
		elif pos.x >= w - RESIZE_CORNER:
			e |= EDGE_R
		if pos.y <= RESIZE_CORNER:
			e |= EDGE_T
		elif pos.y >= h - RESIZE_CORNER:
			e |= EDGE_B
	return e

# Applica il ridimensionamento ancorando il lato opposto e rispettando la
# dimensione minima (custom_minimum_size).
func _apply_resize(gm: Vector2) -> void:
	var d := gm - _resize_start_mouse
	var r := _resize_start_rect
	var minw := custom_minimum_size.x
	var minh := custom_minimum_size.y
	var new_pos := r.position
	var new_size := r.size
	if _resize_edges & EDGE_L:
		new_size.x = maxf(minw, r.size.x - d.x)
		new_pos.x = r.position.x + r.size.x - new_size.x
	elif _resize_edges & EDGE_R:
		new_size.x = maxf(minw, r.size.x + d.x)
	if _resize_edges & EDGE_T:
		new_size.y = maxf(minh, r.size.y - d.y)
		new_pos.y = r.position.y + r.size.y - new_size.y
	elif _resize_edges & EDGE_B:
		new_size.y = maxf(minh, r.size.y + d.y)
	position = new_pos
	size = new_size

# Forma del cursore (Control.CursorShape) per la combinazione di lati data.
# La stanza la applica al ColorRect dell'overlay: _get_cursor_shape() non basta
# perche' non si propaga quando l'input e' inoltrato al SubViewport.
func _cursor_for_edges(e: int) -> int:
	var l := bool(e & EDGE_L)
	var r := bool(e & EDGE_R)
	var t := bool(e & EDGE_T)
	var b := bool(e & EDGE_B)
	if (t and l) or (b and r):
		return Control.CURSOR_FDIAGSIZE
	if (t and r) or (b and l):
		return Control.CURSOR_BDIAGSIZE
	if l or r:
		return Control.CURSOR_HSIZE
	if t or b:
		return Control.CURSOR_VSIZE
	return Control.CURSOR_ARROW

func is_resizing() -> bool:
	return _resizing

# Forma del cursore desiderata per un punto in coordinate locali alla finestra.
# La interroga la stanza per pilotare il cursore reale sull'overlay del PC.
func cursor_at(local_pos: Vector2) -> int:
	if _resizing:
		return _cursor_for_edges(_resize_edges)
	if _maximized:
		return Control.CURSOR_ARROW
	return _cursor_for_edges(_edges_at(local_pos))

func _on_min() -> void:
	minimized.emit(self)

func toggle_max() -> void:
	if _maximized:
		_maximized = false
		position = _restore_rect.position
		size = _restore_rect.size
	else:
		_maximized = true
		_restore_rect = Rect2(position, size)
		position = Vector2.ZERO
		# riempi lo schermo lasciando spazio alla taskbar
		var screen: Vector2 = get_parent_control().size if get_parent_control() else size
		size = Vector2(screen.x, screen.y - OSDesktop.TASKBAR_H)
	_layout_titlebar()

func close() -> void:
	closed.emit(self)
	queue_free()
