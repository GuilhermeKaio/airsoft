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

	# 6. Weapon Types & Specific Models (SRS Seção 4)
	var wt_test = load("res://tests/test_weapon_types.gd").new()
	var wt_methods = [
		"test_shotgun_specs_and_consumption",
		"test_rifle_specs_and_modes",
		"test_pistol_1911_specs_and_slide_lock",
		"test_pistol_glock_specs_and_rpm_switch",
		"test_weapon_prefabs_from_assets"
	]

	print("\n[Weapon Types & Specific Models (SRS Seção 4)]")
	for m in wt_methods:
		wt_test._reset()
		wt_test.call(m)
		if wt_test._failed:
			print("  [FAILED] %s -> %s" % [m, wt_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 7. Inventory & Weapon Slots 1 and 2 (SRS Seção 4 & 6)
	var inv_test = load("res://tests/test_inventory.gd").new()
	var inv_methods = [
		"test_inventory_slot_initialization",
		"test_inventory_slot_switching",
		"test_keyboard_input_slot_switching",
		"test_hud_auto_updates_on_slot_switch",
		"test_magazine_pickup_with_active_slot"
	]

	print("\n[Inventory & Weapon Slots 1 and 2 (SRS Seção 4 & 6)]")
	for m in inv_methods:
		inv_test._reset()
		inv_test.call(m)
		if inv_test._failed:
			print("  [FAILED] %s -> %s" % [m, inv_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 8. Weapon Pickups on Ground & E-Key Swap
	var wp_test = load("res://tests/test_weapon_pickup.gd").new()
	var wp_methods = [
		"test_weapon_pickup_initialization",
		"test_swap_weapon_with_e_key",
		"test_weapon_drop_preserves_state",
		"test_pickup_in_secondary_slot",
		"test_hud_updates_on_weapon_pickup"
	]

	print("\n[Weapon Pickups & E-Key Weapon Swap]")
	for m in wp_methods:
		wp_test._reset()
		wp_test.call(m)
		if wp_test._failed:
			print("  [FAILED] %s -> %s" % [m, wp_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 9. Weapon Alignment & HUD Bounds Fixes
	var align_test = load("res://tests/test_weapon_alignment.gd").new()
	var align_methods = [
		"test_first_person_alignment_with_camera",
		"test_all_prefabs_mesh_and_muzzle_zero_tilt",
		"test_ammo_hud_dimensions_and_no_clipping"
	]

	print("\n[Weapon Alignment & HUD Bounds (Anti-Crooked & Clipping Fixes)]")
	for m in align_methods:
		align_test._reset()
		align_test.call(m)
		if align_test._failed:
			print("  [FAILED] %s -> %s" % [m, align_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 10. Bullet Tracing & Ctrl+T Shortcut
	var tracing_test = load("res://tests/test_bullet_tracing.gd").new()
	var tracing_methods = [
		"test_bb_global_trail_state_and_toggle",
		"test_in_flight_bullet_trail_disabling",
		"test_weapon_bullet_tracing_integration",
		"test_player_tracing_api_and_signals",
		"test_player_shortcut_ctrl_t_input",
		"test_main_shortcut_ctrl_t_input",
		"test_hud_notification_on_tracing_toggled"
	]

	print("\n[Bullet Tracing & Ctrl+T Shortcut]")
	for m in tracing_methods:
		tracing_test._reset()
		tracing_test.call(m)
		if tracing_test._failed:
			print("  [FAILED] %s -> %s" % [m, tracing_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 11. BB Flight Timeout / Despawn & Dry Fire HUD (SRS 3.3.1, 3.5.2 & 3.6)
	var bb_despawn_test = load("res://tests/test_bb_despawn.gd").new()
	var bb_despawn_methods = [
		"test_bb_flight_time_limit_configuration",
		"test_bb_flight_time_accumulation_and_despawn",
		"test_bb_physics_process_triggers_despawn",
		"test_bb_collision_despawn",
		"test_bb_trail_cleanup_upon_despawn",
		"test_bb_flight_time_helpers",
		"test_dry_fire_hud_notification_integration"
	]

	print("\n[BB Flight Timeout, Despawn & HUD Dry Fire (SRS 3.3.1, 3.5.2 & 3.6)]")
	for m in bb_despawn_methods:
		bb_despawn_test._reset()
		bb_despawn_test.call(m)
		if bb_despawn_test._failed:
			print("  [FAILED] %s -> %s" % [m, bb_despawn_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 12. Recoil Spray Pattern System (SRS Adicionais Seção 3)
	var recoil_test = load("res://tests/test_recoil.gd").new()
	var recoil_methods = [
		"test_recoil_weapon_presets_parameters",
		"test_rifle_spray_pattern_phases",
		"test_glock_fire_mode_toggle_updates_recoil",
		"test_recoil_recovery_and_reset_timing",
		"test_camera_recoil_and_compensation"
	]

	print("\n[Recoil Spray Pattern (CS / Valorant Style - SRS Adicionais Seção 3)]")
	for m in recoil_methods:
		recoil_test._reset()
		recoil_test.call(m)
		if recoil_test._failed:
			print("  [FAILED] %s -> %s" % [m, recoil_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 13. Bullet Collision Isolation & Exceptions (SRS Adicionais Seção 5)
	var collision_test = load("res://tests/test_collision_isolation.gd").new()
	var collision_methods = [
		"test_layer_names_configured_in_project",
		"test_bb_collision_layer_and_mask_isolation",
		"test_player_collision_layer_and_mask",
		"test_pickups_collision_layer_and_mask",
		"test_runtime_collision_exception_with_player"
	]

	print("\n[Collision Isolation & Filters (SRS Adicionais Seção 5)]")
	for m in collision_methods:
		collision_test._reset()
		collision_test.call(m)
		if collision_test._failed:
			print("  [FAILED] %s -> %s" % [m, collision_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 14. Pause Screen & Double Sensitivity Control (SRS Seção 6.2)
	var pause_test = load("res://tests/test_pause_screen.gd").new()
	var pause_methods = [
		"test_pause_screen_ui_elements",
		"test_two_way_slider_and_line_edit_sync",
		"test_settings_persistence",
		"test_immediate_runtime_application_to_camera",
		"test_pause_and_resume_flow"
	]

	print("\n[Pause Screen & Double Sensitivity Control (SRS Seção 6.2)]")
	for m in pause_methods:
		pause_test._reset()
		pause_test.call(m)
		if pause_test._failed:
			print("  [FAILED] %s -> %s" % [m, pause_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 15. Valorant Ballistic Rotation Conversion (SRS Seção 6.1)
	var val_test = load("res://tests/test_valorant_sensitivity.gd").new()
	var val_methods = [
		"test_valorant_scale_constants",
		"test_camera_rotation_calculation",
		"test_custom_sensitivity_scaling",
		"test_pitch_clamping"
	]

	print("\n[Valorant Ballistic Rotation Conversion (SRS Seção 6.1)]")
	for m in val_methods:
		val_test._reset()
		val_test.call(m)
		if val_test._failed:
			print("  [FAILED] %s -> %s" % [m, val_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	# 16. Ballistics Deflection, Aim & Dynamic Crosshair (SRS Adicionais Seção 7)
	var ballistics_aim_test = load("res://tests/test_ballistics_and_aim.gd").new()
	var ballistics_aim_methods = [
		"test_kinematic_states_and_speed_thresholds",
		"test_kinematic_spread_cone_angles",
		"test_deadzoning_and_accuracy_threshold",
		"test_counter_strafing_braking_and_smooth_interpolation",
		"test_weapon_total_spread_formula",
		"test_bb_ballistic_cone_deflection_calculation",
		"test_dynamic_crosshair_reactivity",
		"test_player_crosshair_signal_integration"
	]

	print("\n[Ballistics Deflection, Deadzoning & Dynamic Crosshair (SRS Adicionais Seção 7)]")
	for m in ballistics_aim_methods:
		ballistics_aim_test._reset()
		ballistics_aim_test.call(m)
		if ballistics_aim_test._failed:
			print("  [FAILED] %s -> %s" % [m, ballistics_aim_test._message])
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1
			failed += 1
		else:
			print("  [PASSED] %s" % m)
			passed += 1

	print("\n==================================================")
	print("--- TOTAL: %d passed, %d failed ---" % [passed, failed])
	print("==================================================")
	quit(1 if failed > 0 else 0)
