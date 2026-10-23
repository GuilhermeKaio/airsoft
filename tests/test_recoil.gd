extends RefCounted

const WeaponClass = preload("res://Scripts/weapon.gd")
const FPSCameraClass = preload("res://Scripts/fps_camera_look.gd")

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


## 1. Recoil parameters by weapon preset (SRS Adicionais Seção 3.2)
func test_recoil_weapon_presets_parameters() -> void:
	# 1. Rifle (5 balas verticais, 1.2° pitch, 0.9° yaw, 0.25s recovery)
	var rifle = WeaponClass.new()
	rifle.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)
	assert_eq(rifle.recoil_vertical_bullets, 5, "Rifle should have 5 vertical bullets")
	assert_almost_eq(rifle.recoil_vertical_pitch, 1.2, 0.01, "Rifle vertical pitch 1.2°")
	assert_almost_eq(rifle.recoil_lateral_yaw, 0.9, 0.01, "Rifle lateral yaw 0.9°")
	assert_almost_eq(rifle.recoil_recovery_time, 0.25, 0.01, "Rifle recovery time 0.25s")
	rifle.free()

	# 2. PistolGlock Auto (4 balas verticais, 1.6° pitch, 1.3° yaw, 0.20s recovery)
	var glock_auto = WeaponClass.new()
	glock_auto.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_GLOCK)
	glock_auto.fire_mode = WeaponClass.FireMode.AUTO
	glock_auto._update_glock_recoil_preset()
	assert_eq(glock_auto.recoil_vertical_bullets, 4, "Glock Auto should have 4 vertical bullets")
	assert_almost_eq(glock_auto.recoil_vertical_pitch, 1.6, 0.01, "Glock Auto vertical pitch 1.6°")
	assert_almost_eq(glock_auto.recoil_lateral_yaw, 1.3, 0.01, "Glock Auto lateral yaw 1.3°")
	assert_almost_eq(glock_auto.recoil_recovery_time, 0.20, 0.01, "Glock Auto recovery time 0.20s")
	glock_auto.free()

	# 3. PistolGlock Semi (Unitário, 0.8° pitch, 0.15° yaw, 0.15s recovery)
	var glock_semi = WeaponClass.new()
	glock_semi.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_GLOCK)
	assert_eq(glock_semi.fire_mode, WeaponClass.FireMode.SEMI)
	assert_eq(glock_semi.recoil_vertical_bullets, 1, "Glock Semi should be unitary")
	assert_almost_eq(glock_semi.recoil_vertical_pitch, 0.8, 0.01, "Glock Semi vertical pitch 0.8°")
	assert_almost_eq(glock_semi.recoil_lateral_yaw, 0.15, 0.01, "Glock Semi lateral yaw 0.15°")
	assert_almost_eq(glock_semi.recoil_recovery_time, 0.15, 0.01, "Glock Semi recovery time 0.15s")
	glock_semi.free()

	# 4. Pistol 1911 (Unitário, 2.2° pitch, 0.1° yaw, 0.22s recovery)
	var p1911 = WeaponClass.new()
	p1911.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_1911)
	assert_eq(p1911.recoil_vertical_bullets, 1, "1911 should be unitary")
	assert_almost_eq(p1911.recoil_vertical_pitch, 2.2, 0.01, "1911 vertical pitch 2.2°")
	assert_almost_eq(p1911.recoil_lateral_yaw, 0.1, 0.01, "1911 lateral yaw 0.1°")
	assert_almost_eq(p1911.recoil_recovery_time, 0.22, 0.01, "1911 recovery time 0.22s")
	p1911.free()

	# 5. Shotgun (1 ciclo 3 BBs, 3.5° pitch, 0.40s recovery)
	var shotgun = WeaponClass.new()
	shotgun.configure_weapon_preset(WeaponClass.WeaponModel.SHOTGUN)
	assert_eq(shotgun.recoil_vertical_bullets, 1, "Shotgun should be unitary cycle")
	assert_almost_eq(shotgun.recoil_vertical_pitch, 3.5, 0.01, "Shotgun vertical pitch 3.5°")
	assert_almost_eq(shotgun.recoil_recovery_time, 0.40, 0.01, "Shotgun recovery time 0.40s")
	shotgun.free()


## 2. Dynamic Spray Pattern Phases (SRS Adicionais Seção 3.1)
func test_rifle_spray_pattern_phases() -> void:
	var rifle = WeaponClass.new()
	rifle.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)

	# Fase 1 — Balas 1 a 5 (shot_index 0 to 4): elevação predominantemente vertical linear
	for shot in range(5):
		var step := rifle.get_recoil_step(shot)
		assert_almost_eq(step.y, 1.2, 0.01, "Shot %d should have vertical pitch 1.2°" % (shot + 1))
		assert_almost_eq(step.x, 0.0, 0.01, "Shot %d should have 0 lateral yaw" % (shot + 1))

	# Bala 6 (shot_index 5): Transição de elevação máxima e início de deriva lateral
	var transition_step := rifle.get_recoil_step(5)
	assert_true(transition_step.y < 1.2, "Transition vertical step should taper down")
	assert_almost_eq(transition_step.x, 0.9, 0.01, "Transition shot pulls laterally right (Yaw +0.9°)")

	# Fase 2 — Balas 7 em diante: elevação vertical estabilizada, alternando lateralmente
	var step_right := rifle.get_recoil_step(6)
	assert_almost_eq(step_right.y, 0.0, 0.01, "Pitch stabilizes in phase 2")
	assert_almost_eq(step_right.x, 0.9, 0.01, "Pulls right (+Yaw)")

	var step_left := rifle.get_recoil_step(9)
	assert_almost_eq(step_left.y, 0.0, 0.01, "Pitch stabilizes in phase 2")
	assert_almost_eq(step_left.x, -0.9, 0.01, "Alternates to left (-Yaw)")

	rifle.free()


## 3. Glock Fire Mode Switch Updates Recoil Preset
func test_glock_fire_mode_toggle_updates_recoil() -> void:
	var glock = WeaponClass.new()
	glock.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_GLOCK)
	assert_almost_eq(glock.recoil_vertical_pitch, 0.8, 0.01, "Initially semi: 0.8°")

	glock.toggle_fire_mode()
	assert_eq(glock.fire_mode, WeaponClass.FireMode.AUTO)
	assert_almost_eq(glock.recoil_vertical_pitch, 1.6, 0.01, "In AUTO mode: 1.6°")
	assert_almost_eq(glock.recoil_recovery_time, 0.20, 0.01, "In AUTO mode: 0.20s")

	glock.toggle_fire_mode()
	assert_eq(glock.fire_mode, WeaponClass.FireMode.SEMI)
	assert_almost_eq(glock.recoil_vertical_pitch, 0.8, 0.01, "Back in SEMI mode: 0.8°")
	assert_almost_eq(glock.recoil_recovery_time, 0.15, 0.01, "Back in SEMI mode: 0.15s")

	glock.free()


## 4. Recoil Recovery & Burst Continuity (SRS Adicionais Seção 3.3)
func test_recoil_recovery_and_reset_timing() -> void:
	var rifle = WeaponClass.new()
	rifle.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)

	# Simulate 3 shots
	rifle._apply_recoil()
	rifle._apply_recoil()
	rifle._apply_recoil()

	assert_eq(rifle.recoil_shot_index, 3, "Recoil counter accumulated 3 shots")
	assert_almost_eq(rifle.current_recoil_offset.y, 3.6, 0.05, "Accumulated pitch 3 * 1.2° = 3.6°")

	# Wait a small delay < recovery_time (e.g. 0.05s)
	rifle._process_recoil(0.05)
	assert_eq(rifle.recoil_shot_index, 3, "Counter preserves index if fired before full recovery")

	# Fire 4th shot: spray pattern continues at index 3 instead of restarting from 0!
	rifle._apply_recoil()
	assert_eq(rifle.recoil_shot_index, 4, "Continues spray pattern to 4th shot")

	# Now cease fire and wait full recovery time (0.25s)
	rifle._process_recoil(0.26)
	assert_eq(rifle.recoil_shot_index, 0, "Counter resets to 0 after full recovery window elapses")

	rifle.free()


## 5. Camera Look Recoil and Compensation
func test_camera_recoil_and_compensation() -> void:
	var cam = FPSCameraClass.new()
	cam.rotation = Vector3.ZERO

	# Apply recoil (+1.2° pitch, +0.9° yaw)
	cam.apply_recoil(1.2, 0.9)
	assert_almost_eq(cam.rotation.x, deg_to_rad(1.2), 0.001, "Camera pitched up")
	assert_almost_eq(cam.uncompensated_recoil.y, deg_to_rad(1.2), 0.001)
	assert_almost_eq(cam.uncompensated_recoil.x, deg_to_rad(0.9), 0.001)

	# Simulate player pulling down with mouse to compensate
	# Mouse moving down has event.relative.y > 0
	var mouse_event = InputEventMouseMotion.new()
	mouse_event.relative = Vector2(0.0, deg_to_rad(1.2) / cam.mouse_sensitivity)
	cam._is_active_camera = true
	cam._unhandled_input(mouse_event)

	# Uncompensated recoil pitch should now be 0 because player fully compensated!
	assert_almost_eq(cam.uncompensated_recoil.y, 0.0, 0.001, "Player mouse pulled down fully compensated recoil")

	# When recovery occurs, camera should NOT pull down further into the floor
	cam.recover_recoil(deg_to_rad(1.2), 0.0)
	assert_almost_eq(cam.uncompensated_recoil.y, 0.0, 0.001)

	cam.free()
