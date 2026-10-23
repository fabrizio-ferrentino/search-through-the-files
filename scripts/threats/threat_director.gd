extends Node

# ThreatDirector (M4): il regista delle minacce della STANZA. Gira SEMPRE, anche mentre
# sei dentro il PC (le minacce crescono mentre investighi). Tre nemici, decisi dal
# proprietario (19/10/2026):
#   JESTER  si affaccia da una delle porte del corridoio (destra) o dalla FINESTRA
#           (sinistra). E' buio: lo vedi solo con la torcia. Lo scacci TENENDOLO
#           ILLUMINATO: se ne va in USCITA_MIN..USCITA_MAX secondi (a caso, ogni volta);
#           se smetti prima, torna fuori piano. Se il tempo scade -> game_over("jester").
#   HALOMAN la sua controparte: stessi posti, ma NON va illuminato: puntargli contro la
#           torcia e' la morte (game_over("halo")). Se ne va solo se SPEGNI IL PC
#           (pulsante del case o Avvio > Arresta). Arriva solo a PC acceso, e porta una
#           luce sua, cosi' lo riconosci prima di accendere. Tempo scaduto -> stessa fine.
#   GHOSTY  (nome provvisorio) attacca solo DA DIETRO: piu' a lungo non ti giri, piu' si
#           avvicina; mentre lo guardi resta fermo; appena gli punti contro la torcia
#           accesa sparisce. Se arriva alle tue spalle -> game_over("ghosty").
# Jester e HaloMan si dividono UN SOLO turno di affaccio (mai insieme): il ritmo e' quello
# di prima, GRACE -> WAIT -> PEEK (reazione) -> CALM (calma garantita). Ghosty ha un ritmo
# suo e corre in parallelo, ma non colpisce mentre qualcuno si affaccia o mentre c'e' il
# virus mortale del PC: aspetta all'ultimo passo (due minacce mortali nello stesso istante
# non sono tensione, sono una lotteria -- la stessa regola che vale fra affacci e virus).
# Gli spot di affaccio sono i Marker3D nel gruppo "enemy_spots" (le tre porte di
# scenes/corridor.tscn e SpotFinestra di scenes/window_left.tscn; quelli anche in
# "spot_left" sono la zona di sinistra). Il percorso di Ghosty sono due Marker3D nella
# stanza, nei gruppi "ghosty_lontano" e "ghosty_vicino". Il regista non sa nulla della
# geometria: sposta i marker e basta.
# LA TORCIA (19/10/2026) non e' piu' un lampo di 2 s: si accende TENENDO PREMUTO il tasto
# del mouse e si spegne rilasciandolo (torch_accendi / torch_spegni, chiamate da
# player.gd). La batteria si scarica mentre e' accesa e si ricarica da spenta; vuota, la
# torcia si spegne e non si riaccende finche' non ha di nuovo BATTERIA_RIACCENDE.

var player = null         # la Camera3D (player.gd): posa per la mira + is_in_pc()
var virus = null          # il VirusDirector (M5): niente affacci durante il virus mortale

# Prova: invece di chiamare game_over, annota la causa in "morte" (i test controllano
# piu' morti senza chiudere la partita). Mai true nel gioco.
var solo_annota_morte := false
var morte := ""

var _jester: NemicoAffaccio = null
var _halo: NemicoAffaccio = null
var _ghosty = null
var _nemico: NemicoAffaccio = null   # chi si sta affacciando adesso
var _chi := ""                       # "jester" / "halo" (il nemico dell'affaccio in corso)
var _ultimo_chi := ""
var _spots: Array = []
var _glitch_layer: CanvasLayer = null
var _glitch_rect: ColorRect = null
var _velo_ghosty: ColorRect = null

enum State { GRACE, WAIT, PEEK, CALM, STOPPED }
var _state: int = State.GRACE
var _timer := 0.0           # tempo nello stato (GRACE/WAIT/CALM)
var _heat := 0.0            # 0..1: "aggressivita'". Sale nel PC, scende sorvegliando.
var _react_left := 0.0      # secondi rimasti per reagire durante un PEEK
var _react_total := 1.0     # durata piena della finestra corrente (per il tell)
var _uscita := 0.0          # Jester: 0..1, quanto se n'e' gia' andato (illuminandolo)
var _uscita_serve := 1.5    # Jester: secondi di luce che servono stavolta (1-2, a caso)
var _last_spot = null       # ultimo spot usato: per non ripeterlo due volte di fila
var _peek_spot = null       # spot dell'affaccio in corso
var _peek_zone := "right"   # "right" (corridoio) / "left" (finestra)
var _torch: SpotLight3D = null
var _torch_energy := 5.0    # luminosita' "piena"
var _battery := 100.0       # carica della torcia, 0..BATTERY_MAX
var _bat_layer: CanvasLayer = null
var _bat_bg: ColorRect = null
var _bat_fill: ColorRect = null
var _rng := RandomNumberGenerator.new()
# Ghosty
var _g_arriva := false      # false = non c'e' (aspetta il suo turno), true = sta arrivando
var _g_timer := 0.0         # quanto manca al suo arrivo
var _g_p := 0.0             # 0..1: quanto e' vicino (1 = alle tue spalle)

const JESTER_SCENE := "res://scenes/enemies/jester.tscn"
const HALO_SCENE := "res://scenes/enemies/halo_man.tscn"
const GHOSTY_SCENE := "res://scenes/enemies/ghosty.tscn"

# --- Tuning: affacci ---
const GRACE_TIME := 30.0            # calma iniziale a inizio run (s)
# Dopo OGNI affaccio c'e' una CALMA garantita (CALM_TIME) in cui non si affaccia nessuno.
const CALM_TIME := 25.0
const HEAT_RISE_PC := 0.01          # heat/s mentre sei nel PC (molto blando)
const HEAT_DECAY := 0.05            # heat/s mentre sorvegli la stanza
const INTERVAL_CALM := 22.0         # attesa tra affacci a heat 0 (s)
const INTERVAL_HOT := 10.0          # ... a heat 1
const REACT_CALM := 8.0             # Jester: finestra di reazione a heat 0 (s)
const REACT_HOT := 4.0              # ... a heat 1
const USCITA_MIN := 1.0             # Jester: secondi di luce per scacciarlo (a caso fra i due)
const USCITA_MAX := 2.0
const RIENTRO := 0.5                # Jester non illuminato: torna fuori a questa velocita'
# HaloMan: per mandarlo via devi uscire dal PC, girarti al centro e spegnere: piu' tempo
const HALO_REACT_CALM := 12.0
const HALO_REACT_HOT := 8.0
const HALO_PROB := 0.4              # probabilita' che l'affaccio sia suo (a PC acceso)
# --- Tuning: Ghosty ---
const GHOSTY_PRIMO := [45.0, 70.0]  # quando arriva la prima volta (s di partita)
const GHOSTY_PAUSA := [25.0, 45.0]  # quanto sta via dopo che l'hai scacciato
const GHOSTY_DURATA_CALM := 60.0    # da quando parte a quando ti prende, senza mai girarti
const GHOSTY_DURATA_HOT := 40.0     # ... a heat 1
const GHOSTY_VISIBILE := 0.15       # prima di qui non e' ancora entrato nella stanza
const GHOSTY_TRATTIENE := 0.97      # dove aspetta se in quel momento non puo' colpire
const GHOSTY_TELL_DA := 0.35        # da qui il PC comincia a raffreddarsi ai bordi
# --- Torcia ---
const AIM_TOL_DEG := 30.0           # quanto devi essere girato "verso la zona" per illuminarla
const BATTERY_MAX := 100.0
const BATTERY_DRAIN := 12.0         # carica al secondo mentre e' accesa (~8 s di fila)
const BATTERY_RECHARGE := 6.0       # ricarica al secondo mentre e' spenta
const BATTERIA_RIACCENDE := 15.0    # sotto questa, da vuota, non si riaccende
const BATTERIA_DEBOLE := 20.0       # sotto questa la luce tremola

func _ready() -> void:
	add_to_group("regista_stanza")     # cosi' lo trova il pannello di debug (F12)
	_rng.seed = GameManager.run_seed + 4242
	_jester = load(JESTER_SCENE).instantiate()
	_jester.name = "Jester"
	add_child(_jester)          # Node3D sotto Node: global == local, va bene
	_halo = load(HALO_SCENE).instantiate()
	_halo.name = "HaloMan"
	add_child(_halo)
	_ghosty = load(GHOSTY_SCENE).instantiate()
	_ghosty.name = "Ghosty"
	add_child(_ghosty)
	_refresh_spots()
	_prepara_ghosty()
	_setup_glitch()
	_setup_torch()

# Qualcuno si sta affacciando adesso? (il VirusDirector non fa partire virus intanto)
func in_agguato() -> bool:
	return _state == State.PEEK

func _refresh_spots() -> void:
	_spots = get_tree().get_nodes_in_group("enemy_spots")

# Ferma del tutto le minacce (lo chiama il player alla vittoria).
func stop() -> void:
	_state = State.STOPPED
	_jester.nascondi()
	_halo.nascondi()
	_ghosty.sparisci()
	if _torch != null:
		_torch.visible = false
	if _bat_layer != null:
		_bat_layer.visible = false
	_reset_tell()
	_velo_ghosty.visible = false

func _process(delta: float) -> void:
	if _state == State.STOPPED:
		return
	_update_heat(delta)
	_update_torch(delta)
	# Debug: minacce della STANZA disabilitate (F11): niente affacci, niente Ghosty, niente
	# game_over. La torcia resta. Si resta in CALM, cosi' riattivando si riparte da una
	# finestra sicura (mai un affaccio "congelato" che ti uccide al riavvio).
	if not GameManager.room_threats_enabled:
		if _nemico != null:
			_nemico.nascondi()
			_nemico = null
		_reset_tell()
		_state = State.CALM
		_timer = 0.0
		_ghosty_via()
		return
	_avanza_affacci(delta)
	if _state != State.STOPPED:
		_avanza_ghosty(delta)

# ---------------- Jester e HaloMan: il turno di affaccio ----------------

func _avanza_affacci(delta: float) -> void:
	if _state == State.GRACE:
		_timer += delta
		if _timer >= GRACE_TIME:
			_to_wait()
	elif _state == State.WAIT:
		_timer += delta
		# durante il virus mortale del PC si aspetta (e il VirusDirector fa lo stesso)
		if _timer >= _interval() and not (virus != null and virus.mortale_in_corso()):
			_peek()
	elif _state == State.PEEK:
		if _chi == "jester":
			# lo scacci TENENDOLO illuminato: avanza verso l'uscita finche' c'e' luce; senza
			# luce torna fuori piano e il tempo per reagire riprende a scorrere
			if _torcia_accesa() and _facing_zone(_peek_zone):
				_uscita += delta / _uscita_serve
			else:
				_uscita = maxf(0.0, _uscita - delta / _uscita_serve * RIENTRO)
				_react_left -= delta
			if _uscita > 0.0:
				_jester.ritira(_uscita)
			if _uscita >= 1.0:
				_fine_affaccio()
				return
		else:
			# HaloMan: la torcia NON va puntata su di lui -- illuminarlo e' la morte
			# (proprietario, 19/10/2026). Si manda via solo spegnendo il PC.
			if _torcia_accesa() and _facing_zone(_peek_zone):
				_halo.nascondi()
				_nemico = null
				_reset_tell()
				_morte("halo")
				return
			_react_left -= delta
			if not GameManager.pc_on:
				_halo.dismiss()
				_fine_affaccio()
				return
		_update_tell()
		if _react_left <= 0.0:
			var causa := _chi
			_nemico.nascondi()
			_nemico = null
			_reset_tell()
			_morte(causa)
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

func _fine_affaccio() -> void:
	if _chi == "jester":
		_jester.nascondi()       # e' gia' dietro lo stipite: sparisce
	_nemico = null
	_reset_tell()
	_to_calm()

# Chi si affaccia stavolta: HaloMan solo a PC acceso, e meno spesso se l'ultimo era lui.
func _scegli_chi() -> String:
	if not GameManager.pc_on:
		return "jester"
	var p: float = HALO_PROB * (0.5 if _ultimo_chi == "halo" else 1.0)
	return "halo" if _rng.randf() < p else "jester"

# Affaccia il nemico a uno spot a caso e apre la finestra di reazione.
func _peek(chi := "") -> void:
	if _spots.is_empty():
		_refresh_spots()
		if _spots.is_empty():
			_to_wait()        # nessuno spot: riprova piu' tardi (niente crash)
			return
	_chi = chi if chi != "" else _scegli_chi()
	_ultimo_chi = _chi
	_nemico = _halo if _chi == "halo" else _jester
	var spot: Node3D = _choose_spot()
	_last_spot = spot
	_peek_spot = spot
	_peek_zone = _zone_of(spot)
	_nemico.appear_at(spot.global_position, player.global_transform.origin)
	_uscita = 0.0
	_uscita_serve = _rng.randf_range(USCITA_MIN, USCITA_MAX)
	_react_total = _react_time() if _chi == "jester" else _halo_react_time()
	_react_left = _react_total
	_state = State.PEEK

# Sceglie uno spot a caso, mai due volte di fila lo stesso.
func _choose_spot() -> Node3D:
	var candidates: Array = []
	for s in _spots:
		if s != _last_spot:
			candidates.append(s)
	if candidates.is_empty():
		candidates = _spots.duplicate()
	var chosen: Node3D = candidates[_rng.randi() % candidates.size()]
	return chosen

# Zona dello spot: "left" se e' nel gruppo "spot_left" (la finestra), se no "right".
func _zone_of(spot) -> String:
	if spot.is_in_group("spot_left"):
		return "left"
	return "right"

# True se la camera e' girata verso la zona (destra, sinistra o dietro).
func _facing_zone(zone: String) -> bool:
	var target: float = player.pos_right
	if zone == "left":
		target = player.pos_left
	elif zone == "back":
		target = player.pos_back
	var yaw: float = player.rotation_degrees.y
	return absf(wrapf(yaw - target, -180.0, 180.0)) <= AIM_TOL_DEG

# ---------------- Ghosty: da dietro ----------------

func _prepara_ghosty() -> void:
	var lontano: Node3D = get_tree().get_first_node_in_group("ghosty_lontano")
	var vicino: Node3D = get_tree().get_first_node_in_group("ghosty_vicino")
	var occhio: Vector3 = player.global_position if player != null else Vector3.ZERO
	# senza marker: un percorso dritto alle spalle della camera (che guarda verso -Z)
	var da: Vector3 = lontano.global_position if lontano != null else occhio + Vector3(0, -0.95, 4.2)
	var a: Vector3 = vicino.global_position if vicino != null else occhio + Vector3(0, -0.95, 1.1)
	_ghosty.percorso(da, a, occhio)
	_g_arriva = false
	_g_timer = _rng.randf_range(GHOSTY_PRIMO[0], GHOSTY_PRIMO[1])
	_g_p = 0.0

func _avanza_ghosty(delta: float) -> void:
	if not _g_arriva:
		_g_timer -= delta
		if _g_timer <= 0.0:
			_g_arriva = true
			_g_p = 0.0
		_aggiorna_velo()
		return
	var guardato := _guardi_dietro()
	if guardato and _torcia_accesa() and _g_p >= GHOSTY_VISIBILE:
		_ghosty_via()                      # la luce lo cancella
		return
	if not guardato:
		_g_p += delta / lerpf(GHOSTY_DURATA_CALM, GHOSTY_DURATA_HOT, _heat)
	# non colpisce mentre qualcuno si affaccia o c'e' il virus mortale: aspetta all'ultimo
	# passo, fermo, finche' non tocca di nuovo a lui
	if _state == State.PEEK or (virus != null and virus.mortale_in_corso()):
		_g_p = minf(_g_p, GHOSTY_TRATTIENE)
	if _g_p >= 1.0:
		_ghosty.sparisci()
		_g_arriva = false
		_velo_ghosty.visible = false
		_morte("ghosty")
		return
	if _g_p >= GHOSTY_VISIBILE:
		_ghosty.metti_a(inverse_lerp(GHOSTY_VISIBILE, 1.0, _g_p))
	else:
		_ghosty.sparisci()
	_aggiorna_velo()

# Lo stai guardando? (girato indietro, nella stanza)
func _guardi_dietro() -> bool:
	return not player.is_in_pc() and _facing_zone("back")

# Se ne va e torna dopo una pausa.
func _ghosty_via() -> void:
	_ghosty.sparisci()
	_g_arriva = false
	_g_p = 0.0
	_g_timer = _rng.randf_range(GHOSTY_PAUSA[0], GHOSTY_PAUSA[1])
	_aggiorna_velo()

func _morte(causa: String) -> void:
	if solo_annota_morte:
		morte = causa
		if causa != "ghosty":
			_to_calm()
		return
	_state = State.STOPPED
	GameManager.game_over(causa)

# ---------------- la torcia: si tiene premuta ----------------

func _setup_torch() -> void:
	# Torcia "pulita" stile FNAF 4: un fascio che illumina dove guardi, con ombre vere.
	_torch = SpotLight3D.new()
	_torch.visible = false
	_torch.light_energy = 5.0
	_torch.spot_range = 18.0
	_torch.spot_angle = 20.0
	_torch.spot_angle_attenuation = 1.0
	_torch.shadow_enabled = true    # ombre: il fascio sembra luce VERA (il nemico fa ombra)
	_torch.light_color = Color(1.0, 0.97, 0.85)
	add_child(_torch)
	_torch_energy = _torch.light_energy
	_setup_battery_ui()

# Premuto (in stanza, girato a destra/sinistra/dietro): si accende, se c'e' carica.
func torch_accendi() -> void:
	if player.is_in_pc() or _torch == null:
		return
	if _battery < BATTERIA_RIACCENDE and not _torch.visible:
		return
	_punta_torcia()
	_torch.visible = true

# Rilasciato: si spegne.
func torch_spegni() -> void:
	if _torch != null:
		_torch.visible = false

func _torcia_accesa() -> bool:
	return _torch != null and _torch.visible

func _update_torch(delta: float) -> void:
	if _torcia_accesa():
		if player.is_in_pc():
			torch_spegni()
		else:
			_battery -= BATTERY_DRAIN * delta
			if _battery <= 0.0:
				_battery = 0.0
				torch_spegni()            # vuota: si spegne da sola
			else:
				_punta_torcia()
				var tremola: float = 1.0
				if _battery < BATTERIA_DEBOLE:
					tremola = _rng.randf_range(0.35, 1.0)
				_torch.light_energy = _torch_energy * tremola
	else:
		_battery = minf(BATTERY_MAX, _battery + BATTERY_RECHARGE * delta)
	_update_battery_ui()

# Luce VERA, non "stampata": parte dalla MANO (un po' sotto/destra dell'occhio) e punta
# dove guardi, all'altezza del nemico (non sul pavimento): il fascio graza pareti e nemici
# e fa ombre. Si riallinea a ogni frame, cosi' segue lo sguardo.
# Mira a 3 m e 20 cm SOPRA l'occhio (23/10/2026): prima mirava a 8 m e 20 cm sotto, e alla
# finestra (a 1.6 m) il centro del fascio cadeva sul termosifone invece che sul vetro. Verso
# il corridoio (destra) invece mira a 6 m all'altezza dell'occhio: con la mira in su, in fondo
# al corridoio il fascio finiva sul soffitto.
func _punta_torcia() -> void:
	var cam_t: Transform3D = player.global_transform
	var fwd: Vector3 = -cam_t.basis.z
	var flat: Vector3 = Vector3(fwd.x, 0.0, fwd.z)
	if flat.length() < 0.01:
		flat = fwd
	flat = flat.normalized()
	_torch.global_position = cam_t.origin + cam_t.basis.x * 0.2 - cam_t.basis.y * 0.05
	var aim: Vector3 = cam_t.origin + flat * 3.0
	aim.y = cam_t.origin.y + 0.2
	if _facing_zone("right"):
		# il corridoio e' lungo: con la mira in su il fascio finiva sul soffitto in fondo.
		# Qui quasi orizzontale, all'altezza dell'occhio a 6 m.
		aim = cam_t.origin + flat * 6.0
	_torch.look_at(aim, Vector3.UP)

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

func _halo_react_time() -> float:
	return lerpf(HALO_REACT_CALM, HALO_REACT_HOT, _heat)

func _jit(t: float) -> float:
	return t * (1.0 + _rng.randf_range(-0.15, 0.15))

# --- gli avvisi dentro il PC, dove non vedi la stanza ---
# Affaccio (Jester o HaloMan): riusa scripts/os/glitch.gdshader e cresce man mano che la
# finestra di reazione si esaurisce. Non dice CHI e': per saperlo devi uscire e guardare.
# Ghosty: un'altra cosa apposta, perche' chiede un'altra reazione (girarsi): i bordi dello
# schermo si raffreddano e si scuriscono man mano che si avvicina. Leggero: lo nota chi fa
# attenzione.
func _setup_glitch() -> void:
	_glitch_layer = CanvasLayer.new()
	_glitch_layer.layer = 15   # sopra l'overlay PC (10), sotto la morte (50)
	add_child(_glitch_layer)
	_velo_ghosty = ColorRect.new()
	_velo_ghosty.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo_ghosty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform float forza = 0.0;
void fragment() {
	vec2 d = (UV - 0.5) * vec2(1.333, 1.0);
	float bordo = smoothstep(0.32, 0.85, length(d));
	COLOR = vec4(0.03, 0.06, 0.1, bordo * forza);
}"""
	var mv := ShaderMaterial.new()
	mv.shader = sh
	_velo_ghosty.material = mv
	_velo_ghosty.visible = false
	_glitch_layer.add_child(_velo_ghosty)
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

# Quanto si vede il velo di Ghosty adesso (0 = niente). Pubblico per i test.
func forza_velo_ghosty() -> float:
	if not _g_arriva or not player.is_in_pc():
		return 0.0
	return smoothstep(GHOSTY_TELL_DA, 1.0, _g_p) * 0.6

func _aggiorna_velo() -> void:
	var f := forza_velo_ghosty()
	_velo_ghosty.visible = f > 0.0
	_velo_ghosty.material.set_shader_parameter("forza", f)

# ---------------- DEV-ONLY: il pannello di debug (F12) ----------------
# Testi in inglese, come tutto il debug.

const NOMI_STATO := ["GRACE", "WAIT", "PEEK", "CALM", "STOPPED"]
const NOMI_DEBUG := {"jester": "Jester", "halo": "HaloMan"}

# Si affaccia ADESSO (salta l'attesa): chi = "jester" / "halo" / "" (come capita).
# "" se e' uscito, se no il motivo.
func forza_affaccio(chi := "") -> String:
	if _state == State.STOPPED:
		return "the run is over"
	if not GameManager.room_threats_enabled:
		return "room threats are OFF (F11)"
	if _state == State.PEEK:
		return "%s is already out" % NOMI_DEBUG.get(_chi, _chi)
	if chi == "halo" and not GameManager.pc_on:
		return "HaloMan only comes with the PC on"
	_peek(chi)
	return "" if _state == State.PEEK else "no spot found (group enemy_spots)"

# Lo rimanda via senza morire: si riparte da una finestra sicura (CALM).
func allontana() -> String:
	if _state != State.PEEK:
		return "nobody is out"
	_nemico.dismiss()
	_nemico = null
	_reset_tell()
	_to_calm()
	return ""

# Ghosty arriva ADESSO, gia' entrato nella stanza (in fondo).
func ghosty_forza() -> String:
	if _state == State.STOPPED:
		return "the run is over"
	if not GameManager.room_threats_enabled:
		return "room threats are OFF (F11)"
	_g_arriva = true
	_g_p = maxf(_g_p, GHOSTY_VISIBILE)
	return ""

func ghosty_allontana() -> String:
	if not _g_arriva:
		return "Ghosty is not coming"
	_ghosty_via()
	return ""

func stato_debug() -> String:
	var chi: String = NOMI_DEBUG.get(_chi, "Jester/HaloMan") if _state == State.PEEK else "Jester/HaloMan"
	var s: String = "%s: %s" % [chi, NOMI_STATO[_state]]
	match _state:
		State.GRACE:
			s += " (start grace, %d s left)" % maxi(0, ceili(GRACE_TIME - _timer))
		State.WAIT:
			# l'intervallo vero ha un +-15% a caso a ogni controllo: qui la media
			s += " (peek in ~%d s)" % maxi(0, ceili(lerpf(INTERVAL_CALM, INTERVAL_HOT, _heat) - _timer))
		State.PEEK:
			s += " (%s side, %.1f s to react" % [_peek_zone, _react_left]
			if _chi == "jester":
				s += ", light %d%% of %.1f s)" % [roundi(_uscita * 100.0), _uscita_serve]
			else:
				s += ", PC %s)" % ("ON" if GameManager.pc_on else "off")
		State.CALM:
			s += " (safe for %d s)" % maxi(0, ceili(CALM_TIME - _timer))
	if not GameManager.room_threats_enabled:
		s += " - room threats OFF"
	if _g_arriva:
		s += "\n  Ghosty: coming, %d%% of the way%s" % [roundi(_g_p * 100.0),
				" (watched)" if _guardi_dietro() else ""]
	else:
		s += "\n  Ghosty: away, back in %d s" % maxi(0, ceili(_g_timer))
	return s + "\n  heat %.2f  torch %s, battery %d%%" % [_heat,
			"ON" if _torcia_accesa() else "off", roundi(_battery / BATTERY_MAX * 100.0)]
