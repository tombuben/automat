extends Node3D

@export var target: CharacterBody3D
@export var follow_time := 0.25
@export var look_ahead_distance := 1.5
@export var look_ahead_time := 0.2

var follow_velocity := 0.0
var look_ahead := 0.0
var look_ahead_velocity := 0.0


func _process(delta):
	if target == null:
		return

	# --- LOOK AHEAD ---
	var desired_look := 0.0
	if abs(target.velocity.x) > 0.1:
		desired_look = sign(target.velocity.x) * look_ahead_distance

	var look_result = smooth_damp(
		look_ahead,
		desired_look,
		look_ahead_velocity,
		look_ahead_time,
		delta
	)
	look_ahead = look_result[0]
	look_ahead_velocity = look_result[1]

	# --- FOLLOW PLAYER ---
	var target_x = target.global_position.x + look_ahead
	var follow_result = smooth_damp(
		global_position.x,
		target_x,
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
