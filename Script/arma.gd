extends Node3D

@export var bb_scene: PackedScene 
@onready var ponta_do_cano = $Cano/PontaDoCano

const ENERGIA_JOULES: float = 1.49
const METROS_PARA_PES: float = 3.28084

@export var spin_rad_s: float = 1200.0

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		atirar()

func atirar() -> void:
	if bb_scene == null:
		push_error("Cena da BB não configurada!")
		return
		
	var bala = bb_scene.instantiate()
	get_tree().current_scene.add_child(bala)
	bala.global_transform = ponta_do_cano.global_transform
	bala.mass = 0.0002
	var massa_kg = bala.mass
	var velocidade_ms = sqrt((2.0 * ENERGIA_JOULES) / massa_kg)
	var velocidade_fps = velocidade_ms * METROS_PARA_PES
	
	print("", massa_kg, "kg | ", ENERGIA_JOULES, "J | ", round(velocidade_fps), " FPS")
	var direcao_tiro = -ponta_do_cano.global_transform.basis.x.normalized()
	bala.linear_velocity = direcao_tiro * velocidade_ms

	var eixo_spin = direcao_tiro.cross(Vector3.UP).normalized()
	bala.angular_velocity = eixo_spin * spin_rad_s
