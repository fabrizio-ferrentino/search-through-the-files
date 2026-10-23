class_name FpsCounter
extends CanvasLayer

# DEV-ONLY: il contatore degli FPS in alto a destra. Lo crea GameManager solo nelle build
# di debug (editor ed export di debug), sulla radice: resta visibile nel menu, in stanza e
# dentro il PC. Testo di debug = inglese. Non prende il mouse.

const AGGIORNA := 0.25   # secondi fra un aggiornamento e l'altro (un numero leggibile, non che balla)

var _label: Label
var _attesa := 0.0

func _ready() -> void:
	layer = 70   # sopra tutto, anche sopra la pausa (60)
	process_mode = Node.PROCESS_MODE_ALWAYS   # conta anche in pausa
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_label.offset_left = -160
	_label.offset_right = -8
	_label.offset_top = 6
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 4)
	add_child(_label)
	_label.text = "FPS --"   # al primo frame il conteggio non c'e' ancora (dava "FPS 1" in rosso)

func _process(delta: float) -> void:
	_attesa += delta
	if _attesa >= AGGIORNA:
		_attesa = 0.0
		_aggiorna()

func _aggiorna() -> void:
	var fps: float = Engine.get_frames_per_second()
	_label.text = "FPS %d" % int(fps)
	# verde sopra 55, giallo sopra 30, rosso sotto: si vede al volo quando cala
	var c := Color(0.4, 1.0, 0.4)
	if fps < 30.0:
		c = Color(1.0, 0.35, 0.3)
	elif fps < 55.0:
		c = Color(1.0, 0.85, 0.3)
	_label.add_theme_color_override("font_color", c)
