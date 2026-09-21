extends Node

# Test della SECONDA VIA della chiave nella foto: il codice nei BYTE del file invece che nei
# pixel (OSContent._make_photos -> code_commento, OSContent.byte_dump).
#
# Perche' esiste questa via. Nascondere il codice nei pixel ha un limite MISURATO: perche' la
# scritta sia insieme invisibile a riposo e rivelabile col cursore "Nitidezza" serve che la
# struttura che la maschera sia ~6.8 volte il rumore alla scala dei tratti, e sulle foto vere
# il meglio ottenibile e' 0.4-0.9 (tests/photo_banda_scan). Su molte foto quindi o si vede
# subito o non si legge mai. Il codice nei byte non ha quel limite: funziona su qualsiasi
# foto, e cercarlo aprendo l'immagine col Blocco note e' il gioco che il titolo promette.
#
# Qui si pretende che:
#   1 le due modalita' escano entrambe sui semi (la randomicita' e' il punto);
#   2 in modalita' FILE il codice sia nel dump dei byte e NON nei pixel (nessuna scritta);
#   3 in modalita' PIXEL il codice NON sia nel dump (o sarebbe una scorciatoia gratis);
#   4 il codice non compaia nelle foto ESCA, in nessuna delle due modalita';
#   5 il dump sia stabile (riaprire il file da' lo stesso) e abbia la forma di un JPEG;
#   6 il pannello F12 dica quale delle due vie e' stata usata;
#   7 la POSIZIONE del commento nel dump CAMBI da un run all'altro. Prima era scritta a
#     mano e usciva sempre alla riga 7 su 31 -- il 20% dall'alto, su qualunque seme e
#     qualunque foto (proprietario, 20/09/2026: "appare sempre in alto"): chi aveva
#     trovato una chiave sapeva dove guardare per tutte le altre. Un commento JPEG non
#     puo' stare in mezzo ai dati compressi, percio' le posizioni possibili sono le tre
#     dell'intestazione piu' la CODA dopo la fine del file, ed e' li' che deve finire
#     qualche volta.
#
# Va eseguito come SCENA (serve l'autoload GameManager). Headless va bene: qui non si
# guardano pixel.
#   & $godot --headless --path $proj res://tests/photo_file_key_test.tscn
# ============================================================

const SEMI := 40

var _fails: Array = []
var _quanti_file := 0
var _quanti_pixel := 0
var _posizioni: Array = []      # dove stava il codice nel dump (0.0 = in cima, 1.0 = in fondo)

func _ready() -> void:
	get_tree().create_timer(300.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	for i in range(SEMI):
		_prova(1000 + i * 13)
	print("\n   modalita' su %d semi: nel file %d, nei pixel %d" % [SEMI, _quanti_file, _quanti_pixel])
	_check("ENTRAMBE_LE_VIE", _quanti_file > 0 and _quanti_pixel > 0,
			"una delle due modalita' non esce mai (file %d, pixel %d)" % [_quanti_file, _quanti_pixel])
	# meta' e meta' dichiarata: si accetta un ampio margine, ma non 95/5
	var quota := float(_quanti_file) / float(maxi(1, SEMI))
	_check("QUOTA_RAGIONEVOLE", quota >= 0.25 and quota <= 0.75,
			"la modalita' 'nel file' esce nel %d%% dei casi" % int(quota * 100.0))

	_prova_posizioni()

	if _fails.is_empty():
		print("RISULTATO: PASS (le due vie funzionano e restano distinte)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# In quale punto del dump sta il codice, da 0.0 (prima riga) a 1.0 (ultima).
func _dove(dump: String, etichetta: String) -> float:
	var righe := dump.split("
")
	for i in range(righe.size()):
		if str(righe[i]).find(etichetta) >= 0:
			return float(i) / float(maxi(1, righe.size() - 1))
	return -1.0

# La posizione deve girare: e' tutto il punto della correzione del 20/09/2026.
func _prova_posizioni() -> void:
	if _posizioni.size() < 5:
		_check("POSIZIONI_ABBASTANZA", false,
				"solo %d run nella via 'nel file': non si puo' dire niente" % _posizioni.size())
		return
	var quarti := {}
	var minimo := 2.0
	var massimo := -1.0
	for p in _posizioni:
		var v: float = float(p)
		quarti[mini(3, int(v * 4.0))] = true
		minimo = minf(minimo, v)
		massimo = maxf(massimo, v)
	var elenco := PackedStringArray()
	for p in _posizioni:
		elenco.append("%d%%" % int(round(float(p) * 100.0)))
	print("   posizione del codice nel dump: %s" % ", ".join(elenco))
	_check("POSIZIONE_VARIA", quarti.size() >= 3,
			"il codice cade sempre nella stessa parte del file (%d quarti su 4)" % quarti.size())
	_check("NON_SOLO_IN_ALTO", massimo > 0.6,
			"il codice non arriva mai oltre il %d%% del file" % int(round(massimo * 100.0)))
	_check("ANCHE_IN_ALTO", minimo < 0.4,
			"il codice non e' mai nell'intestazione (minimo %d%%)" % int(round(minimo * 100.0)))

func _prova(seme: int) -> void:
	GameManager.start_new_run(seme)
	var etichetta: String = GameManager.key_label(OSContent.KEY_IMAGE)
	if etichetta == "":
		_ko(seme, "nessuna chiave immagine")
		return
	var foto := _foto_del_run()
	if foto.is_empty():
		_ko(seme, "nessuna foto nel run")
		return

	var portatrice := {}
	for f in foto:
		if str(f.get("code", "")) != "" or str(f.get("code_commento", "")) != "":
			if not portatrice.is_empty():
				_ko(seme, "due foto portano la chiave")
				return
			portatrice = f
	if portatrice.is_empty():
		_ko(seme, "nessuna foto porta la chiave")
		return

	var nel_file: bool = str(portatrice.get("code_commento", "")) != ""
	var dump: String = OSContent.byte_dump(portatrice)

	if nel_file:
		_quanti_file += 1
		if dump.find(etichetta) < 0:
			_ko(seme, "modalita' file ma il codice non e' nei byte")
		else:
			_posizioni.append(_dove(dump, etichetta))
		if str(portatrice.get("code", "")) != "":
			_ko(seme, "modalita' file ma c'e' anche la scritta nei pixel")
		if str(portatrice.get("code_commento", "")).find(etichetta) < 0:
			_ko(seme, "il commento non contiene il codice")
		# il commento non deve dire "codice"/"chiave": chi legge lo riconosce da solo
		var basso := str(portatrice.get("code_commento", "")).to_lower()
		# in ENTRAMBE le lingue: il commento non deve autodenunciarsi
		if basso.find("codice") >= 0 or basso.find("chiave") >= 0 or basso.find("code") >= 0 or basso.find("key") >= 0:
			_ko(seme, "il commento si autodenuncia: '%s'" % str(portatrice.get("code_commento", "")))
	else:
		_quanti_pixel += 1
		if str(portatrice.get("code", "")) != etichetta:
			_ko(seme, "modalita' pixel ma la scritta non c'e'")
		if dump.find(etichetta) >= 0:
			_ko(seme, "modalita' pixel ma il codice si legge anche nei byte")

	# le esche restano pulite in entrambe le modalita'
	for f in foto:
		if f == portatrice:
			continue
		if OSContent.byte_dump(f).find(etichetta) >= 0 or str(f.get("code", "")) != "":
			_ko(seme, "il codice compare anche su un'esca (%s)" % str(f.get("name", "")))

	# stabile: riaprire il file deve dare lo stesso dump
	if OSContent.byte_dump(portatrice) != dump:
		_ko(seme, "il dump cambia da un'apertura all'altra")
	# ...e deve avere la forma di un JPEG: inizia con FFD8 e contiene la fine FFD9. Non si
	# pretende piu' che FINISCA con FFD9: dopo la fine puo' esserci la coda che i programmi
	# dell'epoca lasciavano attaccata (ed e' una delle posizioni del commento), ma dev'essere
	# poca roba, non una seconda immagine.
	var eoi := dump.rfind(char(255) + char(217))
	if dump.substr(0, 2) != char(255) + char(216) or eoi < 0:
		_ko(seme, "il dump non ha l'intestazione o la fine di un JPEG")
	elif dump.length() - eoi > 600:
		_ko(seme, "dopo la fine del JPEG ci sono %d caratteri di coda" % (dump.length() - eoi - 2))
	if dump.find("JFIF") < 0:
		_ko(seme, "manca l'intestazione JFIF")

	# il pannello F12 deve dire quale via e' stata usata
	var hint := str(GameManager.key_hints.get(OSContent.KEY_IMAGE, ""))
	var atteso := "NEL FILE" if nel_file else "nei pixel"
	if hint.find(atteso) < 0:
		_ko(seme, "il suggerimento F12 non dice la via ('%s', atteso '%s')" % [hint, atteso])

func _foto_del_run() -> Array:
	# Il nome della cartella e' TRADOTTO (locale/ui.csv): cercarlo scritto in italiano
	# funzionava solo finche' il gioco era in italiano. La chiave invece non cambia.
	var cart := _trova(VFS.get_root(), OSContent._t("VFS_PICTURES"))
	var out: Array = []
	for c in cart.get("children", []):
		if c is Dictionary and str(c.get("filetype", "")) == "image":
			out.append(c)
	return out

func _trova(nodo: Dictionary, nome: String) -> Dictionary:
	if str(nodo.get("name", "")) == nome:
		return nodo
	for c in nodo.get("children", []):
		if c is Dictionary:
			var r := _trova(c, nome)
			if not r.is_empty():
				return r
	return {}

func _ko(seme: int, perche: String) -> void:
	var nome := "seme_%d" % seme
	print("FAIL  %s -- %s" % [nome, perche])
	if not _fails.has(nome):
		_fails.append(nome)

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		_fails.append(nome)
