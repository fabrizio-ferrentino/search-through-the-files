class_name ImageViewerApp
extends Control

# Visualizzatore immagini con strumenti di regolazione (M3 parte 3). Apre una "foto"
# del run e la mostra con uno ShaderMaterial (adjust.gdshader) pilotato da cursori:
# luminosita', contrasto, saturazione, livelli, nitidezza.
#
# La foto che nasconde la chiave ha una RICETTA segreta (27/11/2026, scelta del
# proprietario): UN cursore e una DIREZIONE, sorteggiati per partita. A riposo la scritta non
# c'e' proprio (opacita' zero, nessuna filigrana); piu' si spinge quel cursore in quel verso,
# piu' emerge, senza un valore preciso da trovare. Ripiego: alterare MOLTO la foto con
# qualunque cursore la fa emergere lo stesso, cosi' nessuno resta bloccato. (Una prima
# versione voleva due cursori su bersagli precisi: "troppo complicato da capire", scartata.)
# Prima ancora la scritta era sempre presente e debole, sperando che un filtro la separasse
# dalla trama: misurato, su foto vere o si vedeva subito o non si leggeva mai.
# Foto e scritta sono COMPOSTE in un SubViewport e lo shader agisce sull'insieme: la
# scritta si comporta come parte dell'immagine. Le altre foto sono esche.
var os
var window

var _mat: ShaderMaterial
var _sliders: Array = []   # [{ "node": HSlider, "default": float, "param": String }]
var _data: Dictionary = {}
var _lbl: Label = null       # la scritta-chiave, se questa foto e' la portatrice

# Valori di default = identita' dello shader (vedi adjust.gdshader).
const DEFAULTS := {
	"brightness": 0.0,
	"contrast": 1.0,
	"saturation": 1.0,
	"black_point": 0.0,
	"white_point": 1.0,
	"detail": 0.0,
}
# Corsa di ogni cursore: la ricetta ragiona in posizione 0..1 lungo questa corsa.
const CORSE := {
	"brightness": Vector2(-0.7, 0.7),
	"contrast": Vector2(0.2, 8.0),
	"saturation": Vector2(0.0, 3.0),
	"black_point": Vector2(0.0, 0.95),
	"white_point": Vector2(0.05, 1.0),
	"detail": Vector2(0.0, 1.0),
}
# Versi ammessi per ogni cursore: quelli che non appiattiscono la foto (contrasto in giu'
# o i livelli verso il centro spegnerebbero anche la scritta).
const VERSI := {
	"brightness": [1, -1],
	"contrast": [1],
	"saturation": [1, -1],
	"black_point": [1],
	"white_point": [-1],
	"detail": [1],
}
# --- Quanto si vede (REGOLA QUI; si provano dal vivo con tests/photo_lab.tscn) ---
# (static var e non const solo perche' il laboratorio le regola dal vivo; nel gioco non cambiano)
static var DIR_INIZIO := 0.15   # avanzamento del cursore giusto (0..1 del suo lato) dove comincia
static var DIR_PIENO := 0.75    # ... e dove la scritta e' piena
static var TOT_INIZIO := 1.2    # ripiego: somma degli spostamenti di TUTTI i cursori dove comincia
static var TOT_PIENO := 2.5     # ... e dove e' piena (un cursore solo, anche in fondo, fa al piu' 1.0)
static var CODE_FORZA := 0.30   # scarto di colore della scritta a rivelazione piena
static var CODE_OPACITA := 0.85 # opacita' della scritta a rivelazione piena

# Posizione 0..1 di un valore lungo la corsa del suo cursore.
static func posizione(param: String, valore: float) -> float:
	var c: Vector2 = CORSE[param]
	return clampf((valore - c.x) / (c.y - c.x), 0.0, 1.0)

static func valore_a(param: String, pos: float) -> float:
	var c: Vector2 = CORSE[param]
	return lerpf(c.x, c.y, pos)

# Quanto ha spinto il cursore giusto nel verso giusto: 0 al default, 1 in fondo a quel lato.
static func avanzamento(ingrediente: Dictionary, valori: Dictionary) -> float:
	var p := str(ingrediente["param"])
	var d := posizione(p, float(DEFAULTS[p]))
	var x := posizione(p, float(valori.get(p, DEFAULTS[p])))
	if int(ingrediente["verso"]) > 0:
		return clampf((x - d) / maxf(1.0 - d, 0.001), 0.0, 1.0)
	return clampf((d - x) / maxf(d, 0.001), 0.0, 1.0)

# Quanto e' rivelata la scritta (0..1) coi cursori a "valori" ({param: valore}).
# ricetta = [{ "param", "verso" }]: il cursore giusto, oppure il ripiego, il piu' alto dei due.
static func rivelazione(ricetta: Array, valori: Dictionary) -> float:
	var r := 0.0
	for ing in ricetta:
		r = maxf(r, smoothstep(DIR_INIZIO, DIR_PIENO, avanzamento(ing, valori)))
	var tot := 0.0
	for p in DEFAULTS:
		tot += absf(posizione(p, float(valori.get(p, DEFAULTS[p]))) - posizione(p, float(DEFAULTS[p])))
	return maxf(r, smoothstep(TOT_INIZIO, TOT_PIENO, tot))

# La parte PUNTO PER PUNTO dello shader, sulla luminanza (la saturazione non la cambia):
# serve a scegliere un punto e un verso della scritta che ai valori della ricetta non
# finiscano bruciati nel bianco o nel nero. La nitidezza non e' puntuale e si ignora.
static func luma_regolata(l: float, valori: Dictionary) -> float:
	var bp: float = float(valori.get("black_point", 0.0))
	var wp: float = float(valori.get("white_point", 1.0))
	var c: float = (l - bp) / maxf(wp - bp, 0.001)
	c += float(valori.get("brightness", 0.0))
	c = (c - 0.5) * float(valori.get("contrast", 1.0)) + 0.5
	return clampf(c, 0.0, 1.0)

# I valori dei cursori quando la scritta e' appena piena: il cursore giusto spinto fino a
# DIR_PIENO nel suo verso, gli altri al default.
static func valori_ricetta(ricetta: Array) -> Dictionary:
	var v := DEFAULTS.duplicate()
	for ing in ricetta:
		var p := str(ing["param"])
		var d := posizione(p, float(DEFAULTS[p]))
		var lato: float = (1.0 - d) if int(ing["verso"]) > 0 else d
		v[p] = valore_a(p, d + float(ing["verso"]) * DIR_PIENO * lato)
	return v

# Verso dello scarto (+1 schiarisce, -1 scurisce) che ai valori della ricetta si vede di piu'.
static func verso_migliore(base_l: float, ricetta: Array) -> float:
	var v := valori_ricetta(ricetta)
	var su: float = absf(luma_regolata(clampf(base_l + CODE_FORZA, 0.0, 1.0), v) - luma_regolata(base_l, v))
	var giu: float = absf(luma_regolata(clampf(base_l - CODE_FORZA, 0.0, 1.0), v) - luma_regolata(base_l, v))
	return 1.0 if su >= giu else -1.0

func launch(node) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var data: Dictionary = node if node is Dictionary else {}
	_data = data

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
		_place_code(vp, data, code)   # "trovata" per le statistiche solo quando si legge

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
	# Prima era un Panel con la colonna a offset fissi: la colonna non contava nella misura
	# della finestra e, appena la finestra era piu' bassa dei cursori, "Ripristina" e gli
	# ultimi cursori uscivano tagliati. Ora la colonna sta in uno ScrollContainer: se non
	# c'e' posto compare la barra di scorrimento, come nei pannelli di Windows 95.
	var side := PanelContainer.new()
	side.add_theme_stylebox_override("panel", Win95._sb(true, Win95.C_FACE, true, 10, 10, 10, 10))
	side.custom_minimum_size = Vector2(210, 0)
	root.add_child(side)
	var scorri := ScrollContainer.new()
	scorri.name = "Scorri"
	scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side.add_child(scorri)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL   # con posto, "Ripristina" va in fondo
	col.add_theme_constant_override("separation", 6)
	# un margine a destra: quando compare, la barra di scorrimento non tocca i cursori
	var aria_barra := MarginContainer.new()
	aria_barra.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aria_barra.size_flags_vertical = Control.SIZE_EXPAND_FILL
	aria_barra.add_theme_constant_override("margin_right", 12)
	scorri.add_child(aria_barra)
	aria_barra.add_child(col)

	var title := Label.new()
	title.text = tr("IV_TITLE")
	col.add_child(title)

	_add_slider(col, tr("IV_BRIGHTNESS"), "brightness")
	_add_slider(col, tr("IV_CONTRAST"), "contrast")
	_add_slider(col, tr("IV_SATURATION"), "saturation")
	_add_slider(col, tr("IV_BLACK_POINT"), "black_point")
	_add_slider(col, tr("IV_WHITE_POINT"), "white_point")
	# il passa-banda (vedi adjust.gdshader): uno dei possibili ingredienti della ricetta
	_add_slider(col, tr("IV_SHARPNESS"), "detail")

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)

	var reset := Button.new()
	reset.name = "Ripristina"
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
	var ricetta: Array = data.get("ricetta", [])
	# Verso dello scarto: quello che ai valori della ricetta resta piu' leggibile.
	var d: float = verso_migliore((base.r + base.g + base.b) / 3.0, ricetta) * CODE_FORZA
	var c := Color(clampf(base.r + d, 0, 1), clampf(base.g + d, 0, 1), clampf(base.b + d, 0, 1))

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
	lbl.modulate.a = 0.0   # a riposo non c'e': la fa comparire solo la ricetta
	vp.add_child(lbl)
	_lbl = lbl

# Ricalcola quanto si vede la scritta dai cursori attuali.
func _aggiorna_codice() -> void:
	if _lbl == null:
		return
	var valori := {}
	for e in _sliders:
		valori[e["param"]] = (e["node"] as HSlider).value
	var r := rivelazione(_data.get("ricetta", []), valori)
	_lbl.modulate.a = CODE_OPACITA * r
	if r >= 0.6:
		GameManager.scopri_in(_lbl.text)

# Dimensione del SubViewport: aspetto della foto, rimpicciolito per stare entro maxv
# (mai ingrandito oltre l'originale).
func _fit_size(src: Vector2, maxv: Vector2) -> Vector2i:
	if src.x <= 1 or src.y <= 1:
		return Vector2i(320, 240)
	var s: float = minf(1.0, minf(maxv.x / src.x, maxv.y / src.y))
	return Vector2i(maxi(8, int(src.x * s)), maxi(8, int(src.y * s)))

func _add_slider(parent: VBoxContainer, text: String, param: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # un nome lungo va a capo, non esce
	parent.add_child(lbl)
	var s := HSlider.new()
	s.min_value = (CORSE[param] as Vector2).x
	s.max_value = (CORSE[param] as Vector2).y
	s.step = 0.01
	s.value = float(DEFAULTS[param])
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(func(value: float):
		_mat.set_shader_parameter(param, value)
		_aggiorna_codice())
	parent.add_child(s)
	var aria := Control.new()   # stacco fra un cursore e il nome del successivo
	aria.custom_minimum_size = Vector2(0, 8)
	parent.add_child(aria)
	_sliders.append({"node": s, "default": float(DEFAULTS[param]), "param": param})

# Riporta cursori e shader ai valori di default (l'immagine torna "non regolata").
func _reset() -> void:
	for entry in _sliders:
		(entry["node"] as HSlider).value = float(entry["default"])
