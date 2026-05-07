extends Node3D

@export var target: CharacterBody3D
@export var camera_rig: Node3D
@export var camera: Camera3D

@export var follow_time := 0.25
@export var look_ahead_distance := 1.5
@export var look_ahead_time := 0.2
@export var deadzone := 0.2

@export var zone_blend_time := 0.4
var rig_tween: Tween
var fov_tween: Tween

var active_zones: Array = []

var current_transition_time := 1.0
var current_transition_type := Tween.TRANS_SINE
var current_ease_type := Tween.EASE_IN_OUT


var follow_velocity := 0.0
var look_ahead := 0.0
var look_ahead_velocity := 0.0
var camera_target_x := 0.0

# --- Zoom / Rig movement ---
var default_rig_z := 0.0
var target_rig_z := 0.0
var rig_z_velocity := 0.0

# --- FOV ---
var default_fov := 75.0
var target_fov := 75.0
var fov_velocity := 0.0

func _ready():
	if target:
		camera_target_x = target.global_position.x

	if camera:
		default_fov = camera.fov
		target_fov = default_fov

	if camera_rig:
		default_rig_z = camera_rig.position.z
		target_rig_z = default_rig_z


func _process(delta):
	if target == null:
		return

	# --- Deadzone ---
	var delta_x = target.global_position.x - camera_target_x

	if abs(delta_x) > deadzone:
		camera_target_x += delta_x - sign(delta_x) * deadzone

	# --- Look ahead ---
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

	# --- Horizontal follow ---
	var follow_result = smooth_damp(
		global_position.x,
		camera_target_x + look_ahead,
		follow_velocity,
		follow_time,
		delta
	)

	global_position.x = follow_result[0]
	follow_velocity = follow_result[1]


# --- Zone API ---
func push_camera_zone(zone):
	if active_zones.has(zone):
		return

	active_zones.append(zone)

	update_camera_zone()


func remove_camera_zone(zone):
	active_zones.erase(zone)

	update_camera_zone()


func update_camera_zone():
	if active_zones.is_empty():
		return_to_default()
		return

	# Highest priority wins
	active_zones.sort_custom(func(a, b):
		return a.zone_priority > b.zone_priority
	)

	var zone = active_zones[0]

	apply_camera_zone(zone)


func apply_camera_zone(zone):
	target_rig_z = zone.camera_target.global_position.z
	target_fov = zone.camera_fov

	current_transition_time = zone.transition_time
	current_transition_type = zone.transition_type
	current_ease_type = zone.ease_type

	if rig_tween:
		rig_tween.kill()

	if fov_tween:
		fov_tween.kill()

	# --- Rig Tween ---
	rig_tween = create_tween()

	rig_tween.tween_property(
		camera_rig,
		"position:z",
		target_rig_z,
		current_transition_time
	).set_trans(current_transition_type).set_ease(current_ease_type)

	# --- FOV Tween ---
	fov_tween = create_tween()

	fov_tween.tween_property(
		camera,
		"fov",
		target_fov,
		current_transition_time
	).set_trans(current_transition_type).set_ease(current_ease_type)


func return_to_default():
	if rig_tween:
		rig_tween.kill()

	if fov_tween:
		fov_tween.kill()

	rig_tween = create_tween()

	rig_tween.tween_property(
		camera_rig,
		"position:z",
		default_rig_z,
		current_transition_time
	).set_trans(current_transition_type).set_ease(current_ease_type)

	fov_tween = create_tween()

	fov_tween.tween_property(
		camera,
		"fov",
		default_fov,
		current_transition_time
	).set_trans(current_transition_type).set_ease(current_ease_type)


# --- Smooth Damp ---
func smooth_damp(current, goal, velocity, smooth_time, delta):
	var omega = 2.0 / smooth_time
	var x = omega * delta
	var exp_factor = 1.0 / (1.0 + x + 0.48 * x * x + 0.235 * x * x * x)

	var change = current - goal
	var temp = (velocity + omega * change) * delta
	velocity = (velocity - omega * temp) * exp_factor
	var output = goal + (change + temp) * exp_factor

	return [output, velocity]
