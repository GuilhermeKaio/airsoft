extends RefCounted

const ShootingTargetClass = preload("res://Scripts/shooting_target.gd")
const ShootingGalleryManagerClass = preload("res://Scripts/shooting_gallery_manager.gd")
const ScoreSystemClass = preload("res://Scripts/score_system.gd")
const BBClass = preload("res://Scripts/bb.gd")

var _failed: bool = false
var _message: String = ""
var _assertion_count: int = 0

func _reset() -> void:
	_failed = false
	_message = ""
	_assertion_count = 0

func assert_true(condition: bool, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if not condition:
		_failed = true
		_message = msg if msg != "" else "Esperava true, obteve false"

func assert_false(condition: bool, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if condition:
		_failed = true
		_message = msg if msg != "" else "Esperava false, obteve true"

func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if actual != expected:
		_failed = true
		_message = msg if msg != "" else ("Esperava %s, obteve %s" % [str(expected), str(actual)])

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if absf(actual - expected) > tolerance:
		_failed = true
		_message = msg if msg != "" else ("Esperava ~%s, obteve %s (tolerância: %s)" % [str(expected), str(actual), str(tolerance)])


# 1. Target Classification and Properties (SRS 1.1)
func test_target_classification_and_properties() -> void:
	var enemy = ShootingTargetClass.new()
	enemy._ready()

	assert_eq(enemy.target_type, ShootingTargetClass.TargetType.ENEMY, "Padrão deve ser ENEMY")
	assert_eq(enemy.movement_type, ShootingTargetClass.MovementType.STATIC, "Padrão deve ser STATIC")
	assert_eq(enemy.points_value, 100, "Alvo inimigo deve conceder 100 pontos")
	assert_true(enemy.is_active, "Alvo deve iniciar ativo")
	assert_eq(enemy.collision_layer, 16, "Alvo deve estar na Layer 5 (Targets, valor 16)")

	var friendly = ShootingTargetClass.new()
	friendly.target_type = ShootingTargetClass.TargetType.FRIENDLY
	friendly._ready()

	assert_eq(friendly.target_type, ShootingTargetClass.TargetType.FRIENDLY)
	assert_eq(friendly.points_value, -200, "Alvo amigo/civil deve penalizar -200 pontos")

	enemy.free()
	friendly.free()


# 2. Target Hit Reaction and Mechanical Knockdown (SRS 1.3)
func test_target_hit_reaction_and_knockdown() -> void:
	var target = ShootingTargetClass.new()
	target._ready()

	var state = {"hit_signal_fired": false, "hit_target": null}
	target.alvo_atingido.connect(func(t, _bb):
		state["hit_signal_fired"] = true
		state["hit_target"] = t
	)

	# Simulate BB impact
	var mock_bb = Node.new()
	target.on_hit(mock_bb)

	assert_true(state["hit_signal_fired"], "Sinal alvo_atingido deve ser emitido no impacto")
	assert_eq(state["hit_target"], target, "Alvo emitido deve ser a própria instância")
	assert_false(target.is_active, "Alvo deve ficar inativo após ser atingido")
	assert_almost_eq(target.rotation.x, -deg_to_rad(90.0), 0.05, "Alvo deve tombar 90 graus para trás mecanicamente")

	# Subsequent hits while inactive must be ignored
	state["hit_signal_fired"] = false
	target.on_hit(mock_bb)
	assert_false(state["hit_signal_fired"], "Disparos subsequentes enquanto abatido devem ser ignorados")

	# Target Reset / Respawn
	target.reset_target()
	assert_true(target.is_active, "Alvo deve voltar ao estado ativo após reset")
	assert_almost_eq(target.rotation.x, 0.0, 0.01, "Alvo deve retornar à posição erguida (0 graus)")

	mock_bb.free()
	target.free()


# 3. Kinematic Behaviors: Static, Linear Patrol, Popup (SRS 1.2)
func test_target_kinematics_linear_patrol() -> void:
	var patrol_target = ShootingTargetClass.new()
	patrol_target.movement_type = ShootingTargetClass.MovementType.LINEAR_PATROL
	patrol_target.patrol_distance = 10.0
	patrol_target.move_speed = 5.0
	patrol_target.patrol_axis = Vector3(1, 0, 0)
	patrol_target._ready()

	var start_pos_x = patrol_target.position.x
	# Advance 1.0s: should move 5.0m to the right (+X)
	patrol_target._physics_process(1.0)
	assert_almost_eq(patrol_target.position.x, start_pos_x + 5.0, 0.01, "Patrulha avança linearmente")

	# Next step reaches or exceeds boundary (5.0m limit): inverts direction smoothly
	patrol_target._physics_process(0.5)
	assert_true(patrol_target.position.x <= start_pos_x + 5.0, "Não deve ultrapassar o limite do curso")
	assert_eq(patrol_target._patrol_direction, -1.0, "Direção inverte para vaivém ping-pong")

	patrol_target.free()


func test_target_kinematics_popup() -> void:
	var popup_target = ShootingTargetClass.new()
	popup_target.movement_type = ShootingTargetClass.MovementType.POPUP
	popup_target.popup_duration = 2.0
	popup_target.popup_hide_time = 1.0
	popup_target._ready()

	assert_true(popup_target.is_active, "Popup inicia visível/erguido")

	# Advance less than popup_duration: remains active
	popup_target._physics_process(1.5)
	assert_true(popup_target.is_active, "Permanece erguido durante janela de popup")

	# Advance past popup_duration without hit: hides without points
	popup_target._physics_process(0.6)
	assert_false(popup_target.is_active, "Oculta automaticamente ao expirar o tempo sem ser atingido")
	assert_almost_eq(popup_target.rotation.x, -deg_to_rad(90.0), 0.05, "Tombado quando oculto")

	# Advance past popup_hide_time: pops back up
	popup_target._physics_process(1.1)
	assert_true(popup_target.is_active, "Resurge automaticamente erguido após tempo oculto")
	assert_almost_eq(popup_target.rotation.x, 0.0, 0.01, "Erguido após resurge")

	popup_target.free()


# 4. ShootingGalleryManager: Scoring & Combo Multipliers (SRS 2.1)
func test_scoring_and_combo_multipliers() -> void:
	var manager = ShootingGalleryManagerClass.new()
	manager.max_combo_multiplier = 4.0
	manager.combo_multiplier_step = 0.5
	manager._ready()
	manager.iniciar_sessao(60.0)

	var enemy = ShootingTargetClass.new()
	enemy.target_type = ShootingTargetClass.TargetType.ENEMY
	enemy.points_value = 100
	enemy._ready()

	# Hit 1: Enemy -> +100 points, combo 1x (mult 1.0)
	manager.on_target_hit(enemy)
	assert_eq(manager.score, 100, "1º acerto concede 100 pontos")
	assert_eq(manager.combo, 1, "Combo streak = 1")
	assert_almost_eq(manager.combo_multiplier, 1.0, 0.01, "Multiplicador inicial = 1.0x")

	# Hit 2: Enemy -> +150 points (100 * 1.5), total 250, combo 2
	manager.on_target_hit(enemy)
	assert_eq(manager.combo, 2, "Combo streak = 2")
	assert_almost_eq(manager.combo_multiplier, 1.5, 0.01, "Multiplicador escala para 1.5x")
	assert_eq(manager.score, 250, "Total acumulado = 250 pontos")

	# Hit 3: Enemy -> +200 points (100 * 2.0), total 450, combo 3
	manager.on_target_hit(enemy)
	assert_eq(manager.combo, 3)
	assert_almost_eq(manager.combo_multiplier, 2.0, 0.01)
	assert_eq(manager.score, 450)

	# Hit Friendly: civilian penalty -200, combo reset to 1.0x
	var friendly = ShootingTargetClass.new()
	friendly.target_type = ShootingTargetClass.TargetType.FRIENDLY
	friendly.points_value = -200
	friendly._ready()

	manager.on_target_hit(friendly)
	assert_eq(manager.combo, 0, "Combo deve ser resetado após acertar civil/amigo")
	assert_almost_eq(manager.combo_multiplier, 1.0, 0.01, "Multiplicador reseta para 1.0x")
	assert_eq(manager.friendly_hits, 1, "Penalidade registrada")
	assert_eq(manager.score, 250, "Score reduz 200 pontos de penalidade (450 - 200 = 250)")

	enemy.free()
	friendly.free()
	manager.free()


# 5. Missed Shot and Combo Decay (SRS 2.1)
func test_missed_shot_and_combo_decay() -> void:
	var manager = ShootingGalleryManagerClass.new()
	manager._ready()
	manager.iniciar_sessao(60.0)

	var enemy = ShootingTargetClass.new()
	enemy._ready()

	manager.on_target_hit(enemy)
	manager.on_target_hit(enemy)
	assert_true(manager.combo > 0)
	var initial_decay_timer = manager.combo_decay_timer

	# Miss reduces combo decay time
	manager.registrar_erro(1.0)
	assert_almost_eq(manager.combo_decay_timer, initial_decay_timer - 1.0, 0.01, "Erro reduz tempo do combo")

	# Full decay timeout resets combo
	manager._process(initial_decay_timer)
	assert_eq(manager.combo, 0, "Combo reseta para 0 após timeout")
	assert_almost_eq(manager.combo_multiplier, 1.0, 0.01, "Multiplicador reseta para 1.0x")

	enemy.free()
	manager.free()


# 6. Session Modes & Precision Calculation (SRS 2.2)
func test_session_modes_and_accuracy() -> void:
	var manager = ShootingGalleryManagerClass.new()
	manager.session_mode = ShootingGalleryManagerClass.SessionMode.TIME_ATTACK
	manager._ready()

	var session_ended_data = {
		"fired": false,
		"final_score": 0,
		"final_accuracy": 0.0
	}

	manager.sessao_encerrada.connect(func(final_score, acc, _hits, _pens):
		session_ended_data["fired"] = true
		session_ended_data["final_score"] = final_score
		session_ended_data["final_accuracy"] = acc
	)

	manager.iniciar_sessao(30.0)
	assert_true(manager.is_session_active, "Sessão Time Attack ativa")
	assert_almost_eq(manager.time_remaining, 30.0, 0.01)

	var enemy = ShootingTargetClass.new()
	enemy._ready()

	# Simulate 10 shots fired, 8 hits
	manager.registrar_disparo(10)
	for i in range(8):
		manager.on_target_hit(enemy)

	assert_almost_eq(manager.get_accuracy(), 80.0, 0.1, "Precisão = (8 / 10) * 100 = 80.0%")

	# Elapse remaining time
	manager._process(30.0)
	assert_false(manager.is_session_active, "Sessão encerra ao atingir 0s")
	assert_true(session_ended_data["fired"], "Sinal sessao_encerrada emitido")
	assert_almost_eq(session_ended_data["final_accuracy"], 80.0, 0.1, "Precisão final informada corretamente")
	assert_true(session_ended_data["final_score"] > 0, "Pontuação final computada")

	# Points blocked after session end
	var score_before = manager.score
	manager.on_target_hit(enemy)
	assert_eq(manager.score, score_before, "Novos pontos bloqueados após término da sessão")

	enemy.free()
	manager.free()


# 7. Normative Signal Contracts (SRS 2.3)
func test_normative_signals_contract() -> void:
	var manager = ShootingGalleryManagerClass.new()
	manager._ready()

	var signals_fired = {
		"alvo_atingido": false,
		"pontuacao_alterada": false,
		"sessao_iniciada": false,
		"sessao_encerrada": false,
		"combo_alterado": false
	}

	manager.alvo_atingido.connect(func(_alvo, _tipo, _pts, _mult): signals_fired["alvo_atingido"] = true)
	manager.pontuacao_alterada.connect(func(_pontos, _delta): signals_fired["pontuacao_alterada"] = true)
	manager.sessao_iniciada.connect(func(_tempo, _modo = 0): signals_fired["sessao_iniciada"] = true)
	manager.sessao_encerrada.connect(func(_score, _acc, _h, _p): signals_fired["sessao_encerrada"] = true)
	manager.combo_alterado.connect(func(_combo, _mult): signals_fired["combo_alterado"] = true)

	manager.iniciar_sessao(10.0)
	assert_true(signals_fired["sessao_iniciada"], "Contrato sinal sessao_iniciada")

	var target = ShootingTargetClass.new()
	target._ready()

	manager.on_target_hit(target)
	assert_true(signals_fired["alvo_atingido"], "Contrato sinal alvo_atingido")
	assert_true(signals_fired["pontuacao_alterada"], "Contrato sinal pontuacao_alterada")
	assert_true(signals_fired["combo_alterado"], "Contrato sinal combo_alterado")

	manager.encerrar_sessao()
	assert_true(signals_fired["sessao_encerrada"], "Contrato sinal sessao_encerrada")

	target.free()
	manager.free()


# 8. BB Projectile Impact Integration & Collision Trigger (SRS 1.3 & Seção 5)
func test_bb_target_impact_integration() -> void:
	var target = ShootingTargetClass.new()
	target._ready()

	var bb = BBClass.new()
	bb._ready()

	# Simulate BB entered target
	bb._on_body_entered(target)
	assert_false(target.is_active, "BB impact triggers target.on_hit(bb)")

	bb.free()
	target.free()


# 9. Standalone ScoreSystem (SRS Adicionais Seção 2.1)
func test_standalone_score_system() -> void:
	var sys = ScoreSystemClass.new()
	sys.max_combo_multiplier = 4.0
	sys.combo_multiplier_step = 0.5

	# Enemy hit
	var res1 = sys.registrar_acerto(0, 100)
	assert_eq(res1["delta_pontos"], 100)
	assert_almost_eq(res1["multiplicador"], 1.0)
	assert_eq(sys.score, 100)
	assert_eq(sys.combo, 1)

	# Second enemy hit -> 100 * 1.5 = 150
	var res2 = sys.registrar_acerto(0, 100)
	assert_eq(res2["delta_pontos"], 150)
	assert_almost_eq(res2["multiplicador"], 1.5)
	assert_eq(sys.score, 250)
	assert_eq(sys.combo, 2)

	# Friendly hit -> -200 penalty, combo resets to 0, mult 1.0
	var res3 = sys.registrar_acerto(1, -200)
	assert_eq(res3["delta_pontos"], -200)
	assert_almost_eq(res3["multiplicador"], 1.0)
	assert_eq(sys.score, 50)
	assert_eq(sys.combo, 0)
	assert_almost_eq(sys.combo_multiplier, 1.0)

	# Misses and shots
	sys.registrar_disparo(5)
	assert_eq(sys.total_shots, 5)
	assert_eq(sys.total_hits, 3)
	assert_almost_eq(sys.calcular_precisao(), 60.0, 0.1)

	# Reset
	sys.zerar()
	assert_eq(sys.score, 0)
	assert_eq(sys.combo, 0)
	assert_eq(sys.total_shots, 0)
