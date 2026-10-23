extends CanvasLayer

signal sensitivity_changed(new_sensitivity: float)
signal bullet_trails_toggled(enabled: bool)
signal trails_balas_alternado(habilitado: bool)
signal game_paused
signal game_resumed

const SETTINGS_PATH: String = "user://settings.cfg"
const DEFAULT_SENSITIVITY: float = 0.40
const MIN_SENSITIVITY: float = 0.05
const MAX_SENSITIVITY: float = 2.00
const SENSITIVITY_STEP: float = 0.01

@onready var pause_overlay: Control = $PauseOverlay
@onready var sensitivity_slider: HSlider = find_child("SensitivitySlider", true, false)
@onready var sensitivity_line_edit: LineEdit = find_child("SensitivityLineEdit", true, false)
@onready var sensitivity_spinbox: SpinBox = find_child("SensitivitySpinBox", true, false)
@onready var bullet_trails_checkbox: CheckBox = find_child("BulletTrailsCheckBox", true, false)
@onready var trails_checkbox: CheckBox = find_child("BulletTrailsCheckBox", true, false)
@onready var resume_button: Button = find_child("ResumeButton", true, false)
@onready var restart_button: Button = find_child("RestartButton", true, false)

var current_sensitivity: float = DEFAULT_SENSITIVITY
var bullet_trails_enabled: bool = true
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _updating_ui: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_ui_references()
	if pause_overlay:
		pause_overlay.visible = false

	_load_and_apply_settings()
	_connect_signals()


func _init_ui_references() -> void:
	if pause_overlay == null:
		pause_overlay = get_node_or_null("PauseOverlay")
	if sensitivity_slider == null:
		sensitivity_slider = find_child("SensitivitySlider", true, false)
	if sensitivity_line_edit == null:
		sensitivity_line_edit = find_child("SensitivityLineEdit", true, false)
	if sensitivity_spinbox == null:
		sensitivity_spinbox = find_child("SensitivitySpinBox", true, false)
	if bullet_trails_checkbox == null:
		bullet_trails_checkbox = find_child("BulletTrailsCheckBox", true, false)
	if bullet_trails_checkbox == null:
		bullet_trails_checkbox = find_child("TrailsCheckBox", true, false)
	if bullet_trails_checkbox == null:
		bullet_trails_checkbox = find_child("TrailCheckBox", true, false)
	trails_checkbox = bullet_trails_checkbox
	if resume_button == null:
		resume_button = find_child("ResumeButton", true, false)
	if restart_button == null:
		restart_button = find_child("RestartButton", true, false)


func _connect_signals() -> void:
	if sensitivity_slider and not sensitivity_slider.value_changed.is_connected(_on_slider_value_changed):
		sensitivity_slider.value_changed.connect(_on_slider_value_changed)

	if sensitivity_line_edit:
		if not sensitivity_line_edit.text_changed.is_connected(_on_line_edit_text_changed):
			sensitivity_line_edit.text_changed.connect(_on_line_edit_text_changed)
		if not sensitivity_line_edit.text_submitted.is_connected(_on_line_edit_text_submitted):
			sensitivity_line_edit.text_submitted.connect(_on_line_edit_text_submitted)

	if sensitivity_spinbox and not sensitivity_spinbox.value_changed.is_connected(_on_spinbox_value_changed):
		sensitivity_spinbox.value_changed.connect(_on_spinbox_value_changed)

	if bullet_trails_checkbox and not bullet_trails_checkbox.toggled.is_connected(_on_trails_checkbox_toggled):
		bullet_trails_checkbox.toggled.connect(_on_trails_checkbox_toggled)

	if resume_button and not resume_button.pressed.is_connected(resume_game):
		resume_button.pressed.connect(resume_game)

	if restart_button and not restart_button.pressed.is_connected(restart_game):
		restart_button.pressed.connect(restart_game)


func _load_and_apply_settings() -> void:
	current_sensitivity = load_sensitivity_setting()
	_apply_sensitivity_to_ui(current_sensitivity)
	apply_sensitivity_to_camera(current_sensitivity)

	bullet_trails_enabled = load_bullet_trails_setting()
	set_bullet_trails_enabled(bullet_trails_enabled, false)


func _apply_sensitivity_to_ui(sens: float) -> void:
	_updating_ui = true
	if sensitivity_slider:
		sensitivity_slider.min_value = MIN_SENSITIVITY
		sensitivity_slider.max_value = MAX_SENSITIVITY
		var prev_step = sensitivity_slider.step
		sensitivity_slider.step = 0.001
		sensitivity_slider.value = sens
		sensitivity_slider.step = prev_step if prev_step > 0.0 else SENSITIVITY_STEP

	if sensitivity_line_edit:
		sensitivity_line_edit.text = "%.3f" % sens

	if sensitivity_spinbox:
		sensitivity_spinbox.min_value = MIN_SENSITIVITY
		sensitivity_spinbox.max_value = MAX_SENSITIVITY
		sensitivity_spinbox.step = 0.001
		sensitivity_spinbox.value = sens
	_updating_ui = false


func set_sensitivity(val: float, save_to_file: bool = true) -> void:
	var clamped := clampf(val, MIN_SENSITIVITY, MAX_SENSITIVITY)
	current_sensitivity = clamped
	_apply_sensitivity_to_ui(clamped)
	apply_sensitivity_to_camera(clamped)
	if save_to_file:
		save_sensitivity_setting(clamped)
	sensitivity_changed.emit(clamped)


func get_sensitivity() -> float:
	return current_sensitivity


func _on_slider_value_changed(value: float) -> void:
	if _updating_ui:
		return
	var clamped := clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
	current_sensitivity = clamped
	_updating_ui = true
	if sensitivity_line_edit:
		sensitivity_line_edit.text = "%.3f" % clamped
	if sensitivity_spinbox:
		sensitivity_spinbox.value = clamped
	_updating_ui = false

	apply_sensitivity_to_camera(clamped)
	save_sensitivity_setting(clamped)
	sensitivity_changed.emit(clamped)


func _on_line_edit_text_changed(new_text: String) -> void:
	if _updating_ui:
		return
	if new_text.is_valid_float():
		var val := float(new_text)
		val = clampf(val, MIN_SENSITIVITY, MAX_SENSITIVITY)
		current_sensitivity = val
		_updating_ui = true
		if sensitivity_slider:
			var prev_step = sensitivity_slider.step
			sensitivity_slider.step = 0.001
			sensitivity_slider.value = val
			sensitivity_slider.step = prev_step if prev_step > 0.0 else SENSITIVITY_STEP
		if sensitivity_spinbox:
			sensitivity_spinbox.value = val
		_updating_ui = false

		apply_sensitivity_to_camera(val)
		save_sensitivity_setting(val)
		sensitivity_changed.emit(val)


func _on_line_edit_text_submitted(_new_text: String) -> void:
	if sensitivity_line_edit:
		sensitivity_line_edit.text = "%.3f" % current_sensitivity


func _on_spinbox_value_changed(value: float) -> void:
	if _updating_ui:
		return
	var clamped := clampf(value, MIN_SENSITIVITY, MAX_SENSITIVITY)
	current_sensitivity = clamped
	_updating_ui = true
	if sensitivity_slider:
		var prev_step = sensitivity_slider.step
		sensitivity_slider.step = 0.001
		sensitivity_slider.value = clamped
		sensitivity_slider.step = prev_step if prev_step > 0.0 else SENSITIVITY_STEP
	if sensitivity_line_edit:
		sensitivity_line_edit.text = "%.3f" % clamped
	_updating_ui = false

	apply_sensitivity_to_camera(clamped)
	save_sensitivity_setting(clamped)
	sensitivity_changed.emit(clamped)


func apply_sensitivity_to_camera(sens: float) -> void:
	if not is_inside_tree():
		var node = get_parent()
		while node != null:
			_apply_to_child_cameras(node, sens)
			node = node.get_parent()
		return

	var viewport = get_viewport()
	if viewport:
		var cam = viewport.get_camera_3d()
		if cam and "valorant_sensitivity" in cam:
			cam.valorant_sensitivity = sens

	if get_tree():
		var cameras = get_tree().get_nodes_in_group("fps_cameras")
		for c in cameras:
			if "valorant_sensitivity" in c:
				c.valorant_sensitivity = sens
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			if "valorant_sensitivity" in p:
				p.valorant_sensitivity = sens


func _apply_to_child_cameras(node: Node, sens: float) -> void:
	if node != self:
		if "valorant_sensitivity" in node:
			node.valorant_sensitivity = sens
	for child in node.get_children():
		if child != self:
			_apply_to_child_cameras(child, sens)


func set_bullet_trails_enabled(enabled: bool, save_to_file: bool = true) -> void:
	bullet_trails_enabled = enabled
	_updating_ui = true
	if bullet_trails_checkbox:
		bullet_trails_checkbox.button_pressed = enabled
		bullet_trails_checkbox.text = "Ativado" if enabled else "Desativado"
	_updating_ui = false

	var BBClass = load("res://Scripts/bb.gd")
	if BBClass and "set_global_trail_enabled" in BBClass:
		BBClass.set_global_trail_enabled(enabled, get_tree() if is_inside_tree() else null)

	_apply_trails_to_player(enabled)

	if save_to_file:
		save_bullet_trails_setting(enabled)

	bullet_trails_toggled.emit(enabled)
	trails_balas_alternado.emit(enabled)


func is_bullet_trails_enabled() -> bool:
	return bullet_trails_enabled


func toggle_bullet_trails() -> bool:
	set_bullet_trails_enabled(not bullet_trails_enabled, true)
	return bullet_trails_enabled


func _on_trails_checkbox_toggled(toggled_on: bool) -> void:
	if _updating_ui:
		return
	set_bullet_trails_enabled(toggled_on, true)


func _apply_trails_to_player(enabled: bool) -> void:
	if not is_inside_tree():
		var node = get_parent()
		while node != null:
			if node.has_method("set_bullet_tracing"):
				node.set_bullet_tracing(enabled)
			for child in node.get_children():
				if child != self and child.has_method("set_bullet_tracing"):
					child.set_bullet_tracing(enabled)
			node = node.get_parent()
		return

	if get_tree():
		var players = get_tree().get_nodes_in_group("player")
		for p in players:
			if p.has_method("set_bullet_tracing"):
				p.set_bullet_tracing(enabled)


func save_bullet_trails_setting(enabled: bool) -> void:
	var config := ConfigFile.new()
	var _err = config.load(SETTINGS_PATH)
	config.set_value("gameplay", "bullet_trails", enabled)
	config.save(SETTINGS_PATH)


func load_bullet_trails_setting() -> bool:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err == OK:
		var val = config.get_value("gameplay", "bullet_trails", true)
		if val is bool:
			return val
	return true


func save_sensitivity_setting(sens: float) -> void:
	var config := ConfigFile.new()
	var _err = config.load(SETTINGS_PATH)
	config.set_value("input", "sensitivity", sens)
	config.save(SETTINGS_PATH)


func load_sensitivity_setting() -> float:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err == OK:
		var val = config.get_value("input", "sensitivity", DEFAULT_SENSITIVITY)
		if val is float or val is int:
			return clampf(float(val), MIN_SENSITIVITY, MAX_SENSITIVITY)
	return DEFAULT_SENSITIVITY


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		toggle_pause()
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if is_inside_tree() and get_tree() and get_tree().paused:
		resume_game()
	else:
		pause_game()


func pause_game() -> void:
	_prev_mouse_mode = Input.mouse_mode
	if is_inside_tree() and get_tree():
		get_tree().paused = true
	if pause_overlay:
		pause_overlay.visible = true

	var BBClass = load("res://Scripts/bb.gd")
	if BBClass and "is_global_trail_enabled" in BBClass:
		var current_state: bool = BBClass.is_global_trail_enabled()
		bullet_trails_enabled = current_state
		_updating_ui = true
		if bullet_trails_checkbox:
			bullet_trails_checkbox.button_pressed = current_state
			bullet_trails_checkbox.text = "Ativado" if current_state else "Desativado"
		_updating_ui = false

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_paused.emit()


func resume_game() -> void:
	if is_inside_tree() and get_tree():
		get_tree().paused = false
	if pause_overlay:
		pause_overlay.visible = false
	if _prev_mouse_mode == Input.MOUSE_MODE_CAPTURED or _prev_mouse_mode == Input.MOUSE_MODE_CONFINED:
		Input.mouse_mode = _prev_mouse_mode
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game_resumed.emit()


func restart_game() -> void:
	if is_inside_tree() and get_tree():
		get_tree().paused = false
	if pause_overlay:
		pause_overlay.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if is_inside_tree() and get_tree():
		get_tree().reload_current_scene()
