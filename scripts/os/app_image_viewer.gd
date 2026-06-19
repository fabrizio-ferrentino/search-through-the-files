class_name ImageViewerApp
extends Control

# Visualizzatore immagini con strumenti di regolazione (M3 parte 3). Apre una "foto"
# del run e la mostra con uno ShaderMaterial (adjust.gdshader) pilotato da cursori:
# luminosita', contrasto, saturazione, livelli.
#
# La foto che nasconde una chiave la mostra come scritta a bassissimo contrasto,
# posizionata e ruotata a caso (seme stabile per run). Foto e scritta vengono
# COMPOSTE in un SubViewport e lo shader agisce sull'insieme: cosi' la scritta e'
# invisibile all'apertura e si comporta come parte dell'immagine, emergendo solo
# regolando (non e' un livello separabile). Le altre foto sono esche.
var os
var window

var _mat: ShaderMaterial
var _sliders: Array = []   # [{ "node": HSlider, "default": float }]

# --- Aspetto della scritta-chiave (REGOLA QUI) ---
# Dimensione: frazione dell'altezza della foto. Piu' basso = scritta piu' piccola.
const CODE_SIZE_FACTOR := 0.08
# Trasparenza: piu' basso = piu' mimetizzata. Sotto 1 la foto TRASPARE attraverso la
# scritta, cosi' su foto reali (con dettaglio) non resta una "macchia" piatta opaca.
# (Troppo basso pero' la rende difficile da trovare anche regolando: 0.6 e' un buon punto.)
const CODE_ALPHA := 0.6

# Valori di default = identita' dello shader (vedi adjust.gdshader).
const DEFAULTS := {
	"brightness": 0.0,
	"contrast": 1.0,
	"saturation": 1.0,
	"black_point": 0.0,
	"white_point": 1.0,
}

func launch(node) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var data: Dictionary = node if node is Dictionary else {}

	_mat = ShaderMaterial.new()
	_mat.shader = load("res://scripts/os/adjust.gdshader")
	for k in DEFAULTS:
		_mat.set_shader_parameter(k, DEFAULTS[k])

	var root := HBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 6)
	add_child(root)

	# --- area immagine (campo incassato) ---
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", Win95._sb(false, Color("303030"), true, 4, 4, 4, 4))
	frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(frame)

	var display := Control.new()
	display.set_anchors_preset(Control.PRESET_FULL_RECT)
	display.offset_left = 4
	display.offset_top = 4
	display.offset_right = -4
	display.offset_bottom = -4
	display.clip_contents = true
	frame.add_child(display)

	var photo_tex := OSContent.make_photo(data)

	# SubViewport: compone foto + (eventuale) scritta-chiave a dimensione fissa, cosi'
	# posizione/rotazione sono in pixel-foto (indipendenti dallo scaling a video) e lo
	# shader, applicato alla texture del viewport, regola foto e scritta insieme.
	var vp := SubViewport.new()
	vp.size = _fit_size(photo_tex.get_size() if photo_tex else Vector2(320, 240), Vector2(640, 480))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.transparent_bg = false
	vp.gui_disable_input = true
	add_child(vp)

	var inner := TextureRect.new()
	inner.texture = photo_tex
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	inner.stretch_mode = TextureRect.STRETCH_SCALE
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(inner)

	var code := str(data.get("code", ""))
	if code != "":
		_place_code(vp, photo_tex, data, code)

	var view := TextureRect.new()
	view.texture = vp.get_texture()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.material = _mat
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.add_child(view)

	# --- pannello regolazioni ---
	var side := Panel.new()
	side.add_theme_stylebox_override("panel", Win95._sb(true, Win95.C_FACE, true, 8, 8, 8, 8))
	side.custom_minimum_size = Vector2(210, 0)
	root.add_child(side)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 10
	col.offset_top = 10
	col.offset_right = -10
	col.offset_bottom = -10
	col.add_theme_constant_override("separation", 25)
	side.add_child(col)

	var title := Label.new()
	title.text = "Regolazioni immagine"
	col.add_child(title)

	_add_slider(col, "Luminosita'", "brightness", -0.7, 0.7)
	_add_slider(col, "Contrasto", "contrast", 0.2, 8.0)
	_add_slider(col, "Saturazione", "saturation", 0.0, 3.0)
	_add_slider(col, "Punto nero", "black_point", 0.0, 0.95)
	_add_slider(col, "Punto bianco", "white_point", 0.05, 1.0)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var reset := Button.new()
	reset.text = "Reimposta"
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_reset)
	col.add_child(reset)

	if window:
		window.set_title(str(data.get("name", "Visualizzatore immagini")))

# Posiziona la scritta-chiave nel SubViewport. Sceglie la zona piu' LISCIA della foto
# (minor dettaglio) fra alcuni candidati (seme stabile per run): su un'area piatta la
# scritta e' invisibile all'apertura E si rivela regolando; su un'area di dettaglio si
# noterebbe e non si rivelerebbe. Colore = media locale +/- un piccolo scarto, semi-
# trasparente cosi' la foto traspare.
func _place_code(vp: SubViewport, photo_tex: Texture2D, data: Dictionary, code: String) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(data.get("code_seed", 0))
	var vps := Vector2(vp.size)
	var fsize: int = maxi(10, int(vps.y * CODE_SIZE_FACTOR))
	var font := ThemeDB.fallback_font
	var tsz := font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	# margini per non far uscire la scritta (con un extra per la rotazione)
	var mx: float = minf(0.45, (tsz.x * 0.5) / vps.x * 1.3 + 0.04)
	var my: float = minf(0.45, (tsz.y * 0.5) / vps.y * 1.3 + 0.06)

	# fra alcuni candidati, scegli quello con meno dettaglio (varianza piu' bassa)
	var img := _photo_image(photo_tex)
	var u := 0.5
	var v := 0.5
	var base := Color(0.5, 0.5, 0.5)
	var best_var := INF
	for _i in range(14):
		var cu: float = r.randf_range(mx, 1.0 - mx)
		var cv: float = r.randf_range(my, 1.0 - my)
		var st := _region_stats(img, cu, cv)
		if float(st["variance"]) < best_var:
			best_var = float(st["variance"])
			u = cu
			v = cv
			base = st["avg"]

	var d: float = OSContent.PHOTO_KEY_DELTA * (1.0 if r.randf() < 0.5 else -1.0)
	var c := Color(clampf(base.r + d, 0, 1), clampf(base.g + d, 0, 1), clampf(base.b + d, 0, 1))
	c.a = CODE_ALPHA   # semi-trasparente: la foto traspare, niente "macchia" piatta

	var lbl := Label.new()
	lbl.text = code
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", c)
	lbl.size = tsz
	lbl.pivot_offset = tsz * 0.5
	lbl.position = Vector2(u, v) * vps - tsz * 0.5
	lbl.rotation = deg_to_rad(r.randf_range(-12.0, 12.0))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(lbl)

# Dimensione del SubViewport: aspetto della foto, rimpicciolito per stare entro maxv
# (mai ingrandito oltre l'originale).
func _fit_size(src: Vector2, maxv: Vector2) -> Vector2i:
	if src.x <= 1 or src.y <= 1:
		return Vector2i(320, 240)
	var s: float = minf(1.0, minf(maxv.x / src.x, maxv.y / src.y))
	return Vector2i(maxi(8, int(src.x * s)), maxi(8, int(src.y * s)))

# Decomprime la foto in un Image una volta sola (gestisce le texture compresse).
func _photo_image(tex: Texture2D) -> Image:
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img = img.duplicate() as Image
	if img.is_compressed() and img.decompress() != OK:
		return null
	return img

# Statistiche locali attorno a (u,v): colore medio (per mimetizzare il testo) e varianza
# di luminanza (quanto e' "dettagliata" la zona: bassa = liscia = buon nascondiglio).
func _region_stats(img: Image, u: float, v: float) -> Dictionary:
	if img == null:
		return {"avg": Color(0.5, 0.5, 0.5), "variance": 0.0}
	var w := img.get_width()
	var h := img.get_height()
	var cxp := int(clampf(u, 0, 1) * (w - 1))
	var cyp := int(clampf(v, 0, 1) * (h - 1))
	var rad: int = maxi(2, int(min(w, h) * 0.06))
	var step: int = maxi(1, (rad * 2) / 24)
	var sr := 0.0
	var sg := 0.0
	var sb := 0.0
	var sl := 0.0
	var sl2 := 0.0
	var n := 0
	for y in range(maxi(0, cyp - rad), mini(h, cyp + rad), step):
		for x in range(maxi(0, cxp - rad), mini(w, cxp + rad), step):
			var col := img.get_pixel(x, y)
			sr += col.r
			sg += col.g
			sb += col.b
			var l := (col.r + col.g + col.b) / 3.0
			sl += l
			sl2 += l * l
			n += 1
	if n == 0:
		return {"avg": Color(0.5, 0.5, 0.5), "variance": 0.0}
	var mean_l := sl / n
	return {"avg": Color(sr / n, sg / n, sb / n), "variance": maxf(0.0, sl2 / n - mean_l * mean_l)}

# Crea una riga "etichetta + cursore" legata a un uniforme dello shader.
func _add_slider(parent: VBoxContainer, text: String, param: String, minv: float, maxv: float) -> void:
	var lbl := Label.new()
	lbl.text = text
	parent.add_child(lbl)
	var s := HSlider.new()
	s.min_value = minv
	s.max_value = maxv
	s.step = 0.01
	s.value = float(DEFAULTS[param])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(value: float): _mat.set_shader_parameter(param, value))
	parent.add_child(s)
	_sliders.append({"node": s, "default": float(DEFAULTS[param])})

# Riporta cursori e shader ai valori di default (l'immagine torna "non regolata").
func _reset() -> void:
	for entry in _sliders:
		(entry["node"] as HSlider).value = float(entry["default"])
