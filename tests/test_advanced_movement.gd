extends RefCounted

const PlayerClass = preload("res://Scripts/player.gd")

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
		_message = msg if msg != "" else "Expected true, got false"

func assert_false(condition: bool, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if condition:
		_failed = true
		_message = msg if msg != "" else "Expected false, got true"

func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if actual != expected:
		_failed = true
		_message = msg if msg != "" else ("Expected %s, got %s" % [str(expected), str(actual)])

func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.05, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if abs(actual - expected) > tolerance:
		_failed = true
		_message = msg if msg != "" else ("Expected ~%f, got %f (diff: %f > %f)" % [expected, actual, abs(actual - expected), tolerance])

func assert_in_range(val: float, min_val: float, max_val: float, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if val < min_val or val > max_val:
		_failed = true
		_message = msg if msg != "" else ("Value %f not in range [%f, %f]" % [val, min_val, max_val])


## 1. Preservação de Inércia no Solo (Jump Timing Window <= 0.1s) (SRS Adicionais Seção 4.1.1)
func test_jump_timing_window_and_inertia_preservation() -> void:
	var player = PlayerClass.new()
	player.set_on_floor_override(true)
	player.time_on_floor = 0.0
	player.was_on_floor = false # Simula acabou de aterrissar

	var initial_speed: float = 9.5
	player.velocity = Vector3(0.0, 0.0, -initial_speed)

	var bhop_performed := [false]
	var recorded_speed := [0.0]
	player.bunny_hop_performed.connect(func(spd: float):
		bhop_performed[0] = true
		recorded_speed[0] = spd
	)

	# Salto acionado dentro da janela de tolerância (0.05s <= 0.1s)
	player.process_movement(0.05, Vector2.ZERO, true, false, 0.0)

	assert_true(bhop_performed[0], "Bunny hop signal should be emitted on timed jump")
	assert_true(player.is_bunny_hopping, "Player should be in bunny hopping state")
	assert_eq(player.velocity.y, player.jump_velocity, "Vertical jump velocity must be applied")
	assert_true(player.get_horizontal_speed() >= initial_speed, "Horizontal inertia must be preserved without ground friction")
	assert_almost_eq(recorded_speed[0], player.get_horizontal_speed(), 0.01, "Emitted speed should match horizontal speed")

	player.free()


## 2. Penalidade de Perda de Ritmo (> 0.1s no Chão sem Saltar) (SRS Adicionais Seção 4.1.4)
func test_rhythm_loss_penalty_after_window() -> void:
	var player = PlayerClass.new()
	player.set_on_floor_override(true)
	player.time_on_floor = 0.0
	player.was_on_floor = true
	player.is_bunny_hopping = true
	player.speed = 5.0

	# Jogador aterrissa correndo para frente com alta velocidade (11.0 m/s)
	player.velocity = Vector3(0.0, 0.0, -11.0)

	var bhop_failed := [false]
	player.bunny_hop_failed.connect(func(): bhop_failed[0] = true)

	# Frame 1: 0.06s no chão sem saltar (tempo acumulado = 0.06s <= 0.1s, inércia preservada)
	player.process_movement(0.06, Vector2(0.0, -1.0), false, false, 0.0)
	assert_false(bhop_failed[0], "Should not fail within 0.1s window")
	assert_almost_eq(player.get_horizontal_speed(), 11.0, 0.01, "Friction not applied within window")

	# Frame 2: +0.06s no chão (tempo acumulado = 0.12s > 0.1s) -> Perda de ritmo!
	player.process_movement(0.06, Vector2(0.0, -1.0), false, false, 0.0)
	assert_true(bhop_failed[0], "bunny_hop_failed emitted when exceeding 0.1s on floor without jump")
	assert_false(player.is_bunny_hopping, "Bunny hopping state cancelled upon rhythm loss")
	assert_almost_eq(player.get_horizontal_speed(), player.speed, 0.05, "Speed instantly resets to running speed (speed=5.0)")

	# Se soltar as teclas de movimento no chão sem saltar, o atrito desacelera em direção a zero
	player.process_movement(0.1, Vector2.ZERO, false, false, 0.0)
	assert_true(player.get_horizontal_speed() < player.speed, "Ground friction decelerates stopped player")

	player.free()


## 3. Aceleração Aérea por Strafe para a Esquerda (SRS Adicionais Seção 4.1.2)
func test_air_strafe_left_coordination_and_acceleration() -> void:
	var player = PlayerClass.new()
	player.set_on_floor_override(false) # No ar

	var initial_speed: float = 6.0
	player.velocity = Vector3(0.0, 0.0, -initial_speed) # Indo para frente (-Z)

	var strafe_signal_called := [false]
	var emitted_speed := [0.0]
	var emitted_delta := [0.0]
	player.air_strafe_accelerated.connect(func(spd: float, d_spd: float):
		strafe_signal_called[0] = true
		emitted_speed[0] = spd
		emitted_delta[0] = d_spd
	)

	# Pressiona exclusivamente tecla de strafe esquerda (input_dir.x = -1.0, input_dir.y = 0.0)
	# E rotaciona a câmera para a esquerda (yaw_delta > 0 em radianos)
	var delta: float = 0.05
	player.process_movement(delta, Vector2(-1.0, 0.0), false, false, 0.06)

	assert_true(strafe_signal_called[0], "air_strafe_accelerated signal should be emitted")
	assert_true(emitted_delta[0] > 0.0, "Delta speed should be positive during coordinated air strafe")
	var final_speed: float = player.get_horizontal_speed()
	assert_true(final_speed > initial_speed, "Speed should strictly increase from air strafe acceleration")
	assert_true(player.velocity.x < 0.0, "Velocity should turn left into negative X")
	assert_true(player.is_air_strafing(), "is_air_strafing() should return true during active strafe")

	player.free()


## 4. Aceleração Aérea por Strafe para a Direita (SRS Adicionais Seção 4.1.2)
func test_air_strafe_right_coordination_and_acceleration() -> void:
	var player = PlayerClass.new()
	player.set_on_floor_override(false)

	var initial_speed: float = 6.0
	player.velocity = Vector3(0.0, 0.0, -initial_speed)

	var strafe_signal_called := [false]
	player.air_strafe_accelerated.connect(func(_s: float, _d: float):
		strafe_signal_called[0] = true
	)

	# Pressiona tecla de strafe direita (input_dir.x = 1.0) e vira para a direita (yaw_delta < 0)
	var delta: float = 0.05
	player.process_movement(delta, Vector2(1.0, 0.0), false, false, -0.06)

	assert_true(strafe_signal_called[0], "air_strafe_accelerated signal emitted for right strafe")
	assert_true(player.get_horizontal_speed() > initial_speed, "Speed increases turning right")
	assert_true(player.velocity.x > 0.0, "Velocity turns right into positive X")

	player.free()


## 5. Rejeição de Strafe Não-Coordenado (Anti-Cheat / Precisão Mecânica)
func test_uncoordinated_strafe_rejection() -> void:
	var player = PlayerClass.new()
	player.set_on_floor_override(false)

	var initial_speed: float = 6.0
	player.velocity = Vector3(0.0, 0.0, -initial_speed)

	# Caso A: Strafe esquerda mas virando câmera para a direita (yaw_delta < 0) -> Conflito
	player.process_movement(0.05, Vector2(-1.0, 0.0), false, false, -0.05)
	assert_false(player.is_air_strafing(), "Uncoordinated strafe (left input + right turn) rejected")
	assert_almost_eq(player.get_horizontal_speed(), initial_speed, 0.01, "No air strafe speed gain on conflict")

	# Caso B: Strafe direita mas virando câmera para a esquerda (yaw_delta > 0) -> Conflito
	player.velocity = Vector3(0.0, 0.0, -initial_speed)
	player.process_movement(0.05, Vector2(1.0, 0.0), false, false, 0.05)
	assert_false(player.is_air_strafing(), "Uncoordinated strafe (right input + left turn) rejected")
	assert_almost_eq(player.get_horizontal_speed(), initial_speed, 0.01)

	# Caso C: Não exclusivamente strafe (pressionando W + A: input_dir.y != 0)
	player.velocity = Vector3(0.0, 0.0, -initial_speed)
	player.process_movement(0.05, Vector2(-1.0, -1.0), false, false, 0.05)
	assert_false(player.is_air_strafing(), "Non-exclusive strafe (moving forward while strafing) rejected")

	# Caso D: Sem rotação de câmera (yaw_delta = 0)
	player.velocity = Vector3(0.0, 0.0, -initial_speed)
	player.process_movement(0.05, Vector2(-1.0, 0.0), false, false, 0.0)
	assert_false(player.is_air_strafing(), "Strafe without turning camera gives no acceleration")

	player.free()


## 6. Limite e Balanceamento de Velocidade Máxima (Speed Clamping <= 15.0 m/s) (SRS Adicionais Seção 4.1.3)
func test_speed_clamping_to_max_bhop_speed() -> void:
	var player = PlayerClass.new()
	player.set_on_floor_override(false)
	player.bhop_max_speed = 15.0

	# Jogador já no teto máximo
	player.velocity = Vector3(0.0, 0.0, -15.0)

	# Executa strafe coordenado repetidas vezes
	for i in range(10):
		player.process_movement(0.05, Vector2(-1.0, 0.0), false, false, 0.05)

	var final_speed: float = player.get_horizontal_speed()
	assert_true(final_speed <= 15.0001, "Horizontal speed must be strictly clamped to bhop_max_speed (15.0 m/s)")
	assert_almost_eq(final_speed, 15.0, 0.01, "Horizontal speed capped at 15.0 m/s")

	# Tentativa com velocidade inicial acima do teto é imediatamente contida
	player.velocity = Vector3(20.0, 0.0, 0.0)
	player.process_movement(0.016, Vector2.ZERO, false, false, 0.0)
	assert_almost_eq(player.get_horizontal_speed(), 15.0, 0.01, "Excess velocity clamped to bhop_max_speed")

	player.free()


## 7. Buffer de Salto (Jump Buffering <= 0.1s antes de Tocar o Solo)
func test_jump_buffering() -> void:
	var player = PlayerClass.new()
	player.set_on_floor_override(false) # No ar
	player.velocity = Vector3(0.0, -2.0, -8.0)

	var bhop_performed := [false]
	player.bunny_hop_performed.connect(func(_s): bhop_performed[0] = true)

	# Jogador aperta pulo no ar (0.05s antes de pousar)
	player.process_movement(0.05, Vector2.ZERO, true, false, 0.0)
	assert_true(player.jump_buffer_timer > 0.0, "Jump buffer timer should be active")
	assert_false(bhop_performed[0], "Should not trigger bunny hop while still airborne")

	# No frame seguinte, toca o solo (sem apertar o botão novamente)
	player.set_on_floor_override(true)
	player.process_movement(0.016, Vector2.ZERO, false, false, 0.0)

	assert_true(bhop_performed[0], "Buffered jump should execute Bunny Hop immediately upon landing")
	assert_eq(player.velocity.y, player.jump_velocity, "Vertical jump velocity applied via buffer")
	assert_true(player.get_horizontal_speed() >= 8.0, "Momentum preserved through buffered bunny hop")

	player.free()


## 8. Helper de Aceleração e Vetor Perpendicular (SRS Adicionais Seção 4.1.2)
func test_air_strafe_helper_formula_and_vectors() -> void:
	var player = PlayerClass.new()
	player.air_acceleration = 12.0
	player.bhop_max_speed = 15.0

	var cur_vel := Vector3(0.0, 0.0, -5.0)
	var wish_dir := Vector3(-1.0, 0.0, 0.0) # Wish para esquerda
	var accel_vec: Vector3 = player.calculate_air_strafe_acceleration(wish_dir, 0.05, cur_vel, 0.05)

	# Aceleração deve ter componente na direção do strafe (-X)
	assert_true(accel_vec.x < 0.0, "Acceleration vector must pull in strafe direction")
	var resulting_speed: float = (cur_vel + accel_vec).length()
	assert_true(resulting_speed > cur_vel.length(), "Resulting speed must exceed initial speed")

	player.free()


## 9. Predicado can_bunny_hop() e Habilitação
func test_can_bunny_hop_predicate() -> void:
	var player = PlayerClass.new()
	player.set_on_floor_override(true)
	player.time_on_floor = 0.05 # Dentro de 0.1s

	assert_true(player.can_bunny_hop(), "Can bunny hop when on floor and within window")

	# Passa do tempo de tolerância
	player.time_on_floor = 0.15
	assert_false(player.can_bunny_hop(), "Cannot bunny hop when time on floor > 0.1s")

	# Quando no ar
	player.time_on_floor = 0.02
	player.set_on_floor_override(false)
	assert_false(player.can_bunny_hop(), "Cannot bunny hop while in the air")

	# Quando desabilitado
	player.set_on_floor_override(true)
	player.bunny_hop_enabled = false
	assert_false(player.can_bunny_hop(), "Cannot bunny hop when bunny_hop_enabled = false")

	player.free()
