extends Control

@export var tamanho: float = 8.0
@export var espessura: float = 2.0
@export var espaco: float = 3.0
@export var cor: Color = Color(1, 1, 1, 0.9)

@onready var camera3: Camera3D = get_node("../../Player/Camera3")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _process(_delta: float) -> void:
	visible = get_viewport().get_camera_3d() == camera3


func _draw() -> void:
	var centro := size / 2.0

	draw_line(centro - Vector2(espaco + tamanho, 0), centro - Vector2(espaco, 0), cor, espessura)
	draw_line(centro + Vector2(espaco, 0), centro + Vector2(espaco + tamanho, 0), cor, espessura)

	draw_line(centro - Vector2(0, espaco + tamanho), centro - Vector2(0, espaco), cor, espessura)
	draw_line(centro + Vector2(0, espaco), centro + Vector2(0, espaco + tamanho), cor, espessura)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
