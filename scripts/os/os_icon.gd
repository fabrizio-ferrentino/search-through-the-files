class_name OSIcon
extends Control

# Icone disegnate via codice (placeholder "provvisori" ma riconoscibili).
@export var kind: String = "file"

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_kind(k: String) -> void:
	kind = k
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	match kind:
		"folder":
			_folder(w, h)
		"folder_open":
			_folder(w, h, true)
		"computer":
			_computer(w, h)
		"ie":
			_ie(w, h)
		"file", "text":
			_file(w, h)
		"notepad":
			_notepad(w, h)
		"trash":
			_trash(w, h)
		"win":
			_winflag(w, h)
		"globe":
			_ie(w, h)
		_:
			_file(w, h)

func _outline(r: Rect2, c: Color) -> void:
	draw_rect(r, c, false, 1.0)

func _folder(w: float, h: float, open := false) -> void:
	var tab := Rect2(w * 0.10, h * 0.24, w * 0.40, h * 0.14)
	draw_rect(tab, Color("c79a30"))
	var body := Rect2(w * 0.08, h * 0.32, w * 0.84, h * 0.48)
	draw_rect(body, Color("f2c84b") if not open else Color("ffe08a"))
	_outline(body, Color("80631a"))

func _computer(w: float, h: float) -> void:
	var mon := Rect2(w * 0.14, h * 0.12, w * 0.72, h * 0.52)
	draw_rect(mon, Color("c9c8b8"))
	_outline(mon, Color("5a5a50"))
	var scr := Rect2(w * 0.20, h * 0.18, w * 0.60, h * 0.38)
	draw_rect(scr, Color("0d6b6b"))
	var base := Rect2(w * 0.30, h * 0.64, w * 0.40, h * 0.10)
	draw_rect(base, Color("b6b5a6"))
	_outline(base, Color("5a5a50"))
	var kb := Rect2(w * 0.16, h * 0.78, w * 0.68, h * 0.12)
	draw_rect(kb, Color("d6d5c6"))
	_outline(kb, Color("5a5a50"))

func _ie(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.5)
	var r: float = min(w, h) * 0.34
	draw_circle(c, r, Color("cfe2ff"))
	draw_circle(c, r, Color("1a4fa0"), false, 2.0)
	var f := ThemeDB.fallback_font
	var fs := int(min(w, h) * 0.55)
	var ts := f.get_string_size("e", HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	draw_string(f, c + Vector2(-ts.x * 0.5, ts.y * 0.32), "e", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("12386f"))
	# anello giallo "in orbita"
	draw_arc(c, r * 1.05, deg_to_rad(20), deg_to_rad(200), 24, Color("efc63c"), 3.0)

func _file(w: float, h: float) -> void:
	var page := Rect2(w * 0.22, h * 0.12, w * 0.50, h * 0.76)
	draw_rect(page, Color("ffffff"))
	_outline(page, Color("404040"))
	# angolo piegato
	var fold := PackedVector2Array([
		Vector2(page.position.x + page.size.x, page.position.y),
		Vector2(page.position.x + page.size.x + w * 0.10, page.position.y + h * 0.14),
		Vector2(page.position.x + page.size.x, page.position.y + h * 0.14),
	])
	draw_colored_polygon(fold, Color("dddddd"))
	# righe di testo
	for i in range(4):
		var ly := page.position.y + h * (0.26 + i * 0.13)
		draw_line(Vector2(page.position.x + 3, ly), Vector2(page.position.x + page.size.x - 3, ly), Color("8a8a8a"), 1.0)

func _notepad(w: float, h: float) -> void:
	var page := Rect2(w * 0.20, h * 0.12, w * 0.58, h * 0.76)
	draw_rect(page, Color("ffffff"))
	_outline(page, Color("404040"))
	draw_rect(Rect2(page.position.x, page.position.y, page.size.x, h * 0.12), Color("1a4fa0"))
	for i in range(4):
		var ly := page.position.y + h * (0.34 + i * 0.13)
		draw_line(Vector2(page.position.x + 4, ly), Vector2(page.position.x + page.size.x - 4, ly), Color("9a9a9a"), 1.0)

func _trash(w: float, h: float) -> void:
	var lid := Rect2(w * 0.24, h * 0.20, w * 0.52, h * 0.08)
	draw_rect(lid, Color("9aa0a6"))
	_outline(lid, Color("4a4f54"))
	var can := PackedVector2Array([
		Vector2(w * 0.28, h * 0.30), Vector2(w * 0.72, h * 0.30),
		Vector2(w * 0.66, h * 0.84), Vector2(w * 0.34, h * 0.84),
	])
	draw_colored_polygon(can, Color("b6bcc2"))
	draw_polyline(can + PackedVector2Array([can[0]]), Color("4a4f54"), 1.0)

func _winflag(w: float, h: float) -> void:
	var s: float = min(w, h)
	var o := Vector2((w - s) * 0.5, (h - s) * 0.5)
	var c := s * 0.42
	var g := s * 0.06
	draw_rect(Rect2(o + Vector2(s * 0.08, s * 0.10), Vector2(c, c)), Color("d83b3b"))
	draw_rect(Rect2(o + Vector2(s * 0.08 + c + g, s * 0.10), Vector2(c, c)), Color("3fae4a"))
	draw_rect(Rect2(o + Vector2(s * 0.08, s * 0.10 + c + g), Vector2(c, c)), Color("2f7fd8"))
	draw_rect(Rect2(o + Vector2(s * 0.08 + c + g, s * 0.10 + c + g), Vector2(c, c)), Color("efc63c"))
