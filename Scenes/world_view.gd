extends Camera3D

@export var spawnItem : PackedScene

func _input(event):
	# Mouse in viewport coordinates.
	if event is InputEventMouseButton:
		var relative_position = event.position / get_viewport().get_visible_rect().size.y
		relative_position.x = (relative_position.x * 2) - 1
		relative_position.y = (relative_position.y * 2) - 1
		print("Mouse Click/Unclick at: ", relative_position)
		
		var relative_angle = relative_position * fov/2
		print("Mouse Click/Unclick at: ", relative_angle)

		if event.pressed:
			shoot(relative_angle)
	elif event is InputEventMouseMotion:
		print("Mouse Motion at: ", event.position)

	# Print the size of the viewport.
	print("Viewport Resolution is: ", get_viewport().get_visible_rect().size)

func shoot(relative_angle):
	var object = spawnItem.instantiate()
	add_child(object)
	var applied_force = transform.basis.z * -10 + transform.basis.y * 1
	
	applied_force = applied_force.rotated(Vector3.DOWN, deg_to_rad(relative_angle.x))
	applied_force = applied_force.rotated(Vector3.LEFT, deg_to_rad(relative_angle.y))
	object.apply_central_impulse(applied_force)
	pass
