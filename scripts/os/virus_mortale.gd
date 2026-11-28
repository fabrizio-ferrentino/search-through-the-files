class_name VirusMortale
extends Node

# Il virus MORTALE (M5, GDD §7.2 "shutdown-or-die"): il FANTASMA del PC, un'apparizione
# (apparizione.gd) di Apparizione.FANTASMI -- il bambino o gli occhi -- che RESTA. Se il PC non
# viene spento entro DURATA secondi -- Avvio > Arresta, oppure il pulsante del case -- e'
# game_over("virus"). Niente falsi allarmi del fantasma (proprietario, 28/11/2026): se lo vedi,
# e' vero. UNA FASE SOLA (proprietario, 18/10/2026): cresce piano per tutta la DURATA
# (crescita), ma resta se stesso.
# Vive DENTRO l'OS, quindi si vede anche sul monitor 3D dalla stanza. Non usa
# glitch.gdshader: quello e' l'avviso del nemico nel corridoio. pulisci() toglie tutto: lo
# chiama il regista quando il PC viene spento in tempo (o le minacce del PC con F8).

signal scaduto

const DURATA := 10.0      # proprietario: 25 s erano troppi

var _os: OSDesktop = null
var _t := 0.0
var _finito := false
var _app: Apparizione = null

# apparizione = uno di Apparizione.FANTASMI per sceglierlo (i test); "" = secondo i PESI.
func setup(os: OSDesktop, rng: RandomNumberGenerator, apparizione := "") -> void:
	_os = os
	name = "VirusMortale"
	if apparizione == "":
		apparizione = Apparizione.scegli(rng)
	assert(Apparizione.FANTASMI.has(apparizione), "il virus mortale e' solo un fantasma: " + apparizione)
	# la fa crescere QUESTO nodo (avanza), cosi' il virus e i test vanno al passo
	_app = Apparizione.new()
	os.add_child(_app)
	_app.setup(os, apparizione, rng)
	_app.crescita = DURATA
	_app.set_process(false)

func progresso() -> float:
	return clampf(_t / DURATA, 0.0, 1.0)

func apparizione() -> Apparizione:
	return _app if _app != null and is_instance_valid(_app) else null

func _process(delta: float) -> void:
	avanza(delta)

# Il passo del virus, pubblico perche' il test lo fa girare a mano.
func avanza(delta: float) -> void:
	if _finito:
		return
	_t += delta
	if apparizione() != null:
		_app.avanza(delta)
	if _t >= DURATA:
		_finito = true
		scaduto.emit()

# Toglie ogni traccia.
func pulisci() -> void:
	_finito = true
	set_process(false)
	if apparizione() != null:
		_app.pulisci()
	queue_free()
