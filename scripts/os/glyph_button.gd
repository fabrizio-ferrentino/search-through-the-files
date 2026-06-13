class_name GlyphButton
extends Control

# Pulsantino della barra del titolo: bordo 3D + glifo disegnato (minimizza/ingrandisci/chiudi).
signal pressed

@export var glyph: String = "close"  # "min" | "max" | "close"
var _down := false

func _init() -> void:
	custom_minimum_size = Vector2(22, 20)
	mouse_filter = Control.MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			queue_redraw()
		else:
			if _down and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
			_down = false
			queue_redraw()
		accept_event()

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Win95.C_FACE)
	Win95.bevel_rid(get_canvas_item(), r, not _down)
	var o := Vector2(1, 1) if _down else Vector2.ZERO
	var c := size * 0.5 + o
	var col := Win95.C_TEXT
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
