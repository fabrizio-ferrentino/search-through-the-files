extends Node

# Strumento di sviluppo (non un test): il VASSOIO della barra col pannello del volume
# aperto, fotografato per giudicarlo a occhio (che niente esca dal pannello, che casella
# e cursore abbiano lo stile Win95 del resto dell'OS).
# Salva user://vassoio_volume.png (pannello aperto) e user://vassoio_muto.png (zittito).
# Va eseguito A FINESTRA:
#   & $godot --path $proj res://tests/vassoio_check.tscn

const OS_SIZE := Vector2i(1440, 1080)

func _ready() -> void:
	await get_tree().process_frame
	GameManager.start_new_run(5)
	GameManager.pc_on = true
	GameManager.logged_in = true
	var muto_prima: bool = GameManager.pc_muto
	var vp := SubViewport.new()
	vp.size = OS_SIZE
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)
	var os = load("res://scripts/os/desktop.gd").new()
	os.size = Vector2(OS_SIZE)
	vp.add_child(os)
	for i in range(6):
		await get_tree().process_frame
	AudioPC.imposta_muto(false)
	os._aggiorna_icona_volume()
	os._btn_volume.pressed.emit()
	await _foto(vp, "vassoio_volume.png")
	os._casella_muto.button_pressed = true
	await _foto(vp, "vassoio_muto.png")
	AudioPC.imposta_muto(muto_prima)
	get_tree().quit(0)

# Salva l'angolo in basso a destra dello schermo dell'OS, ingrandito 2x.
func _foto(vp: SubViewport, nome: String) -> void:
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var im := vp.get_texture().get_image()
	var r := Rect2i(OS_SIZE.x - 360, OS_SIZE.y - 330, 360, 330)
	var pezzo := im.get_region(r)
	pezzo.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_NEAREST)
	pezzo.save_png("user://" + nome)
	print("salvata " + nome)
