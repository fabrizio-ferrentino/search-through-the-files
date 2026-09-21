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

# --- font d'epoca (assets/fonts/, licenza SIL OFL 1.1) ---
# Arimo = clone metrico di Arial (il sans del web anni '90 e della UI Win95),
# Cousine = clone metrico di Courier New (le pagine con face="Courier New").
# Sono gli stessi font per la UI dell'OS e per le pagine del browser: cosi' il
# finto sistema e il finto web hanno lo stesso sapore d'epoca.
const FONT_DIR := "res://assets/fonts/"
const _FONT_FILES := {
	"sans": "Arimo-Regular.ttf",
	"sans_b": "Arimo-Bold.ttf",
	"sans_i": "Arimo-Italic.ttf",
	"sans_bi": "Arimo-BoldItalic.ttf",
	"mono": "Cousine-Regular.ttf",
	"mono_b": "Cousine-Bold.ttf",
}
static var _fonts: Dictionary = {}

# Font condiviso per nome (vedi _FONT_FILES). Se il file non c'e' si ripiega sul
# font di sistema, cosi' il gioco parte comunque.
static func font(nome := "sans") -> Font:
	if _fonts.has(nome):
		return _fonts[nome]
	var f: Font = ThemeDB.fallback_font
	var path: String = FONT_DIR + str(_FONT_FILES.get(nome, ""))
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is Font:
			f = res
	_fonts[nome] = f
	return f

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
	var f := font()
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
# ---------------- pezzi di CORNICE condivisi ----------------
# Stanno qui, e non dentro un'app, perche' la cornice dev'essere la STESSA dappertutto:
# il browser e l'Esplora risorse costruiscono le loro barre con queste funzioni, cosi' un
# pulsante spento si riconosce allo stesso modo in tutte e due (regola 7 del CLAUDE.md).

# Altezza delle strisce. MENUBAR_H tiene conto dell'altezza vera di un pulsante di menu
# (31 px col tema e il font di qui) piu' i 2+2 di margine: piu' bassa, le voci sbordano
# sulla barra sotto e le due barre sembrano schiacciate l'una sull'altra. Era il difetto
# dell'Esplora risorse, che ne aveva 26 (segnalato dal proprietario, 20/09/2026).
const MENUBAR_H := 35
const ADDRBAR_H := 36
const TB_ICONA := 24
const TB_CAPTION := 14        # la didascalia e' piu' piccola del testo dei menu, come allora
const TB_ALTA := 54

# Un pulsante della barra strumenti: icona sopra, nome sotto. Il contenuto sta in un VBox
# FIGLIO (un Button non impagina i figli da solo), che e' anche comodo per lo stato
# disabilitato: sbiadendo il VBox si spengono insieme icona e nome. La larghezza la decide
# il NOME misurato col font vero, perche' a larghezza fissa le didascalie lunghe si
# tagliavano. Le didascalie ci sono perche' il viewport dell'OS viene ridotto a ~2/3 e
# passa dal CRT: le sole icone, a quella scala, non si leggono.
static func tool_button(kind: String, testo := "", cb := Callable(), attivo := true) -> Button:
	var b := Button.new()
	var larga: float = 40.0
	if testo != "":
		larga = maxf(larga, font("sans").get_string_size(
				testo, HORIZONTAL_ALIGNMENT_LEFT, -1, TB_CAPTION).x + 12.0)
	b.custom_minimum_size = Vector2(larga, TB_ALTA)
	b.focus_mode = Control.FOCUS_NONE
	var box := VBoxContainer.new()
	box.name = "Contenuto"
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 3
	box.offset_bottom = -2
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)
	b.add_child(box)
	var ic := OSIcon.new()
	ic.kind = kind
	ic.custom_minimum_size = Vector2(TB_ICONA, TB_ICONA)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(ic)
	if testo != "":
		var lb := Label.new()
		lb.text = testo
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lb.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lb.add_theme_font_size_override("font_size", TB_CAPTION)
		lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lb)
	if cb.is_valid():
		b.pressed.connect(cb)
	if not attivo:
		b.disabled = true
	fade(b, not attivo)
	return b

# Sbiadisce (o riaccende) il contenuto di un pulsante, per accompagnare lo stato
# disabilitato. Serve perche' il tema colora di grigio solo il testo DEL BUTTON, e qui
# icona e didascalia sono nodi figli: a colori pieni un pulsante spento sembra attivo.
static func fade(b: Button, spento: bool) -> void:
	if b == null:
		return
	var box := b.get_node_or_null("Contenuto") as Control
	if box != null:
		box.modulate = Color(1, 1, 1, 0.38) if spento else Color(1, 1, 1, 1)

# Una striscia in rilievo che attraversa la finestra: e' il contenitore delle barre in
# Win95, e senza di lei i pulsanti sembrano appoggiati sul niente.
static func strip(parent: Control, alta: int) -> Panel:
	var p := Panel.new()
	p.add_theme_stylebox_override("panel", _sb(true, C_FACE, false, 0, 0, 0, 0))
	p.custom_minimum_size = Vector2(0, alta)
	parent.add_child(p)
	return p

# La "maniglia" a due righe verticali all'inizio della barra: nei programmi dell'epoca
# diceva che la barra si poteva staccare e trascinare. Qui non si stacca (non serve), ma
# senza di lei la barra non si riconosce.
static func grip() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(9, 0)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		var h: float = c.size.y
		for i in range(2):
			var x: float = 2.0 + float(i) * 4.0
			c.draw_line(Vector2(x, 2.0), Vector2(x, h - 2.0), C_LIGHT, 1.0)
			c.draw_line(Vector2(x + 1.0, 2.0), Vector2(x + 1.0, h - 2.0), C_SHADOW, 1.0))
	return c

# La riga incisa che separa i gruppi dentro una tendina.
static func menu_separator() -> Control:
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(0, 7)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.draw.connect(func():
		var y: float = 3.0
		sep.draw_line(Vector2(2, y), Vector2(sep.size.x - 2, y), C_SHADOW, 1.0)
		sep.draw_line(Vector2(2, y + 1), Vector2(sep.size.x - 2, y + 1), C_LIGHT, 1.0))
	return sep

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = font()
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

	# BARRE DI SCORRIMENTO. Non erano tematizzate affatto (18/09/2026): su una pagina lunga,
	# in Blocco note e nel "visualizza sorgente" compariva la barra scura e arrotondata di
	# Godot, che e' la cosa che rompe di piu' l'illusione -- si nota prima di qualsiasi
	# dettaglio dei pulsanti.
	# In Win95 il canale e' un incavo e il cursore un pulsante in rilievo. Il canale vero era
	# una scacchiera 1x1 di bianco e grigio; qui si usa il suo tono MEDIO e non la scacchiera,
	# perche' lo schermo dell'OS viene rimpicciolito a ~2/3 e passato dal CRT, dove un
	# reticolo da un pixel diventa un moire sporco invece di una texture.
	# Lo SPESSORE viene dai margini interni dello stylebox (ScrollBar non ha una costante per
	# quello), quindi serve uno stylebox PER ASSE: sulla verticale i margini larghi danno la
	# larghezza, sull'orizzontale quelli alti danno l'altezza. Con un unico stylebox a
	# margini zero la barra veniva spessa due pixel.
	# 20 px: sono i 16 di allora riportati alla scala dell'OS, che gira a 1440x1080.
	var mezzo := 10
	t.set_stylebox("scroll", "VScrollBar", _sb(false, Color("e0e0e0"), false, mezzo, 0, mezzo, 0))
	t.set_stylebox("scroll_focus", "VScrollBar", _sb(false, Color("e0e0e0"), false, mezzo, 0, mezzo, 0))
	t.set_stylebox("grabber", "VScrollBar", _sb(true, C_FACE, true, mezzo, 12, mezzo, 12))
	t.set_stylebox("grabber_highlight", "VScrollBar", _sb(true, C_FACE, true, mezzo, 12, mezzo, 12))
	t.set_stylebox("grabber_pressed", "VScrollBar", _sb(false, C_FACE, true, mezzo, 12, mezzo, 12))
	t.set_stylebox("scroll", "HScrollBar", _sb(false, Color("e0e0e0"), false, 0, mezzo, 0, mezzo))
	t.set_stylebox("scroll_focus", "HScrollBar", _sb(false, Color("e0e0e0"), false, 0, mezzo, 0, mezzo))
	t.set_stylebox("grabber", "HScrollBar", _sb(true, C_FACE, true, 12, mezzo, 12, mezzo))
	t.set_stylebox("grabber_highlight", "HScrollBar", _sb(true, C_FACE, true, 12, mezzo, 12, mezzo))
	t.set_stylebox("grabber_pressed", "HScrollBar", _sb(false, C_FACE, true, 12, mezzo, 12, mezzo))

	# Label / ScrollContainer
	t.set_color("font_color", "Label", C_TEXT)

	# RichTextLabel (pagine del browser): font d'epoca in tutti gli slot, cosi'
	# <b>/<i> e face="Courier New" (-> [code]) restano nella stessa famiglia.
	t.set_font("normal_font", "RichTextLabel", font("sans"))
	t.set_font("bold_font", "RichTextLabel", font("sans_b"))
	t.set_font("italics_font", "RichTextLabel", font("sans_i"))
	t.set_font("bold_italics_font", "RichTextLabel", font("sans_bi"))
	t.set_font("mono_font", "RichTextLabel", font("mono"))
	# celle attaccate, come cellspacing="0" dell'HTML d'epoca (e cosi' la riga
	# invisibile che impone la larghezza delle tabelle non lascia un filo grigio)
	t.set_constant("table_h_separation", "RichTextLabel", 0)
	t.set_constant("table_v_separation", "RichTextLabel", 0)
	# selezione blu navy con testo bianco
	t.set_color("selection_color", "RichTextLabel", C_SELECT)
	t.set_color("font_selected_color", "RichTextLabel", C_TITLE_TEXT)
	return t
