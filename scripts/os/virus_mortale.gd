class_name VirusMortale
extends Node

# Il virus MORTALE (M5, GDD §7.2 "shutdown-or-die"). Richiesta del proprietario: "deve
# succedere qualcosa che se lo vedi capisci che devi spegnere il pc altrimenti muori
# (es. sfondo che cambia, glitch visivi, sangue che appare)". E' la maledizione (GDD §2b)
# che affiora nel PC, e ha DURATA secondi: se il PC non viene spento prima -- Avvio >
# Arresta, oppure il pulsante del case -- e' game_over("virus").
# Cresce in tre tempi, cosi' chi lo vede per la prima volta capisce che sta peggiorando:
#   1 lo SFONDO diventa rosso sangue (in pochi secondi: deve saltare all'occhio subito) e
#     compare, scritta in grande SOPRA le finestre, la voce della maledizione: "non
#     spegnermi" -- che e' anche l'indizio, detto al contrario. Sopra, non sullo sfondo:
#     sotto le finestre se ne leggevano due pezzi ("no", "ermi"), cioe' niente;
#   2 il SANGUE cola dal bordo alto dello schermo, sopra le finestre;
#   3 le finestre TREMANO e lo schermo pulsa di rosso, come un battito, fino alla fine.
# Vive DENTRO l'OS (gli strati li aggiunge al desktop), quindi si vede anche sul monitor
# 3D dalla stanza. Non usa glitch.gdshader: quello e' l'avviso del nemico nel corridoio,
# e i due non devono potersi confondere. Il sangue sta SOTTO la barra delle applicazioni e
# il menu Avvio: la via d'uscita resta sempre pulita. Il sangue non prende il mouse.
# pulisci() toglie tutto e rimette a posto le finestre: lo chiama il regista quando il PC
# viene spento in tempo (o le minacce vengono spente con F11).

signal scaduto

const DURATA := 30.0
const C_SANGUE := Color(0.42, 0.0, 0.02)
const C_SANGUE_SCURO := Color(0.22, 0.0, 0.01)
const C_SCRITTA := Color(0.62, 0.03, 0.05)
# i tre tempi, in frazioni di DURATA
const T_SFONDO := 0.15        # sfondo pieno a questa frazione (4.5 s)
const T_SCRITTA := [0.12, 0.35]
const T_SANGUE := 0.10        # da qui cola
const T_TREMA := 0.72         # da qui le finestre tremano e lo schermo pulsa
const GOCCE := 70
const BATTITO := 1.1          # Hz: un battito, non uno stroboscopio

var _os: OSDesktop = null
var _rng: RandomNumberGenerator = null
var _t := 0.0
var _finito := false
var _tinta: ColorRect = null
var _scritta: Label = null
var _sangue: Control = null
var _gocce: Array = []        # [x, larghezza, velocita', partenza (frazione), lunghezza]
var _orlo: PackedFloat32Array = PackedFloat32Array()   # altezza della pozza in alto, per colonna

func setup(os: OSDesktop, rng: RandomNumberGenerator) -> void:
	_os = os
	_rng = rng
	name = "VirusMortale"
	var w: float = os.size.x

	# 1) lo sfondo: un velo sopra la carta da parati, sotto le icone
	_tinta = ColorRect.new()
	_tinta.name = "VirusSfondo"
	_tinta.color = Color(C_SANGUE, 0.0)
	_tinta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	os.sopra_sfondo(_tinta)

	# 2) il sangue: sopra le finestre, sotto barra e menu Avvio
	_sangue = Control.new()
	_sangue.name = "VirusSangue"
	_sangue.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sangue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sangue.draw.connect(_disegna_sangue)
	os.sopra_finestre(_sangue)

	_scritta = Label.new()
	_scritta.text = tr("VIRUS_CURSE_MSG")
	_scritta.add_theme_font_override("font", Win95.font("sans_b"))
	_scritta.add_theme_font_size_override("font_size", 96)
	_scritta.add_theme_color_override("font_color", C_SCRITTA)
	_scritta.add_theme_color_override("font_outline_color", C_SANGUE_SCURO)
	_scritta.add_theme_constant_override("outline_size", 10)
	_scritta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_scritta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_scritta.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scritta.offset_bottom = -OSDesktop.TASKBAR_H
	_scritta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scritta.modulate.a = 0.0
	_sangue.add_child(_scritta)

	for i in range(GOCCE):
		_gocce.append([
			_rng.randf_range(0.0, w),
			_rng.randf_range(3.0, 12.0),
			_rng.randf_range(25.0, 110.0),
			_rng.randf_range(T_SANGUE, 0.85),
			0.0])
	_orlo.resize(int(w / 8.0) + 2)
	for i in range(_orlo.size()):
		_orlo[i] = _rng.randf_range(0.6, 1.4)

func progresso() -> float:
	return clampf(_t / DURATA, 0.0, 1.0)

func _process(delta: float) -> void:
	avanza(delta)

# Il passo del virus, pubblico perche' il test lo fa girare a mano.
func avanza(delta: float) -> void:
	if _finito:
		return
	_t += delta
	var f := progresso()
	_tinta.color.a = 0.92 * smoothstep(0.0, T_SFONDO, f)
	_scritta.modulate.a = 0.85 * smoothstep(T_SCRITTA[0], T_SCRITTA[1], f)
	var velocita := 1.0 + 2.0 * smoothstep(T_TREMA, 1.0, f)   # verso la fine cola piu' in fretta
	for g in _gocce:
		if f >= float(g[3]):
			# il sangue rallenta mentre scende: viscoso, non una pioggia
			g[4] = float(g[4]) + float(g[2]) * velocita * delta / (1.0 + float(g[4]) / 400.0)
	_sangue.queue_redraw()
	_trema(f)
	if f >= 1.0:
		_finito = true
		scaduto.emit()

# Tempo 3: il livello delle finestre trema a scatti (spostando il CONTENITORE, non le
# finestre: pulisci() lo rimette a zero e nessuna geometria viene toccata).
func _trema(f: float) -> void:
	if f < T_TREMA:
		return
	var forza: float = lerpf(2.0, 9.0, smoothstep(T_TREMA, 1.0, f))
	if _rng.randf() < 0.35:
		_os.window_layer.position = Vector2(_rng.randf_range(-forza, forza),
				_rng.randf_range(-forza, forza)).round()

func _disegna_sangue() -> void:
	if _sangue == null:       # pulito: lo strato aspetta solo di essere liberato
		return
	var f := progresso()
	var s := _sangue.size
	# la pozza lungo il bordo alto, da cui partono le colate
	var alto: float = 34.0 * smoothstep(T_SANGUE * 0.5, 0.6, f) + 30.0 * smoothstep(0.6, 1.0, f)
	if alto > 0.5:
		var pts := PackedVector2Array([Vector2(0, 0)])
		for i in range(_orlo.size()):
			pts.append(Vector2(i * 8.0, alto * _orlo[i]))
		pts.append(Vector2(s.x, 0))
		_sangue.draw_colored_polygon(pts, C_SANGUE)
	for g in _gocce:
		var lun: float = g[4]
		if lun <= 0.5:
			continue
		var x: float = g[0]
		var lw: float = g[1]
		var fine: float = minf(lun, s.y)
		_sangue.draw_rect(Rect2(x - lw * 0.5, 0, lw, fine), C_SANGUE)
		_sangue.draw_rect(Rect2(x - lw * 0.5, 0, maxf(1.0, lw * 0.25), fine), C_SANGUE_SCURO)
		_sangue.draw_circle(Vector2(x, fine), lw * 0.75, C_SANGUE)
	# tempo 3: lo schermo pulsa di rosso ai bordi, al ritmo di un battito
	if f >= T_TREMA:
		var k: float = smoothstep(T_TREMA, 1.0, f)
		var battito: float = pow(maxf(0.0, sin(_t * TAU * BATTITO)), 6.0)
		var a: float = (0.18 + 0.35 * battito) * k
		var bordo: float = 120.0 + 160.0 * k
		for i in range(6):
			var d: float = bordo * (1.0 - i / 6.0)
			var c := Color(C_SANGUE_SCURO, a / 6.0)
			_sangue.draw_rect(Rect2(0, 0, s.x, d * 0.5), c)
			_sangue.draw_rect(Rect2(0, s.y - d * 0.5, s.x, d * 0.5), c)
			_sangue.draw_rect(Rect2(0, 0, d * 0.5, s.y), c)
			_sangue.draw_rect(Rect2(s.x - d * 0.5, 0, d * 0.5, s.y), c)

# Toglie ogni traccia: strati liberati, finestre rimesse dove erano.
func pulisci() -> void:
	_finito = true
	set_process(false)
	if _os != null and is_instance_valid(_os) and _os.window_layer != null:
		_os.window_layer.position = Vector2.ZERO
	for n in [_tinta, _sangue]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_tinta = null
	_sangue = null
	queue_free()
