extends Node3D

@export var target_transform: Transform3D
@export var target_fov := 60.0
@export var blend_time := 0.5
@export var camera_node: Camera3D

func _on_body_entered(body):
	if body.name != "Player":
		return
	camera_node.set_zone_override(self, true)

func _on_body_exited(body):
	if body.name != "Player":
		return
	camera_node.set_zone_override(self, false)
