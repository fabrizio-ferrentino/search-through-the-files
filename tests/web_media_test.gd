extends Node

# Test del browser con i MEDIA delle pagine (2026-10-23): musica, sfondo a mosaico,
# testo che scorre e lampeggia. Si pretende che:
#   1 la musica di un <bgsound> NON parta mentre la pagina arriva, ma alla fine del
#     caricamento (prima "suonata" dal sintetizzatore in un thread), in loop se chiesto;
#   2 cambiare pagina la fermi;
#   3 un <embed autostart="false"> resti muto finche' non si preme il suo play, e il suo
#     stop la fermi (i due pulsanti sono link "__audio:" che il browser intercetta);
#   4 <body background="..."> metta lo sfondo a mosaico (anche una GIF animata) e che lo
#     sfondo SCORRA con la pagina; una pagina senza lo tolga;
#   5 [marquee] e [blink] siano effetti installati: nel testo della pagina non resta
#     nessun tag stampato;
#   6 la musica passi dal bus "PC" (AudioPC): dentro il PC pulita e centrata, nella
#     stanza dagli altoparlanti -- piu' cupa, con un filo d'eco, spostata dal lato in cui
#     sta il monitor e piu' bassa di spalle.
#
# Va eseguito come SCENA (serve l'autoload GameManager). Headless va bene: l'audio
# headless e' il driver muto, ma il player risulta comunque in riproduzione.
#   & $godot --headless --path $proj res://tests/web_media_test.tscn
# ============================================================

const LIMITE := 20.0        # secondi per il render di un MIDI in un thread

var _browser: BrowserApp
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.start_new_run(4242)
	GameManager.debug_tutti_i_siti = true
	BrowserApp.attesa_scala = 0.05
	var sub := SubViewport.new()
	sub.size = Vector2i(1440, 1080)
	add_child(sub)
	var host := Control.new()
	host.theme = Win95.make_theme()
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.size = Vector2(820, 560)
	sub.add_child(host)
	_browser = BrowserApp.new()
	host.add_child(_browser)
	_browser.launch(null)
	await _browser.attendi_caricamento()
	await get_tree().process_frame

	# ---------- 1) bgsound: parte a pagina arrivata, in loop ----------
	_pagina("<html><body><bgsound src=\"jack.mid\" loop=\"infinite\"><p>Musica!</p></body></html>")
	_check("BGSOUND_NON_SUBITO", not _browser.sta_suonando() and not _browser.musica_in_attesa(),
			"la musica e' partita mentre la pagina arrivava")
	_browser._fine_caricamento("blog/index")
	await _aspetta_musica()
	_check("BGSOUND_SUONA", _browser.sta_suonando(), "a pagina arrivata la musica non parte")
	var st := _browser._musica.stream as AudioStreamWAV
	_check("BGSOUND_LOOP", st != null and st.loop_mode == AudioStreamWAV.LOOP_FORWARD,
			"loop=\"infinite\" non e' in loop: %s" % [st])

	# ---------- 2) cambiare pagina la ferma ----------
	_browser._load("forum/index")
	_check("NAVIGA_FERMA", not _browser.sta_suonando() and not _browser.musica_in_attesa(),
			"cambiando pagina la musica continua")
	await _browser.attendi_caricamento()

	# ---------- 3) embed: muto finche' non si preme play ----------
	_pagina("<html><body><p>Inno</p><embed src=\"inno.mid\" autostart=\"false\" loop=\"true\"></body></html>")
	_browser._fine_caricamento("calcio/index")
	await get_tree().process_frame
	_check("EMBED_MUTO", not _browser.sta_suonando() and not _browser.musica_in_attesa(),
			"autostart=\"false\" suona da solo")
	# il lettore disegnato (Media Player): i suoi pulsanti sono immagini con i link play/stop
	var bb: String = _browser._rtl.text
	_check("EMBED_LETTORE", bb.find("[url=%s][img]" % HtmlBB.META_PLAY) >= 0 and bb.find("[url=%s][img]" % HtmlBB.META_STOP) >= 0,
			"il lettore non si vede")
	_browser._on_meta(HtmlBB.META_PLAY)
	await _aspetta_musica()
	_check("EMBED_PLAY", _browser.sta_suonando(), "il play non suona")
	_browser._on_meta(HtmlBB.META_STOP)
	_check("EMBED_STOP", not _browser.sta_suonando(), "lo stop non ferma")
	# e lo stop non e' un indirizzo: si resta sulla pagina
	_check("EMBED_NON_NAVIGA", _browser._current == "forum/index", "i pulsanti hanno navigato: %s" % _browser._current)

	# ---------- 4) sfondo a mosaico che scorre ----------
	var lungo := "<html><body background=\"stelle.gif\" bgcolor=\"#000020\" text=\"#FFFFFF\">"
	for k in range(80):
		lungo += "<p>Riga numero %d di una pagina lunga che deve scorrere.</p>" % k
	_pagina(lungo + "</body></html>")
	await get_tree().process_frame
	await get_tree().process_frame
	_check("MOSAICO", _browser._page_tile.visible and _browser._page_tile.texture is AnimatedTexture,
			"lo sfondo a mosaico non c'e'")
	var barra := _browser._rtl.get_v_scroll_bar()
	barra.value = 100.0
	await get_tree().process_frame
	var th := float(_browser._page_tile.texture.get_height())
	_check("MOSAICO_SCORRE", is_equal_approx(_browser._page_tile.position.y, -fposmod(barra.value, th)),
			"lo sfondo non segue lo scorrimento: y=%f, scorso=%f" % [_browser._page_tile.position.y, barra.value])
	_pagina("<html><body bgcolor=\"#FFFFFF\"><p>Niente sfondo</p></body></html>")
	_check("MOSAICO_VIA", not _browser._page_tile.visible, "lo sfondo della pagina prima e' rimasto")

	# ---------- 5) marquee e blink: effetti, non testo ----------
	_pagina("<html><body><marquee>Scorre</marquee><p><blink>Lampeggia</blink></p></body></html>")
	var testo := _browser._rtl.get_parsed_text()
	_check("EFFETTI", testo.find("Scorre") >= 0 and testo.find("Lampeggia") >= 0
			and testo.find("[") < 0, "tag stampati o testo perso: %s" % testo.c_escape())

	# ---------- 6) il bus del PC e da dove arriva il suono ----------
	_check("BUS_PC", _browser._musica.bus == AudioPC.BUS and AudioServer.get_bus_index(AudioPC.BUS) >= 0,
			"la musica non passa dagli altoparlanti del PC: %s" % _browser._musica.bus)
	for k in range(120):
		AudioPC.dentro(0.1)
	var dentro := AudioPC.stato()
	_check("DENTRO_PULITO", absf(float(dentro["pan"])) < 0.01 and float(dentro["taglio"]) > 15000.0
			and float(dentro["eco"]) < 0.01, str(dentro))
	for k in range(120):
		AudioPC.nella_stanza(Vector3(0, 0, -2), 0.1)        # monitor davanti
	var fronte := AudioPC.stato()
	_check("STANZA_CUPA", float(fronte["taglio"]) < 6000.0 and float(fronte["eco"]) > 0.1
			and float(fronte["db"]) < -1.0, str(fronte))
	for k in range(120):
		AudioPC.nella_stanza(Vector3(2, 0, 0), 0.1)         # monitor a destra
	_check("STANZA_DESTRA", float(AudioPC.stato()["pan"]) > 0.5, str(AudioPC.stato()))
	for k in range(120):
		AudioPC.nella_stanza(Vector3(0, 0, 2), 0.1)         # monitor alle spalle
	var spalle := AudioPC.stato()
	_check("STANZA_SPALLE", float(spalle["taglio"]) < float(fronte["taglio"])
			and float(spalle["db"]) < float(fronte["db"]), str(spalle))
	for k in range(120):
		AudioPC.dentro(0.1)

	GameManager.debug_tutti_i_siti = false
	if _fails.is_empty():
		print("RISULTATO: PASS (musica, sfondi ed effetti delle pagine funzionano)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# Mette una pagina scritta qui nel browser, come se fosse arrivata da un file.
func _pagina(html: String) -> void:
	_browser._ferma_musica()
	_browser._html_text = html
	_browser._render_html(HtmlBB.strip_comments(HtmlBB.body_inner(html)))

func _aspetta_musica() -> void:
	var t0 := Time.get_ticks_msec()
	while _browser.musica_in_attesa() and Time.get_ticks_msec() - t0 < LIMITE * 1000.0:
		await get_tree().process_frame
	await get_tree().process_frame

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		_fails.append(nome)
