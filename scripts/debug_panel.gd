class_name DebugPanel
extends CanvasLayer

# Il PANNELLO DI DEBUG (F12, DEV-ONLY: da togliere prima del rilascio). Era solo
# un'etichetta con le chiavi; il proprietario (18/10/2026) non riusciva a far comparire a
# comando tutte le minacce -- F9 gira fra i tre virus e l'apparizione del mortale esce a
# caso -- quindi ora ha i PULSANTI: ogni apparizione vera o falsa, ogni virus, l'affaccio
# del Jester, gli interruttori delle minacce, il PC dritto al desktop; e uno STATO che si
# aggiorna da solo (cosa fa il Jester, fra quanto il prossimo virus, e PERCHE' un virus
# adesso non puo' partire), piu' una riga con l'esito dell'ultimo pulsante.
# Tutto il testo e' in INGLESE, come tutto il debug, e non passa dal CSV.
# Il mouse sopra il pannello e' del pannello: player.gd lo chiede a
# GameManager.debug_sotto_mouse e non lo gira ne' alla stanza ne' al PC (senza, un clic su
# un pulsante cliccava anche il desktop sotto, e passarci sopra girava la visuale). I
# pulsanti non prendono il FUOCO: altrimenti lo spazio scritto nel Blocco note li premerebbe.
# I registi li trova per GRUPPO ("regista_stanza", "regista_virus": se li mettono loro nel
# _ready), non per scena corrente -- i test aggiungono la stanza alla radice. Fuori dalla
# stanza i pulsanti rispondono "not in the room" invece di rompersi.

const LARGO := 540.0
const MARGINE := 16.0
const FONT_SIZE := 15
const C_TESTO := Color(0.95, 0.95, 0.8)
const C_TITOLO := Color(0.95, 0.8, 0.25)
const C_GRIGIO := Color(0.6, 0.6, 0.55)
const C_OK := Color(0.55, 0.95, 0.55)
const C_NO := Color(1.0, 0.55, 0.45)
const TASTI := "F8 PC threats  F9 start a virus  Shift+F9 false alarm\nF10 die  F11 room threats  F12 close"
const OGNI := 0.25             # ogni quanto si riscrive lo stato (s)
const REGISTA_VIRUS := preload("res://scripts/threats/virus_director.gd")   # le sue costanti

var etichetta_chiavi: Label = null   # GameManager._keys_label punta qui (i test la leggono)
var _box: PanelContainer = null
var _corpo: VBoxContainer = null
var _stato: Label = null
var _esito: Label = null
var _btn_stanza: Button = null
var _btn_pc: Button = null
var _btn_siti: Button = null
var _btn_compatto: Button = null
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

# Tutto il testo del pannello (etichette e pulsanti), per i test.
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

# I due pulsanti REAL/FALSE della riga di un'apparizione.
func riga_apparizione(tipo: String) -> Array:
	var r = _box.find_child("Riga_" + tipo, true, false)
	return [] if r == null else r.find_children("*", "Button", true, false)

func aggiorna() -> void:
	if etichetta_chiavi == null:
		return
	etichetta_chiavi.text = GameManager.keys_report()
	_btn_stanza.text = "Room threats: " + ("ON" if GameManager.room_threats_enabled else "OFF")
	_btn_pc.text = "PC threats: " + ("ON" if GameManager.pc_threats_enabled else "OFF")
	_btn_siti.text = "All sites: " + ("ON" if GameManager.debug_tutti_i_siti else "OFF")
	_corpo.visible = not GameManager.debug_compatto
	_btn_compatto.text = "+" if GameManager.debug_compatto else "-"
	_stato.text = _testo_stato()
	_disponi()

# In alto a DESTRA (a sinistra ci sono le icone del desktop). A mano e non con le ancore:
# quando il pannello si compatta deve accorciarsi restando attaccato al bordo.
func _disponi() -> void:
	_box.reset_size()
	var largo_schermo: float = _box.get_viewport_rect().size.x
	_box.position = Vector2(largo_schermo - _box.size.x - MARGINE, MARGINE)

# ---------------- costruzione ----------------

func _costruisci() -> void:
	_box = PanelContainer.new()
	_box.name = "DebugPanel"
	_box.custom_minimum_size.x = LARGO
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.04, 0.06, 0.92)
	sb.border_color = Color(0.9, 0.8, 0.2)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(10)
	_box.add_theme_stylebox_override("panel", sb)
	add_child(_box)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	_box.add_child(v)

	var testa := HBoxContainer.new()
	v.add_child(testa)
	var titolo := _etichetta("DEBUG", C_TITOLO)
	titolo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	testa.add_child(titolo)
	_btn_compatto = _bottone("-", _compatta)
	_btn_compatto.tooltip_text = "show only the keys"
	testa.add_child(_btn_compatto)
	etichetta_chiavi = _etichetta("", C_TESTO)
	v.add_child(etichetta_chiavi)

	_corpo = VBoxContainer.new()
	_corpo.add_theme_constant_override("separation", 5)
	v.add_child(_corpo)
	_sezione("STATUS")
	_stato = _etichetta("", C_TESTO)
	_corpo.add_child(_stato)

	_sezione("SWITCHES")
	_btn_stanza = _bottone("", _cambia_stanza)
	_btn_pc = _bottone("", _cambia_pc)
	_riga([_btn_stanza, _btn_pc, _bottone("Die", _muori)])

	_sezione("PC")
	_riga([_bottone("Boot to desktop", _al_desktop), _bottone("Power off", _spegni)])

	_sezione("WEB  (all sites = the whole catalog answers and the portal lists it)")
	_btn_siti = _bottone("", _cambia_siti)
	_riga([_btn_siti, _bottone("Open the portal", _apri_portale)])

	_sezione("ROOM  (Jester and HaloMan never together; Ghosty comes from behind)")
	_riga([_bottone("Jester: peek now", _affaccio.bind("jester")),
			_bottone("HaloMan: peek now", _affaccio.bind("halo")),
			_bottone("Peek: send away", _via)])
	_riga([_bottone("Ghosty: come now", _ghosty), _bottone("Ghosty: go away", _ghosty_via)])

	_sezione("VIRUSES  (start now, skipping the wait)")
	_riga([_bottone("Lethal (random)", _virus.bind("mortale", "")),
			_bottone("YouAreStupid", _virus.bind("stupido", "")),
			_bottone("Blue screen", _virus.bind("crash", ""))])
	_riga([_bottone("Stop current", _ferma), _bottone("Next virus: no wait", _azzera.bind(false)),
			_bottone("Next false alarm: no wait", _azzera.bind(true))])

	_sezione("APPARITIONS  REAL = lethal (%d s)  FALSE = gone in %.1f-%.1f s" % [
			int(VirusMortale.DURATA), REGISTA_VIRUS.FALSO_DURATA[0], REGISTA_VIRUS.FALSO_DURATA[1]])
	for t in Apparizione.TIPI:
		var riga := HBoxContainer.new()
		riga.name = "Riga_" + str(t)
		var nome := _etichetta(str(t) + ("" if Apparizione.PICCOLE.has(t) else "  (grave)"), C_TESTO)
		nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		riga.add_child(nome)
		riga.add_child(_bottone("REAL", _virus.bind("mortale", t)))
		riga.add_child(_bottone("FALSE", _virus.bind("falso", t)))
		_corpo.add_child(riga)

	_esito = _etichetta("", C_OK)
	_esito.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_corpo.add_child(_esito)
	v.add_child(_etichetta(TASTI, C_GRIGIO))

func _sezione(testo_sez: String) -> void:
	var l := _etichetta(testo_sez, C_TITOLO)
	_corpo.add_child(l)

func _riga(pulsanti: Array) -> void:
	var h := HBoxContainer.new()
	for b in pulsanti:
		(b as Button).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(b)
	_corpo.add_child(h)

func _etichetta(t: String, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", Win95.font("mono"))
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _bottone(t: String, azione: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE        # lo spazio e l'Invio restano al gioco
	b.add_theme_font_override("font", Win95.font("mono"))
	b.add_theme_font_size_override("font_size", FONT_SIZE - 1)
	b.pressed.connect(azione)
	return b

# ---------------- stato ----------------

func _testo_stato() -> String:
	var righe := []
	var os = _os()
	var pc := "OFF"
	if GameManager.pc_on:
		if os != null and os._booting:
			pc = "ON - booting"
		elif not GameManager.logged_in:
			pc = "ON - login"
		else:
			pc = "ON - desktop"
	var dove := "-"
	var vd = _regista_virus()
	if vd != null and vd.player != null:
		dove = "inside the PC" if vd.player.is_in_pc() else "in the room, looking " + vd.player.current_view()
	righe.append("PC: %s  |  player: %s" % [pc, dove])
	var td = _regista_stanza()
	righe.append(td.stato_debug() if td != null else "Room: - (not in the room)")
	righe.append(vd.stato_debug() if vd != null else "PC virus: - (not in the room)")
	return "\n".join(righe)

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

func _cambia_stanza() -> void:
	GameManager.imposta_minacce_stanza(not GameManager.room_threats_enabled)
	_dici("room threats " + ("ON" if GameManager.room_threats_enabled else "OFF"), true)

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

func _azzera(falso: bool) -> void:
	var vd = _regista_virus()
	if vd == null:
		_dici("refused: not in the room", false)
		return
	vd.azzera_attesa(falso)
	_dici("next %s: no wait - it starts once the player has been inside the PC for %d s" % [
			"false alarm" if falso else "virus", int(vd.ENTRATA_MIN)], true)
