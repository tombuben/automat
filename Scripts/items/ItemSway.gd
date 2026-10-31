extends Node3D

@export var sway_amount := 0.028    # radians
@export var sway_speed := 1

@export var hover_amount := 0.01     # meters
@export var hover_speed := 1.73



var base_position : Vector3
var base_rotation : Vector3

func _ready():
	base_position = position
	base_rotation = rotation

func _process(_delta):
	var t = Time.get_ticks_msec() * 0.001

	# subtle leaning motion
	rotation.z = base_rotation.z + (
		(sin(t * sway_speed)
		+ sin(t * sway_speed * 0.53 * 1.7))
		* sway_amount
	)

	# hover motion
	position.y = base_position.y + (
		sin(t * hover_speed * 0.7)
		* hover_amount
	)
