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
		"locked":
			_locked(w, h)
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
		"trash_full":
			_trash(w, h, true)
		"win":
			_winflag(w, h)
		"globe":
			_ie(w, h)
		"back":
			_arrow_left(w, h)
		"up":
			_up(w, h)
		"cut":
			_cut(w, h)
		"copy":
			_copy(w, h)
		"paste":
			_paste(w, h)
		"delete":
			_delete(w, h)
		"props":
			_props(w, h)
		"views":
			_views(w, h)
		"dropdown":
			_dropdown(w, h)
		"fwd":
			_arrow_right(w, h)
		"stop":
			_stop(w, h)
		"refresh":
			_refresh(w, h)
		"home":
			_home(w, h)
		"star":
			_star(w, h)
		"print":
			_print(w, h)
		"search":
			_search(w, h)
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

func _locked(w: float, h: float) -> void:
	# cartella con un lucchetto sopra (nodo "secret")
	_folder(w, h)
	var body := Rect2(w * 0.40, h * 0.50, w * 0.34, h * 0.30)
	var c := Vector2(body.position.x + body.size.x * 0.5, body.position.y)
	# staffa del lucchetto
	draw_arc(c, w * 0.11, deg_to_rad(180.0), deg_to_rad(360.0), 16, Color("3a3a3a"), 3.0)
	# corpo
	draw_rect(body, Color("e0c020"))
	_outline(body, Color("6a5600"))
	# buco della chiave
	draw_circle(body.position + body.size * Vector2(0.5, 0.45), w * 0.035, Color("3a3a3a"))

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

func _trash(w: float, h: float, full := false) -> void:
	# carta accartocciata che sporge quando il cestino e' pieno (disegnata prima del bidone)
	if full:
		for p in [Vector2(w * 0.36, h * 0.16), Vector2(w * 0.58, h * 0.12), Vector2(w * 0.48, h * 0.20)]:
			draw_circle(p, w * 0.07, Color("eef0f2"))
			draw_arc(p, w * 0.07, 0, TAU, 12, Color("9aa0a6"), 1.0)
	var lid := Rect2(w * 0.24, h * 0.20, w * 0.52, h * 0.08)
	draw_rect(lid, Color("9aa0a6"))
	_outline(lid, Color("4a4f54"))
	var can := PackedVector2Array([
		Vector2(w * 0.28, h * 0.30), Vector2(w * 0.72, h * 0.30),
		Vector2(w * 0.66, h * 0.84), Vector2(w * 0.34, h * 0.84),
	])
	draw_colored_polygon(can, Color("b6bcc2"))
	draw_polyline(can + PackedVector2Array([can[0]]), Color("4a4f54"), 1.0)

func _arrow_left(w: float, h: float) -> void:
	var cy := h * 0.5
	var col := Color("123a7a")
	draw_rect(Rect2(w * 0.42, cy - h * 0.09, w * 0.32, h * 0.18), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.20, cy), Vector2(w * 0.46, cy - h * 0.24), Vector2(w * 0.46, cy + h * 0.24),
	]), col)

func _up(w: float, h: float) -> void:
	draw_rect(Rect2(w * 0.14, h * 0.44, w * 0.30, h * 0.10), Color("c79a30"))
	var body := Rect2(w * 0.12, h * 0.52, w * 0.74, h * 0.34)
	draw_rect(body, Color("f2c84b"))
	_outline(body, Color("80631a"))
	var ax := w * 0.49
	draw_colored_polygon(PackedVector2Array([
		Vector2(ax, h * 0.12), Vector2(ax - w * 0.20, h * 0.40), Vector2(ax + w * 0.20, h * 0.40),
	]), Color("1a431f"))
	draw_rect(Rect2(ax - w * 0.07, h * 0.36, w * 0.14, h * 0.22), Color("1a431f"))

func _cut(w: float, h: float) -> void:
	var c1 := Vector2(w * 0.34, h * 0.70)
	var c2 := Vector2(w * 0.62, h * 0.70)
	draw_line(c1, Vector2(w * 0.74, h * 0.20), Color("808080"), 2.0)
	draw_line(c2, Vector2(w * 0.26, h * 0.20), Color("808080"), 2.0)
	draw_arc(c1, w * 0.10, 0, TAU, 14, Color("404040"), 2.0)
	draw_arc(c2, w * 0.10, 0, TAU, 14, Color("404040"), 2.0)

func _copy(w: float, h: float) -> void:
	var b := Rect2(w * 0.20, h * 0.16, w * 0.40, h * 0.52)
	draw_rect(b, Color.WHITE)
	_outline(b, Color("404040"))
	var f := Rect2(w * 0.36, h * 0.30, w * 0.40, h * 0.52)
	draw_rect(f, Color.WHITE)
	_outline(f, Color("404040"))
	for i in range(3):
		var ly := f.position.y + h * (0.12 + i * 0.12)
		draw_line(Vector2(f.position.x + 3, ly), Vector2(f.position.x + f.size.x - 4, ly), Color("8a8a8a"), 1.0)

func _paste(w: float, h: float) -> void:
	var board := Rect2(w * 0.20, h * 0.20, w * 0.58, h * 0.64)
	draw_rect(board, Color("b58a4a"))
	_outline(board, Color("5a3f1a"))
	draw_rect(Rect2(w * 0.40, h * 0.13, w * 0.18, h * 0.10), Color("9a9a9a"))
	var page := Rect2(w * 0.28, h * 0.30, w * 0.42, h * 0.46)
	draw_rect(page, Color.WHITE)
	_outline(page, Color("707070"))
	for i in range(2):
		var ly := page.position.y + h * (0.12 + i * 0.13)
		draw_line(Vector2(page.position.x + 3, ly), Vector2(page.position.x + page.size.x - 4, ly), Color("9a9a9a"), 1.0)

func _delete(w: float, h: float) -> void:
	var col := Color("c0241c")
	draw_line(Vector2(w * 0.28, h * 0.28), Vector2(w * 0.72, h * 0.72), col, 3.0)
	draw_line(Vector2(w * 0.72, h * 0.28), Vector2(w * 0.28, h * 0.72), col, 3.0)

func _props(w: float, h: float) -> void:
	var page := Rect2(w * 0.24, h * 0.14, w * 0.46, h * 0.72)
	draw_rect(page, Color.WHITE)
	_outline(page, Color("404040"))
	for i in range(3):
		var ly := page.position.y + h * (0.12 + i * 0.13)
		draw_line(Vector2(page.position.x + 4, ly), Vector2(page.position.x + page.size.x - 5, ly), Color("8a8a8a"), 1.0)
	draw_line(Vector2(w * 0.50, h * 0.62), Vector2(w * 0.60, h * 0.74), Color("1c8a2a"), 2.5)
	draw_line(Vector2(w * 0.60, h * 0.74), Vector2(w * 0.80, h * 0.44), Color("1c8a2a"), 2.5)

func _views(w: float, h: float) -> void:
	var col := Color("103a7a")
	var s := w * 0.30
	draw_rect(Rect2(w * 0.16, h * 0.16, s, s), col)
	draw_rect(Rect2(w * 0.54, h * 0.16, s, s), col)
	draw_rect(Rect2(w * 0.16, h * 0.54, s, s), col)
	draw_rect(Rect2(w * 0.54, h * 0.54, s, s), col)

func _dropdown(w: float, h: float) -> void:
	var cx := w * 0.5
	var cy := h * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - w * 0.22, cy - h * 0.10), Vector2(cx + w * 0.22, cy - h * 0.10), Vector2(cx, cy + h * 0.16),
	]), Color.BLACK)

func _arrow_right(w: float, h: float) -> void:
	var cy := h * 0.5
	var col := Color("123a7a")
	draw_rect(Rect2(w * 0.26, cy - h * 0.09, w * 0.32, h * 0.18), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.80, cy), Vector2(w * 0.54, cy - h * 0.24), Vector2(w * 0.54, cy + h * 0.24),
	]), col)

func _stop(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.5)
	var r: float = min(w, h) * 0.36
	draw_circle(c, r, Color("c0241c"))
	draw_line(c + Vector2(-r * 0.5, -r * 0.5), c + Vector2(r * 0.5, r * 0.5), Color.WHITE, 2.0)
	draw_line(c + Vector2(r * 0.5, -r * 0.5), c + Vector2(-r * 0.5, r * 0.5), Color.WHITE, 2.0)

func _refresh(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.52)
	var r: float = min(w, h) * 0.32
	var col := Color("1c7a2a")
	var a1 := deg_to_rad(210.0)
	draw_arc(c, r, deg_to_rad(-50.0), a1, 24, col, 2.5)
	var head := c + Vector2(cos(a1), sin(a1)) * r
	draw_colored_polygon(PackedVector2Array([
		head + Vector2(-w * 0.12, -h * 0.02),
		head + Vector2(w * 0.02, -h * 0.15),
		head + Vector2(w * 0.07, h * 0.04),
	]), col)

func _home(w: float, h: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.5, h * 0.14), Vector2(w * 0.86, h * 0.50), Vector2(w * 0.14, h * 0.50),
	]), Color("8a2f2f"))
	var body := Rect2(w * 0.26, h * 0.48, w * 0.48, h * 0.36)
	draw_rect(body, Color("d9c39a"))
	_outline(body, Color("5a4a30"))
	draw_rect(Rect2(w * 0.44, h * 0.62, w * 0.15, h * 0.22), Color("6a4a2a"))

func _star(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.52)
	var rad_out: float = min(w, h) * 0.40
	var rad_in := rad_out * 0.45
	var pts := PackedVector2Array()
	for i in range(10):
		var ang := deg_to_rad(-90.0 + i * 36.0)
		var rr := rad_out if i % 2 == 0 else rad_in
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, Color("efc63c"))

func _print(w: float, h: float) -> void:
	var paper := Rect2(w * 0.26, h * 0.14, w * 0.48, h * 0.24)
	draw_rect(paper, Color.WHITE)
	_outline(paper, Color("707070"))
	var body := Rect2(w * 0.16, h * 0.38, w * 0.68, h * 0.30)
	draw_rect(body, Color("9aa0a6"))
	_outline(body, Color("4a4f54"))
	draw_rect(Rect2(w * 0.72, h * 0.46, w * 0.06, h * 0.06), Color("2fae4a"))
	var out := Rect2(w * 0.30, h * 0.60, w * 0.40, h * 0.22)
	draw_rect(out, Color.WHITE)
	_outline(out, Color("707070"))

func _search(w: float, h: float) -> void:
	var c := Vector2(w * 0.44, h * 0.42)
	var r: float = min(w, h) * 0.24
	var col := Color("123a7a")
	draw_arc(c, r, 0, TAU, 18, col, 2.5)
	draw_line(c + Vector2(r * 0.7, r * 0.7), Vector2(w * 0.82, h * 0.82), col, 3.0)

func _winflag(w: float, h: float) -> void:
	var s: float = min(w, h)
	var o := Vector2((w - s) * 0.5, (h - s) * 0.5)
	var c := s * 0.42
	var g := s * 0.06
	draw_rect(Rect2(o + Vector2(s * 0.08, s * 0.10), Vector2(c, c)), Color("d83b3b"))
	draw_rect(Rect2(o + Vector2(s * 0.08 + c + g, s * 0.10), Vector2(c, c)), Color("3fae4a"))
	draw_rect(Rect2(o + Vector2(s * 0.08, s * 0.10 + c + g), Vector2(c, c)), Color("2f7fd8"))
	draw_rect(Rect2(o + Vector2(s * 0.08 + c + g, s * 0.10 + c + g), Vector2(c, c)), Color("efc63c"))
