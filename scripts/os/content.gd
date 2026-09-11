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
# Di quanto la scritta-chiave si discosta dal colore di fondo. Basso: all'apertura deve
# risultare invisibile, emerge solo regolando l'immagine. NB: la scritta e' anche
# semi-trasparente (ImageViewerApp.CODE_ALPHA), quindi serve un minimo di scarto perche'
# il segnale sopravviva e resti trovabile regolando contrasto/livelli.
const PHOTO_KEY_DELTA := 0.006
# Tinte di base delle foto (toni medi: lasciano spazio a schiarire/scurire).
const PHOTO_TINTS := ["5a5560", "625a52", "525e58", "5c5c4e", "565c66", "604f52"]
# Cartella delle foto d'autore (PNG/JPG): se contiene immagini il run le usa al posto
# dei placeholder procedurali. Il codice del run viene comunque sovrapposto a runtime
# dal visualizzatore (la chiave cambia ogni partita: un file fisso non puo' contenerla).
const PHOTO_DIR := "res://assets/textures/photos/"

# Testi portatori della chiave in un FILE di testo.
const _FILE_CARRIERS := [
	"Codice di attivazione del prodotto:\n  {{KEY}}\n\nConservare in luogo sicuro. Non divulgare a terzi.",
	"Appunti:\n- comprare floppy\n- {{KEY}} (importante!)\n- chiamare Luca",
	"Licenza d'uso\nNumero di serie: {{KEY}}\nValida per un solo computer.",
	"non dimenticare il codice {{KEY}}\nstavolta l'ho nascosto bene.",
]
# Nomi possibili del file portatore (devono NON collidere coi file base del VFS).
const _FILE_NAMES := ["codice.txt", "licenza.txt", "attivazione.txt", "promemoria.txt", "scratch.txt"]
# Cartelle del VFS dove puo' finire il file portatore della chiave.
const _FILE_FOLDERS := ["Documenti", "Sistema", "Immagini"]
# Nomi possibili della cartella che porta il codice nel proprio nome.
const _FOLDER_NAMES := ["Backup", "Archivio", "Copia", "Vecchi file", "Riserva"]

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
		_folder("Documenti", "folder", [
			_text("diario.txt", "Caro diario,\noggi ho trovato uno strano computer.\nLo schermo si accende con un ronzio...\n\nC'e' qualcosa che non torna in questa stanza."),
			_text("password.txt", "NON dire a nessuno:\n  utente: admin\n  pass:   hunter2\n\n(cancellare questo file!)"),
			_text("lista_spesa.txt", "- floppy disk\n- nastro adesivo\n- caffe'\n- una nuova tastiera"),
		]),
		# La cartella Immagini contiene le foto del run (una nasconde la chiave 4).
		_folder("Immagini", "folder", _make_image_folder(rng)),
		_folder("Internet", "folder", [
			_html("Pagina iniziale.url", "start"),
		]),
		_folder("Sistema", "folder", [
			_text("config.sys", "DEVICE=HIMEM.SYS\nDOS=HIGH,UMB\nFILES=30\nBUFFERS=20"),
			_text("autoexec.bat", "@ECHO OFF\nPROMPT $P$G\nPATH C:\\DOS\nSET TEMP=C:\\TEMP"),
			_text("note_sistema.txt", "Manutenzione completata.\nUltimo riavvio: lunedi'."),
		]),
	]
	_place_file_key(c_children, rng)     # chiave 1
	_place_folder_key(c_children, rng)   # chiave 2
	return _folder("Risorse del computer", "computer", [
		_folder("Disco locale (C:)", "folder", c_children),
		_folder("Cestino", "trash", []),
	])

# Chiave 1: file portatore (nome + contenuto a caso) in una cartella a caso.
static func _place_file_key(c_children: Array, rng: RandomNumberGenerator) -> void:
	var label := GameManager.key_label(KEY_FILE)
	if label == "":
		return
	var folder := _find_child(c_children, _pick(_FILE_FOLDERS, rng))
	if folder.is_empty():
		return
	var name: String = _pick(_FILE_NAMES, rng)
	var content: String = _pick(_FILE_CARRIERS, rng)
	folder["children"].append(_text(name, content.replace(KEY_SLOT, label)))

# Chiave 2: cartella di "backup" (nome a caso) col codice scritto nel nome stesso,
# inserita in un punto a caso tra i figli di C:.
static func _place_folder_key(c_children: Array, rng: RandomNumberGenerator) -> void:
	var label := GameManager.key_label(KEY_FOLDER)
	if label == "":
		return
	var base: String = _pick(_FOLDER_NAMES, rng)
	var folder := _folder("%s %s" % [base, label], "folder", [
		_text("note.txt", "Copia di sicurezza automatica.\nNon eliminare questa cartella."),
	])
	c_children.insert(rng.randi_range(0, c_children.size()), folder)

# ---------------- foto (cartella Immagini + chiave 4) ----------------

# Contenuto della cartella Immagini: un leggimi che suggerisce il puzzle + le foto.
static func _make_image_folder(rng: RandomNumberGenerator) -> Array:
	var children: Array = [
		_text("leggimi.txt", "Alcune di queste foto sono venute male: troppo chiare,\ntroppo scure o slavate. Col visualizzatore puoi regolarle\n(luminosita', contrasto, livelli)."),
	]
	children.append_array(_make_photos(rng))
	return children

# Genera 3-4 foto (nomi tipo IMG_0123.jpg); una a caso nasconde la chiave 4. Usa le
# foto d'autore in PHOTO_DIR se presenti, altrimenti placeholder procedurali.
static func _make_photos(rng: RandomNumberGenerator) -> Array:
	var photos: Array = []
	var files := _photo_files()
	var base_id := rng.randi_range(100, 8000)
	if files.is_empty():
		var count := rng.randi_range(3, 4)
		for i in range(count):
			photos.append(_photo_proc("IMG_%04d.jpg" % (base_id + i), rng.randi(), _pick(PHOTO_TINTS, rng)))
	else:
		var pool := _shuffled(files, rng)
		var count: int = mini(pool.size(), rng.randi_range(3, 4))
		for i in range(count):
			photos.append(_photo_file("IMG_%04d.jpg" % (base_id + i), str(pool[i])))
	var label := GameManager.key_label(KEY_IMAGE)
	if label != "" and not photos.is_empty():
		var idx := rng.randi_range(0, photos.size() - 1)
		photos[idx]["code"] = label
		photos[idx]["code_seed"] = rng.randi()   # posizione/rotazione della scritta (stabile per run)
	return photos

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

# Texture di una foto. Se il nodo ha un "path" (foto d'autore) carica il file; altrimenti
# genera un placeholder procedurale (CPU, deterministico per seed: campo tinto, granuloso,
# vignettato). La scritta-chiave NON sta nei pixel: la sovrappone il visualizzatore come
# Label che CONDIVIDE lo stesso shader, cosi' la regolazione agisce su foto e scritta insieme.
static func make_photo(node: Dictionary) -> Texture2D:
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
			var n := r.randf_range(-0.03, 0.03)                     # grana
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
	return {"name": name, "type": "file", "icon": "ie", "filetype": "html", "url": url}
