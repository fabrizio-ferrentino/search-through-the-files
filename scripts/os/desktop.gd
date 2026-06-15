class_name OSDesktop
extends Control

# Controller principale del mini-OS (stile retro' anni '90) renderizzato dentro il SubViewport 4:3.
# Gestisce desktop, taskbar, menu Start e il window manager.

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
var _exiting := false
var _ctx_layer: Control
var _ctx_panel: Panel
var _ctx_vbox: VBoxContainer

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

	# ripristina le finestre della sessione precedente (sessione continua)
	_restore_session()

	# rivela il desktop dal nero (entrando nel PC)
	_reveal_screen()

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
	var defs := [
		{"name": "Risorse del computer", "icon": "computer", "open": func(): open_app("explorer", VFS.get_root())},
		{"name": "Documenti", "icon": "folder", "open": func(): open_app("explorer", _folder_path(["Disco locale (C:)", "Documenti"]))},
		{"name": "Web", "icon": "ie", "open": func(): open_app("browser", "start")},
		{"name": "Cestino", "icon": "trash", "open": func(): open_app("explorer", _folder_path(["Cestino"]))},
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
		{"name": "Chiudi sessione...", "icon": "trash", "open": func(): _exit_to_room()},
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
			var win := open_window(str(file.get("name", "Senza nome")) + " - Blocco note", Vector2(560, 460), "notepad")
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
	var ch: Array = VFS.get_desktop().get("children", [])
	for i in range(ch.size()):
		if is_same(ch[i], data):
			ch.remove_at(i)
			break
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
		start_menu.move_to_front()

# ---------------- input globale ----------------

func _input(event: InputEvent) -> void:
	if _exiting:
		return
	if event.is_action_pressed("ui_cancel"):
		# ESC: esci subito dal PC e torna nella stanza (salvando la sessione)
		_exit_to_room()
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

func _exit_to_room() -> void:
	if _exiting:
		return
	_exiting = true
	_save_session()
	_capture_screen()
	GameManager.returning_from_pc = true
	# cambio scena diretto: e' la stanza a fare l'animazione inversa (parte dal nero)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

# Overlay nero a tutto schermo: rivela il desktop dal nero entrando nel PC.
func _reveal_screen() -> void:
	var ov := get_node_or_null("../../../FadeOverlay") as ColorRect
	if ov == null:
		return
	ov.color.a = 1.0
	ov.visible = true
	create_tween().tween_property(ov, "color:a", 0.0, 0.4)

# Cattura il desktop (il SubViewport in cui gira l'OS) per mostrarlo sul monitor 3D.
func _capture_screen() -> void:
	if DisplayServer.get_name() == "headless":
		return   # niente GPU: impossibile leggere la texture del viewport
	var vp := get_viewport()
	if vp == null:
		return
	var img := vp.get_texture().get_image()
	if img != null and not img.is_empty():
		GameManager.pc_screenshot = img

# ---------------- sessione continua ----------------

func _save_session() -> void:
	var data := {"windows": [], "active": -1}
	var kids := window_layer.get_children()   # ordine = z-order
	for i in range(kids.size()):
		var win := kids[i] as OSWindow
		if win == null or win.content_root.get_child_count() == 0:
			continue
		var app = win.content_root.get_child(0)
		if not app.has_method("get_session"):
			continue
		if win == active_window:
			data["active"] = data["windows"].size()
		var entry: Dictionary = app.get_session()
		entry["rect"] = [win.position.x, win.position.y, win.size.x, win.size.y]
		entry["minimized"] = not win.visible
		data["windows"].append(entry)
	GameManager.pc_session = data

func _restore_session() -> void:
	var data = GameManager.pc_session
	if data == null or not (data is Dictionary):
		return
	for entry in data.get("windows", []):
		_spawn_entry(entry)
	var ai := int(data.get("active", -1))
	var kids := window_layer.get_children()
	if ai >= 0 and ai < kids.size() and kids[ai].visible:
		focus_window(kids[ai] as OSWindow)
	else:
		active_window = null
		_update_taskbar()

func _spawn_entry(entry: Dictionary) -> void:
	var win: OSWindow = null
	match entry.get("kind", ""):
		"explorer":
			win = open_app("explorer", VFS.resolve_path(entry.get("folder_path", [])))
		"browser":
			win = open_app("browser", str(entry.get("url", "start")))
		"notepad":
			# ricollega al file reale del VFS (se esiste ancora) per poterlo salvare
			var f = null
			var p: Array = entry.get("path", [])
			if p.size() > 0:
				f = VFS.resolve_node(p)
			if f == null or f.get("type", "") != "file":
				f = {"name": entry.get("file_name", "Senza nome"), "type": "file", "filetype": "text", "content": entry.get("text", "")}
			win = open_app("notepad", f)
	if win == null:
		return
	var r: Array = entry.get("rect", [])
	if r.size() == 4:
		win.position = Vector2(r[0], r[1])
		win.size = Vector2(r[2], r[3])
	var app = win.content_root.get_child(0)
	if app.has_method("restore_session"):
		app.restore_session(entry)
	if entry.get("minimized", false):
		win.hide()
		if active_window == win:
			active_window = null
		_update_taskbar()
