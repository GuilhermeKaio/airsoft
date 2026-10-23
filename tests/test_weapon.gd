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


func test_hop_up_unhandled_input_mouse_wheel() -> void:
	var weapon = WeaponClass.new()
	weapon.min_hop_up = 0.0
	weapon.max_hop_up = 2500.0
	weapon.spin_rad_s = 1200.0
	weapon.hop_up_step = 50.0

	var signal_values: Array[float] = []
	weapon.hop_up_adjusted.connect(func(v: float): signal_values.append(v))

	# 1. Wheel up event (hopup_increase)
	var ev_up = InputEventMouseButton.new()
	ev_up.button_index = MOUSE_BUTTON_WHEEL_UP
	ev_up.pressed = true
	weapon._unhandled_input(ev_up)

	assert_eq(weapon.spin_rad_s, 1250.0, "Wheel Up in _unhandled_input should increase hop-up by step")
	assert_eq(signal_values.size(), 1, "Should emit hop_up_adjusted signal")
	assert_eq(signal_values[0], 1250.0)

	# 2. Wheel up release event (pressed = false) should NOT change hop-up
	var ev_up_release = InputEventMouseButton.new()
	ev_up_release.button_index = MOUSE_BUTTON_WHEEL_UP
	ev_up_release.pressed = false
	weapon._unhandled_input(ev_up_release)
	assert_eq(weapon.spin_rad_s, 1250.0, "Wheel release should not change hop-up")
	assert_eq(signal_values.size(), 1)

	# 3. Wheel down event (hopup_decrease)
	var ev_down = InputEventMouseButton.new()
	ev_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev_down.pressed = true
	weapon._unhandled_input(ev_down)

	assert_eq(weapon.spin_rad_s, 1200.0, "Wheel Down in _unhandled_input should decrease hop-up by step")
	assert_eq(signal_values.size(), 2)
	assert_eq(signal_values[1], 1200.0)

	# 4. Limit testing: increase to max clamp
	weapon.spin_rad_s = 2480.0
	weapon._unhandled_input(ev_up)
	assert_eq(weapon.spin_rad_s, 2500.0, "Should clamp to max_hop_up via _unhandled_input")

	# 5. Limit testing: decrease to min clamp
	weapon.spin_rad_s = 20.0
	weapon._unhandled_input(ev_down)
	assert_eq(weapon.spin_rad_s, 0.0, "Should clamp to min_hop_up via _unhandled_input")

	weapon.free()


func test_delegated_commands_api() -> void:
	var weapon = WeaponClass.new()
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	weapon.equipped_magazine = MagazineClass.new(MagazineClass.Type.MAG_PISTOL_GLOCK, 25, 20, 0.00025)
	weapon._ready()

	# 1. alternar_modo_tiro
	assert_eq(weapon.fire_mode, WeaponClass.FireMode.SEMI)
	weapon.alternar_modo_tiro()
	assert_eq(weapon.fire_mode, WeaponClass.FireMode.AUTO)
	weapon.alternar_modo_tiro()
	assert_eq(weapon.fire_mode, WeaponClass.FireMode.SEMI)

	# 2. ajustar_hop_up
	var prev_hop = weapon.spin_rad_s
	weapon.ajustar_hop_up(100.0)
	assert_eq(weapon.spin_rad_s, prev_hop + 100.0)

	# 3. atirar in SEMI mode with dummy bb scene
	var packed_scene = PackedScene.new()
	var dummy_node = Node3D.new()
	packed_scene.pack(dummy_node)
	dummy_node.free()
	weapon.bb_scene = packed_scene

	assert_eq(weapon.current_ammo, 20)
	weapon.atirar(true)
	assert_eq(weapon.current_ammo, 19, "atirar(true) should trigger fire in SEMI mode")
	weapon.atirar(false)
	assert_eq(weapon.current_ammo, 19, "atirar(false) release should not fire")

	# 4. recarregar
	weapon.recarregar()
	assert_true(weapon.is_reloading, "recarregar() should start reload process when magazine is not full")

	weapon.free()
