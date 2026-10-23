extends RefCounted

const PlayerClass = preload("res://Scripts/player.gd")
const WeaponClass = preload("res://Scripts/weapon.gd")
const AmmoHUDClass = preload("res://Scripts/ammo_hud.gd")
const MagazineClass = preload("res://Scripts/magazine.gd")
const MagazinePickupClass = preload("res://Scripts/magazine_pickup.gd")

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


func test_inventory_slot_initialization() -> void:
	var player = PlayerClass.new()
	var rifle = WeaponClass.new()
	rifle.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)
	var glock = WeaponClass.new()
	glock.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_GLOCK)

	player.weapon_slot_1 = rifle
	player.weapon_slot_2 = glock
	player._ready()

	assert_eq(player.active_slot, 1, "Default active slot is 1")
	assert_eq(player.get_weapon(), rifle, "Active weapon should be Slot 1 (Rifle)")
	assert_true(rifle.visible, "Primary weapon is visible")
	assert_false(glock.visible, "Secondary weapon is hidden")

	rifle.free()
	glock.free()
	player.free()


func test_inventory_slot_switching() -> void:
	var player = PlayerClass.new()
	var rifle = WeaponClass.new()
	rifle.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)
	var glock = WeaponClass.new()
	glock.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_GLOCK)

	player.weapon_slot_1 = rifle
	player.weapon_slot_2 = glock
	player._ready()

	var swapped_events: Array = []
	player.weapon_swapped.connect(func(w, slot): swapped_events.append([w, slot]))

	# Switch to Slot 2
	var success = player.select_slot(2)
	assert_true(success, "Should switch to slot 2")
	assert_eq(player.active_slot, 2)
	assert_eq(player.get_weapon(), glock)
	assert_false(rifle.visible, "Rifle should now be hidden")
	assert_true(glock.visible, "Glock should now be visible")
	assert_eq(swapped_events.size(), 1)
	assert_eq(swapped_events[0][0], glock)
	assert_eq(swapped_events[0][1], 2)

	# Switch back to Slot 1 via alias selecionar_slot
	success = player.selecionar_slot(1)
	assert_true(success)
	assert_eq(player.active_slot, 1)
	assert_eq(player.get_weapon(), rifle)
	assert_true(rifle.visible)
	assert_false(glock.visible)
	assert_eq(swapped_events.size(), 2)

	# Invalid slot selection
	assert_false(player.select_slot(3), "Invalid slot index 3")
	assert_false(player.select_slot(0), "Invalid slot index 0")

	rifle.free()
	glock.free()
	player.free()


func test_keyboard_input_slot_switching() -> void:
	var player = PlayerClass.new()
	var rifle = WeaponClass.new()
	rifle.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)
	var glock = WeaponClass.new()
	glock.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_GLOCK)

	player.equip_weapon_in_slot(rifle, 1)
	player.equip_weapon_in_slot(glock, 2)
	player.select_slot(1, true)

	assert_eq(player.active_slot, 1)

	# 1. Press Key 2 (keycode 50) without Ctrl
	var ev_key2 = InputEventKey.new()
	ev_key2.keycode = KEY_2
	ev_key2.pressed = true
	ev_key2.echo = false
	ev_key2.ctrl_pressed = false
	player._unhandled_input(ev_key2)

	assert_eq(player.active_slot, 2, "Pressing key 2 switches to slot 2")
	assert_eq(player.get_weapon(), glock)

	# 2. Press Ctrl+1 (should NOT switch slot because Ctrl is used for camera look)
	var ev_ctrl1 = InputEventKey.new()
	ev_ctrl1.keycode = KEY_1
	ev_ctrl1.pressed = true
	ev_ctrl1.echo = false
	ev_ctrl1.ctrl_pressed = true
	player._unhandled_input(ev_ctrl1)

	assert_eq(player.active_slot, 2, "Ctrl+1 should NOT trigger weapon slot switch")

	# 3. Press Key 1 without Ctrl
	var ev_key1 = InputEventKey.new()
	ev_key1.keycode = KEY_1
	ev_key1.pressed = true
	ev_key1.echo = false
	ev_key1.ctrl_pressed = false
	player._unhandled_input(ev_key1)

	assert_eq(player.active_slot, 1, "Pressing key 1 switches to slot 1")
	assert_eq(player.get_weapon(), rifle)

	# 4. Action weapon_slot_2
	var ev_act2 = InputEventAction.new()
	ev_act2.action = "weapon_slot_2"
	ev_act2.pressed = true
	player._unhandled_input(ev_act2)

	assert_eq(player.active_slot, 2, "Action weapon_slot_2 switches to slot 2")

	rifle.free()
	glock.free()
	player.free()


func test_hud_auto_updates_on_slot_switch() -> void:
	var player = PlayerClass.new()
	var rifle = WeaponClass.new()
	rifle.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)
	rifle._ready()

	var shotgun = WeaponClass.new()
	shotgun.configure_weapon_preset(WeaponClass.WeaponModel.SHOTGUN)
	shotgun._ready()

	player.weapon_slot_1 = rifle
	player.weapon_slot_2 = shotgun
	player._ready()

	var hud = AmmoHUDClass.new()
	hud.setup(player.get_weapon())
	player.weapon_swapped.connect(hud._on_player_weapon_swapped)

	assert_true("Rifle" in hud.text, "HUD displays Rifle")
	assert_true("30 / 30" in hud.text)

	# Switch to Slot 2 (Shotgun)
	player.select_slot(2)
	assert_true("Shotgun" in hud.text, "HUD automatically displays Shotgun after swap")
	assert_true("30 / 30" in hud.text)

	hud.free()
	rifle.free()
	shotgun.free()
	player.free()


func test_magazine_pickup_with_active_slot() -> void:
	var player = PlayerClass.new()
	var rifle = WeaponClass.new()
	rifle.configure_weapon_preset(WeaponClass.WeaponModel.RIFLE)
	rifle._ready()

	var glock = WeaponClass.new()
	glock.configure_weapon_preset(WeaponClass.WeaponModel.PISTOL_GLOCK)
	glock._ready()

	player.weapon_slot_1 = rifle
	player.weapon_slot_2 = glock
	player._ready()

	var pickup = MagazinePickupClass.new()
	pickup.drop_previous_on_swap = false

	# Active weapon is Slot 1 (Rifle -> STANAG)
	# Glock magazine is incompatible with active Rifle
	pickup.setup_magazine(MagazineClass.Type.MAG_PISTOL_GLOCK, 25, 25, 0.00025)
	var picked = pickup.try_pickup(player)
	assert_false(picked, "Glock magazine rejected by active Rifle in Slot 1")

	# Switch to Slot 2 (Glock)
	player.select_slot(2)
	picked = pickup.try_pickup(player)
	assert_true(picked, "Glock magazine accepted by active Glock in Slot 2")

	pickup.free()
	rifle.free()
	glock.free()
	player.free()
