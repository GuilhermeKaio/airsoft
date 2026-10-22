extends RefCounted

const WeaponClass = preload("res://Scripts/weapon.gd")
const MagazineClass = preload("res://Scripts/magazine.gd")
const MagazineLoaderClass = preload("res://Scripts/magazine_loader.gd")

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


func test_weapon_initialization() -> void:
	var weapon = WeaponClass.new()
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	weapon._ready()

	assert_true(weapon.equipped_magazine != null, "Weapon should auto-create default magazine if null")
	assert_eq(weapon.equipped_magazine.type, MagazineClass.Type.MAG_PISTOL_GLOCK)
	assert_eq(weapon.current_ammo, 25)
	assert_eq(weapon.magazine_capacity, 25)
	weapon.free()


func test_weapon_magazine_compatibility() -> void:
	var weapon = WeaponClass.new()
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	weapon._ready()

	var wrong_mag = MagazineLoaderClass.create_rifle_stanag()
	var signal_tracker = [false]
	weapon.incompatible_magazine.connect(func(): signal_tracker[0] = true)
	
	var equipped = weapon.equip_magazine(wrong_mag)
	assert_false(equipped, "Should refuse STANAG magazine in Glock pistol")
	assert_true(signal_tracker[0], "Should emit incompatible_magazine signal")

	# Now equip correct magazine
	var correct_mag = MagazineLoaderClass.create_pistol_glock(0.25, 25, 20)
	equipped = weapon.equip_magazine(correct_mag)
	assert_true(equipped, "Should accept Glock magazine in Glock pistol")
	assert_eq(weapon.current_ammo, 20)
	assert_eq(weapon.bb_mass_grams, 0.25)
	weapon.free()


func test_weapon_firing_and_dry_fire() -> void:
	var weapon = WeaponClass.new()
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	weapon.equipped_magazine = MagazineClass.new(MagazineClass.Type.MAG_PISTOL_GLOCK, 2, 1, 0.00020)
	weapon._ready()

	var dry_fired_tracker = [0]
	weapon.dry_fired.connect(func(): dry_fired_tracker[0] += 1)

	# Fire when 1 bullet remaining (without bb_scene it still consumes and logs or handles dry fire)
	# When bb_scene is null, fire() prints error and returns, so let's set a mock bb_scene
	var packed_scene = PackedScene.new()
	var dummy_node = Node3D.new()
	packed_scene.pack(dummy_node)
	dummy_node.free()
	weapon.bb_scene = packed_scene

	# Consumes 1st bullet
	weapon.fire()
	assert_eq(weapon.current_ammo, 0, "Current ammo should decrease to 0")

	# Second attempt with empty magazine -> triggers dry fire
	weapon.fire()
	assert_eq(dry_fired_tracker[0], 1, "Should emit dry_fired signal when shooting empty magazine")
	assert_eq(weapon.current_ammo, 0)
	weapon.free()


func test_hop_up_and_fire_mode() -> void:
	var weapon = WeaponClass.new()
	weapon.min_hop_up = 0.0
	weapon.max_hop_up = 2500.0
	weapon.spin_rad_s = 1000.0

	weapon.adjust_hop_up(200.0)
	assert_eq(weapon.spin_rad_s, 1200.0)

	# Clamp maximum
	weapon.adjust_hop_up(5000.0)
	assert_eq(weapon.spin_rad_s, 2500.0, "Should clamp to max_hop_up")

	# Fire mode toggle
	assert_eq(weapon.fire_mode, WeaponClass.FireMode.SEMI)
	weapon.toggle_fire_mode()
	assert_eq(weapon.fire_mode, WeaponClass.FireMode.AUTO)
	weapon.toggle_fire_mode()
	assert_eq(weapon.fire_mode, WeaponClass.FireMode.SEMI)
	weapon.free()
