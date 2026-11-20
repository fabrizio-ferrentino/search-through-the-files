class_name GifDecoder
extends RefCounted

# ============================================================
# Decodificatore GIF (87a/89a) per le pagine web: Godot non importa le GIF, e
# le GIF animate sono IL segno del web anni '90 (cantieri, buste che girano,
# fiamme, contatori). Modulo puro, statico, senza engine oltre a Image/Texture:
# i test lo provano headless (tests/gif_test.gd).
#
# Copre quello che le GIF d'epoca usano davvero: palette globale e locale,
# trasparenza, ritardo per fotogramma, interlacciamento e lo SMALTIMENTO dei
# fotogrammi (1 = lascia, 2 = cancella al fondo, 3 = torna al precedente),
# perche' quasi tutte le GIF animate ridisegnano solo il rettangolo che cambia.
# ============================================================

const RITARDO_MINIMO := 0.1     # ritardo 0 o 1 centesimo: i browser usavano ~0.1 s
const MAX_FOTOGRAMMI := 256     # limite di AnimatedTexture

# Decodifica una GIF. Restituisce {"w", "h", "frames": [{"image": Image, "delay": float}]}
# con fotogrammi GIA' composti (ognuno e' l'immagine intera da mostrare), oppure {}
# se il file non e' una GIF leggibile.
static func decodifica(dati: PackedByteArray) -> Dictionary:
	if dati.size() < 13:
		return {}
	var firma := dati.slice(0, 6).get_string_from_ascii()
	if firma != "GIF87a" and firma != "GIF89a":
		return {}
	var w := _u16(dati, 6)
	var h := _u16(dati, 8)
	if w <= 0 or h <= 0:
		return {}
	var pk := dati[10]
	var i := 13
	var pal_globale := PackedByteArray()
	if pk & 0x80:
		var n := 3 * (1 << ((pk & 7) + 1))
		pal_globale = dati.slice(i, i + n)
		i += n
	# la tela: trasparente all'inizio (i browser non dipingevano il colore di fondo)
	var tela := PackedByteArray()
	tela.resize(w * h * 4)
	tela.fill(0)
	var frames: Array = []
	# controllo grafico in sospeso (vale per l'immagine che segue)
	var ritardo := 0.0
	var smaltimento := 0
	var trasparente := -1
	while i < dati.size() and frames.size() < MAX_FOTOGRAMMI:
		var b := dati[i]
		i += 1
		if b == 0x3B:                                  # fine del file
			break
		if b == 0x21:                                  # estensione
			if i >= dati.size():
				break
			var etichetta := dati[i]
			i += 1
			if etichetta == 0xF9 and i + 5 < dati.size() and dati[i] == 4:
				var gp := dati[i + 1]
				smaltimento = (gp >> 2) & 7
				ritardo = float(_u16(dati, i + 2)) / 100.0
				trasparente = dati[i + 4] if (gp & 1) else -1
			i = _salta_blocchi(dati, i)
			continue
		if b != 0x2C:                                  # blocco sconosciuto: ci si ferma
			break
		if i + 9 > dati.size():
			break
		var fx := _u16(dati, i)
		var fy := _u16(dati, i + 2)
		var fw := _u16(dati, i + 4)
		var fh := _u16(dati, i + 6)
		var fp := dati[i + 8]
		i += 9
		var pal := pal_globale
		if fp & 0x80:
			var n2 := 3 * (1 << ((fp & 7) + 1))
			pal = dati.slice(i, i + n2)
			i += n2
		if i >= dati.size():
			break
		var min_codice := dati[i]
		i += 1
		# i sotto-blocchi dei dati LZW, cuciti in un'unica sequenza
		var lzw := PackedByteArray()
		while i < dati.size():
			var lun := dati[i]
			i += 1
			if lun == 0:
				break
			lzw.append_array(dati.slice(i, i + lun))
			i += lun
		var indici := _lzw(lzw, min_codice, fw * fh)
		if fp & 0x40:
			indici = _deinterlaccia(indici, fw, fh)
		var prima: PackedByteArray = tela.duplicate() if smaltimento == 3 else PackedByteArray()
		_dipingi(tela, w, h, indici, fx, fy, fw, fh, pal, trasparente)
		var im := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, tela)
		frames.append({"image": im, "delay": maxf(ritardo, RITARDO_MINIMO) if ritardo > 0.01 else RITARDO_MINIMO})
		# smaltimento: cosa resta sulla tela per il fotogramma dopo
		if smaltimento == 2:
			_svuota(tela, w, h, fx, fy, fw, fh)
		elif smaltimento == 3 and not prima.is_empty():
			tela = prima
		ritardo = 0.0
		smaltimento = 0
		trasparente = -1
	if frames.is_empty():
		return {}
	return {"w": w, "h": h, "frames": frames}

# La GIF come texture: AnimatedTexture se ha piu' fotogrammi (si anima da sola,
# anche dentro un RichTextLabel, senza ridisegnare la pagina), ImageTexture se ne ha
# uno. null se il file non si legge.
static func texture_da_file(path: String) -> Texture2D:
	if not FileAccess.file_exists(path):
		return null
	var g := decodifica(FileAccess.get_file_as_bytes(path))
	if g.is_empty():
		return null
	var frames: Array = g["frames"]
	if frames.size() == 1:
		return ImageTexture.create_from_image(frames[0]["image"])
	var at := AnimatedTexture.new()
	at.frames = frames.size()
	for k in range(frames.size()):
		at.set_frame_texture(k, ImageTexture.create_from_image(frames[k]["image"]))
		at.set_frame_duration(k, float(frames[k]["delay"]))
	return at

# ---------------- LZW ----------------

# Decompressione LZW a lunghezza di codice variabile (3..12 bit, LSB first).
# Il dizionario e' a catena (prefisso + ultimo byte); ogni stringa si scrive
# all'indietro direttamente nell'uscita, cosi' non si costruiscono stringhe.
static func _lzw(dati: PackedByteArray, min_codice: int, npix: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(npix)
	out.fill(0)
	if min_codice < 1 or min_codice > 11:
		return out
	var clear := 1 << min_codice
	var eoi := clear + 1
	var prefisso := PackedInt32Array()
	prefisso.resize(4096)
	var suffisso := PackedByteArray()
	suffisso.resize(4096)
	var lunghezza := PackedInt32Array()
	lunghezza.resize(4096)
	for k in range(clear):
		prefisso[k] = -1
		suffisso[k] = k
		lunghezza[k] = 1
	var taglia := min_codice + 1
	var maschera := (1 << taglia) - 1
	var prossimo := clear + 2
	var vecchio := -1
	var primo := 0              # primo byte dell'ultima stringa scritta
	var pos := 0
	var acc := 0
	var bit := 0
	var i := 0
	var n := dati.size()
	while pos < npix:
		while bit < taglia:
			if i >= n:
				return out
			acc |= dati[i] << bit
			i += 1
			bit += 8
		var codice := acc & maschera
		acc >>= taglia
		bit -= taglia
		if codice == clear:
			taglia = min_codice + 1
			maschera = (1 << taglia) - 1
			prossimo = clear + 2
			vecchio = -1
			continue
		if codice == eoi:
			break
		if vecchio == -1:
			if codice >= clear:
				break                                 # file rovinato
			out[pos] = suffisso[codice]
			pos += 1
			primo = suffisso[codice]
			vecchio = codice
			continue
		if codice < prossimo:
			# codice noto: si scrive la sua stringa
			var lun := lunghezza[codice]
			var c := codice
			var p := pos + lun - 1
			while c != -1:
				if p < npix:
					out[p] = suffisso[c]
				primo = suffisso[c]
				p -= 1
				c = prefisso[c]
			pos += lun
		elif codice == prossimo:
			# il caso KwKwK: la stringa del vecchio piu' il suo primo byte
			var lun2 := lunghezza[vecchio]
			var c2 := vecchio
			var p2 := pos + lun2 - 1
			while c2 != -1:
				if p2 < npix:
					out[p2] = suffisso[c2]
				p2 -= 1
				c2 = prefisso[c2]
			if pos + lun2 < npix:
				out[pos + lun2] = primo
			pos += lun2 + 1
		else:
			break                                     # codice impossibile: file rovinato
		if prossimo < 4096:
			prefisso[prossimo] = vecchio
			suffisso[prossimo] = primo
			lunghezza[prossimo] = lunghezza[vecchio] + 1
			prossimo += 1
			if prossimo == (1 << taglia) and taglia < 12:
				taglia += 1
				maschera = (1 << taglia) - 1
		vecchio = codice
	return out

# ---------------- composizione ----------------

static func _dipingi(tela: PackedByteArray, w: int, h: int, indici: PackedByteArray,
		fx: int, fy: int, fw: int, fh: int, pal: PackedByteArray, trasp: int) -> void:
	var ncol := pal.size() / 3
	for y in range(fh):
		var ty := fy + y
		if ty >= h:
			break
		var riga := y * fw
		for x in range(fw):
			var tx := fx + x
			if tx >= w:
				break
			var idx := indici[riga + x]
			if idx == trasp or idx >= ncol:
				continue
			var o := (ty * w + tx) * 4
			tela[o] = pal[idx * 3]
			tela[o + 1] = pal[idx * 3 + 1]
			tela[o + 2] = pal[idx * 3 + 2]
			tela[o + 3] = 255

static func _svuota(tela: PackedByteArray, w: int, h: int, fx: int, fy: int, fw: int, fh: int) -> void:
	for y in range(fy, mini(fy + fh, h)):
		for x in range(fx, mini(fx + fw, w)):
			var o := (y * w + x) * 4
			tela[o] = 0
			tela[o + 1] = 0
			tela[o + 2] = 0
			tela[o + 3] = 0

# Righe interlacciate: arrivano 0,8,16.. poi 4,12.. poi 2,6.. poi 1,3..
static func _deinterlaccia(indici: PackedByteArray, fw: int, fh: int) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(indici.size())
	var sorgente := 0
	for passo in [[0, 8], [4, 8], [2, 4], [1, 2]]:
		var y: int = passo[0]
		while y < fh:
			for x in range(fw):
				out[y * fw + x] = indici[sorgente * fw + x]
			sorgente += 1
			y += int(passo[1])
	return out

# ---------------- byte ----------------

static func _u16(d: PackedByteArray, i: int) -> int:
	if i + 1 >= d.size():
		return 0
	return d[i] | (d[i + 1] << 8)

static func _salta_blocchi(d: PackedByteArray, i: int) -> int:
	while i < d.size():
		var lun := d[i]
		i += 1
		if lun == 0:
			break
		i += lun
	return i
