extends RefCounted

const PlayerClass = preload("res://Scripts/player.gd")
const WeaponClass = preload("res://Scripts/weapon.gd")
const CrosshairClass = preload("res://Scripts/crosshair.gd")
const MagazineClass = preload("res://Scripts/magazine.gd")
const MagazineLoaderClass = preload("res://Scripts/magazine_loader.gd")

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


## 1. Estados Cinemáticos e Limiares de Velocidade (SRS Adicionais Seção 7.1)
func test_kinematic_states_and_speed_thresholds() -> void:
	var player = PlayerClass.new()
	player.set_on_floor_override(true)

	# 1. Parado / Estático (v_h <= 1.0 m/s)
	player.velocity = Vector3(0.5, 0.0, 0.5) # v_h ~ 0.707 m/s
	assert_eq(player.get_kinematic_state(), PlayerClass.KinematicState.STATIONARY, "v_h <= 1.0 m/s should be STATIONARY")

	player.velocity = Vector3(1.0, 0.0, 0.0) # v_h = 1.0 m/s
	assert_eq(player.get_kinematic_state(), PlayerClass.KinematicState.STATIONARY, "v_h == 1.0 m/s should be STATIONARY")

	# 2. Andando (1.0 m/s < v_h <= 3.0 m/s)
	player.velocity = Vector3(2.0, 0.0, 0.0)
	assert_eq(player.get_kinematic_state(), PlayerClass.KinematicState.WALKING, "1.0 < v_h <= 3.0 should be WALKING")

	player.velocity = Vector3(0.0, 0.0, 3.0)
	assert_eq(player.get_kinematic_state(), PlayerClass.KinematicState.WALKING, "v_h == 3.0 should be WALKING")

	# 3. Correndo (v_h > 3.0 m/s)
	player.velocity = Vector3(4.0, 0.0, 3.0) # v_h = 5.0 m/s
	assert_eq(player.get_kinematic_state(), PlayerClass.KinematicState.RUNNING, "v_h > 3.0 should be RUNNING")

	# 4. No Ar / Pulando (not is_on_floor())
	player.set_on_floor_override(false)
	player.velocity = Vector3(0.0, 3.0, 0.0)
	assert_eq(player.get_kinematic_state(), PlayerClass.KinematicState.AIRBORNE, "not on floor should be AIRBORNE")

	player.free()


## 2. Cones e Ângulos de Dispersão Cinemática (SRS Adicionais Seção 7.1)
func test_kinematic_spread_cone_angles() -> void:
	var player = PlayerClass.new()
	player.set_on_floor_override(true)

	# Stationary: erro adicional nulo (0.0°)
	player.velocity = Vector3.ZERO
	var stationary_spread := player.get_target_movement_spread(PlayerClass.KinematicState.STATIONARY)
	assert_almost_eq(stationary_spread, 0.0, 0.001, "Stationary movement spread penalty should be 0.0°")

	# Walking: Baixo / Moderado (0.8° a 1.5°)
	var walking_spread_min := player.get_target_movement_spread(PlayerClass.KinematicState.WALKING, 1.01)
	var walking_spread_max := player.get_target_movement_spread(PlayerClass.KinematicState.WALKING, 3.0)
	assert_in_range(walking_spread_min, 0.8, 1.5, "Walking min spread in [0.8°, 1.5°]")
	assert_in_range(walking_spread_max, 0.8, 1.5, "Walking max spread in [0.8°, 1.5°]")

	# Running: Severo / Alto (4.5° a 7.0°)
	var running_spread := player.get_target_movement_spread(PlayerClass.KinematicState.RUNNING, 5.0)
	assert_in_range(running_spread, 4.5, 7.0, "Running spread in [4.5°, 7.0°]")

	# Airborne: Máximo / Extremo (8.0° a 12.0°)
	var airborne_spread := player.get_target_movement_spread(PlayerClass.KinematicState.AIRBORNE)
	assert_in_range(airborne_spread, 8.0, 12.0, "Airborne spread in [8.0°, 12.0°]")

	player.free()


## 3. Zona Morta de Precisão (Accuracy Deadzoning) (SRS Adicionais Seção 7.2)
func test_deadzoning_and_accuracy_threshold() -> void:
	var player = PlayerClass.new()
	player.speed = 5.0
	player.deadzone_speed_ratio = 0.28
	player.set_on_floor_override(true)

	# Limiar normativo: 25% a 30% da velocidade máxima de corrida (5.0 * 0.28 = 1.4 m/s)
	var threshold := player.get_deadzone_speed_threshold()
	assert_almost_eq(threshold, 1.40, 0.01, "Deadzone speed threshold should be 28% of run speed (1.4 m/s)")

	# Velocidade dentro da deadzone (ex: 1.2 m/s <= 1.4 m/s) neutraliza penalidade
	player.velocity = Vector3(1.2, 0.0, 0.0)
	assert_true(player.is_in_accuracy_deadzone(), "1.2 m/s should be inside accuracy deadzone")
	assert_eq(player.get_kinematic_state(), PlayerClass.KinematicState.STATIONARY, "Deadzone restores stationary state")

	# Velocidade acima da deadzone (ex: 2.0 m/s > 1.4 m/s) não está na deadzone
	player.velocity = Vector3(2.0, 0.0, 0.0)
	assert_false(player.is_in_accuracy_deadzone(), "2.0 m/s should NOT be in accuracy deadzone")

	# Sinais de transição de deadzone
	var deadzone_entered := [false]
	var deadzone_exited := [false]
	player.accuracy_deadzone_entered.connect(func(): deadzone_entered[0] = true)
	player.accuracy_deadzone_exited.connect(func(): deadzone_exited[0] = true)

	player.velocity = Vector3(0.5, 0.0, 0.0)
	player.update_movement_spread(0.016)
	assert_true(deadzone_entered[0], "Should emit accuracy_deadzone_entered")

	player.velocity = Vector3(4.0, 0.0, 0.0)
	player.update_movement_spread(0.016)
	assert_true(deadzone_exited[0], "Should emit accuracy_deadzone_exited")

	player.free()


## 4. Counter-Strafing e Interpolação Suave (SRS Adicionais Seção 7.2)
func test_counter_strafing_braking_and_smooth_interpolation() -> void:
	var player = PlayerClass.new()
	player.speed = 5.0
	player.set_on_floor_override(true)
	player.current_movement_spread = 6.0 # Estava correndo

	# Interpolação suave ao parar: desaceleração move_toward proporcional
	player.velocity = Vector3.ZERO
	player.update_movement_spread(0.1) # 100ms
	assert_true(player.current_movement_spread < 6.0, "Spread should smoothly decay towards stationary (0.0°)")
	assert_true(player.current_movement_spread >= 0.0, "Spread cannot be negative")

	# Counter-strafing multiplier garante resposta ágil de frenagem
	assert_true(player.counter_strafe_multiplier >= 2.0, "Counter-strafe multiplier should provide swift braking")

	player.free()


## 5. Fórmula Balística Total de Dispersão (SRS Adicionais Seção 7.3)
func test_weapon_total_spread_formula() -> void:
	var weapon = WeaponClass.new()
	weapon.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)
	assert_almost_eq(weapon.base_spread_deg, 0.08, 0.01, "Rifle base spread ~0.08°")

	# theta_total = theta_base + theta_recoil + theta_movimento
	weapon.current_movement_spread_deg = 0.0
	weapon.recoil_shot_index = 0
	var stationary_total := weapon.get_total_spread_deg()
	assert_almost_eq(stationary_total, 0.08, 0.001, "Stationary total spread matches weapon base")

	# Com recuo acumulado (5 balas)
	weapon.recoil_shot_index = 5
	var recoil_spread: float = weapon.get_total_spread_deg()
	var expected_recoil_total: float = 0.08 + (5.0 * weapon.recoil_spread_factor)
	assert_almost_eq(recoil_spread, expected_recoil_total, 0.001, "Total spread includes recoil bloom")

	# Com movimento (jogador correndo: 5.5°)
	weapon.current_movement_spread_deg = 5.5
	var running_total: float = weapon.get_total_spread_deg()
	var expected_running_total: float = expected_recoil_total + 5.5
	assert_almost_eq(running_total, expected_running_total, 0.001, "Total spread includes movement inaccuracy")

	# Shotgun preset incorpora cone intrínseco
	var shotgun = WeaponClass.new()
	shotgun.configure_weapon_preset(WeaponClass.WeaponModel.SHOTGUN)
	assert_true(shotgun.get_total_spread_deg() >= 2.8, "Shotgun total spread includes multi-pellet spread cone")

	weapon.free()
	shotgun.free()


## 6. Cálculo da Deflexão Cônica Balística 3D da BB (SRS Adicionais Seção 7.3)
func test_bb_ballistic_cone_deflection_calculation() -> void:
	var forward := Vector3.FORWARD

	# Dispersão zero: direção inalterada
	var dir_zero := WeaponClass.calculate_deflected_direction(forward, 0.0)
	assert_almost_eq(dir_zero.angle_to(forward), 0.0, 0.0001, "Zero spread should return unaltered muzzle vector")

	# Dispersão não-nula: deflexão estocástica dentro do limite do cone
	var max_spread_rad := deg_to_rad(5.5)
	for i in range(25):
		var deflected := WeaponClass.calculate_deflected_direction(forward, max_spread_rad)
		assert_almost_eq(deflected.length(), 1.0, 0.001, "Deflected vector must be normalized")
		var dev_angle := deflected.angle_to(forward)
		assert_true(dev_angle <= max_spread_rad + 0.0001, "Deflection angle must not exceed max cone spread")

	# Múltiplas amostras não devem ser todas idênticas (distribuição tridimensional)
	var sample_1 := WeaponClass.calculate_deflected_direction(forward, max_spread_rad)
	var sample_2 := WeaponClass.calculate_deflected_direction(forward, max_spread_rad)
	var are_different := (sample_1 - sample_2).length() > 0.0001
	assert_true(are_different, "Stochastic deflection should produce varied directions across shots")


## 7. Retículo Dinâmico Reativo (Dynamic Crosshair) (SRS Adicionais Seção 7.3)
func test_dynamic_crosshair_reactivity() -> void:
	var crosshair = CrosshairClass.new()
	crosshair.espaco = 4.0
	crosshair.spread_gap_multiplier = 3.5
	crosshair._ready()

	# Parado: espaçamento base (espaco = 4.0)
	crosshair.set_movement_spread(0.0)
	assert_almost_eq(crosshair.get_current_gap(), 4.0, 0.01, "Stationary gap should equal base espaco")

	# Andando (1.0° de erro): gap expande proporcionalmente
	crosshair.set_movement_spread(1.0)
	assert_almost_eq(crosshair.get_current_gap(), 4.0 + (1.0 * 3.5), 0.01, "Walking expands crosshair radially")

	# Correndo (5.5° de erro): gap expande fortemente
	crosshair.set_movement_spread(5.5)
	assert_almost_eq(crosshair.get_current_gap(), 4.0 + (5.5 * 3.5), 0.01, "Running expands crosshair widely")

	# No ar (10.0° de erro): gap atinge abertura máxima
	crosshair.set_movement_spread(10.0)
	assert_almost_eq(crosshair.get_current_gap(), 4.0 + (10.0 * 3.5), 0.01, "Airborne expands crosshair to maximum")

	# Parada mecânica / deadzone: fecha instantaneamente de volta para o gap base
	crosshair.set_movement_spread(0.0)
	assert_almost_eq(crosshair.get_current_gap(), 4.0, 0.01, "Deadzone / stop contracts crosshair tightly back to base")

	crosshair.free()


## 8. Integração Player + Crosshair via Sinais Reativos (SRS Adicionais Seção 7.3)
func test_player_crosshair_signal_integration() -> void:
	var player = PlayerClass.new()
	var crosshair = CrosshairClass.new()
	crosshair.espaco = 3.0
	crosshair.spread_gap_multiplier = 3.0
	crosshair.player_node = player
	crosshair._ready()

	player.set_on_floor_override(true)
	player.velocity = Vector3(5.0, 0.0, 0.0) # Correndo
	player.update_movement_spread(1.0) # Força avanço da interpolação

	assert_true(crosshair.get_current_gap() > 3.0, "Crosshair should reactively expand when player runs")
	assert_true(crosshair.get_movement_spread() > 0.0, "Crosshair should receive movement spread from player signal")

	player.free()
	crosshair.free()
