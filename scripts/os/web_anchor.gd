class_name WebAnchor
extends RefCounted

# ============================================================
# DOVE nascondere la chiave del run in una pagina d'autore.
#
# Prima la chiave finiva sempre in una riga aggiunta prima di </body>, e a forza di
# giocare si riconosceva a vista. Qui la pagina viene scandita e si raccolgono tutti
# i punti in cui la chiave puo' entrare senza rompere niente; poi ne viene estratto
# uno (vedi inietta()). Come in Welcome to the Game 2: puo' stare in mezzo alla
# pagina o in mezzo al codice, non solo in fondo.
#
# Modulo PURO: nessun riferimento a GameManager o OSContent, cosi' i test possono
# provarlo headless sulle pagine vere (tests/html_bb_test.gd). La politica (quale
# sito, quale frase, quale modalita') resta in web_runtime.gd.
#
# Le tre trappole che le regole qui sotto evitano -- misurate, non supposte:
#  1 il testo dentro una tabella ma FUORI da una cella non viene reso
#    (HtmlBB._rows accumula solo mentre e' dentro <td>/<th>): niente ancore
#    visibili in quei punti, mentre per i commenti vanno benissimo;
#  2 in coda a una cella i <font color="#FFFFFF"> sono gia' chiusi, quindi su una
#    cella scura la frase sarebbe nera su fondo scuro: serve il controllo di
#    contrasto (_leggibile);
#  3 un commento dentro <title> finirebbe nella barra del titolo della finestra
#    (app_browser lo legge dall'HTML non ripulito): dentro il titolo niente.
# ============================================================

# ---- tipi di ancoraggio ----
# Visibili (resi a schermo, selezionabili).
const RIGA := "RIGA"                     # riga a se' fra due blocchi
const IN_FRASE := "IN_FRASE"             # in mezzo a una frase: solo la chiave nuda
const CODA_PARAGRAFO := "CODA_PARAGRAFO" # attaccata alla fine di un paragrafo
const VOCE_ELENCO := "VOCE_ELENCO"       # nuova voce di un elenco esistente
const CODA_CELLA := "CODA_CELLA"         # in fondo a una cella chiara di tabella
# Solo nel sorgente (invisibili a schermo).
const COMM_BLOCCO := "COMM_BLOCCO"       # commento fra due blocchi
const COMM_TESTO := "COMM_TESTO"         # commento in mezzo a una frase del markup
const COMM_HEAD := "COMM_HEAD"           # commento nell'intestazione, in cima al codice
const COMM_TABELLA := "COMM_TABELLA"     # commento sepolto fra le righe di una tabella
const ATTRIBUTO := "ATTRIBUTO"           # title= di un link, alt= di un'immagine
const RIPIEGO := "RIPIEGO"               # nessuna ancora: come si faceva prima

# Ordine FISSO di estrazione del tipo. Non si usa l'ordine di scansione: dipenderebbe
# dalla pagina e la scelta non sarebbe riproducibile dal seme.
const TIPI_VISIBILI := [RIGA, IN_FRASE, CODA_PARAGRAFO, VOCE_ELENCO, CODA_CELLA]
const TIPI_SORGENTE := [COMM_BLOCCO, COMM_TESTO, COMM_HEAD, COMM_TABELLA, ATTRIBUTO]

# Pesi per TIPO, non per singola fessura: le ~8 fessure "riga a se'" altrimenti
# schiaccerebbero l'unica cella o l'unico elenco, e la varieta' non si vedrebbe.
const PESI := {
	RIGA: 2, IN_FRASE: 3, CODA_PARAGRAFO: 3, VOCE_ELENCO: 2, CODA_CELLA: 2,
	COMM_BLOCCO: 2, COMM_TESTO: 3, COMM_HEAD: 2, COMM_TABELLA: 2, ATTRIBUTO: 2,
}

# Soglie, tarate sulle 10 pagine vere (il censimento lo stampa il test).
const MIN_TRATTO := 30        # caratteri minimi di un tratto di testo per starci in mezzo
const MIN_PARAGRAFO := 24     # testo minimo di un paragrafo per scrivergli in coda
const MIN_CELLA := 24         # testo minimo di una cella
const MIN_FUORI_LINK := 12    # testo del paragrafo che non sta dentro un link
const FONT_TITOLO := 4        # <font size="4"> o piu': e' un titolo, non prosa
const MIN_CONTRASTO := 0.55   # scarto di luminanza fondo/testo per dire "cella chiara"
                              # (0.45 lasciava passare il grigio #808080, dove il testo
                              # autorato e' bianco e il nero si legge male)

const CONTENITORI := ["p", "div", "center", "blockquote", "ul", "ol", "li", "table",
	"tr", "td", "th", "h1", "h2", "h3", "h4", "h5", "h6", "form", "font", "a",
	"b", "i", "u", "s", "code"]
const VOID_BLOCCO := ["br", "hr"]

# ============================================================
# Scansione
# ============================================================

# Tutte le ancore della pagina per la modalita' chiesta, in ordine di posizione.
# Ogni voce: { pos, tipo, nota } piu' eventuali extra ("attr" per ATTRIBUTO,
# "lista" per VOCE_ELENCO).
static func ancore(src: String, visibile: bool) -> Array:
	var out: Array = []
	var i := 0
	var n := src.length()
	var zona := "pre"              # "pre" -> "head" -> "body"
	var in_titolo := false
	var pila: Array = []           # contenitori aperti
	var prof_tab := 0
	var in_cella := false
	var cella_th := false
	var cella_testo := 0
	var fondo_cella := ""
	var fondo_riga := ""
	var fondo_tab := ""
	var fondo_pagina := ""
	var col_testo := ""
	var par_aperto := false
	var par_testo := 0
	var par_link := 0
	var par_titolo := false
	var in_link := 0
	var lista_pos := -1
	# contatori: servono solo a scrivere la nota per il pannello F12
	var n_par := 0
	var n_tab := 0
	var n_celle := 0

	while i < n:
		# ---- tratto di testo ----
		if src[i] != "<":
			var lt := src.find("<", i)
			if lt < 0:
				lt = n
			var tratto := src.substr(i, lt - i)
			var lung := tratto.strip_edges().length()
			if par_aperto:
				par_testo += lung
				if in_link > 0:
					par_link += lung
			if in_cella:
				cella_testo += lung
			if lung >= MIN_TRATTO and not in_titolo and zona == "body":
				var reso: bool = prof_tab == 0 or in_cella
				var dove := _nota_testo(par_aperto, n_par, in_cella, n_celle)
				if visibile and reso and in_link == 0:
					var sp := _spazio_centrale(tratto)
					if sp >= 0:
						out.append({"pos": i + sp + 1, "tipo": IN_FRASE, "nota": dove})
				elif not visibile:
					var sp2 := _spazio_centrale(tratto)
					if sp2 >= 0:
						out.append({"pos": i + sp2 + 1, "tipo": COMM_TESTO,
								"nota": "commento " + dove})
			i = lt
			continue

		# ---- commento gia' presente nel file: si salta tutto ----
		if src.substr(i, 4) == "<!--":
			var fine_c := src.find("-->", i)
			i = (fine_c + 3) if fine_c >= 0 else n
			continue

		var gt := src.find(">", i)
		if gt < 0:
			break
		var tag := src.substr(i + 1, gt - i - 1)
		var nm := HtmlBB._tagname(tag).to_lower()
		var chiude: bool = tag.strip_edges().begins_with("/")

		# ---- ancore che vanno PRIMA del tag di chiusura (stato ancora "dentro") ----
		if chiude and nm == "p" and prof_tab == 0 and pila.size() == 1 and str(pila[0]) == "p":
			if par_testo >= MIN_PARAGRAFO and not par_titolo \
					and (par_testo - par_link) >= MIN_FUORI_LINK and visibile:
				out.append({"pos": i, "tipo": CODA_PARAGRAFO,
						"nota": "in coda al paragrafo %d" % n_par})
		if chiude and (nm == "td" or nm == "th") and in_cella and not cella_th and visibile:
			var cima: String = str(pila[pila.size() - 1]) if not pila.is_empty() else ""
			if cima == nm and cella_testo >= MIN_CELLA \
					and _leggibile(_fondo(fondo_cella, fondo_riga, fondo_tab, fondo_pagina), col_testo):
				out.append({"pos": i, "tipo": CODA_CELLA,
						"nota": "in coda alla cella %d (tab. %d)" % [n_celle, n_tab]})
		if not visibile and chiude and nm == "head":
			out.append({"pos": i, "tipo": COMM_HEAD, "nota": "commento nell'intestazione"})

		# ---- ancora ATTRIBUTO: dentro un tag che c'e' gia' ----
		if not visibile and not chiude and zona == "body":
			var att := ""
			if nm == "a" and HtmlBB._attr(tag, "href") != "" and HtmlBB._attr(tag, "title") == "":
				att = "title"
			elif nm == "img" and HtmlBB._attr(tag, "src") != "" and HtmlBB._attr(tag, "alt") == "":
				att = "alt"
			if att != "":
				out.append({"pos": i + 1 + nm.length(), "tipo": ATTRIBUTO, "attr": att,
						"nota": "attributo %s di <%s>" % [att, nm]})

		# ---- aggiornamento dello stato ----
		match nm:
			"title":
				in_titolo = not chiude
			"head":
				zona = "head" if not chiude else zona
			"body":
				if not chiude:
					zona = "body"
					fondo_pagina = HtmlBB._attr(tag, "bgcolor")
					col_testo = HtmlBB._attr(tag, "text")
				else:
					# dopo </body> non si rende piu' niente (app_browser taglia
					# la' il documento): da qui in poi nessuna ancora
					zona = "fine"
			"table":
				if chiude:
					prof_tab = maxi(prof_tab - 1, 0)
					if prof_tab == 0:
						fondo_tab = ""
				else:
					prof_tab += 1
					n_tab += 1
					if prof_tab == 1:
						fondo_tab = HtmlBB._attr(tag, "bgcolor")
			"tr":
				if not chiude:
					fondo_riga = HtmlBB._attr(tag, "bgcolor")
					in_cella = false
			"td", "th":
				if chiude:
					in_cella = false
				else:
					in_cella = true
					cella_th = nm == "th"
					cella_testo = 0
					fondo_cella = HtmlBB._attr(tag, "bgcolor")
					n_celle += 1
			"p":
				if not chiude:
					par_aperto = true
					par_testo = 0
					par_link = 0
					par_titolo = false
					n_par += 1
				else:
					par_aperto = false
			"a":
				in_link = maxi(in_link - 1, 0) if chiude else in_link + 1
			"font":
				if not chiude and par_aperto:
					var sz := HtmlBB._attr(tag, "size")
					if sz != "" and sz.is_valid_int() and sz.to_int() >= FONT_TITOLO:
						par_titolo = true
			"ul":
				# solo <ul>: in un <ol> una voce in piu' rinumera tutte quelle dopo,
				# cioe' cambierebbe la pagina anche fuori dal punto d'inserimento
				lista_pos = -1 if chiude else gt + 1

		# ---- la pila dei contenitori (tollerante come HtmlBB._rows) ----
		if chiude:
			if CONTENITORI.has(nm):
				var k := pila.rfind(nm)
				if k >= 0:
					pila.resize(k)
		elif CONTENITORI.has(nm) and not tag.strip_edges().ends_with("/"):
			if nm == "p" and not pila.is_empty() and str(pila[pila.size() - 1]) == "p":
				pila.pop_back()           # un <p> nuovo chiude quello di prima
			pila.append(nm)

		# ---- ancore che vanno DOPO il tag (stato aggiornato) ----
		var dopo := gt + 1
		# NB: non dopo </body> -- quello che sta la' non viene reso. L'ultimo blocco
		# della pagina offre gia' la fessura "in fondo", prima di </body>.
		if zona == "body" and pila.is_empty() and prof_tab == 0 and not (chiude and nm == "body"):
			if chiude or nm == "body" or VOID_BLOCCO.has(nm):
				if visibile:
					out.append({"pos": dopo, "tipo": RIGA, "nota": _nota_riga(nm, chiude)})
				else:
					out.append({"pos": dopo, "tipo": COMM_BLOCCO,
							"nota": "commento " + _nota_riga(nm, chiude)})
		if visibile and lista_pos >= 0 and prof_tab == 0:
			# nuova voce: in testa all'elenco o dopo una voce esistente
			if (not chiude and nm == "ul") or (chiude and nm == "li"):
				out.append({"pos": dopo, "tipo": VOCE_ELENCO, "lista": lista_pos,
						"nota": "nuova voce nell'elenco"})
		if not visibile and prof_tab > 0 and not in_cella:
			if (not chiude and nm == "table") or (chiude and (nm == "tr" or nm == "td" or nm == "th")):
				out.append({"pos": dopo, "tipo": COMM_TABELLA,
						"nota": "commento nella tabella %d" % n_tab})
		if not visibile and chiude and nm == "title":
			out.append({"pos": dopo, "tipo": COMM_HEAD, "nota": "commento nell'intestazione"})

		i = dopo
	return out

# ============================================================
# Iniezione
# ============================================================

# Mette la chiave in UNA delle ancore. Le due frazioni (0..1) vengono dal seme del
# run (web_runtime.build), non da qui: cosi' la posizione e' sempre la stessa per
# tutta la partita, anche se la pagina viene ricaricata.
# Ritorna { html, tipo, nota, pos, inserito, reso }: "reso" e' il testo che DEVE
# comparire a schermo ("" se la chiave sta solo nel sorgente) e i test lo usano.
static func inietta(src: String, testo: String, chiave: String, visibile: bool,
		frac_tipo: float, frac_fessura: float) -> Dictionary:
	var lista := ancore(src, visibile)
	if lista.is_empty() or testo == "":
		return _ripiego(src, testo, visibile)
	var gruppi: Array = []
	var pesi: Array = []
	for t in (TIPI_VISIBILI if visibile else TIPI_SORGENTE):
		var g: Array = []
		for a in lista:
			if str(a["tipo"]) == t:
				g.append(a)
		if not g.is_empty():
			gruppi.append(g)
			pesi.append(int(PESI.get(t, 1)))
	if gruppi.is_empty():
		return _ripiego(src, testo, visibile)
	var gruppo: Array = gruppi[_scegli(pesi, frac_tipo)]
	var k: int = mini(gruppo.size() - 1, int(clampf(frac_fessura, 0.0, 0.999999) * gruppo.size()))
	return inserisci(src, gruppo[k], testo, chiave)

# Inserisce in UNA ancora precisa. Separata da inietta() perche' i test la usano
# per passare in rassegna tutte le ancore di tutte le pagine, non solo quella che
# il seme ha estratto.
static func inserisci(src: String, anc: Dictionary, testo: String, chiave: String) -> Dictionary:
	var pezzo := _pezzo(src, anc, testo, chiave)
	var pos := int(anc["pos"])
	return {
		"html": src.substr(0, pos) + pezzo + src.substr(pos),
		"tipo": str(anc["tipo"]), "nota": str(anc["nota"]), "pos": pos,
		"inserito": pezzo, "reso": _reso(str(anc["tipo"]), testo, chiave),
	}

# Il pezzo di HTML da infilare, che dipende dal tipo di ancora.
static func _pezzo(src: String, anc: Dictionary, testo: String, chiave: String) -> String:
	match str(anc["tipo"]):
		RIGA:
			return "\n<p><font face=\"Arial\" size=\"2\">" + testo + "</font></p>\n"
		IN_FRASE:
			# in mezzo a una frase va SOLO la chiave nuda ("...il cielo e' 3-A87G blu"),
			# senza tag: eredita font e colore del testo attorno, quindi e' sempre
			# leggibile, anche dentro una cella scura
			return chiave + " "
		CODA_PARAGRAFO, CODA_CELLA:
			return " " + testo
		VOCE_ELENCO:
			var f := _font_voce(src, int(anc.get("lista", 0)))
			if f == "":
				return "\n<li>" + testo + "</li>"
			return "\n<li>" + f + testo + "</font></li>"
		COMM_BLOCCO, COMM_HEAD:
			return "\n<!-- " + _commento_sicuro(testo) + " -->\n"
		COMM_TESTO, COMM_TABELLA:
			# senza spazi attorno: togliendo il commento il documento torna IDENTICO
			return "<!-- " + _commento_sicuro(testo) + " -->"
		ATTRIBUTO:
			return " " + str(anc.get("attr", "title")) + "=\"" + chiave + "\""
	return ""

# Cosa deve comparire a schermo per quel tipo ("" = niente, sta solo nel sorgente).
static func _reso(tipo: String, testo: String, chiave: String) -> String:
	match tipo:
		IN_FRASE:
			return chiave
		RIGA, CODA_PARAGRAFO, CODA_CELLA, VOCE_ELENCO:
			return testo
	return ""

# Come si faceva prima: riga prima di </body>, o in coda al documento. Vale quando
# la pagina non offre nessun aggancio adatto: la chiave non si perde mai.
static func _ripiego(src: String, testo: String, visibile: bool) -> Dictionary:
	if testo == "":
		return {"html": src, "tipo": RIPIEGO, "nota": "nessuna chiave", "pos": -1,
				"inserito": "", "reso": ""}
	var pezzo := ("\n<p><font face=\"Arial\" size=\"2\">" + testo + "</font></p>\n") if visibile \
			else ("\n<!-- " + _commento_sicuro(testo) + " -->\n")
	var pos := src.findn("</body>")
	var html := (src.substr(0, pos) + pezzo + src.substr(pos)) if pos >= 0 else (src + pezzo)
	return {"html": html, "tipo": RIPIEGO, "nota": "in fondo (nessun aggancio)",
			"pos": pos, "inserito": pezzo, "reso": testo if visibile else ""}

# ============================================================
# Helper
# ============================================================

# Indice dello spazio piu' vicino al centro del tratto, con una lettera o una cifra
# subito dopo (cosi' la chiave finisce FRA due parole, non dentro una). -1 se non
# ce n'e' uno utile nella meta' centrale.
static func _spazio_centrale(tratto: String) -> int:
	var n := tratto.length()
	var centro: float = float(n) * 0.5
	var scelto := -1
	var dist: float = float(n)
	for i in range(int(float(n) * 0.25), int(float(n) * 0.75)):
		if tratto[i] != " ":
			continue
		if i + 1 >= n:
			continue
		var c := tratto[i + 1]
		if not (c.to_lower() != c.to_upper() or c.is_valid_int()):
			continue
		var d: float = absf(float(i) - centro)
		if d < dist:
			dist = d
			scelto = i
	return scelto

# Il <font> della prima voce dell'elenco, senza il colore (che si eredita dalla
# pagina): cosi' la voce nuova ha lo stesso corpo delle sorelle.
static func _font_voce(src: String, da: int) -> String:
	var li := src.findn("<li", da)
	if li < 0:
		return ""
	var gt := src.find(">", li)
	if gt < 0:
		return ""
	if not src.substr(gt + 1, 5).begins_with("<font"):
		return ""
	var fgt := src.find(">", gt + 1)
	if fgt < 0:
		return ""
	var tag := src.substr(gt + 1, fgt - gt)
	var re := RegEx.create_from_string(r'\s*color="[^"]*"')
	return re.sub(tag, "", true)

# Un commento non deve poter troncare se stesso ne' sfasare chi cerca il primo ">"
# (HtmlBB e il "visualizza sorgente" lo fanno): "-->" e le angolari via.
static func _commento_sicuro(t: String) -> String:
	return t.replace("--", "-").replace("<", "(").replace(">", ")")

# Fondo efficace di una cella: cella -> riga -> tabella -> pagina.
static func _fondo(cella: String, riga: String, tabella: String, pagina: String) -> String:
	for c in [cella, riga, tabella, pagina]:
		if str(c) != "":
			return str(c)
	return ""

# Il testo di pagina si legge su quel fondo? E' il controllo che tiene la frase
# fuori dai banner scuri, dove finirebbe nera su fondo scuro.
static func _leggibile(fondo: String, testo: String) -> bool:
	return absf(_colore(fondo, Color("c0c0c0")).get_luminance()
			- _colore(testo, Color.BLACK).get_luminance()) >= MIN_CONTRASTO

static func _colore(s: String, def: Color) -> Color:
	var h := HtmlBB._col(s)
	return Color.html(h) if h != "" and Color.html_is_valid(h) else def

# Estrazione pesata: la frazione (0..1) cade in uno dei tipi disponibili.
static func _scegli(pesi: Array, frac: float) -> int:
	var tot := 0
	for p in pesi:
		tot += int(p)
	if tot <= 0:
		return 0
	var soglia: float = clampf(frac, 0.0, 0.999999) * float(tot)
	var acc := 0.0
	for k in range(pesi.size()):
		acc += float(pesi[k])
		if soglia < acc:
			return k
	return pesi.size() - 1

static func _nota_testo(par_aperto: bool, n_par: int, in_cella: bool, n_celle: int) -> String:
	if in_cella:
		return "in mezzo alla cella %d" % n_celle
	if par_aperto:
		return "in mezzo al paragrafo %d" % n_par
	return "in mezzo al testo"

static func _nota_riga(nm: String, chiude: bool) -> String:
	if nm == "body" and not chiude:
		return "riga in cima alla pagina"
	if nm == "body" and chiude:
		return "riga in fondo alla pagina"
	return "riga dopo </%s>" % nm if chiude else "riga dopo <%s>" % nm
