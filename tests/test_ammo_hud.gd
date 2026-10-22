extends RefCounted

const AmmoHUDClass = preload("res://Scripts/ammo_hud.gd")
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


func test_hud_initialization_with_weapon() -> void:
	var weapon = WeaponClass.new()
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	weapon.spin_rad_s = 1200.0
	weapon._ready()

	var hud = AmmoHUDClass.new()
	hud.setup(weapon)

	assert_eq(hud.current_ammo, 25, "Initial ammo should be 25")
	assert_eq(hud.magazine_capacity, 25, "Initial capacity should be 25")
	assert_eq(hud.bb_mass_grams, 0.20, "Initial BB mass should be 0.20g")
	assert_eq(hud.fire_mode, "SEMI", "Initial fire mode should be SEMI")
	assert_eq(hud.hop_up, 1200.0, "Initial hop up should be 1200.0")

	assert_true("SEMI" in hud.text, "Text should contain SEMI")
	assert_true("25 / 25" in hud.text, "Text should contain 25 / 25")
	assert_true("0.20g" in hud.text, "Text should contain 0.20g")
	assert_true("Hop-up: 1200" in hud.text, "Text should contain Hop-up: 1200")

	hud.free()
	weapon.free()


func test_reactive_signals_update() -> void:
	var weapon = WeaponClass.new()
	weapon._ready()

	var hud = AmmoHUDClass.new()
	hud.setup(weapon)

	# 1. Test reactive ammo signal
	weapon.ammo_changed.emit(18, 25)
	assert_eq(hud.current_ammo, 18)
	assert_true("18 / 25" in hud.text)

	# 2. Test reactive fire mode signal
	weapon.fire_mode_changed.emit("AUTO")
	assert_eq(hud.fire_mode, "AUTO")
	assert_true("AUTO" in hud.text)

	# 3. Test reactive hop-up signal
	weapon.hop_up_adjusted.emit(1850.0)
	assert_eq(hud.hop_up, 1850.0)
	assert_true("Hop-up: 1850" in hud.text)

	hud.free()
	weapon.free()


func test_no_polling_in_process() -> void:
	var weapon = WeaponClass.new()
	weapon._ready()

	var hud = AmmoHUDClass.new()
	hud.setup(weapon)

	assert_eq(hud.current_ammo, 25)
	assert_true("25 / 25" in hud.text)

	# Mutate weapon internal value without emitting signal
	weapon.equipped_magazine.current_ammo = 10

	# Call _process multiple times
	hud._process(0.016)
	hud._process(0.016)

	# HUD must NOT have polled or changed text!
	assert_eq(hud.current_ammo, 25, "HUD must not update state by polling in _process")
	assert_true("25 / 25" in hud.text, "HUD text must remain unchanged until signal is emitted")

	# Now emit signal reactively
	weapon.ammo_changed.emit(10, 25)
	assert_eq(hud.current_ammo, 10, "HUD must update when signal is emitted")
	assert_true("10 / 25" in hud.text, "HUD text must update when signal is emitted")

	hud.free()
	weapon.free()


func test_reactive_magazine_change() -> void:
	var weapon = WeaponClass.new()
	weapon._ready()

	var hud = AmmoHUDClass.new()
	hud.setup(weapon)

	var heavy_mag = MagazineLoaderClass.create_pistol_glock(0.30, 25, 22)
	weapon.equip_magazine(heavy_mag)

	assert_eq(hud.current_ammo, 22)
	assert_eq(hud.bb_mass_grams, 0.30)
	assert_true("22 / 25" in hud.text)
	assert_true("0.30g" in hud.text)

	hud.free()
	weapon.free()


func test_temporary_notifications() -> void:
	var weapon = WeaponClass.new()
	weapon._ready()

	var hud = AmmoHUDClass.new()
	hud.setup(weapon)

	# Dry fire should NOT show "SEM MUNIÇÃO"
	weapon.dry_fired.emit()
	assert_false("SEM MUNIÇÃO" in hud.text, "Dry fire notification should not appear in HUD")

	weapon.incompatible_magazine.emit()
	assert_true("CARREGADOR INCOMPATÍVEL" in hud.text, "Incompatible magazine notification should appear in HUD")

	hud.free()
	weapon.free()
