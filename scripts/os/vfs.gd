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

static func _build() -> Dictionary:
	return _folder("Risorse del computer", "computer", [
		_folder("Disco locale (C:)", "folder", [
			_folder("Desktop", "folder", []),
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
			]),
		]),
		_folder("Cestino", "trash", []),
	])
