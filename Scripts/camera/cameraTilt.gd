extends Camera3D

@export var max_angle := 2.0
@export var smooth_speed := 5.0

func _process(delta):
	var vp = get_viewport()
	var mouse_pos = vp.get_mouse_position()
	var rect = vp.get_visible_rect()
	
	# Check if mouse is inside THIS viewport
	if rect.has_point(mouse_pos):
		var offset = (mouse_pos / rect.size) - Vector2(0.5, 0.5)
		
		var target_rot_x = -offset.y * deg_to_rad(max_angle)
		var target_rot_y = -offset.x * deg_to_rad(max_angle)
		
		rotation.x = lerp(rotation.x, target_rot_x, delta * smooth_speed)
		rotation.y = lerp(rotation.y, target_rot_y, delta * smooth_speed)
	else:
		# Return smoothly to neutral when mouse leaves
		rotation.x = lerp(rotation.x, 0.0, delta * smooth_speed)
		rotation.y = lerp(rotation.y, 0.0, delta * smooth_speed)
