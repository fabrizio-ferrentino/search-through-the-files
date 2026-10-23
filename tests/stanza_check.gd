extends Node

# Strumento di sviluppo (non un test): la STANZA vera fotografata dalle quattro visuali
# (centro, sinistra, destra, dietro), com'e' per chi gioca e poi "accesa" (luce ambientale
# alta) per leggere la geometria, piu' una vista dall'alto. Minacce spente.
#   user://stanza_<vista>.png        come la vede chi gioca
#   user://stanza_<vista>_luce.png   con la luce ambientale alzata
#   user://stanza_alto_luce.png      dall'alto, accesa
# Va eseguito A FINESTRA:
#   & $godot --path $proj res://tests/stanza_check.tscn

func _ready() -> void:
	await get_tree().process_frame
	GameManager.room_threats_enabled = false
	GameManager.pc_threats_enabled = false
	GameManager.start_new_run(1)
	var stanza: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(stanza)
	await get_tree().create_timer(1.8).timeout
	var player = stanza.find_child("Camera3D", true, false)
	var env: Environment = (stanza.find_child("Atmosphere", true, false) as WorldEnvironment).environment
	var buio: float = env.ambient_light_energy
	for vista in [["centro", player.pos_center], ["sinistra", player.pos_left],
			["destra", player.pos_right], ["dietro", player.pos_back]]:
		player.target_yaw = vista[1]
		await get_tree().create_timer(1.5).timeout
		env.ambient_light_energy = buio
		await _foto("stanza_%s.png" % vista[0])
		env.ambient_light_energy = 1.2
		await _foto("stanza_%s_luce.png" % vista[0])
	# gli spot degli affacci: una sagoma rossa (alta 1.8, senza luce propria) su ognuno,
	# vista da destra, per controllare che dalla sedia si vedano tutti
	var rosso := StandardMaterial3D.new()
	rosso.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rosso.albedo_color = Color(1, 0.1, 0.1)
	for spot in get_tree().get_nodes_in_group("enemy_spots"):
		var sagoma := MeshInstance3D.new()
		var capsula := CapsuleMesh.new()
		capsula.radius = 0.2
		capsula.height = 1.8
		sagoma.mesh = capsula
		sagoma.material_override = rosso
		stanza.add_child(sagoma)
		sagoma.global_position = (spot as Node3D).global_position + Vector3(0, 0.9, 0)
	player.target_yaw = player.pos_right
	await get_tree().create_timer(1.5).timeout
	env.ambient_light_energy = buio
	await _foto("stanza_spot_destra.png")
	# dall'alto: una telecamera nuova sopra la stanza, guarda giu'
	var cam := Camera3D.new()
	stanza.add_child(cam)
	cam.global_position = Vector3(0.5, 7.0, 1.0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.fov = 70
	stanza.find_child("Soffitto", true, false).visible = false
	cam.current = true
	await _foto("stanza_alto_luce.png")
	GameManager.room_threats_enabled = true
	GameManager.pc_threats_enabled = true
	get_tree().quit()

func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("user://" + nome)
