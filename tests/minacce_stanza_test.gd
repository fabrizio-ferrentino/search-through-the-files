extends Node

# Test delle MINACCE DELLA STANZA (M4, 19/10/2026): Jester, HaloMan e Ghosty nella stanza
# vera, col ThreatDirector vero. Il tempo lo fa scorrere il test (td._process a passi),
# e le morti non chiudono la partita: td.solo_annota_morte le scrive in td.morte.
# Si pretende che:
#   1 la TORCIA si accenda tenendo premuto e si spenga rilasciando; si scarichi accesa e
#     si ricarichi spenta; vuota si spenga da sola e non si riaccenda subito; dentro il
#     PC non si accenda;
#   2 il JESTER se ne vada solo TENENDOLO illuminato, per 1-2 s A CASO (diversi da un
#     affaccio all'altro); illuminato a meta' e lasciato, torni fuori e il tempo riprenda;
#     la luce verso la zona sbagliata non conti; lasciato stare uccida ("jester");
#   3 si affacci anche dalla FINESTRA (zona sinistra), FUORI dal muro;
#   4 HALOMAN arrivi solo a PC acceso; puntargli la torcia UCCIDA (dall'altra parte no);
#     spegnere il PC lo mandi via; visto, distolto lo sguardo e RIGUARDATO uccida;
#     lasciato stare uccida ("halo"); mai insieme al Jester;
#   5 GHOSTY avanzi quando non lo guardi (anche dentro il PC), PIU' IN FRETTA quando lo
#     guardi senza luce, sparisca appena lo illumini girato verso di lui (e torni dopo una pausa);
#     non colpisca mentre qualcuno si affaccia; arrivato in fondo uccida ("ghosty");
#     dentro il PC lo annunci il velo ai bordi, e solo da vicino;
#   6 IL RITMO (26/11/2026): ogni lato ha la sua pressione, che scende GUARDANDOLO (piano a
#     occhio, in fretta con la torcia) e sale se no; dal lato che fissi non si affaccia
#     nessuno; ci si affaccia dal lato pieno; dopo un affaccio quel lato riparte da zero e
#     c'e' la pausa breve; fino alla prima chiave c'e' solo il Jester (HaloMan mai, Ghosty
#     fermo); le chiavi dopo la prima accelerano.
# Salva foto da guardare: jester_finestra.png, halo_corridoio.png, ghosty_dietro.png.
# Va eseguito A FINESTRA:
#   & $godot --path $proj res://tests/minacce_stanza_test.tscn

const PASSO := 1.0 / 30.0

var _fails: Array = []
var _room: Node = null
var _player = null
var _td = null

func _ready() -> void:
	get_tree().create_timer(240.0).timeout.connect(func():
		print("RISULTATO: FAIL -> timeout " + ", ".join(_fails)); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.room_threats_enabled = true
	GameManager.pc_threats_enabled = false
	GameManager.start_new_run(19)
	GameManager.pc_on = true
	GameManager.logged_in = true
	_room = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_room)
	await get_tree().create_timer(1.8).timeout       # la dissolvenza d'ingresso
	_player = _room.find_child("Camera3D", true, false)
	_td = _player._threats
	_td.set_process(false)                            # il tempo lo fa scorrere il test
	_td.solo_annota_morte = true
	_td._g_timer = 1.0e9                              # Ghosty solo quando lo chiamiamo noi

	_prova_torcia()
	_prova_ritmo()                                    # prima: qui non c'e' ancora nessuna chiave
	await _prova_jester()
	await _prova_finestra()
	await _prova_halo()
	await _prova_ghosty()
	# le morti evitate contano Jester, HaloMan e Ghosty scacciati (una per nemico)
	var st: Dictionary = GameManager.statistiche
	_check("STATISTICHE_NEMICI", int(st.get("evitate", 0)) >= 3, "contati: %s" % str(st))

	GameManager.pc_threats_enabled = true
	GameManager.room_threats_enabled = true
	if _fails.is_empty():
		print("RISULTATO: PASS (Jester, HaloMan e Ghosty fanno quello che devono)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# ---------- 1: la torcia ----------

func _prova_torcia() -> void:
	_gira(_player.pos_right)
	_td._battery = 100.0
	_td.torch_accendi()
	var accesa: bool = _td._torcia_accesa()
	_passi(1.0)
	var dopo1: float = _td._battery
	var ancora: bool = _td._torcia_accesa()
	_td.torch_spegni()
	var spenta: bool = not _td._torcia_accesa()
	_passi(2.0)
	_check("TORCIA_A_PRESSIONE", accesa and ancora and spenta and dopo1 < 90.0 and dopo1 > 65.0
			and _td._battery > dopo1 + 8.0,
			"accesa %s, ancora dopo 1 s %s, spenta al rilascio %s, batteria %.1f -> %.1f" % [str(accesa),
			str(ancora), str(spenta), dopo1, _td._battery])
	_td._battery = 100.0
	_td.torch_accendi()
	_passi(4.5)                        # 100 / BATTERY_DRAIN = 4,2 s di luce
	var vuota: bool = not _td._torcia_accesa() and _td._battery < 5.0
	_td.torch_spegni()
	_td.torch_accendi()
	var non_riparte: bool = not _td._torcia_accesa()
	_td.torch_spegni()
	_player._in_pc = true
	_td._battery = 100.0
	_td.torch_accendi()
	var nel_pc: bool = _td._torcia_accesa()
	_player._in_pc = false
	_check("TORCIA_SI_SCARICA", vuota and non_riparte and not nel_pc,
			"vuota e spenta %s, non si riaccende subito %s, accesa nel PC %s" % [str(vuota),
			str(non_riparte), str(nel_pc)])
	_td.torch_spegni()
	_td._battery = 100.0

# ---------- 6: il ritmo, le pressioni dei lati e lo sblocco alla prima chiave ----------

func _prova_ritmo() -> void:
	GameManager.chiavi_trovate.clear()
	_td._g_arriva = false
	_td._g_timer = 5.0
	var visti := {}
	for i in range(60):
		visti[_td._scegli_chi()] = true
	_td._state = _td.State.CALM
	_td._timer = 0.0
	_gira(_player.pos_center)
	_passi(10.0)
	var ghosty_fermo: bool = not _td._g_arriva and is_equal_approx(_td._g_timer, 5.0)
	_check("SOLO_JESTER_SENZA_CHIAVI", visti.keys() == ["jester"] and ghosty_fermo,
			"senza chiavi escono %s; Ghosty arriva %s, timer %.1f" % [str(visti.keys()),
			str(_td._g_arriva), _td._g_timer])

	# guardare un lato lo scarica: piano a occhio nudo, in fretta con la torcia
	_td._state = _td.State.CALM
	_td._timer = 0.0
	_td._pressione = {"right": 0.9, "left": 0.5}
	_gira(_player.pos_right)
	_passi(3.0)
	var occhio: float = _td._pressione["right"]
	var altro: float = _td._pressione["left"]
	_td._battery = 100.0
	_td.torch_accendi()
	_passi(2.0)
	_td.torch_spegni()
	var torcia: float = _td._pressione["right"]
	_check("GUARDARE_SCARICA", occhio < 0.86 and occhio > 0.7 and torcia < 0.2 and altro > 0.5,
			"destra 0.90 -> a occhio %.2f -> con la torcia %.2f; sinistra 0.50 -> %.2f" % [occhio,
			torcia, altro])

	# dal lato che fissi non si affaccia nessuno
	_td._state = _td.State.WAIT
	_td._pressione = {"right": 0.999, "left": 0.0}
	_gira(_player.pos_right)
	_passi(20.0)
	# (anche la morte: un affaccio lasciato scadere in 20 s finirebbe prima del controllo)
	_check("NIENTE_AFFACCIO_DOVE_GUARDI", not _td.in_agguato() and _td.morte == ""
			and _td._pressione["right"] < 0.99,
			"fissando la destra: affaccio %s, morte '%s', pressione %.2f" % [str(_td.in_agguato()),
			_td.morte, _td._pressione["right"]])
	_td.morte = ""

	# ci si affaccia dal lato pieno; poi quel lato riparte da zero e c'e' la pausa
	_td._state = _td.State.WAIT
	_td._pressione = {"right": 0.0, "left": 0.99}
	_player._in_pc = true
	_passi(1.0)
	var lato: String = _td._peek_zone if _td.in_agguato() else "nessuno"
	var a_sinistra: bool = _td.in_agguato() and _td._peek_spot.is_in_group("spot_left")
	_td.allontana()
	var azzerato: bool = _td._pressione["left"] == 0.0
	_td._pressione["right"] = 1.0
	_passi(_td.CALM_TIME - 1.0)
	var in_pausa: bool = not _td.in_agguato()
	_passi(2.0)
	var dopo: bool = _td.in_agguato() and _td._peek_zone == "right"
	_td.allontana()
	_player._in_pc = false
	_check("AFFACCIO_DAL_LATO_PIENO", a_sinistra, "lato pieno sinistra, affaccio da: %s" % lato)
	_check("PAUSA_DOPO_AFFACCIO", azzerato and in_pausa and dopo,
			"sinistra azzerata %s, nessuno nella pausa %s, poi da destra %s" % [str(azzerato),
			str(in_pausa), str(dopo)])

	# le chiavi: la prima sveglia gli altri, quelle dopo accelerano
	var t_prima: float = GameManager.tempo_partita
	GameManager.tempo_partita = 0.0
	var m0: float = _td._moltiplicatore()
	GameManager.chiavi_trovate = {1: true}
	var m1: float = _td._moltiplicatore()
	GameManager.chiavi_trovate = {1: true, 2: true, 3: true}
	var m3: float = _td._moltiplicatore()
	GameManager.tempo_partita = t_prima
	_check("CHIAVI_ACCELERANO", is_equal_approx(m0, m1) and m3 > m1 * 1.3,
			"moltiplicatore con 0/1/3 chiavi: %.2f / %.2f / %.2f" % [m0, m1, m3])

	GameManager.chiavi_trovate.clear()
	GameManager.scopri_in(GameManager.key_label(1))   # da qui in poi tutti e tre i nemici
	_td._g_timer = 0.5
	_passi(1.0)
	var arriva: bool = _td._g_arriva
	_td._ghosty_via()
	_td._g_timer = 1.0e9
	_check("GHOSTY_PARTE_ALLA_PRIMA_CHIAVE", arriva and GameManager.chiavi_trovate.has(1),
			"trovata la chiave 1 %s, Ghosty arriva %s" % [str(GameManager.chiavi_trovate.has(1)), str(arriva)])
	_td._pressione = {"right": 0.0, "left": 0.0}
	_td._state = _td.State.CALM
	_td._timer = 0.0

# ---------- 2: il Jester ----------

func _prova_jester() -> void:
	# illuminato fino in fondo: se ne va, e ci mette 1-2 s
	_affaccio("jester", "right")
	var serve: float = _td._uscita_serve
	_gira(_player.pos_right)
	_td.torch_accendi()
	_passi(serve - 0.2)
	var ancora_fuori: bool = _td.in_agguato()
	_passi(0.4)
	_td.torch_spegni()
	await _frame(2)
	_check("JESTER_SE_NE_VA_ILLUMINATO", serve >= 1.0 and serve <= 2.0 and ancora_fuori
			and not _td.in_agguato() and not _td._jester.visible and _td.morte == "",
			"servivano %.2f s; dopo %.2f ancora fuori %s; poi affaccio %s, visibile %s" % [serve,
			serve - 0.2, str(ancora_fuori), str(_td.in_agguato()), str(_td._jester.visible)])
	# il tempo cambia ogni volta
	var tempi := {}
	for i in range(8):
		_affaccio("jester", "")
		tempi["%.2f" % _td._uscita_serve] = true
		_td.allontana()
	_check("JESTER_TEMPO_A_CASO", tempi.size() >= 6, "tempi per scacciarlo: %s" % str(tempi.keys()))
	# illuminato a meta' e lasciato: torna fuori, e intanto il tempo per reagire scorre
	_affaccio("jester", "right")
	_gira(_player.pos_right)
	_td.torch_accendi()
	_passi(_td._uscita_serve * 0.5)
	_td.torch_spegni()
	var meta: float = _td._uscita
	var tempo_prima: float = _td._react_left
	_passi(1.0)
	_check("JESTER_TORNA_SE_LASCI", meta > 0.35 and _td._uscita < meta - 0.1 and _td.in_agguato()
			and _td._react_left < tempo_prima - 0.9,
			"uscita %.2f -> %.2f, tempo %.1f -> %.1f" % [meta, _td._uscita, tempo_prima, _td._react_left])
	# la luce dall'altra parte non conta
	_gira(_player.pos_left)
	_td.torch_accendi()
	var prima: float = _td._uscita
	_passi(0.5)
	_td.torch_spegni()
	_check("JESTER_ZONA_GIUSTA", _td._uscita <= prima, "illuminando a sinistra l'uscita e' salita")
	# lasciato stare: uccide
	_passi(_td._react_left + 0.5)
	_check("JESTER_UCCIDE", _td.morte == "jester", "causa: '%s'" % _td.morte)
	_td.morte = ""

# ---------- 3: la finestra ----------

func _prova_finestra() -> void:
	var finestra := false
	for i in range(30):
		_affaccio("jester", "")
		if _td._peek_zone == "left":
			finestra = true
			break
		_td.allontana()
	var fuori: bool = finestra and _td._peek_spot.global_position.x < -2.1
	_check("JESTER_DALLA_FINESTRA", finestra and fuori,
			"in 30 affacci finestra %s, piedi a x=%.2f (il muro esterno e' a -2.11)" % [str(finestra),
			_td._peek_spot.global_position.x if _td._peek_spot else 0.0])
	if finestra:
		_gira(_player.pos_left)
		await get_tree().create_timer(0.8).timeout   # il tempo di sgusciare fuori
		_td.torch_accendi()
		await _frame(3)
		await _foto("jester_finestra.png")
		_td.torch_spegni()
	_td.allontana()
	await get_tree().create_timer(0.6).timeout   # finisce di sgusciare via

# ---------- 4: HaloMan ----------

func _prova_halo() -> void:
	GameManager.pc_on = false
	var no: String = _td.forza_affaccio("halo")
	var mai := true
	for i in range(60):
		if _td._scegli_chi() == "halo":
			mai = false
	GameManager.pc_on = true
	var visti := {}
	for i in range(60):
		visti[_td._scegli_chi()] = true
	_check("HALO_SOLO_A_PC_ACCESO", no != "" and mai and visti.has("halo") and visti.has("jester"),
			"a PC spento: rifiuto '%s', mai lui %s; a PC acceso escono %s" % [no, str(mai), str(visti.keys())])
	# mai insieme al Jester; e la torcia puntata DALL'ALTRA PARTE non conta
	_affaccio("halo", "right")
	var solo_lui: bool = _td._halo.visible and not _td._jester.visible
	var no_jester: String = _td.forza_affaccio("jester")
	_gira(_player.pos_right)
	await get_tree().create_timer(0.8).timeout
	await _foto("halo_corridoio.png")
	_check("MAI_INSIEME", solo_lui and no_jester != "", "visibili halo %s jester %s, secondo affaccio '%s'"
			% [str(_td._halo.visible), str(_td._jester.visible), no_jester])
	_gira(_player.pos_left)
	_td.torch_accendi()
	_passi(1.0)
	_td.torch_spegni()
	var vivo: bool = _td.morte == "" and _td.in_agguato()
	# puntargli contro la torcia: si muore, subito (azzerato lo sguardo: qui conta solo la luce)
	_td._halo_visto = 0
	_gira(_player.pos_right)
	_td.torch_accendi()
	_passi(PASSO * 2)
	_td.torch_spegni()
	_check("HALO_TORCIA_UCCIDE", vivo and _td.morte == "halo" and not _td._halo.visible,
			"luce dall'altra parte: vivo %s; luce su di lui: causa '%s'" % [str(vivo), _td.morte])
	_td.morte = ""
	_affaccio("halo", "right")
	# spegnere il PC si'
	GameManager.pc_on = false
	_passi(0.1)
	await get_tree().create_timer(0.6).timeout   # esce sgusciando
	_check("HALO_SPEGNI_IL_PC", not _td.in_agguato() and not _td._halo.visible and _td.morte == "",
			"a PC spento: affaccio %s, visibile %s, morte '%s'" % [str(_td.in_agguato()),
			str(_td._halo.visible), _td.morte])
	GameManager.pc_on = true
	# lasciato stare: uccide
	_affaccio("halo", "")
	_passi(_td._react_left + 0.5)
	_check("HALO_UCCIDE", _td.morte == "halo" and _td._react_total >= 8.0,
			"causa '%s', tempo per reagire %.1f s" % [_td.morte, _td._react_total])
	_td.morte = ""
	# visto, poi altrove: si vive; RIGUARDATO: si muore (senza torcia)
	_affaccio("halo", "right")
	_gira(_player.pos_right)
	_passi(0.5)
	_gira(_player.pos_center)
	_passi(0.5)
	var vivo_altrove: bool = _td.morte == "" and _td.in_agguato()
	_gira(_player.pos_right)
	_passi(PASSO * 2)
	_check("HALO_NON_RIGUARDARLO", vivo_altrove and _td.morte == "halo",
			"guardato e poi altrove: vivo %s; riguardato: causa '%s'" % [str(vivo_altrove), _td.morte])
	_td.morte = ""
	_gira(_player.pos_center)

# ---------- 5: Ghosty ----------

func _prova_ghosty() -> void:
	_td._pressione = {"right": 0.0, "left": 0.0}      # nessun affaccio nei 30 s di questa prova
	_td._g_arriva = true
	_td._g_p = 0.0
	_gira(_player.pos_center)
	_passi(12.0)
	var avanzato: float = _td._g_p
	_gira(_player.pos_back)
	_passi(5.0)
	var guardato: float = _td._g_p
	# guardato senza luce corre: in 5 s fa piu' strada di quanta ne faceva in 12 senza
	var corre: bool = (guardato - avanzato) / 5.0 > 1.5 * avanzato / 12.0
	_player._in_pc = true
	_passi(3.0)
	var nel_pc: float = _td._g_p
	_player._in_pc = false
	_check("GHOSTY_AVANZA_E_CORRE_SE_GUARDATO", avanzato > 0.1 and corre and nel_pc > guardato + 0.03
			and _td._ghosty.visible,
			"dopo 12 s %.2f, guardato 5 s %.2f (corre %s), nel PC 3 s %.2f, visibile %s" % [avanzato,
			guardato, str(corre), nel_pc, str(_td._ghosty.visible)])
	# girato dietro: la foto, poi la torcia dall'altra parte non fa niente, verso di lui si'
	_td._g_p = 0.6
	_gira(_player.pos_back)
	_passi(PASSO)
	await get_tree().create_timer(0.3).timeout
	await _foto("ghosty_dietro.png")
	_gira(_player.pos_right)
	_td.torch_accendi()
	_passi(PASSO)
	var resta: bool = _td._g_arriva and _td._ghosty.visible
	_td.torch_spegni()
	_gira(_player.pos_back)
	_td.torch_accendi()
	_passi(PASSO)
	_td.torch_spegni()
	_check("GHOSTY_SPARISCE_ALLA_LUCE", resta and not _td._g_arriva and not _td._ghosty.visible
			and _td._g_timer >= 25.0,
			"luce a destra: resta %s; luce verso di lui: arriva %s visibile %s, torna fra %.0f s" % [str(resta),
			str(_td._g_arriva), str(_td._ghosty.visible), _td._g_timer])
	# il velo nel PC: solo da vicino
	_td._g_arriva = true
	_player._in_pc = true
	_td._g_p = 0.2
	var lontano: float = _td.forza_velo_ghosty()
	_td._g_p = 0.85
	var vicino: float = _td.forza_velo_ghosty()
	_player._in_pc = false
	_check("GHOSTY_VELO_NEL_PC", lontano == 0.0 and vicino > 0.2,
			"velo con Ghosty lontano %.2f, vicino %.2f" % [lontano, vicino])
	# non colpisce mentre qualcuno si affaccia...
	_affaccio("jester", "right")
	_gira(_player.pos_center)
	_td._g_p = 0.95
	_td._react_left = 100.0
	_passi(5.0)
	var aspetta: bool = _td.morte == "" and _td._g_p <= _td.GHOSTY_TRATTIENE + 0.001
	_td.allontana()
	# ...poi si'
	_passi(5.0)
	_check("GHOSTY_NON_INSIEME_E_POI_UCCIDE", aspetta and _td.morte == "ghosty",
			"durante l'affaccio aspetta %s; dopo, causa '%s'" % [str(aspetta), _td.morte])
	_td.morte = ""

# ---------- utilita' ----------

# Un affaccio di "chi" ("" = come capita) nella zona voluta ("" = qualunque).
func _affaccio(chi: String, zona: String) -> void:
	for i in range(40):
		if _td.in_agguato():
			_td.allontana()
		_td._state = _td.State.CALM
		_td._pressione = {"right": 0.0, "left": 0.0}
		_td.forza_affaccio(chi)
		if zona == "" or _td._peek_zone == zona:
			return

func _gira(yaw: float) -> void:
	_player.target_yaw = yaw
	_player.rotation_degrees.y = yaw

func _passi(secondi: float) -> void:
	var n := int(ceil(secondi / PASSO))
	for i in range(n):
		_td._process(PASSO)

func _frame(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	get_tree().root.get_texture().get_image().save_png("user://" + nome)

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("  ok  " + nome)
	else:
		print("  NO  %s: %s" % [nome, perche])
		_fails.append(nome)
