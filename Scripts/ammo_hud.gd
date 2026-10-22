extends Label

## HUD de munição. Só aparece quando a Camera3 é a câmera ativa do viewport,
## igual ao comportamento da mira (crosshair.gd).

@onready var camera3: Camera3D = get_node("../../Player/Camera3")
@onready var arma = get_node("../../Player/Arma")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -240.0
	offset_top = -70.0
	offset_right = -24.0
	offset_bottom = -24.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 32)
	add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)


func _process(_delta: float) -> void:
	visible = get_viewport().get_camera_3d() == camera3

	text = "%d / %d" % [arma.current_ammo, arma.magazine_capacity]
