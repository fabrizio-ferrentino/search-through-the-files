extends Control

# STRUMENTO DI SVILUPPO (non un test, non fa parte del gioco): il "laboratorio foto".
# A destra il visualizzatore VERO del gioco (ImageViewerApp, stessi cursori e stesso shader);
# a sinistra si sceglie la foto e la ricetta (un cursore + un verso) e si regolano dal vivo
# i numeri di gusto della scritta (da dove a dove emerge, il ripiego della regolazione forte,
# forza e opacita'). Quando un valore convince si riporta a mano in app_image_viewer.gd.
# Testo in inglese: e' testo da sviluppatore (regola 8 di CLAUDE.md).
#
#   & $godot --path $proj res://tests/photo_lab.tscn

var _files: Array = []
var _codice := ""
var _nodo: Dictionary = {}
var _ricetta: Array = []
var _app: ImageViewerApp
var _host: Control
var _info: Label
var _scelta: OptionButton
var _seme_ric: SpinBox
var _px: HSlider
var _py: HSlider
var _rot: SpinBox
var _dir_inizio: HSlider
var _dir_pieno: HSlider
var _tot_inizio: HSlider
var _tot_pieno: HSlider
var _forza: HSlider
var _opacita: HSlider
var _occupato := false

func _ready() -> void:
	theme = Win95.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	GameManager.start_new_run(12345)
	_codice = GameManager.key_label(OSContent.KEY_IMAGE)
	_files = OSContent._photo_files()

	var fondo := ColorRect.new()
	fondo.color = Win95.C_FACE
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)
	var riga := HBoxContainer.new()
	riga.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	riga.add_theme_constant_override("separation", 10)
	add_child(riga)
	var scorri := ScrollContainer.new()
	scorri.custom_minimum_size = Vector2(320, 0)
	scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	riga.add_child(scorri)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 4)
	scorri.add_child(col)
	_host = Control.new()
	_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	riga.add_child(_host)

	col.add_child(_testo("PHOTO LAB  (code %s)" % _codice))
	_scelta = OptionButton.new()
	for f in _files:
		_scelta.add_item(str(f).get_file())
	_scelta.item_selected.connect(func(_i: int): _nuova_ricetta())
	col.add_child(_scelta)
	var nav := HBoxContainer.new()
	col.add_child(nav)
	nav.add_child(_bottone("< Prev", func(): _sposta(-1)))
	nav.add_child(_bottone("Next >", func(): _sposta(1)))

	col.add_child(_testo("Recipe seed (another slider/direction)"))
	_seme_ric = _numero(col, 0, 9999, func(): _nuova_ricetta())
	col.add_child(_bottone("Show the solution (right slider to the end)", _soluzione))
	col.add_child(_bottone("Reset the viewer's sliders", func(): _app._reset()))

	col.add_child(_testo("\nWHERE"))
	col.add_child(_testo("Position X / Y"))
	_px = _cursore(col, 0.0, 1.0, 0.01)
	_py = _cursore(col, 0.0, 1.0, 0.01)
	col.add_child(_testo("Rotation seed"))
	_rot = _numero(col, 0, 999, func(): _ricostruisci())

	col.add_child(_testo("\nTASTE (live; copy good values into app_image_viewer.gd)"))
	_dir_inizio = _cursore_etichettato(col, "DIR_INIZIO (right slider: starts showing at)", 0.0, 0.9, 0.01, ImageViewerApp.DIR_INIZIO)
	_dir_pieno = _cursore_etichettato(col, "DIR_PIENO (right slider: fully shown at)", 0.1, 1.0, 0.01, ImageViewerApp.DIR_PIENO)
	_tot_inizio = _cursore_etichettato(col, "TOT_INIZIO (fallback, all sliders: starts at)", 0.5, 4.0, 0.05, ImageViewerApp.TOT_INIZIO)
	_tot_pieno = _cursore_etichettato(col, "TOT_PIENO (fallback, all sliders: full at)", 0.6, 5.0, 0.05, ImageViewerApp.TOT_PIENO)
	_forza = _cursore_etichettato(col, "CODE_FORZA (colour step when fully shown)", 0.02, 0.6, 0.01, ImageViewerApp.CODE_FORZA)
	_opacita = _cursore_etichettato(col, "CODE_OPACITA (opacity when fully shown)", 0.05, 1.0, 0.01, ImageViewerApp.CODE_OPACITA)

	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_info)

	if _files.is_empty():
		_info.text = "No photos in " + OSContent.PHOTO_DIR
		return
	_nuova_ricetta()

func _process(_d: float) -> void:
	if _app == null or _ricetta.is_empty():
		return
	var valori := {}
	for e in _app._sliders:
		valori[e["param"]] = (e["node"] as HSlider).value
	var r := ImageViewerApp.rivelazione(_ricetta, valori)
	_info.text = "\nRECIPE: %s\n\nRevealed now: %d%%\n\nAt rest the code must NOT be there. Pushing the right slider the right way brings it out gradually. Fallback: pushing several sliders hard brings it out too." % [
			OSContent.ricetta_testo(_ricetta), roundi(r * 100.0)]

func _testo(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _bottone(t: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	return b

func _numero(parent: Control, a: int, b: int, cb: Callable) -> SpinBox:
	var n := SpinBox.new()
	n.min_value = a
	n.max_value = b
	n.value_changed.connect(func(_v: float): cb.call())
	parent.add_child(n)
	return n

func _cursore(parent: Control, a: float, b: float, passo: float) -> HSlider:
	var s := HSlider.new()
	s.min_value = a
	s.max_value = b
	s.step = passo
	s.value_changed.connect(func(_v: float): _ricostruisci())
	parent.add_child(s)
	return s

func _cursore_etichettato(parent: Control, nome: String, a: float, b: float, passo: float, v: float) -> HSlider:
	var l := _testo("")
	parent.add_child(l)
	var s := _cursore(parent, a, b, passo)
	s.value_changed.connect(func(x: float): l.text = "%s: %.2f" % [nome, x])
	s.value = v
	l.text = "%s: %.2f" % [nome, v]
	return s

func _sposta(d: int) -> void:
	_scelta.select(posmod(_scelta.selected + d, _files.size()))
	_nuova_ricetta()

# Ricetta e punto come li sceglierebbe il gioco (seme del laboratorio).
func _nuova_ricetta() -> void:
	var path := str(_files[maxi(0, _scelta.selected)])
	_nodo = {"name": path.get_file(), "type": "file", "icon": "image", "filetype": "image",
			"path": path, "code": _codice}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_seme_ric.value) + 1
	var img := OSContent._scan_image(_nodo)
	var spot := {}
	for i in range(30):   # come il gioco: una ricetta che brucia la zona si risorteggia
		_ricetta = OSContent._ricetta(rng)
		spot = OSContent._punto_codice(img, _ricetta, rng)
		if float(spot.get("stacco", 1.0)) >= OSContent.CODE_STACCO_MIN:
			break
	_nodo["ricetta"] = _ricetta
	_occupato = true
	_px.value = (spot["uv"] as Vector2).x
	_py.value = (spot["uv"] as Vector2).y
	_occupato = false
	_ricostruisci()

func _ricostruisci() -> void:
	if _occupato or _nodo.is_empty():
		return
	ImageViewerApp.DIR_INIZIO = _dir_inizio.value
	ImageViewerApp.DIR_PIENO = maxf(_dir_pieno.value, _dir_inizio.value + 0.01)
	ImageViewerApp.TOT_INIZIO = _tot_inizio.value
	ImageViewerApp.TOT_PIENO = maxf(_tot_pieno.value, _tot_inizio.value + 0.05)
	ImageViewerApp.CODE_FORZA = _forza.value
	ImageViewerApp.CODE_OPACITA = _opacita.value
	var img := OSContent._scan_image(_nodo)
	var uv := Vector2(_px.value, _py.value)
	_nodo["code_uv"] = uv
	if img != null:
		var dim := Vector2(img.get_size())
		var box_dim := Vector2i(int(dim.x * 0.22), int(dim.y * 0.14))
		_nodo["code_base"] = OSContent._box_stats(img, Rect2i(Vector2i(uv * dim) - box_dim / 2, box_dim))["avg"]
	_nodo["code_seed"] = int(_rot.value)

	# i cursori del visualizzatore restano dove li ha messi l'utente
	var valori: Array = []
	if _app != null:
		for e in _app._sliders:
			valori.append((e["node"] as HSlider).value)
		_app.queue_free()
	_app = ImageViewerApp.new()
	_host.add_child(_app)
	_app.launch(_nodo)
	for i in range(mini(valori.size(), _app._sliders.size())):
		(_app._sliders[i]["node"] as HSlider).value = valori[i]
	_app._aggiorna_codice()

func _soluzione() -> void:
	_app._reset()
	var p := str(_ricetta[0]["param"])
	for e in _app._sliders:
		if str(e["param"]) == p:
			(e["node"] as HSlider).value = ImageViewerApp.valore_a(p, 1.0 if int(_ricetta[0]["verso"]) > 0 else 0.0)
