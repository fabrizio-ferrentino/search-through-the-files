extends Node

# Strumento di sviluppo (non un test): la STANZA vera, vista a sinistra, fotografata per
# giudicare a occhio la finestra segnaposto (scenes/window_left.tscn). Minacce spente, si
# aspetta la dissolvenza d'ingresso (1 s) e il giro della visuale. Salva:
#   user://finestra_sinistra.png   lo sguardo a sinistra, come lo vede chi gioca
#   user://finestra_centro.png     lo sguardo dritto, per vedere se la finestra si intravede
# Va eseguito A FINESTRA:
#   & $godot --path $proj res://tests/finestra_check.tscn

func _ready() -> void:
	await get_tree().process_frame
	GameManager.room_threats_enabled = false
	GameManager.pc_threats_enabled = false
	GameManager.start_new_run(1)
	var stanza: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(stanza)
	await get_tree().create_timer(1.8).timeout
	var player = stanza.find_child("Camera3D", true, false)
	_foto("finestra_centro.png")
	player._move_view("left")
	await get_tree().create_timer(2.5).timeout
	_foto("finestra_sinistra.png")
	var finestra := stanza.find_child("WindowLeft", true, false)
	print("finestra nella stanza: ", finestra != null,
			" | punti spot_left: ", get_tree().get_nodes_in_group("spot_left").size(),
			" | punti enemy_spots: ", get_tree().get_nodes_in_group("enemy_spots").size())
	GameManager.room_threats_enabled = true
	GameManager.pc_threats_enabled = true
	get_tree().quit()

func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("user://" + nome)
