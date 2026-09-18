extends Node

# STRUMENTO: risponde alla domanda che decide se il puzzle dell'immagine possa funzionare.
#
# Perche' il codice sia NASCOSTO a riposo serve struttura locale che lo mascheri, alla scala
# in cui l'occhio guarda una scritta alta ~25 px (chiamiamola "grana grossa", 4-15 px).
# Perche' sia RIVELABILE col cursore serve che la stessa zona sia PULITA alla scala dei
# tratti (2-3 px), che e' la banda del filtro.
# Le due cose tirano in direzioni opposte, ma NON sono la stessa cosa: una zona marezzata e
# morbida (sfondo fuori fuoco, muro macchiato, cielo con nuvole sfumate) ha molta grana
# grossa e poca grana fine. Qui si cerca proprio quella.
#
# Il conto della fattibilita':
#   serve      delta >= R_OBIETTIVO * banda / RISPOSTA        (per leggersi)
#   si puo'    delta <= MASCHERA_K * grana_grossa             (per restare nascosto)
#   quindi     grana_grossa / banda >= R_OBIETTIVO / (RISPOSTA * MASCHERA_K)
# Con i valori misurati fa ~6.8: e' il numero da battere, e la colonna "rapporto" lo dice.
#
#   & $godot --path $proj res://tests/photo_banda_scan.tscn
# ============================================================

const R_OBIETTIVO := 1.8      # rapporto segnale/rumore che serve nella banda (tarato)
const RISPOSTA := 0.33        # risposta misurata del filtro ai tratti
const MASCHERA_K := 0.8       # quanto scarto una data grana grossa riesce a mascherare

func _ready() -> void:
	get_tree().create_timer(1200.0).timeout.connect(func(): print("TIMEOUT"); get_tree().quit(1))
	await get_tree().process_frame
	var serve: float = R_OBIETTIVO / (RISPOSTA * MASCHERA_K)
	print("serve grana_grossa/banda >= %.1f perche' una zona sia insieme nascosta e rivelabile\n" % serve)
	print("%-22s %9s %9s %9s %9s %s" % ["foto", "banda", "grossa", "rapporto", "delta", "esito"])
	for path in OSContent._photo_files():
		_scansiona(path, serve)
		await get_tree().process_frame
	get_tree().quit(0)

func _scansiona(path: String, serve: float) -> void:
	var img := OSContent._scan_image({"path": path})
	if img == null:
		print("  %-20s illeggibile" % path.get_file())
		return
	var w := img.get_width()
	var h := img.get_height()
	var tb := OSContent._text_box_px(img.get_size())
	var bw: int = mini(w, tb.x)
	var bh: int = mini(h, tb.y)

	# griglia di riquadri della misura del testo; per ognuno le DUE misure
	var best := Rect2i(0, 0, bw, bh)
	var best_rap := -1.0
	var best_banda := 0.0
	var best_grossa := 0.0
	var passo_x: int = maxi(6, bw / 3)
	var passo_y: int = maxi(6, bh / 3)
	var y := 0
	while y + bh <= h:
		var x := 0
		while x + bw <= w:
			var box := Rect2i(x, y, bw, bh)
			var banda := OSContent.banda_box(img, box, 3)
			var grossa := _grana_grossa(img, box)
			var rap: float = (grossa / banda) if banda > 0.00002 else 999.0
			if rap > best_rap:
				best_rap = rap
				best = box
				best_banda = banda
				best_grossa = grossa
			x += passo_x
		y += passo_y

	# rimisura fitta del vincitore
	best_banda = OSContent.banda_box(img, best)
	best_grossa = _grana_grossa(img, best)
	best_rap = (best_grossa / best_banda) if best_banda > 0.00002 else 999.0
	var delta: float = R_OBIETTIVO * best_banda / RISPOSTA
	print("%-22s %9.4f %9.4f %9.2f %9.4f %s  (%d%%,%d%%)" % [
			path.get_file(), best_banda, best_grossa, best_rap, delta,
			("OK" if best_rap >= serve else "NON BASTA"),
			int(100.0 * float(best.position.x + bw / 2) / float(w)),
			int(100.0 * float(best.position.y + bh / 2) / float(h))])

# "Grana grossa": deviazione della luminanza dentro finestre di ~12 px, cioe' la struttura
# che l'occhio usa per non accorgersi di una scritta, TOLTA la pendenza larga (una sfumatura
# liscia non maschera niente) e SENZA contare i tratti fini (quelli sono il nemico del
# cursore, non un aiuto). Si prende il quantile BASSO fra le finestre: deve mascherare
# dappertutto sotto la scritta, non in media.
func _grana_grossa(img: Image, box: Rect2i) -> float:
	var fin := 12
	var valori: Array = []
	var y := box.position.y
	while y + fin <= box.end.y:
		var x := box.position.x
		while x + fin <= box.end.x:
			var somma := 0.0
			var somma2 := 0.0
			var n := 0
			for j in range(0, fin, 2):
				for i in range(0, fin, 2):
					var c := img.get_pixel(x + i, y + j)
					var l: float = (c.r + c.g + c.b) / 3.0
					somma += l
					somma2 += l * l
					n += 1
			var media := somma / float(maxi(1, n))
			valori.append(sqrt(maxf(0.0, somma2 / float(maxi(1, n)) - media * media)))
			x += fin
		y += fin
	if valori.is_empty():
		return 0.0
	valori.sort()
	return float(valori[clampi(int(float(valori.size()) * 0.25), 0, valori.size() - 1)])
