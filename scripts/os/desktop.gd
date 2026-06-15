class_name OSDesktop
extends Control

# Controller principale del mini-OS (stile retro' anni '90) renderizzato dentro il SubViewport 4:3.
# Gestisce desktop, taskbar, menu Start e il window manager.
#
# L'OS vive sempre (la stanza e il PC coesistono): lo schermo del monitor 3D
# mostra dal vivo questo SubViewport. Accensione/spegnimento/login sono metodi a
# runtime (boot / power_off), non cambi di scena. ESC chiede l'uscita alla stanza.

signal exit_requested   # ESC o "Annulla": torna alla vista stanza (senza spegnere)

const TASKBAR_H := 40

var window_layer: Control
var taskbar: Panel
var tasks_box: HBoxContainer
var start_btn: Button
var start_menu: Panel
var clock_label: Label
var icons_layer: Control

var windows: Array = []
var taskbar_buttons: Dictionary = {}   # OSWindow -> Button
var active_window: OSWindow = null
var _cascade := 0
var _desk_sel: DesktopItem = null
var _state_overlay: Control = null   # overlay di stato a tutto schermo (login / nessun segnale / avvio)
var _ctx_layer: Control
var _ctx_panel: Panel
var _ctx_vbox: VBoxContainer
var _no_signal_box: Panel = null
var _no_signal_vel: Vector2 = Vector2.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_filter = Control.MOUSE_FILTER_PASS
	theme = Win95.make_theme()

	_build_wallpaper()
	_build_icons()

	window_layer = Control.new()
	window_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE: il layer a tutto schermo non deve bloccare i click sulle icone del
	# desktop sottostanti; le finestre figlie (STOP) restano comunque cliccabili.
	window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(window_layer)

	_build_taskbar()
	_build_start_menu()
	_build_desktop_menu()

	# stato iniziale: il PC parte spento -> "nessun segnale" sul monitor
	if not GameManager.pc_on:
		_show_no_signal()
	elif not GameManager.logged_in:
		_show_login()

# ---------------- costruzione UI ----------------

func _build_wallpaper() -> void:
	var wp := ColorRect.new()
	wp.color = Win95.C_DESKTOP
	wp.set_anchors_preset(Control.PRESET_FULL_RECT)
	wp.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			if e.button_index == MOUSE_BUTTON_RIGHT:
				_show_desktop_menu([["Nuovo documento di testo", _new_desktop_file]])
			else:
				_deselect_desktop())
	add_child(wp)

func _build_icons() -> void:
	icons_layer = Control.new()
	icons_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	icons_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icons_layer)
	_refresh_icons()

func _refresh_icons() -> void:
	for c in icons_layer.get_children():
		c.queue_free()
	_desk_sel = null
	# icona del Cestino "pieno" quando contiene qualcosa
	var trash_icon := "trash_full" if not VFS.get_trash().get("children", []).is_empty() else "trash"
	var defs := [
		{"name": "Risorse del computer", "icon": "computer", "open": func(): open_app("explorer", VFS.get_root())},
		{"name": "Documenti", "icon": "folder", "open": func(): open_app("explorer", _folder_path(["Disco locale (C:)", "Documenti"]))},
		{"name": "Web", "icon": "ie", "open": func(): open_app("browser", "start")},
		{"name": "Cestino", "icon": trash_icon, "open": func(): open_app("explorer", _folder_path(["Cestino"]))},
	]
	var y := 24.0
	for d in defs:
		_add_desktop_item(d, y, false)
		y += 108.0
	# file creati sul desktop (dal VFS)
	for f in VFS.get_desktop().get("children", []):
		_add_desktop_item(f, y, true)
		y += 108.0

func _add_desktop_item(d: Dictionary, y: float, is_file: bool) -> void:
	var item := DesktopItem.new()
	item.setup(d, 48, 100, Win95.C_TITLE_TEXT)
	item.position = Vector2(20, y)
	item.activated.connect(_on_desktop_activated)
	item.picked.connect(_on_desktop_picked)
	if is_file:
		item.context_requested.connect(_on_desktop_item_context)
	icons_layer.add_child(item)

func _build_taskbar() -> void:
	taskbar = Panel.new()
	taskbar.anchor_left = 0.0
	taskbar.anchor_right = 1.0
	taskbar.anchor_top = 1.0
	taskbar.anchor_bottom = 1.0
	taskbar.offset_top = -TASKBAR_H
	add_child(taskbar)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 4
	hb.offset_right = -4
	hb.offset_top = 4
	hb.offset_bottom = -4
	hb.add_theme_constant_override("separation", 4)
	taskbar.add_child(hb)

	start_btn = _icon_button("Start", "win", TASKBAR_H - 8)
	start_btn.custom_minimum_size.x = 96
	start_btn.toggle_mode = true
	start_btn.pressed.connect(_toggle_start_menu)
	hb.add_child(start_btn)

	var sep := VSeparator.new()
	hb.add_child(sep)

	tasks_box = HBoxContainer.new()
	tasks_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tasks_box.add_theme_constant_override("separation", 3)
	hb.add_child(tasks_box)

	var clock_panel := Panel.new()
	clock_panel.add_theme_stylebox_override("panel", Win95._sb(false, Win95.C_FACE, true, 8, 2, 8, 2))
	clock_panel.custom_minimum_size = Vector2(86, 0)
	hb.add_child(clock_panel)
	clock_label = Label.new()
	clock_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clock_panel.add_child(clock_label)

	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(_update_clock)
	add_child(t)
	_update_clock()

func _build_start_menu() -> void:
	var item_h := 42
	var items := [
		{"name": "Esplora risorse", "icon": "computer", "open": func(): open_app("explorer", VFS.get_root())},
		{"name": "Web", "icon": "ie", "open": func(): open_app("browser", "start")},
		{"name": "Documenti", "icon": "folder", "open": func(): open_app("explorer", _folder_path(["Disco locale (C:)", "Documenti"]))},
		{"sep": true},
		{"name": "Spegni il PC", "icon": "win", "open": func(): _show_shutdown()},
	]
	var menu_w := 250
	var stripe_w := 34
	var menu_h := 0
	for it in items:
		menu_h += 8 if it.has("sep") else item_h
	menu_h += 6

	start_menu = Panel.new()
	start_menu.visible = false
	start_menu.size = Vector2(menu_w, menu_h)
	start_menu.position = Vector2(0, size.y - TASKBAR_H - menu_h)
	add_child(start_menu)

	var stripe := ColorRect.new()
	stripe.color = Win95.C_TITLE
	stripe.position = Vector2(3, 3)
	stripe.size = Vector2(stripe_w, menu_h - 6)
	start_menu.add_child(stripe)
	var flag := OSIcon.new()
	flag.kind = "win"
	flag.size = Vector2(26, 26)
	flag.position = Vector2(4, menu_h - 36)
	stripe.add_child(flag)

	var vb := VBoxContainer.new()
	vb.position = Vector2(3 + stripe_w, 3)
	vb.size = Vector2(menu_w - stripe_w - 6, menu_h - 6)
	vb.add_theme_constant_override("separation", 0)
	start_menu.add_child(vb)

	for it in items:
		if it.has("sep"):
			var s := ColorRect.new()
			s.color = Win95.C_SHADOW
			s.custom_minimum_size = Vector2(0, 8)
			vb.add_child(s)
			continue
		var b := _icon_button(it["name"], it["icon"], item_h)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cb: Callable = it["open"]
		b.pressed.connect(func():
			start_menu.visible = false
			start_btn.button_pressed = false
			cb.call())
		vb.add_child(b)

func _icon_button(text: String, kind: String, h: int) -> Button:
	var b := Button.new()
	b.text = "      " + text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, h)
	b.focus_mode = Control.FOCUS_NONE
	var icon_s := h - 14
	var ic := OSIcon.new()
	ic.kind = kind
	ic.size = Vector2(icon_s, icon_s)
	ic.position = Vector2(7, (h - icon_s) / 2.0)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	return b

# ---------------- window manager ----------------

func open_window(title: String, win_size: Vector2, icon_kind: String) -> OSWindow:
	var win := OSWindow.new()
	win.os = self
	window_layer.add_child(win)
	win.setup(title, win_size, icon_kind)
	win.position = Vector2(90 + _cascade * 28, 60 + _cascade * 28)
	_cascade = (_cascade + 1) % 7
	win.closed.connect(_on_window_closed)
	win.minimized.connect(_on_window_min)
	win.title_changed.connect(_on_title_changed)
	windows.append(win)
	_add_taskbar_button(win)
	focus_window(win)
	return win

func open_app(kind: String, arg = null) -> OSWindow:
	match kind:
		"explorer":
			var folder: Dictionary = arg if arg is Dictionary else VFS.get_root()
			var win := open_window(folder.get("name", "Esplora risorse"), Vector2(740, 520), "folder")
			var app := FileExplorerApp.new()
			win.content_root.add_child(app)
			app.os = self
			app.window = win
			app.launch(folder)
			return win
		"browser":
			var win := open_window("Web", Vector2(900, 640), "ie")
			var app := BrowserApp.new()
			win.content_root.add_child(app)
			app.os = self
			app.window = win
			app.launch(arg if arg is String else "start")
			return win
		"notepad":
			var file: Dictionary = arg if arg is Dictionary else {}
			var win := open_window(str(file.get("name", "Senza nome")), Vector2(560, 460), "notepad")
			var app := NotepadApp.new()
			win.content_root.add_child(app)
			app.os = self
			app.window = win
			app.launch(file)
			return win
	return null

func focus_window(win: OSWindow) -> void:
	active_window = win
	if is_instance_valid(win):
		window_layer.move_child(win, -1)
	for w in windows:
		w.set_active(w == win)
	_update_taskbar()

func _add_taskbar_button(win: OSWindow) -> void:
	var b := _icon_button(win.win_title, win.icon_kind, TASKBAR_H - 8)
	b.toggle_mode = true
	b.custom_minimum_size.x = 150
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = 0.0
	b.pressed.connect(_on_taskbar_pressed.bind(win))
	tasks_box.add_child(b)
	taskbar_buttons[win] = b

func _on_taskbar_pressed(win: OSWindow) -> void:
	if not win.visible:
		win.show()
		focus_window(win)
	elif win == active_window:
		win.hide()
		win.set_active(false)
		active_window = null
		_update_taskbar()
	else:
		focus_window(win)

func _on_window_min(win: OSWindow) -> void:
	win.hide()
	if active_window == win:
		active_window = null
	_update_taskbar()

func _on_window_closed(win: OSWindow) -> void:
	windows.erase(win)
	if taskbar_buttons.has(win):
		taskbar_buttons[win].queue_free()
		taskbar_buttons.erase(win)
	if active_window == win:
		active_window = null
	_update_taskbar()

func _on_title_changed(win: OSWindow) -> void:
	if taskbar_buttons.has(win):
		taskbar_buttons[win].text = "      " + win.win_title

func _update_taskbar() -> void:
	for win in taskbar_buttons:
		var b: Button = taskbar_buttons[win]
		b.button_pressed = (win == active_window and win.visible)
		b.text = "      " + win.win_title

# ---------------- desktop icons ----------------

func _on_desktop_picked(item: DesktopItem) -> void:
	if _desk_sel and _desk_sel != item:
		_desk_sel.set_selected(false)
	_desk_sel = item
	item.set_selected(true)

func _on_desktop_activated(data: Dictionary) -> void:
	if data.has("open"):
		data["open"].call()
	elif data.get("type", "") == "folder":
		open_app("explorer", data)
	elif data.get("type", "") == "file":
		if data.get("filetype", "") == "html":
			open_app("browser", data.get("url", "start"))
		else:
			open_app("notepad", data)

func _on_desktop_item_context(item: DesktopItem) -> void:
	var data: Dictionary = item.data
	_show_desktop_menu([
		["Apri", func(): _on_desktop_activated(data)],
		["Elimina", func(): _delete_desktop_file(data)],
	])

func _deselect_desktop() -> void:
	if _desk_sel:
		_desk_sel.set_selected(false)
		_desk_sel = null

# ---------------- crea / elimina file sul desktop ----------------

func _new_desktop_file() -> void:
	var df := VFS.get_desktop()
	var base := "Nuovo documento"
	var fname := base + ".txt"
	var n := 1
	while _desktop_name_exists(df, fname):
		n += 1
		fname = "%s (%d).txt" % [base, n]
	var f := {"name": fname, "type": "file", "icon": "text", "filetype": "text", "content": "", "_parent": df}
	if not df.has("children"):
		df["children"] = []
	df["children"].append(f)
	_refresh_icons()

func _desktop_name_exists(df: Dictionary, n: String) -> bool:
	for c in df.get("children", []):
		if c.get("name", "") == n:
			return true
	return false

func _delete_desktop_file(data) -> void:
	VFS.move_to_trash(data)   # va nel Cestino, non sparisce
	_refresh_icons()

# Ricostruisce le icone del desktop (es. dopo aver spostato file nel Cestino da
# un'altra finestra): aggiorna anche lo stato pieno/vuoto del Cestino.
func refresh_desktop() -> void:
	_refresh_icons()

# ---------------- menu contestuale del desktop ----------------

func _build_desktop_menu() -> void:
	_ctx_layer = Control.new()
	_ctx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctx_layer.visible = false
	add_child(_ctx_layer)
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_ctx_layer.visible = false)
	_ctx_layer.add_child(catcher)
	_ctx_panel = Panel.new()
	_ctx_layer.add_child(_ctx_panel)
	_ctx_vbox = VBoxContainer.new()
	_ctx_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctx_vbox.offset_left = 3
	_ctx_vbox.offset_top = 3
	_ctx_vbox.offset_right = -3
	_ctx_vbox.offset_bottom = -3
	_ctx_vbox.add_theme_constant_override("separation", 0)
	_ctx_panel.add_child(_ctx_vbox)

func _show_desktop_menu(items: Array) -> void:
	for c in _ctx_vbox.get_children():
		c.free()
	var labels: Array = []
	for it in items:
		var b := Button.new()
		b.text = it[0]
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		var cb: Callable = it[1]
		b.pressed.connect(func():
			_ctx_layer.visible = false
			cb.call())
		_ctx_vbox.add_child(b)
		labels.append(it[0])
	var ms := _ctx_vbox.get_combined_minimum_size()
	var w := maxf(Win95.menu_width(labels), ms.x + 6.0)
	var ht := ms.y + 6.0
	_ctx_panel.size = Vector2(w, ht)
	var pos := get_local_mouse_position()
	pos.x = clamp(pos.x, 0.0, max(0.0, size.x - w))
	pos.y = clamp(pos.y, 0.0, max(0.0, size.y - ht))
	_ctx_panel.position = pos
	_ctx_layer.visible = true
	_ctx_layer.move_to_front()

# ---------------- start menu ----------------

func _toggle_start_menu() -> void:
	start_menu.visible = start_btn.button_pressed
	if start_menu.visible:
		# riposiziona sempre sopra la taskbar (robusto anche se la dimensione cambia)
		start_menu.position = Vector2(0, size.y - TASKBAR_H - start_menu.size.y)
		start_menu.move_to_front()

# ---------------- input globale ----------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# ESC: torna alla vista stanza (il PC resta nello stato attuale)
		exit_requested.emit()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mp := get_global_mouse_position()
		# chiudi il menu Start se si clicca fuori
		if start_menu and start_menu.visible:
			if not start_menu.get_global_rect().has_point(mp) and not start_btn.get_global_rect().has_point(mp):
				start_menu.visible = false
				start_btn.button_pressed = false
		# porta in primo piano la finestra sotto il cursore
		_focus_under_mouse(mp)

func _focus_under_mouse(mp: Vector2) -> void:
	# itera nell'ordine visivo (z-order): l'ultimo figlio e' quello in primo piano
	var kids := window_layer.get_children()
	for i in range(kids.size() - 1, -1, -1):
		var w := kids[i] as OSWindow
		if w != null and w.visible and w.get_global_rect().has_point(mp):
			if w != active_window:
				focus_window(w)
			else:
				# assicura che resti in cima
				window_layer.move_child(w, -1)
			return

# Forma del cursore per un punto in coordinate del desktop. La stanza la usa per
# mostrare il cursore di ridimensionamento sull'overlay del PC: il SubViewport non
# pilota il cursore reale, quindi lo facciamo dal lato stanza.
func cursor_shape_at(pos: Vector2) -> int:
	var kids := window_layer.get_children()
	# una finestra in ridimensionamento mantiene il suo cursore ovunque sia il mouse
	for k in kids:
		var rw := k as OSWindow
		if rw and rw.is_resizing():
			return rw.cursor_at(Vector2.ZERO)
	# altrimenti: finestra in cima (ultimo figlio) sotto il punto
	for i in range(kids.size() - 1, -1, -1):
		var w := kids[i] as OSWindow
		if w and w.visible and Rect2(w.position, w.size).has_point(pos):
			return w.cursor_at(pos - w.position)
	return Control.CURSOR_ARROW

# ---------------- util ----------------

func _update_clock() -> void:
	var t := Time.get_time_dict_from_system()
	clock_label.text = "%02d:%02d" % [t.hour, t.minute]

func _folder_path(names: Array) -> Dictionary:
	var cur := VFS.get_root()
	for n in names:
		var found := {}
		for c in cur.get("children", []):
			if c.get("name", "") == n:
				found = c
				break
		if found.is_empty():
			return cur
		cur = found
	return cur

# ---------------- accensione / spegnimento (runtime) ----------------

# Rimuove l'overlay di stato corrente (login / nessun segnale / avvio).
func _clear_state() -> void:
	if _state_overlay and is_instance_valid(_state_overlay):
		_state_overlay.queue_free()
	_state_overlay = null
	_no_signal_box = null # Interrompe il movimento in _process

# Accensione del case (dal pulsante nella stanza): animazione di avvio, poi login.
func boot() -> void:
	GameManager.pc_on = true
	GameManager.logged_in = false
	_play_boot()

# Spegnimento del case: chiude tutto e mostra "nessun segnale".
func power_off() -> void:
	for w in windows.duplicate():
		if is_instance_valid(w):
			w.close()
	GameManager.pc_on = false
	GameManager.logged_in = false
	active_window = null
	_update_taskbar()
	_show_no_signal()

# Animazione di avvio: splash nero con logo e barra di avanzamento, poi il login.
func _play_boot() -> void:
	_clear_state()
	var splash := ColorRect.new()
	splash.color = Color.BLACK
	splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	splash.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(splash)
	splash.move_to_front()
	_state_overlay = splash

	var logo := Label.new()
	logo.text = "52-HZ WHALE"
	logo.add_theme_color_override("font_color", Win95.C_LIGHT)
	logo.add_theme_font_size_override("font_size", 64)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.position = Vector2(size.x * 0.5 - 200, size.y * 0.5 - 110)
	logo.size = Vector2(400, 80)
	splash.add_child(logo)

	var sub := Label.new()
	sub.text = "Avvio del sistema in corso..."
	sub.add_theme_color_override("font_color", Win95.C_HILIGHT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(size.x * 0.5 - 200, size.y * 0.5 + 12)
	sub.size = Vector2(400, 24)
	splash.add_child(sub)

	var bar_w := 300.0
	var track := Panel.new()
	track.add_theme_stylebox_override("panel", Win95._sb(false, Win95.C_LIGHT, true, 2, 2, 2, 2))
	track.position = Vector2(size.x * 0.5 - bar_w * 0.5, size.y * 0.5 + 52)
	track.size = Vector2(bar_w, 22)
	splash.add_child(track)
	var fill := ColorRect.new()
	fill.color = Win95.C_TITLE
	fill.position = Vector2(3, 3)
	fill.size = Vector2(0, 16)
	track.add_child(fill)

	var tw := create_tween()
	tw.tween_property(fill, "size:x", bar_w - 6.0, 1.3)
	tw.tween_callback(func():
		if GameManager.pc_on:
			_show_login())

# ---------------- finestre modali ----------------

# Crea un overlay modale a tutto schermo con un riquadro centrale in stile Win95
# (barra del titolo blu + corpo grigio). Riusato da login e arresto.
func _make_modal(title: String, dlg_size: Vector2, bg: Color) -> Dictionary:
	var layer := Control.new()
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_STOP   # blocca i click al desktop sotto
	add_child(layer)
	layer.move_to_front()

	var back := ColorRect.new()
	back.color = bg
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(back)

	var panel := Panel.new()
	panel.size = dlg_size
	panel.position = ((size - dlg_size) * 0.5).floor()
	layer.add_child(panel)

	var tbar := ColorRect.new()
	tbar.color = Win95.C_TITLE
	tbar.position = Vector2(3, 3)
	tbar.size = Vector2(dlg_size.x - 6, 26)
	panel.add_child(tbar)
	var tl := Label.new()
	tl.text = title
	tl.add_theme_color_override("font_color", Win95.C_TITLE_TEXT)
	tl.position = Vector2(7, 2)
	tl.size = Vector2(dlg_size.x - 14, 26)
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tbar.add_child(tl)

	return {"layer": layer, "panel": panel}

# Schermata di login: chiede la password (per ora "123") prima di mostrare il desktop.
func _show_login() -> void:
	_clear_state()
	var dlg := _make_modal("Accesso a 52-hz Whale", Vector2(380, 196), Win95.C_DESKTOP)
	var layer: Control = dlg["layer"]
	var panel: Panel = dlg["panel"]
	_state_overlay = layer

	var msg := Label.new()
	msg.text = "Digitare la password per accedere."
	msg.position = Vector2(16, 42)
	panel.add_child(msg)

	var cap := Label.new()
	cap.text = "Password:"
	cap.position = Vector2(16, 80)
	panel.add_child(cap)

	var pw := LineEdit.new()
	pw.secret = true
	pw.position = Vector2(120, 76)
	pw.size = Vector2(140, 30)
	panel.add_child(pw)

	var err := Label.new()
	err.add_theme_color_override("font_color", Color(0.6, 0, 0))
	err.position = Vector2(16, 120)
	err.size = Vector2(panel.size.x - 32, 24)
	panel.add_child(err)

	var ok := Button.new()
	ok.text = "OK"
	ok.position = Vector2(panel.size.x - 110, 76)
	ok.size = Vector2(92, 32)
	panel.add_child(ok)

	var attempt := func():
		if pw.text == "123":
			GameManager.logged_in = true
			_clear_state()   # rimuove il login -> compare il desktop
		else:
			err.text = "Password non corretta. Riprovare."
			pw.clear()
			pw.grab_focus()
	ok.pressed.connect(attempt)
	pw.text_submitted.connect(func(_t): attempt.call())
	# (niente "Annulla": per uscire senza loggare si preme ESC)
	pw.call_deferred("grab_focus")

# Conferma di spegnimento (stile classico: solo Sì / No).
func _show_shutdown() -> void:
	var dlg := _make_modal("Spegnimento", Vector2(380, 170), Color(0, 0, 0, 0.35))
	var layer: Control = dlg["layer"]
	var panel: Panel = dlg["panel"]

	# triangolo di avviso (disegnato a mano)
	var warn := Control.new()
	warn.position = Vector2(20, 48)
	warn.size = Vector2(36, 36)
	panel.add_child(warn)
	warn.draw.connect(func():
		var pts := PackedVector2Array([Vector2(18, 2), Vector2(34, 32), Vector2(2, 32)])
		warn.draw_colored_polygon(pts, Color("efc63c"))
		warn.draw_polyline(pts + PackedVector2Array([pts[0]]), Color.BLACK, 1.5)
		warn.draw_string(ThemeDB.fallback_font, Vector2(14, 28), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.BLACK))

	var lbl := Label.new()
	lbl.text = "Sei sicuro di voler spegnere il PC?"
	lbl.position = Vector2(72, 52)
	lbl.size = Vector2(panel.size.x - 90, 40)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(lbl)

	var yes := Button.new()
	yes.text = "Sì"
	yes.position = Vector2(panel.size.x * 0.5 - 104, 118)
	yes.size = Vector2(96, 32)
	panel.add_child(yes)

	var no := Button.new()
	no.text = "No"
	no.position = Vector2(panel.size.x * 0.5 + 8, 118)
	no.size = Vector2(96, 32)
	panel.add_child(no)

	yes.pressed.connect(func(): layer.queue_free(); power_off())
	no.pressed.connect(func(): layer.queue_free())

# Schermo "nessun segnale": come i vecchi monitor CRT col cavo staccato / PC
# spento. Riquadro che vaga lentamente su sfondo nero (anti burn-in).
func _show_no_signal() -> void:
	_clear_state()
	var ov := ColorRect.new()
	ov.color = Color.BLACK
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ov)
	ov.move_to_front()
	_state_overlay = ov

	var box := Panel.new()
	box.add_theme_stylebox_override("panel", Win95._sb(true, Color(0.13, 0.13, 0.16), true, 0, 0, 0, 0))
	box.size = Vector2(360, 116)
	
	# Posizione iniziale casuale per non farlo partire sempre dallo stesso punto
	var max_x := size.x - box.size.x
	var max_y := size.y - box.size.y
	box.position = Vector2(randf_range(20.0, max_x - 20.0), randf_range(20.0, max_y - 20.0))
	ov.add_child(box)

	var title := Label.new()
	title.text = "NESSUN SEGNALE"
	title.add_theme_color_override("font_color", Color(0.92, 0.92, 0.95))
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 26)
	title.size = Vector2(box.size.x, 38)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Controllare il cavo del segnale"
	sub.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 70)
	sub.size = Vector2(box.size.x, 24)
	box.add_child(sub)

	# Assegna il riquadro per abilitare il movimento in _process
	_no_signal_box = box

	# Configura la velocità e una direzione diagonale casuale
	var speed := 110.0 # Velocità in pixel al secondo
	# Genera un angolo tra ~27° e ~63° per evitare movimenti troppo orizzontali o verticali
	var angle := randf_range(0.15, 0.35) * PI 
	var dir_x := 1.0 if randf() > 0.5 else -1.0
	var dir_y := 1.0 if randf() > 0.5 else -1.0
	_no_signal_vel = Vector2(cos(angle) * dir_x, sin(angle) * dir_y) * speed
	
	# ---------------- loop di aggiornamento ----------------

func _process(delta: float) -> void:
	if is_instance_valid(_no_signal_box) and _no_signal_box.is_inside_tree():
		# Sposta il riquadro in base alla velocità e al tempo trascorso
		_no_signal_box.position += _no_signal_vel * delta
		
		# Limiti di movimento entro lo schermo del desktop
		var min_x := 0.0
		var max_x := size.x - _no_signal_box.size.x
		var min_y := 0.0
		var max_y := size.y - _no_signal_box.size.y
		
		# Rimbalzo e correzione per l'asse X
		if _no_signal_box.position.x <= min_x:
			_no_signal_box.position.x = min_x
			_no_signal_vel.x = abs(_no_signal_vel.x)
		elif _no_signal_box.position.x >= max_x:
			_no_signal_box.position.x = max_x
			_no_signal_vel.x = -abs(_no_signal_vel.x)
			
		# Rimbalzo e correzione per l'asse Y
		if _no_signal_box.position.y <= min_y:
			_no_signal_box.position.y = min_y
			_no_signal_vel.y = abs(_no_signal_vel.y)
		elif _no_signal_box.position.y >= max_y:
			_no_signal_box.position.y = max_y
			_no_signal_vel.y = -abs(_no_signal_vel.y)
