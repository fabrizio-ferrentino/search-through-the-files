extends Node

# Test del DISCO CASUALE (18/10/2026): cartelle e file diversi a ogni partita, pescati dal
# catalogo (scripts/os/catalogo_disco.gd), con lo scheletro di Win95 sempre al suo posto.
#
# E' anche il controllo di chi AGGIUNGE un file al catalogo: se una traduzione manca, se un
# nome va in conflitto con un altro, se una voce non compare mai (una zona scritta male),
# se un testo contiene qualcosa che sembra una chiave -- lo dice questo test.
# Si pretende che:
#   1 ogni voce del catalogo abbia nome e testo tradotti in TUTTE le lingue, che i nomi
#     siano diversi fra loro in ogni lingua (anche solo per maiuscole: su un disco Windows
#     sono lo stesso file) e che le zone siano quelle che esistono;
#   2 nessun testo contenga qualcosa con la forma di una chiave (cifra-trattino-4): la
#     caccia resta leale solo se le chiavi vere sono le uniche fatte cosi';
#   3 su SEMI partite e in ogni lingua: lo scheletro c'e' sempre, Immagini sta SEMPRE in
#     Documenti\Immagini con le sue foto e niente del catalogo dentro, gli horror sono
#     QUANTI_HORROR, le quantita' restano nei limiti, nessuna cartella ha due nomi uguali,
#     nessun {PROG} resta nel testo, nessun carattere vietato nei nomi, e le chiavi 1 e 2
#     sono ancora sul disco;
#   4 stesso seme = stesso disco (riproducibile), semi diversi = dischi diversi (varia
#     davvero), e le due lingue danno la stessa FORMA con le stesse voci;
#   5 ogni voce del catalogo -- file, cartelle, programmi -- compaia almeno una volta sulle
#     SEMI partite: una voce che non esce mai e' un errore di chi l'ha scritta.
#
# Headless:
#   & $godot --headless --path $proj res://tests/disco_casuale_test.tscn
# ============================================================

const SEMI := 30
const VIETATI := "\\/:*?\"<>|"

var _fails: Array = []
var _chiave_re := RegEx.new()

func _ready() -> void:
	get_tree().create_timer(300.0).timeout.connect(func(): _timeout())
	await get_tree().process_frame
	_chiave_re.compile("\\b\\d-[A-Z0-9]{4}\\b")
	var lingua_prima: String = GameManager.lingua

	_prova_catalogo()
	_prova_partite()

	GameManager.set_lingua(lingua_prima, false)
	if _fails.is_empty():
		print("RISULTATO: PASS (il disco cambia a ogni partita, e lo scheletro resta quello di Win95)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

func _timeout() -> void:
	print("RISULTATO: FAIL -> timeout")
	get_tree().quit(1)

# ---------- 1 e 2: il catalogo ----------

func _voci_file() -> Array:
	var tutte: Array = []
	tutte.append_array(CatalogoDisco.FILE_EPOCA)
	tutte.append_array(CatalogoDisco.FILE_HORROR)
	tutte.append_array(CatalogoDisco.FILE_DEI_PROGRAMMI)
	return tutte

func _prova_catalogo() -> void:
	var mancanti := PackedStringArray()
	var doppi := PackedStringArray()
	var finte := PackedStringArray()
	var zone_sbagliate := PackedStringArray()
	for lingua in GameManager.LINGUE:
		GameManager.set_lingua(str(lingua), false)
		var nomi := {}
		for voce in _voci_file():
			for k in [voce[0], voce[1]]:
				if tr(str(k)) == str(k) or tr(str(k)).strip_edges() == "":
					mancanti.append("%s/%s" % [lingua, k])
			var nome := tr(str(voce[0])).to_lower()
			if nomi.has(nome):
				doppi.append("%s: '%s' (%s e %s)" % [lingua, nome, nomi[nome], voce[0]])
			nomi[nome] = voce[0]
			var testo := OSContent._testo(str(voce[1]))
			if _chiave_re.search(testo) != null:
				finte.append("%s/%s" % [lingua, voce[1]])
		for k in CatalogoDisco.CARTELLE_DOCUMENTI:
			if tr(str(k)) == str(k):
				mancanti.append("%s/%s" % [lingua, k])
	for voce in CatalogoDisco.FILE_EPOCA + CatalogoDisco.FILE_HORROR:
		for z in voce[2]:
			if int(z) < CatalogoDisco.DOCUMENTI or int(z) > CatalogoDisco.EXTRA:
				zone_sbagliate.append("%s: zona %s" % [voce[0], str(z)])
	_check("CATALOGO_TRADOTTO", mancanti.is_empty(), "manca la traduzione: " + ", ".join(mancanti))
	_check("NOMI_UNICI", doppi.is_empty(), "nomi uguali: " + "; ".join(doppi))
	_check("NESSUNA_CHIAVE_FINTA", finte.is_empty(),
			"testi con qualcosa che sembra una chiave: " + ", ".join(finte))
	_check("ZONE_VALIDE", zone_sbagliate.is_empty(), ", ".join(zone_sbagliate))

# ---------- 3, 4 e 5: le partite ----------

func _prova_partite() -> void:
	var guasti := {}            # nome controllo -> elenco di problemi
	var firme := {}             # firma del disco -> quante partite
	var viste := {}             # voci e cartelle comparse almeno una volta
	var horror_keys := {}
	for v in CatalogoDisco.FILE_HORROR:
		horror_keys[v[0]] = true
	var t0 := Time.get_ticks_msec()

	for seme in range(1, SEMI + 1):
		var forma := {}
		for lingua in GameManager.LINGUE:
			GameManager.set_lingua(str(lingua), false)
			GameManager.start_new_run(seme)
			var radice := VFS.get_root()
			var c := _figlio(radice, OSContent._t("VFS_C_DRIVE"))
			var luogo := "seme %d/%s" % [seme, lingua]

			# lo scheletro
			for nome in [OSContent.DIR_SISTEMA, OSContent._t("VFS_PROGRAMS"),
					OSContent._t("VFS_DOCUMENTS"), OSContent.DIR_TEMP, "AUTOEXEC.BAT"]:
				if _figlio(c, str(nome)).is_empty():
					_guasto(guasti, "SCHELETRO", "%s: manca %s" % [luogo, nome])
			var prog := _figlio(c, OSContent._t("VFS_PROGRAMS"))
			for nome in [OSContent.APP_WEB, OSContent.APP_FOTO]:
				if _figlio(prog, nome).is_empty():
					_guasto(guasti, "SCHELETRO", "%s: manca il programma %s" % [luogo, nome])

			# Immagini: sempre li', con le foto, e niente del catalogo dentro
			var img := _figlio(_figlio(c, OSContent._t("VFS_DOCUMENTS")), OSContent._t("VFS_PICTURES"))
			var foto := 0
			for f in img.get("children", []):
				if str(f.get("filetype", "")) == "image":
					foto += 1
				if f.has("voce"):
					_guasto(guasti, "IMMAGINI_PULITA", "%s: in Immagini c'e' %s" % [luogo, f["name"]])
			if img.is_empty() or foto < 3:
				_guasto(guasti, "IMMAGINI_FISSA", "%s: Immagini manca o ha %d foto" % [luogo, foto])

			# conti e regole su tutto l'albero
			var conti := {"horror": 0, "voci": [], "sotto_doc": 0, "programmi": 0}
			_visita(radice, luogo, conti, guasti, horror_keys)
			var hmin: int = CatalogoDisco.QUANTI_HORROR[0]
			var hmax: int = CatalogoDisco.QUANTI_HORROR[1]
			if int(conti["horror"]) < hmin or int(conti["horror"]) > hmax:
				_guasto(guasti, "HORROR_QUANTI", "%s: %d horror" % [luogo, int(conti["horror"])])
			for v in conti["voci"]:
				viste[v] = true

			# le cartelle e i programmi del catalogo comparsi
			var doc := _figlio(c, OSContent._t("VFS_DOCUMENTS"))
			for k in CatalogoDisco.CARTELLE_DOCUMENTI:
				if not _figlio(doc, OSContent._t(str(k))).is_empty():
					viste[k] = true
			for voce in CatalogoDisco.PROGRAMMI:
				if not _figlio(prog, str(voce[0])).is_empty():
					viste[voce[0]] = true
			for voce in CatalogoDisco.CARTELLE_RADICE:
				if not _figlio(c, str(voce[0])).is_empty():
					viste[voce[0]] = true

			# le chiavi 1 e 2 sono ancora sul disco
			for indice in [OSContent.KEY_FILE, OSContent.KEY_FOLDER]:
				var etichetta := GameManager.key_label(indice)
				if etichetta != "" and not _contiene(radice, etichetta):
					_guasto(guasti, "CHIAVI_SUL_DISCO", "%s: %s non c'e'" % [luogo, etichetta])

			forma[str(lingua)] = [_forma(radice), str(conti["voci"])]
			if str(lingua) == str(GameManager.LINGUE[0]):
				var firma := _firma(radice)
				firme[firma] = int(firme.get(firma, 0)) + 1
				# stesso seme di nuovo: deve venire lo stesso disco
				GameManager.start_new_run(seme)
				if _firma(VFS.get_root()) != firma:
					_guasto(guasti, "RIPRODUCIBILE", "seme %d: due dischi diversi" % seme)

		var a := str(GameManager.LINGUE[0])
		var b := str(GameManager.LINGUE[1])
		if forma[a][0] != forma[b][0] or forma[a][1] != forma[b][1]:
			_guasto(guasti, "STESSA_FORMA", "seme %d: %s e %s danno dischi diversi" % [seme, a, b])

	print("   %d partite x %d lingue in %d ms; dischi diversi: %d su %d"
			% [SEMI, GameManager.LINGUE.size(), Time.get_ticks_msec() - t0, firme.size(), SEMI])
	for nome in ["SCHELETRO", "IMMAGINI_FISSA", "IMMAGINI_PULITA", "HORROR_QUANTI",
			"NIENTE_DOPPIONI", "NIENTE_SEGNAPOSTO", "NIENTE_VIETATI", "CHIAVI_SUL_DISCO",
			"RIPRODUCIBILE", "STESSA_FORMA"]:
		var lista: Array = guasti.get(nome, [])
		_check(nome, lista.is_empty(), "; ".join(PackedStringArray(lista.slice(0, 5))))
	_check("VARIA_DAVVERO", firme.size() >= SEMI - 2,
			"solo %d dischi diversi su %d partite" % [firme.size(), SEMI])

	var mai := PackedStringArray()
	for voce in _voci_file():
		if not viste.has(voce[0]):
			mai.append(str(voce[0]))
	for k in CatalogoDisco.CARTELLE_DOCUMENTI:
		if not viste.has(k):
			mai.append(str(k))
	for voce in CatalogoDisco.PROGRAMMI + CatalogoDisco.CARTELLE_RADICE:
		if not viste.has(voce[0]):
			mai.append(str(voce[0]))
	_check("OGNI_VOCE_COMPARE", mai.is_empty(),
			"in %d partite non e' mai uscito: %s (zona sbagliata?)" % [SEMI, ", ".join(mai)])

# Giro di tutto l'albero: doppioni per cartella, segnaposto rimasti, caratteri vietati,
# horror e voci del catalogo.
func _visita(nodo: Dictionary, luogo: String, conti: Dictionary, guasti: Dictionary,
		horror_keys: Dictionary) -> void:
	var nomi := {}
	for f in nodo.get("children", []):
		if not f is Dictionary:
			continue
		var nome := str(f.get("name", ""))
		var basso := nome.to_lower()
		if nomi.has(basso):
			_guasto(guasti, "NIENTE_DOPPIONI", "%s: due '%s' in %s" % [luogo, nome, nodo.get("name", "C:")])
		nomi[basso] = true
		# le UNITA' (figlie della radice) hanno i due punti nel nome, "Disco locale (C:)", e
		# vanno bene: un'unita' non e' un file. La regola vale da dentro le unita' in giu'.
		if nodo.get("_parent", null) != null:
			for ch in VIETATI:
				if nome.contains(ch):
					_guasto(guasti, "NIENTE_VIETATI", "%s: '%s'" % [luogo, nome])
		if str(f.get("content", "")).contains("{PROG}"):
			_guasto(guasti, "NIENTE_SEGNAPOSTO", "%s: {PROG} in %s" % [luogo, nome])
		if f.has("voce"):
			(conti["voci"] as Array).append(str(f["voce"]))
			if horror_keys.has(f["voce"]):
				conti["horror"] = int(conti["horror"]) + 1
		_visita(f, luogo, conti, guasti, horror_keys)

# La FORMA: tipi e numero di figli, senza i nomi (che cambiano con la lingua).
func _forma(nodo: Dictionary) -> String:
	var s := str(nodo.get("type", "")) + "("
	for f in nodo.get("children", []):
		if f is Dictionary:
			s += _forma(f)
	return s + ")"

# La FIRMA: nomi e contenuti, per dire se due dischi sono lo stesso disco.
func _firma(nodo: Dictionary) -> String:
	var s := str(nodo.get("name", "")) + "#" + str(str(nodo.get("content", "")).hash()) + "["
	for f in nodo.get("children", []):
		if f is Dictionary:
			s += _firma(f)
	return s + "]"

func _figlio(nodo: Dictionary, nome: String) -> Dictionary:
	for f in nodo.get("children", []):
		if f is Dictionary and str(f.get("name", "")) == nome:
			return f
	return {}

func _contiene(nodo: Dictionary, etichetta: String) -> bool:
	if str(nodo.get("name", "")).contains(etichetta) or str(nodo.get("content", "")).contains(etichetta):
		return true
	for f in nodo.get("children", []):
		if f is Dictionary and _contiene(f, etichetta):
			return true
	return false

func _guasto(guasti: Dictionary, nome: String, cosa: String) -> void:
	if not guasti.has(nome):
		guasti[nome] = []
	(guasti[nome] as Array).append(cosa)

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		if not _fails.has(nome):
			_fails.append(nome)
