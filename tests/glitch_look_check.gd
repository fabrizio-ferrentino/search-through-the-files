extends Node

# Strumento di sviluppo (non un test): il glitch della CARTELLA SEGRETA come lo vede il
# giocatore -- stanza vera, dentro il PC, attraverso il CRT -- in un PROVINO di
# fotogrammi. Un glitch si giudica nel tempo, non da una foto sola: una raffica dura
# pochi decimi di secondo e una foto a caso la manca o la coglie a meta'.
#
# Salva in user://glitch/:
#   provino_<nome>.png   16 fotogrammi ritagliati attorno al dialogo, 4x4, in ordine
#                        di tempo (da sinistra a destra, dall'alto in basso)
#   riposo_<nome>.png    il dialogo fermo, a grandezza piena (deve restare leggibile)
#
# Esecuzione (FINESTRA):
#   & $godot --path $proj res://tests/glitch_look_check.tscn
#   & $godot --path $proj res://tests/glitch_look_check.tscn -- sbagliato
# Con "sbagliato" il provino parte da un tentativo con codici errati (la reazione).
# ============================================================

const OUT := "user://glitch/"
const FOTOGRAMMI := 16
const OGNI := 3                # un fotogramma ogni 3 frame del gioco

var _room: Node = null
var _player: Node = null

func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func(): _timeout())
	await get_tree().process_frame
	var sbagliato := OS.get_cmdline_user_args().has("sbagliato")
	GameManager.room_threats_enabled = false
	GameManager.pc_threats_enabled = false
	GameManager.start_new_run(2024)
	GameManager.pc_on = true
	GameManager.logged_in = true
	_room = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_room)
	await get_tree().create_timer(1.6).timeout     # la dissolvenza d'ingresso della stanza
	_player = _room.find_child("Camera3D", true, false)
	_player._show_pc_overlay()
	var os_node = _player._os
	os_node.open_secret_folder({})
	for i in range(6):
		await get_tree().process_frame

	var pannello := _pannello(os_node)
	if pannello == null:
		print("ERRORE: dialogo non trovato")
		get_tree().quit(1)
		return

	# a riposo: aspetta che l'eventuale raffica d'apertura sia finita
	await get_tree().create_timer(1.2).timeout
	var dim := get_tree().root.get_texture().get_image().get_size()
	var k := float(dim.y) / 1080.0
	var x0 := float(dim.x) * 240.0 / 1920.0
	var r_os := pannello.get_global_rect().grow(140.0)
	var crop := Rect2i(int(x0 + r_os.position.x * k), int(r_os.position.y * k),
			int(r_os.size.x * k), int(r_os.size.y * k))
	crop = crop.intersection(Rect2i(Vector2i.ZERO, dim))
	var nome := "sbagliato" if sbagliato else "raffica"
	DirAccess.make_dir_recursive_absolute(OUT)
	(await _foto()).get_region(crop).save_png(OUT + "riposo_" + nome + ".png")

	# parte la cosa da guardare: una raffica, o un tentativo sbagliato
	if sbagliato:
		for le in pannello.find_children("*", "LineEdit", true, false):
			(le as LineEdit).text = "XXXX"
		for b in pannello.find_children("*", "Button", true, false):
			if (b as Button).text == tr("SECRET_UNLOCK"):
				(b as Button).pressed.emit()
	elif os_node.has_method("glitch_segreto"):
		os_node.glitch_segreto(1.0)
	else:
		# il vecchio dialogo non ha un comando: si alza a mano la sua intensita'
		var fx = pannello.get_node_or_null("GlitchFX")
		if fx != null:
			var tw := create_tween()
			tw.tween_property(fx.material, "shader_parameter/intensity", 0.9, 0.04)
			tw.tween_interval(0.25)
			tw.tween_property(fx.material, "shader_parameter/intensity", 0.05, 0.22)

	var sheet := Image.create_empty(crop.size.x * 4, crop.size.y * 4, false, Image.FORMAT_RGBA8)
	var t0 := Time.get_ticks_msec()
	var stato := PackedStringArray()
	for f in range(FOTOGRAMMI):
		for i in range(OGNI - 1):
			await get_tree().process_frame
		var img := await _foto()
		img.convert(Image.FORMAT_RGBA8)   # blit_rect vuole lo stesso formato (la foto e' RGB8)
		sheet.blit_rect(img, crop, Vector2i((f % 4) * crop.size.x, (f / 4) * crop.size.y))
		var g = os_node._glitch_cartella if "_glitch_cartella" in os_node else null
		stato.append("%d:%dms%s[%s]" % [f + 1, Time.get_ticks_msec() - t0,
				"*" if (g != null and g.in_raffica()) else "", g._titolo.text if g != null else ""])
	sheet.save_png(OUT + "provino_" + nome + ".png")
	print("fotogrammi (* = raffica in corso): " + " ".join(stato))
	print("provino in: %s" % ProjectSettings.globalize_path(OUT + "provino_" + nome + ".png"))
	get_tree().quit(0)

func _timeout() -> void:
	print("ERRORE: timeout")
	get_tree().quit(1)

func _foto() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_tree().root.get_texture().get_image()

# Il pannello del dialogo: il Panel dentro l'ultimo strato modale del desktop.
func _pannello(os_node) -> Panel:
	var strato: Control = os_node._modal_layer
	if strato == null:
		return null
	for c in strato.get_children():
		if c is Panel:
			return c
	return null
