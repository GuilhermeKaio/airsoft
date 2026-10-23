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

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.05, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if abs(actual - expected) > tolerance:
		_failed = true
		_message = msg if msg != "" else ("Expected ~%f, got %f (diff: %f > %f)" % [expected, actual, abs(actual - expected), tolerance])


## 1. Shotgun (SRS Seção 4 & 4.1.1)
func test_shotgun_specs_and_consumption() -> void:
	var shotgun = WeaponClass.new()
	shotgun.configure_weapon_preset(WeaponClass.WeaponModel.SHOTGUN)
	shotgun._ready()

	assert_eq(shotgun.compatible_magazine_type, MagazineClass.Type.MAG_SHOTGUN_SHELL)
	assert_eq(shotgun.projectiles_per_shot, 3, "Shotgun should shoot 3 BBs per shot")
	assert_almost_eq(shotgun.energy_joules, 1.1, 0.05, "Shotgun energy should be ~1.1J")
	assert_eq(shotgun.allowed_fire_modes.size(), 1)
	assert_eq(shotgun.fire_mode, WeaponClass.FireMode.SEMI)

	# Test toggling fire mode does not activate AUTO
	shotgun.toggle_fire_mode()
	assert_eq(shotgun.fire_mode, WeaponClass.FireMode.SEMI, "Shotgun should strictly remain in SEMI/Pump mode")

	# Test consumption: 3 BBs per cycle (SRS 4.1.1: consumir_bbs(3))
	assert_eq(shotgun.current_ammo, 30, "Default shell magazine has 30 BBs")
	shotgun.fire()
	assert_eq(shotgun.current_ammo, 27, "Firing once must consume 3 BBs from shell")

	shotgun.fire()
	assert_eq(shotgun.current_ammo, 24, "Firing twice must consume 6 BBs total")

	# Test partial consumption when fewer than 3 BBs remain
	shotgun.equipped_magazine.current_ammo = 2
	shotgun.fire()
	assert_eq(shotgun.current_ammo, 0, "Shotgun fires remaining 2 BBs and reaches empty")

	# Test dry fire when empty
	var dry_fired = [false]
	shotgun.dry_fired.connect(func(): dry_fired[0] = true)
	shotgun.fire()
	assert_true(dry_fired[0], "Dry fire when magazine is empty")

	shotgun.free()


## 2. Rifle (SRS Seção 4 & 4.1.2)
func test_rifle_specs_and_modes() -> void:
	var rifle = WeaponClass.new()
	rifle.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)
	rifle._ready()

	assert_eq(rifle.compatible_magazine_type, MagazineClass.Type.MAG_RIFLE_STANAG)
	assert_eq(rifle.projectiles_per_shot, 1, "Rifle fires 1 BB per cycle")
	assert_almost_eq(rifle.energy_joules, 1.49, 0.05, "Rifle muzzle energy ~1.49J")
	assert_almost_eq(rifle.get_cadence_rpm(), 800.0, 5.0, "Cadence ~800 RPM")

	# Modes: SEMI and AUTO
	assert_eq(rifle.fire_mode, WeaponClass.FireMode.SEMI)
	rifle.toggle_fire_mode()
	assert_eq(rifle.fire_mode, WeaponClass.FireMode.AUTO, "Rifle toggles to AUTO")
	rifle.toggle_fire_mode()
	assert_eq(rifle.fire_mode, WeaponClass.FireMode.SEMI, "Rifle toggles back to SEMI")

	# Consumption: 1 BB per shot
	assert_eq(rifle.current_ammo, 30)
	rifle.fire()
	assert_eq(rifle.current_ammo, 29)

	rifle.free()


## 3. Pistol 1911 (SRS Seção 4 & 4.1.3)
func test_pistol_1911_specs_and_slide_lock() -> void:
	var p1911 = WeaponClass.new()
	p1911.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_1911)
	p1911._ready()

	assert_eq(p1911.compatible_magazine_type, MagazineClass.Type.MAG_PISTOL_1911)
	assert_almost_eq(p1911.energy_joules, 0.9, 0.05, "Pistol 1911 muzzle energy ~0.9J")
	assert_eq(p1911.projectiles_per_shot, 1)

	# Modes: strictly SEMI
	assert_eq(p1911.fire_mode, WeaponClass.FireMode.SEMI)
	p1911.toggle_fire_mode()
	assert_eq(p1911.fire_mode, WeaponClass.FireMode.SEMI, "Pistol 1911 is strictly SEMI")

	# Slide lock open when magazine empties (SRS 4.1.3)
	assert_false(p1911.is_slide_locked_open, "Slide initially closed")
	p1911.equipped_magazine.current_ammo = 1
	p1911.fire()
	assert_eq(p1911.current_ammo, 0)
	assert_true(p1911.is_slide_locked_open, "Slide locks open when last BB is fired")

	# Reload resets slide lock open
	p1911._finish_reload()
	assert_false(p1911.is_slide_locked_open, "Slide lock released upon reload")
	assert_eq(p1911.current_ammo, 15, "1911 magazine refilled to 15 BBs")

	p1911.free()


## 4. Pistol Glock (SRS Seção 4 & 4.1.4)
func test_pistol_glock_specs_and_rpm_switch() -> void:
	var glock = WeaponClass.new()
	glock.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_GLOCK)
	glock._ready()

	assert_eq(glock.compatible_magazine_type, MagazineClass.Type.MAG_PISTOL_GLOCK)
	assert_almost_eq(glock.energy_joules, 1.0, 0.05, "Glock muzzle energy ~1.0J")
	assert_eq(glock.fire_mode, WeaponClass.FireMode.SEMI)
	assert_almost_eq(glock.get_cadence_rpm(), 400.0, 5.0, "Glock semi cadence ~400 RPM")

	# Glock supports AUTO with higher cadence (Glock 18C SRS 4.1.4)
	glock.toggle_fire_mode()
	assert_eq(glock.fire_mode, WeaponClass.FireMode.AUTO)
	assert_almost_eq(glock.get_cadence_rpm(), 1100.0, 10.0, "Glock auto cadence ~1100 RPM")

	glock.toggle_fire_mode()
	assert_eq(glock.fire_mode, WeaponClass.FireMode.SEMI)
	assert_almost_eq(glock.get_cadence_rpm(), 400.0, 5.0)

	glock.free()


## 5. Visual Prefabs instantiation from Assets
func test_weapon_prefabs_from_assets() -> void:
	var models = [
		WeaponClass.WeaponModel.SHOTGUN,
		WeaponClass.WeaponModel.RIFLE,
		WeaponClass.WeaponModel.PISTOL_1911,
		WeaponClass.WeaponModel.PISTOL_GLOCK
	]

	for m in models:
		var w = WeaponClass.new()
		w.configure_weapon_preset(m)
		w._ready()
		assert_true(w.weapon_instance != null, "Weapon instance instantiated for %s" % w.get_weapon_model_name())
		assert_true(w.mesh != null, "Mesh found for %s" % w.get_weapon_model_name())
		assert_true(w.muzzle != null, "Muzzle found for %s" % w.get_weapon_model_name())
		w.free()
