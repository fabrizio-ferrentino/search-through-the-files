extends Node

# ============================================================
# Stato del run (la partita corrente). Centralizzato qui cosi' che avviare un
# nuovo run o un game over resettino tutto in un punto solo (vedi start_new_run).
# ============================================================

# Seme del run: fissa la randomizzazione (M3) e rende i run riproducibili in debug.
var run_seed: int = 0
# Generatore seminato del run, usato dalla randomizzazione futura.
var rng := RandomNumberGenerator.new()

# Chiavi nascoste nel run (M1): ognuna { index:int, code:String }. La cartella
# segreta valida l'input del giocatore contro questa lista. Generate da
# start_new_run() e disseminate nei contenuti dell'OS (file, nomi di cartelle,
# pagine web, sorgente HTML).
var keys: Array = []

# Parametri delle chiavi (tunabili). Charset senza glifi ambigui (niente O/0, I/1).
const KEY_COUNT := 4
const KEY_LEN := 4
const KEY_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

# Questa variabile rimarrà in memoria per tutto il gioco
var first_time_in_room = true

# Stato di accensione del "case" (il computer). true = acceso: il monitor riceve
# segnale. Si accende/spegne dal pulsante del case nella stanza (o con "Spegni il
# PC" dal menu Start). A PC spento il monitor mostra "nessun segnale".
var pc_on := false

# True dopo aver inserito la password: distingue la schermata di login dal
# desktop. Resta true uscendo con ESC (l'OS continua a girare), torna false allo
# spegnimento. Un PC puo' essere acceso ma non ancora loggato (mostra il login).
var logged_in := false

# True mentre l'overlay di morte e' in corso: evita game over multipli sovrapposti.
var _game_over_active := false

# True da "Inizia" fino alla morte o alla vittoria. Serve ai tasti di debug: nel menu
# non c'e' nessuna partita, quindi non hanno senso (e il pannello F12 mostrerebbe i dati
# della partita precedente, dato che vive sulla radice e sopravvive al cambio di scena).
var run_active := false

# Debug: le minacce si spengono in due gruppi, per provare l'una senza l'altra.
# F11 = quelle della STANZA (ThreatDirector: niente affacci, non puo' uccidere);
# F8 = quelle del PC (VirusDirector: niente virus, il conto si ferma).
var room_threats_enabled := true
var pc_threats_enabled := true

# DEV-ONLY. Dove e' finita ogni chiave: lo riempiono i generatori dei contenuti
# mentre le piazzano (content.gd, web_runtime.gd) chiamando note_key(). Serve al
# pannello di debug F12: senza, provare una partita vuol dire cercare alla cieca.
var key_hints: Dictionary = {}
# ...e di che TIPO e' ogni chiave in questa partita: la 1 e' un file o una cartella a
# seconda del seme (18/10/2026), quindi il pannello non puo' piu' avere una mappa fissa.
var key_kinds: Dictionary = {}
var _keys_panel: DebugPanel = null   # il pannello di debug F12 (debug_panel.gd)
var _keys_label: Label = null        # le sue righe delle chiavi
var debug_compatto := false          # pannello ridotto alle sole chiavi (resta fra un F12 e l'altro)
# DEV-ONLY (20/10/2026, proprietario: "fai in modo che io li possa vedere tutti"): il web
# risponde con TUTTI i siti del catalogo e il portale li elenca tutti, non solo quelli
# estratti stanotte. Le chiavi restano dove il seme le ha messe. Pulsante nel pannello F12.
var debug_tutti_i_siti := false

# ---------------- lingua ----------------
# L'INGLESE e' la lingua base del gioco (scelta del proprietario, 19/09/2026), e va imposto
# a mano: Godot parte dalla lingua del SISTEMA, quindi su una macchina italiana il gioco
# usciva in italiano senza che nessuno l'avesse chiesto (verificato: il locale iniziale era
# it_IT). Le traduzioni stanno in locale/ui.csv, una colonna per lingua; una chiave che
# manca viene mostrata COM'E' (tutta maiuscola), quindi un buco si vede subito a schermo.
const LINGUA_BASE := "en"
const LINGUE := ["en", "it"]         # quelle che il CSV contiene davvero
# Il nome di una lingua si scrive NELLA lingua stessa (endonimo): in un elenco di lingue
# "Italiano" non va tradotto in "Italian", o chi cerca la propria non la riconosce. Percio'
# questi nomi NON stanno in locale/ui.csv.
const NOMI_LINGUA := {"en": "English", "it": "Italiano"}
# La scelta di chi gioca sopravvive alla chiusura del gioco. Un file di impostazioni a se',
# non lo stato del run: questo non si azzera a ogni partita.
const FILE_IMPOSTAZIONI := "user://impostazioni.cfg"

var lingua := LINGUA_BASE

func _ready() -> void:
	# la lingua scelta nelle Opzioni, o l'inglese la prima volta. salva = false: qui si
	# sta RILEGGENDO una scelta, non facendone una nuova.
	set_lingua(_lingua_salvata(), false)

# Il nome da mostrare per un codice lingua ("it" -> "Italiano").
func nome_lingua(codice: String) -> String:
	return str(NOMI_LINGUA.get(codice, codice))

# Cambia lingua a gioco avviato: la chiamera' il menu Opzioni (M6).
# Quello che passa da tr() si aggiorna quando l'interfaccia viene ricostruita -- e nell'OS
# succede a ogni apertura di finestra, quindi in pratica basta riaprire quello che si sta
# guardando. Il testo DENTRO il gioco (pagine web, nomi dei file) segue la lingua dalla
# generazione del run: cambiarla a metta' partita non riscrive il PC, ed e' giusto cosi'.
# salva = false quando la lingua la cambia il CODICE e non chi gioca (i test, che girano
# le due lingue e poi rimettono quella base): un test non deve riscrivere l'impostazione
# di chi gioca.
func set_lingua(codice: String, salva := true) -> void:
	if not LINGUE.has(codice):
		codice = LINGUA_BASE
	lingua = codice
	TranslationServer.set_locale(codice)
	if salva:
		_salva_lingua(codice)

func _lingua_salvata() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(FILE_IMPOSTAZIONI) != OK:
		return LINGUA_BASE           # nessun file: prima partita
	var c := str(cfg.get_value("gioco", "lingua", LINGUA_BASE))
	return c if LINGUE.has(c) else LINGUA_BASE

func _salva_lingua(codice: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(FILE_IMPOSTAZIONI)      # rilegge prima di scrivere: le altre impostazioni restano
	cfg.set_value("gioco", "lingua", codice)
	var err := cfg.save(FILE_IMPOSTAZIONI)
	if err != OK:
		push_warning("settings not saved (error %d)" % err)

# ---------------- ciclo di vita del run ----------------

# Avvia una nuova partita: fissa il seme, azzera lo stato del PC e ricostruisce
# il filesystem da zero. Lo chiama il menu allo "Start" (e restart()).
# new_seed = 0 -> ne genera uno casuale (run normale); un seme esplicito = debug.

func start_new_run(new_seed: int = 0) -> void:
	run_seed = new_seed if new_seed != 0 else randi()
	rng.seed = run_seed
	_generate_keys()          # genera le chiavi PRIMA di costruire i contenuti che le ospitano
	key_hints.clear()         # le posizioni le riannotano i generatori qui sotto
	key_kinds.clear()
	first_time_in_room = true
	pc_on = false
	logged_in = false
	_game_over_active = false
	VFS.build_run(run_seed)    # filesystem fresco: "perdere -> run nuovo" riparte pulito
	BrowserApp.reset_pages()   # pagine web rigenerate per il nuovo run (con le nuove chiavi)
	run_active = true
	_refresh_keys_panel()      # se il pannello di debug e' aperto, mostra la partita NUOVA

# Fine partita: lo chiameranno i nemici (M4), dalla stanza o dal PC. Mostra
# l'overlay di morte (jumpscare -> schermata GAME OVER -> menu), sopra a tutto.
# cause = chi/cosa ha ucciso il giocatore (gancio: in M4 sceglie il sottotitolo).
func game_over(cause := "") -> void:
	if _game_over_active:
		return
	_game_over_active = true
	finish_run()               # niente pannello di debug appeso sopra la morte e il menu
	print("[GameManager] game_over(", cause, ")")
	var ds = load("res://scripts/death_screen.gd").new()
	ds.cause = cause
	# alla radice: copre stanza E vista PC, regge il cambio scena. call_deferred:
	# sicuro anche se game_over scatta mentre l'albero sta costruendo dei nodi.
	get_tree().root.add_child.call_deferred(ds)

# Fine della partita (morte o vittoria): da qui in poi non c'e' piu' nulla da mostrare,
# quindi si chiude il pannello di debug e i tasti di debug si disattivano. La chiamano
# game_over() e player._on_game_won().
func finish_run() -> void:
	run_active = false
	close_keys_panel()

# Ricomincia da capo: nuovo seme, filesystem ricostruito, stato azzerato.
# (Non usato dal flusso di morte, che torna al menu; resta come hook per M4 / "Riprova".)
func restart() -> void:
	start_new_run()

# DEV-ONLY: F12 apre il PANNELLO DI DEBUG (scripts/debug_panel.gd: chiavi, stato delle
# minacce, pulsanti per far partire ogni virus e apparizione), F10 forza il game over (per
# provare jumpscare/flusso), F11 accende/spegne le minacce della STANZA, F8 quelle del PC
# (F9, far partire un virus, sta in virus_director.gd). Da togliere prima del rilascio.
# Tutto il testo di debug -- pannello e console -- e' in INGLESE, in ogni lingua del
# gioco (richiesta del proprietario, 18/10/2026): non e' testo per chi gioca, e non passa
# dal CSV. I nomi delle cose del gioco che compaiono nelle note (file, cartelle, siti)
# restano invece quelli che il giocatore vede.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			toggle_keys_panel()
		elif event.keycode == KEY_F10:
			if run_active:
				game_over("debug")
			else:
				print("[GameManager] F10 ignored: no run in progress")
		elif event.keycode == KEY_F11:
			imposta_minacce_stanza(not room_threats_enabled)
		elif event.keycode == KEY_F8:
			imposta_minacce_pc(not pc_threats_enabled)

# I due interruttori del debug: li usano i tasti F11/F8 E i pulsanti del pannello.
func imposta_minacce_stanza(on: bool) -> void:
	room_threats_enabled = on
	print("[GameManager] room threats (F11): ", _on_off(on))
	_refresh_keys_panel()

func imposta_minacce_pc(on: bool) -> void:
	pc_threats_enabled = on
	print("[GameManager] PC threats (F8): ", _on_off(on))
	_refresh_keys_panel()

static func _on_off(v: bool) -> String:
	return "ON" if v else "OFF"

# ---------------- chiavi (M1) ----------------

# Genera le chiavi del run con l'RNG seminato (codici riproducibili in debug).
func _generate_keys() -> void:
	keys.clear()
	for i in range(KEY_COUNT):
		var code := ""
		for _c in range(KEY_LEN):
			code += KEY_CHARS[rng.randi() % KEY_CHARS.length()]
		keys.append({"index": i + 1, "code": code})

# Codice della chiave con indice dato (1-based); "" se non esiste.
func key_code(index: int) -> String:
	for k in keys:
		if int(k.get("index", 0)) == index:
			return str(k.get("code", ""))
	return ""

# Etichetta completa della chiave, formato "<indice>-<codice>" (es. "1-Q9FY").
# Stringa vuota se la chiave non esiste. E' COSI' che la chiave appare nei contenuti
# e va digitata: il prefisso dice a quale riga appartiene.
func key_label(index: int) -> String:
	var c := key_code(index)
	return ("%d-%s" % [index, c]) if c != "" else ""

# True se le righe digitate corrispondono alle chiavi del run. Nel campo si scrive
# solo il CODICE nudo ("Q9FY"); e' la RIGA a dire a quale chiave appartiene:
# rows[i] deve combaciare col codice della chiave di indice i+1. Maiuscolo, spazi
# ignorati; input parziale / codice nella riga sbagliata -> false.
func check_keys(rows: Array) -> bool:
	if rows.size() != keys.size():
		return false
	for k in keys:
		var idx: int = int(k.get("index", 0)) - 1
		if idx < 0 or idx >= rows.size():
			return false
		var got: String = str(rows[idx]).strip_edges().replace(" ", "").to_upper()
		if got != str(k.get("code", "")).to_upper():
			return false
	return true

# ---------------- DEV-ONLY: chiavi e nascondigli (F12) ----------------

# Annota dove e' stata piazzata una chiave (lo chiamano i generatori dei contenuti).
func note_key(index: int, dove: String, tipo := "") -> void:
	key_hints[index] = dove
	if tipo != "":
		key_kinds[index] = tipo

# Rapporto sintetico: intestazione con seme e stato delle minacce, poi una riga
# per chiave (codice, tipo, dove sta).
func keys_report() -> String:
	# la 1 la dice chi l'ha piazzata (FILE o FOLDER); 2 e 3 web, 4 immagine
	var tipi := {1: "DISK", 2: "WEB", 3: "WEB", 4: "IMAGE"}
	tipi.merge(key_kinds, true)
	var out := "KEYS  seed %d  -  room threats %s  -  PC threats %s\n" % [run_seed,
			_on_off(room_threats_enabled), _on_off(pc_threats_enabled)]
	for i in range(1, KEY_COUNT + 1):
		out += "%-8s %-6s %s\n" % [key_label(i), str(tipi.get(i, "?")), str(key_hints.get(i, "-"))]
	return out.strip_edges()

# Mostra/nasconde il pannello di debug con le chiavi; stampa lo stesso in console.
# CanvasLayer alla radice: si vede sia in stanza sia dentro il PC.
func toggle_keys_panel() -> void:
	if _keys_panel != null and is_instance_valid(_keys_panel):
		close_keys_panel()
		return
	if not run_active:
		# nel menu non c'e' niente da mostrare: aprirlo farebbe vedere i dati del run
		# precedente (il pannello sta sulla radice e sopravvive al cambio di scena)
		print("[GameManager] F12 ignored: no run in progress")
		return
	print("\n" + keys_report())
	var p := DebugPanel.new()
	get_tree().root.add_child(p)
	_keys_panel = p
	_keys_label = p.etichetta_chiavi
	_refresh_keys_panel()

# Chiude il pannello di debug, se aperto.
func close_keys_panel() -> void:
	if _keys_panel != null and is_instance_valid(_keys_panel):
		_keys_panel.queue_free()
	_keys_panel = null
	_keys_label = null

# Riscrive il pannello (se aperto): lo usano anche F8 e F11, cosi' lo stato delle minacce
# si vede cambiare sul momento (il resto lo riscrive lui, quattro volte al secondo).
func _refresh_keys_panel() -> void:
	if debug_aperto():
		_keys_panel.aggiorna()

func debug_aperto() -> bool:
	return _keys_panel != null and is_instance_valid(_keys_panel)

# Il mouse e' sopra il pannello di debug? player.gd allora non lo gira ne' alla stanza ne'
# al PC: e' del pannello.
func debug_sotto_mouse(pos: Vector2) -> bool:
	return debug_aperto() and _keys_panel.sotto(pos)

# Tutto il testo del pannello ("" se chiuso): per i test.
func debug_testo() -> String:
	return _keys_panel.testo() if debug_aperto() else ""
