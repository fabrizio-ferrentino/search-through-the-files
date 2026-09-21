class_name OSWindow
extends Control

# Finestra in stile Win95: cornice 3D, barra titolo trascinabile, pulsanti, area contenuto.
signal closed(win)
signal minimized(win)
signal title_changed(win)

const BORDER := 4
const TITLE_H := 30
const RESIZE_MARGIN := 8     # spessore del bordo "afferrabile" per ridimensionare
const RESIZE_CORNER := 24    # vicino agli angoli la zona di presa si allarga (resize diagonale)

# Lati toccati per il ridimensionamento (combinabili come flag).
enum { EDGE_L = 1, EDGE_R = 2, EDGE_T = 4, EDGE_B = 8 }

var os                      # riferimento al desktop (OSDesktop)
var win_title := "Finestra"
var icon_kind := "file"
var active := false

var content_root: Control   # qui le app aggiungono la loro UI
var _title_label: Label
var _icon: OSIcon
var _btn_min: GlyphButton
var _btn_max: GlyphButton
var _btn_close: GlyphButton

var _dragging := false
var _drag_off := Vector2.ZERO
var _maximized := false
var _restore_rect := Rect2()

# "Mostra il contenuto delle finestre durante il trascinamento" SPENTO, come era per
# default su Win95: si vede solo il contorno tratteggiato e la finestra salta alla
# geometria nuova al rilascio (richiesta del proprietario, 21/09/2026). Non era solo
# gusto: ridisegnare il contenuto a ogni pixel era troppo per quelle macchine -- e qui
# ha lo stesso effetto collaterale buono, perche' una pagina del browser non rifa'
# l'impaginazione delle tabelle a ogni movimento del mouse, ma una volta sola.
# Due interruttori STATICI (come ATTESA_ATTIVA del browser) perche' l'originale le
# trattava come una cosa sola: per avere il contorno SOLO sul ridimensionamento basta
# CONTORNO_SPOSTA = false, e mettendoli entrambi a false si torna al comportamento
# "dal vivo" di prima. I test li ribaltano per davvero: un interruttore collegato a
# niente e' peggio che non averlo.
static var CONTORNO_RIDIMENSIONA := true
static var CONTORNO_SPOSTA := true

var _resizing := false
var _resize_edges := 0
var _resize_start_mouse := Vector2.ZERO
var _resize_start_rect := Rect2()

var _fantasma := false               # questo trascinamento sta mostrando il contorno
var _fantasma_rect := Rect2()        # la geometria che il contorno sta promettendo

func setup(title: String, win_size: Vector2, ikind: String) -> void:
	win_title = title
	icon_kind = ikind
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(220, 120)
	size = win_size
	clip_contents = true

	_icon = OSIcon.new()
	_icon.kind = ikind
	add_child(_icon)

	_title_label = Label.new()
	_title_label.text = title
	_title_label.add_theme_color_override("font_color", Win95.C_TITLE_TEXT)
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.clip_text = true
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_label)

	_btn_min = GlyphButton.new()
	_btn_min.glyph = "min"
	_btn_min.pressed.connect(_on_min)
	add_child(_btn_min)

	_btn_max = GlyphButton.new()
	_btn_max.glyph = "max"
	_btn_max.pressed.connect(toggle_max)
	add_child(_btn_max)

	_btn_close = GlyphButton.new()
	_btn_close.glyph = "close"
	_btn_close.pressed.connect(close)
	add_child(_btn_close)

	content_root = Control.new()
	content_root.clip_contents = true
	content_root.anchor_right = 1.0
	content_root.anchor_bottom = 1.0
	# inset = RESIZE_MARGIN: lascia scoperto un bordo abbastanza largo da afferrare
	# per il ridimensionamento (il contenuto non copre la zona di presa)
	content_root.offset_left = RESIZE_MARGIN
	content_root.offset_top = BORDER + TITLE_H
	content_root.offset_right = -RESIZE_MARGIN
	content_root.offset_bottom = -RESIZE_MARGIN
	add_child(content_root)

	_layout_titlebar()

func set_title(t: String) -> void:
	win_title = t
	if _title_label:
		_title_label.text = t
	title_changed.emit(self)

func set_active(v: bool) -> void:
	active = v
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_titlebar()
	elif what == NOTIFICATION_EXIT_TREE:
		_abbandona_trascinamento()

func _layout_titlebar() -> void:
	if not _btn_close:
		return
	var bs := Vector2(22, 20)
	var by := BORDER + (TITLE_H - bs.y) / 2.0
	var bx := size.x - BORDER - 3 - bs.x
	_btn_close.position = Vector2(bx, by)
	_btn_close.size = bs
	bx -= bs.x + 2
	_btn_max.position = Vector2(bx, by)
	_btn_max.size = bs
	bx -= bs.x
	_btn_min.position = Vector2(bx, by)
	_btn_min.size = bs

	_icon.position = Vector2(BORDER + 5, BORDER + (TITLE_H - 18) / 2.0)
	_icon.size = Vector2(18, 18)
	_title_label.position = Vector2(BORDER + 28, BORDER)
	_title_label.size = Vector2(max(0.0, bx - (BORDER + 30)), TITLE_H)

func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Win95.C_FACE)
	# barra titolo
	var tcol := Win95.C_TITLE if active else Win95.C_TITLE_OFF
	draw_rect(Rect2(BORDER, BORDER, size.x - 2 * BORDER, TITLE_H), tcol)
	Win95.bevel_rid(get_canvas_item(), r, true)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if event.pressed:
			# 1) bordo della finestra -> ridimensionamento (disattivo se ingrandita)
			var edges := 0 if _maximized else _edges_at(mb.position)
			if edges != 0:
				_resizing = true
				_resize_edges = edges
				_resize_start_mouse = get_global_mouse_position()
				_resize_start_rect = Rect2(position, size)
				_fantasma = CONTORNO_RIDIMENSIONA and _contorno_disponibile()
				if _fantasma:
					_mostra_fantasma(_resize_start_rect)
				accept_event()
				return
			# 2) barra titolo -> trascina (doppio click = ingrandisci/ripristina)
			var in_title: bool = mb.position.y >= BORDER and mb.position.y <= BORDER + TITLE_H \
				and mb.position.x > BORDER and mb.position.x < size.x - BORDER
			if in_title:
				if event.double_click:
					toggle_max()
				else:
					_dragging = true
					_drag_off = get_global_mouse_position() - global_position
					_fantasma = CONTORNO_SPOSTA and _contorno_disponibile()
					if _fantasma:
						_mostra_fantasma(Rect2(position, size))
				accept_event()
		else:
			# IL SALTO: fin qui si e' visto solo il contorno, la geometria nuova si
			# applica tutta insieme adesso.
			if _fantasma and (_dragging or _resizing):
				position = _fantasma_rect.position
				size = _fantasma_rect.size
			_spegni_contorno()
			_dragging = false
			_resizing = false
	elif event is InputEventMouseMotion:
		if _resizing:
			var r := _rect_resize(get_global_mouse_position())
			if _fantasma:
				_mostra_fantasma(r)
			else:
				position = r.position
				size = r.size
			accept_event()
		elif _dragging:
			# dal globale alle coordinate del genitore (e' li' che vive position), poi
			# dentro lo schermo: la finestra si ferma al bordo, non ci passa sotto
			var p := get_global_mouse_position() - _drag_off - (global_position - position)
			var d := Rect2(_dentro(p, size), size)
			if _fantasma:
				_mostra_fantasma(d)
			else:
				position = d.position
			accept_event()

# ---------------- il contorno tratteggiato ----------------
# Il contorno lo disegna il DESKTOP (OSDesktop._build_contorno): deve stare sopra tutte
# le finestre e uscire dai bordi di questa, che ha clip_contents. Senza desktop -- una
# finestra costruita da sola in un test, o un'app che la usa fuori dall'OS -- si
# ridimensiona dal vivo come prima, invece di non far niente.
func _contorno_disponibile() -> bool:
	return os != null and os.has_method("mostra_contorno")

# Il rettangolo va al desktop in coordinate GLOBALI: la finestra ragiona in coordinate
# del genitore (e' li' che vive position), il contorno vive altrove nell'albero.
func _mostra_fantasma(r: Rect2) -> void:
	_fantasma_rect = r
	os.mostra_contorno(Rect2(r.position + (global_position - position), r.size))

func _spegni_contorno() -> void:
	if _fantasma and _contorno_disponibile():
		os.nascondi_contorno()
	_fantasma = false

# Se la finestra spariva mentre la si trascinava (minimizzata, chiusa, tolta dall'
# albero) il contorno resterebbe disegnato su uno schermo dove non si muove piu' niente.
func _abbandona_trascinamento() -> void:
	_spegni_contorno()
	_dragging = false
	_resizing = false

# ---------------- il confine dello schermo ----------------
# Il monitor del gioco e' un 4:3 FISSO: quello che una finestra si porta oltre il bordo
# non si vede piu' e col mouse non si recupera -- non c'e' un secondo schermo dove
# spingerla, ne' un desktop piu' grande da scorrere. Percio' trascinamento e
# ridimensionamento si fermano al bordo, come succede su un PC vero (richiesta del
# proprietario, 20/09/2026).
#
# L'AREA UTILE e' lo schermo meno la barra delle applicazioni: la stessa che riempie
# l'ingrandimento, cosi' una finestra spinta in basso e una ingrandita arrivano
# esattamente allo stesso punto invece di fermarsi a due altezze diverse.
func area_utile() -> Rect2:
	var p := get_parent_control()
	var s: Vector2 = p.size if p != null else size
	return Rect2(Vector2.ZERO, Vector2(s.x, maxf(0.0, s.y - OSDesktop.TASKBAR_H)))

# La posizione piu' vicina a quella chiesta che tiene TUTTA la finestra dentro l'area.
# Se la finestra e' piu' grande dell'area resta incollata in alto a sinistra: meglio
# perdere il bordo destro che la barra del titolo, che e' l'unica presa che ha.
func _dentro(p: Vector2, s: Vector2) -> Vector2:
	var a := area_utile()
	return Vector2(
		clampf(p.x, a.position.x, maxf(a.position.x, a.end.x - s.x)),
		clampf(p.y, a.position.y, maxf(a.position.y, a.end.y - s.y)))

# Rimette la finestra dentro lo schermo. La chiama il desktop appena l'ha aperta, e
# serve a chiunque cambi posizione o dimensione da codice: il confine e' rispettato
# da chi trascina, ma niente impedisce a un'app di piazzarsi fuori.
func assesta() -> void:
	if _maximized:
		return
	var a := area_utile()
	var minimo := custom_minimum_size
	size = Vector2(clampf(size.x, minimo.x, maxf(minimo.x, a.size.x)),
			clampf(size.y, minimo.y, maxf(minimo.y, a.size.y)))
	position = _dentro(position, size)

# --- Ridimensionamento in stile Win95: si "afferra" il bordo 3D della finestra ---

# Lati toccati dal punto (combinazione di EDGE_*). I bordi hanno spessore
# RESIZE_MARGIN; vicino agli angoli la zona si allarga (RESIZE_CORNER) per il
# trascinamento diagonale.
func _edges_at(pos: Vector2) -> int:
	var w := size.x
	var h := size.y
	var e := 0
	if pos.x <= RESIZE_MARGIN:
		e |= EDGE_L
	elif pos.x >= w - RESIZE_MARGIN:
		e |= EDGE_R
	if pos.y <= RESIZE_MARGIN:
		e |= EDGE_T
	elif pos.y >= h - RESIZE_MARGIN:
		e |= EDGE_B
	# se siamo gia' su un lato, estendi all'angolo piu' vicino
	if e != 0:
		if pos.x <= RESIZE_CORNER:
			e |= EDGE_L
		elif pos.x >= w - RESIZE_CORNER:
			e |= EDGE_R
		if pos.y <= RESIZE_CORNER:
			e |= EDGE_T
		elif pos.y >= h - RESIZE_CORNER:
			e |= EDGE_B
	return e

# La geometria che il ridimensionamento vuole: lato opposto ancorato, dimensione
# minima rispettata, tutto dentro lo schermo. E' un CONTO e non un effetto, perche' il
# contorno ha bisogno dello stesso numero senza toccare la finestra -- e cosi' il
# contorno non puo' promettere una geometria che il rilascio poi correggerebbe.
func _rect_resize(gm: Vector2) -> Rect2:
	var d := gm - _resize_start_mouse
	var r := _resize_start_rect
	var minw := custom_minimum_size.x
	var minh := custom_minimum_size.y
	var new_pos := r.position
	var new_size := r.size
	# ...e nemmeno tirando un bordo si esce dallo schermo: il lato che si trascina si
	# ferma al confine, quello opposto resta inchiodato dov'e' (altrimenti la finestra
	# scivolerebbe mentre la si allarga)
	var a := area_utile()
	if _resize_edges & EDGE_L:
		new_size.x = maxf(minw, r.size.x - d.x)
		new_pos.x = r.position.x + r.size.x - new_size.x
		if new_pos.x < a.position.x:
			new_pos.x = a.position.x
			new_size.x = maxf(minw, r.position.x + r.size.x - new_pos.x)
	elif _resize_edges & EDGE_R:
		new_size.x = clampf(r.size.x + d.x, minw, maxf(minw, a.end.x - new_pos.x))
	if _resize_edges & EDGE_T:
		new_size.y = maxf(minh, r.size.y - d.y)
		new_pos.y = r.position.y + r.size.y - new_size.y
		if new_pos.y < a.position.y:
			new_pos.y = a.position.y
			new_size.y = maxf(minh, r.position.y + r.size.y - new_pos.y)
	elif _resize_edges & EDGE_B:
		new_size.y = clampf(r.size.y + d.y, minh, maxf(minh, a.end.y - new_pos.y))
	return Rect2(new_pos, new_size)

# Forma del cursore (Control.CursorShape) per la combinazione di lati data.
# La stanza la applica al ColorRect dell'overlay: _get_cursor_shape() non basta
# perche' non si propaga quando l'input e' inoltrato al SubViewport.
func _cursor_for_edges(e: int) -> int:
	var l := bool(e & EDGE_L)
	var r := bool(e & EDGE_R)
	var t := bool(e & EDGE_T)
	var b := bool(e & EDGE_B)
	if (t and l) or (b and r):
		return Control.CURSOR_FDIAGSIZE
	if (t and r) or (b and l):
		return Control.CURSOR_BDIAGSIZE
	if l or r:
		return Control.CURSOR_HSIZE
	if t or b:
		return Control.CURSOR_VSIZE
	return Control.CURSOR_ARROW

func is_resizing() -> bool:
	return _resizing

# Forma del cursore desiderata per un punto in coordinate locali alla finestra.
# La interroga la stanza per pilotare il cursore reale sull'overlay del PC.
func cursor_at(local_pos: Vector2) -> int:
	if _resizing:
		return _cursor_for_edges(_resize_edges)
	if _maximized:
		return Control.CURSOR_ARROW
	return _cursor_for_edges(_edges_at(local_pos))

func _on_min() -> void:
	_abbandona_trascinamento()
	minimized.emit(self)

func toggle_max() -> void:
	if _maximized:
		_maximized = false
		position = _restore_rect.position
		size = _restore_rect.size
		assesta()      # il rettangolo salvato era buono per lo schermo di allora
	else:
		_maximized = true
		_restore_rect = Rect2(position, size)
		position = Vector2.ZERO
		# riempi lo schermo lasciando spazio alla taskbar
		var screen: Vector2 = get_parent_control().size if get_parent_control() else size
		size = Vector2(screen.x, screen.y - OSDesktop.TASKBAR_H)
	_layout_titlebar()

func close() -> void:
	_abbandona_trascinamento()
	closed.emit(self)
	queue_free()
