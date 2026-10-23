class_name ControlPanelButton
extends AnimatableBody3D

## Botão-Alvo Físico Interativo do Painel de Controle (SRS Adicionais Seção 2.1)
## Suporta duplo acionamento: impacto balístico direto de BB (Layer 5 / on_hit)
## e acionamento por tecla de interação [E] ou clique (press).

signal pressed(button: ControlPanelButton)
signal button_hit(button: ControlPanelButton, bb: Node)

@export var button_id: String = ""
@export var button_text: String = "":
	set(val):
		button_text = val
		if label_3d:
			label_3d.text = val

@export var button_size: Vector2 = Vector2(0.65, 0.28)
@export var is_selected: bool = false:
	set(val):
		is_selected = val
		_update_appearance()

@export_group("Visual Styling")
@export var normal_color: Color = Color(0.18, 0.22, 0.28, 1.0)
@export var selected_color: Color = Color(0.2, 0.85, 0.4, 1.0)
@export var flash_color: Color = Color(1.0, 1.0, 0.6, 1.0)
@export var text_color: Color = Color.WHITE

var collision_shape: CollisionShape3D = null
var mesh_instance: MeshInstance3D = null
var label_3d: Label3D = null
var _material: StandardMaterial3D = null
var _is_animating: bool = false
var _original_pos_z: float = 0.0


func _ready() -> void:
	add_to_group("control_panel_buttons")

	# Layer 5 (Targets = 16) para detecção pela BB balística, e Layer 1 (World = 1)
	collision_layer = 16 | 1
	collision_mask = 0

	_find_or_create_nodes()
	_original_pos_z = position.z
	_update_appearance()


func _find_or_create_nodes() -> void:
	for child in get_children():
		if child is MeshInstance3D and mesh_instance == null:
			mesh_instance = child
		elif child is CollisionShape3D and collision_shape == null:
			collision_shape = child
		elif child is Label3D and label_3d == null:
			label_3d = child

	var scale_factor: float = maxf(button_size.y / 0.28, 1.0)
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(button_size.x, button_size.y, 0.08 * scale_factor)
		collision_shape.shape = box_shape
		add_child(collision_shape)

	if mesh_instance == null:
		mesh_instance = MeshInstance3D.new()
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(button_size.x, button_size.y, 0.06 * scale_factor)
		mesh_instance.mesh = box_mesh
		add_child(mesh_instance)

	if label_3d == null:
		label_3d = Label3D.new()
		label_3d.text = button_text
		label_3d.font_size = int(22 * scale_factor)
		label_3d.outline_size = int(4 * scale_factor)
		label_3d.outline_modulate = Color.BLACK
		label_3d.position = Vector3(0, 0, 0.035 * scale_factor)
		add_child(label_3d)
	else:
		label_3d.font_size = int(22 * scale_factor)
		label_3d.outline_size = int(4 * scale_factor)
		label_3d.position = Vector3(0, 0, 0.035 * scale_factor)
		if not button_text.is_empty():
			label_3d.text = button_text


func _update_appearance() -> void:
	if mesh_instance == null:
		return

	if _material == null:
		_material = StandardMaterial3D.new()
		mesh_instance.material_override = _material

	if is_selected:
		_material.albedo_color = selected_color
		_material.emission_enabled = true
		_material.emission = selected_color
		_material.emission_energy_multiplier = 0.8
		if label_3d:
			label_3d.modulate = Color.WHITE
	else:
		_material.albedo_color = normal_color
		_material.emission_enabled = false
		if label_3d:
			label_3d.modulate = Color(0.85, 0.85, 0.85, 1.0)


## Acionamento por disparo direto de BB (SRS 2.1)
func on_hit(bb: Node = null) -> void:
	button_hit.emit(self, bb)
	press()


func acertar(bb: Node = null) -> void:
	on_hit(bb)


## Acionamento mecânico / tecla de interação [E] / clique (SRS 2.1)
func press() -> void:
	_play_press_feedback()
	pressed.emit(self)


func _play_press_feedback() -> void:
	if _material == null or not is_inside_tree():
		return

	if _is_animating:
		return
	_is_animating = true

	var tween = create_tween()
	if tween:
		# Flash luminoso
		_material.albedo_color = flash_color
		_material.emission_enabled = true
		_material.emission = flash_color
		_material.emission_energy_multiplier = 1.6

		# Efeito mecânico de afundamento ligeiro do botão na placa
		var push_depth = 0.03 * maxf(button_size.y / 0.28, 1.0)
		tween.tween_property(self, "position:z", _original_pos_z - push_depth, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "position:z", _original_pos_z, 0.08).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_callback(func():
			_is_animating = false
			_update_appearance()
		)
	else:
		_update_appearance()
		_is_animating = false
