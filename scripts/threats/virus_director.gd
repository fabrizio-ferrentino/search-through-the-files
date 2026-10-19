extends Node

# VirusDirector (M5): il regista delle minacce DENTRO il PC, gemello del ThreatDirector
# della stanza. Tre virus (GDD §7.2), uno alla volta:
#   "mortale" -> VirusMortale: un'apparizione che RESTA; spegni il PC o muori;
#   "stupido" -> VirusStupido: la raffica di finestre "YouAreStupid", non uccide;
#   "crash"   -> lo SCHERMO BLU (OSDesktop.schermo_blu): dopo 5 s il PC si riavvia da solo.
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
# FALSI ALLARMI (18/10/2026, proprietario): ogni FALSO_MIN..FALSO_MAX secondi di PC acceso
# (il primo dopo FALSO_PRIMO) un'Apparizione -- la stessa con cui comincia il virus mortale
# -- compare per meno di Apparizione.SOGLIA_FALSO e sparisce. "Rari", scelta sua. Hanno un
# conto tutto loro: non spostano i virus veri, ma dopo un falso il prossimo virus aspetta
# almeno DOPO_FALSO secondi, perche' un vero che parte appena finito un falso si
# confonderebbe con lui. Spegnere per un falso allarme costa il riavvio: e' il prezzo
# dell'errore, ed e' voluto.
# DEV-ONLY: F9 fa partire subito il prossimo virus, a giro (mortale -> stupido -> crash);
# SHIFT+F9 un falso allarme. Per sceglierne uno preciso (anche QUALE apparizione) c'e' il
# pannello di debug F12 (debug_panel.gd), che usa forza_debug / ferma_debug / stato_debug.

var player = null            # la Camera3D (player.gd): is_in_pc() e il regista della stanza
var os: OSDesktop = null     # il desktop dentro il SubViewport

const PRIMO_VIRUS := 180.0   # secondi di PC acceso prima del primo
const PAUSA_MIN := 120.0     # fra la fine di un virus e l'inizio del prossimo
const PAUSA_MAX := 240.0
const ENTRATA_MIN := 4.0     # secondi dentro il PC prima che uno possa partire
const TIPI := ["mortale", "stupido", "crash"]
const PESI := [0.4, 0.3, 0.3]
# Il nome di ogni virus nei messaggi di debug (in inglese, come tutto il debug).
const NOMI_DEBUG := {"mortale": "lethal", "stupido": "YouAreStupid", "crash": "blue screen",
		"falso": "false alarm"}
const FALSO_PRIMO := [90.0, 180.0]   # il primo falso allarme, in secondi di PC acceso
const FALSO_MIN := 180.0             # poi uno ogni 3-5 minuti
const FALSO_MAX := 300.0
const FALSO_DURATA := [2.0, 2.5]     # sempre sotto Apparizione.SOGLIA_FALSO (proprietario:
                                     # 2-2,5 s; prima 0,3-1,2 s, troppo poco per vederlo)
const DOPO_FALSO := 15.0             # un virus vero non parte prima di questo, dopo un falso

var _rng := RandomNumberGenerator.new()
var _evento := ""            # il virus in corso ("" = nessuno)
var _nodo = null             # il suo nodo (VirusMortale / VirusStupido), se ne ha uno
var _ultimo := ""
var _tempo := 0.0            # secondi di PC acceso e loggato
var _prossimo := PRIMO_VIRUS
var _prossimo_falso := 0.0
var _in_pc_da := 0.0
var _fermo := false
var _giro_debug := 0

func _ready() -> void:
	add_to_group("regista_virus")      # cosi' lo trova il pannello di debug (F12)
	_rng.seed = GameManager.run_seed + 5151
	_prossimo_falso = _rng.randf_range(FALSO_PRIMO[0], FALSO_PRIMO[1])

func in_corso() -> String:
	return _evento

func mortale_in_corso() -> bool:
	return _evento == "mortale"

# Fermo definitivo (vittoria): via il virus in corso e niente piu' virus.
func stop() -> void:
	_fermo = true
	if (_evento == "mortale" or _evento == "falso") and is_instance_valid(_nodo):
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
	elif _tempo >= _prossimo_falso and _pronto():
		_avvia("falso")

# _in_pc_da conta solo DENTRO il PC (fuori torna a zero), quindi dice anche "e' dentro".
func _pronto() -> bool:
	return GameManager.run_active and os.pronto_per_virus() \
			and _in_pc_da >= ENTRATA_MIN and not _jester_in_agguato()

func _jester_in_agguato() -> bool:
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

# apparizione = il tipo di Apparizione per "falso" e "mortale" ("" = a caso secondo i PESI;
# il pannello di debug la sceglie a mano).
func _avvia(tipo: String, apparizione := "") -> void:
	_evento = tipo
	if tipo != "falso":          # un falso allarme non conta nel "mai lo stesso due volte"
		_ultimo = tipo
	print("[VirusDirector] virus: ", NOMI_DEBUG.get(tipo, tipo))
	match tipo:
		"falso":
			var a := Apparizione.new()
			os.add_child(a)
			# gli stessi tipi del vero
			a.setup(os, apparizione if apparizione != "" else Apparizione.scegli(_rng), _rng)
			a.durata = _rng.randf_range(FALSO_DURATA[0], FALSO_DURATA[1])
			a.finita.connect(_fine)
			_nodo = a
			print("[VirusDirector] false alarm: ", a.tipo, " (%.1f s)" % a.durata)
		"mortale":
			var v := VirusMortale.new()
			os.add_child(v)
			v.setup(os, _rng, apparizione)
			v.scaduto.connect(_uccidi)
			_nodo = v
			print("[VirusDirector] lethal apparition: ", v.apparizione().tipo)
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
		"falso":
			if not GameManager.pc_on and is_instance_valid(_nodo):
				_nodo.pulisci()          # a PC spento non resta niente a schermo
			if not is_instance_valid(_nodo):
				_fine()
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
	if _evento == "falso":
		_prossimo_falso = _tempo + _rng.randf_range(FALSO_MIN, FALSO_MAX)
		_prossimo = maxf(_prossimo, _tempo + DOPO_FALSO)
	else:
		_prossimo = _tempo + _rng.randf_range(PAUSA_MIN, PAUSA_MAX)
	_evento = ""
	_nodo = null

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

# ---------------- DEV-ONLY: il pannello di debug (F12) ----------------
# Testi in inglese, come tutto il debug.

# Un virus scelto a mano: tipo = uno di TIPI o "falso"; apparizione = uno di
# Apparizione.TIPI per "mortale"/"falso" ("" = a caso). "" se e' partito, se no il motivo.
func forza_debug(tipo: String, apparizione := "") -> String:
	var no := perche_no()
	if no == "":
		_avvia(tipo, apparizione)
	return no

# Perche' un virus NON puo' partire adesso ("" = puo'). Le stesse regole di forza(), piu'
# l'interruttore F8: con le minacce del PC spente il mortale verrebbe tolto all'istante.
func perche_no() -> String:
	if _fermo:
		return "the run is over"
	if not GameManager.pc_threats_enabled:
		return "PC threats are OFF (F8)"
	if _evento != "":
		return "a virus is already running (%s)" % NOMI_DEBUG.get(_evento, _evento)
	if os == null:
		return "no PC"
	if not GameManager.pc_on:
		return "the PC is off"
	if not GameManager.logged_in:
		return "the PC is not on the desktop yet (boot or login)"
	if not os.pronto_per_virus():
		return "the desktop is busy (a dialog or a rename is open)"
	return ""

# Toglie il virus in corso SENZA fermare il regista (il prossimo arriva col suo conto).
func ferma_debug() -> String:
	if _evento == "":
		return "no virus is running"
	match _evento:
		"falso", "mortale":
			if is_instance_valid(_nodo):
				_nodo.pulisci()
		"stupido":
			if is_instance_valid(_nodo):
				_nodo.ferma()            # niente piu' finestre nuove...
				for w in _nodo.vive():   # ...e via quelle aperte
					if is_instance_valid(w):
						w.close()
		"crash":
			os._chiudi_schermo_blu()     # senza riavvio
	_fine()
	return ""

# Porta a ZERO l'attesa del prossimo virus (o falso allarme): parte appena le condizioni
# normali lo permettono -- dentro il PC da ENTRATA_MIN, desktop libero. Serve a provare il
# ritmo vero, non a forzare.
func azzera_attesa(falso: bool) -> void:
	if falso:
		_prossimo_falso = _tempo
	else:
		_prossimo = _tempo

# Cosa sta succedendo adesso, in una riga.
func evento_debug() -> String:
	if _evento == "":
		return "none"
	var s: String = NOMI_DEBUG.get(_evento, _evento)
	if _evento == "mortale" and is_instance_valid(_nodo):
		var v: VirusMortale = _nodo
		var app := v.apparizione()
		s += " '%s' - kills in %d s" % [app.tipo if app != null else "?", ceili(v.DURATA - v._t)]
	elif _evento == "falso" and is_instance_valid(_nodo):
		var a: Apparizione = _nodo
		s += " '%s' - gone in %.1f s" % [a.tipo, maxf(0.0, a.durata - a._t)]
	return s

func stato_debug() -> String:
	var s := "PC virus: %s" % evento_debug()
	if _fermo:
		return s + "  (stopped)"
	s += "\n  next virus in %d s, next false alarm in %d s  (PC-on time %d s)" % [
			maxi(0, ceili(_prossimo - _tempo)), maxi(0, ceili(_prossimo_falso - _tempo)), int(_tempo)]
	var no := perche_no()
	if _evento == "" and no == "" and _in_pc_da < ENTRATA_MIN:
		no = "the player must be inside the PC for %d s (only for the natural ones)" % int(ENTRATA_MIN)
	s += "\n  can start: " + ("yes" if no == "" else "no - " + no)
	return s

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F9:
		var tipo := "falso" if (event as InputEventKey).shift_pressed else ""
		if GameManager.run_active and not forza(tipo):
			print("[VirusDirector] F9 ignored: a virus is already running or the desktop is busy")
