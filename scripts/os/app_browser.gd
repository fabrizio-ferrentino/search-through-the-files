class_name BrowserApp
extends Control

# Browser finto: barra indirizzi, navigazione tra pagine e "Ispeziona elemento"
# che mostra il (presunto) codice HTML, generato dalla stessa descrizione della pagina.
var os
var window

const HOST := "webnet95"

var _addr: LineEdit
var _page_vbox: VBoxContainer
var _scroll: ScrollContainer
var _page_bg: ColorRect
var _inspector: Control
var _inspector_edit: TextEdit

var _ctx_layer: Control
var _ctx_menu: VBoxContainer
var _ctx_idx := -1

var _current := ""
var _back: Array = []
var _forward: Array = []
var _html_text := ""
var _line_map: Dictionary = {}

static var _pages_cache: Dictionary = {}

func launch(arg) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 3)
	add_child(root)

	# --- barra strumenti ---
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	root.add_child(bar)
	_tool_btn(bar, "< Indietro", _go_back)
	_tool_btn(bar, "Avanti >", _go_forward)
	_tool_btn(bar, "Aggiorna", func(): _load(_current))
	var lbl := Label.new()
	lbl.text = "Indirizzo:"
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(lbl)
	_addr = LineEdit.new()
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr.text_submitted.connect(_on_addr_submit)
	bar.add_child(_addr)
	_tool_btn(bar, "Vai", func(): _on_addr_submit(_addr.text))
	_tool_btn(bar, "Ispeziona", func(): _toggle_inspector())

	# --- area pagina ---
	var page_area := Control.new()
	page_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_area.clip_contents = true
	root.add_child(page_area)

	_page_bg = ColorRect.new()
	_page_bg.color = Color.WHITE
	_page_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_area.add_child(_page_bg)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.gui_input.connect(_on_bg_input)
	page_area.add_child(_scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + s, 18)
	_scroll.add_child(margin)

	_page_vbox = VBoxContainer.new()
	_page_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(_page_vbox)

	# --- inspector (nascosto) ---
	_build_inspector(root)
	# --- menu contestuale custom ---
	_build_ctx_menu()

	_load(arg if arg is String else "home")

func _tool_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

func _build_inspector(root: Control) -> void:
	_inspector = VBoxContainer.new()
	_inspector.custom_minimum_size = Vector2(0, 230)
	_inspector.visible = false
	_inspector.add_theme_constant_override("separation", 0)
	root.add_child(_inspector)

	var head := Panel.new()
	head.add_theme_stylebox_override("panel", Win95._sb(true, Win95.C_FACE, true, 6, 3, 6, 3))
	head.custom_minimum_size = Vector2(0, 26)
	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 6
	hb.offset_right = -4
	head.add_child(hb)
	var t := Label.new()
	t.text = "Strumenti di sviluppo  -  Elementi (HTML)"
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(t)
	var x := GlyphButton.new()
	x.glyph = "close"
	x.custom_minimum_size = Vector2(22, 20)
	x.pressed.connect(func(): _inspector.visible = false)
	hb.add_child(x)
	_inspector.add_child(head)

	_inspector_edit = TextEdit.new()
	_inspector_edit.editable = false
	_inspector_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_inspector_edit.add_theme_font_size_override("font_size", 16)
	_inspector_edit.add_theme_font_override("font", ThemeDB.fallback_font)
	_inspector.add_child(_inspector_edit)

func _build_ctx_menu() -> void:
	_ctx_layer = Control.new()
	_ctx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctx_layer.visible = false
	add_child(_ctx_layer)

	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_ctx_layer.visible = false)
	_ctx_layer.add_child(catcher)

	var panel := Panel.new()
	panel.name = "Panel"
	panel.custom_minimum_size = Vector2(210, 0)
	_ctx_layer.add_child(panel)

	_ctx_menu = VBoxContainer.new()
	_ctx_menu.add_theme_constant_override("separation", 0)
	_ctx_menu.offset_left = 3
	_ctx_menu.offset_top = 3
	_ctx_menu.offset_right = -3
	_ctx_menu.offset_bottom = -3
	_ctx_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(_ctx_menu)
	_ctx_item("Ispeziona elemento", func(): _open_inspector(_ctx_idx))
	_ctx_item("Indietro", _go_back)
	_ctx_item("Aggiorna", func(): _load(_current))

func _ctx_item(text: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 26)
	b.pressed.connect(func():
		_ctx_layer.visible = false
		cb.call())
	_ctx_menu.add_child(b)

func _show_ctx(idx: int) -> void:
	_ctx_idx = idx
	var panel := _ctx_layer.get_node("Panel") as Panel
	var pos := get_local_mouse_position()
	pos.x = min(pos.x, size.x - 212)
	pos.y = min(pos.y, size.y - 120)
	panel.position = pos
	panel.size = Vector2(210, _ctx_menu.get_combined_minimum_size().y + 6)
	_ctx_layer.visible = true
	_ctx_layer.move_to_front()

# ---------------- navigazione ----------------

func _on_addr_submit(text: String) -> void:
	var url := text.strip_edges()
	url = url.trim_prefix("http://").trim_prefix(HOST + "/").trim_prefix("/")
	if url == "":
		url = "home"
	_go(url)

func _go(url: String) -> void:
	if _current != "":
		_back.append(_current)
	_forward.clear()
	_load(url)

func _go_back() -> void:
	if _back.is_empty():
		return
	_forward.append(_current)
	_load(_back.pop_back())

func _go_forward() -> void:
	if _forward.is_empty():
		return
	_back.append(_current)
	_load(_forward.pop_back())

func _load(url: String) -> void:
	if url == "":
		url = "home"
	_current = url
	var page: Dictionary = _pages().get(url, _page_404(url))
	_addr.text = "http://%s/%s" % [HOST, url]
	if window:
		window.set_title(str(page.get("title", url)) + " - Web")
	var built := _build_html(page)
	_html_text = built["text"]
	_line_map = built["map"]
	_render(page)
	_scroll.scroll_vertical = 0
	if _inspector.visible:
		_inspector_edit.text = _html_text

func _on_bg_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_show_ctx(-1)

func _on_el_input(event: InputEvent, idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_show_ctx(idx)

# ---------------- rendering ----------------

func _render(page: Dictionary) -> void:
	for c in _page_vbox.get_children():
		c.queue_free()
	var els: Array = page.get("elements", [])
	for i in range(els.size()):
		var ctrl := _make_element(els[i])
		if ctrl:
			ctrl.gui_input.connect(_on_el_input.bind(i))
			_page_vbox.add_child(ctrl)

func _make_element(el: Dictionary) -> Control:
	match el.get("tag", "p"):
		"h1":
			return _text_label(el.get("text", ""), 34, Color("000066"))
		"h2":
			return _text_label(el.get("text", ""), 26, Color("003366"))
		"p":
			return _text_label(el.get("text", ""), 18, Color.BLACK)
		"a":
			var link := LinkButton.new()
			link.text = el.get("text", "")
			link.focus_mode = Control.FOCUS_NONE
			link.add_theme_color_override("font_color", Win95.C_LINK)
			link.add_theme_color_override("font_hover_color", Color("ee0000"))
			link.add_theme_font_size_override("font_size", 18)
			var href: String = el.get("href", "home")
			link.pressed.connect(func(): _go(href))
			return link
		"hr":
			var hr := ColorRect.new()
			hr.color = Win95.C_SHADOW
			hr.custom_minimum_size = Vector2(0, 2)
			return hr
		"ul":
			var box := VBoxContainer.new()
			for it in el.get("items", []):
				box.add_child(_text_label("•  " + str(it), 18, Color.BLACK))
			return box
		"img":
			return _make_img(el)
	return null

func _text_label(text: String, fsize: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _make_img(el: Dictionary) -> Control:
	var w: float = el.get("w", 560)
	var h: float = el.get("h", 100)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(w, h)
	var rect := ColorRect.new()
	rect.color = Color(str(el.get("color", "5577aa")))
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(rect)
	var alt := Label.new()
	alt.text = "[ " + str(el.get("alt", "immagine")) + " ]"
	alt.set_anchors_preset(Control.PRESET_FULL_RECT)
	alt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alt.add_theme_color_override("font_color", Color.WHITE)
	alt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(alt)
	return holder

# ---------------- generazione HTML + inspector ----------------

func _esc(s: String) -> String:
	return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

func _build_html(page: Dictionary) -> Dictionary:
	var lines: Array = []
	var map: Dictionary = {}
	lines.append("<!DOCTYPE html>")
	lines.append("<html>")
	lines.append("<head>")
	lines.append("    <title>" + _esc(str(page.get("title", ""))) + "</title>")
	lines.append("</head>")
	lines.append("<body>")
	var els: Array = page.get("elements", [])
	for i in range(els.size()):
		var start := lines.size()
		_emit(lines, els[i], "    ")
		map[i] = [start, lines.size() - 1]
	lines.append("</body>")
	lines.append("</html>")
	return {"text": "\n".join(lines), "map": map}

func _emit(lines: Array, el: Dictionary, indent: String) -> void:
	var tag: String = el.get("tag", "p")
	match tag:
		"h1", "h2", "p":
			lines.append("%s<%s>%s</%s>" % [indent, tag, _esc(el.get("text", "")), tag])
		"a":
			lines.append('%s<a href="%s">%s</a>' % [indent, el.get("href", "#"), _esc(el.get("text", ""))])
		"hr":
			lines.append(indent + "<hr>")
		"img":
			lines.append('%s<img src="%s.png" alt="%s" width="%d" height="%d">' % [
				indent, str(el.get("alt", "img")).to_lower().replace(" ", "_"),
				_esc(el.get("alt", "")), int(el.get("w", 560)), int(el.get("h", 100))])
		"ul":
			lines.append(indent + "<ul>")
			for it in el.get("items", []):
				lines.append("%s    <li>%s</li>" % [indent, _esc(str(it))])
			lines.append(indent + "</ul>")

func _toggle_inspector() -> void:
	if _inspector.visible:
		_inspector.visible = false
	else:
		_open_inspector(-1)

func _open_inspector(idx: int) -> void:
	_inspector.visible = true
	_inspector_edit.text = _html_text
	if idx >= 0 and _line_map.has(idx):
		var rng: Array = _line_map[idx]
		var last_len: int = _inspector_edit.get_line(rng[1]).length()
		_inspector_edit.set_caret_line(rng[1])
		_inspector_edit.select(rng[0], 0, rng[1], last_len)
		_inspector_edit.scroll_vertical = max(0, rng[0] - 1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		if window == null or window.active:
			_toggle_inspector()
			get_viewport().set_input_as_handled()

# ---------------- contenuti delle pagine ----------------

func _page_404(url: String) -> Dictionary:
	return {
		"title": "Pagina non trovata",
		"elements": [
			{"tag": "h1", "text": "Errore 404"},
			{"tag": "p", "text": "La pagina \"" + url + "\" non e' stata trovata su questo server."},
			{"tag": "hr"},
			{"tag": "a", "text": "Torna alla home", "href": "home"},
		]
	}

func _pages() -> Dictionary:
	if _pages_cache.is_empty():
		_pages_cache = {
			"home": {
				"title": "WebNet 95 - Home",
				"elements": [
					{"tag": "img", "alt": "WebNet 95", "color": "1a3f8a", "w": 560, "h": 90},
					{"tag": "h1", "text": "Benvenuto su WebNet 95"},
					{"tag": "p", "text": "Il portale del World Wide Web ottimizzato per il tuo modem a 56k. Naviga con il mouse, e prova il tasto destro per ispezionare la pagina!"},
					{"tag": "h2", "text": "Collegamenti"},
					{"tag": "a", "text": "Ultime notizie", "href": "news"},
					{"tag": "a", "text": "Il blog segreto", "href": "blog"},
					{"tag": "a", "text": "Un link rotto", "href": "boh"},
					{"tag": "hr"},
					{"tag": "h2", "text": "Lo sapevi che..."},
					{"tag": "ul", "items": [
						"Questo schermo e' un vero 4:3 con effetto CRT.",
						"Il tasto destro apre 'Ispeziona elemento'.",
						"Tutto l'HTML qui sotto e' generato dal gioco.",
					]},
					{"tag": "p", "text": "© 1995 WebNet. Tutti i diritti riservati."},
				]
			},
			"news": {
				"title": "WebNet 95 - Notizie",
				"elements": [
					{"tag": "h1", "text": "Ultime notizie"},
					{"tag": "p", "text": "Rilasciato un nuovo sistema operativo a finestre: tutti ne parlano."},
					{"tag": "h2", "text": "Tecnologia"},
					{"tag": "p", "text": "I floppy da 1.44 MB sono il futuro dell'archiviazione portatile."},
					{"tag": "img", "alt": "foto sgranata", "color": "777777", "w": 300, "h": 180},
					{"tag": "hr"},
					{"tag": "a", "text": "Torna alla home", "href": "home"},
				]
			},
			"blog": {
				"title": "Il blog segreto",
				"elements": [
					{"tag": "h1", "text": "Pagina nascosta"},
					{"tag": "p", "text": "Se stai leggendo questo, hai trovato il collegamento giusto nel computer."},
					{"tag": "p", "text": "La password e' nascosta in un file di testo dentro Documenti..."},
					{"tag": "hr"},
					{"tag": "a", "text": "Torna alla home", "href": "home"},
				]
			},
		}
	return _pages_cache
