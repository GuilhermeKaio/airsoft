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
- Player input delegation: Player captures `_unhandled_input` and delegates to active weapon slot (`atirar`, `alternar_modo_tiro`, `recarregar`, `ajustar_hop_up`). Recarga é estritamente manual (tecla R / `recarregar`); disparar sem munição produz apenas dry-fire sem auto-recarga.
- Inventory / Slots: Slot 1 (primary) and Slot 2 (secondary) toggled via keys 1 and 2 (`weapon_slot_1`, `weapon_slot_2`). Keep `ctrl_pressed` ignored to preserve Ctrl+1..5 camera switching.
- Weapon Pickup & Swap: `WeaponPickup` on ground (`Scenes/weapon_pickup.tscn`) displays 3D model, ammo, and `[E] Trocar Arma`. Pressing `E` (action `interact`) swaps the player's active slot weapon, drops previous weapon to ground preserving model, magazine ammo, mass, hop-up, and energy.
- HUD synchronization: Purely reactive via signals (`weapon_swapped`, `ammo_changed`, `fire_mode_changed`, `hop_up_adjusted`, `incompatible_magazine`, `dry_fired`/`disparo_seco`, `bullet_tracing_toggled`). Displays temporary warning messages like `SEM MUNIÇÃO` and `CARREGADOR INCOMPATÍVEL`.
- Bullet Tracing Toggle (Ctrl+T): Toggles bullet trail renderers globally via `BB.toggle_global_trail_enabled()` / `Player.toggle_bullet_tracing()`, immediately clearing existing in-flight trails and disabling trail creation for subsequent shots. Notifies HUD reactively (`TRACING: DESATIVADO` / `TRACING: ATIVADO`).
- BB Lifetime & Despawn (SRS 3.6): Default flight time limit of 10.0s (`max_flight_time`). Upon first collision with ground or any body, timeout is set to 5.0s (`post_collision_flight_time`) before despawning (`queue_free()`) and deactivating trail. Signals `despawned` upon removal.
- Recoil Spray Pattern (CS / Valorant style - SRS Adicionais 3): Multi-phase recoil: Phase 1 vertical pitch climb (balas 1-5 no Rifle a 1.2°/bala), Phase 2 deriva lateral alternada (Yaw 0.9°). Recuperação suave interpola para zero em `recoil_recovery_time` (Rifle 0.25s, Glock Auto 0.20s, Glock Semi 0.15s, 1911 0.22s, Shotgun 0.40s). Disparar antes da recuperação preserva o índice do spray pattern. `fps_camera_look.gd` absorve compensação do mouse evitando "floor pull" na recuperação.
- Collision Isolation & Physics Layers (SRS Adicionais 5): Layer 1 (World), Layer 2 (Player), Layer 3 (Weapon), Layer 4 (BB_Projectile), Layer 5 (Targets), Layer 6 (Pickups). Projéteis BB monitoram estritamente `collision_mask = 17` (World + Targets), proibindo Player (Layer 2) e Weapon (Layer 3). Exceção programática em tempo de execução (`bullet.add_collision_exception_with(player)`) confere imunidade contra autocolisão.
