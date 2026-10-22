extends RefCounted

const MagazinePickupClass = preload("res://Scripts/magazine_pickup.gd")
const WeaponClass = preload("res://Scripts/weapon.gd")
const MagazineClass = preload("res://Scripts/magazine.gd")
const MagazineLoaderClass = preload("res://Scripts/magazine_loader.gd")
const AmmoHUDClass = preload("res://Scripts/ammo_hud.gd")

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


func test_pickup_initialization() -> void:
	var pickup = MagazinePickupClass.new()
	var test_mag = MagazineLoaderClass.create_pistol_glock(0.25, 25, 20)
	pickup.magazine = test_mag
	pickup._ready()

	assert_eq(pickup.magazine.type, MagazineClass.Type.MAG_PISTOL_GLOCK)
	assert_eq(pickup.magazine.current_ammo, 20)
	assert_eq(pickup.magazine.capacity, 25)
	assert_eq(pickup.magazine.get_bb_mass_grams(), 0.25)

	# Label & visuals check
	assert_true(pickup.label != null, "Label3D deve ser inicializado")
	assert_true("Pistol Glock" in pickup.label.text, "Label deve conter nome da arma/tipo")
	assert_true("20 / 25" in pickup.label.text, "Label deve conter contagem de munição")
	assert_true("0.25g" in pickup.label.text, "Label deve conter massa da BB")

	pickup.free()


func test_compatible_pickup_and_swap() -> void:
	var weapon = WeaponClass.new()
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	weapon.equipped_magazine = MagazineLoaderClass.create_pistol_glock(0.20, 25, 12)
	weapon._ready()

	var pickup = MagazinePickupClass.new()
	var new_mag = MagazineLoaderClass.create_pistol_glock(0.25, 25, 25)
	pickup.magazine = new_mag
	pickup.drop_previous_on_swap = false
	pickup._ready()

	var picked_up_signal_received = [false]
	pickup.magazine_picked_up.connect(func(_p, _n, _d): picked_up_signal_received[0] = true)

	var success = pickup.try_pickup(weapon)
	assert_true(success, "Deveria aceitar carregador compatível Glock")
	assert_true(picked_up_signal_received[0], "Deveria emitir sinal magazine_picked_up")
	assert_eq(weapon.current_ammo, 25, "Arma deve atualizar munição para 25")
	assert_eq(weapon.bb_mass_grams, 0.25, "Arma deve atualizar gramatura para 0.25g")

	pickup.free()
	weapon.free()


func test_subsequent_shot_uses_new_bb_mass() -> void:
	var weapon = WeaponClass.new()
	weapon.energy_joules = 1.49
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	weapon.equipped_magazine = MagazineLoaderClass.create_pistol_glock(0.20, 25, 20)
	weapon._ready()

	var packed_scene = PackedScene.new()
	var dummy_node = Node3D.new()
	packed_scene.pack(dummy_node)
	dummy_node.free()
	weapon.bb_scene = packed_scene

	# Swap to heavier BB magazine (0.30g = 0.00030 kg)
	var pickup = MagazinePickupClass.new()
	pickup.magazine = MagazineLoaderClass.create_pistol_glock(0.30, 25, 25)
	pickup.drop_previous_on_swap = false
	pickup._ready()
	pickup.try_pickup(weapon)

	assert_eq(weapon.equipped_magazine.bb_mass_kg, 0.00030)
	
	# Expected velocity for 1.49J with 0.30g: sqrt(2 * 1.49 / 0.00030) = sqrt(9933.33) ~= 99.666 m/s
	var expected_v: float = sqrt((2.0 * weapon.energy_joules) / weapon.equipped_magazine.bb_mass_kg)
	assert_true(abs(expected_v - 99.666) < 0.1, "Velocidade subsequente deve refletir nova massa")

	weapon.fire()
	assert_eq(weapon.current_ammo, 24, "Disparo subsequente deve consumir munição do novo carregador")

	pickup.free()
	weapon.free()


func test_incompatible_magazine_rejected() -> void:
	var weapon = WeaponClass.new()
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	var original_mag = MagazineLoaderClass.create_pistol_glock(0.20, 25, 15)
	weapon.equipped_magazine = original_mag
	weapon._ready()

	var pickup = MagazinePickupClass.new()
	var incompatible_mag = MagazineLoaderClass.create_rifle_stanag(0.25, 30, 30)
	pickup.magazine = incompatible_mag
	pickup._ready()

	var weapon_incompat_fired = [false]
	var pickup_rejected_fired = [false]
	weapon.incompatible_magazine.connect(func(): weapon_incompat_fired[0] = true)
	pickup.pickup_rejected.connect(func(_p, _r): pickup_rejected_fired[0] = true)

	var success = pickup.try_pickup(weapon)
	assert_false(success, "Coleta de carregador incompatível deve falhar")
	assert_true(weapon_incompat_fired[0], "Arma deve emitir sinal incompatible_magazine")
	assert_true(pickup_rejected_fired[0], "Pickup deve emitir sinal pickup_rejected")
	assert_eq(weapon.equipped_magazine, original_mag, "Carregador da arma deve permanecer intacto")
	assert_eq(weapon.current_ammo, 15, "Munição da arma deve permanecer 15")
	assert_false(pickup.is_queued_for_deletion(), "Pickup incompatível não deve ser deletado da cena")

	pickup.free()
	weapon.free()


func test_hud_updates_immediately_on_pickup() -> void:
	var weapon = WeaponClass.new()
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	weapon.equipped_magazine = MagazineLoaderClass.create_pistol_glock(0.20, 25, 10)
	weapon._ready()

	var hud = AmmoHUDClass.new()
	hud.setup(weapon)
	assert_true("10 / 25" in hud.text)
	assert_true("0.20g" in hud.text)

	# Coleta carregador com 0.30g e 25 BBs
	var pickup = MagazinePickupClass.new()
	pickup.magazine = MagazineLoaderClass.create_pistol_glock(0.30, 25, 25)
	pickup.drop_previous_on_swap = false
	pickup._ready()
	pickup.try_pickup(weapon)

	# HUD deve ter atualizado reativamente sem polling
	assert_eq(hud.current_ammo, 25)
	assert_eq(hud.bb_mass_grams, 0.30)
	assert_true("25 / 25" in hud.text)
	assert_true("0.30g" in hud.text)

	# Tentar coletar incompatível deve mostrar notificação no HUD
	var incompat_pickup = MagazinePickupClass.new()
	incompat_pickup.magazine = MagazineLoaderClass.create_shotgun_shell(0.20, 30, 30)
	incompat_pickup._ready()
	incompat_pickup.try_pickup(weapon)

	assert_true("CARREGADOR INCOMPATÍVEL" in hud.text, "HUD deve exibir aviso de carregador incompatível")
	assert_true("25 / 25" in hud.text, "Dados da munição devem permanecer inalterados")

	incompat_pickup.free()
	pickup.free()
	hud.free()
	weapon.free()


func test_drop_previous_magazine_improvement() -> void:
	# Cria nó raiz para conter os nós da cena simulada
	var root = Node3D.new()

	var weapon = WeaponClass.new()
	weapon.compatible_magazine_type = MagazineClass.Type.MAG_PISTOL_GLOCK
	var old_mag = MagazineLoaderClass.create_pistol_glock(0.20, 25, 7)
	weapon.equipped_magazine = old_mag
	weapon._ready()
	root.add_child(weapon)

	var pickup = MagazinePickupClass.new()
	var new_mag = MagazineLoaderClass.create_pistol_glock(0.28, 25, 25)
	pickup.magazine = new_mag
	pickup.drop_previous_on_swap = true
	root.add_child(pickup)
	pickup._ready()

	var success = pickup.try_pickup(weapon)
	assert_true(success, "Deveria efetuar a troca")

	# Verifica se o carregador anterior foi spawnado na cena
	var found_dropped_pickup: Node = null
	for child in root.get_children():
		if child != pickup and (child is MagazinePickupClass or child.get_script() == MagazinePickupClass):
			found_dropped_pickup = child
			break

	assert_true(found_dropped_pickup != null, "Carregador anterior deve ser instanciado no cenário")
	if found_dropped_pickup != null:
		assert_eq(found_dropped_pickup.magazine.current_ammo, 7, "Carregador dropado deve preservar as 7 BBs restantes")
		assert_eq(found_dropped_pickup.magazine.get_bb_mass_grams(), 0.20, "Carregador dropado deve preservar massa de 0.20g")
		assert_eq(found_dropped_pickup.magazine.type, MagazineClass.Type.MAG_PISTOL_GLOCK)
		assert_true(found_dropped_pickup.pickup_cooldown > 0.0, "Carregador dropado deve possuir cooldown para evitar re-coleta imediata")
		found_dropped_pickup.free()

	pickup.free()
	weapon.free()
	root.free()
