extends Node

# Test dei VIRUS (M5, richiesta del proprietario: "bisogna creare dei cattivi anche nel
# mondo 2d, non devono essere troppo invasivi"). La stanza vera, dentro il PC, col
# VirusDirector vero; il regista della stanza viene fermato, cosi' il Jester non si
# affaccia in mezzo al test. Il tempo dei virus lo fa scorrere il test (avanza), non
# l'orologio: i minuti di attesa diventano un ciclo.
# Si pretende che:
#   1 IL RITMO (scelto dal proprietario: "rari"): niente virus prima di PRIMO_VIRUS di PC
#     acceso, niente se il giocatore e' nella stanza, appena entrato, con un dialogo
#     aperto o a minacce del PC spente (F8 congela il conto; F11, la stanza, no); dopo
#     uno, la pausa e' fra PAUSA_MIN e PAUSA_MAX; mai lo stesso due volte di fila, e
#     tutti e tre escono, ma il MORTALE solo dopo la prima chiave trovata;
#   1b il FANTASMA e il FASTIDIO (proprietario, 28/11/2026): il fantasma e' solo il bambino o
#     gli occhi (sangue, tremito, orologio, scritte, lampeggio NON ci sono piu'); ognuno si
#     VEDE, sta sotto icone e finestre -- o sopra le finestre con l'interruttore di sviluppo --
#     e RESTA (a 4 s e a DURATA * 0.8 c'e' ancora, sempre lui); il fastidio e' il buio: si
#     vede e SPARISCE DEL TUTTO entro Apparizione.SOGLIA_FALSO, senza uccidere; il regista lo
#     fa partire col suo conto (FASTIDIO_MIN..MAX), mai sopra un altro virus, e dopo un
#     fastidio il virus aspetta DOPO_FASTIDIO; SHIFT+F9 ne forza uno;
#   2 il MORTALE e' un'apparizione che resta, e spegnere salva -- dal menu Avvio E dal
#     case: niente morte, ogni strato tolto; e il
#     ThreatDirector non si affaccia intanto;
#   3 YouAreStupid apra la sua raffica (titolo e scritta in INGLESE in ogni lingua, dentro
#     lo schermo, nella barra), NON SI POSSA IGNORARE -- sempre sopra le altre finestre
#     anche cliccandole, niente "riduci" ne' dalla barra, il fuoco della tastiera rubato,
#     e lasciate li' ne arrivano altre -- la X chiuda anche una finestra IN MOVIMENTO
#     (prima si premeva ma il rilascio cadeva fuori dal pulsante),
#     le vaganti si muovano senza uscire, chiuderle ne faccia nascere altre ma MAI oltre i
#     tetti, e che FINISCA; spegnere il PC lo chiuda e non riapra niente;
#   4 lo SCHERMO BLU stia sopra a tutto e si veda blu; mangi i clic E i tasti (nessun tasto
#     lo chiude: si subisce); mostri un conto alla rovescia tradotto che scende; ESC --
#     passando da player.gd -- esca dal PC mentre il conto va avanti sul monitor; e allo
#     scadere il PC si RIAVVII DA SOLO come nella realta' (finestre chiuse, nero, BIOS,
#     login); F9 vero lo apra; il testo non abbia segnaposto rimasti ne' forme di chiave;
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
	GameManager.room_threats_enabled = true
	GameManager.pc_threats_enabled = true
	GameManager.start_new_run(5150)
	GameManager.pc_on = true
	GameManager.logged_in = true
	_room = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_room)
	await get_tree().create_timer(1.6).timeout       # la dissolvenza d'ingresso della stanza
	_player = _room.find_child("Camera3D", true, false)
	_player._threats.stop()          # niente Jester durante il test
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
	await _prova_apparizioni()
	await _prova_mortale()
	await _prova_stupido()
	await _prova_schermo_blu()
	await _prova_pannello()
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
	GameManager.room_threats_enabled = true
	GameManager.pc_threats_enabled = true
	get_tree().quit(0 if _fails.is_empty() else 1)

func _timeout() -> void:
	print("RISULTATO: FAIL -> timeout " + ", ".join(_fails))
	get_tree().quit(1)

# ---------- 1: il ritmo ----------

func _prova_ritmo() -> void:
	_vd._tempo = 0.0
	_vd._prossimo = _vd.PRIMO_VIRUS
	_vd._prossimo_fastidio = 1.0e9     # i fastidi hanno la loro sezione (1b)
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

	# F8 (minacce del PC) congela il conto...
	GameManager.pc_threats_enabled = false
	var t0: float = _vd._tempo
	_passi(30.0)
	_check("F8_CONGELA", _vd.in_corso() == "" and is_equal_approx(_vd._tempo, t0),
			"a minacce del PC spente: evento '%s', tempo %.1f -> %.1f" % [_vd.in_corso(), t0, _vd._tempo])
	GameManager.pc_threats_enabled = true
	# ...F11 (minacce della stanza) no: e' un altro interruttore
	GameManager.room_threats_enabled = false
	_vd.avanza(0.5)
	_check("F11_NON_TOCCA_IL_PC", _vd._tempo > t0,
			"a minacce della STANZA spente il conto dei virus si e' fermato")
	GameManager.room_threats_enabled = true
	_vd._tempo = t0

	_passi(1.0)
	var tipo: String = _vd.in_corso()
	_check("PARTE", tipo != "", "a tempo scaduto, dentro il PC e col desktop libero non parte niente")
	await _chiudi_evento()
	var pausa: float = _vd._prossimo - _vd._tempo
	_check("PAUSA", pausa >= _vd.PAUSA_MIN and pausa <= _vd.PAUSA_MAX,
			"pausa dopo un virus %.0f s, fuori da %d-%d" % [pausa, int(_vd.PAUSA_MIN), int(_vd.PAUSA_MAX)])

	# il mortale aspetta la prima chiave trovata (26/11/2026); gli altri no
	GameManager.chiavi_trovate.clear()
	var senza := {}
	for i in range(300):
		var s: String = _vd._scegli()
		_vd._ultimo = s
		senza[s] = true
	_check("MORTALE_ASPETTA_LA_CHIAVE", not senza.has("mortale") and senza.size() == 2,
			"senza chiavi escono %s" % str(senza.keys()))
	GameManager.scopri_in(GameManager.key_label(1))

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
			await _attendi_blu()
			await _riaccendi()
	await get_tree().process_frame
	_vd.avanza(0.1)

# ---------- 1b: il fantasma e il fastidio ----------

func _prova_apparizioni() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var finestra: OSWindow = _os.open_app("notepad", {"name": "a.txt", "content": "ciao"})
	finestra.position = Vector2(420, 260)
	await _frame(2)

	# il proprietario ha tolto sangue, tremito, orologio (28/11/2026), scritte, lampeggio: il
	# fantasma e' solo il bambino o gli occhi, il buio solo un fastidio
	var tolti := ["lampeggio", "scritte", "sangue", "tremito", "orologio"].filter(
			func(t): return Apparizione.TIPI.has(t))
	_check("NIENTE_TOLTI", tolti.is_empty() and Apparizione.FANTASMI == ["bambino", "occhi"]
			and Apparizione.PESI.size() == Apparizione.FANTASMI.size() and Apparizione.TIPI.has("buio")
			and not Apparizione.FANTASMI.has("buio"),
			"tornati %s, FANTASMI %s, PESI %d" % [str(tolti), str(Apparizione.FANTASMI), Apparizione.PESI.size()])

	# ogni FANTASMA, come VERO: si vede, sta sotto icone e finestre (di base) o sopra le finestre
	# (interruttore di sviluppo), e non se ne va
	for sopra in [false, true]:
		GameManager.fantasma_sopra_finestre = sopra
		for tipo in Apparizione.FANTASMI:
			var v := VirusMortale.new()
			_os.add_child(v)
			v.setup(_os, rng, tipo)
			v.set_process(false)
			var a := v.apparizione()
			_porta_a(v, 0.25)
			await _frame(2)
			var si_vede := false
			var come := ""
			if tipo == "bambino":
				si_vede = _si_vede_li(a)
				come = "sagoma"
				if not sopra:
					# caratteri NERI (proprietario, 19/10), e niente alone: DENTRO le celle delle
					# lettere, fra un tratto e l'altro, si vede ancora la carta da parati
					var nere := 0
					for k in a._celle:
						if (k[2] as Color).r < 0.2:
							nere += 1
					var fra := _carta_fra_le_lettere(a)
					_check("BAMBINO_NERO", a._celle.size() > 0 and nere == a._celle.size(),
							"bambino: %d caratteri neri su %d" % [nere, a._celle.size()])
					_check("BAMBINO_SENZA_ALONE", fra > 0.3,
							"nelle celle del bambino solo %.0f%% dei pixel e' carta da parati (un alone?)" % (fra * 100.0))
			else:
				si_vede = a._occhi.size() >= 1
				come = "%d coppie" % a._occhi.size()
			var dove := "SOPRA" if sopra else "SFONDO"
			_check("APPARE_%s_%s" % [tipo.to_upper(), dove], si_vede, "fantasma '%s' non si vede (%s)" % [tipo, come])
			var i_strato: int = a._sfondo.get_index()
			var sotto_icone: bool = i_strato < _os.icons_layer.get_index()
			var sopra_finestre: bool = i_strato > _os.window_layer.get_index() and i_strato < _os.taskbar.get_index()
			_check("STRATO_%s_%s" % [tipo.to_upper(), dove], sopra_finestre if sopra else sotto_icone,
					"fantasma '%s' (sopra le finestre: %s) allo strato %d: icone %d, finestre %d, barra %d" % [tipo,
					str(sopra), i_strato, _os.icons_layer.get_index(), _os.window_layer.get_index(),
					_os.taskbar.get_index()])
			if not sopra:
				_foto("virus_fantasma_%s.png" % tipo)
			# il vero RESTA, sempre lo stesso: oltre la soglia di un fastidio e fino quasi alla fine
			_porta_a(v, 4.0)
			var a4: bool = is_instance_valid(a) and a.attiva()
			_porta_a(v, v.DURATA * 0.8)
			var a8: bool = is_instance_valid(a) and a.attiva() and a.tipo == tipo
			_check("IL_VERO_RESTA_%s_%s" % [tipo.to_upper(), dove], a4 and a8 and not v._finito,
					"fantasma '%s': a 4 s %s, a %.0f s %s" % [tipo, str(a4), v.DURATA * 0.8, str(a8)])
			v.pulisci()
			await _frame(2)
	GameManager.fantasma_sopra_finestre = false

	# il FASTIDIO (il buio): si vede, poi sparisce DEL TUTTO prima di SOGLIA_FALSO
	var f := Apparizione.new()
	_os.add_child(f)
	f.setup(_os, "buio", rng)
	f.durata = 2.0
	f.set_process(false)
	f.avanza(0.25)
	await _frame(2)
	var scuro: float = f._velo.color.a if f._velo != null else -1.0
	_check("APPARE_BUIO", scuro > 0.45, "il fastidio 'buio' non si vede (alfa %.2f)" % scuro)
	_foto("virus_fastidio_buio.png")
	f.avanza(2.0)
	await _frame(2)
	var resti := 0
	for n in _os.find_children("Apparizione*", "", true, false):
		if not n.is_queued_for_deletion():
			resti += 1
	_check("SPARISCE_BUIO", not is_instance_valid(f) and resti == 0 and not GameManager._game_over_active,
			"dopo il fastidio: nodo vivo %s, strati %d" % [str(is_instance_valid(f)), resti])

	# il buio copre TUTTO lo schermo, anche il menu Avvio e "Arresta il sistema" aperti DOPO
	# (si portano in primo piano: lum_prima gli passavano sopra e "rimangono invariati")
	var punti := {}
	_os._toggle_start_menu()
	await _frame(2)
	punti["menu"] = Vector2i(_os.start_menu.global_position - _os.global_position + _os.start_menu.size * 0.6)
	punti["barra"] = Vector2i(int(_os.size.x * 0.5), int(_os.size.y) - 4)
	var lum_prima: Dictionary = await _luminanze(punti)
	_os._toggle_start_menu()
	_os._show_shutdown()
	await _frame(2)
	punti["dialogo"] = Vector2i(_os.size * 0.5)
	var ld: Dictionary = await _luminanze(punti)
	lum_prima["dialogo"] = ld["dialogo"]
	_os._modal_layer.queue_free()
	await _frame(2)
	var bt := Apparizione.new()
	_os.add_child(bt)
	bt.setup(_os, "buio", rng)
	bt.set_process(false)
	bt.avanza(0.3)                              # buio fermo (lo sfarfallio parte lum_dopo)
	_os._toggle_start_menu()
	await _frame(2)
	var lum_dopo: Dictionary = await _luminanze(punti)
	_os._toggle_start_menu()
	_os._show_shutdown()
	await _frame(2)
	var ld2: Dictionary = await _luminanze(punti)
	lum_dopo["dialogo"] = ld2["dialogo"]
	_os._modal_layer.queue_free()
	await _frame(2)
	var coperti := true
	for k in lum_prima:
		if float(lum_dopo[k]) > float(lum_prima[k]) * 0.6:
			coperti = false
	_check("BUIO_TUTTO_LO_SCHERMO", coperti and bt._velo.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"buio: luminanza lum_prima %s, lum_dopo %s" % [str(lum_prima), str(lum_dopo)])
	bt.pulisci()
	await _frame(2)

	# il buio SFARFALLA come una lampadina che sta per spegnersi (proprietario, 19/10): mai piu'
	# chiaro del suo solito, cali che arrivano quasi al buio, MORBIDI (niente scatti da
	# interruttore), e mai piu' di 3 cali in un secondo (fotosensibilita')
	var bu := Apparizione.new()
	_os.add_child(bu)
	bu.setup(_os, "buio", rng)
	bu.set_process(false)
	var alfe: Array = []
	for i in range(9 * 30):                  # 9 s a 30 passi al secondo
		bu.avanza(1.0 / 30.0)
		if bu._t >= 0.5:
			alfe.append(bu._velo.color.a)
	bu.pulisci()
	await _frame(2)
	var solito := 0.62                         # lo scuro del fastidio, senza crescita
	var alfa_min := 1.0
	var alfa_max := 0.0
	var salto := 0.0
	var inizi: Array = []
	var in_calo := false
	for i in range(alfe.size()):
		var al: float = alfe[i]
		alfa_min = minf(alfa_min, al)
		alfa_max = maxf(alfa_max, al)
		if i > 0:
			salto = maxf(salto, absf(al - float(alfe[i - 1])))
		var calo := al > solito + 0.08
		if calo and not in_calo:
			inizi.append(i / 30.0)
		in_calo = calo
	var al_secondo := 0
	for i in range(inizi.size()):
		var n := 0
		for j in range(i, inizi.size()):
			if float(inizi[j]) - float(inizi[i]) < 1.0:
				n += 1
		al_secondo = maxi(al_secondo, n)
	_check("BUIO_LAMPADINA", alfa_min >= solito - 0.03 and alfa_max >= 0.78 and inizi.size() >= 2
			and al_secondo <= 3 and salto <= 0.25,
			"buio: alfa fra %.2f e %.2f (il solito %.2f), %d cali, al massimo %d in un secondo, salto massimo %.2f"
			% [alfa_min, alfa_max, solito, inizi.size(), al_secondo, salto])

	# il bambino e' fatto di CARATTERI (proprietario, 19/10: ASCII art) e la griglia, ferma,
	# cambia mentre lui dondola sotto: non e' un'immagine di testo incollata
	var bb := Apparizione.new()
	_os.add_child(bb)
	bb.setup(_os, "bambino", rng)
	bb.crescita = VirusMortale.DURATA
	bb.set_process(false)
	bb.avanza(0.3)
	var ammessi := Apparizione.ASCII_RAMPA + Apparizione.ASCII_SPARSI + "()"
	var quanti := bb._celle.size()
	var prima := ""
	for k in bb._celle:
		prima += str(k[1])
	var solo_ascii := true
	for k in bb._celle:
		if not ammessi.contains(str(k[1])):
			solo_ascii = false
	for i in range(30):
		bb.avanza(0.1)
	var dopo := ""
	for k in bb._celle:
		dopo += str(k[1])
	# DETTAGLIATO come gli occhi, non un blocco: i capelli piu' scuri del viso, una linea scura
	# dove la maglia finisce sui pantaloncini, piu' scura del busto
	var capelli := Apparizione._in_testa(Vector2(0.0, -Apparizione.TESTA_RY * 0.7))
	var viso := Apparizione._in_testa(Vector2(0.0, Apparizione.TESTA_RY * 0.6))
	var orlo := Vector2(0.0, 120.0)
	var busto := Vector2(0.0, 70.0)
	_check("BAMBINO_DETTAGLI", bb._tono(capelli) > bb._tono(viso) + 0.12
			and bb._tono(orlo) > bb._tono(busto) + 0.2 and bb._tono(viso) > 0.0,
			"toni: capelli %.2f, viso %.2f, orlo della maglia %.2f, busto %.2f" % [bb._tono(capelli),
			bb._tono(viso), bb._tono(orlo), bb._tono(busto)])
	_check("BAMBINO_ASCII", quanti >= 60 and solo_ascii and prima != dopo,
			"bambino: %d caratteri, solo ASCII %s, cambia mentre dondola %s" % [quanti, str(solo_ascii), str(prima != dopo)])
	bb.pulisci()

	# gli OCCHI sono occhi veri fatti di caratteri: bianchi (sclera, riflesso) E scuri (pupilla,
	# iride, ciglia); la pupilla -- le "@" scure -- va dove guardano; quando sbattono sparisce
	var oc := Apparizione.new()
	_os.add_child(oc)
	oc.setup(_os, "occhi", rng)
	oc.set_process(false)
	oc.avanza(0.5)
	var coppia: Vector2 = oc._occhi[0][0]
	oc._occhi[0][1] = 3.0                          # niente battito adesso (fase lontana)
	oc.guarda_test = coppia + Vector2(-600, 0)
	oc._componi_occhi()
	var bianchi := 0
	var neri := 0
	for k in oc._celle_occhi:
		if (k[2] as Color).r > 0.5:
			bianchi += 1
		else:
			neri += 1
	var a_sinistra := _pupille(oc)
	oc.guarda_test = coppia + Vector2(600, 0)
	oc._componi_occhi()
	var a_destra := _pupille(oc)
	oc._occhi[0][1] = 4.7 - fmod(oc._t, 4.7) + 0.1    # adesso e' a meta' battito: chiusi
	oc._componi_occhi()
	var chiusi := _pupille(oc)
	_check("OCCHI_REALISTICI", bianchi >= 80 and neri >= 40 and a_sinistra.y > 0 and a_destra.y > 0
			and a_destra.x > a_sinistra.x + 8.0 and chiusi.y == 0,
			"occhi: %d celle bianche, %d scure; pupille a sinistra %s, a destra %s, chiusi %s"
			% [bianchi, neri, str(a_sinistra), str(a_destra), str(chiusi)])
	oc.pulisci()
	await _frame(2)

	# il regista: un fastidio parte col suo conto, e' sempre il buio, finisce da solo, e sposta il prossimo
	_vd._in_pc_da = 10.0
	_vd._prossimo = _vd._tempo + 1.0e6
	_vd._prossimo_fastidio = _vd._tempo
	_vd.avanza(0.1)
	var fd = _vd._nodo
	_check("REGISTA_FASTIDIO", _vd.in_corso() == "fastidio" and fd is Apparizione and fd.tipo == "buio"
			and fd.durata < Apparizione.SOGLIA_FALSO,
			"regista: evento '%s', tipo %s, durata %s" % [_vd.in_corso(), str(fd.tipo if fd is Apparizione else "-"),
			str(fd.durata if fd is Apparizione else -1)])
	if fd is Apparizione:
		fd.set_process(false)
		for i in range(40):                  # 4 s: oltre qualsiasi FASTIDIO_DURATA
			if is_instance_valid(fd):
				fd.avanza(0.1)
	_vd.avanza(0.1)
	var fra_quanto: float = _vd._prossimo_fastidio - _vd._tempo
	_check("FASTIDIO_FINISCE", _vd.in_corso() == "" and not GameManager._game_over_active
			and fra_quanto >= _vd.FASTIDIO_MIN - 0.5 and fra_quanto <= _vd.FASTIDIO_MAX + 0.5,
			"dopo il fastidio: evento '%s', prossimo fra %.0f s" % [_vd.in_corso(), fra_quanto])
	_vd._prossimo = _vd._tempo
	_vd._evento = "fastidio"
	_vd._fine()
	_check("DOPO_FASTIDIO_ASPETTA", _vd._prossimo >= _vd._tempo + _vd.DOPO_FASTIDIO - 0.01,
			"dopo un fastidio il virus e' fra %.1f s" % (_vd._prossimo - _vd._tempo))

	# mai sopra un altro virus
	_vd._ultimo = ""
	_vd.forza("stupido")
	_vd._prossimo_fastidio = _vd._tempo
	_vd.avanza(0.1)
	_check("MAI_SOPRA_UN_VIRUS", _vd.in_corso() == "stupido", "durante YouAreStupid e' partito '%s'" % _vd.in_corso())
	await _chiudi_evento()

	# SHIFT+F9: un fastidio
	_vd._prossimo = _vd._tempo + 1.0e6
	_vd._prossimo_fastidio = 1.0e9
	await _tasto(KEY_F9, "", true)
	_check("SHIFT_F9_FASTIDIO", _vd.in_corso() == "fastidio", "SHIFT+F9 ha fatto partire '%s'" % _vd.in_corso())
	if _vd._nodo is Apparizione:
		_vd._nodo.pulisci()
	_vd.avanza(0.1)
	_vd._prossimo_fastidio = 1.0e9
	if is_instance_valid(finestra):
		finestra.close()
	await _frame(2)

# Il bambino si vede DAVVERO nei pixel: lungo il suo asse (il collo e' spostato del nodo)
# il colore non e' piu' quello della carta da parati. I caratteri sono bianchi e radi, quindi
# per ogni riga si guarda una STRISCIA larga una cella attorno all'asse, non un pixel solo
# (una colonna puo' cadere fra due lettere).
func _si_vede_li(a: Apparizione) -> bool:
	var img: Image = _player._os_viewport.get_texture().get_image()
	var base: Color = Win95.C_DESKTOP
	var x := int(a._bambino.x - Apparizione.NODO.x * Apparizione.SCALA_BAMBINO)
	var y0 := int(a._bambino.y)
	var diversi := 0
	for dy in range(10, 220, 6):
		for dx in range(-6, 7):
			var c := img.get_pixel(clampi(x + dx, 0, img.get_width() - 1), clampi(y0 + dy, 0, img.get_height() - 1))
			if absf(c.r - base.r) + absf(c.g - base.g) + absf(c.b - base.b) > 0.25:
				diversi += 1
				break
	return diversi >= 12

# Dentro le celle che il bambino occupa, che frazione dei pixel e' ancora la carta da
# parati? Le lettere coprono una parte della cella; un alone scuro dietro la porterebbe a 0.
func _carta_fra_le_lettere(a: Apparizione) -> float:
	var img: Image = _player._os_viewport.get_texture().get_image()
	var base: Color = Win95.C_DESKTOP
	var tot := 0
	var carta := 0
	for k in a._celle:
		var pos: Vector2 = k[0]
		var cella := Rect2(pos.x, pos.y - a._cella.y * 0.8, a._cella.x, a._cella.y)
		for y in range(int(cella.position.y), int(cella.end.y)):
			for x in range(int(cella.position.x), int(cella.end.x)):
				if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
					continue
				var c := img.get_pixel(x, y)
				tot += 1
				if absf(c.r - base.r) + absf(c.g - base.g) + absf(c.b - base.b) < 0.06:
					carta += 1
	return float(carta) / maxf(1.0, float(tot))

# La luminanza di alcuni punti dello schermo del PC (nome -> valore).
func _luminanze(punti: Dictionary) -> Dictionary:
	await RenderingServer.frame_post_draw
	var img: Image = _player._os_viewport.get_texture().get_image()
	var out := {}
	for k in punti:
		var p: Vector2i = punti[k]
		out[k] = img.get_pixelv(p.clamp(Vector2i.ZERO, img.get_size() - Vector2i.ONE)).get_luminance()
	return out

# Il baricentro delle PUPILLE (le "@" scure) negli occhi composti: x medio, e quante sono.
func _pupille(a: Apparizione) -> Vector2:
	var somma := 0.0
	var n := 0
	for k in a._celle_occhi:
		if str(k[1]) == "@" and (k[2] as Color).r < 0.5:
			somma += (k[0] as Vector2).x
			n += 1
	return Vector2(somma / maxf(1.0, float(n)), float(n))

# ---------- 2: il virus mortale ----------

func _prova_mortale() -> void:
	var finestra: OSWindow = _os.open_app("notepad", {"name": "x.txt", "content": "ciao"})
	finestra.position = Vector2(500, 300)
	await get_tree().process_frame
	_check("PARTE_MORTALE", _vd.forza("mortale"), "forza('mortale') rifiutato a desktop libero")
	var v: VirusMortale = _vd._nodo
	v.set_process(false)
	var app := v.apparizione()
	_porta_a(v, v.DURATA * 0.5)
	_check("MORTALE_E_UN_APPARIZIONE", app != null and is_instance_valid(app) and app.attiva()
			and app.crescita == v.DURATA, "il virus mortale non porta un'apparizione che resta")

	# il Jester non si affaccia durante il virus mortale
	var td = _player._threats
	var stato_td: int = td._state
	td._state = td.State.WAIT
	td._timer = 1.0e6
	td._process(0.016)
	_check("JESTER_ASPETTA", not td.in_agguato(), "il nemico si e' affacciato durante il virus mortale")
	td._state = stato_td

	# salvato dal menu Avvio > Arresta > Si'
	_os._show_shutdown()
	await get_tree().process_frame
	var si := _bottone(_os._modal_layer, tr("UI_YES"))
	si.pressed.emit()
	_vd.avanza(0.1)
	await _frame(2)
	_check("SALVATO_DAL_MENU", _vd.in_corso() == "" and not GameManager._game_over_active
			and not is_instance_valid(v) and not is_instance_valid(app)
			and _os.find_children("Apparizione*", "", true, false).is_empty(),
			"dopo Arresta: evento '%s', morte %s, apparizione %s" % [_vd.in_corso(),
			str(GameManager._game_over_active), str(is_instance_valid(app))])
	await _riaccendi()

	# ...e dal pulsante del case, dalla stanza
	_vd._ultimo = ""
	_vd.forza("mortale")
	v = _vd._nodo
	v.set_process(false)
	_porta_a(v, v.DURATA * 0.8)
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

	# non si puo' ignorare: sempre sopra, non si riduce, ruba il fuoco
	var prima_v: OSWindow = vive[0]
	_check("TRE_PULSANTI", prima_v._btn_min.visible and prima_v._btn_max.visible
			and prima_v._btn_close.visible and prima_v.sempre_in_cima,
			"la finestra del virus non ha i tre pulsanti (riduci, ingrandisci, chiudi)")
	# non si abbassa: "riduci" c'e' ma e' spento (clic VERO sul pulsante), e la barra non la
	# nasconde (proprietario, 18/10/2026)
	_os.focus_window(prima_v)
	s._vel.erase(prima_v)                     # ferma, cosi' il clic cade sul pulsante
	await get_tree().process_frame
	_check("RIDUCI_SPENTO", prima_v._btn_min.disabilitato, "il 'riduci' del virus non e' disattivato")
	_clic(prima_v._btn_min.get_global_rect().get_center())
	await _frame(2)
	_check("NON_SI_ABBASSA", prima_v.visible, "cliccando 'riduci' la finestra del virus si e' abbassata")
	_os._on_taskbar_pressed(prima_v)
	_check("NON_SI_ABBASSA_DALLA_BARRA", prima_v.visible,
			"cliccando il suo pulsante nella barra la finestra del virus si e' abbassata")
	var normale: OSWindow = _os.open_app("notepad", {"name": "w.txt", "content": ""})
	_check("ALTRE_SI_ABBASSANO", not normale._btn_min.disabilitato, "anche le finestre normali hanno 'riduci' spento")
	normale.close()
	var note: OSWindow = _os.open_app("notepad", {"name": "z.txt", "content": "ciao"})
	_os.focus_window(note)
	_clic(note.position + Vector2(note.size.x * 0.5, 12))      # e anche cliccandola
	await _frame(2)
	var sotto := true
	for w in s.vive():
		if (w as OSWindow).get_index() < note.get_index():
			sotto = false
	_check("SEMPRE_IN_CIMA", sotto, "una finestra normale, cliccata, e' passata sopra al virus")
	var campo: Control = note.find_children("*", "TextEdit", true, false)[0]
	campo.grab_focus()
	s._in_coda = 1
	s._attesa = 0.0
	s.avanza(0.01)
	await get_tree().process_frame
	_check("RUBA_IL_FUOCO", _os.get_viewport().gui_get_focus_owner() != campo,
			"una finestra nuova del virus non toglie il fuoco al blocco note")
	note.close()

	# la X su una finestra che si MUOVE: premuta e rilasciata nello stesso punto, deve chiudere
	var vagante: OSWindow = s.vive()[1]
	vagante.position = Vector2(80, 300)
	# solo LEI si muove, e in primo piano, e nel frattempo non ne nascono altre: un'altra
	# finestra del virus che le passa sopra si prenderebbe il clic, e il controllo
	# misurerebbe la sfortuna (succedeva sempre, cambiata la sequenza casuale) invece del
	# difetto che cerca
	for w in s._vel.keys():
		s._vel.erase(w)
	s._vel[vagante] = Vector2(500, 0)
	s._in_coda = 0
	s._ignorate = -100.0
	_os.focus_window(vagante)
	await get_tree().process_frame
	var x: Vector2 = vagante._btn_close.get_global_rect().get_center()
	_premi_mouse(x, true)
	await get_tree().process_frame
	for i in range(5):
		s.avanza(0.1)                 # mezzo secondo col tasto giu': a 500 px/s sarebbe lontana
		await get_tree().process_frame
	_premi_mouse(x, false)
	await _frame(2)
	_check("X_SU_VAGANTE", not is_instance_valid(vagante),
			"la X di una finestra in movimento si preme ma non chiude")
	s._ignorate = 0.0                        # di nuovo come in gioco: il prossimo controllo lo prova

	var posizioni := {}
	for w in s._vel.keys():
		posizioni[w] = (w as OSWindow).position
	var fuori := 0
	var all_inizio: int = s.vive().size()
	var di_piu := 0
	for i in range(400):
		s.avanza(0.05)
		di_piu = maxi(di_piu, s.vive().size() - all_inizio)
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
	_check("IGNORATE_INSISTONO", di_piu >= 2 and s.vive().size() <= STUPIDO.MAX_VIVE,
			"lasciate li' 20 s: %d finestre in piu', %d aperte (tetto %d)" % [di_piu,
			s.vive().size(), STUPIDO.MAX_VIVE])
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
	_os.schermo_blu(rng)
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
	var testo: String = sb.testo(rng)
	_check("TESTO_PULITO", not testo.contains("{") and testo.contains("0028:C00")
			and not RegEx.create_from_string("\\b\\d-[A-Z0-9]{4}\\b").search(testo),
			"testo dello schermo blu: %s" % testo)

	# i clic non passano
	var attiva: OSWindow = _os.active_window
	_clic(esplora.position + Vector2(40, 10))
	await _frame(2)
	_check("MANGIA_I_CLIC", _os.active_window == attiva and _os.schermo_blu_aperto(),
			"un clic sotto lo schermo blu ha cambiato finestra o l'ha chiuso")

	# i tasti non lo chiudono (e non arrivano al blocco note che sta sotto): si subisce
	await _tasto(KEY_B, "b")
	await _tasto(KEY_SPACE, " ")
	await _tasto(KEY_ENTER)
	_check("TASTI_NON_LO_CHIUDONO", _os.schermo_blu_aperto() and is_instance_valid(note)
			and is_instance_valid(esplora), "un tasto ha chiuso lo schermo blu o una finestra")

	# il conto alla rovescia: tradotto, col numero, e scende
	var n0: int = sb.secondi_al_riavvio() if is_instance_valid(sb) else -1
	var riga0: String = sb.riga_fine() if is_instance_valid(sb) else ""
	await get_tree().create_timer(1.2).timeout
	var n1: int = sb.secondi_al_riavvio() if is_instance_valid(sb) else -1
	_check("CONTO_ALLA_ROVESCIA", riga0.begins_with(tr("BSOD_RESTART").format({"N": n0}))
			and not riga0.contains("{") and n1 >= 1 and n1 < n0,
			"riga '%s', secondi %d -> %d" % [riga0, n0, n1])

	# ESC dalla coda vera esce dal PC; lo schermo blu e il conto continuano sul monitor
	await _tasto(KEY_ESCAPE)
	for i in range(120):
		if not _player.entering:
			break
		await get_tree().process_frame
	_check("ESC_ESCE_E_CONTINUA", not _player._in_pc and _os.schermo_blu_aperto(),
			"dopo ESC: nel PC %s, schermo blu %s" % [str(_player._in_pc), str(_os.schermo_blu_aperto())])

	# ...e allo scadere il PC si RIAVVIA DA SOLO: tutto chiuso, prima il nero, poi il BIOS,
	# poi il login -- senza che nessuno abbia premuto niente
	await _attendi_blu()
	_check("RIAVVIA_DA_SOLO", _os.windows.is_empty() and not is_instance_valid(note)
			and not is_instance_valid(esplora) and not GameManager.logged_in and _os._booting
			and GameManager.pc_on, "allo scadere: %d finestre, loggato %s, avvio %s" % [
			_os.windows.size(), str(GameManager.logged_in), str(_os._booting)])
	var ov = _os._state_overlay
	_check("PRIMA_IL_NERO", ov is ColorRect and (ov as ColorRect).color == Color.BLACK
			and (ov as ColorRect).get_child_count() == 0, "dopo il crash non c'e' lo schermo nero")
	await get_tree().create_timer(OSDesktop.RIAVVIO_NERO + 0.4).timeout
	ov = _os._state_overlay
	_check("POI_IL_BIOS", ov != null and is_instance_valid(ov) and ov.find_children("*", "Label", true, false).size() > 0,
			"dopo il nero non parte il BIOS")
	await get_tree().create_timer(8.0).timeout
	_check("LOGIN_DOPO", not _os._booting and _os._state_overlay != null and is_instance_valid(_os._state_overlay),
			"dopo il riavvio non c'e' il login")
	await _riaccendi()
	_player._show_pc_overlay()
	await _frame(2)

	# dal regista, col tasto F9 VERO (dentro il PC: lo stesso tasto arriva anche all'OS, ed e'
	# cosi' che lo schermo blu si chiudeva nell'istante in cui si apriva); finito il crash,
	# il regista e' libero
	if not _player._in_pc:
		_player._show_pc_overlay()
		await _frame(2)
	_vd._ultimo = ""
	_vd._giro_debug = _vd.TIPI.find("crash")
	await _tasto(KEY_F9)
	await _frame(3)
	_check("F9_APRE_IL_BLU", _os.schermo_blu_aperto() and _vd.in_corso() == "crash",
			"F9 non lascia lo schermo blu aperto (aperto %s, regista '%s')" % [
			str(_os.schermo_blu_aperto()), _vd.in_corso()])
	await _attendi_blu()
	await _riaccendi()
	_vd.avanza(0.1)
	_check("REGISTA_BLU_FINITO", _vd.in_corso() == "", "chiuso lo schermo blu il regista e' su '%s'" % _vd.in_corso())

	# spegnere col case durante uno schermo blu lo toglie
	_os.schermo_blu(rng)
	_os.power_off()
	await _frame(2)
	_check("SPEGNERE_TOGLIE_IL_BLU", not _os.schermo_blu_aperto(), "a PC spento lo schermo blu e' rimasto")
	await _riaccendi()

# ---------- 5: la vittoria ferma tutto ----------

# ---------- 4b: il pannello di debug (F12) ----------
# Il proprietario non riusciva a far comparire a comando tutte le minacce: ogni pulsante
# del pannello deve far partire QUELLA cosa (quale apparizione compresa), dire perche' se
# non puo', e un clic sul pannello dentro il PC NON deve arrivare anche all'OS sotto.

func _prova_pannello() -> void:
	await _attendi_desktop_libero()
	if not GameManager.debug_aperto():
		GameManager.toggle_keys_panel()
	await _frame(2)
	var p: DebugPanel = GameManager._keys_panel
	var sbagliati := []
	for tipo in Apparizione.FANTASMI:
		var bottoni := p.riga_apparizione(tipo)
		if bottoni.size() != 1:
			sbagliati.append("%s: %d pulsanti" % [tipo, bottoni.size()])
			continue
		(bottoni[0] as Button).pressed.emit()
		var app = null
		if _vd.in_corso() == "mortale" and is_instance_valid(_vd._nodo):
			app = _vd._nodo.apparizione()
		if app == null or app.tipo != tipo:
			sbagliati.append("REAL %s -> '%s' %s" % [tipo, _vd.in_corso(), app.tipo if app != null else "-"])
		p.pulsante("Stop current").pressed.emit()
		await _frame(1)
		if _vd.in_corso() != "":
			sbagliati.append("Stop current lascia '%s'" % _vd.in_corso())
	p.pulsante("Nuisance: darkness").pressed.emit()
	var fd = _vd._nodo
	if _vd.in_corso() != "fastidio" or not (fd is Apparizione) or fd.tipo != "buio":
		sbagliati.append("Nuisance -> '%s'" % _vd.in_corso())
	p.pulsante("Stop current").pressed.emit()
	await _frame(1)
	_check("PANNELLO_OGNI_APPARIZIONE", sbagliati.is_empty(), str(sbagliati))

	for coppia in [["YouAreStupid", "stupido"], ["Blue screen", "crash"]]:
		p.pulsante(coppia[0]).pressed.emit()
		var partito: String = _vd.in_corso()
		p.pulsante("Stop current").pressed.emit()
		await _frame(3)
		_check("PANNELLO_" + str(coppia[1]).to_upper(), partito == coppia[1] and _vd.in_corso() == ""
				and not _os.schermo_blu_aperto(), "'%s' -> '%s', dopo Stop '%s'" % [coppia[0], partito, _vd.in_corso()])

	# un rifiuto si spiega: con le minacce del PC spente non parte niente, e il pannello dice perche'
	p.pulsante("PC threats: ON").pressed.emit()
	p.riga_apparizione("bambino")[0].pressed.emit()
	_check("PANNELLO_DICE_PERCHE", _vd.in_corso() == "" and p.testo().contains("refused: PC threats are OFF"),
			"con F8 spento: evento '%s', esito '%s'" % [_vd.in_corso(), p._esito.text])
	p.pulsante("PC threats: OFF").pressed.emit()
	_check("PANNELLO_INTERRUTTORE", GameManager.pc_threats_enabled, "il pulsante non riaccende le minacce del PC")
	p.pulsante("Ghost above windows: OFF").pressed.emit()
	var sopra_acceso: bool = GameManager.fantasma_sopra_finestre
	p.pulsante("Ghost above windows: ON").pressed.emit()
	_check("PANNELLO_FANTASMA_SOPRA", sopra_acceso and not GameManager.fantasma_sopra_finestre,
			"l'interruttore 'Ghost above windows' non cambia GameManager.fantasma_sopra_finestre")

	# il Jester a comando (il test lo tiene fermo: lo si rimette in attesa solo qui)
	var td = _player._threats
	td._state = td.State.CALM
	p.pulsante("Jester: peek now").pressed.emit()
	var fuori: bool = td.in_agguato()
	p.pulsante("Peek: send away").pressed.emit()
	_check("PANNELLO_JESTER", fuori and not td.in_agguato() and not GameManager._game_over_active,
			"affaccio %s, poi in agguato %s" % [str(fuori), str(td.in_agguato())])
	td.stop()

	# un CLIC VERO dentro il PC sopra il pannello: lo prende il pannello, non l'OS sotto
	p.pulsante("Viruses").pressed.emit()      # Stop current sta nella scheda Viruses: per cliccarlo va aperta
	p.pulsante("Lethal (random)").pressed.emit()
	var ferma: Button = p.pulsante("Stop current")
	await _frame(2)
	var centro: Vector2 = ferma.get_global_rect().get_center()
	var sotto: OSWindow = _os.open_app("notepad", {"name": "sotto.txt", "content": ""})
	sotto.position = (_player.schermo_a_os() * centro - Vector2(150, 60)).floor()
	var davanti: OSWindow = _os.open_app("notepad", {"name": "davanti.txt", "content": ""})
	davanti.position = Vector2(60, 500)
	await _frame(2)
	_os.focus_window(davanti)
	await _frame(2)
	var dentro_os := sotto.get_global_rect().has_point(_player.schermo_a_os() * centro)
	var schermo: Vector2 = get_tree().root.get_final_transform() * centro
	for giu in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = giu
		e.position = schermo
		e.global_position = schermo
		Input.parse_input_event(e)
		Input.flush_buffered_events()
		await _frame(2)
	_check("PANNELLO_CLIC_SUO", dentro_os and _vd.in_corso() == "" and _os.active_window == davanti,
			"clic su Stop sopra una finestra: sotto c'era %s, virus '%s', attiva '%s'" % [str(dentro_os),
			_vd.in_corso(), _os.active_window.win_title if _os.active_window != null else "-"])
	sotto.close()
	davanti.close()
	_foto("debug_pannello.png")
	GameManager.close_keys_panel()
	await _frame(2)

# Aspetta che lo schermo blu e il riavvio siano finiti, poi riporta il PC al desktop.
func _attendi_desktop_libero() -> void:
	_os.salta_al_desktop()
	await _frame(3)

func _prova_stop() -> void:
	_vd._ultimo = ""
	_vd.forza("mortale")
	var v = _vd._nodo
	_vd.stop()
	await _frame(2)
	_check("STOP_PULISCE", not is_instance_valid(v) and _os.find_children("Apparizione*", "", true, false).is_empty(),
			"dopo stop il virus mortale e' ancora li'")
	_check("STOP_FERMA", not _vd.forza("stupido"), "dopo stop parte ancora un virus")
	_vd._fermo = false

# ---------- 6: le lingue ----------

func _prova_lingue() -> void:
	var chiavi := ["VIRUS_STUPID_TITLE", "VIRUS_STUPID_MSG", "BSOD_HEADER",
			"BSOD_TEXT", "BSOD_RESTART",
			"DEATH_VIRUS_1", "DEATH_VIRUS_2", "DEATH_VIRUS_3", "DEATH_VIRUS_4"]
	var tradotte := ["BSOD_TEXT", "BSOD_RESTART", "DEATH_VIRUS_1", "DEATH_VIRUS_2", "DEATH_VIRUS_3", "DEATH_VIRUS_4"]
	var mancano: Array = []
	for k in chiavi:
		var en := TranslationServer.get_translation_object("en").get_message(k)
		var it := TranslationServer.get_translation_object("it").get_message(k)
		if en == "" or it == "" or (k in tradotte and en == it):
			mancano.append(k)
	_check("LINGUE", mancano.is_empty(), "scritte mancanti o non tradotte: %s" % str(mancano))
	# YouAreStupid resta in inglese anche a gioco in italiano (proprietario, 18/10/2026)
	var msg_it := TranslationServer.get_translation_object("it").get_message("VIRUS_STUPID_MSG")
	_check("STUPID_IN_INGLESE", msg_it == "YOU ARE STUPID",
			"in italiano la scritta del virus e' '%s'" % msg_it)
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

# Porta il virus al secondo t (dall'inizio), a passi di 0.1.
func _porta_a(v: VirusMortale, t: float) -> void:
	while v._t < t - 0.001 and not v._finito:
		v.avanza(minf(0.1, t - v._t))

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

# Lo schermo blu si chiude da solo dopo DURATA: si aspetta che lo faccia, come chi gioca.
# Torna appena e' chiuso, cioe' nel primo istante del riavvio (lo schermo nero).
func _attendi_blu() -> void:
	var fine: int = Time.get_ticks_msec() + int((SchermoBlu.DURATA + 2.0) * 1000.0)
	while _os.schermo_blu_aperto() and Time.get_ticks_msec() < fine:
		await get_tree().process_frame

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
	_premi_mouse(p, true)
	_premi_mouse(p, false)

func _premi_mouse(p: Vector2, giu: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = giu
	e.position = p
	e.global_position = p
	_player._os_viewport.push_input(e, true)

func _tasto(codice: Key, carattere := "", shift := false) -> void:
	for giu in [true, false]:
		var e := InputEventKey.new()
		e.keycode = codice
		e.physical_keycode = codice
		e.pressed = giu
		e.shift_pressed = shift
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
