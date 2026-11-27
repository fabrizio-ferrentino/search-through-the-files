extends Node

# Test della CATENA VERA della chiave-foto: non basta che il codice sia giusto nella
# composizione, deve arrivare agli OCCHI DEL GIOCATORE. In mezzo ci sono tre passaggi
# che possono cancellarlo:
#   composizione (SubViewport del visualizzatore, max 640x480)
#     -> riquadro della finestra dell'OS   (se la finestra e' piccola, RIMPICCIOLISCE)
#       -> schermo dell'OS 1440x1080
#         -> finestra di gioco (x0.667) + filtro CRT
#
# Storia (13/09/2026): con la finestra a 620x480 la foto veniva rimpicciolita del 40% e
# la scritta arrivava con 123 pixel — sei caratteri in 123 pixel sono una macchiolina,
# non un codice. Ingrandita la finestra (910x590) si e' passati a 575 pixel.
#
# Verifica anche la RIVELAZIONE (27/11/2026) sullo schermo vero: a riposo la scritta non
# deve arrivare a schermo per niente; spingendo il cursore giusto a meta' corsa e' un'ombra,
# in fondo si legge.
#
# Esecuzione (FINESTRA):
#   & $godot --path $proj res://tests/photo_chain_test.tscn
# ============================================================

const SEME := 12345          # da qui si cerca il primo seme con la chiave nei PIXEL
const PIXEL_MIN := 300      # pixel della scritta che devono sopravvivere fino allo schermo
const OUT := "C:/Users/ffria/AppData/Local/Temp/claude/z--Progetti-Search-Through-the-Files/1536785d-988b-4eed-baf2-48564844db2c/scratchpad/catena/"

var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var seme := SEME
	for i in range(60):
		GameManager.start_new_run(SEME + i)
		if not _portatrice().is_empty():
			seme = SEME + i
			break
	GameManager.start_new_run(seme)
	GameManager.pc_on = true
	GameManager.logged_in = true
	var stanza: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(stanza)
	for i in range(25):
		await get_tree().process_frame
	var cam := stanza.get_node_or_null("Camera3D")
	cam._show_pc_overlay()
	for i in range(5):
		await get_tree().process_frame

	# Il nome della cartella e' TRADOTTO (locale/ui.csv): cercarlo scritto in italiano
	# funzionava solo finche' il gioco era in italiano. La chiave invece non cambia.
	var foto := _portatrice()
	if foto.is_empty():
		print("RISULTATO: FAIL -> nessuna foto porta la chiave")
		get_tree().quit(1)
		return
	print("chiave ", GameManager.key_label(OSContent.KEY_IMAGE), " su ", foto.get("name"),
			" (", str(foto.get("path", "")).get_file(), ")")

	var win = cam._os.open_app("image", foto)
	for i in range(10):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var app: ImageViewerApp = null
	for c in win.content_root.get_children():
		if c is ImageViewerApp:
			app = c
	var vp: SubViewport = null
	for c in app.get_children():
		if c is SubViewport:
			vp = c
	var lbl: Label = null
	for c in vp.get_children():
		if c is Label:
			lbl = c
	if app == null or vp == null or lbl == null:
		print("RISULTATO: FAIL -> visualizzatore o scritta non trovati")
		get_tree().quit(1)
		return
	var view: TextureRect = null
	for c in app.find_children("*", "TextureRect", true, false):
		if c.material != null:
			view = c
	var scala: float = view.size.x / float(maxi(1, vp.size.x))
	print("composizione ", vp.size, " -> riquadro a video ", view.size, " (scala %.2f)" % scala)
	_check("NIENTE_RIMPICCIOLIMENTO", scala >= 0.98,
			"la finestra rimpicciolisce la foto (scala %.2f): la scritta si perde" % scala)

	var ric: Array = foto.get("ricetta", [])
	print("ricetta: ", OSContent.ricetta_testo(ric))

	# --- a riposo: niente ---
	var riposo := await _misura(lbl)
	print("a riposo     : %d pixel, cuore %.2f livelli" % [int(riposo["pixel"]), float(riposo["cuore"])])
	_check("A_RIPOSO_NON_C_E", int(riposo["pixel"]) == 0,
			"a riposo %d pixel della scritta arrivano a schermo" % int(riposo["pixel"]))

	# --- il cursore giusto a meta' corsa: piu' di niente, meno della piena ---
	var p := str(ric[0]["param"])
	var verso := int(ric[0]["verso"])
	var d := ImageViewerApp.posizione(p, float(ImageViewerApp.DEFAULTS[p]))
	var lato: float = (1.0 - d) if verso > 0 else d
	_cursore(app, p, ImageViewerApp.valore_a(p, d + float(verso) * 0.4 * lato))
	var meta := await _misura(lbl)
	print("a meta' corsa: %d pixel, cuore %.2f livelli" % [int(meta["pixel"]), float(meta["cuore"])])

	# --- in fondo: si legge, sullo schermo vero (finestra + CRT) ---
	_cursore(app, p, ImageViewerApp.valore_a(p, 1.0 if verso > 0 else 0.0))
	var tutta := await _misura(lbl)
	print("in fondo     : %d pixel, cuore %.2f livelli" % [int(tutta["pixel"]), float(tutta["cuore"])])
	_check("GRADUALE", float(meta["cuore"]) > 0.0 and float(meta["cuore"]) < float(tutta["cuore"]),
			"a meta' corsa %.1f livelli, in fondo %.1f: non cresce per gradi" % [float(meta["cuore"]), float(tutta["cuore"])])
	_check("ARRIVA_A_SCHERMO", int(tutta["pixel"]) >= PIXEL_MIN,
			"solo %d pixel della scritta arrivano a schermo (minimo %d)" % [int(tutta["pixel"]), PIXEL_MIN])
	_check("RIVELAZIONE", float(tutta["cuore"]) >= 25.0,
			"in fondo il codice sale solo a %.1f livelli: troppo poco per leggerlo" % float(tutta["cuore"]))

	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "rivelata.png")
	print("schermata in ", OUT, "rivelata.png")

	if _fails.is_empty():
		print("RISULTATO: PASS (la chiave arriva a schermo e si rivela)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# La foto che porta la chiave nei PIXEL (quella col codice nel file non ha "ricetta").
func _portatrice() -> Dictionary:
	for c in _trova(VFS.get_root(), OSContent._t("VFS_PICTURES")).get("children", []):
		if c is Dictionary and str(c.get("code", "")) != "" and c.has("ricetta"):
			return c
	return {}

# Muove un cursore VERO del visualizzatore (come farebbe il giocatore).
func _cursore(app: ImageViewerApp, param: String, valore: float) -> void:
	for e in app._sliders:
		if str(e["param"]) == param:
			(e["node"] as HSlider).value = valore

# Schermo intero con e senza la scritta: quanto ne arriva agli occhi del giocatore.
func _misura(lbl: Label) -> Dictionary:
	for i in range(5):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var con := get_viewport().get_texture().get_image()
	lbl.visible = false
	for i in range(4):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var senza := get_viewport().get_texture().get_image()
	lbl.visible = true
	return _delta(con, senza, Rect2(Vector2.ZERO, Vector2(con.get_size())))

# Quanti pixel cambia la scritta e di quanto (cuore dei tratti: i pixel che cambiano
# almeno la meta' del massimo — la media su tutti sottostima, i bordi sfumati contano poco).
func _delta(a: Image, b: Image, zona: Rect2) -> Dictionary:
	var x0 := maxi(0, int(zona.position.x))
	var y0 := maxi(0, int(zona.position.y))
	var x1 := mini(a.get_width(), int(zona.end.x))
	var y1 := mini(a.get_height(), int(zona.end.y))
	var diff: Array = []
	for y in range(y0, y1):
		for x in range(x0, x1):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d: float = (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) / 3.0 * 255.0
			if d > 0.4:
				diff.append(d)
	if diff.is_empty():
		return {"pixel": 0, "cuore": 0.0}
	var dmax := 0.0
	for d in diff:
		dmax = maxf(dmax, float(d))
	var somma := 0.0
	var n := 0
	for d in diff:
		if float(d) >= dmax * 0.5:
			somma += float(d)
			n += 1
	return {"pixel": diff.size(), "cuore": somma / float(maxi(1, n))}

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		_fails.append(nome)

func _trova(nodo: Dictionary, nome: String) -> Dictionary:
	if str(nodo.get("name", "")) == nome:
		return nodo
	for c in nodo.get("children", []):
		if c is Dictionary:
			var r := _trova(c, nome)
			if not r.is_empty():
				return r
	return {}
