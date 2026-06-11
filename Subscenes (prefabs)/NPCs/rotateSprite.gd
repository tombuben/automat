extends Sprite3D

@export var rotation_speed := -40.0 # degrees per second

func _process(delta):
	rotate_z(deg_to_rad(rotation_speed * delta))
