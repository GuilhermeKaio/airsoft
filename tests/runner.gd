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
		"test_hop_up_unhandled_input_mouse_wheel"
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

	# 3. Ammo HUD tests
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

	print("\n==================================================")
	print("--- TOTAL: %d passed, %d failed ---" % [passed, failed])
	print("==================================================")
	quit(1 if failed > 0 else 0)
