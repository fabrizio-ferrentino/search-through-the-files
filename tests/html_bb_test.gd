extends SceneTree

# Test unitario (headless) di due cose pure, senza engine ne' autoload:
#   1 il compilatore HtmlBB: stringa HTML -> stringa BBCode;
#   2 lo scanner WebAnchor, cioe' DOVE si puo' nascondere la chiave web: si
#     passano in rassegna TUTTE le ancore di TUTTE le pagine d'autore, non solo
#     quella che un seme ha estratto.
#   & $godot --headless --path $proj -s res://tests/html_bb_test.gd

const WA := preload("res://scripts/os/web_anchor.gd")
const PAGINE := "res://web/pages/"
const CHIAVE := "9-TEST"
const FRASE := "Promemoria personale: 9-TEST. Non perderlo."
# I fondi scuri usati dalle pagine: la frase visibile non deve mai finire li'
# (sarebbe nera su fondo scuro).
const FONDI_SCURI := ["#303030", "#3a5a2f", "#808080", "#8a1f1f", "#1f6a2f",
	"#5a3f8a", "#2f6a8a", "#7a5a1f", "#000000"]

var _fails: Array = []

func _initialize() -> void:
	# 1. stack chiuso/riaperto al <br>: nessun tag attraversa il newline
	_eq("stack_br", HtmlBB.compile("<b>a<br>b</b>"), "[b]a[/b]\n[b]b[/b]")

	# 2. font annidato in b, sempre ben formato al <br>
	_eq("font_in_b", HtmlBB.compile("<b><font color=\"#ff0000\">a<br>b</font></b>"),
		"[b][color=#ff0000]a[/color][/b]\n[b][color=#ff0000]b[/color][/b]")

	# 3. entita' e parentesi quadre escapate
	_eq("entita", HtmlBB.compile("x &amp; [y] &raquo;"), "x & [lb]y[rb] »")
	# &nbsp; resta uno spazio vero, che non si comprime: i disegni ASCII si allineano con quello
	_eq("nbsp", HtmlBB.compile("a&nbsp;&nbsp;&nbsp;b  c"), "a   b c")

	# 4. link con colore dal contesto
	_eq("link", HtmlBB.compile("<a href=\"news.html\">N</a>", {"link_color": "#66ff66"}),
		"[url=news.html][color=#66ff66][u]N[/u][/color][/url]")

	# 5. hr: default e con width
	_eq("hr_default", HtmlBB.compile("<hr>"), "[hr color=#808080 height=2 width=100%]")
	_eq("hr_width", HtmlBB.compile("<hr width=\"50%\" color=\"#aa0000\" size=\"4\">"),
		"[hr color=#aa0000 height=4 width=50% align=center]")

	# 6. immagine mancante -> segnaposto
	_eq("img_rotta", HtmlBB.compile("<img src=\"boh.png\" width=\"64\">"),
		"[img width=64]res://web/img/_rotta_.imgtex[/img]")

	# 7. tabella con righe di lunghezza diversa: cella di riempimento
	var t := HtmlBB.compile("<table border=\"1\"><tr><td>A</td><td>B</td></tr><tr><td>C</td></tr></table>")
	_has("tab_ncols", t, "[table=2]")
	_count("tab_celle", t, "[cell", 4)
	_has("tab_bordo", t, "border=#808080")
	_has("tab_filler", t, "[cell padding=8,4,8,4 border=#808080][/cell]")

	# 8. tabella annidata: la interna viene ricompilata dentro la cella
	var nest := HtmlBB.compile("<table><tr><td><table><tr><td>X</td></tr></table></td></tr></table>")
	_count("tab_annidata", nest, "[table=1]", 2)
	_has("tab_annidata_x", nest, "X")

	# 9. th = grassetto centrato
	_has("th", HtmlBB.compile("<table><tr><th>T</th></tr></table>"), "[cell padding=8,4,8,4][center][b]T[/b][/center][/cell]")

	# 10. bgcolor: riga -> cella senza colore proprio; normalizzazione senza '#'
	var bg := HtmlBB.compile("<table><tr bgcolor=\"112233\"><td>A</td></tr></table>")
	_has("bg_riga", bg, "bg=#112233")

	# 11. blockquote -> indent
	_has("blockquote", HtmlBB.compile("testo<blockquote>citazione</blockquote>"), "[indent]citazione[/indent]")

	# 12. ol numerata
	var ol := HtmlBB.compile("<ol><li>uno</li><li>due</li></ol>")
	_has("ol_1", ol, "1. uno")
	_has("ol_2", ol, "2. due")

	# 13. p align=center
	_has("p_center", HtmlBB.compile("a<p align=\"center\">b</p>"), "[center]b[/center]")

	# 14. moduli (dal 24/10/2026 funzionano: qui si controlla il disegno e la descrizione
	# che il browser usa; il funzionamento e' in web_moduli_test)
	var cm := {}
	var fm := HtmlBB.compile("<form action=\"/cgi-bin/cerca.pl\" method=\"get\">Cerca: <input type=\"text\" name=\"q\" size=\"20\" value=\"floppy\"> <input type=\"submit\" value=\"Vai\"></form>", cm)
	_has("input_submit", fm, "[url=__invia:0][img]" + HtmlBB.tex_pulsante("Vai", false) + "[/img][/url]")
	# il pulsante e' un'immagine di Windows 95 con la scritta, e c'e' anche quella premuta
	_has("pulsante_premuto_registrato", str(load(HtmlBB.tex_pulsante("Vai", true)) != null), "true")
	_has("input_text", fm, "floppy[img width=")
	# il pulsante-menu d'epoca e' un link alla pagina dell'onclick
	_has("pulsante_menu", HtmlBB.compile("<form><input type=\"button\" value=\"Home\" onclick=\"location.href='index.html'\"></form>", {}),
			"[url=__vai:index.html][img]")
	# tutto il riquadro di un campo vuoto risponde al clic: la barretta e' alta una riga
	# un campo ha la sua misura: il testo troppo lungo non lo allarga, scorre dentro
	_no("campo_misura_fissa", HtmlBB.compile("<input type=\"text\" size=\"10\" value=\"%s\">" % "x".repeat(60), {}), "x".repeat(60))
	_has("campo_font_suo", HtmlBB.compile("<font face=\"Times\" size=\"1\"><b><input type=\"text\" size=\"10\"></b></font>", {}), "[font_size=14]")
	_has("campo_vuoto_cliccabile", HtmlBB.compile("<input type=\"text\" name=\"v\" size=\"10\">", {}), "height=19]res://web/img/spacer.png[/img]\n[img width=")
	var moduli: Array = cm.get("moduli", [])
	if moduli.size() == 1 and str(moduli[0]["action"]) == "/cgi-bin/cerca.pl" and str(moduli[0]["campi"][0]["nome"]) == "q":
		print("PASS  moduli_ctx")
	else:
		print("FAIL  moduli_ctx: %s" % [moduli])
		_fails.append("moduli_ctx")
	# il valore scritto dal giocatore vince su quello della pagina, e il campo attivo ha il cursore
	_has("input_valore", HtmlBB.compile("<input type=\"text\" name=\"q\" value=\"a\">", {"valori": {"m0_0": "ciao"}, "campo_attivo": "m0_0"}), "ciao[blink]|[/blink]")
	_has("input_password", HtmlBB.compile("<input type=\"password\" name=\"p\">", {"valori": {"m0_0": "segreto"}}), "*******")
	_has("checkbox", HtmlBB.compile("<input type=\"checkbox\" name=\"c\" checked>"), "[url=__spunta:m0_0][img width=16 height=16]res://web/img/_casella_on.tex[/img][/url]")
	_has("radio", HtmlBB.compile("<input type=\"radio\" name=\"r\" value=\"a\">"), "_pallino_off.tex")
	_has("select", HtmlBB.compile("<select name=\"s\"><option value=\"1\">Uno<option value=\"2\" selected>Due</select>"), "spacer.png[/img]Due[img")
	_has("textarea", HtmlBB.compile("<textarea name=\"t\" rows=\"3\" cols=\"30\">riga</textarea>"), "spacer.png[/img]riga[img width=")
	_has("textarea_tre_righe", str(HtmlBB.compile("<textarea name=\"t\" rows=\"3\" cols=\"30\">riga</textarea>").count("height=19]")), "6")
	_has("button", HtmlBB.compile("<form><button type=\"submit\"><b>Entra</b></button></form>"), "[url=__invia:0][img]" + HtmlBB.tex_pulsante("Entra", false))
	_has("reset", HtmlBB.compile("<form><input type=\"reset\" value=\"Pulisci\"></form>"), "[url=__azzera:0]")
	_eq("hidden", HtmlBB.compile("<input type=\"hidden\" name=\"h\" value=\"x\">"), "")

	# 14b. testo d'epoca: <pre> tiene spazi e a capo, gli altri tag i loro stili
	var pr := HtmlBB.compile("<pre>\n a  b\n c</pre>")
	_has("pre_spazi", pr, "[code]" + char(0xA0) + "a" + char(0xA0) + char(0xA0) + "b[/code]\n[code]" + char(0xA0) + "c")
	_has("tt", HtmlBB.compile("<tt>x</tt>"), "[code]x[/code]")
	_has("strike", HtmlBB.compile("<strike>x</strike>"), "[s]x[/s]")
	_has("small", HtmlBB.compile("<small>x</small>"), "[font_size=12]x")
	_has("address", HtmlBB.compile("<address>x</address>"), "[i]x[/i]")

	# 14c. i link alle pagine gia' viste prendono il colore vlink
	var vis := HtmlBB.compile("<a href=\"a.html\">A</a> <a href=\"b.html\">B</a>", {"link_color": "#0000ff",
			"vlink_color": "#800080", "visitato": func(h: String) -> bool: return h == "a.html"})
	_has("vlink_visto", vis, "[url=a.html][color=#800080]")
	_has("vlink_non_visto", vis, "[url=b.html][color=#0000ff]")

	# 15. max una riga vuota consecutiva
	var sp := HtmlBB.compile("a<p><p><p>b")
	_no("newline_collapse", sp, "\n\n\n")

	# 16. lo scanner delle ancore sulle pagine vere
	_prova_ancore()

	# 17-24: gli strumenti per la varieta' dei siti (2026-10-23)
	_prova_varieta()

	if _fails.is_empty():
		print("RISULTATO: PASS (tutti i test superati)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	quit(0 if _fails.is_empty() else 1)

func _eq(name: String, got: String, want: String) -> void:
	if got == want:
		print("PASS  " + name)
	else:
		print("FAIL  %s\n  atteso:  %s\n  ottenuto: %s" % [name, want.c_escape(), got.c_escape()])
		_fails.append(name)

func _has(name: String, got: String, frag: String) -> void:
	if got.find(frag) >= 0:
		print("PASS  " + name)
	else:
		print("FAIL  %s\n  manca:   %s\n  ottenuto: %s" % [name, frag.c_escape(), got.c_escape()])
		_fails.append(name)

func _no(name: String, got: String, frag: String) -> void:
	if got.find(frag) < 0:
		print("PASS  " + name)
	else:
		print("FAIL  %s — presente frammento vietato %s in: %s" % [name, frag.c_escape(), got.c_escape()])
		_fails.append(name)

func _count(name: String, got: String, frag: String, want: int) -> void:
	var cnt := got.count(frag)
	if cnt == want:
		print("PASS  " + name)
	else:
		print("FAIL  %s — %s presente %d volte (attese %d) in: %s" % [name, frag, cnt, want, got.c_escape()])
		_fails.append(name)


# ============================================================
# GIF, famiglie di caratteri, colonne, marquee/blink, musica
# ============================================================

func _prova_varieta() -> void:
	# 17. GIF animata: decodificata e registrata su un percorso virtuale che [img]
	# carica; il file c'e' (lo genera tools/web/media.py)
	var g := HtmlBB.compile("<img src=\"busta.gif\">")
	_eq("gif_percorso", g, "[img]res://web/img/busta.gif.tex[/img]")
	var tex := load("res://web/img/busta.gif.tex")
	if tex is AnimatedTexture and (tex as AnimatedTexture).frames > 1:
		print("PASS  gif_animata")
	else:
		print("FAIL  gif_animata: %s" % [tex])
		_fails.append("gif_animata")
	_has("gif_mancante", HtmlBB.compile("<img src=\"non_ce.gif\">"), "_rotta_.imgtex")

	# 18. famiglie: Times -> Tinos, Comic -> Comic Neue, Arial = il sans del tema
	_has("face_serif", HtmlBB.compile("<font face=\"Times New Roman\">a</font>"), "[font=" + Win95.percorso_font_pagina("serif") + "]a[/font]")
	_has("face_comic", HtmlBB.compile("<font face=\"Comic Sans MS\">a</font>"), "ComicNeue-Regular.ttf")
	_eq("face_arial", HtmlBB.compile("<font face=\"Verdana, Arial\">a</font>"), "a")
	_has("face_mono", HtmlBB.compile("<font face=\"Courier New\">a</font>"), "[code]a[/code]")
	# grassetto DENTRO un'altra famiglia: il file grassetto, non [b] (che e' Arimo)
	var bs := HtmlBB.compile("<font face=\"Times\"><b>a</b></font>")
	_has("serif_b", bs, "Tinos-Bold.ttf")
	_no("serif_b_no_tema", bs, "[b]")
	_has("b_serif", HtmlBB.compile("<b><font face=\"Times\">a</font></b>"), "Tinos-Bold.ttf")
	_has("serif_i", HtmlBB.compile("<font face=\"Georgia\"><i>a</i></font>"), "Tinos-Italic.ttf")
	_has("serif_h1", HtmlBB.compile("<font face=\"Times\"><h1>T</h1></font>"), "Tinos-Bold.ttf")
	_has("sans_in_serif", HtmlBB.compile("<font face=\"Times\"><font face=\"Arial\">a</font></font>"), "Arimo-Regular.ttf")

	# 19. colonne con la loro larghezza: la colonna laterale da 160 px, l'altra il resto
	var lat := HtmlBB.compile("<table width=\"600\" cellpadding=\"4\"><tr><td width=\"160\">menu</td><td>testo</td></tr></table>")
	_has("td_width_160", lat, "[img width=148 height=1]")
	_has("td_width_resto", lat, "[img width=428 height=1]")
	var pct := HtmlBB.compile("<table width=\"100%\" cellpadding=\"0\"><tr><td width=\"25%\">a</td><td>b</td></tr></table>", {"page_width": 800.0})
	_has("td_width_pct", pct, "[img width=196 height=1]")
	_has("td_width_pct_resto", pct, "[img width=596 height=1]")
	# una tabella al 100% DENTRO una cella e' larga quanto la cella, non quanto la pagina
	var ann := HtmlBB.compile("<table width=\"600\" cellpadding=\"4\"><tr><td width=\"160\">menu</td><td><table width=\"100%\" cellpadding=\"0\"><tr><td>x</td></tr></table></td></tr></table>", {"page_width": 900.0})
	_has("annidata_della_cella", ann, "[img width=424 height=1]")
	_no("annidata_non_della_pagina", ann, "[img width=896 height=1]")
	# una tabella piu' stretta della pagina sta fra colonne vuote che si prendono il resto,
	# cosi' un paragrafo lungo non la allarga fino al bordo (centrata: due colonne, una per lato)
	var sch := HtmlBB.compile("<table width=\"500\" align=\"center\"><tr><td>" + "parola ".repeat(80) + "</td></tr></table>", {"page_width": 904.0})
	_has("stretta_centrata", sch, "[table=3][cell padding=0,0,0,0][img width=200 height=1]")
	_no("stretta_niente_center", sch, "[center]")
	var sin := HtmlBB.compile("<table width=\"50%\"><tr><td>x</td></tr></table>", {"page_width": 804.0})
	_has("stretta_sinistra", sin, "[table=2][cell padding=0,0,0,0][table=1]")
	_has("stretta_sinistra_resto", sin, "[img width=398 height=1]")
	# un <hr> dentro una cella e' largo quanto la CELLA (in Godot la % e' della pagina intera)
	_has("hr_in_cella", HtmlBB.compile("<table width=\"400\" cellpadding=\"0\"><tr><td><hr></td></tr></table>", {"page_width": 900.0}), "height=2 width=396]")
	_no("piena_non_stretta",HtmlBB.compile("<table width=\"100%\"><tr><td>x</td></tr></table>", {"page_width": 800.0}), "[table=2]")
	_has("bordercolor",HtmlBB.compile("<table border=\"1\" bordercolor=\"#FF0000\"><tr><td>a</td></tr></table>"), "border=#FF0000")

	# 20. marquee: riga a se', con larghezza, lunghezza, velocita'; in una cella e' ferma
	var mq := HtmlBB.compile("<p>prima</p><marquee scrollamount=\"3\">Benvenuti!</marquee><p>dopo</p>", {"page_width": 700.0})
	_has("marquee", mq, "[left][marquee w=700 len=")
	_has("marquee_testo", mq, "]Benvenuti![/marquee][/left]")
	_has("marquee_v", mq, " v=35 dir=l mode=s n=")
	_has("marquee_alt", HtmlBB.compile("<marquee behavior=\"alternate\" direction=\"right\">x</marquee>"), "dir=r mode=a")
	var mc := HtmlBB.compile("<table><tr><td><marquee>fermo</marquee></td></tr></table>")
	_has("marquee_cella", mc, "fermo")
	_no("marquee_cella_ferma", mc, "[marquee")
	# piu' lungo della pagina: andrebbe a capo, quindi resta fermo
	var ml := HtmlBB.compile("<marquee>" + "parola ".repeat(60) + "</marquee>", {"page_width": 300.0})
	_has("marquee_lungo", ml, "parola parola")
	_no("marquee_lungo_fermo", ml, "[marquee")

	# 21. blink: un tag in linea che sopravvive al <br>
	_eq("blink", HtmlBB.compile("<blink>a<br>b</blink>"), "[blink]a[/blink]\n[blink]b[/blink]")

	# 22. bgsound / embed: niente testo, la musica nel contesto; il lettore visibile
	var ctx := {}
	var bgs := HtmlBB.compile("<bgsound src=\"jack.mid\" loop=\"infinite\">ciao", ctx)
	_eq("bgsound_muto", bgs, "ciao")
	var au: Dictionary = ctx.get("audio", {})
	if str(au.get("path", "")) == "res://web/audio/jack.mid" and bool(au.get("loop")) and bool(au.get("auto")):
		print("PASS  bgsound_ctx")
	else:
		print("FAIL  bgsound_ctx: %s" % [au])
		_fails.append("bgsound_ctx")
	var ctx2 := {}
	var emb := HtmlBB.compile("<embed src=\"inno.mid\" autostart=\"false\" width=\"145\" height=\"40\">", ctx2)
	_has("embed_play", emb, "[url=" + HtmlBB.META_PLAY + "]")
	_has("embed_stop", emb, "[url=" + HtmlBB.META_STOP + "]")
	if not bool((ctx2.get("audio", {}) as Dictionary).get("auto", true)):
		print("PASS  embed_non_parte")
	else:
		print("FAIL  embed_non_parte: %s" % [ctx2])
		_fails.append("embed_non_parte")
	_eq("embed_nascosto", HtmlBB.compile("<embed src=\"valzer.mid\" hidden=\"true\" autostart=\"true\">x"), "x")

	# 23. la chiave non finisce mai in testo che scorre o lampeggia
	var mob := "<html><body><p>Un paragrafo qualunque abbastanza lungo da ospitare la chiave.</p>" \
			+ "<marquee>Questo testo scorre da destra a sinistra senza fermarsi mai</marquee>" \
			+ "<p><blink>Questo testo lampeggia senza sosta e non si riesce a leggerlo</blink></p></body></html>"
	var dentro := 0
	for a in WA.ancore(mob, true):
		var pos: int = a["pos"]
		var m0 := mob.find("<marquee>")
		var m1 := mob.find("</marquee>")
		var b0 := mob.find("<blink>")
		var b1 := mob.find("</blink>")
		if (pos > m0 and pos <= m1) or (pos > b0 and pos <= b1):
			dentro += 1
			print("  ancora %s in testo mobile a %d" % [a["tipo"], pos])
	if dentro == 0:
		print("PASS  ancore_fuori_dal_mobile")
	else:
		print("FAIL  ancore_fuori_dal_mobile")
		_fails.append("ancore_fuori_dal_mobile")

	# 24. sfondo a mosaico: la texture di un src (anche GIF)
	if HtmlBB.texture("stelle.gif") is AnimatedTexture and HtmlBB.texture("quadretti.gif") is ImageTexture:
		print("PASS  sfondo_texture")
	else:
		print("FAIL  sfondo_texture")
		_fails.append("sfondo_texture")

# ============================================================
# Scanner delle ancore (WebAnchor) sulle pagine d'autore
# ============================================================

func _prova_ancore() -> void:
	# due pin sul COMPILATORE, che documentano le trappole che lo scanner evita
	_no("tabella_scarta_fuori_cella",
			HtmlBB.compile("<table><tr><td>A</td></tr><p>PERSO</p><tr><td>B</td></tr></table>"),
			"PERSO")
	_eq("commento_a_meta_testo",
			HtmlBB.compile(HtmlBB.strip_comments("uno <!-- x --> due")),
			HtmlBB.compile("uno due"))
	# un testo ostile non deve poter troncare il commento
	var ostile: Dictionary = WA.inserisci("<html><body><p>abc</p></body></html>",
			{"pos": 26, "tipo": WA.COMM_BLOCCO, "nota": ""}, "a --> b <c>", CHIAVE)
	_count("commento_sicuro", str(ostile["inserito"]), "-->", 1)

	print("   censimento delle ancore (per pagina):")
	for nome in _pagine():
		var raw := _leggi(PAGINE + nome + ".html")
		if raw == "":
			_fails.append("pagina_illeggibile_" + nome)
			continue
		var vis: Array = WA.ancore(raw, true)
		var src: Array = WA.ancore(raw, false)
		print("   %-18s visibili %2d %-42s sorgente %2d %s"
				% [nome, vis.size(), _conta(vis), src.size(), _conta(src)])
		# ogni pagina deve offrire scelta, in entrambe le modalita'
		_ge("ancore_visibili_" + nome, vis.size(), 3)
		_ge("ancore_sorgente_" + nome, src.size(), 6)
		# lo scanner presuppone che le pagine d'autore non abbiano commenti
		_no("senza_commenti_" + nome, raw, "<!--")
		# mai dentro <title>: finirebbe nella barra del titolo della finestra
		var t0 := raw.findn("<title>")
		var t1 := raw.findn("</title>")
		for a in vis + src:
			var p := int(a["pos"])
			if t0 >= 0 and t1 > t0 and p > t0 + 7 and p <= t1:
				_fails.append("ancora_nel_titolo_" + nome)
				print("FAIL  ancora_nel_titolo_%s (%s a %d)" % [nome, str(a["tipo"]), p])
				break
		# nessuna frase visibile su un fondo scuro: il fondo si ricalcola qui in
		# modo indipendente (cella -> riga -> tabella -> pagina), non chiedendolo
		# a WebAnchor, altrimenti si proverebbe la regola con se stessa
		for a in vis:
			if str(a["tipo"]) != WA.CODA_CELLA:
				continue
			var bg := _fondo_di(raw, int(a["pos"])).to_lower()
			# su una pagina SCURA (testo chiaro: la pagina del ragazzo) una cella nera si legge
			if FONDI_SCURI.has(bg) and not _testo_chiaro(raw):
				_fails.append("cella_scura_" + nome)
				print("FAIL  cella_scura_%s -- %s su fondo %s" % [nome, str(a["nota"]), bg])
				break
		# l'invariante forte, su OGNI ancora di OGNI pagina
		for a in vis:
			_invariante(nome, raw, a, true)
		for a in src:
			_invariante(nome, raw, a, false)

# Il testo della pagina (<body text>) e' chiaro? Allora il fondo scuro e' voluto e si legge.
func _testo_chiaro(raw: String) -> bool:
	var b := raw.findn("<body")
	if b < 0:
		return false
	var c := HtmlBB._attr(raw.substr(b, raw.find(">", b) - b), "text")
	return c != "" and Color.html_is_valid(HtmlBB._col(c)) and Color.html(HtmlBB._col(c)).get_luminance() > 0.5

# Iniettata la chiave in questa ancora, la pagina deve rendere IDENTICA a prima a
# meno di quello che si e' aggiunto. Si confronta il BBCode COMPILATO (i tag non
# sono spazi: cosi' si vede anche una [cell] perduta o un [table=2] diventato
# [table=3]) e si guarda la DIFFERENZA: quello che sparisce deve essere niente,
# quello che appare deve contenere il testo atteso.
func _invariante(pagina: String, raw: String, anc: Dictionary, visibile: bool) -> void:
	var tipo := str(anc["tipo"])
	var r: Dictionary = WA.inserisci(raw, anc, FRASE, CHIAVE)
	var ctx := {"link_color": "#0000ee", "page_width": 900.0}
	var pulito := _senza_vuoti(_norm(HtmlBB.compile(HtmlBB.strip_comments(HtmlBB.body_inner(raw)), ctx)))
	var con := _senza_vuoti(_norm(HtmlBB.compile(HtmlBB.strip_comments(HtmlBB.body_inner(str(r["html"]))), ctx)))
	var d := _differenza(pulito, con)
	var perso := str(d[0])
	var aggiunto := str(d[1])
	var etichetta := "%s/%s@%d" % [pagina, tipo, int(anc["pos"])]
	if perso.strip_edges() != "":
		_fails.append("perso_" + etichetta)
		print("FAIL  perso_%s -- la pagina perde: %s" % [etichetta, perso.substr(0, 60)])
		return
	if visibile:
		# la frase c'e' a schermo CON la chiave e non senza. Non si cerca nel solo "aggiunto"
		# del confronto prefisso/suffisso: se la frase comincia con la stessa lettera del testo
		# che la segue ("Promemoria..." prima di "Page 1 of 47") il prefisso comune se la mangia
		var reso := str(r["reso"])
		if reso == "" or con.find(reso) < 0 or pulito.find(reso) >= 0:
			_fails.append("reso_" + etichetta)
			print("FAIL  reso_%s -- a schermo non arriva il testo (aggiunto: '%s')"
					% [etichetta, aggiunto.substr(0, 60)])
	else:
		if str(r["html"]).find(CHIAVE) < 0:
			_fails.append("sorgente_" + etichetta)
			print("FAIL  sorgente_%s -- la chiave non e' nel sorgente" % etichetta)
		elif aggiunto.strip_edges() != "":
			_fails.append("visibile_" + etichetta)
			print("FAIL  visibile_%s -- a schermo compare '%s'"
					% [etichetta, aggiunto.substr(0, 60)])

# Prefisso e suffisso in comune via, resta [cio' che c'e' solo in a, solo in b].
func _differenza(a: String, b: String) -> Array:
	var i := 0
	while i < a.length() and i < b.length() and a[i] == b[i]:
		i += 1
	var j := 0
	while j < a.length() - i and j < b.length() - i 			and a[a.length() - 1 - j] == b[b.length() - 1 - j]:
		j += 1
	return [a.substr(i, a.length() - i - j), b.substr(i, b.length() - i - j)]

# Quante ancore per tipo, in breve: e' il censimento che serve a tarare le soglie.
func _conta(lista: Array) -> String:
	var per_tipo: Dictionary = {}
	for a in lista:
		var t := str(a["tipo"])
		per_tipo[t] = int(per_tipo.get(t, 0)) + 1
	var parti: Array = []
	for t in per_tipo:
		parti.append("%s:%d" % [t, int(per_tipo[t])])
	parti.sort()
	return "[" + ", ".join(PackedStringArray(parti)) + "]"

# Fondo efficace nel punto dato: il primo bgcolor che si incontra risalendo
# cella -> riga -> tabella -> pagina.
func _fondo_di(raw: String, pos: int) -> String:
	var pre := raw.substr(0, pos)
	for nome_tag in ["<td", "<tr", "<table", "<body"]:
		var q := pre.rfindn(nome_tag)
		if q < 0:
			continue
		var gt := raw.find(">", q)
		if gt < 0:
			continue
		var bg := HtmlBB._attr(raw.substr(q, gt - q), "bgcolor")
		if bg != "":
			return bg
	return ""

# Le pagine d'autore stanno in web/pages/<lingua>/ e, dal 19/10/2026, nelle cartelle dei
# siti, web/pages/<lingua>/<sito>/: il censimento le passa in rassegna TUTTE, in ogni lingua. Una pagina tradotta che non offre piu' nascondigli
# (o che ha perso una tabella per strada) e' un difetto che si vedrebbe solo giocando
# in quella lingua, cioe' mai da qui.
func _pagine() -> Array:
	var out: Array = []
	var radice := DirAccess.open(PAGINE)
	if radice == null:
		return out
	for d in radice.get_directories():
		var dir := DirAccess.open(PAGINE + d)
		if dir == null:
			continue
		for f in dir.get_files():
			if f.ends_with(".html"):
				out.append(d + "/" + f.substr(0, f.length() - 5))
		for sito in dir.get_directories():
			var sd := DirAccess.open(PAGINE + d + "/" + sito)
			if sd == null:
				continue
			for f in sd.get_files():
				if f.ends_with(".html"):
					out.append(d + "/" + sito + "/" + f.substr(0, f.length() - 5))
	out.sort()
	return out

func _leggi(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""

# Spazi collassati: le righe vuote in piu' introdotte da un <p>/<li> nuovo non
# sono un cambio di struttura, i tag BBCode invece si'.
# Via le coppie di tag che non avvolgono niente ("[color=#CCC][font_size=16][/font_size][/color]"):
# non disegnano nulla, e i margini dei blocchi (HtmlBB._spazio) ne lasciano di diverse a
# seconda di cosa c'e' prima. Contano i pezzi che si VEDONO.
func _senza_vuoti(s: String) -> String:
	# solo i tag di formato: una [cell][/cell] vuota tiene la griglia e deve contare
	var re := RegEx.create_from_string("\\[(color|font_size|font|bgcolor|b|i|u|s|center|left|right|code|blink)(=[^\\]]*)?( [^\\]]*)?\\]\\s*\\[/\\1\\]")
	var prima := ""
	while prima != s:
		prima = s
		s = re.sub(s, "", true)
	return s

func _norm(s: String) -> String:
	var re := RegEx.create_from_string(r"\s+")
	return re.sub(s, " ", true).strip_edges()

func _ge(name: String, got: int, minimo: int) -> void:
	if got >= minimo:
		print("PASS  %s (%d)" % [name, got])
	else:
		print("FAIL  %s -- %d, attese almeno %d" % [name, got, minimo])
		_fails.append(name)
