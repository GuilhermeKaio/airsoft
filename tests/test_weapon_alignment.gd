extends RefCounted

const WeaponClass = preload("res://Scripts/weapon.gd")
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

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.01, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if abs(actual - expected) > tolerance:
		_failed = true
		_message = msg if msg != "" else "Expected ~%.3f, got %.3f" % [expected, actual]


func test_first_person_alignment_with_camera() -> void:
	var root = Node3D.new()
	var cam = Camera3D.new()
	cam.name = "Camera3"
	root.add_child(cam)

	var weapon = WeaponClass.new()
	root.add_child(weapon)
	weapon._ready()

	# Simulate camera looking at different yaw and pitch angles
	cam.rotation = Vector3(deg_to_rad(-30.0), deg_to_rad(45.0), 0.0)
	weapon._process(0.016)

	# 1. Weapon basis must match camera basis
	var cam_forward: Vector3 = -cam.transform.basis.z.normalized()
	var weapon_forward: Vector3 = -weapon.transform.basis.z.normalized()
	assert_almost_eq(weapon_forward.dot(cam_forward), 1.0, 0.001, "Weapon forward must align with camera forward")

	# 2. Weapon roll must remain 0 (no crooked weapon)
	var euler: Vector3 = weapon.transform.basis.get_euler()
	assert_almost_eq(euler.z, 0.0, 0.001, "Weapon roll angle must be 0")

	# 3. Muzzle direction must shoot directly forward
	if weapon.muzzle:
		var muzzle_local_fwd: Vector3 = -weapon.muzzle.transform.basis.z.normalized()
		var muzzle_dir: Vector3 = (weapon.transform.basis * muzzle_local_fwd).normalized()
		assert_almost_eq(muzzle_dir.dot(cam_forward), 1.0, 0.001, "Muzzle fire direction must align with camera gaze")

	root.free()


func test_all_prefabs_mesh_and_muzzle_zero_tilt() -> void:
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

		assert_true(w.mesh != null, "Mesh exists for %s" % w.get_weapon_model_name())
		assert_true(w.muzzle != null, "Muzzle exists for %s" % w.get_weapon_model_name())

		# Mesh rotation relative to weapon root should have 0 roll and 0 yaw
		var mesh_rot: Vector3 = w.mesh.rotation_degrees
		assert_almost_eq(mesh_rot.x, 0.0, 0.1, "Mesh pitch is 0 for %s" % w.get_weapon_model_name())
		assert_almost_eq(mesh_rot.y, 0.0, 0.1, "Mesh yaw is 0 for %s" % w.get_weapon_model_name())
		assert_almost_eq(mesh_rot.z, 0.0, 0.1, "Mesh roll is 0 for %s" % w.get_weapon_model_name())

		# Muzzle forward vector (-basis.z) relative to weapon should point straight forward (0, 0, -1)
		var muzzle_fwd: Vector3 = -w.muzzle.transform.basis.z.normalized()
		assert_almost_eq(muzzle_fwd.x, 0.0, 0.01, "Muzzle forward X for %s" % w.get_weapon_model_name())
		assert_almost_eq(muzzle_fwd.y, 0.0, 0.01, "Muzzle forward Y for %s" % w.get_weapon_model_name())
		assert_almost_eq(muzzle_fwd.z, -1.0, 0.01, "Muzzle forward Z for %s" % w.get_weapon_model_name())

		w.free()


func test_ammo_hud_dimensions_and_no_clipping() -> void:
	var hud = AmmoHUDClass.new()
	hud._ready()

	assert_true(hud.offset_left <= -800.0, "HUD offset_left has plenty of width")
	assert_almost_eq(hud.offset_right, -24.0, 1.0, "HUD offset_right maintains 24px right screen margin")
	assert_true(hud.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "HUD is right-aligned")

	var font_size: int = hud.get_theme_font_size("font_size")
	assert_true(font_size <= 24, "Font size scaled comfortably to fit text without clipping")

	hud.free()
