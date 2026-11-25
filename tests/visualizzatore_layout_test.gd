extends Node

# Il visualizzatore di foto non taglia i suoi comandi (proprietario, 25/11/2026: "alcuni
# pulsanti sono tagliati, come se non fosse responsive"). Controlla che:
#   1 alla misura d'apertura "Ripristina" e tutti i cursori si vedano INTERI;
#   2 in una finestra piccola nessun comando esca dal pannello: compare la barra di
#     scorrimento e, scorrendo in fondo, "Ripristina" si vede intero.
# Salva visualizzatore_apertura.png e visualizzatore_piccolo.png in user://.
# A FINESTRA:  & $godot --path $proj res://tests/visualizzatore_layout_test.tscn

const SEME := 4242

var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.start_new_run(SEME)
	GameManager.pc_on = true
	GameManager.logged_in = true
	var stanza: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(stanza)
	for i in range(25):
		await get_tree().process_frame
	var cam := stanza.get_node_or_null("Camera3D")
	cam._show_pc_overlay()
	await _frame(5)

	var foto := _una_foto(VFS.get_root())
	if foto.is_empty():
		print("RISULTATO: FAIL -> nessuna foto sul disco")
		get_tree().quit(1)
		return
	var win = cam._os.open_app("image", foto)
	await _frame(10)
	var app: ImageViewerApp = null
	for c in win.content_root.get_children():
		if c is ImageViewerApp:
			app = c
	var scorri := app.find_child("Scorri", true, false) as ScrollContainer
	var reset := app.find_child("Ripristina", true, false) as Button
	if scorri == null or reset == null:
		print("RISULTATO: FAIL -> pannello o Ripristina non trovati")
		get_tree().quit(1)
		return

	# 1: alla misura d'apertura si vede tutto, senza scorrere
	var interi := _comandi_interi(app, scorri)
	_check("APERTURA_TUTTO_VISIBILE", interi == "" and _dentro(reset, scorri),
			"tagliati: %s; Ripristina %s in %s" % [interi, str(reset.get_global_rect()), str(scorri.get_global_rect())])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://visualizzatore_apertura.png")

	# 2: finestra piccola: niente esce di lato, si scorre fino a Ripristina
	win.size = Vector2(560, 340)
	await _frame(6)
	var barra := scorri.get_v_scroll_bar()
	var larghi := _comandi_larghi(app, scorri)
	scorri.scroll_vertical = 100000
	await _frame(4)
	_check("PICCOLA_SI_SCORRE", barra.visible and larghi == "" and _dentro(reset, scorri),
			"barra %s, escono di lato: %s; Ripristina %s in %s" % [str(barra.visible), larghi,
			str(reset.get_global_rect()), str(scorri.get_global_rect())])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("user://visualizzatore_piccolo.png")

	if _fails.is_empty():
		print("RISULTATO: PASS (il visualizzatore non taglia i suoi comandi)")
		get_tree().quit(0)
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
		get_tree().quit(1)

# I cursori e i pulsanti che non stanno INTERI nella parte visibile del pannello.
func _comandi_interi(app: Node, scorri: ScrollContainer) -> String:
	var fuori: Array = []
	for n in app.find_children("*", "Range", true, false) + app.find_children("*", "Button", true, false):
		if n is ScrollBar:
			continue
		if not _dentro(n as Control, scorri):
			fuori.append(str((n as Node).name))
	return ", ".join(fuori)

# Quelli che escono DI LATO (in altezza si scorre, in larghezza no).
func _comandi_larghi(app: Node, scorri: ScrollContainer) -> String:
	var fuori: Array = []
	var r := scorri.get_global_rect()
	for n in app.find_children("*", "Range", true, false) + app.find_children("*", "Button", true, false):
		if n is ScrollBar:
			continue
		var c := (n as Control).get_global_rect()
		if c.position.x < r.position.x - 0.5 or c.end.x > r.end.x + 0.5:
			fuori.append(str((n as Node).name))
	return ", ".join(fuori)

func _dentro(c: Control, scorri: ScrollContainer) -> bool:
	return scorri.get_global_rect().grow(0.5).encloses(c.get_global_rect())

func _una_foto(nodo: Dictionary) -> Dictionary:
	if str(nodo.get("filetype", "")) == "image":
		return nodo
	for c in nodo.get("children", []):
		if c is Dictionary:
			var r := _una_foto(c)
			if not r.is_empty():
				return r
	return {}

func _frame(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _check(nome: String, ok: bool, perche: String) -> void:
	print(("  ok  " if ok else "  NO  ") + nome + ("" if ok else ": " + perche))
	if not ok:
		_fails.append(nome)
