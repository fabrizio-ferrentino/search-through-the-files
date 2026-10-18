extends Node

# Strumento di sviluppo (A FINESTRA): TUTTE le icone di OSIcon in un foglio, per giudicarle
# insieme e vedere se sembrano della stessa serie. Ogni icona a 48, 24 e 16 px (desktop,
# menu Avvio, barra/titolo), col suo nome sotto, sui tre fondi veri: il verde acqua del
# desktop, il grigio di barre e finestre, il bianco delle cartelle. Disegna in un
# SubViewport a misura fissa (la finestra del gioco riscala tutto) e salva
# user://icone.png ingrandita x2 senza interpolazione, cosi' si vedono i pixel veri.
# Con "-- web" fa solo l'icona della rete a 16/18/24/32/48/64 px (user://icona_web.png)
# e il desktop vero col browser aperto (user://icona_web_desktop.png).
#   & $godot --path $proj res://tests/icone_check.tscn
#   & $godot --path $proj res://tests/icone_check.tscn -- web

const TIPI := ["folder", "folder_open", "locked", "computer", "web", "file", "floppy",
		"hdd", "cdrom", "exe", "smiley", "image", "notepad", "trash", "trash_full", "whale",
		"whale_pale", "back", "fwd", "up", "cut", "copy", "paste", "delete", "props",
		"views", "dropdown", "stop", "refresh", "home", "star", "print", "search"]
const PER_RIGA := 11
const CELLA := Vector2(104, 74)
const INGRANDI := 2

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "web" in args:
		await _solo_web()
	elif args.size() >= 2 and args[0] == "zoom":
		await _zoom(args[1].split(","))
	else:
		await _foglio()
	get_tree().quit()

# "-- zoom folder,file": solo quelle, a 16/24/32/48 px, sul verde e sul bianco, x4.
func _zoom(tipi: PackedStringArray) -> void:
	var misure := [16, 24, 32, 48]
	var largo := 0.0
	for m in misure:
		largo += m + 10.0
	var vp := _viewport(Vector2i(int(largo + 6) * 2, 56 * tipi.size()))
	for f in range(2):
		var zona := ColorRect.new()
		zona.color = [Win95.C_DESKTOP, Color.WHITE][f]
		zona.position = Vector2((largo + 6) * f, 0)
		zona.size = Vector2(largo + 6, 56 * tipi.size())
		vp.add_child(zona)
		for i in range(tipi.size()):
			var x := 6.0
			for m in misure:
				_icona(zona, tipi[i], m, Vector2(x, 56 * i + 28 - m * 0.5))
				x += m + 10.0
	await _salva(vp, "user://icone_zoom.png", 4)
	print("RISULTATO: salvata user://icone_zoom.png")

func _foglio() -> void:
	var righe: int = int(ceil(TIPI.size() / float(PER_RIGA)))
	var blocco := Vector2(CELLA.x * PER_RIGA, CELLA.y * righe)
	var vp := _viewport(Vector2i(int(blocco.x), int(blocco.y) * 3))
	var fondi := [Win95.C_DESKTOP, Win95.C_FACE, Color.WHITE]
	for f in range(fondi.size()):
		var zona := ColorRect.new()
		zona.color = fondi[f]
		zona.position = Vector2(0, blocco.y * f)
		zona.size = blocco
		vp.add_child(zona)
		for i in range(TIPI.size()):
			var cella := Vector2(CELLA.x * (i % PER_RIGA), CELLA.y * (i / PER_RIGA))
			var x := cella.x + 6.0
			for m in [48, 24, 16]:
				_icona(zona, TIPI[i], m, Vector2(x, cella.y + 4 + (48 - m) * 0.5))
				x += m + 6.0
			var nome := Label.new()
			nome.text = TIPI[i]
			nome.add_theme_font_size_override("font_size", 11)
			nome.add_theme_color_override("font_color",
					Color.WHITE if f == 0 else Color.BLACK)
			nome.position = cella + Vector2(6, 54)
			zona.add_child(nome)
	await _salva(vp, "user://icone.png")
	print("RISULTATO: salvata user://icone.png")

func _solo_web() -> void:
	var misure := [16, 18, 24, 32, 48, 64]
	var vp := _viewport(Vector2i(330, 84 * 3))
	var fondi := [Win95.C_DESKTOP, Win95.C_FACE, Color.WHITE]
	for i in range(fondi.size()):
		var riga := ColorRect.new()
		riga.color = fondi[i]
		riga.position = Vector2(0, i * 84)
		riga.size = Vector2(330, 84)
		vp.add_child(riga)
		var x := 8.0
		for m in misure:
			_icona(riga, "web", m, Vector2(x, 42 - m * 0.5))
			x += m + 14.0
	await _salva(vp, "user://icona_web.png", 3)

	GameManager.start_new_run(4242)
	GameManager.pc_on = true
	GameManager.logged_in = true
	var vos := _viewport(Vector2i(1440, 1080))
	var os: OSDesktop = load("res://scripts/os/desktop.gd").new()
	os.size = Vector2(1440, 1080)
	vos.add_child(os)
	for k in range(3):
		await get_tree().process_frame
	BrowserApp.attesa_scala = 0.05
	var win: OSWindow = os.open_app("browser", "start")
	win.position = Vector2(300, 120)
	await get_tree().create_timer(0.6).timeout
	vos.get_texture().get_image().save_png("user://icona_web_desktop.png")
	print("RISULTATO: salvate user://icona_web.png e user://icona_web_desktop.png")

func _viewport(dim: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = dim
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	return vp

func _icona(dove: Control, tipo: String, m: int, pos: Vector2) -> void:
	var ic := OSIcon.new()
	ic.kind = tipo
	ic.size = Vector2(m, m)
	ic.position = pos.floor()
	dove.add_child(ic)

func _salva(vp: SubViewport, percorso: String, x := INGRANDI) -> void:
	for k in range(4):
		await get_tree().process_frame
	var img := vp.get_texture().get_image()
	img.resize(vp.size.x * x, vp.size.y * x, Image.INTERPOLATE_NEAREST)
	img.save_png(percorso)
