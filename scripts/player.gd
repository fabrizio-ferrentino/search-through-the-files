extends Camera3D

@onready var raycast = $RayCast3D
# Riferimenti ai nodi UI (Assicurati che i percorsi siano corretti o usa %)
@onready var arrow_left = $"../HUD/ArrowsUI/ArrowLeft"
@onready var arrow_right = $"../HUD/ArrowsUI/ArrowRight"
@onready var arrow_down = $"../HUD/ArrowsUI/ArrowDown"

# --- CONFIGURAZIONE POSIZIONI ---
var pos_left = 70.0
var pos_center = 0.0
var pos_right = -70.0
var pos_back = 180.0 

var target_yaw = 0.0
var move_speed = 12.0
var can_change_pos = true

# Metodo delle frecce: false = al passaggio del mouse (hover, com'e' ora);
# true = bisogna CLICCARE la freccia. Cambia qui (o dall'Inspector) per scegliere.
@export var click_to_turn := true

# --- animazione di ingresso nel PC (telecamera che entra nello schermo) ---
@export var fly_time := 0.4        # durata del volo verso lo schermo (secondi) - più basso = più veloce
@export var fly_fov_zoom := 12.0   # di quanto stringere il FOV durante il volo (zoom)
var entering := false               # transizione in corso (volo telecamera)
var _in_pc := false                 # vista PC attiva (overlay a tutto schermo)
var _ending := false                # finale in corso (vittoria): blocca ogni input

# --- PC coesistente: l'OS gira sempre in un SubViewport autonomo ---
const OS_SIZE := Vector2i(1440, 1080)
var _os_viewport: SubViewport = null   # qui vive l'OS, rende sempre (monitor dal vivo)
var _os = null                         # OSDesktop
var _pc_layer: CanvasLayer = null      # overlay a tutto schermo (vista "dentro il PC")
var _pc_bg: ColorRect = null           # sfondo nero dell'overlay (porta il cursore reale)
var _pc_fade: ColorRect = null         # rettangolo nero per le dissolvenze dell'overlay
var _screen_tex: ImageTexture = null   # texture del monitor 3D (aggiornata dal SubViewport)
var _poll_accum := 0.0
var _home_transform: Transform3D       # posa "a riposo" della telecamera (centro stanza)
var _home_fov := 75.0

# --- schermo del monitor nella stanza (mostra il desktop del PC) ---
@export_group("Schermo monitor")
@export var screen_w := 0.35                        # larghezza del pannello dello schermo
@export var screen_h := 0.31                        # altezza del pannello dello schermo
@export var screen_push := 0.03                     # sporgenza davanti al vetro bombato del CRT (evita che la bombatura buchi il pannello)
@export var screen_nudge := Vector3(0.007, 0.0, 0)  # micro-aggiustamento di posizione

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_home_transform = global_transform   # posa centrale da cui si entra/torna
	_home_fov = fov
	# Al primo ingresso copri SUBITO lo schermo col nero, PRIMA di qualsiasi await:
	# cosi' il livello non lampeggia mentre si costruiscono SubViewport e schermo
	# del monitor. La rivelazione (fade_out) parte solo a costruzione finita.
	var first: bool = GameManager.first_time_in_room
	if first:
		$"../Fade_transition".show()
		$"../Fade_transition".color = Color(0, 0, 0, 1)
	# attendi che Main finisca di costruirsi prima di aggiungere nodi fratelli
	await get_tree().process_frame
	_spawn_computer()                    # crea l'OS persistente (overlay nascosto)
	await _setup_monitor_screen()
	if first:
		$"../Fade_transition/fade_timer".start()
		$"../Fade_transition/AnimationPlayer".play("fade_out")
		GameManager.first_time_in_room = false
	_update_arrows() # Imposta le frecce iniziali
	_setup_arrow_input()

# Crea l'OS in un SubViewport autonomo che gira SEMPRE (anche stando in stanza):
# cosi' il monitor 3D mostra il PC dal vivo (avvio compreso). La vista a tutto
# schermo e' un overlay separato, mostrato solo quando si "entra" nello schermo.
func _spawn_computer() -> void:
	# 1) SubViewport dell'OS: sempre nell'albero e visibile -> rende di continuo.
	_os_viewport = SubViewport.new()
	_os_viewport.size = OS_SIZE
	_os_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_os_viewport.transparent_bg = false
	_os_viewport.disable_3d = true
	get_parent().add_child(_os_viewport)
	_os = load("res://scripts/os/desktop.gd").new()
	# rettangolo fisso 1440x1080 (ancore in alto a sx, niente full-rect che
	# raddoppierebbe gli offset): cosi' size e' corretta gia' in _ready -> taskbar,
	# menu Start e overlay risultano centrati anche al primo avvio.
	_os.position = Vector2.ZERO
	_os.size = Vector2(OS_SIZE)
	_os_viewport.add_child(_os)
	if _os.has_signal("exit_requested"):
		_os.exit_requested.connect(_exit_pc)
	if _os.has_signal("game_won"):
		_os.game_won.connect(_on_game_won)

	# 2) Overlay a tutto schermo: lo stesso schermo, ingrandito col CRT (nascosto in stanza).
	_pc_layer = CanvasLayer.new()
	_pc_layer.name = "PCLayer"
	_pc_layer.layer = 10
	_pc_layer.visible = false
	get_parent().add_child(_pc_layer)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_pc_layer.add_child(bg)
	_pc_bg = bg   # e' il Control del viewport principale sotto il mouse: pilota il cursore

	var screen := TextureRect.new()
	screen.texture = _os_viewport.get_texture()
	screen.position = Vector2((1920 - OS_SIZE.x) / 2.0, 0.0)
	screen.size = Vector2(OS_SIZE)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/os/crt.gdshader")
	mat.set_shader_parameter("screen_size", Vector2(OS_SIZE))
	screen.material = mat
	_pc_layer.add_child(screen)

	_pc_fade = ColorRect.new()
	_pc_fade.color = Color.BLACK
	_pc_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pc_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pc_layer.add_child(_pc_fade)

func _input(event):
	if entering:
		return
	if _in_pc:
		# in vista PC: ESC esce, tutto il resto va inoltrato all'OS nel SubViewport
		if event.is_action_pressed("ui_cancel"):
			_exit_pc()
			return
		_forward_to_os(event)
		if event is InputEventMouse:
			_update_pc_cursor((event as InputEventMouse).position)
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Creiamo un raggio che parte dalla punta del mouse
		var camera = self
		var mouse_pos = get_viewport().get_mouse_position()
		var ray_origin = camera.project_ray_origin(mouse_pos)
		var ray_end = ray_origin + camera.project_ray_normal(mouse_pos) * 2000
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		var result = space_state.intersect_ray(query)
		if result:
			var collider = result.collider
			print("Ho colpito: ", collider.name)
			if (collider.name == "Monitor") and target_yaw == pos_center:
				var part := _hit_part(collider, int(result.get("shape", -1)))
				if part == "Computer":
					# pulsante di accensione del case: accende se spento, spegne se acceso
					_power_button()
				else:
					# schermo del monitor: entra nel PC (se spento si vedra' "nessun segnale")
					_enter_pc()

# Ricava il nome del CollisionShape3D colpito (CollisionShape3D = schermo, Computer = case).
func _hit_part(body, shape_idx: int) -> String:
	if shape_idx < 0 or not body.has_method("shape_find_owner"):
		return ""
	var owner_id: int = body.shape_find_owner(shape_idx)
	var node = body.shape_owner_get_owner(owner_id)
	return node.name if node else ""

# Inoltra l'input della stanza all'OS nel SubViewport, riportando la posizione
# del mouse nello spazio dello schermo (lo schermo e' centrato in orizzontale).
func _forward_to_os(event: InputEvent) -> void:
	if _os_viewport == null:
		return
	var ev := event
	if event is InputEventMouse:
		ev = event.duplicate()
		ev.position = event.position - Vector2((1920 - OS_SIZE.x) / 2.0, 0.0)
	_os_viewport.push_input(ev, true)

# Aggiorna il cursore reale dell'overlay PC chiedendo all'OS la forma per il punto
# sotto il mouse. Il SubViewport non pilota il cursore reale: lo applichiamo qui sul
# ColorRect dell'overlay, l'unico Control del viewport principale sotto il mouse.
func _update_pc_cursor(screen_pos: Vector2) -> void:
	if _pc_bg == null or _os == null:
		return
	var os_pos := screen_pos - Vector2((1920 - OS_SIZE.x) / 2.0, 0.0)
	_pc_bg.mouse_default_cursor_shape = _os.cursor_shape_at(os_pos)

# Pulsante di accensione sul case: spegne il PC se acceso, lo accende se spento.
# Non cambia scena: l'OS vive sempre, il monitor mostra l'avvio/login dal vivo.
func _power_button() -> void:
	if entering or _in_pc or _os == null:
		return
	if GameManager.pc_on:
		_os.power_off()
	else:
		_os.boot()

# Entra nella vista PC: la telecamera vola nello schermo, poi appare l'overlay
# a tutto schermo dell'OS (lo stesso che gira sul monitor).
func _enter_pc() -> void:
	if entering or _in_pc or _pc_layer == null:
		return
	entering = true
	arrow_left.hide()
	arrow_right.hide()
	arrow_down.hide()

	var screen := _screen_point()
	var t_start := global_transform
	var near := t_start.origin.lerp(screen, 0.9)   # quasi a contatto con lo schermo
	var t_end := Transform3D(Basis.IDENTITY, near).looking_at(screen, Vector3.UP)
	var start_fov := fov

	_play_fade("fade_in", fly_time * 0.85)   # la stanza va al nero durante il volo
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(func(s: float): global_transform = t_start.interpolate_with(t_end, s), 0.0, 1.0, fly_time)
	tw.parallel().tween_property(self, "fov", start_fov - fly_fov_zoom, fly_time)
	tw.tween_callback(_show_pc_overlay)

# A volo finito (schermo nero) mostra subito l'overlay dell'OS, senza dissolvenza
# dal nero: una volta "dentro" il PC il desktop compare immediatamente.
func _show_pc_overlay() -> void:
	_in_pc = true
	_pc_fade.color.a = 0.0
	_pc_layer.visible = true
	entering = false

# Esce dalla vista PC (ESC o "Annulla"): l'OS va al nero, si nasconde l'overlay e
# la telecamera torna indietro rivelando la stanza. L'OS resta com'e' (acceso/login/desktop).
func _exit_pc() -> void:
	if not _in_pc or entering:
		return
	entering = true
	# l'OS puo' aver lasciato un cursore di resize sull'overlay: torna alla freccia
	if _pc_bg:
		_pc_bg.mouse_default_cursor_shape = Control.CURSOR_ARROW
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	var tw := create_tween()
	tw.tween_property(_pc_fade, "color:a", 1.0, 0.25)
	tw.tween_callback(_finish_exit)

# --- vittoria: cartella segreta sbloccata (segnale dall'OS) ---
func _on_game_won() -> void:
	if _ending:
		return
	_ending = true
	entering = true            # blocca input e movimento fino al cambio scena
	if _pc_layer:
		_pc_layer.visible = false
	_in_pc = false
	_show_ending()

# Schermata finale a tutto schermo (sopra ogni cosa), con ritorno al menu.
func _show_ending() -> void:
	var layer := CanvasLayer.new()
	layer.name = "EndingLayer"
	layer.layer = 20
	get_parent().add_child(layer)

	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	bg.modulate.a = 0.0
	layer.add_child(bg)

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 40)
	bg.add_child(vb)

	var title := Label.new()
	title.text = "HAI VINTO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	vb.add_child(title)

	var btn := Button.new()
	btn.text = "Torna al menu"
	btn.custom_minimum_size = Vector2(240, 56)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vb.add_child(btn)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var tw := create_tween()
	tw.tween_property(bg, "modulate:a", 1.0, 1.2)

func _finish_exit() -> void:
	_pc_layer.visible = false
	_in_pc = false
	# la stanza e' nera (Fade_transition): torna alla posa di partenza svelandola
	var t_now := global_transform
	_play_fade("fade_out", fly_time)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(s: float): global_transform = t_now.interpolate_with(_home_transform, s), 0.0, 1.0, fly_time)
	tw.parallel().tween_property(self, "fov", _home_fov, fly_time)
	tw.tween_callback(func():
		entering = false
		_update_arrows())

# Avvia un'animazione della dissolvenza ("fade_in"=verso il nero, "fade_out"=dal nero)
# regolando la velocita' per farla durare il tempo indicato.
func _play_fade(anim: String, duration: float) -> void:
	var fade = get_node_or_null("../Fade_transition")
	if fade == null:
		return
	fade.show()
	var ap = fade.get_node_or_null("AnimationPlayer")
	if ap == null:
		return
	var a = ap.get_animation(anim)
	if a:
		ap.speed_scale = a.length / max(0.05, duration)
	ap.play(anim)

# --- schermo del monitor: mostra DAL VIVO il SubViewport dell'OS sul vetro ---
func _setup_monitor_screen() -> void:
	_kill_monitor_emission()   # spegne le scritte verdi del terminale del modello
	if _os_viewport == null:
		return
	# lascia renderizzare il SubViewport un paio di frame prima di leggerne la texture
	await get_tree().process_frame
	await get_tree().process_frame
	var img := _os_viewport.get_texture().get_image()
	if img == null or img.is_empty():
		img = Image.create(OS_SIZE.x, OS_SIZE.y, false, Image.FORMAT_RGBA8)
		img.fill(Color.BLACK)
	_screen_tex = ImageTexture.create_from_image(img)
	_build_screen_quad(_screen_tex)

# Aggiorna la texture del monitor 3D col contenuto attuale dell'OS (poche volte
# al secondo: basta per avvio/login/desktop e non pesa).
func _poll_monitor(delta: float) -> void:
	if _screen_tex == null or _os_viewport == null:
		return
	_poll_accum += delta
	if _poll_accum < 0.08:
		return
	_poll_accum = 0.0
	var img := _os_viewport.get_texture().get_image()
	if img == null or img.is_empty():
		return
	if img.get_size() == Vector2i(_screen_tex.get_width(), _screen_tex.get_height()):
		_screen_tex.update(img)
	else:
		_screen_tex.set_image(img)

# Spegne l'emissivo del modello del monitor (il finto terminale verde) cosi' lo
# schermo sottostante e' nero e il pannello del desktop puo' stare dentro la cornice.
func _kill_monitor_emission() -> void:
	var mon = get_node_or_null("../Monitor")
	if mon == null:
		return
	var mi = _find_mesh(mon)
	if mi == null:
		return
	for s in range(mi.get_surface_override_material_count()):
		var m = mi.get_active_material(s)
		if m is BaseMaterial3D:
			var d = m.duplicate()
			d.emission_enabled = false
			mi.set_surface_override_material(s, d)

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r = _find_mesh(c)
		if r:
			return r
	return null

func _build_screen_quad(tex: Texture2D) -> void:
	if tex == null:
		return
	var old = get_parent().get_node_or_null("MonitorScreen")
	if old:
		old.queue_free()

	var quad := MeshInstance3D.new()
	quad.name = "MonitorScreen"
	var mesh := QuadMesh.new()
	quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex   # ViewportTexture: il monitor mostra l'OS dal vivo
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	quad.material_override = mat
	get_parent().add_child(quad)

	# Se esiste il nodo di riferimento "test-schermo", ricalca esattamente
	# posizione/orientamento/dimensione del suo lato schermo.
	var ref = get_node_or_null("../test-schermo")
	if ref is MeshInstance3D and ref.mesh is BoxMesh:
		ref.visible = false
		var info := _face_from_box(ref)
		mesh.size = info["size"]
		quad.global_transform = Transform3D(info["basis"], info["origin"] + info["basis"].z * screen_push)
	else:
		mesh.size = Vector2(screen_w, screen_h)
		quad.global_position = _screen_point() + Vector3(0, 0, screen_push) + screen_nudge

# Ricava il rettangolo dello "schermo" da un box piatto: la faccia grande
# (asse piu' sottile = normale), orientata verso la camera e con l'alto in su.
func _face_from_box(box: MeshInstance3D) -> Dictionary:
	var t := box.global_transform
	var ms: Vector3 = box.mesh.size
	var dirs := [t.basis.x, t.basis.y, t.basis.z]
	var lens := [ms.x, ms.y, ms.z]
	# normale = asse con spessore (mondo) minore
	var ni := 0
	var minw := INF
	for i in range(3):
		var wl: float = dirs[i].length() * lens[i]
		if wl < minw:
			minw = wl
			ni = i
	# i due assi della faccia
	var face: Array = []
	for i in range(3):
		if i != ni:
			face.append(i)
	# larghezza = asse piu' orizzontale, altezza = piu' verticale
	var wi: int = face[0]
	var hi: int = face[1]
	if absf(dirs[face[0]].normalized().y) > absf(dirs[face[1]].normalized().y):
		wi = face[1]
		hi = face[0]
	var nz: Vector3 = dirs[ni].normalized()
	if nz.z < 0.0:
		nz = -nz
	var ny: Vector3 = dirs[hi].normalized()
	if ny.y < 0.0:
		ny = -ny
	var nx: Vector3 = ny.cross(nz).normalized()
	ny = nz.cross(nx).normalized()
	var width: float = dirs[wi].length() * lens[wi]
	var height: float = dirs[hi].length() * lens[hi]
	return {"basis": Basis(nx, ny, nz), "size": Vector2(width, height), "origin": t.origin}

func _screen_point() -> Vector3:
	# Centro dello schermo: centro dell'area di collisione del Monitor, spostato
	# sulla faccia frontale (verso la camera).
	var mon = get_node_or_null("../Monitor")
	if mon:
		var col = mon.get_node_or_null("CollisionShape3D")
		if col:
			var center = mon.global_transform * col.position
			if col.shape is BoxShape3D:
				# faccia frontale = mezza profondità lungo l'asse Z del monitor (verso la camera)
				center += mon.global_transform.basis.z * (col.shape.size.z * 0.5)
			return center
		return mon.global_position
	var glow = get_node_or_null("../ScreenGlow")
	if glow:
		return glow.global_position
	return global_position - global_transform.basis.z * 1.0

func _process(delta):
	if not _in_pc:
		_poll_monitor(delta)   # tieni il monitor 3D aggiornato quando si e' in stanza
	if entering or _in_pc:
		return
	# --- LOGICA DI MOVIMENTO ---
	# La zona attiva e' il RETTANGOLO della freccia visibile (non piu' tutto il bordo):
	# il cursore deve stare sul box-freccia al centro del lato.
	var mp := get_viewport().get_mouse_position()
	var r_left: Rect2 = arrow_left.get_global_rect()
	var r_right: Rect2 = arrow_right.get_global_rect()
	var r_down: Rect2 = arrow_down.get_global_rect()
	var over_left: bool = arrow_left.visible and r_left.has_point(mp)
	var over_right: bool = arrow_right.visible and r_right.has_point(mp)
	var over_down: bool = arrow_down.visible and r_down.has_point(mp)

	# feedback visivo: il pulsante sotto il cursore si illumina (in entrambe le modalita')
	arrow_left.hovered = over_left
	arrow_right.hovered = over_right
	arrow_down.hovered = over_down

	# Modalita' HOVER: il cursore sopra la freccia gira la visuale (con isteresi).
	# Modalita' CLICK: il giro avviene su _arrow_action() via segnale "clicked".
	if not click_to_turn:
		if over_left:
			if can_change_pos and target_yaw != pos_back:
				_move_view("left")
				can_change_pos = false
		elif over_right:
			if can_change_pos and target_yaw != pos_back:
				_move_view("right")
				can_change_pos = false
		elif over_down:
			if can_change_pos:
				if target_yaw == pos_center:
					target_yaw = pos_back
				elif target_yaw == pos_back:
					target_yaw = pos_center
				can_change_pos = false
				_update_arrows()
		else:
			# Isteresi: ri-abilita il cambio solo quando il cursore e' BEN FUORI da ogni
			# freccia (rettangolo + margine). Cosi' dopo un cambio un piccolo movimento
			# non ne fa subito un altro: il mouse deve davvero uscire dalla zona.
			var m := 70.0
			var near_arrow: bool = (arrow_left.visible and r_left.grow(m).has_point(mp)) \
				or (arrow_right.visible and r_right.grow(m).has_point(mp)) \
				or (arrow_down.visible and r_down.grow(m).has_point(mp))
			if not near_arrow:
				can_change_pos = true
	# Rotazione fluida
	rotation_degrees.y = lerp(rotation_degrees.y, target_yaw, delta * move_speed)

# Collega le frecce e imposta il filtro del mouse a seconda della modalita'.
func _setup_arrow_input() -> void:
	for a in [arrow_left, arrow_right, arrow_down]:
		a.mouse_filter = Control.MOUSE_FILTER_STOP if click_to_turn else Control.MOUSE_FILTER_IGNORE
		if click_to_turn:
			a.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# il segnale scatta solo in modalita' click (in hover il mouse_filter e' IGNORE)
	arrow_left.clicked.connect(func(): _arrow_action("left"))
	arrow_right.clicked.connect(func(): _arrow_action("right"))
	arrow_down.clicked.connect(func(): _arrow_action("down"))

# Cambio di visuale per la modalita' click (chiamato dal segnale della freccia).
func _arrow_action(d: String) -> void:
	if entering or _in_pc or _ending:
		return
	match d:
		"left":
			if target_yaw != pos_back:
				_move_view("left")
		"right":
			if target_yaw != pos_back:
				_move_view("right")
		"down":
			if target_yaw == pos_center:
				target_yaw = pos_back
			elif target_yaw == pos_back:
				target_yaw = pos_center
			_update_arrows()

func _move_view(direction):
	var old_yaw = target_yaw
	if direction == "left":
		if target_yaw == pos_right: target_yaw = pos_center
		elif target_yaw == pos_center: target_yaw = pos_left
			
	elif direction == "right":
		if target_yaw == pos_left: target_yaw = pos_center
		elif target_yaw == pos_center: target_yaw = pos_right
	
	if old_yaw != target_yaw:
		_update_arrows() # Aggiorna le frecce solo se la posizione è cambiata

# --- GESTIONE VISIBILITÀ FRECCE ---
func _update_arrows():
	# Nascondiamo tutto per resettare
	arrow_left.hide()
	arrow_right.hide()
	arrow_down.hide()
	match target_yaw:
		pos_center:
			arrow_left.show()
			arrow_right.show()
			arrow_down.show()
		pos_left:
			arrow_right.show()
		pos_right:
			arrow_left.show()
		pos_back:
			arrow_down.show()
