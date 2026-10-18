extends Node

# Test dei VIRUS (M5, richiesta del proprietario: "bisogna creare dei cattivi anche nel
# mondo 2d, non devono essere troppo invasivi"). La stanza vera, dentro il PC, col
# VirusDirector vero; il regista della stanza viene fermato, cosi' il Clown non si
# affaccia in mezzo al test. Il tempo dei virus lo fa scorrere il test (avanza), non
# l'orologio: i minuti di attesa diventano un ciclo.
# Si pretende che:
#   1 IL RITMO (scelto dal proprietario: "rari"): niente virus prima di PRIMO_VIRUS di PC
#     acceso, niente se il giocatore e' nella stanza, appena entrato, con un dialogo
#     aperto o a minacce spente (F11 congela il conto); dopo uno, la pausa e' fra
#     PAUSA_MIN e PAUSA_MAX; mai lo stesso due volte di fila, e tutti e tre escono;
#   2 il MORTALE si veda -- sfondo rosso NEI PIXEL, la scritta tradotta, il sangue che
#     cola sopra le finestre ma SOTTO barra e menu Avvio (la via d'uscita resta pulita) --
#     e che spegnere salvi, dal menu Avvio E dal case: niente morte, ogni strato tolto,
#     le finestre rimesse a posto; e che il ThreatDirector non si affacci intanto;
#   3 YouAreStupid apra la sua raffica (titolo tradotto, dentro lo schermo, nella barra),
#     le vaganti si muovano senza uscire, chiuderle ne faccia nascere altre ma MAI oltre i
#     tetti, e che FINISCA; spegnere il PC lo chiuda e non riapra niente;
#   4 lo SCHERMO BLU stia sopra a tutto e si veda blu; mangi i clic; ESC -- passando da
#     player.gd -- sia "un tasto qualsiasi" e NON faccia uscire dal PC; il normale chiuda
#     il programma in primo piano e lasci gli altri; il grave riavvii (finestre chiuse,
#     avvio, login); il testo non abbia segnaposto rimasti ne' forme di chiave;
#   5 la vittoria (stop) tolga il virus in corso e non ne faccia partire altri;
#   6 le scritte nuove esistano in tutte e due le lingue, e la morte "virus" abbia le sue;
#   7 ULTIMO, perche' chiude la partita: il mortale lasciato correre UCCIDA, con la causa
#     "virus".
# Salva anche tre foto sotto user:// (virus_mortale_*.png, virus_blu.png) da guardare.
# A FINESTRA (legge i pixel):
#   & $godot --path $proj res://tests/virus_test.tscn
# ============================================================

const STUPIDO := preload("res://scripts/os/virus_stupido.gd")

var _room: Node = null
var _player: Node = null
var _os: OSDesktop = null
var _vd = null
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(180.0).timeout.connect(func(): _timeout())
	await get_tree().process_frame
	GameManager.set_lingua("it", false)
	GameManager.threats_enabled = true
	GameManager.start_new_run(5150)
	GameManager.pc_on = true
	GameManager.logged_in = true
	_room = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_room)
	await get_tree().create_timer(1.6).timeout       # la dissolvenza d'ingresso della stanza
	_player = _room.find_child("Camera3D", true, false)
	_player._threats.stop()          # niente Clown durante il test
	_player._show_pc_overlay()
	_os = _player._os
	_vd = _player._virus
	_check("REGISTA_C_E", _vd != null, "player.gd non ha creato il VirusDirector")
	if _vd == null:
		_fine()
		return
	_vd.set_process(false)           # il tempo lo fa scorrere il test
	for i in range(4):
		await get_tree().process_frame

	await _prova_ritmo()
	await _prova_mortale()
	await _prova_stupido()
	await _prova_schermo_blu()
	await _prova_stop()
	_prova_lingue()
	await _prova_morte()
	_fine()

func _fine() -> void:
	if _fails.is_empty():
		print("RISULTATO: PASS (i virus arrivano rari, si vedono, e spegnere salva)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().paused = false
	GameManager.threats_enabled = true
	get_tree().quit(0 if _fails.is_empty() else 1)

func _timeout() -> void:
	print("RISULTATO: FAIL -> timeout " + ", ".join(_fails))
	get_tree().quit(1)

# ---------- 1: il ritmo ----------

func _prova_ritmo() -> void:
	_vd._tempo = 0.0
	_vd._prossimo = _vd.PRIMO_VIRUS
	_vd._in_pc_da = 10.0
	_passi(_vd.PRIMO_VIRUS - 2.0)
	_check("NIENTE_PRIMA", _vd.in_corso() == "",
			"virus '%s' partito prima di %d s" % [_vd.in_corso(), int(_vd.PRIMO_VIRUS)])

	# nella stanza no: il giocatore deve vederlo cominciare
	_player._in_pc = false
	_passi(10.0)
	_check("SOLO_DENTRO_IL_PC", _vd.in_corso() == "", "e' partito col giocatore nella stanza")
	_player._in_pc = true
	_passi(_vd.ENTRATA_MIN - 1.0)
	_check("NON_APPENA_ENTRATO", _vd.in_corso() == "", "e' partito appena rientrato nel PC")

	# con un dialogo aperto no
	_os.apri_informazioni("X", "exe", ["a", "b"])
	await get_tree().process_frame
	_passi(5.0)
	_check("NIENTE_COI_DIALOGHI", _vd.in_corso() == "", "e' partito con un dialogo aperto")
	_os._modal_layer.queue_free()
	await get_tree().process_frame

	# F11 congela il conto
	GameManager.threats_enabled = false
	var t0: float = _vd._tempo
	_passi(30.0)
	_check("F11_CONGELA", _vd.in_corso() == "" and is_equal_approx(_vd._tempo, t0),
			"a minacce spente: evento '%s', tempo %.1f -> %.1f" % [_vd.in_corso(), t0, _vd._tempo])
	GameManager.threats_enabled = true

	_passi(1.0)
	var tipo: String = _vd.in_corso()
	_check("PARTE", tipo != "", "a tempo scaduto, dentro il PC e col desktop libero non parte niente")
	await _chiudi_evento()
	var pausa: float = _vd._prossimo - _vd._tempo
	_check("PAUSA", pausa >= _vd.PAUSA_MIN and pausa <= _vd.PAUSA_MAX,
			"pausa dopo un virus %.0f s, fuori da %d-%d" % [pausa, int(_vd.PAUSA_MIN), int(_vd.PAUSA_MAX)])

	var visti := {}
	var doppi := 0
	for i in range(300):
		var s: String = _vd._scegli()
		if s == _vd._ultimo:
			doppi += 1
		_vd._ultimo = s
		visti[s] = true
	_check("MAI_DUE_UGUALI", doppi == 0, "%d volte lo stesso virus due volte di fila" % doppi)
	_check("TUTTI_E_TRE", visti.size() == 3, "in 300 scelte usciti solo %s" % str(visti.keys()))

# Fa finire il virus in corso, qualunque sia, come lo finirebbe il giocatore.
func _chiudi_evento() -> void:
	match _vd.in_corso():
		"mortale":
			_os.power_off()
			_vd.avanza(0.1)
			await _riaccendi()
		"stupido":
			var n = _vd._nodo
			n.ferma()
			for w in n.vive():
				w.close()
			n.avanza(0.1)
		"crash":
			await _tasto(KEY_SPACE)
			if not GameManager.logged_in:
				await _riaccendi()
	await get_tree().process_frame
	_vd.avanza(0.1)

# ---------- 2: il virus mortale ----------

func _prova_mortale() -> void:
	var finestra: OSWindow = _os.open_app("notepad", {"name": "x.txt", "content": "ciao"})
	finestra.position = Vector2(500, 300)
	await get_tree().process_frame
	var prima := _pixel_sfondo()
	_check("PARTE_MORTALE", _vd.forza("mortale"), "forza('mortale') rifiutato a desktop libero")
	var v: VirusMortale = _vd._nodo
	v.set_process(false)
	_avanza_virus(v, v.DURATA * 0.3)
	await _frame(2)
	var dopo := _pixel_sfondo()
	_check("SFONDO_ROSSO", dopo.r > dopo.g * 2.5 and dopo.r > dopo.b * 2.5 and prima.g > prima.r,
			"sfondo prima %s, durante il virus %s: non e' diventato rosso" % [str(prima), str(dopo)])
	_check("SCRITTA", v._scritta.text == tr("VIRUS_CURSE_MSG") and v._scritta.modulate.a > 0.5
			and v._scritta.text != "VIRUS_CURSE_MSG",
			"la scritta e' '%s' (alfa %.2f)" % [v._scritta.text, v._scritta.modulate.a])
	var colate := 0
	for g in v._gocce:
		if float(g[4]) > 5.0:
			colate += 1
	_check("SANGUE_COLA", colate > 5, "al 30%% del virus colano solo %d gocce" % colate)
	var i_sangue: int = v._sangue.get_index()
	_check("STRATI", v._tinta.get_index() < _os.icons_layer.get_index()
			and i_sangue > _os.window_layer.get_index()
			and i_sangue < _os.taskbar.get_index() and i_sangue < _os.start_menu.get_index(),
			"ordine: sfondo %d icone %d finestre %d sangue %d barra %d menu %d" % [v._tinta.get_index(),
			_os.icons_layer.get_index(), _os.window_layer.get_index(), i_sangue,
			_os.taskbar.get_index(), _os.start_menu.get_index()])
	_check("SANGUE_NON_PRENDE_IL_MOUSE", v._sangue.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and v._tinta.mouse_filter == Control.MOUSE_FILTER_IGNORE, "uno strato del virus prende il mouse")
	_foto("virus_mortale_1.png")
	_avanza_virus(v, v.DURATA * 0.55)
	var mosso := false
	for i in range(30):
		v.avanza(0.05)
		if _os.window_layer.position != Vector2.ZERO:
			mosso = true
	_check("TREMA", mosso, "alla fine del virus le finestre non tremano")
	await _frame(2)
	_foto("virus_mortale_2.png")

	# il Clown non si affaccia durante il virus mortale
	var td = _player._threats
	var stato_td: int = td._state
	td._state = td.State.WAIT
	td._timer = 1.0e6
	td._process(0.016)
	_check("CLOWN_ASPETTA", not td.in_agguato(), "il nemico si e' affacciato durante il virus mortale")
	td._state = stato_td

	# salvato dal menu Avvio > Arresta > Si'
	_os._show_shutdown()
	await get_tree().process_frame
	var si := _bottone(_os._modal_layer, tr("UI_YES"))
	si.pressed.emit()
	_vd.avanza(0.1)
	await _frame(2)
	_check("SALVATO_DAL_MENU", _vd.in_corso() == "" and not GameManager._game_over_active
			and not is_instance_valid(v) and _os.window_layer.position == Vector2.ZERO
			and _os.find_child("VirusSangue", true, false) == null
			and _os.find_child("VirusSfondo", true, false) == null,
			"dopo Arresta: evento '%s', morte %s, strati rimasti %s" % [_vd.in_corso(),
			str(GameManager._game_over_active), str(_os.find_child("VirusSangue", true, false) != null)])
	await _riaccendi()

	# ...e dal pulsante del case, dalla stanza
	_vd._ultimo = ""
	_vd.forza("mortale")
	v = _vd._nodo
	v.set_process(false)
	_avanza_virus(v, v.DURATA * 0.8)
	_player._exit_pc()
	for i in range(300):
		if not _player.entering and not _player._in_pc:
			break
		await get_tree().process_frame
	_player._power_button()
	_vd.avanza(0.1)
	await _frame(2)
	_check("SALVATO_DAL_CASE", not GameManager.pc_on and _vd.in_corso() == ""
			and not GameManager._game_over_active and not is_instance_valid(v),
			"dopo il case: acceso %s, evento '%s'" % [str(GameManager.pc_on), _vd.in_corso()])
	await _riaccendi()
	_player._show_pc_overlay()
	await _frame(2)

# ---------- 3: YouAreStupid ----------

func _prova_stupido() -> void:
	var finestre_prima: int = _os.windows.size()
	_check("PARTE_STUPIDO", _vd.forza("stupido"), "forza('stupido') rifiutato")
	var s = _vd._nodo
	s.set_process(false)
	for i in range(30):
		s.avanza(0.1)
	await get_tree().process_frame
	var vive: Array = s.vive()
	_check("RAFFICA", vive.size() == STUPIDO.PRIMA_ONDATA,
			"aperte %d finestre invece di %d" % [vive.size(), STUPIDO.PRIMA_ONDATA])
	var titoli_ok := true
	for w in vive:
		if (w as OSWindow).win_title != tr("VIRUS_STUPID_TITLE") or not _os.taskbar_buttons.has(w):
			titoli_ok = false
	_check("TITOLO_E_BARRA", titoli_ok and _os.windows.size() == finestre_prima + vive.size(),
			"titolo diverso da '%s' o finestre senza pulsante nella barra" % tr("VIRUS_STUPID_TITLE"))
	var posizioni := {}
	for w in s._vel.keys():
		posizioni[w] = (w as OSWindow).position
	var fuori := 0
	for i in range(400):
		s.avanza(0.05)
		for w in s.vive():
			var a: Rect2 = (w as OSWindow).area_utile()
			if not a.grow(0.5).encloses(Rect2((w as OSWindow).position, (w as OSWindow).size)):
				fuori += 1
	var mosse := 0
	for w in posizioni:
		if is_instance_valid(w) and (w as OSWindow).position != posizioni[w]:
			mosse += 1
	_check("VAGANTI", posizioni.is_empty() or mosse == posizioni.size(),
			"%d vaganti, se ne sono mosse %d" % [posizioni.size(), mosse])
	if posizioni.is_empty():
		print("  (nota: in questo seme nessuna finestra vaga)")
	_check("DENTRO_LO_SCHERMO", fuori == 0, "%d volte una finestra e' uscita dallo schermo" % fuori)
	await _foto_frame("virus_stupido.png")

	# chiudendole ne nascono altre, ma finisce
	var max_vive := 0
	var totale := 0
	var giri := 0
	while is_instance_valid(s) and giri < 200:
		giri += 1
		totale = s.aperte_in_tutto()
		var vv: Array = s.vive()
		max_vive = maxi(max_vive, vv.size())
		if not vv.is_empty():
			(vv[0] as OSWindow).close()
		s.avanza(0.4)
		await get_tree().process_frame
	_check("FINISCE", not is_instance_valid(s), "dopo 200 chiusure il virus e' ancora vivo")
	_check("TETTI", max_vive <= STUPIDO.MAX_VIVE and totale <= STUPIDO.MAX_TOTALE,
			"%d finestre vive insieme (tetto %d), %d in tutto (tetto %d)" % [max_vive,
			STUPIDO.MAX_VIVE, totale, STUPIDO.MAX_TOTALE])
	_check("NE_NASCONO_ALTRE", totale > STUPIDO.PRIMA_ONDATA,
			"chiudendole non ne e' mai nata un'altra (%d in tutto)" % totale)
	_vd.avanza(0.1)
	_check("REGISTA_LIBERO", _vd.in_corso() == "", "finito YouAreStupid il regista e' ancora su '%s'" % _vd.in_corso())

	# spegnere il PC lo chiude e non riapre niente
	_vd._ultimo = ""
	_vd.forza("stupido")
	s = _vd._nodo
	s.set_process(false)
	for i in range(10):
		s.avanza(0.1)
	_os.power_off()
	for i in range(20):
		if is_instance_valid(s):
			s.avanza(0.1)
	await get_tree().process_frame
	_vd.avanza(0.1)
	_check("SPEGNERE_LO_CHIUDE", _os.windows.is_empty() and not is_instance_valid(s) and _vd.in_corso() == "",
			"a PC spento: %d finestre, virus vivo %s" % [_os.windows.size(), str(is_instance_valid(s))])
	await _riaccendi()
	_player._show_pc_overlay()
	await _frame(2)

# ---------- 4: lo schermo blu ----------

func _prova_schermo_blu() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var esplora: OSWindow = _os.open_app("explorer", VFS.get_root())
	var note: OSWindow = _os.open_app("notepad", {"name": "y.txt", "content": "ciao"})
	await _frame(2)
	_os.schermo_blu(false, rng)
	await _frame(2)
	var sb: SchermoBlu = _os._schermo_blu
	_check("BLU_IN_CIMA", sb != null and sb.get_index() == _os.get_child_count() - 1,
			"lo schermo blu non e' l'ultimo figlio del desktop")
	var img: Image = _player._os_viewport.get_texture().get_image()
	var blu := 0
	for i in range(200):
		var c := img.get_pixel(int(img.get_width() * (0.05 + 0.9 * (i % 20) / 20.0)), int(img.get_height() * (0.05 + 0.9 * (i / 20) / 10.0)))
		if c.b > 0.55 and c.r < 0.2 and c.g < 0.2:
			blu += 1
	_check("SI_VEDE_BLU", blu > 150, "solo %d punti blu su 200 nello schermo" % blu)
	await _foto_frame("virus_blu.png")
	var testo: String = sb.testo(false, rng)
	_check("TESTO_PULITO", not testo.contains("{") and testo.contains("0028:C00")
			and not RegEx.create_from_string("\\b\\d-[A-Z0-9]{4}\\b").search(testo),
			"testo dello schermo blu: %s" % testo)

	# i clic non passano
	var attiva: OSWindow = _os.active_window
	_clic(esplora.position + Vector2(40, 10))
	await _frame(2)
	_check("MANGIA_I_CLIC", _os.active_window == attiva and _os.schermo_blu_aperto(),
			"un clic sotto lo schermo blu ha cambiato finestra o l'ha chiuso")

	# ESC dalla coda vera: e' "un tasto", non l'uscita dal PC
	await _tasto(KEY_ESCAPE)
	_check("ESC_E_UN_TASTO", not _os.schermo_blu_aperto() and _player._in_pc and not _player.entering,
			"dopo ESC: schermo blu %s, nel PC %s" % [str(_os.schermo_blu_aperto()), str(_player._in_pc)])
	await _frame(2)
	_check("CHIUDE_IL_PROGRAMMA", not is_instance_valid(note) and is_instance_valid(esplora),
			"il blocco note in primo piano %s, l'esplora %s" % [
			"c'e' ancora" if is_instance_valid(note) else "chiuso", "c'e'" if is_instance_valid(esplora) else "chiuso"])

	# il grave riavvia
	_os.schermo_blu(true, rng)
	await _frame(2)
	await _tasto(KEY_A, "a")
	await _frame(2)
	_check("GRAVE_RIAVVIA", _os.windows.is_empty() and not GameManager.logged_in and _os._booting
			and GameManager.pc_on, "dopo il tasto: %d finestre, loggato %s, avvio %s" % [
			_os.windows.size(), str(GameManager.logged_in), str(_os._booting)])
	await get_tree().create_timer(8.0).timeout
	_check("LOGIN_DOPO", not _os._booting and _os._state_overlay != null and is_instance_valid(_os._state_overlay),
			"dopo il riavvio non c'e' il login")
	await _riaccendi()

	# dal regista: finito il crash, il regista e' libero
	_vd._ultimo = ""
	_vd.forza("crash")
	await _frame(2)
	_check("REGISTA_BLU", _os.schermo_blu_aperto(), "forza('crash') non ha aperto lo schermo blu")
	await _tasto(KEY_SPACE)
	if not GameManager.logged_in:
		await _riaccendi()
	_vd.avanza(0.1)
	_check("REGISTA_BLU_FINITO", _vd.in_corso() == "", "chiuso lo schermo blu il regista e' su '%s'" % _vd.in_corso())

	# spegnere col case durante uno schermo blu lo toglie
	_os.schermo_blu(false, rng)
	_os.power_off()
	await _frame(2)
	_check("SPEGNERE_TOGLIE_IL_BLU", not _os.schermo_blu_aperto(), "a PC spento lo schermo blu e' rimasto")
	await _riaccendi()

# ---------- 5: la vittoria ferma tutto ----------

func _prova_stop() -> void:
	_vd._ultimo = ""
	_vd.forza("mortale")
	var v = _vd._nodo
	_vd.stop()
	await _frame(2)
	_check("STOP_PULISCE", not is_instance_valid(v) and _os.find_child("VirusSangue", true, false) == null,
			"dopo stop il virus mortale e' ancora li'")
	_check("STOP_FERMA", not _vd.forza("stupido"), "dopo stop parte ancora un virus")
	_vd._fermo = false

# ---------- 6: le lingue ----------

func _prova_lingue() -> void:
	var chiavi := ["VIRUS_STUPID_TITLE", "VIRUS_STUPID_MSG", "VIRUS_CURSE_MSG", "BSOD_HEADER",
			"BSOD_TEXT", "BSOD_TEXT_GRAVE", "BSOD_CONTINUE", "BSOD_RESTART",
			"DEATH_VIRUS_1", "DEATH_VIRUS_2", "DEATH_VIRUS_3", "DEATH_VIRUS_4"]
	var tradotte := ["VIRUS_STUPID_MSG", "VIRUS_CURSE_MSG", "BSOD_TEXT", "BSOD_TEXT_GRAVE",
			"BSOD_CONTINUE", "BSOD_RESTART", "DEATH_VIRUS_1", "DEATH_VIRUS_2", "DEATH_VIRUS_3", "DEATH_VIRUS_4"]
	var mancano: Array = []
	for k in chiavi:
		var en := TranslationServer.get_translation_object("en").get_message(k)
		var it := TranslationServer.get_translation_object("it").get_message(k)
		if en == "" or it == "" or (k in tradotte and en == it):
			mancano.append(k)
	_check("LINGUE", mancano.is_empty(), "scritte mancanti o non tradotte: %s" % str(mancano))
	var ds = load("res://scripts/death_screen.gd").new()
	var sub: String = ds._pick_subtitle("virus")
	ds.free()
	_check("MORTE_VIRUS_SUA", sub.begins_with("DEATH_VIRUS_"), "la morte 'virus' usa il sottotitolo %s" % sub)

# ---------- 7: lasciato correre, uccide ----------

func _prova_morte() -> void:
	_vd._ultimo = ""
	_vd._fermo = false
	_check("PARTE_ULTIMO", _vd.forza("mortale"), "forza('mortale') rifiutato")
	var v: VirusMortale = _vd._nodo
	v.set_process(false)
	_avanza_virus(v, v.DURATA + 0.5)
	await _frame(3)
	var ds = null
	for c in get_tree().root.get_children():
		if c.get("cause") != null and str(c.get("cause")) == "virus":
			ds = c
	_check("UCCIDE", GameManager._game_over_active and ds != null,
			"a tempo scaduto: morte %s, schermata %s" % [str(GameManager._game_over_active), str(ds != null)])
	if ds != null:
		ds.queue_free()

# ---------- utilita' ----------

func _passi(secondi: float) -> void:
	var n := int(ceil(secondi))
	for i in range(n):
		_vd.avanza(1.0)

func _avanza_virus(v: VirusMortale, secondi: float) -> void:
	var n := int(ceil(secondi / 0.1))
	for i in range(n):
		v.avanza(0.1)

func _riaccendi() -> void:
	_os._boot_token += 1
	_os._booting = false
	GameManager.pc_on = true
	GameManager.logged_in = true
	_os._clear_state()
	await _frame(2)

func _frame(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

# Il colore della carta da parati in un punto che nessuna finestra ne' icona copre.
func _pixel_sfondo() -> Color:
	var img: Image = _player._os_viewport.get_texture().get_image()
	return img.get_pixel(int(img.get_width() * 0.92), int(img.get_height() * 0.80))

func _bottone(radice: Node, testo: String) -> Button:
	for b in radice.find_children("*", "Button", true, false):
		if (b as Button).text == testo:
			return b
	return null

func _clic(p: Vector2) -> void:
	for giu in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = giu
		e.position = p
		e.global_position = p
		_player._os_viewport.push_input(e, true)

func _tasto(codice: Key, carattere := "") -> void:
	for giu in [true, false]:
		var e := InputEventKey.new()
		e.keycode = codice
		e.physical_keycode = codice
		e.pressed = giu
		if giu and carattere != "":
			e.unicode = carattere.unicode_at(0)
		Input.parse_input_event(e)
	Input.flush_buffered_events()
	await _frame(3)

func _foto(nome: String) -> void:
	get_tree().root.get_texture().get_image().save_png("user://" + nome)

func _foto_frame(nome: String) -> void:
	await _frame(2)
	_foto(nome)

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("  ok  " + nome)
	else:
		print("  NO  " + nome + ": " + perche)
		_fails.append(nome)
