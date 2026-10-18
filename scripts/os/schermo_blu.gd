class_name SchermoBlu
extends Control

# Lo SCHERMO BLU (M5, richiesta del proprietario: "piu' che virus vorrei dar fastidio al
# giocatore facendo crashare a caso il pc"). E' quello di Win95, in modalita' testo:
# fondo blu, il nome del sistema in un riquadro grigio, l'eccezione e la sorte del PC.
# Si RIAVVIA DA SOLO dopo DURATA secondi, con un conto alla rovescia in fondo (proprietario,
# 18/10/2026: non gli piaceva dover premere un tasto). E' un imprevisto che si SUBISCE,
# come l'avvio non saltabile: intanto le minacce della stanza girano. Allo scadere emette
# "scaduto" e il desktop fa il riavvio (OSDesktop.riavvia: nero, BIOS, avvio, login, tutte
# le finestre perse): qui c'e' solo la schermata.
# Storia, perche' non torni: prima era "un tasto qualsiasi per continuare", e a quel punto
# serviva anche un'attesa di 0.7 s -- lo stesso F9 che lo fa partire arrivava all'OS e lo
# chiudeva nell'istante in cui si apriva, e chi stava scrivendo lo chiudeva senza vederlo.
# Tasti e clic vengono MANGIATI (non devono finire nelle finestre che stanno sotto), ma ESC
# e P passano dalla stanza prima di arrivare qui: ESC esce dal PC e il conto continua sul
# monitor 3D, P mette in pausa e il conto si ferma con l'albero.
# Niente CTRL+ALT+CANC nel testo: il sistema vero se lo prende prima del gioco, e una riga
# che promette una cosa che non funziona e' peggio di nessuna.

signal scaduto

const C_FONDO := Color("0000aa")       # il blu della modalita' testo VGA
const C_TESTO := Color("ffffff")
const C_GRIGIO := Color("aaaaaa")
const FONT_PX := 30                    # ~80 colonne su 1440 px, come lo schermo vero
const LAMPEGGIO := 0.5                 # il trattino del cursore, mezzo secondo acceso
const DURATA := 5.0                    # secondi di schermo blu prima del riavvio

# Pezzi del messaggio. Codici e moduli veri di Win95, scelti a caso: nessuno ha la forma
# di una chiave (cifra-trattino-quattro), che resta riservata alla caccia.
const ECCEZIONI := ["0E", "0D", "06", "0C"]
const MODULI := ["VMM(01)", "VWIN32(05)", "IFSMGR(01)", "VFAT(02)", "VXDLDR(03)", "NTKERN(04)"]

var _riga_fine: Label = null
var _t := 0.0
var _fatto := false

func setup(rng: RandomNumberGenerator) -> void:
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

	# messaggio, riga vuota e conto alla rovescia in COLONNA: quante righe occupi il messaggio
	# lo decide l'a capo, cioe' la lingua, e qui non si sa ancora (contarle a mano lasciava
	# la riga finale attaccata all'ultima)
	var colonna := VBoxContainer.new()
	colonna.add_theme_constant_override("separation", 0)
	colonna.position = Vector2(0, testa.position.y + FONT_PX * 2.2)
	colonna.size = Vector2(w, FONT_PX * 12)
	colonna.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(colonna)

	var corpo := Label.new()
	corpo.text = testo(rng)
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

	_riga_fine = Label.new()
	_riga_fine.add_theme_font_override("font", mono)
	_riga_fine.add_theme_font_size_override("font_size", FONT_PX)
	_riga_fine.add_theme_color_override("font_color", C_TESTO)
	_riga_fine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_riga_fine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colonna.add_child(_riga_fine)
	_aggiorna_riga()

# Il messaggio, con eccezione, indirizzo e modulo pescati dall'rng del regista (cosi' la
# stessa partita da' gli stessi crash). Pubblico: lo legge anche il test.
static func testo(rng: RandomNumberGenerator) -> String:
	var ecc: String = ECCEZIONI[rng.randi() % ECCEZIONI.size()]
	var mod: String = MODULI[rng.randi() % MODULI.size()]
	var ind := "0028:C00%05X" % rng.randi_range(0x10000, 0xFFFFF)
	var off := "%08X" % rng.randi_range(0x1000, 0x2FFFF)
	return TranslationServer.translate("BSOD_TEXT").c_unescape().format({
		"ECC": ecc, "IND": ind, "MOD": "%s + %s" % [mod, off]})

# Secondi interi che mancano al riavvio (5, 4, ... 1). Pubblico: lo legge il test.
func secondi_al_riavvio() -> int:
	return maxi(1, int(ceil(DURATA - _t)))

func riga_fine() -> String:
	return _riga_fine.text if _riga_fine != null else ""

func _process(delta: float) -> void:
	if _fatto:
		return
	_t += delta
	_aggiorna_riga()
	if _t >= DURATA:
		_fatto = true
		scaduto.emit()

func _aggiorna_riga() -> void:
	if _riga_fine == null:
		return
	var acceso := fmod(_t, LAMPEGGIO * 2.0) < LAMPEGGIO
	_riga_fine.text = tr("BSOD_RESTART").format({"N": secondi_al_riavvio()}) \
			+ (" _" if acceso else "  ")

# Gira PRIMA del desktop (i figli ricevono _input per primi): tasti e clic si fermano qui
# senza fare niente, cosi' non arrivano alle finestre che stanno sotto.
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
