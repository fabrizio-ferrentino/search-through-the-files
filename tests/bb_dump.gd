extends SceneTree

# Strumento di sviluppo: compila OGNI pagina di web/pages (tutte le lingue) col compilatore
# vero e scrive il BBCode in un solo file, una pagina dopo l'altra. Serve a provare che un
# ritocco che non deve cambiare l'aspetto (per esempio tools/web/snellisci.py) davvero non
# lo cambia: si fa il dump prima e dopo e si confrontano i due file.
#   & $godot --headless --path $proj -s res://tests/bb_dump.gd -- <file di uscita>

func _initialize() -> void:
	var uscita := "user://bb_dump.txt"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		uscita = args[0]
	var righe: PackedStringArray = []
	var n := 0
	for lingua in DirAccess.get_directories_at("res://web/pages"):
		var base := "res://web/pages/" + lingua
		var file: PackedStringArray = []
		for f in DirAccess.get_files_at(base):
			if f.ends_with(".html"):
				file.append(base + "/" + f)
		for sito in DirAccess.get_directories_at(base):
			for f in DirAccess.get_files_at(base + "/" + sito):
				if f.ends_with(".html"):
					file.append(base + "/" + sito + "/" + f)
		for p in file:
			var html := FileAccess.get_file_as_string(p)
			var body := HtmlBB.strip_comments(HtmlBB.body_inner(html))
			var ctx := {"link_color": "#0000ee", "page_width": 900.0, "vlink_color": "#551a8b"}
			righe.append("=== " + p)
			righe.append(HtmlBB.compile(body, ctx))
			# e i posti dove la chiave web si puo' nascondere, per tipo: un ritocco del codice
			# della pagina non deve farne sparire nessuno
			for vis in [true, false]:
				var tipi := {}
				for a in WebAnchor.ancore(html, vis):
					var t := str((a as Dictionary).get("tipo", "?"))
					tipi[t] = int(tipi.get(t, 0)) + 1
				var chiavi := tipi.keys()
				chiavi.sort()
				var r := "ANCORE " + ("visibili" if vis else "sorgente")
				for k in chiavi:
					r += " %s=%d" % [k, tipi[k]]
				righe.append(r)
			n += 1
	var fa := FileAccess.open(uscita, FileAccess.WRITE)
	fa.store_string("\n".join(righe))
	fa.close()
	print("RISULTATO: %d pagine compilate in %s" % [n, uscita])
	quit()
