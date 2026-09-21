extends Node

# Test della STRUTTURA del filesystem finto: deve essere quella di un disco di fine anni
# '90, non una cartella qualunque (richiesta del proprietario, 20/09/2026).
#
# Quello che si pretende, e il perche':
#   1 "Risorse del computer" elenca le UNITA' -- floppy A:, disco C:, CD-ROM D:, Cestino.
#     Con il solo C: dentro, quella finestra non somiglia a niente dell'epoca;
#   2 i file d'avvio (AUTOEXEC.BAT, CONFIG.SYS, COMMAND.COM) stanno nella RADICE di C:.
#     Prima erano dentro una cartella "Sistema", dove nessun PC li ha mai avuti: e' il
#     difetto che ha fatto nascere questo lavoro;
#   3 la cartella di sistema (C:\WHALE, al posto di C:\WINDOWS) contiene SYSTEM, FONTS,
#     TEMP, il Desktop, il Menu Avvio e i Preferiti, dove Windows 95 li teneva;
#   4 VFS.get_desktop() trova il Desktop LI' e ci trova dentro la cartella protetta: e'
#     la cartella da cui il desktop disegna le sue icone, quindi se il percorso non
#     seguisse l'albero la scrivania resterebbe vuota;
#   5 le foto del run stanno in Documenti\Immagini;
#   6 i nomi di SISTEMA sono identici in ogni lingua (WHALE, SYSTEM, AUTOEXEC.BAT...)
#     mentre le cartelle dell'utente sono tradotte -- era cosi' anche nelle versioni
#     italiane, ed e' meta' dell'aria d'epoca;
#   7 nessuna chiave di traduzione arriva a schermo come nome o contenuto;
#   8 le chiavi 1 e 2 restano piazzate e trovabili nell'albero nuovo, e il pannello F12
#     ne dice il percorso in stile DOS;
#   9 un file binario si apre e mostra byte illeggibili, non una pagina vuota.
#
# Va eseguito come SCENA (serve l'autoload GameManager). Headless va bene.
#   & $godot --headless --path $proj res://tests/filesystem_test.tscn
# ============================================================

const SEMI := 12

var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(
			func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.set_lingua(GameManager.LINGUA_BASE, false)
	GameManager.start_new_run(4242)

	var radice := VFS.get_root()
	_stampa(radice, 0, 2)
	_prova_unita(radice)
	_prova_radice_c(radice)
	_prova_cartella_sistema(radice)
	_prova_desktop()
	_prova_documenti(radice)
	_prova_binari(radice)
	_prova_niente_chiavi(radice)
	_prova_chiavi_piazzate()
	_prova_due_lingue()

	GameManager.set_lingua(GameManager.LINGUA_BASE, false)
	if _fails.is_empty():
		print("RISULTATO: PASS (l'albero e' quello di un disco del '98)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# ---------------- 1: le unita' ----------------

func _prova_unita(radice: Dictionary) -> void:
	var attese := [
		[OSContent._t("VFS_A_DRIVE"), "floppy"],
		[OSContent._t("VFS_C_DRIVE"), "hdd"],
		[OSContent._t("VFS_D_DRIVE"), "cdrom"],
		[OSContent._t("VFS_TRASH"), "trash"],
	]
	var mancanti: Array = []
	for a in attese:
		var n := _figlio(radice, str(a[0]))
		if n.is_empty():
			mancanti.append(str(a[0]))
		elif str(n.get("icon", "")) != str(a[1]):
			_ko("ICONA_UNITA", "%s ha l'icona '%s' invece di '%s'"
					% [str(a[0]), str(n.get("icon", "")), str(a[1])])
	_check("UNITA", mancanti.is_empty(), "in Risorse del computer manca: %s" % ", ".join(mancanti))

# ---------------- 2: la radice di C: ----------------

func _prova_radice_c(radice: Dictionary) -> void:
	var c := _c(radice)
	var mancanti: Array = []
	for f in ["AUTOEXEC.BAT", "CONFIG.SYS", "COMMAND.COM", "IO.SYS", "BOOTLOG.TXT"]:
		if _figlio(c, str(f)).is_empty():
			mancanti.append(str(f))
	_check("FILE_AVVIO_NELLA_RADICE", mancanti.is_empty(),
			"nella radice di C: manca: %s" % ", ".join(mancanti))
	# e non devono essere rimasti anche altrove
	var sistema := _figlio(c, OSContent.DIR_SISTEMA)
	_check("AVVIO_NON_DUPLICATO", _figlio(sistema, "AUTOEXEC.BAT").is_empty(),
			"AUTOEXEC.BAT sta anche dentro la cartella di sistema")
	var attese := [OSContent.DIR_SISTEMA, OSContent._t("VFS_PROGRAMS"),
			OSContent._t("VFS_DOCUMENTS"), OSContent.DIR_TEMP]
	mancanti = []
	for f in attese:
		if _figlio(c, str(f)).is_empty():
			mancanti.append(str(f))
	_check("CARTELLE_DI_C", mancanti.is_empty(), "nella radice di C: manca: %s" % ", ".join(mancanti))

# ---------------- 3: C:\WHALE ----------------

func _prova_cartella_sistema(radice: Dictionary) -> void:
	var sistema := _figlio(_c(radice), OSContent.DIR_SISTEMA)
	_check("CARTELLA_SISTEMA", not sistema.is_empty(),
			"non c'e' C:\\%s" % OSContent.DIR_SISTEMA)
	if sistema.is_empty():
		return
	var mancanti: Array = []
	for f in [OSContent.DIR_SYSTEM, OSContent.DIR_FONTS, OSContent.DIR_TEMP,
			OSContent._t("VFS_DESKTOP"), OSContent._t("VFS_START_MENU"),
			OSContent._t("VFS_FAVORITES")]:
		if _figlio(sistema, str(f)).is_empty():
			mancanti.append(str(f))
	_check("DENTRO_LA_SISTEMA", mancanti.is_empty(),
			"in C:\\%s manca: %s" % [OSContent.DIR_SISTEMA, ", ".join(mancanti)])
	var menu := _figlio(sistema, OSContent._t("VFS_START_MENU"))
	_check("MENU_AVVIO_PROGRAMMI", not _figlio(menu, OSContent._t("VFS_PROGRAMS_MENU")).is_empty(),
			"il Menu Avvio non contiene la cartella dei programmi")

# ---------------- 4: il Desktop ----------------

func _prova_desktop() -> void:
	var d := VFS.get_desktop()
	var percorso: Array = VFS.path_of(d)
	_check("DESKTOP_TROVATO", str(d.get("name", "")) == OSContent._t("VFS_DESKTOP"),
			"VFS.get_desktop() torna '%s' (percorso %s)" % [str(d.get("name", "")), str(percorso)])
	_check("DESKTOP_NELLA_SISTEMA", percorso.has(OSContent.DIR_SISTEMA),
			"il Desktop non sta dentro C:\\%s: %s" % [OSContent.DIR_SISTEMA, str(percorso)])
	var protetta := false
	for f in d.get("children", []):
		if f is Dictionary and str(f.get("type", "")) == "secret":
			protetta = true
	_check("CARTELLA_PROTETTA", protetta, "sul Desktop non c'e' la cartella protetta")

# ---------------- 5: documenti e foto ----------------

func _prova_documenti(radice: Dictionary) -> void:
	var doc := _figlio(_c(radice), OSContent._t("VFS_DOCUMENTS"))
	var img := _figlio(doc, OSContent._t("VFS_PICTURES"))
	_check("IMMAGINI_DENTRO_DOCUMENTI", not img.is_empty(),
			"le Immagini non sono dentro i Documenti")
	var foto := 0
	for f in img.get("children", []):
		if f is Dictionary and str(f.get("filetype", "")) == "image":
			foto += 1
	_check("FOTO_DEL_RUN", foto >= 3, "in Immagini ci sono %d foto" % foto)
	var prog := _figlio(_c(radice), OSContent._t("VFS_PROGRAMS"))
	_check("PROGRAMMI", not _figlio(prog, OSContent.APP_WEB).is_empty()
			and not _figlio(prog, OSContent.APP_FOTO).is_empty(),
			"in %s mancano le cartelle dei programmi" % OSContent._t("VFS_PROGRAMS"))

# ---------------- 9: i binari ----------------

func _prova_binari(radice: Dictionary) -> void:
	var sys := _figlio(_figlio(_c(radice), OSContent.DIR_SISTEMA), OSContent.DIR_SYSTEM)
	var uno := _figlio(sys, "KRNL386.EXE")
	_check("BINARIO_C_E", not uno.is_empty(), "manca KRNL386.EXE in %s" % OSContent.DIR_SYSTEM)
	if uno.is_empty():
		return
	var testo := str(uno.get("content", ""))
	_check("BINARIO_ILLEGGIBILE", str(uno.get("filetype", "")) == "bin" and testo.length() > 200
			and testo.find("This program cannot be run in DOS mode.") >= 0,
			"il binario non ha la forma di un eseguibile (%d caratteri)" % testo.length())
	_check("BINARIO_STABILE", str(OSContent._binario("KRNL386.EXE").get("content", "")) == testo,
			"riaprire lo stesso file da' byte diversi")

# ---------------- 7: niente chiavi di traduzione a schermo ----------------

func _prova_niente_chiavi(radice: Dictionary) -> void:
	var sporchi: Array = []
	_cerca_chiavi(radice, sporchi)
	_check("NIENTE_CHIAVI_IN_CHIARO", sporchi.is_empty(),
			"si leggono chiavi di traduzione: %s" % ", ".join(sporchi))

func _cerca_chiavi(nodo: Dictionary, fuori: Array) -> void:
	var nome := str(nodo.get("name", ""))
	for pre in ["VFS_", "FN_", "FT_", "FD_", "FC_"]:
		if nome.begins_with(str(pre)) or str(nodo.get("content", "")).begins_with(str(pre)):
			if not fuori.has(nome):
				fuori.append(nome)
	for c in nodo.get("children", []):
		if c is Dictionary:
			_cerca_chiavi(c, fuori)

# ---------------- 8: le chiavi del run ----------------

func _prova_chiavi_piazzate() -> void:
	var guasti: Array = []
	for seme in range(1, SEMI + 1):
		GameManager.start_new_run(seme)
		var radice := VFS.get_root()
		for indice in [OSContent.KEY_FILE, OSContent.KEY_FOLDER]:
			var etichetta: String = GameManager.key_label(indice)
			if etichetta == "":
				continue
			if not _contiene(radice, etichetta):
				guasti.append("seme %d: %s non e' nell'albero" % [seme, etichetta])
			var nota := str(GameManager.key_hints.get(indice, ""))
			if nota.find("C:\\") < 0:
				guasti.append("seme %d: il pannello F12 non dice il percorso ('%s')" % [seme, nota])
	_check("CHIAVI_PIAZZATE", guasti.is_empty(), ", ".join(guasti))

# Il codice compare nel nome di un nodo o nel contenuto di un file.
func _contiene(nodo: Dictionary, etichetta: String) -> bool:
	if str(nodo.get("name", "")).find(etichetta) >= 0:
		return true
	if str(nodo.get("content", "")).find(etichetta) >= 0:
		return true
	for c in nodo.get("children", []):
		if c is Dictionary and _contiene(c, etichetta):
			return true
	return false

# ---------------- 6: sistema uguale, utente tradotto ----------------

func _prova_due_lingue() -> void:
	var nomi := {}
	var conti := {}
	for lingua in GameManager.LINGUE:
		GameManager.set_lingua(str(lingua), false)
		GameManager.start_new_run(4242)
		var c := _c(VFS.get_root())
		nomi[str(lingua)] = {
			"documenti": str(_figlio(c, OSContent._t("VFS_DOCUMENTS")).get("name", "")),
			"sistema": str(_figlio(c, OSContent.DIR_SISTEMA).get("name", "")),
			"avvio": str(_figlio(c, "AUTOEXEC.BAT").get("name", "")),
		}
		conti[str(lingua)] = _conta(VFS.get_root())
	var a := str(GameManager.LINGUE[0])
	var b := str(GameManager.LINGUE[1])
	_check("SISTEMA_NON_TRADOTTO",
			nomi[a]["sistema"] == nomi[b]["sistema"] and nomi[a]["avvio"] == nomi[b]["avvio"]
			and nomi[a]["sistema"] != "",
			"i nomi di sistema cambiano con la lingua: %s / %s" % [str(nomi[a]), str(nomi[b])])
	_check("UTENTE_TRADOTTO", nomi[a]["documenti"] != nomi[b]["documenti"],
			"la cartella dei documenti si chiama '%s' in tutte e due le lingue" % nomi[a]["documenti"])
	_check("STESSA_FORMA", conti[a] == conti[b],
			"l'albero ha %d nodi in %s e %d in %s: a una lingua manca qualcosa"
			% [conti[a], a, conti[b], b])
	print("   nodi nell'albero: %d (%s) / %d (%s)" % [conti[a], a, conti[b], b])

func _conta(nodo: Dictionary) -> int:
	var n := 1
	for c in nodo.get("children", []):
		if c is Dictionary:
			n += _conta(c)
	return n

# ---------------- utilita' ----------------

func _c(radice: Dictionary) -> Dictionary:
	return _figlio(radice, OSContent._t("VFS_C_DRIVE"))

func _figlio(nodo: Dictionary, nome: String) -> Dictionary:
	for c in nodo.get("children", []):
		if c is Dictionary and str(c.get("name", "")) == nome:
			return c
	return {}

# Stampa l'albero (solo i primi livelli): serve a guardarlo, non e' un controllo.
func _stampa(nodo: Dictionary, livello: int, max_livello: int) -> void:
	var segno := "+" if str(nodo.get("type", "")) == "folder" else "-"
	print("   %s%s %s" % ["  ".repeat(livello), segno, str(nodo.get("name", "?"))])
	if livello >= max_livello:
		return
	for c in nodo.get("children", []):
		if c is Dictionary:
			_stampa(c, livello + 1, max_livello)

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		if not _fails.has(nome):
			_fails.append(nome)

func _ko(nome: String, perche: String) -> void:
	print("FAIL  %s -- %s" % [nome, perche])
	if not _fails.has(nome):
		_fails.append(nome)
