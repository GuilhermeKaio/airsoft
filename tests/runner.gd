extends SceneTree

func _init() -> void:
	_initialize()

func _initialize() -> void:
	print("==================================================")
	print("--- EXECUTING SIMULATOR UNIT TESTS ---")
	print("==================================================")

	var passed = 0
	var failed = 0

	# 1. Magazine tests
	var mag_test = load("res://tests/test_magazine.gd").new()
	var mag_methods = [
		"test_magazine_initialization",
		"test_compatibility_types",
		"test_consumption_and_empty",
		"test_mass_and_conversions",
		"test_magazine_loader_factory",
		"test_speedloader_and_transfer",
		"test_saved_tres_resources"
	]
	
	print("\n[Magazine & Loader]")
	for m in mag_methods:
		mag_test._reset()
		mag_test.call(m)
		if mag_test._failed:
			print("  [FAILED] %s -> %s" % [m, mag_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 2. Weapon tests
	var weapon_test = load("res://tests/test_weapon.gd").new()
	var weapon_methods = [
		"test_weapon_initialization",
		"test_weapon_magazine_compatibility",
		"test_weapon_firing_and_dry_fire",
		"test_hop_up_and_fire_mode",
		"test_hop_up_unhandled_input_mouse_wheel",
		"test_delegated_commands_api"
	]

	print("\n[Weapon & Integration]")
	for m in weapon_methods:
		weapon_test._reset()
		weapon_test.call(m)
		if weapon_test._failed:
			print("  [FAILED] %s -> %s" % [m, weapon_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 3. Player input delegation tests (SRS Sections 2 & 3.1)
	var player_test = load("res://tests/test_player.gd").new()
	var player_methods = [
		"test_player_weapon_reference",
		"test_delegation_atirar",
		"test_delegation_alternar_modo_tiro",
		"test_delegation_recarregar",
		"test_delegation_ajustar_hop_up",
		"test_unhandled_input_delegation",
		"test_player_and_real_weapon_integration"
	]

	print("\n[Player (Command Delegation)]")
	for m in player_methods:
		player_test._reset()
		player_test.call(m)
		if player_test._failed:
			print("  [FAILED] %s -> %s" % [m, player_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 4. Ammo HUD tests
	var hud_test = load("res://tests/test_ammo_hud.gd").new()
	var hud_methods = [
		"test_hud_initialization_with_weapon",
		"test_reactive_signals_update",
		"test_no_polling_in_process",
		"test_reactive_magazine_change",
		"test_temporary_notifications"
	]

	print("\n[Ammo HUD (Reactive Signals)]")
	for m in hud_methods:
		hud_test._reset()
		hud_test.call(m)
		if hud_test._failed:
			print("  [FAILED] %s -> %s" % [m, hud_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 4. Magazine Pickup & Scenario Swap tests (Requirement 5)
	var pickup_test = load("res://tests/test_magazine_pickup.gd").new()
	var pickup_methods = [
		"test_pickup_initialization",
		"test_compatible_pickup_and_swap",
		"test_subsequent_shot_uses_new_bb_mass",
		"test_incompatible_magazine_rejected",
		"test_hud_updates_immediately_on_pickup",
		"test_drop_previous_magazine_improvement"
	]

	print("\n[Magazine Pickup & Scenario Swap (Requirement 5)]")
	for m in pickup_methods:
		pickup_test._reset()
		pickup_test.call(m)
		if pickup_test._failed:
			print("  [FAILED] %s -> %s" % [m, pickup_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 5. Spring Physical Model & Motor Cadence tests (SRS 3.2.1 & 3.2.2)
	var sm_test = load("res://tests/test_spring_and_motor.gd").new()
	var sm_methods = [
		"test_spring_physical_model_formula",
		"test_spring_simplified_model",
		"test_bb_velocity_calculation_dynamic_mass",
		"test_spring_energy_affects_bb_velocity",
		"test_motor_cadence_formula_srs_calibration",
		"test_cadence_rule_1_sensitivity",
		"test_cadence_rule_2_interval_blocking_semi",
		"test_cadence_rule_2_interval_blocking_auto",
		"test_cadence_rule_3_verifiability_and_debugging",
		"test_weapon_model_presets"
	]

	print("\n[Spring Model & Motor Cadence (SRS 3.2.1 & 3.2.2)]")
	for m in sm_methods:
		sm_test._reset()
		sm_test.call(m)
		if sm_test._failed:
			print("  [FAILED] %s -> %s" % [m, sm_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	print("\n==================================================")
	print("--- TOTAL: %d passed, %d failed ---" % [passed, failed])
	print("==================================================")
	quit(1 if failed > 0 else 0)
