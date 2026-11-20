class_name BrowserApp
extends Control

# Browser del gioco: la pagina e' UN SOLO RichTextLabel, compilato dall'HTML
# "legacy" (web/pages/*.html) in BBCode da HtmlBB (scripts/os/html_bbcode.gd).
# Cosi' la selezione col mouse e' CONTINUA su tutto il documento (celle di
# tabella comprese), i link sono [url] nativi (meta_clicked: naviga al rilascio
# solo se il clic non era un trascinamento — come un browser vero) e la pagina
# scorre/riflette da sola. La chiave web per-run la inietta WebRuntime al
# caricamento (testo visibile o commento). Niente motore esterno: leggero.

var os
var window

var _addr: LineEdit
var _digitato := ""                    # ultimo indirizzo scritto a mano (vedi _load)
var _rtl: PageView                  # la pagina: un solo documento BBCode
var _page_bg: ColorRect
var _page_tile: TextureRect          # <body background="...">: lo sfondo a mosaico

var _ctx_layer: Control
var _ctx_menu: VBoxContainer
var _ctx_panel: Panel
var _menu_aperto: Button = null
var _tend_panel: Panel                 # l'elenco aperto di una tendina della pagina
var _tend_scorri: ScrollContainer
var _tend_lista: VBoxContainer
var _barra_menu: Array = []          # le voci della barra, per ALT+lettera      # voce di menu premuta (resta "giu'" mentre e' aperta)
var _btn_back: Button
var _btn_fwd: Button
var _btn_stop: Button
var _btn_pref: Button

var _current := ""
var _back: Array = []
var _forward: Array = []
var _html_text := ""                # sorgente (con chiave iniettata) per "visualizza sorgente"

var _reflow_width := -1.0            # se >= 0: la pagina ha tabelle in % -> ricompila se cambia

const PAGES_DIR := "res://web/pages/"
var _home := WebRuntime.HOME      # la wiki: pagina generata, non un file

# ---- caricamento della pagina (il modem non e' istantaneo) ----
# In WTTG2 aprire un sito richiede un attimo, e quell'attimo e' tensione: le
# minacce continuano a girare mentre aspetti. Qui l'attesa e' breve e dipende dal
# "peso" finto della pagina, lo stesso numero di KB che la wiki elenca nella
# cronologia (WebRuntime.fake_kb): il conto nella barra di stato combacia.
const CARICA_MIN := 1        	 # attesa minima, secondi
const CARICA_MAX := 3            # attesa massima: non deve annoiare
const CARICA_PER_KB := 0.018     # quanto pesa un KB finto
const CARICA_JITTER := 0.12      # sporcatura casuale, cosi' non e' mai identica
const CARICA_BLOCCHI := 14       # blocchetti della barra di avanzamento (stile Win95)
const BLOCCO_W := 8              # larghezza di un blocchetto
const BLOCCO_SEP := 2            # stacco fra due blocchetti
const INCAVO_BORDO := 2          # margine interno dell'incavo (vedi Win95._sb sotto)

# I test la abbassano (~0.05): il percorso resta lo stesso -- velo, barra di stato,
# segnale, interruzione -- ma senza aspettare secondi a ogni pagina.
static var attesa_scala := 1.0

# ATTESA_ATTIVA = false  ->  le pagine si aprono ISTANTANEE. Niente velo, niente barra
#   che conta i KB, niente globo che lampeggia; "interrompi" resta sempre grigio perche'
#   non c'e' niente da interrompere. E' il browser come era prima del 16/09.
#   Attenzione a cosa si perde: l'attesa non e' solo estetica, e' tensione -- le minacce
#   della stanza continuano a girare mentre guardi la barra, e senza attesa il web diventa
#   un posto sicuro dove stare.
#
# SCOPERTA_GRADUALE = false  ->  l'attesa resta, ma il velo copre TUTTA la pagina fino
#   alla fine e poi sparisce di colpo (com'era prima del 18/09), invece di ritirarsi
#   dall'alto seguendo i dati. Con questo spento "interrompi" ti lascia la pagina VUOTA
#   invece che a meta': e' comunque onesto (una pagina che non e' arrivata e' bianca, ed
#   e' quello che si vedeva premendo Stop durante la connessione) ma si capisce meno.
static var ATTESA_ATTIVA := true
static var SCOPERTA_GRADUALE := false

signal load_finished(page: String)

var _velo: ColorRect = null            # copre la pagina mentre "arriva"
var _stato_lbl: Label = null
var _blocchi: Array = []               # i quadratini della barra di avanzamento
var _globo: OSIcon = null              # l'icona accanto all'indirizzo: lampeggia
var _in_carica := false                # sta arrivando qualcosa (vedi is_loading)
var _tw_carica: Tween = null
var _tw_globo: Tween = null

# La musica della pagina (<bgsound>/<embed>, vedi HtmlBB._audio): parte quando la
# pagina ha finito di arrivare, si ferma cambiando pagina, ricaricando, interrompendo
# o chiudendo la finestra. Un MIDI va prima "suonato" in un thread (MidiSynth):
# _musica_attesa e' il file che si sta aspettando.
var _musica: AudioStreamPlayer = null
var _audio_pagina: Dictionary = {}
var _musica_attesa := ""
const MUSICA_DB := -6.0

# I MODULI della pagina (HtmlBB li disegna, qui funzionano): i valori scritti dal
# giocatore (id del campo -> valore), il campo in cui sta scrivendo, e la descrizione dei
# moduli che il compilatore lascia nel contesto. Si azzerano cambiando pagina.
var _valori: Dictionary = {}
var _campo := ""
var _moduli: Array = []
var _meta_contati := 0                 # cresce a ogni link cliccato (vedi _forse_fuori)
var _stato_fermo := ""                 # la barra di stato a pagina ferma (dopo un passaggio su un link)
# La pagina che risponde quando un modulo va a uno script che non c'e' (cgi-bin...): il
# server d'epoca rispondeva "500 Internal Server Error", ed e' quello che si vede.
const PAGINA_ERRORE := "500"

func launch(arg) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 2)
	add_child(root)

	# --- barra menu ---
	# Sta su una STRISCIA in rilievo che attraversa la finestra, come in Win95: prima erano
	# pulsanti piatti appoggiati sul fondo della finestra, e senza la striscia non si
	# leggevano come una barra dei menu ma come una riga di etichette. Le voci aprono
	# tendine vere (_apri_menu): erano tutte morte.
	var menubar := _striscia(root, Win95.MENUBAR_H)
	var mb_box := HBoxContainer.new()
	mb_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mb_box.offset_left = 3
	mb_box.offset_top = 2
	mb_box.offset_bottom = -2
	mb_box.add_theme_constant_override("separation", 0)
	menubar.add_child(mb_box)
	# Le scritte hanno la & davanti alla lettera dell'acceleratore (locale/ui.csv): la barra
	# la toglie, sottolinea quella lettera e risponde ad ALT (Win95.menubar_button). In
	# inglese "Favorites" ha la A sottolineata, non la F: la F e' di "File", ed e' proprio
	# cosi' che facevano i programmi dell'epoca quando la prima lettera era occupata.
	for m in [[tr("MENU_FILE"), _voci_file], [tr("MENU_EDIT"), _voci_modifica],
			[tr("MENU_VIEW"), _voci_visualizza], [tr("MENU_FAVORITES"), Callable()],
			["?", _voci_aiuto]]:
		var f: Callable = m[1]
		# "Preferiti" resta grigio per scelta di gioco: vedi la nota sulla barra strumenti.
		var mb := Win95.menubar_button(str(m[0]), f.is_valid())
		mb.custom_minimum_size = Vector2(0, 0)
		if f.is_valid():
			mb.pressed.connect(func(): _apri_menu(f.call(), mb))
		mb_box.add_child(mb)
		_barra_menu.append(mb)

	# --- barra strumenti ---
	var toolbar := _striscia(root, Win95.TB_ALTA + 8)
	var tb_box := HBoxContainer.new()
	tb_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tb_box.offset_left = 2
	tb_box.offset_top = 3
	tb_box.offset_bottom = -3
	tb_box.offset_right = -4
	tb_box.add_theme_constant_override("separation", 1)
	toolbar.add_child(tb_box)
	tb_box.add_child(_maniglia())        # il "grip" a puntini: dettaglio d'epoca
	_btn_back = _icon_btn("back", tr("BR_BACK"), _go_back)
	_btn_fwd = _icon_btn("fwd", tr("BR_FORWARD"), _go_forward)
	_btn_stop = _icon_btn("stop", tr("BR_STOP"), _interrompi)
	tb_box.add_child(_btn_back)
	tb_box.add_child(_btn_fwd)
	tb_box.add_child(_vsep())
	tb_box.add_child(_btn_stop)
	tb_box.add_child(_icon_btn("refresh", tr("BR_REFRESH"), func(): _load(_current)))
	tb_box.add_child(_icon_btn("home", tr("BR_HOME"), _go_home))
	tb_box.add_child(_vsep())
	tb_box.add_child(_icon_btn("search", tr("BR_SOURCE"), _view_source))
	# PREFERITI: disabilitato per scelta di gioco (18/09/2026). Funzionava ed elencava i siti
	# del run, ma un elenco cliccabile di tutti i siti rende la navigazione troppo comoda:
	# il giocatore deve girare fra le pagine, non saltarci da un menu. Il pulsante e la voce
	# restano al loro posto, grigi, perche' un browser dell'epoca senza Preferiti non e'
	# credibile. WebRuntime.sites() resta: e' l'elenco che la wiki usa comunque.
	_btn_pref = _icon_btn("star", Win95.testo_semplice(tr("MENU_FAVORITES")), Callable(), false)
	tb_box.add_child(_btn_pref)
	# Stampa: non c'e' una stampante e non ci sara'. Resta al suo posto perche' un browser
	# del '98 senza il pulsante stampa non e' credibile, ma DISABILITATO -- l'unica cosa
	# onesta: un pulsante che non fa niente e sembra attivo e' peggio che non averlo.
	tb_box.add_child(_icon_btn("print", tr("BR_PRINT"), Callable(), false))
	# il "throbber" va in fondo a DESTRA della barra strumenti, come nei browser dell'epoca
	# (il logo animato di Netscape / il globo di IE): prima stava infilato fra l'etichetta
	# "Indirizzo:" e il campo, dove non e' mai stato in nessun browser
	var molla := Control.new()
	molla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tb_box.add_child(molla)
	_globo = OSIcon.new()
	_globo.kind = "web"
	_globo.custom_minimum_size = Vector2(28, 28)
	_globo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_globo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tb_box.add_child(_globo)

	# La finestra non si stringe sotto la larghezza della barra strumenti: piu' stretta,
	# gli ultimi pulsanti uscivano dal bordo (vedi la stessa nota in app_file_explorer).
	if window != null:
		var minima: float = tb_box.get_combined_minimum_size().x + 24.0
		window.custom_minimum_size = Vector2(maxf(window.custom_minimum_size.x, minima),
				window.custom_minimum_size.y)

	# --- barra indirizzo ---
	# Anche questa su una striscia in rilievo: le tre barre (menu, strumenti, indirizzo)
	# devono leggersi come tre bande dello stesso mobile, non come righe sospese.
	var addrstrip := _striscia(root, Win95.ADDRBAR_H)
	var addrbar := HBoxContainer.new()
	addrbar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	addrbar.offset_left = 4
	addrbar.offset_top = 3
	addrbar.offset_bottom = -3
	addrbar.offset_right = -4
	addrbar.add_theme_constant_override("separation", 6)
	addrstrip.add_child(addrbar)
	var lbl := Label.new()
	lbl.text = tr("EX_ADDRESS")
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	addrbar.add_child(lbl)
	_addr = LineEdit.new()
	_addr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_addr.placeholder_text = tr("BR_ADDR_HINT")
	_addr.text_submitted.connect(_on_addr_submit)
	addrbar.add_child(_addr)
	addrbar.add_child(_text_btn(tr("BR_GO"), func(): _on_addr_submit(_addr.text)))

	# --- area pagina ---
	var page_area := Control.new()
	page_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_area.clip_contents = true
	root.add_child(page_area)

	_page_bg = ColorRect.new()
	_page_bg.color = Color.WHITE
	_page_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_page_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page_area.add_child(_page_bg)

	# lo sfondo a mosaico sta fra il colore e la pagina, e scorre con lei
	_page_tile = TextureRect.new()
	_page_tile.stretch_mode = TextureRect.STRETCH_TILE
	_page_tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_page_tile.visible = false
	page_area.add_child(_page_tile)

	# La pagina: un PageView (RichTextLabel specializzato, scripts/os/page_view.gd).
	# Lui gestisce clic vs trascinamento, selezione e forma del cursore: il nodo
	# nudo, con l'input inoltrato nella SubViewport, selezionava una frase a ogni
	# clic e mangiava i link. Lo scroll resta quello nativo dell'RTL (rotella +
	# auto-scroll mentre trascini la selezione oltre il bordo).
	_rtl = PageView.new()
	_rtl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := StyleBoxEmpty.new()
	pad.set_content_margin_all(PageView.PAD)    # margine della pagina
	pad.content_margin_right = PageView.PAD + PageView.BARRA   # piu' la striscia della barra
	_rtl.add_theme_stylebox_override("normal", pad)
	_rtl.add_theme_font_size_override("normal_font_size", 16)
	# il testo delle pagine e' nitido come sugli schermi del 1999 (Win95.font_pagina)
	for coppia in [["normal_font", "sans"], ["bold_font", "sans_b"], ["italics_font", "sans_i"],
			["bold_italics_font", "sans_bi"], ["mono_font", "mono"]]:
		_rtl.add_theme_font_override(coppia[0], Win95.font_pagina(coppia[1]))
	_rtl.meta_clicked.connect(_on_meta)         # UNICO meccanismo di navigazione
	_rtl.resized.connect(_on_page_resized)
	# passando su un link, in basso compare l'indirizzo dove porta (Netscape, IE)
	_rtl.meta_hover_started.connect(_su_link)
	_rtl.meta_hover_ended.connect(func(_m) -> void: _via_dal_link())
	page_area.add_child(_rtl)
	_rtl.get_v_scroll_bar().value_changed.connect(func(_v: float) -> void: _sposta_mosaico())
	page_area.resized.connect(_sposta_mosaico)

	_musica = AudioStreamPlayer.new()
	_musica.volume_db = MUSICA_DB
	_musica.bus = AudioPC.bus()           # gli altoparlanti del PC: volume, muto, posizione
	add_child(_musica)

	# Il VELO: mentre la pagina "arriva" non si deve poter leggere ne' cliccare
	# niente. Sta sopra al PageView (aggiunto dopo = disegnato dopo) ed e' STOP,
	# cosi' i clic non passano alla pagina sotto.
	_velo = ColorRect.new()
	_velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_velo.color = Color.WHITE
	_velo.mouse_filter = Control.MOUSE_FILTER_STOP
	_velo.visible = false
	page_area.add_child(_velo)

	_costruisci_barra_stato(root)
	_build_ctx_menu()

	_load(_norm(arg if arg is String else _home))

# ---------------- navigazione ----------------

# Da un INDIRIZZO (digitato nella barra, o l'argomento con cui si apre il browser) al
# nome della pagina ("sito/pagina"): WebRuntime.page_of. "start" e il vuoto sono la home;
# un indirizzo che non e' di nessuno dei nostri siti e' "server non trovato", come
# succedeva con un dominio scritto male. I LINK dentro le pagine passano da _on_meta.
func _norm(s: String) -> String:
	var pagina := WebRuntime.page_of(s)
	if pagina != "":
		return pagina
	var u := s.strip_edges().to_lower()
	if u == "" or u == "start" or u == "index" or u == "home":
		return _home
	return WebRuntime.NONSERVER

func _on_addr_submit(text: String) -> void:
	# si ricorda il testo digitato: se non porta a nessuna pagina, la barra lo
	# tiene invece di mostrare l'indirizzo della 404
	var t := text.strip_edges()
	_digitato = t if t.begins_with("http://") else ("http://" + t)
	_go(_norm(text))

func _go(name: String) -> void:
	if _current != "" and _current != name:
		_back.append(_current)
		_forward.clear()
	_load(name)

func _go_back() -> void:
	if _back.is_empty():
		return
	_forward.append(_current)
	_load(_back.pop_back())

func _go_forward() -> void:
	if _forward.is_empty():
		return
	_back.append(_current)
	_load(_forward.pop_back())

func _go_home() -> void:
	_go(_home)

# Legge il file di una pagina d'autore ("" se non c'e'). Statica perche' serve
# anche a reset_pages(), che risolve la posizione della chiave senza istanza:
# WebRuntime non fa IO su file (vedi il suo commento in testa).
# Le pagine sono TRADOTTE: stanno in web/pages/<lingua>/ e il nome della pagina e'
# un identificatore che non cambia (cambia il contenuto del file). Se una lingua non
# ha quella pagina si ripiega sull'inglese, la lingua base, e in ultimo sulla vecchia
# cartella piatta: una pagina che manca non deve sparire dal gioco, solo dalla lingua.
static func read_page(name: String) -> String:
	for path in [PAGES_DIR + WebRuntime.lingua() + "/" + name + ".html",
			PAGES_DIR + "en/" + name + ".html", PAGES_DIR + name + ".html"]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				return f.get_as_text()
	return ""

func _load(name: String) -> void:
	_ferma_musica()
	_valori.clear()
	_scrivi_in("")
	_moduli = []
	if name == "":
		name = _home
	var chiesto := name        # quello che si voleva aprire: serve alla barra se e' una 404
	var raw := ""
	if name == _home:
		# la HOME e' GENERATA per-run (i siti estratti dal catalogo), non un file
		raw = WebRuntime.home_html()
	else:
		# un sito del catalogo che stanotte NON e' fra quelli estratti non risponde: e' la
		# pagina d'epoca "impossibile trovare il server" (non la 404, che e' "il sito c'e',
		# la pagina no"), con l'indirizzo chiesto nella barra
		if not WebRuntime.in_partita(name):
			name = WebRuntime.NONSERVER
		raw = read_page(name)
		if raw == "":
			var e404 := read_page("404") if name != "404" else ""
			if e404 != "":
				name = "404"
				raw = e404
			else:
				_current = name
				_html_text = ""
				_render_html("<center><font size=\"5\"><b>Errore 404</b></font><br>Pagina non trovata.</center>")
				return
	# inietta la chiave web del run se questa pagina la ospita (visibile o commento)
	_html_text = WebRuntime.source_html(name, raw)
	_current = name
	WebRuntime.visita(name)
	# la barra mostra l'INDIRIZZO, non il nome del file. Su una pagina che non
	# esiste resta scritto l'indirizzo CHIESTO -- quello digitato, o quello del link
	# morto (il "thread rimosso" del forum) -- come in un browser vero; mostrare
	# "http://404" sarebbe l'indirizzo della pagina d'errore, non della richiesta.
	if name == WebRuntime.NONSERVER or name == PAGINA_ERRORE or (name == "404" and chiesto != "404"):
		_addr.text = _digitato if _digitato != "" else WebRuntime.display_url(chiesto)
	else:
		_addr.text = WebRuntime.display_url(name)
	if window:
		window.set_title(_between(_html_text, "<title>", "</title>"))
	_render_html(HtmlBB.strip_comments(HtmlBB.body_inner(_html_text)))
	# la pagina e' pronta dentro, ma il modem se la prende con calma: il velo la
	# tiene coperta per un attimo (vedi _avvia_caricamento)
	_avvia_caricamento(name)
	_aggiorna_pulsanti()

# Compila il body in BBCode e lo mette nell'RTL. I colori di pagina vengono dal
# <body>: bgcolor (sfondo), text (testo), link (colore dei link) — cosi' le
# pagine scure funzionano (<body bgcolor="#000000" text="#BBBBBB" link="#66FF66">).
# set_page() azzera selezione, scroll e stato di hover del link.
func _render_html(body: String) -> void:
	_page_bg.color = _body_bg(_html_text)
	_imposta_mosaico(_body_attr(_html_text, "background"))
	_rtl.add_theme_color_override("default_color", _body_text(_html_text))
	var ctx := {"link_color": _body_link(_html_text), "page_width": _page_width(),
			"vlink_color": _body_vlink(_html_text), "visitato": _visitato,
			"valori": _valori, "campo_attivo": _campo}
	_rtl.set_page(HtmlBB.compile(body, ctx))
	# Una colonna con dentro una parola o un'immagine piu' larga della sua parte allarga la
	# tabella oltre il bordo: un browser vero restringe allora le ALTRE colonne. Qui si fa lo
	# stesso ricompilando con una pagina piu' stretta di quanto e' uscito (le colonne
	# elastiche cedono quei pixel). Due tentativi bastano; se non cede, si lascia com'e'.
	var pw := _page_width()
	for _tentativo in range(2):
		var fuori := _rtl.get_content_width() - _page_width()
		if fuori <= 1.0 or not bool(ctx.get("uses_width", false)):
			break
		pw -= fuori + 2.0
		ctx = {"link_color": ctx["link_color"], "page_width": pw, "vlink_color": ctx["vlink_color"],
				"visitato": _visitato, "valori": _valori, "campo_attivo": _campo}
		_rtl.set_page(HtmlBB.compile(body, ctx))
	_moduli = ctx.get("moduli", [])
	_audio_pagina = ctx.get("audio", {})
	# le tabelle con width="N%" dipendono dalla larghezza: se la pagina ne ha,
	# ricompiliamo quando la finestra cambia misura (come il reflow di un browser)
	_reflow_width = _page_width() if bool(ctx.get("uses_width", false)) else -1.0

# Larghezza utile della pagina in pixel (tolti i margini): serve alle tabelle in %.
# Tolta anche la barra di scorrimento: su una pagina lunga compare e il testo si stringe, e
# una tabella al 100% calcolata sulla misura intera finiva col bordo destro sotto la barra.
# Come IE d'epoca, lo spazio della barra si toglie sempre.
func _page_width() -> float:
	return maxf(0.0, _rtl.size.x - 2.0 * PageView.PAD - PageView.BARRA)

# Ricompila la pagina alla nuova larghezza (solo se contiene tabelle in %).
func _on_page_resized() -> void:
	if _reflow_width < 0.0 or _html_text == "":
		return
	if absf(_page_width() - _reflow_width) < 2.0:
		return
	_render_html(HtmlBB.strip_comments(HtmlBB.body_inner(_html_text)))

# Un link cliccato: relativo = una pagina dello STESSO sito, assoluto = un altro sito o il
# portale (WebRuntime.risolvi_link). Se non porta da nessuna parte la barra mostra il link.
func _on_meta(meta) -> void:
	_meta_contati += 1
	var m := str(meta)
	# i controlli dei moduli non sono indirizzi
	if m.begins_with("__campo:"):
		_scrivi_in(m.substr(8))
		_ridisegna()
		return
	if m.begins_with("__spunta:"):
		_spunta(m.substr(9))
		return
	if m.begins_with("__tendina:"):
		_apri_tendina(m.substr(10))
		return
	if m.begins_with("__invia:"):
		_invia(int(m.substr(8)))
		return
	if m.begins_with("__azzera:"):
		_azzera(int(m.substr(9)))
		return
	if m.begins_with("__vai:"):
		m = m.substr(6)          # un pulsante-menu: da qui e' un link come gli altri
		meta = m
	_scrivi_in("")
	# i pulsanti del lettore di un <embed> non sono indirizzi
	if str(meta) == HtmlBB.META_PLAY:
		_suona()
		return
	if str(meta) == HtmlBB.META_STOP:
		_ferma_musica()
		return
	var dove := WebRuntime.risolvi_link(str(meta), _current)
	_digitato = ""          # si e' cliccato un link: non c'e' niente di digitato
	if dove == "":
		var scritto := m.strip_edges()
		_digitato = scritto if scritto.begins_with("http://") else "http://" + scritto
		dove = WebRuntime.NONSERVER
	_go(dove)

# Tasto destro = menu contestuale OVUNQUE nell'area pagina (l'RTL e' STOP e si
# mangia il clic destro; _input gira prima della distribuzione gui, e cosi' la
# selezione sopravvive al clic destro). Ctrl+C/Ctrl+A: solo quando il focus non
# e' in un campo di testo (barra indirizzo, ispettore), che si copia da solo.
# Input GLOBALE (non _gui_input): serve perche' il tasto destro e Ctrl+C devono funzionare
# sulla pagina senza che il RichTextLabel abbia il fuoco.
# Il prezzo e' che _input arriva SEMPRE, anche a finestra ridotta o coperta, quindi qui si
# deve controllare a mano di essere davvero sullo schermo -- vedi _in_primo_piano().
func _input(event: InputEvent) -> void:
	# si scrive in un campo di una pagina: i tasti sono suoi
	if _campo != "" and event is InputEventKey and event.pressed and _in_primo_piano():
		var focus := get_viewport().gui_get_focus_owner()
		if not (focus is LineEdit or focus is TextEdit) and _tasto_nel_campo(event):
			get_viewport().set_input_as_handled()
			return
	# un clic sulla pagina fuori da ogni campo smette di scrivere: si guarda DOPO che la
	# pagina ha gestito il clic, perche' il link del campo arriva solo al rilascio
	if _campo != "" and event is InputEventMouseButton and not event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and _sotto_il_mouse():
		_forse_fuori.call_deferred(_meta_contati)
	# ALT+lettera apre la tendina sottolineata. Vale la stessa regola del resto della
	# tastiera qui: risponde solo la finestra in primo piano.
	if event is InputEventKey and _in_primo_piano() \
			and Win95.premi_acceleratore(_barra_menu, event):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not _sotto_il_mouse():
			return
		if _rtl != null and _rtl.get_global_rect().has_point(get_global_mouse_position()):
			# come in Windows: il destro ATTIVA la finestra e apre il menu in un colpo solo.
			# Senza questo il primo destro su una finestra non attiva si perdeva a darle il
			# fuoco e bisognava cliccare due volte.
			if window != null and not window.active and os != null:
				os.focus_window(window)
			_show_ctx()
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and event.ctrl_pressed:
		if not _in_primo_piano():
			return
		var focus := get_viewport().gui_get_focus_owner()
		if focus is LineEdit or focus is TextEdit:
			return
		if event.keycode == KEY_C:
			_copy()
		elif event.keycode == KEY_A:
			_rtl.select_all()
			get_viewport().set_input_as_handled()

# Per la TASTIERA (Ctrl+C, Ctrl+A): comanda il FUOCO, non il mouse.
# "attiva" da sola non basta -- una finestra RIDOTTA A ICONA e' nascosta ma i suoi nodi
# restano nell'albero, con le stesse coordinate di prima, quindi senza questo controllo il
# browser continuava a rispondere da dietro e a consumare l'evento
# (get_viewport().set_input_as_handled()), lasciando desktop e altre finestre a bocca
# asciutta. is_visible_in_tree() diventa falso appena un antenato si nasconde.
func _in_primo_piano() -> bool:
	if not is_visible_in_tree():
		return false
	return window == null or window.active

# Per il MOUSE: comanda chi sta sotto il cursore, non chi ha il fuoco.
# Lo si chiede al desktop (finestra_sotto) invece di guardare window.active perche' _input
# gira PRIMA che il desktop assegni il fuoco: al primo destro su una finestra non ancora
# attiva "sono io l'attiva?" risponderebbe sempre no, e il clic andrebbe sprecato.
# Passando dal desktop si rispetta anche lo z-order, cosi' una finestra COPERTA da un'altra
# non si prende un clic che non e' suo.
func _sotto_il_mouse() -> bool:
	if not is_visible_in_tree():
		return false
	if window == null or os == null:
		return true
	return os.finestra_sotto(get_global_mouse_position()) == window

# ---------------- copia ----------------

# "Copia"/Ctrl+C: la selezione se c'e', altrimenti tutta la pagina.
func _copy() -> void:
	var txt := _rtl.get_selected_text()
	if txt.strip_edges() == "":
		txt = _rtl.get_parsed_text()
	txt = txt.strip_edges()
	if txt != "":
		DisplayServer.clipboard_set(txt)

func _copy_all() -> void:
	var txt := _rtl.get_parsed_text().strip_edges()
	if txt != "":
		DisplayServer.clipboard_set(txt)

# ---------------- estrazione dal sorgente ----------------

func _tagname(tag: String) -> String:
	var t := tag.strip_edges()
	if t.begins_with("/"):
		t = t.substr(1)
	var sp := t.find(" ")
	if sp >= 0:
		t = t.substr(0, sp)
	return t.to_lower()

func _attr(tag: String, name: String) -> String:
	var low := tag.to_lower()
	var key := name.to_lower() + "="
	var i := low.find(key)
	if i < 0:
		return ""
	i += key.length()
	if i >= tag.length():
		return ""
	var q := tag[i]
	if q == "\"" or q == "'":
		var j := tag.find(q, i + 1)
		return tag.substr(i + 1, j - i - 1) if j > i else ""
	var j2 := i
	while j2 < tag.length() and tag[j2] != " " and tag[j2] != ">":
		j2 += 1
	return tag.substr(i, j2 - i)

func _between(s: String, a: String, b: String) -> String:
	var i := s.findn(a)
	if i < 0:
		return ""
	i += a.length()
	var j := s.findn(b, i)
	return s.substr(i, j - i).strip_edges() if j >= 0 else ""

# Attributo del tag <body> ("bgcolor"/"text"/"link"), o "" se assente.
func _body_attr(html: String, name: String) -> String:
	var bi := html.findn("<body")
	if bi >= 0:
		var gt := html.find(">", bi)
		if gt > bi:
			return _attr(html.substr(bi, gt - bi), name)
	return ""

# ---------------- sfondo a mosaico ----------------

func _imposta_mosaico(src: String) -> void:
	var tex: Texture2D = HtmlBB.texture(src) if src.strip_edges() != "" else null
	_page_tile.texture = tex
	_page_tile.visible = tex != null
	_sposta_mosaico()

# Il mosaico scorre con la pagina: si sposta di quanto e' scorsa, modulo una
# piastrella, e copre sempre l'area visibile piu' una piastrella di scorta.
func _sposta_mosaico() -> void:
	if _page_tile == null or _page_tile.texture == null:
		return
	var area: Vector2 = (_page_tile.get_parent() as Control).size
	var th: float = maxf(1.0, float(_page_tile.texture.get_height()))
	var scorso: float = _rtl.get_v_scroll_bar().value if _rtl != null else 0.0
	_page_tile.position = Vector2(0.0, -fposmod(scorso, th))
	_page_tile.size = Vector2(area.x, area.y + th)

# ---------------- musica della pagina ----------------

func _suona() -> void:
	var path := str(_audio_pagina.get("path", ""))
	if path == "" or _musica == null:
		return
	var loop := bool(_audio_pagina.get("loop", false))
	if path.get_extension().to_lower() == "mid":
		var s := MidiSynth.stream_in_cache(path, loop)
		if s != null:
			_avvia_musica(s)
		elif not MidiSynth.pronto(path):
			# il MIDI va prima "suonato": in un thread, e intanto si aspetta
			_musica_attesa = path
			MidiSynth.prepara(path)
			set_process(true)
		return
	var st := load(path) as AudioStream
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = loop
	elif st is AudioStreamWAV and loop:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	if st != null:
		_avvia_musica(st)

func _avvia_musica(st: AudioStream) -> void:
	_musica_attesa = ""
	_musica.stream = st
	_musica.play()

func _ferma_musica() -> void:
	_musica_attesa = ""
	if _musica != null:
		_musica.stop()

# Vero mentre la pagina sta suonando (i test lo usano).
func sta_suonando() -> bool:
	return _musica != null and _musica.playing

# Vero mentre si aspetta che il MIDI della pagina sia pronto.
func musica_in_attesa() -> bool:
	return _musica_attesa != ""

func _process(_delta: float) -> void:
	if _musica_attesa == "":
		set_process(false)
		return
	if MidiSynth.pronto(_musica_attesa):
		var s := MidiSynth.stream_in_cache(_musica_attesa, bool(_audio_pagina.get("loop", false)))
		_musica_attesa = ""
		if s != null:
			_avvia_musica(s)

func _body_bg(html: String) -> Color:
	var bg := HtmlBB._col(_body_attr(html, "bgcolor"))
	if bg != "" and Color.html_is_valid(bg):
		return Color.html(bg)
	return Color("c0c0c0")

func _body_text(html: String) -> Color:
	var c := HtmlBB._col(_body_attr(html, "text"))
	if c != "" and Color.html_is_valid(c):
		return Color.html(c)
	return Win95.C_TEXT

# ---------------- moduli ----------------

func _campo_da_id(id: String) -> Dictionary:
	for mod in _moduli:
		for c in mod["campi"]:
			if str(c["id"]) == id:
				return c
	return {}

func _valore(c: Dictionary) -> String:
	return str(_valori.get(c["id"], c["valore"]))

# Comincia (o smette, con "") a scrivere in un campo. Finche' si scrive, la "p" non mette
# in pausa e ESC smette di scrivere invece di uscire dal PC (desktop.typing/trattiene_esc
# chiedono al gruppo "campo_web_attivo").
func _scrivi_in(id: String) -> void:
	_campo = id
	if id != "" and not is_in_group("campo_web_attivo"):
		add_to_group("campo_web_attivo")
	elif id == "" and is_in_group("campo_web_attivo"):
		remove_from_group("campo_web_attivo")

# Vero se questa finestra sta ricevendo la tastiera per un campo della pagina.
func scrive() -> bool:
	return _campo != "" and _in_primo_piano()

# Ricompila la pagina con i valori nuovi senza perdere il punto a cui si era arrivati.
func _ridisegna() -> void:
	var barra := _rtl.get_v_scroll_bar()
	var dove := barra.value
	_render_html(HtmlBB.strip_comments(HtmlBB.body_inner(_html_text)))
	barra.value = dove
	(func() -> void: barra.value = dove).call_deferred()

# Un tasto mentre si scrive. Vero se l'ha usato il campo.
func _tasto_nel_campo(ev: InputEventKey) -> bool:
	var c := _campo_da_id(_campo)
	if c.is_empty():
		_scrivi_in("")
		return false
	if ev.ctrl_pressed or ev.alt_pressed or ev.meta_pressed:
		return false
	var v := _valore(c)
	match ev.keycode:
		KEY_BACKSPACE:
			v = v.substr(0, maxi(0, v.length() - 1))
		KEY_ENTER, KEY_KP_ENTER:
			if str(c["tipo"]) != "textarea":
				_invia(int(c["modulo"]))
				return true
			v += "\n"
		KEY_ESCAPE:
			_scrivi_in("")
			_ridisegna()
			return true
		KEY_TAB:
			_campo_dopo(c)
			return true
		_:
			if ev.unicode < 32:
				return false
			var massimo := int(c.get("max", 0))
			if massimo > 0 and v.length() >= massimo:
				return true
			v += char(ev.unicode)
	_valori[_campo] = v
	_ridisegna()
	return true

# Tab: il campo scrivibile dopo, nello stesso modulo (in giro).
func _campo_dopo(c: Dictionary) -> void:
	var campi: Array = []
	for x in _moduli[int(c["modulo"])]["campi"]:
		if str(x["tipo"]) in ["text", "password", "textarea"]:
			campi.append(x)
	var k := 0
	for j in range(campi.size()):
		if str(campi[j]["id"]) == str(c["id"]):
			k = (j + 1) % campi.size()
	_scrivi_in(str(campi[k]["id"]))
	_ridisegna()

func _forse_fuori(contati: int) -> void:
	if contati == _meta_contati and _campo != "":
		_scrivi_in("")
		_ridisegna()

func _spunta(id: String) -> void:
	var c := _campo_da_id(id)
	if c.is_empty():
		return
	if str(c["tipo"]) == "radio":
		# un solo pallino per gruppo (stesso modulo, stesso nome)
		for x in _moduli[int(c["modulo"])]["campi"]:
			if str(x["tipo"]) == "radio" and str(x["nome"]) == str(c["nome"]):
				_valori[x["id"]] = ""
		_valori[id] = "1"
	else:
		_valori[id] = "" if _valore(c) != "" else "1"
	_ridisegna()

# La tendina come quella di Windows: l'elenco scende PROPRIO sotto la casella, largo
# quanto lei, bianco con un filo nero; la voce sotto il mouse si accende di blu e la voce
# scelta e' accesa quando si apre. Se sotto non c'e' posto, sale sopra la casella. (Prima
# si apriva il menu del tasto destro dove si era cliccato: sembrava un'altra cosa.)
const TENDINA_RIGA := 18.0
const TENDINA_MAX_RIGHE := 10

func _apri_tendina(id: String) -> void:
	var c := _campo_da_id(id)
	if c.is_empty() or (c.get("opzioni", []) as Array).is_empty():
		return
	var pagina := _current
	var mouse := get_local_mouse_position()
	var r: Rect2 = await _rtl.rettangolo_di("__tendina:" + id)
	if pagina != _current or _campo_da_id(id).is_empty():
		return                 # nel frattempo si e' cambiata pagina
	for k in _tend_lista.get_children():
		_tend_lista.remove_child(k)
		k.queue_free()
	var scelto := _valore(c)
	var voci: Array = []
	for o in c.get("opzioni", []):
		var valore := str(o[0])
		var b := Button.new()
		b.text = str(o[1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, TENDINA_RIGA)
		b.add_theme_font_override("font", Win95.font_pagina("sans"))
		b.add_theme_font_size_override("font_size", HtmlBB.CTRL_FONT)
		b.add_theme_stylebox_override("normal", _tend_stile(false))
		b.add_theme_stylebox_override("hover", _tend_stile(true))
		b.add_theme_stylebox_override("pressed", _tend_stile(true))
		b.add_theme_stylebox_override("hover_pressed", _tend_stile(true))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.add_theme_color_override("font_color", Win95.C_TEXT)
		for stato in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			b.add_theme_color_override(stato, Win95.C_TITLE_TEXT)
		b.pressed.connect(func() -> void:
			_chiudi_menu()
			_valori[id] = valore
			_ridisegna())
		_tend_lista.add_child(b)
		voci.append(b)
		if valore == scelto:
			_accendi_voce(b, true)
	# appena il mouse passa su una voce, la scelta di prima si spegne: acceso e' solo
	# quello che c'e' sotto il mouse
	for b in voci:
		(b as Button).mouse_entered.connect(func() -> void:
			for altro in voci:
				_accendi_voce(altro, false))
	var origine: Vector2 = _rtl.global_position - global_position
	var largo := 150.0
	var dove := mouse
	var sopra := mouse.y
	if r.size.x > 0.0:
		largo = r.size.x
		dove = origine + Vector2(r.position.x, r.end.y)
		sopra = origine.y + r.position.y
	var righe := mini(voci.size(), TENDINA_MAX_RIGHE)
	var alto := float(righe) * TENDINA_RIGA + 2.0
	_tend_scorri.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if voci.size() > righe \
			else ScrollContainer.SCROLL_MODE_DISABLED
	if dove.y + alto > size.y - 4.0:
		dove.y = sopra - alto          # sotto non ci sta: si apre verso l'alto
	dove.x = clampf(dove.x, 0.0, maxf(0.0, size.x - largo))
	_tend_panel.position = dove
	_tend_panel.size = Vector2(largo, alto)
	_ctx_panel.visible = false
	_tend_panel.visible = true
	_ctx_layer.visible = true
	_ctx_layer.move_to_front()

func _accendi_voce(b: Button, acceso: bool) -> void:
	b.add_theme_stylebox_override("normal", _tend_stile(acceso))
	b.add_theme_color_override("font_color", Win95.C_TITLE_TEXT if acceso else Win95.C_TEXT)

func _tend_stile(acceso: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Win95.C_SELECT if acceso else Color.WHITE
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	return sb

func _azzera(fi: int) -> void:
	if fi < 0 or fi >= _moduli.size():
		return
	for c in _moduli[fi]["campi"]:
		_valori.erase(c["id"])
	_scrivi_in("")
	_ridisegna()

# INVIA: i valori del modulo diventano la "query" (?nome=valore&...) e si va dove dice
# action. Se e' una pagina del sito, si apre quella; se e' uno script che qui non esiste
# (/cgi-bin/cerca.pl, un .asp, un indirizzo sbagliato) il server risponde con l'errore 500
# d'epoca -- il pulsante ha funzionato, e' il server che non c'e' piu'.
func _invia(fi: int) -> void:
	if fi < 0 or fi >= _moduli.size():
		return
	var mod: Dictionary = _moduli[fi]
	var coppie: Array = []
	for c in mod["campi"]:
		var nome := str(c["nome"])
		if nome == "":
			continue
		match str(c["tipo"]):
			"checkbox", "radio":
				if _valore(c) != "":
					coppie.append(nome.uri_encode() + "=" + str(c.get("invia", "on")).uri_encode())
			_:
				coppie.append(nome.uri_encode() + "=" + _valore(c).uri_encode())
	var query := "&".join(coppie)
	var azione := str(mod["action"]).strip_edges()
	var pagina := _current if azione == "" else WebRuntime.risolvi_link(azione, _current)
	var esiste := pagina != "" and WebRuntime.in_partita(pagina) and read_page(pagina) != ""
	var indirizzo := ""
	if esiste:
		indirizzo = WebRuntime.display_url(pagina)
	else:
		var base := WebRuntime.host_of(WebRuntime.sito_di(_current) + "/index") if WebRuntime.sito_di(_current) != "" else WebRuntime.host_of(_current)
		indirizzo = azione if azione.begins_with("http") else "http://" + base + "/" + azione.trim_prefix("/")
	if query != "":
		indirizzo += "?" + query
	_scrivi_in("")
	_digitato = indirizzo
	_go(pagina if esiste else PAGINA_ERRORE)
	_addr.text = indirizzo

# ---------------- la barra di stato sui link ----------------

func _su_link(meta) -> void:
	if _in_carica or _stato_lbl == null:
		return
	var m := str(meta)
	if m.begins_with("__vai:"):
		m = m.substr(6)          # un pulsante-menu: la barra dice dove porta, come un link
	elif m.begins_with("__"):
		return
	var dove := WebRuntime.risolvi_link(m, _current)
	_stato_lbl.text = WebRuntime.display_url(dove) if dove != "" else (m if m.begins_with("http") else "http://" + m)

func _via_dal_link() -> void:
	if _in_carica or _stato_lbl == null:
		return
	_stato_lbl.text = _stato_fermo

# Un link porta a una pagina gia' vista in questa partita? (il colore vlink)
func _visitato(href: String) -> bool:
	var p := WebRuntime.risolvi_link(href, _current)
	return p != "" and WebRuntime.visitate.has(p)

func _body_vlink(html: String) -> String:
	var c := HtmlBB._col(_body_attr(html, "vlink"))
	if c != "" and Color.html_is_valid(c):
		return c
	return "#551A8B"

func _body_link(html: String) -> String:
	var c := HtmlBB._col(_body_attr(html, "link"))
	if c != "" and Color.html_is_valid(c):
		return c
	return "#" + Win95.C_LINK.to_html(false)


# ---------------- visualizza sorgente ----------------

# "Origine" come Internet Explorer: la pagina finisce in un file temporaneo (index[1].htm)
# che si apre nel BLOCCO NOTE, una finestra a se', col sorgente cosi' com'e' arrivato (niente
# rientri, niente colori) e il carattere a spaziatura fissa del Blocco note. Come IE, ogni
# pressione apre una finestra nuova; mentre la pagina arriva non si apre niente (in IE la
# voce era grigia). Senza sistema intorno (i test del solo browser) il file si prepara ma
# non c'e' dove aprirlo: lo si legge da sorgente_aperto.
var sorgente_aperto: Dictionary = {}

func _view_source() -> void:
	if _html_text == "" or is_loading():
		return
	sorgente_aperto = {"name": _nome_temporaneo(), "content": _html_text, "filetype": "text"}
	if os != null and os.has_method("open_app"):
		os.open_app("notepad", sorgente_aperto)

# Il nome che IE dava alla copia nella cache: il file della pagina con [1] (la home del
# portale, che non ha un file, era "default").
func _nome_temporaneo() -> String:
	var base := "default" if _current == "" or _current == WebRuntime.HOME else _current.get_file()
	return base + "[1].htm"

func _build_ctx_menu() -> void:
	_ctx_layer = Control.new()
	_ctx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctx_layer.visible = false
	add_child(_ctx_layer)
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			_chiudi_menu())
	_ctx_layer.add_child(catcher)
	_ctx_panel = Panel.new()
	_ctx_panel.name = "Panel"
	_ctx_panel.custom_minimum_size = Vector2(210, 0)
	_ctx_layer.add_child(_ctx_panel)
	_ctx_menu = VBoxContainer.new()
	_ctx_menu.add_theme_constant_override("separation", 0)
	_ctx_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ctx_menu.offset_left = 3
	_ctx_menu.offset_top = 3
	_ctx_menu.offset_right = -3
	_ctx_menu.offset_bottom = -3
	_ctx_panel.add_child(_ctx_menu)
	# l'elenco di una tendina della pagina (vedi _apri_tendina): bianco, filo nero
	_tend_panel = Panel.new()
	_tend_panel.name = "Tendina"
	var cornice := StyleBoxFlat.new()
	cornice.bg_color = Color.WHITE
	cornice.border_color = Win95.C_DARK
	cornice.set_border_width_all(1)
	_tend_panel.add_theme_stylebox_override("panel", cornice)
	_tend_panel.visible = false
	_ctx_layer.add_child(_tend_panel)
	_tend_scorri = ScrollContainer.new()
	_tend_scorri.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tend_scorri.offset_left = 1
	_tend_scorri.offset_top = 1
	_tend_scorri.offset_right = -1
	_tend_scorri.offset_bottom = -1
	_tend_scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tend_panel.add_child(_tend_scorri)
	_tend_lista = VBoxContainer.new()
	_tend_lista.add_theme_constant_override("separation", 0)
	_tend_lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tend_scorri.add_child(_tend_lista)

# Il menu del tasto destro sulla pagina. "Copia" e "Indietro" ci sono solo quando hanno
# senso: col tasto destro su una pagina appena aperta, in Win95, "Indietro" era grigio.
func _show_ctx() -> void:
	var sel: bool = _rtl.get_selected_text() != ""
	_riempi_menu([
		[tr("BR_BACK"), _go_back if not _back.is_empty() else Callable()],
		[tr("BR_FORWARD"), _go_forward if not _forward.is_empty() else Callable()],
		[tr("BR_REFRESH"), func(): _load(_current)],
		["-"],
		[tr("NP_COPY"), _copy if sel else Callable()],
		[tr("BR_COPY_ALL"), _copy_all],
		[tr("NP_SELECT_ALL"), func(): _rtl.select_all()],
		["-"],
		[tr("BR_VIEW_SOURCE"), _view_source],
	])
	_mostra_menu(get_local_mouse_position())

# Rigenera lo stato web del run (chiave + portatore). Gancio da GameManager.start_new_run().
static func reset_pages() -> void:
	WebRuntime.build()
	# risolve SUBITO dove finiscono le chiavi web (sono due): il pannello F12 deve
	# poterlo dire prima che il giocatore apra le pagine, e WebRuntime non legge file
	for n in range(WebRuntime.quanti_posti()):
		var c := WebRuntime.carrier(n)
		if c != "":
			WebRuntime.source_html(c, read_page(c))

# ---------------- caricamento della pagina ----------------

# La barra di stato in fondo alla finestra: a sinistra cosa sta facendo il modem,
# a destra l'avanzamento a blocchetti come nei programmi dell'epoca.
func _costruisci_barra_stato(root: Control) -> void:
	var barra := Panel.new()
	barra.add_theme_stylebox_override("panel", Win95._sb(false, Win95.C_FACE, true, 6, 3, 6, 3))
	barra.custom_minimum_size = Vector2(0, 26)
	root.add_child(barra)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", 6)
	barra.add_child(hb)

	_stato_lbl = Label.new()
	_stato_lbl.text = tr("BR_READY")
	_stato_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_stato_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stato_lbl.clip_text = true
	hb.add_child(_stato_lbl)

	# incavo con i blocchetti dentro
	# La larghezza dell'incavo si RICAVA dai blocchetti, non si scrive a mano: con
	# un numero tondo (150) restavano 8 px liberi a destra, cioe' un quadratino
	# vuoto anche a caricamento finito -- sembrava non completarsi mai.
	var largh_riga := CARICA_BLOCCHI * BLOCCO_W + (CARICA_BLOCCHI - 1) * BLOCCO_SEP
	var incavo := Panel.new()
	incavo.add_theme_stylebox_override("panel", Win95._sb(true, Win95.C_FACE, true,
			INCAVO_BORDO, INCAVO_BORDO, INCAVO_BORDO, INCAVO_BORDO))
	incavo.custom_minimum_size = Vector2(largh_riga + INCAVO_BORDO * 2, 18)
	incavo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(incavo)
	# NB: gli ancoraggi non sanno niente dei margini dello stylebox, quindi la fila
	# va rientrata a mano -- altrimenti si stende su tutto il pannello (bordo
	# compreso) e in fondo a destra resta lo spazio di un quadratino, come se la
	# barra non si completasse mai.
	var riga := HBoxContainer.new()
	riga.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	riga.offset_left = INCAVO_BORDO
	riga.offset_top = INCAVO_BORDO
	riga.offset_right = -INCAVO_BORDO
	riga.offset_bottom = -INCAVO_BORDO
	riga.add_theme_constant_override("separation", BLOCCO_SEP)
	incavo.add_child(riga)
	_blocchi.clear()
	for i in range(CARICA_BLOCCHI):
		var b := ColorRect.new()
		b.color = Win95.C_TITLE
		# larghezza FISSA, non EXPAND_FILL: i blocchetti spenti sono nascosti, e un
		# solo blocchetto elastico si allargherebbe su tutta la barra (visto)
		b.custom_minimum_size = Vector2(BLOCCO_W, 0)
		b.size_flags_vertical = Control.SIZE_FILL
		b.visible = false
		riga.add_child(b)
		_blocchi.append(b)

# Vero mentre la pagina sta "arrivando". I test lo usano per aspettare.
# NON si deduce piu' dal velo: dopo un'interruzione il velo RESTA (copre la parte che non e'
# arrivata) ma il caricamento e' finito.
func is_loading() -> bool:
	return _in_carica

# Aspetta la fine del caricamento in corso (ritorna subito se non ce n'e' uno).
func attendi_caricamento() -> void:
	if is_loading():
		await load_finished

# Copre la pagina e fa scorrere la barra di stato per un tempo breve, che dipende
# dal peso finto della pagina. Un Tween e non una coroutine: muore col nodo, si
# ferma con la pausa del gioco, e ricaricare o interrompere basta ucciderlo.
func _avvia_caricamento(page: String) -> void:
	if _velo == null:
		return
	if _tw_carica != null and _tw_carica.is_valid():
		_tw_carica.kill()
	# interruttore spento: la pagina e' gia' pronta, si passa direttamente alla fine cosi'
	# barra di stato, pulsanti e segnale load_finished restano coerenti
	if not ATTESA_ATTIVA:
		_in_carica = false
		_velo.visible = false
		_scopri(0.0)
		_fine_caricamento(page)
		return
	var kb := WebRuntime.fake_kb(page)
	var durata: float = clampf(float(kb) * CARICA_PER_KB, CARICA_MIN, CARICA_MAX)
	durata = maxf((durata + randf_range(-CARICA_JITTER, CARICA_JITTER)) * attesa_scala, 0.0)
	_velo.color = _page_bg.color        # come se la pagina non fosse ancora arrivata
	_velo.visible = true
	_in_carica = true
	_rtl.deselect()
	_passo_caricamento(0.0, page)
	_globo_acceso(true)
	_tw_carica = create_tween()
	_tw_carica.tween_method(_passo_caricamento.bind(page), 0.0, 1.0, durata)
	_tw_carica.tween_callback(_fine_caricamento.bind(page))

# Un passo dell'attesa: prima la connessione, poi i dati che arrivano.
# Il VELO si ritira DALL'ALTO seguendo i dati ricevuti, cioe' la pagina si scopre dall'alto
# verso il basso come faceva davvero un browser col modem. Prima copriva tutto o niente, e
# quello rendeva "Interrompi" un imbroglio (vedi _interrompi).
func _passo_caricamento(t: float, page: String) -> void:
	var kb := WebRuntime.fake_kb(page)
	if t < 0.35:
		_stato_lbl.text = tr("BR_CONNECTING") % WebRuntime.host_of(page)
	else:
		var quanti: int = int(float(kb) * (t - 0.35) / 0.65)
		_stato_lbl.text = tr("BR_RECEIVING") % [mini(quanti, kb), kb]
	# la parte scoperta segue i DATI, non la connessione: finche' si connette non arriva
	# niente, ed e' lo stesso conto che mostra i KB qui sopra
	_scopri(clampf((t - 0.35) / 0.65, 0.0, 1.0))
	_avanzamento(t)

# Scopre la pagina dall'alto: "quanto" 0 = tutta coperta, 1 = tutta scoperta. Il velo e'
# ancorato in basso e si alza il suo bordo superiore, cosi' la parte arrivata e' leggibile
# E cliccabile (anche quello era vero: si poteva seguire un link prima della fine).
func _scopri(quanto: float) -> void:
	if _velo == null:
		return
	# interruttore spento: il velo copre tutto fino alla fine (vedi SCOPERTA_GRADUALE)
	_velo.anchor_top = clampf(quanto, 0.0, 1.0) if SCOPERTA_GRADUALE else 0.0
	_velo.offset_top = 0.0

func _fine_caricamento(page: String) -> void:
	_in_carica = false
	_velo.visible = false
	_scopri(0.0)                        # pronto per il prossimo caricamento
	_globo_acceso(false)
	_avanzamento(1.0)
	_stato_lbl.text = tr("BR_DONE") % WebRuntime.host_of(page)
	_stato_fermo = _stato_lbl.text
	_aggiorna_pulsanti()
	if bool(_audio_pagina.get("auto", false)):
		_suona()
	load_finished.emit(page)

# Il pulsante "interrompi": FERMA l'arrivo dei dati e lascia la pagina A META'.
# Prima scopriva tutta la pagina di colpo, ed era un imbroglio: bastava premerlo per
# saltare l'attesa. E l'attesa non e' un fastidio da poter saltare -- e' tensione, perche'
# le minacce nella stanza continuano a girare mentre stai li' a guardare la barra.
# Adesso il velo resta dov'e' arrivato: leggi la parte di sopra, il resto no, e per averlo
# devi ricaricare e aspettare da capo. E' anche quello che facevano i browser dell'epoca:
# Stop ti lasciava una pagina tronca, spesso senza le immagini.
func _interrompi() -> void:
	if not is_loading():
		return
	if _tw_carica != null and _tw_carica.is_valid():
		_tw_carica.kill()
	_in_carica = false
	_globo_acceso(false)
	_ferma_musica()             # la musica non era ancora arrivata: non arrivera'
	_stato_lbl.text = tr("BR_STOPPED")
	_stato_fermo = _stato_lbl.text
	_aggiorna_pulsanti()
	load_finished.emit(_current)

# Quanti blocchetti accesi.
func _avanzamento(t: float) -> void:
	var acceso: int = int(round(clampf(t, 0.0, 1.0) * float(_blocchi.size())))
	for i in range(_blocchi.size()):
		(_blocchi[i] as ColorRect).visible = i < acceso

# Il globo accanto all'indirizzo lampeggia mentre si carica: e' il "throbber" dei
# browser dell'epoca, l'unica cosa che diceva che il modem stava ancora lavorando.
func _globo_acceso(attivo: bool) -> void:
	if _globo == null:
		return
	if _tw_globo != null and _tw_globo.is_valid():
		_tw_globo.kill()
	if not attivo:
		_globo.modulate.a = 1.0
		return
	_tw_globo = create_tween().set_loops()
	_tw_globo.tween_property(_globo, "modulate:a", 0.35, 0.22)
	_tw_globo.tween_property(_globo, "modulate:a", 1.0, 0.22)

# ---------------- helper UI ----------------

# Pulsante della barra strumenti: ICONA SOPRA, NOME SOTTO. Nei browser dell'epoca su Win95
# la barra non era di sole icone -- ogni pulsante aveva la sua didascalia, ed e' anche il
# motivo per cui quelle barre erano cosi' alte. Le icone da sole, oltretutto, qui non si
# leggevano: lo schermo dell'OS viene rimpicciolito a ~2/3 e passato dal CRT.
# La cornice (pulsanti con didascalia, strisce, maniglia) e' in Win95: la costruisce
# anche l'Esplora risorse, e dev'essere la stessa. Qui restano solo i nomi corti.
func _icon_btn(kind: String, testo := "", cb := Callable(), attivo := true) -> Button:
	return Win95.tool_button(kind, testo, cb, attivo)

func _pallido(b: Button, spento: bool) -> void:
	Win95.fade(b, spento)

func _striscia(parent: Control, alta: int) -> Panel:
	return Win95.strip(parent, alta)

func _maniglia() -> Control:
	return Win95.grip()

# Aggiorna lo stato dei pulsanti che DIPENDONO da dove siamo: indietro/avanti secondo la
# cronologia, interrompi solo mentre si carica. E' il "disabilitato" piu' importante di
# tutti, perche' e' informazione vera: appena aperto il browser, "indietro" non ha dove
# andare e in Win95 era grigio.
func _aggiorna_pulsanti() -> void:
	if _btn_back != null:
		_btn_back.disabled = _back.is_empty()
		_pallido(_btn_back, _btn_back.disabled)
	if _btn_fwd != null:
		_btn_fwd.disabled = _forward.is_empty()
		_pallido(_btn_fwd, _btn_fwd.disabled)
	if _btn_stop != null:
		_btn_stop.disabled = not is_loading()
		_pallido(_btn_stop, _btn_stop.disabled)

# ---------------- le tendine della barra dei menu ----------------
# Formato di una voce: ["testo", Callable] attiva, ["testo", Callable()] DISABILITATA
# (callable non valido), ["-"] separatore.

func _voci_file() -> Array:
	return [
		[tr("BR_NEW"), Callable()],
		[tr("BR_OPEN"), Callable()],
		["-"],
		[tr("BR_SAVE_AS"), Callable()],
		[tr("BR_PRINT_DOTS"), Callable()],
		["-"],
		[tr("NP_CLOSE"), func(): if window != null: window.close()],
	]

func _voci_modifica() -> Array:
	var sel: bool = _rtl != null and _rtl.get_selected_text() != ""
	return [
		[tr("NP_CUT"), Callable()],
		[tr("NP_COPY"), _copy if sel else Callable()],
		[tr("NP_PASTE"), Callable()],
		["-"],
		[tr("NP_SELECT_ALL"), func(): _rtl.select_all()],
		[tr("BR_FIND"), Callable()],
	]

func _voci_visualizza() -> Array:
	return [
		[tr("BR_STOP"), _interrompi if is_loading() else Callable()],
		[tr("BR_REFRESH"), func(): _load(_current)],
		["-"],
		[tr("BR_FONT"), Callable()],
		[tr("BR_SOURCE"), _view_source],
	]

# Cosa CI SAREBBE nei Preferiti. Non e' piu' agganciata a niente (il menu e il pulsante
# sono disabilitati per scelta di gioco: saltare fra i siti da un elenco toglie il senso di
# girare per le pagine), ma resta qui perche' e' la sola cosa che cambierebbe se un giorno
# si volesse riattivarla -- e perche' il test la usa per verificare che sia davvero spenta.
# Se la si riattiva: le voci devono navigare con _go e non con _load, o la visita non entra
# nella cronologia e "indietro" resta grigio.
func _voci_preferiti() -> Array:
	var v: Array = [[tr("BR_ADD_FAVORITE"), Callable()], ["-"]]
	for sito in WebRuntime.sites():
		var f := str(sito.get("file", ""))
		if f == "":
			continue
		v.append([str(sito.get("name", f)), func(): _go(f + "/index")])
	if v.size() == 2:
		v.append([tr("BR_NO_SITES"), Callable()])
	return v

func _voci_aiuto() -> Array:
	return [
		[tr("BR_HELP_TOPICS"), Callable()],
		["-"],
		[tr("BR_ABOUT"), _informazioni],
	]

# Apre una tendina sotto il pulsante che l'ha chiesta. Riusa lo strato del menu
# contestuale: e' la stessa cosa, cambia solo dove si posiziona.
func _apri_menu(voci: Array, sotto: Control) -> void:
	_riempi_menu(voci)
	var giu: Vector2 = sotto.get_global_transform().origin - get_global_transform().origin
	giu.y += sotto.size.y
	_mostra_menu(giu)
	_menu_aperto = sotto as Button
	if _menu_aperto != null:
		_menu_aperto.toggle_mode = true
		_menu_aperto.set_pressed_no_signal(true)

func _chiudi_menu() -> void:
	_ctx_layer.visible = false
	_tend_panel.visible = false
	if _menu_aperto != null:
		_menu_aperto.set_pressed_no_signal(false)
		_menu_aperto.toggle_mode = false
		_menu_aperto = null

# Ricostruisce le voci: si fa a ogni apertura perche' cosa e' attivo dipende dal momento
# (c'e' una selezione? si sta caricando? quali siti esistono in questo run?).
func _riempi_menu(voci: Array) -> void:
	for c in _ctx_menu.get_children():
		c.queue_free()
		_ctx_menu.remove_child(c)
	var larga := 150.0
	for v in voci:
		var testo := str(v[0])
		if testo == "-":
			_ctx_menu.add_child(Win95.menu_separator())
			continue
		var cb: Callable = v[1] if v.size() > 1 else Callable()
		var b := Button.new()
		b.text = testo
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 26)
		if cb.is_valid():
			b.pressed.connect(func():
				_chiudi_menu()
				cb.call())
		else:
			b.disabled = true
		_ctx_menu.add_child(b)
		larga = maxf(larga, b.get_combined_minimum_size().x + 24.0)
	_ctx_panel.custom_minimum_size.x = larga

func _mostra_menu(pos: Vector2) -> void:
	var larga: float = maxf(_ctx_panel.custom_minimum_size.x, 150.0)
	var h: float = _ctx_menu.get_combined_minimum_size().y + 6.0
	pos.x = minf(pos.x, size.x - larga - 2.0)
	pos.y = minf(pos.y, size.y - h - 4.0)
	_ctx_panel.position = pos
	_ctx_panel.size = Vector2(larga, h)
	_ctx_panel.visible = true
	_tend_panel.visible = false
	_ctx_layer.visible = true
	_ctx_layer.move_to_front()

# La finestrella "Informazioni su": un About d'epoca, e l'unica voce del menu "?" che fa
# qualcosa. Nomi inventati, come in tutto il resto dell'OS.
func _informazioni() -> void:
	_chiudi_menu()
	if os == null:
		return
	# Come nell'Esplora: lo disegna il desktop, centrato sullo schermo.
	os.apri_informazioni(tr("BR_ABOUT"), "web",
			[tr("BR_ABOUT_NAME"), tr("BR_ABOUT_VER"), "", tr("BR_ABOUT_COPY")])

func _text_btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _vsep() -> VSeparator:
	var s := VSeparator.new()
	var sb := StyleBoxLine.new()
	sb.color = Win95.C_SHADOW
	sb.thickness = 1
	sb.vertical = true
	s.add_theme_stylebox_override("separator", sb)
	s.add_theme_constant_override("separation", 8)
	return s
