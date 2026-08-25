extends Node3D
@onready var cam1 = $Camera1
@onready var cam2 = $Camera2
@onready var cam3 = $Camera3
@onready var cam4 = $Camera4
@onready var cam5 = $Camera5

func _ready() -> void:
	if cam1:
		cam1.make_current()

func _input(event: InputEvent) -> void:if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed:match event.keycode:
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
