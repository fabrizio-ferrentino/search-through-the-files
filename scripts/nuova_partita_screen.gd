class_name NuovaPartitaScreen
extends CanvasLayer

# La schermata che si apre premendo "Avvia" nel menu (proprietario, 25/11/2026: un campo
# del seme sotto i pulsanti del menu "e' brutto, metti una schermata dopo aver premuto avvia
# e li' scelgo cosa fare"). Due strade: una partita a caso, o una partita col SEME scritto
# (quello che la schermata di fine partita mostra), per rigiocare la stessa. Il seme decide
# disco, chiavi, siti e i tempi di nemici e virus. Stesso aspetto delle Impostazioni.

signal avvia(seme: int)     # 0 = a caso
signal chiusa

const SEME_MAX := 4294967295   # il seme sta in 32 bit

var campo: LineEdit
var gioca_seme: Button

func _ready() -> void:
	layer = 10
	var radice := Control.new()
	radice.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.mouse_filter = Control.MOUSE_FILTER_STOP   # nessun clic ai pulsanti del menu sotto
	add_child(radice)
	var sfondo := ColorRect.new()
	sfondo.color = Color.BLACK
	sfondo.set_anchors_preset(Control.PRESET_FULL_RECT)
	radice.add_child(sfondo)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 40)
	radice.add_child(vb)

	var titolo := Label.new()
	titolo.text = tr("UI_NEW_GAME")
	titolo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titolo.add_theme_font_size_override("font_size", 80)
	titolo.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vb.add_child(titolo)

	var casuale := _pulsante("Casuale", tr("UI_RANDOM_GAME"), Vector2(720, 110))
	casuale.pressed.connect(func(): _parti(0))
	vb.add_child(casuale)

	var riga := HBoxContainer.new()
	riga.alignment = BoxContainer.ALIGNMENT_CENTER
	riga.add_theme_constant_override("separation", 20)
	vb.add_child(riga)
	var et := Label.new()
	et.text = tr("UI_SEED")
	et.add_theme_font_size_override("font_size", 44)
	et.add_theme_color_override("font_color", Color(0.82, 0.82, 0.82))
	riga.add_child(et)
	campo = LineEdit.new()
	campo.name = "Seme"
	campo.custom_minimum_size = Vector2(340, 80)
	campo.add_theme_font_size_override("font_size", 44)
	campo.max_length = 10
	campo.placeholder_text = tr("UI_SEED_HINT")
	campo.text_changed.connect(_solo_cifre)
	campo.text_submitted.connect(func(_t: String): _gioca_col_seme())
	riga.add_child(campo)
	gioca_seme = _pulsante("GiocaSeme", tr("UI_PLAY_SEED"), Vector2(260, 80))
	gioca_seme.disabled = true             # senza un seme valido non c'e' niente da giocare
	gioca_seme.pressed.connect(_gioca_col_seme)
	riga.add_child(gioca_seme)

	var indietro := _pulsante("Indietro", tr("UI_BACK"), Vector2(360, 96))
	indietro.pressed.connect(chiudi)
	vb.add_child(indietro)

func _pulsante(nome: String, testo: String, misura: Vector2) -> Button:
	var b := Button.new()
	b.name = nome
	b.text = testo
	b.custom_minimum_size = misura
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 44)
	return b

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):   # ESC: come Indietro
		get_viewport().set_input_as_handled()
		chiudi()

func chiudi() -> void:
	chiusa.emit()
	queue_free()

func _solo_cifre(t: String) -> void:
	var pulito := ""
	for c in t:
		if c >= "0" and c <= "9":
			pulito += c
	if pulito != t:
		campo.text = pulito
		campo.caret_column = pulito.length()
	gioca_seme.disabled = seme_scritto() == 0

# Il seme scritto, o 0 se il campo e' vuoto, e' 0 o e' fuori misura.
func seme_scritto() -> int:
	var t := campo.text.strip_edges()
	if t == "" or not t.is_valid_int():
		return 0
	var n := t.to_int()
	return n if n > 0 and n <= SEME_MAX else 0

func _gioca_col_seme() -> void:
	if seme_scritto() != 0:
		_parti(seme_scritto())

func _parti(seme: int) -> void:
	set_process_input(false)
	avvia.emit(seme)
	queue_free()
