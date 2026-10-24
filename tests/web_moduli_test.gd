extends Node

# Test dei MODULI delle pagine web e dei comportamenti d'epoca del browser (24/10/2026,
# proprietario: "se i pulsanti esistevano creamoli"). Si pretende che:
#   1 un clic su un campo lo attivi: i tasti scrivono, Backspace cancella, il campo
#     mostra il testo col cursore, e finche' si scrive il browser lo dichiara (scrive(),
#     gruppo "campo_web_attivo": la "p" non mette in pausa, ESC non esce dal PC);
#   2 ESC smetta di scrivere;
#   3 le caselle si spuntino e si tolgano, i pallini di un gruppo si escludano a vicenda,
#     la tendina si apra e la voce scelta diventi il valore;
#   4 Invia porti dove dice action con i valori nella query: uno script che non c'e'
#     (/cgi-bin/...) da' la pagina d'errore 500 d'epoca, una pagina del sito la apre;
#     Invio in un campo di testo invia; Annulla riporta i valori della pagina;
#   5 passando su un link la barra di stato mostri l'indirizzo, e uscendo torni com'era;
#   6 i link alle pagine gia' viste prendano il colore vlink della pagina.
#
# Va eseguito come SCENA (serve l'autoload GameManager). Headless va bene.
#   & $godot --headless --path $proj res://tests/web_moduli_test.tscn
# ============================================================

const MODULO := """<html><body bgcolor="#FFFFFF" link="#0000FF" vlink="#800080">
<p>Una pagina di prova con un modulo, come quelle di una volta.</p>
<form action="/cgi-bin/cerca.pl" method="get">
Cerca: <input type="text" name="q" size="20">
<input type="checkbox" name="c" value="si"> solo titoli
<input type="radio" name="r" value="a" checked> tutto <input type="radio" name="r" value="b"> archivio
<select name="s"><option value="1">Uno<option value="2">Due</select>
<input type="submit" value="Cerca"> <input type="reset" value="Annulla">
</form>
</body></html>"""

var _sub: SubViewport
var _browser: BrowserApp
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.start_new_run(4242)
	GameManager.debug_tutti_i_siti = true
	BrowserApp.attesa_scala = 0.05
	_sub = SubViewport.new()
	_sub.size = Vector2i(1440, 1080)
	add_child(_sub)
	var host := Control.new()
	host.theme = Win95.make_theme()
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.size = Vector2(820, 560)
	_sub.add_child(host)
	_browser = BrowserApp.new()
	host.add_child(_browser)
	_browser.launch(null)
	await _browser.attendi_caricamento()
	_browser._load("forum/index")
	await _browser.attendi_caricamento()
	await get_tree().process_frame

	# ---------- 1) scrivere in un campo ----------
	_pagina(MODULO)
	_check("MODULO_LETTO", _browser._moduli.size() == 1 and (_browser._moduli[0]["campi"] as Array).size() == 5,
			"moduli: %s" % [_browser._moduli])
	_browser._on_meta("__campo:m0_0")
	_check("CAMPO_ATTIVO", _browser._campo == "m0_0" and _browser.scrive() and _browser.is_in_group("campo_web_attivo"),
			"il campo non si attiva")
	for ch in "ciao":
		_tasto(OS.find_keycode_from_string(ch.to_upper()), ch.unicode_at(0))
	_check("SCRIVE", str(_browser._valori.get("m0_0", "")) == "ciao", "valore: %s" % _browser._valori.get("m0_0", ""))
	_check("SI_VEDE", _browser._rtl.get_parsed_text().find("ciao|") >= 0, "il testo scritto non compare")
	_tasto(KEY_BACKSPACE, 0)
	_check("CANCELLA", str(_browser._valori.get("m0_0", "")) == "cia", "valore: %s" % _browser._valori.get("m0_0", ""))

	# ---------- 2) ESC smette di scrivere ----------
	_tasto(KEY_ESCAPE, 0)
	_check("ESC", _browser._campo == "" and not _browser.is_in_group("campo_web_attivo"), "ESC non ferma la scrittura")

	# ---------- 3) caselle, pallini, tendina ----------
	_browser._on_meta("__spunta:m0_1")
	_check("SPUNTA", str(_browser._valori.get("m0_1", "")) != "", "la casella non si spunta")
	_browser._on_meta("__spunta:m0_1")
	_check("TOGLIE", str(_browser._valori.get("m0_1", "x")) == "", "la casella non si toglie")
	_browser._on_meta("__spunta:m0_1")
	_browser._on_meta("__spunta:m0_3")
	_check("PALLINI", str(_browser._valori.get("m0_3", "")) == "1" and str(_browser._valori.get("m0_2", "x")) == "",
			"i pallini non si escludono: %s" % [_browser._valori])
	_browser._on_meta("__tendina:m0_4")
	var voci := _browser._ctx_menu.get_children().filter(func(b): return b is Button)
	_check("TENDINA_APERTA", voci.size() == 2, "voci della tendina: %d" % voci.size())
	if voci.size() == 2:
		(voci[1] as Button).pressed.emit()
	_check("TENDINA_SCELTA", str(_browser._valori.get("m0_4", "")) == "2", "valore: %s" % _browser._valori.get("m0_4", ""))

	# ---------- 4) invio ----------
	_browser._on_meta("__invia:0")
	await _browser.attendi_caricamento()
	_check("INVIA_ERRORE_500", _browser._current == BrowserApp.PAGINA_ERRORE, "pagina: %s" % _browser._current)
	_check("INVIA_QUERY", _browser._addr.text.find("/cgi-bin/cerca.pl?q=cia&c=si&r=b&s=2") >= 0,
			"indirizzo: %s" % _browser._addr.text)
	# un modulo che va a una pagina del sito la apre; Invio in un campo invia
	_browser._load("forum/index")
	await _browser.attendi_caricamento()
	_pagina(MODULO.replace("/cgi-bin/cerca.pl", "rules.html"))
	_browser._on_meta("__campo:m0_0")
	_tasto(KEY_X, "x".unicode_at(0))
	_tasto(KEY_ENTER, 0)
	await _browser.attendi_caricamento()
	_check("INVIO_INVIA", _browser._current == "forum/rules" and _browser._addr.text.find("rules.html?q=x") >= 0,
			"pagina %s, indirizzo %s" % [_browser._current, _browser._addr.text])
	# Annulla: tornano i valori della pagina
	_pagina(MODULO)
	_browser._on_meta("__spunta:m0_1")
	_browser._on_meta("__azzera:0")
	_check("ANNULLA", _browser._valori.is_empty(), "valori rimasti: %s" % [_browser._valori])

	# ---------- 5) l'indirizzo nella barra di stato ----------
	_browser._stato_fermo = "fermo"
	_browser._su_link("rules.html")
	_check("STATO_LINK", _browser._stato_lbl.text.find("rules.html") >= 0, "barra: %s" % _browser._stato_lbl.text)
	_browser._via_dal_link()
	_check("STATO_TORNA", _browser._stato_lbl.text == "fermo", "barra: %s" % _browser._stato_lbl.text)

	# ---------- 6) i link visitati ----------
	WebRuntime.visita("forum/rules")
	_pagina("<html><body link=\"#0000FF\" vlink=\"#800080\"><a href=\"rules.html\">regole</a> <a href=\"members.html\">iscritti</a></body></html>")
	var bb: String = _browser._rtl.text
	_check("VLINK", bb.find("[url=rules.html][color=#800080]") >= 0 and bb.find("[url=members.html][color=#0000FF]") >= 0,
			"bbcode: %s" % bb.c_escape())

	GameManager.debug_tutti_i_siti = false
	if _fails.is_empty():
		print("RISULTATO: PASS (i moduli funzionano, la barra di stato e i link visitati anche)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# Mette una pagina scritta qui nel browser (il sito corrente resta quello caricato).
func _pagina(html: String) -> void:
	_browser._html_text = html
	_browser._valori.clear()
	_browser._scrivi_in("")
	_browser._render_html(HtmlBB.strip_comments(HtmlBB.body_inner(html)))

func _tasto(codice: int, unicode: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codice
	ev.unicode = unicode
	ev.pressed = true
	_sub.push_input(ev)

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		_fails.append(nome)
