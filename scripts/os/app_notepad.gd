class_name NotepadApp
extends Control

# Blocco note: mostra il contenuto di un file di testo del VFS,
# con menu contestuale (tasto destro) in stile classico.
var os
var window

var _edit: TextEdit
var _file_name := "Senza nome"
var _ctx_layer: Control
var _ctx_menu: VBoxContainer
var _items: Dictionary = {}

const MENU_W := 190

func launch(arg) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var file: Dictionary = arg if arg is Dictionary else {}
	_file_name = str(file.get("name", "Senza nome"))

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# finta barra dei menu
	var menubar := HBoxContainer.new()
	menubar.add_theme_constant_override("separation", 2)
	for m in ["File", "Modifica", "Cerca", "?"]:
		var b := Button.new()
		b.text = m
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		menubar.add_child(b)
	root.add_child(menubar)

	_edit = TextEdit.new()
	_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_edit.text = file.get("content", "")
	# il testo iniziale e' la base: senza questo, "Annulla" lo cancellerebbe tutto
	_edit.clear_undo_history()
	_edit.editable = true
	_edit.context_menu_enabled = false   # usiamo il nostro menu personalizzato
	_edit.add_theme_font_size_override("font_size", 18)
	_edit.gui_input.connect(_on_edit_input)
	root.add_child(_edit)

	_build_ctx_menu()

func get_session() -> Dictionary:
	return {"kind": "notepad", "file_name": _file_name, "text": _edit.text}

func _on_edit_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_show_ctx()
		_edit.accept_event()

# ---------------- menu contestuale ----------------

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
	panel.custom_minimum_size = Vector2(MENU_W, 0)
	_ctx_layer.add_child(panel)

	_ctx_menu = VBoxContainer.new()
	_ctx_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctx_menu.offset_left = 3
	_ctx_menu.offset_top = 3
	_ctx_menu.offset_right = -3
	_ctx_menu.offset_bottom = -3
	_ctx_menu.add_theme_constant_override("separation", 0)
	panel.add_child(_ctx_menu)

	_add_item("Annulla", func(): _edit.undo())
	_add_sep()
	_add_item("Taglia", func(): _edit.cut())
	_add_item("Copia", func(): _edit.copy())
	_add_item("Incolla", func(): _edit.paste())
	_add_item("Elimina", func(): _edit.delete_selection())
	_add_sep()
	_add_item("Seleziona tutto", func(): _edit.select_all())

func _add_item(label: String, cb: Callable) -> void:
	var b := Button.new()
	b.text = label
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 26)
	b.pressed.connect(func():
		_ctx_layer.visible = false
		cb.call()
		_edit.grab_focus())
	_ctx_menu.add_child(b)
	_items[label] = b

func _add_sep() -> void:
	var sep := HSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = Win95.C_SHADOW
	sb.thickness = 1
	sep.add_theme_stylebox_override("separator", sb)
	sep.add_theme_constant_override("separation", 9)
	_ctx_menu.add_child(sep)

func _show_ctx() -> void:
	# abilita/disabilita le voci come nell'originale
	var has_sel := _edit.has_selection()
	_items["Annulla"].disabled = not _edit.has_undo()
	_items["Taglia"].disabled = not has_sel
	_items["Copia"].disabled = not has_sel
	_items["Incolla"].disabled = not DisplayServer.clipboard_has()
	_items["Elimina"].disabled = not has_sel
	_items["Seleziona tutto"].disabled = _edit.text.is_empty()

	var panel := _ctx_layer.get_node("Panel") as Panel
	panel.size = Vector2(MENU_W, _ctx_menu.get_combined_minimum_size().y + 6)
	var pos := get_local_mouse_position()
	pos.x = clamp(pos.x, 0.0, max(0.0, size.x - panel.size.x))
	pos.y = clamp(pos.y, 0.0, max(0.0, size.y - panel.size.y))
	panel.position = pos
	_ctx_layer.visible = true
	_ctx_layer.move_to_front()
