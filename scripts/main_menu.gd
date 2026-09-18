extends Node2D

var button_type = null

var opzioni: OptionsScreen = null    # la schermata Opzioni, se aperta

func _ready() -> void:
	_etichette()

# I tre pulsanti del menu sono scritti nella SCENA (li ha messi il proprietario in
# editor): le etichette si assegnano qui, da locale/ui.csv, cosi' la scena non va
# toccata e il menu segue la lingua come il resto del gioco. Il titolo no: il nome
# del gioco non si traduce. Si richiama dopo un cambio di lingua nelle Opzioni,
# altrimenti i pulsanti resterebbero nella lingua di prima finche' non si riapre il menu.
func _etichette() -> void:
	$button_manager/Start.text = tr("UI_START")
	$button_manager/Option.text = tr("UI_OPTIONS")
	$button_manager/Quit.text = tr("UI_QUIT")

func _on_start_pressed() -> void:
	button_type = "start"
	GameManager.start_new_run()   # nuovo run: seme, stato PC azzerato e filesystem fresco
	$Fade_transition.show()
	$Fade_transition/fade_timer.start()
	$Fade_transition/AnimationPlayer.play("fade_in")

# OPZIONI: apre la schermata (scripts/options_screen.gd), che oggi contiene solo la
# scelta della lingua. Prima questo pulsante era disabilitato nella scena e il suo
# callback chiudeva il gioco -- un pulsante "Opzioni" che spegne tutto e' peggio di uno
# spento, quindi finche' non c'era niente da mostrare era giusto lasciarlo grigio.
func _on_option_pressed() -> void:
	if opzioni != null and is_instance_valid(opzioni):
		return                       # gia' aperta: il doppio clic non ne apre due
	opzioni = OptionsScreen.new()
	opzioni.lingua_cambiata.connect(_etichette)
	add_child(opzioni)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_fade_timer_timeout() -> void:
	if button_type == "start":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	#elif button_type == "option":
		#get_tree().change_scene_to_file("res://main.tscn")
