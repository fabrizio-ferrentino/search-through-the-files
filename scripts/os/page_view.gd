class_name PageView
extends RichTextLabel

# La PAGINA del browser: un RichTextLabel che si comporta come un browser vero.
#
# Perche' una sottoclasse e non il nodo nudo: in 4.6 il RichTextLabel decide da
# solo clic/selezione/cursore, e nel gioco (input inoltrato dentro una
# SubViewport, finestra scalata) il risultato e' sbagliato:
#  - mentre tieni premuto, un TIMER interno estende la selezione anche se non
#    trascini -> un clic fermo selezionava un'intera frase;
#  - l'engine emette meta_clicked (link) solo se NON c'e' una selezione attiva,
#    quindi 2-3 px di tremolio della mano uccidevano il link;
#  - il cursore era una sola proprieta' per tutto il controllo, cambiata dai
#    segnali meta_hover_*, che dentro una SubViewport con input inoltrato non
#    scattano mai (vedi player.gd::_set_os_mouse_in): restava l'I-beam fisso.
#
# Qui: il tremolio sotto SOGLIA viene BLOCCATO (accept_event), al rilascio di un
# clic senza trascinamento la selezione viene azzerata (cosi' il link scatta), e
# la forma del cursore viene riassegnata a ogni movimento (_aggiorna_cursore).
# Il resto (selezione col trascinamento, parola col doppio clic) lo fa l'engine:
# gli lasciamo passare gli eventi che gli servono.
#
# Comportamenti coperti dal test tests/browser_click_test.tscn.

# Oltre questi pixel (logici, nello spazio del SubViewport) il movimento col tasto
# premuto e' un TRASCINAMENTO. Sotto e' un CLIC: la mano trema sempre un po' e in
# finestra 1280x720 su viewport 1920 un pixel fisico vale ~1.5 px logici.
const DRAG_SOGLIA := 6.0

# Margine interno della pagina (deve combaciare con lo stylebox "normal").
const PAD := 18.0

var _press_pos := Vector2.ZERO
var _held := false
var _dragging := false
var _multi := false               # doppio/triplo clic: la selezione va tenuta

func _init() -> void:
	bbcode_enabled = true
	fit_content = false
	scroll_active = true
	selection_enabled = true
	context_menu_enabled = false            # il menu contestuale e' quello del browser
	shortcut_keys_enabled = false           # Ctrl+C / Ctrl+A li gestisce il browser
	focus_mode = Control.FOCUS_CLICK
	deselect_on_focus_loss_enabled = false
	drag_and_drop_selection_enabled = false # niente DnD dentro la SubViewport
	autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mouse_default_cursor_shape = Control.CURSOR_ARROW

# Carica la pagina (BBCode). Ricalcola anche il cursore: la pagina cambia SOTTO
# il mouse fermo, quindi la forma giusta puo' essere un'altra.
func set_page(bbcode: String) -> void:
	_held = false
	_dragging = false
	_multi = false
	text = bbcode
	get_v_scroll_bar().value = 0
	_aggiorna_cursore(get_local_mouse_position())

# ---------------- clic, trascinamento, selezione ----------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_held = true
			_dragging = false
			_press_pos = event.position
			_multi = event.double_click
			# Come in un browser vero il clic azzera la selezione; MA non al
			# doppio clic, altrimenti cancelleremmo la parola che l'engine sta
			# per selezionare subito dopo di noi.
			if not _multi:
				deselect()
		else:
			_held = false
			# Clic "fermo": nessuna selezione residua (il timer interno tende a
			# crearla comunque). Va fatto PRIMA che l'engine gestisca il rilascio:
			# meta_clicked scatta solo se la selezione non e' attiva.
			if not _dragging and not _multi:
				deselect()
			_dragging = false
			_multi = false
	elif event is InputEventMouseMotion:
		_aggiorna_cursore(event.position)
		if _held and not _dragging:
			if event.position.distance_to(_press_pos) < DRAG_SOGLIA:
				accept_event()      # tremolio: non deve diventare una selezione
			else:
				_dragging = true    # da qui in poi l'engine estende la selezione

# ---------------- cursore ----------------

# RichTextLabel::get_cursor_shape() fa GIA' l'hit-test dei link (mano) e mentre
# tieni premuto forza l'I-beam; per tutto il resto ritorna il "default cursor" del
# controllo. Quindi a noi basta tenere aggiornato QUEL default: col nodo nudo era
# I-beam fisso, percio' la freccetta "I" restava attiva su tutta la pagina, vuoto
# compreso. (get_cursor_shape non e' sovrascrivibile da script in Godot 4.)
func _aggiorna_cursore(pos: Vector2) -> void:
	mouse_default_cursor_shape = _forma_a(pos)

# I-beam solo dove c'e' davvero del testo: dentro i margini e sopra la fine del
# contenuto. Nel resto della pagina (margini e vuoto sotto il testo) freccia.
func _forma_a(pos: Vector2) -> CursorShape:
	if pos.x < PAD or pos.x > size.x - PAD or pos.y < PAD:
		return Control.CURSOR_ARROW
	var scroll := 0.0
	var vs := get_v_scroll_bar()
	if vs != null:
		scroll = vs.value
	var fine_testo: float = minf(float(get_content_height()) - scroll, size.y)
	if pos.y > fine_testo:
		return Control.CURSOR_ARROW
	return Control.CURSOR_IBEAM
