extends Control

@export var tamanho: float = 8.0
@export var espessura: float = 2.0
@export var espaco: float = 3.0
@export var cor: Color = Color(1, 1, 1, 0.9)

@export_group("Dynamic Crosshair (SRS Adicionais Seção 7.3)")
@export var spread_gap_multiplier: float = 3.5
@export var player_node: Node
@export var camera_node: Camera3D

var current_movement_spread: float = 0.0
var _current_gap: float = 3.0

@onready var camera3: Camera3D = get_node_or_null("../../Player/Camera3")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_current_gap = espaco
	_resolve_dependencies()


func _resolve_dependencies() -> void:
	if player_node == null and is_inside_tree():
		player_node = get_node_or_null("../../Player")
		if player_node == null and get_tree():
			var players := get_tree().get_nodes_in_group("player")
			if players.size() > 0:
				player_node = players[0]

	if player_node != null:
		if player_node.has_signal("movement_spread_changed") and not player_node.movement_spread_changed.is_connected(_on_movement_spread_changed):
			player_node.movement_spread_changed.connect(_on_movement_spread_changed)

	if camera_node == null:
		camera_node = camera3
		if camera_node == null and player_node != null:
			camera_node = player_node.get_node_or_null("Camera3")


func _on_movement_spread_changed(spread_deg: float, _state: int) -> void:
	set_movement_spread(spread_deg)


func set_movement_spread(spread_deg: float) -> void:
	current_movement_spread = maxf(spread_deg, 0.0)
	var new_gap := espaco + (current_movement_spread * spread_gap_multiplier)
	if absf(new_gap - _current_gap) > 0.01:
		_current_gap = new_gap
		queue_redraw()


func get_current_gap() -> float:
	return _current_gap


func get_movement_spread() -> float:
	return current_movement_spread


func set_spread_gap_multiplier(multiplier: float) -> void:
	spread_gap_multiplier = multiplier
	set_movement_spread(current_movement_spread)


func _process(_delta: float) -> void:
	if camera_node == null or player_node == null:
		_resolve_dependencies()

	var active_cam: Camera3D = camera_node if camera_node != null else camera3
	if active_cam != null and get_viewport():
		visible = get_viewport().get_camera_3d() == active_cam

	if player_node != null and player_node.has_method("get_movement_spread"):
		var p_spread: float = player_node.get_movement_spread()
		if absf(p_spread - current_movement_spread) > 0.01:
			set_movement_spread(p_spread)


func _draw() -> void:
	var dynamic_espaco := _current_gap
	var centro := size / 2.0

	draw_line(centro - Vector2(dynamic_espaco + tamanho, 0), centro - Vector2(dynamic_espaco, 0), cor, espessura)
	draw_line(centro + Vector2(dynamic_espaco, 0), centro + Vector2(dynamic_espaco + tamanho, 0), cor, espessura)

	draw_line(centro - Vector2(0, dynamic_espaco + tamanho), centro - Vector2(0, dynamic_espaco), cor, espessura)
	draw_line(centro + Vector2(0, dynamic_espaco), centro + Vector2(0, dynamic_espaco + tamanho), cor, espessura)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
