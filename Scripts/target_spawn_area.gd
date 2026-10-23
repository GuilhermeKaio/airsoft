@tool
class_name TargetSpawnArea
extends Node3D

## Área Delimitada de Spawn dos Alvos (SRS Adicionais Seção 1.4)
## Delimita o volume 3D do estande de tiro (Largura X, Altura Y, Profundidade Z)
## e garante validação de anti-sobreposição (separação mínima de 2.0m) entre alvos.
## Visível no editor da Godot Engine, mas oculta dentro do jogo.

const DEFAULT_LATERAL_MIN: float = -12.0
const DEFAULT_LATERAL_MAX: float = 12.0
const DEFAULT_DEPTH_MIN: float = 10.0
const DEFAULT_DEPTH_MAX: float = 45.0
const DEFAULT_HEIGHT_MIN: float = 0.5
const DEFAULT_HEIGHT_MAX: float = 2.5
const DEFAULT_MIN_SEPARATION: float = 2.0

signal target_spawned(target: ShootingTarget, position: Vector3)
signal alvo_gerado(alvo: ShootingTarget, posicao: Vector3)
signal target_despawned(target: ShootingTarget)
signal alvo_desapareceu(alvo: ShootingTarget)
signal target_removed(target: ShootingTarget)

@export_group("Spawn Volume Bounds (SRS 1.4)")
## Faixa lateral (X) em relação à linha central da galeria (-12m a +12m)
@export var lateral_min: float = DEFAULT_LATERAL_MIN:
	set(val):
		lateral_min = val
		if Engine.is_editor_hint():
			_update_editor_debug_visualization()

@export var lateral_max: float = DEFAULT_LATERAL_MAX:
	set(val):
		lateral_max = val
		if Engine.is_editor_hint():
			_update_editor_debug_visualization()

## Distância longitudinal (Z) à frente da bancada (10m a 45m)
@export var depth_min: float = DEFAULT_DEPTH_MIN:
	set(val):
		depth_min = val
		if Engine.is_editor_hint():
			_update_editor_debug_visualization()

@export var depth_max: float = DEFAULT_DEPTH_MAX:
	set(val):
		depth_max = val
		if Engine.is_editor_hint():
			_update_editor_debug_visualization()

## Elevação vertical (Y) acima do piso (0.5m a 2.5m)
@export var height_min: float = DEFAULT_HEIGHT_MIN:
	set(val):
		height_min = val
		if Engine.is_editor_hint():
			_update_editor_debug_visualization()

@export var height_max: float = DEFAULT_HEIGHT_MAX:
	set(val):
		height_max = val
		if Engine.is_editor_hint():
			_update_editor_debug_visualization()

@export_group("Anti-Overlap & Validation")
## Raio mínimo de separação para evitar sobreposição geométrica ou oclusão (m)
@export var min_separation: float = DEFAULT_MIN_SEPARATION
## Número máximo de tentativas de busca por posição livre antes do fallback
@export var max_spawn_attempts: int = 50
## Se true, as coordenadas de spawn são transformadas usando o Transform3D deste nó
@export var use_local_space: bool = true

@export_group("Target Scene & Manager Reference")
@export var target_scene: PackedScene = preload("res://Scenes/shooting_target.tscn")
@export var manager_path: NodePath = ^""

var _active_targets: Array[ShootingTarget] = []
var _manager: Node = null
var _debug_mesh: MeshInstance3D = null
var _editor_label: Label3D = null


func _ready() -> void:
	if Engine.is_editor_hint():
		# No editor da Godot: exibe o volume 3D demarcado com suas medidas
		_setup_editor_debug_visualization()
		return

	# DENTRO DO JOGO: garante que a área NÃO é mostrada
	_cleanup_editor_visualization()

	add_to_group("target_spawn_area")
	_find_and_setup_manager()


func _find_and_setup_manager() -> void:
	if not manager_path.is_empty():
		_manager = get_node_or_null(manager_path)
	if _manager == null and is_inside_tree():
		if get_parent() and get_parent().has_method("register_target"):
			_manager = get_parent()
		elif get_tree().current_scene:
			_manager = get_tree().current_scene.find_child("ShootingGalleryManager", true, false)
		if _manager == null:
			_manager = get_tree().root.find_child("ShootingGalleryManager", true, false)

	if _manager and _manager.has_method("set_spawn_area"):
		_manager.call("set_spawn_area", self)


func set_manager(manager: Node) -> void:
	_manager = manager


## Gera um ponto aleatório uniforme dentro dos limites numéricos da área (SRS 1.4)
func get_random_point_in_bounds() -> Vector3:
	var x = randf_range(lateral_min, lateral_max)
	var y = randf_range(height_min, height_max)
	var z = randf_range(depth_min, depth_max)
	return Vector3(x, y, z)


## Transforma ponto local para coordenadas globais de mundo
func to_world_position(local_point: Vector3) -> Vector3:
	if use_local_space and is_inside_tree():
		return to_global(local_point)
	elif use_local_space:
		return global_transform * local_point if is_inside_tree() else (position + local_point)
	return local_point


## Converte coordenadas globais para coordenadas locais da área
func to_local_position(world_point: Vector3) -> Vector3:
	if use_local_space and is_inside_tree():
		return to_local(world_point)
	return world_point


## Valida se a posição respeita a distância mínima de separação anti-sobreposição (SRS 1.4)
func is_position_valid(candidate_pos: Vector3, active_positions: Array = [], min_dist: float = -1.0) -> bool:
	var req_dist = min_dist if min_dist > 0.0 else min_separation
	var positions_to_check = active_positions
	if positions_to_check.is_empty():
		positions_to_check = get_active_target_positions()

	for existing in positions_to_check:
		if candidate_pos.distance_to(existing) < req_dist:
			return false
	return true


## Retorna uma posição válida garantindo anti-sobreposição (SRS 1.4)
func get_valid_spawn_position(existing_positions: Array = [], min_dist: float = -1.0, max_attempts: int = -1) -> Vector3:
	var attempts_limit = max_attempts if max_attempts > 0 else max_spawn_attempts
	var req_dist = min_dist if min_dist > 0.0 else min_separation

	var positions_to_check = existing_positions
	if positions_to_check.is_empty():
		positions_to_check = get_active_target_positions()

	# Se não há alvos ativos, qualquer ponto no volume é imediatamente válido
	if positions_to_check.is_empty():
		var local_pt = get_random_point_in_bounds()
		return to_world_position(local_pt)

	var best_candidate := Vector3.ZERO
	var best_distance := -1.0

	for attempt in range(attempts_limit):
		var local_candidate = get_random_point_in_bounds()
		var candidate_world = to_world_position(local_candidate)

		# Calcula menor distância até qualquer alvo existente
		var closest_dist := 1e9
		for pos in positions_to_check:
			var d = candidate_world.distance_to(pos)
			if d < closest_dist:
				closest_dist = d

		if closest_dist >= req_dist:
			return candidate_world

		if closest_dist > best_distance:
			best_distance = closest_dist
			best_candidate = candidate_world

	# Fallback com melhor separação encontrada
	return best_candidate if best_distance > 0.0 else to_world_position(get_random_point_in_bounds())


## Instancia e posiciona dinamicamente um novo alvo dentro da área delimitada (SRS 1.4)
func spawn_target(type: int = 0, movement: int = 0, despawn_window: float = 0.0) -> ShootingTarget:
	_cleanup_invalid_targets()

	var target_instance: ShootingTarget = null
	if target_scene != null:
		var scene_obj = target_scene.instantiate()
		if scene_obj is ShootingTarget:
			target_instance = scene_obj
		else:
			target_instance = ShootingTarget.new()
	else:
		target_instance = ShootingTarget.new()

	target_instance.target_type = type as ShootingTarget.TargetType
	target_instance.movement_type = movement as ShootingTarget.MovementType

	if despawn_window > 0.0:
		target_instance.despawn_lifetime = despawn_window

	var spawn_pos = get_valid_spawn_position()
	add_child(target_instance)

	if is_inside_tree():
		target_instance.global_position = spawn_pos
	else:
		target_instance.position = spawn_pos

	_active_targets.append(target_instance)

	# Monitora término/despawn do alvo
	target_instance.tree_exited.connect(func(): _on_target_tree_exited(target_instance))
	if target_instance.has_signal("alvo_desapareceu"):
		target_instance.alvo_desapareceu.connect(func(t): _on_target_despawned(t))

	# Registra com o ShootingGalleryManager
	if _manager and _manager.has_method("register_target"):
		_manager.call("register_target", target_instance)

	target_spawned.emit(target_instance, spawn_pos)
	alvo_gerado.emit(target_instance, spawn_pos)

	return target_instance


## Remove e desinstancia um alvo ativo da área
func remove_target(target: ShootingTarget) -> void:
	if target == null:
		return
	if _active_targets.has(target):
		_active_targets.erase(target)
	target_removed.emit(target)
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		target.set_deferred("collision_layer", 0)
		target.visible = false
		target.queue_free()


## Remove todos os alvos ativos gerados pela área
func clear_all_targets() -> void:
	_cleanup_invalid_targets()
	var targets_copy = _active_targets.duplicate()
	_active_targets.clear()

	for t in targets_copy:
		if is_instance_valid(t) and not t.is_queued_for_deletion():
			t.set_deferred("collision_layer", 0)
			t.visible = false
			t.queue_free()


func _on_target_tree_exited(target: ShootingTarget) -> void:
	if _active_targets.has(target):
		_active_targets.erase(target)


func _on_target_despawned(target: ShootingTarget) -> void:
	target_despawned.emit(target)
	alvo_desapareceu.emit(target)


func _cleanup_invalid_targets() -> void:
	var valid_list: Array[ShootingTarget] = []
	for t in _active_targets:
		if is_instance_valid(t) and not t.is_queued_for_deletion():
			valid_list.append(t)
	_active_targets = valid_list


## Retorna alvos ativos atualmente instanciados
func get_active_targets() -> Array[ShootingTarget]:
	_cleanup_invalid_targets()
	return _active_targets.duplicate()


## Retorna posições globais de todos os alvos ativos
func get_active_target_positions() -> Array[Vector3]:
	_cleanup_invalid_targets()
	var positions: Array[Vector3] = []
	for t in _active_targets:
		if is_instance_valid(t) and t.is_inside_tree():
			positions.append(t.global_position)
		elif is_instance_valid(t):
			positions.append(t.position)
	return positions


## Retorna a quantidade de alvos ativos na área
func get_active_target_count() -> int:
	_cleanup_invalid_targets()
	return _active_targets.size()


## Retorna o centro geométrico da caixa de spawn
func get_bounds_center() -> Vector3:
	return Vector3(
		(lateral_min + lateral_max) * 0.5,
		(height_min + height_max) * 0.5,
		(depth_min + depth_max) * 0.5
	)


## Retorna as dimensões (largura, altura, profundidade) do volume de spawn
func get_bounds_size() -> Vector3:
	return Vector3(
		absf(lateral_max - lateral_min),
		absf(height_max - height_min),
		absf(depth_max - depth_min)
	)


## Configuração visual da área de spawn EXCLUSIVAMENTE para o editor
func _setup_editor_debug_visualization() -> void:
	_cleanup_editor_visualization()

	# Volume translúcido 3D
	_debug_mesh = MeshInstance3D.new()
	_debug_mesh.name = "EditorDebugVolumeMesh"
	var box = BoxMesh.new()
	box.size = get_bounds_size()
	_debug_mesh.mesh = box
	_debug_mesh.position = get_bounds_center()

	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.1, 0.75, 1.0, 0.18) # Azul ciano translúcido
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.75, 1.0)
	mat.emission_energy_multiplier = 0.4
	_debug_mesh.material_override = mat
	add_child(_debug_mesh)

	# Rótulo 3D informativo no topo da área no editor
	_editor_label = Label3D.new()
	_editor_label.name = "EditorDebugLabel"
	var sz = get_bounds_size()
	_editor_label.text = "ÁREA DE SPAWN DE ALVOS (%.1fm x %.1fm x %.1fm)\nSeparação mínima: %.1fm" % [sz.x, sz.y, sz.z, min_separation]
	_editor_label.font_size = 28
	_editor_label.outline_size = 6
	_editor_label.modulate = Color(0.2, 0.9, 1.0)
	_editor_label.position = Vector3(
		get_bounds_center().x,
		height_max + 0.4,
		get_bounds_center().z
	)
	add_child(_editor_label)


func _update_editor_debug_visualization() -> void:
	if not Engine.is_editor_hint():
		return

	if _debug_mesh and _debug_mesh.mesh is BoxMesh:
		(_debug_mesh.mesh as BoxMesh).size = get_bounds_size()
		_debug_mesh.position = get_bounds_center()

	if _editor_label:
		var sz = get_bounds_size()
		_editor_label.text = "ÁREA DE SPAWN DE ALVOS (%.1fm x %.1fm x %.1fm)\nSeparação mínima: %.1fm" % [sz.x, sz.y, sz.z, min_separation]
		_editor_label.position = Vector3(
			get_bounds_center().x,
			height_max + 0.4,
			get_bounds_center().z
		)


func _cleanup_editor_visualization() -> void:
	if _debug_mesh != null and is_instance_valid(_debug_mesh):
		_debug_mesh.queue_free()
		_debug_mesh = null
	if _editor_label != null and is_instance_valid(_editor_label):
		_editor_label.queue_free()
		_editor_label = null

	# Remove também se existir nó com o nome
	var old_mesh = get_node_or_null("EditorDebugVolumeMesh")
	if old_mesh:
		old_mesh.queue_free()
	var old_lbl = get_node_or_null("EditorDebugLabel")
	if old_lbl:
		old_lbl.queue_free()
