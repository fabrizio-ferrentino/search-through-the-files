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

static func _build() -> Dictionary:
	return _folder("Risorse del computer", "computer", [
		_folder("Disco locale (C:)", "folder", [
			_folder("Documenti", "folder", [
				_text("diario.txt", "Caro diario,\noggi ho trovato uno strano computer.\nLo schermo si accende con un ronzio...\n\nC'e' qualcosa che non torna in questa stanza."),
				_text("password.txt", "NON dire a nessuno:\n  utente: admin\n  pass:   hunter2\n\n(cancellare questo file!)"),
				_text("lista_spesa.txt", "- floppy disk\n- nastro adesivo\n- caffe'\n- una nuova tastiera"),
			]),
			_folder("Immagini", "folder", [
				_text("leggimi.txt", "Le immagini sono andate perse durante l'ultimo riavvio."),
			]),
			_folder("Internet", "folder", [
				_html("Home.url", "home"),
				_html("Blog segreto.url", "blog"),
			]),
			_folder("Sistema", "folder", [
				_text("config.sys", "DEVICE=HIMEM.SYS\nDOS=HIGH,UMB\nFILES=30\nBUFFERS=20"),
				_text("autoexec.bat", "@ECHO OFF\nPROMPT $P$G\nPATH C:\\DOS\nSET TEMP=C:\\TEMP"),
			]),
		]),
		_folder("Cestino", "trash", []),
	])
