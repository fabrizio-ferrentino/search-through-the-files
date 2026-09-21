class_name FileExplorerApp
extends Control

# Esplora risorse: naviga le cartelle del VFS, apre file (testo -> blocco note, html -> browser).
var os
var window

var _folder: Dictionary
var _history: Array = []          # per il pulsante "Indietro"
# Larghezza di una casella. I nomi di SISTEMA sono in 8.3 maiuscolo e a 92 px
# "AUTOEXEC.BAT" andava a capo in mezzo all'estensione ("CONFIG.SY / S"): illeggibile, e
# mai visto su un PC dell'epoca. Le lettere maiuscole larghe (COMMAND.COM) vogliono 132.
const CELLA_W := 132
const CELLA_SEP := 8
# La vista a ICONE PICCOLE esiste davvero: prima "Icone grandi" era l'unica e cliccarla
# ridisegnava la stessa cosa, cioe' era una voce finta con l'aria di funzionare
# (segnalato dal proprietario, 20/09/2026). Elenco e Dettagli restano grigi: vogliono un
# elemento disposto in orizzontale, che DesktopItem oggi non sa fare.
enum { VISTA_GRANDI, VISTA_PICCOLE }
const CELLA_W_PICCOLE := 104

var _grid: GridContainer
var _scroll: ScrollContainer
var _in_disposizione := false
var _vista := VISTA_GRANDI
var _addr: Label
var _combo_icon: OSIcon
var _items: Array = []
var _selected: DesktopItem
var _ctx_layer: Control
var _ctx_panel: Panel
var _ctx_vbox: VBoxContainer
# i pulsanti il cui stato DIPENDE da dove siamo e da cosa e' selezionato
var _btn_back: Button
var _btn_up: Button
var _btn_del: Button
var _btn_drop: Button
var _menu_aperto: Button = null

func launch(arg) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 2)
	add_child(root)

	# --- barra dei menu: tendine VERE (vedi _voci_*) ---
	# Prima erano cinque scritte che non facevano niente. Adesso ogni voce o funziona o e'
	# grigia, come nel browser: un menu che si apre e non ha dentro niente di attivo dice
	# lo stesso "non si puo' fare", ma lo dice da dentro il programma invece che col
	# silenzio.
	var menubar := Win95.strip(root, Win95.MENUBAR_H)
	var mb_box := HBoxContainer.new()
	mb_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mb_box.offset_left = 3
	mb_box.offset_top = 2
	mb_box.offset_bottom = -2
	mb_box.add_theme_constant_override("separation", 0)
	menubar.add_child(mb_box)
	for m in [[tr("MENU_FILE"), _voci_file], [tr("MENU_EDIT"), _voci_modifica],
			[tr("MENU_VIEW"), _voci_visualizza], [tr("MENU_TOOLS"), _voci_strumenti],
			["?", _voci_aiuto]]:
		var mb := Button.new()
		mb.text = str(m[0])
		mb.flat = true
		mb.focus_mode = Control.FOCUS_NONE
		var f: Callable = m[1]
		mb.pressed.connect(func(): _apri_menu(f.call(), mb))
		mb_box.add_child(mb)

	# --- barra strumenti ---
	var toolbar := Win95.strip(root, Win95.TB_ALTA + 8)
	var tb_box := HBoxContainer.new()
	tb_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tb_box.offset_left = 2
	tb_box.offset_top = 3
	tb_box.offset_bottom = -3
	tb_box.offset_right = -4
	tb_box.add_theme_constant_override("separation", 1)
	toolbar.add_child(tb_box)
	tb_box.add_child(Win95.grip())
	_btn_back = Win95.tool_button("back", tr("BR_BACK"), _go_back)
	_btn_up = Win95.tool_button("up", tr("EX_UP"), _go_up)
	_btn_del = Win95.tool_button("delete", tr("EX_DELETE"), _delete_selected)
	tb_box.add_child(_btn_back)
	tb_box.add_child(_btn_up)
	tb_box.add_child(_vsep())
	# TAGLIA / COPIA / INCOLLA: in questo OS non c'e' un blocco appunti per i file e non ci
	# sara'. Restano al loro posto, grigi, perche' un Esplora senza quei tre non e'
	# credibile -- e' la stessa scelta fatta per "Stampa" nel browser.
	tb_box.add_child(Win95.tool_button("cut", tr("NP_CUT"), Callable(), false))
	tb_box.add_child(Win95.tool_button("copy", tr("NP_COPY"), Callable(), false))
	tb_box.add_child(Win95.tool_button("paste", tr("NP_PASTE"), Callable(), false))
	tb_box.add_child(_vsep())
	tb_box.add_child(_btn_del)
	tb_box.add_child(Win95.tool_button("props", tr("EX_PROPERTIES"), Callable(), false))
	tb_box.add_child(_vsep())
	# Cicla fra icone grandi e piccole, come il pulsante omonimo di Win95.
	tb_box.add_child(Win95.tool_button("views", tr("MENU_VIEW"), _cambia_vista))

	# La finestra non si puo' stringere sotto la larghezza della sua barra strumenti:
	# sotto quella misura gli ultimi pulsanti finivano oltre il bordo e venivano tagliati
	# a meta' (misurato: 29 px fuori in una finestra da 420). Anche l'Esplora vero aveva
	# una larghezza minima, e per lo stesso motivo.
	_impone_larghezza_minima(tb_box)

	# --- barra indirizzo (stile combo) ---
	var addrstrip := Win95.strip(root, Win95.ADDRBAR_H)
	var addrbar := HBoxContainer.new()
	addrbar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	addrbar.offset_left = 5
	addrbar.offset_top = 3
	addrbar.offset_right = -5
	addrbar.offset_bottom = -3
	addrbar.add_theme_constant_override("separation", 6)
	addrstrip.add_child(addrbar)
	var addr_lbl := Label.new()
	addr_lbl.text = tr("EX_ADDRESS")
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
	# La freccia della combo: elenca le cartelle che stanno SOPRA questa e ci porta. E'
	# quello che faceva l'originale (mostrava l'albero) ed e' anche il solo posto dove puo'
	# portare senza regalare niente: sono le stesse cartelle da cui si e' passati.
	_btn_drop = Button.new()
	_btn_drop.custom_minimum_size = Vector2(20, 22)
	_btn_drop.focus_mode = Control.FOCUS_NONE
	var di := OSIcon.new()
	di.kind = "dropdown"
	di.size = Vector2(16, 16)
	di.position = Vector2(2, 3)
	di.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_btn_drop.add_child(di)
	_btn_drop.pressed.connect(func(): _apri_menu(_voci_percorso(), _btn_drop))
	chb.add_child(_btn_drop)

	# area contenuto (campo incassato bianco con scorrimento)
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", Win95._sb(false, Win95.C_LIGHT, true, 2, 2, 2, 2))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(panel)

	_scroll = ScrollContainer.new()
	var scroll := _scroll
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 4
	scroll.offset_top = 4
	scroll.offset_right = -4
	scroll.offset_bottom = -4
	panel.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 1                # vero valore: _aggiorna_colonne(), sulla larghezza
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	# PASS: i click nell'area vuota arrivano allo scroll (menu "Nuovo")
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(_grid)
	scroll.gui_input.connect(_on_empty_input)
	scroll.resized.connect(_aggiorna_colonne)

	_build_ctx()
	_folder = arg if arg is Dictionary else VFS.get_root()
	_refresh()

# Larghezza minima della finestra = quello che serve alla barra passata (piu' i bordi).
func _impone_larghezza_minima(barra: Control) -> void:
	if window == null:
		return
	var minima: float = barra.get_combined_minimum_size().x + 24.0
	window.custom_minimum_size = Vector2(maxf(window.custom_minimum_size.x, minima),
			window.custom_minimum_size.y)

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
		window.set_title(str(_folder.get("name", tr("SHELL_EXPLORER"))))
	_addr.text = _path_string(_folder)
	if _combo_icon:
		_combo_icon.set_kind(_folder.get("icon", "folder"))
	_selected = null
	for c in _grid.get_children():
		c.queue_free()
	_items.clear()
	_aggiorna_colonne()
	for child in _folder.get("children", []):
		var item := DesktopItem.new()
		item.setup(child, 40 if _vista == VISTA_GRANDI else 20, _cella_w(), Win95.C_TEXT)
		item.activated.connect(_on_activated)
		item.picked.connect(_on_picked)
		item.context_requested.connect(_on_item_context)
		_grid.add_child(item)
		_items.append(item)
	_aggiorna_pulsanti()

# Quante icone per riga ci stanno DAVVERO nella finestra. Con un numero fisso di colonne
# una finestra stretta tagliava l'ultima (e ne usciva una barra di scorrimento orizzontale,
# che un Esplora non ha mai avuto in vista a icone): qui invece si ridispongono, come
# facevano loro. La guardia serve perche' cambiare le colonne cambia l'ingombro del
# contenitore, che puo' riemettere "resized" -- la stessa trappola della barra delle
# applicazioni (desktop.gd::_disponi_barra).
func _aggiorna_colonne() -> void:
	if _in_disposizione or _scroll == null or _grid == null:
		return
	_in_disposizione = true
	var larga: float = _scroll.size.x
	var quante: int = int(floor((larga + CELLA_SEP) / float(_cella_w() + CELLA_SEP)))
	_grid.columns = maxi(1, quante)
	_in_disposizione = false

func _cella_w() -> int:
	return CELLA_W if _vista == VISTA_GRANDI else CELLA_W_PICCOLE

# Cambia vista (e ridisegna). La chiamano il menu Visualizza e il pulsante della barra,
# che cicla fra le due come faceva quello di Win95.
func _imposta_vista(v: int) -> void:
	if v == _vista:
		return
	_vista = v
	_refresh()

func _cambia_vista() -> void:
	_imposta_vista(VISTA_GRANDI if _vista == VISTA_PICCOLE else VISTA_PICCOLE)

func _on_picked(item: DesktopItem) -> void:
	if _selected and _selected != item:
		_selected.set_selected(false)
	_selected = item
	item.set_selected(true)
	_aggiorna_pulsanti()

# Lo stato dei pulsanti che DIPENDE da dove siamo e da cosa e' selezionato: e' il
# "disabilitato" che porta informazione, lo stesso principio del browser. "Su" e' grigio
# in cima all'albero, "Indietro" quando non si e' ancora andati da nessuna parte, e
# "Elimina" quando non c'e' selezione o quando quella cosa non si puo' buttare.
func _aggiorna_pulsanti() -> void:
	_spegni(_btn_back, _history.is_empty())
	_spegni(_btn_up, not (_folder.get("_parent", null) is Dictionary))
	_spegni(_btn_del, _selected == null or not _eliminabile(_selected.data))
	_spegni(_btn_drop, _antenati().is_empty())

func _spegni(b: Button, spento: bool) -> void:
	if b == null:
		return
	b.disabled = spento
	Win95.fade(b, spento)

# Cosa si puo' buttare nel Cestino. NON le unita' e il Cestino stesso (sono figli di
# "Risorse del computer": un disco non si elimina), e NON la cartella protetta, che e' la
# partita -- mandarla nel Cestino la renderebbe irraggiungibile e il run invincibile.
# Prima il menu contestuale offriva "Elimina" su tutto, cartella protetta compresa.
func _eliminabile(data) -> bool:
	if not (data is Dictionary):
		return false
	if str(data.get("type", "")) == "secret":
		return false
	var genitore = data.get("_parent", null)
	return genitore is Dictionary and not is_same(genitore, VFS.get_root())

# Dove si puo' creare un file nuovo: non in "Risorse del computer" (li' dentro ci sono le
# unita') e non nel Cestino.
func _si_puo_creare() -> bool:
	return not is_same(_folder, VFS.get_root()) and not VFS.is_trash(_folder)

# Le cartelle che stanno SOPRA quella aperta, dalla radice in giu'.
func _antenati() -> Array:
	var catena: Array = []
	var cur = _folder.get("_parent", null)
	while cur != null and cur is Dictionary:
		catena.push_front(cur)
		cur = cur.get("_parent", null)
	return catena

func _vai_a(nodo: Dictionary) -> void:
	if is_same(nodo, _folder):
		return
	_history.append(_folder)
	_folder = nodo
	_refresh()

func _on_activated(data: Dictionary) -> void:
	match data.get("type", ""):
		"folder":
			_history.append(_folder)
			_folder = data
			_refresh()
		"file":
			match data.get("filetype", ""):
				"html":
					os.open_app("browser", data.get("url", "home"))
				"image":
					os.open_app("image", data)
				_:
					os.open_app("notepad", data)
		"secret":
			os.open_secret_folder(data)

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

# ---------------- crea / elimina ----------------

func _on_empty_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			var crea := Callable()
			if _si_puo_creare():
				crea = _new_text_file
			_show_menu([[tr("EX_NEW_TEXT"), crea], ["-"], [tr("EX_PROPERTIES"), Callable()]])
		elif event.button_index == MOUSE_BUTTON_LEFT and _selected:
			_selected.set_selected(false)
			_selected = null
			_aggiorna_pulsanti()

func _on_item_context(item: DesktopItem) -> void:
	_on_picked(item)     # il destro SELEZIONA anche, come in Win95: cosi' i pulsanti seguono
	var data: Dictionary = item.data
	var voci: Array = [[tr("EX_OPEN"), func(): _on_activated(data)]]
	# "Apri con Blocco note" su un'immagine: mostra i BYTE del file. C'e' perche' e' d'epoca
	# (era il modo di sbirciare dentro un file senza strumenti) e perche' una delle chiavi
	# del run puo' stare proprio la', nel commento del file, invece che nei pixel.
	if str(data.get("filetype", "")) == "image":
		voci.append([tr("EX_OPEN_NOTEPAD"), func(): os.open_app("notepad", data)])
	voci.append(["-"])
	var canc := Callable()
	if _eliminabile(data):
		canc = func(): _delete_item(data)
	voci.append([tr("EX_DELETE"), canc])       # grigia su unita', Cestino e cartella protetta
	voci.append([tr("EX_PROPERTIES"), Callable()])
	_show_menu(voci)

func _name_exists(n: String) -> bool:
	for c in _folder.get("children", []):
		if c.get("name", "") == n:
			return true
	return false

func _new_text_file() -> void:
	var base := tr("VFS_NEW_DOC")
	var fname := base + ".txt"
	var n := 1
	while _name_exists(fname):
		n += 1
		fname = "%s (%d).txt" % [base, n]
	var f := {"name": fname, "type": "file", "icon": "text", "filetype": "text", "content": "", "_parent": _folder}
	if not _folder.has("children"):
		_folder["children"] = []
	_folder["children"].append(f)
	_refresh()
	for it in _items:
		if is_same(it.data, f):
			_on_picked(it)
			break

func _delete_selected() -> void:
	if _selected:
		_delete_item(_selected.data)

func _delete_item(data) -> void:
	if VFS.is_trash(_folder):
		# gia' nel Cestino: l'eliminazione e' definitiva
		var ch: Array = _folder.get("children", [])
		for i in range(ch.size()):
			if is_same(ch[i], data):
				ch.remove_at(i)
				break
	else:
		VFS.move_to_trash(data)
	_refresh()
	if os and os.has_method("refresh_desktop"):
		os.refresh_desktop()   # aggiorna l'icona del Cestino sul desktop

# ---------------- menu contestuale ----------------

func _build_ctx() -> void:
	_ctx_layer = Control.new()
	_ctx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctx_layer.visible = false
	add_child(_ctx_layer)
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_chiudi_menu())
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

# Formato di una voce, lo stesso del browser: ["testo", Callable] attiva,
# ["testo", Callable()] DISABILITATA (callable non valido), ["-"] separatore.
func _riempi_menu(voci: Array) -> void:
	# queue_free() e NON free(): una voce che riapre un menu (l'"Informazioni su") chiama
	# questa funzione DA DENTRO il proprio segnale "pressed", e liberare subito quel
	# pulsante fa fallire Godot con "Object is locked and can't be freed" -- il menu
	# restava a meta' e l'About non si apriva. remove_child() lo toglie subito dal
	# contenitore, cosi' non conta piu' nella misura della tendina nuova.
	for c in _ctx_vbox.get_children():
		_ctx_vbox.remove_child(c)
		c.queue_free()
	var labels: Array = []
	for v in voci:
		var testo := str(v[0])
		if testo == "-":
			_ctx_vbox.add_child(Win95.menu_separator())
			continue
		var cb: Callable = v[1] if v.size() > 1 else Callable()
		var b := Button.new()
		b.text = testo
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		if cb.is_valid():
			b.pressed.connect(func():
				_chiudi_menu()
				cb.call())
		else:
			b.disabled = true
		_ctx_vbox.add_child(b)
		labels.append(testo)
	_ctx_panel.custom_minimum_size.x = maxf(Win95.menu_width(labels),
			_ctx_vbox.get_combined_minimum_size().x + 24.0)

func _mostra_menu(pos: Vector2) -> void:
	var w: float = maxf(_ctx_panel.custom_minimum_size.x, 150.0)
	var ht: float = _ctx_vbox.get_combined_minimum_size().y + 6.0
	pos.x = clampf(pos.x, 0.0, maxf(0.0, size.x - w))
	pos.y = clampf(pos.y, 0.0, maxf(0.0, size.y - ht))
	_ctx_panel.position = pos
	_ctx_panel.size = Vector2(w, ht)
	_ctx_layer.visible = true
	_ctx_layer.move_to_front()

# Menu contestuale: dove sta il mouse.
func _show_menu(items: Array) -> void:
	_riempi_menu(items)
	_mostra_menu(get_local_mouse_position())

# Tendina della barra dei menu: sotto il pulsante che l'ha chiesta, che resta premuto
# finche' e' aperta (cosi' si vede quale menu si sta guardando).
func _apri_menu(voci: Array, sotto: Control) -> void:
	if voci.is_empty():
		return
	_riempi_menu(voci)
	var giu: Vector2 = sotto.get_global_transform().origin - get_global_transform().origin
	giu.y += sotto.size.y
	_mostra_menu(giu)
	_menu_aperto = sotto as Button
	if _menu_aperto != null:
		_menu_aperto.toggle_mode = true
		_menu_aperto.set_pressed_no_signal(true)

func _chiudi_menu() -> void:
	_ctx_layer.visible = false
	if _menu_aperto != null:
		_menu_aperto.set_pressed_no_signal(false)
		_menu_aperto.toggle_mode = false
		_menu_aperto = null

# ---------------- le voci delle tendine ----------------
# Si ricostruiscono a ogni apertura: cosa e' attivo dipende dal momento (c'e' qualcosa di
# selezionato? si puo' creare qui? si puo' salire?).

func _voci_file() -> Array:
	var crea := Callable()
	if _si_puo_creare():
		crea = _new_text_file
	var apri := Callable()
	var canc := Callable()
	if _selected != null:
		var d: Dictionary = _selected.data
		apri = func(): _on_activated(d)
		if _eliminabile(d):
			canc = func(): _delete_item(d)
	var chiudi := Callable()
	if window != null:
		chiudi = func(): window.close()
	return [
		[tr("EX_NEW_TEXT"), crea],
		["-"],
		[tr("EX_OPEN"), apri],
		[tr("EX_DELETE"), canc],
		[tr("EX_PROPERTIES"), Callable()],
		["-"],
		[tr("NP_CLOSE"), chiudi],
	]

# Niente blocco appunti per i file, e la selezione e' di UNO alla volta: qui non c'e'
# niente di attivo, e il menu lo dice invece di non aprirsi.
func _voci_modifica() -> Array:
	return [
		[tr("NP_UNDO"), Callable()],
		["-"],
		[tr("NP_CUT"), Callable()],
		[tr("NP_COPY"), Callable()],
		[tr("NP_PASTE"), Callable()],
		["-"],
		[tr("NP_SELECT_ALL"), Callable()],
		[tr("EX_INVERT"), Callable()],
	]

func _voci_visualizza() -> Array:
	return [
		[tr("EX_TOOLBAR"), Callable()],
		[tr("EX_STATUSBAR"), Callable()],
		["-"],
		[_segna(tr("EX_LARGE_ICONS"), _vista == VISTA_GRANDI),
				func(): _imposta_vista(VISTA_GRANDI)],
		[_segna(tr("EX_SMALL_ICONS"), _vista == VISTA_PICCOLE),
				func(): _imposta_vista(VISTA_PICCOLE)],
		[tr("EX_LIST"), Callable()],
		[tr("EX_DETAILS"), Callable()],
		["-"],
		[tr("BR_REFRESH"), _refresh],
		[tr("EX_OPTIONS"), Callable()],
	]

# Il pallino davanti alla vista in uso: nelle tendine dell'epoca le scelte alternative si
# segnavano cosi', ed e' anche la risposta a "l'ho cliccata e non e' successo niente" --
# non succede niente perche' e' gia' quella.
func _segna(testo: String, attiva: bool) -> String:
	return ("* " if attiva else "   ") + testo

func _voci_strumenti() -> Array:
	return [
		[tr("EX_FIND"), Callable()],
		["-"],
		[tr("EX_MAP_DRIVE"), Callable()],
		[tr("EX_DISCONNECT"), Callable()],
	]

func _voci_aiuto() -> Array:
	return [
		[tr("BR_HELP_TOPICS"), Callable()],
		["-"],
		[tr("EX_ABOUT"), _informazioni],
	]

# Le cartelle sopra questa, dalla radice in giu': e' l'elenco della freccia nella barra
# dell'indirizzo.
func _voci_percorso() -> Array:
	var v: Array = []
	for n in _antenati():
		var nodo: Dictionary = n
		v.append([str(nodo.get("name", "?")), func(): _vai_a(nodo)])
	return v

# La finestrella "Informazioni su": nomi e versione sono quelli che il sistema mostra
# all'avvio (desktop.gd), non altri -- e' lo stesso programma.
func _informazioni() -> void:
	_riempi_menu([
		[tr("EX_ABOUT_NAME"), Callable()],
		["-"],
		[tr("BOOT_VERSION"), Callable()],
		[tr("EX_ABOUT_COPY"), Callable()],
		["-"],
		[tr("NP_CLOSE"), func(): pass],
	])
	_mostra_menu(Vector2(size.x * 0.22, size.y * 0.28))
