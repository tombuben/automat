extends Node3D

@export var swing_angle := 8.0
@export var swing_speed := 1.0

var t := randf() * TAU

func _ready():
	swing_speed *= randf_range(0.85, 1.15)

func _process(delta):
	t += delta
	rotation_degrees.z = sin(t * swing_speed) * swing_angle
