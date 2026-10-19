extends Node3D

# Ghosty (M4, nome provvisorio): attacca SOLO DA DIETRO. Piu' a lungo non ti giri, piu'
# si avvicina; finche' lo guardi resta fermo dove e' arrivato; appena gli punti contro la
# torcia accesa, sparisce. Qui c'e' solo il CORPO (dove sta, come si vede): il ritmo, cioe'
# quanto avanza e quando colpisce, sta nel ThreatDirector, che chiama metti_a(t).
# Il modello di ghosty.tscn e' un SEGNAPOSTO (figura pallida e semitrasparente).

# Fluttua: su e giu' piano, non cammina.
@export var fluttua_ampiezza := 0.05
@export var fluttua_velocita := 0.8     # giri al secondo

var _da := Vector3.ZERO      # dove compare (lontano, in fondo alla stanza)
var _a := Vector3.ZERO       # dove ti prende (subito alle tue spalle)
var _guarda := Vector3.ZERO  # verso chi guarda (la testa del giocatore)
var _t := 0.0
var _base := Vector3.ZERO

func _ready() -> void:
	visible = false

# Il percorso: da "da" (lontano) ad "a" (vicino), sempre rivolto verso "guarda".
func percorso(da: Vector3, a: Vector3, guarda: Vector3) -> void:
	_da = da
	_a = a
	_guarda = guarda

# Dove sta lungo il percorso (0 = in fondo, 1 = alle tue spalle). Mostra il corpo.
func metti_a(t: float) -> void:
	_base = _da.lerp(_a, clampf(t, 0.0, 1.0))
	global_position = _base
	var verso := Vector3(_guarda.x, _base.y, _guarda.z)
	if verso.distance_to(_base) > 0.01:
		look_at(verso, Vector3.UP)
	visible = true

# Sparisce di colpo (la torcia, o la fine).
func sparisci() -> void:
	visible = false

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	global_position = _base + Vector3.UP * sin(_t * TAU * fluttua_velocita) * fluttua_ampiezza
