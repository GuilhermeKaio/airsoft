extends RigidBody3D

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var velocity := state.linear_velocity
	velocity.x = 1.0
	state.linear_velocity = velocity
