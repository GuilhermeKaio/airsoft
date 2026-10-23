extends RefCounted

const PauseScreenScene = preload("res://Scenes/pause_screen.tscn")
const PauseScreenClass = preload("res://Scripts/pause_screen.gd")
const FpsCameraClass = preload("res://Scripts/fps_camera_look.gd")

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


## 1. UI Elements existence and hierarchy in pause_screen.tscn
func test_pause_screen_ui_elements() -> void:
	var pause_instance = PauseScreenScene.instantiate()
	assert_true(pause_instance != null, "PauseScreen instantiated successfully")

	var overlay = pause_instance.get_node_or_null("PauseOverlay")
	assert_true(overlay != null, "PauseOverlay node exists")
	assert_false(overlay.visible, "PauseOverlay initially hidden")

	var slider = pause_instance.find_child("SensitivitySlider", true, false) as HSlider
	assert_true(slider != null, "SensitivitySlider (HSlider) exists")
	assert_almost_eq(slider.min_value, 0.05, 0.001, "Slider min_value is 0.05")
	assert_almost_eq(slider.max_value, 2.00, 0.001, "Slider max_value is 2.00")
	assert_almost_eq(slider.step, 0.01, 0.001, "Slider step is 0.01")

	var line_edit = pause_instance.find_child("SensitivityLineEdit", true, false) as LineEdit
	assert_true(line_edit != null, "SensitivityLineEdit (LineEdit) exists")

	var resume_btn = pause_instance.find_child("ResumeButton", true, false) as Button
	assert_true(resume_btn != null, "ResumeButton exists")

	var restart_btn = pause_instance.find_child("RestartButton", true, false) as Button
	assert_true(restart_btn != null, "RestartButton exists")

	pause_instance.free()


## 2. Two-way synchronization between HSlider and LineEdit
func test_two_way_slider_and_line_edit_sync() -> void:
	var pause_instance = PauseScreenScene.instantiate()
	pause_instance._ready()

	var slider = pause_instance.sensitivity_slider
	var line_edit = pause_instance.sensitivity_line_edit

	# Case A: Changing slider updates LineEdit
	slider.value = 0.75
	slider.value_changed.emit(0.75)
	assert_almost_eq(pause_instance.current_sensitivity, 0.75, 0.001, "Current sensitivity updated to 0.75")
	assert_eq(line_edit.text, "0.750", "LineEdit text formatted to 3 decimals on slider change")

	# Case B: Typing in LineEdit updates Slider and current_sensitivity with fine 3-decimal precision (e.g. 0.385)
	line_edit.text = "0.385"
	pause_instance._on_line_edit_text_changed("0.385")
	assert_almost_eq(pause_instance.current_sensitivity, 0.385, 0.001, "Current sensitivity matches exact 3-decimal entry 0.385")
	assert_almost_eq(slider.value, 0.385, 0.005, "Slider value updated to ~0.385")

	# Case C: Boundary clamping [0.05, 2.00]
	pause_instance._on_line_edit_text_changed("5.000")
	assert_almost_eq(pause_instance.current_sensitivity, 2.00, 0.001, "Upper bound clamped to 2.00")

	pause_instance._on_line_edit_text_changed("0.01")
	assert_almost_eq(pause_instance.current_sensitivity, 0.05, 0.001, "Lower bound clamped to 0.05")

	pause_instance.free()


## 3. ConfigFile persistence (user://settings.cfg)
func test_settings_persistence() -> void:
	var pause_instance = PauseScreenScene.instantiate()
	pause_instance._ready()

	# Save a specific sensitivity value
	var test_val: float = 0.582
	pause_instance.set_sensitivity(test_val, true)

	# Verify file written
	var config := ConfigFile.new()
	var err := config.load("user://settings.cfg")
	assert_eq(err, OK, "settings.cfg loaded successfully")
	var saved_val = config.get_value("input", "sensitivity", -1.0)
	assert_almost_eq(float(saved_val), test_val, 0.001, "Saved sensitivity in settings.cfg matches 0.582")

	# Load in a new pause instance and verify it auto-loads
	var pause_instance_2 = PauseScreenScene.instantiate()
	pause_instance_2._ready()
	assert_almost_eq(pause_instance_2.current_sensitivity, test_val, 0.001, "New instance auto-loads 0.582")
	assert_eq(pause_instance_2.sensitivity_line_edit.text, "0.582", "Loaded value reflected in LineEdit")

	pause_instance.free()
	pause_instance_2.free()


## 4. Immediate runtime application to active Camera3D
func test_immediate_runtime_application_to_camera() -> void:
	var root = Node3D.new()
	var cam = FpsCameraClass.new()
	cam.name = "TestCamera"
	root.add_child(cam)
	cam._ready()

	var pause_instance = PauseScreenScene.instantiate()
	root.add_child(pause_instance)
	pause_instance._ready()

	# Initial sync
	assert_almost_eq(cam.valorant_sensitivity, pause_instance.current_sensitivity, 0.001, "Camera sensitivity matches pause screen")

	# Change sensitivity in pause screen
	pause_instance.set_sensitivity(1.234)
	assert_almost_eq(cam.valorant_sensitivity, 1.234, 0.001, "Camera sensitivity updated immediately to 1.234")

	# Change via slider
	pause_instance.sensitivity_slider.value = 0.88
	pause_instance.sensitivity_slider.value_changed.emit(0.88)
	assert_almost_eq(cam.valorant_sensitivity, 0.88, 0.01, "Camera sensitivity updated immediately via slider")

	root.free()


## 5. Pause and Resume Game Flow
func test_pause_and_resume_flow() -> void:
	var pause_instance = PauseScreenScene.instantiate()
	pause_instance._ready()

	assert_false(pause_instance.get_tree().paused if pause_instance.is_inside_tree() else false)

	# Toggle pause
	pause_instance.pause_game()
	assert_true(pause_instance.pause_overlay.visible, "Overlay visible when paused")

	pause_instance.resume_game()
	assert_false(pause_instance.pause_overlay.visible, "Overlay hidden when resumed")

	pause_instance.free()
