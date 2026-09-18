extends Node

# Test della RIVELAZIONE della chiave nella foto: quanto e' LEGGIBILE il codice, glifo per
# glifo, misurato ATTRAVERSO LO SHADER VERO spazzando il cursore "Nitidezza" (detail).
#
# Perche' serviva. Nessun test toccava "detail": photo_chain_test "rivela" muovendo solo
# punto nero e punto bianco, quindi il passa-banda -- l'unico strumento su cui il puzzle si
# regge -- non era verificato da niente. E nessuna misura era per GLIFO: photo_key_test
# media sul "cuore" dei tratti prendendo il massimo GLOBALE come riferimento, cosi' due
# lettere forti coprono quattro sepolte, che e' esattamente il guasto che il proprietario
# vede su sun_person.jpg (codice illeggibile a qualunque posizione del cursore).
#
# Come funziona, ed e' la costruzione che lo rende affidabile:
#   le MASCHERE vengono da MONTE (la composizione con e senza la scritta: la differenza e'
#   esatta e senza rumore), i VALORI da VALLE (il SubViewport ospite, cioe' dopo lo shader).
#   Cosi' si sa con certezza dove sono i tratti anche quando a schermo non si vedono.
#
# Misure, per ogni cella di glifo g:
#   L_g     frazione dei punti del NUCLEO che cade fuori da [P1, P99] del FONDO della stessa
#           cella. E' il criterio primario: limitata, senza unita', e non mente quando
#           l'uscita dello shader taglia a 0/1 (dove il classico segnale/rumore esplode
#           perche' lo scarto del fondo crolla).
#   d'_g    differenza delle medie su sqrt(0.5*(var nucleo + var fondo)): continua, per tarare.
#   clip_g  frazione del fondo a 0 o 1: dice che si e' nella zona di taglio.
# Aggregati: PEGGIO = la peggiore delle 6 celle (una sola lettera sepolta rende il codice
# illeggibile), LEG = il meglio che PEGGIO raggiunge spazzando il cursore.
#
# A RIPOSO (cursori fermi) si misura anche la meta' "troppo palese" del problema:
#   A_g       media di |differenza| sul nucleo, in livelli su 255;
#   firma     la stessa differenza CON IL SEGNO: se |firma| e' molto meno di A_g, quello
#             che si vede non e' la scritta ma il BUCO che la Label semi-trasparente fa
#             nella trama della foto (l'appiattimento descritto in OSContent.CODE_ALPHA);
#   sigma     scarto della luminanza della foto sul fondo della cella: e' il rumore che
#             deve mascherare la scritta.
#
# Esecuzione (FINESTRA: serve il rasterizzatore per rileggere i pixel):
#   & $godot --path $proj res://tests/photo_reveal_test.tscn
# ============================================================

const SEME := 12345
const SEVERO := false            # true = i rilievi diventano fallimenti (dopo la fase 3)
const LEG_MIN := 0.75            # il glifo peggiore deve staccarsi in QUALCHE posizione
const RIPOSO_MAX := 0.15         # ...e a cursori FERMI non deve staccarsi affatto
const DETAIL_MAX_UTILE := 0.90   # il punto giusto deve stare dentro la corsa, non al fermo
const FILIGRANA_LIVELLI := 12.0  # sotto tanto la filigrana e' sempre accettabile
const FILIGRANA_K := 1.8         # ...oppure entro 1.8 volte il rumore locale
const SOGLIA_TRATTO := 0.15      # livelli: sopra qui il pixel appartiene a un tratto
const NUCLEO_FRAZ := 0.7         # nucleo = >= 0.7 del PICCO della cella
# Il "picco" della cella e' il 98esimo percentile, non il massimo: su un glifo sottile un
# solo pixel di antialiasing fortunato alzava il riferimento e il nucleo restava vuoto
# (misurato: mycity.jpg cella 1 con 5 punti, sun_person.jpg cella 4 con 3).
const PICCO_PERC := 0.98
const NUCLEO_MIN := 5            # meno punti di tanto e la media non significa niente

var _fails: Array = []
var _avvisi: Array = []

func _ready() -> void:
	get_tree().create_timer(900.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.start_new_run(SEME)
	var codice: String = GameManager.key_label(OSContent.KEY_IMAGE)
	print("codice di prova: %s   (una prova per FOTO, indipendente dal seme)" % codice)
	var riepilogo: Array = []
	for path in OSContent._photo_files():
		var r := await _prova_foto(path, codice)
		if not r.is_empty():
			riepilogo.append(r)
	_riepiloga(riepilogo)
	if _fails.is_empty():
		print("RISULTATO: PASS")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

func _prova_foto(path: String, codice: String) -> Dictionary:
	var nodo := {"name": path.get_file(), "type": "file", "icon": "image", "filetype": "image",
			"path": path, "code": codice, "code_seed": 7}
	var spot: Dictionary = OSContent._prepare_hiding_spot(nodo)
	if spot.is_empty():
		print("  %-22s non analizzabile" % path.get_file())
		return {}
	nodo["code_uv"] = spot["uv"]
	nodo["code_base"] = spot["avg"]
	nodo["code_delta"] = spot["delta"]
	if spot.has("blur_rect"):
		nodo["blur_rect"] = spot["blur_rect"]
		nodo["blur_target"] = spot["blur_target"]

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
	var lbl: Label = null
	if vp != null:
		for c in vp.get_children():
			if c is Label:
				lbl = c
	var view: TextureRect = null
	for c in app.find_children("*", "TextureRect", true, false):
		if c.material != null:
			view = c
	if vp == null or lbl == null or view == null:
		print("  %-22s visualizzatore incompleto" % path.get_file())
		host_vp.queue_free()
		return {}

	# --- le maschere, da MONTE ---
	var con := _img(vp)
	lbl.visible = false
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var senza := _img(vp)
	lbl.visible = true
	for i in range(2):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var celle := _celle(lbl, codice, con, senza, view, vp)
	if celle.is_empty():
		_ko("%s: geometria delle celle sbagliata (nucleo o fondo insufficienti)" % path.get_file())
		host_vp.queue_free()
		return {}

	# --- la spazzata del cursore, da VALLE ---
	print("\n%s   scarto %.4f  banda(peggiore) %.4f%s" % [
			path.get_file(), float(spot["delta"]), float(spot["sigma_bp"]),
			("  [SFOCATA]" if spot.has("blur_rect") else "")])
	_banda_vera(con, senza, celle)
	_varianti(con, senza, celle)
	print("  detail     L1    L2    L3    L4    L5    L6   PEGGIO  d'(peggio)  taglio")
	var risultati: Dictionary = {}
	for i in range(21):
		var d: float = snappedf(float(i) * 0.05, 0.01)
		var r := await _misura_a(app, host_vp, celle, d)
		risultati[d] = r
		_riga(d, r)
	# ATTENZIONE, errore da non rifare: la prima versione prendeva il massimo su TUTTO il
	# cursore, detail 0.00 compreso. Cosi' una foto col codice ben visibile a riposo usciva
	# "leggibile" con LEG 0.85 mentre il cursore non serviva a niente -- che e' esattamente
	# quello che il proprietario vedeva giocando. Sono due cose diverse e vanno separate:
	#   L_RIPOSO  quanto si stacca a cursori FERMI. Deve essere BASSO: e' il nascondiglio.
	#   LEG       il meglio che si ottiene MUOVENDO il cursore (detail > 0). Deve essere ALTO.
	# Una foto va bene solo se entrambe le condizioni valgono.
	var l_riposo: float = float(risultati[0.0]["peggio"])
	var best_d := 0.0
	var best_l := -1.0
	for d in risultati:
		if float(d) <= 0.001:
			continue
		if float(risultati[d]["peggio"]) > best_l:
			best_l = float(risultati[d]["peggio"])
			best_d = float(d)
	# affinamento attorno al massimo: il punto giusto puo' essere stretto
	var dd: float = maxf(0.0, best_d - 0.04)
	while dd <= minf(1.0, best_d + 0.04) + 0.001:
		var dq: float = snappedf(dd, 0.01)
		if dq > 0.001 and not risultati.has(dq):
			var r2 := await _misura_a(app, host_vp, celle, dq)
			risultati[dq] = r2
			if float(r2["peggio"]) > best_l:
				best_l = float(r2["peggio"])
				best_d = dq
		dd += 0.01
	app._mat.set_shader_parameter("detail", 0.0)

	# --- l'ALTRA via di rivelazione: la finestra dei LIVELLI ---
	# Il passa-banda separa per DIMENSIONE e su una foto con trama alla scala dei tratti
	# non ce la fa (misurato: serve grana_grossa/banda >= 6.8, le foto vere danno 0.4-0.9).
	# I livelli separano per INTENSITA': stringendo punto nero e punto bianco attorno al tono
	# della zona, 3 livelli diventano 255. Qui si misura quanto rende QUESTA via, con lo
	# stesso criterio per glifo, cosi' le due sono confrontabili.
	var base: Color = spot["avg"]
	var lum: float = (base.r + base.g + base.b) / 3.0
	var best_liv := -1.0
	var best_fin := 0.0
	print("  finestra livelli attorno a %.3f:" % lum)
	for fin in [0.010, 0.016, 0.025, 0.040, 0.060, 0.090]:
		var f: float = float(fin)
		var r3 := await _misura_livelli(app, host_vp, celle, lum, f)
		print("     +-%.3f  L per glifo %s  PEGGIO %.2f" % [f, str(r3["testo"]), float(r3["peggio"])])
		if float(r3["peggio"]) > best_liv:
			best_liv = float(r3["peggio"])
			best_fin = f
	app._mat.set_shader_parameter("black_point", 0.0)
	app._mat.set_shader_parameter("white_point", 1.0)
	print("  LIVELLI: meglio %.2f con finestra +-%.3f" % [best_liv, best_fin])

	# --- a riposo ---
	var a_txt: Array = []
	var f_txt: Array = []
	var s_txt: Array = []
	var a_peggio := 0.0
	var incoerenza := 0.0
	for c in celle:
		a_txt.append("%5.1f" % float(c["A"]))
		f_txt.append("%+5.1f" % float(c["A_firma"]))
		s_txt.append("%5.1f" % float(c["sigma_loc"]))
		a_peggio = maxf(a_peggio, float(c["A"]))
		incoerenza = maxf(incoerenza, float(c["A"]) / maxf(0.5, float(c["sigma_loc"])))
	print("  a riposo   A_g = %s livelli" % " ".join(a_txt))
	print("           firma = %s   (|firma| << A  =>  si vede il BUCO nella trama, non la scritta)" % " ".join(f_txt))
	print("           sigma = %s" % " ".join(s_txt))
	var nascosto: bool = l_riposo <= RIPOSO_MAX
	var leggibile: bool = best_l >= LEG_MIN
	var esito := "OK"
	if not nascosto and not leggibile:
		esito = "SI VEDE A RIPOSO *E* NON SI LEGGE"
	elif not nascosto:
		esito = "SI VEDE A RIPOSO (il cursore non serve)"
	elif not leggibile:
		esito = "NON SI LEGGE NEMMENO COL CURSORE"
	print("  a riposo L %.2f (max %.2f)  |  col cursore LEG %.2f al detail %.2f  ->  %s"
			% [l_riposo, RIPOSO_MAX, best_l, best_d, esito])

	if not nascosto:
		_nota("%s: si stacca gia' a cursori fermi (L riposo %.2f, limite %.2f)"
				% [path.get_file(), l_riposo, RIPOSO_MAX])
	if not leggibile:
		_nota("%s: LEG %.2f sotto %.2f -- il glifo peggiore non si stacca a nessun cursore"
				% [path.get_file(), best_l, LEG_MIN])
	elif best_d > DETAIL_MAX_UTILE:
		_nota("%s: il punto giusto e' a %.2f, praticamente al fermo del cursore"
				% [path.get_file(), best_d])
	for i in range(celle.size()):
		var cc: Dictionary = celle[i]
		var tetto: float = maxf(FILIGRANA_LIVELLI, FILIGRANA_K * float(cc["sigma_loc"]))
		if float(cc["A"]) > tetto:
			_nota("%s: glifo %d a riposo %.1f livelli contro un tetto di %.1f -- si vede senza regolare"
					% [path.get_file(), i + 1, float(cc["A"]), tetto])
			break

	host_vp.queue_free()
	await get_tree().process_frame
	return {"foto": path.get_file(), "leg": best_l, "detail": best_d, "riposo": l_riposo,
			"a_peggio": a_peggio, "incoerenza": incoerenza,
			"banda": float(spot["sigma_bp"]), "delta": float(spot["delta"]),
			"sigma": float(spot["sigma"]),
			"sfocata": spot.has("blur_rect")}

# ---------------- le celle dei glifi ----------------

# Una cella per carattere, dagli AVANZAMENTI del font vero: e' il solo modo di sapere dove
# finisce una lettera e comincia l'altra. Per ognuna si raccolgono i punti della
# composizione (per le maschere) e i corrispondenti punti dell'ospite (per i valori).
func _celle(lbl: Label, codice: String, con: Image, senza: Image, view: TextureRect, vp: SubViewport) -> Array:
	var font := Win95.font("sans")
	var fsize: int = maxi(10, int(Vector2(vp.size).y * OSContent.CODE_SIZE_FACTOR))
	var xs: Array = [0.0]
	for i in range(1, codice.length() + 1):
		xs.append(font.get_string_size(codice.substr(0, i), HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x)
	var t := lbl.get_transform()
	var inv := t.affine_inverse()
	# composizione -> ospite: il TextureRect centra la composizione conservando il rapporto
	# d'aspetto (STRETCH_KEEP_ASPECT_CENTERED), quindi scala e origine sono queste. Si
	# prende il pixel PIU' VICINO: mediare rimetterebbe la sfocatura che stiamo misurando.
	var s: float = minf(view.size.x / float(vp.size.x), view.size.y / float(vp.size.y))
	var origine: Vector2 = view.get_global_transform().origin + (view.size - Vector2(vp.size) * s) * 0.5
	var dim := con.get_size()

	var out: Array = []
	for g in range(codice.length()):
		var cella := Rect2(float(xs[g]), 0.0, float(xs[g + 1]) - float(xs[g]), lbl.size.y)
		var larga := cella.grow(2.0)
		var bb := Rect2(t * cella.position, Vector2.ZERO)
		for p in [cella.position + Vector2(cella.size.x, 0.0), cella.end,
				cella.position + Vector2(0.0, cella.size.y)]:
			bb = bb.expand(t * p)
		var zona := Rect2i(bb.grow(4.0)).intersection(Rect2i(Vector2i.ZERO, dim))
		var punti: Array = []
		var dentro: Array = []
		for y in range(zona.position.y, zona.end.y):
			for x in range(zona.position.x, zona.end.x):
				var loc: Vector2 = inv * Vector2(x, y)
				if not larga.has_point(loc):
					continue
				var firma: float = (_luma(con.get_pixel(x, y)) - _luma(senza.get_pixel(x, y))) * 255.0
				var stretta: bool = cella.has_point(loc)
				punti.append({"x": x, "y": y, "d": absf(firma), "f": firma, "stretta": stretta})
				if stretta:
					dentro.append(absf(firma))
		dentro.sort()
		var dmax: float = 0.0 if dentro.is_empty() else float(dentro[clampi(
				int(float(dentro.size()) * PICCO_PERC), 0, dentro.size() - 1)])
		if dmax < 0.5:
			print("   cella %d: la scritta non cambia nemmeno un livello" % (g + 1))
			return []
		# maschera dei tratti DILATATA di 2 px: il fondo non deve toccare l'antialiasing
		var tratto: Dictionary = {}
		for p in punti:
			if float(p["d"]) >= SOGLIA_TRATTO:
				tratto[Vector2i(int(p["x"]), int(p["y"]))] = true
		var nucleo: Array = []
		var fondo: Array = []
		var nucleo_comp: Array = []
		var fondo_comp: Array = []
		var a_somma := 0.0
		var f_somma := 0.0
		var lum_somma := 0.0
		var lum_somma2 := 0.0
		for p in punti:
			var pv := Vector2i(int(p["x"]), int(p["y"]))
			if bool(p["stretta"]) and float(p["d"]) >= dmax * NUCLEO_FRAZ:
				nucleo.append(_ospite(origine, s, pv))
				nucleo_comp.append(pv)
				a_somma += float(p["d"])
				f_somma += float(p["f"])
			elif float(p["d"]) < SOGLIA_TRATTO and not _vicino(tratto, pv, 2):
				fondo.append(_ospite(origine, s, pv))
				fondo_comp.append(pv)
				var l: float = _luma(senza.get_pixel(pv.x, pv.y)) * 255.0
				lum_somma += l
				lum_somma2 += l * l
		if nucleo.size() < NUCLEO_MIN or fondo.size() < 40:
			print("   cella %d: nucleo %d, fondo %d -- geometria insufficiente"
					% [g + 1, nucleo.size(), fondo.size()])
			return []
		var nf := float(fondo.size())
		var media := lum_somma / nf
		out.append({
			"nucleo": nucleo, "fondo": fondo,
			"nucleo_comp": nucleo_comp, "fondo_comp": fondo_comp,
			"A": a_somma / float(nucleo.size()),
			"A_firma": f_somma / float(nucleo.size()),
			"sigma_loc": sqrt(maxf(0.0, lum_somma2 / nf - media * media)),
		})
	return out

func _ospite(origine: Vector2, s: float, p: Vector2i) -> Vector2i:
	var q: Vector2 = origine + (Vector2(p) + Vector2(0.5, 0.5)) * s
	return Vector2i(int(round(q.x)), int(round(q.y)))

func _vicino(tratto: Dictionary, p: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if tratto.has(p + Vector2i(dx, dy)):
				return true
	return false

# Segnale e rumore nella banda VERA dello shader, cella per cella. E' il numero che decide
# se il codice possa essere rivelato: la zona morta del cursore fa passare i tratti e non il
# rumore solo se il rapporto supera 1/DEAD (~2.2). Il generatore stima questo rapporto con
# la piramide, che e' un ALTRO filtro -- qui si misura quello giusto.
func _banda_vera(con: Image, senza: Image, celle: Array) -> void:
	var w := senza.get_width()
	var h := senza.get_height()
	var lc := OSContent.bp_luma(con)
	var ls := OSContent.bp_luma(senza)
	var righe: Array = []
	var risposte: Array = []
	var risposte_v: Array = []
	var peggiore := 999.0
	for c in celle:
		var seg_somma := 0.0
		for p in c["nucleo_comp"]:
			var q: Vector2i = p
			seg_somma += absf(OSContent.bp_shader_at(lc, w, h, q.x, q.y)
					- OSContent.bp_shader_at(ls, w, h, q.x, q.y))
		var segnale: float = seg_somma / float(maxi(1, c["nucleo_comp"].size()))
		var rum2 := 0.0
		for p in c["fondo_comp"]:
			var q2: Vector2i = p
			var b: float = OSContent.bp_shader_at(ls, w, h, q2.x, q2.y)
			rum2 += b * b
		var rumore: float = sqrt(rum2 / float(maxi(1, c["fondo_comp"].size())))
		var rap: float = (segnale / rumore) if rumore > 0.00002 else 999.0
		righe.append("%5.2f" % rap)
		peggiore = minf(peggiore, rap)
		# lo scarto COMPOSTO di un tratto e' A (in livelli): la risposta e' banda/scarto
		var scarto: float = float(c["A"]) / 255.0
		var risp: float = (segnale / scarto) if scarto > 0.0005 else 0.0
		risposte.append("%5.2f" % risp)
		risposte_v.append(risp)
	print("  banda vera dello shader: rapporto per glifo %s -> PEGGIORE %.2f  (serve >= %.1f)"
			% [" ".join(righe), peggiore, 1.0 / 0.45])
	# RISPOSTA del filtro: quanta ampiezza di banda produce un tratto di scarto noto. E' la
	# costante CODE_BP_RESPONSE, che finora era 0.65 tarata sulla piramide -- cioe' su un
	# filtro che il giocatore non usa mai.
	print("  risposta del filtro ai tratti: %s  (media %.2f)  -> CODE_BP_RESPONSE"
			% [" ".join(risposte), _media(risposte_v)])

# Varianti di KERNEL a confronto, sullo stesso punto e sugli stessi glifi. Conta una sola
# colonna: il rapporto del glifo PEGGIORE, perche' una lettera sepolta rende illeggibile
# tutto il codice. Serve a scegliere il filtro per misura e non per intuizione -- la banda
# va accordata sui tratti veri (2.2-2.5 px), e il termine "fine dentro larga" sottraeva
# segnale senza dare niente in cambio.
const VARIANTI := [
	{"nome": "A attuale (0.2 fine in larga)", "fine_centro": 0.5, "fine_raggio": 1.0,
		"anelli": [1.8, 3.8, 6.8], "pesi": [0.02879, 0.04283, 0.02838], "fine_in_larga": 0.2},
	{"nome": "B senza fine in larga", "fine_centro": 0.5, "fine_raggio": 1.0,
		"anelli": [1.8, 3.8, 6.8], "pesi": [0.035988, 0.053538, 0.035475], "fine_in_larga": 0.0},
	{"nome": "C fine solo centro", "fine_centro": 1.0, "fine_raggio": 1.0,
		"anelli": [1.8, 3.8, 6.8], "pesi": [0.035988, 0.053538, 0.035475], "fine_in_larga": 0.0},
	{"nome": "D larga piu' larga", "fine_centro": 0.5, "fine_raggio": 1.0,
		"anelli": [2.6, 5.2, 9.0], "pesi": [0.035988, 0.053538, 0.035475], "fine_in_larga": 0.0},
	{"nome": "E larga piu' stretta", "fine_centro": 0.5, "fine_raggio": 1.0,
		"anelli": [1.4, 2.8, 5.0], "pesi": [0.035988, 0.053538, 0.035475], "fine_in_larga": 0.0},
	{"nome": "F fine 1.4 + larga media", "fine_centro": 0.4, "fine_raggio": 1.4,
		"anelli": [2.2, 4.4, 7.6], "pesi": [0.035988, 0.053538, 0.035475], "fine_in_larga": 0.0},
]

func _varianti(con: Image, senza: Image, celle: Array) -> void:
	var w := senza.get_width()
	var h := senza.get_height()
	var lc := OSContent.bp_luma(con)
	var ls := OSContent.bp_luma(senza)
	print("  varianti di kernel (rapporto del glifo PEGGIORE, e risposta media):")
	for v in VARIANTI:
		var ker: Dictionary = {
			"fine_centro": v["fine_centro"], "fine_raggio": v["fine_raggio"],
			"anelli": v["anelli"], "pesi": v["pesi"], "fine_in_larga": v["fine_in_larga"]}
		var peggio := 999.0
		var risp: Array = []
		for c in celle:
			var seg_somma := 0.0
			for p in c["nucleo_comp"]:
				var q: Vector2i = p
				seg_somma += absf(OSContent.bp_at_kernel(lc, w, h, q.x, q.y, ker)
						- OSContent.bp_at_kernel(ls, w, h, q.x, q.y, ker))
			var segnale: float = seg_somma / float(maxi(1, c["nucleo_comp"].size()))
			var rum2 := 0.0
			for p in c["fondo_comp"]:
				var q2: Vector2i = p
				var b: float = OSContent.bp_at_kernel(ls, w, h, q2.x, q2.y, ker)
				rum2 += b * b
			var rumore: float = sqrt(rum2 / float(maxi(1, c["fondo_comp"].size())))
			peggio = minf(peggio, (segnale / rumore) if rumore > 0.00002 else 999.0)
			var scarto: float = float(c["A"]) / 255.0
			risp.append((segnale / scarto) if scarto > 0.0005 else 0.0)
		print("     %-32s peggiore %6.2f   risposta %.2f" % [str(v["nome"]), peggio, _media(risp)])

func _media(v: Array) -> float:
	var somma := 0.0
	for x in v:
		somma += float(x)
	return somma / float(maxi(1, v.size()))

# ---------------- la misura a un dato cursore ----------------

func _misura_a(app: ImageViewerApp, host_vp: SubViewport, celle: Array, d: float) -> Dictionary:
	app._mat.set_shader_parameter("detail", d)
	for i in range(2):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := _img(host_vp)
	var dim := img.get_size()
	var elle: Array = []
	var dprimi: Array = []
	var tagli: Array = []
	for c in celle:
		var vf := _valori(img, c["fondo"], dim)
		var vn := _valori(img, c["nucleo"], dim)
		if vf.size() < 10 or vn.size() < 4:
			elle.append(0.0)
			dprimi.append(0.0)
			tagli.append(0.0)
			continue
		vf.sort()
		var p1: float = float(vf[clampi(int(float(vf.size()) * 0.01), 0, vf.size() - 1)])
		var p99: float = float(vf[clampi(int(float(vf.size()) * 0.99), 0, vf.size() - 1)])
		var fuori := 0
		for v in vn:
			if float(v) < p1 or float(v) > p99:
				fuori += 1
		elle.append(float(fuori) / float(vn.size()))
		var sf := _stat(vf)
		var sn := _stat(vn)
		var pool: float = sqrt(maxf(0.000001, 0.5 * (float(sf["var"]) + float(sn["var"]))))
		dprimi.append(absf(float(sn["media"]) - float(sf["media"])) / pool)
		var estremi := 0
		for v in vf:
			if float(v) <= 0.002 or float(v) >= 0.998:
				estremi += 1
		tagli.append(float(estremi) / float(vf.size()))
	var peggio := 1.0
	var idx := 0
	for i in range(elle.size()):
		if float(elle[i]) < peggio:
			peggio = float(elle[i])
			idx = i
	return {"L": elle, "peggio": peggio, "dprimo": float(dprimi[idx]), "taglio": float(tagli[idx])}

# Come _misura_a ma muovendo punto nero / punto bianco invece della nitidezza.
func _misura_livelli(app: ImageViewerApp, host_vp: SubViewport, celle: Array,
		lum: float, fin: float) -> Dictionary:
	app._mat.set_shader_parameter("black_point", clampf(lum - fin, 0.0, 0.95))
	app._mat.set_shader_parameter("white_point", clampf(lum + fin, 0.05, 1.0))
	for i in range(2):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := _img(host_vp)
	var dim := img.get_size()
	var elle: Array = []
	var testo: Array = []
	for c in celle:
		var vf := _valori(img, c["fondo"], dim)
		var vn := _valori(img, c["nucleo"], dim)
		if vf.size() < 10 or vn.size() < 4:
			elle.append(0.0)
			testo.append(" 0.00")
			continue
		vf.sort()
		var p1: float = float(vf[clampi(int(float(vf.size()) * 0.01), 0, vf.size() - 1)])
		var p99: float = float(vf[clampi(int(float(vf.size()) * 0.99), 0, vf.size() - 1)])
		var fuori := 0
		for v in vn:
			if float(v) < p1 or float(v) > p99:
				fuori += 1
		var l: float = float(fuori) / float(vn.size())
		elle.append(l)
		testo.append("%5.2f" % l)
	var peggio := 1.0
	for l2 in elle:
		peggio = minf(peggio, float(l2))
	return {"peggio": peggio, "testo": " ".join(testo)}

func _valori(img: Image, punti: Array, dim: Vector2i) -> Array:
	var out: Array = []
	for p in punti:
		var q: Vector2i = p
		if q.x < 0 or q.y < 0 or q.x >= dim.x or q.y >= dim.y:
			continue
		out.append(_luma(img.get_pixel(q.x, q.y)))
	return out

func _stat(v: Array) -> Dictionary:
	var somma := 0.0
	var somma2 := 0.0
	for x in v:
		somma += float(x)
		somma2 += float(x) * float(x)
	var n := float(maxi(1, v.size()))
	var media := somma / n
	return {"media": media, "var": maxf(0.0, somma2 / n - media * media)}

func _riga(d: float, r: Dictionary) -> void:
	var celle: Array = []
	for l in r["L"]:
		celle.append("%5.2f" % float(l))
	print("   %.2f  %s   %5.2f      %6.2f     %.3f" % [
			d, " ".join(celle), float(r["peggio"]), float(r["dprimo"]), float(r["taglio"])])

# ---------------- riepilogo ----------------

func _riepiloga(righe: Array) -> void:
	print("\n=== riepilogo ===")
	print("%-22s %7s %7s %7s %6s %7s %6s" % ["foto", "banda", "sigma", "riposo", "LEG", "detail", "A_max"])
	var incoerenze: Array = []
	for r in righe:
		print("%-22s %7.4f %7.4f %7.2f %6.2f %7.2f %6.1f%s%s" % [
				str(r["foto"]), float(r["banda"]), float(r["sigma"]), float(r["riposo"]),
				float(r["leg"]), float(r["detail"]), float(r["a_peggio"]),
				("  SFOCATA" if bool(r["sfocata"]) else ""),
				("" if (float(r["riposo"]) <= RIPOSO_MAX and float(r["leg"]) >= LEG_MIN) else "  <-- NO")])
		incoerenze.append(float(r["incoerenza"]))
	if incoerenze.size() >= 2:
		var mn: float = float(incoerenze[0])
		var mx: float = float(incoerenze[0])
		for v in incoerenze:
			mn = minf(mn, float(v))
			mx = maxf(mx, float(v))
		print("filigrana (A/sigma) da %.1f a %.1f: piu' larga la forbice, piu' e' incoerente fra foto calme e mosse"
				% [mn, mx])
	if not _avvisi.is_empty():
		print("\n%d rilievi%s:" % [_avvisi.size(),
				("  (AVVISI: non fanno fallire finche' SEVERO = false)" if not SEVERO else "")])
		for a in _avvisi:
			print("   - " + str(a))

func _img(vp: SubViewport) -> Image:
	var img := vp.get_texture().get_image()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img

func _luma(c: Color) -> float:
	return (c.r + c.g + c.b) / 3.0

func _nota(perche: String) -> void:
	_avvisi.append(perche)
	if SEVERO:
		_fails.append(perche.get_slice(":", 0))

func _ko(perche: String) -> void:
	print("FAIL  " + perche)
	_fails.append(perche.get_slice(":", 0))
