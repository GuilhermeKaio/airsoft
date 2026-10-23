class_name Weapon
extends Node3D

const Magazine = preload("res://Scripts/magazine.gd")
const MagazineLoader = preload("res://Scripts/magazine_loader.gd")

enum FireMode { SEMI, AUTO }
enum SpringModel { PHYSICAL, SIMPLIFIED }
enum WeaponModel { SHOTGUN, RIFLE, PISTOL_1911, PISTOL_GLOCK }

signal ammo_changed(current: int, max_capacity: int)
signal municao_alterada(current: int, max_capacity: int)
signal fire_mode_changed(new_mode: String)
signal modo_tiro_alterado(new_mode: String)
signal reload_started(duration: float)
signal recarga_iniciada(duration: float)
signal reload_completed()
signal recarga_concluida()
signal hop_up_adjusted(new_value: float)
signal hop_up_ajustado(new_value: float)
signal dry_fired()
signal disparo_seco()
signal incompatible_magazine()
signal carregador_incompativel()
signal magazine_equipped(magazine: Magazine)
signal cadencia_alterada(novo_rof: float, novo_intervalo: float)
signal mola_ajustada(nova_energia: float)
signal recoil_applied(pitch_deg: float, yaw_deg: float, shot_index: int)
signal recuo_aplicado(pitch_deg: float, yaw_deg: float, shot_index: int)
signal recoil_recovered()
signal recuo_recuperado()

@export_group("Recoil & Spray Pattern (SRS Adicionais Seção 3)")
@export var recoil_enabled: bool = true
@export var recoil_vertical_bullets: int = 5
@export var recoil_vertical_pitch: float = 1.2
@export var recoil_lateral_yaw: float = 0.9
@export var recoil_recovery_time: float = 0.25
@export var player_node: Node

var recovery_speed: float:
	get:
		return 1.0 / maxf(recoil_recovery_time, 0.001)
	set(value):
		if value > 0.0:
			recoil_recovery_time = 1.0 / value

var recoil_shot_index: int = 0
var current_recoil_offset: Vector2 = Vector2.ZERO # x: yaw, y: pitch (degrees)
var time_since_last_shot: float = 0.0
var _is_recoil_recovering: bool = false

@export_group("Weapon Identity & Models (SRS 3.2 & 4)")
@export var weapon_model: WeaponModel = WeaponModel.PISTOL_GLOCK
@export var projectiles_per_shot: int = 1
@export var spread_cone_angle: float = 0.0
@export var allowed_fire_modes: Array[FireMode] = [FireMode.SEMI, FireMode.AUTO]
@export var is_slide_locked_open: bool = false

@export_group("Prefabs")
@export var bb_scene: PackedScene
@export var weapon_prefab: PackedScene

@export_group("Spring & Energy System (SRS 3.2.1)")
@export var spring_model: SpringModel = SpringModel.PHYSICAL
@export var spring_k: float = 1192.0:
	set(value):
		spring_k = value
		mola_ajustada.emit(energy_joules)
@export var spring_x: float = 0.05:
	set(value):
		spring_x = value
		mola_ajustada.emit(energy_joules)
@export var nominal_energy_joules: float = 1.49:
	set(value):
		nominal_energy_joules = value
		mola_ajustada.emit(energy_joules)

var simplified_energy_joules: float:
	get:
		return nominal_energy_joules
	set(value):
		nominal_energy_joules = value
		mola_ajustada.emit(energy_joules)

@export_group("Ballistics & Hop-Up")
@export var spin_rad_s: float = 1200.0
@export var min_hop_up: float = 0.0
@export var max_hop_up: float = 2500.0
@export var hop_up_step: float = 50.0
@export var bullet_tracing_enabled: bool = true

const METERS_TO_FEET: float = 3.28084

@export_group("Motor, Gearbox & Cadence (SRS 3.2.2)")
@export var motor_rpm: float = 8100.0:
	set(value):
		motor_rpm = value
		_update_cadence()
@export var gear_ratio_n: float = 30.0:
	set(value):
		gear_ratio_n = value
		_update_cadence()
@export var rof: float = 4.5
@export var fire_interval: float = 0.22222222

@export_group("Firing Mechanics")
@export var fire_mode: FireMode = FireMode.SEMI
@export var reload_time: float = 2.0

@export_group("Magazine System")
@export var compatible_magazine_type: Magazine.Type = Magazine.Type.MAG_PISTOL_GLOCK
@export var equipped_magazine: Magazine

var energy_joules: float:
	get:
		return get_muzzle_energy()
	set(value):
		nominal_energy_joules = value
		spring_model = SpringModel.SIMPLIFIED

var spring_constant_k: float:
	get:
		return spring_k
	set(value):
		spring_k = value
		spring_model = SpringModel.PHYSICAL

var spring_compression_x: float:
	get:
		return spring_x
	set(value):
		spring_x = value
		spring_model = SpringModel.PHYSICAL

var rpm: float:
	get:
		return motor_rpm
	set(value):
		motor_rpm = value

var gear_ratio: float:
	get:
		return gear_ratio_n
	set(value):
		gear_ratio_n = value

var rotations_per_cycle: float:
	get:
		return gear_ratio_n
	set(value):
		gear_ratio_n = value

var weapon_instance: Node3D
var mesh: Node3D
var muzzle: Node3D
@onready var camera3: Camera3D = get_node_or_null("../Camera3")

@export_group("First Person View")
@export var first_person_offset: Vector3 = Vector3(0.20, -0.2, -0.45)

var _trigger_held: bool = false
var _fire_cooldown: float = 0.0
var is_reloading: bool = false
var _reload_timer: float = 0.0

var _mesh_initial_position: Vector3
var _mesh_initial_rotation: Vector3

var current_ammo: int:
	get:
		return equipped_magazine.current_ammo if equipped_magazine != null else 0

var magazine_capacity: int:
	get:
		return equipped_magazine.capacity if equipped_magazine != null else 0

var bb_mass_grams: float:
	get:
		return equipped_magazine.get_bb_mass_grams() if equipped_magazine != null else 0.0


func _init() -> void:
	_update_cadence()


func _get_target_camera() -> Camera3D:
	if camera3 and is_instance_valid(camera3):
		return camera3
	camera3 = get_node_or_null("../Camera3")
	if camera3:
		return camera3
	var p = get_parent()
	if p and p.has_node("Camera3"):
		camera3 = p.get_node("Camera3")
		return camera3
	if is_inside_tree() and get_viewport():
		var vp_cam = get_viewport().get_camera_3d()
		if vp_cam:
			return vp_cam
	return null


func _ready() -> void:
	# O input é delegado pelo Player conforme SRS Seções 2 e 3.1
	set_process_unhandled_input(false)
	_update_cadence()

	if first_person_offset == Vector3(0.20, -0.2, -0.45) or first_person_offset == Vector3(0.20, -0.18, -0.38):
		first_person_offset = get_default_offset_for_model(weapon_model)

	var cam := _get_target_camera()
	if cam:
		var cam_trans: Transform3D = cam.global_transform if cam.is_inside_tree() else cam.transform
		var new_trans := Transform3D(cam_trans.basis, cam_trans.origin + cam_trans.basis * first_person_offset)
		if is_inside_tree():
			global_transform = new_trans
		else:
			transform = new_trans
	
	if bb_scene == null:
		bb_scene = load("res://Scenes/bb.tscn")

	if equipped_magazine == null:
		_equip_default_magazine()
	
	_emit_initial_state()

	if weapon_prefab == null:
		weapon_prefab = _resolve_default_prefab()

	if weapon_prefab:
		weapon_instance = weapon_prefab.instantiate()
		add_child(weapon_instance)
		
		mesh = weapon_instance.find_child("Mesh", true, false)
		if not mesh:
			mesh = weapon_instance
			
		muzzle = weapon_instance.find_child("Muzzle", true, false)
		if not muzzle:
			muzzle = weapon_instance.find_child("PontaDoCano", true, false)
		
		if mesh:
			_mesh_initial_position = mesh.position
			_mesh_initial_rotation = mesh.rotation_degrees


func _equip_default_magazine() -> void:
	match compatible_magazine_type:
		Magazine.Type.MAG_SHOTGUN_SHELL:
			equipped_magazine = MagazineLoader.create_shotgun_shell(0.20, 30, 30)
		Magazine.Type.MAG_RIFLE_STANAG:
			equipped_magazine = MagazineLoader.create_rifle_stanag(0.25, 30, 30)
		Magazine.Type.MAG_PISTOL_1911:
			equipped_magazine = MagazineLoader.create_pistol_1911(0.20, 15, 15)
		Magazine.Type.MAG_PISTOL_GLOCK, _:
			equipped_magazine = MagazineLoader.create_pistol_glock(0.20, 25, 25)


func _resolve_default_prefab() -> PackedScene:
	match weapon_model:
		WeaponModel.SHOTGUN:
			return load("res://Scenes/shotgun.tscn")
		WeaponModel.RIFLE:
			return load("res://Scenes/rifle.tscn")
		WeaponModel.PISTOL_1911:
			return load("res://Scenes/pistol1911.tscn")
		WeaponModel.PISTOL_GLOCK, _:
			return load("res://Scenes/pistolGlock.tscn")


func _process(delta: float) -> void:
	var cam := _get_target_camera()
	if cam:
		var cam_trans: Transform3D = cam.global_transform if cam.is_inside_tree() else cam.transform
		var new_trans := Transform3D(cam_trans.basis, cam_trans.origin + cam_trans.basis * first_person_offset)
		if is_inside_tree():
			global_transform = new_trans
		else:
			transform = new_trans

	_process_recoil(delta)

	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
		return

	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	if fire_mode == FireMode.AUTO and _trigger_held and _fire_cooldown <= 0.0:
		if equipped_magazine != null and not equipped_magazine.is_empty():
			fire()
			_fire_cooldown = get_fire_interval()
		else:
			trigger_dry_fire()
			_fire_cooldown = get_fire_interval()


## Delegação de Comandos (SRS Seções 2 e 3.1)
func atirar(pressionado: bool) -> void:
	_trigger_held = pressionado
	if not pressionado:
		return
	if is_reloading:
		return
	if _fire_cooldown > 0.0:
		# Regra 2 (SRS 3.2.2): Bloqueio de Intervalo - acionamentos mais rápidos que intervalo são descartados
		return

	if equipped_magazine != null and not equipped_magazine.is_empty():
		fire()
		_fire_cooldown = get_fire_interval()
	else:
		trigger_dry_fire()
		_fire_cooldown = get_fire_interval()


func alternar_modo_tiro() -> void:
	toggle_fire_mode()


func recarregar() -> void:
	if not is_reloading:
		if equipped_magazine != null and not equipped_magazine.is_full():
			_start_reload()


func reload() -> void:
	recarregar()


func ajustar_hop_up(delta_value: float) -> void:
	adjust_hop_up(delta_value)


## Fallback / compatibilidade: delega para as funções de comando
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action("fire") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		atirar(event.pressed)
	elif event.is_action_pressed("toggle_fire_mode"):
		alternar_modo_tiro()
	elif event.is_action_pressed("reload"):
		recarregar()
	elif event.is_action_pressed("hopup_increase") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed):
		ajustar_hop_up(hop_up_step)
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hopup_decrease") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed):
		ajustar_hop_up(-hop_up_step)
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()


func toggle_fire_mode() -> void:
	if allowed_fire_modes.size() <= 1:
		print("Fire mode is fixed to %s for %s" % ["SEMI" if fire_mode == FireMode.SEMI else "AUTO", get_weapon_model_name()])
		return
	
	var next_mode = FireMode.AUTO if fire_mode == FireMode.SEMI else FireMode.SEMI
	if not allowed_fire_modes.has(next_mode):
		return
	fire_mode = next_mode
	if weapon_model == WeaponModel.PISTOL_GLOCK:
		motor_rpm = 33000.0 if fire_mode == FireMode.AUTO else 12000.0
		_update_glock_recoil_preset()
	var mode_name := "AUTO" if fire_mode == FireMode.AUTO else "SEMI"
	print("Fire mode: ", mode_name)
	fire_mode_changed.emit(mode_name)
	modo_tiro_alterado.emit(mode_name)


func adjust_hop_up(delta_value: float) -> void:
	spin_rad_s = clampf(spin_rad_s + delta_value, min_hop_up, max_hop_up)
	hop_up_adjusted.emit(spin_rad_s)
	hop_up_ajustado.emit(spin_rad_s)
	print("Hop-up adjusted to: ", spin_rad_s, " rad/s")


func set_bullet_tracing(enabled: bool) -> void:
	bullet_tracing_enabled = enabled


func toggle_bullet_tracing() -> bool:
	bullet_tracing_enabled = not bullet_tracing_enabled
	return bullet_tracing_enabled


func is_bullet_tracing_enabled() -> bool:
	return bullet_tracing_enabled


func trigger_incompatible_magazine() -> void:
	print("Incompatible magazine! Expected: ", Magazine.get_type_name_for(compatible_magazine_type))
	incompatible_magazine.emit()
	carregador_incompativel.emit()


func swap_magazine(new_magazine: Magazine) -> Magazine:
	if new_magazine == null:
		return null
	if new_magazine.type != compatible_magazine_type:
		print("Incompatible magazine! Expected: ", Magazine.get_type_name_for(compatible_magazine_type), " but received: ", new_magazine.get_type_name())
		incompatible_magazine.emit()
		carregador_incompativel.emit()
		return null
	
	var old_mag := equipped_magazine
	equipped_magazine = new_magazine
	magazine_equipped.emit(equipped_magazine)
	ammo_changed.emit(equipped_magazine.current_ammo, equipped_magazine.capacity)
	municao_alterada.emit(equipped_magazine.current_ammo, equipped_magazine.capacity)
	print("Swapped magazine: ", equipped_magazine.get_type_name(), " [", equipped_magazine.current_ammo, "/", equipped_magazine.capacity, "] - BB: ", equipped_magazine.get_bb_mass_grams(), "g")
	return old_mag


func equip_magazine(new_magazine: Magazine) -> bool:
	return swap_magazine(new_magazine) != null


func trigger_dry_fire() -> void:
	print("Click! Dry-fire (no ammo or missing magazine).")
	dry_fired.emit()
	disparo_seco.emit()


func _start_reload() -> void:
	if is_reloading:
		return
	is_reloading = true
	_reload_timer = reload_time
	reload_started.emit(reload_time)
	recarga_iniciada.emit(reload_time)
	print("Reloading...")
	
	if mesh:
		var tween = create_tween()
		var drop_time = reload_time * 0.3
		var rise_time = reload_time * 0.3
		var hold_time = reload_time * 0.4
		
		tween.tween_property(mesh, "position", _mesh_initial_position + Vector3(-0.04, -0.12, 0.04), drop_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(mesh, "rotation_degrees", _mesh_initial_rotation + Vector3(-12, 8, -15), drop_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		tween.tween_interval(hold_time)
		
		tween.tween_property(mesh, "position", _mesh_initial_position, rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(mesh, "rotation_degrees", _mesh_initial_rotation, rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _finish_reload() -> void:
	is_reloading = false
	is_slide_locked_open = false
	if equipped_magazine:
		equipped_magazine.refill()
		ammo_changed.emit(equipped_magazine.current_ammo, equipped_magazine.capacity)
		municao_alterada.emit(equipped_magazine.current_ammo, equipped_magazine.capacity)
	if mesh:
		mesh.position = _mesh_initial_position
		mesh.rotation_degrees = _mesh_initial_rotation
	reload_completed.emit()
	recarga_concluida.emit()
	print("Reload complete!")


## Modelo Físico da Mola e Velocidade (SRS Seção 3.2.1)
func calculate_spring_energy(k: float = spring_k, x: float = spring_x) -> float:
	return 0.5 * k * (x * x)


func get_muzzle_energy() -> float:
	if spring_model == SpringModel.PHYSICAL:
		return calculate_spring_energy(spring_k, spring_x)
	return nominal_energy_joules


func calculate_velocity(bb_mass_kg: float, energy: float = NAN) -> float:
	var e: float = get_muzzle_energy() if is_nan(energy) else energy
	if bb_mass_kg <= 0.0 or e <= 0.0:
		return 0.0
	return sqrt((2.0 * e) / bb_mass_kg)


func calculate_muzzle_velocity(bb_mass_kg: float, energy: float = NAN) -> float:
	return calculate_velocity(bb_mass_kg, energy)


func adjust_spring(k: float, x: float) -> void:
	spring_k = k
	spring_x = x
	spring_model = SpringModel.PHYSICAL
	mola_ajustada.emit(energy_joules)


func set_spring(k: float, x: float) -> void:
	adjust_spring(k, x)


func set_simplified_energy(joules: float) -> void:
	nominal_energy_joules = joules
	spring_model = SpringModel.SIMPLIFIED
	mola_ajustada.emit(energy_joules)


## Motor, Gearbox e Cadência Real (SRS Seção 3.2.2)
func _update_cadence() -> void:
	if motor_rpm > 0.0 and gear_ratio_n > 0.0:
		rof = motor_rpm / (60.0 * gear_ratio_n)
		fire_interval = 1.0 / rof
	else:
		rof = 0.0
		fire_interval = 0.0
	cadencia_alterada.emit(rof, fire_interval)


func get_rof() -> float:
	if motor_rpm > 0.0 and gear_ratio_n > 0.0:
		return motor_rpm / (60.0 * gear_ratio_n)
	return 0.0


func get_fire_interval() -> float:
	var r := get_rof()
	if r > 0.0:
		return 1.0 / r
	return 1.0


func get_cadence_rpm() -> float:
	return rof * 60.0


func set_motor_and_gearbox(p_motor_rpm: float, p_gear_ratio_n: float) -> void:
	motor_rpm = p_motor_rpm
	gear_ratio_n = p_gear_ratio_n
	_update_cadence()


func print_cadence_debug() -> void:
	print("Cadence Debug -> Motor RPM: %.1f | N: %.1f | ROF: %.2f BB/s | Intervalo: %.4fs" % [motor_rpm, gear_ratio_n, rof, fire_interval])


func get_weapon_model_name() -> String:
	match weapon_model:
		WeaponModel.SHOTGUN:
			return "Shotgun"
		WeaponModel.RIFLE:
			return "Rifle"
		WeaponModel.PISTOL_1911:
			return "Pistol1911"
		WeaponModel.PISTOL_GLOCK:
			return "PistolGlock"
		_:
			return "Unknown"


static func get_default_offset_for_model(model: WeaponModel) -> Vector3:
	match model:
		WeaponModel.SHOTGUN:
			return Vector3(0.22, -0.25, -0.40)
		WeaponModel.RIFLE:
			return Vector3(0.22, -0.25, -0.42)
		WeaponModel.PISTOL_1911:
			return Vector3(0.20, -0.2, -0.4)
		WeaponModel.PISTOL_GLOCK, _:
			return Vector3(0.20, -0.2, -0.45)


func configure_weapon_preset(model: WeaponModel) -> void:
	weapon_model = model
	first_person_offset = get_default_offset_for_model(model)
	match model:
		WeaponModel.SHOTGUN:
			first_person_offset = Vector3(0.22, -0.25, -0.40)
			compatible_magazine_type = Magazine.Type.MAG_SHOTGUN_SHELL
			simplified_energy_joules = 1.1
			spring_k = 880.0
			spring_x = 0.05
			motor_rpm = 1500.0
			gear_ratio_n = 30.0
			projectiles_per_shot = 3
			spread_cone_angle = 0.05
			allowed_fire_modes = [FireMode.SEMI]
			fire_mode = FireMode.SEMI
			recoil_vertical_bullets = 1
			recoil_vertical_pitch = 3.5
			recoil_lateral_yaw = 0.8
			recoil_recovery_time = 0.40
			weapon_prefab = load("res://Scenes/shotgun.tscn")
		WeaponModel.RIFLE:
			first_person_offset = Vector3(0.22, -0.25, -0.42)
			compatible_magazine_type = Magazine.Type.MAG_RIFLE_STANAG
			simplified_energy_joules = 1.49
			spring_k = 1192.0
			spring_x = 0.05
			motor_rpm = 24000.0
			gear_ratio_n = 30.0
			projectiles_per_shot = 1
			spread_cone_angle = 0.0
			allowed_fire_modes = [FireMode.SEMI, FireMode.AUTO]
			spin_rad_s = 1300.0
			recoil_vertical_bullets = 5
			recoil_vertical_pitch = 1.2
			recoil_lateral_yaw = 0.9
			recoil_recovery_time = 0.25
			weapon_prefab = load("res://Scenes/rifle.tscn")
		WeaponModel.PISTOL_1911:
			first_person_offset = Vector3(0.20, -0.2, -0.4)
			compatible_magazine_type = Magazine.Type.MAG_PISTOL_1911
			simplified_energy_joules = 0.9
			spring_k = 720.0
			spring_x = 0.05
			motor_rpm = 10500.0
			gear_ratio_n = 30.0
			projectiles_per_shot = 1
			spread_cone_angle = 0.0
			allowed_fire_modes = [FireMode.SEMI]
			fire_mode = FireMode.SEMI
			recoil_vertical_bullets = 1
			recoil_vertical_pitch = 2.2
			recoil_lateral_yaw = 0.1
			recoil_recovery_time = 0.22
			weapon_prefab = load("res://Scenes/pistol1911.tscn")
		WeaponModel.PISTOL_GLOCK:
			first_person_offset = Vector3(0.20, -0.2, -0.45)
			compatible_magazine_type = Magazine.Type.MAG_PISTOL_GLOCK
			simplified_energy_joules = 1.0
			spring_k = 800.0
			spring_x = 0.05
			motor_rpm = 12000.0
			gear_ratio_n = 30.0
			projectiles_per_shot = 1
			spread_cone_angle = 0.0
			allowed_fire_modes = [FireMode.SEMI, FireMode.AUTO]
			_update_glock_recoil_preset()
			weapon_prefab = load("res://Scenes/pistolGlock.tscn")
	_update_cadence()


func disparar() -> void:
	fire()


func fire() -> void:
	if bb_scene == null:
		push_error("BB scene is not configured!")
		return
	
	if equipped_magazine == null or equipped_magazine.is_empty():
		trigger_dry_fire()
		return

	var count_to_fire := mini(projectiles_per_shot, equipped_magazine.current_ammo)
	if count_to_fire <= 0:
		trigger_dry_fire()
		return

	var consumed: bool = equipped_magazine.consume_bbs(count_to_fire)
	if not consumed:
		trigger_dry_fire()
		return
	
	ammo_changed.emit(equipped_magazine.current_ammo, equipped_magazine.capacity)
	municao_alterada.emit(equipped_magazine.current_ammo, equipped_magazine.capacity)

	# v = sqrt(2E / m) para cálculo de velocidade com a massa da BB equipada (SRS 3.2.1)
	var bb_mass_kg: float = equipped_magazine.bb_mass_kg
	var velocity_ms: float = calculate_velocity(bb_mass_kg)
	var velocity_fps: float = velocity_ms * METERS_TO_FEET

	print(bb_mass_kg, "kg | ", energy_joules, "J | ", round(velocity_fps), " FPS | Remaining: ", equipped_magazine.current_ammo)

	var muzzle_transform: Transform3D
	if muzzle and muzzle.is_inside_tree():
		muzzle_transform = muzzle.global_transform
	elif is_inside_tree():
		muzzle_transform = global_transform
	elif muzzle:
		muzzle_transform = muzzle.transform
	else:
		muzzle_transform = Transform3D.IDENTITY

	var base_fire_dir: Vector3
	if muzzle and muzzle.is_inside_tree():
		base_fire_dir = -muzzle.global_transform.basis.z.normalized()
	elif muzzle:
		base_fire_dir = -muzzle.transform.basis.z.normalized()
	elif is_inside_tree():
		base_fire_dir = -global_transform.basis.z.normalized()
	else:
		base_fire_dir = Vector3.FORWARD

	var spin_axis = base_fire_dir.cross(Vector3.UP).normalized()
	if spin_axis.length_squared() < 0.001:
		spin_axis = Vector3.RIGHT
	var perp_axis = base_fire_dir.cross(spin_axis).normalized()

	var tree := get_tree() if is_inside_tree() else null
	var spawn_parent: Node = tree.current_scene if (tree and tree.current_scene) else get_parent()

	for i in range(count_to_fire):
		var bullet = bb_scene.instantiate()
		if "trail_enabled" in bullet:
			var BBClass = load("res://Scripts/bb.gd")
			var global_tr: bool = BBClass.global_trail_enabled if (BBClass != null and "global_trail_enabled" in BBClass) else true
			bullet.trail_enabled = bullet_tracing_enabled and global_tr
		if spawn_parent:
			spawn_parent.add_child(bullet)
		
		# Physics collision isolation & runtime collision exception (SRS Adicionais Seção 5)
		if bullet is CollisionObject3D:
			bullet.collision_layer = 8
			bullet.collision_mask = 17
			var player_target := _get_player_node()
			if player_target and player_target is CollisionObject3D:
				bullet.add_collision_exception_with(player_target)
		
		bullet.global_transform = muzzle_transform
		if "mass" in bullet:
			bullet.mass = bb_mass_kg

		var fire_direction := base_fire_dir
		if (count_to_fire > 1 or spread_cone_angle > 0.0) and spread_cone_angle > 0.0:
			var angle_x = randf_range(-spread_cone_angle, spread_cone_angle)
			var angle_y = randf_range(-spread_cone_angle, spread_cone_angle)
			fire_direction = (Basis(spin_axis, angle_y) * Basis(perp_axis, angle_x) * base_fire_dir).normalized()

		if "linear_velocity" in bullet:
			bullet.linear_velocity = fire_direction * velocity_ms
		if "angular_velocity" in bullet:
			bullet.angular_velocity = spin_axis * spin_rad_s

	_play_fire_animation()
	_apply_recoil()


func _play_fire_animation() -> void:
	if mesh == null:
		return
	
	var recoil_offset := Vector3(0, 0, 0.05)
	var is_empty_now := (equipped_magazine != null and equipped_magazine.is_empty())
	
	var tween = create_tween()
	if tween:
		tween.tween_property(mesh, "position", _mesh_initial_position + recoil_offset, 0.03)
		if is_empty_now and (weapon_model == WeaponModel.PISTOL_1911 or weapon_model == WeaponModel.PISTOL_GLOCK):
			is_slide_locked_open = true
		else:
			tween.tween_property(mesh, "position", _mesh_initial_position, 0.05)


func _emit_initial_state() -> void:
	if equipped_magazine:
		magazine_equipped.emit(equipped_magazine)
		ammo_changed.emit(equipped_magazine.current_ammo, equipped_magazine.capacity)
		municao_alterada.emit(equipped_magazine.current_ammo, equipped_magazine.capacity)
	var mode_name := "AUTO" if fire_mode == FireMode.AUTO else "SEMI"
	fire_mode_changed.emit(mode_name)
	modo_tiro_alterado.emit(mode_name)
	hop_up_adjusted.emit(spin_rad_s)
	hop_up_ajustado.emit(spin_rad_s)
	cadencia_alterada.emit(rof, fire_interval)
	mola_ajustada.emit(energy_joules)


func _update_glock_recoil_preset() -> void:
	if fire_mode == FireMode.AUTO:
		recoil_vertical_bullets = 4
		recoil_vertical_pitch = 1.6
		recoil_lateral_yaw = 1.3
		recoil_recovery_time = 0.20
	else:
		recoil_vertical_bullets = 1
		recoil_vertical_pitch = 0.8
		recoil_lateral_yaw = 0.15
		recoil_recovery_time = 0.15


func _get_player_node() -> Node:
	if player_node != null and is_instance_valid(player_node):
		return player_node
	var p := get_parent()
	while p != null:
		if p is CharacterBody3D or p.is_in_group("player") or p.name == "Player":
			return p
		p = p.get_parent()
	if is_inside_tree() and get_tree() and get_tree().current_scene:
		var scene_player := get_tree().current_scene.find_child("Player", true, false)
		if scene_player:
			return scene_player
	return null


func get_recoil_step(shot_index: int) -> Vector2:
	match weapon_model:
		WeaponModel.RIFLE:
			if shot_index < recoil_vertical_bullets:
				return Vector2(0.0, recoil_vertical_pitch)
			elif shot_index == recoil_vertical_bullets:
				return Vector2(recoil_lateral_yaw, recoil_vertical_pitch * 0.3)
			else:
				var cycle := (shot_index - recoil_vertical_bullets - 1) % 6
				var dir := 1.0 if cycle < 3 else -1.0
				return Vector2(dir * recoil_lateral_yaw, 0.0)
		WeaponModel.PISTOL_GLOCK:
			if fire_mode == FireMode.AUTO:
				if shot_index < recoil_vertical_bullets:
					return Vector2(0.0, recoil_vertical_pitch)
				else:
					var sign_dir := 1.0 if (((shot_index - recoil_vertical_bullets) / 2) % 2 == 0) else -1.0
					return Vector2(sign_dir * recoil_lateral_yaw, 0.2)
			else:
				return Vector2(randf_range(-recoil_lateral_yaw, recoil_lateral_yaw), recoil_vertical_pitch)
		WeaponModel.PISTOL_1911:
			return Vector2(randf_range(-recoil_lateral_yaw, recoil_lateral_yaw), recoil_vertical_pitch)
		WeaponModel.SHOTGUN:
			return Vector2(randf_range(-recoil_lateral_yaw, recoil_lateral_yaw), recoil_vertical_pitch)
		_:
			if shot_index < recoil_vertical_bullets:
				return Vector2(0.0, recoil_vertical_pitch)
			return Vector2(recoil_lateral_yaw, 0.0)


func get_current_recoil_step() -> Vector2:
	return get_recoil_step(recoil_shot_index)


func get_current_recoil_offset() -> Vector2:
	return current_recoil_offset


func reset_recoil() -> void:
	recoil_shot_index = 0
	current_recoil_offset = Vector2.ZERO
	time_since_last_shot = 0.0
	_is_recoil_recovering = false
	var cam := _get_target_camera()
	if cam and cam.has_method("reset_recoil"):
		cam.reset_recoil()


func is_recoil_recovering() -> bool:
	return _is_recoil_recovering


func _apply_recoil() -> void:
	if not recoil_enabled:
		return
	var step := get_recoil_step(recoil_shot_index)
	recoil_shot_index += 1
	current_recoil_offset += step
	time_since_last_shot = 0.0
	_is_recoil_recovering = false

	var cam := _get_target_camera()
	if cam and cam.has_method("apply_recoil"):
		cam.apply_recoil(step.y, step.x)
	elif cam:
		cam.rotation.x = clamp(cam.rotation.x + deg_to_rad(step.y), deg_to_rad(-89.0), deg_to_rad(89.0))
		cam.rotate_y(-deg_to_rad(step.x))

	recoil_applied.emit(step.y, step.x, recoil_shot_index)
	recuo_aplicado.emit(step.y, step.x, recoil_shot_index)


func _process_recoil(delta: float) -> void:
	if not recoil_enabled:
		return

	time_since_last_shot += delta

	# Recoil recovery triggers when trigger is not shooting (elapsed fire_interval)
	var cadence_interval := get_fire_interval()
	if time_since_last_shot >= cadence_interval and current_recoil_offset != Vector2.ZERO:
		_is_recoil_recovering = true
		var rec_time := maxf(recoil_recovery_time, 0.01)
		var decay_rate := delta / rec_time
		var old_offset := current_recoil_offset

		current_recoil_offset.x = move_toward(current_recoil_offset.x, 0.0, maxf(abs(old_offset.x) * decay_rate, delta * 3.0))
		current_recoil_offset.y = move_toward(current_recoil_offset.y, 0.0, maxf(abs(old_offset.y) * decay_rate, delta * 3.0))

		var delta_pitch := old_offset.y - current_recoil_offset.y
		var delta_yaw := old_offset.x - current_recoil_offset.x

		var cam := _get_target_camera()
		if cam and cam.has_method("recover_recoil"):
			cam.recover_recoil(deg_to_rad(delta_pitch), deg_to_rad(delta_yaw))
		elif cam:
			cam.rotation.x = clamp(cam.rotation.x - deg_to_rad(delta_pitch), deg_to_rad(-89.0), deg_to_rad(89.0))
			cam.rotate_y(deg_to_rad(delta_yaw))

	# Recoil counter reset (SRS 3.3):
	# If time_since_last_shot >= recoil_recovery_time, spray counter resets to 0.
	# If the player fires before this time, recoil_shot_index continues accumulating.
	if time_since_last_shot >= recoil_recovery_time:
		recoil_shot_index = 0
		if current_recoil_offset == Vector2.ZERO and _is_recoil_recovering:
			_is_recoil_recovering = false
			recoil_recovered.emit()
			recuo_recuperado.emit()
