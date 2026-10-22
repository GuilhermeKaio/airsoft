extends CanvasLayer

## Tela de Pause acionada pela tecla ESC
## Não contém botões: pressione ESC para pausar ou despausar o jogo.

@onready var pause_overlay: Control = $PauseOverlay

var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if pause_overlay:
		pause_overlay.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause() -> void:
	if get_tree().paused:
		resume_game()
	else:
		pause_game()

func pause_game() -> void:
	_prev_mouse_mode = Input.mouse_mode
	get_tree().paused = true
	if pause_overlay:
		pause_overlay.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume_game() -> void:
	get_tree().paused = false
	if pause_overlay:
		pause_overlay.visible = false
	if _prev_mouse_mode == Input.MOUSE_MODE_CAPTURED or _prev_mouse_mode == Input.MOUSE_MODE_CONFINED:
		Input.mouse_mode = _prev_mouse_mode
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
