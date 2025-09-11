extends RigidBody3D

func _integrate_forces(state):
	var min_angle = deg_to_rad(-45)
	var max_angle = deg_to_rad(45)
	if rotation.y < min_angle:
		rotation.y = min_angle
		angular_velocity.y = 1
	elif rotation.y > max_angle:
		rotation.y = max_angle
		angular_velocity.y = -1
