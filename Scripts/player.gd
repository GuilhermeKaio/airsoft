extends CharacterBody3D

signal weapon_swapped(new_weapon: Node, slot_index: int)
signal arma_trocada(nova_arma: Node, slot_index: int)
signal slot_selected(slot_index: int)
signal bullet_tracing_toggled(enabled: bool)
signal tracing_balas_alternado(habilitado: bool)

@export var speed: float = 5.0
@export var sprint_speed: float = 8.5
@export var jump_velocity: float = 4.5
@export var gravity: float = 9.8

@export_group("Inventory & Weapon Slots (SRS Seção 4 & 6)")
@export var weapon: Node
@export var weapon_slot_1: Node
@export var weapon_slot_2: Node
@export var active_slot: int = 1

@onready var main_camera: Camera3D = get_node_or_null("Camera3")


func _ready() -> void:
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

	weapon_swapped.emit(weapon, active_slot)
	arma_trocada.emit(weapon, active_slot)
	slot_selected.emit(active_slot)
	return true


func selecionar_slot(slot_index: int) -> bool:
	return select_slot(slot_index)


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
