extends SceneTree

# Test unitario (headless) del decodificatore GIF (scripts/os/gif_decoder.gd) sulle
# GIF vere di web/img/ (generate da tools/web/media.py) e su file rovinati.
#   & $godot --headless --path $proj -s res://tests/gif_test.gd

const IMG := "res://web/img/"

var _fails: Array = []

func _initialize() -> void:
	# 1. ogni GIF della cartella si decodifica, con fotogrammi della misura giusta
	var n := 0
	for f in DirAccess.get_files_at(IMG):
		if f.get_extension().to_lower() != "gif":
			continue
		n += 1
		var g := GifDecoder.decodifica(FileAccess.get_file_as_bytes(IMG + f))
		if g.is_empty():
			_ko("decodifica_" + f, "vuota")
			continue
		for fr in g["frames"]:
			var im: Image = fr["image"]
			if im.get_width() != int(g["w"]) or im.get_height() != int(g["h"]) or float(fr["delay"]) <= 0.0:
				_ko("fotogramma_" + f, "%dx%d delay %s" % [im.get_width(), im.get_height(), fr["delay"]])
				break
	_si("ci_sono_gif", n >= 10, "%d gif" % n)

	# 2. quanti fotogrammi e che ritardo (cosi' li scrive media.py)
	var busta := _gif("busta.gif")
	_si("busta_12", (busta["frames"] as Array).size() == 12, str((busta["frames"] as Array).size()))
	_si("busta_ritardo", is_equal_approx(float(busta["frames"][0]["delay"]), 0.1), str(busta["frames"][0]["delay"]))
	var zod := _gif("zodiaco.gif")
	_si("zodiaco_24", (zod["frames"] as Array).size() == 24, str((zod["frames"] as Array).size()))
	_si("zodiaco_ritardo", is_equal_approx(float(zod["frames"][0]["delay"]), 0.12), str(zod["frames"][0]["delay"]))

	# 3. i colori: la tovaglia a quadretti (8 px per quadretto)
	var q: Image = _gif("quadretti.gif")["frames"][0]["image"]
	_colore("quadretto_bianco", q.get_pixel(0, 0), Color8(255, 255, 255))
	_colore("quadretto_rosa", q.get_pixel(8, 0), Color8(240, 170, 170))
	_colore("quadretto_rosso", q.get_pixel(8, 8), Color8(220, 90, 90))
	_colore("quadretto_ripete", q.get_pixel(17, 1), Color8(255, 255, 255))
	# il contatore: cifre verdi accese, fondo nero (immagine grande: tante parole LZW)
	var c: Image = _gif("contatore_jack.gif")["frames"][0]["image"]
	_colore("contatore_fondo", c.get_pixel(0, 0), Color8(0, 0, 0))

	# 4. trasparenza: l'angolo della busta non si dipinge
	var b0: Image = busta["frames"][0]["image"]
	_si("trasparente", b0.get_pixel(0, 0).a == 0.0, str(b0.get_pixel(0, 0)))
	_si("opaco", b0.get_pixel(20, 12).a == 1.0, str(b0.get_pixel(20, 12)))

	# 5. smaltimento 2: quello che un fotogramma lascia scoperto torna trasparente.
	# Nel fotogramma 3 la busta e' di taglio (cos ~ 0): ai lati non resta niente del
	# fotogramma 0, che era larga.
	var b3: Image = busta["frames"][3]["image"]
	_si("smaltimento", b0.get_pixel(5, 12).a == 1.0 and b3.get_pixel(5, 12).a == 0.0,
			"%s / %s" % [b0.get_pixel(5, 12), b3.get_pixel(5, 12)])

	# 6. texture: animata se ha piu' fotogrammi, semplice se ne ha uno
	var at := GifDecoder.texture_da_file(IMG + "globo.gif")
	_si("texture_animata", at is AnimatedTexture and (at as AnimatedTexture).frames == 16, str(at))
	_si("texture_fissa", GifDecoder.texture_da_file(IMG + "stemma.gif") is ImageTexture, "")
	_si("texture_mancante", GifDecoder.texture_da_file(IMG + "non_ce.gif") == null, "")

	# 7. file rovinati: niente crash, al piu' un risultato vuoto o parziale
	_si("non_gif", GifDecoder.decodifica("ciao mondo, non sono una gif".to_utf8_buffer()).is_empty(), "")
	_si("vuoto", GifDecoder.decodifica(PackedByteArray()).is_empty(), "")
	var intero := FileAccess.get_file_as_bytes(IMG + "globo.gif")
	var tronco := GifDecoder.decodifica(intero.slice(0, intero.size() / 2))
	_si("troncata", tronco.is_empty() or (tronco["frames"] as Array).size() < 16, "")

	# 8. interlacciata: righe 0,8.. poi 4.. poi 2.. poi 1..; un'immagine 1x10 con la
	# riga y colorata con l'indice y deve tornare in ordine
	var ordine := [0, 8, 4, 2, 6, 1, 3, 5, 7, 9]
	var righe := PackedByteArray()
	for y in ordine:
		righe.append(y)
	var dritte := GifDecoder._deinterlaccia(righe, 1, 10)
	var ok := true
	for y in range(10):
		if dritte[y] != y:
			ok = false
	_si("interlacciata", ok, str(dritte))

	if _fails.is_empty():
		print("RISULTATO: PASS (tutti i test superati)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	quit(0 if _fails.is_empty() else 1)

func _gif(nome: String) -> Dictionary:
	return GifDecoder.decodifica(FileAccess.get_file_as_bytes(IMG + nome))

func _si(nome: String, cond: bool, info: String) -> void:
	if cond:
		print("PASS  " + nome)
	else:
		_ko(nome, info)

func _ko(nome: String, info: String) -> void:
	print("FAIL  %s  %s" % [nome, info])
	_fails.append(nome)

func _colore(nome: String, got: Color, want: Color) -> void:
	_si(nome, got.is_equal_approx(want), "atteso %s, ottenuto %s" % [want, got])
