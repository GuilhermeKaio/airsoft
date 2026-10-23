class_name ShootingGalleryManager
extends Node

## Gerenciador da Galeria de Tiro e Sistema de Pontuação (SRS Adicionais Seções 1.4 & 2)
## Orquestra os 3 modos de jogo (Time Attack, Free Practice, Time Attack Hard),
## as janelas de velocidade de sumir (Longa, Média, Curta), o spawn dinâmico na área delimitada,
## cronômetro, multiplicadores de combo, precisão e painel de controle.

enum GameMode {
	TIME_ATTACK = 0,
	FREE_PRACTICE = 1,
	TIME_ATTACK_HARD = 2
}

enum SessionMode {
	TIME_ATTACK = 0,
	FREE_PRACTICE = 1,
	TIME_ATTACK_HARD = 2
}

enum DespawnSpeed {
	LONGA = 0,
	MEDIA = 1,
	CURTA = 2
}

# Sinais normativos obrigatórios (SRS 2.4)
signal alvo_atingido(alvo: Node, tipo_alvo: int, pontos: int, multiplicador: float)
signal alvo_desapareceu(alvo: Node)
signal pontuacao_alterada(pontuacao_atual: int, delta_pontos: int)
signal sessao_iniciada(tempo_limite: float, modo: int)
signal sessao_encerrada(pontuacao_final: int, precisao: float, acertos: int, penalidades: int)
signal combo_alterado(combo_atual: int, multiplicador: float)
signal configuracao_alterada(novo_modo: int, nova_velocidade_sumir: int)

# Sinais em inglês para conveniência
signal target_hit(target: Node, target_type: int, points: int, multiplier: float)
signal target_despawned(target: Node)
signal score_changed(current_score: int, delta_points: int)
signal session_started(time_limit: float, mode: int)
signal session_ended(final_score: int, accuracy: float, hits: int, penalties: int)
signal combo_changed(current_combo: int, multiplier: float)
signal configuration_changed(new_mode: int, new_despawn_speed: int)

@export_group("Session & Game Modes (SRS 2.1 & 2.2)")
@export var session_mode: SessionMode = SessionMode.FREE_PRACTICE:
	set(val):
		if val != session_mode and is_session_active:
			if session_mode != SessionMode.FREE_PRACTICE:
				encerrar_sessao()
			else:
				is_session_active = false
		session_mode = val
	get:
		return session_mode

var game_mode: GameMode:
	set(val):
		session_mode = val as SessionMode
	get:
		return session_mode as GameMode

@export var default_time_limit: float = 60.0
@export var auto_start_practice: bool = true
@export var practice_target_count: int = 4

@export_group("Despawn Speeds (SRS 2.1)")
@export var current_despawn_speed: DespawnSpeed = DespawnSpeed.MEDIA
## Janela Longa: ~2.5s a 3.0s
@export var despawn_window_long: float = 3.0
## Janela Média: ~1.5s a 2.0s
@export var despawn_window_medium: float = 1.8
## Janela Curta: ~0.8s a 1.0s
@export var despawn_window_short: float = 0.9

@export_group("Spawn Area Reference (SRS 1.4)")
@export var spawn_area: TargetSpawnArea = null
@export var spawn_area_path: NodePath = ^""

@export_group("Combo & Scoring Rules (SRS 2.3)")
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

# Recordes por modo (SRS 2.1)
var high_scores: Dictionary = {
	GameMode.TIME_ATTACK: 0,
	GameMode.FREE_PRACTICE: 0,
	GameMode.TIME_ATTACK_HARD: 0
}

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

	_find_spawn_area()
	discover_targets()
	call_deferred("discover_targets")
	call_deferred("_deferred_initial_setup")


func _deferred_initial_setup() -> void:
	_find_spawn_area()
	if session_mode == SessionMode.FREE_PRACTICE and auto_start_practice:
		if not is_session_active:
			iniciar_sessao(-1.0)
		elif spawn_area and spawn_area.get_active_target_count() == 0:
			_setup_targets_for_session()


func _find_spawn_area() -> void:
	if spawn_area != null:
		return
	if not spawn_area_path.is_empty():
		spawn_area = get_node_or_null(spawn_area_path)
	if spawn_area == null and is_inside_tree():
		if get_tree().current_scene:
			spawn_area = get_tree().current_scene.find_child("TargetSpawnArea", true, false)
		if spawn_area == null:
			spawn_area = get_tree().root.find_child("TargetSpawnArea", true, false)

	if spawn_area != null:
		spawn_area.set_manager(self)
		if not spawn_area.target_despawned.is_connected(_on_spawn_area_target_despawned):
			spawn_area.target_despawned.connect(_on_spawn_area_target_despawned)


func set_spawn_area(area: TargetSpawnArea) -> void:
	spawn_area = area
	if spawn_area != null and not spawn_area.target_despawned.is_connected(_on_spawn_area_target_despawned):
		spawn_area.target_despawned.connect(_on_spawn_area_target_despawned)
	if session_mode == SessionMode.FREE_PRACTICE and auto_start_practice and is_session_active:
		if spawn_area != null and spawn_area.get_active_target_count() == 0:
			_setup_targets_for_session()


func _sync_score_system_settings() -> void:
	if score_system:
		score_system.max_combo_multiplier = max_combo_multiplier
		score_system.combo_multiplier_step = combo_multiplier_step
		score_system.combo_timeout = combo_timeout
		score_system.allow_negative_score = allow_negative_score


func _process(delta: float) -> void:
	# Contrarrelógio (TIME_ATTACK ou TIME_ATTACK_HARD)
	if (session_mode == SessionMode.TIME_ATTACK or session_mode == SessionMode.TIME_ATTACK_HARD) and is_session_active:
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


## Retorna o tempo em segundos para a velocidade de sumir selecionada (SRS 2.1)
func get_despawn_duration() -> float:
	match current_despawn_speed:
		DespawnSpeed.LONGA:
			return despawn_window_long
		DespawnSpeed.MEDIA:
			return despawn_window_medium
		DespawnSpeed.CURTA:
			return despawn_window_short
		_:
			return despawn_window_medium


## Define o modo de jogo ativo (SRS 2.1 & 2.2)
func set_game_mode(new_mode: int) -> void:
	var mode_val = clampi(new_mode, 0, 2)
	var new_session_mode = mode_val as SessionMode

	# Encerra a sessão se mudar de modo enquanto uma sessão está acontecendo
	# O modo Treino Livre não possui tela de fim de sessão; para sem apresentar resumo
	if new_session_mode != session_mode and is_session_active:
		if session_mode != SessionMode.FREE_PRACTICE:
			encerrar_sessao()
		else:
			is_session_active = false

	session_mode = new_session_mode
	game_mode = mode_val as GameMode

	if spawn_area and is_instance_valid(spawn_area):
		spawn_area.clear_all_targets()
		if session_mode == SessionMode.FREE_PRACTICE:
			is_session_active = true
			_setup_targets_for_session()
		elif is_session_active:
			_setup_targets_for_session()

	configuracao_alterada.emit(session_mode, current_despawn_speed)
	configuration_changed.emit(session_mode, current_despawn_speed)


func set_session_mode(new_mode: int) -> void:
	set_game_mode(new_mode)


## Define a velocidade da janela de sumir (SRS 2.1)
func set_despawn_speed(new_speed: int) -> void:
	var speed_val = clampi(new_speed, 0, 2)
	current_despawn_speed = speed_val as DespawnSpeed
	configuracao_alterada.emit(session_mode, current_despawn_speed)
	configuration_changed.emit(session_mode, current_despawn_speed)


## Alterna ciclicamente entre os 3 modos de jogo
func cycle_game_mode() -> int:
	var next_mode = (int(session_mode) + 1) % 3
	set_game_mode(next_mode)
	return next_mode


## Alterna ciclicamente entre as 3 velocidades de sumir
func cycle_despawn_speed() -> int:
	var next_speed = (int(current_despawn_speed) + 1) % 3
	set_despawn_speed(next_speed)
	return next_speed


## Retorna o recorde para o modo especificado ou do modo atual
func get_high_score(mode: int = -1) -> int:
	var target_mode = mode if mode >= 0 else int(session_mode)
	return high_scores.get(target_mode, 0)


## Reseta os recordes acumulados
func reset_high_scores() -> void:
	high_scores[GameMode.TIME_ATTACK] = 0
	high_scores[GameMode.FREE_PRACTICE] = 0
	high_scores[GameMode.TIME_ATTACK_HARD] = 0


## Inicia sessão do estande de tiro (SRS 2.2)
func iniciar_sessao(duracao: float = -1.0) -> void:
	_sync_score_system_settings()
	if duracao > 0.0:
		time_limit = duracao
	elif session_mode == SessionMode.TIME_ATTACK or session_mode == SessionMode.TIME_ATTACK_HARD:
		time_limit = default_time_limit
	else:
		time_limit = 0.0

	time_remaining = time_limit
	is_session_active = true

	score_system.zerar()

	# Reseta alvos estáticos pré-existentes
	for t in registered_targets:
		if is_instance_valid(t) and t.has_method("reset_target") and (spawn_area == null or not spawn_area.get_active_targets().has(t)):
			t.reset_target()

	# Orquestra alvos dinâmicos na área de spawn conforme o modo de jogo (SRS 2.2)
	_setup_targets_for_session()

	sessao_iniciada.emit(time_limit, int(session_mode))
	session_started.emit(time_limit, int(session_mode))
	pontuacao_alterada.emit(0, 0)
	score_changed.emit(0, 0)
	combo_alterado.emit(0, 1.0)
	combo_changed.emit(0, 1.0)


func start_session(duration: float = -1.0) -> void:
	iniciar_sessao(duration)


func _setup_targets_for_session() -> void:
	if spawn_area == null:
		return

	spawn_area.clear_all_targets()

	match session_mode:
		SessionMode.TIME_ATTACK:
			# 1 alvo por vez na área (SRS 2.2)
			spawn_area.spawn_target(0, 0, 0.0)

		SessionMode.FREE_PRACTICE:
			# Quantidade fixa X alvos simultâneos (apenas ENEMY)
			for i in range(practice_target_count):
				spawn_area.spawn_target(0, 0, 0.0)

		SessionMode.TIME_ATTACK_HARD:
			# 1 alvo temporizado com velocidade de sumir selecionada
			var window = get_despawn_duration()
			spawn_area.spawn_target(0, 0, window)


## Encerra a sessão ativa e consolida estatísticas (SRS 2.2)
func encerrar_sessao() -> void:
	if not is_session_active:
		return

	is_session_active = false
	var precisao: float = get_accuracy()

	# Atualiza recorde (High Score) do modo
	var cur_mode = int(session_mode)
	if score > high_scores.get(cur_mode, 0):
		high_scores[cur_mode] = score

	if spawn_area and is_instance_valid(spawn_area):
		if session_mode != SessionMode.FREE_PRACTICE:
			spawn_area.clear_all_targets()

	sessao_encerrada.emit(score, precisao, enemy_hits, friendly_hits)
	session_ended.emit(score, precisao, enemy_hits, friendly_hits)


func end_session() -> void:
	encerrar_sessao()


## Zera pontuação e estatísticas (SRS 2.2)
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


## Disparo no vazio / erro (SRS 2.3)
func registrar_erro(reducao_segundos: float = 1.0) -> void:
	score_system.registrar_erro(reducao_segundos)


func register_miss(reduction_seconds: float = 1.0) -> void:
	registrar_erro(reduction_seconds)


## Callback de impacto no alvo (SRS 2.3)
func on_target_hit(alvo: Node, _bb: Node = null) -> void:
	# No Time Attack e Time Attack Hard, bloqueia pontos se a sessão estiver inativa
	if (session_mode == SessionMode.TIME_ATTACK or session_mode == SessionMode.TIME_ATTACK_HARD) and not is_session_active:
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

	# Atualiza spawn dinâmico na área de spawn conforme as regras do modo (SRS 2.2)
	_handle_target_hit_spawn_logic(alvo)


func _on_target_hit(alvo: Node, bb: Node = null) -> void:
	on_target_hit(alvo, bb)


func _handle_target_hit_spawn_logic(alvo: Node) -> void:
	if spawn_area == null or not is_instance_valid(spawn_area):
		return

	var active_spawned = spawn_area.get_active_targets()
	if not active_spawned.has(alvo):
		return

	match session_mode:
		SessionMode.TIME_ATTACK:
			# Limpa todos os alvos e mantém estritamente 1 único alvo até o fim do tempo (SRS 2.2)
			spawn_area.clear_all_targets()
			if is_session_active:
				spawn_area.spawn_target(0, 0, 0.0)

		SessionMode.FREE_PRACTICE:
			# Ao abater qualquer um, remove o alvo e repõe até a quantidade fixa (SRS 2.2)
			spawn_area.remove_target(alvo)
			while spawn_area.get_active_target_count() < practice_target_count:
				spawn_area.spawn_target(0, 0, 0.0)

		SessionMode.TIME_ATTACK_HARD:
			# No Hard: limpa todos os alvos e spawna estritamente 1 novo alvo temporizado
			spawn_area.clear_all_targets()
			if is_session_active:
				var window = get_despawn_duration()
				spawn_area.spawn_target(0, 0, window)


## Callback de desaparecimento por expiração de tempo (Time Attack Hard - SRS 2.2 e 2.3)
func on_target_despawned(alvo: Node) -> void:
	if alvo == null or not is_instance_valid(alvo) or alvo.has_meta("_despawn_handled"):
		return
	alvo.set_meta("_despawn_handled", true)

	if not is_session_active and session_mode != SessionMode.FREE_PRACTICE:
		return

	# Em Time Attack Hard, alvo desaparecido zera o combo e não concede pontos
	if session_mode == SessionMode.TIME_ATTACK_HARD:
		_reset_combo()
		alvo_desapareceu.emit(alvo)
		target_despawned.emit(alvo)

		if spawn_area and is_instance_valid(spawn_area):
			spawn_area.clear_all_targets()
			if is_session_active:
				var window = get_despawn_duration()
				spawn_area.spawn_target(0, 0, window)
	else:
		alvo_desapareceu.emit(alvo)
		target_despawned.emit(alvo)


func _on_spawn_area_target_despawned(alvo: Node) -> void:
	on_target_despawned(alvo)


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

	var is_spawned_by_area = (spawn_area != null and is_instance_valid(spawn_area) and (alvo.get_parent() == spawn_area or spawn_area.get_active_targets().has(alvo)))
	if not is_spawned_by_area:
		if alvo.has_signal("alvo_desapareceu") and not alvo.alvo_desapareceu.is_connected(on_target_despawned):
			alvo.alvo_desapareceu.connect(on_target_despawned)
		elif alvo.has_signal("target_despawned") and not alvo.target_despawned.is_connected(on_target_despawned):
			alvo.target_despawned.connect(on_target_despawned)


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
	if node is ShootingTarget or node.is_in_group("shooting_targets") or node.has_method("reset_target"):
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
