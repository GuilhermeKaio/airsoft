extends Camera3D

@export var mouse_sensitivity: float = 0.003
@export var min_pitch_deg: float = -89.0
@export var max_pitch_deg: float = 89.0

var _is_active_camera: bool = false


func _process(_delta: float) -> void:
	var should_be_active := get_viewport().get_camera_3d() == self
	if should_be_active != _is_active_camera:
		_is_active_camera = should_be_active
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _is_active_camera else Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active_camera:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

		var new_pitch: float = rotation.x - event.relative.y * mouse_sensitivity
		rotation.x = clamp(new_pitch, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))

	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
