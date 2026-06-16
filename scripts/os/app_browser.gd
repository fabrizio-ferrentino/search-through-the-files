class_name BrowserApp
extends Control

# Browser finto: barra indirizzi, navigazione tra pagine e "Ispeziona elemento"
# che mostra il (presunto) codice HTML, generato dalla stessa descrizione della pagina.
var os
var window

var _addr: LineEdit
var _page_vbox: VBoxContainer
var _scroll: ScrollContainer
var _page_bg: ColorRect
var _inspector: Control
var _inspector_edit: TextEdit
var _resizing := false

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
	root.add_theme_constant_override("separation", 2)
	add_child(root)

	# --- barra dei menu ---
	var menubar := HBoxContainer.new()
	menubar.add_theme_constant_override("separation", 2)
	for m in ["File", "Modifica", "Visualizza", "Preferiti", "?"]:
		var mb := Button.new()
		mb.text = m
		mb.flat = true
		mb.focus_mode = Control.FOCUS_NONE
		menubar.add_child(mb)
	root.add_child(menubar)

	# --- barra strumenti (icone) ---
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 2)
	root.add_child(toolbar)
	toolbar.add_child(_icon_btn("back", _go_back))                    # funzionante
	toolbar.add_child(_icon_btn("fwd", _go_forward))                 # funzionante
	toolbar.add_child(_icon_btn("stop"))                             # finto
	toolbar.add_child(_icon_btn("refresh", func(): _load(_current))) # funzionante
	toolbar.add_child(_icon_btn("home", func(): _go("start")))       # funzionante
	toolbar.add_child(_vsep())
	toolbar.add_child(_icon_btn("search", func(): _toggle_inspector())) # Ispeziona
	toolbar.add_child(_icon_btn("star"))                             # finto (Preferiti)
	toolbar.add_child(_icon_btn("print"))                            # finto

	# --- barra indirizzo (stile combo) ---
	var addrbar := HBoxContainer.new()
	addrbar.add_theme_constant_override("separation", 6)
	root.add_child(addrbar)
	var lbl := Label.new()
	lbl.text = "Indirizzo:"
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	addrbar.add_child(lbl)
	var gicon := OSIcon.new()
	gicon.kind = "ie"
	gicon.custom_minimum_size = Vector2(18, 18)
	gicon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gicon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	addrbar.add_child(gicon)
	_addr = LineEdit.new()
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr.placeholder_text = "Digita un indirizzo, es. http://news.com"
	_addr.text_submitted.connect(_on_addr_submit)
	addrbar.add_child(_addr)
	var drop := Button.new()
	drop.custom_minimum_size = Vector2(20, 24)
	drop.focus_mode = Control.FOCUS_NONE
	var di := OSIcon.new()
	di.kind = "dropdown"
	di.size = Vector2(16, 16)
	di.position = Vector2(2, 4)
	di.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.add_child(di)
	addrbar.add_child(drop)
	addrbar.add_child(_text_btn("Vai", func(): _on_addr_submit(_addr.text)))

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

	_load(arg if arg is String else "start")

func _icon_btn(kind: String, cb := Callable()) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(30, 28)
	b.focus_mode = Control.FOCUS_NONE
	var ic := OSIcon.new()
	ic.kind = kind
	ic.size = Vector2(20, 20)
	ic.position = Vector2(5, 4)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

func _text_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _vsep() -> VSeparator:
	var s := VSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = Win95.C_SHADOW
	sb.thickness = 1
	sb.vertical = true
	s.add_theme_stylebox_override("separator", sb)
	s.add_theme_constant_override("separation", 8)
	return s

func _build_inspector(root: Control) -> void:
	_inspector = VBoxContainer.new()
	_inspector.custom_minimum_size = Vector2(0, 230)
	_inspector.visible = false
	_inspector.add_theme_constant_override("separation", 0)
	root.add_child(_inspector)

	# maniglia per ridimensionare l'altezza (trascina su/giu')
	var grip := Panel.new()
	grip.custom_minimum_size = Vector2(0, 9)
	grip.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	grip.add_theme_stylebox_override("panel", Win95._sb(true, Win95.C_FACE, true, 0, 0, 0, 0))
	grip.gui_input.connect(_on_grip_input)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grip.add_child(center)
	var marker := HBoxContainer.new()
	marker.add_theme_constant_override("separation", 3)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(marker)
	for i in range(2):
		var dot := ColorRect.new()
		dot.color = Win95.C_SHADOW
		dot.custom_minimum_size = Vector2(22, 2)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.add_child(dot)
	_inspector.add_child(grip)

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

# Trascina la maniglia in cima all'inspector per cambiarne l'altezza.
func _on_grip_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_resizing = event.pressed
	elif event is InputEventMouseMotion and _resizing:
		var cms := _inspector.custom_minimum_size
		cms.y = clampf(cms.y - event.relative.y, 90.0, maxf(120.0, size.y - 220.0))
		_inspector.custom_minimum_size = cms

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
	url = url.trim_prefix("http://").trim_prefix("https://").trim_suffix("/")
	if url == "":
		url = "start"
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
		url = "start"
	_current = url
	var page: Dictionary = _pages().get(url, _page_404(url))
	_addr.text = "" if url == "start" else "http://" + url
	if window:
		window.set_title(str(page.get("title", url)))
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
			# largo solo quanto il testo (allineato a sx): l'area link/hover non
			# deve coprire tutta la riga, ma solo la scritta, come un link reale
			link.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			link.add_theme_color_override("font_color", Win95.C_LINK)
			link.add_theme_color_override("font_hover_color", Color("ee0000"))
			link.add_theme_font_size_override("font_size", 18)
			var href: String = el.get("href", "start")
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
			# Commento HTML: compare nel sorgente (Ispeziona elemento) ma _make_element
			# non lo rende a video -> ottimo nascondiglio per una chiave.
		"comment":
			lines.append("%s<!-- %s -->" % [indent, str(el.get("text", ""))])

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
			{"tag": "p", "text": "Impossibile trovare il sito \"http://" + url + "\"."},
			{"tag": "p", "text": "Controlla l'indirizzo o la connessione del modem."},
			{"tag": "hr"},
			{"tag": "a", "text": "Pagina iniziale", "href": "start"},
		]
	}

# Svuota la cache delle pagine: chiamato da GameManager.start_new_run() cosi' le
# pagine (e le chiavi che contengono) si rigenerano per ogni nuovo run.
static func reset_pages() -> void:
	_pages_cache = {}

func _pages() -> Dictionary:
	if _pages_cache.is_empty():
		var k3 := GameManager.key_label(3)   # chiave nel testo VISIBILE di una pagina (con prefisso "3-")
		var k4 := GameManager.key_label(4)   # chiave nel SORGENTE HTML (commento, con prefisso "4-")
		_pages_cache = {
			"start": {
				"title": "Pagina iniziale",
				"elements": [
					{"tag": "img", "alt": "Il mio portale", "color": "1a3f8a", "w": 560, "h": 80},
					{"tag": "h1", "text": "Pagina iniziale"},
					{"tag": "h2", "text": "Collegamenti piu' visti"},
					{"tag": "a", "text": "NewsOggi - Le ultime notizie", "href": "news.com"},
					{"tag": "a", "text": "GiocaWeb - Giochi gratis online", "href": "giochi.net"},
					{"tag": "a", "text": "MeteoNow - Previsioni del tempo", "href": "meteo.com"},
					{"tag": "hr"},
					{"tag": "h2", "text": "Collegamenti recenti"},
					{"tag": "a", "text": "Il blog segreto", "href": "blog.io"},
					{"tag": "a", "text": "WebMail - La tua posta", "href": "mail.com"},
					{"tag": "a", "text": "Sito inesistente (prova 404)", "href": "sito-finto.com"},
					{"tag": "p", "text": "Suggerimento: tasto destro -> Ispeziona elemento per vedere l'HTML."},
				]
			},
			"news.com": {
				"title": "NewsOggi",
				"elements": [
					{"tag": "img", "alt": "NewsOggi", "color": "8a1f1f", "w": 560, "h": 70},
					{"tag": "h1", "text": "NewsOggi"},
					{"tag": "comment", "text": "build-key=" + k4},
					{"tag": "h2", "text": "In primo piano"},
					{"tag": "p", "text": "Rilasciato un nuovo sistema operativo a finestre: code ai negozi."},
					{"tag": "p", "text": "Gli esperti: i floppy da 1.44 MB sono il futuro dell'archiviazione."},
					{"tag": "img", "alt": "foto sgranata", "color": "777777", "w": 320, "h": 180},
					{"tag": "hr"},
					{"tag": "a", "text": "Vai a GiocaWeb", "href": "giochi.net"},
					{"tag": "a", "text": "Pagina iniziale", "href": "start"},
				]
			},
			"giochi.net": {
				"title": "GiocaWeb",
				"elements": [
					{"tag": "img", "alt": "GiocaWeb", "color": "1f6a2f", "w": 560, "h": 70},
					{"tag": "h1", "text": "GiocaWeb"},
					{"tag": "p", "text": "I migliori giochi shareware da scaricare col tuo modem a 56k."},
					{"tag": "ul", "items": [
						"Solitario Deluxe",
						"Campo Minato 3D",
						"Serpente 2000",
					]},
					{"tag": "hr"},
					{"tag": "a", "text": "Leggi le notizie", "href": "news.com"},
					{"tag": "a", "text": "Pagina iniziale", "href": "start"},
				]
			},
			"meteo.com": {
				"title": "MeteoNow",
				"elements": [
					{"tag": "img", "alt": "MeteoNow", "color": "2f6a8a", "w": 560, "h": 70},
					{"tag": "h1", "text": "MeteoNow"},
					{"tag": "h2", "text": "Oggi"},
					{"tag": "p", "text": "Sole con qualche nuvola. Massima 24 gradi, minima 14 gradi."},
					{"tag": "p", "text": "Domani: pioggia in arrivo dal pomeriggio."},
					{"tag": "hr"},
					{"tag": "a", "text": "Pagina iniziale", "href": "start"},
				]
			},
			"blog.io": {
				"title": "Il blog segreto",
				"elements": [
					{"tag": "h1", "text": "Pagina nascosta"},
					{"tag": "p", "text": "Se stai leggendo questo, hai trovato il collegamento giusto nel computer."},
					{"tag": "p", "text": "La password e' nascosta in un file di testo dentro Documenti..."},
					{"tag": "p", "text": "Promemoria personale: il terzo frammento e' " + k3 + ". Gli altri li ho sparsi altrove."},
					{"tag": "hr"},
					{"tag": "a", "text": "Pagina iniziale", "href": "start"},
				]
			},
			"mail.com": {
				"title": "WebMail",
				"elements": [
					{"tag": "img", "alt": "WebMail", "color": "5a3f8a", "w": 560, "h": 70},
					{"tag": "h1", "text": "WebMail"},
					{"tag": "p", "text": "Accedi alla tua casella di posta elettronica."},
					{"tag": "p", "text": "Utente: ______    Password: ______"},
					{"tag": "p", "text": "(Modulo di accesso non disponibile in questa demo.)"},
					{"tag": "hr"},
					{"tag": "a", "text": "Pagina iniziale", "href": "start"},
				]
			},
		}
	return _pages_cache
