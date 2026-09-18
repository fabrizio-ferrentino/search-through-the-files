extends Node2D

var button_type = null

# I tre pulsanti del menu sono scritti nella SCENA (li ha messi il proprietario in
# editor): le etichette si assegnano qui, da locale/ui.csv, cosi' la scena non va
# toccata e il menu segue la lingua come il resto del gioco. Il titolo no: il nome
# del gioco non si traduce.
func _ready() -> void:
	$button_manager/Start.text = tr("UI_START")
	$button_manager/Option.text = tr("UI_OPTIONS")
	$button_manager/Quit.text = tr("UI_QUIT")

func _on_start_pressed() -> void:
	button_type = "start"
	GameManager.start_new_run()   # nuovo run: seme, stato PC azzerato e filesystem fresco
	$Fade_transition.show()
	$Fade_transition/fade_timer.start()
	$Fade_transition/AnimationPlayer.play("fade_in")

func _on_option_pressed() -> void:
	get_tree().quit()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_fade_timer_timeout() -> void:
	if button_type == "start":
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	#elif button_type == "option":
		#get_tree().change_scene_to_file("res://main.tscn")
