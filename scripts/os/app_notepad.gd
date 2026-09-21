class_name NotepadApp
extends Control

# Blocco note: mostra il contenuto di un file di testo del VFS,
# con menu contestuale (tasto destro) in stile classico.
var os
var window

var _edit: TextEdit
var _file_name := "Senza nome"
var _file_dict = null          # riferimento al file nel VFS (per salvare)
var _modified := false
var _barra_menu: Array = []          # le voci della barra, per ALT+lettera
var _menu_layer: Control
var _menu_panel: Panel
var _menu_vbox: VBoxContainer

const MENU_W := 190

func launch(arg) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var file: Dictionary = arg if arg is Dictionary else {}
	_file_dict = arg if arg is Dictionary else null
	_file_name = str(file.get("name", "Senza nome"))

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# barra dei menu (File / Modifica con tendina)
	var menubar := HBoxContainer.new()
	menubar.add_theme_constant_override("separation", 2)
	# Barra dei menu con l'acceleratore sottolineato, come le altre due (Win95.menubar_button
	# toglie la & dalla scritta tradotta e risponde ad ALT+lettera).
	var mb_file := Win95.menubar_button(tr("MENU_FILE"))
	mb_file.pressed.connect(func(): _open_file_menu(mb_file))
	menubar.add_child(mb_file)
	var mb_mod := Win95.menubar_button(tr("MENU_EDIT"))
	mb_mod.pressed.connect(func(): _open_edit_menu(_below(mb_mod)))
	menubar.add_child(mb_mod)
	# "Cerca" e "?" non fanno niente: qui restano GRIGIE invece di sembrare attive - la
	# stessa regola del browser e dell'Esplora (Win95.menubar_button senza callback).
	var mb_cerca := Win95.menubar_button(tr("MENU_SEARCH"), false)
	menubar.add_child(mb_cerca)
	menubar.add_child(Win95.menubar_button("?", false))
	_barra_menu = [mb_file, mb_mod, mb_cerca]
	root.add_child(menubar)

	_edit = TextEdit.new()
	_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Un'IMMAGINE aperta col Blocco note mostra i suoi byte, non un errore: e' quello che
	# faceva davvero, ed e' una delle strade per trovare una chiave (OSContent.byte_dump
	# mette il commento del file in chiaro in mezzo alla sbrodolata). Non e' modificabile:
	# riscrivere byte a caso in un'immagine non deve poter cambiare il contenuto del gioco.
	# Un BINARIO (.EXE, .DLL, un font) ha gia' la sua sbrodolata dentro "content": la si
	# mostra com'e'. Nessuno dei due si puo' modificare: riscrivere byte a caso non deve
	# poter cambiare il contenuto del gioco.
	var tipo := str(file.get("filetype", ""))
	var e_immagine: bool = tipo == "image"
	var sola_lettura: bool = e_immagine or tipo == "bin"
	_edit.text = OSContent.byte_dump(file) if e_immagine else str(file.get("content", ""))
	_edit.editable = not sola_lettura
	# il testo iniziale e' la base: senza questo, "Annulla" lo cancellerebbe tutto
	_edit.clear_undo_history()
	_edit.editable = not sola_lettura
	_edit.context_menu_enabled = false   # usiamo il nostro menu personalizzato
	_edit.add_theme_font_size_override("font_size", 18)
	_edit.gui_input.connect(_on_edit_input)
	root.add_child(_edit)

	_build_menu()
	# da qui in poi le modifiche dell'utente segnano il file come "non salvato"
	if not sola_lettura:
		_edit.text_changed.connect(_on_text_changed)

func _on_text_changed() -> void:
	_modified = true
	_update_title()

func _update_title() -> void:
	if window:
		window.set_title(("* " if _modified else "") + _file_name)

func _save() -> void:
	if _file_dict != null:
		_file_dict["content"] = _edit.text
	_modified = false
	_update_title()

func _on_edit_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_S and event.ctrl_pressed:
		_save()
		_edit.accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_open_edit_menu(get_local_mouse_position())
		_edit.accept_event()

# ---------------- menu a tendina (File / Modifica / tasto destro) ----------------

# ALT+lettera: come nelle altre barre, e solo se questa finestra e' attiva.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or window == null or not window.active:
		return
	if Win95.premi_acceleratore(_barra_menu, event):
		get_viewport().set_input_as_handled()

func _menubar_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	return b

func _below(btn: Control) -> Vector2:
	var local := btn.global_position - global_position
	return Vector2(local.x, local.y + btn.size.y)

func _close() -> void:
	if window:
		window.close()

func _open_file_menu(btn: Control) -> void:
	_open_menu([
		[tr("NP_SAVE"), func(): _save(), _file_dict == null],
		["sep"],
		[tr("NP_CLOSE"), func(): _close()],
	], _below(btn))

func _open_edit_menu(at: Vector2) -> void:
	var has_sel := _edit.has_selection()
	_open_menu([
		[tr("NP_UNDO"), func(): _edit.undo(), not _edit.has_undo()],
		["sep"],
		[tr("NP_CUT"), func(): _edit.cut(), not has_sel],
		[tr("NP_COPY"), func(): _edit.copy(), not has_sel],
		[tr("NP_PASTE"), func(): _edit.paste(), not DisplayServer.clipboard_has()],
		[tr("NP_DELETE"), func(): _edit.delete_selection(), not has_sel],
		["sep"],
		[tr("NP_SELECT_ALL"), func(): _edit.select_all(), _edit.text.is_empty()],
	], at)

func _build_menu() -> void:
	_menu_layer = Control.new()
	_menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_layer.visible = false
	add_child(_menu_layer)
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_menu_layer.visible = false)
	_menu_layer.add_child(catcher)
	_menu_panel = Panel.new()
	_menu_layer.add_child(_menu_panel)
	_menu_vbox = VBoxContainer.new()
	_menu_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_vbox.offset_left = 3
	_menu_vbox.offset_top = 3
	_menu_vbox.offset_right = -3
	_menu_vbox.offset_bottom = -3
	_menu_vbox.add_theme_constant_override("separation", 0)
	_menu_panel.add_child(_menu_vbox)

# items: voci ["sep"] oppure [etichetta, Callable, disabilitato?]
func _open_menu(items: Array, at: Vector2) -> void:
	for c in _menu_vbox.get_children():
		c.free()
	var labels: Array = []
	for it in items:
		if it.size() == 1:
			var sep := HSeparator.new()
			var sb := StyleBoxLine.new()
			sb.color = Win95.C_SHADOW
			sb.thickness = 1
			sep.add_theme_stylebox_override("separator", sb)
			sep.add_theme_constant_override("separation", 9)
			_menu_vbox.add_child(sep)
		else:
			var b := Button.new()
			b.text = it[0]
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.focus_mode = Control.FOCUS_NONE
			if it.size() >= 3:
				b.disabled = it[2]
			var cb: Callable = it[1]
			b.pressed.connect(func():
				_menu_layer.visible = false
				cb.call()
				_edit.grab_focus())
			_menu_vbox.add_child(b)
			labels.append(it[0])
	var ms := _menu_vbox.get_combined_minimum_size()
	var w := maxf(Win95.menu_width(labels), ms.x + 6.0)
	var ht := ms.y + 6.0
	_menu_panel.size = Vector2(w, ht)
	at.x = clampf(at.x, 0.0, maxf(0.0, size.x - w))
	at.y = clampf(at.y, 0.0, maxf(0.0, size.y - ht))
	_menu_panel.position = at
	_menu_layer.visible = true
	_menu_layer.move_to_front()
