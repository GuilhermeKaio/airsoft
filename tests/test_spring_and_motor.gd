extends RefCounted

const WeaponClass = preload("res://Scripts/weapon.gd")
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


func assert_almost_eq(actual: float, expected: float, tolerance: float = 0.001, msg: String = "") -> void:
	_assertion_count += 1
	if _failed:
		return
	if abs(actual - expected) > tolerance:
		_failed = true
		_message = msg if msg != "" else ("Expected %f +/- %f, got %f" % [expected, tolerance, actual])


## --- FEATURE 2: MODELO FÍSICO DA MOLA (SRS Seção 3.2.1) ---

func test_spring_physical_model_formula() -> void:
	var weapon = WeaponClass.new()
	# Modelo padrão deve ser o físico (SRS 3.2.1)
	assert_eq(weapon.spring_model, WeaponClass.SpringModel.PHYSICAL, "Physical model must be default")

	# Padrão calibrado: k = 1192 N/m, x = 0.05 m -> E = 0.5 * 1192 * 0.05^2 = 1.49 J
	assert_almost_eq(weapon.spring_k, 1192.0, 0.01)
	assert_almost_eq(weapon.spring_x, 0.05, 0.001)
	assert_almost_eq(weapon.energy_joules, 1.49, 0.001, "E = 1/2 * k * x^2 must equal 1.49J")

	# Customização de k e x via adjust_spring
	weapon.adjust_spring(800.0, 0.05)
	# E = 0.5 * 800 * 0.0025 = 1.0 J
	assert_almost_eq(weapon.energy_joules, 1.0, 0.001, "E = 0.5 * 800 * 0.05^2 must equal 1.0J")

	weapon.adjust_spring(1500.0, 0.06)
	# E = 0.5 * 1500 * 0.0036 = 2.7 J
	assert_almost_eq(weapon.energy_joules, 2.7, 0.001, "E = 0.5 * 1500 * 0.06^2 must equal 2.7J")

	# Propriedades de alias
	weapon.spring_constant_k = 1000.0
	weapon.spring_compression_x = 0.04
	# E = 0.5 * 1000 * 0.0016 = 0.8 J
	assert_almost_eq(weapon.energy_joules, 0.8, 0.001)

	weapon.free()


func test_spring_simplified_model() -> void:
	var weapon = WeaponClass.new()
	weapon.set_simplified_energy(1.2)
	assert_eq(weapon.spring_model, WeaponClass.SpringModel.SIMPLIFIED)
	assert_almost_eq(weapon.energy_joules, 1.2, 0.001, "Simplified model must use nominal energy directly")

	# Alterando via energy_joules diretamente
	weapon.energy_joules = 1.85
	assert_almost_eq(weapon.energy_joules, 1.85, 0.001)

	# Alternando de volta para o modelo físico
	weapon.spring_model = WeaponClass.SpringModel.PHYSICAL
	weapon.spring_k = 1200.0
	weapon.spring_x = 0.05
	assert_almost_eq(weapon.energy_joules, 1.5, 0.001)

	weapon.free()


func test_bb_velocity_calculation_dynamic_mass() -> void:
	var weapon = WeaponClass.new()
	weapon.set_simplified_energy(1.49)

	# v = sqrt(2E / m)
	var v_020 = weapon.calculate_velocity(0.00020) # 0.20g
	var v_025 = weapon.calculate_velocity(0.00025) # 0.25g
	var v_030 = weapon.calculate_velocity(0.00030) # 0.30g
	var v_032 = weapon.calculate_velocity(0.00032) # 0.32g

	# Valores analíticos teóricos
	var expected_020 = sqrt((2.0 * 1.49) / 0.00020) # ~122.0655 m/s
	var expected_025 = sqrt((2.0 * 1.49) / 0.00025) # ~109.1787 m/s
	var expected_030 = sqrt((2.0 * 1.49) / 0.00030) # ~99.6661 m/s

	assert_almost_eq(v_020, expected_020, 0.01, "0.20g velocity mismatch")
	assert_almost_eq(v_025, expected_025, 0.01, "0.25g velocity mismatch")
	assert_almost_eq(v_030, expected_030, 0.01, "0.30g velocity mismatch")

	# Regra mandatória SRS 3.2.1: Proibido uso de velocidade fixa
	assert_true(v_020 > v_025, "Lighter BB (0.20g) must be faster than (0.25g)")
	assert_true(v_025 > v_030, "0.25g BB must be faster than 0.30g")
	assert_true(v_030 > v_032, "0.30g BB must be faster than 0.32g")

	# Casos de borda (massa <= 0 ou energia <= 0)
	assert_eq(weapon.calculate_velocity(0.0), 0.0, "Zero mass should return 0 velocity")
	assert_eq(weapon.calculate_velocity(-0.0002), 0.0, "Negative mass should return 0 velocity")
	assert_eq(weapon.calculate_velocity(0.0002, 0.0), 0.0, "Zero energy should return 0 velocity")
	assert_eq(weapon.calculate_velocity(0.0002, -1.0), 0.0, "Negative energy override should return 0 velocity")

	weapon.free()


func test_spring_energy_affects_bb_velocity() -> void:
	var weapon = WeaponClass.new()
	var mass_kg := 0.00025 # 0.25g

	weapon.adjust_spring(800.0, 0.05) # E = 1.0J
	var v_low = weapon.calculate_velocity(mass_kg)

	weapon.adjust_spring(1600.0, 0.05) # E = 2.0J
	var v_high = weapon.calculate_velocity(mass_kg)

	assert_true(v_high > v_low, "Doubling spring k must increase BB muzzle velocity")
	assert_almost_eq(v_high / v_low, sqrt(2.0), 0.01, "Velocity ratio should equal sqrt(E2/E1)")

	weapon.free()


## --- FEATURE 3: MOTOR, GEARBOX E CADÊNCIA REAL (SRS Seção 3.2.2) ---

func test_motor_cadence_formula_srs_calibration() -> void:
	var weapon = WeaponClass.new()
	# Exemplo de Calibração SRS 3.2.2:
	# Rotação do motor = 8.100 RPM
	# Rotações por disparo (N) = 30
	# ROF = 8100 / (60 * 30) = 4.5 BB/s
	# intervalo = 1 / 4.5 ~= 0.2222 s
	weapon.set_motor_and_gearbox(8100.0, 30.0)

	assert_almost_eq(weapon.rof, 4.5, 0.001, "ROF must equal 4.5 BB/s")
	assert_almost_eq(weapon.get_rof(), 4.5, 0.001)
	assert_almost_eq(weapon.fire_interval, 1.0 / 4.5, 0.001, "Interval must equal ~0.2222s")
	assert_almost_eq(weapon.get_fire_interval(), 1.0 / 4.5, 0.001)
	assert_almost_eq(weapon.get_cadence_rpm(), 270.0, 0.01, "Cadence RPM should be 4.5 * 60 = 270")

	weapon.free()


func test_cadence_rule_1_sensitivity() -> void:
	var weapon = WeaponClass.new()
	weapon.set_motor_and_gearbox(8100.0, 30.0)
	var rof_base = weapon.rof
	var interval_base = weapon.fire_interval

	# Regra 1: Aumentar a rotação do motor deve obrigatoriamente aumentar a cadência (ROF)
	weapon.motor_rpm = 12000.0
	var rof_mid = weapon.rof
	var interval_mid = weapon.fire_interval

	assert_true(rof_mid > rof_base, "ROF must increase when motor RPM increases")
	assert_true(interval_mid < interval_base, "Interval must decrease when motor RPM increases")

	weapon.motor_rpm = 18000.0
	var rof_high = weapon.rof
	var interval_high = weapon.fire_interval

	assert_true(rof_high > rof_mid, "ROF must continue increasing with higher motor RPM")
	assert_true(interval_high < interval_mid, "Interval must continue decreasing with higher motor RPM")

	# Alterando N (gear ratio): maior N reduz ROF; menor N aumenta ROF
	weapon.gear_ratio_n = 15.0 # Engrenagem mais rápida (15:1 vs 30:1)
	assert_almost_eq(weapon.rof, 20.0, 0.001, "ROF at 18000 RPM and N=15 should be 18000/(60*15) = 20 BB/s")

	weapon.free()


func test_cadence_rule_2_interval_blocking_semi() -> void:
	var weapon = WeaponClass.new()
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	weapon.equipped_magazine = MagazineLoaderClass.create_pistol_glock(0.20, 25, 10)
	weapon.set_motor_and_gearbox(8100.0, 30.0) # ROF = 4.5 BB/s, intervalo ~= 0.2222s
	weapon.fire_mode = WeaponClass.FireMode.SEMI
	weapon._ready()

	var dummy_scene = PackedScene.new()
	var dummy_node = Node3D.new()
	dummy_scene.pack(dummy_node)
	dummy_node.free()
	weapon.bb_scene = dummy_scene

	var interval = weapon.get_fire_interval()

	# 1. Primeiro disparo válido
	weapon.atirar(true)
	assert_eq(weapon.current_ammo, 9, "First trigger press should fire and consume 1 BB")
	weapon.atirar(false)

	# 2. Tentativa imediata (tempo decorrido = 0): DEVE SER DESCARTADA (Regra 2)
	weapon.atirar(true)
	assert_eq(weapon.current_ammo, 9, "Immediate trigger press must be discarded (Rule 2: interval blocking)")
	weapon.atirar(false)

	# 3. Avança tempo parcial (50% do intervalo): ainda bloqueado
	weapon._process(interval * 0.5)
	weapon.atirar(true)
	assert_eq(weapon.current_ammo, 9, "Trigger press within interval must be discarded")
	weapon.atirar(false)

	# 4. Avança restante do tempo (mais 60% do intervalo, total > 100%): cooldown zerou
	weapon._process(interval * 0.6)
	weapon.atirar(true)
	assert_eq(weapon.current_ammo, 8, "Trigger press after interval elapsed must fire successfully")
	weapon.atirar(false)

	weapon.free()


func test_cadence_rule_2_interval_blocking_auto() -> void:
	var weapon = WeaponClass.new()
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	weapon.equipped_magazine = MagazineLoaderClass.create_pistol_glock(0.20, 30, 30)
	weapon.set_motor_and_gearbox(8100.0, 30.0) # ROF = 4.5 BB/s, intervalo = 0.2222s
	weapon.fire_mode = WeaponClass.FireMode.AUTO
	weapon._ready()

	var dummy_scene = PackedScene.new()
	var dummy_node = Node3D.new()
	dummy_scene.pack(dummy_node)
	dummy_node.free()
	weapon.bb_scene = dummy_scene

	var interval = weapon.get_fire_interval()

	# Pressiona gatilho em AUTO -> 1º tiro disparado imediatamente
	weapon.atirar(true)
	assert_eq(weapon.current_ammo, 29, "Initial AUTO shot should fire immediately")

	# Simula pequenos passos de física / processo
	var step := 0.016666 # ~60 FPS
	var total_time := 0.0

	# Passo a passo até quase completar o 1º intervalo
	while total_time + step < interval:
		weapon._process(step)
		total_time += step

	assert_eq(weapon.current_ammo, 29, "No second shot before full interval in AUTO")

	# Passa o limite do intervalo
	weapon._process(step * 2.0)
	assert_eq(weapon.current_ammo, 28, "Second shot fired exactly after interval elapsed")

	# Solta o gatilho
	weapon.atirar(false)
	weapon._process(interval * 2.0)
	assert_eq(weapon.current_ammo, 28, "Releasing trigger must stop automatic firing")

	weapon.free()


func test_cadence_rule_3_verifiability_and_debugging() -> void:
	var weapon = WeaponClass.new()
	var cadence_signal_received = [false, 0.0, 0.0]
	var spring_signal_received = [false, 0.0]

	weapon.cadencia_alterada.connect(func(r: float, i: float):
		cadence_signal_received[0] = true
		cadence_signal_received[1] = r
		cadence_signal_received[2] = i
	)

	weapon.mola_ajustada.connect(func(e: float):
		spring_signal_received[0] = true
		spring_signal_received[1] = e
	)

	# Atualiza motor
	weapon.motor_rpm = 9000.0
	assert_true(cadence_signal_received[0], "cadencia_alterada signal must be emitted")
	assert_almost_eq(cadence_signal_received[1], 5.0, 0.001, "ROF should be 9000 / (60 * 30) = 5.0")
	assert_almost_eq(cadence_signal_received[2], 0.2, 0.001, "Interval should be 0.2s")

	# Verifica propriedades @export
	assert_almost_eq(weapon.rof, 5.0, 0.001, "Exported rof property must match")
	assert_almost_eq(weapon.fire_interval, 0.2, 0.001, "Exported fire_interval property must match")

	# Atualiza mola
	weapon.adjust_spring(1600.0, 0.05)
	assert_true(spring_signal_received[0], "mola_ajustada signal must be emitted")
	assert_almost_eq(spring_signal_received[1], 2.0, 0.001, "Energy should be 2.0J")

	# Depuração via print_cadence_debug
	weapon.print_cadence_debug()

	weapon.free()


func test_weapon_model_presets() -> void:
	var weapon = WeaponClass.new()

	weapon.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)
	assert_eq(weapon.compatible_magazine_type, MagazineClass.Type.MAG_RIFLE_STANAG)
	assert_almost_eq(weapon.energy_joules, 1.49, 0.01)
	assert_almost_eq(weapon.get_cadence_rpm(), 800.0, 1.0)
	assert_eq(weapon.get_weapon_model_name(), "Rifle")

	weapon.configure_weapon_preset(WeaponClass.WeaponModel.SHOTGUN)
	assert_eq(weapon.compatible_magazine_type, MagazineClass.Type.MAG_SHOTGUN_SHELL)
	assert_almost_eq(weapon.energy_joules, 1.1, 0.01)
	assert_almost_eq(weapon.get_cadence_rpm(), 50.0, 1.0)
	assert_eq(weapon.get_weapon_model_name(), "Shotgun")

	weapon.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_1911)
	assert_eq(weapon.compatible_magazine_type, MagazineClass.Type.MAG_PISTOL_1911)
	assert_almost_eq(weapon.energy_joules, 0.9, 0.01)
	assert_almost_eq(weapon.get_cadence_rpm(), 350.0, 1.0)
	assert_eq(weapon.get_weapon_model_name(), "Pistol1911")

	weapon.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_GLOCK)
	assert_eq(weapon.compatible_magazine_type, MagazineClass.Type.MAG_PISTOL_GLOCK)
	assert_almost_eq(weapon.energy_joules, 1.0, 0.01)
	assert_almost_eq(weapon.get_cadence_rpm(), 400.0, 1.0)
	assert_eq(weapon.get_weapon_model_name(), "PistolGlock")

	weapon.free()
