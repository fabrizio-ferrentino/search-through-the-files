extends Camera3D

@onready var raycast = $RayCast3D
# Riferimenti ai nodi UI (Assicurati che i percorsi siano corretti o usa %)
@onready var arrow_left = $"../HUD/ArrowsUI/ArrowLeft"
@onready var arrow_right = $"../HUD/ArrowsUI/ArrowRight"
@onready var arrow_down = $"../HUD/ArrowsUI/ArrowDown"

# --- CONFIGURAZIONE POSIZIONI ---
var pos_left = 70.0
var pos_center = 0.0
var pos_right = -70.0
var pos_back = 180.0 

var target_yaw = 0.0
var edge_margin = 0.05 
var move_speed = 12.0
var can_change_pos = true
var reset_margin = 0.10 # Margine largo per resettare

func _ready():
	if GameManager.first_time_in_room:
		$"../Fade_transition".show()
		$"../Fade_transition/fade_timer".start()
		$"../Fade_transition/AnimationPlayer".play("fade_out")
		GameManager.first_time_in_room = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_update_arrows() # Imposta le frecce iniziali

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Creiamo un raggio che parte dalla punta del mouse
		var camera = self
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 2000
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result = space_state.intersect_ray(query)
		if result:
			var collider = result.collider
			print("Ho colpito: ", collider.name) 
			if (collider.name == "Monitor") and target_yaw == pos_center:
				print("Enter in Pc mode")
				var error = get_tree().change_scene_to_file("res://scenes/ComputerMode.tscn")

func _process(delta):
	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var mouse_x_pct = mouse_pos.x / viewport_size.x
	var mouse_y_pct = mouse_pos.y / viewport_size.y
	
	# --- LOGICA DI MOVIMENTO ---
	if mouse_x_pct < edge_margin:
		if can_change_pos and target_yaw != pos_back:
			print("Guardo a Sinistra")
			_move_view("left")
			can_change_pos = false
			
	elif mouse_x_pct > (1.0 - edge_margin):
		if can_change_pos and target_yaw != pos_back:
			print("Guardo a Destra")
			_move_view("right")
			can_change_pos = false
			
	elif mouse_y_pct > 0.95:
		if can_change_pos:
			if target_yaw == pos_center:
				target_yaw = pos_back
			elif target_yaw == pos_back:
				target_yaw = pos_center
			can_change_pos = false
			_update_arrows()
	else:
		# Resettiamo il comando SOLO se il mouse si allontana bene dai bordi
		if mouse_x_pct > reset_margin and mouse_x_pct < (1.0 - reset_margin) and mouse_y_pct < 0.85:
			can_change_pos = true
	# Rotazione fluida
	rotation_degrees.y = lerp(rotation_degrees.y, target_yaw, delta * move_speed)

func _move_view(direction):
	var old_yaw = target_yaw
	if direction == "left":
		if target_yaw == pos_right: target_yaw = pos_center
		elif target_yaw == pos_center: target_yaw = pos_left
			
	elif direction == "right":
		if target_yaw == pos_left: target_yaw = pos_center
		elif target_yaw == pos_center: target_yaw = pos_right
	
	if old_yaw != target_yaw:
		_update_arrows() # Aggiorna le frecce solo se la posizione è cambiata

# --- GESTIONE VISIBILITÀ FRECCE ---
func _update_arrows():
	# Nascondiamo tutto per resettare
	arrow_left.hide()
	arrow_right.hide()
	arrow_down.hide()
	match target_yaw:
		pos_center:
			arrow_left.show()
			arrow_right.show()
			arrow_down.show()
		pos_left:
			arrow_right.show()
		pos_right:
			arrow_left.show()
		pos_back:
			arrow_down.show()
