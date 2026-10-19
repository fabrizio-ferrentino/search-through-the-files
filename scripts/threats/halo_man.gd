extends NemicoAffaccio

# HaloMan (M4): la controparte del Jester. Si affaccia dagli stessi posti (le porte del
# corridoio e la finestra), ma NON va illuminato: puntargli la torcia uccide. Se ne va
# solo se SPEGNI IL PC. Arriva solo a PC acceso (e' la luce dello schermo a chiamarlo) e
# porta una luce sua, l'aureola: lo vedi anche al buio, al contrario del Jester, e lo
# riconosci PRIMA di accendere la torcia. Le regole stanno nel ThreatDirector.
# Il modello di halo_man.tscn e' un SEGNAPOSTO (capsula scura + aureola).

# L'aureola pulsa piano: e' l'unica cosa viva di lui.
@export var pulsazione := 0.6       # giri al secondo
var _t := 0.0
var _luce: OmniLight3D = null
var _energia := 1.0

func _ready() -> void:
	super()
	_luce = find_child("LuceAureola", true, false) as OmniLight3D
	if _luce != null:
		_energia = _luce.light_energy

func _process(delta: float) -> void:
	if not visible or _luce == null:
		return
	_t += delta
	_luce.light_energy = _energia * (0.8 + 0.2 * sin(_t * TAU * pulsazione))
