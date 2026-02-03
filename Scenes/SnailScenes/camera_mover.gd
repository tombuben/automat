extends Node3D

@export var target: CharacterBody3D
@export var follow_time := 0.25
@export var look_ahead_distance := 1.5
@export var look_ahead_time := 0.2
@export var deadzone := 0.2

var follow_velocity := 0.0
var look_ahead := 0.0
var look_ahead_velocity := 0.0
var camera_target_x := 0.0  # the “deadzone-tracked” X

func _ready():
	if target:
		camera_target_x = target.global_position.x

func _process(delta):
	if target == null:
		return

	# --- Update camera target based on deadzone ---
	var delta_x = target.global_position.x - camera_target_x
	if abs(delta_x) > deadzone:
		# Move target only beyond deadzone
		camera_target_x += delta_x - sign(delta_x) * deadzone

	# --- Look-ahead ---
	var direction := 0
	if target.velocity.x > 0.01:
		direction = 1
	elif target.velocity.x < -0.01:
		direction = -1

	var desired_look := direction * look_ahead_distance
	var look_result = smooth_damp(
		look_ahead,
		desired_look,
		look_ahead_velocity,
		look_ahead_time,
		delta
	)
	look_ahead = look_result[0]
	look_ahead_velocity = look_result[1]

	# --- Smooth follow ---
	var follow_result = smooth_damp(
		global_position.x,
		camera_target_x + look_ahead,
		follow_velocity,
		follow_time,
		delta
	)
	global_position.x = follow_result[0]
	follow_velocity = follow_result[1]

# --- SmoothDamp Function ---
func smooth_damp(current, goal, velocity, smooth_time, delta):
	var omega = 2.0 / smooth_time
	var x = omega * delta
	var exp_factor = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)

	var change = current - goal
	var temp = (velocity + omega * change) * delta
	velocity = (velocity - omega * temp) * exp_factor
	var output = goal + (change + temp) * exp_factor

	return [output, velocity]
