extends CharacterBody3D

@export var speed := 4.0
@export var acceleration := 6.0
@export var deceleration := 8.0
@export var gravity := 20.0

@onready var visual := $Visual
@onready var camera := get_viewport().get_camera_3d()

func _physics_process(delta):

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# Input
	var input_dir = Vector3(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		0,
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()

	var target_velocity = input_dir * speed

	# Accelerate toward target
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	# Decelerate when no input
	if input_dir == Vector3.ZERO:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)

	move_and_slide()

	# Face camera (Paper Mario style)
	var cam_pos = camera.global_position
	var look_pos = Vector3(cam_pos.x, visual.global_position.y, cam_pos.z)
	visual.look_at(look_pos, Vector3.UP)

	# Flip sprite
	if input_dir.x != 0:
		visual.scale.x = sign(input_dir.x)
