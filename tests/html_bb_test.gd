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

	# 14. input decorativi
	_has("input_submit", HtmlBB.compile("<input type=\"submit\" value=\"Invia\">"), "[lb] Invia [rb]")
	_has("input_text", HtmlBB.compile("<input type=\"text\" size=\"20\">"), "[u]          [/u]")

	# 15. max una riga vuota consecutiva
	var sp := HtmlBB.compile("a<p><p><p>b")
	_no("newline_collapse", sp, "\n\n\n")

	# 16. lo scanner delle ancore sulle pagine vere
	_prova_ancore()

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
		print("   %-14s visibili %2d %-42s sorgente %2d %s"
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
			if FONDI_SCURI.has(bg):
				_fails.append("cella_scura_" + nome)
				print("FAIL  cella_scura_%s -- %s su fondo %s" % [nome, str(a["nota"]), bg])
				break
		# l'invariante forte, su OGNI ancora di OGNI pagina
		for a in vis:
			_invariante(nome, raw, a, true)
		for a in src:
			_invariante(nome, raw, a, false)

# Iniettata la chiave in questa ancora, la pagina deve rendere IDENTICA a prima a
# meno di quello che si e' aggiunto. Si confronta il BBCode COMPILATO (i tag non
# sono spazi: cosi' si vede anche una [cell] perduta o un [table=2] diventato
# [table=3]) e si guarda la DIFFERENZA: quello che sparisce deve essere niente,
# quello che appare deve contenere il testo atteso.
func _invariante(pagina: String, raw: String, anc: Dictionary, visibile: bool) -> void:
	var tipo := str(anc["tipo"])
	var r: Dictionary = WA.inserisci(raw, anc, FRASE, CHIAVE)
	var ctx := {"link_color": "#0000ee", "page_width": 900.0}
	var pulito := _norm(HtmlBB.compile(HtmlBB.strip_comments(HtmlBB.body_inner(raw)), ctx))
	var con := _norm(HtmlBB.compile(HtmlBB.strip_comments(HtmlBB.body_inner(str(r["html"]))), ctx))
	var d := _differenza(pulito, con)
	var perso := str(d[0])
	var aggiunto := str(d[1])
	var etichetta := "%s/%s@%d" % [pagina, tipo, int(anc["pos"])]
	if perso.strip_edges() != "":
		_fails.append("perso_" + etichetta)
		print("FAIL  perso_%s -- la pagina perde: %s" % [etichetta, perso.substr(0, 60)])
		return
	if visibile:
		var reso := str(r["reso"])
		if reso == "" or aggiunto.find(reso) < 0:
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

func _pagine() -> Array:
	var out: Array = []
	var d := DirAccess.open(PAGINE)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".html"):
			out.append(f.substr(0, f.length() - 5))
	out.sort()
	return out

func _leggi(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	return f.get_as_text() if f != null else ""

# Spazi collassati: le righe vuote in piu' introdotte da un <p>/<li> nuovo non
# sono un cambio di struttura, i tag BBCode invece si'.
func _norm(s: String) -> String:
	var re := RegEx.create_from_string(r"\s+")
	return re.sub(s, " ", true).strip_edges()

func _ge(name: String, got: int, minimo: int) -> void:
	if got >= minimo:
		print("PASS  %s (%d)" % [name, got])
	else:
		print("FAIL  %s -- %d, attese almeno %d" % [name, got, minimo])
		_fails.append(name)
