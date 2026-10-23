# Airsoft Simulator Runbook (Napkin)

## Testing & Execution
- Run unit test suite: `& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless -s tests/runner.gd | Out-String`
- In-memory weapon testing without node tree: always check `is_inside_tree()` before accessing `global_transform` to prevent engine condition errors.
- Headless asset re-import: `& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --editor --quit`

## Architecture & Conventions
- Models and textures reside in `res://Assets/` with `colormap.png` texturing (`PistolGlock.obj`, `Pistol1911.obj`, `Rifle.obj`, `Shotgun.obj`).
- OBJ models are natively aligned along -Z (barrel forward), +Y (up), and +X (right).
- First-Person Weapon Alignment: Weapon `global_transform` dynamically matches `camera3.global_transform.basis` with `first_person_offset`, guaranteeing 0 roll and preventing weapon tilting/crookedness when looking around. Muzzle firing direction uses `-muzzle.global_transform.basis.z.normalized()`.
- Ammo HUD dimensions: `offset_left = -900.0`, `offset_right = -24.0`, `offset_top = -90.0`, `offset_bottom = -20.0` with `font_size = 22` to comfortably fit long weapon titles without clipping off screen margins.
- Player input delegation: Player captures `_unhandled_input` and delegates to active weapon slot (`atirar`, `alternar_modo_tiro`, `recarregar`, `ajustar_hop_up`).
- Inventory / Slots: Slot 1 (primary) and Slot 2 (secondary) toggled via keys 1 and 2 (`weapon_slot_1`, `weapon_slot_2`). Keep `ctrl_pressed` ignored to preserve Ctrl+1..5 camera switching.
- Weapon Pickup & Swap: `WeaponPickup` on ground (`Scenes/weapon_pickup.tscn`) displays 3D model, ammo, and `[E] Trocar Arma`. Pressing `E` (action `interact`) swaps the player's active slot weapon, drops previous weapon to ground preserving model, magazine ammo, mass, hop-up, and energy.
- HUD synchronization: Purely reactive via signals (`weapon_swapped`, `ammo_changed`, `fire_mode_changed`, `hop_up_adjusted`, `incompatible_magazine`).
