extends RigidBody3D
const AIR_DENSITY = 1.225
const DRAG_COEFFICIENT = 0.47
const RADIUS = 0.003
const CROSS_SECTIONAL_AREA = PI * (RADIUS * RADIUS)

const GROUP_PROJECTILE := "bb_projectile"
const GROUP_PROJETIL := GROUP_PROJECTILE

const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_WEAPON: int = 4
const LAYER_BB_PROJECTILE: int = 8
const LAYER_TARGETS: int = 16
const LAYER_PICKUPS: int = 32

const DEFAULT_BB_LAYER: int = LAYER_BB_PROJECTILE
const DEFAULT_BB_MASK: int = LAYER_WORLD | LAYER_TARGETS

signal despawned()
signal despawn_triggered()

func has_collision_exception_with(target: Node) -> bool:
	if target is CollisionObject3D:
		return get_collision_exceptions().has(target)
	return false

static var global_trail_enabled: bool = true

static func set_global_trail_enabled(enabled: bool, tree: SceneTree = null) -> void:
	global_trail_enabled = enabled
	if tree != null:
		for node in tree.get_nodes_in_group(GROUP_PROJECTILE):
			if node.has_method("set_trail_enabled"):
				node.set_trail_enabled(enabled)
			elif "trail_enabled" in node:
				node.trail_enabled = enabled

static func toggle_global_trail_enabled(tree: SceneTree = null) -> bool:
	set_global_trail_enabled(not global_trail_enabled, tree)
	return global_trail_enabled

static func is_global_trail_enabled() -> bool:
	return global_trail_enabled

var hit_ground: bool = false
var _trail_recording: bool = true
var _is_despawning: bool = false

@export_group("Flight Timeout & Despawn (SRS 3.6)")
@export var max_flight_time: float = 10.0
@export var post_collision_flight_time: float = 5.0
@export var despawn_on_collision: bool = true

var collision_despawn_delay: float:
	get:
		return post_collision_flight_time
	set(value):
		post_collision_flight_time = value

var collision_flight_time: float:
	get:
		return post_collision_flight_time
	set(value):
		post_collision_flight_time = value

var tempo_limite_apos_colisao: float:
	get:
		return post_collision_flight_time
	set(value):
		post_collision_flight_time = value

var flight_time_limit: float:
	get:
		return max_flight_time
	set(value):
		max_flight_time = value

var tempo_limite_voo: float:
	get:
		return max_flight_time
	set(value):
		max_flight_time = value

var current_flight_time: float = 0.0

var flight_time: float:
	get:
		return current_flight_time
	set(value):
		current_flight_time = value

var tempo_voo: float:
	get:
		return current_flight_time
	set(value):
		current_flight_time = value

@export_group("Aerodynamics & Ballistics")
@export var magnus_coefficient: float = 1.0

@export_group("Trail Rendering")
@export var trail_enabled: bool = true
@export var trail_max_points: int = 40
@export var trail_lifetime: float = 0.4
@export var trail_width: float = 0.01
@export var trail_color: Color = Color(1.0, 0.85, 0.3, 1.0)

@export var trail_glow: bool = false

@export_range(0.1, 3.0) var trail_fade_sharpness: float = 0.35

var _trail_mesh_instance: MeshInstance3D
var _trail_immediate: ImmediateMesh
var _trail_material: StandardMaterial3D
var _trail_points: Array = []


func _ready() -> void:
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.0

	# Ensure physics layers follow SRS Adicionais Seção 5
	if collision_layer == 1 and collision_mask == 1:
		collision_layer = DEFAULT_BB_LAYER
		collision_mask = DEFAULT_BB_MASK
	# Mandatory isolation: Prohibit collision mask from monitoring Player (Layer 2) or Weapon (Layer 3)
	collision_mask = collision_mask & ~(LAYER_PLAYER | LAYER_WEAPON)

	add_to_group(GROUP_PROJECTILE)
	add_to_group("bb_projetil")
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_body_entered)

	if not global_trail_enabled:
		trail_enabled = false

	if trail_enabled:
		_setup_trail()


func set_trail_enabled(enabled: bool) -> void:
	trail_enabled = enabled
	_trail_recording = enabled and not hit_ground
	if not enabled:
		if _trail_immediate:
			_trail_immediate.clear_surfaces()
		_trail_points.clear()
		if _trail_mesh_instance:
			_trail_mesh_instance.visible = false
	else:
		if _trail_mesh_instance == null:
			_setup_trail()
		else:
			_trail_mesh_instance.visible = true
	var bullet_trail_particles = get_node_or_null("BulletTrail")
	if bullet_trail_particles and bullet_trail_particles is GPUParticles3D:
		bullet_trail_particles.emitting = enabled


func _on_body_entered(body: Node) -> void:
	if hit_ground:
		return

	if body != null and (body.is_in_group(GROUP_PROJECTILE) or body.is_in_group("bb_projetil")):
		if "hit_ground" in body and body.hit_ground:
			_stop_trail_recording()
			if despawn_on_collision:
				_handle_collision_despawn()
	else:
		_stop_trail_recording()
		if despawn_on_collision:
			_handle_collision_despawn()


func _stop_trail_recording() -> void:
	hit_ground = true
	_trail_recording = false


func _handle_collision_despawn() -> void:
	if _is_despawning:
		return
	max_flight_time = post_collision_flight_time
	current_flight_time = 0.0
	if max_flight_time <= 0.0:
		despawn()
	elif is_inside_tree():
		get_tree().create_timer(max_flight_time).timeout.connect(func():
			if not is_despawned():
				despawn()
		)


func advance_flight_time(delta: float) -> void:
	if _is_despawning:
		return
	current_flight_time += delta
	if max_flight_time > 0.0 and current_flight_time >= max_flight_time:
		despawn()


func reset_flight_time() -> void:
	current_flight_time = 0.0


func get_flight_time() -> float:
	return current_flight_time


func get_remaining_flight_time() -> float:
	if max_flight_time <= 0.0:
		return INF
	return maxf(0.0, max_flight_time - current_flight_time)


func is_despawned() -> bool:
	return _is_despawning or is_queued_for_deletion()


func despawn() -> void:
	if _is_despawning and is_queued_for_deletion():
		return
	_is_despawning = true
	_stop_trail_recording()
	set_trail_enabled(false)
	despawn_triggered.emit()
	despawned.emit()
	if not is_queued_for_deletion():
		queue_free()


func remover() -> void:
	despawn()


func _physics_process(delta: float) -> void:
	advance_flight_time(delta)
	if _is_despawning or is_queued_for_deletion():
		return

	var current_velocity = linear_velocity
	var speed = current_velocity.length()

	if speed > 0:
		var speed_squared = current_velocity.length_squared()
		var drag_magnitude = 0.5 * AIR_DENSITY * DRAG_COEFFICIENT * CROSS_SECTIONAL_AREA * speed_squared
		var drag_direction = -current_velocity.normalized()
		var drag_force = drag_direction * drag_magnitude
		var magnus_force = magnus_coefficient * AIR_DENSITY * CROSS_SECTIONAL_AREA * RADIUS \
				* angular_velocity.cross(current_velocity)

		apply_central_force(drag_force)
		apply_central_force(magnus_force)
	if trail_enabled and _trail_recording:
		_record_trail_point()


func _process(delta: float) -> void:
	if _is_despawning or is_queued_for_deletion():
		return
	if not trail_enabled:
		return
	_age_trail_points(delta)
	_draw_trail()


func _setup_trail() -> void:
	_trail_immediate = ImmediateMesh.new()

	_trail_material = StandardMaterial3D.new()
	_trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_material.vertex_color_use_as_albedo = true
	_trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_trail_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if trail_glow else BaseMaterial3D.BLEND_MODE_MIX

	_trail_mesh_instance = MeshInstance3D.new()
	_trail_mesh_instance.mesh = _trail_immediate
	_trail_mesh_instance.material_override = _trail_material
	_trail_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_mesh_instance.top_level = true

	add_child(_trail_mesh_instance)


func _record_trail_point() -> void:
	var pos: Vector3 = global_position if is_inside_tree() else position
	_trail_points.append({"pos": pos, "age": 0.0})
	while _trail_points.size() > trail_max_points:
		_trail_points.remove_at(0)


func _age_trail_points(delta: float) -> void:
	var i := 0
	while i < _trail_points.size():
		_trail_points[i]["age"] += delta
		if _trail_points[i]["age"] > trail_lifetime:
			_trail_points.remove_at(i)
		else:
			i += 1


func _draw_trail() -> void:
	_trail_immediate.clear_surfaces()

	if _trail_points.size() < 2:
		return

	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var cam_pos := camera.global_position

	_trail_immediate.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)

	var count := _trail_points.size()
	for i in range(count):
		var point = _trail_points[i]
		var pos: Vector3 = point["pos"]
		var age: float = point["age"]
		var raw_ratio: float = clamp(1.0 - (age / trail_lifetime), 0.0, 1.0)
		var life_ratio: float = pow(raw_ratio, trail_fade_sharpness)
		var dir: Vector3
		if i == 0:
			dir = _trail_points[i + 1]["pos"] - pos
		elif i == count - 1:
			dir = pos - _trail_points[i - 1]["pos"]
		else:
			dir = _trail_points[i + 1]["pos"] - _trail_points[i - 1]["pos"]

		if dir.length_squared() < 0.000001:
			dir = Vector3.FORWARD
		dir = dir.normalized()
		var to_cam := (cam_pos - pos).normalized()
		var side := dir.cross(to_cam)
		if side.length_squared() < 0.000001:
			side = Vector3.RIGHT
		side = side.normalized()

		var half_width := trail_width * 0.5 * life_ratio
		var color := trail_color
		color.a = trail_color.a * life_ratio

		_trail_immediate.surface_set_color(color)
		_trail_immediate.surface_add_vertex(pos + side * half_width)
		_trail_immediate.surface_set_color(color)
		_trail_immediate.surface_add_vertex(pos - side * half_width)

	_trail_immediate.surface_end()
