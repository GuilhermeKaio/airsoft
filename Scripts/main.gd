extends Node3D

@onready var cam1 = $Player/Camera1
@onready var cam2 = $Player/Camera2
@onready var cam3 = $Player/Camera3
@onready var cam4 = $Player/Camera4
@onready var cam5 = $Player/Camera5


func _ready() -> void:
	if cam3:
		cam3.make_current()

	var gallery_mgr = get_node_or_null("ShootingGalleryManager")
	var gallery_hud = get_node_or_null("HUD/ShootingGalleryHUD")
	var spawn_area = get_node_or_null("TargetSpawnArea")
	var control_panel = get_node_or_null("ShootingGalleryControlPanel")
	var player_node = get_node_or_null("Player")
	if gallery_mgr:
		if spawn_area and gallery_mgr.has_method("set_spawn_area"):
			gallery_mgr.set_spawn_area(spawn_area)
		if control_panel and control_panel.has_method("setup_manager"):
			control_panel.setup_manager(gallery_mgr)
		if player_node and gallery_mgr.has_method("setup_player"):
			gallery_mgr.setup_player(player_node)
		if gallery_hud and gallery_hud.has_method("setup"):
			gallery_hud.setup(gallery_mgr)
		gallery_mgr.discover_targets(self)

	# Trail de balas começa desabilitada por padrão
	var BBClass = preload("res://Scripts/bb.gd")
	if BBClass and "set_global_trail_enabled" in BBClass:
		BBClass.set_global_trail_enabled(false, get_tree())
	if player_node and player_node.has_method("set_bullet_tracing"):
		player_node.set_bullet_tracing(false)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if not event.ctrl_pressed and event.keycode == KEY_G:
			var gallery_mgr = get_node_or_null("ShootingGalleryManager")
			if gallery_mgr:
				if gallery_mgr.is_session_active:
					gallery_mgr.encerrar_sessao()
				else:
					gallery_mgr.iniciar_sessao()
				if is_inside_tree() and get_viewport():
					get_viewport().set_input_as_handled()
				return
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
