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

# ---------------- ciclo di vita del run ----------------

# Avvia una nuova partita: fissa il seme, azzera lo stato del PC e ricostruisce
# il filesystem da zero. Lo chiama il menu allo "Start" (e restart()).
# new_seed = 0 -> ne genera uno casuale (run normale); un seme esplicito = debug.
func start_new_run(new_seed: int = 0) -> void:
	run_seed = new_seed if new_seed != 0 else randi()
	rng.seed = run_seed
	_generate_keys()          # genera le chiavi PRIMA di costruire i contenuti che le ospitano
	first_time_in_room = true
	pc_on = false
	logged_in = false
	_game_over_active = false
	VFS.build_run(run_seed)    # filesystem fresco: "perdere -> run nuovo" riparte pulito
	BrowserApp.reset_pages()   # pagine web rigenerate per il nuovo run (con le nuove chiavi)

# Fine partita: lo chiameranno i nemici (M4), dalla stanza o dal PC. Mostra
# l'overlay di morte (jumpscare -> schermata GAME OVER -> menu), sopra a tutto.
# cause = chi/cosa ha ucciso il giocatore (gancio: in M4 sceglie il sottotitolo).
func game_over(cause := "") -> void:
	if _game_over_active:
		return
	_game_over_active = true
	print("[GameManager] game_over(", cause, ")")
	var ds = load("res://scripts/death_screen.gd").new()
	ds.cause = cause
	# alla radice: copre stanza E vista PC, regge il cambio scena. call_deferred:
	# sicuro anche se game_over scatta mentre l'albero sta costruendo dei nodi.
	get_tree().root.add_child.call_deferred(ds)

# Ricomincia da capo: nuovo seme, filesystem ricostruito, stato azzerato.
# (Non usato dal flusso di morte, che torna al menu; resta come hook per M4 / "Riprova".)
func restart() -> void:
	start_new_run()

# DEV-ONLY (M2): F10 forza il game over per provare jumpscare/flusso. In M4 sara'
# un nemico a chiamarlo: rimuovere allora questo input di debug.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		game_over("debug")

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
