extends Node

# Strumento di sviluppo (A FINESTRA): l'icona "web" (OSIcon._rete) alle misure in cui il
# gioco la usa -- 16-18 px nella barra e nel titolo, 24 nel menu Avvio, 32-48 sul desktop
# e nell'Esplora, 64 per il dettaglio -- sui tre fondi veri: il verde acqua del desktop, il
# grigio di barre e finestre, il bianco delle cartelle. Disegna in un SubViewport a misura
# fissa (la finestra del gioco riscala tutto) e salva user://icona_web.png ingrandita x3
# senza interpolazione, cosi' si vedono i pixel veri.
#   & $godot --path $proj res://tests/icona_web_check.tscn

const MISURE := [16, 18, 24, 32, 48, 64]
const LARGO := 330
const ALTO_RIGA := 84
const INGRANDI := 3

func _ready() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(LARGO, ALTO_RIGA * 3)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var fondi := [Win95.C_DESKTOP, Win95.C_FACE, Color.WHITE]
	for i in range(fondi.size()):
		var riga := ColorRect.new()
		riga.color = fondi[i]
		riga.position = Vector2(0, i * ALTO_RIGA)
		riga.size = Vector2(LARGO, ALTO_RIGA)
		vp.add_child(riga)
		var x := 8.0
		for m in MISURE:
			var ic := OSIcon.new()
			ic.kind = "web"
			ic.size = Vector2(m, m)
			ic.position = Vector2(x, ALTO_RIGA * 0.5 - m * 0.5).floor()
			riga.add_child(ic)
			x += m + 14.0
	for k in range(4):
		await get_tree().process_frame
	var img := vp.get_texture().get_image()
	img.resize(LARGO * INGRANDI, ALTO_RIGA * 3 * INGRANDI, Image.INTERPOLATE_NEAREST)
	img.save_png("user://icona_web.png")

	# ...e dove la si vede davvero: il desktop vero, col browser aperto e il menu Avvio
	# (icona del desktop, titolo della finestra, pulsante nella barra, voce del menu e il
	# globo accanto all'indirizzo). Salva user://icona_web_desktop.png.
	GameManager.start_new_run(4242)
	GameManager.pc_on = true
	GameManager.logged_in = true
	var vos := SubViewport.new()
	vos.size = Vector2i(1440, 1080)
	vos.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vos)
	var os: OSDesktop = load("res://scripts/os/desktop.gd").new()
	os.size = Vector2(1440, 1080)
	vos.add_child(os)
	for k in range(3):
		await get_tree().process_frame
	BrowserApp.attesa_scala = 0.05
	var win: OSWindow = os.open_app("browser", "start")
	win.position = Vector2(300, 120)
	os._toggle_start_menu()
	await get_tree().create_timer(0.6).timeout
	vos.get_texture().get_image().save_png("user://icona_web_desktop.png")
	print("RISULTATO: salvate user://icona_web.png e user://icona_web_desktop.png")
	get_tree().quit()
