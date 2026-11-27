class_name OSContent
extends RefCounted

# ============================================================
# Libreria dei contenuti dell'OS — M3 (parti 1+2+3: data-driven + generatore + foto).
#
# Parte 1: i contenuti (albero del filesystem + pool di siti web) vivono qui come
# DATI, separati da chi li costruisce/mostra (vfs.gd, app_browser.gd, image viewer).
#
# Parte 2 (generatore seminato): dal seme del run (GameManager.run_seed) si decide in
# modo RIPRODUCIBILE quali siti del catalogo entrano nel run e DOVE finiscono le
# chiavi. Mappa indice->categoria FISSA (vedi KEY_*), decisa dal proprietario il
# 18/10/2026 (prima erano file / cartella / web / immagine, una per tecnica):
#   * chiave 1 DISCO    -> a caso, meta' delle volte un FILE portatore (nome + testo a
#                          caso, in una cartella a caso) e meta' una CARTELLA "di backup"
#                          col codice nel nome. Mai tutte e due.
#   * chiavi 2 e 3 WEB  -> due siti DIVERSI del run, ognuna a caso nel TESTO VISIBILE o
#                          nel SORGENTE HTML (vedi web_runtime.gd)
#   * chiave 4 IMMAGINE -> nascosta in una foto (parte 3, sotto)
# La chiave non sta MAI dentro un binario (.EXE, .SYS, .COM, .DLL...): il file portatore
# e' sempre un .txt nuovo, e i binari sono solo rumore illeggibile. E' una regola: aprire
# a tappeto i binari non deve mai servire.
#
# Parte 3 (foto + puzzle di regolazione): la cartella "Immagini" contiene alcune foto.
# Una porta la chiave 4 come scritta a bassissimo contrasto, leggibile solo regolando
# l'immagine (luminosita'/contrasto/livelli) nel visualizzatore. Le foto d'autore vanno
# in PHOTO_DIR: se ci sono, il run le usa; altrimenti make_photo genera placeholder
# procedurali. In OGNI caso il codice del run NON e' nei pixel del file: lo sovrappone
# il visualizzatore a runtime (la chiave cambia ogni partita, un file fisso non potrebbe
# contenerla).
#
# Robustezza: ogni build usa un RandomNumberGenerator PROPRIO (run_seed + un salt),
# quindi e' riproducibile e indipendente dall'ordine/momento di chiamata (il browser
# genera le pagine in modo lazy). VFS e siti piazzano ognuno le proprie chiavi senza
# coordinarsi: e' solo la POSIZIONE dentro la categoria a variare.
# ============================================================

# Segnaposto generico di chiave nei testi portatori: sostituito con key_label(n).
const KEY_SLOT := "{{KEY}}"

# Mappa indice->categoria (fissa): dove finisce ogni chiave del run.
const KEY_DISCO := 1                 # file O cartella, a caso (vedi build_filesystem)
const KEY_WEB_1 := 2
const KEY_WEB_2 := 3
const KEY_WEB := [KEY_WEB_1, KEY_WEB_2]
const KEY_IMAGE := 4

# Salt del generatore seminato del filesystem (i siti web vivono ora in WebRuntime).
const VFS_SALT := 1001

# Foto del run.
const PHOTO_W := 320
const PHOTO_H := 240
# --- La scritta-chiave nei pixel ---
# Dal 27/11/2026 non si nasconde piu' "debole dentro la trama" (misurato per mesi: su foto
# vere o si vedeva subito o non si leggeva mai, vedi docs/code/PHOTO_KEY.md). A riposo non
# c'e' proprio; la fa emergere UN cursore spinto in una direzione, sorteggiati qui e
# applicati da ImageViewerApp (dove stanno le soglie da regolare).
const CODE_SIZE_FACTOR := 0.062         # altezza del testo, in frazione della foto
const CODE_TILT := 12.0                 # rotazione massima della scritta, in gradi
# La foto si analizza alla misura in cui il giocatore la vede (il SubViewport del
# visualizzatore, max 640x480).
const CODE_SCAN := Vector2i(640, 480)
# Quante volte su 1 la chiave della foto va nei BYTE del file invece che nei pixel.
const CODE_QUOTA_FILE := 0.5
# Stacco minimo (luminanza 0..1, ~30 livelli) fra scritta e fondo a cursore spinto: sotto,
# quel cursore brucerebbe la zona nel bianco o nel nero e se ne sorteggia un altro.
const CODE_STACCO_MIN := 0.12
# Tinte di base delle foto (toni medi: lasciano spazio a schiarire/scurire).
const PHOTO_TINTS := ["5a5560", "625a52", "525e58", "5c5c4e", "565c66", "604f52"]
# Cartella delle foto d'autore (PNG/JPG): se contiene immagini il run le usa al posto
# dei placeholder procedurali. Il codice del run viene comunque sovrapposto a runtime
# dal visualizzatore (la chiave cambia ogni partita: un file fisso non puo' contenerla).
const PHOTO_DIR := "res://assets/textures/photos/"
# Foto nella cartella Immagini a ogni partita: fisse, scelta del proprietario (27/11/2026).
const PHOTO_COUNT := 5

# Testi portatori della chiave in un FILE di testo.
const _FILE_CARRIERS := ["FT_CARRIER_1", "FT_CARRIER_2", "FT_CARRIER_3", "FT_CARRIER_4"]
# Nomi possibili del file portatore (devono NON collidere coi file base del VFS).
# CHIAVI, non nomi: il nome vero lo da' _t() quando si genera il run.
const _FILE_NAMES := ["FN_CODE", "FN_LICENCE", "FN_ACTIVATION", "FN_REMINDER", "FN_SCRATCH"]
# Nomi di SISTEMA: non si traducono, e stanno in 8.3 maiuscolo. Non e' pigrizia -- anche
# nelle versioni italiane dell'epoca C:\WINDOWS\SYSTEM restava tale, e solo le cartelle
# dell'utente (Documenti, Programmi, Menu Avvio) erano tradotte. Quel contrasto fra nomi
# corti maiuscoli e nomi lunghi tradotti e' meta' dell'aria d'epoca.
const DIR_SISTEMA := "WHALE"        # la cartella del sistema operativo (il C:\WINDOWS locale)
const DIR_SYSTEM := "SYSTEM"
const DIR_FONTS := "FONTS"
const DIR_TEMP := "TEMP"
# Nomi di prodotto: marchi inventati, uguali in ogni lingua (come lo erano i veri).
const APP_WEB := "WebNet Explorer"
const APP_FOTO := "PhotoLab 2.0"
# Nomi possibili della cartella che porta il codice nel proprio nome.
const _FOLDER_NAMES := ["FD_BACKUP", "FD_ARCHIVE", "FD_COPY", "FD_OLD_FILES", "FD_SPARE"]

# Testo lungo tradotto. Nel CSV gli "a capo" si scrivono come \n (due caratteri: righe
# vere dentro una cella complicherebbero il file), e qui si riconvertono. Vale per i testi
# DI GIOCO; le stringhe d'interfaccia stanno su una riga e passano da _t() normale.
# Traduzione da una funzione STATICA. Non si puo' usare tr(): quello e' un metodo di
# Object, e tutto OSContent e' statico (lo chiamano VFS._build e i test senza istanziare
# niente). TranslationServer.translate fa la stessa cosa passando dal singleton.
static func _t(chiave: String) -> String:
	return TranslationServer.translate(chiave)

static func _testo(chiave: String) -> String:
	return _t(chiave).c_unescape()

# ---------------- filesystem (albero base del run) ----------------

# Albero del filesystem (radice "Risorse del computer"), in tre tempi:
#  1 lo SCHELETRO fisso (_disco_c): quello che ogni PC del '98 aveva e che il gioco cerca,
#    con le foto del run in Documenti\Immagini;
#  2 il RIEMPIMENTO a caso (_riempi_disco, dal catalogo in catalogo_disco.gd): cartelle in
#    piu', programmi inventati, file d'epoca e qualche file horror. Diverso a ogni partita
#    (18/10/2026, richiesta del proprietario);
#  3 la CHIAVE 1, in un file O nel nome di una cartella (a caso), anche fra le cartelle nuove.
# Il riempimento ha un RNG SUO: cosi' non sposta le estrazioni di foto e chiavi, e
# aggiungere una voce al catalogo non cambia quale foto porta il codice.
# Lo consuma VFS._build(), che aggiunge poi i back-reference _parent.
static func build_filesystem() -> Dictionary:
	var rng := _run_rng(VFS_SALT)
	var c_children: Array = _disco_c(rng)
	var nuove: Dictionary = _riempi_disco(c_children)
	# la chiave 1 sta in un file OPPURE nel nome di una cartella. L'estrazione viene
	# DOPO le foto (_disco_c): cosi' quale foto porta il codice non cambia per nessun seme
	if rng.randf() < 0.5:
		_place_folder_key(c_children, rng, nuove["sotto_documenti"])
	else:
		_place_file_key(c_children, rng, nuove["chiave_file"])
	# RISORSE DEL COMPUTER = le UNITA', non una cartella sola. Un "Risorse del computer"
	# con dentro il solo disco C: e' la cosa che tradisce il tema piu' in fretta: nel '98
	# la prima finestra che si apriva elencava floppy, disco, CD-ROM e Cestino. A: e D:
	# sono vuoti apposta (nessun dischetto dentro), ma ci sono.
	return _folder(_t("VFS_MY_COMPUTER"), "computer", [
		_folder(_t("VFS_A_DRIVE"), "floppy", []),
		_folder(_t("VFS_C_DRIVE"), "hdd", c_children),
		_folder(_t("VFS_D_DRIVE"), "cdrom", []),
		_folder(_t("VFS_TRASH"), "trash", []),
	])

# La radice di C:, come la trovavi accendendo un PC dell'epoca: i file d'avvio SULLA
# RADICE (prima stavano in una cartella "Sistema", dove nessun PC li ha mai avuti), la
# cartella del sistema operativo, i programmi, i documenti e la TEMP.
static func _disco_c(rng: RandomNumberGenerator) -> Array:
	return [
		_cartella_sistema(),
		_folder(_t("VFS_PROGRAMS"), "folder", [
			_folder(APP_WEB, "folder", [
				_binario("WEBNET.EXE"),
				_text(_t("FN_APP_README"), _testo("FT_APP_README")),
			]),
			_folder(APP_FOTO, "folder", [
				_binario("PHOTOLAB.EXE"),
				_binario("PLFILTER.DLL"),
			]),
		]),
		# i file di Documenti arrivano dal catalogo (diario, lettere, ricette... e qualcosa
		# di peggio): qui resta solo Immagini, SEMPRE allo stesso posto
		_folder(_t("VFS_DOCUMENTS"), "folder", [
			# le foto del run stanno qui dentro: una nasconde la chiave 4
			_folder(_t("VFS_PICTURES"), "folder", _make_image_folder(rng)),
		]),
		_folder(DIR_TEMP, "folder", [
			_binario("~MF0A12.TMP"),
		]),
		_text("AUTOEXEC.BAT", "@ECHO OFF\nPROMPT $P$G\nPATH C:\\" + DIR_SISTEMA
				+ ";C:\\" + DIR_SISTEMA + "\\" + DIR_SYSTEM + "\nSET TEMP=C:\\" + DIR_TEMP
				+ "\nLH C:\\" + DIR_SISTEMA + "\\MOUSE.COM"),
		_text("CONFIG.SYS", "DEVICE=C:\\" + DIR_SISTEMA + "\\HIMEM.SYS\nDOS=HIGH,UMB\n"
				+ "FILES=30\nBUFFERS=20\nSTACKS=9,256"),
		_text("BOOTLOG.TXT", "Loading Device = C:\\" + DIR_SISTEMA + "\\HIMEM.SYS\n"
				+ "LoadSuccess   = C:\\" + DIR_SISTEMA + "\\HIMEM.SYS\n"
				+ "Loading Device = C:\\" + DIR_SISTEMA + "\\VMM32.VXD\n"
				+ "LoadSuccess   = C:\\" + DIR_SISTEMA + "\\VMM32.VXD\n"
				+ "SysCritInit   = OK\nInitComplete  = OK"),
		_binario("COMMAND.COM"),
		_binario("IO.SYS"),
	]

# C:\WHALE -- la cartella del sistema, al posto di C:\WINDOWS. Dentro c'e' quello che
# Windows 95 ci teneva: SYSTEM, FONTS, TEMP, il Desktop, il Menu Avvio, i Preferiti e i
# file .INI. Il Desktop sta QUI, non nella radice di C:, perche' e' li' che stava davvero
# (ed e' la cartella che VFS.get_desktop() cerca per disegnare le icone sulla scrivania).
static func _cartella_sistema() -> Dictionary:
	return _folder(DIR_SISTEMA, "folder", [
		_folder(DIR_SYSTEM, "folder", [
			_binario("VMM32.VXD"), _binario("KRNL386.EXE"), _binario("GDI.EXE"),
			_binario("USER.EXE"), _binario("MOUSE.DRV"), _binario("SOUND.DRV"),
		]),
		_folder(DIR_FONTS, "folder", [
			_binario("SYSTEM.FON"), _binario("COURIER.FON"), _binario("ARIAL.TTF"),
		]),
		_folder(DIR_TEMP, "folder", [
			_binario("~DF3A12.TMP"),
			_text("INSTALL.LOG", "[Setup]\nStart = 09:14:22\nCopy = "
					+ DIR_SYSTEM + "\\VMM32.VXD ... OK\nEnd = 09:16:03"),
		]),
		# La cartella protetta vive sul Desktop: sembra una cartella qualunque ma e'
		# quella da sbloccare (type "secret").
		_folder(_t("VFS_DESKTOP"), "folder", [
			{"name": _t("VFS_SECRET"), "type": "secret", "icon": "locked"},
		]),
		_folder(_t("VFS_START_MENU"), "folder", [
			_folder(_t("VFS_PROGRAMS_MENU"), "folder", [
				_html(APP_WEB, "start"),
			]),
		]),
		_folder(_t("VFS_FAVORITES"), "folder", [
			_html(_t("FN_HOMEPAGE"), "start"),
		]),
		_text(DIR_SISTEMA + ".INI", "[windows]\nload=\nrun=\n\n[Desktop]\n"
				+ "Wallpaper=(None)\nTileWallpaper=0"),
		_text("SYSTEM.INI", "[boot]\nshell=WHALEEXP.EXE\nmouse.drv=MOUSE.DRV\n\n"
				+ "[386Enh]\nEMMExclude=C000-CFFF"),
	])

# Dove puo' finire il file che porta la chiave 1: PERCORSI (dalla radice di C:), non nomi.
# Prima si cercava fra i soli figli di C:, e con un albero profondo non basta piu'. Sono
# tutti posti in cui un .txt non stona -- fra i documenti, fra le foto, in una TEMP o
# nella cartella di un programma: il giocatore deve poterci arrivare ragionando.
static func _cartelle_chiave() -> Array:
	return [
		[_t("VFS_DOCUMENTS")],
		[_t("VFS_DOCUMENTS"), _t("VFS_PICTURES")],
		[DIR_SISTEMA, DIR_TEMP],
		[DIR_TEMP],
		[_t("VFS_PROGRAMS"), APP_FOTO],
		[DIR_SISTEMA],
	]

# Chiave 1, come FILE: portatore (nome + contenuto a caso) in una cartella a caso -- fra quelle
# fisse di _cartelle_chiave() e quelle nate in questa partita (sottocartelle di Documenti,
# programmi inventati, cartelle in piu' di C:).
static func _place_file_key(c_children: Array, rng: RandomNumberGenerator, nuove: Array = []) -> void:
	var label := GameManager.key_label(KEY_DISCO)
	if label == "":
		return
	var percorso: Array = _pick(_cartelle_chiave() + nuove, rng)
	var folder := _find_path(c_children, percorso)
	if folder.is_empty():
		percorso = [_t("VFS_DOCUMENTS")]          # ripiego: i Documenti ci sono sempre
		folder = _find_path(c_children, percorso)
		if folder.is_empty():
			return
	# il nome non deve coincidere con un file gia' li' (in italiano "licenza.txt" e il
	# LICENZA.TXT di un programma sono lo stesso nome, su un disco Windows)
	var name: String = _nome_libero(folder["children"], _t(_pick(_FILE_NAMES, rng)))
	var content: String = _testo(_pick(_FILE_CARRIERS, rng))
	folder["children"].append(_text(name, content.replace(KEY_SLOT, label)))
	GameManager.note_key(KEY_DISCO, "%s (in %s)" % [name, _percorso_dos(percorso)], "FILE")

# Chiave 1, come CARTELLA: "di backup" (nome a caso) col codice scritto nel proprio nome. Va
# nella radice di C: o dentro Documenti: sono i due posti dove uno la metterebbe davvero.
static func _place_folder_key(c_children: Array, rng: RandomNumberGenerator, sotto_doc: Array = []) -> void:
	var label := GameManager.key_label(KEY_DISCO)
	if label == "":
		return
	var base: String = _t(_pick(_FOLDER_NAMES, rng))
	var folder := _folder("%s %s" % [base, label], "folder", [
		_text(_t("FN_NOTE"), _testo("FT_NOTE")),
	])
	var percorso: Array = []
	var dentro: Array = c_children
	if rng.randf() < 0.5:
		var doc := _find_path(c_children, [_t("VFS_DOCUMENTS")])
		if not doc.is_empty():
			percorso = [_t("VFS_DOCUMENTS")]
			dentro = doc["children"]
			# meta' delle volte un livello piu' giu', in una cartella dell'utente
			if not sotto_doc.is_empty() and rng.randf() < 0.5:
				var p: Array = _pick(sotto_doc, rng)
				var sotto := _find_path(c_children, p)
				if not sotto.is_empty():
					percorso = p
					dentro = sotto["children"]
	dentro.insert(rng.randi_range(0, dentro.size()), folder)
	GameManager.note_key(KEY_DISCO, "%s (folder name, in %s)"
			% [str(folder.get("name", "?")), _percorso_dos(percorso)], "FOLDER")

# ---------------- il riempimento a caso (catalogo_disco.gd) ----------------

# Mette sul disco quello che il catalogo puo' offrire: sottocartelle in Documenti,
# programmi inventati, cartelle in piu' di C:, binari in SYSTEM e TEMP, file d'epoca per
# zona e 2-3 file horror. Torna i percorsi nuovi che le chiavi possono usare.
#
# DUE REGOLE che tengono uguali le partite fra le lingue (filesystem_test, STESSA_FORMA):
# ogni scelta si fa per INDICE di voce del catalogo, mai sul nome tradotto; e "questa
# voce c'e' gia' qui?" si chiede alla chiave della voce, non al nome. Una voce d'epoca o
# horror compare una volta sola sul disco; i file dei programmi una per programma.
static func _riempi_disco(c: Array) -> Dictionary:
	var r := _run_rng(VFS_SALT + 2)
	var doc := _find_path(c, [_t("VFS_DOCUMENTS")])
	var prog := _find_path(c, [_t("VFS_PROGRAMS")])
	var system := _find_path(c, [DIR_SISTEMA, DIR_SYSTEM])
	var temp_c := _find_path(c, [DIR_TEMP])
	var temp_w := _find_path(c, [DIR_SISTEMA, DIR_TEMP])
	# zona -> luoghi possibili: [percorso, cartella]. La radice di C: non e' una cartella
	# del VFS a questo punto (lo diventa dopo): una pseudo-cartella sui suoi figli basta.
	var luoghi := {
		CatalogoDisco.DOCUMENTI: [[[_t("VFS_DOCUMENTS")], doc]],
		CatalogoDisco.RADICE: [[[], {"children": c}]],
		CatalogoDisco.SISTEMA: [[[DIR_SISTEMA], _find_path(c, [DIR_SISTEMA])]],
		CatalogoDisco.TEMP: [[[DIR_TEMP], temp_c], [[DIR_SISTEMA, DIR_TEMP], temp_w]],
		CatalogoDisco.PROGRAMMA: [[[_t("VFS_PROGRAMS"), APP_FOTO],
				_find_path(c, [_t("VFS_PROGRAMS"), APP_FOTO])]],
		CatalogoDisco.EXTRA: [],
	}
	var chiave_file: Array = []
	var sotto_documenti: Array = []

	# 1. le cartelle dell'utente dentro Documenti
	for k in _alcuni(CatalogoDisco.CARTELLE_DOCUMENTI, CatalogoDisco.QUANTE_SOTTOCARTELLE, r):
		var f := _folder(_t(str(k)), "folder", [])
		_inserisci(doc["children"], f, r)
		var p := [_t("VFS_DOCUMENTS"), f["name"]]
		luoghi[CatalogoDisco.DOCUMENTI].append([p, f])
		chiave_file.append(p)
		sotto_documenti.append(p)

	# 2. i programmi inventati, ognuno coi suoi binari e (forse) LEGGIMI e LICENZA
	for voce in _alcuni(CatalogoDisco.PROGRAMMI, CatalogoDisco.QUANTI_PROGRAMMI, r):
		var f := _folder(str(voce[0]), "folder", _binari(voce[1]))
		_file_dei_programmi(f, r)
		_inserisci(prog["children"], f, r)
		var p := [_t("VFS_PROGRAMS"), f["name"]]
		luoghi[CatalogoDisco.PROGRAMMA].append([p, f])
		chiave_file.append(p)
	# PhotoLab e' fisso, ma un LEGGIMI ce lo puo' avere anche lui
	_file_dei_programmi(luoghi[CatalogoDisco.PROGRAMMA][0][1], r)

	# 3. le cartelle in piu' nella radice di C:
	for voce in _alcuni(CatalogoDisco.CARTELLE_RADICE, CatalogoDisco.QUANTE_CARTELLE_RADICE, r):
		var f := _folder(str(voce[0]), "folder", _binari(voce[1]))
		_inserisci(c, f, r)
		var p := [f["name"]]
		luoghi[CatalogoDisco.EXTRA].append([p, f])
		chiave_file.append(p)

	# 4. binari in piu' in SYSTEM, e qualche ~DFxxxx.TMP nelle due TEMP
	for nome in _alcuni(CatalogoDisco.BINARI_SISTEMA, CatalogoDisco.QUANTI_BINARI_SISTEMA, r):
		system["children"].append(_binario(str(nome)))
	for i in range(r.randi_range(CatalogoDisco.QUANTI_TMP[0], CatalogoDisco.QUANTI_TMP[1])):
		var t: Dictionary = temp_c if r.randf() < 0.5 else temp_w
		var nome := "~DF%04X.TMP" % r.randi_range(0x1000, 0xFFFF)
		if _nome_libero(t["children"], nome) == nome:
			t["children"].append(_binario(nome))

	# 5. i file d'epoca, zona per zona
	var usate := {}          # chiavi delle voci gia' sul disco: una volta sola ciascuna
	for zona in CatalogoDisco.QUANTI_EPOCA:
		var quanti: Array = CatalogoDisco.QUANTI_EPOCA[zona]
		var n := r.randi_range(int(quanti[0]), int(quanti[1]))
		var adatte: Array = []
		for voce in CatalogoDisco.FILE_EPOCA:
			if (voce[2] as Array).has(zona):
				adatte.append(voce)
		for voce in _shuffled(adatte, r):
			if n <= 0:
				break
			if _metti_voce(voce, [zona], luoghi, usate, r):
				n -= 1

	# 6. la storia: i file del PADRE (almeno uno sempre) e gli HORROR, pochi, ciascuno in
	# uno qualunque dei suoi posti
	for gruppo in [[CatalogoDisco.FILE_LORE_PADRE, CatalogoDisco.QUANTI_PADRE],
			[CatalogoDisco.FILE_HORROR, CatalogoDisco.QUANTI_HORROR]]:
		var h := r.randi_range(int(gruppo[1][0]), int(gruppo[1][1]))
		for voce in _shuffled(gruppo[0], r):
			if h <= 0:
				break
			if _metti_voce(voce, voce[2], luoghi, usate, r):
				h -= 1

	return {"chiave_file": chiave_file, "sotto_documenti": sotto_documenti}

# Mette UNA voce del catalogo in uno dei luoghi delle zone date (a caso). Falso se la voce
# e' gia' sul disco o se nessuna di quelle zone ha un luogo in questa partita (EXTRA senza
# cartelle in piu'): chi chiama passa alla voce successiva.
static func _metti_voce(voce: Array, zone: Array, luoghi: Dictionary, usate: Dictionary,
		r: RandomNumberGenerator) -> bool:
	if usate.has(voce[0]):
		return false
	var possibili: Array = []
	for z in zone:
		possibili.append_array(luoghi.get(z, []))
	if possibili.is_empty():
		return false
	var dove: Dictionary = _pick(possibili, r)[1]
	var nome := _t(str(voce[0]))
	if _nome_libero(dove["children"], nome) != nome:
		return false
	var f := _text(nome, _testo_catalogo(str(voce[1]), str(dove.get("name", ""))))
	f["voce"] = voce[0]       # da quale voce del catalogo viene (lo leggono i test)
	_inserisci(dove["children"], f, r)
	usate[voce[0]] = true
	return true

# Il testo di una voce del catalogo coi SEGNAPOSTO sostituiti: {PROG} = la cartella in cui
# finisce (il programma), {PROTAGONISTA} = il nome del protagonista, che sta in UNA riga
# del CSV (LORE_PROTAGONIST) perche' il proprietario potrebbe cambiarlo.
static func _testo_catalogo(chiave: String, cartella: String) -> String:
	return _testo(chiave).replace("{PROG}", cartella) \
			.replace("{PROTAGONISTA}", _t("LORE_PROTAGONIST"))

# LEGGIMI e LICENZA di un programma, ognuno con la sua probabilita'.
static func _file_dei_programmi(cartella: Dictionary, r: RandomNumberGenerator) -> void:
	for voce in CatalogoDisco.FILE_DEI_PROGRAMMI:
		if r.randf() < float(voce[2]):
			var nome := _t(str(voce[0]))
			if _nome_libero(cartella["children"], nome) == nome:
				var f := _text(nome, _testo_catalogo(str(voce[1]), str(cartella["name"])))
				f["voce"] = voce[0]
				cartella["children"].append(f)

static func _binari(nomi: Array) -> Array:
	var out: Array = []
	for n in nomi:
		out.append(_binario(str(n)))
	return out

# Da 'min' a 'max' elementi distinti dell'array, a caso.
static func _alcuni(arr: Array, quanti: Array, r: RandomNumberGenerator) -> Array:
	var n := mini(arr.size(), r.randi_range(int(quanti[0]), int(quanti[1])))
	return _shuffled(arr, r).slice(0, n)

# In un punto a caso dell'elenco: in fondo si riconoscerebbe a colpo d'occhio cosa e'
# stato aggiunto (lo stesso motivo per cui la cartella della chiave 2 si infila a caso).
static func _inserisci(figli: Array, nodo: Dictionary, r: RandomNumberGenerator) -> void:
	figli.insert(r.randi_range(0, figli.size()), nodo)

# Il nome dato se e' libero in quella cartella, altrimenti "nome (2).ext": come un disco
# Windows, maiuscole e minuscole non contano.
static func _nome_libero(figli: Array, nome: String) -> String:
	var presi := {}
	for f in figli:
		if f is Dictionary:
			presi[str(f.get("name", "")).to_lower()] = true
	if not presi.has(nome.to_lower()):
		return nome
	var punto := nome.rfind(".")
	var base := nome if punto <= 0 else nome.substr(0, punto)
	var est := "" if punto <= 0 else nome.substr(punto)
	var n := 2
	while presi.has(("%s (%d)%s" % [base, n, est]).to_lower()):
		n += 1
	return "%s (%d)%s" % [base, n, est]

# Un percorso (array di nomi sotto C:) scritto come lo scriveva il sistema: C:\WHALE\TEMP.
static func _percorso_dos(percorso: Array) -> String:
	var s := "C:\\"
	for i in range(percorso.size()):
		s += str(percorso[i])
		if i < percorso.size() - 1:
			s += "\\"
	return s

# ---------------- foto (cartella Immagini + chiave 4) ----------------

# Contenuto della cartella Immagini: un leggimi che suggerisce il puzzle + le foto.
static func _make_image_folder(rng: RandomNumberGenerator) -> Array:
	var children: Array = [
		_text(_t("FN_README"), _testo("FT_README")),
	]
	children.append_array(_make_photos(rng))
	return children

# Genera 3-4 foto (nomi da fotocamera d'epoca, vedi _nomi_foto): una porta la chiave 4, le altre sono esche.
# Usa le foto d'autore in PHOTO_DIR se presenti, altrimenti placeholder procedurali.
#
# La portatrice si sceglie a CASO fra quelle del run: ogni foto va bene, perche' la
# scritta la fa comparire la ricetta (vedi _ricetta). Le altre sono esche.
static func _make_photos(rng: RandomNumberGenerator) -> Array:
	var files := _photo_files()
	# una sola estrazione, come prima: il resto della sequenza (portatrice, ecc.) non cambia
	var seme_nomi := rng.randi()
	var label := GameManager.key_label(KEY_IMAGE)
	var photos: Array = []

	if files.is_empty():
		var count := PHOTO_COUNT
		var nomi := _nomi_foto(count, seme_nomi)
		for i in range(count):
			photos.append(_photo_proc(nomi[i], rng.randi(), _pick(PHOTO_TINTS, rng)))
	else:
		var pool := _shuffled(files, rng)
		var count: int = mini(pool.size(), PHOTO_COUNT)
		var nomi := _nomi_foto(count, seme_nomi)
		for i in range(count):
			photos.append(_photo_file(nomi[i], str(pool[i])))

	if label == "" or photos.is_empty():
		return photos

	# Portatrice: a CASO fra le foto del run, senza preferenze. Nessuna foto e' esclusa e
	# nessuna privilegiata: la randomizzazione e' quella promessa dal gioco.
	var idx := rng.randi_range(0, photos.size() - 1)
	photos[idx]["code_seed"] = rng.randi()   # rotazione della scritta (stabile per run)
	# DUE MODI di nascondere la chiave in una foto, sorteggiati dal seme (17/09/2026): nei
	# pixel (rivelata dalla ricetta dei cursori) o nei BYTE del file, come un commento JPEG,
	# che si trova aprendo
	# l'immagine col Blocco note -- che e' il gioco promesso dal titolo, ed e' d'epoca (i
	# commenti nei JPEG esistevano, e aprire un'immagine in un editor di testo per trovarci
	# stringhe leggibili era un passatempo comune).
	var nel_file: bool = rng.randf() < CODE_QUOTA_FILE
	var sorgente := str(photos[idx].get("path", "")).get_file()
	var dove := str(photos[idx]["name"])
	dove += " = %s" % (sorgente if sorgente != "" else "generated")
	if nel_file:
		photos[idx]["code_commento"] = _commento_file(label, rng)
		dove += " - IN THE FILE (open with Notepad)"
		GameManager.note_key(KEY_IMAGE, dove)
		return photos

	photos[idx]["code"] = label
	var img := _scan_image(photos[idx])
	var ricetta: Array = []
	var spot := {}
	for tentativo in range(30):
		ricetta = _ricetta(rng)
		spot = _punto_codice(img, ricetta, rng)
		if float(spot.get("stacco", 1.0)) >= CODE_STACCO_MIN:
			break
	photos[idx]["ricetta"] = ricetta
	photos[idx]["code_uv"] = spot["uv"]
	photos[idx]["code_base"] = spot["avg"]
	var uv: Vector2 = spot["uv"]
	dove += " - in the pixels at %d%%,%d%% - recipe: %s" % [int(uv.x * 100.0), int(uv.y * 100.0), ricetta_testo(ricetta)]
	GameManager.note_key(KEY_IMAGE, dove)
	return photos

# Il testo del commento dentro il file: una nota che un utente del '98 avrebbe lasciato col
# suo programma di fotoritocco, col codice dentro. Non si dice mai "codice" o "chiave": chi
# legge deve riconoscerlo da solo.
static func _commento_file(label: String, rng: RandomNumberGenerator) -> String:
	var modelli := ["FC_1", "FC_2", "FC_3", "FC_4", "FC_5", "FC_6"]
	return (_t(str(_pick(modelli, rng))) % label)

# Come si VEDE un'immagine aperta col Blocco note: l'intestazione JFIF, poi byte illeggibili,
# col commento in chiaro in mezzo. Non e' un vero JPEG (le foto del run sono generate a
# runtime) ma ha la forma giusta, ed e' quella che conta: il giocatore scorre la sbrodolata e
# trova la riga leggibile. Deterministico dal nome del file, cosi' riaprirlo da' lo stesso.
static func byte_dump(node: Dictionary) -> String:
	var nome := str(node.get("name", "IMG.jpg"))
	var commento := str(node.get("code_commento", ""))
	var r := RandomNumberGenerator.new()
	r.seed = hash(nome)
	var out := PackedStringArray()
	# DOVE finisce il commento: sorteggiato dal nome del file, quindi diverso a ogni run e
	# sempre lo stesso riaprendo lo stesso file. Prima era scritto a mano e usciva SEMPRE
	# alla riga 7 su 31 -- il 20% dall'alto, misurato su 14 semi (proprietario, 20/09/2026:
	# "appare sempre in alto"). Era lo stesso difetto della chiave web, che prima di
	# web_anchor.gd finiva sempre in fondo alla pagina.
	var punto := r.randi_range(0, 3) if commento != "" else -1

	# intestazione JFIF come si vedeva davvero. I byte si costruiscono con _bytes() e non con
	# gli escape nel sorgente: un \u0000 dentro una stringa GDScript fa fallire il tokenizer
	# ("Unexpected NUL character"), e i NUL veri diventano spazi perche' e' cosi' che li
	# mostrava un editor di testo.
	out.append(_bytes([255, 216, 255, 224, 0, 16]) + "JFIF" + _bytes([0, 1, 1, 0, 0, 1, 0, 1, 0, 0]))
	out.append(_riga_binaria(r, 62))
	if punto == 0:
		out.append(_segmento_commento(r, commento))      # subito dopo l'intestazione

	# tabelle di quantizzazione (DQT)
	out.append(_riga_binaria(r, 58) + _bytes([255, 219, 0, 67, 0]))
	for i in range(r.randi_range(2, 6)):
		out.append(_riga_binaria(r, 64))
	if punto == 1:
		out.append(_segmento_commento(r, commento))      # fra le tabelle

	# dimensioni (SOF0) e tabelle di Huffman (DHT)
	out.append(_bytes([255, 192, 0, 17, 8]) + _riga_binaria(r, 44))
	out.append(_bytes([255, 196, 0, 31, 0]) + _riga_binaria(r, 40))
	for i in range(r.randi_range(3, 9)):
		out.append(_riga_binaria(r, 64))
	if punto == 2:
		out.append(_segmento_commento(r, commento))      # l'ultimo punto possibile

	# SOS: da qui in poi sono dati compressi. Un commento NON puo' stare li' in mezzo --
	# dopo l'inizio scansione non ci sono piu' marcatori fino alla fine, e un file fatto
	# cosi' non sarebbe un JPEG. Per questo l'unico modo di finire IN FONDO e' la coda.
	out.append(_bytes([255, 218, 0, 12, 3]) + _riga_binaria(r, 48))
	for i in range(r.randi_range(6, 26)):
		out.append(_riga_binaria(r, 64))
	out.append(_riga_binaria(r, 37) + _bytes([255, 217]))     # EOI: fine dell'immagine

	# ...e dopo la fine: quello che tanti programmi dell'epoca lasciavano attaccato al file
	# (miniature, avanzi dell'editor). E' la posizione che prima non esisteva affatto.
	if punto == 3:
		out.append(_segmento_commento(r, commento))
		for i in range(r.randi_range(0, 3)):
			out.append(_riga_binaria(r, 64))
	return "\n".join(out)

# Il segmento COM: byte, marcatore FF FE, lunghezza, il testo IN CHIARO, altri byte. Anche
# quanti byte stanno prima e dopo e' sorteggiato: a lunghezza fissa la riga del commento
# si riconoscerebbe dalla forma, senza nemmeno leggerla.
static func _segmento_commento(r: RandomNumberGenerator, testo: String) -> String:
	return _riga_binaria(r, r.randi_range(3, 22)) + _bytes([255, 254, 0, testo.length() + 2]) \
			+ testo + _riga_binaria(r, r.randi_range(3, 18))

# Byte espliciti come caratteri. I NUL diventano spazi: un NUL vero dentro una String di
# Godot la troncherebbe, e a schermo non si vedrebbe comunque nulla.
static func _bytes(v: Array) -> String:
	var s := ""
	for b in v:
		var n: int = int(b) & 0xFF
		s += " " if n == 0 else char(n)
	return s

# Una riga di byte "illeggibili": si evitano NUL e caratteri di controllo, che manderebbero a
# capo o che non si disegnerebbero, cosi' la sbrodolata resta compatta come nella realta'.
static func _riga_binaria(r: RandomNumberGenerator, quanti: int) -> String:
	var s := ""
	for i in range(quanti):
		var c := r.randi_range(33, 255)
		if c == 127 or (c >= 128 and c <= 160):
			c = 46
		s += char(c)
	return s

# ---------------- la scritta nei pixel: ricetta e punto ----------------

# La ricetta: UN cursore e un verso, fra quelli ammessi (ImageViewerApp.VERSI).
static func _ricetta(rng: RandomNumberGenerator) -> Array:
	var p := str(_pick(ImageViewerApp.VERSI.keys(), rng))
	return [{"param": p, "verso": int(_pick(ImageViewerApp.VERSI[p], rng))}]

# La ricetta in chiaro, per il pannello F12 (testo da sviluppatore: inglese).
static func ricetta_testo(ricetta: Array) -> String:
	var parti: PackedStringArray = []
	for ing in ricetta:
		parti.append("%s %s" % [str(ing["param"]), "up" if int(ing["verso"]) > 0 else "down"])
	return " + ".join(parti)

# Dove scrivere: fra alcuni punti a caso, quello che A CURSORE SPINTO risalta di piu'
# (una zona che a quei valori finisce tutta bianca o tutta nera la cancellerebbe), con una
# preferenza per le zone calme, dove sei caratteri si leggono meglio.
static func _punto_codice(img: Image, ricetta: Array, rng: RandomNumberGenerator) -> Dictionary:
	var meglio := {"uv": Vector2(0.5, 0.5), "avg": Color(0.5, 0.5, 0.5)}
	if img == null:
		return meglio
	var v := ImageViewerApp.valori_ricetta(ricetta)
	var dim := Vector2(img.get_size())
	var box_dim := Vector2i(int(dim.x * 0.22), int(dim.y * 0.14))
	var punteggio := -INF
	for i in range(12):
		var uv := Vector2(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8))
		var box := Rect2i(Vector2i(uv * dim) - box_dim / 2, box_dim)
		var st := _box_stats(img, box)
		var avg: Color = st["avg"]
		var l: float = (avg.r + avg.g + avg.b) / 3.0
		var codice: float = clampf(l + ImageViewerApp.verso_migliore(l, ricetta) * ImageViewerApp.CODE_FORZA, 0.0, 1.0)
		var stacco: float = absf(ImageViewerApp.luma_regolata(codice, v) - ImageViewerApp.luma_regolata(l, v))
		var p: float = stacco - 0.5 * float(st["sigma"])
		if p > punteggio:
			punteggio = p
			meglio = {"uv": uv, "avg": avg, "stacco": stacco}
	return meglio

# Colore medio e deviazione standard della luminanza dentro un riquadro (campionati).
static func _box_stats(img: Image, box: Rect2i) -> Dictionary:
	var campione_x: int = maxi(1, box.size.x / 12)
	var campione_y: int = maxi(1, box.size.y / 6)
	var sr := 0.0
	var sg := 0.0
	var sb := 0.0
	var sl := 0.0
	var sl2 := 0.0
	var n := 0
	for y in range(box.position.y, box.position.y + box.size.y, campione_y):
		for x in range(box.position.x, box.position.x + box.size.x, campione_x):
			var c := img.get_pixel(x, y)
			sr += c.r
			sg += c.g
			sb += c.b
			var l := (c.r + c.g + c.b) / 3.0
			sl += l
			sl2 += l * l
			n += 1
	if n == 0:
		return {"avg": Color(0.5, 0.5, 0.5), "sigma": 0.0}
	var media := sl / float(n)
	return {
		"avg": Color(sr / float(n), sg / float(n), sb / float(n)),
		"sigma": sqrt(maxf(0.0, sl2 / float(n) - media * media)),
	}

# Immagine della foto ridotta alla MISURA IN CUI il giocatore la vede (il SubViewport del
# visualizzatore, max CODE_SCAN): analizzare una copia piu' piccola mentirebbe, perche' il
# rimpicciolimento media via la grana e una zona mossa sembrerebbe liscia.
static func _scan_image(node: Dictionary) -> Image:
	var tex := _raw_photo(node)
	if tex == null:
		return null
	var img := tex.get_image()
	if img == null:
		return null
	img = img.duplicate() as Image
	if img.is_compressed() and img.decompress() != OK:
		return null
	var fit := _fit_scan(img.get_size())
	if fit != img.get_size():
		img.resize(fit.x, fit.y, Image.INTERPOLATE_BILINEAR)
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	return img

# Misura a video: dentro CODE_SCAN, senza mai ingrandire (come ImageViewerApp._fit_size).
static func _fit_scan(src: Vector2i) -> Vector2i:
	if src.x <= 0 or src.y <= 0:
		return CODE_SCAN
	var s: float = minf(1.0, minf(float(CODE_SCAN.x) / float(src.x), float(CODE_SCAN.y) / float(src.y)))
	return Vector2i(maxi(8, int(src.x * s)), maxi(8, int(src.y * s)))

# Elenco (ordinato, per riproducibilita') dei file immagine in PHOTO_DIR. Gestisce sia
# l'editor (xxx.png + xxx.png.import) sia l'export. Vuoto se la cartella non esiste.
static func _photo_files() -> Array:
	var out: Array = []
	var seen := {}
	var d := DirAccess.open(PHOTO_DIR)
	if d == null:
		return out
	for f in d.get_files():
		var fname := f
		if fname.ends_with(".import"):
			fname = fname.trim_suffix(".import")
		var low := fname.to_lower()
		var is_img := low.ends_with(".png") or low.ends_with(".jpg") or low.ends_with(".jpeg") or low.ends_with(".webp") or low.ends_with(".bmp")
		if is_img and not seen.has(fname):
			seen[fname] = true
			out.append(PHOTO_DIR + fname)
	out.sort()
	return out

# Nodo foto PROCEDURALE (placeholder): parametri per rigenerarla in make_photo.
static func _photo_proc(name: String, seed: int, tint: String) -> Dictionary:
	return {
		"name": name, "type": "file", "icon": "image", "filetype": "image",
		"photo_seed": seed, "tint": tint, "code": "",
	}

# Nodo foto da FILE (foto d'autore): "path" punta all'immagine in PHOTO_DIR.
static func _photo_file(name: String, path: String) -> Dictionary:
	return {
		"name": name, "type": "file", "icon": "image", "filetype": "image",
		"path": path, "code": "",
	}

# Texture della foto COSI' COME LA VEDE IL GIOCATORE: ridotta alla misura di
# visualizzazione (la stessa su cui _punto_codice sceglie il punto della scritta).
static func make_photo(node: Dictionary) -> Texture2D:
	var img := _scan_image(node)
	if img == null:
		return _raw_photo(node)
	return ImageTexture.create_from_image(img)

# Texture della foto NON toccata: file d'autore, oppure placeholder procedurale generato
# (CPU, deterministico per seed: campo tinto, granuloso, vignettato). La scritta-chiave non
# sta nei pixel: la sovrappone il visualizzatore come Label che CONDIVIDE lo stesso shader.
static func _raw_photo(node: Dictionary) -> Texture2D:
	var path := str(node.get("path", ""))
	if path != "" and ResourceLoader.exists(path):
		var res = load(path)
		if res is Texture2D:
			return res
	var r := RandomNumberGenerator.new()
	r.seed = int(node.get("photo_seed", 0))
	var tint := Color(str(node.get("tint", "505050")))
	var w := PHOTO_W
	var h := PHOTO_H
	var cx := w * 0.5
	var cy := h * 0.5
	var maxd2 := cx * cx + cy * cy
	var data := PackedByteArray()
	data.resize(w * h * 3)
	var i := 0
	for y in range(h):
		for x in range(w):
			var dx := x - cx
			var dy := y - cy
			var vig := 1.0 - 0.45 * ((dx * dx + dy * dy) / maxd2)   # piu' scuro ai bordi
			var n := r.randf_range(-0.012, 0.012)                     # grana
			data[i] = int(clampf((tint.r + n) * vig, 0.0, 1.0) * 255.0)
			data[i + 1] = int(clampf((tint.g + n) * vig, 0.0, 1.0) * 255.0)
			data[i + 2] = int(clampf((tint.b + n) * vig, 0.0, 1.0) * 255.0)
			i += 3
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGB8, data)
	return ImageTexture.create_from_image(img)

# ---------------- utilita' seminate ----------------

# RNG seminato dal seme del run (+ salt): riproducibile e indipendente dall'ordine
# di chiamata. run_seed = 0 (run non avviato) -> contenuto deterministico senza chiavi.
static func _run_rng(salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = GameManager.run_seed + salt
	return r

# Copia mescolata (Fisher-Yates) con l'RNG dato: NON tocca l'array originale.
static func _shuffled(arr: Array, rng: RandomNumberGenerator) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp
	return a

# Elemento a caso dall'array con l'RNG dato.
# Nomi dei file come li scrivevano le fotocamere digitali del 1997-99: una per partita (la
# fotocamera di famiglia), numerazione crescente da un punto a caso, con i buchi delle foto
# cancellate. Generatore proprio, cosi' non sposta la sequenza del resto della cartella.
static func _nomi_foto(count: int, seme: int) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = seme
	var formato := r.randi_range(0, 5)
	var n := r.randi_range(3, 150)
	var nomi: Array = []
	for i in range(count):
		n += r.randi_range(1, 9)
		match formato:
			0: nomi.append("MVC-%03dF.JPG" % n)    # Sony Mavica (salvava su floppy)
			1: nomi.append("DCP_%04d.JPG" % n)     # Kodak DC
			2: nomi.append("DSCN%04d.JPG" % n)     # Nikon Coolpix
			3: nomi.append("PICT%04d.JPG" % n)     # Minolta / Konica
			4: nomi.append("DSC%05d.JPG" % n)      # Sony Cyber-shot
			_: nomi.append("P%X%02d%04d.JPG" % [r.randi_range(1, 12), r.randi_range(1, 28), n])  # Olympus: mese in esadecimale, giorno, contatore
	return nomi

static func _pick(arr: Array, rng: RandomNumberGenerator):
	return arr[rng.randi_range(0, arr.size() - 1)]

# Prima cartella figlia (type "folder") col nome dato; {} se assente.
# Segue un PERCORSO di nomi di cartella a partire da un elenco di figli ({} se si perde).
static func _find_path(children: Array, parts: Array) -> Dictionary:
	if parts.is_empty():
		return {}
	var cur := _find_child(children, str(parts[0]))
	for i in range(1, parts.size()):
		if cur.is_empty():
			return {}
		cur = _find_child(cur.get("children", []), str(parts[i]))
	return cur

static func _find_child(children: Array, name: String) -> Dictionary:
	for c in children:
		if c is Dictionary and str(c.get("name", "")) == name and str(c.get("type", "")) == "folder":
			return c
	return {}

# ---------------- helper di costruzione nodi VFS ----------------

static func _folder(name: String, icon: String, children: Array) -> Dictionary:
	return {"name": name, "type": "folder", "icon": icon, "children": children}

static func _text(name: String, content: String) -> Dictionary:
	return {"name": name, "type": "file", "icon": "text", "filetype": "text", "content": content}

static func _html(name: String, url: String) -> Dictionary:
	return {"name": name, "type": "file", "icon": "web", "filetype": "html", "url": url}

# Un file BINARIO (.EXE, .DLL, .VXD, .TMP, un font): aperto col Blocco note mostra la
# sbrodolata di byte, com'era. Non e' decorazione: chi ha gia' visto che un eseguibile e'
# illeggibile capisce al volo cosa sta guardando quando apre una FOTO col Blocco note, che
# e' una delle due strade della chiave 4 (vedi byte_dump). filetype "bin" = sola lettura.
# Il contenuto e' deterministico dal nome: riaprirlo da' sempre lo stesso.
static func _binario(nome: String) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash(nome)
	var righe := PackedStringArray()
	# "MZ" + l'intestazione DOS, come iniziava ogni eseguibile
	righe.append(_bytes([77, 90, 144, 0, 3, 0, 0, 0, 4]) + _riga_binaria(r, 48))
	for i in range(r.randi_range(6, 11)):
		righe.append(_riga_binaria(r, 64))
	# la scritta che stava in chiaro dentro quasi ogni .EXE dell'epoca
	righe.append(_riga_binaria(r, 14) + "This program cannot be run in DOS mode."
			+ _riga_binaria(r, 9))
	for i in range(r.randi_range(8, 16)):
		righe.append(_riga_binaria(r, 64))
	return {"name": nome, "type": "file", "icon": "exe", "filetype": "bin",
			"content": "\n".join(righe)}
