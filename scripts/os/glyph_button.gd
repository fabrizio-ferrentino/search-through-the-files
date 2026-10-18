class_name GlyphButton
extends Control

# Pulsantino della barra del titolo: bordo 3D + glifo disegnato (minimizza/ingrandisci/chiudi).
signal pressed

@export var glyph: String = "close"  # "min" | "max" | "close"
var _down := false
# Disattivato: glifo grigio in rilievo (come i pulsanti spenti di Win95) e i clic non fanno
# niente. Lo usa il "riduci" delle finestre YouAreStupid (OSWindow.blocca_in_cima).
var disabilitato := false:
	set(v):
		disabilitato = v
		_down = false
		queue_redraw()

func _init() -> void:
	custom_minimum_size = Vector2(22, 20)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if disabilitato:
			accept_event()       # il clic si ferma qui: non passa alla barra del titolo
			return
		if event.pressed:
			_down = true
			queue_redraw()
		else:
			if _down and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
			_down = false
			queue_redraw()
		accept_event()

# Il pulsante e' tenuto premuto adesso? (OSWindow.occupata: una finestra che si muove da
# sola deve fermarsi, o il rilascio cade fuori dal pulsante e il clic va perso)
func premuto() -> bool:
	return _down

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Win95.C_FACE)
	Win95.bevel_rid(get_canvas_item(), r, not _down)
	var o := Vector2(1, 1) if _down else Vector2.ZERO
	var c := size * 0.5 + o
	var col := Win95.C_TEXT
	if disabilitato:
		# il glifo spento di Win95: grigio scuro con un'ombra bianca un pixel sotto a destra
		var ombra := Color.WHITE
		col = Win95.C_SHADOW
		if glyph == "min":
			draw_rect(Rect2(c.x - 4, size.y - 5, 8, 2), ombra)
	match glyph:
		"min":
			draw_rect(Rect2(c.x - 5, size.y - 6 + o.y, 8, 2), col)
		"max":
			var br := Rect2(c.x - 6, c.y - 6, 12, 11).position + o
			draw_rect(Rect2(br, Vector2(12, 11)), col, false, 1.0)
			draw_rect(Rect2(br, Vector2(12, 2.5)), col)
		"close":
			for d in [Vector2(-4, -4), Vector2(-4, 4)]:
				draw_line(c + d, c - d, col, 1.6)
