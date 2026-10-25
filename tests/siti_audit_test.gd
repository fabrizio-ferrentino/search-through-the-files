extends Node

# COLLAUDO di tutto il web: apre OGNI pagina di OGNI sito, nelle due lingue, nel browser vero
# (alla misura della finestra in partita) e la usa come farebbe il giocatore. Pretende che:
#   APRE        la pagina si apra (non la 404, non "server non trovato")
#   LARGHEZZA   niente esca a destra dalla finestra (una tabella troppo larga e' tagliata)
#   RESIDUI     nel testo visibile non resti codice: tag HTML, BBCode, entita' &xxx;
#   IMMAGINI    nessuna immagine rotta (un src= che non esiste)
#   LINK        ogni link e pulsante-menu porti a una pagina che c'e' (o al portale, o a un
#               indirizzo morto dichiarato in "morti"): un link rotto dentro il sito e' un bug
#   CAMPI       scrivere in un campo (poco, tanto, a capo, cancellare) non cambi la misura
#               della pagina: un campo vero ha la sua misura e il testo ci scorre dentro
#   SPUNTE      caselle, pallini e tendine cambiano valore senza cambiare la misura
#   INVIO       ogni modulo inviato porti a una pagina del suo sito o all'errore 500
#   MENU        ogni pulsante-menu (onclick=location.href) apra la sua pagina
# Alla fine stampa l'elenco dei problemi, raggruppati, con la pagina.
#   & $godot --headless --path $proj res://tests/siti_audit_test.tscn
# ============================================================

const LINGUE := ["en", "it"]
const LIMITE := 1500.0
const TOLLERANZA := 1.0

var _sub: SubViewport
var _browser: BrowserApp
var _problemi: Dictionary = {}       # prova -> Array di righe
var _contati: Dictionary = {}        # prova -> quante verifiche
var _url_re := RegEx.create_from_string("\\[url=([^\\]]+)\\]")
var _tag_re := RegEx.create_from_string("</?[a-zA-Z][a-zA-Z0-9]*(\\s[^>]*)?>")
var _bb_re := RegEx.create_from_string("\\[/?(url|img|table|cell|font|font_size|color|bgcolor|b|i|u|s|center|right|left|code|marquee|blink|indent|ul|ol)\\b[^\\]]*\\]")
var _ent_re := RegEx.create_from_string("&(#[0-9]+|[a-zA-Z]{2,8});")

func _ready() -> void:
	get_tree().create_timer(LIMITE).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.start_new_run(4242)
	GameManager.debug_tutti_i_siti = true
	BrowserApp.attesa_scala = 0.0
	_sub = SubViewport.new()
	_sub.size = Vector2i(1440, 1080)
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)
	var host := Control.new()
	host.theme = Win95.make_theme()
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.size = Vector2(820, 560)      # la finestra del browser in partita
	_sub.add_child(host)
	_browser = BrowserApp.new()
	host.add_child(_browser)
	_browser.launch(null)
	await _browser.attendi_caricamento()

	for l in LINGUE:
		GameManager.set_lingua(l, false)
		WebRuntime.build()
		for c in CatalogoSiti.SITI:
			for pg in c["pagine"]:
				await _collauda(l, str(c["id"]) + "/" + str(pg), c)

	var totale := 0
	for prova in _contati.keys():
		var n: int = (_problemi.get(prova, []) as Array).size()
		totale += n
		print("%s  %s  (%d verifiche, %d problemi)" % ["PASS" if n == 0 else "FAIL", prova, int(_contati[prova]), n])
		for riga in (_problemi.get(prova, []) as Array).slice(0, 25):
			print("      " + str(riga))
		if n > 25:
			print("      ... e altri %d" % (n - 25))
	print("RISULTATO: " + ("PASS" if totale == 0 else "FAIL -> %d problemi" % totale))
	get_tree().quit(0 if totale == 0 else 1)

func _segna(prova: String, ok: bool, riga: String) -> void:
	_contati[prova] = int(_contati.get(prova, 0)) + 1
	if not ok:
		if not _problemi.has(prova):
			_problemi[prova] = []
		(_problemi[prova] as Array).append(riga)

func _apri(pagina: String) -> void:
	_browser._load(pagina)
	await _browser.attendi_caricamento()
	await get_tree().process_frame

# La misura della pagina: quanto e' alto e largo quello che c'e' dentro.
func _misura() -> Vector2:
	return Vector2(_browser._rtl.get_content_width(), _browser._rtl.get_content_height())

func _collauda(l: String, pagina: String, sito: Dictionary) -> void:
	var dove := "%s/%s" % [l, pagina]
	await _apri(pagina)
	_segna("APRE", _browser._current == pagina, "%s: si apre '%s'" % [dove, _browser._current])
	if _browser._current != pagina:
		return
	var rtl: PageView = _browser._rtl
	var bb: String = rtl.text

	# ---- larghezza ----
	# la barra di scorrimento verticale si prende la sua striscia: li' sotto non deve finire niente
	var largo: float = _browser._page_width()
	var occupa: float = rtl.get_content_width()
	# Il contenuto non deve finire sotto la barra di scorrimento. Una tabella che si allarga
	# per riempire la riga sfora di qualche px per colonna (limite del RichTextLabel 4.6, che
	# non conta il bordo delle celle quando le stringe): lo assorbe il margine destro, dove la
	# striscia della barra e' sempre riservata (PageView.BARRA). Oltre, si vedrebbe tagliato.
	var limite: float = largo + PageView.PAD
	_segna("LARGHEZZA", occupa <= limite, "%s: contenuto largo %d px, prima della barra ce ne sono %d" % [dove, int(occupa), int(limite)])

	# ---- residui ----
	# un "<nick>" scritto nella pagina come &lt;nick&gt; e' testo voluto (i log della chat,
	# la lezione di HTML del provider): conta solo il codice che non doveva vedersi
	var testo := rtl.get_parsed_text()
	var sorgente := BrowserApp.read_page(pagina)
	for re in [_tag_re, _bb_re, _ent_re]:
		var trovato := ""
		for m in (re as RegEx).search_all(testo):
			var t := m.get_string()
			if t.begins_with("<") and sorgente.find("&lt;" + t.substr(1, t.length() - 2)) >= 0:
				continue
			if t.begins_with("&") and sorgente.find("&amp;" + t.substr(1)) >= 0:
				continue
			trovato = t
			break
		_segna("RESIDUI", trovato == "", "%s: si legge '%s'" % [dove, trovato])

	# ---- immagini ----
	_segna("IMMAGINI", bb.find("_rotta_.imgtex") < 0, "%s: un'immagine rotta" % dove)

	# ---- link ----
	var morti: Array = sito.get("morti", [])
	var menu: Array = []
	for m in _url_re.search_all(bb):
		var href := m.get_string(1)
		if href.begins_with("__"):
			continue
		var nudo := href.trim_prefix("http://").trim_suffix("/").to_lower()
		var dest := WebRuntime.risolvi_link(href, pagina)
		# la pagina "rimossa" di un sito (il thread cancellato del forum) e' morta apposta
		var ok := morti.has(nudo) or dest == WebRuntime.HOME or dest.ends_with("/removed") \
				or (dest != "" and BrowserApp.read_page(dest) != "")
		_segna("LINK", ok, "%s: '%s' non porta a niente (%s)" % [dove, href, dest])
	# i pulsanti-menu: nel sorgente, per sapere quali sono
	var on_re := RegEx.create_from_string("location(?:\\.href)?\\s*=\\s*'([^']+)'")
	for m in on_re.search_all(sorgente):
		menu.append(m.get_string(1))

	# ---- campi, spunte, tendine ----
	var base := _misura()
	var moduli: Array = _browser._moduli.duplicate(true)
	for fi in range(moduli.size()):
		for c in moduli[fi]["campi"]:
			var id := str(c["id"])
			match str(c["tipo"]):
				"text", "password", "textarea":
					await _prova_campo(dove, id, str(c["tipo"]), base)
				"checkbox", "radio":
					_browser._spunta(id)
					await get_tree().process_frame
					_uguale("SPUNTE", dove, "dopo la spunta di %s" % id, base)
					# di nuovo com'era (un pallino non si toglie ricliccandolo)
					_browser._valori.clear()
					_browser._ridisegna()
				"select":
					for o in c.get("opzioni", []):
						_browser._valori[id] = str(o[0])
						_browser._ridisegna()
						await get_tree().process_frame
						_uguale("SPUNTE", dove, "tendina %s su '%s'" % [id, str(o[1])], base)
					# di nuovo com'era: la prova del campo dopo parte dalla pagina di partenza
					_browser._valori.erase(id)
					_browser._ridisegna()
		_browser._valori.clear()
		_browser._ridisegna()

	# ---- invio: ogni modulo, dalla pagina appena aperta ----
	for fi in range(moduli.size()):
		var meta := "__invia:%d" % fi
		if bb.find("[url=" + meta + "]") < 0:
			continue
		await _apri(pagina)
		_browser._on_meta(meta)
		await _browser.attendi_caricamento()
		var arrivo: String = _browser._current
		var ok := arrivo == BrowserApp.PAGINA_ERRORE or WebRuntime.sito_di(arrivo) == WebRuntime.sito_di(pagina)
		_segna("INVIO", ok, "%s: il modulo %d porta a '%s'" % [dove, fi, arrivo])

	# ---- pulsanti-menu ----
	for href in menu:
		await _apri(pagina)
		var atteso := WebRuntime.risolvi_link(str(href), pagina)
		_browser._on_meta(str(href))
		await _browser.attendi_caricamento()
		_segna("MENU", _browser._current == atteso, "%s: il pulsante '%s' apre '%s'" % [dove, href, _browser._current])

func _uguale(prova: String, dove: String, cosa: String, base: Vector2) -> void:
	var ora := _misura()
	_segna(prova, absf(ora.x - base.x) <= TOLLERANZA and absf(ora.y - base.y) <= TOLLERANZA,
			"%s: %s la pagina passa da %dx%d a %dx%d" % [dove, cosa, int(base.x), int(base.y), int(ora.x), int(ora.y)])

func _tasto(u: String, code := KEY_NONE) -> void:
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = code
	ev.unicode = u.unicode_at(0) if u != "" else 0
	_browser._tasto_nel_campo(ev)

func _prova_campo(dove: String, id: String, tipo: String, base: Vector2) -> void:
	_browser._scrivi_in(id)
	_browser._ridisegna()
	await get_tree().process_frame
	_uguale("CAMPI", dove, "attivando %s" % id, base)
	for ch in "ciao":
		_tasto(ch)
	await get_tree().process_frame
	_uguale("CAMPI", dove, "scrivendo poco in %s" % id, base)
	for k in range(90):
		_tasto("Wm "[k % 3])
	await get_tree().process_frame
	_uguale("CAMPI", dove, "scrivendo tanto in %s" % id, base)
	if tipo == "textarea":
		for k in range(12):
			_tasto("", KEY_ENTER)
			_tasto("x")
		await get_tree().process_frame
		_uguale("CAMPI", dove, "andando a capo in %s" % id, base)
	_browser._valori[id] = ""
	_browser._ridisegna()
	await get_tree().process_frame
	_uguale("CAMPI", dove, "svuotando %s" % id, base)
	_browser._scrivi_in("")
	_browser._ridisegna()
	await get_tree().process_frame
	_uguale("CAMPI", dove, "lasciando %s" % id, base)
