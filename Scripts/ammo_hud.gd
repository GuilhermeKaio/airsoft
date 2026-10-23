extends Label

@export var weapon_path: NodePath = ^"../../Player/Weapon"
@export var camera_path: NodePath = ^"../../Player/Camera3"
@export var player_path: NodePath = ^"../../Player"

@onready var camera3: Camera3D = get_node_or_null(camera_path)
@onready var weapon: Node = get_node_or_null(weapon_path)
@onready var player: Node = get_node_or_null(player_path)

var current_ammo: int = 0
var magazine_capacity: int = 0
var bb_mass_grams: float = 0.0
var fire_mode: String = "SEMI"
var hop_up: float = 0.0

var _notification_text: String = ""
var _notification_tween: Tween = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -900.0
	offset_top = -90.0
	offset_right = -24.0
	offset_bottom = -20.0
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_size_override("font_size", 22)
	add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.75))
	add_theme_constant_override("shadow_offset_x", 2)
	add_theme_constant_override("shadow_offset_y", 2)

	if player:
		if player.has_signal("weapon_swapped") and not player.weapon_swapped.is_connected(_on_player_weapon_swapped):
			player.weapon_swapped.connect(_on_player_weapon_swapped)
		elif player.has_signal("arma_trocada") and not player.arma_trocada.is_connected(_on_player_weapon_swapped):
			player.arma_trocada.connect(_on_player_weapon_swapped)

	if weapon:
		setup(weapon)
	elif player and player.has_method("get_weapon"):
		var pw = player.get_weapon()
		if pw:
			setup(pw)


func _on_player_weapon_swapped(new_weapon: Node, _slot_index: int = 0) -> void:
	if new_weapon:
		setup(new_weapon)


func setup(target_weapon: Node) -> void:
	if weapon and weapon != target_weapon:
		_disconnect_weapon(weapon)

	weapon = target_weapon
	if weapon == null:
		return

	_connect_weapon(weapon)
	_sync_from_weapon()


func _connect_weapon(w: Node) -> void:
	if w.has_signal("ammo_changed") and not w.ammo_changed.is_connected(_on_ammo_changed):
		w.ammo_changed.connect(_on_ammo_changed)
	if w.has_signal("fire_mode_changed") and not w.fire_mode_changed.is_connected(_on_fire_mode_changed):
		w.fire_mode_changed.connect(_on_fire_mode_changed)
	if w.has_signal("hop_up_adjusted") and not w.hop_up_adjusted.is_connected(_on_hop_up_adjusted):
		w.hop_up_adjusted.connect(_on_hop_up_adjusted)
	if w.has_signal("magazine_equipped") and not w.magazine_equipped.is_connected(_on_magazine_equipped):
		w.magazine_equipped.connect(_on_magazine_equipped)
	if w.has_signal("incompatible_magazine") and not w.incompatible_magazine.is_connected(_on_incompatible_magazine):
		w.incompatible_magazine.connect(_on_incompatible_magazine)


func _disconnect_weapon(w: Node) -> void:
	if w.has_signal("ammo_changed") and w.ammo_changed.is_connected(_on_ammo_changed):
		w.ammo_changed.disconnect(_on_ammo_changed)
	if w.has_signal("fire_mode_changed") and w.fire_mode_changed.is_connected(_on_fire_mode_changed):
		w.fire_mode_changed.disconnect(_on_fire_mode_changed)
	if w.has_signal("hop_up_adjusted") and w.hop_up_adjusted.is_connected(_on_hop_up_adjusted):
		w.hop_up_adjusted.disconnect(_on_hop_up_adjusted)
	if w.has_signal("magazine_equipped") and w.magazine_equipped.is_connected(_on_magazine_equipped):
		w.magazine_equipped.disconnect(_on_magazine_equipped)
	if w.has_signal("incompatible_magazine") and w.incompatible_magazine.is_connected(_on_incompatible_magazine):
		w.incompatible_magazine.disconnect(_on_incompatible_magazine)


func _sync_from_weapon() -> void:
	if weapon == null:
		return
	if "current_ammo" in weapon:
		current_ammo = weapon.current_ammo
	if "magazine_capacity" in weapon:
		magazine_capacity = weapon.magazine_capacity
	if "bb_mass_grams" in weapon:
		bb_mass_grams = weapon.bb_mass_grams
	if "fire_mode" in weapon:
		if typeof(weapon.fire_mode) == TYPE_STRING:
			fire_mode = weapon.fire_mode
		elif weapon.fire_mode == 1:
			fire_mode = "AUTO"
		else:
			fire_mode = "SEMI"
	if "spin_rad_s" in weapon:
		hop_up = weapon.spin_rad_s
	_update_display()


func _process(_delta: float) -> void:
	if camera3:
		visible = get_viewport().get_camera_3d() == camera3


func _on_ammo_changed(current: int, max_capacity: int) -> void:
	current_ammo = current
	magazine_capacity = max_capacity
	if weapon and "bb_mass_grams" in weapon:
		bb_mass_grams = weapon.bb_mass_grams
	_update_display()


func _on_fire_mode_changed(new_mode: String) -> void:
	fire_mode = new_mode
	_update_display()


func _on_hop_up_adjusted(new_value: float) -> void:
	hop_up = new_value
	_update_display()


func _on_magazine_equipped(mag: Resource) -> void:
	if mag != null:
		if mag.has_method("get_bb_mass_grams"):
			bb_mass_grams = mag.get_bb_mass_grams()
		if "current_ammo" in mag:
			current_ammo = mag.current_ammo
		if "capacity" in mag:
			magazine_capacity = mag.capacity
	_update_display()


func _on_incompatible_magazine() -> void:
	_show_notification("CARREGADOR INCOMPATÍVEL")


func _show_notification(msg: String, duration: float = 1.5) -> void:
	_notification_text = msg
	_update_display()
	if not is_inside_tree():
		return
	if _notification_tween:
		_notification_tween.kill()
	_notification_tween = create_tween()
	_notification_tween.tween_interval(duration)
	_notification_tween.tween_callback(func():
		_notification_text = ""
		_update_display()
	)


func _update_display() -> void:
	text = _format_display_text()


func _format_display_text() -> String:
	var model_prefix := ""
	if weapon and weapon.has_method("get_weapon_model_name"):
		model_prefix = "[%s] " % weapon.get_weapon_model_name()
	var ammo_part := "%d / %d" % [current_ammo, magazine_capacity]
	var mass_part := " (%.2fg)" % bb_mass_grams if bb_mass_grams > 0.0 else ""
	var hop_part := "Hop-up: %d" % roundi(hop_up)
	var main_line := "%s%s | %s%s | %s" % [model_prefix, fire_mode, ammo_part, mass_part, hop_part]
	if _notification_text != "":
		return "%s\n%s" % [_notification_text, main_line]
	return main_line
