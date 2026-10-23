class_name ShootingGalleryHUD
extends Control

## HUD Reativo para o Estande de Tiro (Shooting Gallery HUD)
## Exibe pontuação, multiplicador de combo, tempo restante, precisão e mensagens de impacto.

@export var gallery_manager_path: NodePath = ^"../../ShootingGalleryManager"
@onready var gallery_manager: ShootingGalleryManager = get_node_or_null(gallery_manager_path)

@onready var score_label: Label = find_child("ScoreLabel", true, false)
@onready var combo_label: Label = find_child("ComboLabel", true, false)
@onready var timer_label: Label = find_child("TimerLabel", true, false)
@onready var stats_label: Label = find_child("StatsLabel", true, false)
@onready var notification_label: Label = find_child("NotificationLabel", true, false)
@onready var summary_panel: PanelContainer = find_child("SummaryPanel", true, false)
@onready var summary_label: Label = find_child("SummaryContentLabel", true, false)
@onready var restart_button: Button = find_child("RestartButton", true, false)
@onready var close_button: Button = find_child("CloseButton", true, false)

var _notification_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if summary_panel:
		summary_panel.visible = false
		summary_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_find_and_setup_manager()
	call_deferred("_find_and_setup_manager")

	if restart_button and not restart_button.pressed.is_connected(_on_restart_pressed):
		restart_button.pressed.connect(_on_restart_pressed)
	if close_button and not close_button.pressed.is_connected(_on_close_pressed):
		close_button.pressed.connect(_on_close_pressed)


func _find_and_setup_manager() -> void:
	if gallery_manager == null:
		gallery_manager = get_node_or_null(gallery_manager_path)
	if gallery_manager == null and is_inside_tree():
		if get_tree().current_scene:
			gallery_manager = get_tree().current_scene.get_node_or_null("ShootingGalleryManager")
		if gallery_manager == null and get_parent() and get_parent().get_parent():
			gallery_manager = get_parent().get_parent().get_node_or_null("ShootingGalleryManager")
		if gallery_manager == null:
			gallery_manager = get_tree().root.find_child("ShootingGalleryManager", true, false)

	if gallery_manager:
		setup(gallery_manager)


func setup(manager: ShootingGalleryManager) -> void:
	gallery_manager = manager
	if gallery_manager == null:
		return

	if not gallery_manager.pontuacao_alterada.is_connected(_on_pontuacao_alterada):
		gallery_manager.pontuacao_alterada.connect(_on_pontuacao_alterada)
	if not gallery_manager.combo_alterado.is_connected(_on_combo_alterado):
		gallery_manager.combo_alterado.connect(_on_combo_alterado)
	if not gallery_manager.alvo_atingido.is_connected(_on_alvo_atingido):
		gallery_manager.alvo_atingido.connect(_on_alvo_atingido)
	if not gallery_manager.sessao_iniciada.is_connected(_on_sessao_iniciada):
		gallery_manager.sessao_iniciada.connect(_on_sessao_iniciada)
	if not gallery_manager.sessao_encerrada.is_connected(_on_sessao_encerrada):
		gallery_manager.sessao_encerrada.connect(_on_sessao_encerrada)
	if gallery_manager.has_signal("alvo_desapareceu") and not gallery_manager.alvo_desapareceu.is_connected(_on_alvo_desapareceu):
		gallery_manager.alvo_desapareceu.connect(_on_alvo_desapareceu)

	_update_labels(gallery_manager.score, gallery_manager.combo, gallery_manager.combo_multiplier)


func _process(_delta: float) -> void:
	if gallery_manager == null:
		return

	# Update timer label
	if timer_label:
		if gallery_manager.session_mode == ShootingGalleryManager.SessionMode.TIME_ATTACK:
			if gallery_manager.is_session_active:
				timer_label.text = "TEMPO: %04.1fs" % gallery_manager.time_remaining
				if gallery_manager.time_remaining <= 10.0:
					timer_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
				else:
					timer_label.modulate = Color(1.0, 1.0, 1.0, 1.0)
			else:
				timer_label.text = "TEMPO: 00.0s"
		elif gallery_manager.session_mode == ShootingGalleryManager.SessionMode.TIME_ATTACK_HARD:
			if gallery_manager.is_session_active:
				timer_label.text = "HARD: %04.1fs [JANELA: %.1fs]" % [gallery_manager.time_remaining, gallery_manager.get_despawn_duration()]
				if gallery_manager.time_remaining <= 10.0:
					timer_label.modulate = Color(1.0, 0.3, 0.3, 1.0)
				else:
					timer_label.modulate = Color(1.0, 0.7, 0.2, 1.0)
			else:
				timer_label.text = "HARD: 00.0s"
		else:
			timer_label.text = "MODO: TREINO LIVRE"

	# Update live accuracy / shots stats
	if stats_label:
		var acc = gallery_manager.get_accuracy()
		stats_label.text = "ACERTOS: %d | TIROS: %d | PRECISÃO: %04.1f%%" % [
			gallery_manager.total_hits,
			gallery_manager.total_shots,
			acc
		]


func _on_pontuacao_alterada(pontos: int, _delta: int) -> void:
	if score_label:
		score_label.text = "PONTOS: %d" % pontos


func _on_combo_alterado(combo_atual: int, multiplicador: float) -> void:
	if combo_label:
		if combo_atual > 1:
			combo_label.visible = true
			combo_label.text = "COMBO %dx (%.1fx)" % [combo_atual, multiplicador]
			combo_label.modulate = Color(1.0, 0.85, 0.2, 1.0)
		else:
			combo_label.visible = false


func _on_alvo_atingido(_alvo: Node, tipo_alvo: int, delta_pontos: int, multiplicador: float) -> void:
	var text: String
	var color: Color
	if tipo_alvo == 0:
		# ENEMY hit
		if multiplicador > 1.0:
			text = "+%d (x%.1f COMBO!)" % [delta_pontos, multiplicador]
		else:
			text = "+%d" % delta_pontos
		color = Color(0.3, 1.0, 0.3, 1.0)
	else:
		# FRIENDLY hit
		text = "%d PENALIDADE! AMIGO ATINGIDO" % delta_pontos
		color = Color(1.0, 0.2, 0.2, 1.0)

	_show_notification(text, color)


func _on_sessao_iniciada(_tempo_limite: float, modo: int = 0) -> void:
	_hide_summary()
	var mode_name = "TIME ATTACK"
	if modo == 1:
		mode_name = "TREINO LIVRE"
	elif modo == 2:
		mode_name = "TIME ATTACK HARD"

	_show_notification("SESSÃO INICIADA (%s)!" % mode_name, Color(0.4, 0.8, 1.0))
	if score_label:
		score_label.text = "PONTOS: 0"
	if combo_label:
		combo_label.visible = false


func _on_alvo_desapareceu(_alvo: Node) -> void:
	_show_notification("ALVO SUMIU! COMBO PERDIDO", Color(1.0, 0.45, 0.1))


func _on_sessao_encerrada(pontuacao_final: int, precisao: float, acertos: int, penalidades: int) -> void:
	# O modo Treino Livre nunca apresenta a tela de fim de sessão
	if gallery_manager and gallery_manager.session_mode == ShootingGalleryManager.SessionMode.FREE_PRACTICE:
		return
	_show_summary(pontuacao_final, precisao, acertos, penalidades)


func _show_summary(pontuacao_final: int, precisao: float, acertos: int, _penalidades: int = 0) -> void:
	if summary_panel:
		summary_panel.visible = true
		summary_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if summary_label:
		summary_label.text = "FIM DA SESSÃO!\n\nPontuação Final: %d\nPrecisão: %.1f%%\nInimigos Abatidos: %d" % [
			pontuacao_final,
			precisao,
			acertos
		]
	if is_inside_tree() and get_tree():
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _hide_summary() -> void:
	if summary_panel:
		summary_panel.visible = false
		summary_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_inside_tree() and get_tree() and get_tree().paused:
		get_tree().paused = false
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_restart_pressed() -> void:
	_hide_summary()
	if gallery_manager:
		gallery_manager.iniciar_sessao()


func _on_close_pressed() -> void:
	_hide_summary()


func _input(event: InputEvent) -> void:
	if summary_panel and summary_panel.visible:
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
			_hide_summary()
			if is_inside_tree() and get_viewport():
				get_viewport().set_input_as_handled()


func _show_notification(msg: String, color: Color = Color.WHITE) -> void:
	if notification_label == null:
		return

	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()

	notification_label.text = msg
	notification_label.modulate = color
	notification_label.visible = true

	_notification_tween = create_tween()
	if _notification_tween:
		_notification_tween.tween_interval(1.2)
		_notification_tween.tween_property(notification_label, "modulate:a", 0.0, 0.4)
		_notification_tween.tween_callback(func(): notification_label.visible = false)


func _update_labels(score: int, combo: int, mult: float) -> void:
	if score_label:
		score_label.text = "PONTOS: %d" % score
	if combo_label:
		if combo > 1:
			combo_label.visible = true
			combo_label.text = "COMBO %dx (%.1fx)" % [combo, mult]
		else:
			combo_label.visible = false
