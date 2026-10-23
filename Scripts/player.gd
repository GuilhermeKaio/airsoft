extends CharacterBody3D

@export var speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

@export var weapon: Node

@onready var main_camera: Camera3D = get_node_or_null("Camera3")


func _ready() -> void:
	if weapon == null:
		weapon = get_node_or_null("Weapon")


func get_weapon() -> Node:
	if weapon == null and is_inside_tree():
		weapon = get_node_or_null("Weapon")
	return weapon


func set_weapon(new_weapon: Node) -> void:
	weapon = new_weapon


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


func _unhandled_input(event: InputEvent) -> void:
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


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)

	var direction := Vector3.ZERO
	if main_camera:
		var cam_basis := main_camera.global_transform.basis
		var forward := -cam_basis.z
		forward.y = 0.0
		forward = forward.normalized()

		var right := cam_basis.x
		right.y = 0.0
		right = right.normalized()

		direction = (forward * -input_dir.y + right * input_dir.x)
		if direction.length() > 0.0:
			direction = direction.normalized()

	var current_speed := speed if Input.is_action_pressed("sprint") else sprint_speed

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	move_and_slide()
