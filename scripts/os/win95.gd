class_name Win95
extends RefCounted

# Palette e helper grafici condivisi per il look retro' anni '90.

const C_DESKTOP := Color("008080")   # teal del desktop
const C_FACE := Color("c0c0c0")      # grigio delle superfici
const C_LIGHT := Color("ffffff")     # luce esterna del bordo 3D
const C_HILIGHT := Color("dfdfdf")   # luce interna
const C_SHADOW := Color("808080")    # ombra interna
const C_DARK := Color("000000")      # ombra esterna
const C_TITLE := Color("000080")     # barra titolo attiva (blu navy)
const C_TITLE_OFF := Color("7f7f7f") # barra titolo inattiva
const C_TITLE_TEXT := Color("ffffff")
const C_TEXT := Color("000000")
const C_SELECT := Color("000080")
const C_LINK := Color("0000ee")

# Disegna un bordo 3D in stile Win95 (rilevato o incassato) sul canvas item dato.
static func bevel_rid(ci: RID, rect: Rect2, raised: bool, double: bool = true) -> void:
	var x := rect.position.x
	var y := rect.position.y
	var w := rect.size.x
	var h := rect.size.y
	var tl_o := C_LIGHT if raised else C_DARK
	var br_o := C_DARK if raised else C_LIGHT
	RenderingServer.canvas_item_add_rect(ci, Rect2(x, y, w, 1.0), tl_o)
	RenderingServer.canvas_item_add_rect(ci, Rect2(x, y, 1.0, h), tl_o)
	RenderingServer.canvas_item_add_rect(ci, Rect2(x, y + h - 1.0, w, 1.0), br_o)
	RenderingServer.canvas_item_add_rect(ci, Rect2(x + w - 1.0, y, 1.0, h), br_o)
	if double:
		var tl_i := C_HILIGHT if raised else C_SHADOW
		var br_i := C_SHADOW if raised else C_HILIGHT
		RenderingServer.canvas_item_add_rect(ci, Rect2(x + 1.0, y + 1.0, w - 2.0, 1.0), tl_i)
		RenderingServer.canvas_item_add_rect(ci, Rect2(x + 1.0, y + 1.0, 1.0, h - 2.0), tl_i)
		RenderingServer.canvas_item_add_rect(ci, Rect2(x + 1.0, y + h - 2.0, w - 2.0, 1.0), br_i)
		RenderingServer.canvas_item_add_rect(ci, Rect2(x + w - 2.0, y + 1.0, 1.0, h - 2.0), br_i)

# Larghezza adatta per un menu, in base alla voce di testo piu' lunga.
static func menu_width(labels: Array, min_w := 120.0) -> float:
	var f := ThemeDB.fallback_font
	var w := min_w
	for s in labels:
		w = max(w, f.get_string_size(str(s), HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 38.0)
	return w

static func _sb(raised: bool, bg: Color, double: bool, ml: int, mt: int, mr: int, mb: int) -> StyleBoxWin95:
	var s := StyleBoxWin95.new()
	s.raised = raised
	s.bg = bg
	s.double = double
	s.set_content_margin(SIDE_LEFT, ml)
	s.set_content_margin(SIDE_TOP, mt)
	s.set_content_margin(SIDE_RIGHT, mr)
	s.set_content_margin(SIDE_BOTTOM, mb)
	return s

# Tema globale applicato alla radice dell'OS: i figli ereditano.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = ThemeDB.fallback_font
	t.default_font_size = 18

	# Button (rilevato; premuto = incassato)
	t.set_stylebox("normal", "Button", _sb(true, C_FACE, true, 10, 5, 10, 5))
	t.set_stylebox("hover", "Button", _sb(true, C_FACE, true, 10, 5, 10, 5))
	t.set_stylebox("pressed", "Button", _sb(false, C_FACE, true, 11, 6, 9, 4))
	t.set_stylebox("disabled", "Button", _sb(true, C_FACE, true, 10, 5, 10, 5))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", C_TEXT)
	t.set_color("font_hover_color", "Button", C_TEXT)
	t.set_color("font_pressed_color", "Button", C_TEXT)
	t.set_color("font_focus_color", "Button", C_TEXT)
	t.set_color("font_disabled_color", "Button", C_SHADOW)

	# LineEdit (campo incassato bianco)
	var field := _sb(false, C_LIGHT, true, 6, 4, 6, 4)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field)
	t.set_color("font_color", "LineEdit", C_TEXT)
	t.set_color("caret_color", "LineEdit", C_TEXT)
	t.set_color("font_selected_color", "LineEdit", C_TITLE_TEXT)
	t.set_color("selection_color", "LineEdit", C_SELECT)

	# TextEdit (notepad / inspector)
	var tfield := _sb(false, C_LIGHT, true, 6, 4, 6, 4)
	t.set_stylebox("normal", "TextEdit", tfield)
	t.set_stylebox("focus", "TextEdit", tfield)
	t.set_color("font_color", "TextEdit", C_TEXT)
	# in sola lettura (inspector) Godot usa font_readonly_color: senza questo resta grigio
	t.set_color("font_readonly_color", "TextEdit", C_TEXT)
	t.set_color("caret_color", "TextEdit", C_TEXT)
	t.set_color("font_selected_color", "TextEdit", C_TITLE_TEXT)
	t.set_color("selection_color", "TextEdit", C_SELECT)
	t.set_color("background_color", "TextEdit", C_LIGHT)

	# Panel
	t.set_stylebox("panel", "Panel", _sb(true, C_FACE, true, 0, 0, 0, 0))

	# PopupMenu (menu contestuale)
	t.set_stylebox("panel", "PopupMenu", _sb(true, C_FACE, true, 2, 2, 2, 2))
	t.set_stylebox("hover", "PopupMenu", _sb(false, C_SELECT, false, 0, 0, 0, 0))
	t.set_color("font_color", "PopupMenu", C_TEXT)
	t.set_color("font_hover_color", "PopupMenu", C_TITLE_TEXT)
	t.set_color("font_separator_color", "PopupMenu", C_SHADOW)

	# Label / ScrollContainer
	t.set_color("font_color", "Label", C_TEXT)
	return t
