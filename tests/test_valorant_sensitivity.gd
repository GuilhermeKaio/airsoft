extends RefCounted

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

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.0001, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if abs(actual - expected) > tolerance:
		_failed = true
		_message = msg if msg != "" else ("Expected ~%f, got %f (diff: %f > %f)" % [expected, actual, abs(actual - expected), tolerance])


## 1. Valorant Ballistic Scale Constants (SRS Seção 6.1)
func test_valorant_scale_constants() -> void:
	var cam = FpsCameraClass.new()
	assert_almost_eq(cam.VALORANT_DEG_PER_COUNT, 0.07, 0.00001, "Valorant deg per count is 0.07 deg")

	# fator_radiano = 0.07 * (pi / 180) ≈ 0.0012217304764 rad/pixel
	var expected_rad = 0.07 * (PI / 180.0)
	assert_almost_eq(cam.VALORANT_RADIAN_FACTOR, expected_rad, 0.000001, "VALORANT_RADIAN_FACTOR matches 0.07 * (PI / 180)")
	assert_almost_eq(cam.VALORANT_RADIAN_FACTOR, 0.0012217304764, 0.000001, "VALORANT_RADIAN_FACTOR matches spec constant")

	assert_almost_eq(cam.DEFAULT_SENSITIVITY, 0.40, 0.001, "Default sensitivity is 0.40")

	cam.free()


## 2. 1:1 Valorant Camera Rotation Calculation (Δθ = -Δx * sens * factor)
func test_camera_rotation_calculation() -> void:
	var cam = FpsCameraClass.new()
	cam.valorant_sensitivity = 0.40
	cam._is_active_camera = true
	cam.rotation = Vector3.ZERO

	# Simulate moving mouse right by 100 pixels (relative.x = 100, relative.y = 0)
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(100.0, 0.0)
	cam._unhandled_input(motion)

	# Δθ = -100 * (0.40 * 0.0012217304764) ≈ -0.048869219 rad
	var expected_yaw_rad: float = -100.0 * 0.40 * cam.VALORANT_RADIAN_FACTOR
	assert_almost_eq(cam.rotation.y, expected_yaw_rad, 0.0001, "Yaw rotation matches exact Valorant formula")

	# In degrees: 100 counts * 0.40 * 0.07° = 2.8°
	var yaw_deg = rad_to_deg(cam.rotation.y)
	assert_almost_eq(yaw_deg, -2.8, 0.001, "Yaw rotation matches 2.8 degrees")

	# Vertical pitch: moving mouse up (relative.y = -50)
	motion.relative = Vector2(0.0, -50.0)
	cam._unhandled_input(motion)

	# In degrees: 50 counts * 0.40 * 0.07° = 1.4° pitch up
	var pitch_deg = rad_to_deg(cam.rotation.x)
	assert_almost_eq(pitch_deg, 1.4, 0.001, "Pitch rotation matches 1.4 degrees up")

	cam.free()


## 3. Custom Sensitivity Scaling (e.g. 0.35 Valorant standard)
func test_custom_sensitivity_scaling() -> void:
	var cam = FpsCameraClass.new()
	cam.set_valorant_sensitivity(0.35)
	cam._is_active_camera = true
	cam.rotation = Vector3.ZERO

	# 800 counts at sens 0.35: 800 * 0.35 * 0.07° = 19.6°
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(800.0, 0.0)
	cam._unhandled_input(motion)

	var yaw_deg = rad_to_deg(cam.rotation.y)
	assert_almost_eq(yaw_deg, -19.6, 0.005, "800 counts at 0.35 sens rotates exactly 19.6 degrees")

	cam.free()


## 4. Pitch Clamping within min/max angles
func test_pitch_clamping() -> void:
	var cam = FpsCameraClass.new()
	cam.valorant_sensitivity = 1.0
	cam._is_active_camera = true
	cam.rotation = Vector3.ZERO

	# Large upward mouse movement
	var motion = InputEventMouseMotion.new()
	motion.relative = Vector2(0.0, -10000.0)
	cam._unhandled_input(motion)

	assert_almost_eq(rad_to_deg(cam.rotation.x), cam.max_pitch_deg, 0.01, "Pitch clamped at max_pitch_deg (89 deg)")

	# Large downward mouse movement
	motion.relative = Vector2(0.0, 20000.0)
	cam._unhandled_input(motion)

	assert_almost_eq(rad_to_deg(cam.rotation.x), cam.min_pitch_deg, 0.01, "Pitch clamped at min_pitch_deg (-89 deg)")

	cam.free()
