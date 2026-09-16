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
# Come e' allineato ogni carattere della pagina (vedi _mappa_allineamenti):
# l'engine dice quanto e' larga una riga ma non dove comincia, e questa mappa
# copre quel buco. Vuota = modello non attendibile, si usa il ripiego.
var _codici := PackedByteArray()
# Ripiego quando la mappa non c'e': quali allineamenti sono possibili nella pagina.
var _ha_centro := false
var _ha_destra := false

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

func _ready() -> void:
	# Con la rotellina il testo scorre SOTTO un mouse fermo: senza questo il
	# cursore resterebbe quello di prima fino al movimento successivo.
	get_v_scroll_bar().value_changed.connect(
			func(_v: float) -> void: _aggiorna_cursore(get_local_mouse_position()))
	# cambiando larghezza la pagina si rimpagina: la maschera vecchia descrive
	# un'altra disposizione e va rifatta (di solito il browser ricarica anche la
	# pagina, ma non va dato per scontato)
	resized.connect(func() -> void:
		_masc = null
		_masc_token += 1
		_masc_da_fare = true)

# Carica la pagina (BBCode). Ricalcola anche il cursore: la pagina cambia SOTTO
# il mouse fermo, quindi la forma giusta puo' essere un'altra.
func set_page(bbcode: String) -> void:
	_held = false
	_dragging = false
	_multi = false
	_ha_centro = bbcode.find("[center]") >= 0
	_ha_destra = bbcode.find("[right]") >= 0
	text = bbcode
	_mappa_allineamenti(bbcode)
	# la maschera NON si costruisce qui: disegnare il gemello e rileggerne i pixel
	# costa un fotogramma, e al caricamento ci si pesta i piedi con il primo clic o
	# trascinamento. Si fa al primo movimento del mouse sulla pagina (vedi
	# _gui_input): se il giocatore non ci passa mai sopra, non serve.
	_masc = null
	_masc_token += 1
	_masc_da_fare = true
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
		# mai mentre si tiene premuto: il disegno del gemello rubera' un fotogramma
		# e un trascinamento in corso ne soffrirebbe
		if _masc_da_fare and not _held:
			_masc_da_fare = false
			_prepara_maschera(text)
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

# I-beam solo dove c'e' davvero del testo, RIGA PER RIGA. Prima si guardava solo
# se il punto stava dentro l'altezza del contenuto, e quindi l'I-beam restava
# acceso su tutta la pagina: anche negli stacchi fra i paragrafi e nel vuoto a
# destra delle righe corte. L'engine sa dove sono le righe (get_line_offset /
# _height / _width) e quelle misure bastano.
func _forma_a(pos: Vector2) -> CursorShape:
	if pos.x < PAD or pos.x > size.x - PAD or pos.y < PAD:
		return Control.CURSOR_ARROW
	var scroll := 0.0
	var vs := get_v_scroll_bar()
	if vs != null:
		scroll = vs.value
	# get_line_offset e' relativo all'AREA DI CONTENUTO, che comincia PAD sotto il
	# bordo: per confrontarlo col mouse va rimesso lo stesso PAD (e lo scorrimento).
	var y: float = pos.y + scroll
	var riga := _riga_a(y)
	if riga < 0:
		return Control.CURSOR_ARROW               # stacco fra righe, o sotto il testo
	var larg: float = get_line_width(riga)
	if larg <= 0.0:
		return Control.CURSOR_ARROW               # riga vuota (il salto di paragrafo)
	var come := _allineamento_riga(riga)
	if come == A_NONTESTO:
		return Control.CURSOR_ARROW               # immagine, righello: non e' testo
	if _masc != null:
		# con la maschera si sa dove sono le lettere: vale per tutta la pagina, e
		# soprattutto DENTRO le tabelle, dove la larghezza della riga e' tutta la
		# tabella e quindi non distingue niente
		return Control.CURSOR_IBEAM if _testo_in(pos.x, y) else Control.CURSOR_ARROW
	return Control.CURSOR_IBEAM if _in_banda(pos.x, larg, come) else Control.CURSOR_ARROW

# Indice della riga la cui banda verticale contiene y (-1 se nessuna). Gli offset
# crescono con l'indice, quindi ricerca binaria: su una pagina lunga scandirle
# tutte a ogni movimento del mouse sarebbe spreco.
func _riga_a(y: float) -> int:
	var lo := 0
	var hi: int = get_line_count() - 1
	while lo <= hi:
		var mid: int = (lo + hi) / 2
		var cima: float = get_line_offset(mid) + PAD
		if y < cima:
			hi = mid - 1
		elif y > cima + get_line_height(mid):
			lo = mid + 1
		else:
			return mid
	return -1

# La riga e' larga "larg": con l'allineamento (dalla mappa) si sa anche DOVE
# comincia, e la banda del testo e' quella sola. Senza mappa (come = A_IGNOTO) si
# ripiega sull'unione delle posizioni possibili nella pagina: piu' larga del vero,
# ma mai in difetto. La scelta e' di non avere FALSI NEGATIVI -- sopra il testo
# l'I-beam c'e' sempre, ed e' quello che conta: dice "questo si puo' selezionare",
# e in questo gioco le chiavi si trovano proprio selezionando il testo.
func _in_banda(x: float, larg: float, come: int) -> bool:
	var utile: float = size.x - PAD * 2.0
	larg = minf(larg, utile)
	match come:
		A_SINISTRA:
			return x <= PAD + larg
		A_DESTRA:
			return x >= size.x - PAD - larg
		A_CENTRO:
			return absf(x - (PAD + utile * 0.5)) <= larg * 0.5
	# ripiego: l'unione delle posizioni che la pagina puo' avere
	if x <= PAD + larg:
		return true
	if _ha_destra and x >= size.x - PAD - larg:
		return true
	return _ha_centro and absf(x - (PAD + utile * 0.5)) <= larg * 0.5

# ---------------- mappa degli allineamenti ----------------

# Come e' allineato un carattere. A_NONTESTO = immagini e righelli: disegnano
# qualcosa ma non sono testo, e sopra ci va la freccia (come in un browser vero).
const A_SINISTRA := 0
const A_CENTRO := 1
const A_DESTRA := 2
const A_NONTESTO := 3
const A_IGNOTO := -1

# Tag che l'engine CONSUMA (non finiscono nel testo). Tutto il resto resta testo:
# una pagina puo' contenere parentesi quadre scritte a mano ("[discussione
# rimossa dai moderatori]" nel forum), che l'engine stampa come sono.
const TAG_NOTI := ["b", "i", "u", "s", "code", "color", "bgcolor", "fgcolor",
	"font", "font_size", "table", "cell", "url", "center", "left", "right",
	"fill", "indent", "ul", "ol", "li", "p", "img", "hr", "mono", "outline_size",
	"outline_color"]

# Ricostruisce l'allineamento di ogni carattere camminando il BBCode. Il punto
# delicato: contare i caratteri esattamente come l'engine. Invece di fidarsi si
# cammina IN PARALLELO al testo spogliato (get_parsed_text) e si avanza solo sui
# caratteri che combaciano; se alla fine non si e' consumato tutto il testo, il
# modello non regge e la mappa viene buttata (si ripiega su _in_banda senza
# allineamento). Cosi' un tag sconosciuto o un cambio di versione non producono
# un cursore sbagliato, solo uno piu' grossolano.
func _mappa_allineamenti(bb: String) -> void:
	_codici = PackedByteArray()
	var spogliato := get_parsed_text()
	if spogliato.is_empty():
		return
	var codici := PackedByteArray()
	codici.resize(spogliato.length())
	var pila: Array = [A_SINISTRA]         # allineamento corrente (annidabile)
	var in_tabella := 0                    # le tabelle possono essere annidate
	var all_tabella := A_SINISTRA          # allineamento della tabella piu' esterna
	var non_testo := 0                     # dentro [img]: quello che esce non e' testo
	var bi := 0
	var pi := 0
	while bi < bb.length() and pi < spogliato.length():
		if bb[bi] == "[":
			var fine: int = bb.find("]", bi)
			if fine > bi:
				var corpo: String = bb.substr(bi + 1, fine - bi - 1)
				var nome: String = corpo.split("=")[0].split(" ")[0]
				var chiude: bool = nome.begins_with("/")
				if chiude:
					nome = nome.substr(1)
				if TAG_NOTI.has(nome):
					match nome:
						"center", "left", "right":
							if chiude:
								if pila.size() > 1:
									pila.pop_back()
							else:
								pila.append(A_CENTRO if nome == "center" else (A_DESTRA if nome == "right" else A_SINISTRA))
						"table":
							if chiude:
								in_tabella = maxi(in_tabella - 1, 0)
							else:
								if in_tabella == 0:
									all_tabella = pila[pila.size() - 1]
								in_tabella += 1
						"img":
							non_testo += -1 if chiude else 1
					bi = fine + 1
					# immagini e righelli: l'engine mette UN carattere segnaposto
					# (uno spazio, oppure il carattere "oggetto" U+FFFC) dove
					# sta il disegno. Va marcato come non-testo, altrimenti la
					# riga della barretta invisibile che allarga le tabelle
					# (web/img/spacer.png) sembrerebbe testo.
					if (nome == "hr" or (nome == "img" and chiude)) and pi < spogliato.length():
						if spogliato[pi] == " " or spogliato.unicode_at(pi) == 0xFFFC:
							codici[pi] = A_NONTESTO
							pi += 1
					continue
		# testo: avanza sul testo spogliato solo se combacia
		if spogliato[pi] == bb[bi]:
			var come: int = all_tabella if in_tabella > 0 else int(pila[pila.size() - 1])
			codici[pi] = A_NONTESTO if non_testo > 0 else come
			pi += 1
		bi += 1
	if pi < spogliato.length():
		return                 # cammino non riuscito: meglio nessuna mappa
	_codici = codici

# Allineamento della riga (A_IGNOTO se la mappa non c'e', A_NONTESTO se la riga
# e' fatta solo di immagini o righelli).
func _allineamento_riga(riga: int) -> int:
	if _codici.is_empty():
		return A_IGNOTO
	var r := get_line_range(riga)
	var da: int = maxi(r.x, 0)
	var a: int = mini(r.y, _codici.size())
	while da < a:
		if _codici[da] != A_NONTESTO:
			return int(_codici[da])
		da += 1
	return A_NONTESTO if r.y > r.x else A_IGNOTO


# ---------------- maschera del testo ----------------

# Dove sono le LETTERE, alla lettera. Serve perche' per l'engine una TABELLA e'
# UNA RIGA SOLA alta tutto il blocco, e dentro non espone dove sono le celle
# (nessun metodo, ne' in 4.6 ne' in 4.7): la larghezza della riga e' la tabella
# intera, quindi dentro le tabelle il metodo delle righe non distingue niente.
# Percio' al caricamento la pagina viene ridisegnata UNA VOLTA fuori schermo, su
# fondo trasparente e con i colori di fondo azzerati: li' l'unica cosa che
# dipinge sono le lettere, e quanto coprono (il canale alpha) dice esattamente
# dove c'e' testo. L'immagine viene tenuta rimpicciolita di BLOCCO, cosi' ogni
# interrogazione costa un pixel, e sta in coordinate del CONTENUTO: scorrere la
# pagina non la invalida.
#
# Se qualcosa non torna (impaginato diverso, pagina troppo alta, disegno non
# pronto) la maschera non c'e' e si usa il metodo delle righe: piu' grossolano,
# mai in difetto.

const BLOCCO := 4               # lato del blocco della maschera, in pixel
const SOGLIA_TESTO := 0.05      # copertura minima di un blocco per dirlo "testo"
const MASC_ALT_MAX := 8192      # oltre non si disegna il gemello: meglio il ripiego

var _masc: Image = null
var _masc_token := 0
var _masc_da_fare := false     # la pagina e' cambiata: la maschera va rifatta

# Ridisegna la pagina fuori schermo e tiene la maschera. E' una coroutine: parte
# al caricamento e finisce un paio di fotogrammi dopo (fino ad allora il cursore
# usa il metodo delle righe). Il token annulla il lavoro se intanto la pagina
# cambia, cosi' due caricamenti ravvicinati non si scambiano la maschera.
func _prepara_maschera(bbcode: String) -> void:
	_masc = null
	_masc_token += 1
	var tok := _masc_token
	if not is_inside_tree() or size.x < 8.0:
		return
	await get_tree().process_frame                   # serve l'impaginato valido
	if not _masc_valida(tok):
		return
	var alt: int = int(ceilf(float(get_content_height()) + PAD * 2.0))
	if alt < 4 or alt > MASC_ALT_MAX:
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(int(size.x), alt)
	vp.transparent_bg = true                         # "dipinto" = "c'e' una lettera"
	vp.disable_3d = true
	vp.gui_disable_input = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var gemello := RichTextLabel.new()
	gemello.bbcode_enabled = true
	gemello.theme = _tema()
	gemello.autowrap_mode = autowrap_mode
	gemello.tab_size = tab_size
	gemello.scroll_active = false
	gemello.selection_enabled = false
	# la pagina vera ha degli override di tema (il browser le impone corpo 16 e un
	# suo stylebox): senza copiarli il gemello impagina con altre metriche
	_copia_tema(gemello)
	# fondo trasparente ma con gli STESSI margini, o il testo partirebbe altrove
	var sb := get_theme_stylebox("normal")
	var vuoto := StyleBoxEmpty.new()
	if sb != null:
		vuoto.content_margin_left = sb.get_margin(SIDE_LEFT)
		vuoto.content_margin_right = sb.get_margin(SIDE_RIGHT)
		vuoto.content_margin_top = sb.get_margin(SIDE_TOP)
		vuoto.content_margin_bottom = sb.get_margin(SIDE_BOTTOM)
	gemello.add_theme_stylebox_override("normal", vuoto)
	gemello.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# se la pagina vera mostra la barra di scorrimento il testo ha meno spazio: il
	# gemello deve andare a capo negli stessi punti
	var barra := get_v_scroll_bar()
	var largh: float = size.x - (barra.size.x if barra != null and barra.visible else 0.0)
	gemello.size = Vector2(largh, float(alt))
	gemello.text = _senza_fondi(bbcode)
	vp.add_child(gemello)
	add_child(vp)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if not _masc_valida(tok):
		vp.queue_free()
		return
	# controprova: il gemello deve aver impaginato IDENTICO, altrimenti la
	# maschera descrive un'altra pagina e si preferisce non averla
	var uguale: bool = gemello.get_line_count() == get_line_count()
	if uguale:
		for l in range(get_line_count()):
			if absf(gemello.get_line_offset(l) - get_line_offset(l)) > 1.0 \
					or absf(gemello.get_line_height(l) - get_line_height(l)) > 1.0:
				uguale = false
				break
	var img: Image = null
	if uguale:
		var tex := vp.get_texture()
		if tex != null:
			img = tex.get_image()
	vp.queue_free()
	if img == null or not _masc_valida(tok):
		return
	# rimpicciolire di BLOCCO in un colpo solo CAMPIONA invece di mediare (lo
	# stesso inciampo del puzzle della foto): si dimezza, e dimezzare e' una media
	# 2x2 vera. Dopo, l'alpha di un pixel = quanto testo copre quel blocco.
	var passi: int = int(log(float(BLOCCO)) / log(2.0))
	for i in range(passi):
		img.resize(maxi(img.get_width() / 2, 1), maxi(img.get_height() / 2, 1),
				Image.INTERPOLATE_BILINEAR)
	_masc = img

func _masc_valida(tok: int) -> bool:
	return tok == _masc_token and is_inside_tree()

# Vero se nel punto (x nella pagina, y nel contenuto) la maschera dice che c'e'
# testo. Si guarda anche il blocco a destra e a sinistra: fra due parole c'e' uno
# spazio vuoto, e senza quel margine il cursore lampeggerebbe scorrendo una riga.
# In verticale NON si allarga: lo stacco fra due righe di testo deve dare freccia.
func _testo_in(x: float, y: float) -> bool:
	if _masc == null:
		return false
	var bx: int = int(x) / BLOCCO
	var by: int = int(y) / BLOCCO
	if by < 0 or by >= _masc.get_height():
		return false
	for dx in [0, -1, 1]:
		var px: int = bx + dx
		if px >= 0 and px < _masc.get_width():
			if _masc.get_pixel(px, by).a > SOGLIA_TESTO:
				return true
	return false


# Nel gemello deve restare dipinto SOLO il testo. Quindi: fondi e bordi delle
# celle trasparenti, e trasparenti anche immagini e righelli -- che disegnano ma
# non sono testo, e sopra ci va la freccia come in un browser vero. I colori si
# SOSTITUISCONO, non si cancellano: bordi e immagini occupano spazio, e togliendoli
# l'impaginato cambierebbe e la maschera finirebbe fuori posto (provato: la
# controprova qui sopra scartava tutte le pagine con tabelle).
func _senza_fondi(bb: String) -> String:
	var re := RegEx.create_from_string(r"(\s(?:bg|border))=[^\s\]]+")
	var fuori: String = re.sub(bb, "$1=#00000000", true)
	re = RegEx.create_from_string(r"\[bgcolor=[^\]]*\]")
	fuori = re.sub(fuori, "[bgcolor=#00000000]", true)
	# via il colore proprio di immagini e righelli, poi lo si impone trasparente
	re = RegEx.create_from_string(r"(\[(?:img|hr)[^\]]*?)\s*color=[^\s\]]+")
	fuori = re.sub(fuori, "$1", true)
	re = RegEx.create_from_string(r"\[(img|hr)([^\]]*)\]")
	return re.sub(fuori, "[$1$2 color=#00000000]", true)

# Copia sul gemello gli elementi di tema che cambiano l'impaginato: caratteri,
# corpi e le spaziature (comprese quelle delle tabelle). get_theme_* legge il
# valore EFFETTIVO della pagina vera, override compresi, quindi non serve sapere
# chi li ha messi.
func _copia_tema(a: RichTextLabel) -> void:
	for nome in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
		var f := get_theme_font(nome)
		if f != null:
			a.add_theme_font_override(nome, f)
	for nome in ["normal_font_size", "bold_font_size", "italics_font_size",
			"bold_italics_font_size", "mono_font_size"]:
		a.add_theme_font_size_override(nome, get_theme_font_size(nome))
	for nome in ["line_separation", "paragraph_separation", "table_h_separation",
			"table_v_separation", "text_highlight_h_padding", "text_highlight_v_padding",
			"outline_size", "shadow_outline_size", "shadow_offset_x", "shadow_offset_y"]:
		if has_theme_constant(nome):
			a.add_theme_constant_override(nome, get_theme_constant(nome))

# Il tema con cui e' impaginata la pagina (di solito sta su un antenato).
func _tema() -> Theme:
	var n: Node = self
	while n != null:
		if n is Control and (n as Control).theme != null:
			return (n as Control).theme
		n = n.get_parent()
	return null
