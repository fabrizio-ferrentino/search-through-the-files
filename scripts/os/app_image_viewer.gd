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

# Aspetto della scritta-chiave: le costanti stanno in OSContent, perche' servono anche
# alla preparazione del nascondiglio (che deve sapere quanto sara' grande la scritta).
# Regolare li': CODE_SIZE_FACTOR (dimensione), CODE_ALPHA (trasparenza), CODE_TILT.

# Valori di default = identita' dello shader (vedi adjust.gdshader).
const DEFAULTS := {
	"brightness": 0.0,
	"contrast": 1.0,
	"saturation": 1.0,
	"black_point": 0.0,
	"white_point": 1.0,
	"detail": 0.0,
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
		_place_code(vp, data, code)

	var view := TextureRect.new()
	view.texture = vp.get_texture()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	view.material = _mat
	# Prelievi esatti per il passa-banda: niente pre-miscelatura dovuta al leggero
	# ingrandimento, e niente lettura oltre il bordo.
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
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
	col.add_theme_constant_override("separation", 18)   # 6 cursori nella finestra
	side.add_child(col)

	var title := Label.new()
	title.text = tr("IV_TITLE")
	col.add_child(title)

	_add_slider(col, tr("IV_BRIGHTNESS"), "brightness", -0.7, 0.7)
	_add_slider(col, tr("IV_CONTRAST"), "contrast", 0.2, 8.0)
	_add_slider(col, tr("IV_SATURATION"), "saturation", 0.0, 3.0)
	_add_slider(col, tr("IV_BLACK_POINT"), "black_point", 0.0, 0.95)
	_add_slider(col, tr("IV_WHITE_POINT"), "white_point", 0.05, 1.0)
	# Il passa-banda: separa la scritta dal dettaglio della foto per DIMENSIONE, non per
	# intensita' (vedi adjust.gdshader). E' lo strumento che rende la chiave trovabile su
	# qualsiasi foto, senza doverla ritoccare.
	_add_slider(col, tr("IV_SHARPNESS"), "detail", 0.0, 1.0)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var reset := Button.new()
	reset.text = tr("IV_RESET")
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(_reset)
	col.add_child(reset)

	if window:
		window.set_title(str(data.get("name", tr("IV_WINDOW"))))

# Posiziona la scritta-chiave nel SubViewport. Sceglie la zona piu' LISCIA della foto
# Sovrappone la scritta-chiave alla foto, DENTRO il SubViewport di composizione (foto +
# scritta insieme), cosi' i cursori agiscono su entrambe e il codice emerge solo
# regolando: non e' un livello separabile.
#
# Il NASCONDIGLIO non lo decide questa funzione: lo ha scelto OSContent._best_hiding_spot
# quando il run e' stato generato (la zona piu' liscia della foto, col colore medio e lo
# scarto scalato sul rumore di quella zona). Qui si disegna soltanto. Il motivo: i cursori
# amplificano scritta E dettaglio della foto nella stessa misura, quindi se lo scarto e'
# piu' debole del dettaglio locale la scritta non emerge a nessun valore.
func _place_code(vp: SubViewport, data: Dictionary, code: String) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = int(data.get("code_seed", 0))
	var vps := Vector2(vp.size)
	var fsize: int = maxi(10, int(vps.y * OSContent.CODE_SIZE_FACTOR))
	var font := Win95.font("sans")
	var tsz := font.get_string_size(code, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)

	var base: Color = data.get("code_base", Color(0.5, 0.5, 0.5))
	var delta: float = float(data.get("code_delta", OSContent.CODE_DELTA_MIN))
	# Verso dello scarto: si schiarisce sui fondi scuri, si scurisce su quelli chiari
	# (altrimenti a caso, stabile per run). Diviso per l'opacita': quello che conta e'
	# lo scarto del risultato COMPOSTO, e la Label e' semi-trasparente.
	var lum: float = (base.r + base.g + base.b) / 3.0
	var segno := 1.0
	if lum > 0.75:
		segno = -1.0
	elif lum >= 0.25 and r.randf() < 0.5:
		segno = -1.0
	var d: float = segno * delta / maxf(0.05, OSContent.CODE_ALPHA)
	var c := Color(clampf(base.r + d, 0, 1), clampf(base.g + d, 0, 1), clampf(base.b + d, 0, 1))
	c.a = OSContent.CODE_ALPHA   # semi-trasparente: la foto traspare, niente "macchia" piatta

	# posizione scelta in fase di generazione, tenuta dentro i bordi della foto
	var uv: Vector2 = data.get("code_uv", Vector2(0.5, 0.5))
	var mx: float = minf(0.45, (tsz.x * 0.5) / maxf(1.0, vps.x) + 0.03)
	var my: float = minf(0.45, (tsz.y * 0.5) / maxf(1.0, vps.y) + 0.04)
	uv.x = clampf(uv.x, mx, 1.0 - mx)
	uv.y = clampf(uv.y, my, 1.0 - my)

	var lbl := Label.new()
	lbl.text = code
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", c)
	lbl.size = tsz
	lbl.pivot_offset = tsz * 0.5
	lbl.position = uv * vps - tsz * 0.5
	lbl.rotation = deg_to_rad(r.randf_range(-OSContent.CODE_TILT, OSContent.CODE_TILT))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(lbl)

# Dimensione del SubViewport: aspetto della foto, rimpicciolito per stare entro maxv
# (mai ingrandito oltre l'originale).
func _fit_size(src: Vector2, maxv: Vector2) -> Vector2i:
	if src.x <= 1 or src.y <= 1:
		return Vector2i(320, 240)
	var s: float = minf(1.0, minf(maxv.x / src.x, maxv.y / src.y))
	return Vector2i(maxi(8, int(src.x * s)), maxi(8, int(src.y * s)))

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
