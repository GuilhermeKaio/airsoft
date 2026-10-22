class_name MagazinePickup
extends Area3D

## Interactive collectible magazine in 3D space.
## Allows picking up or swapping magazines in the scenario.
## Validates weapon compatibility, equips the new magazine,
## updates HUD reactively, and optionally drops the previous magazine in place.

const Magazine = preload("res://Scripts/magazine.gd")
const MagazineLoader = preload("res://Scripts/magazine_loader.gd")

signal magazine_picked_up(picker: Node, new_magazine: Magazine, dropped_magazine: Magazine)
signal pickup_rejected(picker: Node, reason: String)

@export var magazine: Magazine
@export var auto_pickup: bool = true
@export var drop_previous_on_swap: bool = true
@export var pickup_cooldown: float = 0.0
@export var rotation_speed: float = 1.2
@export var bob_amplitude: float = 0.08
@export var bob_frequency: float = 2.0
@export var pickup_scene: PackedScene

var _cooldown_timer: float = 0.0
var _elapsed_time: float = 0.0
var _initial_model_y: float = 0.0
var _rejection_timer: float = 0.0
var _overlapping_bodies: Array[Node3D] = []

@onready var model_container: Node3D = get_node_or_null("ModelContainer")
@onready var mesh_instance: MeshInstance3D = get_node_or_null("ModelContainer/MagazineMesh")
@onready var label: Label3D = get_node_or_null("ModelContainer/Label3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")


func _ready() -> void:
	if magazine == null:
		magazine = MagazineLoader.create_pistol_glock(0.25, 25, 25)
	
	_cooldown_timer = pickup_cooldown

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_setup_collision()
	_setup_visuals()

	if model_container:
		_initial_model_y = model_container.position.y


func _setup_collision() -> void:
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.6, 1.8, 1.6)
		collision_shape.shape = shape
		add_child(collision_shape)


func _setup_visuals() -> void:
	if model_container == null:
		model_container = Node3D.new()
		model_container.name = "ModelContainer"
		add_child(model_container)
		_initial_model_y = model_container.position.y

	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "MagazineMesh"
		model_container.add_child(mesh_instance)

	if label == null:
		label = Label3D.new()
		label.name = "Label3D"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = false
		label.font_size = 32
		label.outline_size = 8
		label.position = Vector3(0, 0.55, 0)
		model_container.add_child(label)

	update_visuals()


func update_visuals() -> void:
	if magazine == null:
		return

	if label and _rejection_timer <= 0.0:
		label.text = "%s\n%d / %d BBs (%.2fg)" % [
			magazine.get_type_name(),
			magazine.current_ammo,
			magazine.capacity,
			magazine.get_bb_mass_grams()
		]
		label.modulate = Color(1, 1, 1, 1)

	if mesh_instance:
		_apply_mesh_for_type(magazine.type)


func _apply_mesh_for_type(mag_type: Magazine.Type) -> void:
	var mat := StandardMaterial3D.new()
	mat.roughness = 0.4

	match mag_type:
		Magazine.Type.MAG_SHOTGUN_SHELL:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.08
			cylinder.bottom_radius = 0.08
			cylinder.height = 0.30
			mesh_instance.mesh = cylinder
			mat.albedo_color = Color(0.9, 0.12, 0.12) # Red shell
		Magazine.Type.MAG_RIFLE_STANAG:
			var box := BoxMesh.new()
			box.size = Vector3(0.12, 0.52, 0.22)
			mesh_instance.mesh = box
			mat.albedo_color = Color(0.28, 0.32, 0.36) # Dark metallic STANAG
			mat.metallic = 0.6
		Magazine.Type.MAG_PISTOL_1911:
			var box := BoxMesh.new()
			box.size = Vector3(0.08, 0.40, 0.16)
			mesh_instance.mesh = box
			mat.albedo_color = Color(0.22, 0.22, 0.24) # Gunmetal
			mat.metallic = 0.5
		Magazine.Type.MAG_PISTOL_GLOCK, _:
			var box := BoxMesh.new()
			box.size = Vector3(0.10, 0.42, 0.18)
			mesh_instance.mesh = box
			mat.albedo_color = Color(0.12, 0.12, 0.14) # Polymer black Glock mag
			mat.roughness = 0.6

	mesh_instance.material_override = mat

	mesh_instance.material_override = mat


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0 and auto_pickup:
			for b in _overlapping_bodies:
				if is_instance_valid(b) and try_pickup(b):
					return

	if _rejection_timer > 0.0:
		_rejection_timer -= delta
		if _rejection_timer <= 0.0:
			update_visuals()

	# Floating and bobbing animation
	if model_container:
		_elapsed_time += delta
		model_container.rotate_y(rotation_speed * delta)
		model_container.position.y = _initial_model_y + sin(_elapsed_time * bob_frequency) * bob_amplitude


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		for body in _overlapping_bodies:
			if is_instance_valid(body) and try_pickup(body):
				if is_inside_tree() and get_viewport():
					get_viewport().set_input_as_handled()
				return


func _on_body_entered(body: Node3D) -> void:
	if not _overlapping_bodies.has(body):
		_overlapping_bodies.append(body)

	if auto_pickup and _cooldown_timer <= 0.0:
		try_pickup(body)


func _on_body_exited(body: Node3D) -> void:
	_overlapping_bodies.erase(body)


## Attempts to collect or swap this magazine with the given collector's equipped weapon.
func try_pickup(collector: Node) -> bool:
	if _cooldown_timer > 0.0:
		return false

	var weapon: Node = _find_weapon(collector)
	if weapon == null or magazine == null:
		return false

	var weapon_compat_type: int = -1
	if "compatible_magazine_type" in weapon:
		weapon_compat_type = weapon.compatible_magazine_type

	# Validate compatibility
	if weapon_compat_type != magazine.type:
		if weapon.has_method("trigger_incompatible_magazine"):
			weapon.trigger_incompatible_magazine()
		elif weapon.has_signal("incompatible_magazine"):
			weapon.incompatible_magazine.emit()
		
		pickup_rejected.emit(collector, "incompatible")
		_show_rejection_feedback()
		return false

	# Compatible: perform swap
	var previous_mag: Magazine = null
	if weapon.has_method("swap_magazine"):
		previous_mag = weapon.swap_magazine(magazine)
	elif weapon.has_method("equip_magazine"):
		if "equipped_magazine" in weapon:
			previous_mag = weapon.equipped_magazine
		weapon.equip_magazine(magazine)

	magazine_picked_up.emit(collector, magazine, previous_mag)

	# Improvement: Drop previous magazine at this location preserving remaining ammo
	if drop_previous_on_swap and previous_mag != null:
		_spawn_dropped_pickup(previous_mag)

	if is_inside_tree():
		queue_free()
	return true


func _spawn_dropped_pickup(dropped_mag: Magazine) -> Node:
	var instance: Node = null
	if pickup_scene != null:
		instance = pickup_scene.instantiate()
	else:
		var scene_res = load("res://Scenes/magazine_pickup.tscn")
		if scene_res is PackedScene:
			instance = scene_res.instantiate()
		else:
			instance = get_script().new()

	if instance != null:
		instance.set("magazine", dropped_mag)
		instance.set("drop_previous_on_swap", drop_previous_on_swap)
		instance.set("pickup_cooldown", 1.0) # 1 second cooldown prevents instant re-collection
		
		var spawn_parent: Node = get_parent()
		if spawn_parent == null and is_inside_tree():
			spawn_parent = get_tree().current_scene
		
		if spawn_parent != null:
			spawn_parent.add_child(instance)
			if is_inside_tree() and "global_position" in instance:
				instance.global_position = global_position
			if instance.has_method("update_visuals"):
				instance.update_visuals()
	return instance


func _show_rejection_feedback() -> void:
	_rejection_timer = 1.5
	if label:
		label.text = "INCOMPATÍVEL COM ESTA ARMA!\n(%s)" % magazine.get_type_name()
		label.modulate = Color(1.0, 0.2, 0.2, 1.0)


func _find_weapon(node: Node) -> Node:
	if node == null:
		return null
	if "compatible_magazine_type" in node and node.has_method("equip_magazine"):
		return node
	if node.has_method("get_weapon"):
		var w = node.get_weapon()
		if w != null:
			return w
	if node.has_node("Weapon"):
		return node.get_node("Weapon")
	for child in node.get_children():
		if "compatible_magazine_type" in child and child.has_method("equip_magazine"):
			return child
	return null


## Setup magazine programmatically
func setup_magazine(p_type: Magazine.Type, p_capacity: int, p_ammo: int, p_mass_kg: float) -> void:
	magazine = Magazine.new(p_type, p_capacity, p_ammo, p_mass_kg)
	update_visuals()
