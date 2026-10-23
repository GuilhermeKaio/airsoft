class_name ShootingGalleryManager
extends Node

## Gerenciador da Galeria de Tiro e Sistema de Pontuação (SRS Adicionais Seção 2)
## Controla cronômetro, modos de sessão, multiplicador de combo, precisão balística e eventos do estande.

enum SessionMode {
	TIME_ATTACK,
	FREE_PRACTICE
}

# Sinais normativos obrigatórios (SRS 2.3)
signal alvo_atingido(alvo: Node, tipo_alvo: int, pontos: int, multiplicador: float)
signal pontuacao_alterada(pontuacao_atual: int, delta_pontos: int)
signal sessao_iniciada(tempo_limite: float)
signal sessao_encerrada(pontuacao_final: int, precisao: float, acertos: int, penalidades: int)
signal combo_alterado(combo_atual: int, multiplicador: float)

# Sinais em inglês para conveniência
signal target_hit(target: Node, target_type: int, points: int, multiplier: float)
signal score_changed(current_score: int, delta_points: int)
signal session_started(time_limit: float)
signal session_ended(final_score: int, accuracy: float, hits: int, penalties: int)
signal combo_changed(current_combo: int, multiplier: float)

@export_group("Session Settings (SRS 2.2)")
@export var session_mode: SessionMode = SessionMode.FREE_PRACTICE
@export var default_time_limit: float = 60.0
@export var auto_start_practice: bool = true

@export_group("Combo & Scoring Rules (SRS 2.1)")
@export var max_combo_multiplier: float = 4.0
@export var combo_multiplier_step: float = 0.5
@export var combo_timeout: float = 4.0
@export var allow_negative_score: bool = false

const ScoreSystemClass = preload("res://Scripts/score_system.gd")

# Runtime state
var score_system = ScoreSystemClass.new()
var time_limit: float = 60.0
var time_remaining: float = 60.0
var is_session_active: bool = false

var score: int:
	get: return score_system.score if score_system else 0
	set(val):
		if score_system: score_system.score = val

var combo: int:
	get: return score_system.combo if score_system else 0
	set(val):
		if score_system: score_system.combo = val

var combo_multiplier: float:
	get: return score_system.combo_multiplier if score_system else 1.0
	set(val):
		if score_system: score_system.combo_multiplier = val

var combo_decay_timer: float:
	get: return score_system.combo_decay_timer if score_system else 0.0
	set(val):
		if score_system: score_system.combo_decay_timer = val

var total_shots: int:
	get: return score_system.total_shots if score_system else 0
	set(val):
		if score_system: score_system.total_shots = val

var total_hits: int:
	get: return score_system.total_hits if score_system else 0
	set(val):
		if score_system: score_system.total_hits = val

var enemy_hits: int:
	get: return score_system.enemy_hits if score_system else 0
	set(val):
		if score_system: score_system.enemy_hits = val

var friendly_hits: int:
	get: return score_system.friendly_hits if score_system else 0
	set(val):
		if score_system: score_system.friendly_hits = val

var registered_targets: Array[Node] = []
var _connected_player: Node = null
var _connected_weapons: Array[Node] = []


func _ready() -> void:
	_sync_score_system_settings()
	time_limit = default_time_limit
	time_remaining = time_limit

	# Auto-discover targets in scene tree if available
	discover_targets()
	call_deferred("discover_targets")

	if session_mode == SessionMode.FREE_PRACTICE and auto_start_practice:
		iniciar_sessao(-1.0)


func _sync_score_system_settings() -> void:
	if score_system:
		score_system.max_combo_multiplier = max_combo_multiplier
		score_system.combo_multiplier_step = combo_multiplier_step
		score_system.combo_timeout = combo_timeout
		score_system.allow_negative_score = allow_negative_score


func _process(delta: float) -> void:
	# Contrarrelógio (TIME_ATTACK)
	if session_mode == SessionMode.TIME_ATTACK and is_session_active:
		time_remaining -= delta
		if time_remaining <= 0.0:
			time_remaining = 0.0
			encerrar_sessao()

	# Decaimento do combo por tempo no sistema de pontuação
	var prev_combo = combo
	score_system.atualizar_tempo(delta)
	if prev_combo > 0 and combo == 0:
		combo_alterado.emit(0, 1.0)
		combo_changed.emit(0, 1.0)


## Inicia sessão do estande de tiro (SRS 2.2)
func iniciar_sessao(duracao: float = -1.0) -> void:
	_sync_score_system_settings()
	if duracao > 0.0:
		time_limit = duracao
	elif session_mode == SessionMode.TIME_ATTACK:
		time_limit = default_time_limit
	else:
		time_limit = 0.0

	time_remaining = time_limit
	is_session_active = true

	score_system.zerar()

	# Reset targets
	for t in registered_targets:
		if is_instance_valid(t) and t.has_method("reset_target"):
			t.reset_target()

	sessao_iniciada.emit(time_limit)
	session_started.emit(time_limit)
	pontuacao_alterada.emit(0, 0)
	score_changed.emit(0, 0)
	combo_alterado.emit(0, 1.0)
	combo_changed.emit(0, 1.0)


func start_session(duration: float = -1.0) -> void:
	iniciar_sessao(duration)


## Encerra a sessão ativa e consolida estatísticas (SRS 2.2)
func encerrar_sessao() -> void:
	if not is_session_active:
		return

	is_session_active = false
	var precisao: float = get_accuracy()

	sessao_encerrada.emit(score, precisao, enemy_hits, friendly_hits)
	session_ended.emit(score, precisao, enemy_hits, friendly_hits)


func end_session() -> void:
	encerrar_sessao()


## Zera pontuação e estatísticas (SRS 2.2 - Free Practice)
func zerar_pontuacao() -> void:
	var old_score = score
	score_system.zerar()

	pontuacao_alterada.emit(0, -old_score)
	score_changed.emit(0, -old_score)
	combo_alterado.emit(0, 1.0)
	combo_changed.emit(0, 1.0)


func reset_score() -> void:
	zerar_pontuacao()


## Registra disparo de projétil para cálculo de precisão (SRS 2.2)
func registrar_disparo(quantidade: int = 1) -> void:
	if is_session_active or session_mode == SessionMode.FREE_PRACTICE:
		score_system.registrar_disparo(quantidade)


func register_shot(count: int = 1) -> void:
	registrar_disparo(count)


## Disparo no vazio / erro (SRS 2.1)
## Reduz gradualmente o tempo do combo
func registrar_erro(reducao_segundos: float = 1.0) -> void:
	score_system.registrar_erro(reducao_segundos)


func register_miss(reduction_seconds: float = 1.0) -> void:
	registrar_erro(reduction_seconds)


## Callback de impacto no alvo (SRS 2.1)
func on_target_hit(alvo: Node, _bb: Node = null) -> void:
	# No Time Attack, bloqueia novos pontos se a sessão estiver inativa
	if session_mode == SessionMode.TIME_ATTACK and not is_session_active:
		return

	var target_type_val: int = 0
	if "target_type" in alvo:
		target_type_val = alvo.target_type

	var points_base: int = 100 if target_type_val == 0 else -200
	if "points_value" in alvo:
		points_base = alvo.points_value

	_sync_score_system_settings()
	var result = score_system.registrar_acerto(target_type_val, points_base)

	alvo_atingido.emit(alvo, target_type_val, result["delta_pontos"], result["multiplicador"])
	target_hit.emit(alvo, target_type_val, result["delta_pontos"], result["multiplicador"])
	pontuacao_alterada.emit(score, result["delta_pontos"])
	score_changed.emit(score, result["delta_pontos"])
	combo_alterado.emit(combo, combo_multiplier)
	combo_changed.emit(combo, combo_multiplier)


func _on_target_hit(alvo: Node, bb: Node = null) -> void:
	on_target_hit(alvo, bb)


func _reset_combo() -> void:
	score_system._reset_combo()
	combo_alterado.emit(0, 1.0)
	combo_changed.emit(0, 1.0)


## Precisão (%) = (Total de Acertos / Total de Tiros Disparados) * 100 (SRS 2.2)
func get_accuracy() -> float:
	return score_system.get_accuracy()


## Registro e monitoramento de alvos
func register_target(alvo: Node) -> void:
	if alvo == null or registered_targets.has(alvo):
		return

	registered_targets.append(alvo)

	if alvo.has_signal("target_hit") and not alvo.target_hit.is_connected(on_target_hit):
		alvo.target_hit.connect(on_target_hit)
	elif alvo.has_signal("alvo_atingido") and not alvo.alvo_atingido.is_connected(on_target_hit):
		alvo.alvo_atingido.connect(on_target_hit)
	elif alvo.has_signal("hit") and not alvo.hit.is_connected(on_target_hit):
		alvo.hit.connect(on_target_hit)


func registrar_alvo(alvo: Node) -> void:
	register_target(alvo)


func discover_targets(root: Node = null) -> void:
	var search_root = root
	if search_root == null and is_inside_tree():
		search_root = get_tree().current_scene
		if search_root == null:
			search_root = get_parent()
		if search_root == null:
			search_root = get_tree().root
	if search_root == null:
		return
	_search_and_register_targets(search_root)


func _search_and_register_targets(node: Node) -> void:
	if node.is_in_group("shooting_targets") or node.has_method("reset_target"):
		register_target(node)
	for child in node.get_children():
		_search_and_register_targets(child)


## Integração com Player e Armas para contagem automática de disparos
func setup_player(player: Node) -> void:
	if _connected_player and _connected_player != player:
		_disconnect_player(_connected_player)

	_connected_player = player
	if player == null:
		return

	if player.has_signal("weapon_swapped") and not player.weapon_swapped.is_connected(_on_weapon_swapped):
		player.weapon_swapped.connect(_on_weapon_swapped)
	elif player.has_signal("arma_trocada") and not player.arma_trocada.is_connected(_on_weapon_swapped):
		player.arma_trocada.connect(_on_weapon_swapped)

	if player.has_method("get_weapon"):
		var w = player.get_weapon()
		if w:
			setup_weapon(w)


func _disconnect_player(player: Node) -> void:
	if player.has_signal("weapon_swapped") and player.weapon_swapped.is_connected(_on_weapon_swapped):
		player.weapon_swapped.disconnect(_on_weapon_swapped)
	if player.has_signal("arma_trocada") and player.arma_trocada.is_connected(_on_weapon_swapped):
		player.arma_trocada.disconnect(_on_weapon_swapped)


func _on_weapon_swapped(new_weapon: Node, _slot_index: int = 0) -> void:
	if new_weapon:
		setup_weapon(new_weapon)


func setup_weapon(weapon: Node) -> void:
	if weapon == null or _connected_weapons.has(weapon):
		return

	_connected_weapons.append(weapon)

	if weapon.has_signal("shot_fired") and not weapon.shot_fired.is_connected(_on_shot_fired):
		weapon.shot_fired.connect(_on_shot_fired)
	elif weapon.has_signal("tiro_disparado") and not weapon.tiro_disparado.is_connected(_on_shot_fired):
		weapon.tiro_disparado.connect(_on_shot_fired)


func _on_shot_fired(count: int = 1) -> void:
	registrar_disparo(count)
