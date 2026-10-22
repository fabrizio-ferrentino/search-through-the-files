extends Node

# Test del CATALOGO DEI SITI (scripts/os/catalogo_siti.gd) e di come una partita li sceglie.
# Il web e' fatto di siti a cartelle, web/pages/<lingua>/<sito>/<pagina>.html, una trentina
# in tutto, 10-15 per partita di cui 4-5 di lore (proprietario, 19/10/2026). Qui si pretende:
#   1 ogni sito del catalogo ha TUTTE le sue pagine in ogni lingua, e nella cartella non c'e'
#     una pagina che il catalogo non elenca (la chiave non potrebbe mai finirci, e nessun link
#     del test la controllerebbe);
#   2 i domini non si ripetono, ne' fra i siti ne' con il portale;
#   3 in nessuna pagina c'e' un testo con la forma di una chiave (una cifra, un trattino e
#     quattro lettere/cifre): la caccia resta leale solo se le chiavi vere sono le uniche;
#   4 un sito "completo" e' complesso davvero: almeno COMPLETO_PAGINE pagine e
#     COMPLETO_TESTO caratteri di testo visibile in ogni lingua -- l'asticella che il
#     proprietario ha chiesto ("2 paragrafi e 2 o 3 sottopagine non va bene");
#   5 l'ESTRAZIONE, provata su un catalogo finto di 30 siti (il vero oggi ne ha meno e li
#     prende tutti): 10-15 siti, 4-5 di lore, almeno uno sul padre e uno sul ragazzo, stessa
#     scelta per lo stesso seme, e su tanti semi escono tutti; col catalogo vero, se i siti
#     sono meno di 10 escono tutti;
#   6 gli INDIRIZZI: una sottopagina e lo spazio ~utente si risolvono, un link relativo resta
#     nel suo sito, uno assoluto porta al sito giusto, e un sito del catalogo che stanotte non
#     e' estratto non risponde ("server non trovato");
#   7 i siti sono CHIUSI in se stessi (proprietario, 20/10/2026: "non mi piace che un sito ti
#     porta su un altro sito"): un link porta a una pagina dello STESSO sito, al portale
#     WebNet o a un indirizzo MORTO del catalogo (una pagina sparita: "server non trovato");
#   8 nessun campo o pulsante (<input>, <form>, <select>, <textarea>, <button>): il browser
#     non li sa usare, quindi un accesso, una ricerca, un carrello si scrivono CHIUSI;
#   9 le DATE: il web del PC e' fermo al 1999 (proprietario: la tragedia e' nella primavera
#     1999) -- nessuna data dopo il 1999 e niente orari relativi ("oggi, 21:05").
#
# Va eseguito come SCENA (serve l'autoload GameManager). Headless va bene.
#   & $godot --headless --path $proj res://tests/siti_catalogo_test.tscn
# ============================================================

const LINGUE := ["en", "it"]
const PAGINE := "res://web/pages/"

var _fails: Array = []
var _chiave_re := RegEx.new()
var _tag_re := RegEx.new()
var _spazi_re := RegEx.new()

func _ready() -> void:
	await get_tree().process_frame
	_chiave_re.compile("\\b\\d-[A-Z0-9]{4}\\b")
	_tag_re.compile("<[^>]*>")
	_spazi_re.compile("\\s+")
	var lingua_prima: String = GameManager.lingua
	GameManager.set_lingua("it", false)
	GameManager.start_new_run(777)

	_prova_pagine()
	_prova_domini()
	_prova_testi()
	_prova_estrazione()
	_prova_indirizzi()
	_prova_chiusi()
	_prova_controlli()
	_prova_date()
	_prova_debug_tutti()

	GameManager.set_lingua(lingua_prima, false)
	if _fails.is_empty():
		print("RISULTATO: PASS (i siti del catalogo ci sono, sono complessi e si scelgono bene)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# ---------- 1: le pagine ----------

func _prova_pagine() -> void:
	var mancanti: Array = []
	var orfane: Array = []
	for c in CatalogoSiti.SITI:
		var id := str(c["id"])
		var pagine: Array = c["pagine"]
		if pagine.is_empty() or str(pagine[0]) != "index":
			_ko("INDEX_PRIMA", "il sito %s non elenca index per prima" % id)
		for l in LINGUE:
			for pg in pagine:
				if not FileAccess.file_exists("%s%s/%s/%s.html" % [PAGINE, l, id, str(pg)]):
					mancanti.append("%s/%s/%s" % [l, id, str(pg)])
			var dir := DirAccess.open("%s%s/%s" % [PAGINE, l, id])
			if dir == null:
				mancanti.append("%s/%s/ (cartella)" % [l, id])
				continue
			for f in dir.get_files():
				if f.ends_with(".html") and not pagine.has(f.trim_suffix(".html")):
					orfane.append("%s/%s/%s" % [l, id, f])
	_check("PAGINE_CI_SONO", mancanti.is_empty(), "mancano: %s" % ", ".join(mancanti))
	_check("NIENTE_PAGINE_ORFANE", orfane.is_empty(),
			"pagine nella cartella ma non nel catalogo: %s" % ", ".join(orfane))

# ---------- 2: i domini ----------

func _prova_domini() -> void:
	var visti := {WebRuntime.HOME_EN: "portale", WebRuntime.HOME_IT: "portale"}
	var doppi: Array = []
	for c in CatalogoSiti.SITI:
		for l in LINGUE:
			var d := str(c[l]).to_lower()
			if visti.has(d):
				doppi.append("%s (%s e %s)" % [d, str(visti[d]), str(c["id"])])
			visti[d] = str(c["id"])
	_check("DOMINI_UNICI", doppi.is_empty(), "domini ripetuti: %s" % ", ".join(doppi))

# ---------- 3 e 4: i testi ----------

func _prova_testi() -> void:
	var finte: Array = []
	var poveri: Array = []
	for c in CatalogoSiti.SITI:
		var id := str(c["id"])
		var pagine: Array = c["pagine"]
		for l in LINGUE:
			var testo := 0
			for pg in pagine:
				var raw := _leggi("%s%s/%s/%s.html" % [PAGINE, l, id, str(pg)])
				var m := _chiave_re.search(raw)
				if m != null:
					finte.append("%s/%s/%s: '%s'" % [l, id, str(pg), m.get_string()])
				testo += _visibile(raw).length()
			if str(c["stato"]) == "completo":
				if pagine.size() < CatalogoSiti.COMPLETO_PAGINE or testo < CatalogoSiti.COMPLETO_TESTO:
					poveri.append("%s/%s: %d pagine, %d caratteri" % [l, id, pagine.size(), testo])
				else:
					print("   %s/%s: %d pagine, %d caratteri di testo" % [l, id, pagine.size(), testo])
	_check("NIENTE_CHIAVI_FINTE", finte.is_empty(),
			"testi con la forma di una chiave: %s" % ", ".join(finte))
	_check("SITI_COMPLETI_COMPLESSI", poveri.is_empty(),
			"siti 'completi' troppo poveri: %s" % ", ".join(poveri))

# ---------- 5: l'estrazione ----------

func _prova_estrazione() -> void:
	var finto := _catalogo_finto()
	var visti := {}
	var storti: Array = []
	for seme in range(1, 301):
		var rng := RandomNumberGenerator.new()
		rng.seed = seme
		var scelti: Array = WebRuntime._scegli_siti(finto, rng)
		var lore := 0
		var voci := {}
		for s in scelti:
			visti[str(s["file"])] = true
			if str(s["tipo"]) == "lore":
				lore += 1
				voci[str(s["voce"])] = true
		if scelti.size() < WebRuntime.SITI_MIN or scelti.size() > WebRuntime.SITI_MAX \
				or lore < WebRuntime.LORE_MIN or lore > WebRuntime.LORE_MAX \
				or not voci.has("padre") or not voci.has("ragazzo"):
			storti.append("seme %d: %d siti, %d di lore, voci %s" % [seme, scelti.size(), lore,
					str(voci.keys())])
		if seme == 7:
			var rng2 := RandomNumberGenerator.new()
			rng2.seed = seme
			var ancora: Array = WebRuntime._scegli_siti(finto, rng2)
			_check("ESTRAZIONE_RIPRODUCIBILE", _ids(ancora) == _ids(scelti),
					"stesso seme, siti diversi: %s / %s" % [str(_ids(scelti)), str(_ids(ancora))])
	_check("ESTRAZIONE_REGOLA", storti.is_empty(), "; ".join(storti.slice(0, 5)))
	_check("ESTRAZIONE_TUTTI", visti.size() == finto.size(),
			"su 300 semi sono usciti %d siti su %d" % [visti.size(), finto.size()])
	# il catalogo vero: con meno di SITI_MIN siti, la partita li prende tutti
	if CatalogoSiti.SITI.size() < WebRuntime.SITI_MIN:
		_check("CATALOGO_PICCOLO_TUTTI", WebRuntime.sites().size() == CatalogoSiti.SITI.size(),
				"il catalogo ha %d siti, la partita ne ha %d" % [CatalogoSiti.SITI.size(),
				WebRuntime.sites().size()])

func _catalogo_finto() -> Array:
	var out: Array = []
	var voci := ["padre", "padre", "padre", "ragazzo", "ragazzo", "ragazzo", "ragazzo", "ragazzo",
			"ragazzo", "maledizione", "maledizione", "maledizione"]
	for i in range(18):
		out.append({"file": "normale%d" % i, "tipo": "normale", "voce": "", "pagine": ["index"]})
	for i in range(voci.size()):
		out.append({"file": "lore%d" % i, "tipo": "lore", "voce": voci[i], "pagine": ["index"]})
	return out

func _ids(siti: Array) -> Array:
	var out: Array = []
	for s in siti:
		out.append(str(s["file"]))
	return out

# ---------- 6: gli indirizzi ----------

func _prova_indirizzi() -> void:
	var casi := {
		"http://www.webnet.it/~balena52/thoughts.html": "balena/thoughts",
		"www.webnet.it/~balena52": "balena/index",
		"www.gazzettadellaprovincia.it/tragedia.html": "cronaca/tragedia",
		"www.webnet.it": WebRuntime.HOME,
		"http://www.retroforum.com/rules.html": "forum/rules",
		"retroforum.it": "forum/index",
		"www.nonesiste.it": "",
	}
	var storti: Array = []
	for u in casi:
		if WebRuntime.page_of(str(u)) != str(casi[u]):
			storti.append("%s -> '%s' (atteso '%s')" % [u, WebRuntime.page_of(str(u)), casi[u]])
	_check("INDIRIZZI_SOTTOPAGINE", storti.is_empty(), "; ".join(storti))

	var link := [
		["rules.html", "forum/index", "forum/rules"],
		["index.html", "balena/thoughts", "balena/index"],
		["http://www.retroforum.it", "balena/links", "forum/index"],
		["http://www.webnet.it", "forum/rules", WebRuntime.HOME],
	]
	var rotti: Array = []
	for k in link:
		var r := WebRuntime.risolvi_link(str(k[0]), str(k[1]))
		if r != str(k[2]):
			rotti.append("%s da %s -> '%s' (atteso '%s')" % [k[0], k[1], r, k[2]])
	_check("LINK_NEL_SITO", rotti.is_empty(), "; ".join(rotti))

	# un sito del catalogo che stanotte non e' estratto: "server non trovato"
	var tolto := str(WebRuntime.sites()[0]["file"])
	var restano: Array = []
	for s in WebRuntime._chosen:
		if str(s["file"]) != tolto:
			restano.append(s)
	WebRuntime._chosen = restano
	_check("FUORI_PARTITA_NON_RISPONDE", not WebRuntime.in_partita(tolto + "/index")
			and WebRuntime.in_partita("404") and WebRuntime.in_partita(WebRuntime.HOME),
			"il sito %s, tolto dalla partita, risponde ancora" % tolto)
	WebRuntime.build()

# ---------- 7: siti chiusi ----------

func _prova_chiusi() -> void:
	var href_re := RegEx.new()
	href_re.compile("href\\s*=\\s*\"([^\"]*)\"")
	var fuori: Array = []
	for l in LINGUE:
		for pagina in _tutte_le_pagine():
			var id := WebRuntime.sito_di(pagina)
			var morti: Array = CatalogoSiti.sito(id).get("morti", []) if id != "" else []
			for m in href_re.search_all(_leggi("%s%s/%s.html" % [PAGINE, l, pagina])):
				var h := m.get_string(1)
				var dove := WebRuntime.risolvi_link(h, pagina)
				var nudo := h.trim_prefix("http://").trim_suffix("/").to_lower()
				# una pagina MORTA del sito ("removed") e' nel suo sito: la regola la copre gia'
				var ok := dove == WebRuntime.HOME or (id != "" and WebRuntime.sito_di(dove) == id) \
						or morti.has(nudo)
				if not ok:
					fuori.append("%s/%s -> %s" % [l, pagina, h])
	_check("SITI_CHIUSI", fuori.is_empty(), "link verso un altro sito: %s" % ", ".join(fuori.slice(0, 8)))

# ---------- 8: niente controlli ----------

func _prova_controlli() -> void:
	var re := RegEx.new()
	re.compile("(?i)<(input|form|select|textarea|button)\\b")
	var con: Array = []
	for l in LINGUE:
		for pagina in _tutte_le_pagine():
			var m := re.search(_leggi("%s%s/%s.html" % [PAGINE, l, pagina]))
			if m != null:
				con.append("%s/%s <%s>" % [l, pagina, m.get_string(1)])
	_check("NIENTE_CONTROLLI", con.is_empty(), "campi o pulsanti: %s" % ", ".join(con.slice(0, 8)))

# ---------- 9: le date ----------

func _prova_date() -> void:
	var rel := RegEx.new()
	rel.compile("(?i)\\b(today|yesterday|oggi|ieri)\\b,?\\s*(at|alle|ore)?\\s*\\d{1,2}[:.]\\d{2}")
	var anno := RegEx.new()
	anno.compile("\\b\\d{1,2}/(?:\\d{1,2}/)?((?:19|20)\\d{2})\\b|&copy;\\s*((?:19|20)\\d{2})|\\(c\\)\\s*((?:19|20)\\d{2})")
	var relative: Array = []
	var dopo: Array = []
	for l in LINGUE:
		for pagina in _tutte_le_pagine():
			var raw := _leggi("%s%s/%s.html" % [PAGINE, l, pagina])
			var m := rel.search(_visibile(raw))
			if m != null:
				relative.append("%s/%s '%s'" % [l, pagina, m.get_string()])
			# gli anni sul sorgente: _visibile toglie anche il &copy;
			for a in anno.search_all(raw):
				var y := int(a.get_string(1) + a.get_string(2) + a.get_string(3))
				if y > 1999:
					dopo.append("%s/%s '%s'" % [l, pagina, a.get_string()])
	_check("NIENTE_DATE_RELATIVE", relative.is_empty(), ", ".join(relative.slice(0, 8)))
	_check("NIENTE_DATE_DOPO_1999", dopo.is_empty(), ", ".join(dopo.slice(0, 8)))

# ---------- il debug "tutti i siti" (pannello F12) ----------

func _prova_debug_tutti() -> void:
	var tolto := str(CatalogoSiti.SITI[0]["id"])
	var restano: Array = []
	for s in WebRuntime._chosen:
		if str(s["file"]) != tolto:
			restano.append(s)
	WebRuntime._chosen = restano
	var portatori := [WebRuntime.carrier(0), WebRuntime.carrier(1)]
	GameManager.debug_tutti_i_siti = true
	var risponde := WebRuntime.in_partita(tolto + "/index")
	var nel_portale := WebRuntime.home_html().find(WebRuntime.display_url(tolto + "/index")) >= 0
	var segnato := WebRuntime.home_html().find("not in tonight's run") >= 0
	var fermi := [WebRuntime.carrier(0), WebRuntime.carrier(1)] == portatori
	GameManager.debug_tutti_i_siti = false
	var di_nuovo_no := not WebRuntime.in_partita(tolto + "/index")
	_check("DEBUG_TUTTI_I_SITI", risponde and nel_portale and segnato and fermi and di_nuovo_no,
			"risponde %s, nel portale %s, segnato %s, chiavi ferme %s, spento torna chiuso %s" % [
			risponde, nel_portale, segnato, fermi, di_nuovo_no])
	WebRuntime.build()

# Tutte le pagine del web: quelle dei siti ("sito/pagina") e quelle fuori (404, nonserver).
func _tutte_le_pagine() -> Array:
	var out: Array = ["404", WebRuntime.NONSERVER]
	for c in CatalogoSiti.SITI:
		for pg in c["pagine"]:
			out.append(str(c["id"]) + "/" + str(pg))
	return out

# ---------- utilita' ----------

func _visibile(raw: String) -> String:
	var t := HtmlBB.strip_comments(HtmlBB.body_inner(raw))
	t = _tag_re.sub(t, " ", true)
	for e in ["&nbsp;", "&middot;", "&raquo;", "&laquo;", "&mdash;", "&copy;", "&amp;", "&quot;"]:
		t = t.replace(e, " ")
	return _spazi_re.sub(t, " ", true).strip_edges()

func _leggi(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""

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
