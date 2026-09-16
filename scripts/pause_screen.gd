extends CanvasLayer

# Schermata di PAUSA. Costruita in codice, come le altre sovrimpressioni del gioco
# (vedi death_screen.gd). Vive sulla RADICE dell'albero, quindi copre sia la stanza
# sia la vista del PC, e gira in PROCESS_MODE_ALWAYS: il resto del gioco e' fermo
# (get_tree().paused), lei no -- altrimenti i pulsanti non risponderebbero.
#
# Chi la apre: player.gd, sul tasto dell'azione "pause" (P). Si esce con P, con ESC
# o col pulsante Riprendi. NB: mentre l'albero e' in pausa player.gd non riceve piu'
# input (e' in pausa anche lui), percio' il tasto per riprendere va ascoltato QUI.

const TITOLO := "GIOCO IN PAUSA"

# Emesso quando si riprende: serve a chi l'ha aperta per tornare allo stato di prima.
signal resumed

var _uscita := false          # una volta sola: evita doppi clic sui pulsanti

func _ready() -> void:
	layer = 60                                # sopra la vista PC e l'HUD
	process_mode = Node.PROCESS_MODE_ALWAYS   # deve girare col gioco in pausa
	get_tree().paused = true                  # ferma stanza, minacce e OS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_costruisci()

func _input(event: InputEvent) -> void:
	if _uscita:
		return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		riprendi()

# Torna al gioco: sgancia la pausa e si cancella.
func riprendi() -> void:
	if _uscita:
		return
	_uscita = true
	get_tree().paused = false
	resumed.emit()
	queue_free()

func _costruisci() -> void:
	var radice := Control.new()
	radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.mouse_filter = Control.MOUSE_FILTER_STOP   # niente clic al gioco sotto
	add_child(radice)

	# nero PIENO: l'HUD della stanza (frecce, barra della torcia) sta sul layer 1 e
	# con un nero trasparente traspariva, facendo sembrare la pausa un velo
	var sfondo := ColorRect.new()
	sfondo.color = Color.BLACK
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.add_child(sfondo)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 18)
	radice.add_child(vb)

	var titolo := Label.new()
	titolo.name = "Titolo"
	titolo.text = TITOLO
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titolo.add_theme_font_size_override("font_size", 86)
	titolo.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88))
	vb.add_child(titolo)

	var nota := Label.new()
	nota.text = "P o ESC per riprendere"
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nota.add_theme_font_size_override("font_size", 26)
	nota.add_theme_color_override("font_color", Color(0.62, 0.62, 0.62))
	vb.add_child(nota)

	var stacco := Control.new()
	stacco.custom_minimum_size = Vector2(0, 26)
	vb.add_child(stacco)

	vb.add_child(_pulsante("Riprendi", riprendi))
	vb.add_child(_pulsante("Torna al menu", _al_menu))
	vb.add_child(_pulsante("Chiudi il gioco", _chiudi))

func _pulsante(testo: String, azione: Callable) -> Button:
	var b := Button.new()
	b.name = testo
	b.text = testo
	b.custom_minimum_size = Vector2(280, 52)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(azione)
	return b

func _al_menu() -> void:
	if _uscita:
		return
	_uscita = true
	GameManager.finish_run()    # partita abbandonata: via il pannello di debug
	get_tree().paused = false   # IMPORTANTE: sganciare la pausa prima del menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	queue_free()

func _chiudi() -> void:
	if _uscita:
		return
	_uscita = true
	get_tree().paused = false   # per igiene: nessuno resta in pausa dopo di noi
	get_tree().quit()
