class_name WeaponPickup
extends Area3D

const Weapon = preload("res://Scripts/weapon.gd")
const Magazine = preload("res://Scripts/magazine.gd")
const MagazineLoader = preload("res://Scripts/magazine_loader.gd")

signal weapon_picked_up(picker: Node, new_weapon: Node, dropped_weapon: Node)
signal pickup_rejected(picker: Node, reason: String)

@export var weapon_model: Weapon.WeaponModel = Weapon.WeaponModel.RIFLE
@export var magazine: Magazine
@export var auto_pickup: bool = false
@export var drop_previous_on_swap: bool = true
@export var target_slot: int = 0 # 0 = slot ativo do jogador, 1 = primária, 2 = secundária
@export var pickup_cooldown: float = 0.0
@export var rotation_speed: float = 1.2
@export var bob_amplitude: float = 0.08
@export var bob_frequency: float = 2.0
@export var pickup_scene: PackedScene

# Configurações preservadas da arma
@export var spring_k: float = 1192.0
@export var spring_x: float = 0.05
@export var nominal_energy_joules: float = 1.49
@export var spin_rad_s: float = 1200.0
@export var fire_mode: Weapon.FireMode = Weapon.FireMode.SEMI

var _cooldown_timer: float = 0.0
var _elapsed_time: float = 0.0
var _initial_model_y: float = 0.0
var _overlapping_bodies: Array[Node3D] = []

@onready var model_container: Node3D = get_node_or_null("ModelContainer")
@onready var mesh_instance: MeshInstance3D = get_node_or_null("ModelContainer/WeaponMesh")
@onready var label: Label3D = get_node_or_null("ModelContainer/Label3D")
@onready var collision_shape: CollisionShape3D = get_node_or_null("CollisionShape3D")


func _ready() -> void:
	_cooldown_timer = pickup_cooldown

	if magazine == null:
		_create_default_magazine()

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)

	_setup_collision()
	_setup_visuals()

	if model_container:
		_initial_model_y = model_container.position.y


func _create_default_magazine() -> void:
	match weapon_model:
		Weapon.WeaponModel.SHOTGUN:
			magazine = MagazineLoader.create_shotgun_shell(0.20, 30, 30)
		Weapon.WeaponModel.RIFLE:
			magazine = MagazineLoader.create_rifle_stanag(0.25, 30, 30)
		Weapon.WeaponModel.PISTOL_1911:
			magazine = MagazineLoader.create_pistol_1911(0.20, 15, 15)
		Weapon.WeaponModel.PISTOL_GLOCK, _:
			magazine = MagazineLoader.create_pistol_glock(0.20, 25, 25)


func _setup_collision() -> void:
	if collision_layer == 1 and collision_mask == 1:
		collision_layer = 32
		collision_mask = 2

	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		var shape := BoxShape3D.new()
		shape.size = Vector3(1.8, 1.8, 1.8)
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
		mesh_instance.name = "WeaponMesh"
		model_container.add_child(mesh_instance)

	if label == null:
		label = Label3D.new()
		label.name = "Label3D"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = false
		label.font_size = 30
		label.outline_size = 8
		label.position = Vector3(0, 0.65, 0)
		model_container.add_child(label)

	update_visuals()


func update_visuals() -> void:
	if mesh_instance:
		_apply_mesh_for_model(weapon_model)

	if label:
		var ammo_str := ""
		if magazine:
			ammo_str = "\n%d / %d BBs (%.2fg)" % [magazine.current_ammo, magazine.capacity, magazine.get_bb_mass_grams()]
		var model_name := _get_model_display_name()
		label.text = "%s%s\n[E] Trocar Arma" % [model_name, ammo_str]
		label.modulate = Color(1.0, 0.95, 0.3, 1.0)


func _get_model_display_name() -> String:
	match weapon_model:
		Weapon.WeaponModel.SHOTGUN:
			return "Shotgun Calibre 12"
		Weapon.WeaponModel.RIFLE:
			return "Rifle M4 / STANAG"
		Weapon.WeaponModel.PISTOL_1911:
			return "Colt 1911"
		Weapon.WeaponModel.PISTOL_GLOCK, _:
			return "Pistol Glock"


func _apply_mesh_for_model(model: Weapon.WeaponModel) -> void:
	var mesh_path := ""
	match model:
		Weapon.WeaponModel.SHOTGUN:
			mesh_path = "res://Assets/Shotgun.obj"
		Weapon.WeaponModel.RIFLE:
			mesh_path = "res://Assets/Rifle.obj"
		Weapon.WeaponModel.PISTOL_1911:
			mesh_path = "res://Assets/Pistol1911.obj"
		Weapon.WeaponModel.PISTOL_GLOCK, _:
			mesh_path = "res://Assets/PistolGlock.obj"

	var obj_mesh = load(mesh_path)
	if obj_mesh and mesh_instance:
		mesh_instance.mesh = obj_mesh
		mesh_instance.scale = Vector3(2.5, 2.5, 2.5)
		mesh_instance.rotation_degrees = Vector3(0, 0, 0)
		var mat := StandardMaterial3D.new()
		var tex = load("res://Assets/Textures/colormap.png")
		if tex:
			mat.albedo_texture = tex
		mat.roughness = 0.4
		mesh_instance.material_override = mat


func _process(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta
		if _cooldown_timer <= 0.0 and auto_pickup:
			for b in _overlapping_bodies:
				if is_instance_valid(b) and try_pickup(b):
					return

	if model_container:
		_elapsed_time += delta
		model_container.rotate_y(rotation_speed * delta)
		model_container.position.y = _initial_model_y + sin(_elapsed_time * bob_frequency) * bob_amplitude


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
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


func try_pickup(collector: Node) -> bool:
	if _cooldown_timer > 0.0:
		return false

	var player := _find_player(collector)
	if player == null:
		return false

	# Determina qual slot receberá a arma
	var slot_index := target_slot
	if slot_index <= 0:
		if player.has_method("get_active_slot"):
			slot_index = player.get_active_slot()
		else:
			slot_index = 1

	var old_weapon: Node = null
	if player.has_method("get_weapon_in_slot"):
		old_weapon = player.get_weapon_in_slot(slot_index)
	elif player.has_method("get_weapon"):
		old_weapon = player.get_weapon()

	# Cria a nova arma a ser equipada
	var weapon_scene = load("res://Scenes/Weapon.tscn")
	var new_weapon: Weapon = null
	if weapon_scene is PackedScene:
		new_weapon = weapon_scene.instantiate()
	else:
		new_weapon = Weapon.new()

	new_weapon.configure_weapon_preset(weapon_model)
	new_weapon.spring_k = spring_k
	new_weapon.spring_x = spring_x
	new_weapon.nominal_energy_joules = nominal_energy_joules
	new_weapon.spin_rad_s = spin_rad_s
	new_weapon.fire_mode = fire_mode

	if magazine != null:
		new_weapon.equipped_magazine = magazine

	# Equipa na posição/slot do jogador
	if player.has_method("equip_weapon_in_slot"):
		player.equip_weapon_in_slot(new_weapon, slot_index)
	elif player.has_method("set_weapon"):
		player.set_weapon(new_weapon)

	# Se drop_previous_on_swap for verdadeiro e havia uma arma no slot, solta-a no chão
	var dropped_pickup: Node = null
	if drop_previous_on_swap and old_weapon != null:
		dropped_pickup = _spawn_dropped_pickup(old_weapon)
		old_weapon.queue_free()

	weapon_picked_up.emit(player, new_weapon, old_weapon)

	if is_inside_tree():
		queue_free()
	return true


func _spawn_dropped_pickup(old_weapon: Node) -> Node:
	var instance: Node = null
	if pickup_scene != null:
		instance = pickup_scene.instantiate()
	else:
		var scene_res = load("res://Scenes/weapon_pickup.tscn")
		if scene_res is PackedScene:
			instance = scene_res.instantiate()
		else:
			instance = get_script().new()

	if instance != null:
		if "weapon_model" in old_weapon:
			instance.set("weapon_model", old_weapon.weapon_model)
		if "equipped_magazine" in old_weapon and old_weapon.equipped_magazine != null:
			instance.set("magazine", old_weapon.equipped_magazine)
		if "spring_k" in old_weapon:
			instance.set("spring_k", old_weapon.spring_k)
		if "spring_x" in old_weapon:
			instance.set("spring_x", old_weapon.spring_x)
		if "nominal_energy_joules" in old_weapon:
			instance.set("nominal_energy_joules", old_weapon.nominal_energy_joules)
		if "spin_rad_s" in old_weapon:
			instance.set("spin_rad_s", old_weapon.spin_rad_s)
		if "fire_mode" in old_weapon:
			instance.set("fire_mode", old_weapon.fire_mode)

		instance.set("drop_previous_on_swap", drop_previous_on_swap)
		instance.set("pickup_cooldown", 1.0)

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


func _find_player(node: Node) -> Node:
	if node == null:
		return null
	if node.has_method("equip_weapon_in_slot") and node.has_method("get_weapon"):
		return node
	if node.get_parent() and node.get_parent().has_method("equip_weapon_in_slot"):
		return node.get_parent()
	return null


func setup_weapon(p_model: Weapon.WeaponModel, p_mag: Magazine = null) -> void:
	weapon_model = p_model
	if p_mag != null:
		magazine = p_mag
	else:
		_create_default_magazine()
	update_visuals()
