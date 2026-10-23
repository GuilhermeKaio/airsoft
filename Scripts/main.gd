extends Node3D

@onready var cam1 = $Player/Camera1
@onready var cam2 = $Player/Camera2
@onready var cam3 = $Player/Camera3
@onready var cam4 = $Player/Camera4
@onready var cam5 = $Player/Camera5


func _ready() -> void:
	if cam3:
		cam3.make_current()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed:
			match event.keycode:
				KEY_1:
					cam1.make_current()
				KEY_2:
					cam2.make_current()
				KEY_3:
					cam3.make_current()
				KEY_4:
					cam4.make_current()
				KEY_5:
					cam5.make_current()
				KEY_T:
					toggle_bullet_tracing()
					if is_inside_tree() and get_viewport():
						get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_bullet_tracing"):
		toggle_bullet_tracing()
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()


func toggle_bullet_tracing() -> bool:
	var player_node = get_node_or_null("Player")
	var enabled: bool = false
	if player_node and player_node.has_method("toggle_bullet_tracing"):
		enabled = player_node.toggle_bullet_tracing()
	else:
		var BBClass = preload("res://Scripts/bb.gd")
		enabled = BBClass.toggle_global_trail_enabled(get_tree())
		var hud = get_node_or_null("HUD/AmmoHUD")
		if hud and hud.has_method("_show_notification"):
			var msg = "TRACING: ATIVADO" if enabled else "TRACING: DESATIVADO"
			hud._show_notification(msg)
	return enabled
