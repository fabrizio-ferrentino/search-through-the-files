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
		{"file": "news", "name": "NewsOggi", "desc": "Cronaca e tecnologia, aggiornate ogni giorno.", "featured": true},
		{"file": "meteo", "name": "MeteoNow", "desc": "Previsioni del tempo ora per ora.", "featured": true},
		{"file": "giochi", "name": "GiocaWeb", "desc": "Giochi shareware da scaricare col modem.", "featured": true},
		{"file": "blog", "name": "Il blog segreto di Jack99", "desc": "Pagina personale. Teorie e appunti sparsi.", "featured": false},
		{"file": "forum", "name": "RetroForum - Bacheca", "desc": "Floppy, modem 56k e altre nostalgie.", "featured": false},
		{"file": "shop", "name": "CompraTutto - Offerte", "desc": "Acquisti per corrispondenza a prezzi shock.", "featured": false},
		{"file": "mail", "name": "WebMail", "desc": "La tua casella di posta. Spazio quasi esaurito.", "featured": false},
		{"file": "misteri", "name": "Misteri.NET", "desc": "Verita' che non vogliono farti sapere.", "featured": false},
	]

# Frasi portatrici della chiave: in chiaro (mostrata sulla pagina) o nel sorgente (commento).
const _VISIBLE := [
	"Promemoria personale: %s. Non perderlo.",
	"Nota a margine: il codice e' %s.",
	"P.S. ho segnato %s per non scordarlo.",
	"Per accedere ricordarsi di: %s.",
]
const _COMMENT := [
	"build-key=%s",
	"TODO rimuovere prima del rilascio: %s",
	"debug %s",
	"chiave temporanea %s",
]

static var _chosen: Array = []       # i 5 siti del run (dizionari del pool)
static var _carrier := ""            # file del sito che ospita la chiave
static var _visible := false
static var _text := ""               # frase/commento col codice gia' inserito
static var _key := ""
static var _built_seed := -9999
# DOVE finisce la chiave. Si sorteggiano due frazioni (0..1) e non una posizione,
# perche' qui l'HTML del portatore non c'e' ancora: diventano un punto preciso in
# source_html(), che e' la prima a vedere la pagina. Vedi web_anchor.gd.
static var _frac_tipo := 0.0
static var _frac_fessura := 0.0
static var _ancora: Dictionary = {}     # memo: { html, tipo, nota, pos, reso, hash }

# Sceglie i 5 siti del run + portatore/modalita'/chiave dal seme. La chiama
# BrowserApp.reset_pages() (da GameManager.start_new_run); _ensure() la rifa' se serve.
static func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.run_seed + SITE_SALT
	_chosen = _shuffled(_pool(), rng)
	if _chosen.size() > SITE_COUNT:
		_chosen = _chosen.slice(0, SITE_COUNT)
	_key = GameManager.key_label(OSContent.KEY_WEB)
	# il portatore e' sempre un SITO d'autore: la wiki generata non puo' esserlo,
	# cosi' la chiave non finisce mai nell'indice (come in WTTG2)
	var c: Dictionary = _chosen[rng.randi_range(0, _chosen.size() - 1)]
	_carrier = str(c["file"])
	if _carrier == HOME:
		_carrier = ""
	_visible = rng.randf() < 0.5
	if _key == "":
		_text = ""
	elif _visible:
		_text = _VISIBLE[rng.randi_range(0, _VISIBLE.size() - 1)] % _key
	else:
		_text = _COMMENT[rng.randi_range(0, _COMMENT.size() - 1)] % _key
	# NB: questi due sorteggi stanno IN CODA di proposito. Metterli piu' su
	# cambierebbe la sequenza dell'RNG, e con essa portatore/modalita'/frase di
	# tutti i semi giocati finora.
	_frac_tipo = rng.randf()
	_frac_fessura = rng.randf()
	_ancora = {}
	_built_seed = GameManager.run_seed
	if _key != "" and _carrier != "":
		GameManager.note_key(OSContent.KEY_WEB, _hint())

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
# La CHIAVE del run non finisce MAI qui: la wiki e' solo un indice (come in WTTG2).
# La chiave vive su UNO dei siti elencati — vedi source_html() — e il portatore si
# sceglie fra i file del pool, mai fra le pagine generate.
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
const SITI := {
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

# L'indirizzo da mostrare nella barra per quella pagina.
static func display_url(page: String) -> String:
	return "http://" + str(SITI.get(page, page))

# Solo il dominio (senza "http://"), per scriverlo dentro le pagine.
static func host_of(page: String) -> String:
	return str(SITI.get(page, page))

# Da un indirizzo digitato o cliccato al nome della pagina ("" se non e' dei
# nostri). Tollerante come i browser dell'epoca: "http://www.newsoggi.it/",
# "www.newsoggi.it", "newsoggi.it" e "newsoggi" portano tutti allo stesso posto,
# e resta valido anche il vecchio nome interno ("news").
static func page_of(url: String) -> String:
	var u := url.strip_edges().to_lower()
	u = u.trim_prefix("http://").trim_prefix("https://").trim_suffix("/")
	if u == "":
		return ""
	if SITI.has(u):
		return u                      # il nome interno, per compatibilita'
	for p in SITI:
		var host := str(SITI[p]).to_lower()
		if u == host or u == host.trim_prefix("www.") or u == "www." + host:
			return str(p)
		# "newsoggi" da solo: solo per i domini senza percorso, o "webnet"
		# porterebbe alla pagina personale invece che al portale
		if host.find("/") < 0:
			var nudo := host.trim_prefix("www.")
			if u == nudo.get_slice(".", 0):
				return str(p)
	return ""

const _HOME_TEMPLATE := """<html>
<head><title>Benvenuto su WebNet Gateway v3.1</title></head>
<body bgcolor="#C0C0C0" text="#000000" link="#0000FF" vlink="#800080" alink="#FF0000">

<center>
  <font face="Arial Black, Arial, Helvetica" size="6" color="#000080"><u>WEB<b>NET</b></u> <font size="4" color="#FF0000">GATEWAY</font></font><br>
  <font face="Verdana" size="1">Il tuo punto d'accesso all'Autostrada dell'Informazione</font>
</center>

<div align="center">
<table border="1" bordercolorlight="#FFFFFF" bordercolordark="#808080" cellpadding="8" cellspacing="0" width="70%%" bgcolor="#FFFFFF">
%s</table>
</div>

<br>

<center><font face="Arial" size="1">
<hr width="50%%" size="1">
Sito registrato presso WebNet ISP &copy; 1998<br>
Per eventuali problemi contatta il tuo provider
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
		righe += _header_row("I TUOI PREFERITI:", "#808080")
		for s in featured:
			righe += _fav_row(s)
	if not recent.is_empty():
		righe += _header_row("[ SITI VISITATI DI RECENTE ]", "#000080")
		for s in recent:
			righe += _recent_row(s)
	return _HOME_TEMPLATE % righe

# HTML d'autore con la chiave iniettata, SE questa pagina e' il portatore del run.
# Il punto esatto lo sceglie WebAnchor fra tutti quelli sicuri della pagina (riga a
# se', in mezzo a una frase, in coda a un paragrafo, voce di elenco, cella chiara;
# in modalita' sorgente: commento o attributo) -- prima finiva sempre in fondo e si
# riconosceva a vista. Il browser usa questa stessa stringa sia per mostrare la
# pagina (commenti rimossi) sia per il sorgente (commenti inclusi).
static func source_html(page: String, src: String) -> String:
	_ensure()
	if page == HOME or page != _carrier or _key == "":
		return src   # la wiki resta pulita: nessuna chiave, ne' visibile ne' nel sorgente
	return str(_risolvi(src)["html"])

# Dove va la chiave in QUESTA pagina. Il risultato si tiene da parte (memo
# sull'hash del sorgente): source_html() viene chiamata a ogni caricamento e anche
# per il "visualizza sorgente", e deve dare sempre lo stesso HTML -- altrimenti la
# chiave ballerebbe da un punto all'altro durante la partita.
static func _risolvi(src: String) -> Dictionary:
	var h := src.hash()
	if not _ancora.has("html") or int(_ancora.get("hash", 0)) != h:
		_ancora = WebAnchor.inietta(src, _text, _key, _visible, _frac_tipo, _frac_fessura)
		_ancora["hash"] = h
		GameManager.note_key(OSContent.KEY_WEB, _hint())
	return _ancora

# La riga del pannello di debug (F12): sito, modalita' e DOVE sta la chiave.
static func _hint() -> String:
	var modo := "visibile" if _visible else "sorgente"
	return "%s - %s - %s" % [display_url(_carrier), modo,
			str(_ancora.get("nota", "posizione da risolvere"))]

# ---------------- stato del run (serve ai test) ----------------

static func carrier() -> String:
	_ensure()
	return _carrier

static func is_visible() -> bool:
	_ensure()
	return _visible

# La frase (o il commento) col codice dentro, come viene inserita.
static func key_text() -> String:
	_ensure()
	return _text

# { tipo, nota, pos, reso } dell'ancora scelta. "reso" e' cio' che deve comparire
# a schermo ("" se la chiave sta solo nel sorgente). Vuoto se non ancora risolta.
static func anchor_info() -> Dictionary:
	return {
		"tipo": str(_ancora.get("tipo", "")), "nota": str(_ancora.get("nota", "")),
		"pos": int(_ancora.get("pos", -1)), "reso": str(_ancora.get("reso", "")),
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
