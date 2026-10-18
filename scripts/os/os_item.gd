class_name DesktopItem
extends VBoxContainer

# Icona + etichetta selezionabile, usata sul desktop e dentro l'esplora risorse.
signal activated(data)        # doppio click / Invio
signal picked(item)           # singolo click (per la selezione singola del contenitore)
signal context_requested(item)  # tasto destro
signal rinomina_finita(item, nuovo_nome)   # Invio o clic altrove: il nome scritto va confermato

# I caratteri che un nome di file di Windows non puo' contenere. Si tolgono MENTRE si
# scrive invece di rifiutare il nome alla fine: cosi' non si perde quello che si e' scritto.
const VIETATI := "\\/:*?\"<>|"

var data: Dictionary = {}
var selected := false
var _icon: OSIcon
var _label: Label
var _label_color := Win95.C_TEXT
var _campo: LineEdit = null      # il riquadro di rinomina, solo mentre si rinomina

func setup(node_data: Dictionary, icon_size: int, label_w: int, label_color: Color) -> void:
	data = node_data
	custom_minimum_size = Vector2(label_w, icon_size + 40)
	alignment = BoxContainer.ALIGNMENT_BEGIN
	add_theme_constant_override("separation", 4)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_icon = OSIcon.new()
	_icon.kind = node_data.get("icon", "file")
	_icon.custom_minimum_size = Vector2(icon_size, icon_size)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_child(_icon)

	_label = Label.new()
	_label.text = node_data.get("name", "")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 16)
	_label_color = label_color
	_label.add_theme_color_override("font_color", label_color)
	_label.custom_minimum_size = Vector2(label_w, 0)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Ridisegnare QUANDO l'etichetta si sistema: _draw() legge la sua posizione, che al
	# primo disegno non e' ancora stata calcolata dal contenitore. Su un file appena
	# creato -- che nasce gia' selezionato -- il riquadro blu finiva sopra l'icona e il
	# testo bianco spariva sul fondo chiaro (segnalato dal proprietario, 20/09/2026), e
	# li' restava, perche' niente chiedeva un altro disegno.
	_label.item_rect_changed.connect(queue_redraw)
	add_child(_label)

# ---------------- rinomina (18/10/2026) ----------------
# Come in Win95: l'etichetta diventa un riquadro di testo col nome tutto selezionato.
# Invio conferma, ESC annulla, un clic altrove conferma. Il riquadro e' un LineEdit vero,
# quindi dentro funzionano la selezione col mouse e CTRL+C: e' il modo d'epoca per
# COPIARE un nome -- che qui serve, perche' una chiave del run puo' stare nel nome di una
# cartella. Copiare e poi ESC non cambia niente.
# Chi decide SE si puo' rinominare e' VFS.rinominabile; chi applica il nome nuovo e'
# chi ascolta rinomina_finita (il desktop o l'Esplora), via OSDesktop.rinomina_nodo.

func in_rinomina() -> bool:
	return _campo != null

func inizia_rinomina() -> void:
	if _campo != null:
		return
	_campo = LineEdit.new()
	_campo.set_meta("rinomina", true)        # cosi' il desktop lo riconosce (ESC, clic fuori)
	_campo.text = _label.text
	_campo.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_campo.max_length = 255
	_campo.add_theme_font_size_override("font_size", 16)
	_campo.custom_minimum_size = Vector2(_label.custom_minimum_size.x, 0)
	# il menu del tasto destro del LineEdit e' quello dell'ENGINE, in inglese in ogni lingua
	# e per niente Win95: CTRL+C / CTRL+V bastano, come bastavano allora
	_campo.context_menu_enabled = false
	_campo.text_changed.connect(_filtra)
	_campo.text_submitted.connect(func(_t): _chiudi_rinomina(true))
	# differito: il fuoco si perde DURANTE un clic, e confermare subito vorrebbe dire
	# ridisegnare la cartella mentre quel clic sta ancora cercando l'icona da colpire
	_campo.focus_exited.connect(func(): call_deferred("_chiudi_rinomina", true))
	_label.visible = false
	add_child(_campo)
	_campo.grab_focus()
	_campo.select_all()
	queue_redraw()

func annulla_rinomina() -> void:
	_chiudi_rinomina(false)

# Il clic fuori dal riquadro conferma (lo chiama il desktop, differito per la stessa
# ragione del fuoco perso).
func conferma_rinomina() -> void:
	call_deferred("_chiudi_rinomina", true)

func campo_rinomina() -> LineEdit:
	return _campo

func _chiudi_rinomina(conferma: bool) -> void:
	if _campo == null:
		return
	var c := _campo
	_campo = null      # PRIMA di toglierlo: toglierlo fa perdere il fuoco, che richiama qui
	var nuovo := c.text.strip_edges()
	remove_child(c)
	c.queue_free()
	_label.visible = true
	queue_redraw()
	if conferma and nuovo != "" and nuovo != str(data.get("name", "")):
		rinomina_finita.emit(self, nuovo)

func _filtra(t: String) -> void:
	var pulito := ""
	for ch in t:
		if VIETATI.find(ch) < 0:
			pulito += ch
	if pulito != t and _campo != null:
		var col := _campo.caret_column - (t.length() - pulito.length())
		_campo.text = pulito
		_campo.caret_column = maxi(0, col)

func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			picked.emit(self)
			if event.double_click:
				activated.emit(data)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			picked.emit(self)
			context_requested.emit(self)
			accept_event()

# Il riquadro della selezione: in Win95 abbracciava il TESTO, non tutta la casella. Se il
# nome sta su una riga si stringe attorno a lui; se va a capo si prende tutta la larghezza,
# che e' quanto occupa davvero.
func rett_selezione() -> Rect2:
	var r := _label.get_rect()
	var f := _label.get_theme_font("font")
	if f != null:
		var dim := _label.get_theme_font_size("font_size")
		var larga: float = f.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_CENTER,
				-1, dim).x + 6.0
		if larga < r.size.x:
			r.position.x += (r.size.x - larga) * 0.5
			r.size.x = larga
	return r

func _draw() -> void:
	if selected and _label and _campo == null:
		# evidenziazione blu dietro l'etichetta (non mentre si rinomina: c'e' il riquadro)
		var lr := rett_selezione()
		draw_rect(lr, Win95.C_SELECT)
		_label.add_theme_color_override("font_color", Win95.C_TITLE_TEXT)
	elif _label:
		_label.add_theme_color_override("font_color", _label_color)
