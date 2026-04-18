class_name MouseCursor extends Node2D

var rotation_target : float

func _process(delta: float) -> void:
	position = get_viewport().get_mouse_position()
	return
