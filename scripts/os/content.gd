class_name OSContent
extends RefCounted

# ============================================================
# Libreria dei contenuti "autoriali" dell'OS — M3 (parte 1: contenuto data-driven).
#
# Qui vivono, come DATI separati dalla logica, i due grandi blocchi di contenuto
# del gioco:
#   * l'albero base del filesystem (prima cablato in vfs.gd::_build)
#   * il "pool" di siti web del browser (prima cablato in app_browser.gd::_pages)
#
# vfs.gd e app_browser.gd ora si limitano a COSTRUIRE/MOSTRARE cio' che questa
# libreria restituisce. Le chiavi del run vengono iniettate nei contenuti tramite
# segnaposto {{KEYn}} (vedi _apply_keys): il testo autoriale non contiene codici,
# e' la libreria a sostituirli con GameManager.key_label(n) (es. "1-Q9FY").
#
# La randomizzazione seminata (scegliere ~5 siti dal pool, spostare a caso la
# posizione delle chiavi, generare nomi/contenuti) e' la PARTE 2 della Milestone 3:
# qui il pool e' completo e gli slot delle chiavi sono fissi. La struttura a pool +
# segnaposto e' pero' gia' quella su cui il generatore seminato si innestera'.
# ============================================================

# Modello del segnaposto di chiave nei testi autoriali: "{{KEY1}}".."{{KEYn}}".
# _apply_keys() lo sostituisce in TUTTO l'albero (nomi, contenuti, testi, commenti).
const KEY_TOKEN := "{{KEY%d}}"

# ---------------- filesystem (albero base del run) ----------------

# Albero base del filesystem (radice "Risorse del computer"). I codici chiave sono
# segnaposto {{KEYn}}, riempiti qui da _apply_keys prima di restituire. Lo consuma
# VFS._build(), che aggiunge poi i back-reference _parent.
static func build_filesystem() -> Dictionary:
	var root := _folder("Risorse del computer", "computer", [
		_folder("Disco locale (C:)", "folder", [
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
				_html("Blog segreto.url", "blog.io"),
			]),
			_folder("Sistema", "folder", [
				_text("config.sys", "DEVICE=HIMEM.SYS\nDOS=HIGH,UMB\nFILES=30\nBUFFERS=20"),
				_text("autoexec.bat", "@ECHO OFF\nPROMPT $P$G\nPATH C:\\DOS\nSET TEMP=C:\\TEMP"),
				# Chiave 1: nascosta nel CONTENUTO di un file di testo.
				_text("seriale.txt", "Codice di attivazione del prodotto:\n  {{KEY1}}\n\nConservare in luogo sicuro. Non divulgare a terzi."),
			]),
			# Chiave 2: nascosta nel NOME stesso della cartella (visibile in Esplora risorse).
			_folder("Backup {{KEY2}}", "folder", [
				_text("note.txt", "Copia di sicurezza automatica.\nNon eliminare questa cartella."),
			]),
		]),
		_folder("Cestino", "trash", []),
	])
	_apply_keys(root)
	return root

# ---------------- siti web (pool autoriale) ----------------

# Dizionario di pagine per il browser: { "dominio": pagina, ... }. Le pagine vengono
# dal pool autoriale (_site_pool); la "start" e' GENERATA dai siti del run (un
# collegamento per sito) cosi' si adatta da sola a quali siti esistono. I segnaposto
# {{KEYn}} sono riempiti alla fine. Lo consuma BrowserApp._pages().
static func build_sites() -> Dictionary:
	var sites := _site_pool()
	var pages := {}
	for s in sites:
		pages[s["domain"]] = s["page"]
	pages["start"] = _make_start_page(sites)
	_apply_keys(pages)
	return pages

# Pool autoriale dei siti. Ogni voce: { domain, name, tagline, featured, page }.
# "featured" -> compare tra i "piu' visti" della home; gli altri tra i "recenti"
# (meno in vista: e' li' che si nasconde la chiave web). Aggiungere un sito qui lo
# rende automaticamente raggiungibile e linkato dalla home, senza toccare altro.
static func _site_pool() -> Array:
	return [
		_site("news.com", "NewsOggi", "Le ultime notizie", true, [
			{"tag": "img", "alt": "NewsOggi", "color": "8a1f1f", "w": 560, "h": 70},
			{"tag": "h1", "text": "NewsOggi"},
			# Chiave 4: nascosta nel SORGENTE HTML (commento, non reso a video).
			{"tag": "comment", "text": "build-key={{KEY4}}"},
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
		# Chiave 3: nel TESTO VISIBILE. blog.io e' "recente" (poco in vista) di proposito.
		_site("blog.io", "Il blog segreto", "il diario di qualcuno", false, [
			{"tag": "h1", "text": "Pagina nascosta"},
			{"tag": "p", "text": "Se stai leggendo questo, hai trovato il collegamento giusto nel computer."},
			{"tag": "p", "text": "La password e' nascosta in un file di testo dentro Documenti..."},
			{"tag": "p", "text": "Promemoria personale: {{KEY3}}. Gli altri lo sanno."},
			{"tag": "hr"},
			{"tag": "a", "text": "Pagina iniziale", "href": "start"},
		]),
		# --- siti extra: riempiono il pool (in parte 2 il run ne scegliera' ~5) ---
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

# Voce del pool: impacchetta i metadati (per la home) e la pagina vera e propria.
static func _site(domain: String, name: String, tagline: String, featured: bool, elements: Array) -> Dictionary:
	return {
		"domain": domain,
		"name": name,
		"tagline": tagline,
		"featured": featured,
		"page": {"title": name, "elements": elements},
	}

# Costruisce la "Pagina iniziale" a partire dai siti del run: un collegamento per
# sito (i "featured" tra i piu' visti, gli altri tra i recenti) + il link morto al
# 404 e il suggerimento sull'Ispeziona elemento.
static func _make_start_page(sites: Array) -> Dictionary:
	var els: Array = [
		{"tag": "img", "alt": "Il mio portale", "color": "1a3f8a", "w": 560, "h": 80},
		{"tag": "h1", "text": "Pagina iniziale"},
		{"tag": "h2", "text": "Collegamenti piu' visti"},
	]
	for s in sites:
		if bool(s.get("featured", false)):
			els.append(_home_link(s))
	els.append({"tag": "hr"})
	els.append({"tag": "h2", "text": "Collegamenti recenti"})
	for s in sites:
		if not bool(s.get("featured", false)):
			els.append(_home_link(s))
	els.append({"tag": "a", "text": "Sito inesistente (prova 404)", "href": "sito-finto.com"})
	els.append({"tag": "p", "text": "Suggerimento: tasto destro -> Ispeziona elemento per vedere l'HTML."})
	return {"title": "Pagina iniziale", "elements": els}

# Collegamento per la home: "Nome - sottotitolo" verso il dominio del sito.
static func _home_link(s: Dictionary) -> Dictionary:
	var name := str(s.get("name", ""))
	var tagline := str(s.get("tagline", ""))
	var text := name if tagline == "" else "%s - %s" % [name, tagline]
	return {"tag": "a", "text": text, "href": str(s.get("domain", "start"))}

# ---------------- iniezione delle chiavi ----------------

# Sostituisce i segnaposto {{KEYn}} con GameManager.key_label(n) ovunque nell'albero
# (cammina Dictionary/Array e tocca solo le stringhe). Cosi' il contenuto autoriale
# resta privo di codici e le chiavi del run finiscono nei punti giusti.
static func _apply_keys(data) -> void:
	if data is Dictionary:
		for k in data.keys():
			var v = data[k]
			if v is String:
				data[k] = _fill_keys(v)
			elif v is Dictionary or v is Array:
				_apply_keys(v)
	elif data is Array:
		for i in range(data.size()):
			var v = data[i]
			if v is String:
				data[i] = _fill_keys(v)
			elif v is Dictionary or v is Array:
				_apply_keys(v)

# Riempie i segnaposto di una singola stringa. Un segnaposto la cui chiave non
# esiste (run non ancora avviato) diventa stringa vuota, come faceva il vecchio _build.
static func _fill_keys(s: String) -> String:
	if not s.contains("{{KEY"):
		return s
	for i in range(1, GameManager.KEY_COUNT + 1):
		var token := KEY_TOKEN % i
		if s.contains(token):
			s = s.replace(token, GameManager.key_label(i))
	return s

# ---------------- helper di costruzione nodi VFS ----------------

static func _folder(name: String, icon: String, children: Array) -> Dictionary:
	return {"name": name, "type": "folder", "icon": icon, "children": children}

static func _text(name: String, content: String) -> Dictionary:
	return {"name": name, "type": "file", "icon": "text", "filetype": "text", "content": content}

static func _html(name: String, url: String) -> Dictionary:
	return {"name": name, "type": "file", "icon": "ie", "filetype": "html", "url": url}
