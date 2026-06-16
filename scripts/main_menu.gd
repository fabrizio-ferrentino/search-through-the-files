extends Node2D

var button_type = null

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
