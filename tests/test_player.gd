extends RefCounted

const PlayerClass = preload("res://Scripts/player.gd")
const WeaponClass = preload("res://Scripts/weapon.gd")

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

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if abs(actual - expected) > tolerance:
		_failed = true
		_message = msg if msg != "" else ("Expected ~%f, got %f (diff: %f > %f)" % [expected, actual, abs(actual - expected), tolerance])


class MockWeapon extends Node:
	var atirar_calls: Array = []
	var alternar_modo_calls: int = 0
	var recarregar_calls: int = 0
	var hop_up_calls: Array = []
	var hop_up_step: float = 50.0

	func atirar(pressionado: bool) -> void:
		atirar_calls.append(pressionado)

	func alternar_modo_tiro() -> void:
		alternar_modo_calls += 1

	func recarregar() -> void:
		recarregar_calls += 1

	func ajustar_hop_up(delta: float) -> void:
		hop_up_calls.append(delta)


func test_player_weapon_reference() -> void:
	var player = PlayerClass.new()
	var mock = MockWeapon.new()

	assert_true(player.get_weapon() == null, "Weapon should initially be null before tree or assignment")
	player.set_weapon(mock)
	assert_eq(player.get_weapon(), mock, "Player should return assigned weapon")

	mock.free()
	player.free()


func test_delegation_atirar() -> void:
	var player = PlayerClass.new()
	var mock = MockWeapon.new()
	player.set_weapon(mock)

	player.atirar(true)
	player.atirar(false)

	assert_eq(mock.atirar_calls.size(), 2, "Should have received 2 trigger calls")
	assert_eq(mock.atirar_calls[0], true, "First call should be pressed=true")
	assert_eq(mock.atirar_calls[1], false, "Second call should be pressed=false")

	mock.free()
	player.free()


func test_delegation_alternar_modo_tiro() -> void:
	var player = PlayerClass.new()
	var mock = MockWeapon.new()
	player.set_weapon(mock)

	player.alternar_modo_tiro()
	player.alternar_modo_tiro()

	assert_eq(mock.alternar_modo_calls, 2, "Should delegate alternar_modo_tiro calls to weapon")

	mock.free()
	player.free()


func test_delegation_recarregar() -> void:
	var player = PlayerClass.new()
	var mock = MockWeapon.new()
	player.set_weapon(mock)

	player.recarregar()

	assert_eq(mock.recarregar_calls, 1, "Should delegate recarregar call to weapon")

	mock.free()
	player.free()


func test_delegation_ajustar_hop_up() -> void:
	var player = PlayerClass.new()
	var mock = MockWeapon.new()
	player.set_weapon(mock)

	player.ajustar_hop_up(50.0)
	player.ajustar_hop_up(-50.0)

	assert_eq(mock.hop_up_calls.size(), 2, "Should delegate ajustar_hop_up")
	assert_eq(mock.hop_up_calls[0], 50.0)
	assert_eq(mock.hop_up_calls[1], -50.0)

	mock.free()
	player.free()


func test_unhandled_input_delegation() -> void:
	var player = PlayerClass.new()
	var mock = MockWeapon.new()
	mock.hop_up_step = 75.0
	player.set_weapon(mock)

	# 1. Fire press event
	var ev_fire_press = InputEventMouseButton.new()
	ev_fire_press.button_index = MOUSE_BUTTON_LEFT
	ev_fire_press.pressed = true
	player._unhandled_input(ev_fire_press)

	assert_eq(mock.atirar_calls.size(), 1)
	assert_eq(mock.atirar_calls[0], true)

	# 2. Fire release event
	var ev_fire_release = InputEventMouseButton.new()
	ev_fire_release.button_index = MOUSE_BUTTON_LEFT
	ev_fire_release.pressed = false
	player._unhandled_input(ev_fire_release)

	assert_eq(mock.atirar_calls.size(), 2)
	assert_eq(mock.atirar_calls[1], false)

	# 3. Toggle fire mode
	var ev_mode = InputEventAction.new()
	ev_mode.action = "toggle_fire_mode"
	ev_mode.pressed = true
	player._unhandled_input(ev_mode)
	assert_eq(mock.alternar_modo_calls, 1)

	# 4. Reload
	var ev_reload = InputEventAction.new()
	ev_reload.action = "reload"
	ev_reload.pressed = true
	player._unhandled_input(ev_reload)
	assert_eq(mock.recarregar_calls, 1)

	# 5. Hop-up increase via mouse wheel up
	var ev_wheel_up = InputEventMouseButton.new()
	ev_wheel_up.button_index = MOUSE_BUTTON_WHEEL_UP
	ev_wheel_up.pressed = true
	player._unhandled_input(ev_wheel_up)
	assert_eq(mock.hop_up_calls.size(), 1)
	assert_eq(mock.hop_up_calls[0], 75.0, "Should use weapon's hop_up_step")

	# 6. Hop-up decrease via mouse wheel down
	var ev_wheel_down = InputEventMouseButton.new()
	ev_wheel_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	ev_wheel_down.pressed = true
	player._unhandled_input(ev_wheel_down)
	assert_eq(mock.hop_up_calls.size(), 2)
	assert_eq(mock.hop_up_calls[1], -75.0)

	# 7. Wheel release should not trigger hop-up
	var ev_wheel_release = InputEventMouseButton.new()
	ev_wheel_release.button_index = MOUSE_BUTTON_WHEEL_UP
	ev_wheel_release.pressed = false
	player._unhandled_input(ev_wheel_release)
	assert_eq(mock.hop_up_calls.size(), 2)

	mock.free()
	player.free()


func test_player_and_real_weapon_integration() -> void:
	var player = PlayerClass.new()
	var weapon = WeaponClass.new()
	weapon._ready()
	player.set_weapon(weapon)

	# Test fire mode delegation to real weapon
	assert_eq(weapon.fire_mode, WeaponClass.FireMode.SEMI)
	player.alternar_modo_tiro()
	assert_eq(weapon.fire_mode, WeaponClass.FireMode.AUTO)

	# Test hop-up delegation to real weapon
	var initial_hop = weapon.spin_rad_s
	player.ajustar_hop_up(weapon.hop_up_step)
	assert_eq(weapon.spin_rad_s, initial_hop + weapon.hop_up_step)

	# Test safe execution when weapon is null
	player.set_weapon(null)
	player.atirar(true)
	player.alternar_modo_tiro()
	player.recarregar()
	player.ajustar_hop_up(50.0)

	weapon.free()
	player.free()


func test_player_sensitivity_and_disk_persistence() -> void:
	# Ensure clean state for default sensitivity check
	var dir = DirAccess.open("user://")
	if dir and dir.file_exists("settings.cfg"):
		dir.remove("settings.cfg")

	var player = PlayerClass.new()
	var cam = preload("res://Scripts/fps_camera_look.gd").new()
	cam.name = "Camera3"
	player.add_child(cam)
	player._ready()
	cam._ready()

	assert_almost_eq(player.get_sensitivity(), 0.40, 0.001, "Default player sensitivity is 0.40")

	# Setting player sensitivity updates camera and saves to disk
	player.set_sensitivity(0.654, true)
	assert_almost_eq(player.get_sensitivity(), 0.654, 0.001, "Player sensitivity updated to 0.654")
	assert_almost_eq(cam.valorant_sensitivity, 0.654, 0.001, "Camera sensitivity synchronized to 0.654")

	# Verify disk file
	var config := ConfigFile.new()
	var err := config.load("user://settings.cfg")
	assert_eq(err, OK, "settings.cfg exists and loaded")
	var saved_sens = config.get_value("input", "sensitivity", -1.0)
	assert_almost_eq(float(saved_sens), 0.654, 0.001, "Saved sensitivity on disk matches 0.654")

	# Verify new player instance auto-loads saved sensitivity from disk
	var player2 = PlayerClass.new()
	var cam2 = preload("res://Scripts/fps_camera_look.gd").new()
	cam2.name = "Camera3"
	player2.add_child(cam2)
	player2._ready()
	cam2._ready()

	assert_almost_eq(player2.get_sensitivity(), 0.654, 0.001, "New player instance loads sensitivity 0.654 from disk")
	assert_almost_eq(cam2.valorant_sensitivity, 0.654, 0.001, "New camera instance loads sensitivity 0.654 from disk")

	# Reset back to default
	player2.set_sensitivity(0.40, true)

	player.free()
	player2.free()
