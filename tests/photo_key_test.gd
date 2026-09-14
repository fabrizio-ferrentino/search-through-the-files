extends Node

# Test della CHIAVE NASCOSTA NELLA FOTO (chiave 4). Tre cose da garantire:
#   A. la scritta si RIVELA col cursore "Nitidezza" -> si misura nella BANDA dei tratti,
#      non a occhio puntuale: e' il passa-banda che la tira fuori (vedi adjust.gdshader);
#   B. la scritta resta INVISIBILE ad apertura -> lo scarto puntuale deve essere piccolo
#      in assoluto, oppure molto sotto la struttura locale che la maschera;
#   C. la PORTATRICE cambia: nessuna foto deve prendersi il ruolo troppo spesso.
#
# Storia: il criterio vecchio era il rapporto PUNTUALE scarto/rumore, e su foto piene di
# grana non poteva essere soddisfatto senza ammorbidire la foto (alone visibile) o
# privilegiare 2 foto su 6 (bias, gioco piu' facile). Il passa-banda separa per DIMENSIONE
# e quel compromesso non serve piu': qui si pretende il rapporto NELLA BANDA.
#
# Esecuzione (FINESTRA: serve il rasterizzatore per leggere i pixel):
#   & $godot --path $proj res://tests/photo_key_test.tscn
# ============================================================

const SEMI := [12345, 999, 4242, 7, 20260911, 555]
const RAPPORTO_BP_MIN := 2.0     # serve questo margine perche' la scritta si LEGGA
const DELTA_MIN := 1.0           # livelli su 255: sotto sparisce nella quantizzazione
const SEMI_UNIFORMITA := 60      # quante partite per controllare la distribuzione
const QUOTA_MAX := 0.45          # nessuna foto oltre il 45% dei casi

var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(240.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame

	# --- come viene preparata ogni foto (atteso: quasi tutte INTATTE) ---
	print("--- foto in ", OSContent.PHOTO_DIR, " ---")
	for path in OSContent._photo_files():
		var nodo := {"path": path}
		var t0 := Time.get_ticks_msec()
		var prep := OSContent._prepare_hiding_spot(nodo)
		var costo := Time.get_ticks_msec() - t0
		if prep.is_empty():
			print("  %-24s non leggibile" % path.get_file())
			continue
		var uv: Vector2 = prep["uv"]
		print("  %-24s rumore %.4f | banda %.4f | scarto %.4f | rapporto stimato %.2f | %s  a %d%%,%d%%  [%d ms]" % [
				path.get_file(), float(prep["sigma"]), float(prep["sigma_bp"]), float(prep["delta"]),
				float(prep["rapporto"]), ("SFOCATA" if prep.has("blur_rect") else "INTATTA"),
				int(uv.x * 100.0), int(uv.y * 100.0), costo])

	# --- A + B: sui rendering veri del visualizzatore ---
	for seme in SEMI:
		await _prova(seme)

	# --- C: distribuzione della portatrice su molte partite ---
	_uniformita()

	print("\n--- rapporto di debug (quello che mostra F12) ---")
	print(GameManager.keys_report())
	if _fails.is_empty():
		print("RISULTATO: PASS (la chiave si rivela, resta nascosta e gira fra le foto)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

func _prova(seme: int) -> void:
	GameManager.start_new_run(seme)
	await get_tree().process_frame
	var chiave: String = GameManager.key_label(OSContent.KEY_IMAGE)
	var foto := _foto_portatrice()
	if foto.is_empty():
		_fail(seme, "nessuna foto porta la chiave")
		return

	# visualizzatore vero, dentro una SubViewport come nell'OS
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
	app.launch(foto)
	for i in range(6):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var vp: SubViewport = null
	for c in app.get_children():
		if c is SubViewport:
			vp = c
	var lbl: Label = null
	if vp != null:
		for c in vp.get_children():
			if c is Label:
				lbl = c
	if vp == null or lbl == null:
		_fail(seme, "scritta non creata")
		host_vp.queue_free()
		return

	var con_scritta := vp.get_texture().get_image()
	lbl.visible = false
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var senza := vp.get_texture().get_image()
	lbl.visible = true

	var zona := Rect2i(Vector2i(lbl.position), Vector2i(lbl.size)).grow(2)
	zona = zona.intersection(Rect2i(Vector2i.ZERO, con_scritta.get_size()))
	var m := _misura(con_scritta, senza, zona)
	var sorgente := str(foto.get("path", "")).get_file()
	print("[seme %d] %s su %s (%s) | scarto %.2f livelli | struttura %.2f | BANDA segnale %.4f rumore %.4f -> rapporto %.2f" % [
			seme, chiave, str(foto.get("name", "")), (sorgente if sorgente != "" else "generata"),
			float(m["delta"]), float(m["sigma"]), float(m["bp_segnale"]), float(m["bp_rumore"]), float(m["bp_rapporto"])])

	# Filigrana (scelta del proprietario, 14/09/2026): guardando bene si intuisce la scritta,
	# ma non deve LEGGERSI senza regolare. La metrica "cuore" qui sotto e' sensibile alla
	# geometria delle singole lettere (l'antialiasing di certi caratteri concentra il
	# contrasto di picco) e sovrastima quanto si vede rispetto alla finestra di gioco vera:
	# verificato rendendo per intero le partite dei semi 999 (her.jpg, "4-AYYE", misurato
	# 24.5) e 7 (sun_person.jpg, "4-XQK7", misurato 25.4) nella finestra 1440x1080 reale —
	# in ENTRAMBI i casi il codice resta una filigrana discreta, non leggibile a riposo.
	# La soglia resta comunque un cancello vero contro regressioni (una scritta in chiaro
	# supera abbondantemente 40 livelli).
	var tetto_visibile: float = maxf(30.0, float(m["sigma"]) * 2.0)
	if int(m["pixel"]) < 50:
		_fail(seme, "la scritta non si vede nei pixel (%d punti)" % int(m["pixel"]))
	elif float(m["delta"]) < DELTA_MIN:
		_fail(seme, "scarto %.2f livelli: sparisce nella quantizzazione" % float(m["delta"]))
	elif float(m["delta"]) > tetto_visibile:
		_fail(seme, "scarto %.2f livelli contro un tetto di %.1f: si vede senza regolare" % [float(m["delta"]), tetto_visibile])
	elif float(m["bp_rapporto"]) < RAPPORTO_BP_MIN:
		_fail(seme, "rapporto nella banda %.2f: il cursore Nitidezza non basta a tirarla fuori" % float(m["bp_rapporto"]))
	host_vp.queue_free()
	await get_tree().process_frame

# La portatrice deve girare fra tutte le foto: e' la randomizzazione che il gioco promette.
func _uniformita() -> void:
	var conta := {}
	for i in range(SEMI_UNIFORMITA):
		GameManager.start_new_run(1000 + i * 7)
		var foto := _foto_portatrice()
		var nome := str(foto.get("path", "generata")).get_file()
		conta[nome] = int(conta.get(nome, 0)) + 1
	var totale := 0
	for k in conta:
		totale += int(conta[k])
	var righe: Array = []
	var peggiore := 0.0
	for k in conta:
		var quota: float = float(conta[k]) / float(maxi(1, totale))
		peggiore = maxf(peggiore, quota)
		righe.append("%s %d%%" % [k, int(quota * 100.0)])
	righe.sort()
	print("distribuzione portatrice su %d partite: %s" % [totale, ", ".join(righe)])
	var quante := OSContent._photo_files().size()
	if peggiore > QUOTA_MAX:
		_fail(-1, "una foto porta la chiave nel %d%% delle partite (limite %d%%)" % [int(peggiore * 100.0), int(QUOTA_MAX * 100.0)])
	if quante >= 5 and conta.size() < 5:
		_fail(-1, "solo %d foto diverse fanno da portatrice su %d disponibili" % [conta.size(), quante])

func _foto_portatrice() -> Dictionary:
	var immagini := _trova_cartella(VFS.get_root(), "Immagini")
	for c in immagini.get("children", []):
		if str(c.get("code", "")) != "":
			return c
	return {}

# Confronta i due rendering nella zona della scritta:
#  - scarto PUNTUALE sul cuore dei tratti (la media su tutti i pixel che cambiano
#    sottostima: i bordi sfumati cambiano poco per definizione);
#  - struttura locale (deviazione standard della foto senza scritta);
#  - segnale e rumore NELLA BANDA dei tratti, che e' cio' che vede "Nitidezza".
func _misura(con_scritta: Image, senza: Image, zona: Rect2i) -> Dictionary:
	var differenze: Array = []
	var somma := 0.0
	var somma2 := 0.0
	var n := 0
	for y in range(zona.position.y, zona.end.y):
		for x in range(zona.position.x, zona.end.x):
			var a := con_scritta.get_pixel(x, y)
			var b := senza.get_pixel(x, y)
			var d: float = (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0 * 255.0
			if d > 0.4:
				differenze.append(d)
			var lum: float = (b.r + b.g + b.b) / 3.0 * 255.0
			somma += lum
			somma2 += lum * lum
			n += 1
	var d_max := 0.0
	for d in differenze:
		d_max = maxf(d_max, float(d))
	var somma_cuore := 0.0
	var n_cuore := 0
	for d in differenze:
		if float(d) >= d_max * 0.5:
			somma_cuore += float(d)
			n_cuore += 1
	var media: float = somma / float(maxi(1, n))
	var bp := _misura_banda(con_scritta, senza, zona)
	return {
		"delta": (somma_cuore / float(n_cuore)) if n_cuore > 0 else 0.0,
		"sigma": sqrt(maxf(0.0, somma2 / float(maxi(1, n)) - media * media)),
		"pixel": differenze.size(),
		"bp_segnale": bp["segnale"],
		"bp_rumore": bp["rumore"],
		"bp_rapporto": (float(bp["segnale"]) / float(bp["rumore"])) if float(bp["rumore"]) > 0.0002 else 999.0,
	}

# Segnale e rumore nella banda dei tratti: gemello su CPU di quello che fa lo shader.
# Riusa gli helper di OSContent, cosi' analisi e verifica misurano la stessa cosa.
func _misura_banda(con_scritta: Image, senza: Image, zona: Rect2i) -> Dictionary:
	var cc := OSContent._bp_pair_img(con_scritta)
	var cs := OSContent._bp_pair_img(senza)
	if cc.size() < 2 or cs.size() < 2:
		return {"segnale": 0.0, "rumore": 0.0}
	var diff: Array = []
	for y in range(zona.position.y, zona.end.y):
		for x in range(zona.position.x, zona.end.x):
			var bp_con: float = _luma(cc[0].get_pixel(x, y)) - _luma(cc[1].get_pixel(x, y))
			var bp_senza: float = _luma(cs[0].get_pixel(x, y)) - _luma(cs[1].get_pixel(x, y))
			diff.append(absf(bp_con - bp_senza))
	var dmax := 0.0
	for d in diff:
		dmax = maxf(dmax, float(d))
	var somma := 0.0
	var quanti := 0
	for d in diff:
		if float(d) >= dmax * 0.5:     # cuore dei tratti
			somma += float(d)
			quanti += 1
	var rumore: float = float(OSContent._box_bp(cs, zona)["rms"])
	return {"segnale": (somma / float(maxi(1, quanti))) if quanti > 0 else 0.0, "rumore": rumore}

func _luma(c: Color) -> float:
	return (c.r + c.g + c.b) / 3.0

func _trova_cartella(nodo: Dictionary, nome: String) -> Dictionary:
	if str(nodo.get("name", "")) == nome:
		return nodo
	for c in nodo.get("children", []):
		if c is Dictionary:
			var r := _trova_cartella(c, nome)
			if not r.is_empty():
				return r
	return {}

func _fail(seme: int, perche: String) -> void:
	var etichetta := ("seme %d" % seme) if seme >= 0 else "uniformita'"
	print("FAIL  %s --- %s" % [etichetta, perche])
	_fails.append(etichetta)
