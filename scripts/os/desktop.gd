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

# ---------------- costruzione UI ----------------

func _build_wallpaper() -> void:
	var wp := ColorRect.new()
	wp.color = Win95.C_DESKTOP
	wp.set_anchors_preset(Control.PRESET_FULL_RECT)
	wp.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_deselect_desktop())
	add_child(wp)

func _build_icons() -> void:
	icons_layer = Control.new()
	icons_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	icons_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(icons_layer)

	var defs := [
		{"name": "Risorse del computer", "icon": "computer", "open": func(): open_app("explorer", VFS.get_root())},
		{"name": "Documenti", "icon": "folder", "open": func(): open_app("explorer", _folder_path(["Disco locale (C:)", "Documenti"]))},
		{"name": "Web", "icon": "ie", "open": func(): open_app("browser", "home")},
		{"name": "Cestino", "icon": "trash", "open": func(): open_app("explorer", _folder_path(["Cestino"]))},
	]
	var y := 24.0
	for d in defs:
		var item := DesktopItem.new()
		item.setup(d, 48, 100, Win95.C_TITLE_TEXT)
		item.position = Vector2(20, y)
		item.activated.connect(_on_desktop_activated)
		item.picked.connect(_on_desktop_picked)
		icons_layer.add_child(item)
		y += 108.0

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
		{"name": "Web", "icon": "ie", "open": func(): open_app("browser", "home")},
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

func open_app(kind: String, arg = null) -> void:
	match kind:
		"explorer":
			var folder: Dictionary = arg if arg is Dictionary else VFS.get_root()
			var win := open_window(folder.get("name", "Esplora risorse"), Vector2(740, 520), "folder")
			var app := FileExplorerApp.new()
			win.content_root.add_child(app)
			app.os = self
			app.window = win
			app.launch(folder)
		"browser":
			var win := open_window("Web", Vector2(900, 640), "ie")
			var app := BrowserApp.new()
			win.content_root.add_child(app)
			app.os = self
			app.window = win
			app.launch(arg if arg is String else "home")
		"notepad":
			var file: Dictionary = arg if arg is Dictionary else {}
			var win := open_window(str(file.get("name", "Senza nome")) + " - Blocco note", Vector2(560, 460), "notepad")
			var app := NotepadApp.new()
			win.content_root.add_child(app)
			app.os = self
			app.window = win
			app.launch(file)

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

func _deselect_desktop() -> void:
	if _desk_sel:
		_desk_sel.set_selected(false)
		_desk_sel = null

# ---------------- start menu ----------------

func _toggle_start_menu() -> void:
	start_menu.visible = start_btn.button_pressed
	if start_menu.visible:
		start_menu.move_to_front()

# ---------------- input globale ----------------

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if active_window != null and is_instance_valid(active_window):
			active_window.close()
		elif not windows.is_empty():
			windows[windows.size() - 1].close()
		else:
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
	for i in range(windows.size() - 1, -1, -1):
		var w: OSWindow = windows[i]
		if w.visible and w.get_global_rect().has_point(mp):
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
	get_tree().change_scene_to_file("res://scenes/main.tscn")
