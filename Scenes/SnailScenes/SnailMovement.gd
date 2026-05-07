extends CharacterBody3D

@export var speed := 4.0
@export var acceleration := 6.0
@export var deceleration := 8.0
@export var gravity := 20.0

@onready var visual := $Visual
@onready var camera := get_viewport().get_camera_3d()

@onready var camera_controller := $"../CameraController"

func get_camera_controller():
	return camera_controller
func _physics_process(delta):

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# Horizontal input (LEFT / RIGHT only)
	var input_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	# Target velocity (Z is always 0)
	var target_velocity_x = input_x * speed

	# Accelerate toward target
	velocity.x = move_toward(velocity.x, target_velocity_x, acceleration * delta)

	# Decelerate when no input
	if input_x == 0:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)

	# Lock Z axis completely
	velocity.z = 0

	move_and_slide()

	# Face camera (Paper Mario style)
	var cam_pos = camera.global_position
	var look_pos = Vector3(cam_pos.x, visual.global_position.y, cam_pos.z)
	visual.look_at(look_pos, Vector3.UP)

	# Flip sprite based on movement direction
	if input_x != 0:
		visual.scale.x = sign(input_x)
