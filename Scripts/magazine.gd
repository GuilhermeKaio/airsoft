class_name Magazine
extends Resource

## Represents a magazine for Airsoft replica weapons.
## Manages ammo count, capacity, BB mass (kg & grams), and compatibility types.

## Supported magazine types according to the simulator specification
enum Type {
	MAG_SHOTGUN_SHELL,
	MAG_RIFLE_STANAG,
	MAG_PISTOL_1911,
	MAG_PISTOL_GLOCK,
}

## Compatibility constants
const MAG_SHOTGUN_SHELL = Type.MAG_SHOTGUN_SHELL
const MAG_RIFLE_STANAG = Type.MAG_RIFLE_STANAG
const MAG_PISTOL_1911 = Type.MAG_PISTOL_1911
const MAG_PISTOL_GLOCK = Type.MAG_PISTOL_GLOCK

## Magazine state signals
signal ammo_changed(current: int, max_capacity: int)
signal emptied()
signal refilled()

## Magazine type (weapon compatibility)
@export var type: Type = Type.MAG_RIFLE_STANAG:
	set(value):
		type = value
		emit_changed()

## Maximum BB capacity in the magazine (C > 0)
@export_range(1, 1000, 1) var capacity: int = 30:
	set(value):
		capacity = maxi(1, value)
		if current_ammo > capacity:
			current_ammo = capacity
		emit_changed()
		ammo_changed.emit(current_ammo, capacity)

## Current ammo count remaining in the magazine (0 <= Q <= C)
@export_range(0, 1000, 1) var current_ammo: int = 30:
	set(value):
		var clamped_val: int = clampi(value, 0, capacity)
		if current_ammo != clamped_val:
			current_ammo = clamped_val
			emit_changed()
			ammo_changed.emit(current_ammo, capacity)
			if current_ammo == 0:
				emptied.emit()
			elif current_ammo == capacity:
				refilled.emit()

## Individual BB mass in kilograms (kg) for physics and ballistics calculations.
## Standard values: 0.20g = 0.00020 kg | 0.25g = 0.00025 kg | 0.32g = 0.00032 kg
@export var bb_mass_kg: float = 0.00020:
	set(value):
		bb_mass_kg = maxf(0.00001, value)
		emit_changed()


## Constructor for programmatic initialization
func _init(p_type: Type = Type.MAG_RIFLE_STANAG, p_capacity: int = 30, p_ammo: int = 30, p_mass_kg: float = 0.00020) -> void:
	type = p_type
	capacity = maxi(1, p_capacity)
	current_ammo = clampi(p_ammo, 0, capacity)
	bb_mass_kg = maxf(0.00001, p_mass_kg)


## Returns the friendly display name for a magazine type
static func get_type_name_for(t: Type) -> String:
	match t:
		Type.MAG_SHOTGUN_SHELL:
			return "Shotgun Shell"
		Type.MAG_RIFLE_STANAG:
			return "STANAG (Rifle)"
		Type.MAG_PISTOL_1911:
			return "Pistol 1911"
		Type.MAG_PISTOL_GLOCK:
			return "Pistol Glock"
		_:
			return "Unknown"


## Returns the friendly display name for this magazine
func get_type_name() -> String:
	return get_type_name_for(type)


## Returns the BB mass in grams (g) for HUD / UI display
func get_bb_mass_grams() -> float:
	return bb_mass_kg * 1000.0


## Sets the BB mass from grams (converts internally to kg)
func set_bb_mass_grams(grams: float) -> void:
	bb_mass_kg = grams / 1000.0


## Returns true if the magazine is empty
func is_empty() -> bool:
	return current_ammo <= 0


## Returns true if the magazine is fully loaded
func is_full() -> bool:
	return current_ammo >= capacity


## Consumes an amount of BBs from the magazine.
## Returns true if sufficient ammo was available and consumed; false otherwise.
func consume_bbs(amount: int = 1) -> bool:
	if amount <= 0:
		return true
	if current_ammo >= amount:
		current_ammo -= amount
		return true
	return false


## Adds BBs to the magazine up to maximum capacity.
## Returns the actual number of BBs inserted.
func add_bbs(amount: int) -> int:
	if amount <= 0:
		return 0
	var space_left: int = capacity - current_ammo
	var to_add: int = mini(space_left, amount)
	if to_add > 0:
		current_ammo += to_add
	return to_add


## Fills the magazine to full capacity
func refill() -> void:
	current_ammo = capacity


## Empties the magazine completely and returns the discarded count
func unload_all() -> int:
	var prev := current_ammo
	current_ammo = 0
	return prev


## Validates whether this magazine is compatible with a weapon's required type
func is_compatible_with(target_type: Type) -> bool:
	return type == target_type


## Creates an independent clone of this resource
func clone() -> Resource:
	var script_ref: GDScript = get_script()
	var mag = script_ref.new(type, capacity, current_ammo, bb_mass_kg)
	return mag
