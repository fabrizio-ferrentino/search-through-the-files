extends Node

# Strumento di sviluppo (non un test): i SITI nel browser vero, nella stanza vera, dentro il
# PC, fotografati come li vede chi gioca -- attraverso il CRT -- per giudicarli a occhio.
# Per ogni pagina salva user://sito_<sito>_<pagina>.png (la finestra del gioco).
# Va eseguito A FINESTRA; dopo "--" la lingua (di base "it") e, se si vuole, le pagine:
#   & $godot --path $proj res://tests/siti_check.tscn
#   & $godot --path $proj res://tests/siti_check.tscn -- en forum/index treno/update

const PAGINE := ["forum/index", "forum/hardware", "forum/thread", "forum/members",
		"treno/index", "treno/about", "treno/thoughts", "treno/guestbook", "treno/update"]

func _ready() -> void:
	await get_tree().process_frame
	var argomenti := Array(OS.get_cmdline_user_args())
	var lingua := "it"
	if not argomenti.is_empty() and str(argomenti[0]).length() == 2:
		lingua = str(argomenti.pop_front())
	var pagine: Array = argomenti if not argomenti.is_empty() else PAGINE
	var lingua_prima: String = GameManager.lingua
	GameManager.set_lingua(lingua, false)
	GameManager.room_threats_enabled = false
	GameManager.pc_threats_enabled = false
	GameManager.start_new_run(7)
	GameManager.debug_tutti_i_siti = true   # si fotografa qualunque sito, anche se stanotte non c'e'
	GameManager.pc_on = true
	GameManager.logged_in = true
	var stanza: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(stanza)
	await get_tree().create_timer(1.6).timeout
	var player = stanza.find_child("Camera3D", true, false)
	player._show_pc_overlay()
	var os: OSDesktop = player._os
	BrowserApp.attesa_scala = 0.05
	var win: OSWindow = os.open_app("browser", "start")
	win.toggle_max()
	var app: BrowserApp = win.content_root.get_child(0)
	for p in pagine:
		app._go(str(p))
		await app.attendi_caricamento()
		for i in range(6):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var nome := "sito_%s.png" % str(p).replace("/", "_")
		get_tree().root.get_texture().get_image().save_png("user://" + nome)
		print("salvata ", nome, "  (", app._addr.text, ")")
	BrowserApp.attesa_scala = 1.0
	GameManager.set_lingua(lingua_prima, false)
	GameManager.room_threats_enabled = true
	GameManager.pc_threats_enabled = true
	get_tree().quit()
