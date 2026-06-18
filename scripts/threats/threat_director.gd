extends Node

# ThreatDirector (M4): regista della minaccia "stanza". Gira SEMPRE, anche mentre sei
# dentro il PC (le minacce crescono mentre investighi). Design "FNAF / affaccio":
#   GRACE -> WAIT (conta verso la prossima apparizione) -> PEEK (il nemico si affaccia
#   a una porta a caso; hai una finestra di reazione) -> se lo INQUADRI in tempo torni
#   a WAIT, altrimenti -> GameManager.game_over("clown").
# Le "porte" sono i Marker3D nel gruppo "enemy_spots" (vedi scenes/corridor.tscn): il
# regista non sa nulla della geometria, quindi puoi spostarle/aggiungerne liberamente.

var player = null         # la Camera3D (player.gd): posa per la mira + is_in_pc()

var _clown = null
var _spots: Array = []
var _glitch_layer: CanvasLayer = null
var _glitch_rect: ColorRect = null

enum State { GRACE, WAIT, PEEK, SEEN, CALM, STOPPED }
var _state: int = State.GRACE
var _timer := 0.0           # tempo nello stato (GRACE/WAIT/CALM)
var _heat := 0.0            # 0..1: "aggressivita'". Sale nel PC, scende sorvegliando.
var _react_left := 0.0      # secondi rimasti per reagire durante un PEEK
var _react_total := 1.0     # durata piena della finestra corrente (per il tell)
var _seen_left := 0.0       # secondi in cui resta visibile dopo averlo inquadrato
var _last_spot = null       # ultima porta usata: per non ripeterla due volte di fila
var _peek_spot = null       # porta dell'affaccio in corso (quella da illuminare)
var _torch: SpotLight3D = null   # la torcia: si punta su una porta col click
var _torch_on := 0.0        # secondi rimasti di torcia accesa
var _rng := RandomNumberGenerator.new()

const CLOWN_SCENE := "res://scenes/enemies/clown.tscn"

# --- Tuning ---
const GRACE_TIME := 30.0            # calma iniziale a inizio run (s)
# Ritmo: dopo OGNI check c'e' una CALMA garantita (CALM_TIME) in cui non appare nessuno
# -> tempo per esplorare. L'heat e' blando (sale poco nel PC).
const CALM_TIME := 25.0             # calma garantita dopo un check (s)
const HEAT_RISE_PC := 0.01          # heat/s mentre sei nel PC (molto blando)
const HEAT_DECAY := 0.05            # heat/s mentre sorvegli la stanza
# Intervallo tra affacci e finestra di reazione: interpolati da heat (calmo -> caldo).
const INTERVAL_CALM := 22.0         # attesa tra affacci a heat 0 (s)
const INTERVAL_HOT := 10.0          # ... a heat 1
const REACT_CALM := 8.0             # finestra di reazione a heat 0 (s): devi anche
const REACT_HOT := 4.0              # ... a heat 1   identificare la porta giusta
const SEEN_LINGER := 1.5            # secondi in cui resta visibile dopo il check
const VIEW_HALF_DEG := 40.0         # oltre questo angolo una porta e' "non inquadrata"
# Torcia
const CLICK_RADIUS := 140.0         # px: quanto vicino alla porta devi cliccare
const TORCH_ON_TIME := 2.0          # secondi di torcia accesa dopo un click

func _ready() -> void:
	_rng.seed = GameManager.run_seed + 4242
	_clown = load(CLOWN_SCENE).instantiate()
	_clown.name = "Clown"
	add_child(_clown)          # Node3D sotto Node: global == local, va bene
	_clown.dismiss()
	_refresh_spots()
	_setup_glitch()
	_setup_torch()

func _refresh_spots() -> void:
	_spots = get_tree().get_nodes_in_group("enemy_spots")

# Ferma del tutto la minaccia (lo chiama il player alla vittoria).
func stop() -> void:
	_state = State.STOPPED
	if _clown != null:
		_clown.dismiss()
	if _torch != null:
		_torch.visible = false
	_reset_tell()

func _process(delta: float) -> void:
	if _state == State.STOPPED:
		return
	_update_heat(delta)
	_update_torch(delta)
	if _state == State.GRACE:
		_timer += delta
		if _timer >= GRACE_TIME:
			_to_wait()
	elif _state == State.WAIT:
		_timer += delta
		if _timer >= _interval():
			_peek()
	elif _state == State.PEEK:
		_react_left -= delta
		_update_tell()
		# si scaccia SOLO illuminando la porta giusta con la torcia (torch_click_at);
		# qui resta solo il fallimento per tempo scaduto.
		if _react_left <= 0.0:
			_clown.dismiss()
			_reset_tell()
			_state = State.STOPPED
			GameManager.game_over("clown")
	elif _state == State.SEEN:
		_seen_left -= delta
		if _seen_left <= 0.0:
			_clown.dismiss()
			_to_calm()
	elif _state == State.CALM:
		_timer += delta            # finestra di esplorazione garantita
		if _timer >= CALM_TIME:
			_to_wait()

func _to_wait() -> void:
	_state = State.WAIT
	_timer = 0.0

func _to_calm() -> void:
	_state = State.CALM
	_timer = 0.0

# Affaccia il nemico a una porta a caso e apre la finestra di reazione.
func _peek() -> void:
	if _spots.is_empty():
		_refresh_spots()
		if _spots.is_empty():
			_to_wait()        # nessuno spot: riprova piu' tardi (niente crash)
			return
	var spot: Node3D = _choose_spot()
	_last_spot = spot
	_peek_spot = spot
	_clown.appear_at(spot.global_position, player.global_transform.origin)
	_react_total = _react_time()
	_react_left = _react_total
	_state = State.PEEK

# Sceglie una porta "furba": mai due volte di fila la stessa e, se possibile, una che
# NON stai inquadrando ora (cosi' fissare una porta non ti mette al sicuro).
func _choose_spot() -> Node3D:
	var candidates: Array = []
	for s in _spots:
		if s != _last_spot:
			candidates.append(s)
	if candidates.is_empty():
		candidates = _spots.duplicate()
	var unwatched: Array = []
	for s in candidates:
		if not _is_spot_in_view(s):
			unwatched.append(s)
	var pool: Array = candidates if unwatched.is_empty() else unwatched
	var chosen: Node3D = pool[_rng.randi() % pool.size()]
	return chosen

# True se la porta e' nel campo visivo attuale (entro ~mezzo FOV dalla direzione di sguardo).
func _is_spot_in_view(s) -> bool:
	var cam_o: Vector3 = player.global_transform.origin
	var fwd: Vector3 = -player.global_transform.basis.z
	var to: Vector3 = (s.global_position + Vector3.UP) - cam_o
	if to.length() < 0.01:
		return true
	return rad_to_deg(fwd.angle_to(to)) <= VIEW_HALF_DEG

# --- torcia: la difesa ---
func _setup_torch() -> void:
	_torch = SpotLight3D.new()
	_torch.visible = false
	_torch.light_energy = 6.0
	_torch.spot_range = 14.0
	_torch.spot_angle = 20.0
	_torch.light_color = Color(1.0, 0.97, 0.85)
	add_child(_torch)

func _update_torch(delta: float) -> void:
	if _torch_on > 0.0:
		_torch_on -= delta
		if _torch_on <= 0.0 and _torch != null:
			_torch.visible = false

# Click in stanza: trova la porta piu' vicina al mouse, ci punta la torcia e - se e'
# l'affaccio in corso - scaccia il nemico. La porta sbagliata illumina soltanto (nessun
# effetto, e il tempo continua a scorrere). Usa la proiezione su schermo dei marker:
# niente collisioni nel corridoio, le porte restano semplici Marker3D.
func torch_click_at(mouse_pos: Vector2) -> void:
	if player.is_in_pc():
		return
	var best = null
	var best_d := CLICK_RADIUS
	for s in _spots:
		var w: Vector3 = s.global_position + Vector3.UP * 1.0
		if player.is_position_behind(w):
			continue
		var sp: Vector2 = player.unproject_position(w)
		var d: float = mouse_pos.distance_to(sp)
		if d < best_d:
			best_d = d
			best = s
	if best == null:
		return
	_aim_torch(best)
	if _state == State.PEEK and best == _peek_spot:
		_reset_tell()
		_seen_left = _jit(SEEN_LINGER)
		_state = State.SEEN

func _aim_torch(door) -> void:
	if _torch == null:
		return
	_torch.global_position = player.global_transform.origin
	_torch.look_at(door.global_position + Vector3.UP * 1.0, Vector3.UP)
	_torch.visible = true
	_torch_on = TORCH_ON_TIME

# --- heat: aggiornamento e timer derivati ---
func _update_heat(delta: float) -> void:
	if player.is_in_pc():
		_heat += HEAT_RISE_PC * delta      # ti esponi nel PC -> sale
	else:
		_heat -= HEAT_DECAY * delta        # sorvegli la stanza -> scende
	_heat = clampf(_heat, 0.0, 1.0)

func _interval() -> float:
	return _jit(lerpf(INTERVAL_CALM, INTERVAL_HOT, _heat))

func _react_time() -> float:
	return lerpf(REACT_CALM, REACT_HOT, _heat)

func _jit(t: float) -> float:
	return t * (1.0 + _rng.randf_range(-0.15, 0.15))

# --- tell visivo (solo dentro il PC, dove non vedi la stanza) ---
# Riusa scripts/os/glitch.gdshader: avvisa che c'e' un'affacciata in corso e cresce
# man mano che la finestra di reazione si esaurisce.
func _setup_glitch() -> void:
	_glitch_layer = CanvasLayer.new()
	_glitch_layer.layer = 15   # sopra l'overlay PC (10), sotto la morte (50)
	add_child(_glitch_layer)
	_glitch_rect = ColorRect.new()
	_glitch_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/os/glitch.gdshader")
	mat.set_shader_parameter("intensity", 0.0)
	_glitch_rect.material = mat
	_glitch_rect.visible = false
	_glitch_layer.add_child(_glitch_rect)

func _update_tell() -> void:
	var show_glitch: bool = player.is_in_pc()
	if _glitch_rect == null:
		return
	_glitch_rect.visible = show_glitch
	if show_glitch:
		var urgency: float = 1.0 - clampf(_react_left / maxf(0.01, _react_total), 0.0, 1.0)
		# piu' heat = glitch piu' marcato gia' a inizio finestra
		var t: float = clampf(maxf(urgency, _heat * 0.6), 0.0, 1.0)
		_glitch_rect.material.set_shader_parameter("intensity", lerpf(0.06, 0.55, t))

func _reset_tell() -> void:
	if _glitch_rect != null:
		_glitch_rect.visible = false
