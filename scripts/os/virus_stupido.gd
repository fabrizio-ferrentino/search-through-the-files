class_name VirusStupido
extends Node

# Il virus "YouAreStupid" (M5, GDD §7.2): NON uccide, da' fastidio. Apre una raffica di
# finestrelle con la faccina e la scritta, alcune vagano per lo schermo rimbalzando sui
# bordi, e chiuderne una a volte ne fa nascere altre -- come il "You are an idiot" vero.
# Due tetti lo fanno FINIRE sempre: mai piu' di MAX_VIVE aperte insieme e mai piu' di
# MAX_TOTALE in tutto; chiusa l'ultima, il virus e' finito. Anche spegnere il PC lo
# chiude (power_off chiude tutte le finestre, e qui non si riapre niente a PC spento).
# Le finestre sono OSWindow vere: barra delle applicazioni, trascinamento, chiusura.
# Il regista (virus_director.gd) lo crea e aspetta "finito".
# NON SI PUO' IGNORARE (proprietario, 18/10/2026: "vorrei evitare che i giocatori lo
# ignorino e continuino a giocare"): le finestre stanno SEMPRE SOPRA le altre (cliccare la
# finestra di dietro non le scavalca), NON SI ABBASSANO: i tre pulsanti ci sono, come su
# ogni finestra, ma "riduci" e' grigio e spento, e nemmeno il pulsante nella barra le
# nasconde (il proprietario ha provato la versione in cui si abbassavano e tornavano su da
# sole dopo 2 s, e ha scelto questa) -- ogni nuova toglie il fuoco della tastiera a
# quello che stavi scrivendo, e finche' ne resta aperta
# una ne arriva un'altra ogni INSISTENZA secondi -- sempre dentro i due tetti. L'unico modo
# di levarselo di torno e' chiuderle (o spegnere il PC).
# La scritta resta in INGLESE in ogni lingua: e' il nome del virus, come "You are an idiot".

signal finito

const PRIMA_ONDATA := 5          # finestre aperte all'inizio, una dopo l'altra
const PASSO_ONDATA := 0.35       # secondi fra una e l'altra
const MAX_VIVE := 9
const MAX_TOTALE := 16
const PROB_FIGLI := 0.55         # chiudendone una ne nascono 1-2 (finche' c'e' tetto)
const RITARDO_FIGLI := 0.25
const QUOTA_VAGANTI := 0.4       # quante vagano per lo schermo
const VEL_MIN := 120.0           # px/s
const VEL_MAX := 210.0
const LAMPEGGIO := 0.6           # bianco/nero si scambiano ogni 0.6 s: < 1 Hz, niente strobo
const INSISTENZA := 5.0          # ignorate, ne arriva una in piu' ogni 5 s
const DIM := Vector2(380, 240)

var _os: OSDesktop = null
var _rng: RandomNumberGenerator = null
var _vive: Array = []            # OSWindow aperte da questo virus
var _vel: Dictionary = {}        # OSWindow -> Vector2 (solo le vaganti)
var _aperte := 0                 # quante ne ha aperte in tutto
var _in_coda := 0                # aperture programmate e non ancora fatte
var _attesa := 0.0               # conto alla rovescia per la prossima in coda
var _fermo := false
var _t := 0.0
var _ignorate := 0.0             # da quanto ci sono finestre aperte e niente in coda

func setup(os: OSDesktop, rng: RandomNumberGenerator) -> void:
	_os = os
	_rng = rng
	name = "VirusStupido"
	_in_coda = PRIMA_ONDATA

# Smette di aprirne di nuove (le aperte restano: si chiudono a mano o spegnendo).
func ferma() -> void:
	_fermo = true
	_in_coda = 0

func aperte_in_tutto() -> int:
	return _aperte

func vive() -> Array:
	return _vive.duplicate()

func _process(delta: float) -> void:
	avanza(delta)

# Il passo del virus, pubblico perche' il test lo fa girare a mano.
func avanza(delta: float) -> void:
	_t += delta
	_vive = _vive.filter(func(w): return is_instance_valid(w) and not w.is_queued_for_deletion())
	if _in_coda > 0 and not _fermo:
		_attesa -= delta
		# con un dialogo aperto, al login o durante l'avvio non si apre niente: si aspetta
		if _attesa <= 0.0 and _os.pronto_per_virus():
			_in_coda -= 1
			_attesa = PASSO_ONDATA
			_apri()
	elif _in_coda > 0 and _fermo:
		_in_coda = 0
	# ignorate? ne arriva un'altra (il tetto la ferma da solo, in _apri)
	if _in_coda == 0 and not _vive.is_empty() and not _fermo:
		_ignorate += delta
		if _ignorate >= INSISTENZA:
			_ignorate = 0.0
			if _aperte < MAX_TOTALE and _vive.size() < MAX_VIVE:
				_in_coda = 1
	else:
		_ignorate = 0.0
	_vaga(delta)
	_lampeggia()
	if _vive.is_empty() and (_in_coda == 0 or _fermo or not GameManager.pc_on):
		set_process(false)
		finito.emit()
		queue_free()

func _apri() -> void:
	if _aperte >= MAX_TOTALE or _vive.size() >= MAX_VIVE:
		return
	_aperte += 1
	var win := _os.open_window(tr("VIRUS_STUPID_TITLE"), DIM, "smiley")
	var a := win.area_utile()
	win.position = Vector2(_rng.randf_range(0.0, maxf(0.0, a.size.x - win.size.x)),
			_rng.randf_range(0.0, maxf(0.0, a.size.y - win.size.y))).floor()
	win.assesta()
	win.blocca_in_cima()
	_os.focus_window(win)            # ricalcola l'ordine: lei sopra, ora che e' "in cima"
	_os.get_viewport().gui_release_focus()   # quello che stavi scrivendo resta a meta'
	win.content_root.add_child(_contenuto())
	win.closed.connect(_chiusa)
	_vive.append(win)
	if _rng.randf() < QUOTA_VAGANTI:
		var ang := _rng.randf_range(0.0, TAU)
		_vel[win] = Vector2(cos(ang), sin(ang)) * _rng.randf_range(VEL_MIN, VEL_MAX)

# Chiusa una finestra: a volte ne arrivano altre. Non subito: power_off chiude tutto in
# un colpo, e quando tocca alla coda il PC e' gia' spento (pronto_per_virus dice no).
func _chiusa(win) -> void:
	_vel.erase(win)
	_vive.erase(win)
	if _fermo or _rng.randf() >= PROB_FIGLI:
		return
	var quante := _rng.randi_range(1, 2)
	var posto: int = MAX_TOTALE - _aperte - _in_coda
	_in_coda += clampi(quante, 0, maxi(0, posto))
	_attesa = maxf(_attesa, RITARDO_FIGLI)

# Le vaganti rimbalzano dentro l'area utile. Ferme mentre il giocatore le trascina o le
# ridimensiona, e da ingrandite.
func _vaga(delta: float) -> void:
	for w in _vel.keys():
		if not is_instance_valid(w):
			_vel.erase(w)
			continue
		var win := w as OSWindow
		if not win.visible or win.occupata() or win.is_maximized():
			continue
		var v: Vector2 = _vel[win]
		var a := win.area_utile()
		var p := win.position + v * delta
		var max_p := a.end - win.size
		if p.x <= a.position.x or p.x >= max_p.x:
			v.x = -v.x
		if p.y <= a.position.y or p.y >= max_p.y:
			v.y = -v.y
		_vel[win] = v
		win.position = Vector2(clampf(p.x, a.position.x, maxf(a.position.x, max_p.x)),
				clampf(p.y, a.position.y, maxf(a.position.y, max_p.y)))

func _lampeggia() -> void:
	var negativo := fmod(_t, LAMPEGGIO * 2.0) >= LAMPEGGIO
	for w in _vive:
		var c: Control = (w as OSWindow).content_root.get_child(0) if (w as OSWindow).content_root.get_child_count() > 0 else null
		if c != null and c.has_method("negativo"):
			c.negativo(negativo)

# Il contenuto: fondo bianco (o nero), tre faccine e la scritta.
func _contenuto() -> Control:
	var c := _Faccine.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.testo = tr("VIRUS_STUPID_MSG")
	return c

class _Faccine extends Control:
	var testo := ""
	var _neg := false

	func negativo(v: bool) -> void:
		if v != _neg:
			_neg = v
			queue_redraw()

	func _draw() -> void:
		var fondo := Color.BLACK if _neg else Color.WHITE
		var inchiostro := Color.WHITE if _neg else Color.BLACK
		draw_rect(Rect2(Vector2.ZERO, size), fondo)
		var r: float = minf(size.x / 9.0, size.y / 5.0)
		var y: float = size.y * 0.34
		for i in range(3):
			_faccina(Vector2(size.x * (0.25 + 0.25 * i), y), r)
		var f: Font = Win95.font("sans_b")
		var px := 30
		var tw: float = f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		while tw > size.x - 16.0 and px > 12:
			px -= 2
			tw = f.get_string_size(testo, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		draw_string(f, Vector2((size.x - tw) * 0.5, size.y * 0.80), testo,
				HORIZONTAL_ALIGNMENT_LEFT, -1, px, inchiostro)

	func _faccina(c: Vector2, r: float) -> void:
		draw_circle(c, r, Color("ffd800"))
		draw_arc(c, r, 0.0, TAU, 32, Color.BLACK, 2.0)
		draw_circle(c + Vector2(-r * 0.35, -r * 0.25), r * 0.13, Color.BLACK)
		draw_circle(c + Vector2(r * 0.35, -r * 0.25), r * 0.13, Color.BLACK)
		draw_arc(c + Vector2(0, r * 0.05), r * 0.55, PI * 0.15, PI * 0.85, 16, Color.BLACK, 2.5)
