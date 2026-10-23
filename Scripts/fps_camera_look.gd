extends Camera3D

const VALORANT_DEG_PER_COUNT: float = 0.07
const VALORANT_RADIAN_FACTOR: float = 0.0012217304764
const DEFAULT_SENSITIVITY: float = 0.40
const SETTINGS_PATH: String = "user://settings.cfg"

@export var valorant_sensitivity: float = DEFAULT_SENSITIVITY:
	set(value):
		valorant_sensitivity = value
		mouse_sensitivity = valorant_sensitivity * VALORANT_RADIAN_FACTOR

@export var mouse_sensitivity: float = DEFAULT_SENSITIVITY * VALORANT_RADIAN_FACTOR
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


func _ready() -> void:
	add_to_group("fps_cameras")
	load_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err == OK:
		var sens = config.get_value("input", "sensitivity", DEFAULT_SENSITIVITY)
		if sens is float or sens is int:
			valorant_sensitivity = float(sens)


func set_valorant_sensitivity(sens: float) -> void:
	valorant_sensitivity = sens


func get_valorant_sensitivity() -> float:
	return valorant_sensitivity


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	var viewport = get_viewport()
	if viewport:
		var should_be_active := viewport.get_camera_3d() == self
		if should_be_active != _is_active_camera:
			_is_active_camera = should_be_active
			var is_paused := get_tree().paused if get_tree() else false
			if not is_paused:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _is_active_camera else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active_camera:
		return
	if is_inside_tree() and get_tree() and get_tree().paused:
		return

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var factor: float = valorant_sensitivity * VALORANT_RADIAN_FACTOR
		var mouse_dy: float = motion.relative.y * factor
		var mouse_dx: float = motion.relative.x * factor

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
		pass

	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var is_paused := get_tree().paused if is_inside_tree() and get_tree() else false
		if not is_paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
