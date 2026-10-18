class_name Apparizione
extends Node

# Un'APPARIZIONE della maledizione dentro il PC (M5, proprietario 18/10/2026). E' il virus
# mortale ed e' anche il FALSO ALLARME: una cosa sola, con UNA regola -- se sparisce in un
# attimo era falso, se RESTA e' vero e bisogna spegnere il PC prima che uccida. Niente fasi:
# un'apparizione non diventa mai un'altra cosa (il proprietario ha scartato la versione
# "prima piccola, poi sangue"); nel vero cresce piano, ma resta se stessa.
# Le tre garanzie perche' sia difficile ma giusto:
#   1 il falso dura meno di SOGLIA_FALSO e poi sparisce DEL TUTTO; il vero non sparisce mai;
#   2 all'inizio sono IDENTICI: stessa comparsa (COMPARSA), stesso posto -- solo il tempo li
#     distingue (il vero cresce in "crescita" secondi, a 0.3 s la differenza non si vede);
#   3 nessuna regola nascosta: cio' che il vero ha in piu' e' solo "di piu' dello stesso".
# SETTE TIPI. Le cinque PICCOLE stanno SOLO nella carta da parati (sopra_sfondo: sotto icone e
# finestre) o nell'orologio -- il proprietario le vuole "di poco conto"; una versione che
# spegneva tutto lo schermo, rinominava le icone e metteva il bambino sopra le finestre e'
# stata provata e scartata perche' troppo invasiva:
#   "buio"      la carta da parati si scurisce;
#   "bambino"   la maledizione si MOSTRA (GDD §2b: l'origine e' il ragazzo, il bambino e' la
#               forma che prende): un BAMBINO (maschio: la maledizione e' maschile)
#               impiccato, vicino al bordo destro dello sfondo, come SAGOMA SCURA -- ma con
#               un contorno vero: proporzioni da bambino, capelli corti spettinati, orecchie,
#               maniche, pantaloncini, pollici, piedi in punta, la testa piegata troppo, il
#               nodo e la corda; bordi sfumati, un alone scuro attorno (la carta da parati
#               si scurisce vicino a lui), un'ombra, e dondola e gira piano. Storia, perche'
#               non torni: la prima sagoma, fatta di forme tonde, "era ridicola"; una figura
#               realistica a colori (bambina in camicia da notte, poi bambino di spalle con
#               la maglietta) "non fa paura" -- il proprietario vuole il buio, con la forma
#               giusta. Mai il viso, niente di macabro. Se esiste IMMAGINE_BAMBINO si usa
#               quella;
#   "occhi"     due occhi piccoli e chiari nello sfondo, che guardano il cursore;
#   "orologio"  l'ora della barra sbaglia (all'indietro, 03:33, --:--);
#   "scritte"   una frase della maledizione (VIRUS_SCRITTA_*) appena leggibile nello sfondo.
# Le due GRAVI (scelte dal proprietario) sono apparizioni come le altre, stessa regola:
#   "sangue"    cola dal bordo alto, sopra le finestre ma sotto barra e menu Avvio: un orlo
#               che gonfia, colate che scendono a strappi (viscose, non pioggia) con la
#               goccia in punta (fusa col corpo, mai una pallina), e ogni tanto una
#               goccia che si stacca e cade lasciando una scia;
#   "tremito"   le finestre tremano a scatti (si sposta il CONTENITORE: pulisci lo rimette).
# C'era una terza grave, "lampeggio" (lo schermo che lampeggiava di rosso): tolta, al
# proprietario non piaceva per niente -- non rimetterla.
# Quale esce lo decidono i PESI (scegli). Nessuno strato prende il mouse; pulisci() rimette
# tutto com'era.

signal finita

const TIPI := ["buio", "bambino", "occhi", "orologio", "scritte", "sangue", "tremito"]
const PICCOLE := ["buio", "bambino", "occhi", "orologio", "scritte"]
const PESI := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]   # stesso ordine di TIPI
const SOGLIA_FALSO := 3.0          # un falso allarme dura SEMPRE meno di questo
const COMPARSA := 0.25             # secondi per comparire (uguale per vero e falso)
const IMMAGINE_BAMBINO := "res://assets/textures/virus/bambino.png"
const SCRITTE := ["VIRUS_SCRITTA_1", "VIRUS_SCRITTA_2", "VIRUS_SCRITTA_3",
		"VIRUS_SCRITTA_4", "VIRUS_SCRITTA_5", "VIRUS_SCRITTA_6"]
const OROLOGI := ["03:33", "--:--", "88:88", "00:00", "33:03"]
const GOCCE := 28                  # colate (60 tutte uguali sembravano un codice a barre)
const GOCCE_SUBITO := 9            # quelle che partono subito: anche un falso deve far vedere il sangue
const PASSO_ORLO := 48.0           # l'orlo in alto: un punto ogni tanti px, raccordati
const GRAVITA := 1400.0            # le gocce che si staccano
const C_OMBRA := Color(0.03, 0.015, 0.02)
# --- il bambino ---
const SCALA_BAMBINO := 1.1           # la figura e' alta ~340 unita': ~370 px su uno schermo da 1080
const C_SAGOMA := Color(0.022, 0.016, 0.02)       # quasi nero
const C_CORDA := Color(0.14, 0.11, 0.08)          # la corda, scura in controluce
const C_CORDA_SCURA := Color(0.05, 0.035, 0.025)
const INCLINA_TESTA := 0.55          # piegata TROPPO: il collo non la regge
const TESTA_RX := 25.5               # testa grande: e' un bambino
const TESTA_RY := 30.0
const NODO := Vector2(-17, -50)      # dove la corda arriva al nodo (sopra le spire)
# I contorni GREZZI (collo in 0,0, y in giu'), ammorbiditi con _liscia. Proporzioni di un
# bambino di 7-8 anni: testa ~1/6 dell'altezza, spalle strette e cadenti, braccia lungo i
# fianchi, piedi in punta (pende). Il lato destro e' il sinistro specchiato (_specchia),
# appena spostato: due lati identici sembrano un manichino. In una sagoma conta SOLO il
# contorno, quindi i dettagli che lo rendono vero stanno sul bordo: maniche, orlo dei
# pantaloncini, ginocchia, pollici, orecchie, capelli spettinati.
# Le braccia pendono un po' STACCATE dal busto: in una sagoma un braccio senza uno spiraglio
# di luce accanto si fonde col corpo e sparisce.
const _MAGLIA := [Vector2(-9, 6), Vector2(-22, 10), Vector2(-32, 17), Vector2(-31, 48),
		Vector2(-28, 70), Vector2(-27, 100), Vector2(-30, 119), Vector2(-16, 122), Vector2(0, 120),
		Vector2(16, 123), Vector2(30, 119), Vector2(27, 100), Vector2(28, 70), Vector2(31, 48),
		Vector2(32, 17), Vector2(22, 10), Vector2(9, 6)]
const _MANICA := [Vector2(-31, 15), Vector2(-42, 24), Vector2(-48, 49), Vector2(-34, 52),
		Vector2(-29, 26)]
const _BRACCIO := [Vector2(-44, 46), Vector2(-35, 46), Vector2(-36, 78), Vector2(-37, 112),
		Vector2(-38, 134), Vector2(-36, 146), Vector2(-38, 160), Vector2(-43, 164), Vector2(-47, 159),
		Vector2(-49, 146), Vector2(-48, 134), Vector2(-47, 112), Vector2(-46, 78)]
const _POLLICE := [Vector2(-38, 138), Vector2(-34, 141), Vector2(-33, 150), Vector2(-36, 152),
		Vector2(-38, 147)]
const _CALZONI := [Vector2(-32, 110), Vector2(32, 110), Vector2(33, 138), Vector2(35, 166),
		Vector2(4, 169), Vector2(1, 147), Vector2(-1, 147), Vector2(-4, 169), Vector2(-35, 166),
		Vector2(-33, 138)]
const _GAMBA := [Vector2(-25, 158), Vector2(-5, 158), Vector2(-6, 188), Vector2(-6, 198),
		Vector2(-7, 204), Vector2(-7, 224), Vector2(-8, 240), Vector2(-19, 240), Vector2(-20, 224),
		Vector2(-21, 204), Vector2(-22, 198), Vector2(-23, 188)]
const _PIEDE := [Vector2(-19.5, 236), Vector2(-7.5, 236), Vector2(-8, 250), Vector2(-9, 263),
		Vector2(-12, 274), Vector2(-16, 270), Vector2(-18, 256)]
const _COLLO := [Vector2(-9, 9), Vector2(9, 9), Vector2(12, -8), Vector2(6, -22), Vector2(-6, -18)]
# l'ordine in cui si disegnano le parti (tutte dello stesso colore: conta il contorno)
const _PARTI := ["gamba_sx", "gamba_dx", "piede_sx", "piede_dx", "calzoni", "collo", "maglia",
		"manica_sx", "manica_dx", "braccio_sx", "braccio_dx", "pollice_sx", "pollice_dx", "testa",
		"capelli", "orecchio_sx", "orecchio_dx"]
const C_SANGUE_SCURO := Color(0.19, 0.0, 0.015)    # in alto, dove si rapprende
const C_SANGUE := Color(0.40, 0.0, 0.03)           # il corpo
const C_SANGUE_VIVO := Color(0.60, 0.02, 0.05)     # la punta, fresca

var tipo := ""
var durata := 0.0          # > 0: falso allarme, sparisce da solo dopo questi secondi
var crescita := 0.0        # > 0: vero, l'intensita' arriva a 1 in questi secondi
var intensita := 0.0       # 0..1

var _os: OSDesktop = null
var _rng: RandomNumberGenerator = null
var _t := 0.0
var _fatta := false
var _sfondo: Control = null        # piccole: uno strato sulla carta da parati
var _velo: ColorRect = null        # buio
var _scritte: Array = []           # scritte: le Label sulla carta da parati
var _sangue: Control = null        # sangue: sopra le finestre
var _passo := 0.0
var _minuti := 0
var _occhi: Array = []             # [centro, larghezza, fase del battito, nato a (s)]
var _bambino := Vector2.ZERO       # dove sta il collo
var _bambino_tex: Texture2D = null
var _gruppo: CanvasGroup = null    # bambino: la figura si sfuma IN BLOCCO (vedi setup)
var _figura_nodo: Node2D = null
var _parti := {}                   # bambino: nome -> contorno pronto (PackedVector2Array)
var _gocce: Array = []             # una Dictionary per colata (vedi setup)
var _cadute: Array = []            # gocce staccate: [posizione, velocita']
var _orlo: PackedFloat32Array = PackedFloat32Array()
var _orlo_fase := 0.0

# Un tipo a caso secondo i PESI.
static func scegli(rng: RandomNumberGenerator) -> String:
	var tot := 0.0
	for p in PESI:
		tot += float(p)
	var x := rng.randf() * tot
	for i in range(TIPI.size()):
		x -= float(PESI[i])
		if x <= 0.0:
			return TIPI[i]
	return TIPI[TIPI.size() - 1]

func setup(os: OSDesktop, che_tipo: String, rng: RandomNumberGenerator) -> void:
	_os = os
	_rng = rng
	tipo = che_tipo
	name = "Apparizione"
	var area := Vector2(os.size.x, os.size.y - OSDesktop.TASKBAR_H)
	match tipo:
		"buio":
			_velo = ColorRect.new()
			_velo.name = "Apparizione_buio"
			_velo.color = Color(0, 0, 0, 0)
			_velo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			os.sopra_sfondo(_velo)
			_velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		"bambino", "occhi":
			_sfondo = Control.new()
			_sfondo.name = "Apparizione_" + tipo
			_sfondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_sfondo.draw.connect(_disegna_sfondo)
			os.sopra_sfondo(_sfondo)
			_sfondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			if tipo == "bambino":
				if ResourceLoader.exists(IMMAGINE_BAMBINO):
					_bambino_tex = load(IMMAGINE_BAMBINO)
				# vicino al bordo destro: a sinistra ci sono le icone del desktop
				_bambino = Vector2(area.x * _rng.randf_range(0.80, 0.86), area.y * 0.30)
				# Un CanvasGroup: la figura si disegna OPACA e il gruppo la sfuma tutta
				# insieme. Pezzi semitrasparenti uno sull'altro (braccio sulla maglietta,
				# capelli sul collo) lascerebbero vedere le giunture.
				_gruppo = CanvasGroup.new()
				_gruppo.name = "Figura"       # non "Apparizione*": i test contano quelli
				_gruppo.self_modulate.a = 0.0
				_sfondo.add_child(_gruppo)
				_figura_nodo = Node2D.new()
				_figura_nodo.draw.connect(_disegna_bambino)
				_gruppo.add_child(_figura_nodo)
				_prepara_bambino()
				_figura_nodo.transform = _posa_bambino()
			else:
				_aggiungi_occhi()
		"orologio":
			var t := Time.get_time_dict_from_system()
			_minuti = int(t.hour) * 60 + int(t.minute)
			_cambia_orologio()
		"scritte":
			_aggiungi_scritta()
		"sangue":
			_sangue = Control.new()
			_sangue.name = "Apparizione_sangue"
			_sangue.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_sangue.draw.connect(_disegna_sangue)
			os.sopra_finestre(_sangue)
			_sangue.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_orlo.resize(int(os.size.x / PASSO_ORLO) + 2)
			for i in range(_orlo.size()):
				_orlo[i] = _rng.randf_range(0.55, 1.3)
			for i in range(4):
				_orlo[_rng.randi() % _orlo.size()] = _rng.randf_range(1.6, 2.2)   # qualche sacca gonfia
			_orlo_fase = _rng.randf_range(0.0, TAU)
			for i in range(GOCCE):
				var subito := i < GOCCE_SUBITO
				_gocce.append({
					"x": _rng.randf_range(8.0, os.size.x - 8.0),
					# qualcuna grossa; sotto i 6-7 px, lunghe, sembravano spaghi
					"w": lerpf(6.5, 20.0, pow(_rng.randf(), 1.4)),
					"v": _rng.randf_range(60.0, 150.0),
					# le prime subito, le altre si aggiungono nei secondi dopo
					"parte": 0.0 if subito else _rng.randf_range(0.4, 16.0),
					"lun": 0.0,
					# fin dove arriva: quasi tutte corte, poche fino in fondo
					"max": lerpf(50.0, os.size.y, pow(_rng.randf(), 1.7)),
					"f": _rng.randf_range(1.4, 3.0),
					# le prime partono di slancio (spinta al massimo), le altre a caso
					"ph": PI * 0.5 if subito else _rng.randf_range(0.0, TAU),
					"amp": _rng.randf_range(0.8, 3.5),
					"m": _rng.randf_range(0.0, TAU),
				})

# Quanto e' "comparsa" adesso (0..1): uguale per vero e falso.
func comparsa() -> float:
	return smoothstep(0.0, COMPARSA, _t)

func attiva() -> bool:
	return not _fatta

func grave() -> bool:
	return not PICCOLE.has(tipo)

func _process(delta: float) -> void:
	avanza(delta)

# Il passo, pubblico perche' i test (e VirusMortale) lo fanno girare a mano.
func avanza(delta: float) -> void:
	if _fatta:
		return
	_t += delta
	if crescita > 0.0:
		intensita = clampf(_t / crescita, 0.0, 1.0)
	if durata > 0.0 and _t >= durata:
		pulisci()
		return
	match tipo:
		"buio":
			_velo.color.a = clampf(0.55 * comparsa() + 0.4 * intensita, 0.0, 0.95)
		"bambino":
			# quasi piena da subito, piena nel vero
			_gruppo.self_modulate.a = clampf(0.75 * comparsa() + 0.25 * intensita, 0.0, 1.0)
			_figura_nodo.transform = _posa_bambino()
		"occhi":
			if intensita > 0.5 and _occhi.size() < 2:
				_aggiungi_occhi()
			_sfondo.queue_redraw()
		"orologio":
			_passo -= delta
			if _passo <= 0.0:
				_cambia_orologio()
		"scritte":
			if intensita > 0.5 and _scritte.size() < 2:
				_aggiungi_scritta()
			for l in _scritte:
				var lab := l as Label
				lab.modulate.a = clampf(0.3 * comparsa() + 0.45 * intensita, 0.0, 0.8)
		"sangue":
			_scorri_sangue(delta)
			_sangue.queue_redraw()
		"tremito":
			var forza: float = (2.0 + 7.0 * intensita) * comparsa()
			if _rng.randf() < 0.35:
				_os.window_layer.position = Vector2(_rng.randf_range(-forza, forza),
						_rng.randf_range(-forza, forza)).round()

# --- piccole ---

func _cambia_orologio() -> void:
	if intensita >= 0.9:
		_os.orologio_finto("03:33")          # alla fine si ferma li'
		_passo = 1.0
		return
	if _rng.randf() < 0.5:
		_minuti = posmod(_minuti - _rng.randi_range(1, 7), 24 * 60)   # all'indietro
		_os.orologio_finto("%02d:%02d" % [_minuti / 60, _minuti % 60])
	else:
		_os.orologio_finto(OROLOGI[_rng.randi() % OROLOGI.size()])
	_passo = lerpf(0.4, 0.15, intensita)

func _aggiungi_occhi() -> void:
	var area := Vector2(_os.size.x, _os.size.y - OSDesktop.TASKBAR_H)
	_occhi.append([Vector2(_rng.randf_range(0.3, 0.9) * area.x, _rng.randf_range(0.15, 0.8) * area.y),
			_rng.randf_range(30.0, 38.0), _rng.randf_range(0.0, 5.0), _t])   # a 20-28 px quasi non si vedevano

func _aggiungi_scritta() -> void:
	var usate := []
	for l in _scritte:
		usate.append((l as Label).text)
	var libere := []
	for k in SCRITTE:
		if not usate.has(tr(k)):
			libere.append(k)
	var l := Label.new()
	l.name = "Apparizione_scritta"
	l.text = tr(libere[_rng.randi() % libere.size()])
	l.add_theme_font_override("font", Win95.font("sans_b"))
	l.add_theme_font_size_override("font_size", _rng.randi_range(40, 60))
	l.add_theme_color_override("font_color", Color(0.3, 0.0, 0.03))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.rotation = _rng.randf_range(-0.1, 0.1)
	l.modulate.a = 0.0
	_os.sopra_sfondo(l)
	var area := Vector2(_os.size.x, _os.size.y - OSDesktop.TASKBAR_H)
	l.position = Vector2(_rng.randf_range(0.25, 0.65) * area.x, _rng.randf_range(0.12, 0.8) * area.y).floor()
	_scritte.append(l)

func _disegna_sfondo() -> void:
	if _sfondo == null or tipo != "occhi":
		return
	for o in _occhi:
		_disegna_occhi(o[0], o[1], o[2], _t - float(o[3]))

# --- il bambino ---

# Un punto nel sistema della TESTA (centro della testa in 0,0, inclinata) -> collo in 0,0.
# Il centro e' un po' lontano dal collo: il collo e' tirato.
static func _in_testa(p: Vector2) -> Vector2:
	return Vector2(0, -35).rotated(INCLINA_TESTA) + p.rotated(INCLINA_TESTA)

# I contorni pronti, una volta sola: le forme ammorbidite, la testa con le orecchie, i
# capelli (un po' piu' larghi della testa, finiscono sopra le orecchie) col bordo
# irregolare -- e' il bordo spettinato che fa sembrare vera una testa in sagoma.
func _prepara_bambino() -> void:
	_parti.clear()
	_parti["maglia"] = _liscia(_MAGLIA)
	_parti["manica_sx"] = _liscia(_MANICA, 1)
	_parti["manica_dx"] = _liscia(_specchia(_MANICA, Vector2(1, -2)), 1)
	_parti["braccio_sx"] = _liscia(_BRACCIO)
	_parti["braccio_dx"] = _liscia(_specchia(_BRACCIO, Vector2(1, -2)))
	_parti["pollice_sx"] = _liscia(_POLLICE, 1)
	_parti["pollice_dx"] = _liscia(_specchia(_POLLICE, Vector2(1, -2)), 1)
	_parti["calzoni"] = _liscia(_CALZONI)
	_parti["gamba_sx"] = _liscia(_GAMBA)
	_parti["gamba_dx"] = _liscia(_specchia(_GAMBA, Vector2(-1, -5)))   # un piede piu' su
	_parti["piede_sx"] = _liscia(_PIEDE, 1)
	_parti["piede_dx"] = _liscia(_specchia(_PIEDE, Vector2(-1, -5)), 1)
	_parti["collo"] = _liscia(_COLLO, 1)
	var testa := PackedVector2Array()
	for i in range(32):
		var ang: float = TAU * i / 32.0
		testa.append(_in_testa(Vector2(cos(ang) * TESTA_RX, sin(ang) * TESTA_RY)))
	_parti["testa"] = testa
	for lato in [-1.0, 1.0]:                 # le orecchie sporgono ai lati
		var orecchio := PackedVector2Array()
		for i in range(14):
			var ang: float = TAU * i / 14.0
			orecchio.append(_in_testa(Vector2(lato * (TESTA_RX - 0.5) + cos(ang) * 4.5, 3.0 + sin(ang) * 8.0)))
		_parti["orecchio_" + ("sx" if lato < 0.0 else "dx")] = orecchio
	var cap := PackedVector2Array()
	# il bordo dei capelli e' IRREGOLARE (spettinati). Niente ciuffi a punta: regolari
	# facevano un ingranaggio, pochi sembravano spilli
	for i in range(19):
		var ang: float = lerpf(PI * 1.03, PI * 1.97, i / 18.0)
		var k: float = _rng.randf_range(1.03, 1.12)
		cap.append(_in_testa(Vector2(cos(ang) * TESTA_RX * k, sin(ang) * TESTA_RY * k * 0.98)))
	cap.append(_in_testa(Vector2(TESTA_RX * 0.80, TESTA_RY * 0.30)))
	for i in range(7):
		var x: float = lerpf(TESTA_RX * 0.62, -TESTA_RX * 0.62, i / 6.0)
		cap.append(_in_testa(Vector2(x, TESTA_RY * 0.42 + _rng.randf_range(-2.0, 2.5))))
	cap.append(_in_testa(Vector2(-TESTA_RX * 0.80, TESTA_RY * 0.30)))
	_parti["capelli"] = _liscia(cap, 1)

# Ammorbidisce un contorno chiuso tagliando gli angoli (Chaikin): resta un poligono
# semplice, quindi la triangolazione non fallisce.
static func _liscia(pts: Array, giri := 2) -> PackedVector2Array:
	var p := PackedVector2Array(pts)
	for _g in range(giri):
		var q := PackedVector2Array()
		for i in range(p.size()):
			var a: Vector2 = p[i]
			var b: Vector2 = p[(i + 1) % p.size()]
			q.append(a.lerp(b, 0.25))
			q.append(a.lerp(b, 0.75))
		p = q
	return p

# Il lato destro dal sinistro (rovesciato in x, appena spostato).
static func _specchia(pts: Array, sposta: Vector2) -> Array:
	var out := []
	for p in pts:
		out.append(Vector2(-(p as Vector2).x, (p as Vector2).y) + sposta)
	return out

# La posa di adesso: dondola come un pendolo attorno al punto in alto della corda e gira
# piano su se stesso (la larghezza si stringe e si allarga). E' SOLO la trasformazione del
# nodo: la figura si disegna una volta sola (_disegna_bambino) e poi si muove e basta --
# l'alone sono centinaia di poligoni, ridisegnarli a ogni frame costerebbe per niente.
func _posa_bambino() -> Transform2D:
	var s := SCALA_BAMBINO
	var dondola: float = sin(_t * 0.9) * (0.012 + 0.03 * intensita)
	var gira: float = 0.82 + 0.18 * absf(cos(_t * 0.5 + 0.6))
	var perno := Vector2(_bambino.x, 0.0)
	# il nodo cade sotto il perno
	return Transform2D(dondola, perno) * Transform2D(0.0, Vector2(-NODO.x * s, _bambino.y)) \
			* Transform2D(0.0, Vector2(gira * s, s), 0.0, Vector2.ZERO)

# Tutta la figura in coordinate LOCALI (collo in 0,0), una volta sola.
func _disegna_bambino() -> void:
	var c := _figura_nodo
	if c == null:
		return
	var cima := Vector2(NODO.x, -_bambino.y / SCALA_BAMBINO - 6.0)   # la corda esce dallo schermo
	# l'ALONE: la carta da parati si scurisce attorno a lui, sfumando verso fuori
	for anello in [[22.0, 0.012], [15.0, 0.016], [9.0, 0.02], [4.5, 0.028]]:
		for i in range(10):
			_sagoma(c, Vector2.from_angle(TAU * i / 10.0) * float(anello[0]),
					Color(0, 0, 0, float(anello[1])), cima)
	# l'ombra portata, giu' a destra
	for o in [Vector2(13, 8), Vector2(16, 10)]:
		_sagoma(c, o, Color(0, 0, 0, 0.12), cima)
	if _bambino_tex != null:
		var dim := _bambino_tex.get_size() * 0.35
		c.draw_texture_rect(_bambino_tex, Rect2(Vector2(-dim.x * 0.5, -dim.y * 0.15), dim), false)
		c.draw_line(NODO, cima, C_CORDA, 3.4, true)
		return
	# il bordo morbido (quattro passate di mezzo pixel fuori), poi il pieno
	for o in [Vector2(1.2, 0), Vector2(-1.2, 0), Vector2(0, 1.2), Vector2(0, -1.2)]:
		_sagoma(c, o, Color(C_SAGOMA, 0.35), cima)
	_sagoma(c, Vector2.ZERO, C_SAGOMA, cima)
	# la corda, appena piu' chiara della sagoma, ma solo FUORI dal corpo: le spire del nodo
	# e il tratto fino in cima, con la torsione (il cappio attorno al collo resta scuro: chiaro,
	# staccava la testa dal corpo)
	for i in range(6):
		var giro := _spira(i)
		c.draw_colored_polygon(giro, C_CORDA)
		giro.append(giro[0])
		c.draw_polyline(giro, C_CORDA_SCURA, 1.0, true)
	c.draw_line(NODO, cima, C_CORDA, 3.2, true)
	var y := NODO.y - 4.0
	while y > cima.y:
		c.draw_line(Vector2(NODO.x - 1.5, y - 1.1), Vector2(NODO.x + 1.5, y + 1.1), C_CORDA_SCURA, 0.9, true)
		y -= 5.5

# Una spira del nodo (sei, impilate sul lato della testa).
func _spira(i: int) -> PackedVector2Array:
	var centro := Vector2(NODO.x, NODO.y + 4.0 + i * 4.3)
	var giro := PackedVector2Array()
	for j in range(12):
		var ang: float = TAU * j / 12.0
		giro.append(centro + Vector2(cos(ang) * 6.0, sin(ang) * 2.6))
	return giro

# Tutta la sagoma in un colore, spostata di "sposta": il corpo, il cappio, il
# nodo e la corda fino in cima. La usano l'alone, l'ombra, il bordo morbido e il pieno.
func _sagoma(c: Node2D, sposta: Vector2, col: Color, cima: Vector2) -> void:
	c.draw_set_transform(sposta, 0.0, Vector2.ONE)
	for k in _PARTI:
		c.draw_colored_polygon(_parti[k], col)
	c.draw_polyline(PackedVector2Array([Vector2(-17, -26), Vector2(-11, -12), Vector2(-3, -7),
			Vector2(6, -7), Vector2(12, -12)]), col, 3.6, true)
	for i in range(6):
		c.draw_colored_polygon(_spira(i), col)
	c.draw_line(NODO, cima, col, 3.6, true)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _disegna_occhi(c: Vector2, largo: float, fase: float, eta: float) -> void:
	var a: float = clampf(0.6 * comparsa() + 0.4 * intensita, 0.0, 1.0)
	var mouse := _sfondo.get_local_mouse_position()
	# un'ombra piccola attorno, sfumata (anelli leggeri: uno solo faceva una palla)
	for i in range(8):
		var r: float = largo * (1.7 - i * 0.1)
		var pts := PackedVector2Array()
		for j in range(24):
			var ang: float = TAU * j / 24.0
			pts.append(c + Vector2(cos(ang) * r, sin(ang) * r * 0.7))
		_sfondo.draw_colored_polygon(pts, Color(C_OMBRA, 0.05 * a))
	var aperti: float = smoothstep(0.0, 0.3, eta)
	if fmod(_t + fase, 4.7) < 0.1:
		aperti = 0.05                                   # ogni tanto sbattono
	for lato in [-1.0, 1.0]:
		var o := c + Vector2(lato * largo * 0.6, 0)
		var bianco := PackedVector2Array()
		for i in range(18):
			var ang: float = TAU * i / 18.0
			bianco.append(o + Vector2(cos(ang) * largo * 0.36, sin(ang) * largo * 0.16 * aperti))
		_sfondo.draw_colored_polygon(bianco, Color(0.86, 0.82, 0.68, a))
		if aperti > 0.3:
			var verso: Vector2 = (mouse - o).limit_length(largo * 0.18)
			_sfondo.draw_circle(o + verso * Vector2(1, 0.5), largo * 0.07, Color(0, 0, 0, a))

# --- gravi ---

# Quante colate sono gia' scese di almeno "px" sotto l'orlo (per i test).
func colate(px := 5.0) -> int:
	var n := 0
	for g in _gocce:
		if float(g["lun"]) > px:
			n += 1
	return n

# Le colate scendono A STRAPPI: una spinta che va e viene (sangue viscoso, non pioggia) e
# rallenta man mano che si allungano. Ognuna ha un suo traguardo, che nel vero si allunga
# con l'intensita'; da quelle gia' lunghe ogni tanto si stacca una goccia e cade.
func _scorri_sangue(delta: float) -> void:
	for g in _gocce:
		var parte: float = g["parte"]
		if _t < parte:
			continue
		var lun: float = g["lun"]
		var lmax: float = g["max"]
		var tetto: float = maxf(minf(lmax, 30.0), lmax * (0.25 + 0.75 * intensita))
		if lun < tetto:
			var spinta: float = 0.5 + 0.5 * sin((_t - parte) * float(g["f"]) + float(g["ph"]))
			var vel: float = float(g["v"]) * (1.0 + intensita) * (0.2 + 0.8 * spinta * spinta) \
					/ (1.0 + lun / 600.0)
			g["lun"] = minf(tetto, lun + vel * delta)
		if lun > 60.0 and _cadute.size() < 6 and _rng.randf() < delta * 0.06 * (0.3 + intensita):
			var x: float = g["x"]
			var y: float = _altezza_orlo(x) + lun
			_cadute.append([Vector2(x + _serpeggia(g, y), y), 0.0])
	var fondo: float = _sangue.size.y
	for i in range(_cadute.size() - 1, -1, -1):
		var c: Array = _cadute[i]
		c[1] = float(c[1]) + GRAVITA * delta
		c[0] = (c[0] as Vector2) + Vector2(0, float(c[1]) * delta)
		if (c[0] as Vector2).y > fondo + 20.0:
			_cadute.remove_at(i)

# L'altezza dell'orlo di sangue lungo il bordo alto, in x: punti raccordati morbidi (a
# punte strette, la prima versione, sembrava una sega), e cresce con l'intensita'.
func _altezza_orlo(x: float) -> float:
	var alto: float = (16.0 + 46.0 * intensita) * comparsa()
	var p: float = x / PASSO_ORLO
	var i: int = clampi(int(p), 0, _orlo.size() - 2)
	var k: float = smoothstep(0.0, 1.0, p - i)
	return alto * lerpf(_orlo[i], _orlo[i + 1], k) + 2.0 * sin(x * 0.17 + _orlo_fase) * comparsa()

# Lo spostamento di lato di una colata alla quota y: scende serpeggiando appena.
func _serpeggia(g: Dictionary, y: float) -> float:
	var amp: float = g["amp"]
	var m: float = g["m"]
	return sin(y * 0.012 + m) * amp + sin(y * 0.033 + m * 2.0) * amp * 0.35

func _disegna_sangue() -> void:
	if _sangue == null:
		return
	var s := _sangue.size
	var a: float = comparsa()
	# prima le colate, POI l'orlo sopra: cosi' l'attacco della colata sparisce sotto l'orlo
	for g in _gocce:
		_disegna_colata(g, a, s.y)
	for c in _cadute:
		_disegna_caduta(c[0], float(c[1]), a)
	# l'orlo: scuro in cima (si rapprende), il colore del corpo sul bordo, dove attacca le colate
	var bordo := PackedVector2Array()
	var x0 := 0.0
	while x0 <= s.x + 6.0:
		bordo.append(Vector2(x0, _altezza_orlo(x0)))
		x0 += 6.0
	var scuro := Color(C_SANGUE_SCURO, a)
	var corpo := Color(C_SANGUE, a)
	for i in range(bordo.size() - 1):
		_sangue.draw_primitive(PackedVector2Array([Vector2(bordo[i].x, 0), Vector2(bordo[i + 1].x, 0),
				bordo[i + 1], bordo[i]]), PackedColorArray([scuro, scuro, corpo, corpo]), PackedVector2Array())
	_sangue.draw_polyline(bordo, corpo, 1.5, true)
	# un filo di lucido appena sopra il bordo: e' bagnato
	var lucido := PackedVector2Array()
	for p in bordo:
		lucido.append(p + Vector2(0, -3.5))
	_sangue.draw_polyline(lucido, Color(1.0, 0.5, 0.45, 0.16 * a), 1.5, true)

# Una colata: si allarga dove esce dall'orlo, si assottiglia scendendo, serpeggia appena e
# finisce GONFIANDOSI in una goccia allungata che fa parte dello stesso contorno -- non una
# pallina attaccata in fondo: cosi', piu' larga, piu' chiara e col riflesso a puntino,
# sembrava uno spillo (proprietario: "le gocce appaiono come pallini"). La goccia e' appena
# piu' scura in basso (il sangue li' e' piu' spesso); il lato destro e' in ombra e un filo
# di lucido corre sul sinistro, giu' fin dentro la goccia.
func _disegna_colata(g: Dictionary, a: float, fondo: float) -> void:
	var lun: float = g["lun"]
	if lun <= 0.5:
		return
	var x: float = g["x"]
	var w: float = g["w"]
	var orlo := _altezza_orlo(x)
	var punta: float = minf(orlo + lun, fondo)
	var r: float = minf(w * 0.5, 0.3 * w + lun * 0.25)   # mezza larghezza della goccia
	var lb: float = r * 3.2                               # quanto e' lunga la goccia
	var fine_corpo: float = maxf(punta - lb, 0.0)
	# le quote: il corpo a passi regolari, la goccia fitta (in fondo e' tonda)
	var ys := PackedFloat32Array()
	var n: int = clampi(int(fine_corpo / 14.0) + 2, 2, 48)
	for k in range(n):
		ys.append(fine_corpo * k / n)
	for k in range(13):
		ys.append(lerpf(fine_corpo, punta, sin(PI * 0.5 * k / 12.0)))
	var sx := PackedVector2Array()
	var dx := PackedVector2Array()
	var cols := PackedColorArray()
	for y in ys:
		var u: float = clampf((y - orlo) / maxf(lun, 1.0), 0.0, 1.0)
		var hw: float = w * 0.5 * lerpf(1.0, 0.72, u)
		hw *= 1.0 + 1.5 * (1.0 - smoothstep(orlo - 2.0, orlo + 2.2 * w, y))
		var d: float = punta - y                          # distanza dalla punta
		if d < r:
			# il fondo della goccia: mezza ellisse che chiude il contorno in punta
			var q: float = (r - d) / r
			hw = maxf(hw, r) * sqrt(maxf(0.0, 1.0 - q * q))
		else:
			hw = maxf(hw, lerpf(r, 0.0, smoothstep(r, lb, d)))
		var cx: float = x + _serpeggia(g, y)
		sx.append(Vector2(cx - hw, y))
		dx.append(Vector2(cx + hw, y))
		var col: Color = C_SANGUE.lerp(C_SANGUE_VIVO, 0.3 * u)
		col = col.lerp(C_SANGUE_SCURO, 0.35 * (1.0 - clampf(d / lb, 0.0, 1.0)))
		cols.append(Color(col, a))
	for k in range(sx.size() - 1):
		_sangue.draw_primitive(PackedVector2Array([sx[k], dx[k], dx[k + 1], sx[k + 1]]),
				PackedColorArray([cols[k], cols[k], cols[k + 1], cols[k + 1]]), PackedVector2Array())
	_sangue.draw_polyline(sx, Color(C_SANGUE, a), 1.0, true)
	_sangue.draw_polyline(dx, Color(C_SANGUE_SCURO, 0.7 * a), 1.0, true)
	if lun > 2.0 * w:
		var luce := PackedVector2Array()
		for k in range(sx.size()):
			if sx[k].y > orlo + w and sx[k].y < punta - r * 0.4:
				luce.append(sx[k].lerp(dx[k], 0.3))
		if luce.size() >= 2:
			_sangue.draw_polyline(luce, Color(1.0, 0.55, 0.5, 0.18 * a), clampf(w * 0.15, 1.0, 2.0), true)

# Una goccia che si e' staccata e cade: in caduta e' una goccia con la SCIA (piu' lunga
# quanto piu' va veloce, che sfuma verso l'alto), non un pallino.
func _disegna_caduta(p: Vector2, v: float, a: float) -> void:
	var r := 2.2
	var coda: float = clampf(v * 0.02, 4.0, 26.0)
	var pts := PackedVector2Array([p + Vector2(0, -r - coda)])
	var cols := PackedColorArray([Color(C_SANGUE, 0.0)])
	for k in range(9):                    # il fondo tondo, da destra a sinistra
		var ang: float = PI * k / 8.0
		pts.append(p + Vector2(cos(ang) * r, sin(ang) * r))
		cols.append(Color(C_SANGUE, a))
	_sangue.draw_polygon(pts, cols)

# Rimette tutto com'era: strati liberati, orologio, finestre al loro posto.
func pulisci() -> void:
	if _fatta:
		return
	_fatta = true
	set_process(false)
	if _os != null and is_instance_valid(_os):
		if tipo == "orologio":
			_os.orologio_finto("")
		if tipo == "tremito" and _os.window_layer != null:
			_os.window_layer.position = Vector2.ZERO
	for n in [_sfondo, _velo, _sangue] + _scritte:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_sfondo = null
	_velo = null
	_sangue = null
	_scritte.clear()
	finita.emit()
	queue_free()
