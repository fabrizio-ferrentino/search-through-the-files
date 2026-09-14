extends Node

# Test dell'AVVIO DEL PC in stile 1995 (POST del BIOS -> riga su schermo nero ->
# splash col nastro -> login), piu' strumento per guardarlo a occhio.
#
# La sequenza e' una catena di attese: quello che si rompe in silenzio e' il caso
# in cui viene interrotta a meta'. Qui si pretende che:
#   1 le tre fasi si susseguano nell'ordine giusto e finiscano sul login
#   2 l'avvio NON sia saltabile: ne' un tasto ne' un clic devono portarlo al login
#     (scelta del proprietario: il boot si guarda)
#   3 spegnere il case a meta' avvio fermi la sequenza: niente login che compare
#     da solo dopo lo spegnimento, niente scritture su overlay gia' liberati
#   4 riaccendere subito dopo riparta da capo, senza due sequenze sovrapposte
#
# I controlli ASPETTANO LO STATO, non un istante preciso: le durate delle fasi si
# ritoccano spesso (sono costanti BOOT_* in desktop.gd) e i tempi fissi renderebbero
# il test falso-negativo a ogni taratura. Le durate vere le stampa, per decidere se
# l'avvio e' troppo lungo.
# Salva anche una foto di ogni fase (il percorso lo stampa alla fine).
#
# Esecuzione:
#   & $godot --path $proj res://tests/boot_test.tscn
# ============================================================

const OS_SIZE := Vector2i(1440, 1080)
const OUT := "user://avvio/"
const LIMITE := 8.0        # attesa massima per una fase, poi e' un guasto

var _fails: Array = []
var _vp: SubViewport = null
var _os = null             # OSDesktop
var _t0 := 0               # istante dell'accensione, per cronometrare le fasi

func _ready() -> void:
	get_tree().create_timer(180.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	GameManager.start_new_run(4242)
	_crea_os()
	# riscaldamento: il primo fotogramma costruisce desktop, icone e caratteri
	await _attendi(1.0)

	# ---------- 1) la sequenza completa, fase per fase ----------
	_avvia()
	_check("POST_PARTE", await _aspetta(func(): return _testo().find("Memory Test") >= 0),
			"non compare il conteggio della memoria: %s" % _riga_unica())
	await _attendi(0.25)       # a conteggio iniziato, per la foto
	await _foto("1_post_memoria")

	_check("POST_COMPLETO", await _aspetta(func(): return _testo().find("Verifying DMI Pool Data") >= 0),
			"il POST non arriva in fondo: %s" % _riga_unica())
	await _foto("2_post_completo")

	_check("RIGA_AVVIO", await _aspetta(func(): return _testo().find("Avvio di") >= 0),
			"non compare la riga di avvio su schermo nero: %s" % _riga_unica())
	await _foto("3_riga_avvio")

	# lo splash non ha testo: si riconosce dal cielo + il nastro (due TextureRect)
	_check("SPLASH", await _aspetta(func(): return _conta_tipo(_os._state_overlay, "TextureRect") >= 2),
			"lo splash non arriva a schermo")
	await _attendi(0.4)        # nastro in viaggio, per la foto
	await _foto("4_splash")

	_check("ARRIVA_AL_LOGIN", await _aspetta(func(): return not _os._booting and _os._modal_layer != null),
			"passata tutta la sequenza non compare il login")
	await _foto("5_login")
	print("   durata totale dell'avvio: %.1f s" % _passati())

	# ---------- 2) l'avvio non si salta ----------
	_os.power_off()
	await _attendi(0.1)
	_avvia()
	await _attendi(0.5)
	_check("A_META", _os._booting, "l'avvio era gia' finito: la prova non vale")
	_premi(KEY_SPACE)
	_premi(KEY_ENTER)
	_clicca()
	await _attendi(0.2)
	_check("TASTO_NON_SALTA", _os._booting and _os._modal_layer == null,
			"un tasto o un clic durante l'avvio lo salta: deve essere ignorato")
	# e arriva comunque al login da solo
	_check("FINISCE_DA_SOLO", await _aspetta(func(): return not _os._booting and _os._modal_layer != null),
			"dopo i tasti ignorati l'avvio non arriva piu' al login")

	# ---------- 3) spegnere a meta' avvio ferma tutto ----------
	_os.power_off()
	await _attendi(0.1)
	_avvia()
	await _attendi(0.5)
	_check("SPEGNE_A_META", _os._booting, "l'avvio era gia' finito: la prova non vale")
	_os.power_off()
	await _attendi(0.2)
	_check("SPENTO_SUBITO", not _os._booting and _os._modal_layer == null and _os._no_signal_box != null,
			"dopo lo spegnimento non si vede 'nessun segnale'")
	await _attendi(LIMITE)     # piu' di quanto durerebbe il resto: non deve risvegliarsi
	_check("NIENTE_LOGIN_FANTASMA", _os._modal_layer == null and not GameManager.pc_on,
			"la sequenza interrotta ha aperto il login col PC spento")

	# ---------- 4) riaccensione pulita ----------
	_avvia()
	_check("RIACCENDE", await _aspetta(func(): return _testo().find("Memory Test") >= 0),
			"riaccendendo il POST non riparte da capo")
	_check("RIACCENDE_AL_LOGIN", await _aspetta(func(): return not _os._booting and _os._modal_layer != null),
			"riaccendendo non si arriva al login")

	print("\nfoto delle fasi in: ", ProjectSettings.globalize_path(OUT))
	if _fails.is_empty():
		print("RISULTATO: PASS (avvio in tre fasi, non saltabile, spegnimento a meta')")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# L'OS come lo costruisce player.gd: size fissata PRIMA di entrare nell'albero,
# altrimenti in _ready gli overlay si centrerebbero su una dimensione nulla.
func _crea_os() -> void:
	_vp = SubViewport.new()
	_vp.size = OS_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_vp.transparent_bg = false
	_vp.disable_3d = true
	add_child(_vp)
	_os = load("res://scripts/os/desktop.gd").new()
	_os.position = Vector2.ZERO
	_os.size = Vector2(OS_SIZE)
	_vp.add_child(_os)

# Aspetta che la condizione sia vera, controllando a ogni fotogramma. Stampa da
# quanti secondi dall'accensione e' arrivata la fase (serve a tarare le durate).
func _aspetta(cond: Callable) -> bool:
	var fine: float = _passati() + LIMITE
	while _passati() < fine:
		if cond.call():
			print("      (a %.2f s dall'accensione)" % _passati())
			return true
		await get_tree().process_frame
	return false

func _attendi(t: float) -> void:
	await get_tree().create_timer(t).timeout

# Accende il case e azzera il cronometro delle fasi.
func _avvia() -> void:
	_os.boot()
	_t0 = Time.get_ticks_msec()

func _passati() -> float:
	return float(Time.get_ticks_msec() - _t0) / 1000.0

# Il testo dell'overlay di stato (le fasi a schermo nero sono fatte di Label).
func _testo() -> String:
	if _os._state_overlay == null or not is_instance_valid(_os._state_overlay):
		return ""
	var out := ""
	for c in _os._state_overlay.get_children():
		if c is Label:
			out += (c as Label).text + "\n"
	return out

# Lo stesso testo su una riga, per i messaggi di errore.
func _riga_unica() -> String:
	return _testo().replace("\n", " | ")

func _conta_tipo(nodo: Node, classe: String) -> int:
	if nodo == null or not is_instance_valid(nodo):
		return 0
	var n := 0
	for c in nodo.get_children():
		if c.is_class(classe):
			n += 1
		n += _conta_tipo(c, classe)
	return n

# Tasto vero: passa dal viewport, quindi da OSDesktop._input (come in partita).
func _premi(codice: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codice
	ev.physical_keycode = codice
	ev.pressed = true
	_vp.push_input(ev, true)

# Clic vero in mezzo allo schermo (premuto e rilasciato), come lo inoltra player.gd.
func _clicca() -> void:
	var pos := Vector2(OS_SIZE) * 0.5
	_vp.notify_mouse_entered()      # senza questo il viewport non crede di avere il mouse
	for giu in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.position = pos
		ev.global_position = pos
		ev.pressed = giu
		_vp.push_input(ev, true)

func _foto(nome: String) -> void:
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	if img != null and not img.is_empty():
		img.save_png(OUT + nome + ".png")

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		_fails.append(nome)
