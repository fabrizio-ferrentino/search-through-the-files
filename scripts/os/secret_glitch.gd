class_name SecretGlitch
extends Node

# Il GUASTO del dialogo della cartella segreta (17/10/2026, richiesta del proprietario:
# "piu' reale e piu' spaventoso"). Prima era glitch.gdshader sopra il pannello, a raffiche
# fisse: neve uniforme, separazione dei colori ovunque, sempre uguale e sempre chiusa
# dentro il rettangolo del dialogo (le fette spostate venivano tagliate dal suo bordo,
# cioe' si vedeva che era uno strato appoggiato sopra). Leggeva come un filtro.
#
# Adesso (lo shader e' secret_glitch.gdshader):
#  - GUASTI DI UN PC, non neve: strappi irregolari che si riavvolgono, tessere corrotte,
#    la scia del Win95 bloccato, la tavolozza sbagliata;
#  - SA CHE CI SEI: sobbalza mentre scrivi, al codice sbagliato si arrossa, si corrompe e
#    trema, e lo schermo cala di luce come in un calo di tensione; piu' resti, piu' spesso;
#  - il TITOLO si corrompe durante le raffiche, e di rado lampeggia per 4 fotogrammi una
#    frase (SECRET_SUB_*) legata al seme del GDD: la balena da 52 Hz, "un segnale a cui
#    nessuno risponde". Le frasi stanno nel CSV: si cambiano o si tolgono da li'.
#
# TRE VINCOLI, voluti:
#  1 non tocca MAI quello che il giocatore ha scritto: corrompe pixel e titolo, mai i
#    campi -- perdere un codice digitato per un effetto sarebbe una punizione, non paura;
#  2 raffiche brevi (al massimo ~0,4 s) e fra una e l'altra il dialogo e' leggibile:
#    e' la fine della partita, bisogna poterla finire;
#  3 resta ATTORNO AL DIALOGO (il rettangolo dell'effetto e' il dialogo piu' MARGINE) e
#    non usa lo shader dell'avviso: il glitch a tutto schermo e' il segnale che un nemico
#    si sta affacciando, e non deve avere un sosia.
#
# Vive come figlio dello strato del dialogo, quindi muore con lui; usa _process e non
# Tween, cosi' si ferma con la pausa e non sopravvive al dialogo chiuso.

const MARGINE := 140.0          # spazio attorno al dialogo per la scia
const MAX_RAFFICA := 0.4        # secondi: oltre, il dialogo smette di essere leggibile
enum { STRAPPO, BLOCCHI, SCIA, PALETTE }

const SUBLIMINALI := ["SECRET_SUB_1", "SECRET_SUB_2", "SECRET_SUB_3"]
# caratteri da byte sbagliati: quello che si vedeva quando un testo veniva letto con la
# codifica sbagliata (non sono testo da tradurre, sono rumore)
const SPORCO := "ÿ¤§¶þÐ×÷¿ÆØ±µ¬#%&@"

var raffiche := 0               # quante ne sono partite (lo legge il test)

var _strato: Control
var _panel: Panel
var _titolo: Label
var _testo_titolo := ""
var _fondo_scuro: ColorRect     # il velo dietro al dialogo: cala di luce nei rifiuti
var _alfa_fondo := 0.55
var _fx: ColorRect
var _mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()

var _aperto_da := 0.0           # secondi dall'apertura (escalation)
var _prossima := 0.0            # secondi alla prossima raffica spontanea
var _in_raffica := 0.0          # secondi rimasti della raffica in corso
var _cambio_seme := 0.0
var _titolo_sporco := false
var _subliminale := 0.0         # secondi rimasti della frase nel titolo
var _scossa := 0.0
var _pos_panel := Vector2.ZERO

# strato = lo strato modale del dialogo; il primo figlio e' il velo scuro (vedi
# OSDesktop._make_modal). L'effetto va aggiunto DOPO il pannello, o ci finisce sotto.
func setup(strato: Control, panel: Panel, titolo: Label) -> void:
	_strato = strato
	_panel = panel
	_titolo = titolo
	_testo_titolo = titolo.text
	_pos_panel = panel.position
	if strato.get_child_count() > 0 and strato.get_child(0) is ColorRect:
		_fondo_scuro = strato.get_child(0)
		_alfa_fondo = _fondo_scuro.color.a
	_rng.randomize()

	_fx = ColorRect.new()
	_fx.name = "GlitchSegreto"
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE   # i campi sotto restano cliccabili
	_fx.position = panel.position - Vector2(MARGINE, MARGINE)
	_fx.size = panel.size + Vector2(MARGINE, MARGINE) * 2.0
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://scripts/os/secret_glitch.gdshader")
	_mat.set_shader_parameter("dimensione", _fx.size)
	_mat.set_shader_parameter("pannello",
			Vector4(MARGINE, MARGINE, panel.size.x, panel.size.y))
	_fx.material = _mat
	strato.add_child(_fx)
	_spegni()

	# l'arrivo: il dialogo "si strappa dentro" invece di comparire pulito
	raffica(1.0, SCIA)
	_prossima = _intervallo()

# Il rettangolo dell'effetto, in coordinate dello strato (per il test: deve restare
# attorno al dialogo e non diventare mai un effetto a tutto schermo).
func rettangolo() -> Rect2:
	return Rect2(_fx.position, _fx.size) if _fx != null else Rect2()

func in_raffica() -> bool:
	return _in_raffica > 0.0

# Una raffica. forza 0..1; tipo a caso se non indicato.
func raffica(forza: float, tipo := -1) -> void:
	raffiche += 1
	if tipo < 0:
		var t := _rng.randf()
		tipo = STRAPPO if t < 0.35 else (BLOCCHI if t < 0.65 else (SCIA if t < 0.85 else PALETTE))
	var durata: float = 0.07 if forza < 0.3 else lerpf(0.12, 0.34, forza) * _rng.randf_range(0.85, 1.15)
	_in_raffica = minf(maxf(_in_raffica, durata), MAX_RAFFICA)
	_cambio_seme = 0.0
	_mat.set_shader_parameter("strappo", 0.0)
	_mat.set_shader_parameter("blocchi", 0.0)
	_mat.set_shader_parameter("scia", 0.0)
	_mat.set_shader_parameter("palette", 0.0)
	match tipo:
		STRAPPO:
			_mat.set_shader_parameter("strappo", forza)
			_mat.set_shader_parameter("blocchi", 0.15 * forza)
		BLOCCHI:
			_mat.set_shader_parameter("blocchi", forza)
			_mat.set_shader_parameter("strappo", 0.3 * forza)
		SCIA:
			_mat.set_shader_parameter("scia", forza)
			_mat.set_shader_parameter("strappo", 0.25 * forza)
			var sx := _rng.randf_range(10.0, 18.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
			var sy := _rng.randf_range(6.0, 12.0) * (1.0 if _rng.randf() < 0.6 else -1.0)
			_mat.set_shader_parameter("passo_scia", Vector2(sx, sy))
		PALETTE:
			_mat.set_shader_parameter("palette", 1.0)
			_mat.set_shader_parameter("blocchi", 0.5 * forza)
			_in_raffica = minf(_in_raffica, 0.14)   # il rosso e' un lampo, non uno stato
	if forza > 0.5 and _rng.randf() < 0.5:
		_titolo_sporco = true
	# la frase: rara, mai nei primi secondi (prima bisogna aver guardato il dialogo)
	if forza > 0.7 and _aperto_da > 4.0 and _rng.randf() < 0.2:
		_mostra_subliminale()
	if forza >= 0.85:
		_scossa = 0.2

# Un tasto premuto in un campo: il dialogo sobbalza (una volta su due, o diventa un tic).
func tremito() -> void:
	if _in_raffica > 0.0 or _rng.randf() < 0.5:
		return
	raffica(0.25, STRAPPO)

# Codici sbagliati: il RIFIUTO. Rosso, tessere, strappi, scossa, calo di luce -- e una
# volta su due la frase. I campi restano come sono: chi ha sbagliato una riga deve
# poterla correggere senza riscrivere le altre.
func rifiuto() -> void:
	raffiche += 1
	_in_raffica = 0.36
	_cambio_seme = 0.0
	_mat.set_shader_parameter("palette", 1.0)
	_mat.set_shader_parameter("blocchi", 0.8)
	_mat.set_shader_parameter("strappo", 0.7)
	_mat.set_shader_parameter("scia", 0.0)
	_titolo_sporco = true
	_scossa = 0.3
	if _fondo_scuro != null:
		_fondo_scuro.color.a = 0.85
	if _aperto_da > 4.0 and _rng.randf() < 0.5:
		_mostra_subliminale()

func _mostra_subliminale() -> void:
	_subliminale = 0.07           # ~4 fotogrammi: si vede, ma non si fa in tempo a leggerla bene
	_titolo.text = tr(SUBLIMINALI[_rng.randi() % SUBLIMINALI.size()])

# Piu' resti davanti al dialogo, piu' spesso si rompe: da ~2,8 s fra una raffica e
# l'altra all'apertura a ~1 s dopo un minuto.
func _intervallo() -> float:
	var t := clampf(_aperto_da / 60.0, 0.0, 1.0)
	return lerpf(2.8, 1.0, t) * _rng.randf_range(0.7, 1.3)

func _process(delta: float) -> void:
	if _mat == null:
		return
	_aperto_da += delta
	_mat.set_shader_parameter("fondo", lerpf(0.6, 2.0, clampf(_aperto_da / 60.0, 0.0, 1.0)))

	_prossima -= delta
	if _prossima <= 0.0:
		raffica(_rng.randf_range(0.55, 1.0))
		_prossima = _intervallo()

	if _in_raffica > 0.0:
		_in_raffica -= delta
		_cambio_seme -= delta
		if _cambio_seme <= 0.0:
			# il seme cambia a scatti: fotogrammi digitali, non un'animazione morbida
			_mat.set_shader_parameter("seme", _rng.randf() * 100.0)
			_cambio_seme = _rng.randf_range(0.03, 0.07)
			if _titolo_sporco and _subliminale <= 0.0:
				_titolo.text = _sporca(_testo_titolo)
		if _in_raffica <= 0.0:
			_spegni()

	if _subliminale > 0.0:
		_subliminale -= delta
		if _subliminale <= 0.0:
			_titolo.text = _sporca(_testo_titolo) if (_titolo_sporco and _in_raffica > 0.0) \
					else _testo_titolo

	if _scossa > 0.0:
		_scossa -= delta
		var d := Vector2(_rng.randi_range(-4, 4), _rng.randi_range(-3, 3))
		if _scossa <= 0.0:
			d = Vector2.ZERO
		_panel.position = _pos_panel + d
		_fx.position = _panel.position - Vector2(MARGINE, MARGINE)   # lo shader lo segue

func _spegni() -> void:
	_mat.set_shader_parameter("strappo", 0.0)
	_mat.set_shader_parameter("blocchi", 0.0)
	_mat.set_shader_parameter("scia", 0.0)
	_mat.set_shader_parameter("palette", 0.0)
	_titolo_sporco = false
	if _subliminale <= 0.0:
		_titolo.text = _testo_titolo
	if _fondo_scuro != null:
		_fondo_scuro.color.a = _alfa_fondo

# Il titolo letto con la codifica sbagliata: una lettera su tre diventa un byte sporco.
func _sporca(s: String) -> String:
	var out := ""
	for c in s:
		if c != " " and _rng.randf() < 0.35:
			out += SPORCO[_rng.randi() % SPORCO.length()]
		else:
			out += c
	return out
