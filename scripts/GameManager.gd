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

# Debug: toggle minacce (F11). Quando false, il ThreatDirector non genera
# affacci e non puo' uccidere — utile per testare modifiche in pace.
var threats_enabled := true

# DEV-ONLY. Dove e' finita ogni chiave: lo riempiono i generatori dei contenuti
# mentre le piazzano (content.gd, web_runtime.gd) chiamando note_key(). Serve al
# pannello di debug F12: senza, provare una partita vuol dire cercare alla cieca.
var key_hints: Dictionary = {}
var _keys_panel: CanvasLayer = null
var _keys_label: Label = null

# ---------------- ciclo di vita del run ----------------

# Avvia una nuova partita: fissa il seme, azzera lo stato del PC e ricostruisce
# il filesystem da zero. Lo chiama il menu allo "Start" (e restart()).
# new_seed = 0 -> ne genera uno casuale (run normale); un seme esplicito = debug.
func start_new_run(new_seed: int = 0) -> void:
	run_seed = new_seed if new_seed != 0 else randi()
	rng.seed = run_seed
	_generate_keys()          # genera le chiavi PRIMA di costruire i contenuti che le ospitano
	key_hints.clear()         # le posizioni le riannotano i generatori qui sotto
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

# DEV-ONLY: F12 mostra chiavi e nascondigli, F10 forza il game over (per provare
# jumpscare/flusso), F11 spegne le minacce. Da togliere prima del rilascio.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F12:
			toggle_keys_panel()
		elif event.keycode == KEY_F10:
			if run_active:
				game_over("debug")
			else:
				print("[GameManager] F10 ignorato: nessuna partita in corso")
		elif event.keycode == KEY_F11:
			threats_enabled = not threats_enabled
			print("[GameManager] threats_enabled = ", threats_enabled)
			_refresh_keys_panel()

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
func note_key(index: int, dove: String) -> void:
	key_hints[index] = dove

# Rapporto sintetico: intestazione con seme e stato delle minacce, poi una riga
# per chiave (codice, tipo, dove sta).
func keys_report() -> String:
	var tipi := {1: "FILE", 2: "CART", 3: "WEB", 4: "FOTO"}
	var out := "CHIAVI  seme %d  -  minacce %s
" % [run_seed, "ON" if threats_enabled else "OFF"]
	for i in range(1, KEY_COUNT + 1):
		out += "%-8s %-5s %s
" % [key_label(i), str(tipi.get(i, "?")), str(key_hints.get(i, "-"))]
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
		print("[GameManager] F12 ignorato: nessuna partita in corso")
		return
	print("
" + keys_report())
	var layer := CanvasLayer.new()
	layer.name = "DebugKeysLayer"
	layer.layer = 30                      # sopra vista PC (10) e schermata di morte (20)
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var box := PanelContainer.new()
	# in alto a DESTRA: a sinistra ci sono le icone del desktop
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT, true)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.offset_top = 16
	box.offset_right = -16
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.06, 0.88)
	sb.border_color = Color(0.9, 0.8, 0.2)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(9)
	box.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.add_theme_font_override("font", Win95.font("mono"))
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.8))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(lbl)
	layer.add_child(box)
	get_tree().root.add_child(layer)
	_keys_panel = layer
	_keys_label = lbl
	_refresh_keys_panel()

# Chiude il pannello di debug, se aperto.
func close_keys_panel() -> void:
	if _keys_panel != null and is_instance_valid(_keys_panel):
		_keys_panel.queue_free()
	_keys_panel = null
	_keys_label = null

# Riscrive il testo del pannello (se aperto): lo usa anche F11, cosi' lo stato
# delle minacce si vede cambiare sul momento.
func _refresh_keys_panel() -> void:
	if _keys_label != null and is_instance_valid(_keys_label):
		_keys_label.text = keys_report() + "
F10 morte  F11 minacce F12 chiudi"
