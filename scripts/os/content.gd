class_name OSContent
extends RefCounted

# ============================================================
# Libreria dei contenuti dell'OS — M3 (parti 1+2+3: data-driven + generatore + foto).
#
# Parte 1: i contenuti (albero del filesystem + pool di siti web) vivono qui come
# DATI, separati da chi li costruisce/mostra (vfs.gd, app_browser.gd, image viewer).
#
# Parte 2 (generatore seminato): dal seme del run (GameManager.run_seed) si decide in
# modo RIPRODUCIBILE quali ~5 siti del pool entrano nel run e DOVE finiscono le
# chiavi. Mappa indice->categoria FISSA (vedi KEY_*):
#   * chiave 1 FILE     -> file portatore (nome + testo a caso) in una cartella a caso
#   * chiave 2 CARTELLA -> cartella "di backup" (nome a caso) col codice nel nome
#   * chiave 3 WEB      -> un sito a caso del run, a caso nel TESTO VISIBILE o nel
#                          SORGENTE HTML (commento)
#   * chiave 4 IMMAGINE -> nascosta in una foto (parte 3, sotto)
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
const KEY_FILE := 1
const KEY_FOLDER := 2
const KEY_WEB := 3
const KEY_IMAGE := 4

# Salt del generatore seminato del filesystem (i siti web vivono ora in WebRuntime).
const VFS_SALT := 1001

# Foto del run.
const PHOTO_W := 320
const PHOTO_H := 240
# --- Nascondiglio della scritta-chiave (REGOLA QUI) ---
# Il punto delicato: tutti i cursori del visualizzatore tranne uno sono funzioni PUNTO PER
# PUNTO, quindi amplificano la scritta e il dettaglio della foto nella stessa misura: conta
# solo il rapporto fra i due, e su una foto piena di grana la scritta resta sepolta a
# qualunque valore (bug dell'11/09/2026). Ammorbidire la zona, il rimedio di prima, lasciava
# un alone visibile: dava piu' fastidio del male.
# La via d'uscita e' il cursore "Nitidezza": un PASSA-BANDA (vedi adjust.gdshader) che
# separa per DIMENSIONE invece che per intensita'. Gran parte del rumore di una foto sta a
# bassa frequenza (sfumature di tono) e non disturba una scritta con tratti di 3-5 px:
# misurato sulle foto del proprietario, il rumore nella banda dei tratti e' 2,5-7 volte piu'
# basso di quello grezzo. Percio' qui si cerca la zona col minor rumore NELLA BANDA e lo
# scarto della scritta si tara su quello.
# (Misurato anche il contrario: ingrandire la scritta PEGGIORA le cose, perche' a scale
# grandi domina la struttura vera della foto. La banda sottile e' la migliore.)
# Aspetto della scritta: sta qui perche' serve sia al visualizzatore (che la disegna) sia
# alla preparazione del nascondiglio (che deve sapere quanto sara' grande).
const CODE_SIZE_FACTOR := 0.062         # altezza del testo, in frazione della foto
# Opacita' bassa di proposito: una scritta semi-trasparente di colore FISSO non aggiunge
# solo uno scarto, APPIATTISCE la trama della foto dentro i tratti, e quell'effetto e'
# proporzionale al rumore locale (0.6 su una zona mossa valeva 17 livelli: piu' del segnale
# che volevo). Lo scarto viene diviso per l'opacita' in _place_code, quindi abbassarla
# riduce l'appiattimento LASCIANDO INTATTO il segnale.
const CODE_ALPHA := 0.40
const CODE_TILT := 12.0                 # rotazione massima della scritta, in gradi
const CODE_BOX := Vector2(0.22, 0.16)   # ingombro di scorta, se non si misura col font
const CODE_DELTA_K := 4.5               # scarto = K x rumore PASSA-BANDA locale
const CODE_DELTA_MIN := 0.012           # ~3 livelli su 255: basta dove il fondo e' piatto
const CODE_DELTA_MAX := 0.058           # ~15 livelli: tetto assoluto, oltre e' una scritta
# (16/09/2026, scelta del proprietario: era 0.070 = 18 livelli, e le foto MOSSE ci
# restavano incollate -- misurate a schermo 24-25 livelli, cioe' una filigrana che
# si nota senza toccare i cursori: troppo facile. Abbassato il TETTO e non K: K
# comanda il rapporto nella banda (rapporto = K x 0.65), e ridurlo avrebbe tolto
# margine alla foto piu' debole.
#
# MISURATO abbassando il tetto (photo_key_test, livelli a schermo A RIPOSO):
#   tetto    beautiful_horse   her    sun_person   foto sfocate
#   0.070          9.1         24.5      25.4         2 su 6
#   0.058          9.1         23.3      23.8         2 su 6   <- adesso
#   0.045          9.1         21.4      14.1         4 su 6
# Il calo e' MENO che proporzionale perche' il sistema compensa: se il tetto piu'
# basso porta il rapporto sotto CODE_BP_RATIO_MIN, la generazione sfoca un po' la
# zona, il rumore nella banda scende e lo scarto torna a essere comandato da K.
#
# AGGIORNAMENTO 17/09/2026, e va letto prima di toccare queste costanti: misurando nella
# banda VERA dello shader (banda_box, non la piramide) il "rapporto = K x 0.65" si e'
# rivelato una stima 2-3 volte ottimista -- dove dice 2.3-2.9 ce n'e' 0.85-1.8 -- e la
# risposta vera del filtro ai tratti e' 0.33, non 0.65. Soprattutto: perche' il codice sia
# insieme NASCOSTO a riposo e RIVELABILE col cursore serve che la struttura mascherante sia
# almeno ~6.8 volte il rumore alla scala dei tratti, e sulle foto vere il meglio ottenibile
# e' 0.4-0.9. Cioe' nessuna taratura di queste costanti puo' ottenere entrambe le cose su
# contenuto fotografico: quello che si regola qui e' solo QUANTO si vede la filigrana.
# La via d'uscita non e' una costante, e' una seconda strada per la chiave (il codice nel
# FILE dell'immagine, alla 95/98) -- vedi tests/photo_reveal_test e tests/photo_banda_scan
# per i numeri, e CLAUDE.md per la storia.
# SCELTA DI GIOCO (14/09/2026, del proprietario): il codice deve poter essere RIVELATO su
# QUALSIASI foto, al prezzo di una filigrana appena percepibile guardando bene a riposo. Le
# misure dicono che le due cose non stanno insieme su foto con trama fitta: nessun filtro
# separa scritta e trama se la scritta e' abbastanza debole da non vedersi. Percio' lo scarto
# non ha piu' un tetto legato alla struttura locale: comanda il rapporto nella banda, col
# solo limite di CODE_DELTA_MAX perche' non diventi una scritta in chiaro.
# Rapporto minimo fra scritta e rumore NELLA BANDA: sotto questo il cursore "Nitidezza" non
# riuscirebbe a tirarla fuori, e scatta il ripiego con la sfocatura.
const CODE_BP_RATIO_MIN := 2.2
# Quanto risponde il passa-banda a un tratto della larghezza giusta (~0.65 dello scarto):
# serve solo a stimare il rapporto qui sopra.
const CODE_BP_RESPONSE := 0.65
# La ricerca gira sulla foto ridotta alla MISURA IN CUI il giocatore la vede (il SubViewport
# del visualizzatore, max 640x480): a risoluzione piu' bassa il rimpicciolimento media via
# la grana e la zona sembrerebbe piu' liscia di quello che e'.
const CODE_SCAN := Vector2i(640, 480)
# Ripiego (raro): se nella banda non c'e' margine, si SFOCA appena la macchia. La sfocatura
# abbassa proprio il rumore della banda lasciando stare i toni larghi, quindi si nota molto
# meno del vecchio "velo" (che sbiadiva la zona verso il colore medio: era l'alone pallido).
const CODE_BLUR_STEPS := [2, 3, 4]
# Quante volte su 1 la chiave della foto va nei BYTE del file invece che nei pixel. Meta' e
# meta': i pixel restano perche' piacciono come idea e su una foto adatta sono la versione
# piu' bella, i byte perche' funzionano sempre.
const CODE_QUOTA_FILE := 0.5
# A parita' di quiete si preferisce una zona SCURA: li' la scritta si nota meno.
const CODE_DARK_BONUS := 0.006
# La macchia e' grande il doppio del testo: cosi' la scritta sta tutta dentro la parte
# piena della sfumatura e i bordi morbidi muoiono fuori dalle lettere.
const CODE_PATCH_SCALE := 2.0
# Analisi delle foto (costosa: carica e rimpicciolisce), memorizzata per processo.
static var _spot_cache: Dictionary = {}
static var _prep_cache: Dictionary = {}
static var _bp_cache: Dictionary = {}
# Tinte di base delle foto (toni medi: lasciano spazio a schiarire/scurire).
const PHOTO_TINTS := ["5a5560", "625a52", "525e58", "5c5c4e", "565c66", "604f52"]
# Cartella delle foto d'autore (PNG/JPG): se contiene immagini il run le usa al posto
# dei placeholder procedurali. Il codice del run viene comunque sovrapposto a runtime
# dal visualizzatore (la chiave cambia ogni partita: un file fisso non puo' contenerla).
const PHOTO_DIR := "res://assets/textures/photos/"

# Testi portatori della chiave in un FILE di testo.
const _FILE_CARRIERS := ["FT_CARRIER_1", "FT_CARRIER_2", "FT_CARRIER_3", "FT_CARRIER_4"]
# Nomi possibili del file portatore (devono NON collidere coi file base del VFS).
# CHIAVI, non nomi: il nome vero lo da' _t() quando si genera il run.
const _FILE_NAMES := ["FN_CODE", "FN_LICENCE", "FN_ACTIVATION", "FN_REMINDER", "FN_SCRATCH"]
# Cartelle del VFS dove puo' finire il file portatore della chiave.
const _FILE_FOLDERS := ["VFS_DOCUMENTS", "VFS_SYSTEM", "VFS_PICTURES"]
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

# Albero base del filesystem (radice "Risorse del computer"). Il filler e' fisso; le
# foto della cartella Immagini e le chiavi 1 (file), 2 (cartella) e 4 (immagine)
# vengono generate/piazzate a caso (seminato) prima di restituire. Lo consuma
# VFS._build(), che aggiunge poi i back-reference _parent.
static func build_filesystem() -> Dictionary:
	var rng := _run_rng(VFS_SALT)
	var c_children: Array = [
		# La cartella protetta vive sul Desktop: l'icona "Documenti" e' un'esca
		# (sembra normale ma e' la cartella segreta da sbloccare, type "secret").
		_folder("Desktop", "folder", [
			{"name": "Secret", "type": "secret", "icon": "locked"},
		]),
		_folder(_t("VFS_DOCUMENTS"), "folder", [
			_text(_t("FN_DIARY"), _testo("FT_DIARY")),
			_text(_t("FN_PASSWORD"), _testo("FT_PASSWORD")),
			_text(_t("FN_SHOPPING"), _testo("FT_SHOPPING")),
		]),
		# La cartella Immagini contiene le foto del run (una nasconde la chiave 4).
		_folder(_t("VFS_PICTURES"), "folder", _make_image_folder(rng)),
		_folder("Internet", "folder", [
			_html(_t("FN_HOMEPAGE"), "start"),
		]),
		_folder(_t("VFS_SYSTEM"), "folder", [
			_text("config.sys", "DEVICE=HIMEM.SYS\nDOS=HIGH,UMB\nFILES=30\nBUFFERS=20"),
			_text("autoexec.bat", "@ECHO OFF\nPROMPT $P$G\nPATH C:\\DOS\nSET TEMP=C:\\TEMP"),
			_text(_t("FN_SYSNOTES"), _testo("FT_SYSNOTES")),
		]),
	]
	_place_file_key(c_children, rng)     # chiave 1
	_place_folder_key(c_children, rng)   # chiave 2
	return _folder(_t("VFS_MY_COMPUTER"), "computer", [
		_folder(_t("VFS_C_DRIVE"), "folder", c_children),
		_folder(_t("VFS_TRASH"), "trash", []),
	])

# Chiave 1: file portatore (nome + contenuto a caso) in una cartella a caso.
static func _place_file_key(c_children: Array, rng: RandomNumberGenerator) -> void:
	var label := GameManager.key_label(KEY_FILE)
	if label == "":
		return
	var folder := _find_child(c_children, _t(_pick(_FILE_FOLDERS, rng)))
	if folder.is_empty():
		return
	var name: String = _t(_pick(_FILE_NAMES, rng))
	var content: String = _testo(_pick(_FILE_CARRIERS, rng))
	folder["children"].append(_text(name, content.replace(KEY_SLOT, label)))
	GameManager.note_key(KEY_FILE, "%s (in %s)" % [name, str(folder.get("name", "?"))])

# Chiave 2: cartella di "backup" (nome a caso) col codice scritto nel nome stesso,
# inserita in un punto a caso tra i figli di C:.
static func _place_folder_key(c_children: Array, rng: RandomNumberGenerator) -> void:
	var label := GameManager.key_label(KEY_FOLDER)
	if label == "":
		return
	var base: String = _t(_pick(_FOLDER_NAMES, rng))
	var folder := _folder("%s %s" % [base, label], "folder", [
		_text(_t("FN_NOTE"), _testo("FT_NOTE")),
	])
	c_children.insert(rng.randi_range(0, c_children.size()), folder)
	GameManager.note_key(KEY_FOLDER, "%s (nome cartella, in C:)" % str(folder.get("name", "?")))

# ---------------- foto (cartella Immagini + chiave 4) ----------------

# Contenuto della cartella Immagini: un leggimi che suggerisce il puzzle + le foto.
static func _make_image_folder(rng: RandomNumberGenerator) -> Array:
	var children: Array = [
		_text("leggimi.txt", "Alcune di queste foto sono venute male: troppo chiare,\ntroppo scure o slavate. Non buttarle."),
	]
	children.append_array(_make_photos(rng))
	return children

# Genera 3-4 foto (nomi tipo IMG_0123.jpg): una porta la chiave 4, le altre sono esche.
# Usa le foto d'autore in PHOTO_DIR se presenti, altrimenti placeholder procedurali.
#
# La portatrice si sceglie a CASO fra quelle del run: nessuna foto e' esclusa, perche'
# il nascondiglio se lo prepara il gioco (vedi _prepare_hiding_spot). Le altre sono esche.
static func _make_photos(rng: RandomNumberGenerator) -> Array:
	var files := _photo_files()
	var base_id := rng.randi_range(100, 8000)
	var label := GameManager.key_label(KEY_IMAGE)
	var photos: Array = []

	if files.is_empty():
		var count := rng.randi_range(3, 4)
		for i in range(count):
			photos.append(_photo_proc("IMG_%04d.jpg" % (base_id + i), rng.randi(), _pick(PHOTO_TINTS, rng)))
	else:
		var pool := _shuffled(files, rng)
		var count: int = mini(pool.size(), rng.randi_range(3, 4))
		for i in range(count):
			photos.append(_photo_file("IMG_%04d.jpg" % (base_id + i), str(pool[i])))

	if label == "" or photos.is_empty():
		return photos

	# Portatrice: a CASO fra le foto del run, senza preferenze. Nessuna foto e' esclusa e
	# nessuna privilegiata: la randomizzazione e' quella promessa dal gioco. Si puo' fare
	# perche' il nascondiglio non va piu' ammorbidito (lo rivela il cursore "Nitidezza"),
	# quindi ogni foto va bene; e costa un'analisi sola invece di quattro.
	var idx := rng.randi_range(0, photos.size() - 1)
	photos[idx]["code_seed"] = rng.randi()   # rotazione della scritta (stabile per run)
	# DUE MODI di nascondere la chiave in una foto, sorteggiati dal seme (17/09/2026).
	# Il primo era l'unico e ha un limite MISURATO: perche' la scritta sia insieme invisibile
	# a riposo e rivelabile col cursore serve che la struttura che la maschera sia ~6.8 volte
	# il rumore alla scala dei tratti, e sulle foto vere il meglio ottenibile e' 0.4-0.9
	# (tests/photo_banda_scan). Su molte foto quindi o si vede subito o non si legge mai.
	# Il secondo modo non ha quel limite e funziona su QUALSIASI foto, perche' non tocca i
	# pixel: il codice sta nei BYTE del file, come un commento JPEG, e si trova aprendo
	# l'immagine col Blocco note -- che e' il gioco promesso dal titolo, ed e' d'epoca (i
	# commenti nei JPEG esistevano, e aprire un'immagine in un editor di testo per trovarci
	# stringhe leggibili era un passatempo comune).
	var nel_file: bool = rng.randf() < CODE_QUOTA_FILE
	var sorgente := str(photos[idx].get("path", "")).get_file()
	var dove := str(photos[idx]["name"])
	dove += " = %s" % (sorgente if sorgente != "" else "generata")
	if nel_file:
		photos[idx]["code_commento"] = _commento_file(label, rng)
		dove += " - NEL FILE (Blocco note)"
		GameManager.note_key(KEY_IMAGE, dove)
		return photos

	photos[idx]["code"] = label
	var spot: Dictionary = _prepare_hiding_spot(photos[idx])
	if not spot.is_empty():
		photos[idx]["code_uv"] = spot["uv"]
		photos[idx]["code_base"] = spot["avg"]
		photos[idx]["code_delta"] = spot["delta"]
		if spot.has("blur_rect"):
			photos[idx]["blur_rect"] = spot["blur_rect"]
			photos[idx]["blur_target"] = spot["blur_target"]
		var uv: Vector2 = spot["uv"]
		dove += " - nei pixel a %d%%,%d%%" % [int(uv.x * 100.0), int(uv.y * 100.0)]
		dove += " (rapporto %.1f%s)" % [float(spot.get("rapporto", 0.0)),
				", sfocata" if spot.has("blur_rect") else ""]
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
	# intestazione JFIF come si vedeva davvero. I byte si costruiscono con _bytes() e non con
	# gli escape nel sorgente: un \u0000 dentro una stringa GDScript fa fallire il tokenizer
	# ("Unexpected NUL character"), e i NUL veri diventano spazi perche' e' cosi' che li
	# mostrava un editor di testo.
	out.append(_bytes([255, 216, 255, 224, 0, 16]) + "JFIF" + _bytes([0, 1, 1, 0, 0, 1, 0, 1, 0, 0]))
	out.append(_riga_binaria(r, 62))
	out.append(_riga_binaria(r, 58) + _bytes([255, 219, 0, 67, 0]))
	for i in range(3):
		out.append(_riga_binaria(r, 64))
	# il commento: marcatore COM (ff fe), lunghezza, poi il testo IN CHIARO
	if commento != "":
		out.append(_riga_binaria(r, 12) + _bytes([255, 254, 0, commento.length() + 2])
				+ commento + _riga_binaria(r, 10))
	out.append(_bytes([255, 192, 0, 17, 8]) + _riga_binaria(r, 44))
	for i in range(22):
		out.append(_riga_binaria(r, 64))
	out.append(_riga_binaria(r, 37) + _bytes([255, 217]))
	return "\n".join(out)

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

# ---------------- il nascondiglio della scritta ----------------

# Prepara il punto dove scrivere il codice sulla foto portatrice:
#  1. cerca la macchia della misura del testo con MENO dettaglio;
#  2. se quella macchia e' comunque troppo mossa, la AMMORBIDISCE quel tanto che basta
#     (bordi sfumati), perche' i cursori del visualizzatore non sanno separare scritta e
#     dettaglio: l'unico modo perche' QUALSIASI foto possa ospitare la chiave e' togliere
#     il dettaglio proprio li' sotto;
#  3. rimisura colore medio e rumore DOPO l'ammorbidimento, cosi' lo scarto della scritta
#     viene tarato sul fondo vero.
# Ritorna { uv, avg, sigma } piu' { blur_rect, blur_target } se ha ammorbidito; {} se
# l'immagine non si riesce a leggere.
static func _prepare_hiding_spot(node: Dictionary) -> Dictionary:
	var ck := _photo_key(node)
	if _prep_cache.has(ck):
		return _prep_cache[ck]
	var res := _do_prepare(node)
	_prep_cache[ck] = res
	return res

static func _do_prepare(node: Dictionary) -> Dictionary:
	var img := _scan_image(node)
	if img == null:
		return {}
	var spot := _best_hiding_spot(node)
	if spot.is_empty():
		return {}
	var box: Rect2i = spot["box"]
	var esito := _valuta(spot["uv"], spot["avg"], float(spot["sigma"]), float(spot["sigma_bp"]), box)
	if float(esito["rapporto"]) >= CODE_BP_RATIO_MIN:
		return esito       # caso normale: la foto NON viene toccata

	# Ripiego: la macchia e' centrata sul testo e grande il doppio, cosi' la scritta sta
	# tutta nella parte piena della sfumatura (gli angoli del riquadro sono il punto critico).
	var centro := Vector2(box.position) + Vector2(box.size) * 0.5
	var mezzo := Vector2(box.size) * (CODE_PATCH_SCALE * 0.5)
	var patch := Rect2i(Vector2i(centro - mezzo), Vector2i(mezzo * 2.0))
	patch = patch.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if patch.size.x < 16 or patch.size.y < 10:
		return esito
	var rect_uv := Rect2(
			float(patch.position.x) / float(img.get_width()), float(patch.position.y) / float(img.get_height()),
			float(patch.size.x) / float(img.get_width()), float(patch.size.y) / float(img.get_height()))

	# Si sfoca il MINIMO indispensabile: primo passo che apre il margine, e li' si ferma.
	var migliore := esito
	for k in CODE_BLUR_STEPS:
		var target := Vector2i(maxi(2, patch.size.x / int(k)), maxi(2, patch.size.y / int(k)))
		var prova := img.duplicate() as Image
		_apply_soft_patch(prova, rect_uv, target)
		var st := _box_stats(prova, box)
		var bp := _box_bp(_bp_pair_img(prova), box)
		var e2 := _valuta(spot["uv"], st["avg"], float(st["sigma"]), float(bp["worst"]), box)
		e2["blur_rect"] = rect_uv
		e2["blur_target"] = target
		if float(e2["rapporto"]) > float(migliore["rapporto"]):
			migliore = e2
		if float(e2["rapporto"]) >= CODE_BP_RATIO_MIN:
			break
	return migliore

# Scarto della scritta per un dato fondo, col rapporto atteso nella banda: lo scarto segue il
# rumore della banda (e' quello che il cursore "Nitidezza" deve battere), col tetto assoluto.
static func _valuta(uv: Vector2, avg: Color, sigma: float, sigma_bp: float, box: Rect2i) -> Dictionary:
	var delta: float = clampf(CODE_DELTA_K * sigma_bp, CODE_DELTA_MIN, CODE_DELTA_MAX)
	var rapporto: float = (CODE_BP_RESPONSE * delta / sigma_bp) if sigma_bp > 0.0002 else 999.0
	return {"uv": uv, "avg": avg, "sigma": sigma, "sigma_bp": sigma_bp,
			"delta": delta, "rapporto": rapporto, "box": box}

# SFOCA una macchia dell'immagine con i bordi SFUMATI: al centro il dettaglio fine se ne va,
# verso il bordo la foto resta intatta, cosi' non si vede un rettangolo. La zona scende a
# "target" pixel e poi risale: misura in pixel della zona, quindi il risultato e' identico
# in analisi e a video. Solo sfocatura: il "velo" verso il colore medio, che lasciava un
# alone pallido, e' stato tolto.
static func _apply_soft_patch(img: Image, rect_uv: Rect2, target: Vector2i) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var rx: int = clampi(int(rect_uv.position.x * w), 0, maxi(0, w - 4))
	var ry: int = clampi(int(rect_uv.position.y * h), 0, maxi(0, h - 4))
	var rw: int = mini(w - rx, maxi(4, int(rect_uv.size.x * w)))
	var rh: int = mini(h - ry, maxi(4, int(rect_uv.size.y * h)))
	if rw < 4 or rh < 4:
		return
	# Sfocatura A PIRAMIDE: dimezzamenti successivi e poi raddoppi. Farlo in un colpo solo
	# (giu' e su con un unico resize) sembra equivalente ma NON lo e': l'ingrandimento
	# bilineare da un'immagine minuscola lascia sfaccettature, cioe' spigoli proprio nella
	# banda dei tratti — misurato, il rumore della banda PEGGIORAVA invece di calare.
	var region := img.get_region(Rect2i(rx, ry, rw, rh))
	var tw: int = clampi(target.x, 2, rw)
	var th: int = clampi(target.y, 2, rh)
	var cw := rw
	var ch := rh
	while cw / 2 >= tw and ch / 2 >= th and cw > 4 and ch > 4:
		cw = maxi(2, cw / 2)
		ch = maxi(2, ch / 2)
		region.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
	while cw < rw or ch < rh:
		cw = mini(rw, cw * 2)
		ch = mini(rh, ch * 2)
		region.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
	for y in range(rh):
		var ny := (float(y) / float(maxi(1, rh - 1))) * 2.0 - 1.0
		for x in range(rw):
			var nx := (float(x) / float(maxi(1, rw - 1))) * 2.0 - 1.0
			var d: float = sqrt(nx * nx + ny * ny)
			# piena fino a 0.72 (ci sta dentro tutto il testo), poi sfuma a zero sul bordo
			var a: float = clampf((1.0 - d) / 0.28, 0.0, 1.0)
			if a <= 0.002:
				continue
			a = a * a * (3.0 - 2.0 * a)
			img.set_pixel(rx + x, ry + y, img.get_pixel(rx + x, ry + y).lerp(region.get_pixel(x, y), a))

# Ingombro della scritta-chiave in pixel, misurato COL FONT VERO e tenendo conto della
# rotazione: e' il riquadro che la preparazione deve rendere tranquillo.
static func _text_box_px(size: Vector2i) -> Vector2i:
	var fsize: int = maxi(10, int(size.y * CODE_SIZE_FACTOR))
	var f := Win95.font("sans")
	var sz := f.get_string_size("0-WWWW", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var c: float = cos(deg_to_rad(CODE_TILT))
	var s: float = sin(deg_to_rad(CODE_TILT))
	var bw: int = int(sz.x * c + sz.y * s) + 6
	var bh: int = int(sz.x * s + sz.y * c) + 6
	# rete di sicurezza se il font non fosse disponibile
	bw = clampi(bw, int(size.x * 0.10), int(size.x * 0.60))
	bh = clampi(bh, int(size.y * 0.06), int(size.y * 0.40))
	return Vector2i(bw, bh)

# Cerca la macchia con meno dettaglio: prova una GRIGLIA di riquadri della misura del testo
# sulla foto ridotta a video e tiene quello con la varianza piu' bassa. Ritorna
# { uv, avg (colore medio), sigma (deviazione standard della luminanza, 0..1), box (px) },
# oppure {} se l'immagine non si riesce a leggere.
static func _best_hiding_spot(node: Dictionary) -> Dictionary:
	var chiave := _photo_key(node)
	if _spot_cache.has(chiave):
		return _spot_cache[chiave]
	var img := _scan_image(node)
	if img == null:
		return {}
	var w := img.get_width()
	var h := img.get_height()
	var tb := _text_box_px(img.get_size())
	var bw: int = mini(w, tb.x)
	var bh: int = mini(h, tb.y)
	# Due passate: prima una griglia larga su tutta la foto, poi una fitta solo attorno
	# ai punti migliori. Stessa qualita' della griglia fitta ovunque, ma molto piu' svelta
	# (l'analisi gira all'avvio della partita).
	var coppia := _bp_pair(node)
	var grezzi := _scan_grid(img, coppia, bw, bh, Rect2i(0, 0, w, h), maxi(3, bw / 2), maxi(3, bh / 2), 4)
	var best := {}
	var best_punteggio := INF
	for g in grezzi:
		var b: Rect2i = g["box"]
		var zona := Rect2i(b.position - Vector2i(bw / 2, bh / 2), b.size + Vector2i(bw, bh))
		zona = zona.intersection(Rect2i(Vector2i.ZERO, Vector2i(w, h)))
		var fini := _scan_grid(img, coppia, bw, bh, zona, maxi(2, bw / 6), maxi(2, bh / 6), 1)
		for f in fini:
			if float(f["punteggio"]) < best_punteggio:
				best_punteggio = float(f["punteggio"])
				best = {"uv": f["uv"], "avg": f["avg"], "sigma": f["sigma"],
						"sigma_bp": f["sigma_bp"], "box": f["box"]}
	_spot_cache[chiave] = best
	return best

# Scandisce una zona con riquadri della misura data e ritorna i "quanti" candidati
# migliori (piu' tranquilli, a pari quiete i piu' scuri).
static func _scan_grid(img: Image, coppia: Array, bw: int, bh: int, zona: Rect2i, passo_x: int, passo_y: int, quanti: int) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var out: Array = []
	var y := zona.position.y
	while y + bh <= mini(h, zona.end.y):
		var x := zona.position.x
		while x + bw <= mini(w, zona.end.x):
			var box := Rect2i(x, y, bw, bh)
			var st := _box_stats(img, box)
			var bp := _box_bp(coppia, box)
			var avg: Color = st["avg"]
			var lum: float = (avg.r + avg.g + avg.b) / 3.0
			# Il punteggio guarda il PASSA-BANDA, non il rumore grezzo: e' quello che il
			# cursore "Nitidezza" amplifichera'. Gran parte del rumore grezzo sta a bassa
			# frequenza (sfumature di tono) e non disturba una scritta larga 4 px.
			var punteggio: float = float(bp["worst"]) + CODE_DARK_BONUS * lum
			out.append({
				"uv": Vector2((x + bw * 0.5) / float(w), (y + bh * 0.5) / float(h)),
				"avg": avg, "sigma": st["sigma"], "sigma_bp": bp["worst"],
				"box": box, "punteggio": punteggio,
			})
			x += passo_x
		y += passo_y
	out.sort_custom(func(a, b): return float(a["punteggio"]) < float(b["punteggio"]))
	return out.slice(0, maxi(1, quanti))

# Coppia di sfocature della foto: [fine (~1 px), larga (~8 px)]. La loro DIFFERENZA e' il
# passa-banda, cioe' esattamente cio' che il cursore "Nitidezza" mostra al giocatore: il
# dettaglio alla larghezza dei tratti della scritta (3-5 px). Si ottiene per dimezzamenti
# successivi (media d'area vera) e un solo ingrandimento di ritorno: ridurre di 8 in un
# colpo camperebbe invece di mediare, creando alias.
static func _bp_pair(node: Dictionary) -> Array:
	var chiave := _photo_key(node)
	if _bp_cache.has(chiave):
		return _bp_cache[chiave]
	var img := _scan_image(node)
	if img == null:
		return []
	var coppia := _bp_pair_img(img)
	_bp_cache[chiave] = coppia
	return coppia

# ---------------- gemello esatto del passa-banda DELLO SHADER ----------------
# La piramide qui sopra (_bp_pair_img) e il filtro di adjust.gdshader NON sono lo stesso
# filtro: la piramide parte da mezza risoluzione, quindi la sua banda sta a ~2-8 px e
# MEDIA VIA la grana e i bordi dei blocchi JPEG fra 1 e 4 px; lo shader invece li vede in
# pieno. Misurato il 17/09/2026: dove la piramide stima un rapporto di 2.3-2.9, nella banda
# vera ce n'e' 0.85-1.8, ed e' per questo che il cursore non tirava fuori il codice.
# Serve ai TEST per misurare la cosa giusta (tests/photo_reveal_test, photo_banda_scan).
# Raggi e pesi vanno tenuti IDENTICI a adjust.gdshader: se si cambiano la', si cambiano qui.
const BP_RAGGI := [
	Vector2(1.0, 0.0), Vector2(0.7071, 0.7071), Vector2(0.0, 1.0), Vector2(-0.7071, 0.7071),
	Vector2(-1.0, 0.0), Vector2(-0.7071, -0.7071), Vector2(0.0, -1.0), Vector2(0.7071, -0.7071)]
const BP_ANELLI := [1.8, 3.8, 6.8]
const BP_PESI := [0.02879, 0.04283, 0.02838]
# Griglia con cui si misura il rumore dentro il riquadro del testo: una colonna per glifo
# (il codice e' "0-WWWW", 6 caratteri) e due righe. Coi quadranti un glifo capitato su una
# striscia mossa restava sepolto mentre la media del quadrante diceva che andava bene.
const BANDA_COL := 6
const BANDA_RIGHE := 2
# Percentile del rumore dentro una cella: la zona morta del cursore va battuta dal PICCO,
# non dalla media.
const BANDA_PERC := 0.98

# Mappa di luminanza come la vede lo shader: pesi Rec.601 e la stessa gamma di luma_at.
static func bp_luma(img: Image) -> PackedFloat32Array:
	var w := img.get_width()
	var h := img.get_height()
	var out := PackedFloat32Array()
	out.resize(w * h)
	for y in range(h):
		for x in range(w):
			var c := img.get_pixel(x, y)
			var l: float = maxf(c.r * 0.299 + c.g * 0.587 + c.b * 0.114, 0.0)
			out[y * w + x] = pow(l, 1.0 / 2.2)
	return out

static func _bp_tap(l: PackedFloat32Array, w: int, h: int, x: float, y: float) -> float:
	# il TextureRect campiona NEAREST e clampa alle UV di bordo: identico qui
	var xi: int = clampi(int(round(x)), 0, w - 1)
	var yi: int = clampi(int(round(y)), 0, h - 1)
	return l[yi * w + xi]

# Valore della banda (fine - larga) in un punto, col kernel dello shader.
static func bp_shader_at(l: PackedFloat32Array, w: int, h: int, x: int, y: int) -> float:
	var fx := float(x)
	var fy := float(y)
	var fine: float = _bp_tap(l, w, h, fx, fy) * 0.5
	for i in [0, 2, 4, 6]:
		var d: Vector2 = BP_RAGGI[i]
		fine += _bp_tap(l, w, h, fx + d.x, fy + d.y) * 0.125
	var larga: float = fine * 0.2
	for i in range(8):
		var dir: Vector2 = BP_RAGGI[i]
		for k in range(BP_ANELLI.size()):
			var r: float = float(BP_ANELLI[k])
			larga += _bp_tap(l, w, h, fx + dir.x * r, fy + dir.y * r) * float(BP_PESI[k])
	return fine - larga

# Rumore nella banda VERA dentro un riquadro, sul ritaglio allargato del raggio massimo del
# kernel (la mappa di luminanza costa una pow() per pixel: su tutta la foto sarebbero
# 300.000 a ogni misura). Griglia che segue i glifi, e si tiene la cella PEGGIORE.
static func banda_box(img: Image, box: Rect2i, passo := 2) -> float:
	var bordo: int = int(ceil(float(BP_ANELLI[BP_ANELLI.size() - 1]))) + 2
	var largo := box.grow(bordo).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if largo.size.x < 4 or largo.size.y < 4:
		return 0.0
	var reg := img.get_region(largo)
	var rw := reg.get_width()
	var rh := reg.get_height()
	var l := bp_luma(reg)
	var off := box.position - largo.position
	var n := BANDA_COL * BANDA_RIGHE
	# Array di Array e non di PackedFloat32Array: un Packed* dentro un Array si copia PER
	# VALORE, quindi gli append finirebbero in una copia buttata via.
	var celle: Array = []
	for i in range(n):
		celle.append([])
	for y in range(0, box.size.y, passo):
		var qy: int = clampi(y * BANDA_RIGHE / maxi(1, box.size.y), 0, BANDA_RIGHE - 1)
		for x in range(0, box.size.x, passo):
			var b := bp_shader_at(l, rw, rh, off.x + x, off.y + y)
			var qx: int = clampi(x * BANDA_COL / maxi(1, box.size.x), 0, BANDA_COL - 1)
			(celle[qy * BANDA_COL + qx] as Array).append(absf(b))
	var peggio := 0.0
	for q in range(n):
		var a: Array = celle[q]
		if a.size() < 4:
			continue
		a.sort()
		peggio = maxf(peggio, float(a[clampi(int(float(a.size()) * BANDA_PERC), 0, a.size() - 1)]))
	return peggio

# Come sopra ma su un'immagine qualsiasi (serve per rimisurare una copia sfocata).
static func _bp_pair_img(img: Image) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var fine := img.duplicate() as Image
	# dimezzamenti ESATTI: col bilineare ogni passo e' una media 2x2 vera
	fine.resize(maxi(1, w / 2), maxi(1, h / 2), Image.INTERPOLATE_BILINEAR)
	var larga := fine.duplicate() as Image
	larga.resize(maxi(1, w / 4), maxi(1, h / 4), Image.INTERPOLATE_BILINEAR)
	larga.resize(maxi(1, w / 8), maxi(1, h / 8), Image.INTERPOLATE_BILINEAR)
	fine.resize(w, h, Image.INTERPOLATE_BILINEAR)
	larga.resize(w, h, Image.INTERPOLATE_BILINEAR)
	return [fine, larga]

# Energia del passa-banda dentro un riquadro: "rms" sull'intero riquadro e "worst" sul
# quadrante peggiore. Per decidere si usa il PEGGIORE: la scritta deve battere il rumore
# in tutto il riquadro, non in media (il passa-banda e' basso anche ai due lati di un bordo
# netto, e un riquadro mezzo quieto sarebbe un nascondiglio finto).
static func _box_bp(coppia: Array, box: Rect2i) -> Dictionary:
	if coppia.size() < 2:
		return {"rms": 0.0, "worst": 0.0}
	var fine: Image = coppia[0]
	var larga: Image = coppia[1]
	var campione_x: int = maxi(1, box.size.x / 12)
	var campione_y: int = maxi(1, box.size.y / 6)
	var mx := box.position.x + box.size.x / 2
	var my := box.position.y + box.size.y / 2
	var somma := PackedFloat32Array([0.0, 0.0, 0.0, 0.0])
	var quanti := PackedInt32Array([0, 0, 0, 0])
	for y in range(box.position.y, box.position.y + box.size.y, campione_y):
		for x in range(box.position.x, box.position.x + box.size.x, campione_x):
			var a := fine.get_pixel(x, y)
			var b := larga.get_pixel(x, y)
			var d: float = (a.r + a.g + a.b) / 3.0 - (b.r + b.g + b.b) / 3.0
			var q: int = (0 if x < mx else 1) + (0 if y < my else 2)
			somma[q] += d * d
			quanti[q] += 1
	var tot := 0.0
	var n := 0
	var worst := 0.0
	for q in range(4):
		tot += somma[q]
		n += quanti[q]
		if quanti[q] > 0:
			worst = maxf(worst, sqrt(somma[q] / float(quanti[q])))
	return {"rms": sqrt(tot / float(maxi(1, n))), "worst": worst}

# Chiave di cache di una foto (percorso d'autore, o seme del placeholder procedurale).
static func _photo_key(node: Dictionary) -> String:
	return str(node.get("path", "")) if node.has("path") else "proc:%d" % int(node.get("photo_seed", 0))

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

# Texture della foto COSI' COME LA VEDE IL GIOCATORE. Per le esche e' la foto originale;
# per la portatrice e' la foto con la macchia ammorbidita sotto la scritta (preparata al
# momento di generare il run, vedi _prepare_hiding_spot). L'immagine viene ridotta alla
# misura di visualizzazione: e' quella a cui sono state fatte le misure, e il
# visualizzatore la rimpicciolirebbe comunque.
static func make_photo(node: Dictionary) -> Texture2D:
	var img := _scan_image(node)
	if img == null:
		return _raw_photo(node)
	img = img.duplicate() as Image        # la copia in cache resta pulita
	if node.has("blur_rect"):
		_apply_soft_patch(img, node["blur_rect"], node.get("blur_target", Vector2i(8, 8)))
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
static func _pick(arr: Array, rng: RandomNumberGenerator):
	return arr[rng.randi_range(0, arr.size() - 1)]

# Prima cartella figlia (type "folder") col nome dato; {} se assente.
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
