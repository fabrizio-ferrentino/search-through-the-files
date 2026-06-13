class_name OSWindow
extends Control

# Finestra in stile Win95: cornice 3D, barra titolo trascinabile, pulsanti, area contenuto.
signal closed(win)
signal minimized(win)
signal title_changed(win)

const BORDER := 4
const TITLE_H := 30

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
	content_root.offset_left = BORDER
	content_root.offset_top = BORDER + TITLE_H
	content_root.offset_right = -BORDER
	content_root.offset_bottom = -BORDER
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
		var in_title: bool = mb.position.y >= BORDER and mb.position.y <= BORDER + TITLE_H \
			and mb.position.x > BORDER and mb.position.x < size.x - BORDER
		if event.pressed and in_title:
			if event.double_click:
				toggle_max()
			else:
				_dragging = true
				_drag_off = get_global_mouse_position() - global_position
			accept_event()
		elif not event.pressed:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var p := get_global_mouse_position() - _drag_off
		# tieni la barra titolo dentro lo schermo
		var screen: Vector2 = get_parent_control().size if get_parent_control() else size
		p.x = clamp(p.x, -size.x + 80, screen.x - 40)
		p.y = clamp(p.y, 0.0, screen.y - 36)
		global_position = p
		accept_event()

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
