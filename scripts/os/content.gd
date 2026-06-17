class_name OSContent
extends RefCounted

# ============================================================
# Libreria dei contenuti dell'OS — M3 (parti 1+2: contenuto data-driven + generatore).
#
# Parte 1: i contenuti (albero base del filesystem + pool di siti web) vivono qui
# come DATI, separati da chi li costruisce/mostra (vfs.gd, app_browser.gd).
#
# Parte 2 (generatore seminato): dal seme del run (GameManager.run_seed) decidiamo
# in modo RIPRODUCIBILE quali ~5 siti del pool entrano nel run e DOVE finiscono le
# chiavi. Le chiavi non stanno piu' in posizioni fisse:
#   * chiave in FILE   -> file portatore (nome + testo a caso) in una cartella a caso
#   * chiave in CARTELLA -> cartella "di backup" (nome a caso) col codice nel nome
#   * 2 chiavi WEB     -> 2 siti distinti scelti a caso tra quelli del run, ciascuna
#                          a caso nel TESTO VISIBILE oppure nel SORGENTE HTML (commento)
#
# Robustezza: ogni funzione di build usa un RandomNumberGenerator PROPRIO, seminato
# da run_seed + un salt costante. Cosi' il risultato e' riproducibile e NON dipende
# dall'ordine o dal momento di chiamata (il browser genera le pagine in modo lazy,
# il VFS al build_run): stesso seme -> stesso contenuto. La mappa indice->categoria
# e' fissa (1=file, 2=cartella, 3/4=web), cosi' VFS e siti scelgono le proprie
# chiavi senza doversi coordinare; e' solo la POSIZIONE dentro la categoria a variare.
# ============================================================

# Segnaposto generico di chiave nei testi portatori: sostituito con key_label(n).
const KEY_SLOT := "{{KEY}}"

# Quanti siti del pool entrano in un run (il pool ne ha di piu': vedi _site_pool).
const SITE_COUNT := 5

# Salt distinti per i generatori seminati (cosi' VFS e siti non si correlano).
const VFS_SALT := 1001
const SITE_SALT := 2002

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

# Albero base del filesystem (radice "Risorse del computer"). Il filler e' fisso;
# le chiavi 1 (file) e 2 (nome cartella) vengono piazzate a caso (seminato) prima di
# restituire. Lo consuma VFS._build(), che aggiunge poi i back-reference _parent.
static func build_filesystem() -> Dictionary:
	var rng := _run_rng(VFS_SALT)
	var c_children: Array = [
		# La cartella protetta vive sul Desktop: l'icona "Documenti" e' un'esca
		# (sembra normale ma e' la cartella segreta da sbloccare, type "secret").
		_folder("Desktop", "folder", [
			{"name": "Documenti", "type": "secret", "icon": "locked"},
		]),
		_folder("Documenti", "folder", [
			_text("diario.txt", "Caro diario,\noggi ho trovato uno strano computer.\nLo schermo si accende con un ronzio...\n\nC'e' qualcosa che non torna in questa stanza."),
			_text("password.txt", "NON dire a nessuno:\n  utente: admin\n  pass:   hunter2\n\n(cancellare questo file!)"),
			_text("lista_spesa.txt", "- floppy disk\n- nastro adesivo\n- caffe'\n- una nuova tastiera"),
		]),
		_folder("Immagini", "folder", [
			_text("leggimi.txt", "Le immagini sono andate perse durante l'ultimo riavvio."),
		]),
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
	var label := GameManager.key_label(1)
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
	var label := GameManager.key_label(2)
	if label == "":
		return
	var base: String = _pick(_FOLDER_NAMES, rng)
	var folder := _folder("%s %s" % [base, label], "folder", [
		_text("note.txt", "Copia di sicurezza automatica.\nNon eliminare questa cartella."),
	])
	c_children.insert(rng.randi_range(0, c_children.size()), folder)

# ---------------- siti web (pool + selezione + chiavi) ----------------

# Dizionario di pagine per il browser: { "dominio": pagina, ... }. Sceglie ~SITE_COUNT
# siti dal pool (seminato), pota i link interni verso siti non inclusi (niente 404
# dai collegamenti), piazza le 2 chiavi web e genera la "start" dai siti del run.
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
	# colloca le 2 chiavi web (indici 3 e 4) in 2 siti distinti tra quelli scelti
	_place_web_keys(chosen, rng)

	var pages := {}
	for s in chosen:
		pages[str(s["domain"])] = s["page"]
	pages["start"] = _make_start_page(chosen)
	return pages

# Pool autoriale dei siti (8 oggi: piu' di quanti ne usi un run). Ogni voce:
# { domain, name, tagline, featured, page }. "featured" -> compare tra i "piu' visti"
# della home; gli altri tra i "recenti". Le pagine sono SENZA chiave: e' il generatore
# a iniettarla a runtime nei siti scelti. Aggiungere un sito qui lo rende pescabile.
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
			{"tag": "a", "text": "Vai a GiocaWeb", "href": "giochi.net"},
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
			{"tag": "a", "text": "Leggi le notizie", "href": "news.com"},
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
			{"tag": "p", "text": "La password e' sparsa nei file e nei siti di questo computer..."},
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

# Le 2 chiavi web (indici 3 e 4) in 2 siti distinti scelti a caso tra quelli del run,
# ciascuna a caso nel testo visibile (<p>) oppure nel sorgente HTML (commento).
static func _place_web_keys(chosen: Array, rng: RandomNumberGenerator) -> void:
	var hosts := _shuffled(chosen, rng)
	var web_indices := [3, 4]
	for n in range(web_indices.size()):
		if n >= hosts.size():
			break
		var label := GameManager.key_label(int(web_indices[n]))
		if label == "":
			continue
		var page: Dictionary = hosts[n]["page"]
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
