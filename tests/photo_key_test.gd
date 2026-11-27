extends Node

# Test della CHIAVE NELLA FOTO, via "pixel" (chiave 4): UN cursore spinto in una DIREZIONE
# fa emergere la scritta, e come ripiego anche alterare molto la foto con qualunque cursore
# (27/11/2026, scelta del proprietario). Qui si pretende, su molti semi:
#   A. la ricetta e' un cursore con un verso ammesso (ImageViewerApp.VERSI);
#   B. A RIPOSO la scritta e' a zero;
#   C. il cursore giusto in fondo nel verso giusto la rende piena; nel verso SBAGLIATO no;
#   D. emerge GRADUALMENTE: cresce senza mai calare spingendo il cursore giusto;
#   E. nessun cursore SBAGLIATO, da solo e anche in fondo, la fa emergere;
#   F. ripiego: tre cursori spinti forte la fanno emergere comunque;
#   G. a cursore spinto la scritta stacca dal fondo abbastanza da leggersi (stima puntuale:
#      il controllo a schermo vero e' photo_chain_test);
#   H. la portatrice, i cursori e i versi cambiano fra i semi.
#
#   & $godot --headless --path $proj res://tests/photo_key_test.tscn
# ============================================================

const SEMI := 120

var _fails: Array = []
var _portatrici := {}
var _ricette := {}
var _pixel := 0

func _ready() -> void:
	get_tree().create_timer(300.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	for i in range(SEMI):
		_prova(5000 + i * 7)
	print("   via pixel in %d semi su %d" % [_pixel, SEMI])
	print("   portatrici: ", _portatrici)
	print("   ricette: ", _ricette)
	_check("ABBASTANZA_PIXEL", _pixel >= SEMI / 4, "solo %d run nella via pixel" % _pixel)
	var tutti := 0
	for p in ImageViewerApp.VERSI:
		tutti += (ImageViewerApp.VERSI[p] as Array).size()
	_check("H_RICETTE_VARIE", _ricette.size() >= tutti - 1, "escono solo %s" % str(_ricette.keys()))
	var tetto: int = maxi(4, int(3.0 * float(_pixel) / float(maxi(1, OSContent._photo_files().size()))))
	var peggiore := 0
	for k in _portatrici:
		peggiore = maxi(peggiore, int(_portatrici[k]))
	_check("H_PORTATRICE_GIRA", peggiore <= tetto, "una foto porta la chiave %d volte (tetto %d)" % [peggiore, tetto])
	if _fails.is_empty():
		print("RISULTATO: PASS (un cursore in una direzione rivela la chiave, a riposo non c'e')")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

func _prova(seme: int) -> void:
	GameManager.start_new_run(seme)
	var foto := {}
	for c in _trova(VFS.get_root(), OSContent._t("VFS_PICTURES")).get("children", []):
		if c is Dictionary and str(c.get("code", "")) != "":
			foto = c
	if foto.is_empty():
		return   # via "nel file": la controlla photo_file_key_test
	_pixel += 1
	var chi := str(foto.get("path", "proc")).get_file()
	_portatrici[chi] = int(_portatrici.get(chi, 0)) + 1
	var ric: Array = foto.get("ricetta", [])
	var tag := "seme %d (%s)" % [seme, chi]
	if ric.size() != 1:
		_si("A_UN_CURSORE", false, "%s: ricetta %s" % [tag, str(ric)])
		return
	var p := str(ric[0]["param"])
	var verso := int(ric[0]["verso"])
	_ricette[OSContent.ricetta_testo(ric)] = true
	_si("A_VERSO_AMMESSO", ImageViewerApp.VERSI.has(p) and verso in ImageViewerApp.VERSI[p],
			"%s: %s verso %d" % [tag, p, verso])

	var riposo := ImageViewerApp.DEFAULTS.duplicate()
	_si("B_A_RIPOSO_ZERO", ImageViewerApp.rivelazione(ric, riposo) < 0.001,
			"%s: a riposo %.3f" % [tag, ImageViewerApp.rivelazione(ric, riposo)])

	var in_fondo := riposo.duplicate()
	in_fondo[p] = ImageViewerApp.valore_a(p, 1.0 if verso > 0 else 0.0)
	_si("C_IN_FONDO_PIENA", ImageViewerApp.rivelazione(ric, in_fondo) > 0.95,
			"%s: in fondo %.3f" % [tag, ImageViewerApp.rivelazione(ric, in_fondo)])
	var al_contrario := riposo.duplicate()
	var d := ImageViewerApp.posizione(p, float(ImageViewerApp.DEFAULTS[p]))
	if (verso > 0 and d > 0.001) or (verso < 0 and d < 0.999):
		al_contrario[p] = ImageViewerApp.valore_a(p, 0.0 if verso > 0 else 1.0)
		_si("C_VERSO_SBAGLIATO_NIENTE", ImageViewerApp.rivelazione(ric, al_contrario) < 0.05,
				"%s: nel verso sbagliato %.3f" % [tag, ImageViewerApp.rivelazione(ric, al_contrario)])

	# D: graduale e monotona lungo la corsa del lato giusto
	var prima := -1.0
	var intermedi := 0
	for k in range(11):
		var t := float(k) / 10.0
		var v := riposo.duplicate()
		v[p] = ImageViewerApp.valore_a(p, d + float(verso) * t * ((1.0 - d) if verso > 0 else d))
		var r := ImageViewerApp.rivelazione(ric, v)
		_si("D_MONOTONA", r >= prima - 0.0001, "%s: cala a %d%% della corsa (%.3f < %.3f)" % [tag, k * 10, r, prima])
		if r > 0.05 and r < 0.95:
			intermedi += 1
		prima = r
	_si("D_GRADUALE", intermedi >= 2, "%s: solo %d passi intermedi su 10" % [tag, intermedi])

	# E: ogni cursore sbagliato, da solo, in fondo a entrambi i lati
	for q in ImageViewerApp.DEFAULTS:
		if q == p:
			continue
		for fine in [0.0, 1.0]:
			var v := riposo.duplicate()
			v[q] = ImageViewerApp.valore_a(q, fine)
			var r := ImageViewerApp.rivelazione(ric, v)
			_si("E_SBAGLIATO_DA_SOLO_NIENTE", r < 0.05, "%s: %s a %.0f%% da' %.3f" % [tag, q, fine * 100.0, r])

	# F: ripiego, tre cursori sbagliati spinti forte
	var forte := riposo.duplicate()
	var spinti := 0
	for q in ["contrast", "black_point", "saturation", "detail", "brightness"]:
		if q == p or spinti == 3:
			continue
		forte[q] = ImageViewerApp.valore_a(q, 1.0)
		spinti += 1
	_si("F_RIPIEGO", ImageViewerApp.rivelazione(ric, forte) > 0.95,
			"%s: tre cursori in fondo danno solo %.3f" % [tag, ImageViewerApp.rivelazione(ric, forte)])

	# G: lo stacco a cursore spinto
	var piena := ImageViewerApp.valori_ricetta(ric)
	var base: Color = foto.get("code_base", Color(0.5, 0.5, 0.5))
	var l: float = (base.r + base.g + base.b) / 3.0
	var codice: float = clampf(l + ImageViewerApp.verso_migliore(l, ric) * ImageViewerApp.CODE_FORZA, 0.0, 1.0)
	var stacco: float = absf(ImageViewerApp.luma_regolata(codice, piena) - ImageViewerApp.luma_regolata(l, piena))
	_si("G_STACCA", stacco >= OSContent.CODE_STACCO_MIN, "%s: %s stacco %.3f (fondo %.2f)" % [tag, OSContent.ricetta_testo(ric), stacco, l])

# Una riga per caso fallito; il nome finisce nel riepilogo una volta sola.
func _si(nome: String, ok: bool, perche: String) -> void:
	if not ok:
		print("FAIL  " + nome + " --- " + perche)
		if not nome in _fails:
			_fails.append(nome)

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		_si(nome, false, perche)

func _trova(nodo: Dictionary, nome: String) -> Dictionary:
	if str(nodo.get("name", "")) == nome:
		return nodo
	for c in nodo.get("children", []):
		if c is Dictionary:
			var r := _trova(c, nome)
			if not r.is_empty():
				return r
	return {}
