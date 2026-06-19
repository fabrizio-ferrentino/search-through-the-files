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

# Quanti siti del pool entrano in un run (il pool ne ha di piu': vedi _site_pool).
const SITE_COUNT := 5

# Salt distinti per i generatori seminati (cosi' VFS e siti non si correlano).
const VFS_SALT := 1001
const SITE_SALT := 2002

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

# Testi portatori della chiave WEB nel TESTO VISIBILE (una riga <p>).
const _TEXT_CARRIERS := [
	"Promemoria personale: {{KEY}}. Gli altri lo sanno.",
	"Nota a margine: il codice e' {{KEY}}, non perderlo.",
	"P.S. ho segnato {{KEY}} per non scordarlo.",
	"Per accedere ricordarsi di: {{KEY}}.",
]
# Testi portatori della chiave WEB nel SORGENTE HTML (commento, non reso a video).
const _COMMENT_CARRIERS := [
	"build-key={{KEY}}",
	"TODO rimuovere prima del rilascio: {{KEY}}",
	"debug {{KEY}}",
	"chiave temporanea {{KEY}}",
]
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

# ---------------- siti web (pool + selezione + chiave) ----------------

# Dizionario di pagine per il browser: { "dominio": pagina, ... }. Sceglie ~SITE_COUNT
# siti dal pool (seminato), pota i link interni verso siti non inclusi (niente 404
# dai collegamenti), piazza la chiave web e genera la "start" dai siti del run.
# Lo consuma BrowserApp._pages().
static func build_sites() -> Dictionary:
	var pool := _site_pool()
	var rng := _run_rng(SITE_SALT)
	var chosen := _shuffled(pool, rng)
	if chosen.size() > SITE_COUNT:
		chosen = chosen.slice(0, SITE_COUNT)

	# insiemi dei domini: quelli del run e quelli dell'intero pool
	var selected := {}
	for s in chosen:
		selected[str(s["domain"])] = true
	var pool_domains := {}
	for s in pool:
		pool_domains[str(s["domain"])] = true

	# pota i link verso ALTRI siti del pool non inclusi nel run
	for s in chosen:
		_prune_links(s["page"], selected, pool_domains)
	# colloca la chiave web (indice 3) in un sito a caso tra quelli scelti
	_place_web_key(chosen, rng)

	var pages := {}
	for s in chosen:
		pages[str(s["domain"])] = s["page"]
	pages["start"] = _make_start_page(chosen)
	return pages

# Pool autoriale dei siti (8 oggi: piu' di quanti ne usi un run). Ogni voce:
# { domain, name, tagline, featured, page }. "featured" -> compare tra i "piu' visti"
# della home; gli altri tra i "recenti". Le pagine sono SENZA chiave: e' il generatore
# a iniettarla a runtime nel sito scelto. Aggiungere un sito qui lo rende pescabile.
static func _site_pool() -> Array:
	return [
		_site("news.com", "NewsOggi", "Le ultime notizie", true, [
			{"tag": "img", "alt": "NewsOggi", "color": "8a1f1f", "w": 560, "h": 70},
			{"tag": "h1", "text": "NewsOggi"},
			{"tag": "h2", "text": "In primo piano"},
			{"tag": "p", "text": "Rilasciato un nuovo sistema operativo a finestre: code ai negozi."},
			{"tag": "p", "text": "Gli esperti: i floppy da 1.44 MB sono il futuro dell'archiviazione."},
			{"tag": "img", "alt": "foto sgranata", "color": "777777", "w": 320, "h": 180},
			{"tag": "hr"},
			{"tag": "a", "text": "Pagina iniziale", "href": "start"},
		]),
		_site("giochi.net", "GiocaWeb", "Giochi gratis online", true, [
			{"tag": "img", "alt": "GiocaWeb", "color": "1f6a2f", "w": 560, "h": 70},
			{"tag": "h1", "text": "GiocaWeb"},
			{"tag": "p", "text": "I migliori giochi shareware da scaricare col tuo modem a 56k."},
			{"tag": "ul", "items": [
				"Solitario Deluxe",
				"Campo Minato 3D",
				"Serpente 2000",
			]},
			{"tag": "hr"},
			{"tag": "a", "text": "Pagina iniziale", "href": "start"},
		]),
		_site("meteo.com", "MeteoNow", "Previsioni del tempo", true, [
			{"tag": "img", "alt": "MeteoNow", "color": "2f6a8a", "w": 560, "h": 70},
			{"tag": "h1", "text": "MeteoNow"},
			{"tag": "h2", "text": "Oggi"},
			{"tag": "p", "text": "Sole con qualche nuvola. Massima 24 gradi, minima 14 gradi."},
			{"tag": "p", "text": "Domani: pioggia in arrivo dal pomeriggio."},
			{"tag": "hr"},
			{"tag": "a", "text": "Pagina iniziale", "href": "start"},
		]),
		_site("mail.com", "WebMail", "La tua posta", false, [
			{"tag": "img", "alt": "WebMail", "color": "5a3f8a", "w": 560, "h": 70},
			{"tag": "h1", "text": "WebMail"},
			{"tag": "p", "text": "Accedi alla tua casella di posta elettronica."},
			{"tag": "p", "text": "Utente: ______    Password: ______"},
			{"tag": "p", "text": "(Modulo di accesso non disponibile in questa demo.)"},
			{"tag": "hr"},
			{"tag": "a", "text": "Pagina iniziale", "href": "start"},
		]),
		_site("blog.io", "Il blog segreto", "il diario di qualcuno", false, [
			{"tag": "h1", "text": "Pagina nascosta"},
			{"tag": "p", "text": "Se stai leggendo questo, hai trovato il collegamento giusto nel computer."},
			{"tag": "p", "text": "La password e' sparsa nei file, nei siti e nelle foto di questo computer..."},
			{"tag": "hr"},
			{"tag": "a", "text": "Pagina iniziale", "href": "start"},
		]),
		_site("forum.bbs", "RetroForum", "La bacheca dei nostalgici", false, [
			{"tag": "img", "alt": "RetroForum", "color": "3a5a2f", "w": 560, "h": 70},
			{"tag": "h1", "text": "RetroForum"},
			{"tag": "h2", "text": "Discussioni recenti"},
			{"tag": "ul", "items": [
				"Qualcuno sa riparare un floppy graffiato?",
				"Vendo modem 56k come nuovo",
				"La mia ventola fa un rumore strano di notte...",
			]},
			{"tag": "p", "text": "Registrati per rispondere alle discussioni."},
			{"tag": "hr"},
			{"tag": "a", "text": "Pagina iniziale", "href": "start"},
		]),
		_site("misteri.net", "Misteri.NET", "Verita' che non vogliono farti sapere", false, [
			{"tag": "img", "alt": "Misteri.NET", "color": "1a1030", "w": 560, "h": 70},
			{"tag": "h1", "text": "Misteri.NET"},
			{"tag": "p", "text": "Hai mai avuto la sensazione che il tuo computer ti stia guardando?"},
			{"tag": "p", "text": "Molti utenti riferiscono di file che si aprono da soli nel cuore della notte."},
			{"tag": "p", "text": "Se stai leggendo questo, forse e' gia' troppo tardi."},
			{"tag": "hr"},
			{"tag": "a", "text": "Pagina iniziale", "href": "start"},
		]),
		_site("shop.com", "CompraTutto", "Acquisti per corrispondenza", false, [
			{"tag": "img", "alt": "CompraTutto", "color": "7a5a1f", "w": 560, "h": 70},
			{"tag": "h1", "text": "CompraTutto"},
			{"tag": "h2", "text": "Offerte della settimana"},
			{"tag": "ul", "items": [
				"Tappetino per mouse - 5.000 lire",
				"Confezione 10 floppy - 12.000 lire",
				"Tastiera meccanica - 45.000 lire",
			]},
			{"tag": "p", "text": "Spedizione in 28 giorni lavorativi."},
			{"tag": "hr"},
			{"tag": "a", "text": "Pagina iniziale", "href": "start"},
		]),
	]

# La chiave web (indice 3) in un sito a caso tra quelli del run, a caso nel testo
# visibile (<p>) oppure nel sorgente HTML (commento).
static func _place_web_key(chosen: Array, rng: RandomNumberGenerator) -> void:
	var label := GameManager.key_label(KEY_WEB)
	if label == "" or chosen.is_empty():
		return
	var site: Dictionary = _pick(chosen, rng)
	var page: Dictionary = site["page"]
	var els: Array = page.get("elements", [])
	var el: Dictionary
	if rng.randf() < 0.5:
		var t: String = _pick(_TEXT_CARRIERS, rng)
		el = {"tag": "p", "text": t.replace(KEY_SLOT, label)}
	else:
		var c: String = _pick(_COMMENT_CARRIERS, rng)
		el = {"tag": "comment", "text": c.replace(KEY_SLOT, label)}
	els.insert(_insert_pos(els, rng), el)

# Posizione plausibile dove inserire un elemento: dopo il primo (di solito img/h1).
static func _insert_pos(els: Array, rng: RandomNumberGenerator) -> int:
	if els.size() <= 1:
		return els.size()
	return rng.randi_range(1, els.size())

# Rimuove dalla pagina i link <a> verso ALTRI siti del pool non inclusi nel run
# (cosi' i collegamenti interni non finiscono in un 404). "start" e i link non-pool
# (es. il 404 dimostrativo della home) restano.
static func _prune_links(page: Dictionary, selected: Dictionary, pool_domains: Dictionary) -> void:
	var els: Array = page.get("elements", [])
	var kept: Array = []
	for el in els:
		if str(el.get("tag", "")) == "a":
			var href := str(el.get("href", ""))
			if pool_domains.has(href) and not selected.has(href):
				continue
		kept.append(el)
	page["elements"] = kept

# Voce del pool: impacchetta i metadati (per la home) e la pagina vera e propria.
static func _site(domain: String, name: String, tagline: String, featured: bool, elements: Array) -> Dictionary:
	return {
		"domain": domain,
		"name": name,
		"tagline": tagline,
		"featured": featured,
		"page": {"title": name, "elements": elements},
	}

# Costruisce la "Pagina iniziale" dai siti del run: un collegamento per sito (i
# "featured" tra i piu' visti, gli altri tra i recenti) + il link morto al 404 e il
# suggerimento sull'Ispeziona elemento. Le intestazioni vuote vengono omesse.
static func _make_start_page(sites: Array) -> Dictionary:
	var featured: Array = []
	var recent: Array = []
	for s in sites:
		if bool(s.get("featured", false)):
			featured.append(s)
		else:
			recent.append(s)
	var els: Array = [
		{"tag": "img", "alt": "Il mio portale", "color": "1a3f8a", "w": 560, "h": 80},
		{"tag": "h1", "text": "Pagina iniziale"},
	]
	if not featured.is_empty():
		els.append({"tag": "h2", "text": "Collegamenti piu' visti"})
		for s in featured:
			els.append(_home_link(s))
	if not recent.is_empty():
		els.append({"tag": "hr"})
		els.append({"tag": "h2", "text": "Collegamenti recenti"})
		for s in recent:
			els.append(_home_link(s))
	els.append({"tag": "hr"})
	els.append({"tag": "a", "text": "Sito inesistente (prova 404)", "href": "sito-finto.com"})
	els.append({"tag": "p", "text": "Suggerimento: tasto destro -> Ispeziona elemento per vedere l'HTML."})
	return {"title": "Pagina iniziale", "elements": els}

# Collegamento per la home: "Nome - sottotitolo" verso il dominio del sito.
static func _home_link(s: Dictionary) -> Dictionary:
	var name := str(s.get("name", ""))
	var tagline := str(s.get("tagline", ""))
	var text := name if tagline == "" else "%s - %s" % [name, tagline]
	return {"tag": "a", "text": text, "href": str(s.get("domain", "start"))}

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
