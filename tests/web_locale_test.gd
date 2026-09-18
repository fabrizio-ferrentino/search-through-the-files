extends Node

# Test del WEB PER LINGUA. Il gioco nasce in inglese e l'italiano e' la prima
# traduzione: le pagine d'autore stanno in web/pages/<lingua>/, i nomi delle pagine
# sono identificatori (non testo) e i DOMINI seguono la lingua, perche' un sito
# inglese su un .it si nota subito -- l'indirizzo e' la prima cosa che si legge.
#
# Qui si pretende che, per OGNI lingua dichiarata:
#   1 ci siano davvero TUTTE le pagine (il ripiego su "en" di read_page non deve
#     mascherare una pagina non tradotta: in partita si vedrebbe una pagina inglese
#     dentro un gioco italiano, e il test resterebbe verde);
#   2 ogni LINK dentro le pagine porti da qualche parte -- a una pagina che c'e', o
#     a un indirizzo della tabella (i link morti voluti, come la discussione
#     rimossa del forum, che devono comunque mostrare un indirizzo vero nella
#     barra). E' il controllo che prende l'errore facile: un href italiano lasciato
#     dentro una pagina inglese;
#   3 la wiki generata sia tradotta e COERENTE: nessun segnaposto {…} rimasto,
#     nessuna chiave di traduzione in chiaro (WS_/WEB_HOME_) e nessun dominio
#     dell'altra lingua;
#   4 indirizzo -> pagina -> indirizzo sia un giro chiuso per tutta la tabella;
#   5 la chiave web finisca su un portatore che esiste in QUESTA lingua, e la frase
#     che la porta sia tradotta (non la chiave "WK_V_…");
#   6 le due lingue diano davvero pagine e wiki DIVERSE (se la traduzione non venisse
#     applicata, tutto il resto passerebbe comunque).
#
# Va eseguito come SCENA (serve l'autoload GameManager). Headless va bene.
#   & $godot --headless --path $proj res://tests/web_locale_test.tscn
# ============================================================

const LINGUE := ["en", "it"]
const EXTRA := ["404", "forum_thread"]      # pagine fuori pool, raggiunte dai link
const SEMI := 12

var _fails: Array = []
var _wiki: Dictionary = {}          # lingua -> html della wiki
var _pagine: Dictionary = {}        # lingua -> html di una pagina di riferimento

func _ready() -> void:
	await get_tree().process_frame
	for l in LINGUE:
		_prova_lingua(str(l))
	_confronta_lingue()

	# si torna alla lingua base: un test non deve lasciare il gioco in un'altra
	GameManager.set_lingua(GameManager.LINGUA_BASE)

	if _fails.is_empty():
		print("RISULTATO: PASS (il web e' tradotto e coerente in ogni lingua)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# ---------------- una lingua ----------------

func _prova_lingua(loc: String) -> void:
	GameManager.set_lingua(loc)
	GameManager.start_new_run(4242)
	print("\n=== lingua %s ===" % loc)
	_check("LINGUA_" + loc, WebRuntime.lingua() == loc,
			"WebRuntime.lingua() dice '%s'" % WebRuntime.lingua())

	# 1. tutte le pagine ci sono, nella cartella di QUESTA lingua
	var mancanti: Array = []
	for f in _tutte_le_pagine():
		if not FileAccess.file_exists("res://web/pages/%s/%s.html" % [loc, f]):
			mancanti.append(str(f))
	_check("PAGINE_COMPLETE_" + loc, mancanti.is_empty(),
			"non tradotte: %s" % ", ".join(mancanti))
	for f in _tutte_le_pagine():
		if BrowserApp.read_page(str(f)) == "":
			_ko("PAGINA_VUOTA_" + loc, "%s non si legge" % str(f))

	# 2. ogni link porta a una pagina che c'e' o a un indirizzo della tabella
	var rotti: Array = []
	for f in _tutte_le_pagine():
		var raw := _leggi(loc, str(f))
		for href in _href(raw):
			var nome := _nome_pagina(href)
			if BrowserApp.read_page(nome) != "" or WebRuntime.siti().has(nome):
				continue
			rotti.append("%s -> %s" % [str(f), href])
	_check("LINK_" + loc, rotti.is_empty(), "link che non portano da nessuna parte: %s"
			% ", ".join(rotti))

	# 3. la wiki: tradotta, senza segnaposti e senza domini dell'altra lingua
	var wiki := WebRuntime.home_html()
	_wiki[loc] = wiki
	_check("WIKI_MARCHIO_" + loc, wiki.find("GATEWAY") >= 0, "la wiki non porta il marchio")
	_check("WIKI_SENZA_SEGNAPOSTI_" + loc, wiki.find("{") < 0 and wiki.find("}") < 0,
			"nella wiki e' rimasto un segnaposto del template")
	var chiavi_nude := ""
	for pre in ["WS_", "WEB_HOME_", "WK_V_"]:
		if wiki.find(pre) >= 0:
			chiavi_nude += pre + " "
	_check("WIKI_TRADOTTA_" + loc, chiavi_nude == "",
			"nella wiki si leggono chiavi di traduzione: %s" % chiavi_nude)
	var intrusi: Array = []
	for host in _host_altrui(loc):
		if wiki.find(host) >= 0:
			intrusi.append(host)
	_check("WIKI_DOMINI_" + loc, intrusi.is_empty(),
			"la wiki mostra domini dell'altra lingua: %s" % ", ".join(intrusi))

	# i nomi del pool devono essere tradotti, non le chiavi
	for s in WebRuntime._pool():
		var nome := str(s.get("name", ""))
		var desc := str(s.get("desc", ""))
		if nome.begins_with("WS_") or desc.begins_with("WS_"):
			_ko("POOL_" + loc, "il sito %s non e' tradotto" % str(s.get("file", "")))

	# 4. indirizzo -> pagina -> indirizzo, per tutta la tabella
	for p in WebRuntime.siti():
		var url := WebRuntime.display_url(str(p))
		var indietro := WebRuntime.page_of(url)
		if indietro != str(p):
			_ko("GIRO_" + loc, "%s -> %s -> %s" % [str(p), url, indietro])

	# 5. la chiave: portatore esistente in questa lingua, frase tradotta
	var visibili := 0
	for seme in range(1, SEMI + 1):
		GameManager.start_new_run(seme)
		var kl: String = GameManager.key_label(OSContent.KEY_WEB)
		var port := WebRuntime.carrier()
		if port == "":
			_ko("PORTATORE_" + loc, "il seme %d non ha portatore" % seme)
			continue
		if not FileAccess.file_exists("res://web/pages/%s/%s.html" % [loc, port]):
			_ko("PORTATORE_" + loc, "il portatore %s non esiste in %s" % [port, loc])
			continue
		var testo := WebRuntime.key_text()
		if testo.find("WK_V_") >= 0:
			_ko("FRASE_" + loc, "la frase portatrice e' la chiave di traduzione: %s" % testo)
		if testo.find(kl) < 0:
			_ko("FRASE_" + loc, "la frase portatrice non contiene %s: %s" % [kl, testo])
		if WebRuntime.is_visible():
			visibili += 1
		var inj := WebRuntime.source_html(port, BrowserApp.read_page(port))
		if inj.find(kl) < 0:
			_ko("INIEZIONE_" + loc, "%s non compare nell'HTML di %s (seme %d)" % [kl, port, seme])
		if WebRuntime.home_html().find(kl) >= 0:
			_ko("WIKI_PULITA_" + loc, "la chiave e' finita nella wiki (seme %d)" % seme)
	_check("FRASI_VISIBILI_" + loc, visibili > 0,
			"su %d semi nessuna chiave visibile: le frasi tradotte non sono state provate" % SEMI)

	GameManager.start_new_run(4242)
	_pagine[loc] = _leggi(loc, "forum")
	print("   pagine %d, domini %d, wiki %d byte, semi visibili %d/%d"
			% [_tutte_le_pagine().size(), WebRuntime.siti().size(), wiki.length(), visibili, SEMI])

# ---------------- confronto fra lingue ----------------

func _confronta_lingue() -> void:
	if LINGUE.size() < 2:
		return
	var a := str(LINGUE[0])
	var b := str(LINGUE[1])
	_check("WIKI_DIVERSE", str(_wiki.get(a, "")) != str(_wiki.get(b, "")),
			"la wiki e' identica in %s e %s: la traduzione non viene applicata" % [a, b])
	_check("PAGINE_DIVERSE", str(_pagine.get(a, "")) != str(_pagine.get(b, "")),
			"le pagine d'autore sono identiche in %s e %s" % [a, b])

# ---------------- utilita' ----------------

func _tutte_le_pagine() -> Array:
	var out: Array = []
	for s in WebRuntime._pool():
		out.append(str(s["file"]))
	out.append_array(EXTRA)
	return out

func _leggi(loc: String, nome: String) -> String:
	var f := FileAccess.open("res://web/pages/%s/%s.html" % [loc, nome], FileAccess.READ)
	return f.get_as_text() if f != null else ""

# Tutti gli href di una pagina.
func _href(raw: String) -> Array:
	var out: Array = []
	var i := raw.findn("href=\"")
	while i >= 0:
		var j := raw.find("\"", i + 6)
		if j < 0:
			break
		out.append(raw.substr(i + 6, j - i - 6))
		i = raw.findn("href=\"", j)
	return out

# Come BrowserApp._norm: prima un indirizzo vero, poi il nome del file.
func _nome_pagina(href: String) -> String:
	var p := WebRuntime.page_of(href)
	if p != "":
		return p
	var u := href.strip_edges().to_lower()
	u = u.trim_prefix("http://").trim_prefix("https://").trim_suffix("/").get_file()
	u = u.trim_suffix(".html").trim_suffix(".htm")
	if u == "" or u == "start" or u == "index":
		u = WebRuntime.HOME
	return u

# I domini che esistono SOLO nelle altre lingue (quelli in comune non sono intrusi).
func _host_altrui(loc: String) -> Array:
	var miei: Array = []
	for p in WebRuntime.siti():
		miei.append(str(WebRuntime.siti()[p]))
	var altrui: Array = []
	for tab in [WebRuntime.SITI_EN, WebRuntime.SITI_IT]:
		for p in tab:
			var host := str(tab[p])
			if not miei.has(host) and not altrui.has(host):
				altrui.append(host)
	return altrui

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		if not _fails.has(nome):
			_fails.append(nome)

func _ko(nome: String, perche: String) -> void:
	print("FAIL  %s -- %s" % [nome, perche])
	if not _fails.has(nome):
		_fails.append(nome)
