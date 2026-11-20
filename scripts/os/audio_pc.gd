class_name AudioPC
extends RefCounted

# ============================================================
# Gli ALTOPARLANTI del PC: un bus audio "PC" da cui passa tutto quello che suona il
# computer (oggi la musica delle pagine web). Serve a due cose:
#   1 il VOLUME e il MUTO dell'icona dell'altoparlante nella barra (come in Win98:
#     un clic sull'altoparlante vicino all'orologio, un cursore e "Disattiva");
#     i valori stanno in GameManager (pc_volume, pc_muto), che sopravvive alle scene;
#   2 DA DOVE arriva il suono (proprietario, 23/10/2026: "quando sono nel pc va bene
#     mono, ma poi deve arrivare da avanti, dal pc"). Dentro il PC il suono e' pulito
#     e centrato; nella stanza viene dagli altoparlanti sulla scrivania: si sposta a
#     destra o a sinistra secondo dove si guarda, si fa piu' cupo e lontano girandosi
#     di spalle, e prende un filo dell'eco della stanza.
#
# Il bus si crea da codice la prima volta che serve (il progetto non ha un
# default_bus_layout.tres), con tre effetti: panner, passa-basso, riverbero.
# ============================================================

const BUS := "PC"
const FX_PAN := 0
const FX_PASSA_BASSO := 1
const FX_RIVERBERO := 2

# dentro il PC
const DENTRO_TAGLIO := 20000.0
# nella stanza: di fronte al monitor / di spalle
const STANZA_TAGLIO_FRONTE := 5000.0
const STANZA_TAGLIO_SPALLE := 1600.0
const STANZA_DB_FRONTE := -4.0
const STANZA_DB_SPALLE := -9.0
const STANZA_ECO := 0.18
const STANZA_PAN := 0.8            # di lato il suono non sparisce del tutto da un orecchio
const VELOCITA := 6.0              # quanto in fretta il suono segue lo sguardo

# stato corrente (si avvicina all'obiettivo a ogni fotogramma)
static var _pan := 0.0
static var _taglio := DENTRO_TAGLIO
static var _db_pos := 0.0
static var _eco := 0.0

# Il nome del bus, creandolo se non c'e' ancora. Chi suona: player.bus = AudioPC.bus().
static func bus() -> String:
	if AudioServer.get_bus_index(BUS) < 0:
		_crea()
	return BUS

static func _crea() -> void:
	var i := AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, BUS)
	AudioServer.set_bus_send(i, "Master")
	AudioServer.add_bus_effect(i, AudioEffectPanner.new(), FX_PAN)
	var pb := AudioEffectLowPassFilter.new()
	pb.cutoff_hz = DENTRO_TAGLIO
	AudioServer.add_bus_effect(i, pb, FX_PASSA_BASSO)
	var eco := AudioEffectReverb.new()
	eco.room_size = 0.35
	eco.damping = 0.6
	eco.wet = 0.0
	eco.dry = 1.0
	AudioServer.add_bus_effect(i, eco, FX_RIVERBERO)
	_applica()

# ---------------- volume e muto (l'altoparlante della barra) ----------------

static func imposta_volume(v: float) -> void:
	GameManager.pc_volume = clampf(v, 0.0, 1.0)
	_applica()

static func imposta_muto(m: bool) -> void:
	GameManager.pc_muto = m
	_applica()

static func muto() -> bool:
	return GameManager.pc_muto

static func volume() -> float:
	return GameManager.pc_volume

# ---------------- da dove arriva il suono ----------------

# Dentro il PC: pulito e centrato.
static func dentro(delta: float) -> void:
	_verso(0.0, DENTRO_TAGLIO, 0.0, 0.0, delta)

# Nella stanza. verso_monitor = la direzione dagli occhi agli altoparlanti, nello spazio
# della CAMERA (x a destra, -z davanti): ne vengono il lato e quanto si e' di spalle.
static func nella_stanza(verso_monitor: Vector3, delta: float) -> void:
	var d := verso_monitor.normalized()
	var fronte := clampf(-d.z, -1.0, 1.0) * 0.5 + 0.5          # 1 di fronte, 0 di spalle
	_verso(clampf(d.x, -1.0, 1.0) * STANZA_PAN,
			lerpf(STANZA_TAGLIO_SPALLE, STANZA_TAGLIO_FRONTE, fronte),
			lerpf(STANZA_DB_SPALLE, STANZA_DB_FRONTE, fronte), STANZA_ECO, delta)

static func _verso(pan: float, taglio: float, db: float, eco: float, delta: float) -> void:
	var k := clampf(delta * VELOCITA, 0.0, 1.0)
	_pan = lerpf(_pan, pan, k)
	# il taglio si muove in scala logaritmica: a orecchio e' quella che conta
	_taglio = exp(lerpf(log(_taglio), log(taglio), k))
	_db_pos = lerpf(_db_pos, db, k)
	_eco = lerpf(_eco, eco, k)
	_applica()

# Porta lo stato sul bus.
static func _applica() -> void:
	var i := AudioServer.get_bus_index(BUS)
	if i < 0:
		return
	AudioServer.set_bus_mute(i, GameManager.pc_muto)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(GameManager.pc_volume, 0.0001)) + _db_pos)
	var pan := AudioServer.get_bus_effect(i, FX_PAN) as AudioEffectPanner
	if pan != null:
		pan.pan = _pan
	var pb := AudioServer.get_bus_effect(i, FX_PASSA_BASSO) as AudioEffectLowPassFilter
	if pb != null:
		pb.cutoff_hz = _taglio
	var eco := AudioServer.get_bus_effect(i, FX_RIVERBERO) as AudioEffectReverb
	if eco != null:
		eco.wet = _eco
		eco.dry = 1.0 - _eco * 0.5

# Stato corrente, per i test: {pan, taglio, db, eco}.
static func stato() -> Dictionary:
	return {"pan": _pan, "taglio": _taglio, "db": _db_pos, "eco": _eco}
