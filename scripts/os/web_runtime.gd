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

# Sceglie i 5 siti del run + portatore/modalita'/chiave dal seme. La chiama
# BrowserApp.reset_pages() (da GameManager.start_new_run); _ensure() la rifa' se serve.
static func build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.run_seed + SITE_SALT
	_chosen = _shuffled(_pool(), rng)
	if _chosen.size() > SITE_COUNT:
		_chosen = _chosen.slice(0, SITE_COUNT)
	_key = GameManager.key_label(OSContent.KEY_WEB)
	var c: Dictionary = _chosen[rng.randi_range(0, _chosen.size() - 1)]
	_carrier = str(c["file"])
	_visible = rng.randf() < 0.5
	if _key == "":
		_text = ""
	elif _visible:
		_text = _VISIBLE[rng.randi_range(0, _VISIBLE.size() - 1)] % _key
	else:
		_text = _COMMENT[rng.randi_range(0, _COMMENT.size() - 1)] % _key
	_built_seed = GameManager.run_seed

static func _ensure() -> void:
	if _built_seed != GameManager.run_seed or _chosen.is_empty():
		build()

# Home (gateway) generata dai 5 siti del run: logo + "I TUOI PREFERITI" (featured) +
# "[ SITI VISITATI DI RECENTE ]" (gli altri, in Courier) + footer. Stile "legacy" reso
# dal renderer. I link puntano a "<file>.html" (solo i 5 scelti: niente link morti).
static func home_html() -> String:
	_ensure()
	var featured: Array = []
	var recent: Array = []
	for s in _chosen:
		if bool(s.get("featured", false)):
			featured.append(s)
		else:
			recent.append(s)
	var h := "<html><head><title>Benvenuto su WebNet Gateway v3.1</title></head>"
	h += "<body bgcolor=\"#C0C0C0\" text=\"#000000\" link=\"#0000FF\" vlink=\"#800080\">"
	h += "<center><font face=\"Arial Black, Arial\" size=\"6\" color=\"#000080\"><u>LOCAL<b>NET</b></u> "
	h += "<font size=\"4\" color=\"#FF0000\">GATEWAY</font></font><br>"
	h += "<font face=\"Verdana\" size=\"1\">Il tuo punto d'accesso all'Autostrada dell'Informazione</font><br><br></center>"
	h += "<div align=\"center\"><table border=\"1\" bordercolorlight=\"#FFFFFF\" bordercolordark=\"#808080\" cellpadding=\"8\" cellspacing=\"0\" width=\"70%\" bgcolor=\"#FFFFFF\">"
	if not featured.is_empty():
		h += "<tr bgcolor=\"#808080\"><td><font face=\"Arial\" size=\"2\" color=\"#FFFFFF\"><b>I TUOI PREFERITI:</b></font></td></tr>"
		for s in featured:
			h += "<tr><td>&nbsp;<font face=\"Arial\" size=\"3\"><a href=\"" + str(s["file"]) + ".html\"><b>" + str(s["name"]) + "</b></a></font><br>"
			h += "&nbsp;<font face=\"Arial\" size=\"2\" color=\"#555555\">" + str(s.get("desc", "")) + "</font></td></tr>"
	if not recent.is_empty():
		h += "<tr bgcolor=\"#000080\"><td><font face=\"Arial\" size=\"2\" color=\"#FFFFFF\"><b>[ SITI VISITATI DI RECENTE ]</b></font></td></tr>"
		for s in recent:
			var kb := 8 + (str(s["file"]).length() * 7) % 90
			h += "<tr><td><font face=\"Courier New\" size=\"2\">[" + str(kb) + " KB] &raquo; <a href=\"" + str(s["file"]) + ".html\"><b>" + str(s["name"]) + "</b></a><br>"
			h += "<font color=\"#333333\">&gt;&gt; " + str(s.get("desc", "")) + "</font></font></td></tr>"
	h += "</table></div><br>"
	h += "<center><font face=\"Arial\" size=\"1\"><hr width=\"50%\" size=\"1\">"
	h += "Sito registrato presso WebNet ISP &copy; 1998<br>Per eventuali problemi contatta il tuo provider</font></center>"
	h += "</body></html>"
	return h

# HTML d'autore con la chiave iniettata, SE questa pagina e' il portatore del run. In
# modalita' "visibile" un paragrafo legacy (reso e selezionabile); altrimenti un commento
# (non reso, ma visibile in "visualizza sorgente"). Il browser lo usa sia per mostrare la
# pagina (commenti rimossi) sia per il sorgente (commenti inclusi).
static func source_html(page: String, src: String) -> String:
	_ensure()
	if page != _carrier or _key == "":
		return src
	var snippet := ""
	if _visible:
		# niente color fisso: eredita il colore testo della pagina (leggibile anche sulle pagine scure)
		snippet = "\n<p><font face=\"Arial\" size=\"2\">" + _text + "</font></p>\n"
	else:
		snippet = "\n<!-- " + _text + " -->\n"
	var pos := src.findn("</body>")
	return (src.substr(0, pos) + snippet + src.substr(pos)) if pos >= 0 else (src + snippet)

# Copia mescolata (Fisher-Yates) con l'RNG dato; non tocca l'originale.
static func _shuffled(arr: Array, rng: RandomNumberGenerator) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a
