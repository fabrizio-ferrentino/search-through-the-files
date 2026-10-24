class_name WebRuntime
extends RefCounted

# ============================================================
# Stato web del run per il browser a Controlli. Dal seme del run sceglie da SITI_MIN a
# SITI_MAX siti dal CATALOGO (catalogo_siti.gd), di cui da LORE_MIN a LORE_MAX di lore
# (riproducibile), genera la HOME (gateway) che li elenca, e inietta le due CHIAVI web in
# due pagine di due siti diversi (in chiaro nel testo, o come commento nel sorgente).
# Nessun IO file: le pagine dei siti sono file d'autore in web/pages/<lingua>/<sito>/, la
# home e' generata qui.
#
# UNA PAGINA si chiama "<sito>/<pagina>" ("forum/index", "forum/thread"): il sito e' la
# cartella, la pagina il file senza ".html". Le pagine fuori dai siti (la HOME generata, la
# 404, "server non trovato") hanno un nome solo.
# ============================================================

const SITE_SALT := 2002
# Quanti siti per partita (proprietario, 19/10/2026: una trentina in tutto, 10-15 a
# partita) e quanti di lore fra questi ("2 sono troppo pochi": 4-5). Se il catalogo ne ha
# meno, si prendono tutti quelli che ci sono.
const SITI_MIN := 10
const SITI_MAX := 15
const LORE_MIN := 4
const LORE_MAX := 5
const NONSERVER := "nonserver"      # la pagina "impossibile trovare il server"

# Pool dei siti, dal catalogo: { file (l'id del sito, cioe' la cartella), name, desc,
# featured, tipo, voce, pagine, stato }. featured = mostrato in "I TUOI PREFERITI"; gli altri
# in "DI RECENTE". Per aggiungere un sito: scripts/os/catalogo_siti.gd.
static func _pool() -> Array:
	var out: Array = []
	for c in CatalogoSiti.SITI:
		out.append({"file": str(c["id"]), "name": _t(str(c["nome"])), "desc": _t(str(c["desc"])),
				"featured": bool(c["featured"]), "tipo": str(c["tipo"]), "voce": str(c["voce"]),
				"pagine": (c["pagine"] as Array).duplicate(), "stato": str(c["stato"])})
	return out

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

static var _chosen: Array = []       # i siti del run (dizionari del pool)
# Le chiavi web del run: DUE dal 18/10/2026 (proprietario), su due siti DIVERSI, ognuna
# col suo modo (visibile o solo nel sorgente) tirato a caso. Un Dictionary per chiave:
#   indice   l'indice della chiave (OSContent.KEY_WEB_1 / KEY_WEB_2)
#   key      la sua etichetta ("2-ABCD")
#   carrier  la PAGINA che la ospita ("sito/pagina")
#   visible  nel testo della pagina (true) o solo nel sorgente (false)
#   text     la frase / il commento col codice gia' dentro
#   frac_tipo, frac_fessura   DOVE finisce: due frazioni (0..1) e non una posizione,
#            perche' qui l'HTML del portatore non c'e' ancora; diventano un punto preciso
#            in source_html(), la prima a vedere la pagina (vedi web_anchor.gd)
#   ancora   memo: { html, tipo, nota, pos, reso, hash }
static var _posti: Array = []
static var _built_seed := -9999

# Sceglie i siti del run + portatore/modalita'/chiave dal seme. La chiama
# BrowserApp.reset_pages() (da GameManager.start_new_run); _ensure() la rifa' se serve.
# Le pagine aperte in questa partita: i link che portano li' hanno il colore "visitato"
# della pagina (vlink), come nei browser d'epoca. Si azzera a ogni partita (build).
static var visitate: Dictionary = {}

static func visita(page: String) -> void:
	visitate[page] = true

static func build() -> void:
	visitate.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.run_seed + SITE_SALT
	_chosen = _scegli_siti(_pool(), rng)
	_posti.clear()
	var a := _posto(OSContent.KEY_WEB_1, rng, _chosen)
	_posti.append(a)
	# la SECONDA fra i siti del run tranne quello della prima: due chiavi sullo stesso sito
	# sarebbero un posto solo da frugare
	var altri: Array = []
	for c in _chosen:
		if str(c["file"]) != sito_di(str(a["carrier"])):
			altri.append(c)
	_posti.append(_posto(OSContent.KEY_WEB_2, rng, altri))
	_built_seed = GameManager.run_seed
	for p in _posti:
		if str(p["key"]) != "" and str(p["carrier"]) != "":
			GameManager.note_key(int(p["indice"]), _hint(p), "WEB")

# I siti della partita: da SITI_MIN a SITI_MAX, di cui da LORE_MIN a LORE_MAX di lore (o
# tutti quelli che ci sono). Se ci sono, almeno un sito di lore sul PADRE e uno sul RAGAZZO
# (la voce del catalogo): la storia ha due meta' e una partita deve toccarle tutte e due.
# L'ordine finale e' mescolato: e' l'ordine in cui il portale li elenca.
static func _scegli_siti(pool: Array, rng: RandomNumberGenerator) -> Array:
	var lore: Array = []
	var normali: Array = []
	for c in _shuffled(pool, rng):
		if str(c["tipo"]) == "lore":
			lore.append(c)
		else:
			normali.append(c)
	var quanti := mini(rng.randi_range(SITI_MIN, SITI_MAX), pool.size())
	var quanti_lore := mini(rng.randi_range(LORE_MIN, LORE_MAX), lore.size())
	var presi: Array = []
	for voce in ["padre", "ragazzo"]:
		for c in lore:
			if str(c["voce"]) == voce and presi.size() < quanti_lore:
				presi.append(c)
				break
	for c in lore:
		if presi.size() >= quanti_lore:
			break
		if not presi.has(c):
			presi.append(c)
	for c in normali:
		if presi.size() >= quanti:
			break
		presi.append(c)
	# pochi normali nel catalogo: si riempie con altra lore, pur di arrivare al numero
	for c in lore:
		if presi.size() >= quanti:
			break
		if not presi.has(c):
			presi.append(c)
	return _shuffled(presi, rng)

# Estrae dove va UNA chiave web, fra i siti dati: un sito, poi una sua pagina.
static func _posto(indice: int, rng: RandomNumberGenerator, siti: Array) -> Dictionary:
	var p := {"indice": indice, "key": GameManager.key_label(indice), "carrier": "",
			"visible": false, "text": "", "frac_tipo": 0.0, "frac_fessura": 0.0, "ancora": {}}
	if siti.is_empty():
		return p
	# il portatore e' sempre un SITO d'autore: la wiki generata non puo' esserlo,
	# cosi' la chiave non finisce mai nell'indice (come in WTTG2)
	var c: Dictionary = siti[rng.randi_range(0, siti.size() - 1)]
	var pagine: Array = c.get("pagine", ["index"])
	p["carrier"] = str(c["file"]) + "/" + str(pagine[rng.randi_range(0, pagine.size() - 1)])
	p["visible"] = rng.randf() < 0.5
	var key: String = p["key"]
	if key != "":
		if p["visible"]:
			p["text"] = _frase(_VISIBLE[rng.randi_range(0, _VISIBLE.size() - 1)], key)
		else:
			p["text"] = _COMMENT[rng.randi_range(0, _COMMENT.size() - 1)] % key
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
# E' il "gateway" da cui il giocatore parte: elenca i siti estratti per questo
# run e nient'altro. Modellata sul mockup scritto a mano dal proprietario del
# progetto (web/webnet.html): logo WEBNET, riquadro bianco al 70% centrato su
# sfondo grigio, sezione PREFERITI + sezione SITI VISITATI DI RECENTE in Courier,
# footer dell'ISP.
#
# Le CHIAVI del run non finiscono MAI qui: la wiki e' solo un indice (come in WTTG2).
# Vivono su DUE dei siti elencati — vedi source_html() — e i portatori si scelgono fra
# le pagine dei siti, mai fra le pagine generate.
#
# Il riquadro e' al 70% grazie a <table width="70%">, che il compilatore realizza
# con una spacer trasparente (vedi HtmlBB._spacer_row): serve che il browser passi
# ctx["page_width"], cosa che fa da solo.
# ============================================================

const HOME := "home"          # nome di pagina della wiki (non e' un file)

# ============================================================
# INDIRIZZI. I domini stanno nel catalogo (catalogo_siti.gd), uno per lingua: un sito
# inglese su un .it si nota subito, ed e' l'indirizzo la prima cosa che il giocatore legge
# nella barra. Quelli della rete di fine anni '90: .it per i siti italiani, .com per il
# negozio e i giochi, .net per il sito di misteri, la pagina personale ospitata dall'ISP
# sotto ~utente (era la norma: Geocities, Tripod, il "webspace" del provider) e la webmail
# su un sottodominio del provider.
# L'indirizzo di una pagina e' il dominio del sito piu' "/<pagina>.html" (l'index e' il
# dominio nudo). La HOME e' il portale dell'ISP (quello del footer della wiki).
# ============================================================
const HOME_EN := "www.webnet.com"
const HOME_IT := "www.webnet.it"

# Il dominio di un sito nella lingua data ("" se il sito non c'e').
static func dominio(sito: String, lng := "") -> String:
	var c := CatalogoSiti.sito(sito)
	if c.is_empty():
		return ""
	return str(c["it"]) if (lng if lng != "" else lingua()) == "it" else str(c["en"])

# I siti con il loro dominio nella lingua in corso (piu' la HOME): { id: dominio }.
static func siti() -> Dictionary:
	var out := {HOME: HOME_IT if lingua() == "it" else HOME_EN}
	for c in CatalogoSiti.SITI:
		out[str(c["id"])] = dominio(str(c["id"]))
	return out

# Il sito di una pagina ("forum/thread" -> "forum"; "" per le pagine fuori dai siti).
static func sito_di(page: String) -> String:
	return page.get_slice("/", 0) if page.find("/") > 0 else ""

# La pagina e' di un sito estratto in questa partita? Quelle fuori dai siti (home, 404)
# si', sempre. Un sito del catalogo che stanotte non c'e' risponde "server non trovato".
static func in_partita(page: String) -> bool:
	var s := sito_di(page)
	if s == "":
		return true
	for c in raggiungibili():
		if str(c["file"]) == s:
			return true
	return false

# I siti che stanotte RISPONDONO e che il portale elenca: quelli estratti, oppure -- col
# debug "tutti i siti" del pannello F12 -- tutto il catalogo, nel suo ordine. Le chiavi non
# si spostano: restano sui siti estratti (_chosen), che il debug non tocca.
static func raggiungibili() -> Array:
	_ensure()
	if GameManager.debug_tutti_i_siti:
		return _pool()
	return _chosen

static func _estratto(id: String) -> bool:
	for c in _chosen:
		if str(c["file"]) == id:
			return true
	return false

# L'indirizzo da mostrare nella barra per quella pagina.
static func display_url(page: String) -> String:
	return "http://" + host_of(page)

# Dominio + percorso (senza "http://"), per la barra e per scriverlo dentro le pagine.
static func host_of(page: String) -> String:
	if page == HOME:
		return HOME_IT if lingua() == "it" else HOME_EN
	var s := sito_di(page)
	if s == "" or dominio(s) == "":
		return page
	var nome := page.get_slice("/", 1)
	return dominio(s) if nome == "index" else dominio(s) + "/" + nome + ".html"

# Da un indirizzo digitato o cliccato alla pagina ("" se non e' dei nostri). Tollerante
# come i browser dell'epoca: "http://www.newsoggi.it/", "www.newsoggi.it", "newsoggi.it" e
# "newsoggi" portano tutti allo stesso posto; il percorso ("/regole.html") sceglie la
# pagina del sito. Si cercano i domini di TUTTE le lingue: un indirizzo dell'altra lingua
# non deve dare errore (e' tolleranza, non una scorciatoia: porta alla stessa pagina).
static func page_of(url: String) -> String:
	var u := url.strip_edges().to_lower()
	u = u.trim_prefix("http://").trim_prefix("https://").trim_suffix("/")
	if u == "":
		return ""
	# il nome interno ("forum", "forum/regole"), per compatibilita'
	if CatalogoSiti.sito(u.get_slice("/", 0)).size() > 0 and u.find(".") < 0:
		return u if u.find("/") > 0 else u + "/index"
	if u == HOME:
		return HOME
	# il sito il cui indirizzo (dominio ed eventuale percorso, ~jack99) combacia di piu'
	var meglio := ""
	var resto := ""
	var lungo := -1
	for c in CatalogoSiti.SITI:
		for lng in ["en", "it"]:
			var base := str(c[lng]).to_lower()
			for forma in [base, base.trim_prefix("www.")]:
				var r := _resto(u, forma)
				if r != "?" and forma.length() > lungo:
					meglio = str(c["id"])
					resto = r
					lungo = forma.length()
	if meglio != "":
		return meglio + "/" + _pagina(resto)
	for h in [HOME_EN, HOME_IT]:
		if u == h or u == h.trim_prefix("www.") or u == h.trim_prefix("www.").get_slice(".", 0):
			return HOME
	# "newsoggi" da solo: il primo pezzo di un dominio senza percorso
	for c in CatalogoSiti.SITI:
		for lng in ["en", "it"]:
			var base := str(c[lng]).to_lower()
			if base.find("/") < 0 and u == base.trim_prefix("www.").get_slice(".", 0):
				return str(c["id"]) + "/index"
	return ""

# Se l'indirizzo u e' la base o sta sotto la base, il pezzo che resta ("" = la base);
# altrimenti "?".
static func _resto(u: String, base: String) -> String:
	if u == base:
		return ""
	if u.begins_with(base + "/"):
		return u.substr(base.length() + 1)
	return "?"

# Da un percorso ("regole.html", "", "index.htm") al nome della pagina.
static func _pagina(percorso: String) -> String:
	var p := percorso.trim_prefix("./").trim_suffix("/").get_file()
	p = p.trim_suffix(".html").trim_suffix(".htm")
	return "index" if p == "" else p

# Un LINK cliccato nella pagina "corrente": assoluto (un altro sito, il portale) passa da
# page_of; RELATIVO ("regole.html") resta nello stesso sito, che e' come sono scritti gli
# href fra le pagine di un sito d'autore. "" se non porta da nessuna parte di nostro.
static func risolvi_link(href: String, corrente: String) -> String:
	var h := href.strip_edges()
	var basso := h.to_lower()
	var primo := basso.get_slice("/", 0)
	var assoluto := basso.begins_with("http:") or basso.begins_with("https:") \
			or basso.begins_with("www.") \
			or (primo.find(".") >= 0 and not primo.ends_with(".html") and not primo.ends_with(".htm"))
	var s := sito_di(corrente)
	if assoluto or s == "":
		return page_of(h)
	return s + "/" + _pagina(h)

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
	var file := str(sito["file"]) + "/index"
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
	var file := str(sito["file"]) + "/index"
	var kb := fake_kb(file)
	var r := "  <tr><td><font face=\"Courier New\" size=\"2\">"
	r += "[" + str(kb) + " KB] &raquo; <a href=\"" + display_url(file) + "\"><b>" + str(sito["name"]) + "</b></a><br>
"
	r += "  <font color=\"#555555\">" + display_url(file) + "</font><br>
"
	r += "  <font color=\"#333333\">&gt;&gt; " + str(sito.get("desc", "")) + "</font></font></td></tr>
"
	return r

# Costruisce la wiki dai siti del run: i "featured" fra i preferiti, gli altri
# nella cronologia. Niente link morti: si elencano solo i siti estratti.
static func home_html() -> String:
	_ensure()
	var featured: Array = []
	var recent: Array = []
	for s0 in raggiungibili():
		var s: Dictionary = s0
		if GameManager.debug_tutti_i_siti and not _estratto(str(s["file"])):
			# DEV-ONLY, in inglese come tutto il debug: chi prova vede quali stanotte non ci sono
			s = s.duplicate()
			s["desc"] = str(s.get("desc", "")) + " [DEBUG: not in tonight's run]"
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

# I siti del run (dizionari del pool: file = id del sito, name, desc, featured, ...). Li usa il menu
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
