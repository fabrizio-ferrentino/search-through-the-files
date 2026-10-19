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
# SETTE TIPI. Le quattro PICCOLE stanno SOLO nella carta da parati (sopra_sfondo: sotto icone e
# finestre) o nell'orologio -- il proprietario le vuole "di poco conto"; una versione che
# rinominava le icone e metteva il bambino sopra le finestre e' stata provata e scartata
# perche' troppo invasiva:
#   "bambino"   la maledizione si MOSTRA (GDD §2b: l'origine e' il ragazzo, il bambino e' la
#               forma che prende): un BAMBINO (maschio: la maledizione e' maschile)
#               impiccato, vicino al bordo destro dello sfondo, fatto di CARATTERI ASCII
#               NERI, piccoli (proprietario, 19/10/2026, da un video di ASCII art): la
#               sagoma -- proporzioni da bambino, capelli spettinati, orecchie, maniche,
#               pantaloncini, piedi in punta, la testa piegata troppo, il nodo -- fa da STAMPO
#               per una griglia di testo ferma (vedi ASCII_RAMPA), DETTAGLIATO come gli occhi:
#               ogni parte col suo tono, ombra da un lato, linee dove i vestiti finiscono,
#               pieghe (vedi _prepara_toni); la corda e' una colonna di ")(", attorno pochi
#               simboli tenui. Dondola e gira piano, e i caratteri cambiano. Storia, perche'
#               non torni:
#               la prima sagoma, fatta di forme tonde, "era ridicola"; una figura realistica a
#               colori (bambina in camicia da notte, poi bambino di spalle con la maglietta)
#               "non fa paura"; la sagoma scura piena "non ancora perfetta"; la prima versione
#               ASCII aveva una pozza di buio dietro -- "non mi piace": niente alone nero;
#               i caratteri BIANCHI "si vedeva poco", anche col bordino nero: neri.
#               Mai il viso, niente di macabro. Se esiste IMMAGINE_BAMBINO, lo stampo e' quella
#               (la sua alfa);
#   "occhi"     due occhi REALISTICI fatti di caratteri (palpebre, ciglia, iride, pupilla,
#               riflesso): bianchi dove l'occhio e' chiaro, scuri dove e' scuro, niente attorno;
#               l'iride segue il cursore, sbattono. (Due occhietti stilizzati "(%@@@@%)" sono
#               stati scartati: il proprietario li voleva veri.)
#   "orologio"  l'ora della barra sbaglia (all'indietro, 03:33, --:--);
#   "scritte"   una frase della maledizione (VIRUS_SCRITTA_*) che si DIGITA da sola nello
#               sfondo, come una riga di terminale: prompt ">", cursore "_" che lampeggia,
#               lettere bianche senza macchia scura dietro.
# Le tre GRAVI sono apparizioni come le altre, stessa regola:
#   "buio"      TUTTO lo schermo si scurisce -- finestre, icone, barra, e anche il menu Avvio e
#               i dialoghi aperti DOPO, "Arresta il sistema" compreso (sopra_tutto: uno strato
#               a parte, sempre sopra; il menu e i dialoghi si portano in primo piano e prima
#               gli passavano sopra, "rimangono invariati" -- proprietario) -- e SFARFALLA come
#               una LAMPADINA CHE STA PER SPEGNERSI (proprietario, 19/10/2026: era solo la carta
#               da parati, poi un lampeggio che "non mi piace", poco naturale): vedi _sfarfalla.
#               Mai piu' di 3 cali al secondo (BUIO_RAFFICA_MAX, poi BUIO_PAUSA_MIN di quiete):
#               uno sfarfallio piu' fitto puo' far male a chi e' fotosensibile. Nel vero il buio
#               cresce, lo sfarfallio resta lo stesso;
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
const PICCOLE := ["bambino", "occhi", "orologio", "scritte"]
const PESI := [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]   # stesso ordine di TIPI
const SOGLIA_FALSO := 3.0          # un falso allarme dura SEMPRE meno di questo
const BUIO_RAFFICA_MAX := 3        # buio: al massimo tanti cali in una raffica...
const BUIO_PAUSA_MIN := 1.0        # ...e poi almeno tanto di quiete: mai piu' di 3 cali al secondo
const COMPARSA := 0.25             # secondi per comparire (uguale per vero e falso)
const IMMAGINE_BAMBINO := "res://assets/textures/virus/bambino.png"
const SCRITTE := ["VIRUS_SCRITTA_1", "VIRUS_SCRITTA_2", "VIRUS_SCRITTA_3",
		"VIRUS_SCRITTA_4", "VIRUS_SCRITTA_5", "VIRUS_SCRITTA_6"]
const OROLOGI := ["03:33", "--:--", "88:88", "00:00", "33:03"]
const GOCCE := 28                  # colate (60 tutte uguali sembravano un codice a barre)
const GOCCE_SUBITO := 9            # quelle che partono subito: anche un falso deve far vedere il sangue
const PASSO_ORLO := 48.0           # l'orlo in alto: un punto ogni tanti px, raccordati
const GRAVITA := 1400.0            # le gocce che si staccano
# --- il bambino ---
const SCALA_BAMBINO := 1.35          # la figura e' alta ~350 unita': ~470 px (a 1.1, coi caratteri
                                     # da 9 px, i dettagli non avevano spazio)
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
# Il bambino e' fatto di CARATTERI (proprietario, 19/10/2026, da un video di ASCII art): la
# sagoma qui sopra non si disegna, fa da STAMPO -- se ne misura il TONO cella per cella su una
# griglia di testo FERMA e ogni cella prende il carattere della rampa che gli corrisponde. Il
# tono non e' la sola copertura: e' piu' pieno lontano dal bordo (_distanza), cosi' la figura
# ha VOLUME -- bordi in .:-=, il centro di busto, testa e arti in #%@ -- e non e' un blocco di
# @. La griglia sta ferma e la figura dondola sotto: i caratteri cambiano, e il bordo frigge.
# CARATTERI BIANCHI diretti sulla carta da parati, NIENTE ALONE NERO dietro (proprietario: la
# prima versione aveva una pozza scura e "non mi piace"); piccoli, per avere dettaglio.
const ASCII_RAMPA := " .:-=+*#%@"       # dal vuoto al pieno
const ASCII_SPARSI := "`'.,:;!?|/\\(){}<>[]0123456789%&*+="
const ASCII_FONT := "mono_b"            # grassetto: il tondo, sotto il CRT, diventava un filo
const ASCII_PUNTI := 9                  # corpo del carattere: piccolo = piu' dettaglio (era 13)
const ASCII_RIGA := 9.0                 # passo verticale stretto, come l'ASCII art vera
const ASCII_PASSO := 0.09               # ogni quanto si ricompone (a scatti: e' un terminale)
# Il bambino e' fatto di caratteri NERI (proprietario, 19/10: bianchi "si vedeva poco", anche
# col bordino) e DETTAGLIATO come gli occhi: ogni parte ha il suo TONO (_prepara_toni) --
# capelli e pantaloncini scuri, la maglia a meta', la pelle chiara (pochi punti) --, una linea
# scura dove una parte finisce o ne copre un'altra (il braccio sulla maglia, la maglia sui
# pantaloncini), la luce dall'alto a sinistra (il lato in ombra piu' fitto) e qualche piega
# (_PIEGHE: colletto, maglia, cucitura, ginocchia). Mai il viso: la faccia e' solo pelle.
const VOLUME_R := 10.0                  # a questa distanza dal bordo (unita') il tono e' pieno
const C_BAMBINO := Color(0.02, 0.02, 0.03)
const C_ASCII_CORDA := Color(0.10, 0.07, 0.04)
const PELLE := 0.42                     # la pelle: chiara, pochi punti
const _MATERIALE := {"capelli": 1.0, "calzoni": 0.88, "maglia": 0.68, "manica_sx": 0.68,
		"manica_dx": 0.68}
const ID_CORDA := 100                   # il cappio e le spire, nello stampo delle parti
const LUCE := Vector2i(-1, -2)          # verso la luce, in campioni a meta' risoluzione
# le pieghe, in coordinate locali (collo in 0,0): linee scure dentro la figura
const _PIEGHE := [
	[Vector2(-11, 9), Vector2(-5, 13), Vector2(5, 13), Vector2(11, 9)],       # il colletto
	[Vector2(-24, 24), Vector2(-16, 44)], [Vector2(23, 25), Vector2(15, 46)],  # dalle ascelle
	[Vector2(-14, 92), Vector2(-5, 112)], [Vector2(9, 96), Vector2(4, 114)],   # in fondo alla maglia
	[Vector2(0, 124), Vector2(0, 146)],                                         # la cucitura
	[Vector2(-21, 201), Vector2(-9, 202)], [Vector2(8, 196), Vector2(20, 197)], # le ginocchia
]
const C_ASCII := Color(1.0, 1.0, 1.0)                # occhi e scritte
const C_ASCII_SCURO := Color(0.03, 0.025, 0.035)   # gli occhi: pupilla, ciglia, iride scura
# le scritte: righe di terminale digitate da sole (vedi _aggiungi_scritta)
const SCRITTA_PUNTI := [30, 38]
const SCRITTA_DIGITA := 0.9             # secondi per scrivere la frase intera: il falso dura 2-2.5
const C_SCRITTA_PROMPT := Color(0.62, 0.05, 0.08)
# gli occhi: due occhi REALISTICI fatti di caratteri (proprietario: "preferirei degli occhi
# realistici"), sulla stessa griglia piccola del bambino. OCCHIO_A = mezza larghezza di un
# occhio (px), OCCHIO_B = mezza apertura; l'iride segue il cursore.
const OCCHIO_A := 110.0                 # a 66 px erano 5 righe: non si capiva che fossero occhi
const OCCHIO_B := 44.0
const OCCHIO_DISTANZA := 150.0          # dal centro della coppia al centro di un occhio
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
var _velo_strato: CanvasLayer = null   # buio: lo strato sopra tutto che lo contiene
var _luce := 1.0                   # buio: la "lampadina" (1 = al suo solito, 0 = spenta)
var _luce_meta := 1.0              # buio: dove la luce sta andando
var _luce_passo := 0.0             # buio: fra quanto cambia meta
var _tau_su := 0.05                # buio: quanto ci mette a riprendersi (il filamento si riscalda)
var _cali: Array = []              # buio: i prossimi passi della raffica, [meta, durata, tau_su]
var _in_raffica := false
var _scritte: Array = []           # scritte: le Label sulla carta da parati
var _battute: Array = []           # scritte: per ognuna [nata a, secondi per lettera, passo]
var _sangue: Control = null        # sangue: sopra le finestre
var _passo := 0.0
var _minuti := 0
var _occhi: Array = []             # [centro della coppia, fase del battito, nato a (s)]
var _celle_occhi: Array = []       # [posizione, carattere, colore], ricomposte ogni ASCII_PASSO
var guarda_test: Variant = null    # SOLO i test: il punto che gli occhi guardano (se no il mouse)
var _bambino := Vector2.ZERO       # dove sta il collo
var _bambino_tex: Texture2D = null
var _gruppo: CanvasGroup = null    # bambino: la figura si sfuma IN BLOCCO (vedi setup)
var _parti := {}                   # bambino: nome -> contorno pronto (PackedVector2Array)
var _ascii_nodo: Node2D = null     # bambino: i caratteri, su una griglia ferma
var _maschera := PackedFloat32Array()   # copertura 0..1 della figura, un campione per unita' locale
var _m_org := Vector2.ZERO
var _m_w := 0
var _m_h := 0
var _ids := PackedInt32Array()          # quale parte c'e' in ogni punto (indice in _PARTI + 1)
var _id_h := PackedInt32Array()         # lo stesso a meta' risoluzione (-1 = fuori)
var _toni := PackedFloat32Array()       # il tono pronto, a meta' risoluzione
var _distanza := PackedFloat32Array()   # distanza dal bordo DELLA SUA PARTE (unita'), a meta' risoluzione
var _d_w := 0
var _d_h := 0
var _alone := PackedFloat32Array()      # la stessa sfocata, a 1/4: dove spuntano i simboli sparsi
var _a_w := 0
var _a_h := 0
var _cella := Vector2.ZERO
var _griglia := Rect2()
var _celle: Array = []                  # [posizione, carattere, colore]
var _sparsi := {}                       # cella -> [carattere, soglia]: cambiano piano
var _ascii_t := 0.0
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
			_velo_strato = os.sopra_tutto(_velo)
			_luce_passo = _rng.randf_range(0.3, 1.0)
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
				_ascii_nodo = Node2D.new()          # i caratteri, su una griglia ferma
				_ascii_nodo.draw.connect(_disegna_ascii)
				_gruppo.add_child(_ascii_nodo)
				_prepara_bambino()
				_prepara_maschera()
				_prepara_griglia()
				_componi_ascii()
			else:
				_sfondo.modulate.a = 0.0
				_aggiungi_occhi()
				_componi_occhi()
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
			_sfarfalla(delta)
		"bambino":
			# quasi piena da subito, piena nel vero
			_gruppo.self_modulate.a = clampf(0.85 * comparsa() + 0.15 * intensita, 0.0, 1.0)
			_ascii_t -= delta
			if _ascii_t <= 0.0:
				_ascii_t = ASCII_PASSO
				_componi_ascii()
		"occhi":
			if intensita > 0.5 and _occhi.size() < 2:
				_aggiungi_occhi()
			_sfondo.modulate.a = clampf(0.85 * comparsa() + 0.15 * intensita, 0.0, 1.0)
			_ascii_t -= delta
			if _ascii_t <= 0.0:
				_ascii_t = ASCII_PASSO
				_componi_occhi()
		"orologio":
			_passo -= delta
			if _passo <= 0.0:
				_cambia_orologio()
		"scritte":
			if intensita > 0.5 and _scritte.size() < 2:
				_aggiungi_scritta()
			for i in range(_scritte.size()):
				var lab := _scritte[i] as Label
				lab.modulate.a = clampf(0.45 * comparsa() + 0.4 * intensita, 0.0, 0.85)
				var b: Array = _battute[i]
				var n := mini(lab.text.length(), int((_t - float(b[0])) / float(b[1])) + 1)
				lab.visible_characters = n
				var cur := lab.get_node("Cursore") as Label
				cur.position.x = float(b[2]) * n
				cur.visible = fmod(_t, 0.5) < 0.3 or n < lab.text.length()   # lampeggia a frase finita
		"sangue":
			_scorri_sangue(delta)
			_sangue.queue_redraw()
		"tremito":
			var forza: float = (2.0 + 7.0 * intensita) * comparsa()
			if _rng.randf() < 0.35:
				_os.window_layer.position = Vector2(_rng.randf_range(-forza, forza),
						_rng.randf_range(-forza, forza)).round()

# --- piccole ---

# Il buio: lo scuro cresce col vero (fino a 0.85: Avvio deve restare trovabile) e la luce
# sfarfalla come una LAMPADINA CHE STA PER SPEGNERSI (proprietario: "piu' naturale"). Quasi
# sempre accesa al suo solito, con un tremolio appena; ogni tanto una RAFFICA di 2-3 cali brevi
# (il filamento che perde contatto) oppure un calo LUNGO quasi al buio che si riprende piano
# (il filamento che si raffredda e si riscalda); poi quiete. Niente scatti: la luce va verso la
# meta con un'inerzia, scende in fretta e risale piu' lenta. Mai PIU' CHIARA del suo solito: la
# prima versione tornava quasi normale a lampi, e sembrava un interruttore, non una lampadina.
# Comparsa uguale per vero e falso: lo sfarfallio parte dopo, quando e' gia' buio.
func _sfarfalla(delta: float) -> void:
	var scuro: float = clampf(0.62 * comparsa() + 0.23 * intensita, 0.0, 0.85)
	if _t >= COMPARSA + 0.1:
		_luce_passo -= delta
		if _luce_passo <= 0.0:
			if not _cali.is_empty():
				var c: Array = _cali.pop_front()
				_luce_meta = c[0]
				_luce_passo = c[1]
				_tau_su = c[2]
			elif _in_raffica:
				_in_raffica = false                    # quiete: torna al suo solito
				_luce_meta = 1.0
				_luce_passo = _rng.randf_range(BUIO_PAUSA_MIN, 2.6)
			else:
				_prepara_raffica()
				_luce_passo = 0.0
	var tau: float = 0.025 if _luce_meta < _luce else _tau_su
	_luce = lerpf(_luce, _luce_meta, 1.0 - exp(-delta / tau))
	var tremolio: float = 1.0 - 0.02 * absf(sin(_t * 23.0) * sin(_t * 7.3))   # mai ferma, mai piu' chiara
	_velo.color.a = clampf(1.0 - (1.0 - scuro) * _luce * tremolio, 0.0, 0.96)

# Una raffica: 2-3 cali brevi con un mezzo ritorno fra l'uno e l'altro, oppure (una volta su
# quattro) un calo lungo quasi al buio che si riprende lento.
func _prepara_raffica() -> void:
	_in_raffica = true
	_cali.clear()
	if _rng.randf() < 0.25:
		_cali.append([_rng.randf_range(0.03, 0.12), _rng.randf_range(0.25, 0.6), 0.35])
		return
	var n := _rng.randi_range(2, BUIO_RAFFICA_MAX)
	for i in range(n):
		_cali.append([_rng.randf_range(0.15, 0.5), _rng.randf_range(0.04, 0.09), 0.05])
		if i < n - 1:
			_cali.append([_rng.randf_range(0.8, 1.0), _rng.randf_range(0.06, 0.16), 0.05])

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
	var c := Vector2(_rng.randf_range(0.35, 0.75) * area.x, _rng.randf_range(0.18, 0.78) * area.y)
	_occhi.append([c, _rng.randf_range(0.0, 5.0), _t])

func _aggiungi_scritta() -> void:
	var usate := []
	for l in _scritte:
		usate.append((l as Label).text)
	var libere := []
	for k in SCRITTE:
		if not usate.has(tr(k)):
			libere.append(k)
	# Una riga di TERMINALE (come il bambino, la maledizione scrive coi caratteri del PC): il
	# prompt, la frase che si DIGITA da sola lettera per lettera (visible_characters: il testo
	# della Label resta la frase intera) e il cursore che lampeggia dopo l'ultima lettera. Lettere
	# BIANCHE sulla carta da parati, senza macchia scura dietro (proprietario: niente alone).
	var l := Label.new()
	l.name = "Apparizione_scritta"
	l.text = tr(libere[_rng.randi() % libere.size()])
	var dim := _rng.randi_range(SCRITTA_PUNTI[0], SCRITTA_PUNTI[1])
	l.add_theme_font_override("font", Win95.font(ASCII_FONT))
	l.add_theme_font_size_override("font_size", dim)
	l.add_theme_color_override("font_color", C_ASCII)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.visible_characters = 0
	l.modulate.a = 0.0
	var adv: float = Win95.font(ASCII_FONT).get_char_size(ord("M"), dim).x
	var prompt := Label.new()
	prompt.text = ">"
	prompt.add_theme_font_override("font", Win95.font(ASCII_FONT))
	prompt.add_theme_font_size_override("font_size", dim)
	prompt.add_theme_color_override("font_color", C_SCRITTA_PROMPT)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.position = Vector2(-adv * 2.0, 0.0)
	l.add_child(prompt)
	var cursore := Label.new()
	cursore.name = "Cursore"
	cursore.text = "_"
	cursore.add_theme_font_override("font", Win95.font(ASCII_FONT))
	cursore.add_theme_font_size_override("font_size", dim)
	cursore.add_theme_color_override("font_color", C_ASCII)
	cursore.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_child(cursore)
	var largo: float = adv * (l.text.length() + 4)
	_os.sopra_sfondo(l)
	var area := Vector2(_os.size.x, _os.size.y - OSDesktop.TASKBAR_H)
	l.position = Vector2(_rng.randf_range(0.25, 0.65) * area.x, _rng.randf_range(0.12, 0.8) * area.y).floor()
	l.position.x = minf(l.position.x, area.x - largo - 60.0)    # le frasi lunghe restano dentro
	_scritte.append(l)
	_battute.append([_t, clampf(SCRITTA_DIGITA / maxf(1.0, l.text.length()), 0.025, 0.08), adv])

func _disegna_sfondo() -> void:
	if _sfondo == null or tipo != "occhi":
		return
	var f := Win95.font(ASCII_FONT)
	for k in _celle_occhi:
		_sfondo.draw_char(f, k[0], k[1], ASCII_PUNTI, k[2])

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

# Dove sta l'immagine del bambino (se c'e'), in coordinate locali.
func _rett_immagine() -> Rect2:
	var dim := _bambino_tex.get_size() * 0.35
	return Rect2(Vector2(-dim.x * 0.5, -dim.y * 0.15), dim)

# Lo STAMPO: quanto della figura copre ogni punto locale (1 campione per unita'). Dalle
# parti con un riempimento a righe (pari/dispari: i contorni lisciati restano semplici), o
# dall'alfa dell'immagine se c'e'. Una volta sola: e' l'unico conto pesante.
func _prepara_maschera() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	if _bambino_tex != null:
		var r := _rett_immagine()
		lo = r.position
		hi = r.end
	else:
		for k in _PARTI:
			for p in _parti[k]:
				lo = lo.min(p)
				hi = hi.max(p)
	lo = lo.min(NODO + Vector2(-8, -2))
	_m_org = (lo - Vector2(4, 4)).floor()
	_m_w = int(ceil(hi.x - _m_org.x)) + 5
	_m_h = int(ceil(hi.y - _m_org.y)) + 5
	_maschera = PackedFloat32Array()
	_maschera.resize(_m_w * _m_h)
	_maschera.fill(0.0)
	_ids = PackedInt32Array()
	_ids.resize(_m_w * _m_h)
	_ids.fill(0)
	if _bambino_tex != null:
		var img := _bambino_tex.get_image()
		if img.is_compressed():
			img.decompress()
		var r := _rett_immagine()
		img.resize(maxi(1, int(r.size.x)), maxi(1, int(r.size.y)), Image.INTERPOLATE_BILINEAR)
		var alfa := img.detect_alpha() != Image.ALPHA_NONE
		var ox := int(r.position.x - _m_org.x)
		var oy := int(r.position.y - _m_org.y)
		for y in range(img.get_height()):
			for x in range(img.get_width()):
				var col := img.get_pixel(x, y)
				var v: float = col.a if alfa else 1.0 - col.get_luminance()
				if ox + x >= 0 and ox + x < _m_w and oy + y >= 0 and oy + y < _m_h:
					_maschera[(oy + y) * _m_w + ox + x] = v
	else:
		# nell'ordine di disegno: quella dopo copre quella prima (il braccio sulla maglia)
		for i in range(_PARTI.size()):
			_riempi(_parti[_PARTI[i]], i + 1)
		_riempi_tratto(PackedVector2Array([Vector2(-17, -26), Vector2(-11, -12), Vector2(-3, -7),
				Vector2(6, -7), Vector2(12, -12)]), 1.8, ID_CORDA)       # il cappio
	for i in range(6):
		_riempi(_spira(i), ID_CORDA)
	_prepara_distanza()
	_prepara_toni()
	# l'alone: la stessa a 1/4, sfocata due volte (~12 unita')
	_a_w = int(ceil(_m_w / 4.0))
	_a_h = int(ceil(_m_h / 4.0))
	_alone = PackedFloat32Array()
	_alone.resize(_a_w * _a_h)
	_alone.fill(0.0)
	for y in range(_m_h):
		for x in range(_m_w):
			_alone[(y >> 2) * _a_w + (x >> 2)] += _maschera[y * _m_w + x] / 16.0
	for _g in range(2):
		_alone = _sfoca(_alone, _a_w, _a_h, 3)

# La DISTANZA DAL BORDO di ogni punto (a meta' risoluzione, in unita'), con una trasformata a
# smusso in due passate. Il bordo e' quello della SUA PARTE: dove la parte cambia (il braccio
# sopra la maglia) c'e' un bordo anche dentro la figura -- da li' vengono le linee interne.
func _prepara_distanza() -> void:
	_d_w = int(ceil(_m_w / 2.0))
	_d_h = int(ceil(_m_h / 2.0))
	_id_h = PackedInt32Array()
	_id_h.resize(_d_w * _d_h)
	for y in range(_d_h):
		for x in range(_d_w):
			var mi := mini(y * 2, _m_h - 1) * _m_w + mini(x * 2, _m_w - 1)
			_id_h[y * _d_w + x] = _ids[mi] if _maschera[mi] >= 0.5 else -1
	var d := PackedFloat32Array()
	d.resize(_d_w * _d_h)
	var lontano := 1.0e6
	for y in range(_d_h):
		for x in range(_d_w):
			var i := y * _d_w + x
			var id := _id_h[i]
			var bordo := id < 0 or x == 0 or y == 0 or x == _d_w - 1 or y == _d_h - 1
			if not bordo:
				bordo = _id_h[i - 1] != id or _id_h[i + 1] != id or _id_h[i - _d_w] != id \
						or _id_h[i + _d_w] != id
			d[i] = 0.0 if bordo else lontano
	var dg := 1.4142
	for y in range(_d_h):
		for x in range(_d_w):
			var i := y * _d_w + x
			var v: float = d[i]
			if v == 0.0:
				continue
			if x > 0:
				v = minf(v, d[i - 1] + 1.0)
			if y > 0:
				v = minf(v, d[i - _d_w] + 1.0)
				if x > 0:
					v = minf(v, d[i - _d_w - 1] + dg)
				if x < _d_w - 1:
					v = minf(v, d[i - _d_w + 1] + dg)
			d[i] = v
	for y in range(_d_h - 1, -1, -1):
		for x in range(_d_w - 1, -1, -1):
			var i := y * _d_w + x
			var v: float = d[i]
			if v == 0.0:
				continue
			if x < _d_w - 1:
				v = minf(v, d[i + 1] + 1.0)
			if y < _d_h - 1:
				v = minf(v, d[i + _d_w] + 1.0)
				if x < _d_w - 1:
					v = minf(v, d[i + _d_w + 1] + dg)
				if x > 0:
					v = minf(v, d[i + _d_w - 1] + dg)
			d[i] = v
	for i in range(d.size()):
		d[i] *= 2.0                       # da celle a meta' risoluzione a unita'
	_distanza = d

# Il TONO di ogni punto (0..1, quanto e' scuro), una volta sola: il materiale della parte, piu'
# scuro sul bordo e in ombra (la luce viene da LUCE), una linea piena dove la parte finisce e
# sulle pieghe. Con l'immagine (IMMAGINE_BAMBINO) non ci sono parti: solo il volume.
func _prepara_toni() -> void:
	_toni = PackedFloat32Array()
	_toni.resize(_d_w * _d_h)
	_toni.fill(0.0)
	var linee := PackedByteArray()
	linee.resize(_d_w * _d_h)
	linee.fill(0)
	if _bambino_tex == null:
		for pl in _PIEGHE:
			for k in range(pl.size() - 1):
				var a: Vector2 = pl[k]
				var b: Vector2 = pl[k + 1]
				var lo := ((a.min(b) - _m_org) / 2.0).floor() - Vector2.ONE
				var hi := ((a.max(b) - _m_org) / 2.0).ceil() + Vector2.ONE
				for y in range(maxi(0, int(lo.y)), mini(_d_h, int(hi.y) + 1)):
					for x in range(maxi(0, int(lo.x)), mini(_d_w, int(hi.x) + 1)):
						var p := _m_org + Vector2(x * 2 + 1, y * 2 + 1)
						if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= 1.2:
							linee[y * _d_w + x] = 1
	for y in range(_d_h):
		for x in range(_d_w):
			var i := y * _d_w + x
			var id := _id_h[i]
			if id < 0:
				continue
			var d: float = _distanza[i]
			var t: float
			if _bambino_tex != null:
				t = lerpf(0.45, 1.0, smoothstep(0.0, VOLUME_R, d))
			elif d < 0.5 or linee[i] == 1:
				t = 1.0                           # il bordo della parte, o una piega
			else:
				# il lato verso la luce e' piu' chiaro: andando verso la luce il bordo si avvicina
				var luce: float = clampf((_dist_h(x - LUCE.x, y - LUCE.y) - _dist_h(x + LUCE.x, y + LUCE.y))
						/ 9.0, -1.0, 1.0)
				t = _materiale(id) * lerpf(1.15, 0.85, smoothstep(2.0, VOLUME_R, d)) - 0.25 * luce
			_toni[i] = clampf(t, 0.1, 1.0)

func _dist_h(x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= _d_w or y >= _d_h:
		return 0.0
	return _distanza[y * _d_w + x]

func _materiale(id: int) -> float:
	if id == ID_CORDA:
		return 0.92
	if id <= 0 or id > _PARTI.size():
		return PELLE
	return float(_MATERIALE.get(_PARTI[id - 1], PELLE))

func _riempi(poli: PackedVector2Array, id := 0) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in poli:
		lo = lo.min(p)
		hi = hi.max(p)
	var n := poli.size()
	for r in range(maxi(0, int(lo.y - _m_org.y) - 1), mini(_m_h, int(hi.y - _m_org.y) + 2)):
		var yc := _m_org.y + r + 0.5
		var xs := PackedFloat32Array()
		for i in range(n):
			var a := poli[i]
			var b := poli[(i + 1) % n]
			if (a.y <= yc) != (b.y <= yc):
				xs.append(a.x + (yc - a.y) * (b.x - a.x) / (b.y - a.y))
		xs.sort()
		var k := 0
		while k + 1 < xs.size():
			var c0 := maxi(0, int(ceil(xs[k] - _m_org.x - 0.5)))
			var c1 := mini(_m_w - 1, int(floor(xs[k + 1] - _m_org.x - 0.5)))
			for c in range(c0, c1 + 1):
				_maschera[r * _m_w + c] = 1.0
				_ids[r * _m_w + c] = id
			k += 2

# Una linea spessa (il cappio) nello stampo.
func _riempi_tratto(linea: PackedVector2Array, raggio: float, id := 0) -> void:
	for i in range(linea.size() - 1):
		var a := linea[i]
		var b := linea[i + 1]
		var lo := a.min(b) - Vector2(raggio, raggio) - _m_org
		var hi := a.max(b) + Vector2(raggio, raggio) - _m_org
		for y in range(maxi(0, int(lo.y)), mini(_m_h, int(hi.y) + 1)):
			for x in range(maxi(0, int(lo.x)), mini(_m_w, int(hi.x) + 1)):
				var p := _m_org + Vector2(x + 0.5, y + 0.5)
				if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= raggio:
					_maschera[y * _m_w + x] = 1.0
					_ids[y * _m_w + x] = id

# Sfocatura a scatola, orizzontale poi verticale.
static func _sfoca(src: PackedFloat32Array, w: int, h: int, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(w * h)
	for y in range(h):
		for x in range(w):
			var s := 0.0
			for d in range(-r, r + 1):
				s += src[y * w + clampi(x + d, 0, w - 1)]
			tmp[y * w + x] = s / (2 * r + 1)
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in range(h):
		for x in range(w):
			var s := 0.0
			for d in range(-r, r + 1):
				s += tmp[clampi(y + d, 0, h - 1) * w + x]
			out[y * w + x] = s / (2 * r + 1)
	return out

func _copertura(p: Vector2) -> float:
	var x := int(floor(p.x - _m_org.x))
	var y := int(floor(p.y - _m_org.y))
	if x < 0 or y < 0 or x >= _m_w or y >= _m_h:
		return 0.0
	return _maschera[y * _m_w + x]

# Il TONO di un punto locale (0..1, quanto e' scuro): quello pronto di _prepara_toni.
func _tono(p: Vector2) -> float:
	var x := int(floor((p.x - _m_org.x) / 2.0))
	var y := int(floor((p.y - _m_org.y) / 2.0))
	if x < 0 or y < 0 or x >= _d_w or y >= _d_h:
		return 0.0
	return _toni[y * _d_w + x]

func _alone_in(p: Vector2) -> float:
	var x := int(floor((p.x - _m_org.x) / 4.0))
	var y := int(floor((p.y - _m_org.y) / 4.0))
	if x < 0 or y < 0 or x >= _a_w or y >= _a_h:
		return 0.0
	return _alone[y * _a_w + x]

# La griglia di testo, FERMA sullo schermo: copre la figura in tutte le pose (dondola) e
# sale fino in cima per la corda.
func _prepara_griglia() -> void:
	_misura_cella()
	var s := SCALA_BAMBINO
	var base := Vector2(_bambino.x - NODO.x * s, _bambino.y)
	var lo := base + _m_org * s
	var hi := base + (_m_org + Vector2(_m_w, _m_h)) * s
	lo.x -= 40.0          # il dondolio (ai piedi ~25 px) e i simboli attorno
	hi.x += 40.0
	hi.y += 30.0
	var x0 := floorf(lo.x / _cella.x) * _cella.x
	_griglia = Rect2(Vector2(x0, 0.0), Vector2(ceilf((hi.x - x0) / _cella.x) * _cella.x,
			ceilf(hi.y / _cella.y) * _cella.y))

# Ricompone la griglia nella posa di adesso: per ogni cella il tono della figura (4 campioni)
# -> un carattere della rampa, NERO. Il bordo frigge (un po' di rumore solo dove la cella e'
# coperta a meta'), la corda e' una colonna di ")(", e attorno spuntano pochi simboli tenui -- di piu'
# quando il vero cresce. Le celle che cadono lontano dalla figura si saltano subito (sopra la
# testa c'e' solo la corda).
func _componi_ascii() -> void:
	if _ascii_nodo == null:
		return
	var tr2 := _posa_bambino()
	var inv := tr2.affine_inverse()
	var sub: Array = []
	for i in range(2):
		for j in range(2):
			sub.append(inv.basis_xform(Vector2((i - 0.5) * _cella.x * 0.5, (j - 0.5) * _cella.y * 0.5)))
	var nodo_s: Vector2 = tr2 * NODO
	var cima_s: Vector2 = tr2 * Vector2(NODO.x, -_bambino.y / SCALA_BAMBINO - 6.0)
	var f := Win95.font(ASCII_FONT)
	var alza: float = (_cella.y + f.get_ascent(ASCII_PUNTI) - f.get_descent(ASCII_PUNTI)) * 0.5
	var cols := int(_griglia.size.x / _cella.x)
	var righe := int(_griglia.size.y / _cella.y)
	var fitti: float = 0.25 + 0.3 * intensita
	var n_rampa := ASCII_RAMPA.length()
	var dentro := Rect2(_m_org, Vector2(_m_w, _m_h)).grow(14.0)
	_celle.clear()
	for r in range(righe):
		var y: float = _griglia.position.y + (r + 0.5) * _cella.y
		var corda := -1
		if y < nodo_s.y - _cella.y * 0.5:
			var u: float = (y - nodo_s.y) / (cima_s.y - nodo_s.y)
			corda = int(floor((lerpf(nodo_s.x, cima_s.x, u) - _griglia.position.x) / _cella.x))
		for c in range(cols):
			var p: Vector2 = _griglia.position + Vector2((c + 0.5) * _cella.x, y - _griglia.position.y)
			var dove := Vector2(_griglia.position.x + c * _cella.x, _griglia.position.y + r * _cella.y + alza)
			var l: Vector2 = inv * p
			if not dentro.has_point(l):
				if c == corda:
					_celle.append([dove, ")" if r % 2 == 0 else "(", C_ASCII_CORDA])
				continue
			var tono := 0.0
			var cop := 0.0
			for o in sub:
				tono += _tono(l + o)
				cop += _copertura(l + o)
			tono *= 0.25
			if cop > 0.0 and cop < 4.0:
				tono = clampf(tono + _rng.randf_range(-0.07, 0.07), 0.0, 1.0)
			if tono > 0.06:
				var i := clampi(roundi(tono * (n_rampa - 1)), 1, n_rampa - 1)
				_celle.append([dove, ASCII_RAMPA[i], Color(C_BAMBINO, lerpf(0.85, 1.0, tono))])
			elif c == corda:
				_celle.append([dove, ")" if r % 2 == 0 else "(", C_ASCII_CORDA])
			else:
				var a := _alone_in(l)
				if a < 0.02:
					continue
				var chiave := r * 4096 + c
				var s: Array = _sparsi.get(chiave, [])
				if s.is_empty() or _rng.randf() < 0.05:
					s = [ASCII_SPARSI[_rng.randi() % ASCII_SPARSI.length()], _rng.randf()]
					_sparsi[chiave] = s
				if float(s[1]) < a * fitti:
					_celle.append([dove, s[0], Color(C_BAMBINO, 0.15 + 0.3 * a)])
	_ascii_nodo.queue_redraw()

func _disegna_ascii() -> void:
	var f := Win95.font(ASCII_FONT)
	for k in _celle:
		_ascii_nodo.draw_char(f, k[0], k[1], ASCII_PUNTI, k[2])

# Una spira del nodo (sei, impilate sul lato della testa).
func _spira(i: int) -> PackedVector2Array:
	var centro := Vector2(NODO.x, NODO.y + 4.0 + i * 4.3)
	var giro := PackedVector2Array()
	for j in range(12):
		var ang: float = TAU * j / 12.0
		giro.append(centro + Vector2(cos(ang) * 6.0, sin(ang) * 2.6))
	return giro

# Gli OCCHI: per ogni cella della griglia (la stessa, piccola, del bambino) il tono di un
# occhio vero, calcolato (_tono_occhio), con 4 campioni -> un carattere della rampa: BIANCO
# dove il tono e' positivo (la sclera, il riflesso), SCURO dove e' negativo (pupilla, bordo
# dell'iride, ciglia). Il nero sta solo DENTRO l'occhio: attorno niente alone.
func _componi_occhi() -> void:
	if _sfondo == null:
		return
	var cella := _misura_cella()
	var f := Win95.font(ASCII_FONT)
	var alza: float = (cella.y + f.get_ascent(ASCII_PUNTI) - f.get_descent(ASCII_PUNTI)) * 0.5
	var guarda: Vector2 = guarda_test if guarda_test != null else _sfondo.get_local_mouse_position()
	var n_rampa := ASCII_RAMPA.length()
	_celle_occhi.clear()
	for o in _occhi:
		var coppia: Vector2 = o[0]
		var eta: float = _t - float(o[2])
		# si aprono, e ogni tanto sbattono (la palpebra scende e risale in ~0.2 s)
		var aperto: float = smoothstep(0.0, 0.3, eta)
		var b: float = fmod(_t + float(o[1]), 4.7)
		if b < 0.2:
			aperto = minf(aperto, absf(b - 0.1) / 0.1)
		for lato in [-1.0, 1.0]:
			var centro: Vector2 = coppia + Vector2(lato * OCCHIO_DISTANZA, 0.0)
			# l'iride va verso il punto guardato, ma resta nell'occhio
			var verso: Vector2 = guarda - centro
			var iride := Vector2(clampf(verso.x / 420.0, -1.0, 1.0) * 0.30,
					clampf(verso.y / 420.0, -1.0, 1.0) * 0.10)
			var c0 := int(floor((centro.x - OCCHIO_A * 1.1) / cella.x))
			var c1 := int(ceil((centro.x + OCCHIO_A * 1.1) / cella.x))
			var r0 := int(floor((centro.y - OCCHIO_A * 0.78) / cella.y))
			var r1 := int(ceil((centro.y + OCCHIO_A * 0.55) / cella.y))
			for r in range(r0, r1):
				for c in range(c0, c1):
					var p := Vector2((c + 0.5) * cella.x, (r + 0.5) * cella.y)
					var tono := 0.0
					for dx in [-0.25, 0.25]:
						for dy in [-0.25, 0.25]:
							var q: Vector2 = (p + Vector2(dx * cella.x, dy * cella.y) - centro) / OCCHIO_A
							tono += _tono_occhio(Vector2(q.x * lato, q.y), Vector2(iride.x * lato, iride.y), aperto, lato)
					tono *= 0.25
					if absf(tono) < 0.08:
						continue
					var i := clampi(roundi(absf(tono) * (n_rampa - 1)), 1, n_rampa - 1)
					var col := C_ASCII if tono > 0.0 else C_ASCII_SCURO
					_celle_occhi.append([Vector2(c * cella.x, r * cella.y + alza), ASCII_RAMPA[i],
							Color(col, lerpf(0.55, 1.0, absf(tono)))])
	_sfondo.queue_redraw()

# Il tono di un occhio nel punto q (unita' = mezza larghezza; x verso l'ESTERNO dell'occhio,
# cosi' i due occhi sono speculari): + bianco, - scuro, 0 niente (la carta da parati).
func _tono_occhio(q: Vector2, iride: Vector2, aperto: float, lato: float) -> float:
	var u := q.x
	var v := q.y
	if absf(u) > 1.08:
		return 0.0
	var k := OCCHIO_B / OCCHIO_A
	var w := maxf(0.0, 1.0 - u * u)
	# le palpebre: quella di sopra ha la gobba verso l'interno, l'angolo esterno un po' piu' su
	var su_aperta: float = -k * pow(w, 0.65) * (1.0 + 0.12 * u) - 0.03 * u
	var giu: float = k * 0.72 * pow(w, 0.9)
	var su: float = lerpf(giu - 0.01, su_aperta, aperto)
	var piega: float = su_aperta - 0.20 * pow(w, 0.5)
	# FUORI dall'apertura
	if v < su or v > giu or absf(u) > 1.0:
		var dsu := su - v                  # quanto sopra il bordo della palpebra
		if absf(u) <= 1.0 and dsu >= 0.0 and dsu < 0.055:
			return -0.9                    # la linea delle ciglia, spessa
		if u > -0.55 and u < 0.95 and dsu >= 0.055 and dsu < 0.17 * (1.0 - absf(u) * 0.5):
			# le ciglia: pochi tratti corti che piegano verso l'esterno (fitte facevano rumore)
			var t: float = fposmod((u - dsu * 1.2) * 7.0, 1.0)
			if t < 0.2:
				return -0.6
		if absf(u) < 0.8 and absf(v - piega) < 0.02:
			return -0.15                   # la piega della palpebra, appena
		if absf(u) < 0.9 and absf(v - giu - 0.02) < 0.025:
			return -0.3                    # il bordo di sotto
		return 0.0
	# DENTRO: sclera, iride, pupilla, riflesso
	var d := Vector2(u, v).distance_to(iride)
	var raggio := k * 1.05
	var pupilla := raggio * (0.36 + 0.18 * intensita)    # nel vero si dilata
	# il riflesso sta dalla STESSA parte dello schermo in tutti e due (una luce sola)
	var riflesso := Vector2(u, v).distance_to(iride + Vector2(-raggio * 0.35 * -lato, -raggio * 0.38))
	if riflesso < raggio * 0.17:
		return 1.0
	var ombra: float = smoothstep(su, su + 0.16, v)      # sotto la palpebra di sopra e' piu' scuro
	if d < pupilla:
		return -1.0
	if d < raggio:
		# l'iride SCURA (chiara si perdeva nella sclera): fibre a raggiera, bordo piu' scuro
		var ang := atan2(v - iride.y, u - iride.x)
		var fibre: float = sin(ang * 13.0 + sin(ang * 5.0) * 2.0) * 0.5 + 0.5
		var bordo: float = smoothstep(raggio * 0.72, raggio, d)
		var tono: float = lerpf(lerpf(-0.35, -0.62, fibre), -0.85, bordo)
		return lerpf(-0.9, tono, ombra)
	var angoli: float = 1.0 - 0.55 * pow(absf(u), 2.0)  # piu' scura verso gli angoli
	return 0.85 * angoli * lerpf(0.35, 1.0, ombra)

# La cella del terminale (larghezza del carattere, passo delle righe), una volta sola.
func _misura_cella() -> Vector2:
	if _cella == Vector2.ZERO:
		_cella = Vector2(ceilf(Win95.font(ASCII_FONT).get_char_size(ord("M"), ASCII_PUNTI).x), ASCII_RIGA)
	return _cella

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
	for n in [_sfondo, _velo, _velo_strato, _sangue] + _scritte:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_sfondo = null
	_velo = null
	_velo_strato = null
	_sangue = null
	_scritte.clear()
	finita.emit()
	queue_free()
