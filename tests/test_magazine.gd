extends RefCounted

const Magazine = preload("res://Scripts/magazine.gd")
const MagazineLoader = preload("res://Scripts/magazine_loader.gd")

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


func test_magazine_initialization() -> void:
	var mag = Magazine.new()
	assert_eq(mag.type, Magazine.Type.MAG_RIFLE_STANAG, "Tipo padrão deve ser STANAG")
	assert_eq(mag.capacity, 30, "Capacidade padrão deve ser 30")
	assert_eq(mag.current_ammo, 30, "Munição inicial deve ser 30")
	assert_eq(mag.bb_mass_kg, 0.00020, "Massa padrão deve ser 0.00020 kg")
	assert_false(mag.is_empty(), "Não deve iniciar vazio")
	assert_true(mag.is_full(), "Deve iniciar cheio por padrão")


func test_compatibility_types() -> void:
	# Verifica que os 4 tipos normativos do SRS existem
	assert_eq(Magazine.MAG_SHOTGUN_SHELL, Magazine.Type.MAG_SHOTGUN_SHELL)
	assert_eq(Magazine.MAG_RIFLE_STANAG, Magazine.Type.MAG_RIFLE_STANAG)
	assert_eq(Magazine.MAG_PISTOL_1911, Magazine.Type.MAG_PISTOL_1911)
	assert_eq(Magazine.MAG_PISTOL_GLOCK, Magazine.Type.MAG_PISTOL_GLOCK)

	var shotgun_mag = Magazine.new(Magazine.Type.MAG_SHOTGUN_SHELL, 30, 30, 0.00020)
	assert_true(shotgun_mag.is_compatible_with(Magazine.Type.MAG_SHOTGUN_SHELL))
	assert_false(shotgun_mag.is_compatible_with(Magazine.Type.MAG_RIFLE_STANAG))
	assert_false(shotgun_mag.is_compatible_with(Magazine.Type.MAG_PISTOL_1911))
	assert_false(shotgun_mag.is_compatible_with(Magazine.Type.MAG_PISTOL_GLOCK))

	# Teste de compatibilidade com helper MagazineLoader
	assert_true(MagazineLoader.check_compatibility(Magazine.Type.MAG_SHOTGUN_SHELL, shotgun_mag))
	assert_false(MagazineLoader.check_compatibility(Magazine.Type.MAG_RIFLE_STANAG, shotgun_mag))


func test_consumption_and_empty() -> void:
	var mag = Magazine.new(Magazine.Type.MAG_RIFLE_STANAG, 5, 5, 0.00025)
	
	# Consome 1 a 1
	var success = mag.consume_bbs(1)
	assert_true(success, "Deveria consumir com sucesso 1 BB")
	assert_eq(mag.current_ammo, 4)

	# Shotgun consome 3 BBs simultâneas
	success = mag.consume_bbs(3)
	assert_true(success, "Deveria consumir 3 BBs")
	assert_eq(mag.current_ammo, 1)

	# Tentar consumir 2 quando resta apenas 1 deve falhar (disparo a seco)
	success = mag.consume_bbs(2)
	assert_false(success, "Não deve permitir consumo se insuficiente")
	assert_eq(mag.current_ammo, 1, "Munição não deve mudar se o consumo falhar")

	# Consome a última BB
	success = mag.consume_bbs(1)
	assert_true(success)
	assert_eq(mag.current_ammo, 0)
	assert_true(mag.is_empty(), "Deve acusar vazio")

	# Tentativa em carregador vazio
	assert_false(mag.consume_bbs(1), "Não deve atirar com carregador vazio")


func test_mass_and_conversions() -> void:
	var mag = Magazine.new(Magazine.Type.MAG_RIFLE_STANAG, 30, 30, 0.00025)
	# 0.00025 kg == 0.25 g
	assert_eq(mag.get_bb_mass_grams(), 0.25)

	# Define em gramas (ex: 0.32g)
	mag.set_bb_mass_grams(0.32)
	assert_eq(mag.bb_mass_kg, 0.00032)
	assert_eq(mag.get_bb_mass_grams(), 0.32)

	# Funções utilitárias do MagazineLoader
	assert_eq(MagazineLoader.grams_to_kg(0.20), 0.00020)
	assert_eq(MagazineLoader.kg_to_grams(0.00020), 0.20)


func test_magazine_loader_factory() -> void:
	var shotgun = MagazineLoader.create_shotgun_shell()
	assert_eq(shotgun.type, Magazine.Type.MAG_SHOTGUN_SHELL)
	assert_eq(shotgun.capacity, 30)
	assert_eq(shotgun.get_bb_mass_grams(), 0.20)

	var rifle = MagazineLoader.create_rifle_stanag()
	assert_eq(rifle.type, Magazine.Type.MAG_RIFLE_STANAG)
	assert_eq(rifle.capacity, 30)
	assert_eq(rifle.get_bb_mass_grams(), 0.25)

	var pistol1911 = MagazineLoader.create_pistol_1911()
	assert_eq(pistol1911.type, Magazine.Type.MAG_PISTOL_1911)
	assert_eq(pistol1911.capacity, 15)
	assert_eq(pistol1911.get_bb_mass_grams(), 0.20)

	var glock = MagazineLoader.create_pistol_glock()
	assert_eq(glock.type, Magazine.Type.MAG_PISTOL_GLOCK)
	assert_eq(glock.capacity, 25)
	assert_eq(glock.get_bb_mass_grams(), 0.20)


func test_speedloader_and_transfer() -> void:
	var mag = Magazine.new(Magazine.Type.MAG_PISTOL_GLOCK, 25, 0, 0.00020)
	assert_true(mag.is_empty())

	# Adiciona 10 BBs com speedloader
	var added = MagazineLoader.load_magazine(mag, 10)
	assert_eq(added, 10)
	assert_eq(mag.current_ammo, 10)

	# Tenta adicionar 20 BBs (capacidade 25, restam 15 vagas)
	added = MagazineLoader.load_magazine(mag, 20)
	assert_eq(added, 15, "Deve adicionar apenas as 15 vagas restantes")
	assert_true(mag.is_full())

	# Transfere entre carregadores
	var source = mag
	var target = Magazine.new(Magazine.Type.MAG_PISTOL_GLOCK, 25, 0, 0.00020)
	var transferred = MagazineLoader.transfer_bbs(source, target, 5)
	assert_eq(transferred, 5)
	assert_eq(source.current_ammo, 20)
	assert_eq(target.current_ammo, 5)


func test_saved_tres_resources() -> void:
	var stanag_res = load("res://Resources/Magazines/rifle_stanag_30bb_025g.tres")
	assert_true(stanag_res != null, "Recurso stanag deve ser carregado com sucesso")
	assert_eq(stanag_res.type, Magazine.Type.MAG_RIFLE_STANAG)
	assert_eq(stanag_res.capacity, 30)
	assert_eq(stanag_res.bb_mass_kg, 0.00025)

	var shotgun_res = load("res://Resources/Magazines/shotgun_shell_30bb_020g.tres")
	assert_true(shotgun_res != null)
	assert_eq(shotgun_res.type, Magazine.Type.MAG_SHOTGUN_SHELL)

	var p1911_res = load("res://Resources/Magazines/pistol_1911_15bb_020g.tres")
	assert_true(p1911_res != null)
	assert_eq(p1911_res.type, Magazine.Type.MAG_PISTOL_1911)

	var glock_res = load("res://Resources/Magazines/pistol_glock_25bb_020g.tres")
	assert_true(glock_res != null)
	assert_eq(glock_res.type, Magazine.Type.MAG_PISTOL_GLOCK)
