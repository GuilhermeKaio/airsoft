extends RefCounted

const TargetSpawnAreaClass = preload("res://Scripts/target_spawn_area.gd")
const ShootingTargetClass = preload("res://Scripts/shooting_target.gd")
const ShootingGalleryManagerClass = preload("res://Scripts/shooting_gallery_manager.gd")

var _failed: bool = false
var _message: String = ""
var _assertion_count: int = 0

func _reset() -> void:
	_failed = false
	_message = ""
	_assertion_count = 0

func assert_true(condition: bool, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if not condition:
		_failed = true
		_message = msg if msg != "" else "Esperava true, obteve false"

func assert_false(condition: bool, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if condition:
		_failed = true
		_message = msg if msg != "" else "Esperava false, obteve true"

func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if actual != expected:
		_failed = true
		_message = msg if msg != "" else ("Esperava %s, obteve %s" % [str(expected), str(actual)])

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if absf(actual - expected) > tolerance:
		_failed = true
		_message = msg if msg != "" else ("Esperava ~%s, obteve %s (tolerância: %s)" % [str(expected), str(actual), str(tolerance)])


# 1. Spawn Volume Bounds Default Specifications (SRS 1.4)
func test_spawn_area_bounds_specifications() -> void:
	var area = TargetSpawnAreaClass.new()
	area._ready()

	# Largura (Eixo Lateral X): -12.0m a +12.0m
	assert_almost_eq(area.lateral_min, -12.0, 0.001, "Largura mínima deve ser -12.0m")
	assert_almost_eq(area.lateral_max, 12.0, 0.001, "Largura máxima deve ser +12.0m")

	# Profundidade (Eixo Longitudinal Z): 10.0m a 45.0m
	assert_almost_eq(area.depth_min, 10.0, 0.001, "Profundidade mínima deve ser 10.0m")
	assert_almost_eq(area.depth_max, 45.0, 0.001, "Profundidade máxima deve ser 45.0m")

	# Altura (Eixo Vertical Y): 0.5m a 2.5m
	assert_almost_eq(area.height_min, 0.5, 0.001, "Altura mínima deve ser 0.5m")
	assert_almost_eq(area.height_max, 2.5, 0.001, "Altura máxima deve ser 2.5m")

	# Anti-sobreposição: separação mínima de 2.0m
	assert_almost_eq(area.min_separation, 2.0, 0.001, "Raio mínimo de separação deve ser 2.0m")

	area.free()


# 2. Random Points Within Bounds (SRS 1.4)
func test_random_points_strictly_within_bounds() -> void:
	var area = TargetSpawnAreaClass.new()
	area._ready()

	for i in range(50):
		var pt = area.get_random_point_in_bounds()
		assert_true(pt.x >= area.lateral_min and pt.x <= area.lateral_max, "Ponto X deve estar entre lateral_min e lateral_max")
		assert_true(pt.y >= area.height_min and pt.y <= area.height_max, "Ponto Y deve estar entre height_min e height_max")
		assert_true(pt.z >= area.depth_min and pt.z <= area.depth_max, "Ponto Z deve estar entre depth_min e depth_max")

	area.free()


# 3. Anti-Overlap Validation (SRS 1.4)
func test_anti_overlap_validation_and_rejection() -> void:
	var area = TargetSpawnAreaClass.new()
	area._ready()

	var existing = [
		Vector3(0.0, 1.5, 20.0),
		Vector3(5.0, 1.0, 30.0)
	]

	# Point exactly on top of an existing target -> must be rejected
	assert_false(area.is_position_valid(Vector3(0.0, 1.5, 20.0), existing), "Ponto coincidente deve ser inválido")

	# Point 1.0m away (< 2.0m) -> must be rejected
	assert_false(area.is_position_valid(Vector3(0.0, 1.5, 21.0), existing), "Ponto a 1.0m deve ser rejeitado")

	# Point 1.9m away (< 2.0m) -> must be rejected
	assert_false(area.is_position_valid(Vector3(0.0, 1.5, 21.9), existing), "Ponto a 1.9m deve ser rejeitado")

	# Point 2.5m away (>= 2.0m) -> valid
	assert_true(area.is_position_valid(Vector3(0.0, 1.5, 22.5), existing), "Ponto a 2.5m deve ser aceito")

	# Point 10.0m away -> valid
	assert_true(area.is_position_valid(Vector3(-5.0, 1.5, 20.0), existing), "Ponto distante deve ser aceito")

	area.free()


# 4. Anti-Overlap Multi-Target Spawn Distribution (SRS 1.4)
func test_spawn_multiple_targets_respects_separation() -> void:
	var area = TargetSpawnAreaClass.new()
	area.use_local_space = false # testa diretamente em coordenadas locais/globais
	area._ready()

	var spawned: Array[ShootingTarget] = []
	for i in range(8):
		var target = area.spawn_target(0, 0, 0.0)
		spawned.append(target)

	assert_eq(area.get_active_target_count(), 8, "Devem existir 8 alvos ativos instanciados")
	var positions = area.get_active_target_positions()
	assert_eq(positions.size(), 8)

	# Verifica que NENHUM par de alvos possui distância < 2.0m (SRS 1.4)
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			var dist = positions[i].distance_to(positions[j])
			assert_true(dist >= area.min_separation, "Distância entre alvos (%f) deve ser >= 2.0m" % dist)

	area.clear_all_targets()
	assert_eq(area.get_active_target_count(), 0, "Após clear_all_targets, alvos ativos devem ser 0")
	area.free()


# 5. Target Removal and Cleanup
func test_target_removal_and_lifecycle() -> void:
	var area = TargetSpawnAreaClass.new()
	area.use_local_space = false
	area._ready()

	var t1 = area.spawn_target(0, 0, 0.0)
	var t2 = area.spawn_target(1, 0, 0.0)

	assert_eq(area.get_active_target_count(), 2)

	area.remove_target(t1)
	assert_eq(area.get_active_target_count(), 1)
	assert_false(area.get_active_targets().has(t1))
	assert_true(area.get_active_targets().has(t2))

	area.clear_all_targets()
	assert_eq(area.get_active_target_count(), 0)
	area.free()


# 6. Local-to-World Coordinate Mapping with Transformed Node
func test_local_to_world_transform_mapping() -> void:
	var area = TargetSpawnAreaClass.new()
	area.use_local_space = true
	area.position = Vector3(100.0, 0.0, 50.0)
	area._ready()

	var local_pt = Vector3(0.0, 1.5, 20.0)
	var world_pt = area.to_world_position(local_pt)

	assert_almost_eq(world_pt.x, 100.0, 0.01)
	assert_almost_eq(world_pt.y, 1.5, 0.01)
	assert_almost_eq(world_pt.z, 70.0, 0.01)

	area.free()


# 7. Editor vs In-Game Visualization Visibility
func test_editor_vs_ingame_visualization() -> void:
	var area = TargetSpawnAreaClass.new()
	area._ready()

	# Em tempo de jogo (runtime / headless runner: Engine.is_editor_hint() é false)
	assert_false(Engine.is_editor_hint())
	assert_true(area._debug_mesh == null or not area._debug_mesh.is_inside_tree(), "Área de spawn NÃO deve ser visível no jogo")
	assert_true(area._editor_label == null or not area._editor_label.is_inside_tree(), "Label do editor NÃO deve ser visível no jogo")

	# Simulação do modo Editor (deve exibir visualização da caixa e dimensões)
	area._setup_editor_debug_visualization()
	assert_true(area._debug_mesh != null and is_instance_valid(area._debug_mesh) and area._debug_mesh.get_parent() == area, "Área de spawn DEVE estar visível no editor")
	assert_true(area._editor_label != null and is_instance_valid(area._editor_label) and area._editor_label.get_parent() == area, "Label DEVE estar visível no editor")
	assert_eq(area._debug_mesh.name, "EditorDebugVolumeMesh")

	# Limpeza para quando o jogo inicia
	area._cleanup_editor_visualization()
	assert_true(area._debug_mesh == null, "Visualização deve ser removida ao iniciar o jogo")
	assert_true(area._editor_label == null, "Label deve ser removida ao iniciar o jogo")

	area.free()
