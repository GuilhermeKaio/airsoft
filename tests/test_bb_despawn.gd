extends RefCounted

const BBClass = preload("res://Scripts/bb.gd")
const WeaponClass = preload("res://Scripts/weapon.gd")
const MagazineClass = preload("res://Scripts/magazine.gd")
const AmmoHUDClass = preload("res://Scripts/ammo_hud.gd")

var _failed: bool = false
var _message: String = ""
var _assertion_count: int = 0

func _reset() -> void:
	_failed = false
	_message = ""
	_assertion_count = 0
	BBClass.set_global_trail_enabled(true)

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

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if abs(actual - expected) > tolerance:
		_failed = true
		_message = msg if msg != "" else ("Expected ~%f, got %f" % [expected, actual])


## 1. Flight Time Limit Configuration & Defaults (SRS 3.6)
func test_bb_flight_time_limit_configuration() -> void:
	var bb_scene = load("res://Scenes/bb.tscn")
	var bb = bb_scene.instantiate()
	bb._ready()

	assert_eq(bb.max_flight_time, 10.0, "Default max flight time should be 10.0 seconds")
	assert_eq(bb.post_collision_flight_time, 5.0, "Default post-collision flight time should be 5.0 seconds")
	assert_eq(bb.flight_time_limit, 10.0, "Alias flight_time_limit should match max_flight_time")
	assert_eq(bb.tempo_limite_voo, 10.0, "Alias tempo_limite_voo should match max_flight_time")

	bb.max_flight_time = 8.0
	assert_eq(bb.max_flight_time, 8.0)
	assert_eq(bb.flight_time_limit, 8.0)
	assert_eq(bb.tempo_limite_voo, 8.0)

	bb.flight_time_limit = 12.0
	assert_eq(bb.max_flight_time, 12.0)

	bb.tempo_limite_voo = 10.0
	assert_eq(bb.max_flight_time, 10.0)

	bb.free()


## 2. Flight Time Accumulation and Despawn Timeout (10s Default)
func test_bb_flight_time_accumulation_and_despawn() -> void:
	var bb = BBClass.new()
	bb._ready()

	var despawn_signal_fired = [false]
	bb.despawned.connect(func(): despawn_signal_fired[0] = true)

	assert_eq(bb.max_flight_time, 10.0)
	assert_eq(bb.current_flight_time, 0.0)
	assert_false(bb.is_despawned())

	# Advance 6.0s (within 10.0s limit)
	bb.advance_flight_time(6.0)
	assert_almost_eq(bb.current_flight_time, 6.0)
	assert_almost_eq(bb.get_flight_time(), 6.0)
	assert_almost_eq(bb.get_remaining_flight_time(), 4.0)
	assert_false(bb.is_despawned(), "BB should not despawn at 6.0s before 10.0s limit")
	assert_false(despawn_signal_fired[0])

	# Advance another 4.1s (total 10.1s >= 10.0s)
	bb.advance_flight_time(4.1)
	assert_true(bb.is_despawned(), "BB should despawn when reaching 10s flight time limit")
	assert_true(bb.is_queued_for_deletion(), "BB should be queued for deletion")
	assert_true(despawn_signal_fired[0], "despawned signal should be emitted")


## 3. Physics Process Triggers Flight Timeout Despawn
func test_bb_physics_process_triggers_despawn() -> void:
	var bb = BBClass.new()
	bb.max_flight_time = 1.0
	bb._ready()

	# 0.6 seconds in physics
	bb._physics_process(0.6)
	assert_false(bb.is_despawned(), "BB should still be active at 0.6s")

	# Another 0.5 seconds -> total 1.1s >= 1.0s
	bb._physics_process(0.5)
	assert_true(bb.is_despawned(), "BB should despawn via _physics_process after 1.0s timeout")
	assert_true(bb.is_queued_for_deletion())


## 4. Collision Sets Limit to 5s and Despawns (SRS 3.6)
func test_bb_collision_despawn() -> void:
	var bb = BBClass.new()
	bb._ready()

	assert_eq(bb.max_flight_time, 10.0, "Initially 10s timeout before collision")

	# Fly for 3.0s before collision
	bb.advance_flight_time(3.0)
	assert_almost_eq(bb.current_flight_time, 3.0)
	assert_false(bb.is_despawned())

	var despawn_signal_fired = [false]
	bb.despawned.connect(func(): despawn_signal_fired[0] = true)

	var obstacle = Node3D.new()

	# Collision occurs: touches ground or body for the first time
	bb._on_body_entered(obstacle)
	assert_true(bb.hit_ground, "hit_ground should be set upon collision")
	assert_false(bb._trail_recording, "trail recording should stop upon collision")
	assert_eq(bb.max_flight_time, 5.0, "max_flight_time should be set to 5.0 upon first collision")
	assert_eq(bb.current_flight_time, 0.0, "current_flight_time should be reset to 0.0 to countdown 5s")
	assert_almost_eq(bb.get_remaining_flight_time(), 5.0)
	assert_false(bb.is_despawned(), "BB should not despawn immediately on collision, but have 5s")

	# Advance 3.0s on the ground (under 5.0s)
	bb.advance_flight_time(3.0)
	assert_false(bb.is_despawned(), "BB should still exist at 3.0s after collision")
	assert_false(despawn_signal_fired[0])

	# Advance another 2.1s (total 5.1s >= 5.0s after collision)
	bb.advance_flight_time(2.1)
	assert_true(bb.is_despawned(), "BB should despawn after 5s post-collision timeout")
	assert_true(bb.is_queued_for_deletion(), "BB should be queued for deletion")
	assert_true(despawn_signal_fired[0], "despawned signal should fire")

	obstacle.free()


## 5. Trail Cleanup upon Despawn
func test_bb_trail_cleanup_upon_despawn() -> void:
	var bb = BBClass.new()
	bb._ready()
	bb.set_trail_enabled(true)

	bb._record_trail_point()
	bb._record_trail_point()
	assert_eq(bb._trail_points.size(), 2)

	bb.despawn()
	assert_false(bb.trail_enabled, "Trail should be disabled on despawn")
	assert_false(bb._trail_recording, "Trail recording should be stopped on despawn")
	assert_eq(bb._trail_points.size(), 0, "Trail points should be cleared on despawn")
	assert_true(bb.is_despawned())


## 6. Flight Time Reset and Helpers
func test_bb_flight_time_helpers() -> void:
	var bb = BBClass.new()
	bb.max_flight_time = 5.0
	bb._ready()

	bb.advance_flight_time(2.0)
	assert_almost_eq(bb.get_flight_time(), 2.0)
	assert_almost_eq(bb.get_remaining_flight_time(), 3.0)

	bb.reset_flight_time()
	assert_almost_eq(bb.get_flight_time(), 0.0)
	assert_almost_eq(bb.get_remaining_flight_time(), 5.0)

	bb.free()


## 7. Dry Fire HUD Notification Integration (SRS 3.3.1 e 3.5.2)
func test_dry_fire_hud_notification_integration() -> void:
	var weapon = WeaponClass.new()
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	weapon.equipped_magazine = MagazineClass.new(MagazineClass.Type.MAG_PISTOL_GLOCK, 10, 0, 0.00020)
	weapon._ready()

	var hud = AmmoHUDClass.new()
	hud.setup(weapon)

	# Before firing, no temporary notification
	assert_false("SEM MUNIÇÃO" in hud.text)

	# Firing empty weapon triggers dry fire
	weapon.fire()
	assert_true("SEM MUNIÇÃO" in hud.text, "HUD should display SEM MUNIÇÃO when dry fire occurs")
	assert_false(weapon.is_reloading, "Weapon should NOT automatically start reload on fire() when empty")

	# Second dry fire via atirar command
	weapon.atirar(true)
	assert_true("SEM MUNIÇÃO" in hud.text, "HUD should display SEM MUNIÇÃO when atirar triggers dry fire")
	assert_false(weapon.is_reloading, "Weapon should NOT automatically start reload on atirar() when empty")

	# Manual reload only
	weapon.recarregar()
	assert_true(weapon.is_reloading, "Manual recarregar() should start reload process")

	hud.free()
	weapon.free()
