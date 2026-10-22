extends Node3D

@export var bb_scene: PackedScene 
@export var weapon_prefab: PackedScene

var weapon_instance: Node3D
var mesh: Node3D
var ponta_do_cano: Node3D
@onready var camera3: Camera3D = get_node("../Camera3")

const ENERGIA_JOULES: float = 1.49
const METROS_PARA_PES: float = 3.28084

@export var spin_rad_s: float = 1200.0
var _local_offset: Transform3D

## Modos de tiro
enum FireMode { SEMI, AUTO }

@export var fire_mode: FireMode = FireMode.SEMI
@export var rpm: float = 700.0 ## Tiros por minuto no modo automático

var _trigger_held: bool = false
var _fire_cooldown: float = 0.0

## Lógica de Munição (Integração com o HUD)
@export var magazine_capacity: int = 30 ## Tamanho do pente
@export var reload_time: float = 2.0 ## Tempo em segundos para recarregar

var current_ammo: int = 30
var is_reloading: bool = false
var _reload_timer: float = 0.0


var _mesh_initial_position: Vector3
var _mesh_initial_rotation: Vector3

func _ready() -> void:
	_local_offset = camera3.global_transform.affine_inverse() * global_transform
	current_ammo = magazine_capacity
	
	if weapon_prefab:
		weapon_instance = weapon_prefab.instantiate()
		add_child(weapon_instance)
		
		# Procura o Mesh e PontaDoCano
		mesh = weapon_instance.find_child("Mesh", true, false)
		if not mesh:
			mesh = weapon_instance
			
		ponta_do_cano = weapon_instance.find_child("PontaDoCano", true, false)
		
		if mesh:
			_mesh_initial_position = mesh.position
			_mesh_initial_rotation = mesh.rotation_degrees


func _process(delta: float) -> void:
	global_transform = camera3.global_transform * _local_offset

	# Lida com o tempo de recarga
	if is_reloading:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finalizar_recarga()
		return # Impede que o jogador atire enquanto recarrega

	# Cooldown de tiro
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	# Lógica do modo automático
	if fire_mode == FireMode.AUTO and _trigger_held and _fire_cooldown <= 0.0:
		if current_ammo > 0:
			atirar()
			_fire_cooldown = 60.0 / rpm
		else:
			_iniciar_recarga()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_trigger_held = event.pressed
		
		# Lógica do modo semi-automático
		if event.pressed and fire_mode == FireMode.SEMI and not is_reloading:
			if current_ammo > 0:
				atirar()
			else:
				_iniciar_recarga()

	if event.is_action_pressed("toggle_fire_mode"):
		_alternar_modo_de_tiro()
		
	# Recarga manual através de um botão (ex: tecla 'R')
	if event.is_action_pressed("reload") and not is_reloading and current_ammo < magazine_capacity:
		_iniciar_recarga()


func _alternar_modo_de_tiro() -> void:
	fire_mode = FireMode.AUTO if fire_mode == FireMode.SEMI else FireMode.SEMI
	var nome_modo := "Automático" if fire_mode == FireMode.AUTO else "Semi-automático"
	print("Modo de tiro: ", nome_modo)


func _iniciar_recarga() -> void:
	is_reloading = true
	_reload_timer = reload_time
	print("Recarregando...")
	
	var tween = create_tween()
	var tempo_descida = reload_time * 0.3
	var tempo_subida = reload_time * 0.3
	var tempo_espera = reload_time * 0.4
	
	tween.tween_property(mesh, "position", _mesh_initial_position + Vector3(-0.1, -0.3, 0), tempo_descida).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(mesh, "rotation_degrees", _mesh_initial_rotation + Vector3(0, 0, 45), tempo_descida).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween.tween_interval(tempo_espera)
	
	tween.tween_property(mesh, "position", _mesh_initial_position, tempo_subida).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.parallel().tween_property(mesh, "rotation_degrees", _mesh_initial_rotation, tempo_subida).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _finalizar_recarga() -> void:
	is_reloading = false
	current_ammo = magazine_capacity
	print("Recarga concluída!")


func atirar() -> void:
	if bb_scene == null:
		push_error("Cena da BB não configurada!")
		return
		
	# Subtrai a munição
	current_ammo -= 1
		
	var bala = bb_scene.instantiate()
	get_tree().current_scene.add_child(bala)
	bala.global_transform = ponta_do_cano.global_transform
	bala.mass = 0.0002
	var massa_kg = bala.mass
	var velocidade_ms = sqrt((2.0 * ENERGIA_JOULES) / massa_kg)
	var velocidade_fps = velocidade_ms * METROS_PARA_PES
	
	print("", massa_kg, "kg | ", ENERGIA_JOULES, "J | ", round(velocidade_fps), " FPS | Restante: ", current_ammo)
	var direcao_tiro = -ponta_do_cano.global_transform.basis.x.normalized()
	bala.linear_velocity = direcao_tiro * velocidade_ms

	var eixo_spin = direcao_tiro.cross(Vector3.UP).normalized()
	bala.angular_velocity = eixo_spin * spin_rad_s
