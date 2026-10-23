extends CharacterBody3D

@export var speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

@onready var main_camera: Camera3D = $Camera3
@onready var weapon: Node = get_node_or_null("Weapon")


func get_weapon() -> Node:
	if weapon == null:
		weapon = get_node_or_null("Weapon")
	return weapon


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_back") - Input.get_action_strength("move_forward")
	)

	var cam_basis := main_camera.global_transform.basis
	var forward := -cam_basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := cam_basis.x
	right.y = 0.0
	right = right.normalized()

	var direction := (forward * -input_dir.y + right * input_dir.x)
	if direction.length() > 0.0:
		direction = direction.normalized()

	var current_speed := speed if Input.is_action_pressed("sprint") else sprint_speed

	velocity.x = direction.x * current_speed
	velocity.z = direction.z * current_speed

	move_and_slide()
