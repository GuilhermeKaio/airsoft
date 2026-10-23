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

@export_group("Weapon Identity & Models (SRS 3.2 & 4)")
@export var weapon_model: WeaponModel = WeaponModel.PISTOL_GLOCK

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

var _local_offset: Transform3D
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


func _ready() -> void:
	# O input é delegado pelo Player conforme SRS Seções 2 e 3.1
	set_process_unhandled_input(false)
	_update_cadence()

	if camera3:
		_local_offset = camera3.global_transform.affine_inverse() * global_transform
	
	if equipped_magazine == null:
		equipped_magazine = MagazineLoader.create_magazine(compatible_magazine_type, 25, 25, 0.20)
	
	_emit_initial_state()

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


func _process(delta: float) -> void:
	if camera3:
		global_transform = camera3.global_transform * _local_offset

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
			_start_reload()


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
		_start_reload()


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
	fire_mode = FireMode.AUTO if fire_mode == FireMode.SEMI else FireMode.SEMI
	var mode_name := "AUTO" if fire_mode == FireMode.AUTO else "SEMI"
	print("Fire mode: ", mode_name)
	fire_mode_changed.emit(mode_name)
	modo_tiro_alterado.emit(mode_name)


func adjust_hop_up(delta_value: float) -> void:
	spin_rad_s = clampf(spin_rad_s + delta_value, min_hop_up, max_hop_up)
	hop_up_adjusted.emit(spin_rad_s)
	hop_up_ajustado.emit(spin_rad_s)
	print("Hop-up adjusted to: ", spin_rad_s, " rad/s")


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
		
		tween.tween_property(mesh, "position", _mesh_initial_position + Vector3(-0.1, -0.3, 0), drop_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(mesh, "rotation_degrees", _mesh_initial_rotation + Vector3(0, 0, 45), drop_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		
		tween.tween_interval(hold_time)
		
		tween.tween_property(mesh, "position", _mesh_initial_position, rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(mesh, "rotation_degrees", _mesh_initial_rotation, rise_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _finish_reload() -> void:
	is_reloading = false
	if equipped_magazine:
		equipped_magazine.refill()
		ammo_changed.emit(equipped_magazine.current_ammo, equipped_magazine.capacity)
		municao_alterada.emit(equipped_magazine.current_ammo, equipped_magazine.capacity)
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


func configure_weapon_preset(model: WeaponModel) -> void:
	weapon_model = model
	match model:
		WeaponModel.SHOTGUN:
			compatible_magazine_type = Magazine.Type.MAG_SHOTGUN_SHELL
			simplified_energy_joules = 1.1
			spring_k = 880.0
			spring_x = 0.05
			motor_rpm = 1500.0
			gear_ratio_n = 30.0
		WeaponModel.RIFLE:
			compatible_magazine_type = Magazine.Type.MAG_RIFLE_STANAG
			simplified_energy_joules = 1.49
			spring_k = 1192.0
			spring_x = 0.05
			motor_rpm = 24000.0
			gear_ratio_n = 30.0
		WeaponModel.PISTOL_1911:
			compatible_magazine_type = Magazine.Type.MAG_PISTOL_1911
			simplified_energy_joules = 0.9
			spring_k = 720.0
			spring_x = 0.05
			motor_rpm = 10500.0
			gear_ratio_n = 30.0
		WeaponModel.PISTOL_GLOCK:
			compatible_magazine_type = Magazine.Type.MAG_PISTOL_GLOCK
			simplified_energy_joules = 1.0
			spring_k = 800.0
			spring_x = 0.05
			motor_rpm = 12000.0
			gear_ratio_n = 30.0
	_update_cadence()


func fire() -> void:
	if bb_scene == null:
		push_error("BB scene is not configured!")
		return
	
	if equipped_magazine == null or equipped_magazine.is_empty():
		trigger_dry_fire()
		return

	var consumed: bool = equipped_magazine.consume_bbs(1)
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

	var bullet = bb_scene.instantiate()
	if is_inside_tree():
		var tree := get_tree()
		var spawn_parent: Node = tree.current_scene if (tree and tree.current_scene) else get_parent()
		if spawn_parent:
			spawn_parent.add_child(bullet)
	
	var muzzle_transform = muzzle.global_transform if muzzle else (global_transform if is_inside_tree() else Transform3D.IDENTITY)
	bullet.global_transform = muzzle_transform
	if "mass" in bullet:
		bullet.mass = bb_mass_kg

	var fire_direction: Vector3
	if muzzle:
		fire_direction = -muzzle.global_transform.basis.x.normalized()
	elif is_inside_tree():
		fire_direction = -global_transform.basis.z.normalized()
	else:
		fire_direction = Vector3.FORWARD

	if "linear_velocity" in bullet:
		bullet.linear_velocity = fire_direction * velocity_ms
	if "angular_velocity" in bullet:
		var spin_axis = fire_direction.cross(Vector3.UP).normalized()
		bullet.angular_velocity = spin_axis * spin_rad_s


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

