extends Node

# Test del CARICAMENTO di una pagina nel browser (BrowserApp._avvia_caricamento).
#
# Come in WTTG2 aprire un sito non e' istantaneo: c'e' un attimo di attesa, e
# quell'attimo e' tensione (le minacce girano mentre aspetti). Qui si pretende che:
#   1 subito dopo il caricamento la pagina sia COPERTA e non cliccabile (il velo
#     sta sopra al PageView ed e' lui a prendersi il mouse);
#   2 la barra di stato racconti la cosa giusta: prima "Connessione a <dominio>",
#     poi i KB che arrivano -- e il numero di KB deve essere lo STESSO che la wiki
#     elenca nella cronologia (WebRuntime.fake_kb), o si noterebbe la bugia;
#   3 la barra di avanzamento si riempia e finisca piena;
#   4 l'attesa sia BREVE e dentro i limiti dichiarati, e CASUALE (due aperture
#     della stessa pagina non durano uguale);
#   5 la pagina si scopra DALL'ALTO man mano che arriva, come col modem;
#   6 il pulsante "interrompi" FERMI l'arrivo e lasci la pagina a meta' -- non deve
#     regalare il resto, o diventa il modo per saltare l'attesa (e l'attesa e' tensione:
#     le minacce nella stanza girano mentre guardi la barra);
#   7 aprire un'altra pagina mentre la prima carica annulli la prima, senza
#     lasciare il velo appeso;
#   8 i due interruttori (BrowserApp.ATTESA_ATTIVA e SCOPERTA_GRADUALE) facciano davvero
#     quello che dicono: spegnendoli il comportamento cambia, non solo la costante.
#
# Va eseguito come SCENA (serve l'autoload GameManager). Headless va bene: qui non
# si guardano pixel, e i Tween girano comunque.
#   & $godot --headless --path $proj res://tests/page_load_test.tscn
# ============================================================

const VP_SIZE := Vector2i(1440, 1080)
const OUT := "user://caricamento/"
const LIMITE := 6.0        # se un caricamento non finisce entro tanto, e' un guasto

var _sub: SubViewport
var _browser: BrowserApp
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func(): print("RISULTATO: FAIL -> timeout"); get_tree().quit(1))
	await get_tree().process_frame
	GameManager.start_new_run(12345)
	BrowserApp.attesa_scala = 1.0        # qui l'attesa vera E' l'oggetto del test
	# Gli interruttori li decide il proprietario nel file, e questo test NON deve dipendere
	# da dove li ha lasciati: quasi tutto quello che c'e' qui prova il comportamento con
	# l'attesa accesa e la scoperta progressiva, quindi li si fissa. (Successo davvero: con
	# SCOPERTA_GRADUALE lasciato a false tre prove diventavano rosse pur essendo il gioco
	# perfettamente sano.) L'ultima sezione li spegne e riaccende apposta, per provarli.
	BrowserApp.ATTESA_ATTIVA = true
	BrowserApp.SCOPERTA_GRADUALE = true

	_sub = SubViewport.new()
	_sub.size = VP_SIZE
	_sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_sub)
	# grande come una finestra del browser in partita, non a tutto schermo: la barra
	# di stato va guardata nelle proporzioni vere
	var host := Control.new()
	host.theme = Win95.make_theme()
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.size = Vector2(820, 560)
	_sub.add_child(host)
	_browser = BrowserApp.new()
	host.add_child(_browser)
	_browser.launch(null)
	_sub.notify_mouse_entered()          # senza questo il viewport non crede di avere il mouse
	await _browser.attendi_caricamento()
	await get_tree().process_frame

	# ---------- 1) appena aperta, la pagina e' coperta ----------
	var t_inizio := Time.get_ticks_msec()
	_browser._load("forum")
	_check("CARICA_SUBITO", _browser.is_loading(), "il caricamento non parte nemmeno")
	_check("VELO_SOPRA", _browser._velo.visible
			and _browser._velo.get_index() > _browser._rtl.get_index()
			and _browser._velo.mouse_filter == Control.MOUSE_FILTER_STOP,
			"il velo non copre la pagina (visibile=%s, filtro=%d)"
			% [str(_browser._velo.visible), _browser._velo.mouse_filter])
	_check("VELO_COLORE_PAGINA", _browser._velo.color == _browser._page_bg.color,
			"il velo non ha il colore di fondo della pagina")

	await _foto("caricamento")   # com'e' fatta la barra di stato mentre lavora

	# il mouse, mentre si carica, deve finire sul VELO e non sulla pagina
	_muovi(Vector2(400, 300))
	await get_tree().process_frame
	var sopra := _sub.gui_get_hovered_control()
	_check("CLIC_NON_PASSA", sopra == _browser._velo,
			"sotto il mouse c'e' %s invece del velo" % str(sopra))

	# ---------- 2) cosa dice la barra di stato ----------
	var kb := WebRuntime.fake_kb("forum")
	_check("KB_COERENTI", str(WebRuntime._recent_row({"file": "forum", "name": "x", "desc": ""})).find("[%d KB]" % kb) >= 0,
			"i KB della barra di stato non sono quelli che elenca la wiki")
	_check("STATO_CONNESSIONE", _browser._stato_lbl.text.find(WebRuntime.host_of("forum")) >= 0
			and _browser._stato_lbl.text.find("onnessione") >= 0,
			"all'inizio la barra dice: '%s'" % _browser._stato_lbl.text)
	var visto_kb := false
	var visto_blocchi := false
	# La durata si misura da quando e' partito il caricamento, NON da qui: in mezzo ci sono
	# uno screenshot e i controlli sul mouse, e quanto ci mettono cambia da una macchina
	# all'altra -- misurando da qui la durata risultava piu' corta del minimo e il test
	# saltava a caso.
	var t0 := t_inizio
	while _browser.is_loading() and (Time.get_ticks_msec() - t0) < int(LIMITE * 1000.0):
		if _browser._stato_lbl.text.find("%d KB" % kb) >= 0:
			visto_kb = true
		if _accesi() > 0:
			visto_blocchi = true
		await get_tree().process_frame
	var durata := float(Time.get_ticks_msec() - t0) / 1000.0
	_check("STATO_RICEZIONE", visto_kb,
			"la barra non ha mai mostrato i KB della pagina (%d KB)" % kb)
	_check("AVANZAMENTO", visto_blocchi, "la barra di avanzamento non si e' mai riempita")
	_check("FINISCE_DA_SOLA", not _browser.is_loading(), "il caricamento non finisce")
	_check("AVANZAMENTO_PIENO", _accesi() == _browser._blocchi.size(),
			"alla fine i blocchetti accesi sono %d su %d"
			% [_accesi(), _browser._blocchi.size()])
	_check("PAGINA_SCOPERTA", not _browser._velo.visible, "il velo resta sopra la pagina")
	# ...e i blocchetti devono arrivare in FONDO all'incavo: con l'incavo piu' largo
	# della fila restava un quadratino vuoto a destra e sembrava non completarsi
	await get_tree().process_frame
	var riga: Control = (_browser._blocchi[0] as Control).get_parent()
	var ultimo: Control = _browser._blocchi[_browser._blocchi.size() - 1]
	var avanzo: float = riga.size.x - (ultimo.position.x + ultimo.size.x)
	_check("AVANZAMENTO_SENZA_BUCHI", absf(avanzo) <= 1.0,
			"a barra piena restano %.0f px vuoti a destra" % avanzo)
	await _foto("completato")

	# ---------- 3) l'attesa e' breve, e casuale ----------
	print("   durata del caricamento di forum: %.2f s (%d KB)" % [durata, kb])
	var massimo: float = BrowserApp.CARICA_MAX + BrowserApp.CARICA_JITTER + 0.35
	_check("ATTESA_BREVE", durata <= massimo, "%.2f s: troppo (limite %.2f)" % [durata, massimo])
	_check("ATTESA_NON_NULLA", durata >= BrowserApp.CARICA_MIN - BrowserApp.CARICA_JITTER - 0.1,
			"%.2f s: praticamente istantaneo" % durata)
	var durate: Array = []
	for i in range(4):
		var d := await _carica_e_cronometra("misteri")
		durate.append(snappedf(d, 0.01))
	var diverse: Dictionary = {}
	for d in durate:
		diverse[d] = true
	print("   quattro aperture di misteri: %s" % str(durate))
	_check("ATTESA_CASUALE", diverse.size() >= 2,
			"sempre la stessa durata: %s" % str(durate))

	# ---------- 4) la pagina si scopre DALL'ALTO man mano che arriva ----------
	# Non e' un vezzo: e' quello che rende onesto il pulsante "interrompi" (sotto).
	_browser._load("news")
	var scoperto: Array = []
	var t1 := Time.get_ticks_msec()
	while _browser.is_loading() and (Time.get_ticks_msec() - t1) < int(LIMITE * 1000.0):
		scoperto.append(_browser._velo.anchor_top)
		await get_tree().process_frame
	var cresce := false
	for i in range(1, scoperto.size()):
		if float(scoperto[i]) > float(scoperto[i - 1]) + 0.001:
			cresce = true
			break
	_check("SCOPRE_DALL_ALTO", cresce and not scoperto.is_empty()
			and float(scoperto[0]) <= 0.02,
			"il velo non si ritira progressivamente (da %.2f a %.2f in %d passi)" % [
			(float(scoperto[0]) if not scoperto.is_empty() else -1.0),
			(float(scoperto[scoperto.size() - 1]) if not scoperto.is_empty() else -1.0),
			scoperto.size()])

	# ---------- 5) il pulsante interrompi: lascia la pagina A META' ----------
	# Prima scopriva tutta la pagina di colpo: bastava premerlo per saltare l'attesa, e
	# l'attesa non e' un fastidio da saltare -- e' tensione, perche' le minacce nella stanza
	# continuano a girare mentre guardi la barra. Qui si pretende che NON regali il resto.
	_browser._load("forum")
	_check("INTERROMPI_PARTE", _browser.is_loading(), "non sta caricando: la prova non vale")
	# si aspetta che sia arrivato un pezzo, altrimenti la prova non distingue niente
	var t2 := Time.get_ticks_msec()
	while _browser.is_loading() and _browser._velo.anchor_top < 0.25 \
			and (Time.get_ticks_msec() - t2) < int(LIMITE * 1000.0):
		await get_tree().process_frame
	var prima: float = _browser._velo.anchor_top
	_browser._interrompi()
	await get_tree().process_frame
	await get_tree().process_frame
	_check("INTERROMPI_FERMA", not _browser.is_loading(),
			"dopo interrompi sta ancora caricando")
	_check("INTERROMPI_NON_REGALA", _browser._velo.visible and _browser._velo.anchor_top < 0.98,
			"dopo interrompi la pagina si vede tutta (velo visibile=%s, scoperto %.2f): il pulsante diventa un modo per saltare l'attesa"
			% [str(_browser._velo.visible), _browser._velo.anchor_top])
	_check("INTERROMPI_CONGELA", absf(_browser._velo.anchor_top - prima) <= 0.03,
			"il velo si e' mosso dopo l'interruzione: da %.2f a %.2f" % [prima, _browser._velo.anchor_top])
	_check("INTERROMPI_LO_DICE", _browser._stato_lbl.text.find("nterrot") >= 0,
			"la barra di stato dice: '%s'" % _browser._stato_lbl.text)
	# ...e ricaricando si deve poter avere la pagina intera: interrompere non blocca il gioco
	_browser._load("forum")
	await _browser.attendi_caricamento()
	await get_tree().process_frame
	_check("RICARICA_DOPO_INTERROMPI", not _browser._velo.visible,
			"dopo aver ricaricato la pagina resta coperta")

	# ---------- 6) cambiare pagina durante il caricamento ----------
	_browser._load("meteo")
	await get_tree().process_frame
	_browser._load("giochi")
	_check("CAMBIO_A_META", _browser.is_loading(), "il secondo caricamento non parte")
	var fine := Time.get_ticks_msec() + int(LIMITE * 1000.0)
	while _browser.is_loading() and Time.get_ticks_msec() < fine:
		await get_tree().process_frame
	_check("CAMBIO_ARRIVA", not _browser._velo.visible and _browser._current == "giochi",
			"pagina=%s velo=%s" % [_browser._current, str(_browser._velo.visible)])

	# ---------- 7) i due interruttori ----------
	await _prova_interruttori()

	if _fails.is_empty():
		print("RISULTATO: PASS (il caricamento c'e', e' breve, casuale e si interrompe)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

# I due interruttori di BrowserApp (chiesti dal proprietario per fare delle prove).
# Si verificano DAVVERO spegnendoli, non leggendo la costante: un interruttore che non e'
# collegato a niente e' peggio che non averlo.
func _prova_interruttori() -> void:
	# --- ATTESA_ATTIVA = false: le pagine si aprono istantanee ---
	BrowserApp.ATTESA_ATTIVA = false
	_browser._load("news")
	_check("SENZA_ATTESA_ISTANTANEA", not _browser.is_loading(),
			"con ATTESA_ATTIVA spento la pagina carica comunque")
	_check("SENZA_ATTESA_NIENTE_VELO", not _browser._velo.visible,
			"con ATTESA_ATTIVA spento il velo copre ancora la pagina")
	_check("SENZA_ATTESA_STOP_GRIGIO", _browser._btn_stop.disabled,
			"con ATTESA_ATTIVA spento 'interrompi' e' ancora attivo")
	await get_tree().process_frame
	BrowserApp.ATTESA_ATTIVA = true

	# --- SCOPERTA_GRADUALE = false: il velo copre tutto fino alla fine ---
	BrowserApp.SCOPERTA_GRADUALE = false
	_browser._load("forum")
	var sempre_coperto := true
	var t := Time.get_ticks_msec()
	while _browser.is_loading() and (Time.get_ticks_msec() - t) < int(LIMITE * 1000.0):
		if _browser._velo.anchor_top > 0.001:
			sempre_coperto = false
		await get_tree().process_frame
	_check("SENZA_SCOPERTA_COPRE_TUTTO", sempre_coperto,
			"con SCOPERTA_GRADUALE spento il velo si ritira comunque")
	await get_tree().process_frame
	_check("SENZA_SCOPERTA_POI_SCOPRE", not _browser._velo.visible,
			"con SCOPERTA_GRADUALE spento la pagina resta coperta anche alla fine")
	BrowserApp.SCOPERTA_GRADUALE = true

# Foto della finestra, solo quando si gira CON la finestra: headless non disegna
# e frame_post_draw non arriva mai -- aspettarlo qui bloccava il test (visto: il
# test passava a finestra e andava in timeout headless).
func _foto(nome: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := _sub.get_texture().get_image()
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	img.get_region(Rect2i(0, 0, 820, 560)).save_png(OUT + nome + ".png")
	print("   foto: ", ProjectSettings.globalize_path(OUT + nome + ".png"))

# Carica una pagina e ritorna quanto e' durata l'attesa.
func _carica_e_cronometra(pagina: String) -> float:
	var t0 := Time.get_ticks_msec()
	_browser._load(pagina)
	var fine := t0 + int(LIMITE * 1000.0)
	while _browser.is_loading() and Time.get_ticks_msec() < fine:
		await get_tree().process_frame
	return float(Time.get_ticks_msec() - t0) / 1000.0

# Quanti blocchetti della barra di avanzamento sono accesi.
func _accesi() -> int:
	var n := 0
	for b in _browser._blocchi:
		if (b as ColorRect).visible:
			n += 1
	return n

func _muovi(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	_sub.push_input(ev, true)

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		_fails.append(nome)
