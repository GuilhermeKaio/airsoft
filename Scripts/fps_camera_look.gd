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
		var factor: float = valorant_sensitivity * VALORANT_RADIAN_FACTOR
		rotate_y(-event.relative.x * factor)

		var new_pitch: float = rotation.x - event.relative.y * factor
		rotation.x = clamp(new_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))

	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		pass

	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		var is_paused := get_tree().paused if is_inside_tree() and get_tree() else false
		if not is_paused:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
