class_name DebugPanel
extends CanvasLayer

# Il PANNELLO DI DEBUG (F12, DEV-ONLY: da togliere prima del rilascio). Nato come etichetta
# con le chiavi; il proprietario (18/10/2026) non riusciva a far comparire a comando tutte
# le minacce, quindi ha i PULSANTI per ogni fantasma, il fastidio, ogni virus, gli
# affacci, Ghosty, gli interruttori e il PC dritto al desktop, piu' uno STATO che si
# aggiorna da solo e una riga con l'esito dell'ultimo pulsante.
# Rifatto il 28/11/2026 (proprietario: "ora e' un casino, non si capisce molto, rendila
# piu' semplice"): in alto SEMPRE le chiavi e i tre interruttori, sotto TRE SCHEDE (Room,
# PC, Viruses) ognuna col suo stato e i suoi pulsanti, invece di un muro unico. Colori:
# verde = acceso/riuscito, rosso = spento/rifiutato, ambra = chiavi e scheda aperta.
# Tutto il testo e' in INGLESE, come tutto il debug, e non passa dal CSV.
# Il mouse sopra il pannello e' del pannello: player.gd lo chiede a
# GameManager.debug_sotto_mouse e non lo gira ne' alla stanza ne' al PC (senza, un clic su
# un pulsante cliccava anche il desktop sotto, e passarci sopra girava la visuale). I
# pulsanti non prendono il FUOCO: altrimenti lo spazio scritto nel Blocco note li premerebbe.
# I registi li trova per GRUPPO ("regista_stanza", "regista_virus": se li mettono loro nel
# _ready), non per scena corrente -- i test aggiungono la stanza alla radice. Fuori dalla
# stanza i pulsanti rispondono "not in the room" invece di rompersi.

const LARGO := 620.0
const MARGINE := 16.0
const SOTTO_FPS := 44.0        # in alto a destra c'e' il contatore FPS (layer 70): si parte sotto
const C_FONDO := Color("#1b1f2a")
const C_BORDO := Color("#3a4153")
const C_TESTO := Color("#e4e7ee")
const C_SPENTO := Color("#8b92a5")
const C_AMBRA := Color("#f2c14e")
const C_OK := Color("#62d67f")
const C_NO := Color("#ff7a66")
const C_BOTTONE := Color("#2a3042")
const TASTI := "F8 PC threats   F9 start a virus   Shift+F9 nuisance   F10 die   F11 room threats   F12 close"
const SCHEDE := ["Room", "PC", "Viruses"]
const OGNI := 0.25             # ogni quanto si riscrive lo stato (s)
const REGISTA_VIRUS := preload("res://scripts/threats/virus_director.gd")   # le sue costanti

var _box: PanelContainer = null
var _seme: Label = null
var _chiavi: VBoxContainer = null
var _corpo: VBoxContainer = null          # tutto tranne testa e chiavi: lo nasconde "-"
var _btn_compatto: Button = null
var _btn_stanza: Button = null
var _btn_pc: Button = null
var _btn_siti: Button = null
var _btn_sopra: Button = null           # il fantasma sopra le finestre (scheda Viruses)
var _linguette: Array = []                # i pulsanti delle schede
var _pagine: Array = []                   # il contenuto delle schede, stesso ordine
var _stato_stanza: Label = null
var _stato_pc: Label = null
var _stato_virus: Label = null
var _esito: Label = null
var _passo := 0.0

func _ready() -> void:
	name = "DebugKeysLayer"
	layer = 30                       # sopra vista PC (10) e vittoria (20); sotto morte e pausa
	process_mode = Node.PROCESS_MODE_ALWAYS
	_costruisci()
	aggiorna()

func _process(delta: float) -> void:
	_passo -= delta
	if _passo <= 0.0:
		_passo = OGNI
		aggiorna()

# Il mouse e' sopra il pannello? (player.gd: allora quel mouse non e' suo)
func sotto(pos: Vector2) -> bool:
	return _box != null and _box.visible and _box.get_global_rect().has_point(pos)

# Tutto il testo del pannello (etichette e pulsanti, anche delle schede chiuse), per i test.
func testo() -> String:
	var out := []
	for n in _box.find_children("*", "", true, false):
		if n is Label:
			out.append((n as Label).text)
		elif n is Button:
			out.append((n as Button).text)
	return "\n".join(out)

# Il pulsante con questo testo (per i test: "REAL" di una riga si cerca con riga_apparizione).
func pulsante(testo_btn: String) -> Button:
	for n in _box.find_children("*", "Button", true, false):
		if (n as Button).text == testo_btn:
			return n
	return null

# Il pulsante REAL della riga di un fantasma.
func riga_apparizione(tipo: String) -> Array:
	var r = _box.find_child("Riga_" + tipo, true, false)
	return [] if r == null else r.find_children("*", "Button", true, false)

func aggiorna() -> void:
	if _box == null:
		return
	_seme.text = "seed %d" % GameManager.run_seed
	_aggiorna_chiavi()
	_interruttore(_btn_stanza, "Room threats", GameManager.room_threats_enabled)
	_interruttore(_btn_pc, "PC threats", GameManager.pc_threats_enabled)
	_interruttore(_btn_siti, "All sites", GameManager.debug_tutti_i_siti, C_AMBRA, C_SPENTO)
	_interruttore(_btn_sopra, "Ghost above windows", GameManager.fantasma_sopra_finestre, C_AMBRA, C_SPENTO)
	_corpo.visible = not GameManager.debug_compatto
	_btn_compatto.text = "+" if GameManager.debug_compatto else "-"
	for i in range(_pagine.size()):
		(_pagine[i] as Control).visible = i == GameManager.debug_scheda
		(_linguette[i] as Button).set_pressed_no_signal(i == GameManager.debug_scheda)
	var td = _regista_stanza()
	var vd = _regista_virus()
	_stato_stanza.text = td.stato_debug() if td != null else "Not in the room."
	_stato_pc.text = _testo_stato_pc(vd)
	_stato_virus.text = vd.stato_debug() if vd != null else "Not in the room."
	_esito.visible = _esito.text != ""
	_disponi()

# In alto a DESTRA (a sinistra ci sono le icone del desktop). A mano e non con le ancore:
# quando il pannello si compatta o cambia scheda deve accorciarsi restando attaccato al bordo.
func _disponi() -> void:
	_box.reset_size()
	var largo_schermo: float = _box.get_viewport_rect().size.x
	_box.position = Vector2(largo_schermo - _box.size.x - MARGINE, SOTTO_FPS)

# Le quattro righe delle chiavi: codice, tipo, dove sta (il dove va a capo, il codice no).
func _aggiorna_chiavi() -> void:
	for i in range(_chiavi.get_child_count()):
		var riga := _chiavi.get_child(i)
		(riga.get_child(0) as Label).text = GameManager.key_label(i + 1)
		(riga.get_child(1) as Label).text = GameManager.key_kind(i + 1)
		(riga.get_child(2) as Label).text = str(GameManager.key_hints.get(i + 1, "-"))

# ---------------- costruzione ----------------

func _costruisci() -> void:
	_box = PanelContainer.new()
	_box.name = "DebugPanel"
	_box.custom_minimum_size.x = LARGO
	_box.add_theme_stylebox_override("panel", _stile(C_FONDO, C_BORDO, 6, 12))
	add_child(_box)
	var v := _colonna(8)
	_box.add_child(v)

	# testa: titolo, seme, Die, compatta
	var testa := HBoxContainer.new()
	testa.add_theme_constant_override("separation", 10)
	v.add_child(testa)
	testa.add_child(_etichetta("Debug", C_TESTO, 20, "sans_b"))
	_seme = _etichetta("", C_SPENTO, 16)
	_seme.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	testa.add_child(_seme)
	var muori := _bottone("Die", _muori)
	muori.add_theme_color_override("font_color", C_NO)
	muori.tooltip_text = "game over now (F10)"
	testa.add_child(muori)
	_btn_compatto = _bottone("-", _compatta)
	_btn_compatto.custom_minimum_size.x = 30
	_btn_compatto.tooltip_text = "show only the keys"
	testa.add_child(_btn_compatto)

	# le chiavi: sempre visibili, anche compatto
	_chiavi = _colonna(6)
	v.add_child(_chiavi)
	for i in range(GameManager.KEY_COUNT):
		var riga := HBoxContainer.new()
		riga.add_theme_constant_override("separation", 10)
		var codice := _etichetta("", C_AMBRA, 17, "mono_b")
		codice.custom_minimum_size.x = 82
		riga.add_child(codice)
		var tipo := _etichetta("", C_SPENTO, 13)
		tipo.custom_minimum_size.x = 56
		riga.add_child(tipo)
		var dove := _etichetta("", C_TESTO, 15, "mono")
		dove.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dove.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		riga.add_child(dove)
		_chiavi.add_child(riga)

	_corpo = _colonna(8)
	v.add_child(_corpo)
	_btn_stanza = _bottone("", _cambia_stanza)
	_btn_pc = _bottone("", _cambia_pc)
	_btn_siti = _bottone("", _cambia_siti)
	_btn_siti.tooltip_text = "every site of the catalog answers and the portal lists them all"
	_corpo.add_child(_riga([_btn_stanza, _btn_pc, _btn_siti]))

	# le schede
	var linguette := HBoxContainer.new()
	linguette.add_theme_constant_override("separation", 2)
	_corpo.add_child(linguette)
	for i in range(SCHEDE.size()):
		var l := _bottone(SCHEDE[i], _apri_scheda.bind(i))
		l.toggle_mode = true
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		linguette.add_child(l)
		_linguette.append(l)
	_pagine = [_scheda_stanza(), _scheda_pc(), _scheda_virus()]
	var fondo := PanelContainer.new()
	fondo.add_theme_stylebox_override("panel", _stile(C_FONDO.darkened(0.25), C_BORDO, 4, 10))
	_corpo.add_child(fondo)
	var pila := _colonna(0)
	fondo.add_child(pila)
	for p in _pagine:
		pila.add_child(p)

	_esito = _etichetta("", C_OK, 16)
	_esito.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_corpo.add_child(_esito)
	var tasti := _etichetta(TASTI, C_SPENTO, 13)
	tasti.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_corpo.add_child(tasti)

func _scheda_stanza() -> VBoxContainer:
	var s := _colonna(8)
	_stato_stanza = _stato()
	s.add_child(_stato_stanza)
	s.add_child(_riga([_bottone("Jester: peek now", _affaccio.bind("jester")),
			_bottone("HaloMan: peek now", _affaccio.bind("halo")),
			_bottone("Peek: send away", _via)]))
	s.add_child(_riga([_bottone("Ghosty: come now", _ghosty), _bottone("Ghosty: go away", _ghosty_via)]))
	s.add_child(_nota("Jester and HaloMan never peek together. Ghosty comes from behind: turn around and light it."))
	return s

func _scheda_pc() -> VBoxContainer:
	var s := _colonna(8)
	_stato_pc = _stato()
	s.add_child(_stato_pc)
	s.add_child(_riga([_bottone("Boot to desktop", _al_desktop), _bottone("Power off", _spegni),
			_bottone("Open the portal", _apri_portale)]))
	s.add_child(_nota("Boot to desktop skips the boot and the password."))
	return s

func _scheda_virus() -> VBoxContainer:
	var s := _colonna(8)
	_stato_virus = _stato()
	s.add_child(_stato_virus)
	s.add_child(_riga([_bottone("Lethal (random)", _virus.bind("mortale", "")),
			_bottone("Nuisance: darkness", _virus.bind("fastidio", "")),
			_bottone("YouAreStupid", _virus.bind("stupido", "")),
			_bottone("Blue screen", _virus.bind("crash", ""))]))
	s.add_child(_riga([_bottone("Stop current", _ferma), _bottone("Next virus: no wait", _azzera.bind(false)),
			_bottone("Next nuisance: no wait", _azzera.bind(true))]))
	s.add_child(_nota("Ghost: kills in %d s unless the PC is switched off. Nuisance: gone in %.1f-%.1f s." % [
			int(VirusMortale.DURATA), REGISTA_VIRUS.FASTIDIO_DURATA[0], REGISTA_VIRUS.FASTIDIO_DURATA[1]]))
	for t in Apparizione.FANTASMI:
		s.add_child(_riga_apparizione(str(t)))
	_btn_sopra = _bottone("", _cambia_sopra)
	_btn_sopra.tooltip_text = "the ghost shows above the windows instead of on the wallpaper (next ghost)"
	s.add_child(_riga([_btn_sopra]))
	return s

func _riga_apparizione(t: String) -> HBoxContainer:
	var riga := HBoxContainer.new()
	riga.name = "Riga_" + t
	riga.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nome := _etichetta("ghost: " + t, C_TESTO, 16)
	nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	riga.add_child(nome)
	var vero := _bottone("REAL", _virus.bind("mortale", t))
	vero.add_theme_color_override("font_color", C_NO)
	riga.add_child(vero)
	return riga

# ---------------- mattoni ----------------

func _stile(fondo: Color, bordo: Color, raggio: int, margine: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fondo
	sb.border_color = bordo
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(raggio)
	sb.set_content_margin_all(margine)
	return sb

func _colonna(spazio: int) -> VBoxContainer:
	var c := VBoxContainer.new()
	c.add_theme_constant_override("separation", spazio)
	return c

func _riga(pulsanti: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for b in pulsanti:
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	return h

func _stato() -> Label:
	var l := _etichetta("", C_TESTO, 15, "mono")
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _nota(t: String) -> Label:
	var l := _etichetta(t, C_SPENTO, 14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _etichetta(t: String, col: Color, size: int, font := "sans") -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", Win95.font(font))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _bottone(t: String, azione: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE        # lo spazio e l'Invio restano al gioco
	b.add_theme_font_override("font", Win95.font("sans"))
	b.add_theme_font_size_override("font_size", 15)
	var normale := _stile(C_BOTTONE, C_BOTTONE, 4, 6)
	normale.content_margin_top = 4
	normale.content_margin_bottom = 4
	var sopra := normale.duplicate() as StyleBoxFlat
	sopra.bg_color = C_BOTTONE.lightened(0.15)
	sopra.border_color = sopra.bg_color
	var premuto := normale.duplicate() as StyleBoxFlat
	premuto.bg_color = C_AMBRA
	premuto.border_color = C_AMBRA
	b.add_theme_stylebox_override("normal", normale)
	b.add_theme_stylebox_override("hover", sopra)
	b.add_theme_stylebox_override("pressed", premuto)
	b.add_theme_stylebox_override("hover_pressed", premuto)
	for k in ["font_color", "font_hover_color"]:
		b.add_theme_color_override(k, C_TESTO)
	for k in ["font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, C_FONDO)
	b.pressed.connect(azione)
	return b

# Un interruttore dice il suo stato a parole E a colori: verde acceso, rosso spento.
# (All sites e' spento di norma: grigio, e ambra quando e' acceso.)
func _interruttore(b: Button, nome: String, on: bool, c_on := C_OK, c_off := C_NO) -> void:
	b.text = "%s: %s" % [nome, "ON" if on else "OFF"]
	var col: Color = c_on if on else c_off
	b.add_theme_color_override("font_color", col)
	b.add_theme_color_override("font_hover_color", col)

# ---------------- stato ----------------

func _testo_stato_pc(vd) -> String:
	var os = _os()
	var pc := "off"
	if GameManager.pc_on:
		if os != null and os._booting:
			pc = "on, booting"
		elif not GameManager.logged_in:
			pc = "on, at the login"
		else:
			pc = "on, at the desktop"
	var dove := "-"
	if vd != null and vd.player != null:
		dove = "inside the PC" if vd.player.is_in_pc() else "in the room, looking " + vd.player.current_view()
	return "PC: %s\nPlayer: %s" % [pc, dove]

func _dici(t: String, ok: bool) -> void:
	_esito.text = t
	_esito.add_theme_color_override("font_color", C_OK if ok else C_NO)
	print("[Debug] " + t)
	aggiorna()

func _regista_virus():
	return get_tree().get_first_node_in_group("regista_virus")

func _regista_stanza():
	return get_tree().get_first_node_in_group("regista_stanza")

func _os():
	var vd = _regista_virus()
	return null if vd == null else vd.os

# ---------------- azioni ----------------

func _compatta() -> void:
	GameManager.debug_compatto = not GameManager.debug_compatto
	aggiorna()

func _apri_scheda(i: int) -> void:
	GameManager.debug_scheda = i
	aggiorna()

func _cambia_stanza() -> void:
	GameManager.imposta_minacce_stanza(not GameManager.room_threats_enabled)
	_dici("room threats " + ("ON" if GameManager.room_threats_enabled else "OFF"), true)

func _cambia_sopra() -> void:
	GameManager.fantasma_sopra_finestre = not GameManager.fantasma_sopra_finestre
	_dici("ghost " + ("above the windows" if GameManager.fantasma_sopra_finestre else "on the wallpaper"), true)

func _cambia_pc() -> void:
	GameManager.imposta_minacce_pc(not GameManager.pc_threats_enabled)
	_dici("PC threats " + ("ON" if GameManager.pc_threats_enabled else "OFF"), true)

# Tutti i siti del catalogo raggiungibili (e nel portale), non solo quelli estratti: per
# guardarli tutti in una partita sola. Le pagine gia' aperte si aggiornano con "Aggiorna".
func _cambia_siti() -> void:
	GameManager.debug_tutti_i_siti = not GameManager.debug_tutti_i_siti
	_dici("all sites " + ("ON: %d sites answer" % CatalogoSiti.SITI.size()
			if GameManager.debug_tutti_i_siti else "OFF: only tonight's %d" % WebRuntime.sites().size()), true)

func _apri_portale() -> void:
	var os = _os()
	if os == null:
		_dici("refused: not in the room", false)
	elif not GameManager.pc_on or not GameManager.logged_in or os._booting:
		_dici("refused: the PC is not at the desktop (use Boot to desktop)", false)
	else:
		os.open_app("browser", "start")
		_dici("browser opened on the portal", true)

func _muori() -> void:
	GameManager.game_over("debug")

func _al_desktop() -> void:
	var os = _os()
	if os == null:
		_dici("refused: not in the room", false)
		return
	os.salta_al_desktop()
	_dici("PC on, at the desktop", true)

func _spegni() -> void:
	var os = _os()
	if os == null:
		_dici("refused: not in the room", false)
	elif not GameManager.pc_on:
		_dici("refused: the PC is already off", false)
	else:
		os.power_off()
		_dici("PC off", true)

func _affaccio(chi: String) -> void:
	var td = _regista_stanza()
	var no: String = "not in the room" if td == null else td.forza_affaccio(chi)
	if no == "":
		_dici("%s peeks now" % ("HaloMan" if chi == "halo" else "the jester"), true)
	else:
		_dici("refused: " + no, false)

func _via() -> void:
	var td = _regista_stanza()
	var no: String = "not in the room" if td == null else td.allontana()
	if no == "":
		_dici("sent away (safe window)", true)
	else:
		_dici("refused: " + no, false)

func _ghosty() -> void:
	var td = _regista_stanza()
	var no: String = "not in the room" if td == null else td.ghosty_forza()
	if no == "":
		_dici("Ghosty is coming (turn around and light it)", true)
	else:
		_dici("refused: " + no, false)

func _ghosty_via() -> void:
	var td = _regista_stanza()
	var no: String = "not in the room" if td == null else td.ghosty_allontana()
	if no == "":
		_dici("Ghosty went away", true)
	else:
		_dici("refused: " + no, false)

func _virus(tipo: String, apparizione: String) -> void:
	var vd = _regista_virus()
	var no: String = "not in the room" if vd == null else vd.forza_debug(tipo, apparizione)
	if no == "":
		_dici("started: " + vd.evento_debug(), true)
	else:
		_dici("refused: " + no, false)

func _ferma() -> void:
	var vd = _regista_virus()
	var no: String = "not in the room" if vd == null else vd.ferma_debug()
	if no == "":
		_dici("virus stopped", true)
	else:
		_dici("refused: " + no, false)

func _azzera(fastidio: bool) -> void:
	var vd = _regista_virus()
	if vd == null:
		_dici("refused: not in the room", false)
		return
	vd.azzera_attesa(fastidio)
	_dici("next %s: no wait - it starts once the player has been inside the PC for %d s" % [
			"nuisance" if fastidio else "virus", int(vd.ENTRATA_MIN)], true)
