extends RefCounted

const BBClass = preload("res://Scripts/bb.gd")
const WeaponClass = preload("res://Scripts/weapon.gd")
const PlayerClass = preload("res://Scripts/player.gd")
const MainClass = preload("res://Scripts/main.gd")
const AmmoHUDClass = preload("res://Scripts/ammo_hud.gd")

var _failed: bool = false
var _message: String = ""
var _assertion_count: int = 0

func _reset() -> void:
	_failed = false
	_message = ""
	_assertion_count = 0
	# Ensure global state is reset to true before each test
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


## 1. BB Global Trail State and Toggle
func test_bb_global_trail_state_and_toggle() -> void:
	assert_true(BBClass.is_global_trail_enabled(), "Default global trail state should be true")

	# Instantiating a BB when enabled
	var bb_scene = load("res://Scenes/bb.tscn")
	var bb1 = bb_scene.instantiate()
	bb1._ready()
	assert_true(bb1.trail_enabled, "BB should have trail enabled by default")
	bb1.free()

	# Disabling global trail
	BBClass.set_global_trail_enabled(false)
	assert_false(BBClass.is_global_trail_enabled(), "Global trail state should be false")

	# Instantiating a BB when disabled
	var bb2 = bb_scene.instantiate()
	bb2._ready()
	assert_false(bb2.trail_enabled, "BB should have trail disabled when global state is false")
	bb2.free()

	# Toggling back to true
	var toggled_state = BBClass.toggle_global_trail_enabled()
	assert_true(toggled_state, "Toggling false should return true")
	assert_true(BBClass.is_global_trail_enabled(), "Global state should be true after toggle")


## 2. In-Flight Bullet Trail Disabling
func test_in_flight_bullet_trail_disabling() -> void:
	var bb_scene = load("res://Scenes/bb.tscn")
	var bb = bb_scene.instantiate()
	bb._ready()

	# Simulate recording trail points
	bb._record_trail_point()
	bb._record_trail_point()
	assert_eq(bb._trail_points.size(), 2, "Trail should have 2 recorded points")

	# Disable trail on bullet
	bb.set_trail_enabled(false)
	assert_false(bb.trail_enabled, "Trail should be disabled")
	assert_false(bb._trail_recording, "Trail recording should be stopped")
	assert_eq(bb._trail_points.size(), 0, "Trail points should be cleared when disabled")

	# Re-enable trail
	bb.set_trail_enabled(true)
	assert_true(bb.trail_enabled, "Trail should be enabled")
	assert_true(bb._trail_recording, "Trail recording should resume")

	bb.free()


## 3. Weapon Tracing Integration
func test_weapon_bullet_tracing_integration() -> void:
	var weapon = WeaponClass.new()
	weapon._ready()

	assert_true(weapon.is_bullet_tracing_enabled(), "Weapon bullet tracing should be enabled by default")

	# Toggle weapon tracing
	var new_state = weapon.toggle_bullet_tracing()
	assert_false(new_state, "Toggling should return false")
	assert_false(weapon.is_bullet_tracing_enabled())

	weapon.set_bullet_tracing(true)
	assert_true(weapon.is_bullet_tracing_enabled())

	weapon.free()


## 4. Player Tracing API and Signals
func test_player_tracing_api_and_signals() -> void:
	var player = PlayerClass.new()
	var signal_received = [false, false]

	player.bullet_tracing_toggled.connect(func(enabled: bool):
		signal_received[0] = true
		signal_received[1] = enabled
	)

	assert_true(player.is_bullet_tracing_enabled(), "Player tracing initially enabled")

	# Toggle via player
	var state = player.toggle_bullet_tracing()
	assert_false(state, "Player toggle should return false")
	assert_false(player.is_bullet_tracing_enabled())
	assert_false(BBClass.is_global_trail_enabled(), "BB global state should sync to false")
	assert_true(signal_received[0], "bullet_tracing_toggled signal should have fired")
	assert_false(signal_received[1], "Signal value should be false")

	# Toggle again
	signal_received[0] = false
	state = player.toggle_bullet_tracing()
	assert_true(state, "Player toggle should return true")
	assert_true(player.is_bullet_tracing_enabled())
	assert_true(BBClass.is_global_trail_enabled(), "BB global state should sync to true")
	assert_true(signal_received[0])
	assert_true(signal_received[1])

	player.free()


## 5. Player Shortcut Ctrl + T Input Handling
func test_player_shortcut_ctrl_t_input() -> void:
	var player = PlayerClass.new()
	assert_true(player.is_bullet_tracing_enabled())

	# Create Ctrl + T key event
	var ev = InputEventKey.new()
	ev.keycode = KEY_T
	ev.pressed = true
	ev.echo = false
	ev.ctrl_pressed = true

	# First press: disables tracing
	player._unhandled_input(ev)
	assert_false(player.is_bullet_tracing_enabled(), "Ctrl + T should disable bullet tracing on Player")
	assert_false(BBClass.is_global_trail_enabled(), "Global bullet tracing should be disabled")

	# Second press: re-enables tracing
	player._unhandled_input(ev)
	assert_true(player.is_bullet_tracing_enabled(), "Ctrl + T second press should re-enable bullet tracing")
	assert_true(BBClass.is_global_trail_enabled(), "Global bullet tracing should be re-enabled")

	# Without Ctrl, T key should not toggle tracing
	var ev_no_ctrl = InputEventKey.new()
	ev_no_ctrl.keycode = KEY_T
	ev_no_ctrl.pressed = true
	ev_no_ctrl.echo = false
	ev_no_ctrl.ctrl_pressed = false

	player._unhandled_input(ev_no_ctrl)
	assert_true(player.is_bullet_tracing_enabled(), "Plain T without Ctrl should not toggle tracing")

	player.free()


## 6. Main Node Shortcut Ctrl + T Input Handling
func test_main_shortcut_ctrl_t_input() -> void:
	var main = MainClass.new()
	var player = PlayerClass.new()
	player.name = "Player"
	main.add_child(player)

	assert_true(player.is_bullet_tracing_enabled())

	var ev = InputEventKey.new()
	ev.keycode = KEY_T
	ev.pressed = true
	ev.echo = false
	ev.ctrl_pressed = true

	main._input(ev)
	assert_false(player.is_bullet_tracing_enabled(), "Main _input with Ctrl+T should toggle player bullet tracing")

	main._input(ev)
	assert_true(player.is_bullet_tracing_enabled(), "Main _input second Ctrl+T should toggle back")

	player.free()
	main.free()


## 7. HUD Notification on Bullet Tracing Toggled
func test_hud_notification_on_tracing_toggled() -> void:
	var player = PlayerClass.new()
	var hud = AmmoHUDClass.new()
	hud.player = player
	hud._ready()

	# Emit toggle false
	player.toggle_bullet_tracing()
	assert_true(hud._notification_text.contains("DESATIVADO"), "HUD should notify TRACING: DESATIVADO")

	# Emit toggle true
	player.toggle_bullet_tracing()
	assert_true(hud._notification_text.contains("ATIVADO"), "HUD should notify TRACING: ATIVADO")

	hud.free()
	player.free()
