class_name OSIcon
extends Control

# Icone disegnate via codice (placeholder "provvisori" ma riconoscibili).
@export var kind: String = "file"

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_kind(k: String) -> void:
	kind = k
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	match kind:
		"folder":
			_folder(w, h)
		"folder_open":
			_folder(w, h, true)
		"locked":
			_locked(w, h)
		"computer":
			_computer(w, h)
		"web", "ie":
			_rete(w, h)
		"file", "text":
			_file(w, h)
		"floppy":
			_floppy(w, h)
		"hdd":
			_disco(w, h)
		"cdrom":
			_cd(w, h)
		"exe":
			_eseguibile(w, h)
		"smiley":
			_faccina(w, h)
		"image":
			_image(w, h)
		"notepad":
			_notepad(w, h)
		"trash":
			_trash(w, h)
		"trash_full":
			_trash(w, h, true)
		"whale", "win":
			_whale(w, h)
		"whale_pale":
			_whale(w, h, true)
		"globe":
			_rete(w, h)
		"back":
			_arrow_left(w, h)
		"up":
			_up(w, h)
		"cut":
			_cut(w, h)
		"copy":
			_copy(w, h)
		"paste":
			_paste(w, h)
		"delete":
			_delete(w, h)
		"props":
			_props(w, h)
		"views":
			_views(w, h)
		"dropdown":
			_dropdown(w, h)
		"fwd":
			_arrow_right(w, h)
		"stop":
			_stop(w, h)
		"refresh":
			_refresh(w, h)
		"home":
			_home(w, h)
		"star":
			_star(w, h)
		"print":
			_print(w, h)
		"search":
			_search(w, h)
		"speaker":
			_altoparlante(w, h)
		"speaker_muto":
			_altoparlante(w, h, true)
		_:
			_file(w, h)

func _outline(r: Rect2, c: Color) -> void:
	draw_rect(r, c, false, 1.0)

# Cartella. Ritocco del 18/10/2026 (proprietario: "rendere tutto coerente"): anche la
# LINGUETTA ha il contorno, come tutte le altre icone della serie (prima solo il corpo,
# e sul bianco dell'Esplora la linguetta si sfrangiava), e il davanti ha una riga chiara
# in alto, la piega del cartone delle cartelle Win95. La cartella APERTA prima era la
# stessa sagoma solo piu' chiara -- non sembrava aperta: ora il fondo resta dietro, piu'
# scuro, e il davanti si piega in avanti, piu' basso e inclinato.
func _folder(w: float, h: float, open := false) -> void:
	var bordo := Color("80631a")
	var tab := Rect2(w * 0.10, h * 0.24, w * 0.40, h * 0.14)
	draw_rect(tab, Color("c79a30"))
	_outline(tab, bordo)
	var body := Rect2(w * 0.08, h * 0.32, w * 0.84, h * 0.48)
	if not open:
		draw_rect(body, Color("f2c84b"))
		if h >= 24.0:
			draw_line(Vector2(body.position.x + 1, body.position.y + 1.5),
					Vector2(body.end.x - 1, body.position.y + 1.5), Color("ffe08a"), maxf(1.0, h * 0.03))
		_outline(body, bordo)
		return
	draw_rect(body, Color("c79a30"))
	_outline(body, bordo)
	var fronte := PackedVector2Array([
		Vector2(w * 0.22, h * 0.46), Vector2(w * 0.97, h * 0.46),
		Vector2(w * 0.86, h * 0.80), Vector2(w * 0.08, h * 0.80)])
	draw_colored_polygon(fronte, Color("ffd866"))
	draw_polyline(fronte + PackedVector2Array([fronte[0]]), bordo, 1.0)

func _locked(w: float, h: float) -> void:
	# cartella con un lucchetto sopra (nodo "secret")
	_folder(w, h)
	var body := Rect2(w * 0.40, h * 0.50, w * 0.34, h * 0.30)
	var c := Vector2(body.position.x + body.size.x * 0.5, body.position.y)
	# staffa del lucchetto
	draw_arc(c, w * 0.11, deg_to_rad(180.0), deg_to_rad(360.0), 16, Color("3a3a3a"), 3.0)
	# corpo
	draw_rect(body, Color("e0c020"))
	_outline(body, Color("6a5600"))
	# buco della chiave
	draw_circle(body.position + body.size * Vector2(0.5, 0.45), w * 0.035, Color("3a3a3a"))

func _computer(w: float, h: float) -> void:
	var mon := Rect2(w * 0.14, h * 0.12, w * 0.72, h * 0.52)
	draw_rect(mon, Color("c9c8b8"))
	_outline(mon, Color("5a5a50"))
	var scr := Rect2(w * 0.20, h * 0.18, w * 0.60, h * 0.38)
	draw_rect(scr, Color("0d6b6b"))
	var base := Rect2(w * 0.30, h * 0.64, w * 0.40, h * 0.10)
	draw_rect(base, Color("b6b5a6"))
	_outline(base, Color("5a5a50"))
	var kb := Rect2(w * 0.16, h * 0.78, w * 0.68, h * 0.12)
	draw_rect(kb, Color("d6d5c6"))
	_outline(kb, Color("5a5a50"))

# L'icona della RETE (desktop, menu Avvio, finestra del browser, file .html e il
# globo che lampeggia accanto all'indirizzo). Prima era una "e" azzurra con
# l'anello giallo in orbita, cioe' il logo di Internet Explorer: lo stesso
# problema della bandiera di Windows sul pulsante Avvio.
#
# Adesso (18/10/2026, scelta del proprietario: "globo a rete") e' un MAPPAMONDO
# d'epoca: oceano blu, due continenti verdi abbozzati e sopra la RETE di meridiani e
# paralleli -- il browser si chiama WebNet, e la rete del globo e' il suo marchio. La
# versione prima era un globo con due sole linee che galleggiava su due righe d'acqua.
# I continenti sono inventati a occhio (nessuna carta vera: a 32 px non si
# riconoscerebbe comunque) e stanno dentro il 0.85 del raggio, cosi' il bordo scuro
# della sfera li chiude senza bisogno di ritagliarli.
# Il dettaglio scende con la misura, come per la balena: la griglia fitta solo da 32 px,
# a 24 un meridiano e l'equatore, sotto i 20 solo terra e equatore -- a 16-18 px (barra
# delle applicazioni, barra del titolo) tre linee chiare su un disco sono una macchia.
const _TERRA_OVEST := [
	Vector2(-0.55, -0.62), Vector2(-0.30, -0.70), Vector2(-0.18, -0.50),
	Vector2(-0.30, -0.28), Vector2(-0.22, -0.05), Vector2(-0.30, 0.15),
	Vector2(-0.18, 0.40), Vector2(-0.28, 0.72), Vector2(-0.42, 0.60),
	Vector2(-0.48, 0.30), Vector2(-0.62, 0.05), Vector2(-0.75, -0.25),
	Vector2(-0.70, -0.48)]
const _TERRA_EST := [
	Vector2(0.18, -0.72), Vector2(0.42, -0.66), Vector2(0.55, -0.45),
	Vector2(0.40, -0.30), Vector2(0.62, -0.18), Vector2(0.70, 0.05),
	Vector2(0.55, 0.30), Vector2(0.40, 0.58), Vector2(0.25, 0.45),
	Vector2(0.22, 0.18), Vector2(0.10, 0.0), Vector2(0.15, -0.25),
	Vector2(0.08, -0.48)]

func _rete(w: float, h: float) -> void:
	var s: float = min(w, h)
	var o := Vector2((w - s) * 0.5, (h - s) * 0.5)
	var mare := Color("1f5fae")
	var terra := Color("3f9a4a")
	var rete := Color(0.75, 0.9, 0.98, 0.7)
	var scuro := Color("0d3c75")
	var c := o + Vector2(s * 0.5, s * 0.5)
	# raggio generoso: accanto a cartella e monitor un globo piccolo sembrava
	# un'icona di un'altra serie
	var r: float = s * 0.40
	var sp: float = maxf(s * 0.02, 1.0)

	draw_circle(c, r, mare)
	for forma in [_TERRA_OVEST, _TERRA_EST]:
		var pts := PackedVector2Array()
		for p in forma:
			pts.append(c + (p as Vector2) * r)
		draw_colored_polygon(pts, terra)

	# la rete: l'equatore sempre (dritto da piccolo, curvo come i paralleli quando ci
	# sono anche loro); poi meridiani e paralleli man mano che c'e' posto. Linee sottili e
	# un po' trasparenti: piene e fitte, alla prima prova, il globo sembrava una gabbia e i
	# continenti sparivano sotto.
	var grande := s >= 40.0
	var medio := s >= 28.0
	if medio:
		draw_polyline(_arco_ellisse(c, r, r * 0.22, 0.0, PI), rete, sp)
	else:
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), rete, sp)
	if s >= 20.0:
		draw_line(c - Vector2(0, r), c + Vector2(0, r), rete, sp)
		draw_polyline(_ellisse(c, r * (0.50 if grande else 0.58), r), rete, sp)
	if grande:
		draw_polyline(_ellisse(c, r * 0.87, r), rete, sp)
	if medio:
		# i paralleli si vedono di tre quarti: e' l'arco DAVANTI (quello in basso) di
		# un'ellisse schiacciata, ed e' questo a dare la curvatura della sfera
		for lat in ([-0.62, -0.31, 0.31, 0.62] if grande else [-0.5, 0.5]):
			var semi: float = r * cos(asin(lat))
			draw_polyline(_arco_ellisse(c + Vector2(0, r * lat), semi, semi * 0.22, 0.0, PI),
					rete, sp)
		# riflesso in alto a sinistra: fa sembrare una palla e non un disco
		draw_circle(c + Vector2(-r * 0.42, -r * 0.45), r * 0.16, Color(1, 1, 1, 0.35))

	# il bordo scuro per ultimo: chiude la griglia e stacca la palla dal grigio della
	# barra (senza, sul grigio sfuma)
	draw_circle(c, r, scuro, false, sp * 1.4)

# Un tratto di ellisse da a0 a a1 (radianti; y verso il basso, come lo schermo).
func _arco_ellisse(c: Vector2, rx: float, ry: float, a0: float, a1: float, passi := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(passi + 1):
		var a: float = lerpf(a0, a1, float(i) / float(passi))
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

# Punti di un'ellisse chiusa: draw_arc fa solo cerchi, e un globo senza ellissi
# non si legge.
func _ellisse(c: Vector2, rx: float, ry: float, passi := 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(passi + 1):
		var a: float = TAU * float(i) / float(passi)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

# Foglio di testo con l'orecchia. L'orecchia stava FUORI dal foglio (un triangolo grigio
# appeso al bordo destro, ritoccato il 18/10/2026): ora e' l'angolo del foglio stesso,
# tagliato e ripiegato in dentro, come in tutte le icone di documento dell'epoca.
func _file(w: float, h: float) -> void:
	var page := Rect2(w * 0.22, h * 0.10, w * 0.56, h * 0.80)
	var p0 := page.position
	var p1 := page.end
	var piega: float = w * 0.16
	var bordo := Color("404040")
	var foglio := PackedVector2Array([p0, Vector2(p1.x - piega, p0.y),
			Vector2(p1.x, p0.y + piega), p1, Vector2(p0.x, p1.y)])
	draw_colored_polygon(foglio, Color.WHITE)
	draw_polyline(foglio + PackedVector2Array([p0]), bordo, 1.0)
	var orecchia := PackedVector2Array([Vector2(p1.x - piega, p0.y),
			Vector2(p1.x - piega, p0.y + piega), Vector2(p1.x, p0.y + piega)])
	draw_colored_polygon(orecchia, Color("d8d8d8"))
	draw_polyline(orecchia + PackedVector2Array([orecchia[0]]), bordo, 1.0)
	# righe di testo, sotto l'orecchia; da piccolo tre, o diventano una macchia grigia
	var righe := 4 if h >= 24.0 else 3
	for i in range(righe):
		var ly: float = p0.y + piega + h * (0.10 + i * 0.13)
		draw_line(Vector2(p0.x + 3, ly), Vector2(p1.x - 3, ly), Color("8a8a8a"), 1.0)

# ---------------- unita' e programmi ----------------
# Le tre unita' di "Risorse del computer" e l'icona di un eseguibile. Servono perche'
# l'albero del filesystem adesso elenca A:, C: e D: come faceva il sistema vero: con
# l'icona della cartella su tutte e tre, quella finestra non somiglierebbe a niente.
# Come la balena e il globo, hanno un LOD: sotto i 24 px i dettagli minuti (le righe
# dell'etichetta, la spia, i tasti) spariscono invece di impastarsi.

# Floppy da 3,5": corpo scuro, otturatore metallico in alto, etichetta chiara in basso.
func _floppy(w: float, h: float) -> void:
	var body := Rect2(w * 0.12, h * 0.12, w * 0.76, h * 0.76)
	draw_rect(body, Color("2f3a4a"))
	_outline(body, Color("151b24"))
	var shutter := Rect2(w * 0.36, h * 0.14, w * 0.30, h * 0.24)
	draw_rect(shutter, Color("c8ccd2"))
	_outline(shutter, Color("6b7078"))
	draw_rect(Rect2(w * 0.47, h * 0.16, w * 0.08, h * 0.20), Color("8d939b"))
	var etichetta := Rect2(w * 0.22, h * 0.48, w * 0.56, h * 0.32)
	draw_rect(etichetta, Color("e8e8e0"))
	_outline(etichetta, Color("9a9a90"))
	if h >= 24.0:
		for i in range(2):
			draw_rect(Rect2(w * 0.26, h * (0.56 + i * 0.09), w * 0.48, maxf(1.0, h * 0.04)),
					Color("b9b9ae"))

# Disco fisso: il cassetto beige di un PC beige, con la fascia e la spia accesa.
func _disco(w: float, h: float) -> void:
	var box := Rect2(w * 0.08, h * 0.28, w * 0.84, h * 0.44)
	draw_rect(box, Color("c9c8b8"))
	_outline(box, Color("5a5a50"))
	draw_rect(Rect2(w * 0.12, h * 0.34, w * 0.76, h * 0.10), Color("dedcd0"))
	draw_rect(Rect2(w * 0.12, h * 0.56, w * 0.76, h * 0.10), Color("a3a296"))
	if h >= 24.0:
		draw_rect(Rect2(w * 0.76, h * 0.46, w * 0.08, h * 0.07), Color("3fbf3f"))

# CD-ROM: il disco visto in faccia, col foro e il riflesso.
func _cd(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.5)
	var r: float = minf(w, h) * 0.42
	draw_circle(c, r, Color("cfd4da"))
	if h >= 24.0:
		draw_arc(c, r * 0.78, -0.9, 0.5, 12, Color("eef3f8"), maxf(1.0, h * 0.06))
	draw_arc(c, r, 0.0, TAU, 28, Color("70767f"), maxf(1.0, h * 0.045))
	draw_circle(c, r * 0.40, Color("9aa3ad"))
	draw_circle(c, r * 0.17, Color("3a3f46"))

# Eseguibile: una finestrella con la barra del titolo blu, che e' come si disegnava un
# programma senza icona propria.
func _eseguibile(w: float, h: float) -> void:
	var box := Rect2(w * 0.14, h * 0.18, w * 0.72, h * 0.64)
	draw_rect(box, Color("d6d5c6"))
	_outline(box, Color("4a4a42"))
	draw_rect(Rect2(w * 0.16, h * 0.20, w * 0.68, h * 0.16), Color("000080"))
	if h >= 24.0:
		draw_rect(Rect2(w * 0.72, h * 0.23, w * 0.09, h * 0.10), Color("c0c0c0"))
		for i in range(3):
			draw_rect(Rect2(w * 0.20, h * (0.44 + i * 0.12), w * 0.40, maxf(1.0, h * 0.05)),
					Color("8a8a80"))

# Faccina gialla: l'icona del virus YouAreStupid (virus_stupido.gd). Sotto i 24 px la
# bocca diventa un trattino, perche' l'arco si impasterebbe.
func _faccina(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.5)
	var r: float = minf(w, h) * 0.40
	var tratto: float = maxf(1.0, h * 0.05)
	draw_circle(c, r, Color("ffd800"))
	draw_arc(c, r, 0.0, TAU, 24, Color("3a3000"), tratto)
	draw_circle(c + Vector2(-r * 0.36, -r * 0.25), maxf(1.0, r * 0.14), Color.BLACK)
	draw_circle(c + Vector2(r * 0.36, -r * 0.25), maxf(1.0, r * 0.14), Color.BLACK)
	if h >= 24.0:
		draw_arc(c + Vector2(0, r * 0.05), r * 0.55, PI * 0.15, PI * 0.85, 12, Color.BLACK, tratto)
	else:
		draw_rect(Rect2(c.x - r * 0.4, c.y + r * 0.35, r * 0.8, tratto), Color.BLACK)

func _image(w: float, h: float) -> void:
	# foto incorniciata: cielo, sole, una montagnola (icona "file immagine")
	var frame := Rect2(w * 0.16, h * 0.18, w * 0.68, h * 0.62)
	draw_rect(frame, Color("ffffff"))
	var pic := Rect2(frame.position.x + 3, frame.position.y + 3, frame.size.x - 6, frame.size.y - 6)
	draw_rect(pic, Color("8fc6e8"))   # cielo
	draw_circle(Vector2(pic.position.x + pic.size.x * 0.74, pic.position.y + pic.size.y * 0.28), w * 0.07, Color("f2d24b"))
	draw_colored_polygon(PackedVector2Array([   # montagna
		Vector2(pic.position.x, pic.end.y),
		Vector2(pic.position.x + pic.size.x * 0.42, pic.position.y + pic.size.y * 0.40),
		Vector2(pic.end.x, pic.end.y),
	]), Color("3f7a45"))
	_outline(frame, Color("404040"))

func _notepad(w: float, h: float) -> void:
	var page := Rect2(w * 0.20, h * 0.12, w * 0.58, h * 0.76)
	draw_rect(page, Color("ffffff"))
	_outline(page, Color("404040"))
	draw_rect(Rect2(page.position.x, page.position.y, page.size.x, h * 0.12), Color("1a4fa0"))
	for i in range(4):
		var ly := page.position.y + h * (0.34 + i * 0.13)
		draw_line(Vector2(page.position.x + 4, ly), Vector2(page.position.x + page.size.x - 4, ly), Color("9a9a9a"), 1.0)

func _trash(w: float, h: float, full := false) -> void:
	# FOGLI che sporgono quando il cestino e' pieno (disegnati prima del bidone, che ne
	# copre il fondo). Erano tre palline bianche (ritocco del 18/10/2026): fogli storti si
	# leggono come carta buttata, palline no.
	if full:
		for f in [[Vector2(0.38, 0.17), -0.35], [Vector2(0.58, 0.14), 0.25], [Vector2(0.49, 0.21), 0.05]]:
			_foglio_storto(Vector2(w, h) * (f[0] as Vector2), Vector2(w * 0.20, h * 0.22), float(f[1]))
	var lid := Rect2(w * 0.24, h * 0.20, w * 0.52, h * 0.08)
	draw_rect(lid, Color("9aa0a6"))
	_outline(lid, Color("4a4f54"))
	var can := PackedVector2Array([
		Vector2(w * 0.28, h * 0.30), Vector2(w * 0.72, h * 0.30),
		Vector2(w * 0.66, h * 0.84), Vector2(w * 0.34, h * 0.84),
	])
	draw_colored_polygon(can, Color("b6bcc2"))
	draw_polyline(can + PackedVector2Array([can[0]]), Color("4a4f54"), 1.0)

func _arrow_left(w: float, h: float) -> void:
	var cy := h * 0.5
	var col := Color("123a7a")
	draw_rect(Rect2(w * 0.42, cy - h * 0.09, w * 0.32, h * 0.18), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.20, cy), Vector2(w * 0.46, cy - h * 0.24), Vector2(w * 0.46, cy + h * 0.24),
	]), col)

# Un foglio ruotato (centro, misura, angolo in radianti): la carta del cestino pieno.
func _foglio_storto(c: Vector2, dim: Vector2, ang: float) -> void:
	var pts := PackedVector2Array()
	for v in [Vector2(-0.5, -0.5), Vector2(0.5, -0.5), Vector2(0.5, 0.5), Vector2(-0.5, 0.5)]:
		pts.append(c + ((v as Vector2) * dim).rotated(ang))
	draw_colored_polygon(pts, Color("f6f6f2"))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color("8a8f94"), 1.0)

func _up(w: float, h: float) -> void:
	var tab := Rect2(w * 0.14, h * 0.44, w * 0.30, h * 0.10)
	draw_rect(tab, Color("c79a30"))
	_outline(tab, Color("80631a"))     # come la linguetta delle cartelle
	var body := Rect2(w * 0.12, h * 0.52, w * 0.74, h * 0.34)
	draw_rect(body, Color("f2c84b"))
	_outline(body, Color("80631a"))
	var ax := w * 0.49
	draw_colored_polygon(PackedVector2Array([
		Vector2(ax, h * 0.12), Vector2(ax - w * 0.20, h * 0.40), Vector2(ax + w * 0.20, h * 0.40),
	]), Color("1a431f"))
	draw_rect(Rect2(ax - w * 0.07, h * 0.36, w * 0.14, h * 0.22), Color("1a431f"))

func _cut(w: float, h: float) -> void:
	var c1 := Vector2(w * 0.34, h * 0.70)
	var c2 := Vector2(w * 0.62, h * 0.70)
	draw_line(c1, Vector2(w * 0.74, h * 0.20), Color("808080"), 2.0)
	draw_line(c2, Vector2(w * 0.26, h * 0.20), Color("808080"), 2.0)
	draw_arc(c1, w * 0.10, 0, TAU, 14, Color("404040"), 2.0)
	draw_arc(c2, w * 0.10, 0, TAU, 14, Color("404040"), 2.0)

func _copy(w: float, h: float) -> void:
	var b := Rect2(w * 0.20, h * 0.16, w * 0.40, h * 0.52)
	draw_rect(b, Color.WHITE)
	_outline(b, Color("404040"))
	var f := Rect2(w * 0.36, h * 0.30, w * 0.40, h * 0.52)
	draw_rect(f, Color.WHITE)
	_outline(f, Color("404040"))
	for i in range(3):
		var ly := f.position.y + h * (0.12 + i * 0.12)
		draw_line(Vector2(f.position.x + 3, ly), Vector2(f.position.x + f.size.x - 4, ly), Color("8a8a8a"), 1.0)

func _paste(w: float, h: float) -> void:
	var board := Rect2(w * 0.20, h * 0.20, w * 0.58, h * 0.64)
	draw_rect(board, Color("b58a4a"))
	_outline(board, Color("5a3f1a"))
	draw_rect(Rect2(w * 0.40, h * 0.13, w * 0.18, h * 0.10), Color("9a9a9a"))
	var page := Rect2(w * 0.28, h * 0.30, w * 0.42, h * 0.46)
	draw_rect(page, Color.WHITE)
	_outline(page, Color("707070"))
	for i in range(2):
		var ly := page.position.y + h * (0.12 + i * 0.13)
		draw_line(Vector2(page.position.x + 3, ly), Vector2(page.position.x + page.size.x - 4, ly), Color("9a9a9a"), 1.0)

func _delete(w: float, h: float) -> void:
	var col := Color("c0241c")
	draw_line(Vector2(w * 0.28, h * 0.28), Vector2(w * 0.72, h * 0.72), col, 3.0)
	draw_line(Vector2(w * 0.72, h * 0.28), Vector2(w * 0.28, h * 0.72), col, 3.0)

func _props(w: float, h: float) -> void:
	var page := Rect2(w * 0.24, h * 0.14, w * 0.46, h * 0.72)
	draw_rect(page, Color.WHITE)
	_outline(page, Color("404040"))
	for i in range(3):
		var ly := page.position.y + h * (0.12 + i * 0.13)
		draw_line(Vector2(page.position.x + 4, ly), Vector2(page.position.x + page.size.x - 5, ly), Color("8a8a8a"), 1.0)
	draw_line(Vector2(w * 0.50, h * 0.62), Vector2(w * 0.60, h * 0.74), Color("1c8a2a"), 2.5)
	draw_line(Vector2(w * 0.60, h * 0.74), Vector2(w * 0.80, h * 0.44), Color("1c8a2a"), 2.5)

func _views(w: float, h: float) -> void:
	var col := Color("103a7a")
	var s := w * 0.30
	draw_rect(Rect2(w * 0.16, h * 0.16, s, s), col)
	draw_rect(Rect2(w * 0.54, h * 0.16, s, s), col)
	draw_rect(Rect2(w * 0.16, h * 0.54, s, s), col)
	draw_rect(Rect2(w * 0.54, h * 0.54, s, s), col)

func _dropdown(w: float, h: float) -> void:
	var cx := w * 0.5
	var cy := h * 0.5
	draw_colored_polygon(PackedVector2Array([
		Vector2(cx - w * 0.22, cy - h * 0.10), Vector2(cx + w * 0.22, cy - h * 0.10), Vector2(cx, cy + h * 0.16),
	]), Color.BLACK)

func _arrow_right(w: float, h: float) -> void:
	var cy := h * 0.5
	var col := Color("123a7a")
	draw_rect(Rect2(w * 0.26, cy - h * 0.09, w * 0.32, h * 0.18), col)
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.80, cy), Vector2(w * 0.54, cy - h * 0.24), Vector2(w * 0.54, cy + h * 0.24),
	]), col)

func _stop(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.5)
	var r: float = min(w, h) * 0.36
	draw_circle(c, r, Color("c0241c"))
	draw_line(c + Vector2(-r * 0.5, -r * 0.5), c + Vector2(r * 0.5, r * 0.5), Color.WHITE, 2.0)
	draw_line(c + Vector2(r * 0.5, -r * 0.5), c + Vector2(-r * 0.5, r * 0.5), Color.WHITE, 2.0)

# Altoparlante della barra (il volume, come in Win98): cassa grigia, cono nero e due onde.
# Zittito: niente onde, e il cerchio rosso sbarrato sopra.
func _altoparlante(w: float, h: float, muto := false) -> void:
	var s: float = min(w, h)
	var x0 := (w - s) * 0.5
	var y0 := (h - s) * 0.5
	var cassa := Rect2(x0 + s * 0.12, y0 + s * 0.36, s * 0.20, s * 0.28)
	draw_rect(cassa, Color("c0c0c0"))
	_outline(cassa, Color.BLACK)
	draw_colored_polygon(PackedVector2Array([
			Vector2(x0 + s * 0.32, y0 + s * 0.36), Vector2(x0 + s * 0.56, y0 + s * 0.14),
			Vector2(x0 + s * 0.56, y0 + s * 0.86), Vector2(x0 + s * 0.32, y0 + s * 0.64)]), Color("202020"))
	if not muto:
		var c := Vector2(x0 + s * 0.56, y0 + s * 0.5)
		var tratto: float = maxf(1.0, s * 0.07)
		draw_arc(c, s * 0.18, -0.9, 0.9, 8, Color.BLACK, tratto)
		draw_arc(c, s * 0.34, -0.9, 0.9, 10, Color.BLACK, tratto)
		return
	var cc := Vector2(x0 + s * 0.66, y0 + s * 0.62)
	var r := s * 0.26
	var rosso := Color("c0241c")
	var spessore: float = maxf(1.5, s * 0.09)
	draw_arc(cc, r, 0.0, TAU, 16, rosso, spessore)
	draw_line(cc + Vector2(-r, -r) * 0.7, cc + Vector2(r, r) * 0.7, rosso, spessore)

# Aggiorna: freccia circolare. Ritoccata il 18/10/2026: il tratto era fisso a 2.5 px
# (filo sottile a 48 px) e la punta minuscola, quindi a 16 px si leggeva una "U". Ora
# tratto e punta crescono con l'icona, e la punta segue la direzione dell'arco.
func _refresh(w: float, h: float) -> void:
	var s: float = min(w, h)
	var c := Vector2(w * 0.5, h * 0.54)
	var r: float = s * 0.30
	var col := Color("1c7a2a")
	var tratto: float = maxf(2.0, s * 0.10)
	var a0 := deg_to_rad(-40.0)
	var a1 := deg_to_rad(225.0)
	draw_arc(c, r, a0, a1, 28, col, tratto)
	# la punta: in avanti lungo la tangente, larga a cavallo dell'arco
	var radiale := Vector2(cos(a1), sin(a1))
	var avanti := Vector2(-sin(a1), cos(a1))
	var testa := c + radiale * r
	var lun: float = s * 0.22
	draw_colored_polygon(PackedVector2Array([
		testa + avanti * lun,
		testa - radiale * lun * 0.75,
		testa + radiale * lun * 0.75,
	]), col)

func _home(w: float, h: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(w * 0.5, h * 0.14), Vector2(w * 0.86, h * 0.50), Vector2(w * 0.14, h * 0.50),
	]), Color("8a2f2f"))
	var body := Rect2(w * 0.26, h * 0.48, w * 0.48, h * 0.36)
	draw_rect(body, Color("d9c39a"))
	_outline(body, Color("5a4a30"))
	draw_rect(Rect2(w * 0.44, h * 0.62, w * 0.15, h * 0.22), Color("6a4a2a"))

func _star(w: float, h: float) -> void:
	var c := Vector2(w * 0.5, h * 0.52)
	var rad_out: float = min(w, h) * 0.40
	var rad_in := rad_out * 0.45
	var pts := PackedVector2Array()
	for i in range(10):
		var ang := deg_to_rad(-90.0 + i * 36.0)
		var rr := rad_out if i % 2 == 0 else rad_in
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	draw_colored_polygon(pts, Color("efc63c"))

func _print(w: float, h: float) -> void:
	var paper := Rect2(w * 0.26, h * 0.14, w * 0.48, h * 0.24)
	draw_rect(paper, Color.WHITE)
	_outline(paper, Color("707070"))
	var body := Rect2(w * 0.16, h * 0.38, w * 0.68, h * 0.30)
	draw_rect(body, Color("9aa0a6"))
	_outline(body, Color("4a4f54"))
	draw_rect(Rect2(w * 0.72, h * 0.46, w * 0.06, h * 0.06), Color("2fae4a"))
	var out := Rect2(w * 0.30, h * 0.60, w * 0.40, h * 0.22)
	draw_rect(out, Color.WHITE)
	_outline(out, Color("707070"))

# Cerca: la lente. Ritoccata il 18/10/2026: come "aggiorna" aveva il tratto fisso (filo a
# 48 px); ora cresce con l'icona, il vetro e' azzurrino col riflesso e il manico e' scuro
# e piu' spesso -- una lente, non un cerchio con una riga.
func _search(w: float, h: float) -> void:
	var s: float = min(w, h)
	var c := Vector2(w * 0.42, h * 0.40)
	var r: float = s * 0.25
	var col := Color("123a7a")
	draw_line(c + Vector2(r, r) * 0.72, Vector2(w * 0.84, h * 0.84), Color("2a2a2a"),
			maxf(3.0, s * 0.13))
	draw_circle(c, r, Color("cfe7f7"))
	if s >= 24.0:
		draw_arc(c, r * 0.6, deg_to_rad(200.0), deg_to_rad(260.0), 8, Color.WHITE, maxf(1.0, s * 0.04))
	draw_arc(c, r, 0, TAU, 24, col, maxf(2.0, s * 0.07))

# Il logo del sistema: la balena di "52-hz Whale". (Prima era una bandiera a
# quattro riquadri, cioe' quella di Windows: il tema dell'OS e' un'altra cosa.)
# Deve leggersi anche a 18 px nella taskbar, quindi e' fatta di pochi pezzi grossi
# e senza contorni, che a quella misura chiuderebbero la figura. Quello che la
# distingue da un pesce sono tre cose, e vanno tenute: corpo lungo con la testa
# enorme e la linea della bocca, NIENTE pinna dorsale, e la coda attaccata da un
# peduncolo sottile. Piu' lo sbuffo, che la dichiara da lontano.
# pallida = la stessa balena per fondi scuri (la striscia del menu Start): con i
# colori normali, blu su blu, la sagoma non si vedrebbe.
func _whale(w: float, h: float, pallida := false) -> void:
	var s: float = min(w, h)
	var o := Vector2((w - s) * 0.5, (h - s) * 0.5)
	var corpo := Color("bfe2fa") if pallida else Color("14539e")
	var ombra := Color("7fbde8") if pallida else Color("0d3c75")
	var chiaro := Color("4b93cf") if pallida else Color("8fd0f2")
	# coda: un remo largo con l'incavo, i lobi spazzati in alto (e' una pinna
	# ORIZZONTALE vista di sbieco: se fosse una V simmetrica sarebbe un pesce)
	draw_colored_polygon(_poly(o, s, [
		0.72, 0.505, 0.86, 0.425, 0.99, 0.285, 0.93, 0.455,
		0.99, 0.545, 0.90, 0.585, 0.78, 0.545,
	]), corpo)
	# corpo: muso smussato a sinistra, groppa lunga, poi il peduncolo sottile
	draw_colored_polygon(_poly(o, s, [
		0.035, 0.545,
		0.035, 0.49, 0.065, 0.435, 0.135, 0.395, 0.25, 0.37, 0.40, 0.375,
		0.55, 0.405, 0.66, 0.455, 0.745, 0.495,
		0.745, 0.535, 0.65, 0.555,
		0.52, 0.605, 0.36, 0.645, 0.20, 0.645, 0.09, 0.605,
	]), corpo)
	# pinna pettorale: piccola e bassa
	draw_colored_polygon(_poly(o, s, [0.25, 0.625, 0.375, 0.64, 0.275, 0.765]), ombra)
	# pancia chiara lungo il bordo di sotto
	draw_colored_polygon(_poly(o, s, [
		0.06, 0.575, 0.17, 0.635, 0.35, 0.635, 0.51, 0.59, 0.645, 0.545,
		0.62, 0.515, 0.49, 0.56, 0.34, 0.595, 0.18, 0.595, 0.08, 0.545,
	]), chiaro)
	# bocca e occhio solo da 24 px in su: sotto quella misura sono due macchie
	# che sporcano il muso invece di descriverlo
	if s >= 24.0:
		draw_line(o + Vector2(s * 0.04, s * 0.535), o + Vector2(s * 0.225, s * 0.60),
				ombra, maxf(s * 0.028, 1.0))
		draw_circle(o + Vector2(s * 0.125, s * 0.50), maxf(s * 0.024, 0.7),
				Color("1b4f8c") if pallida else Color("eaf5ff"))
	# sbuffo dallo sfiatatoio: da grande tre getti, da piccolo due piu' spessi
	# (tre righe da un pixel attaccate diventano una macchia sola)
	var getto: float = maxf(s * 0.045, 2.0)
	var sfiato := o + Vector2(s * 0.19, s * 0.385)
	var getti := [Vector2(0.125, 0.175), Vector2(0.195, 0.125), Vector2(0.275, 0.185)]
	if s < 30.0:
		getti = [Vector2(0.11, 0.165), Vector2(0.30, 0.165)]
	for punta in getti:
		draw_line(sfiato, o + Vector2(s * punta.x, s * punta.y), chiaro, getto)

# Da coppie x,y in 0..1 ai punti veri dentro il quadrato dell'icona: le sagome
# restano scritte a misura unitaria e reggono qualsiasi dimensione.
func _poly(o: Vector2, s: float, xy: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var k := 0
	while k < xy.size():
		pts.append(o + Vector2(s * float(xy[k]), s * float(xy[k + 1])))
		k += 2
	return pts
