class_name HtmlBB
extends RefCounted

# ============================================================
# Compilatore HTML (sottoinsieme "legacy") -> BBCode per UN SOLO RichTextLabel.
# Tutta la pagina diventa una stringa BBCode: cosi' la selezione e' continua su
# tutto il documento, i link sono [url] nativi (meta_clicked) e le tabelle sono
# [table]/[cell] con sfondo/bordo/padding. Usato da BrowserApp._render_html.
#
# Sottoinsieme supportato: b/i/u, font(color/size/face), h1-h6, br, p(align),
# center, div(align), a(href), hr(width/size/color), ul/ol/li, blockquote,
# img(src/width/height, anche GIF animate), input(type/value), table/tr/td/th
# (border/bordercolor/bgcolor/cellpadding/width/align; bgcolor, align e width per
# cella), marquee, blink, bgsound/embed (la musica: vedi ctx["audio"]).
# NON supportati: CSS, colspan/rowspan.
#
# NOTE comportamento RichTextLabel (verificato in tests/table_width_probe e
# tests/selection_ghost.gd):
# - [cell expand=N] NON allarga la tabella e la larghezza e' guidata dal
#   CONTENUTO, percio' <table width="N%"> lo realizziamo col trucco d'epoca
#   della "spacer.gif": una riga finale con un'immagine trasparente larga
#   esattamente quanto serve (vedi _table). Serve ctx["page_width"] in pixel;
#   senza quello la larghezza resta quella del contenuto.
# - [center] INVECE funziona sulle tabelle: <table align="center"> e le tabelle
#   dentro <center>/<div align="center"> vengono centrate.
# - la selezione include le celle solo se ATTRAVERSA tutta la tabella;
# - [hr] e' nativo in Godot 4.6.
# - face=: "Courier New"/monospace -> [code] (slot mono del tema); Times/serif ->
#   Tinos, Comic -> Comic Neue, con [font=file]; il resto e' il sans del tema
#   (Arimo ~ Arial). Dentro un face non-sans <b>/<i> scelgono il FILE grassetto/
#   corsivo della stessa famiglia: [b] userebbe il grassetto del tema (Arimo).
# ============================================================

const IMG_DIR := "res://web/img/"

# Immagine 1x1 trasparente: allarga una tabella a una misura precisa senza
# comparire (il vecchio trucco dello "spacer.gif" del web anni '90).
const SPACER_IMG := "res://web/img/spacer.png"

# Musica delle pagine (<bgsound>/<embed>): file .mid (o .wav/.ogg) in web/audio/.
const AUDIO_DIR := "res://web/audio/"

# Il lettore d'epoca disegnato al posto di un <embed> visibile: due link "finti"
# che il browser intercetta prima di risolverli come indirizzi (BrowserApp._on_meta).
const META_PLAY := "__audio:play"
const META_STOP := "__audio:stop"

# Quanto occupa una cella oltre al suo padding: misurato con una sonda (24/10/2026), il
# RichTextLabel ci mette 4 px; con 2 una tabella al 100% a piu' colonne usciva dal bordo.
const CELLA_EXTRA := 4

# marquee: velocita' predefinita come in IE (scrollamount 6 px ogni 85 ms)
const MARQUEE_PASSO := 6.0
const MARQUEE_RITARDO := 0.085

const _ENTITIES := {
	"&copy;": "©", "&raquo;": "»", "&laquo;": "«",
	"&middot;": "·", "&hellip;": "…", "&quot;": "\"", "&mdash;": "—", "&deg;": "°",
	"&lt;": "<", "&gt;": ">", "&amp;": "&",
}
const _FONT_PX := {"1": 11, "2": 13, "3": 16, "4": 20, "5": 24, "6": 30, "7": 36}
const _H_PX := {"h1": 30, "h2": 24, "h3": 20, "h4": 18, "h5": 15, "h6": 13}

static var _ws_re: RegEx
static var _nl_re: RegEx
static var _broken_tex: ImageTexture
static var _gif: Dictionary = {}          # percorso del file -> texture (tenuta viva qui)
static var _tag_re: RegEx
static var _size_re: RegEx

# Compila il BODY (gia' senza commenti) in BBCode. ctx: "link_color" (es. "#0000ee").
static func compile(body: String, ctx: Dictionary = {}) -> String:
	# lo stato di UNA compilazione riparte da zero: ricompilando con lo stesso contesto i
	# moduli verrebbero contati due volte e gli id dei campi cambierebbero
	ctx["moduli"] = []
	for k in ["_modulo", "_implicito", "_pre", "_in_cella"]:
		ctx.erase(k)
	var out := _walk(body, ctx)
	if _nl_re == null:
		_nl_re = RegEx.new()
		_nl_re.compile("\\n[ \\t]*\\n[ \\t\\n]*")
	out = _nl_re.sub(out, "\n\n", true)   # max una riga vuota consecutiva
	return out.strip_edges()

# ---------------- scansione (blocchi + inline, stack-based) ----------------

# Un'unica passata: il testo scorre, i tag di formato vanno su uno STACK che a ogni
# <br>/<p> viene chiuso e riaperto (nessun tag attraversa un newline). I blocchi
# (table/hr) chiudono lo stack, emettono il blocco e lo riaprono.
static func _walk(html: String, ctx: Dictionary) -> String:
	var link_color := str(ctx.get("link_color", "#0000ee"))
	var out := ""
	var stack: Array = []
	var lists: Array = []      # stack di liste: {"type": "ul"/"ol", "n": int}
	var i := 0
	var n := html.length()
	while i < n:
		if html[i] != "<":
			var lt := html.find("<", i)
			if lt < 0:
				lt = n
			if int(ctx.get("_pre", 0)) > 0:
				out += _txt_pre(html.substr(i, lt - i), stack)
			else:
				out += _txt(html.substr(i, lt - i))
			i = lt
			continue
		var gt := html.find(">", i)
		if gt < 0:
			out += _txt(html.substr(i))
			break
		var tag := html.substr(i + 1, gt - i - 1)
		var nm := _tagname(tag)
		var closing := tag.strip_edges().begins_with("/")
		i = gt + 1
		if nm.begins_with("!"):
			continue
		if closing:
			match nm:
				"h1", "h2", "h3", "h4", "h5", "h6", "div", "center", "blockquote", "p", "address":
					out += _pop_tag(stack, nm) + "\n"
				"pre":
					ctx["_pre"] = maxi(0, int(ctx.get("_pre", 0)) - 1)
					out += _pop_tag(stack, nm) + "\n"
				"form":
					ctx["_modulo"] = -1
					out += _close_all(stack) + "\n" + _reopen_all(stack)
				"ul", "ol":
					if not lists.is_empty():
						lists.pop_back()
					out += "\n"
				_:
					out += _pop_tag(stack, nm)
			continue
		match nm:
			"table":
				var endt := _table_end(html, i)
				var tbb := _table(html.substr(i, endt - i), tag, ctx)
				# <table align="center">, o tabella dentro <center>/<div align="center">
				var centrata: bool = _attr(tag, "align").to_lower() == "center" or _has_center(stack)
				var stretta := _stringi(tbb, tag, centrata, ctx)
				if stretta != "":
					tbb = stretta
				elif centrata:
					tbb = "[center]" + tbb + "[/center]"
				out += _close_all(stack) + "\n" + tbb + "\n" + _reopen_all(stack)
				var close_gt := html.find(">", endt)
				i = (close_gt + 1) if close_gt >= 0 else n
			"br":
				out += _close_all(stack) + "\n" + _reopen_all(stack)
			"p":
				out += _close_all(stack) + "\n\n" + _reopen_all(stack)
				var al := _attr(tag, "align").to_lower()
				if al == "center":
					out += _push(stack, "p", "[center]", "[/center]")
				elif al == "right":
					out += _push(stack, "p", "[right]", "[/right]")
			"h1", "h2", "h3", "h4", "h5", "h6":
				var hf := _file_di(stack, true, false)
				if hf != "":
					out += "\n" + _push(stack, nm, "[font_size=%d][font=%s]" % [int(_H_PX[nm]), hf], "[/font][/font_size]", {"b": true})
				else:
					out += "\n" + _push(stack, nm, "[font_size=%d][b]" % int(_H_PX[nm]), "[/b][/font_size]", {"b": true})
			"ul", "ol":
				lists.push_back({"type": nm, "n": 0})
				out += "\n"
			"li":
				var pref := "• "
				var depth := maxi(1, lists.size())
				if not lists.is_empty() and str(lists.back()["type"]) == "ol":
					lists.back()["n"] = int(lists.back()["n"]) + 1
					pref = "%d. " % int(lists.back()["n"])
				out += _close_all(stack) + "\n" + "  ".repeat(depth) + pref + _reopen_all(stack)
			"hr":
				out += _close_all(stack) + "\n" + _hr(tag, ctx) +"\n" + _reopen_all(stack)
			"img":
				out += _img(tag)
			"marquee":
				var fine_m := html.findn("</marquee", i)
				if fine_m < 0:
					fine_m = n
				out += _marquee(tag, html.substr(i, fine_m - i), stack, ctx)
				var gm := html.find(">", fine_m)
				i = (gm + 1) if gm >= 0 else n
			"blink":
				out += _push(stack, "blink", "[blink]", "[/blink]")
			# ---- testo d'epoca ----
			"pre":
				out += _close_all(stack) + "\n" + _reopen_all(stack) + _push(stack, "pre", "[code]", "[/code]")
				ctx["_pre"] = int(ctx.get("_pre", 0)) + 1
				# come in HTML, l'a capo subito dopo <pre> non conta
				if i < n and html[i] == "\r":
					i += 1
				if i < n and html[i] == "\n":
					i += 1
			"tt", "kbd", "samp":
				out += _push(stack, nm, "[code]", "[/code]")
			"s", "strike", "del":
				out += _push(stack, nm, "[s]", "[/s]")
			"sup", "sub":
				out += _push(stack, nm, "[font_size=11]", "[/font_size]")
			"big":
				out += _push(stack, nm, "[font_size=20]", "[/font_size]")
			"small":
				out += _push(stack, nm, "[font_size=12]", "[/font_size]")
			"address":
				out += _close_all(stack) + "\n" + _reopen_all(stack) + _push(stack, "address", "[i]", "[/i]", {"i": true})
			"dl", "dt":
				out += _close_all(stack) + "\n" + _reopen_all(stack)
			"dd":
				out += _close_all(stack) + "\n" + _reopen_all(stack) + "\u00a0".repeat(6)
			# ---- moduli (funzionano: vedi BrowserApp, "moduli") ----
			"form":
				out += _close_all(stack) + "\n" + _reopen_all(stack)
				ctx["_modulo"] = _nuovo_modulo(ctx, _attr(tag, "action"), _attr(tag, "method"))
			"button":
				var fine_b := html.findn("</button", i)
				if fine_b < 0:
					fine_b = n
				var etichetta := _solo_testo(_walk(html.substr(i, fine_b - i), {})).strip_edges()
				out += _pulsante(tag, etichetta, ctx)
				var gb := html.find(">", fine_b)
				i = (gb + 1) if gb >= 0 else n
			"select":
				var fine_s := html.findn("</select", i)
				if fine_s < 0:
					fine_s = n
				out += _tendina(tag, html.substr(i, fine_s - i), ctx)
				var gs := html.find(">", fine_s)
				i = (gs + 1) if gs >= 0 else n
			"textarea":
				var fine_t := html.findn("</textarea", i)
				if fine_t < 0:
					fine_t = n
				out += _close_all(stack) + "\n" + _area_testo(tag, html.substr(i, fine_t - i), ctx) + "\n" + _reopen_all(stack)
				var gt2 := html.find(">", fine_t)
				i = (gt2 + 1) if gt2 >= 0 else n
			"bgsound", "embed":
				out += _audio(nm, tag, stack, ctx)
			"input":
				out += _input(tag, ctx)
			"b", "i":
				var bf := _file_di(stack, nm == "b", nm == "i")
				if bf != "":
					out += _push(stack, nm, "[font=" + bf + "]", "[/font]", {nm: true})
				else:
					out += _push(stack, nm, "[%s]" % nm, "[/%s]" % nm, {nm: true})
			"u":
				out += _push(stack, nm, "[u]", "[/u]")
			"center":
				out += _push(stack, "center", "[center]", "[/center]")
			"div":
				out += _close_all(stack) + "\n" + _reopen_all(stack)
				if _attr(tag, "align").to_lower() == "center":
					out += _push(stack, "div", "[center]", "[/center]")
				else:
					out += _push(stack, "div", "", "")
			"blockquote":
				out += _close_all(stack) + "\n" + _reopen_all(stack) + _push(stack, "blockquote", "[indent]", "[/indent]")
			"a":
				# i link alle pagine gia' viste hanno il colore vlink della pagina
				var href := _attr(tag, "href")
				var colore := link_color
				var visto: Callable = ctx.get("visitato", Callable())
				if visto.is_valid() and bool(visto.call(href)):
					colore = str(ctx.get("vlink_color", link_color))
				out += _push(stack, "a", "[url=" + href + "][color=" + colore + "][u]", "[/u][/color][/url]")
			"font":
				var open := ""
				var close := ""
				var extra := {}
				var fam := famiglia(_attr(tag, "face"))
				if fam == "mono":
					open += "[code]"                     # slot mono del tema
					close = "[/code]" + close
				elif fam != "":
					# un'altra famiglia: il file giusto per grassetto/corsivo correnti. Il
					# sans dentro il sans del tema non ha bisogno di niente.
					var st := _stato(stack)
					if fam != "sans" or str(st["fam"]) != "sans":
						open += "[font=" + _font_file(fam, bool(st["b"]), bool(st["i"])) + "]"
						close = "[/font]" + close
					extra["fam"] = fam
				var col := _attr(tag, "color")
				if col != "":
					open += "[color=" + _col(col) + "]"
					close = "[/color]" + close
				var sz := _attr(tag, "size")
				if sz != "":
					open += "[font_size=%d]" % int(_FONT_PX.get(sz.strip_edges(), 16))
					close = "[/font_size]" + close
				out += _push(stack, "font", open, close, extra)
			_:
				pass   # tag sconosciuto: il contenuto scorre comunque
	out += _close_all(stack)
	return out

# True se nello stack c'e' un contesto centrato (<center> o <div align="center">):
# le tabelle vengono emesse FUORI dallo stack, quindi la centratura va riapplicata.
static func _has_center(stack: Array) -> bool:
	for e in stack:
		if str(e.get("open", "")).find("[center]") >= 0:
			return true
	return false

# ---------------- blocchi ----------------

# Dentro una cella la percentuale di [hr] e' della PAGINA, non della cella: una riga al
# 100% in una colonna laterale la allargava fino a spingere la tabella fuori dal bordo.
# In una cella di larghezza nota la percentuale diventa quindi pixel della cella.
static func _hr(tag: String, ctx: Dictionary = {}) -> String:
	var col := _attr(tag, "color")
	var h := _attr(tag, "size")     # <hr size=N> legacy = spessore
	var w := _attr(tag, "width").strip_edges()
	var bb := "[hr color=" + (_col(col) if col != "" else "#808080")
	bb += " height=%d" % (maxi(1, int(h)) if h.strip_edges() != "" else 2)
	var cella := float(ctx.get("page_width", 0.0)) if int(ctx.get("_in_cella", 0)) > 0 else 0.0
	if cella > 0.0 and (w == "" or w.ends_with("%")):
		var pct := 100.0 if w == "" else clampf(w.trim_suffix("%").to_float(), 1.0, 100.0)
		bb += " width=%d" % int(cella * pct / 100.0)
		if w != "":
			bb += " align=center"
	elif w != "":
		bb += " width=" + w + " align=center"
	else:
		bb += " width=100%"
	return bb + "]"

# <marquee>: la riga che scorre (effetto [marquee] di web_effetti.gd). Dentro una
# cella di tabella diventa testo fermo: la cella non sa quanto e' larga e il testo
# scorrerebbe sopra le vicine -- ed e' anche cio' che faceva Netscape, che il
# marquee non lo conosceva e lo mostrava immobile.
static func _marquee(tag: String, interno: String, stack: Array, ctx: Dictionary) -> String:
	var testo := _walk(interno, ctx).replace("\n", " ").strip_edges()
	if testo == "":
		return ""
	if int(ctx.get("_in_cella", 0)) > 0:
		return testo
	ctx["uses_width"] = true
	var largo := float(ctx.get("page_width", 0.0))
	if largo <= 0.0:
		largo = 600.0
	var w_attr := _attr(tag, "width").strip_edges()
	if w_attr != "" and not w_attr.ends_with("%"):
		largo = minf(largo, w_attr.to_float())
	# quanto e' lungo il testo: misurato col font della pagina, al corpo in vigore
	var corpo := 16
	if _size_re == null:
		_size_re = RegEx.create_from_string("font_size=(\\d+)")
	for m in _size_re.search_all(_reopen_all(stack) + testo):
		corpo = int(m.get_string(1))
	var lungo := Win95.font("sans_b").get_string_size(_solo_testo(testo),
			HORIZONTAL_ALIGNMENT_LEFT, -1, corpo).x + 8.0
	# piu' lungo della pagina: il RichTextLabel lo andrebbe a capo e le righe
	# scorrerebbero una sotto l'altra. Resta fermo, come in Netscape (la regola per
	# chi scrive: un marquee sta su una riga)
	if lungo > largo:
		return _close_all(stack) + "\n" + _reopen_all(stack) + testo + _close_all(stack) + "\n" + _reopen_all(stack)
	var passo := _attr(tag, "scrollamount").to_float()
	var ritardo := _attr(tag, "scrolldelay").to_float() / 1000.0
	var v := (passo if passo > 0.0 else MARQUEE_PASSO) / (ritardo if ritardo >= 0.02 else MARQUEE_RITARDO)
	var dir := "r" if _attr(tag, "direction").to_lower() == "right" else "l"
	var modo := "a" if _attr(tag, "behavior").to_lower() == "alternate" else "s"
	var fx := "[marquee w=%d len=%d v=%d dir=%s mode=%s]" % [int(largo), int(lungo), int(v), dir, modo]
	return _close_all(stack) + "\n" + _reopen_all(stack) + "[left]" + fx + testo \
			+ "[/marquee][/left]" + _close_all(stack) + "\n" + _reopen_all(stack)

# <bgsound src loop> / <embed src autostart hidden loop>: la musica della pagina.
# Non si vede niente: la sorgente finisce in ctx["audio"] (la prima vince, come nei
# browser) e la suona BrowserApp quando la pagina ha finito di arrivare. Un <embed>
# NON nascosto disegna il lettore d'epoca: due pulsanti, play e stop.
static func _audio(nm: String, tag: String, stack: Array, ctx: Dictionary) -> String:
	var src := _attr(tag, "src").strip_edges()
	if src == "":
		return ""
	var loop := _attr(tag, "loop").strip_edges().to_lower()
	var auto := true
	var visibile := false
	if nm == "embed":
		auto = _attr(tag, "autostart").strip_edges().to_lower() == "true"
		visibile = _attr(tag, "hidden").strip_edges().to_lower() != "true"
	if not ctx.has("audio"):
		ctx["audio"] = {
			"src": src,
			"path": audio_path(src),
			# bgsound: loop="-1"/"infinite" = per sempre, se manca suona una volta;
			# embed: loop="true"
			"loop": loop == "-1" or loop == "infinite" or loop == "true",
			"auto": auto,
		}
	if not visibile:
		return ""
	var tasti := "[url=%s][color=#000000] ► [/color][/url][color=#808080]|[/color][url=%s][color=#000000] ■ [/color][/url]" % [META_PLAY, META_STOP]
	return _close_all(stack) + "\n[table=1][cell bg=#C0C0C0 border=#808080 padding=6,2,6,2]" \
			+ tasti + "[/cell][/table]\n" + _reopen_all(stack)

# ---------------- moduli ----------------
# I moduli d'epoca FUNZIONANO (proprietario, 24/10/2026: "se i pulsanti esistevano
# creamoli"): campi dove si scrive, caselle che si spuntano, tendine che si aprono,
# pulsanti che inviano. Qui si DISEGNANO soltanto, come piccole tabelle in linea con
# dentro un link speciale (__campo:, __spunta:, __tendina:, __invia:, __azzera:) che il
# browser intercetta; i valori correnti arrivano da ctx["valori"] (id -> valore) e il
# campo in cui si sta scrivendo da ctx["campo_attivo"]. In ctx["moduli"] il compilatore
# lascia la descrizione dei moduli della pagina, che il browser usa per inviarli.
# Gli id ("m0_2" = modulo 0, campo 2) seguono l'ordine del documento: ricompilando la
# stessa pagina tornano uguali.

const CAMPO_FONDO := "#FFFFFF"
const CAMPO_BORDO := "#808080"
const BOTTONE_FONDO := "#C0C0C0"
const BOTTONE_BORDO := "#404040"
const PX_CARATTERE := 8.0       # larghezza di un carattere per size= e cols=
const PX_RIGA := 19.0           # altezza di una riga per rows=
static var _controlli: Dictionary = {}   # "casella_on" ecc. -> texture (tenuta viva qui)

static func _nuovo_modulo(ctx: Dictionary, action: String, method: String) -> int:
	if not ctx.has("moduli"):
		ctx["moduli"] = []
	var moduli: Array = ctx["moduli"]
	moduli.append({"action": action.strip_edges(), "method": method.strip_edges().to_lower(), "campi": []})
	return moduli.size() - 1

# Un campo nuovo nel modulo aperto (o in un modulo implicito, se il campo e' fuori da
# un <form>, come succedeva nelle pagine scritte a mano).
static func _nuovo_campo(ctx: Dictionary, tipo: String, nome: String, valore: String, extra: Dictionary = {}) -> Dictionary:
	var fi: int = int(ctx.get("_modulo", -1))
	if fi < 0:
		if int(ctx.get("_implicito", -1)) < 0:
			ctx["_implicito"] = _nuovo_modulo(ctx, "", "get")
		fi = int(ctx["_implicito"])
	var campi: Array = (ctx["moduli"] as Array)[fi]["campi"]
	var c := {"id": "m%d_%d" % [fi, campi.size()], "tipo": tipo, "nome": nome, "valore": valore, "modulo": fi}
	c.merge(extra)
	campi.append(c)
	return c

# Il valore corrente di un campo: quello scritto dal giocatore, o quello della pagina.
static func _valore(c: Dictionary, ctx: Dictionary) -> String:
	var valori: Dictionary = ctx.get("valori", {})
	return str(valori.get(c["id"], c["valore"]))

static func _input(tag: String, ctx: Dictionary) -> String:
	var tipo := _attr(tag, "type").strip_edges().to_lower()
	if tipo == "":
		tipo = "text"
	var nome := _attr(tag, "name")
	var valore := _ent(_attr(tag, "value"))
	match tipo:
		"hidden":
			_nuovo_campo(ctx, tipo, nome, valore)
			return ""
		"submit", "button", "reset", "image":
			return _pulsante(tag, valore, ctx)
		"checkbox", "radio":
			var spuntata := tag.to_lower().find("checked") >= 0
			var c := _nuovo_campo(ctx, tipo, nome, "1" if spuntata else "", {"invia": valore if valore != "" else "on"})
			var on := _valore(c, ctx) != ""
			return "[url=__spunta:%s][img width=16 height=16]%s[/img][/url]" % [c["id"], _controllo(tipo, on)]
	# text, password e tutto il resto: una riga in cui si scrive
	var size := int(_attr(tag, "size")) if _attr(tag, "size").strip_edges() != "" else 20
	var maxl := int(_attr(tag, "maxlength")) if _attr(tag, "maxlength").strip_edges() != "" else 0
	var c2 := _nuovo_campo(ctx, "password" if tipo == "password" else "text", nome, valore, {"max": maxl})
	var v := _valore(c2, ctx)
	var mostra := "*".repeat(v.length()) if tipo == "password" else v
	return _scatola(c2["id"], "__campo:", mostra, str(ctx.get("campo_attivo", "")) == c2["id"],
			float(clampi(size, 3, 60)) * PX_CARATTERE, 0.0)

# Il riquadro bianco incassato di un campo: testo, cursore se attivo, e una barretta
# trasparente che lo tiene largo quanto chiede size=/cols= anche quando e' vuoto.
static func _scatola(id: String, meta: String, testo: String, attivo: bool, largo: float, alto: float) -> String:
	var t := testo + ("|" if attivo else "")
	var righe := t.split("\n")
	var piu_lunga := ""
	for r in righe:
		if r.length() > piu_lunga.length():
			piu_lunga = r
	var occupa: float = Win95.font("sans").get_string_size(piu_lunga, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var resto := int(maxf(1.0, largo - occupa))
	var corpo := ""
	for k in range(righe.size()):
		if k > 0:
			corpo += "\n"
		corpo += _txt(righe[k]).replace(" ", char(0xA0))
	var dentro := "[color=#000000]" + corpo + "[/color][img width=%d height=1]%s[/img]" % [resto, SPACER_IMG]
	# l'altezza: le righe chieste (rows=), o almeno una riga di testo -- un campo vuoto
	# senza questa barretta verticale era un filo alto 4 px
	dentro = "[img width=1 height=%d]%s[/img]" % [int(maxf(alto, PX_RIGA)), SPACER_IMG] + dentro
	var bordo := "#000080" if attivo else CAMPO_BORDO
	return "[table=1,center][cell bg=%s border=%s padding=4,2,4,2][url=%s%s]%s[/url][/cell][/table]" % [
			CAMPO_FONDO, bordo, meta, id, dentro]

# Un pulsante: <input type=submit/button/reset/image> o <button>. Invia il modulo in cui
# sta (reset lo riporta ai valori della pagina); "image" e' un'immagine cliccabile.
static func _pulsante(tag: String, etichetta: String, ctx: Dictionary) -> String:
	var tipo := _attr(tag, "type").strip_edges().to_lower()
	var fi: int = int(ctx.get("_modulo", -1))
	if fi < 0:
		if int(ctx.get("_implicito", -1)) < 0:
			ctx["_implicito"] = _nuovo_modulo(ctx, "", "get")
		fi = int(ctx["_implicito"])
	var meta := "__azzera:%d" % fi if tipo == "reset" else "__invia:%d" % fi
	# il menu a pulsanti d'epoca: <input type=button onclick="location.href='x.html'">.
	# Il pulsante diventa un link vero (barra di stato, link visitati, regole del sito).
	var vai := pulsante_link(tag)
	if vai != "":
		meta = vai
	if tipo == "image":
		return "[url=%s][img]%s[/img][/url]" % [meta, img_path(_attr(tag, "src"))]
	if etichetta.strip_edges() == "":
		etichetta = TranslationServer.translate("WEB_FORM_RESET" if tipo == "reset" else "WEB_FORM_SUBMIT")
	return "[table=1,center][cell bg=%s border=%s padding=10,2,10,2][url=%s][color=#000000]%s[/color][/url][/cell][/table]" % [
			BOTTONE_FONDO, BOTTONE_BORDO, meta, _txt(etichetta)]

# L'indirizzo di un onclick="location.href='x'" (o window.location / location=), "" se non c'e'.
static func pulsante_link(tag: String) -> String:
	var re := RegEx.create_from_string("(?i)location(?:\\.href)?\\s*=\\s*['\"]([^'\"]+)['\"]")
	var m := re.search(_attr(tag, "onclick"))
	return m.get_string(1).strip_edges() if m != null else ""

# <select>: il valore scelto e la freccetta; il browser apre l'elenco delle <option>.
static func _tendina(tag: String, interno: String, ctx: Dictionary) -> String:
	var opzioni: Array = []
	var scelta := ""
	var re := RegEx.create_from_string("(?is)<option([^>]*)>([^<]*)")
	for m in re.search_all(interno):
		var attr := m.get_string(1)
		var etichetta := _ent(m.get_string(2)).strip_edges()
		var v := _attr("x " + attr, "value")
		if v == "":
			v = etichetta
		opzioni.append([v, etichetta])
		if scelta == "" and attr.to_lower().find("selected") >= 0:
			scelta = v
	if scelta == "" and not opzioni.is_empty():
		scelta = str(opzioni[0][0])
	var c := _nuovo_campo(ctx, "select", _attr(tag, "name"), scelta, {"opzioni": opzioni})
	var v2 := _valore(c, ctx)
	var mostra := v2
	for o in opzioni:
		if str(o[0]) == v2:
			mostra = str(o[1])
	return "[table=1,center][cell bg=%s border=%s padding=4,1,2,1][url=__tendina:%s][color=#000000]%s  [/color][bgcolor=%s][color=#000000] ▼ [/color][/bgcolor][/url][/cell][/table]" % [
			CAMPO_FONDO, CAMPO_BORDO, c["id"], _txt(mostra), BOTTONE_FONDO]

# <textarea>: piu' righe; Invio va a capo invece di inviare.
static func _area_testo(tag: String, interno: String, ctx: Dictionary) -> String:
	var cols := int(_attr(tag, "cols")) if _attr(tag, "cols").strip_edges() != "" else 40
	var rows := int(_attr(tag, "rows")) if _attr(tag, "rows").strip_edges() != "" else 4
	var testo := _ent(interno).trim_prefix("\n").trim_prefix("\r\n")
	var c := _nuovo_campo(ctx, "textarea", _attr(tag, "name"), testo)
	return _scatola(c["id"], "__campo:", _valore(c, ctx), str(ctx.get("campo_attivo", "")) == c["id"],
			float(clampi(cols, 5, 90)) * PX_CARATTERE, float(clampi(rows, 1, 30)) * PX_RIGA)

# Le caselle e i pallini disegnati da Win95, registrati su un percorso virtuale come le
# GIF, cosi' [img] li trova.
static func _controllo(tipo: String, on: bool) -> String:
	var chiave := ("casella" if tipo == "checkbox" else "pallino") + ("_on" if on else "_off")
	var path := IMG_DIR + "_" + chiave + ".tex"
	if not _controlli.has(chiave):
		var tex: Texture2D = Win95._tex_casella(on) if tipo == "checkbox" else Win95._tex_pallino(on)
		tex.take_over_path(path)
		_controlli[chiave] = tex
	return path

# Le entita' in un valore di attributo o di <textarea>/<option>.
static func _ent(s: String) -> String:
	for k in _ENTITIES:
		s = s.replace(k, _ENTITIES[k])
	return s.replace("&nbsp;", " ")

# Il testo dentro <pre>: gli spazi e gli a capo restano dove sono (spazi -> spazi che
# non si comprimono, a capo -> a capo veri, con la pila chiusa e riaperta).
static func _txt_pre(s: String, stack: Array) -> String:
	for k in _ENTITIES:
		s = s.replace(k, _ENTITIES[k])
	s = s.replace("&nbsp;", " ").replace("\t", "    ").replace("\r", "")
	s = s.replace("[", "￰").replace("]", "[rb]").replace("￰", "[lb]")
	s = s.replace(" ", char(0xA0))
	return s.replace("\n", _close_all(stack) + "\n" + _reopen_all(stack))

# Percorso del file audio di una pagina ("" se non c'e').
static func audio_path(src: String) -> String:
	var p := src.strip_edges()
	if p == "":
		return ""
	if not p.begins_with("res://"):
		p = AUDIO_DIR + p.get_file()
	return p if FileAccess.file_exists(p) or ResourceLoader.exists(p) else ""

# Il testo di un pezzo di BBCode, senza tag (serve a misurarne la lunghezza).
static func _solo_testo(bb: String) -> String:
	if _tag_re == null:
		_tag_re = RegEx.create_from_string("\\[[^\\]]*\\]")
	return _tag_re.sub(bb, "", true)

# ---------------- famiglie di caratteri ----------------

# La famiglia di un face= ("Verdana, Arial" -> la prima che si riconosce):
# "mono", "comic", "serif", "sans", oppure "" se il face manca.
static func famiglia(face: String) -> String:
	if face.strip_edges() == "":
		return ""
	for pezzo in face.to_lower().split(","):
		var f := pezzo.strip_edges()
		if f == "":
			continue
		if f.find("courier") >= 0 or f.find("mono") >= 0 or f.find("fixedsys") >= 0 \
				or f.find("console") >= 0:
			return "mono"
		if f.find("comic") >= 0:
			return "comic"
		if f.find("sans") >= 0 or f.find("arial") >= 0 or f.find("helvetica") >= 0 \
				or f.find("verdana") >= 0 or f.find("tahoma") >= 0 or f.find("impact") >= 0:
			return "sans"
		if f.find("times") >= 0 or f.find("serif") >= 0 or f.find("georgia") >= 0 \
				or f.find("garamond") >= 0 or f.find("palatino") >= 0 or f.find("book") >= 0 \
				or f.find("century") >= 0:
			return "serif"
	return "sans"

# Stato tipografico in cima alla pila: famiglia, grassetto, corsivo.
static func _stato(stack: Array) -> Dictionary:
	var st := {"fam": "sans", "b": false, "i": false}
	for e in stack:
		if e.has("fam"):
			st["fam"] = e["fam"]
		if e.get("b", false):
			st["b"] = true
		if e.get("i", false):
			st["i"] = true
	return st

# Il file da usare per un <b>/<i>/<hN> aperto ora: "" nel sans del tema (bastano
# [b]/[i]), il file della famiglia altrimenti.
static func _file_di(stack: Array, b: bool, i: bool) -> String:
	var st := _stato(stack)
	var fam := str(st["fam"])
	if fam == "sans" or fam == "mono":
		return ""
	return _font_file(fam, b or bool(st["b"]), i or bool(st["i"]))

static func _font_file(fam: String, b: bool, i: bool) -> String:
	var nome := fam
	if fam == "comic":
		nome = "comic_b" if b else "comic"       # Comic Neue: niente corsivo, come l'originale
	elif b and i:
		nome = fam + "_bi"
	elif b:
		nome = fam + "_b"
	elif i:
		nome = fam + "_i"
	return Win95.FONT_DIR + str(Win95._FONT_FILES.get(nome, Win95._FONT_FILES["sans"]))

static func _img(tag: String) -> String:
	var opts := ""
	var w := _attr(tag, "width").strip_edges()
	var h := _attr(tag, "height").strip_edges()
	if w != "":
		opts += " width=" + w
	if h != "":
		opts += " height=" + h
	return "[img" + opts + "]" + img_path(_attr(tag, "src")) + "[/img]"

# <table> -> [table=N][cell ...]...[/table]. Righe corte completate con celle
# vuote (le celle riempiono la griglia riga per riga). Ricorsivo: dentro una
# cella puo' esserci un'altra <table>.
static func _table(inner: String, tag: String, ctx: Dictionary) -> String:
	var border := int(_attr(tag, "border")) if _attr(tag, "border").strip_edges() != "" else 0
	var bordo := _col(_attr(tag, "bordercolor"))
	if bordo == "":
		bordo = "#808080"
	var tbg := _attr(tag, "bgcolor")
	var padattr := _attr(tag, "cellpadding")
	var pad := int(padattr) if padattr.strip_edges() != "" else 8
	var vpad := maxi(2, pad - 4)
	var rows := _rows(inner)
	var ncols := 0
	for rd in rows:
		ncols = maxi(ncols, (rd["cells"] as Array).size())
	if ncols == 0:
		return ""
	# la larghezza di ogni colonna (0 = decide il contenuto): serve alla riga
	# distanziatrice e alle tabelle ANNIDATE, le cui percentuali sono della cella
	var colw := _colonne(tag, rows, ncols, ctx)
	var bb := "[table=%d]" % ncols
	for rd in rows:
		var cells: Array = rd["cells"]
		for c in range(ncols):
			var opts := " padding=%d,%d,%d,%d" % [pad, vpad, pad, vpad]
			if border > 0:
				opts += " border=" + bordo
			if c >= cells.size():
				# cella di riempimento (mantiene la griglia allineata)
				var rbg := str(rd.get("bg", ""))
				if rbg == "":
					rbg = tbg
				if rbg != "":
					opts += " bg=" + _col(rbg)
				bb += "[cell" + opts + "][/cell]"
				continue
			var cd: Dictionary = cells[c]
			var bg := str(cd.get("bg", ""))
			if bg == "":
				bg = tbg
			if bg != "":
				opts += " bg=" + _col(bg)
			ctx["_in_cella"] = int(ctx.get("_in_cella", 0)) + 1
			var pagina_fuori: Variant = ctx.get("page_width", 0.0)
			if float(colw[c]) > 0.0:
				ctx["page_width"] = maxf(16.0, float(colw[c]) - float(2 * pad + CELLA_EXTRA))
			var content := _walk(str(cd.get("html", "")), ctx).strip_edges()
			ctx["page_width"] = pagina_fuori
			ctx["_in_cella"] = int(ctx["_in_cella"]) - 1
			if bool(cd.get("th", false)):
				content = "[center][b]" + content + "[/b][/center]"
			else:
				match str(cd.get("align", "")).to_lower():
					"center": content = "[center]" + content + "[/center]"
					"right": content = "[right]" + content + "[/right]"
					_:
						# come in HTML una <td> e' allineata a sinistra: [left] serve a
						# non ereditare il [center] di una tabella centrata
						content = "[left]" + content + "[/left]"
			bb += "[cell" + opts + "]" + content + "[/cell]"
	bb += _spacer_row(colw, pad, tbg)
	return bb + "[/table]"

# <table width="70%"> / width="500": la larghezza di una [table] BBCode e' guidata
# dal CONTENUTO, quindi la imponiamo col trucco d'epoca della "spacer.gif" — una
# riga finale, senza bordo e alta 1 px, con un'immagine trasparente larga quanto
# serve per ogni colonna. Le colonne con <td width="160"> / "25%" (nella prima riga
# che ne dichiara) prendono la loro misura -- e' la colonna laterale dei siti
# d'epoca -- le altre si spartiscono in parti uguali quello che resta.
# Richiede ctx["page_width"] (pixel utili della pagina) per le percentuali.
static func _spacer_row(colw: Array, pad: int, tbg: String) -> String:
	var tutte_zero := true
	for w in colw:
		if float(w) >= 16.0:
			tutte_zero = false
	if tutte_zero:
		return ""
	var opts := " padding=0,0,0,0"
	if tbg != "":
		opts += " bg=" + _col(tbg)
	var out := ""
	for w in colw:
		if float(w) < 16.0:
			out += "[cell" + opts + "][/cell]"
			continue
		# la cella ci aggiunge il proprio padding orizzontale piu' un paio di px di bordo
		var larghezza: int = int(maxf(8.0, float(w) - float(2 * pad + CELLA_EXTRA)))
		out += "[cell" + opts + "][img width=%d height=1]%s[/img][/cell]" % [larghezza, SPACER_IMG]
	return out

# Larghezza in pixel di ogni colonna (0 = non dichiarata e non deducibile).
static func _colonne(tag: String, rows: Array, ncols: int, ctx: Dictionary) -> Array:
	var col: Array = []
	col.resize(ncols)
	col.fill(0.0)
	var target := _misura(_attr(tag, "width"), float(ctx.get("page_width", 0.0)), ctx)
	# le percentuali delle celle sono della tabella, o della pagina se la tabella non
	# ha una larghezza
	var base := target if target > 0.0 else float(ctx.get("page_width", 0.0))
	var dichiarate := false
	for rd in rows:
		var celle: Array = rd["cells"]
		for c in range(mini(celle.size(), ncols)):
			var m := _misura(str((celle[c] as Dictionary).get("width", "")), base, ctx)
			if m > 0.0:
				col[c] = m
				dichiarate = true
		if dichiarate:
			break
	if target < 16.0:
		return col
	var noti := 0.0
	var ignote := 0
	for v in col:
		if float(v) > 0.0:
			noti += float(v)
		else:
			ignote += 1
	if ignote > 0:
		var resto := maxf(0.0, target - noti) / float(ignote)
		for c in range(ncols):
			if float(col[c]) <= 0.0:
				col[c] = resto
	return col

# "70%" o "500" -> pixel (0 se manca, o se la pagina non ha ancora una larghezza).
static func _misura(w: String, base: float, ctx: Dictionary) -> float:
	w = w.strip_edges()
	if w == "":
		return 0.0
	if w.ends_with("%"):
		ctx["uses_width"] = true          # il browser ricompila quando cambia la larghezza
		if base <= 0.0:
			return 0.0                    # larghezza di pagina ancora sconosciuta
		return base * clampf(w.trim_suffix("%").to_float(), 1.0, 100.0) / 100.0
	return w.to_float()

# Una tabella PIU' STRETTA della pagina (<table width="560">, la scheda centrata): la
# riga distanziatrice da' a una [table] solo la larghezza MINIMA, e un paragrafo lungo la
# allarga fino al bordo. La si chiude allora fra colonne vuote che riempiono il resto
# della pagina: lo spazio libero non c'e' piu' e il testo va a capo dentro la tabella.
# "" se la tabella non e' stretta (o la larghezza della pagina non e' ancora nota).
static func _stringi(tbb: String, tag: String, centrata: bool, ctx: Dictionary) -> String:
	var pagina := float(ctx.get("page_width", 0.0))
	var w := _attr(tag, "width").strip_edges()
	if w == "":
		return ""
	# anche a larghezza ancora ignota: il browser deve ricompilare quando la conosce
	ctx["uses_width"] = true
	if pagina <= 0.0:
		return ""
	var target := w.to_float()
	if w.ends_with("%"):
		target = pagina * clampf(w.trim_suffix("%").to_float(), 1.0, 100.0) / 100.0
	var avanzo := pagina - target - 4.0
	if target < 16.0 or avanzo < 24.0:
		return ""
	var vuota := "[cell padding=0,0,0,0][img width=%d height=1]" + SPACER_IMG + "[/img][/cell]"
	var dentro := "[cell padding=0,0,0,0]" + tbb + "[/cell]"
	if centrata:
		var lato := int(avanzo / 2.0)
		return "[table=3]" + vuota % lato + dentro + vuota % lato + "[/table]"
	return "[table=2]" + dentro + vuota % int(avanzo) + "[/table]"

# Indice del "</table>" che chiude la tabella aperta (gestisce l'annidamento).
static func _table_end(html: String, from: int) -> int:
	var depth := 1
	var i := from
	while depth > 0:
		var o := html.findn("<table", i)
		var c := html.findn("</table", i)
		if c < 0:
			return html.length()
		if o >= 0 and o < c:
			depth += 1
			i = o + 6
		else:
			depth -= 1
			if depth == 0:
				return c
			i = c + 8
	return html.length()

# Estrae le righe/celle di una tabella (solo al livello corrente: le tabelle
# annidate restano HTML grezzo dentro la cella). Tollerante: <td>/<tr> non chiusi
# vengono chiusi implicitamente.
static func _rows(inner: String) -> Array:
	var rows: Array = []
	var cells: Array = []
	var cur := ""
	var in_cell := false
	var in_row := false
	var row_bg := ""
	var cell: Dictionary = {}
	var depth := 0
	var i := 0
	var n := inner.length()
	while i < n:
		if inner[i] != "<":
			var lt := inner.find("<", i)
			if lt < 0:
				lt = n
			if in_cell:
				cur += inner.substr(i, lt - i)
			i = lt
			continue
		var gt := inner.find(">", i)
		if gt < 0:
			break
		var tag := inner.substr(i + 1, gt - i - 1)
		var nm := _tagname(tag)
		var closing := tag.strip_edges().begins_with("/")
		if nm == "table":
			depth += -1 if closing else 1
			if in_cell:
				cur += inner.substr(i, gt - i + 1)
			i = gt + 1
			continue
		if depth > 0:
			if in_cell:
				cur += inner.substr(i, gt - i + 1)
			i = gt + 1
			continue
		i = gt + 1
		match nm:
			"tr":
				if in_cell:
					cell["html"] = cur
					cells.append(cell)
					in_cell = false
				if closing or in_row:
					if not cells.is_empty():
						rows.append({"bg": row_bg, "cells": cells})
					cells = []
					in_row = false
				if not closing:
					in_row = true
					row_bg = _attr(tag, "bgcolor")
			"td", "th":
				if in_cell:
					cell["html"] = cur
					cells.append(cell)
					in_cell = false
				if not closing:
					in_cell = true
					cur = ""
					var bg := _attr(tag, "bgcolor")
					if bg == "":
						bg = row_bg
					cell = {"bg": bg, "align": _attr(tag, "align"), "th": nm == "th",
							"width": _attr(tag, "width")}
			_:
				if in_cell:
					cur += inner.substr(gt - tag.length() - 1, tag.length() + 2)
	if in_cell:
		cell["html"] = cur
		cells.append(cell)
	if not cells.is_empty():
		rows.append({"bg": row_bg, "cells": cells})
	return rows

# ---------------- immagini ----------------

# Percorso per [img]: file in web/img/ (o res:// esplicito); se manca, il
# segnaposto "immagine rotta" disegnato in codice (niente PNG di servizio).
static func img_path(src: String) -> String:
	var p := src.strip_edges()
	if p == "":
		return _broken_path()
	if not p.begins_with("res://"):
		p = IMG_DIR + p
	if p.get_extension().to_lower() == "gif":
		return _gif_path(p)
	if ResourceLoader.exists(p):
		return p
	return _broken_path()

# La texture di un src= (per lo sfondo a mosaico di <body background>).
static func texture(src: String) -> Texture2D:
	var p := img_path(src)
	return load(p) as Texture2D

# Godot non importa le GIF: il file si decodifica qui (GifDecoder) UNA volta, e la
# texture si registra su un percorso virtuale come quella dell'immagine rotta, cosi'
# [img] la trova. Animata o no, e' sempre la stessa per tutte le pagine che la usano.
static func _gif_path(p: String) -> String:
	var virtuale := p + ".tex"
	if _gif.has(p):
		return virtuale
	var tex := GifDecoder.texture_da_file(p)
	if tex == null:
		return _broken_path()
	tex.take_over_path(virtuale)
	_gif[p] = tex
	return virtuale

static func _broken_path() -> String:
	var path := IMG_DIR + "_rotta_.imgtex"
	if _broken_tex == null:
		var im := Image.create(64, 48, false, Image.FORMAT_RGBA8)
		im.fill(Color("e8e8e8"))
		for x in range(64):
			im.set_pixel(x, 0, Color("808080"))
			im.set_pixel(x, 47, Color("808080"))
		for y in range(48):
			im.set_pixel(0, y, Color("808080"))
			im.set_pixel(63, y, Color("808080"))
		for k in range(28):
			var xx := 18 + k
			var y1 := 10 + k
			var y2 := 37 - k
			if y1 >= 2 and y1 <= 45:
				im.set_pixel(xx, y1, Color("aa0000"))
				im.set_pixel(xx, y2, Color("aa0000"))
		_broken_tex = ImageTexture.create_from_image(im)
		_broken_tex.take_over_path(path)
	return path

# ---------------- stack dei tag inline ----------------

# extra: lo stato tipografico che il tag porta ("fam", "b", "i"), letto da _stato.
static func _push(stack: Array, nm: String, open: String, close: String, extra: Dictionary = {}) -> String:
	var e := {"nm": nm, "open": open, "close": close}
	e.merge(extra)
	stack.push_back(e)
	return open

static func _pop_tag(stack: Array, nm: String) -> String:
	var idx := -1
	for k in range(stack.size() - 1, -1, -1):
		if str(stack[k]["nm"]) == nm:
			idx = k
			break
	if idx < 0:
		return ""
	var out := ""
	var above: Array = []
	while stack.size() > idx:
		var t: Dictionary = stack.pop_back()
		out += str(t["close"])
		if stack.size() > idx:
			above.push_front(t)
	for t in above:
		stack.push_back(t)
		out += str(t["open"])
	return out

static func _close_all(stack: Array) -> String:
	var out := ""
	for k in range(stack.size() - 1, -1, -1):
		out += str(stack[k]["close"])
	return out

static func _reopen_all(stack: Array) -> String:
	var out := ""
	for t in stack:
		out += str(t["open"])
	return out

# ---------------- documento: body e commenti ----------------
# Funzioni pure che stanno QUI e non nel browser perche' i test headless devono
# poter rifare la stessa pipeline di rendering della pagina senza istanziare
# BrowserApp (vedi tests/html_bb_test.gd).

# Il contenuto fra <body ...> e </body>. Se i tag mancano, tutto il documento.
static func body_inner(html: String) -> String:
	var bi := html.findn("<body")
	if bi < 0:
		return html
	var gt := html.find(">", bi)
	if gt < 0:
		return html
	var endb := html.findn("</body>")
	if endb < 0:
		endb = html.length()
	return html.substr(gt + 1, endb - gt - 1)

# Via i commenti <!-- ... -->. Va fatto PRIMA di compile(): e' quello che rende
# invisibile a schermo la chiave nascosta nel sorgente (resta nel "visualizza
# sorgente", che usa l'HTML non ripulito).
static func strip_comments(s: String) -> String:
	while true:
		var a := s.find("<!--")
		if a < 0:
			break
		var b := s.find("-->", a)
		if b < 0:
			s = s.substr(0, a)
			break
		s = s.substr(0, a) + s.substr(b + 3)
	return s

# ---------------- helper parsing ----------------

static func _tagname(tag: String) -> String:
	var t := tag.strip_edges()
	if t.begins_with("/"):
		t = t.substr(1)
	var sp := t.find(" ")
	if sp >= 0:
		t = t.substr(0, sp)
	return t.to_lower()

static func _attr(tag: String, name: String) -> String:
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

# Normalizza un colore HTML: "C0C0C0" -> "#C0C0C0"; nomi/hex con # passano invariati.
static func _col(c: String) -> String:
	var s := c.strip_edges()
	if s == "" or s.begins_with("#"):
		return s
	if Color.html_is_valid("#" + s):
		return "#" + s
	return s

# Testo: entita', spazi collassati (come l'HTML), parentesi quadre escapate.
static func _txt(s: String) -> String:
	for k in _ENTITIES:
		s = s.replace(k, _ENTITIES[k])
	if _ws_re == null:
		_ws_re = RegEx.new()
		_ws_re.compile("\\s+")
	s = _ws_re.sub(s, " ", true)
	# &nbsp; DOPO aver compresso gli spazi, e come spazio vero che non si comprime ne' va a
	# capo: e' cosi' che le pagine allineano i disegni ASCII (prima diventava uno spazio
	# normale e i disegni si storcevano)
	s = s.replace("&nbsp;", char(0xA0))
	return s.replace("[", "￰").replace("]", "[rb]").replace("￰", "[lb]")
