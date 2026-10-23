class_name ShootingGalleryControlPanel
extends Node3D

## Grande Painel de Controle no Estande de Tiro (SRS Adicionais Seção 2.1)
## 3D World UI interativo posicionado no cenário junto à bancada de tiro.
## Permite seleção dos 3 modos de jogo, 3 velocidades de sumir e acionamento
## por disparo direto de BB ou tecla de interação [E].

signal mode_selected(mode: int)
signal despawn_speed_selected(speed: int)
signal session_toggled()
signal button_activated(button_id: String)

@export var panel_scale: float = 5.0
@export var manager_path: NodePath = ^""
@export var manager: ShootingGalleryManager = null
@export var enable_e_interaction: bool = false

# Display Labels
var title_label: Label3D = null
var mode_display_label: Label3D = null
var speed_display_label: Label3D = null
var high_score_label: Label3D = null
var status_label: Label3D = null
var interaction_prompt: Label3D = null

# Proximity Area
var proximity_area: Area3D = null
var _player_in_range: bool = false
var _overlapping_players: Array[Node] = []

# Buttons dictionary: button_id -> ControlPanelButton
var _buttons: Dictionary = {}


func _ready() -> void:
	add_to_group("shooting_gallery_control_panel")
	_find_or_create_components()
	_connect_manager()
	call_deferred("_connect_manager")
	update_display()


func _find_or_create_components() -> void:
	# Encontra labels e botões filhos existentes
	for child in get_children():
		if child is ControlPanelButton:
			_register_button(child)
		elif child is Area3D and proximity_area == null:
			proximity_area = child

	# Se a cena não tiver os botões/labels criados manualmente, gera proceduralmente
	if _buttons.is_empty():
		_generate_procedural_panel()

	_setup_proximity_area()


func _register_button(btn: ControlPanelButton) -> void:
	if btn.button_id.is_empty():
		return
	_buttons[btn.button_id] = btn
	if not btn.pressed.is_connected(_on_button_pressed):
		btn.pressed.connect(func(b): _on_button_pressed(b.button_id))


func _setup_proximity_area() -> void:
	var s: float = panel_scale
	if proximity_area == null:
		proximity_area = Area3D.new()
		proximity_area.name = "ProximityArea"
		var shape = CollisionShape3D.new()
		var box = BoxShape3D.new()
		box.size = Vector3(4.0 * s, 3.0 * s, 4.0 * s)
		shape.shape = box
		shape.position = Vector3(0, 1.5 * s, 1.5 * s)
		proximity_area.add_child(shape)
		add_child(proximity_area)

	# Monitora Layer 2 (Player)
	proximity_area.collision_layer = 0
	proximity_area.collision_mask = 2 # Player layer

	if not proximity_area.body_entered.is_connected(_on_body_entered):
		proximity_area.body_entered.connect(_on_body_entered)
	if not proximity_area.body_exited.is_connected(_on_body_exited):
		proximity_area.body_exited.connect(_on_body_exited)


func _connect_manager() -> void:
	if manager == null and not manager_path.is_empty():
		manager = get_node_or_null(manager_path)
	if manager == null and is_inside_tree():
		if get_tree().current_scene:
			manager = get_tree().current_scene.find_child("ShootingGalleryManager", true, false)
		if manager == null:
			manager = get_tree().root.find_child("ShootingGalleryManager", true, false)

	if manager:
		if not manager.configuracao_alterada.is_connected(_on_configuracao_alterada):
			manager.configuracao_alterada.connect(_on_configuracao_alterada)
		if not manager.pontuacao_alterada.is_connected(_on_pontuacao_alterada):
			manager.pontuacao_alterada.connect(_on_pontuacao_alterada)
		if not manager.sessao_iniciada.is_connected(_on_sessao_iniciada):
			manager.sessao_iniciada.connect(_on_sessao_iniciada)
		if not manager.sessao_encerrada.is_connected(_on_sessao_encerrada):
			manager.sessao_encerrada.connect(_on_sessao_encerrada)

		update_display()


func setup_manager(mgr: ShootingGalleryManager) -> void:
	manager = mgr
	_connect_manager()


func _unhandled_input(event: InputEvent) -> void:
	if not enable_e_interaction or not _player_in_range:
		return

	if event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E):
		# Tecla [E]: desvinculada por padrão (apenas se enable_e_interaction for explicitamente ativado)
		interact()
		if is_inside_tree() and get_viewport():
			get_viewport().set_input_as_handled()


## Ação de interação rápida com a tecla [E] no estande
func interact() -> void:
	if manager:
		toggle_session()
	else:
		press_button("session_toggle")


func _on_body_entered(body: Node3D) -> void:
	if not _overlapping_players.has(body):
		_overlapping_players.append(body)
	_player_in_range = true
	if interaction_prompt:
		interaction_prompt.visible = true


func _on_body_exited(body: Node3D) -> void:
	if _overlapping_players.has(body):
		_overlapping_players.erase(body)
	_player_in_range = not _overlapping_players.is_empty()
	if interaction_prompt and not _player_in_range:
		interaction_prompt.visible = false


## Aciona um botão pelo seu ID textual (acionado por BB ou [E])
func press_button(button_id: String) -> void:
	if _buttons.has(button_id):
		var btn: ControlPanelButton = _buttons[button_id]
		btn.press()
	else:
		_on_button_pressed(button_id)


func _on_button_pressed(button_id: String) -> void:
	button_activated.emit(button_id)

	match button_id:
		"mode_time_attack":
			select_mode(ShootingGalleryManager.GameMode.TIME_ATTACK)
		"mode_free_practice":
			select_mode(ShootingGalleryManager.GameMode.FREE_PRACTICE)
		"mode_time_attack_hard":
			select_mode(ShootingGalleryManager.GameMode.TIME_ATTACK_HARD)

		"speed_long":
			select_despawn_speed(ShootingGalleryManager.DespawnSpeed.LONGA)
		"speed_medium":
			select_despawn_speed(ShootingGalleryManager.DespawnSpeed.MEDIA)
		"speed_short":
			select_despawn_speed(ShootingGalleryManager.DespawnSpeed.CURTA)

		"session_toggle":
			toggle_session()
		"score_reset":
			reset_score()

	update_display()


func select_mode(mode: int) -> void:
	if manager:
		manager.set_game_mode(mode)
	mode_selected.emit(mode)
	update_display()


func select_despawn_speed(speed: int) -> void:
	if manager:
		manager.set_despawn_speed(speed)
	despawn_speed_selected.emit(speed)
	update_display()


func toggle_session() -> void:
	if manager:
		if manager.session_mode == ShootingGalleryManager.GameMode.FREE_PRACTICE:
			# Treino Livre não possui sessão formal nem tela de fim de sessão
			if manager.is_session_active:
				manager.is_session_active = false
				if manager.spawn_area and is_instance_valid(manager.spawn_area):
					manager.spawn_area.clear_all_targets()
			else:
				manager.is_session_active = true
				if manager.spawn_area and is_instance_valid(manager.spawn_area):
					manager._setup_targets_for_session()
		else:
			if manager.is_session_active:
				manager.encerrar_sessao()
			else:
				manager.iniciar_sessao()
	session_toggled.emit()
	update_display()


func reset_score() -> void:
	if manager:
		manager.zerar_pontuacao()
	update_display()


func _on_configuracao_alterada(_modo: int, _velocidade: int) -> void:
	update_display()


func _on_pontuacao_alterada(_pts: int, _delta: int) -> void:
	update_display()


func _on_sessao_iniciada(_tempo: float, _modo: int = 0) -> void:
	update_display()


func _on_sessao_encerrada(_pts: int, _acc: float, _h: int, _p: int) -> void:
	update_display()


## Atualiza os textos dos mostradores 3D e o estado visual selecionado dos botões
func update_display() -> void:
	var cur_mode: int = 0
	var cur_speed: int = 1
	var high_score: int = 0
	var score_val: int = 0
	var is_active: bool = false
	var time_rem: float = 60.0

	if manager:
		cur_mode = int(manager.session_mode)
		cur_speed = int(manager.current_despawn_speed)
		high_score = manager.get_high_score(cur_mode)
		score_val = manager.score
		is_active = manager.is_session_active
		time_rem = manager.time_remaining

	# Atualiza botões de modo
	if _buttons.has("mode_time_attack"):
		_buttons["mode_time_attack"].is_selected = (cur_mode == ShootingGalleryManager.GameMode.TIME_ATTACK)
	if _buttons.has("mode_free_practice"):
		_buttons["mode_free_practice"].is_selected = (cur_mode == ShootingGalleryManager.GameMode.FREE_PRACTICE)
	if _buttons.has("mode_time_attack_hard"):
		_buttons["mode_time_attack_hard"].is_selected = (cur_mode == ShootingGalleryManager.GameMode.TIME_ATTACK_HARD)

	# Atualiza botões de velocidade de sumir
	if _buttons.has("speed_long"):
		_buttons["speed_long"].is_selected = (cur_speed == ShootingGalleryManager.DespawnSpeed.LONGA)
	if _buttons.has("speed_medium"):
		_buttons["speed_medium"].is_selected = (cur_speed == ShootingGalleryManager.DespawnSpeed.MEDIA)
	if _buttons.has("speed_short"):
		_buttons["speed_short"].is_selected = (cur_speed == ShootingGalleryManager.DespawnSpeed.CURTA)

	# Nomes dos modos e velocidades
	var mode_names = ["TIME ATTACK", "TREINO LIVRE", "TIME ATTACK HARD"]
	var speed_names = ["LONGA (~3.0s)", "MÉDIA (~1.8s)", "CURTA (~0.9s)"]

	if mode_display_label:
		mode_display_label.text = "MODO ATIVO:\n%s" % mode_names[cur_mode]
	if speed_display_label:
		speed_display_label.text = "JANELA SUMIR:\n%s" % speed_names[cur_speed]
	if high_score_label:
		high_score_label.text = "RECORDE:\n%d pts" % high_score

	if status_label:
		var status_str = "EM ANDAMENTO" if is_active else "PRONTO"
		if cur_mode == ShootingGalleryManager.GameMode.FREE_PRACTICE:
			status_label.text = "STATUS: %s | PONTUAÇÃO: %d" % [status_str, score_val]
		else:
			status_label.text = "STATUS: %s | TEMPO: %.1fs | PONTUAÇÃO: %d" % [status_str, time_rem, score_val]


func _generate_procedural_panel() -> void:
	var s: float = panel_scale

	# Painel Base / Moldura (Fundo escuro tático)
	var panel_mesh = MeshInstance3D.new()
	panel_mesh.name = "BackingPlate"
	var box = BoxMesh.new()
	box.size = Vector3(3.2 * s, 2.3 * s, 0.12 * s)
	panel_mesh.mesh = box
	panel_mesh.position = Vector3(0, 1.45 * s, 0)

	var plate_mat = StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.12, 0.14, 0.18, 1.0)
	plate_mat.roughness = 0.6
	panel_mesh.material_override = plate_mat
	add_child(panel_mesh)

	# Suportes / Pés do painel
	var stand_left = MeshInstance3D.new()
	var stand_mesh = BoxMesh.new()
	stand_mesh.size = Vector3(0.08 * s, 1.45 * s, 0.08 * s)
	stand_left.mesh = stand_mesh
	stand_left.position = Vector3(-1.4 * s, 0.725 * s, 0)
	stand_left.material_override = plate_mat
	add_child(stand_left)

	var stand_right = MeshInstance3D.new()
	stand_right.mesh = stand_mesh
	stand_right.position = Vector3(1.4 * s, 0.725 * s, 0)
	stand_right.material_override = plate_mat
	add_child(stand_right)

	# Título principal do painel
	title_label = Label3D.new()
	title_label.name = "TitleLabel"
	title_label.text = "ESTANDE DE TIRO - PAINEL DE CONTROLE"
	title_label.font_size = int(32 * s)
	title_label.outline_size = int(5 * s)
	title_label.outline_modulate = Color.BLACK
	title_label.position = Vector3(0, 2.42 * s, 0.07 * s)
	add_child(title_label)

	# Subtítulos das colunas
	var col1_title = Label3D.new()
	col1_title.text = "MODO DE JOGO"
	col1_title.font_size = int(20 * s)
	col1_title.modulate = Color(0.3, 0.8, 1.0)
	col1_title.outline_size = int(3 * s)
	col1_title.position = Vector3(-0.95 * s, 2.15 * s, 0.07 * s)
	add_child(col1_title)

	var col2_title = Label3D.new()
	col2_title.text = "VELOCIDADE DE SUMIR"
	col2_title.font_size = int(20 * s)
	col2_title.modulate = Color(1.0, 0.75, 0.2)
	col2_title.outline_size = int(3 * s)
	col2_title.position = Vector3(0.95 * s, 2.15 * s, 0.07 * s)
	add_child(col2_title)

	# Botões da Coluna 1: Modos de Jogo (SRS 2.1)
	_create_button("mode_time_attack", "Time Attack", Vector3(-0.95 * s, 1.85 * s, 0.07 * s), Vector2(0.85 * s, 0.26 * s))
	_create_button("mode_free_practice", "Free Practice", Vector3(-0.95 * s, 1.52 * s, 0.07 * s), Vector2(0.85 * s, 0.26 * s))
	_create_button("mode_time_attack_hard", "Hard Attack", Vector3(-0.95 * s, 1.19 * s, 0.07 * s), Vector2(0.85 * s, 0.26 * s))

	# Botões da Coluna 2: Janela de Desaparecimento (SRS 2.1)
	_create_button("speed_long", "Longa (3.0s)", Vector3(0.95 * s, 1.85 * s, 0.07 * s), Vector2(0.85 * s, 0.26 * s))
	_create_button("speed_medium", "Média (1.8s)", Vector3(0.95 * s, 1.52 * s, 0.07 * s), Vector2(0.85 * s, 0.26 * s))
	_create_button("speed_short", "Curta (0.9s)", Vector3(0.95 * s, 1.19 * s, 0.07 * s), Vector2(0.85 * s, 0.26 * s))

	# Mostradores centrais de High Score e Modo Ativo
	high_score_label = Label3D.new()
	high_score_label.name = "HighScoreLabel"
	high_score_label.text = "RECORDE:\n0 pts"
	high_score_label.font_size = int(22 * s)
	high_score_label.outline_size = int(4 * s)
	high_score_label.modulate = Color(1.0, 0.85, 0.2)
	high_score_label.position = Vector3(0, 1.85 * s, 0.07 * s)
	add_child(high_score_label)

	mode_display_label = Label3D.new()
	mode_display_label.name = "ModeDisplayLabel"
	mode_display_label.text = "MODO ATIVO:\nTIME ATTACK"
	mode_display_label.font_size = int(18 * s)
	mode_display_label.outline_size = int(3 * s)
	mode_display_label.position = Vector3(0, 1.48 * s, 0.07 * s)
	add_child(mode_display_label)

	speed_display_label = Label3D.new()
	speed_display_label.name = "SpeedDisplayLabel"
	speed_display_label.text = "JANELA SUMIR:\nMÉDIA (1.8s)"
	speed_display_label.font_size = int(16 * s)
	speed_display_label.outline_size = int(3 * s)
	speed_display_label.position = Vector3(0, 1.18 * s, 0.07 * s)
	add_child(speed_display_label)

	# Botões de Ação na base do painel (Iniciar Sessão / Zerar)
	_create_button("session_toggle", "[ INICIAR / PARAR ]", Vector3(-0.6 * s, 0.78 * s, 0.07 * s), Vector2(0.95 * s, 0.28 * s))
	_create_button("score_reset", "[ ZERAR PONTOS ]", Vector3(0.6 * s, 0.78 * s, 0.07 * s), Vector2(0.95 * s, 0.28 * s))

	# Linha inferior de status da sessão
	status_label = Label3D.new()
	status_label.name = "StatusLabel"
	status_label.text = "STATUS: PRONTO | PONTUAÇÃO: 0"
	status_label.font_size = int(20 * s)
	status_label.outline_size = int(4 * s)
	status_label.modulate = Color(0.3, 0.95, 0.4)
	status_label.position = Vector3(0, 0.48 * s, 0.07 * s)
	add_child(status_label)

	# Dica de acionamento
	interaction_prompt = Label3D.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.text = "[DISPARE NA PLACA PARA ACIONAR]"
	interaction_prompt.font_size = int(16 * s)
	interaction_prompt.outline_size = int(3 * s)
	interaction_prompt.modulate = Color(1.0, 1.0, 0.4)
	interaction_prompt.position = Vector3(0, 0.25 * s, 0.07 * s)
	interaction_prompt.visible = false
	add_child(interaction_prompt)


func _create_button(id: String, text_label: String, pos: Vector3, sz: Vector2) -> ControlPanelButton:
	var btn = ControlPanelButton.new()
	btn.name = "Button_" + id
	btn.button_id = id
	btn.button_text = text_label
	btn.button_size = sz
	btn.position = pos
	add_child(btn)
	_register_button(btn)
	return btn
