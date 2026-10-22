extends Control

# Crosshair simples desenhado no centro da tela.

@export var tamanho: float = 8.0      # comprimento de cada tracinho
@export var espessura: float = 2.0    # espessura da linha
@export var espaco: float = 3.0       # espaço vazio no centro (gap)
@export var cor: Color = Color(1, 1, 1, 0.9)

@onready var camera3: Camera3D = get_node("../../Player/Camera3")

func _ready() -> void:
	# Ocupa a tela inteira e não bloqueia cliques do mouse.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func _process(_delta: float) -> void:
	# Só mostra a mira quando a Camera3 é a câmera ativa do viewport.
	visible = get_viewport().get_camera_3d() == camera3

func _draw() -> void:
	var centro := size / 2.0

	# Linha horizontal (esquerda e direita do centro)
	draw_line(centro - Vector2(espaco + tamanho, 0), centro - Vector2(espaco, 0), cor, espessura)
	draw_line(centro + Vector2(espaco, 0), centro + Vector2(espaco + tamanho, 0), cor, espessura)

	# Linha vertical (cima e baixo do centro)
	draw_line(centro - Vector2(0, espaco + tamanho), centro - Vector2(0, espaco), cor, espessura)
	draw_line(centro + Vector2(0, espaco), centro + Vector2(0, espaco + tamanho), cor, espessura)

func _notification(what: int) -> void:
	# Redesenha se a janela for redimensionada.
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
