extends Camera3D

@export var mouse_sensitivity: float = 0.003
@export var min_pitch_deg: float = -89.0
@export var max_pitch_deg: float = 89.0

var _is_active_camera: bool = false
var uncompensated_recoil: Vector2 = Vector2.ZERO # x: yaw (rad), y: pitch (rad)


func apply_recoil(pitch_deg: float, yaw_deg: float) -> void:
	var pitch_rad := deg_to_rad(pitch_deg)
	var yaw_rad := deg_to_rad(yaw_deg)

	# Apply recoil pitch (+pitch tilts camera up)
	rotation.x = clamp(rotation.x + pitch_rad, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
	# Apply recoil yaw (+yaw tilts camera right, which corresponds to -rotate_y)
	rotate_y(-yaw_rad)

	uncompensated_recoil.y += pitch_rad
	uncompensated_recoil.x += yaw_rad


func recover_recoil(pitch_rad: float, yaw_rad: float) -> void:
	if absf(uncompensated_recoil.y) > 0.00001:
		var step_p: float = signf(uncompensated_recoil.y) * minf(absf(uncompensated_recoil.y), absf(pitch_rad))
		rotation.x = clampf(rotation.x - step_p, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
		uncompensated_recoil.y -= step_p

	if absf(uncompensated_recoil.x) > 0.00001:
		var step_y: float = signf(uncompensated_recoil.x) * minf(absf(uncompensated_recoil.x), absf(yaw_rad))
		rotate_y(step_y)
		uncompensated_recoil.x -= step_y


func reset_recoil() -> void:
	uncompensated_recoil = Vector2.ZERO


func _process(_delta: float) -> void:
	var should_be_active := get_viewport().get_camera_3d() == self
	if should_be_active != _is_active_camera:
		_is_active_camera = should_be_active
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _is_active_camera else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active_camera:
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var mouse_dy: float = motion.relative.y * mouse_sensitivity
		var mouse_dx: float = motion.relative.x * mouse_sensitivity

		# Active recoil compensation (CS/Valorant style):
		# Pulling mouse down opposes upward recoil without causing floor pull upon recovery
		if mouse_dy > 0.0 and uncompensated_recoil.y > 0.0:
			var comp: float = minf(mouse_dy, uncompensated_recoil.y)
			uncompensated_recoil.y -= comp
		elif mouse_dy < 0.0 and uncompensated_recoil.y < 0.0:
			var comp: float = minf(-mouse_dy, -uncompensated_recoil.y)
			uncompensated_recoil.y += comp

		if mouse_dx < 0.0 and uncompensated_recoil.x > 0.0:
			var comp: float = minf(-mouse_dx, uncompensated_recoil.x)
			uncompensated_recoil.x -= comp
		elif mouse_dx > 0.0 and uncompensated_recoil.x < 0.0:
			var comp: float = minf(mouse_dx, -uncompensated_recoil.x)
			uncompensated_recoil.x += comp

		rotate_y(-mouse_dx)

		var new_pitch: float = rotation.x - mouse_dy
		rotation.x = clampf(new_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))

	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
