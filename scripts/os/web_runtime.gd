class_name WebRuntime
extends RefCounted

# ============================================================
# Stato web del run per il browser a Controlli. Dal seme del run sceglie ~5 siti a caso
# da un POOL (riproducibile), genera la HOME (gateway) che li elenca, e inietta la CHIAVE
# web in UNO dei 5 scelti (in chiaro nel testo, o come commento nel sorgente). Nessun IO
# file: le pagine dei siti sono file d'autore in web/pages/, la home e' generata qui.
# ============================================================

const SITE_SALT := 2002
const SITE_COUNT := 5

# Pool dei siti: ogni voce { file (pagina in web/pages/), name, desc, featured }.
# featured = mostrato in "I TUOI PREFERITI"; gli altri in "DI RECENTE". Per aggiungere un
# sito: crea web/pages/<file>.html e aggiungi una riga qui.
static func _pool() -> Array:
	return [
		{"file": "news", "name": _t("WS_NEWS"), "desc": _t("WS_NEWS_D"), "featured": true},
		{"file": "meteo", "name": _t("WS_WEATHER"), "desc": _t("WS_WEATHER_D"), "featured": true},
		{"file": "giochi", "name": _t("WS_GAMES"), "desc": _t("WS_GAMES_D"), "featured": true},
		{"file": "blog", "name": _t("WS_BLOG"), "desc": _t("WS_BLOG_D"), "featured": false},
		{"file": "forum", "name": _t("WS_FORUM"), "desc": _t("WS_FORUM_D"), "featured": false},
		{"file": "shop", "name": _t("WS_SHOP"), "desc": _t("WS_SHOP_D"), "featured": false},
		{"file": "mail", "name": _t("WS_MAIL"), "desc": _t("WS_MAIL_D"), "featured": false},
		{"file": "misteri", "name": _t("WS_MYST"), "desc": _t("WS_MYST_D"), "featured": false},
	]

# ---------------- lingua ----------------
# Il codice a due lettere della lingua in corso ("en", "it"): il locale di sistema
# puo' essere "it_IT", qui conta solo la prima parte. Le pagine d'autore stanno in
# web/pages/<lingua>/ e i NOMI delle pagine sono identificatori, non testo: non
# cambiano da una lingua all'altra, cambia il contenuto dei file.
static func lingua() -> String:
	return TranslationServer.get_locale().get_slice("_", 0).get_slice("-", 0)

# Scorciatoia: tr() e' un metodo di Object, qui e' tutto statico.
static func _t(chiave: String) -> String:
	return TranslationServer.translate(chiave)

# Frasi portatrici della chiave, in chiaro sulla pagina: CHIAVI di traduzione, non
# testo. L'ordine e il numero non si toccano -- il seme sceglie per indice, e
# spostarle cambierebbe la frase di tutti i semi giocati finora.
const _VISIBLE := [
	"WK_V_1", "WK_V_2", "WK_V_3", "WK_V_4",
	"WK_V_5", "WK_V_6", "WK_V_7", "WK_V_8",
]
# I commenti nel sorgente NON si traducono: nel codice di allora i commenti erano
# in inglese in qualunque paese, e questi (lasciati dal proprietario) sono voluti
# cosi'. Tradurli suonerebbe falso proprio dove il giocatore fruga.
const _COMMENT := [
	"%s",
	"%s",
	"%s",
	"build-key=%s",
	"TODO remove before release: %s",
	"debug %s",
	"temporary-key=%s",
	"why are u doing this %s",
	"you shouldn't have done that %s",
	"why i can find this happines %s",
	"%s i just want to be happy", 
]

static var _chosen: Array = []       # i 5 siti del run (dizionari del pool)
# Le chiavi web del run: DUE dal 18/10/2026 (proprietario), su due siti DIVERSI, ognuna
# col suo modo (visibile o solo nel sorgente) tirato a caso. Un Dictionary per chiave:
#   indice   l'indice della chiave (OSContent.KEY_WEB_1 / KEY_WEB_2)
#   key      la sua etichetta ("2-ABCD")
#   carrier  il file del sito che la ospita
#   visible  nel testo della pagina (true) o solo nel sorgente (false)
#   text     la frase / il commento col codice gia' dentro
#   frac_tipo, frac_fessura   DOVE finisce: due frazioni (0..1) e non una posizione,
#            perche' qui l'HTML del portatore non c'e' ancora; diventano un punto preciso
#            in source_html(), la prima a vedere la pagina (vedi web_anchor.gd)
#   ancora   memo: { html, tipo, nota, pos, reso, hash }
static var _posti: Array = []
static var _built_seed := -9999

# Sceglie i 5 siti del run + portatore/modalita'/chiave dal seme. La chiama
# BrowserApp.reset_pages() (da GameManager.start_new_run); _ensure() la rifa' se serve.
static func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.run_seed + SITE_SALT
	_chosen = _shuffled(_pool(), rng)
	if _chosen.size() > SITE_COUNT:
		_chosen = _chosen.slice(0, SITE_COUNT)
	_posti.clear()
	# la PRIMA chiave fa le estrazioni nello stesso ordine di quando ce n'era una sola:
	# cosi' i semi gia' giocati tengono il suo portatore, modo e frase
	var a := _posto(OSContent.KEY_WEB_1, rng, _chosen)
	_posti.append(a)
	# la SECONDA si estrae dopo, IN CODA, fra i siti del run tranne quello della prima:
	# due chiavi sulla stessa pagina sarebbero una chiave sola da cercare
	var altri: Array = []
	for c in _chosen:
		if str(c["file"]) != str(a["carrier"]):
			altri.append(c)
	_posti.append(_posto(OSContent.KEY_WEB_2, rng, altri))
	_built_seed = GameManager.run_seed
	for p in _posti:
		if str(p["key"]) != "" and str(p["carrier"]) != "":
			GameManager.note_key(int(p["indice"]), _hint(p), "WEB")

# Estrae dove va UNA chiave web, fra i siti dati.
static func _posto(indice: int, rng: RandomNumberGenerator, siti: Array) -> Dictionary:
	var p := {"indice": indice, "key": GameManager.key_label(indice), "carrier": "",
			"visible": false, "text": "", "frac_tipo": 0.0, "frac_fessura": 0.0, "ancora": {}}
	if siti.is_empty():
		return p
	# il portatore e' sempre un SITO d'autore: la wiki generata non puo' esserlo,
	# cosi' la chiave non finisce mai nell'indice (come in WTTG2)
	var c: Dictionary = siti[rng.randi_range(0, siti.size() - 1)]
	p["carrier"] = "" if str(c["file"]) == HOME else str(c["file"])
	p["visible"] = rng.randf() < 0.5
	var key: String = p["key"]
	if key != "":
		if p["visible"]:
			p["text"] = _frase(_VISIBLE[rng.randi_range(0, _VISIBLE.size() - 1)], key)
		else:
			p["text"] = _COMMENT[rng.randi_range(0, _COMMENT.size() - 1)] % key
	# NB: questi due sorteggi stanno IN CODA di proposito. Metterli piu' su
	# cambierebbe la sequenza dell'RNG, e con essa portatore/modalita'/frase di
	# tutti i semi giocati finora.
	p["frac_tipo"] = rng.randf()
	p["frac_fessura"] = rng.randf()
	return p

# La frase tradotta col codice dentro. Se la traduzione manca, tr() restituisce la
# chiave: senza "%s" l'operatore % darebbe errore e la chiave resterebbe fuori dalla
# pagina, cioe' introvabile. In quel caso si mette il codice nudo.
static func _frase(chiave: String, codice: String) -> String:
	var f := _t(chiave)
	if f.find("%s") < 0:
		f = "%s"
	return f % codice

static func _ensure() -> void:
	if _built_seed != GameManager.run_seed or _chosen.is_empty():
		build()

# ============================================================
# LA WIKI (home del browser)
# ------------------------------------------------------------
# E' il "gateway" da cui il giocatore parte: elenca i 5 siti estratti per questo
# run e nient'altro. Modellata sul mockup scritto a mano dal proprietario del
# progetto (web/webnet.html): logo WEBNET, riquadro bianco al 70% centrato su
# sfondo grigio, sezione PREFERITI + sezione SITI VISITATI DI RECENTE in Courier,
# footer dell'ISP.
#
# Le CHIAVI del run non finiscono MAI qui: la wiki e' solo un indice (come in WTTG2).
# Vivono su DUE dei siti elencati — vedi source_html() — e i portatori si scelgono fra
# i file del pool, mai fra le pagine generate.
#
# Il riquadro e' al 70% grazie a <table width="70%">, che il compilatore realizza
# con una spacer trasparente (vedi HtmlBB._spacer_row): serve che il browser passi
# ctx["page_width"], cosa che fa da solo.
# ============================================================

const HOME := "home"          # nome di pagina della wiki (non e' un file)

# ============================================================
# INDIRIZZI. Unica fonte di verita': nome interno della pagina -> dominio da
# mostrare. Prima la barra diceva "http://news", cioe' il nome del file: niente
# suffisso, niente che somigliasse a un indirizzo vero. Qui i domini sono quelli
# della rete di fine anni '90 -- .it per i siti italiani, .com per il negozio e i
# giochi, .net per il sito di misteri, la pagina personale ospitata dall'ISP sotto
# ~utente (era la norma: Geocities, Tripod, il "webspace" del provider) e la
# webmail su un sottodominio del provider.
# La HOME e' il portale dell'ISP (quello del footer della wiki), percio' ha un
# indirizzo anche lei.
# AGGIUNGERE UN SITO = una riga qui + una in _pool() + il file in web/pages/.
# I domini seguono la LINGUA: un sito inglese su un .it (o viceversa) si nota
# subito, ed e' l'indirizzo la prima cosa che il giocatore legge nella barra.
const SITI_EN := {
	HOME: "www.webnet.com",
	"news": "www.newstoday.com",
	"meteo": "www.weathernow.com",
	"giochi": "www.playweb.com",
	"blog": "www.webnet.com/~jack99",
	"forum": "www.retroforum.com",
	"shop": "www.buyitall.com",
	"mail": "webmail.webnet.com",
	"misteri": "www.mysteries.net",
	# pagine non del pool, raggiungibili solo dai link interni
	"forum_thread": "www.retroforum.com/thread.html",
	"removed": "www.retroforum.com/removed.html",
}
const SITI_IT := {
	HOME: "www.webnet.it",
	"news": "www.newsoggi.it",
	"meteo": "www.meteonow.it",
	"giochi": "www.giocaweb.com",
	"blog": "www.webnet.it/~jack99",
	"forum": "www.retroforum.it",
	"shop": "www.compratutto.com",
	"mail": "webmail.webnet.it",
	"misteri": "www.misteri.net",
	# pagine non del pool, raggiungibili solo dai link interni
	"forum_thread": "www.retroforum.it/discussione.html",
	"thread_rimosso": "www.retroforum.it/rimosso.html",
}

# La tabella della lingua in corso. Le pagine d'autore (e quindi i link relativi
# dentro di loro) cambiano con la lingua, gli indirizzi devono seguirle.
static func siti() -> Dictionary:
	return SITI_IT if lingua() == "it" else SITI_EN

# L'indirizzo da mostrare nella barra per quella pagina.
static func display_url(page: String) -> String:
	return "http://" + str(siti().get(page, page))

# Solo il dominio (senza "http://"), per scriverlo dentro le pagine.
static func host_of(page: String) -> String:
	return str(siti().get(page, page))

# Da un indirizzo digitato o cliccato al nome della pagina ("" se non e' dei
# nostri). Tollerante come i browser dell'epoca: "http://www.newsoggi.it/",
# "www.newsoggi.it", "newsoggi.it" e "newsoggi" portano tutti allo stesso posto,
# e resta valido anche il vecchio nome interno ("news").
static func page_of(url: String) -> String:
	var u := url.strip_edges().to_lower()
	u = u.trim_prefix("http://").trim_prefix("https://").trim_suffix("/")
	if u == "":
		return ""
	# prima la lingua in corso, poi le altre: un indirizzo dell'altra lingua non
	# deve dare 404 (e' tolleranza, non una scorciatoia: porta alla stessa pagina)
	for tabella in [siti(), SITI_EN, SITI_IT]:
		var p := _cerca(tabella, u)
		if p != "":
			return p
	return ""

static func _cerca(tabella: Dictionary, u: String) -> String:
	if tabella.has(u):
		return u                      # il nome interno, per compatibilita'
	for p in tabella:
		var host := str(tabella[p]).to_lower()
		if u == host or u == host.trim_prefix("www.") or u == "www." + host:
			return str(p)
		# "newsoggi" da solo: solo per i domini senza percorso, o "webnet"
		# porterebbe alla pagina personale invece che al portale
		if host.find("/") < 0:
			var nudo := host.trim_prefix("www.")
			if u == nudo.get_slice(".", 0):
				return str(p)
	return ""

# Le scritte sono TRADOTTE e il template usa {segnaposto} con String.format, non
# l'operatore % (che qui obbligherebbe a raddoppiare ogni "%" delle larghezze).
const _HOME_TEMPLATE := """<html>
<head><title>{title}</title></head>
<body bgcolor="#C0C0C0" text="#000000" link="#0000FF" vlink="#800080" alink="#FF0000">

<center>
  <font face="Arial Black, Arial, Helvetica" size="6" color="#000080"><u>WEB<b>NET</b></u> <font size="4" color="#FF0000">GATEWAY</font></font><br>
  <font face="Verdana" size="1">{tagline}</font>
</center>

<div align="center">
<table border="1" bordercolorlight="#FFFFFF" bordercolordark="#808080" cellpadding="8" cellspacing="0" width="70%" bgcolor="#FFFFFF">
{rows}</table>
</div>

<br>

<center><font face="Arial" size="1">
<hr width="50%" size="1">
{footer1} &copy; 1998<br>
{footer2}
</font></center>

</body>
</html>
"""

# NB per chi cerca: nel template il marchio e' scritto SPEZZATO dai tag
# (<u>WEB<b>NET</b></u>), percio' cercare "WEBNET" nel progetto non lo trova.
# Vale per tutte le scritte del template: vedi docs/WEB_SITES.md.

# Intestazione di sezione (la barra grigia / blu navy del mockup).
static func _header_row(testo: String, colore: String) -> String:
	return "  <tr bgcolor=\"" + colore + "\"><td><font face=\"Arial\" size=\"2\" color=\"#FFFFFF\"><b>" + testo + "</b></font></td></tr>
"

# Voce dei PREFERITI: nome in grassetto + descrizione grigia.
static func _fav_row(sito: Dictionary) -> String:
	var file := str(sito["file"])
	# link ASSOLUTO: la wiki e' un indice di SITI, non pagine dello stesso sito
	var r := "  <tr><td>&nbsp;<font face=\"Arial\" size=\"3\"><a href=\"" + display_url(file) + "\"><b>" + str(sito["name"]) + "</b></a></font><br>
"
	r += "  &nbsp;<font face=\"Arial\" size=\"2\" color=\"#555555\">" + str(sito.get("desc", "")) + "</font></td></tr>
"
	return r

# Il "peso" della pagina in KB. E' finto ma DETERMINISTICO dal nome, perche' lo
# usano in due: la wiki lo elenca nella cronologia, e la barra di stato del browser
# lo conta mentre carica. Se fossero due numeri diversi si noterebbe subito.
static func fake_kb(page: String) -> int:
	return 8 + (page.length() * 7) % 90

# Voce della CRONOLOGIA: peso finto, nome, indirizzo digitabile, descrizione.
# L'indirizzo in chiaro serve anche da promemoria: si puo' scrivere nella barra.
static func _recent_row(sito: Dictionary) -> String:
	var file := str(sito["file"])
	var kb := fake_kb(file)
	var r := "  <tr><td><font face=\"Courier New\" size=\"2\">"
	r += "[" + str(kb) + " KB] &raquo; <a href=\"" + display_url(file) + "\"><b>" + str(sito["name"]) + "</b></a><br>
"
	r += "  <font color=\"#555555\">" + display_url(file) + "</font><br>
"
	r += "  <font color=\"#333333\">&gt;&gt; " + str(sito.get("desc", "")) + "</font></font></td></tr>
"
	return r

# Costruisce la wiki dai 5 siti del run: i "featured" fra i preferiti, gli altri
# nella cronologia. Niente link morti: si elencano solo i siti estratti.
static func home_html() -> String:
	_ensure()
	var featured: Array = []
	var recent: Array = []
	for s in _chosen:
		if bool(s.get("featured", false)):
			featured.append(s)
		else:
			recent.append(s)
	var righe := ""
	if not featured.is_empty():
		righe += _header_row(_t("WEB_HOME_FAVS"), "#808080")
		for s in featured:
			righe += _fav_row(s)
	if not recent.is_empty():
		righe += _header_row(_t("WEB_HOME_RECENT"), "#000080")
		for s in recent:
			righe += _recent_row(s)
	return _HOME_TEMPLATE.format({
		"title": _t("WEB_HOME_TITLE"), "tagline": _t("WEB_HOME_TAGLINE"),
		"rows": righe, "footer1": _t("WEB_HOME_FOOT1"), "footer2": _t("WEB_HOME_FOOT2"),
	})

# HTML d'autore con la chiave iniettata, SE questa pagina porta una delle chiavi web
# (al massimo una: i due portatori sono siti diversi).
# Il punto esatto lo sceglie WebAnchor fra tutti quelli sicuri della pagina (riga a
# se', in mezzo a una frase, in coda a un paragrafo, voce di elenco, cella chiara;
# in modalita' sorgente: commento o attributo) -- prima finiva sempre in fondo e si
# riconosceva a vista. Il browser usa questa stessa stringa sia per mostrare la
# pagina (commenti rimossi) sia per il sorgente (commenti inclusi).
static func source_html(page: String, src: String) -> String:
	_ensure()
	if page == HOME:
		return src   # la wiki resta pulita: nessuna chiave, ne' visibile ne' nel sorgente
	for p in _posti:
		if str(p["carrier"]) == page and str(p["key"]) != "":
			return str(_risolvi(p, src)["html"])
	return src

# Dove va la chiave in QUESTA pagina. Il risultato si tiene da parte (memo
# sull'hash del sorgente): source_html() viene chiamata a ogni caricamento e anche
# per il "visualizza sorgente", e deve dare sempre lo stesso HTML -- altrimenti la
# chiave ballerebbe da un punto all'altro durante la partita.
static func _risolvi(p: Dictionary, src: String) -> Dictionary:
	var h := src.hash()
	var ancora: Dictionary = p["ancora"]
	if not ancora.has("html") or int(ancora.get("hash", 0)) != h:
		ancora = WebAnchor.inietta(src, str(p["text"]), str(p["key"]), bool(p["visible"]),
				float(p["frac_tipo"]), float(p["frac_fessura"]))
		ancora["hash"] = h
		p["ancora"] = ancora
		GameManager.note_key(int(p["indice"]), _hint(p), "WEB")
	return ancora

# La riga del pannello di debug (F12): sito, modalita' e DOVE sta la chiave.
static func _hint(p: Dictionary) -> String:
	var modo := "visible" if bool(p["visible"]) else "source only"
	var ancora: Dictionary = p["ancora"]
	return "%s - %s - %s" % [display_url(str(p["carrier"])), modo,
			str(ancora.get("nota", "position not resolved yet"))]

# ---------------- stato del run (serve ai test) ----------------

# I 5 siti del run (dizionari del pool: file, name, desc, featured). Li usa il menu
# "Preferiti" del browser, che elenca esattamente quelli che la wiki elenca: un menu
# Preferiti con dentro siti non raggiungibili sarebbe una bugia visibile.
static func sites() -> Array:
	_ensure()
	return _chosen.duplicate()

# Quante chiavi web ci sono (n va da 0 a quanti_posti() - 1 negli accessori qui sotto;
# senza n si parla della PRIMA, come quando ce n'era una sola).
static func quanti_posti() -> int:
	_ensure()
	return _posti.size()

# L'indice di chiave (OSContent.KEY_WEB_*) della chiave web n.
static func indice(n := 0) -> int:
	_ensure()
	return int(_posti[n]["indice"])

static func carrier(n := 0) -> String:
	_ensure()
	return str(_posti[n]["carrier"])

static func is_visible(n := 0) -> bool:
	_ensure()
	return bool(_posti[n]["visible"])

# La frase (o il commento) col codice dentro, come viene inserita.
static func key_text(n := 0) -> String:
	_ensure()
	return str(_posti[n]["text"])

# { tipo, nota, pos, reso } dell'ancora scelta. "reso" e' cio' che deve comparire
# a schermo ("" se la chiave sta solo nel sorgente). Vuoto se non ancora risolta.
static func anchor_info(n := 0) -> Dictionary:
	var ancora: Dictionary = {} if n >= _posti.size() else _posti[n]["ancora"]
	return {
		"tipo": str(ancora.get("tipo", "")), "nota": str(ancora.get("nota", "")),
		"pos": int(ancora.get("pos", -1)), "reso": str(ancora.get("reso", "")),
	}

# Copia mescolata (Fisher-Yates) con l'RNG dato; non tocca l'originale.
static func _shuffled(arr: Array, rng: RandomNumberGenerator) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a
