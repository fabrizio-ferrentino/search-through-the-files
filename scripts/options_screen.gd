class_name OptionsScreen
extends CanvasLayer

# Schermata IMPOSTAZIONI del menu principale (nel codice resta "options"). Costruita in CODICE come le altre
# sovrimpressioni del gioco (pause_screen.gd, death_screen.gd) e non nella scena del
# menu: quella scena e' del proprietario, e il menu si limita ad aprire questa.
#
# Dentro: la LINGUA (richiesta del proprietario, 19/09/2026) e il VIDEO -- schermo intero,
# V-Sync, risoluzione della finestra (23/10/2026). Le scelte video le tiene e le salva
# GameManager (set_schermo_intero / set_vsync / set_risoluzione). Il resto (volume,
# sensibilita') arrivera' con M6: _aggiungi_riga() aggiunge una riga e basta.
#
# Perche' la lingua si cambia SOLO dal menu: il testo DENTRO il gioco (nomi dei file,
# contenuto dei file, pagine web) viene generato quando parte il run, percio' cambiarla a
# meta' partita non riscriverebbe il PC. Dal menu la scelta arriva prima dello "Start" e
# vale per tutto il run che segue.

# La lingua e' cambiata: chi ha aperto la schermata (il menu) deve rifare le sue scritte,
# che erano state assegnate con tr() quando era la lingua di prima.
signal lingua_cambiata
signal chiusa

# Ogni riga di scelte: {"pulsanti": {valore -> Button}, "attuale": Callable che da' il valore
# scelto}. _aggiorna_selezione() le ridisegna tutte.
var _righe: Array[Dictionary] = []
var _pulsanti: Dictionary = {}       # codice lingua -> Button (la riga della lingua)
var _tendina_ris: Button            # la dimensione della finestra: apre l'elenco sotto
var _lista_ris: Array[Vector2i] = [] # le dimensioni nell'elenco, nello stesso ordine
var _elenco_ris: Control = null      # l'elenco aperto (con il velo che lo chiude), o null
var _radice: Control
var _etichette: Dictionary = {}      # Label -> chiave di locale/ui.csv
var _testi_si_no: Array[Button] = [] # i pulsanti Si'/No, ritradotti col cambio di lingua
var _titolo: Label
var _indietro: Button
var _crediti: Button
var _schermata_crediti: CreditsScreen = null   # i Riconoscimenti, se aperti sopra questa

func _ready() -> void:
	layer = 10                                 # il menu non usa layer: qui sopra e' libero
	_costruisci()

func _input(event: InputEvent) -> void:
	if _schermata_crediti != null and is_instance_valid(_schermata_crediti):
		return                                 # ESC chiude prima i Riconoscimenti, sopra
	if _elenco_ris != null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()  # ESC chiude prima l'elenco delle dimensioni
		_chiudi_elenco_ris()
		return
	if event.is_action_pressed("ui_cancel"):   # ESC: come il pulsante Indietro
		get_viewport().set_input_as_handled()
		chiudi()

func chiudi() -> void:
	chiusa.emit()
	queue_free()

# ---------------- costruzione ----------------

func _costruisci() -> void:
	var radice := Control.new()
	_radice = radice
	radice.name = "Radice"
	radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.mouse_filter = Control.MOUSE_FILTER_STOP   # nessun clic ai pulsanti del menu sotto
	add_child(radice)

	# nero PIENO, per la stessa ragione della schermata di pausa: con un nero
	# trasparente il titolo e i pulsanti del menu traspaiono attraverso il pannello e
	# sembra un difetto di disegno, non una schermata
	var sfondo := ColorRect.new()
	sfondo.color = Color.BLACK
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.add_child(sfondo)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 24)
	radice.add_child(vb)

	_titolo = Label.new()
	_titolo.name = "Titolo"
	_titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titolo.add_theme_font_size_override("font_size", 80)
	_titolo.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vb.add_child(_titolo)

	vb.add_child(_stacco(40))

	# etichette in una colonna, pulsanti nell'altra: le righe restano allineate
	var griglia := GridContainer.new()
	griglia.columns = 2
	griglia.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	griglia.add_theme_constant_override("h_separation", 40)
	griglia.add_theme_constant_override("v_separation", 24)
	vb.add_child(griglia)

	_aggiungi_riga(griglia, "EtichettaLingua", "UI_LANGUAGE", _pulsanti_lingua())
	_aggiungi_riga(griglia, "EtichettaSchermoIntero", "UI_VIDEO_FULLSCREEN",
			_scelte_si_no("SchermoIntero", func(): return GameManager.schermo_intero, _su_schermo_intero))
	_aggiungi_riga(griglia, "EtichettaVSync", "UI_VIDEO_VSYNC",
			_scelte_si_no("VSync", func(): return GameManager.vsync, _su_vsync))
	_aggiungi_riga(griglia, "EtichettaRisoluzione", "UI_VIDEO_RESOLUTION", _tendina_risoluzione())

	vb.add_child(_stacco(60))

	# in fondo: i Riconoscimenti (scripts/credits_screen.gd) e Indietro
	var fondo := HBoxContainer.new()
	fondo.alignment = BoxContainer.ALIGNMENT_CENTER
	fondo.add_theme_constant_override("separation", 40)
	vb.add_child(fondo)
	_crediti = Button.new()
	_crediti.name = "Riconoscimenti"
	_crediti.custom_minimum_size = Vector2(420, 96)
	_crediti.add_theme_font_size_override("font_size", 44)
	_crediti.pressed.connect(_apri_crediti)
	fondo.add_child(_crediti)
	_indietro = Button.new()
	_indietro.name = "Indietro"
	_indietro.custom_minimum_size = Vector2(360, 96)
	_indietro.add_theme_font_size_override("font_size", 44)
	_indietro.pressed.connect(chiudi)
	fondo.add_child(_indietro)

	_aggiorna_testi()
	_aggiorna_selezione()

# Una riga di impostazione: l'etichetta nella prima colonna, i pulsanti nella seconda.
func _aggiungi_riga(griglia: GridContainer, nome: String, chiave: String, comandi: Array) -> void:
	var et := Label.new()
	et.name = nome
	et.add_theme_font_size_override("font_size", 44)
	et.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	et.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	et.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_etichette[et] = chiave
	griglia.add_child(et)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	for c in comandi:
		hb.add_child(c)
	griglia.add_child(hb)

# Un pulsante di una riga a scelta unica. Il NOME del nodo e' un identificatore (i test lo
# cercano: non deve dipendere dalla lingua in corso).
func _pulsante_scelta(nome: String, gruppo: ButtonGroup, premuto: bool, larghezza: int) -> Button:
	var b := Button.new()
	b.name = nome
	b.toggle_mode = true
	b.button_group = gruppo
	b.button_pressed = premuto
	b.custom_minimum_size = Vector2(larghezza, 96)
	b.add_theme_font_size_override("font_size", 40)
	return b

# Una riga Si'/No (schermo intero, V-Sync).
func _scelte_si_no(nome: String, attuale: Callable, su_scelta: Callable) -> Array:
	var gruppo := ButtonGroup.new()
	var pulsanti := {}
	for valore in [true, false]:
		var b := _pulsante_scelta(nome + ("Si" if valore else "No"), gruppo, valore == attuale.call(), 180)
		b.set_meta("chiave", "UI_ON" if valore else "UI_OFF")
		b.toggled.connect(func(premuto: bool):
			if premuto and valore != attuale.call():
				su_scelta.call(valore)
				_aggiorna_selezione())
		pulsanti[valore] = b
		_testi_si_no.append(b)
	_righe.append({"pulsanti": pulsanti, "attuale": attuale})
	return pulsanti.values()

# La dimensione della FINESTRA: una tendina (sono troppe per una fila di pulsanti; le frecce
# < > al proprietario non piacevano), solo quelle che stanno nello schermo. A schermo intero
# non conta (la finestra e' lo schermo) e la tendina si spegne, visibilmente.
# NON e' l'OptionButton di Godot: il suo elenco aveva un altro aspetto (pallini, freccetta
# minuscola) e si apriva sempre in giu', anche fuori dallo schermo quando la finestra e'
# grande quanto lo schermo (proprietario: "si vede malissimo e va fuori dallo schermo").
# Questo elenco ha i riquadri degli altri pulsanti e si apre dove c'e' posto (_apri_elenco_ris).
func _tendina_risoluzione() -> Array:
	_tendina_ris = Button.new()
	_tendina_ris.name = "Risoluzione"
	_tendina_ris.custom_minimum_size = Vector2(360, 96)
	_tendina_ris.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_tendina_ris.add_theme_font_size_override("font_size", 40)
	for voce in ["normal", "focus", "disabled"]:
		_tendina_ris.add_theme_stylebox_override(voce, _cornice(false))
	for voce in ["hover", "pressed"]:       # sotto il mouse si accende: si capisce che si apre
		_tendina_ris.add_theme_stylebox_override(voce, _cornice(true))
	_tendina_ris.add_theme_color_override("font_disabled_color", Color(0.3, 0.3, 0.3))
	_tendina_ris.draw.connect(_disegna_freccia)
	_tendina_ris.pressed.connect(_apri_elenco_ris)
	return [_tendina_ris]

# Il triangolino della tendina, disegnato (un glifo non e' detto che ci sia nel font).
func _disegna_freccia() -> void:
	var s := _tendina_ris.size
	var col := Color(0.3, 0.3, 0.3) if _tendina_ris.disabled else Color(0.85, 0.85, 0.85)
	var c := Vector2(s.x - 34, s.y / 2)
	_tendina_ris.draw_colored_polygon(PackedVector2Array([
			c + Vector2(-12, -6), c + Vector2(12, -6), c + Vector2(0, 8)]), col)

# Apre l'elenco delle dimensioni sotto la tendina, o sopra se sotto non c'e' posto nella
# parte VISIBILE della finestra (una finestra grande quanto lo schermo ha il fondo sotto la
# barra delle applicazioni); se non ci sta da nessuna parte, scorre. Un velo trasparente
# dietro lo chiude cliccando fuori.
func _apri_elenco_ris() -> void:
	if _elenco_ris != null:
		_chiudi_elenco_ris()
		return
	_lista_ris = GameManager.risoluzioni_possibili()
	var scelto := _indice_risoluzione(_lista_ris)
	var velo := Control.new()
	velo.name = "ElencoRisoluzioni"
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	velo.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed:
			_chiudi_elenco_ris())
	_radice.add_child(velo)
	_elenco_ris = velo

	var pannello := PanelContainer.new()
	var fondo := _cornice(false)
	fondo.bg_color = Color(0.05, 0.05, 0.05)
	fondo.border_color = Color(0.6, 0.6, 0.6)
	fondo.set_content_margin_all(8)
	pannello.add_theme_stylebox_override("panel", fondo)
	velo.add_child(pannello)
	var scorri := ScrollContainer.new()
	scorri.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pannello.add_child(scorri)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	scorri.add_child(vb)
	var voce_scelta: Button = null
	for k in _lista_ris.size():
		var b := Button.new()
		b.name = "Ris%dx%d" % [_lista_ris[k].x, _lista_ris[k].y]
		b.text = tr("UI_RESOLUTION_FMT") % [_lista_ris[k].x, _lista_ris[k].y]
		b.custom_minimum_size = Vector2(_tendina_ris.size.x - 16, 68)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 36)
		var questa := k == scelto
		var col := Color(1, 1, 1) if questa else Color(0.7, 0.7, 0.7)
		for v in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(v, col)
		for v in ["normal", "focus"]:
			b.add_theme_stylebox_override(v, _cornice(questa))
		for v in ["hover", "pressed"]:
			b.add_theme_stylebox_override(v, _cornice(true))
		b.pressed.connect(_su_risoluzione.bind(k))
		vb.add_child(b)
		if questa:
			voce_scelta = b

	# dove metterlo: sotto se ci sta, altrimenti dalla parte con piu' spazio, e se serve scorre
	var area := _area_visibile().grow(-12)
	var r := _tendina_ris.get_global_rect()
	var alto := 16.0 + _lista_ris.size() * 74.0 - 6.0
	var sotto := area.end.y - (r.end.y + 4)
	var sopra := (r.position.y - 4) - area.position.y
	var h := alto
	var y := r.end.y + 4
	if alto > sotto:
		if sopra >= sotto:
			h = minf(alto, sopra)
			y = r.position.y - 4 - h
		else:
			h = sotto
	scorri.custom_minimum_size = Vector2(0, h - 16)
	pannello.position = Vector2(r.position.x, y)
	pannello.size = Vector2(r.size.x, h)
	if voce_scelta != null:
		scorri.ensure_control_visible.call_deferred(voce_scelta)

func _chiudi_elenco_ris() -> void:
	if _elenco_ris != null:
		_elenco_ris.queue_free()
		_elenco_ris = null

# La parte della finestra che si vede davvero (dentro lo spazio utile dello schermo), in
# coordinate di questa schermata. Se non si riesce a calcolarla: tutta la finestra.
func _area_visibile() -> Rect2:
	var vp := get_viewport().get_visible_rect()
	var win := Rect2(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	var utile := Rect2(DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()))
	var vis := win.intersection(utile)
	if vis.size.x <= 0.0 or vis.size.y <= 0.0:
		return vp
	var inv := get_viewport().get_screen_transform().affine_inverse()
	var a: Vector2 = inv * (vis.position - win.position)
	var b: Vector2 = inv * (vis.end - win.position)
	var out := Rect2(a, b - a).intersection(vp)
	return out if out.size.y > 200.0 else vp

func _su_risoluzione(indice: int) -> void:
	_chiudi_elenco_ris()
	if _lista_ris[indice] != GameManager.risoluzione_attuale():
		GameManager.set_risoluzione(_lista_ris[indice])
	_aggiorna_selezione()

# Dove sta la finestra di adesso nella lista; se non c'e' (mai scelta, finestra trascinata),
# la piu' grande che non la supera.
func _indice_risoluzione(lista: Array[Vector2i]) -> int:
	var attuale := GameManager.risoluzione_attuale()
	var idx := 0
	for k in lista.size():
		if lista[k] == attuale:
			return k
		if lista[k].x <= attuale.x and lista[k].y <= attuale.y:
			idx = k
	return idx

# Un pulsante per lingua. Il NOME del nodo e' il codice della lingua (identificatore:
# i test lo cercano e non deve dipendere dalla lingua in corso), il TESTO e' l'endonimo
# -- "Italiano", non "Italian": in un elenco di lingue ognuna si scrive nella propria,
# o chi cerca la sua non la riconosce.
func _pulsanti_lingua() -> Array:
	var gruppo := ButtonGroup.new()
	var out: Array = []
	for codice in GameManager.LINGUE:
		var c := str(codice)
		var b := _pulsante_scelta(c, gruppo, c == GameManager.lingua, 260)
		b.text = GameManager.nome_lingua(c)
		b.toggled.connect(_su_lingua.bind(c))
		_pulsanti[c] = b
		out.append(b)
	_righe.append({"pulsanti": _pulsanti, "attuale": func(): return GameManager.lingua})
	return out

# Quale lingua e' attiva si disegna A MANO, testo E cornice, invece di lasciarlo allo
# stato "premuto" del tema di base: quello scurisce appena il pulsante, e nello scatto
# di prova il pulsante scelto perdeva persino la cornice, sembrando testo qualunque
# accanto a uno vero. Tutte le varianti (premuto, sopra, fuoco) prendono lo stesso
# aspetto, o passarci il mouse cambierebbe il significato di quello che si vede.
func _aggiorna_selezione() -> void:
	# la tendina della finestra: scrive quella di adesso, spenta a schermo intero
	var lista := GameManager.risoluzioni_possibili()
	var i := _indice_risoluzione(lista)
	_tendina_ris.text = tr("UI_RESOLUTION_FMT") % [lista[i].x, lista[i].y]
	_tendina_ris.disabled = GameManager.schermo_intero
	_tendina_ris.queue_redraw()   # la freccia cambia colore se spenta
	for riga in _righe:
		var scelto = riga["attuale"].call()
		for valore in riga["pulsanti"]:
			var b: Button = riga["pulsanti"][valore]
			var attiva: bool = valore == scelto
			b.set_pressed_no_signal(attiva)
			var col := Color(1.0, 1.0, 1.0) if attiva else Color(0.55, 0.55, 0.55)
			if b.disabled:
				col = Color(0.3, 0.3, 0.3)
			for voce in ["font_color", "font_pressed_color", "font_hover_color",
					"font_hover_pressed_color", "font_focus_color", "font_disabled_color"]:
				b.add_theme_color_override(voce, col)
			for voce in ["normal", "pressed", "hover", "focus", "disabled"]:
				b.add_theme_stylebox_override(voce, _cornice(attiva and not b.disabled))

# La cornice di un pulsante lingua: piena e chiara quella scelta, spenta le altre.
func _cornice(attiva: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.22, 0.22) if attiva else Color(0.07, 0.07, 0.07)
	sb.border_color = Color(0.95, 0.95, 0.95) if attiva else Color(0.3, 0.3, 0.3)
	sb.set_border_width_all(3 if attiva else 1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	return sb

func _stacco(altezza: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, altezza)
	return s

# ---------------- reazioni ----------------

# I Riconoscimenti si aprono SOPRA le Impostazioni (layer piu' alto); chiusi, si torna qui.
func _apri_crediti() -> void:
	if _schermata_crediti != null and is_instance_valid(_schermata_crediti):
		return
	_schermata_crediti = CreditsScreen.new()
	_schermata_crediti.layer = layer + 1
	add_child(_schermata_crediti)

func _su_schermo_intero(on: bool) -> void:
	GameManager.set_schermo_intero(on)

func _su_vsync(on: bool) -> void:
	GameManager.set_vsync(on)

func _su_lingua(premuto: bool, codice: String) -> void:
	if not premuto or codice == GameManager.lingua:
		return
	GameManager.set_lingua(codice)      # cambia E salva: qui e' una scelta di chi gioca
	_aggiorna_testi()
	_aggiorna_selezione()
	lingua_cambiata.emit()

# Le scritte di QUESTA schermata dopo un cambio di lingua. I nomi delle lingue no:
# sono endonimi e restano come sono.
func _aggiorna_testi() -> void:
	_titolo.text = tr("UI_OPTIONS_TITLE")
	for et in _etichette:
		(et as Label).text = tr(_etichette[et])
	for b in _testi_si_no:
		b.text = tr(str(b.get_meta("chiave")))
	_crediti.text = tr("UI_CREDITS")
	_indietro.text = tr("UI_BACK")
