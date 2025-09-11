extends Node3D

@export var mouse_height_to_pos_curve : Curve

@onready var cursor_object : CursorBody = $"../CursorObject"
@onready var original_pos = global_position
@onready var target_pos = original_pos

func _process(delta: float) -> void:
	var mouse_pos = get_viewport().get_mouse_position()
	var viewport_rect = get_viewport().get_visible_rect()
	if not viewport_rect.has_point(mouse_pos):
		mouse_pos = get_viewport().get_visible_rect().size / 2
	
	handle_camera_rotation(delta, mouse_pos)
	handle_camera_position(delta, mouse_pos)

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

func handle_camera_position(delta: float, mouse_pos : Vector2) -> void:
	if not cursor_object.last_dragged_object:
		return
	
	var relative_position : float
	if cursor_object.last_dragged_object.freeze: #Todo here check if the object is in item slot
		pass
		#relative_position = -1
	else:
		#var last_object_height = cursor_object.last_dragged_object.global_position.y
		#relative_position = remap(last_object_height, 0.5, 2, 1, -1)
		pass
	
	#todo remove this
	var last_object_height = cursor_object.last_dragged_object.global_position.y
	relative_position = remap(last_object_height, 0.5, 2, 1, -1)
	#todo end
	
	var height_pos = mouse_height_to_pos_curve.sample(relative_position)	
	target_pos.y = original_pos.y - height_pos * 0.6
	
	var speed_factor = 2.0
	var direction = target_pos - global_position
	var step = direction * speed_factor * delta
	global_position += step
