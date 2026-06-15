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
var edge_margin = 0.05
var move_speed = 12.0
var can_change_pos = true
var reset_margin = 0.10 # Margine largo per resettare

# --- animazione di ingresso nel PC (telecamera che entra nello schermo) ---
@export var fly_time := 0.4        # durata del volo verso lo schermo (secondi) - più basso = più veloce
@export var fly_fov_zoom := 12.0   # di quanto stringere il FOV durante il volo (zoom)
var entering := false

# --- schermo del monitor nella stanza (mostra il desktop del PC) ---
@export_group("Schermo monitor")
@export var screen_w := 0.35                        # larghezza del pannello dello schermo
@export var screen_h := 0.31                        # altezza del pannello dello schermo
@export var screen_push := 0.03                     # sporgenza davanti al vetro bombato del CRT (evita che la bombatura buchi il pannello)
@export var screen_nudge := Vector3(0.007, 0.0, 0)  # micro-aggiustamento di posizione

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_monitor_screen()
	if GameManager.returning_from_pc:
		# rientro dal PC: animazione inversa (zoom-out dallo schermo + dissolvenza dal nero)
		GameManager.returning_from_pc = false
		_play_exit_reverse()
		return
	if GameManager.first_time_in_room:
		$"../Fade_transition".show()
		$"../Fade_transition/fade_timer".start()
		$"../Fade_transition/AnimationPlayer".play("fade_out")
		GameManager.first_time_in_room = false
	_update_arrows() # Imposta le frecce iniziali

func _input(event):
	if entering:
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
				print("Enter in Pc mode")
				_enter_pc()

# Animazione: la telecamera entra dentro lo schermo, poi dissolvenza e scena PC.
func _enter_pc() -> void:
	if entering:
		return
	entering = true
	arrow_left.hide()
	arrow_right.hide()
	arrow_down.hide()

	var screen := _screen_point()
	# interpola dal transform ATTUALE (niente scatto iniziale del look_at)
	var t_start := global_transform
	var near := t_start.origin.lerp(screen, 0.9)   # quasi a contatto con lo schermo
	var t_end := Transform3D(Basis.IDENTITY, near).looking_at(screen, Vector3.UP)
	var start_fov := fov

	# dissolvenza al nero IN PARALLELO al volo: a zoom massimo lo schermo e' gia' nero
	_play_fade("fade_in", fly_time * 0.85)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_method(func(s: float): global_transform = t_start.interpolate_with(t_end, s), 0.0, 1.0, fly_time)
	tw.parallel().tween_property(self, "fov", start_fov - fly_fov_zoom, fly_time)
	tw.tween_callback(_go_to_pc)

func _go_to_pc() -> void:
	get_tree().change_scene_to_file("res://scenes/ComputerMode.tscn")

# Animazione inversa al rientro: parte dallo schermo (nero + zoom) e si allontana rivelando la stanza.
func _play_exit_reverse() -> void:
	entering = true
	arrow_left.hide()
	arrow_right.hide()
	arrow_down.hide()
	var screen := _screen_point()
	var t_default := global_transform
	var fov_default := fov
	var near := t_default.origin.lerp(screen, 0.9)
	var t_start := Transform3D(Basis.IDENTITY, near).looking_at(screen, Vector3.UP)
	global_transform = t_start
	fov = fov_default - fly_fov_zoom
	# dissolvenza DAL nero in parallelo allo zoom-out
	_play_fade("fade_out", fly_time)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(s: float): global_transform = t_start.interpolate_with(t_default, s), 0.0, 1.0, fly_time)
	tw.parallel().tween_property(self, "fov", fov_default, fly_time)
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

# --- schermo del monitor: mostra la "foto" del desktop sul vetro ---
func _setup_monitor_screen() -> void:
	# esci dalla fase di _ready prima di toccare l'albero (altrimenti add_child fallisce)
	await get_tree().process_frame
	_kill_monitor_emission()   # spegne le scritte verdi del terminale del modello
	if GameManager.pc_screenshot == null:
		await _make_initial_screenshot()
	if GameManager.pc_screenshot != null:
		_build_screen_quad(GameManager.pc_screenshot)

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

# Genera una foto iniziale renderizzando il desktop una volta (così lo schermo
# si vede "acceso" anche prima di entrare nel PC).
func _make_initial_screenshot() -> void:
	if DisplayServer.get_name() == "headless":
		return   # niente GPU: impossibile leggere la texture del viewport
	# Render-to-texture: un SubViewport dedicato in cui gira solo il desktop.
	var sv := SubViewport.new()
	sv.size = Vector2i(1440, 1080)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.transparent_bg = false
	sv.disable_3d = true
	add_child(sv)
	var os_ctrl = load("res://scripts/os/desktop.gd").new()
	sv.add_child(os_ctrl)
	os_ctrl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	os_ctrl.set_process_input(false)
	os_ctrl.set_process_unhandled_input(false)
	for i in range(6):
		await get_tree().process_frame
	if is_instance_valid(sv):
		var img = sv.get_texture().get_image()
		if img != null and not img.is_empty():
			GameManager.pc_screenshot = img
		sv.queue_free()

func _build_screen_quad(img: Image) -> void:
	if img == null or img.is_empty():
		return
	var old = get_parent().get_node_or_null("MonitorScreen")
	if old:
		old.queue_free()

	var tex := ImageTexture.create_from_image(img)
	var quad := MeshInstance3D.new()
	quad.name = "MonitorScreen"
	var mesh := QuadMesh.new()
	quad.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
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
	if entering:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	var mouse_pos = get_viewport().get_mouse_position()
	var mouse_x_pct = mouse_pos.x / viewport_size.x
	var mouse_y_pct = mouse_pos.y / viewport_size.y
	
	# --- LOGICA DI MOVIMENTO ---
	if mouse_x_pct < edge_margin:
		if can_change_pos and target_yaw != pos_back:
			print("Guardo a Sinistra")
			_move_view("left")
			can_change_pos = false
			
	elif mouse_x_pct > (1.0 - edge_margin):
		if can_change_pos and target_yaw != pos_back:
			print("Guardo a Destra")
			_move_view("right")
			can_change_pos = false
			
	elif mouse_y_pct > 0.95:
		if can_change_pos:
			if target_yaw == pos_center:
				target_yaw = pos_back
			elif target_yaw == pos_back:
				target_yaw = pos_center
			can_change_pos = false
			_update_arrows()
	else:
		# Resettiamo il comando SOLO se il mouse si allontana bene dai bordi
		if mouse_x_pct > reset_margin and mouse_x_pct < (1.0 - reset_margin) and mouse_y_pct < 0.85:
			can_change_pos = true
	# Rotazione fluida
	rotation_degrees.y = lerp(rotation_degrees.y, target_yaw, delta * move_speed)

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
