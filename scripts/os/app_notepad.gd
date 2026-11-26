class_name NotepadApp
extends Control

# Blocco note: mostra il contenuto di un file di testo del VFS,
# con menu contestuale (tasto destro) in stile classico.
# Ritocco del 20/11/2026 (proprietario: "sistemare la ui dei file txt", e il testo tagliato
# nelle finestre strette): rifatto sul Blocco note di Windows 95/98 -- titolo
# "NOME - Blocco note", i menu File / Modifica / ? con le voci di allora, "A capo
# automatico" nel menu Modifica, la barra dei menu che va a capo quando non ci sta.
var os
var window

var _edit: TextEdit
var _file_name := ""
var _file_dict = null          # riferimento al file nel VFS (per salvare)
var _modified := false
var _barra_menu: Array = []          # le voci della barra, per ALT+lettera
var _menu_layer: Control
var _menu_panel: Panel
var _menu_vbox: VBoxContainer

const MENU_W := 190
const NP_CORPO := 17       # il corpo del testo (Fixedsys, vedi launch)

func launch(arg) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var file: Dictionary = arg if arg is Dictionary else {}
	_file_dict = arg if arg is Dictionary else null
	_file_name = str(file.get("name", tr("NP_UNTITLED")))

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# Barra dei menu. E' un HFlowContainer e non una fila fissa: in Windows, quando la
	# finestra e' troppo stretta per tutte le voci, la barra dei menu VA A CAPO su una
	# seconda riga invece di tagliarle (prima, a 220 px, "Cerca" e "?" sparivano).
	var menubar := HFlowContainer.new()
	menubar.name = "BarraMenu"
	menubar.add_theme_constant_override("h_separation", 2)
	menubar.add_theme_constant_override("v_separation", 0)
	# Barra dei menu con l'acceleratore sottolineato, come le altre due (Win95.menubar_button
	# toglie la & dalla scritta tradotta e risponde ad ALT+lettera).
	var mb_file := Win95.menubar_button(tr("MENU_FILE"))
	mb_file.pressed.connect(func(): _open_file_menu(mb_file))
	menubar.add_child(mb_file)
	var mb_mod := Win95.menubar_button(tr("MENU_EDIT"))
	mb_mod.pressed.connect(func(): _open_edit_menu(_below(mb_mod), true))
	menubar.add_child(mb_mod)
	# "Cerca" non fa niente: resta GRIGIA invece di sembrare attiva - la stessa regola del
	# browser e dell'Esplora (Win95.menubar_button senza callback).
	var mb_cerca := Win95.menubar_button(tr("MENU_SEARCH"), false)
	menubar.add_child(mb_cerca)
	var mb_aiuto := Win95.menubar_button("?")
	mb_aiuto.pressed.connect(func(): _open_help_menu(mb_aiuto))
	menubar.add_child(mb_aiuto)
	_barra_menu = [mb_file, mb_mod, mb_cerca]
	root.add_child(menubar)

	_edit = TextEdit.new()
	_edit.name = "Testo"
	_edit.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Un'IMMAGINE aperta col Blocco note mostra i suoi byte, non un errore: e' quello che
	# faceva davvero, ed e' una delle strade per trovare una chiave (OSContent.byte_dump
	# mette il commento del file in chiaro in mezzo alla sbrodolata). Un BINARIO (.EXE,
	# .DLL, un font) ha gia' la sua sbrodolata dentro "content": la si mostra com'e'.
	# Nessuno dei due si puo' modificare: riscrivere byte a caso non deve poter cambiare il
	# contenuto del gioco.
	var tipo := str(file.get("filetype", ""))
	var e_immagine: bool = tipo == "image"
	var sola_lettura: bool = e_immagine or tipo == "bin"
	_edit.text = OSContent.byte_dump(file) if e_immagine else str(file.get("content", ""))
	GameManager.scopri_in(_edit.text)   # file del disco, byte di una foto, sorgente di una pagina
	_edit.editable = not sola_lettura
	# il testo iniziale e' la base: senza questo, "Annulla" lo cancellerebbe tutto
	_edit.clear_undo_history()
	_edit.context_menu_enabled = false   # usiamo il nostro menu personalizzato
	# Il Blocco note di Windows 95/98 scriveva in Fixedsys: un carattere a spaziatura fissa,
	# disegnato a pixel, senza sfumature. Fixedsys e' di Microsoft e qui non c'e': lo fa il
	# clone di Courier (Cousine) in grassetto e NITIDO, che ne ha il peso e i quadretti.
	# Serve soprattutto al sorgente delle pagine ("Origine" nel browser apre qui).
	_edit.add_theme_font_override("font", Win95.font_pagina("mono_b"))
	_edit.add_theme_font_size_override("font_size", NP_CORPO)
	# RIGHE LUNGHE. Nel Blocco note del '95 una riga che non ci stava NON andava a capo:
	# usciva dal bordo destro e si leggeva scorrendo con la barra orizzontale. Per farla
	# andare a capo c'era Modifica > A capo automatico (spezza le righe al bordo della
	# finestra, anche dentro una parola troppo lunga, e la barra orizzontale sparisce).
	# Qui e' lo stesso; la scelta vale per tutta la sessione (GameManager.np_a_capo).
	_edit.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_imposta_a_capo(GameManager.np_a_capo)
	_edit.gui_input.connect(_on_edit_input)
	root.add_child(_edit)

	_build_menu()
	# da qui in poi le modifiche dell'utente segnano il file come "non salvato"
	if not sola_lettura:
		_edit.text_changed.connect(_on_text_changed)
	_update_title()

func a_capo() -> bool:
	return _edit != null and _edit.wrap_mode == TextEdit.LINE_WRAPPING_BOUNDARY

func _imposta_a_capo(si: bool) -> void:
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY if si else TextEdit.LINE_WRAPPING_NONE

func _cambia_a_capo() -> void:
	GameManager.np_a_capo = not a_capo()
	_imposta_a_capo(GameManager.np_a_capo)

func _on_text_changed() -> void:
	_modified = true

# "NOME - Blocco note", come nel '95. Niente asterisco per le modifiche non salvate: il
# Blocco note di allora non lo metteva (se ne accorgeva solo chiudendo).
func _update_title() -> void:
	if window:
		window.set_title(tr("NP_TITLE_FMT") % _file_name)

func _save() -> void:
	if _file_dict != null:
		_file_dict["content"] = _edit.text
	_modified = false

func _on_edit_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_S and event.ctrl_pressed:
		_save()
		_edit.accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_open_edit_menu(get_local_mouse_position(), false)
		_edit.accept_event()

# ---------------- menu a tendina (File / Modifica / ? / tasto destro) ----------------

# ALT+lettera: come nelle altre barre, e solo se questa finestra e' attiva.
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or window == null or not window.active:
		return
	if Win95.premi_acceleratore(_barra_menu, event):
		get_viewport().set_input_as_handled()

func _below(btn: Control) -> Vector2:
	var local := btn.global_position - global_position
	return Vector2(local.x, local.y + btn.size.y)

func _close() -> void:
	if window:
		window.close()

# Le voci del menu File del Blocco note di Windows 98. Funzionano Salva ed Esci; le altre
# (aprire, stampare...) qui non hanno niente da fare e restano GRIGIE (regola 11).
func _open_file_menu(btn: Control) -> void:
	_open_menu([
		[tr("NP_NEW"), Callable(), true],
		[tr("NP_OPEN"), Callable(), true],
		[tr("NP_SAVE"), func(): _save(), _file_dict == null or not _edit.editable],
		[tr("NP_SAVE_AS"), Callable(), true],
		["sep"],
		[tr("NP_PAGE_SETUP"), Callable(), true],
		[tr("NP_PRINT"), Callable(), true],
		["sep"],
		[tr("NP_EXIT"), func(): _close()],
	], _below(btn))

# completo = il menu Modifica della barra; col tasto destro (completo = false) c'erano solo
# le voci di modifica, senza "A capo automatico" e il carattere.
func _open_edit_menu(at: Vector2, completo: bool) -> void:
	var has_sel := _edit.has_selection()
	var scrivibile := _edit.editable
	var voci := [
		[tr("NP_UNDO"), func(): _edit.undo(), not (scrivibile and _edit.has_undo())],
		["sep"],
		[tr("NP_CUT"), func(): _edit.cut(), not (scrivibile and has_sel)],
		[tr("NP_COPY"), func(): _edit.copy(), not has_sel],
		[tr("NP_PASTE"), func(): _edit.paste(), not (scrivibile and DisplayServer.clipboard_has())],
		[tr("NP_DELETE"), func(): _edit.delete_selection(), not (scrivibile and has_sel)],
		["sep"],
		[tr("NP_SELECT_ALL"), func(): _edit.select_all(), _edit.text.is_empty()],
	]
	if completo:
		voci.append(["sep"])
		voci.append([tr("NP_WORD_WRAP"), func(): _cambia_a_capo(), false, a_capo()])
		voci.append([tr("NP_SET_FONT"), Callable(), true])
	_open_menu(voci, at)

func _open_help_menu(btn: Control) -> void:
	_open_menu([
		[tr("NP_HELP_TOPICS"), Callable(), true],
		["sep"],
		[tr("NP_ABOUT"), func(): _informazioni()],
	], _below(btn))

# Come nell'Esplora e nel browser: la finestra "Informazioni" la disegna il desktop.
func _informazioni() -> void:
	if os == null:
		return
	os.apri_informazioni(tr("NP_ABOUT"), "notepad",
			[tr("NP_APP"), tr("BOOT_VERSION"), "", tr("EX_ABOUT_COPY")])

func _build_menu() -> void:
	_menu_layer = Control.new()
	_menu_layer.name = "Menu"
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

# Il segno di spunta delle voci attive ("A capo automatico"), nella colonna a sinistra dove
# Windows lo metteva. Le voci senza spunta hanno un'icona VUOTA della stessa misura, cosi'
# le scritte restano allineate tutte alla stessa colonna.
static var _spunta: ImageTexture = null
static var _spunta_vuota: ImageTexture = null

static func _icona_spunta(segnata: bool) -> ImageTexture:
	if _spunta == null:
		var n := 14
		var vuota := Image.create(n, n, false, Image.FORMAT_RGBA8)
		vuota.fill(Color(0, 0, 0, 0))
		_spunta_vuota = ImageTexture.create_from_image(vuota)
		var im := vuota.duplicate() as Image
		# la spunta di Win95: un trattino in giu' e uno lungo in su, spessi 3 pixel
		var punti := [Vector2i(2, 6), Vector2i(3, 7), Vector2i(4, 8), Vector2i(5, 7),
				Vector2i(6, 6), Vector2i(7, 5), Vector2i(8, 4), Vector2i(9, 3), Vector2i(10, 2)]
		for p in punti:
			for dy in range(3):
				im.set_pixel(p.x, p.y + dy, Win95.C_TEXT)
		_spunta = ImageTexture.create_from_image(im)
	return _spunta if segnata else _spunta_vuota

# items: voci ["sep"] oppure [etichetta, Callable, disabilitato?, spuntata?]
# Una voce con il Callable vuoto e' sempre grigia.
func _open_menu(items: Array, at: Vector2) -> void:
	for c in _menu_vbox.get_children():
		c.free()
	var labels: Array = []
	var con_spunte := false
	for it in items:
		if it.size() >= 4:
			con_spunte = true
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
			var cb: Callable = it[1]
			b.disabled = not cb.is_valid() or (it.size() >= 3 and bool(it[2]))
			if con_spunte:
				b.icon = NotepadApp._icona_spunta(it.size() >= 4 and bool(it[3]))
				b.set_meta("spuntata", it.size() >= 4 and bool(it[3]))
			if cb.is_valid():
				b.pressed.connect(func():
					_menu_layer.visible = false
					cb.call()
					_edit.grab_focus())
			_menu_vbox.add_child(b)
			labels.append(it[0])
	var ms := _menu_vbox.get_combined_minimum_size()
	var w := maxf(Win95.menu_width(labels) + (20.0 if con_spunte else 0.0), ms.x + 6.0)
	var ht := ms.y + 6.0
	_menu_panel.size = Vector2(w, ht)
	at.x = clampf(at.x, 0.0, maxf(0.0, size.x - w))
	at.y = clampf(at.y, 0.0, maxf(0.0, size.y - ht))
	_menu_panel.position = at
	_menu_layer.visible = true
	_menu_layer.move_to_front()
