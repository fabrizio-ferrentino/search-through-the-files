extends Node

# Test della POSIZIONE della chiave web, su molti semi (WebAnchor + WebRuntime).
#
# Prima la chiave finiva sempre in fondo alla pagina; adesso il punto lo sorteggia
# il seme fra tutte le ancore sicure della pagina. Qui si pretende che:
#   1 la modalita' sia rispettata DAVVERO: se e' "visibile" la chiave deve arrivare
#     a schermo, se e' "solo sorgente" NON deve arrivarci ma deve stare nell'HTML.
#     (Il vecchio controllo in browser_e2e deduceva la modalita' da dove trovava la
#     stringa, quindi uno snippet visibile finito in un punto morto passava per
#     "solo sorgente" e il test restava verde con la chiave introvabile.)
#   2 la pagina renda IDENTICA a prima a meno di quello che si e' aggiunto;
#   3 la wiki resti pulita e una sola pagina del pool porti la chiave;
#   4 la posizione sia STABILE (ricaricare la pagina non la sposta) e riproducibile
#     dal seme;
#   5 il pannello F12 dica dove sta;
#   6 le posizioni siano VARIE: e' il motivo di tutto il lavoro.
#
# Va eseguito come SCENA (non con -s): serve l'autoload GameManager.
#   & $godot --headless --path $proj res://tests/web_key_inject.tscn
# ============================================================

const SEMI := 60
const POOL := ["news", "meteo", "giochi", "blog", "forum", "shop", "mail", "misteri"]

var _fails: Array = []
var _tipi: Dictionary = {}          # tipo -> quante volte
var _punti: Dictionary = {}         # "pagina@pos" -> quante volte

func _ready() -> void:
	await get_tree().process_frame
	for seme in range(1, SEMI + 1):
		_prova(seme)

	# riproducibilita': lo stesso seme deve dare la stessa posizione
	var a := _scatto(12345)
	var b := _scatto(12345)
	_check("RIPRODUCIBILE", a == b, "stesso seme, posizioni diverse: %s vs %s" % [a, b])

	_censimento()
	_check("TIPI_VARI", _tipi.size() >= 8,
			"su %d semi solo %d tipi di posizione: %s" % [SEMI, _tipi.size(), str(_tipi.keys())])
	var nuovi := 0
	for t in _tipi:
		if str(t) != WebAnchor.RIGA and str(t) != WebAnchor.COMM_BLOCCO:
			nuovi += int(_tipi[t])
	_check("NON_SOLO_IN_FONDO", nuovi > 0,
			"la chiave finisce sempre in una riga a se': il comportamento nuovo non si vede")
	_check("PUNTI_DIVERSI", _punti.size() >= SEMI / 3,
			"solo %d punti distinti su %d semi" % [_punti.size(), SEMI])

	if _fails.is_empty():
		print("RISULTATO: PASS (la chiave cambia posizione e resta trovabile)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

func _prova(seme: int) -> void:
	GameManager.start_new_run(seme)
	var kl: String = GameManager.key_label(OSContent.KEY_WEB)
	var port := WebRuntime.carrier()
	var vis := WebRuntime.is_visible()
	var info := WebRuntime.anchor_info()
	var tipo := str(info["tipo"])
	if kl == "" or port == "":
		_ko(seme, "nessuna chiave o nessun portatore")
		return
	if not POOL.has(port):
		_ko(seme, "portatore fuori dal pool: %s" % port)
		return
	if tipo == WebAnchor.RIPIEGO or tipo == "":
		_ko(seme, "nessuna ancora trovata in %s (tipo=%s)" % [port, tipo])
		return
	# la wiki e' solo un indice: la chiave non ci finisce mai
	if WebRuntime.home_html().find(kl) >= 0:
		_ko(seme, "la chiave compare nella wiki")

	var raw: String = BrowserApp.read_page(port)
	var iniettato: String = WebRuntime.source_html(port, raw)
	if raw == "":
		_ko(seme, "pagina %s illeggibile" % port)
		return
	# stabile: cinque caricamenti danno la stessa pagina (source_html viene chiamata
	# a ogni _load e anche per il "visualizza sorgente")
	for k in range(4):
		if WebRuntime.source_html(port, raw) != iniettato:
			_ko(seme, "la posizione cambia da un caricamento all'altro")
			break
	if iniettato.find(kl) < 0:
		_ko(seme, "la chiave non e' nel sorgente di %s" % port)
		return

	# la stessa pipeline del browser: commenti via, poi compilazione
	# ctx NUOVO a ogni chiamata: HtmlBB ci scrive dentro ("uses_width"), e un const
	# in Godot e' di sola lettura
	var pulito := _norm(HtmlBB.compile(HtmlBB.strip_comments(HtmlBB.body_inner(raw)), _ctx()))
	var con := _norm(HtmlBB.compile(HtmlBB.strip_comments(HtmlBB.body_inner(iniettato)), _ctx()))
	var d := _differenza(pulito, con)
	if str(d[0]).strip_edges() != "":
		_ko(seme, "%s perde pezzi: %s" % [port, str(d[0]).substr(0, 50)])
	if vis:
		if con.find(kl) < 0:
			_ko(seme, "modalita' visibile ma la chiave non arriva a schermo (%s, %s)" % [port, tipo])
		elif str(d[1]).find(str(info["reso"])) < 0:
			_ko(seme, "a schermo non compare il testo atteso (%s)" % tipo)
	else:
		if con.find(kl) >= 0:
			_ko(seme, "modalita' sorgente ma la chiave si vede a schermo (%s, %s)" % [port, tipo])
		elif str(d[1]).strip_edges() != "":
			_ko(seme, "la pagina cambia pur essendo solo sorgente (%s)" % tipo)

	# una sola pagina del pool porta la chiave
	var quante := 0
	for f in POOL:
		if WebRuntime.source_html(f, BrowserApp.read_page(f)).find(kl) >= 0:
			quante += 1
	if quante != 1:
		_ko(seme, "la chiave e' su %d pagine" % quante)

	# il pannello F12 deve dire sito, modalita' e posizione
	var hint := str(GameManager.key_hints.get(OSContent.KEY_WEB, ""))
	if hint.find("http://" + port) < 0 or hint.find(str(info["nota"])) < 0:
		_ko(seme, "il suggerimento F12 non dice dove: '%s'" % hint)

	_tipi[tipo] = int(_tipi.get(tipo, 0)) + 1
	var punto := "%s@%d" % [port, int(info["pos"])]
	_punti[punto] = int(_punti.get(punto, 0)) + 1

# Fotografia della scelta per un seme: serve alla prova di riproducibilita'.
func _scatto(seme: int) -> String:
	GameManager.start_new_run(seme)
	var info := WebRuntime.anchor_info()
	return "%s/%s@%d" % [WebRuntime.carrier(), str(info["tipo"]), int(info["pos"])]

func _censimento() -> void:
	print("\n   posizioni estratte su %d semi:" % SEMI)
	var chiavi: Array = _tipi.keys()
	chiavi.sort()
	for t in chiavi:
		print("      %-16s %d" % [str(t), int(_tipi[t])])
	print("      (%d punti distinti)" % _punti.size())

# Prefisso e suffisso in comune via: resta [cio' che c'e' solo in a, solo in b].
func _differenza(a: String, b: String) -> Array:
	var i := 0
	while i < a.length() and i < b.length() and a[i] == b[i]:
		i += 1
	var j := 0
	while j < a.length() - i and j < b.length() - i \
			and a[a.length() - 1 - j] == b[b.length() - 1 - j]:
		j += 1
	return [a.substr(i, a.length() - i - j), b.substr(i, b.length() - i - j)]

func _ctx() -> Dictionary:
	return {"link_color": "#0000ee", "page_width": 900.0}

func _norm(s: String) -> String:
	var re := RegEx.create_from_string(r"\s+")
	return re.sub(s, " ", true).strip_edges()

func _ko(seme: int, perche: String) -> void:
	var nome := "seme_%d" % seme
	print("FAIL  %s -- %s" % [nome, perche])
	if not _fails.has(nome):
		_fails.append(nome)

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  %s -- %s" % [nome, perche])
		_fails.append(nome)
