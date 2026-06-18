extends Node3D

# Clown / Slender (M4): nemico che si AFFACCIA da una porta. NON avanza verso di te:
# compare a uno "spot" (una porta), e se non lo inquadri in tempo il regista chiama
# game_over. Questo script vive sulla RADICE del prefab clown.tscn; il modello 3D e'
# un figlio ("Model"), cosi' puoi rifinire texture/scala in editor senza toccare la
# logica. La finestra di reazione e l'heat stanno nel ThreatDirector.

# Altezza locale del punto "testa": il regista la usa per capire se lo stai mirando.
@export var head_height := 1.7
# Affaccio organico (invece del "pop"): sguscia di lato dalla porta.
@export var lean_time := 0.6        # durata dell'uscita/rientro (s)
@export var lean_offset := 0.7      # quanto parte "dietro lo stipite" (m, di lato)

var _shown_pos: Vector3             # posa visibile (sulla porta)
var _hidden_pos: Vector3            # posa nascosta (di lato, dietro lo stipite)
var _tween: Tween

# Compare a uno spot (porta) sgusciando fuori di lato, rivolto verso il giocatore.
func appear_at(spot_pos: Vector3, look_target: Vector3) -> void:
	_shown_pos = spot_pos
	var to_player: Vector3 = look_target - spot_pos
	to_player.y = 0.0
	if to_player.length() < 0.001:
		to_player = Vector3.FORWARD
	to_player = to_player.normalized()
	# asse laterale orizzontale per sgusciare di lato (lato casuale, per varieta')
	var lateral: Vector3 = Vector3.UP.cross(to_player).normalized()
	if randf() < 0.5:
		lateral = -lateral
	_hidden_pos = spot_pos + lateral * lean_offset
	global_position = _hidden_pos
	look_at(global_position + to_player, Vector3.UP)   # fronte verso il giocatore
	scale = Vector3.ONE * 0.9
	visible = true
	_kill_tween()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "global_position", _shown_pos, lean_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector3.ONE, lean_time * 0.6)

# Si ritira sgusciando indietro, poi sparisce.
func dismiss() -> void:
	if not visible:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", _hidden_pos, lean_time * 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): visible = false)

# Posizione mondo della testa (piedi + altezza), per il test di mira del regista.
func head_world_pos() -> Vector3:
	return global_position + Vector3.UP * head_height

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
