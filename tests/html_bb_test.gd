extends SceneTree

# Test unitario (headless) del compilatore HtmlBB: stringa HTML -> stringa BBCode.
#   & $godot --headless --path $proj -s res://tests/html_bb_test.gd

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
