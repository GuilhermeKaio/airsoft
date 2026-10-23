class_name ShootingTarget
extends AnimatableBody3D

## Target Node for Shooting Gallery (SRS Adicionais Seção 1)
## Suporta classificação Enemy/Friendly, movimentação Cinemática (Static, Linear Patrol, Popup),
## detecção de impacto balístico de BBs, knockdown mecânico e feedback visual.

enum TargetType {
	ENEMY,
	FRIENDLY
}

enum MovementType {
	STATIC,
	LINEAR_PATROL,
	POPUP
}

const LAYER_TARGETS: int = 16

signal hit(target: Node, bb: Node)
signal target_hit(target: Node, bb: Node)
signal alvo_atingido(alvo: Node, bb: Node)
signal target_reset(target: Node)
signal alvo_resetado(alvo: Node)
signal target_despawned(target: Node)
signal alvo_desapareceu(alvo: Node)

@export_group("Target Specification (SRS 1.1)")
@export var target_type: TargetType = TargetType.ENEMY:
	set(value):
		target_type = value
		_update_default_points()
		_update_visuals()

@export var movement_type: MovementType = MovementType.STATIC:
	set(value):
		movement_type = value
		_update_movement_state()

@export var points_value: int = 100
@export var move_speed: float = 3.0
@export var respawn_time: float = 3.0
@export var is_active: bool = true:
	set(value):
		is_active = value
		_update_active_state(value)

@export_group("Dimensions & Sizing")
## Largura (X) e Altura (Y) da placa do alvo em metros. Se for (0, 0), respeita as dimensões configuradas na cena .tscn.
@export var target_dimensions: Vector2 = Vector2.ZERO:
	set(value):
		target_dimensions = value
		if is_node_ready() and target_dimensions != Vector2.ZERO:
			_apply_dimensions()

@export_group("Patrol Settings (SRS 1.2)")
@export var patrol_axis: Vector3 = Vector3.RIGHT
@export var patrol_distance: float = 6.0
@export var patrol_start_position: Vector3 = Vector3.ZERO
@export var patrol_end_position: Vector3 = Vector3.ZERO

@export_group("Popup Settings (SRS 1.2)")
@export var popup_duration: float = 3.0
@export var popup_hide_time: float = 2.0

@export_group("Despawn Lifetime (SRS 2.1 & 2.2)")
@export var despawn_lifetime: float = 0.0
var _lifetime_timer: float = 0.0

# Internal state
var _initial_position: Vector3 = Vector3.ZERO
var _initial_rotation: Vector3 = Vector3.ZERO
var _patrol_progress: float = 0.0
var _patrol_direction: float = 1.0

var _popup_timer: float = 0.0
var _is_popping_up: bool = false
var _is_respawning: bool = false
var _respawn_timer: float = 0.0

# Visual and physical references
var mesh_instance: MeshInstance3D = null
var collision_shape: CollisionShape3D = null
var _material: StandardMaterial3D = null


func _ready() -> void:
	add_to_group("shooting_targets")
	add_to_group("shooting_target")
	add_to_group("targets")

	_initial_position = position
	_initial_rotation = rotation

	# Physics Layer: Layer 5 (Targets, bit 5 = 16)
	collision_layer = LAYER_TARGETS
	collision_mask = 0

	_find_or_create_nodes()
	if target_dimensions != Vector2.ZERO:
		_apply_dimensions()
	_update_default_points()
	_update_visuals()
	_update_movement_state()

	call_deferred("_register_with_active_manager")


func _register_with_active_manager() -> void:
	if not is_inside_tree():
		return
	var mgr = get_tree().root.find_child("ShootingGalleryManager", true, false)
	if mgr and mgr.has_method("register_target"):
		mgr.register_target(self)


func _find_or_create_nodes() -> void:
	# Check if children already exist
	for child in get_children():
		if child is MeshInstance3D and mesh_instance == null:
			mesh_instance = child
		elif child is CollisionShape3D and collision_shape == null:
			collision_shape = child

	# Auto-generate default visual plate and collision shape if missing
	var default_w = target_dimensions.x if target_dimensions.x > 0.0 else 1.0
	var default_h = target_dimensions.y if target_dimensions.y > 0.0 else 1.8
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(default_w, default_h, 0.14)
		collision_shape.shape = box_shape
		collision_shape.position = Vector3(0, default_h * 0.5, 0)
		add_child(collision_shape)

	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(default_w, default_h, 0.12)
		mesh_instance.mesh = box_mesh
		mesh_instance.position = Vector3(0, default_h * 0.5, 0)
		add_child(mesh_instance)


func _apply_dimensions() -> void:
	if target_dimensions == Vector2.ZERO:
		return

	if mesh_instance and mesh_instance.mesh is BoxMesh:
		if not mesh_instance.mesh.resource_local_to_scene:
			mesh_instance.mesh = mesh_instance.mesh.duplicate()
		var bm = mesh_instance.mesh as BoxMesh
		bm.size = Vector3(target_dimensions.x, target_dimensions.y, bm.size.z)
		mesh_instance.position.y = target_dimensions.y * 0.5

	if collision_shape and collision_shape.shape is BoxShape3D:
		if not collision_shape.shape.resource_local_to_scene:
			collision_shape.shape = collision_shape.shape.duplicate()
		var bs = collision_shape.shape as BoxShape3D
		bs.size = Vector3(target_dimensions.x, target_dimensions.y, bs.size.z)
		collision_shape.position.y = target_dimensions.y * 0.5


func _update_default_points() -> void:
	if target_type == TargetType.FRIENDLY:
		if points_value > 0 or points_value == 100:
			points_value = -200
	else:
		if points_value < 0 or points_value == -200:
			points_value = 100


func _update_visuals() -> void:
	if mesh_instance == null:
		return

	if _material == null:
		_material = StandardMaterial3D.new()
		mesh_instance.material_override = _material

	if target_type == TargetType.ENEMY:
		# Hostile target: aggressive color (dark red/orange)
		_material.albedo_color = Color(0.85, 0.22, 0.15, 1.0)
		_material.emission_enabled = false
	else:
		# Friendly/civilian target: neutral blue/white
		_material.albedo_color = Color(0.2, 0.55, 0.85, 1.0)
		_material.emission_enabled = false


func _update_movement_state() -> void:
	if movement_type == MovementType.POPUP:
		_is_popping_up = true
		_popup_timer = 0.0
	elif movement_type == MovementType.LINEAR_PATROL:
		_patrol_progress = 0.0
		_patrol_direction = 1.0


func _update_active_state(active: bool) -> void:
	if not is_inside_tree():
		return
	if active:
		set_deferred("collision_layer", LAYER_TARGETS)
		if collision_shape:
			collision_shape.set_deferred("disabled", false)
	else:
		set_deferred("collision_layer", 0)
		if collision_shape:
			collision_shape.set_deferred("disabled", true)


func _physics_process(delta: float) -> void:
	if _is_respawning:
		_respawn_timer += delta
		if _respawn_timer >= respawn_time:
			reset_target()
		return

	if is_active and despawn_lifetime > 0.0:
		_lifetime_timer += delta
		if _lifetime_timer >= despawn_lifetime:
			despawn()
			return

	match movement_type:
		MovementType.STATIC:
			pass

		MovementType.LINEAR_PATROL:
			_process_linear_patrol(delta)

		MovementType.POPUP:
			_process_popup(delta)


func _process_linear_patrol(delta: float) -> void:
	if patrol_distance <= 0.0 or move_speed <= 0.0:
		return

	var half_dist = patrol_distance * 0.5
	_patrol_progress += move_speed * delta * _patrol_direction

	if _patrol_progress >= half_dist:
		_patrol_progress = half_dist
		_patrol_direction = -1.0
	elif _patrol_progress <= -half_dist:
		_patrol_progress = -half_dist
		_patrol_direction = 1.0

	var axis = patrol_axis.normalized() if patrol_axis.length_squared() > 0.001 else Vector3.RIGHT
	position = _initial_position + axis * _patrol_progress


func _process_popup(delta: float) -> void:
	_popup_timer += delta

	if is_active:
		# Target is exposed/upright
		if _popup_timer >= popup_duration:
			# Time window expired without hit: hide without points!
			_popup_hide()
	else:
		# Target is hidden
		if _popup_timer >= popup_hide_time:
			# Time to pop back up
			_popup_reveal()


func _popup_hide() -> void:
	is_active = false
	_popup_timer = 0.0
	_apply_knockdown(true)


func _popup_reveal() -> void:
	is_active = true
	_popup_timer = 0.0
	_apply_knockdown(false)
	_update_visuals()


## Callback de impacto da BB (SRS 1.3)
func on_hit(bb: Node = null) -> void:
	if not is_active:
		return

	is_active = false
	_is_respawning = true
	_respawn_timer = 0.0

	# Mechanical knockdown animation and hit feedback
	_apply_knockdown(true)
	_apply_hit_color_feedback()

	# Emit signals
	hit.emit(self, bb)
	target_hit.emit(self, bb)
	alvo_atingido.emit(self, bb)


func acertar(bb: Node = null) -> void:
	on_hit(bb)


func _apply_knockdown(knocked_down: bool) -> void:
	var target_pitch = (_initial_rotation.x - deg_to_rad(90.0)) if knocked_down else _initial_rotation.x
	if is_inside_tree():
		var tween = create_tween()
		if tween:
			tween.tween_property(self, "rotation:x", target_pitch, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			rotation.x = target_pitch
	else:
		rotation.x = target_pitch


func _apply_hit_color_feedback() -> void:
	if _material == null and mesh_instance != null:
		_material = StandardMaterial3D.new()
		mesh_instance.material_override = _material

	if _material == null:
		return

	if target_type == TargetType.ENEMY:
		# Positive feedback on enemy: green flash
		_material.albedo_color = Color(0.2, 0.95, 0.25, 1.0)
		_material.emission_enabled = true
		_material.emission = Color(0.2, 0.95, 0.25, 1.0)
		_material.emission_energy_multiplier = 1.5
	else:
		# Negative penalty feedback on friendly: red flash
		_material.albedo_color = Color(0.95, 0.1, 0.1, 1.0)
		_material.emission_enabled = true
		_material.emission = Color(0.95, 0.1, 0.1, 1.0)
		_material.emission_energy_multiplier = 1.5


## Força o desaparecimento do alvo por tempo esgotado (Time Attack Hard / SRS 2.1 & 2.2)
func despawn() -> void:
	if not is_active:
		return

	is_active = false
	_apply_knockdown(true)
	target_despawned.emit(self)
	alvo_desapareceu.emit(self)


func sumir() -> void:
	despawn()


## Restaura o alvo ao estado ativo erguido (SRS 1.1 e 1.3)
func reset_target() -> void:
	_is_respawning = false
	_respawn_timer = 0.0
	_popup_timer = 0.0
	_lifetime_timer = 0.0
	is_active = true

	_apply_knockdown(false)
	_update_visuals()

	target_reset.emit(self)
	alvo_resetado.emit(self)


func resetar_alvo() -> void:
	reset_target()
