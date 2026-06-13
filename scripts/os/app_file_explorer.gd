class_name FileExplorerApp
extends Control

# Esplora risorse: naviga le cartelle del VFS, apre file (testo -> blocco note, html -> browser).
var os
var window

var _folder: Dictionary
var _history: Array = []          # per il pulsante "Indietro"
var _grid: GridContainer
var _addr: LineEdit
var _items: Array = []
var _selected: DesktopItem

func launch(arg) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 3)
	add_child(root)

	# barra strumenti
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 4)
	root.add_child(bar)

	var b_back := Button.new()
	b_back.text = "Indietro"
	b_back.focus_mode = Control.FOCUS_NONE
	b_back.pressed.connect(_go_back)
	bar.add_child(b_back)

	var b_up := Button.new()
	b_up.text = "Su"
	b_up.focus_mode = Control.FOCUS_NONE
	b_up.pressed.connect(_go_up)
	bar.add_child(b_up)

	var addr_lbl := Label.new()
	addr_lbl.text = "Indirizzo:"
	addr_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bar.add_child(addr_lbl)

	_addr = LineEdit.new()
	_addr.editable = false
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_addr)

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
