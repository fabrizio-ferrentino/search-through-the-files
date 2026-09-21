extends Node

# Test del CONTORNO TRATTEGGIATO di spostamento e ridimensionamento (21/09/2026).
#
# Su Win95 "mostra il contenuto delle finestre durante il trascinamento" era SPENTO per
# default: tirando un bordo non si vedeva la finestra cambiare, si vedeva solo un
# rettangolo tratteggiato, e la finestra saltava alla geometria nuova al RILASCIO.
# E' una chicca visiva, chiesta dal proprietario, ma tocca il percorso dell'input piu'
# delicato che c'e' qui dentro, quindi va tenuta ferma da un test.
#
# Si pretende che:
#   1 lo strato del contorno stia SOPRA le finestre e non prenda il mouse. Se lo
#     prendesse si mangerebbe i movimenti del trascinamento che lo sta muovendo -- si
#     vedrebbe il contorno comparire e poi restare immobile;
#   2 mentre si tira il bordo inferiore la finestra NON cambi dimensione e il contorno
#     prometta la geometria giusta;
#   3 il contorno sia davvero TRATTEGGIATO nei pixel: blocchi scuri e chiari che si
#     alternano. Una riga continua passerebbe un controllo "c'e' qualcosa disegnato",
#     quindi le due cose si misurano separate -- quanto inchiostro c'e' e quante volte
#     cambia -- o un tratteggio diventato pieno verrebbe riportato come "non disegnato",
#     che e' un difetto diverso;
#   3b il tratteggio SOPRAVVIVA alla riduzione: in partita questo viewport viene
#     rimpicciolito a ~2/3 e passato nella CRT, ed e' l'unica ragione per cui il blocco
#     e' di 2 px e non di 1. Prima questa era una affermazione nel commento; qui
#     l'immagine viene ridotta per davvero e si pretende che il bordo continui a
#     oscillare (con blocchi da 1 px diventa grigio piatto, provato sabotandolo);
#   4 al rilascio la finestra prenda ESATTAMENTE la geometria promessa e il contorno
#     sparisca: se le due non combaciassero, il contorno sarebbe una bugia;
#   5 lo stesso valga per lo SPOSTAMENTO dalla barra del titolo;
#   6 il contorno non prometta mai una geometria fuori dallo schermo. E' un percorso
#     NUOVO accanto a quello che il confine gia' controllava (finestre_confine_test):
#     senza questo, il contorno potrebbe promettere 3000 px e il rilascio correggere,
#     che a schermo si vede come uno scatto;
#   7 i due INTERRUTTORI funzionino davvero: con CONTORNO_RIDIMENSIONA a false il
#     ridimensionamento torna "dal vivo" e nessun contorno compare (idem per
#     CONTORNO_SPOSTA). Un interruttore collegato a niente e' peggio che non averlo.
#
# I trascinamenti sono VERI: eventi spinti nel SubViewport, con la premuta e il
# rilascio separati, perche' tutto il senso di questa modifica sta in COSA SI VEDE fra
# i due momenti.
#
# Va eseguito come SCENA e A FINESTRA, non headless: il controllo 3 legge i pixel.
#   & $godot --path $proj res://tests/finestre_contorno_test.tscn
# ============================================================

const OS_SIZE := Vector2i(1440, 1080)
const EPS := 1.5
const OUT := "user://contorno/"

var _vp: SubViewport
var _os = null                # OSDesktop
var _win: OSWindow = null     # tipizzata: da un Variant "var x := _win.size.y" non compila
var _fails: Array = []

func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(func(): _timeout())
	await get_tree().process_frame
	GameManager.start_new_run(555)
	GameManager.pc_on = true          # si salta avvio e login: qui contano le finestre
	GameManager.logged_in = true

	_vp = SubViewport.new()
	_vp.size = OS_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS   # servono i pixel veri
	_vp.disable_3d = true
	add_child(_vp)
	_os = load("res://scripts/os/desktop.gd").new()
	_os.position = Vector2.ZERO
	_os.size = Vector2(OS_SIZE)
	_vp.add_child(_os)
	_vp.notify_mouse_entered()        # senza, il SubViewport non consegna i movimenti
	for i in range(4):
		await get_tree().process_frame

	_win = _os.open_app("explorer", null)
	if _win == null:
		print("RISULTATO: FAIL -> finestra non aperta")
		get_tree().quit(1)
		return
	await _rimetti_a_posto()

	_prova_strato()
	await _prova_ridimensiona()
	await _prova_sposta()
	await _prova_confine()
	await _prova_interruttori()

	if _fails.is_empty():
		print("RISULTATO: PASS (si vede solo il bordo, e la finestra arriva dove il bordo prometteva)")
	else:
		print("RISULTATO: FAIL -> " + ", ".join(_fails))
	get_tree().quit(0 if _fails.is_empty() else 1)

func _timeout() -> void:
	print("RISULTATO: FAIL -> timeout")
	get_tree().quit(1)

# ---------- 1: lo strato ----------

func _prova_strato() -> void:
	var c: Control = _os._contorno
	if c == null:
		_check("STRATO_ESISTE", false, "il desktop non ha lo strato del contorno")
		return
	_check("STRATO_ESISTE", true, "")
	_check("STRATO_NON_PRENDE_IL_MOUSE", c.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"lo strato prende il mouse: si mangerebbe il trascinamento che lo muove")
	_check("STRATO_SOPRA_LE_FINESTRE", c.get_index() > _os.window_layer.get_index(),
			"lo strato e' il figlio %d e le finestre il %d: il contorno finirebbe sotto"
			% [c.get_index(), _os.window_layer.get_index()])
	_check("STRATO_SPENTO_A_RIPOSO", not c.visible, "il contorno si vede senza trascinare")

# ---------- 2, 3 e 4: il bordo inferiore (il caso chiesto) ----------

func _prova_ridimensiona() -> void:
	var prima := Rect2(_win.position, _win.size)
	var giu := 140.0
	var presa := Vector2(prima.position.x + 200.0, prima.end.y - 2.0)
	await _muovi(presa)
	await _bottone(presa, true)
	await _muovi(presa + Vector2(0.0, giu * 0.5))
	await _muovi(presa + Vector2(0.0, giu))

	# la finestra non si e' mossa di un pixel...
	_check("FINESTRA_FERMA_DURANTE",
			is_equal_approx(_win.size.y, prima.size.y) and is_equal_approx(_win.size.x, prima.size.x),
			"la finestra si e' ridimensionata durante il trascinamento: %s invece di %s"
			% [str(_win.size), str(prima.size)])
	# ...e il contorno promette la geometria nuova
	var atteso := Rect2(prima.position, Vector2(prima.size.x, prima.size.y + giu))
	_check("CONTORNO_VISIBILE", _os._contorno.visible, "nessun contorno durante il trascinamento")
	_check("CONTORNO_PROMETTE", _vicini(_os._contorno_rect, atteso),
			"il contorno mostra %s invece di %s" % [str(_os._contorno_rect), str(atteso)])

	# i PIXEL: tratteggio, non una riga continua
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	var t := _tratteggio(img, _os._contorno_rect)
	print("   tratteggio sul bordo inferiore: %d scuri, %d chiari, %d alternanze (riga y=%d)"
			% [int(t["scuri"]), int(t["chiari"]), int(t["cambi"]), int(t["y"])])
	_check("CONTORNO_DISEGNATO", int(t["scuri"]) >= 20 and int(t["chiari"]) >= 20,
			"sul bordo inferiore non c'e' un tratteggio: %d scuri, %d chiari"
			% [int(t["scuri"]), int(t["chiari"])])
	_check("CONTORNO_TRATTEGGIATO", int(t["cambi"]) >= 15,
			"solo %d alternanze scuro/chiaro: e' una riga continua, non un tratteggio"
			% int(t["cambi"]))
	_prova_riduzione(img, _os._contorno_rect)
	_foto(img, "contorno_ridimensiona.png")

	# il rilascio: la finestra prende esattamente cio' che il contorno prometteva
	await _bottone(presa + Vector2(0.0, giu), false)
	_check("SALTO_AL_RILASCIO", _vicini(Rect2(_win.position, _win.size), atteso),
			"al rilascio la finestra e' %s invece di %s (il contorno aveva promesso male)"
			% [str(Rect2(_win.position, _win.size)), str(atteso)])
	_check("CONTORNO_SPARISCE", not _os._contorno.visible,
			"il contorno resta disegnato dopo il rilascio")

# ---------- 3b: il tratteggio dopo la riduzione a 2/3 ----------
# In partita l'OS non si guarda a 1:1: il SubViewport finisce sul quad del monitor e
# nell'overlay a tutto schermo a circa 2/3, con la CRT sopra. Un tratteggio da 1 px la'
# dentro si media e diventa grigio piatto -- che e' esattamente il difetto che il
# blocco da 2 px evita. Si riduce l'immagine con la bilineare (come farebbe il
# ridimensionamento della texture) e si misura quanto il bordo ancora OSCILLA:
# l'escursione fra il pixel piu' chiaro e il piu' scuro della striscia.
func _prova_riduzione(img: Image, r: Rect2) -> void:
	var piccola := img.duplicate() as Image
	piccola.resize(int(img.get_width() * 2.0 / 3.0), int(img.get_height() * 2.0 / 3.0),
			Image.INTERPOLATE_BILINEAR)
	var k := 2.0 / 3.0
	var y := int(r.end.y * k) - 2
	var minimo := 1.0
	var massimo := 0.0
	for x in range(int(r.position.x * k) + 8, int(r.position.x * k) + 140):
		if x < 0 or x >= piccola.get_width() or y < 0 or y >= piccola.get_height():
			continue
		var l := piccola.get_pixel(x, y).get_luminance()
		minimo = minf(minimo, l)
		massimo = maxf(massimo, l)
	print("   dopo la riduzione a 2/3: escursione %.2f (da %.2f a %.2f)"
			% [massimo - minimo, minimo, massimo])
	_check("TRATTEGGIO_SOPRAVVIVE_ALLA_RIDUZIONE", massimo - minimo >= 0.35,
			"ridotto a 2/3 il bordo oscilla solo di %.2f: e' diventato grigio piatto"
			% (massimo - minimo))

# ---------- 5: lo spostamento ----------

func _prova_sposta() -> void:
	await _rimetti_a_posto()
	var prima := Rect2(_win.position, _win.size)
	var d := Vector2(180.0, 90.0)
	var presa := prima.position + Vector2(200.0, OSWindow.BORDER + OSWindow.TITLE_H * 0.5)
	await _muovi(presa)
	await _bottone(presa, true)
	await _muovi(presa + d * 0.5)
	await _muovi(presa + d)

	var atteso := Rect2(prima.position + d, prima.size)
	_check("SPOSTA_FINESTRA_FERMA", _win.position.is_equal_approx(prima.position),
			"la finestra si e' spostata durante il trascinamento: %s" % str(_win.position))
	_check("SPOSTA_CONTORNO", _os._contorno.visible and _vicini(_os._contorno_rect, atteso),
			"il contorno mostra %s invece di %s" % [str(_os._contorno_rect), str(atteso)])
	await _bottone(presa + d, false)
	_check("SPOSTA_AL_RILASCIO", _vicini(Rect2(_win.position, _win.size), atteso),
			"al rilascio la finestra e' %s invece di %s"
			% [str(Rect2(_win.position, _win.size)), str(atteso)])

# ---------- 6: il contorno non promette l'impossibile ----------

func _prova_confine() -> void:
	await _rimetti_a_posto()
	var prima := Rect2(_win.position, _win.size)
	var presa := Vector2(prima.position.x + 200.0, prima.end.y - 2.0)
	var limite: float = _win.area_utile().end.y     # lo schermo MENO la barra
	await _muovi(presa)
	await _bottone(presa, true)
	await _muovi(presa + Vector2(0.0, 3000.0))
	_check("CONTORNO_DENTRO_LO_SCHERMO", absf(_os._contorno_rect.end.y - limite) <= EPS,
			"il contorno arriva a y=%.1f, oltre il confine %.1f: al rilascio si vedrebbe uno scatto"
			% [_os._contorno_rect.end.y, limite])
	await _bottone(presa + Vector2(0.0, 3000.0), false)
	_check("FINESTRA_DENTRO_LO_SCHERMO", absf(_win.position.y + _win.size.y - limite) <= EPS,
			"dopo il rilascio il fondo e' a y=%.1f invece di %.1f"
			% [_win.position.y + _win.size.y, limite])

# ---------- 7: gli interruttori ----------

func _prova_interruttori() -> void:
	# a) senza il contorno sul ridimensionamento si torna al comportamento "dal vivo"
	OSWindow.CONTORNO_RIDIMENSIONA = false
	await _rimetti_a_posto()
	var prima := Rect2(_win.position, _win.size)
	var presa := Vector2(prima.position.x + 200.0, prima.end.y - 2.0)
	await _muovi(presa)
	await _bottone(presa, true)
	await _muovi(presa + Vector2(0.0, 120.0))
	_check("INTERRUTTORE_RIDIM_DAL_VIVO", _win.size.y > prima.size.y + 100.0,
			"con CONTORNO_RIDIMENSIONA a false la finestra deve ridimensionarsi subito: %.1f -> %.1f"
			% [prima.size.y, _win.size.y])
	_check("INTERRUTTORE_RIDIM_NIENTE_CONTORNO", not _os._contorno.visible,
			"contorno mostrato con l'interruttore spento")
	await _bottone(presa + Vector2(0.0, 120.0), false)
	OSWindow.CONTORNO_RIDIMENSIONA = true

	# b) lo stesso per lo spostamento
	OSWindow.CONTORNO_SPOSTA = false
	await _rimetti_a_posto()
	prima = Rect2(_win.position, _win.size)
	var presa2 := prima.position + Vector2(200.0, OSWindow.BORDER + OSWindow.TITLE_H * 0.5)
	await _muovi(presa2)
	await _bottone(presa2, true)
	await _muovi(presa2 + Vector2(150.0, 0.0))
	_check("INTERRUTTORE_SPOSTA_DAL_VIVO", _win.position.x > prima.position.x + 120.0,
			"con CONTORNO_SPOSTA a false la finestra deve seguire il mouse: %.1f -> %.1f"
			% [prima.position.x, _win.position.x])
	_check("INTERRUTTORE_SPOSTA_NIENTE_CONTORNO", not _os._contorno.visible,
			"contorno mostrato con l'interruttore spento")
	await _bottone(presa2 + Vector2(150.0, 0.0), false)
	OSWindow.CONTORNO_SPOSTA = true

# ---------- strumenti ----------

# Il tratteggio e' fatto di blocchi alterni: su una riga del bordo si devono trovare
# pixel molto scuri E molto chiari, e devono ALTERNARSI. Si guarda la striscia bassa
# del contorno (che dopo un trascinamento in giu' sta sul teal del desktop, che non e'
# ne' scuro ne' chiaro per queste soglie).
# La riga si scegli per INCHIOSTRO (scuri + chiari) e non per alternanze: scegliendola
# per alternanze, una striscia piena non ne aveva nessuna e il test riportava "0 scuri,
# 0 chiari", cioe' "non c'e' niente disegnato" -- un difetto diverso da quello vero
# (disegnato, ma non tratteggiato). Misurato sabotando la trama il 21/09/2026.
func _tratteggio(img: Image, r: Rect2) -> Dictionary:
	var meglio := {"scuri": 0, "chiari": 0, "cambi": 0, "y": -1}
	var y1 := int(r.end.y)
	for y in range(y1 - Win95.CONTORNO_SPESSORE - 2, y1 + 1):
		if y < 0 or y >= img.get_height():
			continue
		var scuri := 0
		var chiari := 0
		var cambi := 0
		var ultimo := 0
		for x in range(int(r.position.x) + 8, int(r.position.x) + 208):
			if x < 0 or x >= img.get_width():
				continue
			var l := img.get_pixel(x, y).get_luminance()
			var stato := 0
			if l < 0.25:
				stato = -1
			elif l > 0.9:
				stato = 1
			if stato == -1:
				scuri += 1
			elif stato == 1:
				chiari += 1
			if stato != 0:
				if ultimo != 0 and stato != ultimo:
					cambi += 1
				ultimo = stato
		if scuri + chiari > int(meglio["scuri"]) + int(meglio["chiari"]):
			meglio = {"scuri": scuri, "chiari": chiari, "cambi": cambi, "y": y}
	return meglio

func _foto(img: Image, nome: String) -> void:
	if img == null or img.is_empty():
		return
	DirAccess.make_dir_recursive_absolute(OUT)
	img.save_png(OUT + nome)
	print("   foto: %s" % ProjectSettings.globalize_path(OUT + nome))

# Ogni prova parte dalla stessa geometria, lontano dai bordi.
func _rimetti_a_posto() -> void:
	_win.position = Vector2(140.0, 110.0)
	_win.size = Vector2(700.0, 430.0)
	for i in range(3):
		await get_tree().process_frame

func _vicini(a: Rect2, b: Rect2) -> bool:
	return absf(a.position.x - b.position.x) <= EPS and absf(a.position.y - b.position.y) <= EPS \
			and absf(a.size.x - b.size.x) <= EPS and absf(a.size.y - b.size.y) <= EPS

func _muovi(pos: Vector2) -> void:
	var m := InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	_vp.push_input(m, true)
	await get_tree().process_frame

func _bottone(pos: Vector2, giu: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = giu
	e.position = pos
	e.global_position = pos
	_vp.push_input(e, true)
	await get_tree().process_frame

func _check(nome: String, ok: bool, perche: String) -> void:
	if ok:
		print("PASS  " + nome)
	else:
		print("FAIL  " + nome + " --- " + perche)
		if not _fails.has(nome):
			_fails.append(nome)
