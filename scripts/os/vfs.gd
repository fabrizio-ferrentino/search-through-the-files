class_name VFS
extends RefCounted

# Filesystem virtuale: un albero di Dictionary.
# Ogni nodo: { name, icon, type: "folder"|"file"|"app", ... }
#   folder -> "children": Array
#   file   -> "filetype": "text"|"html", "content": String (testo) oppure "url": String (html)
#   app    -> "app": "browser"|"explorer", "arg": ...
# I figli ricevono in runtime la chiave "_parent" per la navigazione "su".

static var _root: Dictionary = {}

static func get_root() -> Dictionary:
	if _root.is_empty():
		_root = _build()
		_link_parents(_root, null)
	return _root

# (Ri)costruisce il filesystem per un nuovo run: scarta lo stato precedente
# (file modificati, elementi nel Cestino) e riparte dall'albero base. Lo chiama
# GameManager.start_new_run() cosi' "perdere -> run nuovo" parte sempre pulito.
# Il seed e' previsto per la randomizzazione (M3); per ora l'albero e' fisso.
static func build_run(_seed: int = 0) -> void:
	_root = _build()
	_link_parents(_root, null)

# Percorso (array di nomi dalla radice) di un nodo, per salvare/ripristinare la sessione.
static func path_of(node) -> Array:
	var parts: Array = []
	var cur = node
	while cur != null and cur is Dictionary:
		parts.push_front(cur.get("name", ""))
		cur = cur.get("_parent", null)
	return parts

# Risolve un percorso (array di nomi) in un nodo cartella del VFS.
static func resolve_path(parts: Array) -> Dictionary:
	var cur := get_root()
	for i in range(1, parts.size()):
		var found := {}
		for c in cur.get("children", []):
			if c.get("name", "") == parts[i]:
				found = c
				break
		if found.is_empty():
			return cur
		cur = found
	return cur

# Risolve un percorso in un nodo qualsiasi (file o cartella); null se non esiste.
static func resolve_node(parts: Array):
	var cur = get_root()
	for i in range(1, parts.size()):
		var found = null
		for c in cur.get("children", []):
			if c.get("name", "") == parts[i]:
				found = c
				break
		if found == null:
			return null
		cur = found
	return cur

static func _link_parents(node: Dictionary, parent) -> void:
	node["_parent"] = parent
	for child in node.get("children", []):
		_link_parents(child, node)

static func _folder(name: String, icon: String, children: Array) -> Dictionary:
	return {"name": name, "type": "folder", "icon": icon, "children": children}

static func _text(name: String, content: String) -> Dictionary:
	return {"name": name, "type": "file", "icon": "text", "filetype": "text", "content": content}

static func _html(name: String, url: String) -> Dictionary:
	return {"name": name, "type": "file", "icon": "ie", "filetype": "html", "url": url}

# Cartella che rappresenta il Desktop (i file creati sulla scrivania).
static func get_desktop() -> Dictionary:
	var d = resolve_node(["Risorse del computer", "Disco locale (C:)", "Desktop"])
	return d if d is Dictionary else get_root()

# Cartella "Cestino" (figlia diretta della radice).
static func get_trash() -> Dictionary:
	var d = resolve_node(["Risorse del computer", "Cestino"])
	return d if d is Dictionary else get_root()

# True se il nodo dato e' proprio la cartella Cestino.
static func is_trash(node) -> bool:
	return node is Dictionary and is_same(node, get_trash())

# Sposta un file/cartella nel Cestino: lo stacca dal genitore e lo accoda al
# Cestino, ricordando l'origine (per un eventuale ripristino) e rinominandolo se
# nel Cestino esiste gia' un omonimo.
static func move_to_trash(node) -> void:
	if not node is Dictionary:
		return
	var trash := get_trash()
	var parent = node.get("_parent", null)
	# stacca dal genitore
	if parent is Dictionary:
		var siblings: Array = parent.get("children", [])
		for i in range(siblings.size()):
			if is_same(siblings[i], node):
				siblings.remove_at(i)
				break
	if not trash.has("children"):
		trash["children"] = []
	if not node.has("_orig_parent"):
		node["_orig_parent"] = parent
	node["name"] = _unique_name(trash, node.get("name", "Senza nome"))
	node["_parent"] = trash
	trash["children"].append(node)

# Nome non in conflitto con i figli di "folder" (aggiunge " (n)" prima dell'estensione).
static func _unique_name(folder: Dictionary, wanted: String) -> String:
	var taken := {}
	for c in folder.get("children", []):
		taken[c.get("name", "")] = true
	if not taken.has(wanted):
		return wanted
	var dot := wanted.rfind(".")
	var base := wanted if dot <= 0 else wanted.substr(0, dot)
	var ext := "" if dot <= 0 else wanted.substr(dot)
	var n := 2
	var candidate := "%s (%d)%s" % [base, n, ext]
	while taken.has(candidate):
		n += 1
		candidate = "%s (%d)%s" % [base, n, ext]
	return candidate

static func _build() -> Dictionary:
	var k1 := GameManager.key_label(1)   # chiave nascosta dentro un file di testo (con prefisso "1-")
	var k2 := GameManager.key_label(2)   # chiave nascosta nel NOME di una cartella (con prefisso "2-")
	return _folder("Risorse del computer", "computer", [
		_folder("Disco locale (C:)", "folder", [
			# La cartella protetta vive sul Desktop (compare come icona sulla scrivania).
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
				_text("seriale.txt", "Codice di attivazione del prodotto:\n  " + k1 + "\n\nConservare in luogo sicuro. Non divulgare a terzi."),
			]),
			# La chiave 2 e' contenuta nel NOME stesso di questa cartella (visibile in Esplora risorse).
			_folder("Backup " + k2, "folder", [
				_text("note.txt", "Copia di sicurezza automatica.\nNon eliminare questa cartella."),
			]),
		]),
		_folder("Cestino", "trash", []),
	])
