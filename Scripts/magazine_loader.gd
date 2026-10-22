class_name MagazineLoader
extends RefCounted

## Factory and management utility for Magazines and Speedloaders.
## Creates pre-configured magazines matching replica specifications,
## manages speedloading, and validates weapon compatibility.

const Magazine = preload("res://Scripts/magazine.gd")

const GRAMS_TO_KG: float = 0.001
const KG_TO_GRAMS: float = 1000.0


## Converts grams to kilograms (e.g. 0.20g -> 0.00020 kg)
static func grams_to_kg(grams: float) -> float:
	return grams * GRAMS_TO_KG


## Converts kilograms to grams (e.g. 0.00020 kg -> 0.20g)
static func kg_to_grams(kg: float) -> float:
	return kg * KG_TO_GRAMS


## Creates a custom configured magazine
static func create_magazine(
	type: Magazine.Type,
	capacity: int,
	current_ammo: int = -1,
	bb_mass_grams: float = 0.20
) -> Magazine:
	var final_ammo := capacity if current_ammo < 0 else current_ammo
	return Magazine.new(type, capacity, final_ammo, grams_to_kg(bb_mass_grams))


## Creates a standard Shotgun shell (MAG_SHOTGUN_SHELL)
## Specification: 30 BBs (10 shots of 3 BBs), typical mass: 0.20g
static func create_shotgun_shell(
	bb_mass_grams: float = 0.20,
	capacity: int = 30,
	current_ammo: int = -1
) -> Magazine:
	return create_magazine(Magazine.Type.MAG_SHOTGUN_SHELL, capacity, current_ammo, bb_mass_grams)


## Creates a standard Rifle STANAG magazine (MAG_RIFLE_STANAG)
## Specification: Real-Cap (30 BBs) or Mid-Cap (120 BBs), calibrated for 0.25g - 0.30g
static func create_rifle_stanag(
	bb_mass_grams: float = 0.25,
	capacity: int = 30,
	current_ammo: int = -1
) -> Magazine:
	return create_magazine(Magazine.Type.MAG_RIFLE_STANAG, capacity, current_ammo, bb_mass_grams)


## Creates a standard single-stack Pistol 1911 magazine (MAG_PISTOL_1911)
## Specification: Low capacity (14 to 16 BBs, default 15), typical mass: 0.20g
static func create_pistol_1911(
	bb_mass_grams: float = 0.20,
	capacity: int = 15,
	current_ammo: int = -1
) -> Magazine:
	return create_magazine(Magazine.Type.MAG_PISTOL_1911, capacity, current_ammo, bb_mass_grams)


## Creates a standard double-stack Pistol Glock magazine (MAG_PISTOL_GLOCK)
## Specification: High capacity (22 to 25 BBs, default 25), typical mass: 0.20g
static func create_pistol_glock(
	bb_mass_grams: float = 0.20,
	capacity: int = 25,
	current_ammo: int = -1
) -> Magazine:
	return create_magazine(Magazine.Type.MAG_PISTOL_GLOCK, capacity, current_ammo, bb_mass_grams)


## Validates whether a magazine is compatible with a weapon's required magazine type
static func check_compatibility(weapon_type: Magazine.Type, magazine: Magazine) -> bool:
	if magazine == null:
		return false
	return magazine.type == weapon_type


## Loads BBs into a magazine (speedloader action)
## Returns the actual number of BBs added
static func load_magazine(target: Magazine, amount: int) -> int:
	if target == null:
		return 0
	return target.add_bbs(amount)


## Unloads BBs from a magazine
## If amount < 0, unloads all remaining BBs. Returns the number of removed BBs.
static func unload_magazine(target: Magazine, amount: int = -1) -> int:
	if target == null:
		return 0
	if amount < 0 or amount >= target.current_ammo:
		return target.unload_all()
	target.current_ammo -= amount
	return amount


## Transfers BBs from a source (another magazine or speedloader) to a target magazine
## Returns the count of transferred BBs
static func transfer_bbs(source: Magazine, target: Magazine, max_transfer: int = 9999) -> int:
	if source == null or target == null:
		return 0
	if source.is_empty() or target.is_full() or max_transfer <= 0:
		return 0

	var available_in_source: int = source.current_ammo
	var space_in_target: int = target.capacity - target.current_ammo
	var count_to_move: int = mini(mini(available_in_source, space_in_target), max_transfer)

	if count_to_move > 0:
		source.consume_bbs(count_to_move)
		target.add_bbs(count_to_move)

	return count_to_move
