extends CharacterBody3D

signal weapon_swapped(new_weapon: Node, slot_index: int)
signal arma_trocada(nova_arma: Node, slot_index: int)
signal slot_selected(slot_index: int)
signal bullet_tracing_toggled(enabled: bool)
signal tracing_balas_alternado(habilitado: bool)
signal shot_fired(count: int)
signal tiro_disparado(count: int)

# Sinais de Dispersão Cinemática e Counter-Strafing (SRS Adicionais Seção 7)
signal movement_spread_changed(current_spread_deg: float, state: int)
signal dispersao_movimento_alterada(dispersao_graus: float, estado: int)
signal kinematic_state_changed(new_state: int)
signal estado_cinematico_alterado(novo_estado: int)
signal accuracy_deadzone_entered()
signal accuracy_deadzone_exited()

# Sinais de Movimentação Avançada (SRS Adicionais Seção 4)
signal bunny_hop_performed(speed: float)
signal bunny_hop_executado(velocidade: float)
signal bunny_hop_failed()
signal bunny_hop_falhou()
signal air_strafe_accelerated(speed: float, delta_speed: float)
signal air_strafe_acelerado(velocidade: float, delta_velocidade: float)

enum KinematicState {
	STATIONARY = 0,
	WALKING = 1,
	RUNNING = 2,
	AIRBORNE = 3
}

enum EstadoCinematico {
	ESTATICO = 0,
	ANDANDO = 1,
	CORRENDO = 2,
	NO_AR = 3
}

@export var speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

@export_group("Kinematic Spread & Deadzoning (SRS Adicionais Seção 7)")
@export var walk_speed: float = 2.5
@export var stationary_max_speed: float = 1.0
@export var walking_max_speed: float = 3.0
@export var deadzone_speed_ratio: float = 0.28 # 28% da velocidade de corrida (25% a 30% per SRS 7.2)
@export var stationary_spread_deg: float = 0.0 # Erro adicional de movimento nulo quando parado
@export var walking_spread_deg: float = 1.0 # 0.8° a 1.5°
@export var running_spread_deg: float = 5.5 # 4.5° a 7.0°
@export var airborne_spread_deg: float = 10.0 # 8.0° a 12.0°
@export var spread_lerp_speed: float = 25.0
@export var ground_acceleration: float = 40.0
@export var ground_friction: float = 28.0
@export var counter_strafe_multiplier: float = 2.5

@export_group("Advanced Movement (Bunny Hop & Air Strafe - SRS Adicionais Seção 4)")
@export var bunny_hop_enabled: bool = true
@export var bhop_jump_window: float = 0.1 # Janela de tolerância <= 0.1s (SRS 4.1.1)
@export var bhop_max_speed: float = 15.0 # Teto máximo configurável (SRS 4.1.3: 15.0 m/s)
@export var bhop_jump_boost: float = 0.2 # Preservação / pequeno incremento por salto perfeito
@export var air_acceleration: float = 12.0 # air_accel (SRS 4.1.2)
@export var air_strafe_efficiency_min: float = 0.2
@export var jump_buffer_time: float = 0.1

var time_on_floor: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = true
var is_bunny_hopping: bool = false
var accumulated_yaw_delta: float = 0.0
var _last_camera_yaw: float = 0.0
var _is_currently_air_strafing: bool = false

var current_movement_spread: float = 0.0
var _last_emitted_spread: float = -999.0
var _last_kinematic_state: int = -1
var _was_in_deadzone: bool = false
var _override_on_floor: bool = false
var _forced_on_floor_value: bool = true

const DEFAULT_SENSITIVITY: float = 0.40
const SETTINGS_PATH: String = "user://settings.cfg"

@export_group("Input & Sensitivity (Valorant Scale - SRS Seção 6)")
@export var valorant_sensitivity: float = DEFAULT_SENSITIVITY:
	set(value):
		valorant_sensitivity = value
		if main_camera and "valorant_sensitivity" in main_camera:
			main_camera.valorant_sensitivity = value

var mouse_sensitivity: float:
	get:
		return valorant_sensitivity
	set(value):
		valorant_sensitivity = value

@export_group("Inventory & Weapon Slots (SRS Seção 4 & 6)")
@export var weapon: Node
@export var weapon_slot_1: Node
@export var weapon_slot_2: Node
@export var active_slot: int = 1

@onready var main_camera: Camera3D = get_node_or_null("Camera3")


func _ready() -> void:
	add_to_group("player")
	if collision_layer == 1 and collision_mask == 1:
		collision_layer = 2
		collision_mask = 1

	if main_camera == null:
		main_camera = get_node_or_null("Camera3")

	# Load sensitivity setting from disk and apply to player and camera
	valorant_sensitivity = load_sensitivity_from_disk()
	if main_camera and "valorant_sensitivity" in main_camera:
		main_camera.valorant_sensitivity = valorant_sensitivity

	# Load bullet trails preference if saved on disk
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		var trails_pref = config.get_value("gameplay", "bullet_trails", bullet_tracing_enabled)
		if trails_pref is bool:
			bullet_tracing_enabled = trails_pref
			_apply_bullet_tracing(bullet_tracing_enabled)

	if weapon_slot_1 == null:
		weapon_slot_1 = get_node_or_null("WeaponSlot1")
		if weapon_slot_1 == null:
			weapon_slot_1 = get_node_or_null("Weapon")
	if weapon_slot_2 == null:
		weapon_slot_2 = get_node_or_null("WeaponSlot2")
	
	if weapon == null:
		weapon = weapon_slot_1 if weapon_slot_1 != null else weapon_slot_2

	select_slot(active_slot, true)


func get_weapon() -> Node:
	if weapon == null and is_inside_tree():
		if active_slot == 1 and weapon_slot_1 != null:
			weapon = weapon_slot_1
		elif active_slot == 2 and weapon_slot_2 != null:
			weapon = weapon_slot_2
		else:
			weapon = get_node_or_null("Weapon")
			if weapon == null:
				weapon = weapon_slot_1 if weapon_slot_1 != null else weapon_slot_2
	return weapon


func set_weapon(new_weapon: Node) -> void:
	weapon = new_weapon
	if active_slot == 1:
		weapon_slot_1 = new_weapon
	elif active_slot == 2:
		weapon_slot_2 = new_weapon


func get_active_slot() -> int:
	return active_slot


func get_weapon_in_slot(slot_index: int) -> Node:
	if slot_index == 1:
		return weapon_slot_1
	elif slot_index == 2:
		return weapon_slot_2
	return null


func equip_weapon_in_slot(weapon_node: Node, slot_index: int) -> void:
	if weapon_node != null and weapon_node.get_parent() != self:
		if weapon_node.get_parent() != null:
			weapon_node.get_parent().remove_child(weapon_node)
		add_child(weapon_node)
		if weapon_node is Node3D:
			weapon_node.transform = Transform3D.IDENTITY

	if slot_index == 1:
		weapon_slot_1 = weapon_node
	elif slot_index == 2:
		weapon_slot_2 = weapon_node
	
	if active_slot == slot_index:
		select_slot(slot_index, true)
	else:
		if weapon_node != null and "visible" in weapon_node:
			weapon_node.visible = false


func select_slot(slot_index: int, force: bool = false) -> bool:
	if slot_index != 1 and slot_index != 2:
		return false
	if slot_index == active_slot and not force:
		return true

	var target_weapon: Node = weapon_slot_1 if slot_index == 1 else weapon_slot_2
	if target_weapon == null and not force:
		return false

	var previous_weapon: Node = get_weapon()
	if previous_weapon != null and previous_weapon != target_weapon:
		if previous_weapon.has_method("reset_recoil"):
			previous_weapon.reset_recoil()
		if previous_weapon.has_method("atirar"):
			previous_weapon.atirar(false)

	active_slot = slot_index
	weapon = target_weapon

	if weapon_slot_1 != null and "visible" in weapon_slot_1:
		weapon_slot_1.visible = (active_slot == 1)
	if weapon_slot_2 != null and "visible" in weapon_slot_2:
		weapon_slot_2.visible = (active_slot == 2)

	if weapon != null and weapon.has_method("_emit_initial_state"):
		weapon._emit_initial_state()

	if weapon != null and weapon.has_signal("shot_fired") and not weapon.shot_fired.is_connected(_on_weapon_shot_fired):
		weapon.shot_fired.connect(_on_weapon_shot_fired)

	weapon_swapped.emit(weapon, active_slot)
	arma_trocada.emit(weapon, active_slot)
	slot_selected.emit(active_slot)
	return true


func selecionar_slot(slot_index: int) -> bool:
	return select_slot(slot_index)


func get_active_recoil_offset() -> Vector2:
	var w = get_weapon()
	if w and "current_recoil_offset" in w:
		return w.current_recoil_offset
	return Vector2.ZERO


func reset_recoil() -> void:
	var w = get_weapon()
	if w and w.has_method("reset_recoil"):
		w.reset_recoil()
	if main_camera and main_camera.has_method("reset_recoil"):
		main_camera.reset_recoil()


func _on_weapon_shot_fired(count: int = 1) -> void:
	shot_fired.emit(count)
	tiro_disparado.emit(count)


## Delegação de Comandos para a Arma Ativa (SRS Seções 2 e 3.1)
func atirar(pressionado: bool) -> void:
	var active_weapon = get_weapon()
	if active_weapon and active_weapon.has_method("atirar"):
		active_weapon.atirar(pressionado)


func alternar_modo_tiro() -> void:
	var active_weapon = get_weapon()
	if active_weapon:
		if active_weapon.has_method("alternar_modo_tiro"):
			active_weapon.alternar_modo_tiro()
		elif active_weapon.has_method("toggle_fire_mode"):
			active_weapon.toggle_fire_mode()


func recarregar() -> void:
	var active_weapon = get_weapon()
	if active_weapon:
		if active_weapon.has_method("recarregar"):
			active_weapon.recarregar()
		elif active_weapon.has_method("reload"):
			active_weapon.reload()


func ajustar_hop_up(delta: float) -> void:
	var active_weapon = get_weapon()
	if active_weapon:
		if active_weapon.has_method("ajustar_hop_up"):
			active_weapon.ajustar_hop_up(delta)
		elif active_weapon.has_method("adjust_hop_up"):
			active_weapon.adjust_hop_up(delta)


func _get_hop_up_step() -> float:
	var active_weapon = get_weapon()
	if active_weapon and "hop_up_step" in active_weapon:
		return active_weapon.hop_up_step
	return 50.0


var bullet_tracing_enabled: bool = true


func toggle_bullet_tracing() -> bool:
	bullet_tracing_enabled = not bullet_tracing_enabled
	_apply_bullet_tracing(bullet_tracing_enabled)
	bullet_tracing_toggled.emit(bullet_tracing_enabled)
	tracing_balas_alternado.emit(bullet_tracing_enabled)
	return bullet_tracing_enabled


func set_bullet_tracing(enabled: bool) -> void:
	bullet_tracing_enabled = enabled
	_apply_bullet_tracing(bullet_tracing_enabled)
	bullet_tracing_toggled.emit(bullet_tracing_enabled)
	tracing_balas_alternado.emit(bullet_tracing_enabled)


func is_bullet_tracing_enabled() -> bool:
	return bullet_tracing_enabled


func _apply_bullet_tracing(enabled: bool) -> void:
	var BBClass = load("res://Scripts/bb.gd")
	if BBClass and "set_global_trail_enabled" in BBClass:
		BBClass.set_global_trail_enabled(enabled, get_tree() if is_inside_tree() else null)
	if weapon_slot_1 and weapon_slot_1.has_method("set_bullet_tracing"):
		weapon_slot_1.set_bullet_tracing(enabled)
	if weapon_slot_2 and weapon_slot_2.has_method("set_bullet_tracing"):
		weapon_slot_2.set_bullet_tracing(enabled)
	var active_w = get_weapon()
	if active_w and active_w.has_method("set_bullet_tracing"):
		active_w.set_bullet_tracing(enabled)


func set_sensitivity(val: float, save_to_disk: bool = true) -> void:
	valorant_sensitivity = val
	if main_camera and "valorant_sensitivity" in main_camera:
		main_camera.valorant_sensitivity = val
	if save_to_disk:
		save_sensitivity_to_disk(val)


func get_sensitivity() -> float:
	return valorant_sensitivity


func set_valorant_sensitivity(val: float, save_to_disk: bool = true) -> void:
	set_sensitivity(val, save_to_disk)


func get_valorant_sensitivity() -> float:
	return valorant_sensitivity


func save_sensitivity_to_disk(sens: float = -1.0) -> void:
	var val_to_save := sens if sens >= 0.0 else valorant_sensitivity
	var config := ConfigFile.new()
	var _err = config.load(SETTINGS_PATH)
	config.set_value("input", "sensitivity", val_to_save)
	config.save(SETTINGS_PATH)


func save_sensitivity_setting(sens: float = -1.0) -> void:
	save_sensitivity_to_disk(sens)


func load_sensitivity_from_disk() -> float:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_PATH)
	if err == OK:
		var val = config.get_value("input", "sensitivity", DEFAULT_SENSITIVITY)
		if val is float or val is int:
			return float(val)
	return DEFAULT_SENSITIVITY


func load_sensitivity_setting() -> float:
	return load_sensitivity_from_disk()


func _unhandled_input(event: InputEvent) -> void:
	var is_ctrl: bool = ("ctrl_pressed" in event and event.ctrl_pressed)
	if event.is_action_pressed("toggle_bullet_tracing") or (is_ctrl and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T):
		toggle_bullet_tracing()
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return

	if not is_ctrl and (event.is_action_pressed("weapon_slot_1") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_1)):
		select_slot(1)
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return

	if not is_ctrl and (event.is_action_pressed("weapon_slot_2") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_2)):
		select_slot(2)
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return

	if event.is_action("fire") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if not event.is_echo():
			atirar(event.is_pressed())
			if is_inside_tree() and get_viewport():
				get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("toggle_fire_mode"):
		alternar_modo_tiro()
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("reload"):
		recarregar()
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("hopup_increase") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed):
		ajustar_hop_up(_get_hop_up_step())
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return
	elif event.is_action_pressed("hopup_decrease") or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed):
		ajustar_hop_up(-_get_hop_up_step())
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()
		return


func is_player_on_floor() -> bool:
	if _override_on_floor:
		return _forced_on_floor_value
	if is_inside_tree():
		return is_on_floor()
	return true


func set_on_floor_override(on_floor: bool, active: bool = true) -> void:
	_override_on_floor = active
	_forced_on_floor_value = on_floor


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func get_deadzone_speed_threshold() -> float:
	return speed * deadzone_speed_ratio


func is_in_accuracy_deadzone() -> bool:
	if not is_player_on_floor():
		return false
	return get_horizontal_speed() <= get_deadzone_speed_threshold()


func get_kinematic_state() -> KinematicState:
	if not is_player_on_floor():
		return KinematicState.AIRBORNE
	var v_h := get_horizontal_speed()
	if v_h <= stationary_max_speed or is_in_accuracy_deadzone():
		return KinematicState.STATIONARY
	elif v_h <= walking_max_speed:
		return KinematicState.WALKING
	else:
		return KinematicState.RUNNING


func get_target_movement_spread(state: int = -1, v_h: float = -1.0) -> float:
	if state < 0:
		state = int(get_kinematic_state())
	if v_h < 0.0:
		v_h = get_horizontal_speed()

	match state:
		KinematicState.STATIONARY:
			return stationary_spread_deg
		KinematicState.WALKING:
			var t := clampf((v_h - stationary_max_speed) / maxf(walking_max_speed - stationary_max_speed, 0.001), 0.0, 1.0)
			return lerpf(0.8, 1.5, t)
		KinematicState.RUNNING:
			var t := clampf((v_h - walking_max_speed) / maxf(speed - walking_max_speed, 0.001), 0.0, 1.0)
			return lerpf(4.5, 7.0, t)
		KinematicState.AIRBORNE:
			return airborne_spread_deg
		_:
			return 0.0


func get_movement_spread() -> float:
	return current_movement_spread


func set_movement_spread(value: float) -> void:
	current_movement_spread = value


func update_movement_spread(delta: float) -> void:
	var state := get_kinematic_state()
	var in_deadzone := is_in_accuracy_deadzone()

	if in_deadzone != _was_in_deadzone:
		_was_in_deadzone = in_deadzone
		if in_deadzone:
			accuracy_deadzone_entered.emit()
		else:
			accuracy_deadzone_exited.emit()

	var target_spread := get_target_movement_spread(int(state))
	current_movement_spread = move_toward(current_movement_spread, target_spread, spread_lerp_speed * delta)

	if int(state) != _last_kinematic_state:
		_last_kinematic_state = int(state)
		kinematic_state_changed.emit(int(state))
		estado_cinematico_alterado.emit(int(state))

	if absf(current_movement_spread - _last_emitted_spread) > 0.005:
		_last_emitted_spread = current_movement_spread
		movement_spread_changed.emit(current_movement_spread, int(state))
		dispersao_movimento_alterada.emit(current_movement_spread, int(state))


func register_yaw_delta(delta_rad: float) -> void:
	accumulated_yaw_delta += delta_rad


func get_time_on_floor() -> float:
	return time_on_floor


func is_air_strafing() -> bool:
	return _is_currently_air_strafing


func can_bunny_hop() -> bool:
	return bunny_hop_enabled and is_player_on_floor() and time_on_floor <= bhop_jump_window


func get_bhop_max_speed() -> float:
	return bhop_max_speed


func set_bhop_max_speed(value: float) -> void:
	bhop_max_speed = value


func calculate_air_strafe_acceleration(wish_dir: Vector3, yaw_delta: float, cur_vel: Vector3, delta: float) -> Vector3:
	var vel_h := Vector3(cur_vel.x, 0.0, cur_vel.z)
	var h_speed := vel_h.length()
	if h_speed < 0.05:
		return wish_dir.normalized() * (air_acceleration * delta)

	var v_norm := vel_h.normalized()
	var u_wish := Vector3(wish_dir.x, 0.0, wish_dir.z).normalized()
	var alignment := u_wish.dot(v_norm)
	var eff := clampf(maxf(alignment, air_strafe_efficiency_min), 0.0, 1.0)

	var cross_y := v_norm.cross(u_wish).y
	var strafe_side := signf(cross_y)
	if absf(strafe_side) < 0.01:
		strafe_side = 1.0

	var p_perp: Vector3 = (Vector3.UP.cross(v_norm) if strafe_side > 0.0 else v_norm.cross(Vector3.UP)).normalized()
	var a_mag := air_acceleration * eff
	var delta_speed := a_mag * delta
	var new_speed := minf(h_speed + delta_speed, bhop_max_speed)

	var turn_injection := p_perp * (a_mag * delta / maxf(h_speed, 1.0))
	var new_dir := (v_norm + turn_injection).normalized()
	var new_vel := new_dir * new_speed
	return new_vel - vel_h


func process_movement(delta: float, input_dir: Vector2, jump_pressed: bool, sprint_pressed: bool, yaw_delta: float) -> void:
	var on_floor := is_player_on_floor()

	if on_floor and not was_on_floor:
		time_on_floor = 0.0
		was_on_floor = true

	if not on_floor:
		velocity.y -= gravity * delta
		time_on_floor = 0.0
		was_on_floor = false

	# Jump buffer timer tracking
	if jump_pressed:
		jump_buffer_timer = jump_buffer_time
	elif jump_buffer_timer > 0.0:
		jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

	# Camera direction vectors
	var direction := Vector3.ZERO
	var cam_right := Vector3.RIGHT
	if main_camera:
		var cam_basis := main_camera.global_transform.basis
		var forward := -cam_basis.z
		forward.y = 0.0
		forward = forward.normalized()

		var right := cam_basis.x
		right.y = 0.0
		right = right.normalized()
		cam_right = right

		direction = (forward * -input_dir.y + right * input_dir.x)
		if direction.length() > 0.0:
			direction = direction.normalized()
	else:
		direction = Vector3(input_dir.x, 0.0, input_dir.y)
		if direction.length() > 0.0:
			direction = direction.normalized()

	var is_walking := sprint_pressed
	var target_speed := walk_speed if is_walking else speed
	var cur_h_vel := Vector2(velocity.x, velocity.z)
	var current_speed := cur_h_vel.length()
	var want_jump: bool = jump_pressed or jump_buffer_timer > 0.0

	_is_currently_air_strafing = false

	if on_floor:
		if want_jump:
			# Check Bunny Hop timing window (SRS 4.1.1: <= 0.1s)
			if bunny_hop_enabled and time_on_floor <= bhop_jump_window:
				# PERFECT BUNNY HOP JUMP!
				velocity.y = jump_velocity
				jump_buffer_timer = 0.0
				time_on_floor = 0.0
				was_on_floor = false
				is_bunny_hopping = true

				# Horizontal velocity is preserved without floor friction!
				if current_speed > 0.1 and bhop_jump_boost > 0.0:
					current_speed = minf(current_speed + bhop_jump_boost, bhop_max_speed)
					cur_h_vel = cur_h_vel.normalized() * current_speed

				bunny_hop_performed.emit(current_speed)
				bunny_hop_executado.emit(current_speed)

				velocity.x = cur_h_vel.x
				velocity.z = cur_h_vel.y
				return
			else:
				# Normal jump after timing window expired or bhop disabled
				velocity.y = jump_velocity
				jump_buffer_timer = 0.0
				was_on_floor = false
				is_bunny_hopping = false

		time_on_floor += delta

		# Rhythm loss penalty (SRS 4.1.4: > 0.1s without jump)
		if time_on_floor > bhop_jump_window:
			if is_bunny_hopping:
				is_bunny_hopping = false
				bunny_hop_failed.emit()
				bunny_hop_falhou.emit()

			if current_speed > target_speed:
				current_speed = target_speed
				cur_h_vel = cur_h_vel.normalized() * current_speed

			# Regular ground acceleration and friction
			if direction.length_squared() > 0.0:
				var wish_h_vel := Vector2(direction.x, direction.z) * target_speed
				var is_counter_strafing := cur_h_vel.length_squared() > 0.1 and cur_h_vel.normalized().dot(wish_h_vel.normalized()) < -0.1
				var accel := ground_acceleration * (counter_strafe_multiplier if is_counter_strafing else 1.0)
				cur_h_vel = cur_h_vel.move_toward(wish_h_vel, accel * delta)
			else:
				cur_h_vel = cur_h_vel.move_toward(Vector2.ZERO, ground_friction * delta)
		else:
			# Within the jump timing window (<= 0.1s):
			# Normal floor friction is NOT applied! Inherent velocity preserved!
			pass

	else: # Airborne (not on_floor)
		was_on_floor = false

		# Air Strafe Acceleration (SRS 4.1.2)
		# Exclusively strafing: lateral keys pressed, no forward/backward
		var is_lateral_only: bool = absf(input_dir.x) > 0.1 and absf(input_dir.y) < 0.1
		if is_lateral_only and bunny_hop_enabled:
			var strafe_side: float = signf(input_dir.x) # -1.0 = left, +1.0 = right

			# Coordinated turning:
			# Turning left: yaw_delta > 0.0001 (positive Y rotation in Godot)
			# Turning right: yaw_delta < -0.0001 (negative Y rotation in Godot)
			var is_turning_left: bool = yaw_delta > 0.0001
			var is_turning_right: bool = yaw_delta < -0.0001
			var is_coordinated: bool = (strafe_side < 0.0 and is_turning_left) or (strafe_side > 0.0 and is_turning_right)

			if is_coordinated:
				_is_currently_air_strafing = true
				var vel_3d := Vector3(cur_h_vel.x, 0.0, cur_h_vel.y)
				var h_speed := vel_3d.length()
				var wish_dir_3d: Vector3 = cam_right * strafe_side

				if h_speed > 0.05:
					var v_norm := vel_3d / h_speed
					var alignment := wish_dir_3d.dot(v_norm)
					var eff := clampf(maxf(alignment, air_strafe_efficiency_min), 0.0, 1.0)

					# a_strafe = air_accel * (u_wish dot v_horizontal)
					var a_mag := air_acceleration * eff
					var delta_speed := a_mag * delta
					var new_speed := minf(h_speed + delta_speed, bhop_max_speed)

					# Vector perpendicular to velocity in the direction of the strafe
					var p_perp: Vector3 = Vector3.UP.cross(v_norm) if strafe_side < 0.0 else v_norm.cross(Vector3.UP)
					var turn_factor := clampf(absf(yaw_delta) * 5.0, 0.05, 0.6)
					var turn_injection := p_perp * (a_mag * delta / maxf(h_speed, 1.0) + turn_factor)
					var new_dir := (v_norm + turn_injection).normalized()

					var new_vel_3d := new_dir * new_speed
					cur_h_vel = Vector2(new_vel_3d.x, new_vel_3d.z)

					air_strafe_accelerated.emit(new_speed, delta_speed)
					air_strafe_acelerado.emit(new_speed, delta_speed)
				else:
					cur_h_vel += Vector2(wish_dir_3d.x, wish_dir_3d.z) * (air_acceleration * delta)

	# Clamping to max allowed bhop speed (SRS 4.1.3)
	if cur_h_vel.length() > bhop_max_speed:
		cur_h_vel = cur_h_vel.normalized() * bhop_max_speed

	velocity.x = cur_h_vel.x
	velocity.z = cur_h_vel.y


func _physics_process(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)
	var jump_pressed := Input.is_action_just_pressed("jump")
	var sprint_pressed := Input.is_action_pressed("sprint")

	var current_cam_yaw := main_camera.global_rotation.y if main_camera else 0.0
	var yaw_delta := accumulated_yaw_delta
	accumulated_yaw_delta = 0.0

	if absf(yaw_delta) < 0.0001 and main_camera:
		yaw_delta = wrapf(current_cam_yaw - _last_camera_yaw, -PI, PI)
	_last_camera_yaw = current_cam_yaw

	process_movement(delta, input_dir, jump_pressed, sprint_pressed, yaw_delta)

	if is_inside_tree():
		move_and_slide()
	update_movement_spread(delta)
