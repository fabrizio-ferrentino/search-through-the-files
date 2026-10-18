class_name SchermoBlu
extends Control

# Lo SCHERMO BLU (M5, richiesta del proprietario: "piu' che virus vorrei dar fastidio al
# giocatore facendo crashare a caso il pc"). E' quello di Win95, in modalita' testo:
# fondo blu, il nome del sistema in un riquadro grigio, l'eccezione e "premere un tasto".
# Due gravita' (scelta del proprietario, "misto"):
#   - normale: un tasto chiude il programma in PRIMO PIANO e si torna al desktop;
#   - grave (piu' rara): il sistema e' fermo, un tasto RIAVVIA il PC (avvio + login di
#     nuovo, tutte le finestre perse).
# Il desktop lo apre (OSDesktop.schermo_blu) e decide cosa fare al tasto: qui c'e' solo
# la schermata. Si chiude SOLO coi tasti, come l'originale (in modalita' testo il mouse non
# c'era): i clic vengono mangiati, cosi' non arrivano alle finestre che stanno sotto.
# Niente CTRL+ALT+CANC nel testo: il sistema vero se lo prende prima del gioco, e una riga
# che promette una cosa che non funziona e' peggio di nessuna.

signal premuto(grave: bool)

const C_FONDO := Color("0000aa")       # il blu della modalita' testo VGA
const C_TESTO := Color("ffffff")
const C_GRIGIO := Color("aaaaaa")
const FONT_PX := 30                    # ~80 colonne su 1440 px, come lo schermo vero
const LAMPEGGIO := 0.5                 # il trattino del cursore, mezzo secondo acceso

# Pezzi del messaggio. Codici e moduli veri di Win95, scelti a caso: nessuno ha la forma
# di una chiave (cifra-trattino-quattro), che resta riservata alla caccia.
const ECCEZIONI := ["0E", "0D", "06", "0C"]
const MODULI := ["VMM(01)", "VWIN32(05)", "IFSMGR(01)", "VFAT(02)", "VXDLDR(03)", "NTKERN(04)"]

var grave := false
var _riga_fine: Label = null
var _testo_fine := ""
var _t := 0.0
var _fatto := false

func setup(e_grave: bool, rng: RandomNumberGenerator) -> void:
	grave = e_grave
	name = "SchermoBlu"
	# "and_offsets": il nodo e' gia' nell'albero, e set_anchors_preset da solo ricalcola gli
	# offset per TENERE la dimensione di adesso -- zero. Successo davvero: il testo c'era,
	# il fondo blu no (tests/virus_test, SI_VEDE_BLU).
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP     # i clic non passano alle finestre sotto
	focus_mode = Control.FOCUS_ALL

	var fondo := ColorRect.new()
	fondo.color = C_FONDO
	fondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	var mono: Font = Win95.font("mono")
	var w: float = get_parent_control().size.x if get_parent_control() != null else 1440.0
	var h: float = get_parent_control().size.y if get_parent_control() != null else 1080.0

	# il nome del sistema in negativo, al centro: grigio pieno, scritta blu
	var testa := Label.new()
	testa.text = " %s " % tr("BSOD_HEADER")
	testa.add_theme_font_override("font", mono)
	testa.add_theme_font_size_override("font_size", FONT_PX)
	testa.add_theme_color_override("font_color", C_FONDO)
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_GRIGIO
	testa.add_theme_stylebox_override("normal", sb)
	testa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(testa)
	var tw: float = mono.get_string_size(testa.text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_PX).x
	testa.position = Vector2(floorf((w - tw) * 0.5), floorf(h * 0.30))

	# messaggio, riga vuota e "premere un tasto" in COLONNA: quante righe occupi il messaggio
	# lo decide l'a capo, cioe' la lingua, e qui non si sa ancora (contarle a mano lasciava
	# la riga finale attaccata all'ultima)
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 0)
	colonna.position = Vector2(0, testa.position.y + FONT_PX * 2.2)
	colonna.size = Vector2(w, FONT_PX * 12)
	colonna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(colonna)

	var corpo := Label.new()
	corpo.text = testo(grave, rng)
	corpo.add_theme_font_override("font", mono)
	corpo.add_theme_font_size_override("font_size", FONT_PX)
	corpo.add_theme_color_override("font_color", C_TESTO)
	corpo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	corpo.custom_minimum_size = Vector2(floorf(w * 0.82), 0)
	corpo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	corpo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonna.add_child(corpo)

	var vuota := Control.new()
	vuota.custom_minimum_size = Vector2(0, FONT_PX * 1.2)
	vuota.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonna.add_child(vuota)

	_testo_fine = tr("BSOD_RESTART" if grave else "BSOD_CONTINUE")
	_riga_fine = Label.new()
	_riga_fine.text = _testo_fine + " _"
	_riga_fine.add_theme_font_override("font", mono)
	_riga_fine.add_theme_font_size_override("font_size", FONT_PX)
	_riga_fine.add_theme_color_override("font_color", C_TESTO)
	_riga_fine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_riga_fine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonna.add_child(_riga_fine)

# Il messaggio, con eccezione, indirizzo e modulo pescati dall'rng del regista (cosi' la
# stessa partita da' gli stessi crash). Pubblico: lo legge anche il test.
static func testo(e_grave: bool, rng: RandomNumberGenerator) -> String:
	var ecc: String = ECCEZIONI[rng.randi() % ECCEZIONI.size()]
	var mod: String = MODULI[rng.randi() % MODULI.size()]
	var ind := "0028:C00%05X" % rng.randi_range(0x10000, 0xFFFFF)
	var off := "%08X" % rng.randi_range(0x1000, 0x2FFFF)
	var chiave := "BSOD_TEXT_GRAVE" if e_grave else "BSOD_TEXT"
	return TranslationServer.translate(chiave).c_unescape().format({
		"ECC": ecc, "IND": ind, "MOD": "%s + %s" % [mod, off]})

func _process(delta: float) -> void:
	_t += delta
	if _riga_fine != null:
		var acceso := fmod(_t, LAMPEGGIO * 2.0) < LAMPEGGIO
		_riga_fine.text = _testo_fine + (" _" if acceso else "  ")

# Gira PRIMA del desktop (i figli ricevono _input per primi): un tasto qualsiasi chiude,
# tutto il resto -- i clic compresi -- viene mangiato qui.
func _input(event: InputEvent) -> void:
	if _fatto:
		return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		var k := event as InputEventKey
		if k.pressed and not k.echo and not _solo_modificatore(k.keycode):
			_fatto = true
			premuto.emit(grave)
	elif event is InputEventMouseButton:
		get_viewport().set_input_as_handled()

# SHIFT, CTRL e ALT da soli non sono "un tasto" nemmeno sul DOS: servono per le
# combinazioni, e la pausa del gioco (P) passa dalla stanza prima di arrivare qui.
static func _solo_modificatore(code: int) -> bool:
	return code in [KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_CAPSLOCK]
