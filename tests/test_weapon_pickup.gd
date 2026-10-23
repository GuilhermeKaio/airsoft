extends RefCounted

const PlayerClass = preload("res://Scripts/player.gd")
const WeaponClass = preload("res://Scripts/weapon.gd")
const MagazineClass = preload("res://Scripts/magazine.gd")
const MagazineLoaderClass = preload("res://Scripts/magazine_loader.gd")
const WeaponPickupClass = preload("res://Scripts/weapon_pickup.gd")
const AmmoHUDClass = preload("res://Scripts/ammo_hud.gd")

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

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.05, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if abs(actual - expected) > tolerance:
		_failed = true
		_message = msg if msg != "" else ("Expected ~%f, got %f (diff: %f > %f)" % [expected, actual, abs(actual - expected), tolerance])


func test_weapon_pickup_initialization() -> void:
	var pickup = WeaponPickupClass.new()
	pickup.setup_weapon(WeaponClass.WeaponModel.SHOTGUN)
	pickup._ready()

	assert_eq(pickup.weapon_model, WeaponClass.WeaponModel.SHOTGUN)
	assert_true(pickup.magazine != null, "Default magazine created for Shotgun")
	assert_eq(pickup.magazine.type, MagazineClass.Type.MAG_SHOTGUN_SHELL)
	assert_eq(pickup.magazine.current_ammo, 30)
	assert_false(pickup.auto_pickup, "Weapon pickup should default to auto_pickup = false (requires E)")

	assert_true(pickup.label != null, "Label3D present")
	assert_true("Shotgun" in pickup.label.text, "Label displays Shotgun")
	assert_true("[E]" in pickup.label.text, "Label prompts key [E]")

	pickup.free()


func test_swap_weapon_with_e_key() -> void:
	var player = PlayerClass.new()
	var rifle = WeaponClass.new()
	rifle.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)
	player.equip_weapon_in_slot(rifle, 1)
	player.select_slot(1, true)
	assert_eq(player.get_weapon().weapon_model, WeaponClass.WeaponModel.RIFLE)

	var pickup = WeaponPickupClass.new()
	pickup.setup_weapon(WeaponClass.WeaponModel.SHOTGUN)
	pickup.drop_previous_on_swap = false # Don't spawn into tree for unit test
	pickup._ready()

	# Simulate pressing E when player is within pickup range
	pickup._on_body_entered(player)
	var ev_e = InputEventKey.new()
	ev_e.keycode = KEY_E
	ev_e.pressed = true
	ev_e.echo = false
	pickup._unhandled_input(ev_e)

	# Player's active weapon in slot 1 should now be Shotgun!
	assert_eq(player.get_weapon().weapon_model, WeaponClass.WeaponModel.SHOTGUN, "Active weapon should now be Shotgun")
	assert_eq(player.get_weapon().compatible_magazine_type, MagazineClass.Type.MAG_SHOTGUN_SHELL)

	player.free()
	pickup.free()


func test_weapon_drop_preserves_state() -> void:
	var root = Node3D.new()
	var player = PlayerClass.new()
	root.add_child(player)

	# Rifle with 18 BBs remaining (fired 12 BBs)
	var rifle = WeaponClass.new()
	rifle.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)
	rifle._ready()
	rifle.equipped_magazine.current_ammo = 18
	rifle.spin_rad_s = 1450.0

	player.equip_weapon_in_slot(rifle, 1)
	player.select_slot(1, true)

	var shotgun_pickup = WeaponPickupClass.new()
	shotgun_pickup.setup_weapon(WeaponClass.WeaponModel.SHOTGUN)
	shotgun_pickup.drop_previous_on_swap = true
	root.add_child(shotgun_pickup)
	shotgun_pickup._ready()

	# Pickup Shotgun and drop Rifle
	var picked = shotgun_pickup.try_pickup(player)
	assert_true(picked, "Shotgun picked up")
	assert_eq(player.get_weapon().weapon_model, WeaponClass.WeaponModel.SHOTGUN)

	# Find dropped pickup in root
	var dropped_pickup: Node = null
	for child in root.get_children():
		if child is WeaponPickupClass and child != shotgun_pickup:
			dropped_pickup = child
			break

	assert_true(dropped_pickup != null, "Dropped weapon pickup spawned in world")
	assert_eq(dropped_pickup.weapon_model, WeaponClass.WeaponModel.RIFLE, "Dropped pickup is Rifle")
	assert_eq(dropped_pickup.magazine.current_ammo, 18, "Remaining 18 BBs preserved in dropped weapon")
	assert_almost_eq(dropped_pickup.spin_rad_s, 1450.0, 1.0, "Hop-up preserved in dropped weapon")

	root.free()


func test_pickup_in_secondary_slot() -> void:
	var player = PlayerClass.new()
	var rifle = WeaponClass.new()
	rifle.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)
	var glock = WeaponClass.new()
	glock.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_GLOCK)

	player.equip_weapon_in_slot(rifle, 1)
	player.equip_weapon_in_slot(glock, 2)
	player.select_slot(2, true) # Secondary slot active

	assert_eq(player.get_weapon().weapon_model, WeaponClass.WeaponModel.PISTOL_GLOCK)

	var p1911_pickup = WeaponPickupClass.new()
	p1911_pickup.setup_weapon(WeaponClass.WeaponModel.PISTOL_1911)
	p1911_pickup.drop_previous_on_swap = false

	# Pick up 1911 into active slot 2
	var picked = p1911_pickup.try_pickup(player)
	assert_true(picked)
	assert_eq(player.get_weapon().weapon_model, WeaponClass.WeaponModel.PISTOL_1911, "Slot 2 should now be Colt 1911")
	assert_eq(player.get_weapon_in_slot(1).weapon_model, WeaponClass.WeaponModel.RIFLE, "Slot 1 remains Rifle")

	p1911_pickup.free()
	player.free()


func test_hud_updates_on_weapon_pickup() -> void:
	var player = PlayerClass.new()
	var glock = WeaponClass.new()
	glock.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_GLOCK)
	glock._ready()

	player.equip_weapon_in_slot(glock, 1)
	player.select_slot(1, true)

	var hud = AmmoHUDClass.new()
	hud.setup(player.get_weapon())
	player.weapon_swapped.connect(hud._on_player_weapon_swapped)

	assert_true("PistolGlock" in hud.text)

	# Swap to Rifle
	var rifle_pickup = WeaponPickupClass.new()
	rifle_pickup.setup_weapon(WeaponClass.WeaponModel.RIFLE)
	rifle_pickup.drop_previous_on_swap = false
	rifle_pickup.try_pickup(player)

	assert_true("Rifle" in hud.text, "HUD displays Rifle after pickup")

	hud.free()
	rifle_pickup.free()
	player.free()
