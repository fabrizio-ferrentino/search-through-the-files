extends Node

# Test della CARTELLA SEGRETA: il dialogo con cui si VINCE la partita, e il suo guasto.
#
# Prima non c'era nessun test qui sopra, cioe' nessuno controllava la condizione di
# vittoria. E il 17/10/2026 il glitch del dialogo e' stato rifatto per essere "piu' reale
# e piu' spaventoso" (SecretGlitch + secret_glitch.gdshader), che vuol dire mettere mano
# a raffiche, scosse, titolo corrotto e cali di luce proprio sopra i campi dove si
# scrivono i codici. Si pretende che:
#   1 il dialogo abbia un campo per chiave, il guasto ci sia e NON sia lo shader
#     dell'avviso del regista (glitch.gdshader): quello a tutto schermo vuol dire "c'e'
#     qualcuno nel corridoio", e la cartella non deve avere il suo sosia;
#   2 il guasto resti ATTORNO AL DIALOGO: il suo rettangolo sta dentro dialogo+margine e
#     non si avvicina nemmeno a tutto schermo -- e nei PIXEL, durante una scia, fuori da
#     quel rettangolo non cambia niente mentre nel margine si', le copie ci sono;
#   3 a raffica finita torni TUTTO com'era: titolo, parametri, posizione del pannello
#     (la scossa lo sposta), velo dietro, pixel. Un guasto che lascia residui diventa un
#     dialogo rotto per davvero;
#   4 scrivere funzioni (eventi di tastiera veri) e il guasto non tocchi MAI il testo
#     dei campi -- perdere un codice digitato per un effetto sarebbe una punizione;
#   5 il RIFIUTO (codici sbagliati) dica l'errore TRADOTTO (prima era una frase italiana
#     scritta nel codice, regola 8), si veda (il dialogo diventa rosso: nei pixel il
#     rosso domina) e lasci i campi come sono, cosi' si corregge solo la riga sbagliata;
#   6 la frase subliminale sia tradotta e sparisca da sola in un attimo;
#   7 nessuna raffica superi MAX_RAFFICA: fra una e l'altra il dialogo si deve leggere;
#   8 piu' si resta, piu' spesso si rompe (escalation);
#   9 i codici giusti facciano VINCERE, e il guasto muoia col dialogo (anche con Annulla);
#  10 le frasi nuove esistano in tutte e due le lingue.
#
# Va eseguito come SCENA e A FINESTRA: i controlli 2, 3 e 5 leggono i pixel.
#   & $godot --path $proj res://tests/cartella_segreta_test.tscn
# ============================================================

const OS_SIZE := Vector2i(1440, 1080)

var _vp: SubViewport
var _os = null                 # OSDesktop
var _g: SecretGlitch = null
var _panel: Panel = null
var _campi: Array = []
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(90.0).timeout.connect(func(): _timeout())
	await get_tree().process_frame
	GameManager.start_new_run(4321)
	GameManager.pc_on = true
	GameManager.logged_in = true

	_vp = SubViewport.new()
	_vp.size = OS_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS   # servono i pixel veri
	_vp.disable_3d = true
	add_child(_vp)
	_os = load("res://scripts/os/desktop.gd").new()
	_os.position = Vector2.ZERO
	_os.size = Vector2(OS_SIZE)
	_vp.add_child(_os)
	_vp.notify_mouse_entered()
	for i in range(4):
		await get_tree().process_frame

	if not await _apri():
		print("RISULTATO: FAIL -> il dialogo non si apre")
		get_tree().quit(1)
		return

	_prova_struttura()
	await _prova_scia_confinata()
	await _prova_scrittura()
	await _prova_rifiuto()
	await _prova_subliminale()
	_prova_durate()
	_prova_escalation()
	await _prova_vittoria()
	await _prova_annulla()
	_prova_lingue()

	if _fails.is_empty():
		print("RISULTATO: PASS (la cartella si apre, si rompe, fa paura e si lascia vincere)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

func _timeout() -> void:
	print("RISULTATO: FAIL -> timeout")
	get_tree().quit(1)

# Apre il dialogo, ferma le raffiche spontanee (servono controlli deterministici) e
# aspetta che finisca quella d'arrivo.
func _apri() -> bool:
	_os.open_secret_folder({})
	await get_tree().process_frame
	_g = _os._glitch_cartella
	_panel = null
	for c in (_os._modal_layer as Control).get_children():
		if c is Panel:
			_panel = c
	if _g == null or _panel == null:
		return false
	_g._prossima = 1.0e9
	_campi = _panel.find_children("*", "LineEdit", true, false)
	await _fine_raffica()
	return true

func _fine_raffica() -> void:
	for i in range(120):
		if not _g.in_raffica() and _g._subliminale <= 0.0 and _g._scossa <= 0.0:
			break
		await get_tree().process_frame
	await get_tree().process_frame

# ---------- 1 ----------

func _prova_struttura() -> void:
	_check("UN_CAMPO_PER_CHIAVE", _campi.size() == GameManager.keys.size(),
			"%d campi per %d chiavi" % [_campi.size(), GameManager.keys.size()])
	_check("NON_E_L_AVVISO", _g._mat.shader.resource_path != "res://scripts/os/glitch.gdshader",
			"il guasto usa lo shader dell'avviso del regista: sarebbe il suo sosia")
	_check("NON_PRENDE_IL_MOUSE", _g._fx.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"l'effetto prende il mouse: i campi e i pulsanti sotto non si cliccherebbero")
	var r := _g.rettangolo()
	var lecito := Rect2(_panel.position, _panel.size).grow(SecretGlitch.MARGINE + 1.0)
	_check("ATTORNO_AL_DIALOGO", lecito.encloses(r),
			"il rettangolo del guasto %s esce da dialogo+margine %s" % [str(r), str(lecito)])
	var quota := r.get_area() / float(OS_SIZE.x * OS_SIZE.y)
	_check("NON_A_TUTTO_SCHERMO", quota < 0.5,
			"il guasto copre il %d%% dello schermo: si confonderebbe con l'avviso" % int(quota * 100.0))
	_check("RIPOSO_TITOLO", _g._titolo.text == tr("SECRET_TITLE"),
			"a riposo il titolo dice '%s'" % _g._titolo.text)

# ---------- 2 e 3 ----------

func _prova_scia_confinata() -> void:
	var pos0 := _panel.position
	var riposo := await _foto()
	_os.glitch_segreto(1.0, SecretGlitch.SCIA)
	await get_tree().process_frame
	var scia := await _foto()
	# ritagliato sull'immagine: se un difetto allargasse il guasto oltre lo schermo, i
	# cicli qui sotto chiederebbero pixel inesistenti -- un errore per pixel, centinaia
	# di migliaia di righe, e il test si inchioda invece di fallire (e' successo, col
	# sabotaggio "guasto a tutto schermo"). A coglierlo ci pensano i controlli del punto 1.
	var fx := Rect2i(_g.rettangolo()).intersection(Rect2i(Vector2i.ZERO, OS_SIZE))
	var pan := Rect2i(Rect2(_panel.position, _panel.size))
	var fuori := 0
	var anello := 0
	var anello_tot := 0
	for y in range(0, OS_SIZE.y, 2):
		for x in range(0, OS_SIZE.x, 2):
			var diversi := not riposo.get_pixel(x, y).is_equal_approx(scia.get_pixel(x, y))
			var p := Vector2i(x, y)
			if not fx.has_point(p):
				if diversi:
					fuori += 1
			elif not pan.has_point(p):
				anello_tot += 1
				if diversi:
					anello += 1
	print("   scia: %d pixel cambiati fuori dal guasto, %d su %d nel margine"
			% [fuori, anello, anello_tot])
	# l'orologio della barra puo' scattare di un minuto fra le due foto: qualche
	# centinaio di pixel e' tollerato, uno strappo a tutto schermo no
	_check("SCIA_NON_ESCE", fuori < 400,
			"%d pixel cambiati FUORI dal rettangolo del guasto" % fuori)
	_check("SCIA_SI_VEDE", anello > anello_tot / 50,
			"nel margine attorno al dialogo cambiano solo %d pixel su %d: le copie non ci sono"
			% [anello, anello_tot])

	await _fine_raffica()
	_check("DOPO_TITOLO", _g._titolo.text == tr("SECRET_TITLE"),
			"a raffica finita il titolo dice '%s'" % _g._titolo.text)
	var spenti := true
	for p in ["strappo", "blocchi", "scia", "palette"]:
		if float(_g._mat.get_shader_parameter(p)) != 0.0:
			spenti = false
	_check("DOPO_PARAMETRI_A_ZERO", spenti, "a raffica finita lo shader e' ancora acceso")
	_check("DOPO_PANNELLO_FERMO", _panel.position == pos0,
			"il pannello e' rimasto spostato: %s invece di %s" % [str(_panel.position), str(pos0)])
	var dopo := await _foto()
	var residui := 0
	var tot := 0
	for y in range(fx.position.y, fx.end.y, 2):
		for x in range(fx.position.x, fx.end.x, 2):
			tot += 1
			if not riposo.get_pixel(x, y).is_equal_approx(dopo.get_pixel(x, y)):
				residui += 1
	# tollerati: le righe del "fondo" che saltano di rado e il cursore che lampeggia
	print("   dopo la raffica: %d pixel diversi dal riposo su %d" % [residui, tot])
	_check("DOPO_PIXEL_PULITI", residui < tot / 30,
			"a raffica finita %d pixel su %d sono ancora diversi: il guasto lascia residui"
			% [residui, tot])

# ---------- 4 ----------

func _prova_scrittura() -> void:
	(_campi[0] as LineEdit).grab_focus()
	await get_tree().process_frame
	var prima := _g.raffiche
	for lettera in ["a", "b", "c", "d"]:
		var e := InputEventKey.new()
		e.keycode = OS.find_keycode_from_string(lettera.to_upper())
		e.unicode = lettera.unicode_at(0)
		e.pressed = true
		_vp.push_input(e, true)
		await get_tree().process_frame
		var su := e.duplicate() as InputEventKey
		su.pressed = false
		_vp.push_input(su, true)
		await get_tree().process_frame
	_check("SCRIVERE_FUNZIONA", (_campi[0] as LineEdit).text == "ABCD",
			"scrivendo 'abcd' il campo dice '%s'" % (_campi[0] as LineEdit).text)
	print("   raffiche durante la scrittura: %d" % (_g.raffiche - prima))
	await _fine_raffica()
	_check("TESTO_INTATTO", (_campi[0] as LineEdit).text == "ABCD",
			"dopo i sobbalzi il campo dice '%s'" % (_campi[0] as LineEdit).text)

# ---------- 5 ----------

func _prova_rifiuto() -> void:
	var pos0 := _panel.position
	var scritti: Array = []
	for i in range(_campi.size()):
		var le := _campi[i] as LineEdit
		le.text = "ZZZ" + str(i)
		scritti.append(le.text)
	var prima := _g.raffiche
	_sblocca().pressed.emit()
	await get_tree().process_frame
	var err := ""
	for l in _panel.find_children("*", "Label", true, false):
		if (l as Label).text == tr("SECRET_WRONG"):
			err = (l as Label).text
	_check("ERRORE_TRADOTTO", err != "" and err != "SECRET_WRONG",
			"il messaggio d'errore non e' quello tradotto di SECRET_WRONG")
	_check("RIFIUTO_PARTE", _g.raffiche > prima and float(_g._mat.get_shader_parameter("palette")) == 1.0,
			"ai codici sbagliati il dialogo non reagisce")
	var img := await _foto()
	var r := 0.0
	var g := 0.0
	var pan := Rect2i(Rect2(_panel.position, _panel.size)).grow(-8)
	for y in range(pan.position.y, pan.end.y, 3):
		for x in range(pan.position.x, pan.end.x, 3):
			var c := img.get_pixel(x, y)
			r += c.r
			g += c.g
	print("   rifiuto: rosso medio %.3f, verde medio %.3f" % [r, g])
	_check("RIFIUTO_ROSSO", r > g * 3.0, "durante il rifiuto il dialogo non e' rosso")
	var intatti := true
	for i in range(_campi.size()):
		if (_campi[i] as LineEdit).text != scritti[i]:
			intatti = false
	_check("RIFIUTO_CAMPI_INTATTI", intatti, "il rifiuto ha cambiato i codici scritti")
	await _fine_raffica()
	# le tessere le accende il RIFIUTO, non la scia: e' qui che si vede se a fine
	# raffica restano accese (il sabotaggio che lo provava passava, finche' questo
	# controllo stava solo dopo la scia)
	var spenti := true
	for p in ["strappo", "blocchi", "scia", "palette"]:
		if float(_g._mat.get_shader_parameter(p)) != 0.0:
			spenti = false
	_check("RIFIUTO_POI_SPENTO", spenti, "a rifiuto finito lo shader e' ancora acceso")
	_check("RIFIUTO_POI_PULITO", _panel.position == pos0
			and _g._titolo.text == tr("SECRET_TITLE")
			and is_equal_approx(_g._fondo_scuro.color.a, _g._alfa_fondo),
			"dopo il rifiuto: pannello %s (era %s), titolo '%s', velo %.2f"
			% [str(_panel.position), str(pos0), _g._titolo.text, _g._fondo_scuro.color.a])
	var ancora := true
	for i in range(_campi.size()):
		if (_campi[i] as LineEdit).text != scritti[i]:
			ancora = false
	_check("RIFIUTO_CAMPI_ANCORA_INTATTI", ancora, "a rifiuto finito i codici sono cambiati")

# ---------- 6 ----------

func _prova_subliminale() -> void:
	_g._mostra_subliminale()
	var frasi := [tr("SECRET_SUB_1"), tr("SECRET_SUB_2"), tr("SECRET_SUB_3")]
	_check("FRASE_TRADOTTA", frasi.has(_g._titolo.text) and not _g._titolo.text.begins_with("SECRET_"),
			"nel titolo c'e' '%s'" % _g._titolo.text)
	await get_tree().create_timer(0.2).timeout
	_check("FRASE_SPARISCE", _g._titolo.text == tr("SECRET_TITLE"),
			"dopo 0,2 s il titolo dice ancora '%s'" % _g._titolo.text)

# ---------- 7 e 8 ----------

func _prova_durate() -> void:
	var peggiore := 0.0
	for tipo in [SecretGlitch.STRAPPO, SecretGlitch.BLOCCHI, SecretGlitch.SCIA, SecretGlitch.PALETTE]:
		for i in range(20):
			_g._in_raffica = 0.0
			_g.raffica(1.0, tipo)
			peggiore = maxf(peggiore, _g._in_raffica)
	_g._in_raffica = 0.0
	_g.rifiuto()
	peggiore = maxf(peggiore, _g._in_raffica)
	_g._in_raffica = 0.0
	_g._spegni()
	_g._scossa = 0.0
	_check("RAFFICHE_BREVI", peggiore <= SecretGlitch.MAX_RAFFICA + 0.0001,
			"una raffica dura %.2f s (massimo %.2f)" % [peggiore, SecretGlitch.MAX_RAFFICA])

func _prova_escalation() -> void:
	var media := func(t: float) -> float:
		_g._aperto_da = t
		var s := 0.0
		for i in range(300):
			s += _g._intervallo()
		return s / 300.0
	var subito: float = media.call(0.0)
	var dopo: float = media.call(60.0)
	print("   intervallo medio fra raffiche: %.2f s all'apertura, %.2f s dopo un minuto" % [subito, dopo])
	_check("SI_FA_PIU_FREQUENTE", dopo < subito * 0.5,
			"dopo un minuto le raffiche non sono piu' frequenti (%.2f contro %.2f)" % [dopo, subito])
	_g._aperto_da = 0.0

# ---------- 9 ----------

func _prova_vittoria() -> void:
	var codici := []
	codici.resize(GameManager.keys.size())
	for k in GameManager.keys:
		codici[int(k["index"]) - 1] = str(k["code"])
	for i in range(_campi.size()):
		(_campi[i] as LineEdit).text = codici[i]
	var vinto := [false]
	_os.game_won.connect(func(): vinto[0] = true)
	var g := _g
	_sblocca().pressed.emit()
	for i in range(3):
		await get_tree().process_frame
	_check("SI_VINCE", vinto[0], "con i codici giusti game_won non parte")
	_check("GUASTO_MUORE_COL_DIALOGO", not is_instance_valid(g),
			"chiuso il dialogo il guasto e' ancora vivo")
	_os.glitch_segreto(1.0)       # a dialogo chiuso non deve fare (ne' rompere) niente
	await get_tree().process_frame

func _prova_annulla() -> void:
	if not await _apri():
		_check("RIAPRE", false, "il dialogo non si riapre")
		return
	var g := _g
	for b in _panel.find_children("*", "Button", true, false):
		if (b as Button).text == tr("UI_CANCEL"):
			(b as Button).pressed.emit()
	for i in range(3):
		await get_tree().process_frame
	_check("ANNULLA_CHIUDE_TUTTO", not is_instance_valid(g) and not is_instance_valid(_panel),
			"con Annulla il dialogo o il guasto restano vivi")

# ---------- 10 ----------

func _prova_lingue() -> void:
	var prima: String = GameManager.lingua
	var mancanti := PackedStringArray()
	for lingua in GameManager.LINGUE:
		GameManager.set_lingua(lingua, false)
		for k in ["SECRET_WRONG", "SECRET_SUB_1", "SECRET_SUB_2", "SECRET_SUB_3"]:
			if tr(k) == k or tr(k).strip_edges() == "":
				mancanti.append("%s/%s" % [lingua, k])
	GameManager.set_lingua(prima, false)
	_check("FRASI_IN_OGNI_LINGUA", mancanti.is_empty(), "mancano: " + ", ".join(mancanti))

# ---------- strumenti ----------

func _sblocca() -> Button:
	for b in _panel.find_children("*", "Button", true, false):
		if (b as Button).text == tr("SECRET_UNLOCK"):
			return b
	return null

func _foto() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return _vp.get_texture().get_image()

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		if not _fails.has(nome):
			_fails.append(nome)
