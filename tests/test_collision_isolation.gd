extends RefCounted

const BBClass = preload("res://Scripts/bb.gd")
const WeaponClass = preload("res://Scripts/weapon.gd")
const PlayerClass = preload("res://Scripts/player.gd")
const MagazinePickupClass = preload("res://Scripts/magazine_pickup.gd")
const WeaponPickupClass = preload("res://Scripts/weapon_pickup.gd")

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
		_message = msg if msg != "" else "Expected true, got false"

func assert_false(condition: bool, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if condition:
		_failed = true
		_message = msg if msg != "" else "Expected false, got true"

func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if actual != expected:
		_failed = true
		_message = msg if msg != "" else ("Expected %s, got %s" % [str(expected), str(actual)])


## 1. 3D Physics Layer Names in ProjectSettings (SRS Adicionais Seção 5.1)
func test_layer_names_configured_in_project() -> void:
	var l1: String = ProjectSettings.get_setting("layer_names/3d_physics/layer_1", "")
	var l2: String = ProjectSettings.get_setting("layer_names/3d_physics/layer_2", "")
	var l3: String = ProjectSettings.get_setting("layer_names/3d_physics/layer_3", "")
	var l4: String = ProjectSettings.get_setting("layer_names/3d_physics/layer_4", "")
	var l5: String = ProjectSettings.get_setting("layer_names/3d_physics/layer_5", "")
	var l6: String = ProjectSettings.get_setting("layer_names/3d_physics/layer_6", "")

	assert_eq(l1, "World", "Layer 1 should be World")
	assert_eq(l2, "Player", "Layer 2 should be Player")
	assert_eq(l3, "Weapon", "Layer 3 should be Weapon")
	assert_eq(l4, "BB_Projectile", "Layer 4 should be BB_Projectile")
	assert_eq(l5, "Targets", "Layer 5 should be Targets")
	assert_eq(l6, "Pickups", "Layer 6 should be Pickups")


## 2. BB Projectile Collision Isolation (SRS Adicionais Seção 5.2.1)
func test_bb_collision_layer_and_mask_isolation() -> void:
	var bb_scene = load("res://Scenes/bb.tscn")
	var bb = bb_scene.instantiate()
	bb._ready()

	# Layer 4 (value 8)
	assert_eq(bb.collision_layer, 8, "BB collision_layer should be Layer 4 (8)")

	# Mask must monitor exclusively World (Layer 1 = 1) and Targets (Layer 5 = 16) -> 17
	assert_eq(bb.collision_mask, 17, "BB collision_mask should monitor Layer 1 (World) and Layer 5 (Targets)")

	# Mandatory rule: PROHIBIT Player (Layer 2 = 2) and Weapon (Layer 3 = 4)
	assert_eq(bb.collision_mask & BBClass.LAYER_PLAYER, 0, "BB collision_mask MUST NOT include Player (Layer 2)")
	assert_eq(bb.collision_mask & BBClass.LAYER_WEAPON, 0, "BB collision_mask MUST NOT include Weapon (Layer 3)")

	bb.free()


## 3. Player Collision Layer and Mask (SRS Adicionais Seção 5.1)
func test_player_collision_layer_and_mask() -> void:
	var player = PlayerClass.new()
	player._ready()

	assert_eq(player.collision_layer, 2, "Player collision_layer should be Layer 2 (Player = 2)")
	assert_eq(player.collision_mask, 1, "Player collision_mask should be Layer 1 (World = 1)")
	assert_true(player.is_in_group("player"), "Player node must be registered in group 'player'")

	player.free()


## 4. Pickups Collision Layer and Mask (SRS Adicionais Seção 5.1)
func test_pickups_collision_layer_and_mask() -> void:
	var mag_pickup = MagazinePickupClass.new()
	mag_pickup._setup_collision()
	assert_eq(mag_pickup.collision_layer, 32, "MagazinePickup should be Layer 6 (Pickups = 32)")
	assert_eq(mag_pickup.collision_mask & 2, 2, "MagazinePickup mask must detect Player (Layer 2)")
	mag_pickup.free()

	var wep_pickup = WeaponPickupClass.new()
	wep_pickup._setup_collision()
	assert_eq(wep_pickup.collision_layer, 32, "WeaponPickup should be Layer 6 (Pickups = 32)")
	assert_eq(wep_pickup.collision_mask & 2, 2, "WeaponPickup mask must detect Player (Layer 2)")
	wep_pickup.free()


## 5. Runtime Collision Exception with Player (SRS Adicionais Seção 5.2.2)
func test_runtime_collision_exception_with_player() -> void:
	var player = PlayerClass.new()
	player.name = "Player"
	player._ready()

	var weapon = WeaponClass.new()
	player.add_child(weapon)
	weapon._ready()

	assert_eq(weapon._get_player_node(), player, "Weapon should identify player parent as player node")

	# Fire weapon
	weapon.fire()

	# Find instantiated bullet in weapon's tree
	var bullet: Node = null
	for child in weapon.get_children():
		if child.get_script() == BBClass or child.is_in_group("bb_projectile") or child.is_in_group("bb_projetil"):
			bullet = child
			break
	if bullet == null:
		for child in player.get_children():
			if child.get_script() == BBClass or child.is_in_group("bb_projectile") or child.is_in_group("bb_projetil"):
				bullet = child
				break

	assert_true(bullet != null, "Bullet should be instantiated upon firing")
	if bullet and bullet is CollisionObject3D:
		var has_exception: bool = bullet.get_collision_exceptions().has(player)
		assert_true(has_exception, "Bullet must have runtime collision exception with player node")
		assert_eq(bullet.collision_mask & 2, 0, "Spawned bullet mask does not monitor player")

	player.free()
