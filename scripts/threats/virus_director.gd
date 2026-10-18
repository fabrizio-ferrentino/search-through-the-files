extends Node

# VirusDirector (M5): il regista delle minacce DENTRO il PC, gemello del ThreatDirector
# della stanza. Tre virus (GDD §7.2), uno alla volta:
#   "mortale" -> VirusMortale: sfondo rosso, sangue, tremito; spegni il PC o muori;
#   "stupido" -> VirusStupido: la raffica di finestre "YouAreStupid", non uccide;
#   "crash"   -> lo SCHERMO BLU (OSDesktop.schermo_blu): un tasto riavvia il PC.
# Ritmo scelto dal proprietario ("rari", non devono essere troppo invasivi): il tempo conta
# solo a PC ACCESO e col desktop aperto (dopo il login); il primo virus non prima di
# PRIMO_VIRUS, poi uno ogni PAUSA_MIN..PAUSA_MAX, mai due insieme, mai lo stesso due volte
# di fila. Uno parte SOLO se il giocatore e' dentro il PC da qualche secondo (deve vederlo
# cominciare), con il desktop libero: niente login, avvio, dialoghi aperti -- la cartella
# segreta compresa -- o rinomine in corso, e mai mentre il nemico del corridoio si sta
# affacciando (due minacce mortali insieme non sono tensione, sono una lotteria; il
# ThreatDirector, dal canto suo, non si affaccia durante il virus mortale).
# Spegnere le minacce del PC (F8, GameManager.pc_threats_enabled) congela il conto e toglie
# il virus mortale in corso; F11 (le minacce della STANZA) qui non c'entra.
# DEV-ONLY: F9 fa partire subito il prossimo virus, a giro (mortale -> stupido -> crash).

var player = null            # la Camera3D (player.gd): is_in_pc() e il regista della stanza
var os: OSDesktop = null     # il desktop dentro il SubViewport

const PRIMO_VIRUS := 180.0   # secondi di PC acceso prima del primo
const PAUSA_MIN := 120.0     # fra la fine di un virus e l'inizio del prossimo
const PAUSA_MAX := 240.0
const ENTRATA_MIN := 4.0     # secondi dentro il PC prima che uno possa partire
const TIPI := ["mortale", "stupido", "crash"]
const PESI := [0.4, 0.3, 0.3]
# Il nome di ogni virus nei messaggi di debug (in inglese, come tutto il debug).
const NOMI_DEBUG := {"mortale": "lethal", "stupido": "YouAreStupid", "crash": "blue screen"}

var _rng := RandomNumberGenerator.new()
var _evento := ""            # il virus in corso ("" = nessuno)
var _nodo = null             # il suo nodo (VirusMortale / VirusStupido), se ne ha uno
var _ultimo := ""
var _tempo := 0.0            # secondi di PC acceso e loggato
var _prossimo := PRIMO_VIRUS
var _in_pc_da := 0.0
var _fermo := false
var _giro_debug := 0

func _ready() -> void:
	_rng.seed = GameManager.run_seed + 5151

func in_corso() -> String:
	return _evento

func mortale_in_corso() -> bool:
	return _evento == "mortale"

# Fermo definitivo (vittoria): via il virus in corso e niente piu' virus.
func stop() -> void:
	_fermo = true
	if _evento == "mortale" and is_instance_valid(_nodo):
		_nodo.pulisci()
	elif _evento == "stupido" and is_instance_valid(_nodo):
		_nodo.ferma()
	_evento = ""
	_nodo = null

func _process(delta: float) -> void:
	avanza(delta)

# Il passo del regista, pubblico perche' il test lo fa girare a mano.
func avanza(delta: float) -> void:
	if _fermo or os == null:
		return
	_in_pc_da = _in_pc_da + delta if player.is_in_pc() else 0.0
	if _evento != "":
		_segui()
		return
	if not GameManager.pc_threats_enabled:
		return
	if GameManager.pc_on and GameManager.logged_in:
		_tempo += delta
	if _tempo >= _prossimo and _pronto():
		_avvia(_scegli())

# _in_pc_da conta solo DENTRO il PC (fuori torna a zero), quindi dice anche "e' dentro".
func _pronto() -> bool:
	return GameManager.run_active and os.pronto_per_virus() \
			and _in_pc_da >= ENTRATA_MIN and not _clown_in_agguato()

func _clown_in_agguato() -> bool:
	var t = player.get("_threats")
	return t != null and t.has_method("in_agguato") and t.in_agguato()

# A caso coi PESI, ma mai lo stesso di prima.
func _scegli() -> String:
	var tipi: Array = []
	var pesi: Array = []
	for i in range(TIPI.size()):
		if TIPI[i] != _ultimo:
			tipi.append(TIPI[i])
			pesi.append(PESI[i])
	var tot := 0.0
	for p in pesi:
		tot += float(p)
	var x := _rng.randf() * tot
	for i in range(tipi.size()):
		x -= float(pesi[i])
		if x <= 0.0:
			return tipi[i]
	return tipi[tipi.size() - 1]

func _avvia(tipo: String) -> void:
	_evento = tipo
	_ultimo = tipo
	print("[VirusDirector] virus: ", NOMI_DEBUG.get(tipo, tipo))
	match tipo:
		"mortale":
			var v := VirusMortale.new()
			os.add_child(v)
			v.setup(os, _rng)
			v.scaduto.connect(_uccidi)
			_nodo = v
		"stupido":
			var s := VirusStupido.new()
			s.setup(os, _rng)
			os.add_child(s)
			s.finito.connect(_fine)
			_nodo = s
		"crash":
			os.schermo_blu(_rng)

# Il virus in corso e' finito? Spegnere il PC salva dal mortale.
func _segui() -> void:
	match _evento:
		"mortale":
			if not GameManager.pc_on or not GameManager.pc_threats_enabled:
				if is_instance_valid(_nodo):
					_nodo.pulisci()
				_fine()
		"stupido":
			if not GameManager.pc_threats_enabled and is_instance_valid(_nodo):
				_nodo.ferma()
			if not is_instance_valid(_nodo):
				_fine()
		"crash":
			if not os.schermo_blu_aperto():
				_fine()

func _fine() -> void:
	if _evento == "":
		return
	_evento = ""
	_nodo = null
	_prossimo = _tempo + _rng.randf_range(PAUSA_MIN, PAUSA_MAX)

func _uccidi() -> void:
	_evento = ""
	_nodo = null
	_fermo = true
	GameManager.game_over("virus")

# Fa partire subito un virus (DEV: F9, e i test). Rifiuta se ce n'e' gia' uno o se il
# desktop non e' libero. tipo "" = il prossimo del giro.
func forza(tipo := "") -> bool:
	if _fermo or _evento != "" or os == null or not os.pronto_per_virus():
		return false
	if tipo == "":
		tipo = TIPI[_giro_debug % TIPI.size()]
		_giro_debug += 1
	_avvia(tipo)
	return true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		if GameManager.run_active and not forza():
			print("[VirusDirector] F9 ignored: a virus is already running or the desktop is busy")
