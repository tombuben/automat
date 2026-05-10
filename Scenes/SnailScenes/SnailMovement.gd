extends CharacterBody3D

@export var speed := 4.0
@export var acceleration := 6.0
@export var deceleration := 8.0
@export var gravity := 20.0

@export var auto_stop_distance := 0.1

@onready var visual := $Visual
@onready var camera := get_viewport().get_camera_3d()
@onready var camera_controller := $"../CameraController"

var auto_move_x: float = NAN
var is_auto_walking := false


func get_camera_controller():
	return camera_controller


func _physics_process(delta):

	# =====================================================
	# GRAVITY
	# =====================================================

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0

	# =====================================================
	# INPUT
	# =====================================================

	var input_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")

	# If player gives manual input → cancel auto walk
	if abs(input_x) > 0.01:
		is_auto_walking = false
		auto_move_x = NAN

	# =====================================================
	# AUTO WALK LOGIC
	# =====================================================

	if is_auto_walking:

		var distance = auto_move_x - global_position.x

		if abs(distance) <= auto_stop_distance:
			is_auto_walking = false
			auto_move_x = NAN
			input_x = 0
		else:
			input_x = sign(distance)

	# =====================================================
	# MOVE X ONLY
	# =====================================================

	var target_velocity_x = input_x * speed

	velocity.x = move_toward(
		velocity.x,
		target_velocity_x,
		acceleration * delta
	)

	if input_x == 0:
		velocity.x = move_toward(
			velocity.x,
			0,
			deceleration * delta
		)

	velocity.z = 0

	move_and_slide()

	# =====================================================
	# FACE CAMERA
	# =====================================================

	var cam_pos = camera.global_position
	var look_pos = Vector3(cam_pos.x, visual.global_position.y, cam_pos.z)
	visual.look_at(look_pos, Vector3.UP)

	if input_x != 0:
		visual.scale.x = sign(input_x)


# =========================================================
# CLICK TO WALK
# =========================================================

func _unhandled_input(event):

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:

			var cam = camera
			if cam == null:
				return

			var from = cam.project_ray_origin(event.position)
			var dir = cam.project_ray_normal(event.position)

			# Raycast into world
			var space = get_world_3d().direct_space_state

			var query = PhysicsRayQueryParameters3D.create(
				from,
				from + dir * 1000.0
			)

			var result = space.intersect_ray(query)

			var target_x: float

			if result:
				target_x = result.position.x
			else:
				# fallback: project far plane
				target_x = from.x + dir.x * 10.0

			auto_move_x = target_x
			is_auto_walking = true
