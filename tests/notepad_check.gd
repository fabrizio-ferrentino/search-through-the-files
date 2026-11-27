extends Node

# Strumento di sviluppo (A FINESTRA): il Blocco note vero, dentro il desktop vero, su un
# file di testo con righe lunghe e corte, a tre larghezze (normale, stretta, minima), con
# "A capo automatico" spento e acceso; alla larghezza piena anche il menu Modifica aperto.
# Salva user://notepad_<larghezza>[_acapo].png, per giudicare la finestra e cosa succede
# al testo quando non ci sta.
#   & $godot --path $proj res://tests/notepad_check.tscn

const TESTO := "Caro diario,\n\noggi papa' ha portato a casa il computer nuovo. Dice che con il modem possiamo collegarci a Internet, ma costa caro e non dobbiamo restare collegati troppo.\n\nLISTA DELLA SPESA\n- latte\n- pane\n- batterie per il telecomando\n\nRicordarsi: la password del computer e' scritta dietro il calendario della cucina, sotto il mese di marzo.\n\nUnaparolalunghissimachenonsipuospezzareinnessunmodoperchenonhaspazi.\n"

func _ready() -> void:
	GameManager.start_new_run(4242)
	GameManager.pc_on = true
	GameManager.logged_in = true
	var vp := SubViewport.new()
	vp.size = preload("res://scripts/player.gd").OS_SIZE
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var os: OSDesktop = load("res://scripts/os/desktop.gd").new()
	os.size = Vector2(preload("res://scripts/player.gd").OS_SIZE)
	vp.add_child(os)
	for k in range(3):
		await get_tree().process_frame
	var file := {"name": "DIARIO.TXT", "type": "file", "icon": "text", "filetype": "text",
			"content": TESTO}
	for a_capo in [false, true]:
		GameManager.np_a_capo = a_capo
		for larga in [560, 300, 220]:
			var win: OSWindow = os.open_app("notepad", file)
			win.position = Vector2(300, 120)
			win.size = Vector2(larga, 460)
			for k in range(6):
				await get_tree().process_frame
			if larga == 560:
				var app := win.content_root.get_child(0) as NotepadApp
				app.call("_open_edit_menu", Vector2(60, 34), true)
				for k in range(3):
					await get_tree().process_frame
			var img := vp.get_texture().get_image()
			img = img.get_region(Rect2i(280, 100, 640, 520))
			img.save_png("user://notepad_%d%s.png" % [larga, "_acapo" if a_capo else ""])
			win.close()
			for k in range(3):
				await get_tree().process_frame
	GameManager.np_a_capo = false
	print("RISULTATO: salvate user://notepad_<560|300|220>[_acapo].png")
	get_tree().quit()
