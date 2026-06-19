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
var _peek_spot = null       # spot dell'affaccio in corso
var _peek_zone := "right"   # zona da illuminare per scacciarlo: "right" (corridoio) / "left" (finestra)
var _torch: SpotLight3D = null   # la torcia: si punta su una porta col click
var _torch_on := 0.0        # secondi rimasti di torcia accesa
var _torch_energy := 5.0    # luminosita' "piena" (per il flash debole a batteria scarica)
var _battery := 100.0       # carica della torcia, 0..BATTERY_MAX
var _bat_layer: CanvasLayer = null
var _bat_bg: ColorRect = null
var _bat_fill: ColorRect = null
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
# Torcia
const AIM_TOL_DEG := 30.0           # quanto devi essere girato "verso la zona" per illuminarla
const TORCH_ON_TIME := 2.0          # secondi di torcia accesa dopo un flash
# Batteria: si scarica a ogni flash, si ricarica quando la torcia e' spenta. A batteria
# scarica il flash e' debole e NON scaccia (cosi' non puoi spammare / non sprechi flash).
const BATTERY_MAX := 100.0
const BATTERY_COST := 16.0          # carica spesa per ogni flash
const BATTERY_RECHARGE := 6.0       # ricarica al secondo (mentre la torcia e' spenta)
const WEAK_ENERGY_MUL := 0.22       # luminosita' del flash "scarico"

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
	if _bat_layer != null:
		_bat_layer.visible = false
	_reset_tell()

func _process(delta: float) -> void:
	if _state == State.STOPPED:
		return
	_update_heat(delta)
	_update_torch(delta)
	# Debug: minacce disabilitate (F11): niente affacci, niente game_over.
	# Torcia e batteria restano attive.
	if not GameManager.threats_enabled:
		if _clown != null and _clown.visible:
			_clown.dismiss()
		_reset_tell()
		return
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
		# si scaccia SOLO illuminando con la torcia la zona del nemico (torch_flash);
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
	_peek_zone = _zone_of(spot)
	_clown.appear_at(spot.global_position, player.global_transform.origin)
	_react_total = _react_time()
	_react_left = _react_total
	_state = State.PEEK

# Sceglie uno spot a caso (solo per varieta'), mai due volte di fila lo stesso.
func _choose_spot() -> Node3D:
	var candidates: Array = []
	for s in _spots:
		if s != _last_spot:
			candidates.append(s)
	if candidates.is_empty():
		candidates = _spots.duplicate()
	var chosen: Node3D = candidates[_rng.randi() % candidates.size()]
	return chosen

# Zona da illuminare per scacciarlo. Default "right" (corridoio); uno spot nel gruppo
# "spot_left" e' la finestra di sinistra (quando la creerai). Il Ghost dietro NON usa la
# torcia: avra' una gestione propria.
func _zone_of(spot) -> String:
	if spot.is_in_group("spot_left"):
		return "left"
	return "right"

# True se la camera e' girata verso la zona (corridoio = destra, finestra = sinistra).
func _facing_zone(zone: String) -> bool:
	var target: float = player.pos_left if zone == "left" else player.pos_right
	var yaw: float = player.rotation_degrees.y
	return absf(yaw - target) <= AIM_TOL_DEG

# --- torcia: la difesa ---
func _setup_torch() -> void:
	# Torcia "pulita" stile FNAF 4: un fascio LARGO che illumina tutto il corridoio davanti
	# a te (non una porta specifica). Regola spot_angle (ampiezza) / light_energy (luce).
	_torch = SpotLight3D.new()
	_torch.visible = false
	_torch.light_energy = 5.0
	_torch.spot_range = 18.0
	_torch.spot_angle = 20.0        # fascio (non troppo largo): illumina dove miri
	_torch.spot_angle_attenuation = 1.0
	_torch.shadow_enabled = true    # ombre: il fascio sembra luce VERA (il nemico fa ombra)
	_torch.light_color = Color(1.0, 0.97, 0.85)
	add_child(_torch)
	_torch_energy = _torch.light_energy
	_setup_battery_ui()

func _update_torch(delta: float) -> void:
	if _torch_on > 0.0:
		_torch_on -= delta
		if _torch_on <= 0.0 and _torch != null:
			_torch.visible = false
	else:
		_battery = minf(BATTERY_MAX, _battery + BATTERY_RECHARGE * delta)   # ricarica
	_update_battery_ui()

# Flash della torcia (click in stanza): illumina LARGO dove guardi. Se c'e' un affaccio
# nella ZONA che stai illuminando (corridoio a destra, finestra a sinistra), lo scaccia.
# Non serve mirare la porta esatta: basta essere girato verso quella zona. Batteria
# scarica -> flash debole, nessun effetto.
func torch_flash() -> void:
	if player.is_in_pc():
		return
	if _battery < BATTERY_COST:
		_flash(true)               # batteria scarica: debole, non scaccia
		return
	_battery -= BATTERY_COST
	_flash(false)
	if _state == State.PEEK and _facing_zone(_peek_zone):
		_reset_tell()
		_seen_left = _jit(SEEN_LINGER)
		_state = State.SEEN

func _flash(weak: bool) -> void:
	if _torch == null:
		return
	# Luce VERA, non "stampata": parte dalla MANO (un po' sotto/destra dell'occhio) e punta
	# ORIZZONTALE in profondita' nel corridoio (all'altezza del nemico, non sul pavimento)
	# -> il fascio graza pareti/nemico e fa ombre, invece di un cerchio piatto sullo schermo.
	var cam_t: Transform3D = player.global_transform
	var fwd: Vector3 = -cam_t.basis.z
	var flat: Vector3 = Vector3(fwd.x, 0.0, fwd.z)
	if flat.length() < 0.01:
		flat = fwd
	flat = flat.normalized()
	_torch.global_position = cam_t.origin + cam_t.basis.x * 0.2 - cam_t.basis.y * 0.1
	var aim: Vector3 = cam_t.origin + flat * 8.0
	aim.y = cam_t.origin.y - 0.2
	_torch.look_at(aim, Vector3.UP)
	_torch.light_energy = _torch_energy * (WEAK_ENERGY_MUL if weak else 1.0)
	_torch.visible = true
	_torch_on = TORCH_ON_TIME * (0.4 if weak else 1.0)

# --- barra batteria (HUD, visibile solo in stanza) ---
func _setup_battery_ui() -> void:
	_bat_layer = CanvasLayer.new()
	_bat_layer.layer = 14
	add_child(_bat_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bat_layer.add_child(root)
	_bat_bg = ColorRect.new()
	_bat_bg.color = Color(0, 0, 0, 0.55)
	_bat_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bat_bg.anchor_top = 1.0
	_bat_bg.anchor_bottom = 1.0
	_bat_bg.offset_left = 24
	_bat_bg.offset_right = 228
	_bat_bg.offset_top = -52
	_bat_bg.offset_bottom = -24
	root.add_child(_bat_bg)
	_bat_fill = ColorRect.new()
	_bat_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bat_fill.position = Vector2(2, 2)
	_bat_fill.size = Vector2(200, 24)
	_bat_bg.add_child(_bat_fill)

func _update_battery_ui() -> void:
	if _bat_layer == null:
		return
	_bat_layer.visible = not player.is_in_pc()
	if _bat_fill != null:
		var f: float = clampf(_battery / BATTERY_MAX, 0.0, 1.0)
		_bat_fill.size = Vector2(200.0 * f, 24.0)
		_bat_fill.color = Color(0.85, 0.2, 0.2).lerp(Color(0.3, 0.85, 0.35), f)

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
