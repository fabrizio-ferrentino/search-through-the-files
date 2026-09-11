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
# img(src/width/height), input(type/value), table/tr/td/th (border/bgcolor/
# cellpadding/width/align; bgcolor per riga e per cella, align per cella).
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
# - face=: "Courier New"/monospace -> [code] (slot mono del tema); gli altri
#   restano il sans del tema (Arimo ~ Arial), che e' cio' che le pagine chiedono.
# ============================================================

const IMG_DIR := "res://web/img/"

# Immagine 1x1 trasparente: allarga una tabella a una misura precisa senza
# comparire (il vecchio trucco dello "spacer.gif" del web anni '90).
const SPACER_IMG := "res://web/img/spacer.png"

const _ENTITIES := {
	"&nbsp;": " ", "&copy;": "©", "&raquo;": "»", "&laquo;": "«",
	"&middot;": "·", "&hellip;": "…", "&quot;": "\"", "&mdash;": "—", "&deg;": "°",
	"&lt;": "<", "&gt;": ">", "&amp;": "&",
}
const _FONT_PX := {"1": 11, "2": 13, "3": 16, "4": 20, "5": 24, "6": 30, "7": 36}
const _H_PX := {"h1": 30, "h2": 24, "h3": 20, "h4": 18, "h5": 15, "h6": 13}

static var _ws_re: RegEx
static var _nl_re: RegEx
static var _broken_tex: ImageTexture

# Compila il BODY (gia' senza commenti) in BBCode. ctx: "link_color" (es. "#0000ee").
static func compile(body: String, ctx: Dictionary = {}) -> String:
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
				"h1", "h2", "h3", "h4", "h5", "h6", "div", "center", "blockquote", "p":
					out += _pop_tag(stack, nm) + "\n"
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
				if _attr(tag, "align").to_lower() == "center" or _has_center(stack):
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
				out += "\n" + _push(stack, nm, "[font_size=%d][b]" % int(_H_PX[nm]), "[/b][/font_size]")
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
				out += _close_all(stack) + "\n" + _hr(tag) + "\n" + _reopen_all(stack)
			"img":
				out += _img(tag)
			"input":
				if _attr(tag, "type").to_lower() == "submit":
					out += "[lb] " + _txt(_attr(tag, "value")) + " [rb]"
				else:
					out += "[u]          [/u]"
			"b", "i", "u":
				out += _push(stack, nm, "[%s]" % nm, "[/%s]" % nm)
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
				out += _push(stack, "a", "[url=" + _attr(tag, "href") + "][color=" + link_color + "][u]", "[/u][/color][/url]")
			"font":
				var open := ""
				var close := ""
				var face := _attr(tag, "face").to_lower()
				if face.find("courier") >= 0 or face.find("mono") >= 0 or face.find("fixedsys") >= 0:
					open += "[code]"                     # slot mono del tema
					close = "[/code]" + close
				var col := _attr(tag, "color")
				if col != "":
					open += "[color=" + _col(col) + "]"
					close = "[/color]" + close
				var sz := _attr(tag, "size")
				if sz != "":
					open += "[font_size=%d]" % int(_FONT_PX.get(sz.strip_edges(), 16))
					close = "[/font_size]" + close
				out += _push(stack, "font", open, close)
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

static func _hr(tag: String) -> String:
	var col := _attr(tag, "color")
	var h := _attr(tag, "size")     # <hr size=N> legacy = spessore
	var w := _attr(tag, "width")
	var bb := "[hr color=" + (_col(col) if col != "" else "#808080")
	bb += " height=%d" % (maxi(1, int(h)) if h.strip_edges() != "" else 2)
	if w.strip_edges() != "":
		bb += " width=" + w.strip_edges() + " align=center"
	else:
		bb += " width=100%"
	return bb + "]"

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
	var bb := "[table=%d]" % ncols
	for rd in rows:
		var cells: Array = rd["cells"]
		for c in range(ncols):
			var opts := " padding=%d,%d,%d,%d" % [pad, vpad, pad, vpad]
			if border > 0:
				opts += " border=#808080"
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
			var content := _walk(str(cd.get("html", "")), ctx).strip_edges()
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
	bb += _spacer_row(tag, ncols, pad, tbg, ctx)
	return bb + "[/table]"

# <table width="70%"> / width="500": la larghezza di una [table] BBCode e' guidata
# dal CONTENUTO, quindi la imponiamo col trucco d'epoca della "spacer.gif" — una
# riga finale, senza bordo e alta 1 px, con un'immagine trasparente larga quanto
# serve. Con piu' colonne la misura viene spartita in parti uguali.
# Richiede ctx["page_width"] (pixel utili della pagina) per le percentuali.
static func _spacer_row(tag: String, ncols: int, pad: int, tbg: String, ctx: Dictionary) -> String:
	var w := _attr(tag, "width").strip_edges()
	if w == "" or ncols <= 0:
		return ""
	var target := 0.0
	if w.ends_with("%"):
		ctx["uses_width"] = true          # il browser ricompila quando cambia la larghezza
		var disponibile := float(ctx.get("page_width", 0.0))
		if disponibile <= 0.0:
			return ""                     # larghezza di pagina ancora sconosciuta
		target = disponibile * clampf(w.trim_suffix("%").to_float(), 1.0, 100.0) / 100.0
	else:
		target = w.to_float()
	if target < 16.0:
		return ""
	# la cella ci aggiunge il proprio padding orizzontale piu' un paio di px di bordo
	var larghezza: int = int(maxf(8.0, target / float(ncols) - float(2 * pad + 2)))
	var opts := " padding=0,0,0,0"
	if tbg != "":
		opts += " bg=" + _col(tbg)
	var cella := "[cell" + opts + "][img width=%d height=1]%s[/img][/cell]" % [larghezza, SPACER_IMG]
	return cella.repeat(ncols)

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
					cell = {"bg": bg, "align": _attr(tag, "align"), "th": nm == "th"}
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
	if ResourceLoader.exists(p):
		return p
	return _broken_path()

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

static func _push(stack: Array, nm: String, open: String, close: String) -> String:
	stack.push_back({"nm": nm, "open": open, "close": close})
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
	return s.replace("[", "￰").replace("]", "[rb]").replace("￰", "[lb]")
