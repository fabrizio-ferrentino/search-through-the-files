extends Node

# Strumento di sviluppo (non un test): fotografa la VISTA PC come la vede il giocatore,
# cioe' l'overlay col CRT dentro la finestra vera del gioco, e misura le scanline.
#
# Perche' serve: il CRT viene giudicato a occhio, ma l'occhio guarda una foto a una
# risoluzione, e lo shader lavora a un'altra. La finestra del gioco e' 1280x720
# (project.godot) mentre l'OS e' 1440x1080: l'overlay finisce sullo schermo a 2/3, e
# un effetto pensato "per pixel dell'OS" la' dentro puo' battere coi pixel veri.
# Qui si fotografa la stanza VERA (main.tscn), si entra nel PC e si salva:
#   vista_pc_<L>x<A>.png        quello che vede il giocatore, intero
#   zoom_pc_<L>x<A>.png         un ritaglio ingrandito x4 (testo + desktop), per i pixel
#   vista_stanza_<L>x<A>.png    la stanza col monitor 3D (lo stesso OS, senza CRT)
# e si stampa il profilo delle scanline su una zona piatta del desktop.
#
# Esecuzione (FINESTRA: serve il rasterizzatore):
#   & $godot --path $proj res://tests/crt_look_check.tscn
#   & $godot --path $proj res://tests/crt_look_check.tscn --resolution 1920x1080
# ============================================================

const OUT := "user://crt/"

var _room: Node = null
var _player: Node = null

func _ready() -> void:
	get_tree().create_timer(60.0).timeout.connect(func(): _timeout())
	await get_tree().process_frame
	GameManager.threats_enabled = false     # niente nemici durante le foto
	GameManager.start_new_run(2024)
	GameManager.pc_on = true
	GameManager.logged_in = true
	_room = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(_room)
	for i in range(8):
		await get_tree().process_frame
	_player = _room.find_child("Camera3D", true, false)
	if _player == null:
		print("ERRORE: camera non trovata")
		get_tree().quit(1)
		return

	var dim := get_tree().root.get_texture().get_image().get_size()
	var tag := "%dx%d" % [dim.x, dim.y]
	print("finestra: %s   (base del progetto 1920x1080, OS 1440x1080)" % tag)

	# --- la stanza col monitor (prima di entrare) ---
	# La stanza parte NERA e si svela con una dissolvenza di 1 s (fade_out di
	# Fade_transition): fotografarla prima vuol dire misurare il velo, non il monitor.
	# Il primo giro di questo strumento ci e' cascato -- monitor "a un terzo della
	# luminosita'", bianco puro misurato 94/255 -- ed era solo la dissolvenza a meta'.
	await get_tree().create_timer(1.6).timeout
	var stanza := await _foto("vista_stanza_" + tag + ".png")
	_misura_monitor(stanza)

	# --- dentro il PC: un Esplora e un Blocco note, per avere testo su bianco e teal ---
	_player._show_pc_overlay()
	var os_node = _player._os
	var w1: OSWindow = os_node.open_app("explorer", null)
	w1.position = Vector2(60, 60)
	w1.size = Vector2(700, 460)
	for i in range(10):
		await get_tree().process_frame
	var img := await _foto("vista_pc_" + tag + ".png")

	# ritaglio ingrandito: angolo in alto a sinistra della finestra (titolo, menu, icone)
	var k := float(dim.y) / 1080.0                 # scala OS -> schermo
	var x0 := float(dim.x) * 240.0 / 1920.0        # l'overlay e' centrato in orizzontale
	var crop := Rect2i(int(x0 + 40.0 * k), int(40.0 * k), int(260.0 * k), int(150.0 * k))
	var z := img.get_region(crop)
	z.resize(z.get_width() * 4, z.get_height() * 4, Image.INTERPOLATE_NEAREST)
	z.save_png(OUT + "zoom_pc_" + tag + ".png")

	# --- leggibilita': contrasto del testo (P95 - P5 della luminanza) su tre casi ---
	# rettangoli in coordinate dell'OS, sulla finestra aperta sopra (60,60 700x460)
	_leggibilita(img, "titolo  (bianco su blu) ", Rect2(90, 66, 150, 26), k, x0)
	_leggibilita(img, "indirizzo (nero su bianco)", Rect2(177, 204, 108, 18), k, x0)
	_leggibilita(img, "menu    (nero su grigio)", Rect2(76, 100, 220, 28), k, x0)

	# --- profilo delle scanline su desktop piatto (a destra delle finestre) ---
	_profilo(img, int(x0 + 1000.0 * k), int(x0 + 1300.0 * k), int(600.0 * k), int(900.0 * k), k)

	print("foto in: %s" % ProjectSettings.globalize_path(OUT))
	get_tree().quit(0)

# Il colore del monitor nella stanza, al centro del quad, contro quello che l'OS
# disegna davvero li' (il teal del desktop, 0/128/128). Un quad UNSHADED dovrebbe
# riportarlo identico: se esce piu' scuro, c'e' di mezzo la catena del colore 3D.
func _misura_monitor(img: Image) -> void:
	var quad := _room.get_node_or_null("MonitorScreen") as Node3D
	if quad == null:
		print("monitor: quad non trovato")
		return
	# l'inquadratura della stanza e' fissa: il monitor sta li' (frazioni della foto,
	# misurate sulla vista_stanza). Il centro proiettato del quad non serve: il quad
	# viene ricostruito dopo il primo frame e la sua origine non e' il centro visibile.
	var c := Vector2(img.get_width() * 0.47, img.get_height() * 0.52)
	var s := Color(0, 0, 0)
	var n := 0
	for dy in range(-6, 7):
		for dx in range(30, 50):       # un po' a destra del centro: li' e' desktop vuoto
			var p := Vector2i(int(c.x) + dx, int(c.y) + dy)
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				s += img.get_pixel(p.x, p.y)
				n += 1
	s /= float(maxi(n, 1))
	var env := get_viewport().world_3d.environment if get_viewport().world_3d else null
	print("monitor nella stanza: RGB %d/%d/%d al centro %s (l'OS disegna 0/128/128)   tonemap=%s"
			% [int(s.r * 255.0), int(s.g * 255.0), int(s.b * 255.0), str(c),
			str(env.tonemap_mode) if env else "?"])

# Quanto si stacca il testo dal suo fondo: la distanza fra il 5o e il 95o percentile
# della luminanza nel riquadro. Scanline, alone e maschera la ABBASSANO tutti (scuriscono
# il chiaro, schiariscono lo scuro): e' il numero da non peggiorare, perche' qui il
# giocatore deve leggere codici di 4 caratteri.
func _leggibilita(img: Image, nome: String, r_os: Rect2, k: float, x0: float) -> void:
	var v: Array[float] = []
	for y in range(int(r_os.position.y * k), int(r_os.end.y * k)):
		for x in range(int(x0 + r_os.position.x * k), int(x0 + r_os.end.x * k)):
			v.append(img.get_pixel(x, y).get_luminance())
	v.sort()
	var p5 := v[int(v.size() * 0.05)]
	var p95 := v[int(v.size() * 0.95)]
	print("leggibilita' %s: %.3f  (scuro %.3f, chiaro %.3f)" % [nome, p95 - p5, p5, p95])

func _timeout() -> void:
	print("ERRORE: timeout")
	get_tree().quit(1)

func _foto(nome: String) -> Image:
	for i in range(3):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	var img := get_tree().root.get_texture().get_image()
	img.save_png(OUT + nome)
	return img

# Media di luminanza per RIGA su una banda piatta. Le scanline dovrebbero dare un
# motivo regolare (periodo = 2 righe dell'OS, cioe' 2*k righe di schermo). Se il periodo
# non e' un numero intero di pixel, il motivo "batte": l'ampiezza riga per riga cambia
# su scala lunga. Si misura proprio quello: l'escursione locale (max-min su ogni
# finestra di 4 righe) e quanto VARIA lungo la banda.
func _profilo(img: Image, xa: int, xb: int, ya: int, yb: int, k: float) -> void:
	var m: Array[float] = []
	for y in range(ya, yb):
		var s := 0.0
		for x in range(xa, xb):
			s += img.get_pixel(x, y).get_luminance()
		m.append(s / float(xb - xa))
	var righe := PackedStringArray()
	for i in range(mini(24, m.size())):
		righe.append("%.3f" % m[i])
	# regola di crt.gdshader: periodo = altezza / scanline_righe (360), arrotondato a
	# un intero e mai sotto 2 -- un periodo intero e' cio' che rende il motivo stabile
	var periodo: float = maxf(2.0, roundf(float(img.get_height()) / 360.0))
	print("periodo scanline atteso: %d righe di schermo (intero)" % int(periodo))
	print("prime 24 righe: " + " ".join(righe))
	var esc: Array[float] = []
	for i in range(m.size() - 4):
		var lo := 1.0
		var hi := 0.0
		for j in range(4):
			lo = minf(lo, m[i + j])
			hi = maxf(hi, m[i + j])
		esc.append(hi - lo)
	var media := 0.0
	for e in esc:
		media += e
	media /= float(esc.size())
	var v := 0.0
	var emin := 1.0
	var emax := 0.0
	for e in esc:
		v += (e - media) * (e - media)
		emin = minf(emin, e)
		emax = maxf(emax, e)
	v = sqrt(v / float(esc.size()))
	var lum := 0.0
	for x in m:
		lum += x
	lum /= float(m.size())
	print("luminanza media %.3f | escursione locale media %.3f (min %.3f, max %.3f) | variazione %.0f%%"
			% [lum, media, emin, emax, 100.0 * v / maxf(media, 0.0001)])
