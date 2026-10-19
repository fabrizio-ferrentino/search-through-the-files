extends Node

# Strumento di sviluppo (non un test): le apparizioni in ASCII (bambino, occhi, scritte) nella
# STANZA vera, dentro il PC, fotografate come le vede chi gioca -- attraverso il CRT -- per
# giudicarle a occhio. Per ogni tipo salva:
#   user://ascii_<tipo>.png      la finestra del gioco (CRT compreso)
#   user://ascii_<tipo>_os.png   lo schermo del PC com'e' disegnato (senza CRT)
#   user://ascii_<tipo>_vero.png lo stesso tipo nel VERO, a 8 s su 10 (cresciuto)
# Va eseguito A FINESTRA; dopo "--" i tipi (di base bambino occhi scritte):
#   & $godot --path $proj res://tests/ascii_check.tscn -- bambino

func _ready() -> void:
	await get_tree().process_frame
	GameManager.room_threats_enabled = false
	GameManager.pc_threats_enabled = false
	GameManager.start_new_run(7)
	GameManager.pc_on = true
	GameManager.logged_in = true
	var stanza: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(stanza)
	await get_tree().create_timer(1.6).timeout
	var player = stanza.find_child("Camera3D", true, false)
	player._show_pc_overlay()
	var os: OSDesktop = player._os
	for i in range(4):
		await get_tree().process_frame
	var tipi := OS.get_cmdline_user_args()
	if tipi.is_empty():
		tipi = PackedStringArray(["bambino", "occhi", "scritte"])
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for tipo in tipi:
		for vero in [false, true]:
			var a := Apparizione.new()
			os.add_child(a)
			var t0 := Time.get_ticks_usec()
			a.setup(os, tipo, rng)
			print("%s: setup %.1f ms" % [tipo, (Time.get_ticks_usec() - t0) / 1000.0])
			a.set_process(false)
			if tipo == "occhi":
				a.guarda_test = Vector2(os.size.x * 0.5, os.size.y * 0.75)   # un cursore credibile
			if vero:
				a.crescita = VirusMortale.DURATA
				for k in range(8 * 30):
					a.avanza(1.0 / 30.0)
			else:
				a.durata = 2.0
				for k in range(12):
					a.avanza(1.0 / 30.0)
			for k in range(3):
				await get_tree().process_frame
			var nome := "ascii_%s%s" % [tipo, "_vero" if vero else ""]
			await _foto(nome + ".png")
			if not vero:
				await RenderingServer.frame_post_draw
				player._os_viewport.get_texture().get_image().save_png("user://%s_os.png" % nome)
			t0 = Time.get_ticks_usec()
			for k in range(10):
				a.avanza(0.1)
			print("%s: 10 passi %.1f ms" % [tipo, (Time.get_ticks_usec() - t0) / 1000.0])
			a.pulisci()
			await get_tree().process_frame
	GameManager.room_threats_enabled = true
	GameManager.pc_threats_enabled = true
	get_tree().quit()

func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("user://" + nome)
