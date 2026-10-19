class_name NemicoAffaccio
extends Node3D

# Un nemico che si AFFACCIA da uno "spot" (una porta del corridoio o la finestra) e NON
# avanza verso di te: compare sgusciando di lato e, quando se ne va, torna dietro lo
# stipite. E' la base comune del Jester (jester.gd) e di HaloMan (halo_man.gd); chi
# decide QUANDO e PERCHE' se ne va e' il ThreatDirector. Lo script vive sulla RADICE del
# prefab; il modello e' un figlio, cosi' si rifinisce in editor senza toccare la logica.

# Altezza locale del punto "testa".
@export var head_height := 1.7
# Affaccio organico (invece del "pop"): sguscia di lato dallo spot.
@export var lean_time := 0.6        # durata dell'uscita/rientro (s)
@export var lean_offset := 0.7      # quanto parte "dietro lo stipite" (m, di lato)

var _shown_pos: Vector3             # posa visibile (sullo spot)
var _hidden_pos: Vector3            # posa nascosta (di lato, dietro lo stipite)
var _tween: Tween

# Parte SEMPRE nascosto (il prefab ha visible=true di default): cosi' all'avvio non
# "scivola" verso l'origine prima di sparire, e dismiss() resta un no-op finche' non appare.
func _ready() -> void:
	visible = false

# Compare a uno spot sgusciando fuori di lato, rivolto verso il giocatore.
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

# A che punto e' dell'uscita di scena: 0 = tutto fuori sullo spot, 1 = sparito dietro lo
# stipite. Il regista la muove avanti mentre lo illumini e indietro quando smetti, quindi
# lo si VEDE andarsene (e tornare, se lo lasci).
func ritira(t: float) -> void:
	if not visible:
		return
	_kill_tween()
	global_position = _shown_pos.lerp(_hidden_pos, clampf(t, 0.0, 1.0))

# Si ritira sgusciando indietro, poi sparisce.
func dismiss() -> void:
	if not visible:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(self, "global_position", _hidden_pos, lean_time * 0.7) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.tween_callback(func(): visible = false)

# Sparisce subito, senza uscita (fine partita, debug).
func nascondi() -> void:
	_kill_tween()
	visible = false

# Posizione mondo della testa (piedi + altezza).
func head_world_pos() -> Vector3:
	return global_position + Vector3.UP * head_height

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
