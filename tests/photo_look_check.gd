extends Node

# STRUMENTO (non un test): per ogni foto in PHOTO_DIR salva tre immagini da guardare
#   *_1_orig_vs_preparata.png  originale | come la vede il giocatore (deve essere UGUALE,
#                              salvo il raro ripiego con la sfocatura)
#   *_2_default.png            ritaglio attorno al codice, senza regolazioni: qui il codice
#                              NON si deve vedere
#   *_3_nitidezza.png          lo stesso ritaglio col PASSA-BANDA (gemello su CPU del
#                              cursore "Nitidezza"): qui il codice si deve leggere
# Serve a giudicare a occhio le due cose che i numeri non dicono: se il ritocco si nota e
# se il codice e' leggibile.
#
# Esecuzione:
#   & $godot --path $proj res://tests/photo_look_check.tscn
# ============================================================

const OUT := "C:/Users/ffria/AppData/Local/Temp/claude/z--Progetti-Search-Through-the-Files/1536785d-988b-4eed-baf2-48564844db2c/scratchpad/confronti/"
const GUADAGNO := 14.0     # come il cursore Nitidezza al massimo (adjust.gdshader)

func _ready() -> void:
	get_tree().create_timer(240.0).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	GameManager.start_new_run(12345)
	var codice: String = GameManager.key_label(OSContent.KEY_IMAGE)
	for path in OSContent._photo_files():
		await _confronta(path, codice)
	print("ESITO: immagini in ", OUT)
	get_tree().quit(0)

func _confronta(path: String, codice: String) -> void:
	# nodo foto preparato come in partita
	var nodo := {"name": path.get_file(), "type": "file", "icon": "image", "filetype": "image",
			"path": path, "code": codice, "code_seed": 7}
	var spot: Dictionary = OSContent._prepare_hiding_spot(nodo)
	if spot.is_empty():
		print("  ", path.get_file(), ": non leggibile")
		return
	nodo["code_uv"] = spot["uv"]
	nodo["code_base"] = spot["avg"]
	nodo["code_delta"] = spot["delta"]
	if spot.has("blur_rect"):
		nodo["blur_rect"] = spot["blur_rect"]
		nodo["blur_target"] = spot["blur_target"]

	# visualizzatore vero
	var host_vp := SubViewport.new()
	host_vp.size = Vector2i(1100, 760)
	host_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(host_vp)
	var host := Control.new()
	host.theme = Win95.make_theme()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host_vp.add_child(host)
	var app := ImageViewerApp.new()
	host.add_child(app)
	app.launch(nodo)
	for i in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var vp: SubViewport = null
	for c in app.get_children():
		if c is SubViewport:
			vp = c
	if vp == null:
		host_vp.queue_free()
		return
	var composta := vp.get_texture().get_image()
	if composta.get_format() != Image.FORMAT_RGBA8:
		composta.convert(Image.FORMAT_RGBA8)

	# 1) originale accanto a quella che vede il giocatore
	var originale := OSContent._scan_image({"path": path})
	if originale == null:
		host_vp.queue_free()
		return
	var w := originale.get_width()
	var h := originale.get_height()
	var foglio := Image.create(w * 2, h, false, Image.FORMAT_RGBA8)
	foglio.fill(Color(0.1, 0.1, 0.1))
	foglio.blit_rect(originale, Rect2i(0, 0, w, h), Vector2i(0, 0))
	foglio.blit_rect(composta, Rect2i(0, 0, mini(w, composta.get_width()), mini(h, composta.get_height())), Vector2i(w, 0))
	foglio.save_png(OUT + path.get_file().get_basename() + "_1_orig_vs_preparata.png")

	# 2) e 3) ritaglio attorno al codice: come sta a riposo e col passa-banda
	var box: Rect2i = spot["box"]
	var uv: Vector2 = spot["uv"]
	var cw: int = mini(composta.get_width(), box.size.x * 3)
	var ch: int = mini(composta.get_height(), box.size.y * 4)
	var cx: int = clampi(int(uv.x * composta.get_width()) - cw / 2, 0, maxi(0, composta.get_width() - cw))
	var cy: int = clampi(int(uv.y * composta.get_height()) - ch / 2, 0, maxi(0, composta.get_height() - ch))
	var taglio := Rect2i(cx, cy, cw, ch)
	var riposo := composta.get_region(taglio)
	riposo.resize(cw * 2, ch * 2, Image.INTERPOLATE_NEAREST)
	riposo.save_png(OUT + path.get_file().get_basename() + "_2_default.png")
	var nitida := _passa_banda(composta).get_region(taglio)
	nitida.resize(cw * 2, ch * 2, Image.INTERPOLATE_NEAREST)
	nitida.save_png(OUT + path.get_file().get_basename() + "_3_nitidezza.png")
	# l'altra via: finestra dei livelli stretta attorno al colore medio della zona
	var livelli := _livelli(composta, spot["avg"]).get_region(taglio)
	livelli.resize(cw * 2, ch * 2, Image.INTERPOLATE_NEAREST)
	livelli.save_png(OUT + path.get_file().get_basename() + "_4_livelli.png")

	# quanto e' stata toccata la foto fuori dal riquadro del testo (deve essere zero)
	var fuori := _differenza_fuori(originale, composta, box)
	print("  %-24s banda %.4f | scarto %.4f | rapporto %.2f | %s | differenza fuori dal testo: %.2f livelli" % [
			path.get_file(), float(spot["sigma_bp"]), float(spot["delta"]), float(spot["rapporto"]),
			("SFOCATA" if spot.has("blur_rect") else "INTATTA"), fuori])
	host_vp.queue_free()
	await get_tree().process_frame

# Gemello su CPU del cursore "Nitidezza": differenza fra sfocatura fine e larga, amplificata.
func _passa_banda(img: Image) -> Image:
	var coppia := OSContent._bp_pair_img(img)
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var a: Color = coppia[0].get_pixel(x, y)
			var b: Color = coppia[1].get_pixel(x, y)
			var d: float = ((a.r + a.g + a.b) - (b.r + b.g + b.b)) / 3.0
			var v: float = clampf(0.5 + d * GUADAGNO, 0.0, 1.0)
			out.set_pixel(x, y, Color(v, v, v))
	return out

# L'altra via di rivelazione: i cursori "punto nero/punto bianco" stretti attorno al tono
# della zona (e' quello che faceva emergere il codice prima del passa-banda).
func _livelli(img: Image, base: Color) -> Image:
	var lum: float = (base.r + base.g + base.b) / 3.0
	var bp: float = clampf(lum - 0.035, 0.0, 0.95)
	var wp: float = clampf(lum + 0.035, bp + 0.02, 1.0)
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			out.set_pixel(x, y, Color(
					clampf((c.r - bp) / (wp - bp), 0.0, 1.0),
					clampf((c.g - bp) / (wp - bp), 0.0, 1.0),
					clampf((c.b - bp) / (wp - bp), 0.0, 1.0)))
	return out

# Scarto medio (in livelli) fra originale e foto mostrata, FUORI dal riquadro del testo.
func _differenza_fuori(a: Image, b: Image, box: Rect2i) -> float:
	var somma := 0.0
	var n := 0
	var largo: Rect2i = box.grow(int(box.size.x * 0.6))
	for y in range(0, mini(a.get_height(), b.get_height()), 3):
		for x in range(0, mini(a.get_width(), b.get_width()), 3):
			if largo.has_point(Vector2i(x, y)):
				continue
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			somma += (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0 * 255.0
			n += 1
	return somma / float(maxi(1, n))
