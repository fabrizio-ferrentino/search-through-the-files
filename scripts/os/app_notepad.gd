class_name NotepadApp
extends Control

# Blocco note: mostra il contenuto di un file di testo del VFS.
var os
var window

func launch(arg) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var file: Dictionary = arg if arg is Dictionary else {}

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

	var edit := TextEdit.new()
	edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	edit.text = file.get("content", "")
	edit.editable = true
	edit.add_theme_font_size_override("font_size", 18)
	root.add_child(edit)
