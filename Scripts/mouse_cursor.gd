class_name MouseCursor extends Node2D

var rotation_target : float

func _process(delta: float) -> void:
	position = get_viewport().get_mouse_position()
	rotation_target = Input.get_last_mouse_velocity().x * 0.0001
	rotation = move_toward(rotation, rotation_target, delta * 2)
