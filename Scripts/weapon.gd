class_name Weapon
extends Node3D

## Controller for Airsoft replica weapons.
## Handles magazine compatibility, dynamic BB physics calculation,
## rate of fire, firing modes, reload animation, and state signals.

const Magazine = preload("res://Scripts/magazine.gd")
const MagazineLoader = preload("res://Scripts/magazine_loader.gd")

enum FireMode { SEMI, AUTO }

## Signals
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

@export_group("Prefabs")
@export var bb_scene: PackedScene
@export var weapon_prefab: PackedScene

@export_group("Ballistics & Physics")
## Nominal muzzle energy in Joules
@export var energy_joules: float = 1.49
## Backspin rotation applied to the BB in radians per second (hop-up)
@export var spin_rad_s: float = 1200.0
@export var min_hop_up: float = 0.0
@export var max_hop_up: float = 2500.0
@export var hop_up_step: float = 50.0

const METERS_TO_FEET: float = 3.28084

@export_group("Firing Mechanics")
@export var fire_mode: FireMode = FireMode.SEMI
@export var rpm: float = 700.0 ## Rounds per minute in automatic mode
@export var reload_time: float = 2.0 ## Seconds to complete a reload cycle

@export_group("Magazine System")
## Compatible magazine type for this weapon
@export var compatible_magazine_type: Magazine.Type = Magazine.Type.MAG_PISTOL_GLOCK
## Equipped magazine resource
@export var equipped_magazine: Magazine

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

# Backward compatibility properties for HUD / other scripts
var current_ammo: int:
	get:
		return equipped_magazine.current_ammo if equipped_magazine != null else 0

var magazine_capacity: int:
	get:
		return equipped_magazine.capacity if equipped_magazine != null else 0

var bb_mass_grams: float:
	get:
		return equipped_magazine.get_bb_mass_grams() if equipped_magazine != null else 0.0


func _ready() -> void:
	if camera3:
		_local_offset = camera3.global_transform.affine_inverse() * global_transform
	
	# Fallback/default magazine initialization if none assigned in the inspector
	if equipped_magazine == null:
		equipped_magazine = MagazineLoader.create_magazine(compatible_magazine_type, 25, 25, 0.20)
	
	_emit_initial_state()

	if weapon_prefab:
		weapon_instance = weapon_prefab.instantiate()
		add_child(weapon_instance)
		
		# Look for Mesh and Muzzle / PontaDoCano
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

	# Handle reload timer
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
		return

	# Fire cooldown countdown
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	# Full-auto firing logic
	if fire_mode == FireMode.AUTO and _trigger_held and _fire_cooldown <= 0.0:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_trigger_held = false
		elif equipped_magazine != null and not equipped_magazine.is_empty():
			fire()
			_fire_cooldown = 60.0 / rpm
		else:
			trigger_dry_fire()
			_start_reload()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_trigger_held = event.pressed
		
		# Semi-auto firing logic
		if event.pressed and fire_mode == FireMode.SEMI and not is_reloading:
			if equipped_magazine != null and not equipped_magazine.is_empty():
				if _fire_cooldown <= 0.0:
					fire()
					_fire_cooldown = 60.0 / rpm
			else:
				trigger_dry_fire()
				_start_reload()

	if event.is_action_pressed("toggle_fire_mode"):
		toggle_fire_mode()
		
	if event.is_action_pressed("reload") and not is_reloading:
		if equipped_magazine != null and not equipped_magazine.is_full():
			_start_reload()

	# Hop-up adjustments via wheel up / down (unhandled input ensures no conflict with UI/menus)
	if event.is_action_pressed("hopup_increase"):
		adjust_hop_up(hop_up_step)
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("hopup_decrease"):
		adjust_hop_up(-hop_up_step)
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


func fire() -> void:
	if bb_scene == null:
		push_error("BB scene is not configured!")
		return
	
	if equipped_magazine == null or equipped_magazine.is_empty():
		trigger_dry_fire()
		return

	# Deduct exactly 1 BB (or 3 for shotgun in extended logic)
	var consumed: bool = equipped_magazine.consume_bbs(1)
	if not consumed:
		trigger_dry_fire()
		return
	
	ammo_changed.emit(equipped_magazine.current_ammo, equipped_magazine.capacity)
	municao_alterada.emit(equipped_magazine.current_ammo, equipped_magazine.capacity)

	# Calculate dynamic velocity using equipped magazine's BB mass: v = sqrt(2E / m)
	var bb_mass_kg: float = equipped_magazine.bb_mass_kg
	var velocity_ms: float = sqrt((2.0 * energy_joules) / bb_mass_kg)
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
