class_name FileExplorerApp
extends Control

# Esplora risorse: naviga le cartelle del VFS, apre file (testo -> blocco note, html -> browser).
var os
var window

var _folder: Dictionary
var _history: Array = []          # per il pulsante "Indietro"
var _grid: GridContainer
var _addr: Label
var _combo_icon: OSIcon
var _items: Array = []
var _selected: DesktopItem

func launch(arg) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 2)
	add_child(root)

	# --- barra dei menu ---
	var menubar := HBoxContainer.new()
	menubar.add_theme_constant_override("separation", 2)
	for m in ["File", "Modifica", "Visualizza", "Strumenti", "?"]:
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
	toolbar.add_child(_tool_btn("back", _go_back))   # funzionante
	toolbar.add_child(_tool_btn("up", _go_up))       # funzionante
	toolbar.add_child(_vsep())
	toolbar.add_child(_tool_btn("cut"))              # decorativi
	toolbar.add_child(_tool_btn("copy"))
	toolbar.add_child(_tool_btn("paste"))
	toolbar.add_child(_vsep())
	toolbar.add_child(_tool_btn("delete"))
	toolbar.add_child(_tool_btn("props"))
	toolbar.add_child(_vsep())
	toolbar.add_child(_tool_btn("views"))

	# --- barra indirizzo (stile combo) ---
	var addrbar := HBoxContainer.new()
	addrbar.add_theme_constant_override("separation", 6)
	root.add_child(addrbar)
	var addr_lbl := Label.new()
	addr_lbl.text = "Indirizzo:"
	addr_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	addrbar.add_child(addr_lbl)

	var combo := Panel.new()
	combo.add_theme_stylebox_override("panel", Win95._sb(false, Win95.C_LIGHT, true, 4, 2, 4, 2))
	combo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	combo.custom_minimum_size = Vector2(0, 28)
	addrbar.add_child(combo)
	var chb := HBoxContainer.new()
	chb.set_anchors_preset(Control.PRESET_FULL_RECT)
	chb.offset_left = 4
	chb.offset_top = 2
	chb.offset_right = -3
	chb.offset_bottom = -2
	chb.add_theme_constant_override("separation", 5)
	combo.add_child(chb)
	_combo_icon = OSIcon.new()
	_combo_icon.kind = "folder_open"
	_combo_icon.custom_minimum_size = Vector2(18, 18)
	_combo_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_combo_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chb.add_child(_combo_icon)
	_addr = Label.new()
	_addr.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_addr.clip_text = true
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chb.add_child(_addr)
	var drop := Button.new()
	drop.custom_minimum_size = Vector2(20, 22)
	drop.focus_mode = Control.FOCUS_NONE
	var di := OSIcon.new()
	di.kind = "dropdown"
	di.size = Vector2(16, 16)
	di.position = Vector2(2, 3)
	di.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop.add_child(di)
	chb.add_child(drop)

	# area contenuto (campo incassato bianco con scorrimento)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", Win95._sb(false, Win95.C_LIGHT, true, 2, 2, 2, 2))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 4
	scroll.offset_top = 4
	scroll.offset_right = -4
	scroll.offset_bottom = -4
	panel.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_grid)

	_folder = arg if arg is Dictionary else VFS.get_root()
	_refresh()

func _tool_btn(kind: String, cb := Callable()) -> Button:
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

func _vsep() -> VSeparator:
	var s := VSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = Win95.C_SHADOW
	sb.thickness = 1
	sb.vertical = true
	s.add_theme_stylebox_override("separator", sb)
	s.add_theme_constant_override("separation", 8)
	return s

func _path_string(node: Dictionary) -> String:
	var parts := PackedStringArray()
	var cur = node
	while cur != null and cur is Dictionary:
		parts.insert(0, cur.get("name", ""))
		cur = cur.get("_parent", null)
	return "\\".join(parts)

func _refresh() -> void:
	if window:
		window.set_title(_folder.get("name", "Esplora risorse"))
	_addr.text = _path_string(_folder)
	if _combo_icon:
		_combo_icon.set_kind(_folder.get("icon", "folder"))
	_selected = null
	for c in _grid.get_children():
		c.queue_free()
	_items.clear()
	for child in _folder.get("children", []):
		var item := DesktopItem.new()
		item.setup(child, 40, 92, Win95.C_TEXT)
		item.activated.connect(_on_activated)
		item.picked.connect(_on_picked)
		_grid.add_child(item)
		_items.append(item)

func _on_picked(item: DesktopItem) -> void:
	if _selected and _selected != item:
		_selected.set_selected(false)
	_selected = item
	item.set_selected(true)

func _on_activated(data: Dictionary) -> void:
	match data.get("type", ""):
		"folder":
			_history.append(_folder)
			_folder = data
			_refresh()
		"file":
			if data.get("filetype", "") == "html":
				os.open_app("browser", data.get("url", "home"))
			else:
				os.open_app("notepad", data)

func _go_back() -> void:
	if _history.is_empty():
		return
	_folder = _history.pop_back()
	_refresh()

func _go_up() -> void:
	var parent = _folder.get("_parent", null)
	if parent != null and parent is Dictionary:
		_history.append(_folder)
		_folder = parent
		_refresh()

# ---------------- sessione ----------------

func get_session() -> Dictionary:
	return {"kind": "explorer", "folder_path": VFS.path_of(_folder)}
