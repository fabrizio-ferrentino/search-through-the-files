extends Control

#@onready var start_button = $Taskbar/StartButton
@onready var start_menu = $StartMenu

func _unhandled_input(event):
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED 
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		
func _ready():
	# FONDAMENTALE: Rendi il cursore del mouse visibile
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE 
	
	print("\n--- SCANSIONE NODI Computer---")
	print_tree_pretty()
	print("\n--- FINE SCANSIONE ---\n")
	#start_button.pressed.connect(_on_start_button_pressed)
	#start_menu.visible = false

func _on_start_button_pressed():
	# Apre/chiude menu
	print("Start pressed")
	start_menu.visible = !start_menu.visible

func _input(event):
	if event is InputEventMouseButton and event.pressed:
		# Se clicco e il menu è aperto
		if start_menu.visible:
			# Controlla se ho cliccato fuori dal menu
			if not start_menu.get_global_rect().has_point(get_global_mouse_position()):
				# Chiudi il menu
				start_menu.visible = false
