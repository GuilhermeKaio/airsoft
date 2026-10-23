extends RefCounted

const ShootingGalleryControlPanelClass = preload("res://Scripts/shooting_gallery_control_panel.gd")
const ControlPanelButtonClass = preload("res://Scripts/control_panel_button.gd")
const ShootingGalleryManagerClass = preload("res://Scripts/shooting_gallery_manager.gd")
const TargetSpawnAreaClass = preload("res://Scripts/target_spawn_area.gd")
const ShootingTargetClass = preload("res://Scripts/shooting_target.gd")
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


# 1. Control Panel Structure & Button Initialization (SRS 2.1)
func test_control_panel_initialization_and_buttons() -> void:
	var panel = ShootingGalleryControlPanelClass.new()
	panel._ready()

	assert_true(panel._buttons.has("mode_time_attack"), "Botão Time Attack deve existir")
	assert_true(panel._buttons.has("mode_free_practice"), "Botão Free Practice deve existir")
	assert_true(panel._buttons.has("mode_time_attack_hard"), "Botão Time Attack Hard deve existir")

	assert_true(panel._buttons.has("speed_long"), "Botão Janela Longa deve existir")
	assert_true(panel._buttons.has("speed_medium"), "Botão Janela Média deve existir")
	assert_true(panel._buttons.has("speed_short"), "Botão Janela Curta deve existir")

	assert_true(panel._buttons.has("session_toggle"), "Botão Iniciar/Parar deve existir")
	assert_true(panel._buttons.has("score_reset"), "Botão Zerar Pontos deve existir")

	panel.free()


# 2. Game Mode Selection (3 Modes - SRS 2.1 & 2.2)
func test_game_modes_selection_sync() -> void:
	var manager = ShootingGalleryManagerClass.new()
	var panel = ShootingGalleryControlPanelClass.new()
	panel._ready()
	panel.setup_manager(manager)

	# 1. Time Attack
	panel.press_button("mode_time_attack")
	assert_eq(manager.session_mode, ShootingGalleryManagerClass.SessionMode.TIME_ATTACK)
	assert_true(panel._buttons["mode_time_attack"].is_selected)
	assert_false(panel._buttons["mode_free_practice"].is_selected)
	assert_false(panel._buttons["mode_time_attack_hard"].is_selected)

	# 2. Free Practice
	panel.press_button("mode_free_practice")
	assert_eq(manager.session_mode, ShootingGalleryManagerClass.SessionMode.FREE_PRACTICE)
	assert_false(panel._buttons["mode_time_attack"].is_selected)
	assert_true(panel._buttons["mode_free_practice"].is_selected)
	assert_false(panel._buttons["mode_time_attack_hard"].is_selected)

	# 3. Time Attack Hard
	panel.press_button("mode_time_attack_hard")
	assert_eq(manager.session_mode, ShootingGalleryManagerClass.SessionMode.TIME_ATTACK_HARD)
	assert_false(panel._buttons["mode_time_attack"].is_selected)
	assert_false(panel._buttons["mode_free_practice"].is_selected)
	assert_true(panel._buttons["mode_time_attack_hard"].is_selected)

	panel.free()
	manager.free()


# 3. Despawn Speed Selection (3 Windows - SRS 2.1)
func test_despawn_speeds_selection_sync() -> void:
	var manager = ShootingGalleryManagerClass.new()
	var panel = ShootingGalleryControlPanelClass.new()
	panel._ready()
	panel.setup_manager(manager)

	# Longa: ~2.5s a 3.0s
	panel.press_button("speed_long")
	assert_eq(manager.current_despawn_speed, ShootingGalleryManagerClass.DespawnSpeed.LONGA)
	assert_almost_eq(manager.get_despawn_duration(), 3.0, 0.1)
	assert_true(panel._buttons["speed_long"].is_selected)
	assert_false(panel._buttons["speed_medium"].is_selected)

	# Média: ~1.5s a 2.0s
	panel.press_button("speed_medium")
	assert_eq(manager.current_despawn_speed, ShootingGalleryManagerClass.DespawnSpeed.MEDIA)
	assert_almost_eq(manager.get_despawn_duration(), 1.8, 0.1)
	assert_true(panel._buttons["speed_medium"].is_selected)

	# Curta: ~0.8s a 1.0s
	panel.press_button("speed_short")
	assert_eq(manager.current_despawn_speed, ShootingGalleryManagerClass.DespawnSpeed.CURTA)
	assert_almost_eq(manager.get_despawn_duration(), 0.9, 0.1)
	assert_true(panel._buttons["speed_short"].is_selected)

	panel.free()
	manager.free()


# 4. Dual Trigger Mechanism: Direct BB Hit and Key [E] Interaction (SRS 2.1)
func test_dual_trigger_mechanism_bb_and_interact() -> void:
	var manager = ShootingGalleryManagerClass.new()
	var panel = ShootingGalleryControlPanelClass.new()
	panel._ready()
	panel.setup_manager(manager)

	var btn = panel._buttons["mode_free_practice"] as ControlPanelButton

	# Acionamento por disparo direto de BB (on_hit)
	var mock_bb = BBClass.new()
	btn.on_hit(mock_bb)
	assert_eq(manager.session_mode, ShootingGalleryManagerClass.SessionMode.FREE_PRACTICE, "Disparo direto de BB deve acionar o botão")

	# Acionamento por tecla de interação [E] / interact()
	btn = panel._buttons["mode_time_attack_hard"] as ControlPanelButton
	btn.press()
	assert_eq(manager.session_mode, ShootingGalleryManagerClass.SessionMode.TIME_ATTACK_HARD, "Pressionar botão deve acionar o modo")

	# Teste de botão Iniciar / Parar sessão via painel
	assert_false(manager.is_session_active)
	assert_false(panel.enable_e_interaction, "O uso da tecla [E] deve estar desvinculado por padrão no painel")

	# Verifica que evento de tecla [E] não aciona o painel quando desvinculado
	var event_e = InputEventKey.new()
	event_e.keycode = KEY_E
	event_e.pressed = true
	panel._player_in_range = true
	panel._unhandled_input(event_e)
	assert_false(manager.is_session_active, "Tecla [E] desvinculada NÃO deve acionar a sessão no painel")

	panel.press_button("session_toggle")
	assert_true(manager.is_session_active, "session_toggle deve iniciar a sessão")
	panel.press_button("session_toggle")
	assert_false(manager.is_session_active, "session_toggle deve encerrar a sessão")

	mock_bb.free()
	panel.free()
	manager.free()


# 5. High Score Tracking & Display (SRS 2.1)
func test_high_score_recording_and_display() -> void:
	var manager = ShootingGalleryManagerClass.new()
	var panel = ShootingGalleryControlPanelClass.new()
	panel._ready()
	panel.setup_manager(manager)

	# Inicia Time Attack e marca 500 pontos
	manager.set_game_mode(ShootingGalleryManagerClass.GameMode.TIME_ATTACK)
	manager.iniciar_sessao(60.0)

	var enemy = ShootingTargetClass.new()
	enemy._ready()

	# 5 acertos com multiplicador crescente
	for i in range(5):
		manager.on_target_hit(enemy)

	var score_earned = manager.score
	assert_true(score_earned > 0)

	# Encerra a sessão -> atualiza High Score
	manager.encerrar_sessao()
	assert_eq(manager.get_high_score(ShootingGalleryManagerClass.GameMode.TIME_ATTACK), score_earned, "High score deve ser gravado")
	assert_true(panel.high_score_label.text.contains(str(score_earned)), "Display do painel deve exibir o recorde")

	enemy.free()
	panel.free()
	manager.free()


# 6. Mode 1: Time Attack Dynamic 1-Target Sequence (SRS 2.2)
func test_mode_time_attack_sequential_spawn() -> void:
	var manager = ShootingGalleryManagerClass.new()
	var spawn_area = TargetSpawnAreaClass.new()
	spawn_area.use_local_space = false
	spawn_area._ready()
	manager.set_spawn_area(spawn_area)

	manager.set_game_mode(ShootingGalleryManagerClass.GameMode.TIME_ATTACK)
	manager.iniciar_sessao(60.0)

	# Exatamente 1 alvo por vez na área (SRS 2.2)
	assert_eq(spawn_area.get_active_target_count(), 1, "Time attack deve ter 1 único alvo ativo")
	var target1 = spawn_area.get_active_targets()[0]

	# Ao acertar, alvo é removido e um novo surge imediatamente (SRS 2.2)
	manager.on_target_hit(target1)
	assert_eq(spawn_area.get_active_target_count(), 1, "Após acerto, novo alvo surge imediatamente mantendo 1 ativo")
	var target2 = spawn_area.get_active_targets()[0]
	assert_true(target2 != target1, "O novo alvo deve ser uma instância diferente")

	manager.encerrar_sessao()
	spawn_area.clear_all_targets()
	spawn_area.free()
	manager.free()


# 7. Mode 2: Free Practice Continuous Fixed-X Targets (SRS 2.2)
func test_mode_free_practice_replenishment() -> void:
	var manager = ShootingGalleryManagerClass.new()
	var spawn_area = TargetSpawnAreaClass.new()
	spawn_area.use_local_space = false
	spawn_area._ready()
	manager.set_spawn_area(spawn_area)
	manager.practice_target_count = 4

	manager.set_game_mode(ShootingGalleryManagerClass.GameMode.FREE_PRACTICE)
	manager.iniciar_sessao(-1.0)

	# Mantém permanentemente X alvos inimigos visíveis (ex: 4 alvos)
	assert_eq(spawn_area.get_active_target_count(), 4, "Free Practice deve manter 4 alvos simultâneos")

	var targets_initial = spawn_area.get_active_targets()
	var hit_target = targets_initial[0]

	# Ao abater qualquer um, outro inimigo surge imediatamente para repor a quantidade exata
	manager.on_target_hit(hit_target)
	assert_eq(spawn_area.get_active_target_count(), 4, "Quantidade de alvos deve se manter exatamente 4")

	manager.encerrar_sessao()
	spawn_area.clear_all_targets()
	spawn_area.free()
	manager.free()


# 8. Mode 3: Time Attack Hard Despawn Window & Combo Reset (SRS 2.2 & 2.3)
func test_mode_time_attack_hard_timeout_and_combo_reset() -> void:
	var manager = ShootingGalleryManagerClass.new()
	var spawn_area = TargetSpawnAreaClass.new()
	spawn_area.use_local_space = false
	spawn_area._ready()
	manager.set_spawn_area(spawn_area)

	manager.set_game_mode(ShootingGalleryManagerClass.GameMode.TIME_ATTACK_HARD)
	manager.set_despawn_speed(ShootingGalleryManagerClass.DespawnSpeed.MEDIA) # 1.8s
	manager.iniciar_sessao(60.0)

	var signal_data = {"desapareceu": false, "alvo": null}
	manager.alvo_desapareceu.connect(func(a):
		signal_data["desapareceu"] = true
		signal_data["alvo"] = a
	)

	assert_eq(spawn_area.get_active_target_count(), 1)
	var target1 = spawn_area.get_active_targets()[0]

	# Acerto 1: acumula combo
	manager.on_target_hit(target1)
	assert_eq(manager.combo, 1)

	# Novo alvo gerado com tempo de sumir
	var target2 = spawn_area.get_active_targets()[0]
	assert_almost_eq(target2.despawn_lifetime, 1.8, 0.05, "Alvo deve ter despawn_lifetime configurado")

	# Tempo esgota sem ser atingido (SRS 2.2)
	target2._physics_process(1.9)
	assert_false(target2.is_active, "Alvo deve desaparecer após fim da janela")

	# Manager deve receber notificação de alvo desaparecido
	assert_true(signal_data["desapareceu"], "Sinal alvo_desapareceu deve ser emitido")
	assert_eq(manager.combo, 0, "Combo deve ser zerado por falha de tempo (SRS 2.3)")
	assert_almost_eq(manager.combo_multiplier, 1.0, 0.01)

	# Próximo alvo surge imediatamente na área
	assert_eq(spawn_area.get_active_target_count(), 1, "Próximo alvo deve surgir imediatamente após sumiço")

	manager.encerrar_sessao()
	spawn_area.clear_all_targets()
	spawn_area.free()
	manager.free()


# 9. Normative Signals Contract (SRS 2.4)
func test_normative_signals_contract_extended() -> void:
	var manager = ShootingGalleryManagerClass.new()
	manager._ready()

	var signals_emitted = {
		"sessao_iniciada": false,
		"configuracao_alterada": false,
		"alvo_desapareceu": false
	}

	manager.sessao_iniciada.connect(func(_t, _m): signals_emitted["sessao_iniciada"] = true)
	manager.configuracao_alterada.connect(func(_m, _v): signals_emitted["configuracao_alterada"] = true)
	manager.alvo_desapareceu.connect(func(_a): signals_emitted["alvo_desapareceu"] = true)

	manager.set_game_mode(ShootingGalleryManagerClass.GameMode.TIME_ATTACK_HARD)
	assert_true(signals_emitted["configuracao_alterada"], "Sinal configuracao_alterada emitido ao alterar modo")

	manager.iniciar_sessao(30.0)
	assert_true(signals_emitted["sessao_iniciada"], "Sinal sessao_iniciada(tempo, modo) emitido")

	var dummy_target = ShootingTargetClass.new()
	manager.on_target_despawned(dummy_target)
	assert_true(signals_emitted["alvo_desapareceu"], "Sinal alvo_desapareceu emitido")

	dummy_target.free()
	manager.free()


# 10. Main Scene Integration (main.tscn)
func test_main_scene_integration() -> void:
	var main_scene: PackedScene = load("res://Scenes/main.tscn")
	assert_true(main_scene != null, "Cena main.tscn deve carregar sem erros")
	assert_true(main_scene.can_instantiate(), "Cena main.tscn deve ser instanciável")

	var state = main_scene.get_state()
	var found_spawn_area = false
	var found_panel = false
	var found_manager = false

	for i in range(state.get_node_count()):
		var node_name = state.get_node_name(i)
		if node_name == "TargetSpawnArea":
			found_spawn_area = true
		elif node_name == "ShootingGalleryControlPanel":
			found_panel = true
		elif node_name == "ShootingGalleryManager":
			found_manager = true

	assert_true(found_spawn_area, "TargetSpawnArea deve estar presente em main.tscn")
	assert_true(found_panel, "ShootingGalleryControlPanel deve estar presente em main.tscn")
	assert_true(found_manager, "ShootingGalleryManager deve estar presente em main.tscn")


# 11. Panel 5x Scale
func test_panel_scale_5x() -> void:
	var panel = ShootingGalleryControlPanelClass.new()
	panel.panel_scale = 5.0
	panel._ready()

	assert_almost_eq(panel.panel_scale, 5.0, 0.01, "Escala padrão do painel deve ser 5x")
	var btn = panel._buttons["mode_time_attack"] as ControlPanelButton
	assert_true(btn != null, "Botão Time Attack deve existir no painel 5x")
	assert_almost_eq(btn.button_size.x, 0.85 * 5.0, 0.1, "Largura do botão deve ser ampliada 5x")
	assert_almost_eq(btn.button_size.y, 0.26 * 5.0, 0.1, "Altura do botão deve ser ampliada 5x")

	panel.free()


# 12. Default Practice Mode & Strict Single Target Enforcement in Hard Mode
func test_default_practice_mode_and_hard_single_target_enforcement() -> void:
	var manager = ShootingGalleryManagerClass.new()
	var spawn_area = TargetSpawnAreaClass.new()
	spawn_area.use_local_space = false
	spawn_area._ready()
	manager.set_spawn_area(spawn_area)

	# 1. Modo inicial padrão deve ser FREE_PRACTICE
	assert_eq(manager.session_mode, ShootingGalleryManagerClass.SessionMode.FREE_PRACTICE, "Modo padrão inicial deve ser Treino Livre")

	# 2. Configura e inicia Treino Livre -> deve ter 4 alvos
	manager.iniciar_sessao(-1.0)
	assert_eq(spawn_area.get_active_target_count(), 4, "Treino livre deve conter 4 alvos")

	# 3. Alterna para TIME_ATTACK_HARD -> alvos anteriores de treino DEVEM ser limpos imediatamente
	manager.set_game_mode(ShootingGalleryManagerClass.GameMode.TIME_ATTACK_HARD)
	manager.iniciar_sessao(60.0)

	# Modo Hard DEVE ter estritamente 1 único alvo
	assert_eq(spawn_area.get_active_target_count(), 1, "Modo Hard deve conter estritamente 1 alvo ativo")

	# 4. Ao acertar o alvo no Hard, os outros alvos não devem sobrar nem acumular (estritamente 1)
	var target1 = spawn_area.get_active_targets()[0]
	manager.on_target_hit(target1)
	assert_eq(spawn_area.get_active_target_count(), 1, "Após acerto no Hard, deve continuar com exatamente 1 alvo")

	# 5. Ao sofrer timeout / despawn no Hard, deve continuar com exatamente 1 alvo
	var target2 = spawn_area.get_active_targets()[0]
	target2._physics_process(2.5) # Força despawn do alvo
	assert_eq(spawn_area.get_active_target_count(), 1, "Após timeout no Hard, deve manter estritamente 1 alvo")

	manager.encerrar_sessao()
	spawn_area.clear_all_targets()
	spawn_area.free()
	manager.free()


# 13. End Session Screen: Pause, Mouse Mode Visible & No Penalties Line
func test_end_session_pause_mouse_mode_and_no_penalties_line() -> void:
	var hud_scene = load("res://Scenes/shooting_gallery_hud.tscn")
	var hud = hud_scene.instantiate()
	hud._ready()

	# Simula encerramento de sessão com pontuação, precisão, acertos e penalidades
	hud._show_summary(1500, 92.5, 12, 3)

	# 1. Painel de resumo visível e mouse visível
	assert_true(hud.summary_panel != null and hud.summary_panel.visible, "Painel de resumo deve estar visível")
	assert_eq(Input.mouse_mode, Input.MOUSE_MODE_VISIBLE, "Mouse deve estar liberado (MOUSE_MODE_VISIBLE)")

	# 2. Linha de penalidades removida do texto
	assert_true(hud.summary_label != null, "Label de resumo deve existir")
	var summary_text: String = hud.summary_label.text
	assert_false(summary_text.contains("Penalidades"), "Não deve exibir linha de penalidades")
	assert_false(summary_text.contains("Civis"), "Não deve mencionar civis no resumo")
	assert_true(summary_text.contains("Pontuação Final: 1500"), "Deve conter pontuação final")
	assert_true(summary_text.contains("Precisão: 92.5%"), "Deve conter precisão")
	assert_true(summary_text.contains("Inimigos Abatidos: 12"), "Deve conter inimigos abatidos")

	# 3. Fechamento do resumo
	hud._hide_summary()
	assert_false(hud.summary_panel.visible, "Painel deve ficar oculto após fechar")
	if DisplayServer.get_name() != "headless":
		assert_eq(Input.mouse_mode, Input.MOUSE_MODE_CAPTURED, "Mouse deve retornar para MOUSE_MODE_CAPTURED")

	hud.free()


# 14. End Session on Mode Change While Active
func test_mode_change_ends_active_session() -> void:
	var manager = ShootingGalleryManagerClass.new()
	var spawn_area = TargetSpawnAreaClass.new()
	spawn_area.use_local_space = false
	spawn_area._ready()
	manager.set_spawn_area(spawn_area)

	var signal_data = {
		"session_ended": false,
		"final_score": -1
	}
	manager.sessao_encerrada.connect(func(pts, _acc, _h, _p):
		signal_data["session_ended"] = true
		signal_data["final_score"] = pts
	)

	# Inicia sessão no modo Time Attack
	manager.set_game_mode(ShootingGalleryManagerClass.GameMode.TIME_ATTACK)
	manager.iniciar_sessao(60.0)
	assert_true(manager.is_session_active, "Sessão deve estar ativa")

	# Pontua um acerto
	var target = spawn_area.get_active_targets()[0]
	manager.on_target_hit(target)
	assert_eq(manager.score, 100)

	# Muda o modo enquanto a sessão está ativa -> DEVE encerrar a sessão
	manager.set_game_mode(ShootingGalleryManagerClass.GameMode.TIME_ATTACK_HARD)
	assert_true(signal_data["session_ended"], "Mudar o modo com sessão em andamento deve emitir sessao_encerrada")
	assert_eq(signal_data["final_score"], 100, "Pontuação final da sessão encerrada deve ser preservada")
	assert_false(manager.is_session_active, "A sessão ativa anterior deve ser finalizada")
	assert_eq(manager.session_mode, ShootingGalleryManagerClass.SessionMode.TIME_ATTACK_HARD, "Novo modo deve ser aplicado")

	spawn_area.clear_all_targets()
	spawn_area.free()
	manager.free()


# 15. Free Practice Has No End-Of-Session Screen On Mode Change Or Start Stop
func test_free_practice_no_end_session_screen() -> void:
	var manager = ShootingGalleryManagerClass.new()
	var spawn_area = TargetSpawnAreaClass.new()
	spawn_area.use_local_space = false
	spawn_area._ready()
	manager.set_spawn_area(spawn_area)

	var hud_scene = load("res://Scenes/shooting_gallery_hud.tscn")
	var hud = hud_scene.instantiate()
	hud._ready()
	hud.setup(manager)

	var signal_data = {
		"session_ended": false
	}
	manager.sessao_encerrada.connect(func(_pts, _acc, _h, _p):
		signal_data["session_ended"] = true
	)

	# 1. Escolhe Treino Livre -> inicia imediatamente com alvos
	manager.set_game_mode(ShootingGalleryManagerClass.GameMode.FREE_PRACTICE)
	assert_eq(manager.session_mode, ShootingGalleryManagerClass.SessionMode.FREE_PRACTICE)
	assert_true(manager.is_session_active, "Free practice deve iniciar ativo automaticamente")
	assert_eq(spawn_area.get_active_target_count(), 4, "Deve spawnar alvos de treino")

	# 2. Pode contar pontos normalmente
	var target = spawn_area.get_active_targets()[0]
	manager.on_target_hit(target)
	assert_eq(manager.score, 100, "Free practice pode contar pontos normalmente")

	# 3. Pressionar Iniciar / Parar via painel não apresenta tela de fim de sessão
	var panel = ShootingGalleryControlPanelClass.new()
	panel._ready()
	panel.setup_manager(manager)

	panel.press_button("session_toggle")
	assert_false(signal_data["session_ended"], "Apertar parar em Free Practice não deve emitir sessao_encerrada")
	assert_false(hud.summary_panel.visible, "Apertar parar em Free Practice não deve exibir tela de fim de sessão")

	panel.press_button("session_toggle")
	assert_false(signal_data["session_ended"], "Apertar iniciar em Free Practice não deve emitir sessao_encerrada")
	assert_false(hud.summary_panel.visible, "Apertar iniciar em Free Practice não deve exibir tela de fim de sessão")

	# 4. Mudar para outro modo para o treino SEM apresentar tela de fim de sessão
	manager.set_game_mode(ShootingGalleryManagerClass.GameMode.TIME_ATTACK)
	assert_false(signal_data["session_ended"], "Mudar de Free Practice para outro modo não deve emitir sessao_encerrada")
	assert_false(hud.summary_panel.visible, "Mudar de Free Practice para outro modo não deve exibir tela de fim de sessão")
	assert_eq(manager.session_mode, ShootingGalleryManagerClass.SessionMode.TIME_ATTACK)

	panel.free()
	hud.free()
	spawn_area.clear_all_targets()
	spawn_area.free()
	manager.free()
