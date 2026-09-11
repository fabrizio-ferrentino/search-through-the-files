extends SceneTree

# ============================================================
# TEST-GATE (M-web): riproduce il "fantasma di selezione" del RichTextLabel dentro
# una SubViewport (storico: il rettangolo blu restava ~0.5s dopo deselect()).
# Configura UN RichTextLabel esattamente come il futuro browser (selezione ATTIVA),
# spinge input sintetici via push_input (stesso percorso di player._forward_to_os)
# e conta i pixel di selezione (override rosso puro) frame per frame.
# Valida anche: [hr] nativo, tabella [cell expand] a piena larghezza, selezione
# dentro le celle, meta_clicked su clic "pulito" senza hover precedente.
#
# Esecuzione (FINESTRA, non headless: serve il rasterizzatore vero per get_image()):
#   & $godot --path $proj -s res://tests/selection_ghost.gd
# ============================================================

const OUT_DIR := "C:/Users/ffria/AppData/Local/Temp/claude/z--Progetti-Search-Through-the-Files/12447e9d-bcf2-4adc-8102-d384d3a416d2/scratchpad"
const VP_SIZE := Vector2i(1440, 1080)

var _sub: SubViewport
var _rtl: RichTextLabel
var _meta_hits: Array = []
var _fails: Array = []

func _initialize() -> void:
	_run()

func _run() -> void:
	# --- scena: SubViewport come nel gioco (UPDATE_ALWAYS) + sfondo bianco + un RTL ---
	_sub = SubViewport.new()
	_sub.size = VP_SIZE
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_sub)

	var host := Control.new()
	host.theme = Win95.make_theme()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub.add_child(host)

	var bg := ColorRect.new()
	bg.color = Color.WHITE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(bg)

	_rtl = RichTextLabel.new()
	_rtl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# configurazione IDENTICA al futuro BrowserApp._rtl
	_rtl.bbcode_enabled = true
	_rtl.fit_content = false
	_rtl.scroll_active = true
	_rtl.selection_enabled = true
	_rtl.context_menu_enabled = false
	_rtl.shortcut_keys_enabled = true
	_rtl.focus_mode = Control.FOCUS_CLICK
	_rtl.deselect_on_focus_loss_enabled = false
	_rtl.drag_and_drop_selection_enabled = false
	_rtl.mouse_default_cursor_shape = Control.CURSOR_IBEAM
	_rtl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var pad := StyleBoxEmpty.new()
	pad.set_content_margin_all(18)
	_rtl.add_theme_stylebox_override("normal", pad)
	_rtl.add_theme_font_size_override("normal_font_size", 16)
	_rtl.add_theme_color_override("default_color", Color("222222"))
	# selezione ROSSO PURO per contare i pixel senza ambiguita'
	_rtl.add_theme_color_override("selection_color", Color(1, 0, 0))
	_rtl.add_theme_color_override("font_selected_color", Color(1, 1, 0))
	_rtl.meta_clicked.connect(func(m): _meta_hits.append(str(m)))
	# come fara' il browser: al PRESS sinistro azzera la selezione (il clic su area
	# vuota non la azzera da solo; deselect() e' istantaneo, verificato dal TEST D)
	_rtl.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			_rtl.deselect())
	host.add_child(_rtl)

	# contenuto: link in cima (clic pulito), banner blu (tabella allargata dal
	# CONTENUTO che va a capo: expand non esiste), paragrafi, tabella dati, [hr]
	var para := "Questo e' un paragrafo di prova con abbastanza testo da coprire una riga intera della pagina, per trascinare la selezione. "
	var bb := ""
	bb += para + "\n"
	bb += "[url=test][color=#00aa00]LINK DI PROVA CLICCAMI[/color][/url]\n"
	bb += "[table=1][cell bg=#0000ff][color=#ffffff][b]BANNER A PIENA LARGHEZZA[/b][/color][/cell]"
	bb += "[cell bg=#ffffff]" + para.repeat(2) + "[/cell][/table]\n"
	for k in range(4):
		bb += para + "\n"
	bb += "[hr color=#808080 height=2 width=60% align=center]\n"
	bb += para + "\n"
	# tabella dati per ULTIMA: la selezione include le celle solo se la ATTRAVERSA
	# tutta (drag fin sotto l'ultimo contenuto = fine documento)
	bb += "[table=3]"
	bb += "[cell border=#808080 bg=#c0c0c0 padding=8,4,8,4][b]COLONNA1[/b][/cell]"
	bb += "[cell border=#808080 bg=#c0c0c0 padding=8,4,8,4][b]COLONNA2[/b][/cell]"
	bb += "[cell border=#808080 bg=#c0c0c0 padding=8,4,8,4][b]COLONNA3[/b][/cell]"
	bb += "[cell border=#808080 bg=#ffffff,#e8e8e8 padding=8,4,8,4]CELLA1 contenuto[/cell]"
	bb += "[cell border=#808080 bg=#ffffff,#e8e8e8 padding=8,4,8,4]CELLA2 contenuto[/cell]"
	bb += "[cell border=#808080 bg=#ffffff,#e8e8e8 padding=8,4,8,4]CELLA3 contenuto[/cell]"
	bb += "[/table]\n"
	_rtl.text = bb

	for i in range(6):
		await process_frame
	await RenderingServer.frame_post_draw

	var img := _capture()
	img.save_png(OUT_DIR + "/ghost_0_baseline.png")

	# --- CHECK 1: [hr] supportato (se no, resta come testo letterale) ---
	var parsed := _rtl.get_parsed_text()
	_check("HR_NATIVO", parsed.find("[hr") < 0, "il tag [hr] non e' supportato (resta testo)")

	# --- CHECK 2: banner a piena larghezza (tabella allargata dal contenuto) ---
	var span := _color_span(img, func(c: Color) -> bool: return c.b > 0.85 and c.r < 0.2 and c.g < 0.2)
	var frac: float = float(span) / float(VP_SIZE.x)
	print("banner blu: larghezza %d px su %d (%.0f%%)" % [span, VP_SIZE.x, frac * 100.0])
	_check("TABELLA_LARGA_DA_CONTENUTO", frac > 0.9, "il banner copre solo il %.0f%% della larghezza" % (frac * 100.0))

	# --- TEST A: trascinamento = selezione (anche dentro la tabella) ---
	# NOTE comportamento RTL osservato: (1) una selezione che INIZIA dentro una tabella
	# resta confinata alla tabella; (2) le celle entrano in get_selected_text() solo se
	# la selezione ATTRAVERSA TUTTA la tabella; (3) il PRESS deve cadere SUI GLIFI
	# (sull'area vuota non fissa l'ancora). Quindi: parte dalla prima riga di testo
	# e finisce ben SOTTO l'ultimo contenuto (fine documento, tabella dati inclusa).
	var drag_a := Vector2(150, 26)
	var drag_b := Vector2(300, minf(float(_rtl.get_content_height()) + 40.0, float(VP_SIZE.y) - 20.0))
	print("drag: %s -> %s (content_height=%d)" % [str(drag_a), str(drag_b), _rtl.get_content_height()])
	# NOTA 4.6: la selezione la estende un Timer interno da 0.05s: il drag deve durare
	# in TEMPO REALE, con una pausa dopo l'ULTIMO motion prima del rilascio.
	_press(drag_a)
	await create_timer(0.06).timeout
	for k in range(10):
		var t: float = float(k + 1) / 10.0
		_motion(drag_a.lerp(drag_b, t))
		await create_timer(0.02).timeout
	await create_timer(0.08).timeout
	_release(drag_b)
	await process_frame
	await RenderingServer.frame_post_draw
	var img_sel := _capture()
	img_sel.save_png(OUT_DIR + "/ghost_1_selezione.png")
	var red_sel := _count_red(img_sel)
	var sel_text := _rtl.get_selected_text()
	print("dopo il drag: pixel rossi=%d, testo selezionato=%d caratteri" % [red_sel, sel_text.length()])
	_check("DRAG_SELEZIONA", red_sel > 200 and sel_text.length() > 20, "drag: rossi=%d, sel='%s'" % [red_sel, sel_text.substr(0, 40)])
	_check("SELEZIONE_IN_TABELLA", sel_text.find("CELLA1") >= 0 or sel_text.find("COLONNA1") >= 0, "la selezione non entra nelle celle della tabella")

	# --- TEST B: clic su area vuota -> la selezione sparisce SUBITO (niente fantasma) ---
	_press(Vector2(120, 900))
	await process_frame
	_release(Vector2(120, 900))
	var ghost_b := await _watch_red(60, "B", 5, 30)
	_check("NIENTE_FANTASMA_CLIC", ghost_b <= 2, "rettangolo residuo per %d frame dopo il clic" % ghost_b)

	# --- TEST C: clic semplice sul testo -> nessun lampo di selezione ---
	var flash := 0
	_press(Vector2(300, 200))
	await process_frame
	_release(Vector2(300, 200))
	for k in range(10):
		await RenderingServer.frame_post_draw
		if _count_red(_capture()) > 0:
			flash += 1
		await process_frame
	_check("NIENTE_LAMPO_CLIC", flash == 0, "il clic semplice ha dipinto la selezione per %d frame" % flash)

	# --- TEST D: deselect() PROGRAMMATICO (il trigger storico del fantasma) ---
	_press(drag_a)
	await create_timer(0.06).timeout
	for k in range(6):
		var t2: float = float(k + 1) / 6.0
		_motion(drag_a.lerp(drag_b, t2))
		await create_timer(0.02).timeout
	await create_timer(0.08).timeout
	_release(drag_b)
	await process_frame
	_rtl.deselect()
	var ghost_d := await _watch_red(60, "D", 5, 30)
	_check("NIENTE_FANTASMA_DESELECT", ghost_d <= 2, "rettangolo residuo per %d frame dopo deselect()" % ghost_d)

	# --- TEST E: meta_clicked su clic PULITO (senza hover/motion precedente sul link) ---
	_meta_hits.clear()
	var link_pos := _find_color(_capture(), func(c: Color) -> bool: return c.g > 0.5 and c.r < 0.3 and c.b < 0.3)
	print("link verde trovato a: ", link_pos)
	if link_pos.x < 0.0:
		_check("LINK_CLIC_PULITO", false, "link verde non trovato nell'immagine")
	else:
		_press(link_pos)
		await process_frame
		_release(link_pos)
		for k in range(5):
			await process_frame
		_check("LINK_CLIC_PULITO", _meta_hits.size() == 1, "meta_clicked scattato %d volte (atteso 1)" % _meta_hits.size())

	# --- esito ---
	if _fails.is_empty():
		print("RISULTATO: PASS (tutti i controlli superati)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	quit(0 if _fails.is_empty() else 1)

# Osserva N frame contando i pixel rossi; ritorna il numero di frame (dal 3o in poi)
# ancora "sporchi". Salva un PNG ai frame indicati.
func _watch_red(frames: int, tag: String, snap_a: int, snap_b: int) -> int:
	var dirty := 0
	var counts: Array = []
	for k in range(frames):
		await RenderingServer.frame_post_draw
		var img := _capture()
		var red := _count_red(img)
		counts.append(red)
		if red > 0 and k >= 2:
			dirty += 1
		if k == snap_a or k == snap_b:
			img.save_png(OUT_DIR + "/ghost_%s_frame%d.png" % [tag, k])
		await process_frame
	print("watch %s (60 frame): primi 12 = %s, sporchi dal 3o = %d" % [tag, str(counts.slice(0, 12)), dirty])
	return dirty

func _check(name: String, ok: bool, why: String) -> void:
	if ok:
		print("PASS  " + name)
	else:
		print("FAIL  " + name + " — " + why)
		_fails.append(name)

# --- input sintetici: stesso percorso di player._forward_to_os (push_input locale) ---

func _press(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_sub.push_input(ev, true)

func _release(pos: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = false
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = 0
	_sub.push_input(ev, true)

func _motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT
	_sub.push_input(ev, true)

# --- analisi immagine ---

func _capture() -> Image:
	return _sub.get_texture().get_image()

func _count_red(img: Image) -> int:
	var n := 0
	# campiona 1 pixel su 4 per velocita' (il conteggio resta proporzionale)
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			var c := img.get_pixel(x, y)
			if c.r > 0.85 and c.g < 0.25 and c.b < 0.25:
				n += 1
	return n

# Larghezza massima (max_x - min_x) dei pixel che soddisfano il predicato.
func _color_span(img: Image, pred: Callable) -> int:
	var minx := img.get_width()
	var maxx := -1
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if pred.call(img.get_pixel(x, y)):
				minx = mini(minx, x)
				maxx = maxi(maxx, x)
	return maxi(0, maxx - minx)

# Centro (baricentro) dei pixel che soddisfano il predicato; (-1,-1) se nessuno.
func _find_color(img: Image, pred: Callable) -> Vector2:
	var sx := 0.0
	var sy := 0.0
	var n := 0
	for y in range(0, img.get_height(), 4):
		for x in range(0, img.get_width(), 4):
			if pred.call(img.get_pixel(x, y)):
				sx += float(x)
				sy += float(y)
				n += 1
	if n == 0:
		return Vector2(-1, -1)
	return Vector2(sx / float(n), sy / float(n))
