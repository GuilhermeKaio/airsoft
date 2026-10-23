class_name ShootingGalleryHUD
extends Control

## HUD Reativo para o Estande de Tiro (Shooting Gallery HUD)
## Exibe pontuação, multiplicador de combo, tempo restante, precisão e mensagens de impacto.

@export var gallery_manager_path: NodePath = ^"../../ShootingGalleryManager"
@onready var gallery_manager: ShootingGalleryManager = get_node_or_null(gallery_manager_path)

@onready var score_label: Label = $ScoreContainer/ScoreLabel
@onready var combo_label: Label = $ScoreContainer/ComboLabel
@onready var timer_label: Label = $TimerContainer/TimerLabel
@onready var stats_label: Label = $StatsContainer/StatsLabel
@onready var notification_label: Label = $NotificationLabel
@onready var summary_panel: PanelContainer = $SummaryPanel
@onready var summary_label: Label = $SummaryPanel/SummaryVBox/SummaryContentLabel
@onready var restart_button: Button = $SummaryPanel/SummaryVBox/RestartButton

var _notification_tween: Tween = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hide_summary()

	_find_and_setup_manager()
	call_deferred("_find_and_setup_manager")

	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)


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


func _on_sessao_iniciada(_tempo_limite: float) -> void:
	_hide_summary()
	_show_notification("TREINO INICIADO! ATIRE NOS INIMIGOS!", Color(0.4, 0.8, 1.0))
	if score_label:
		score_label.text = "PONTOS: 0"
	if combo_label:
		combo_label.visible = false


func _on_sessao_encerrada(pontuacao_final: int, precisao: float, acertos: int, penalidades: int) -> void:
	_show_summary(pontuacao_final, precisao, acertos, penalidades)


func _show_summary(pontuacao_final: int, precisao: float, acertos: int, penalidades: int) -> void:
	if summary_panel:
		summary_panel.visible = true
		summary_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	if summary_label:
		summary_label.text = "FIM DA SESSÃO!\n\nPontuação Final: %d\nPrecisão: %.1f%%\nInimigos Abatidos: %d\nPenalidades (Civis): %d" % [
			pontuacao_final,
			precisao,
			acertos,
			penalidades
		]


func _hide_summary() -> void:
	if summary_panel:
		summary_panel.visible = false
		summary_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_restart_pressed() -> void:
	_hide_summary()
	if gallery_manager:
		gallery_manager.iniciar_sessao()


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
