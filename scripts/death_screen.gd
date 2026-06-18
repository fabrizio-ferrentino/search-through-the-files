extends CanvasLayer

# Overlay di morte (M2): jumpscare placeholder -> schermata GAME OVER -> menu.
# Costruito interamente in codice. Vive sopra tutto (stanza E PC): lo aggiunge alla
# radice dell'albero GameManager.game_over(). Audio dello stinger: TODO (audio = M6).

var cause: String = ""          # chi/cosa ha ucciso il giocatore (gancio per M4)

const JUMPSCARE_TIME := 1.2

# Sottotitoli placeholder. In futuro varieranno in base al fantasma (cause).
const SUBTITLES := [
	"Non dovevi distogliere lo sguardo.",
	"Ti osservava da prima che te ne accorgessi.",
	"Il segnale si e' spento. Anche il tuo.",
	"Qualcosa, dentro lo schermo, ti ha visto.",
	"A 52 Hz non risponde mai nessuno.",
	"La stanza non era cosi' vuota.",
]

# Battute specifiche del Clown (M4): scelte quando cause == "clown".
const CLOWN_SUBTITLES := [
	"Il sorriso era l'ultima cosa che hai visto.",
	"Non dovevi smettere di guardare il corridoio.",
	"E' arrivato in fondo mentre tu leggevi.",
	"Avresti dovuto guardarlo negli occhi.",
]

var _shake := false
var _shake_amt := 0.0

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS   # l'overlay gira anche col gioco in pausa
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true                  # congela stanza e OS durante la morte
	_play_jumpscare()

func _process(_delta: float) -> void:
	# tremolio dello schermo durante il jumpscare
	if _shake:
		offset = Vector2(randf_range(-_shake_amt, _shake_amt), randf_range(-_shake_amt, _shake_amt))

# ---------------- fase 1: jumpscare ----------------
func _play_jumpscare() -> void:
	var root := Control.new()
	root.name = "Jumpscare"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP   # blocca l'input
	add_child(root)

	# flash rosso/nero stroboscopico
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(0.65, 0.0, 0.0)
	root.add_child(flash)
	var strobe := create_tween().set_loops()
	strobe.tween_property(flash, "color", Color(0.7, 0.02, 0.02), 0.05)
	strobe.tween_property(flash, "color", Color(0.04, 0.0, 0.0), 0.05)

	# faccia disegnata che "zooma" addosso
	var face := Control.new()
	face.size = Vector2(460, 520)
	face.pivot_offset = face.size * 0.5
	face.position = (Vector2(1920, 1080) - face.size) * 0.5
	face.scale = Vector2(0.5, 0.5)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face.draw.connect(_draw_face.bind(face))
	root.add_child(face)
	face.queue_redraw()

	# glitch sopra a tutto
	var fx := ColorRect.new()
	fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/os/glitch.gdshader")
	mat.set_shader_parameter("intensity", 0.7)
	fx.material = mat
	root.add_child(fx)

	_shake = true
	_shake_amt = 16.0

	# la "zoomata" della faccia scandisce la durata del jumpscare; al termine del
	# tween -> schermata GAME OVER (uso il callback del tween, non un timer).
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(face, "scale", Vector2(1.7, 1.7), JUMPSCARE_TIME)
	tw.tween_callback(func():
		strobe.kill()
		_shake = false
		offset = Vector2.ZERO
		root.queue_free()
		_show_gameover())

# Faccia placeholder disegnata a mano (testa pallida, occhi vuoti, bocca frastagliata).
func _draw_face(c: Control) -> void:
	var w := c.size.x
	var h := c.size.y
	c.draw_rect(Rect2(w * 0.12, h * 0.06, w * 0.76, h * 0.88), Color(0.86, 0.84, 0.80))
	c.draw_circle(Vector2(w * 0.34, h * 0.36), w * 0.10, Color.BLACK)
	c.draw_circle(Vector2(w * 0.66, h * 0.36), w * 0.10, Color.BLACK)
	c.draw_circle(Vector2(w * 0.34, h * 0.36), w * 0.03, Color(0.85, 0, 0))
	c.draw_circle(Vector2(w * 0.66, h * 0.36), w * 0.03, Color(0.85, 0, 0))
	var mouth := PackedVector2Array([
		Vector2(w * 0.30, h * 0.62), Vector2(w * 0.38, h * 0.74), Vector2(w * 0.46, h * 0.62),
		Vector2(w * 0.54, h * 0.76), Vector2(w * 0.62, h * 0.62), Vector2(w * 0.70, h * 0.74),
		Vector2(w * 0.66, h * 0.82), Vector2(w * 0.34, h * 0.82),
	])
	c.draw_colored_polygon(mouth, Color.BLACK)

# ---------------- fase 2: schermata GAME OVER ----------------
func _show_gameover() -> void:
	var scr := Control.new()
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	scr.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scr)

	# sfondo nero OPACO subito: copre il jumpscare uscente senza far rivedere il gioco
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	scr.add_child(bg)

	# solo il testo fa il fade-in (lo sfondo resta nero pieno)
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 26)
	vb.modulate.a = 0.0
	scr.add_child(vb)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 110)
	title.add_theme_color_override("font_color", Color(0.75, 0.05, 0.05))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = _pick_subtitle(cause)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vb.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 24)
	vb.add_child(spacer)

	var btn := Button.new()
	btn.text = "Torna al menu"
	btn.custom_minimum_size = Vector2(240, 56)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func():
		get_tree().paused = false   # IMPORTANTE: sganciare la pausa prima del menu
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		queue_free())
	vb.add_child(btn)

	create_tween().tween_property(vb, "modulate:a", 1.0, 0.6)

# Sottotitolo della schermata GAME OVER, scelto in base alla causa (il nemico).
# Per ora solo il Clown ha battute proprie; le altre cause usano il set generico.
func _pick_subtitle(cause: String) -> String:
	if cause == "clown":
		return CLOWN_SUBTITLES[randi() % CLOWN_SUBTITLES.size()]
	return SUBTITLES[randi() % SUBTITLES.size()]
