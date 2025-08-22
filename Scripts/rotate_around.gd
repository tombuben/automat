extends Node3D

func _process(delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_rect = get_viewport().get_visible_rect()
	if not viewport_rect.has_point(mouse_pos):
		mouse_pos = get_viewport().get_visible_rect().size / 2
	
	handle_camera_rotation(delta, mouse_pos)

func handle_camera_rotation(delta: float, mouse_pos : Vector2) -> void:
	var relative_position = mouse_pos / get_viewport().get_visible_rect().size.y
	relative_position.x = (relative_position.x * 2) - 1
	relative_position.y = (relative_position.y * 2) - 1
	var relative_angle = relative_position * 0.2
	
	var current_camera_quat = basis.get_rotation_quaternion()
	var target_camera_quat = quaternion.from_euler(Vector3(relative_angle.y, relative_angle.x, 0))
	var camera_rotation_speed = 2.0
	var new_camera_quat = current_camera_quat.slerp(target_camera_quat, delta * camera_rotation_speed)
	basis = Basis(new_camera_quat)
