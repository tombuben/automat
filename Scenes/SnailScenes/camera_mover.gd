extends Node3D
@export var target: CharacterBody3D
@export var camera_rig: Node3D
@export var camera: Camera3D
@export var fade_manager: CanvasLayer
@export var follow_time := 0.25
@export var look_ahead_distance := 1.5
@export var look_ahead_time := 0.2
@export var deadzone := 0.2
@export var framing_follow_speed := 4.0
@export var x_follow_speed := 5.0
# =====================================================
# STATE
# =====================================================
var rig_tween: Tween
var fov_tween: Tween
# =====================================================
# ZONE SYSTEM
# =====================================================
# active_zones is every zone the player's body currently overlaps, most
# recently entered last. current_zone is always active_zones sorted by
# zone_priority descending, or null if the player isn't in any zone.
#
# There used to be an `is_camera_transitioning` guard here meant to stop
# transitions from overlapping. It never actually did that (GDScript is
# single-threaded and the tweens run async in the background, so the flag
# was set true then false within the same frame — nothing could ever
# interleave). Its only real effect was a failure mode: if apply_camera_zone
# ever threw (e.g. a zone's camera_target wasn't assigned), the function
# aborted before resetting the flag, and it stayed stuck true forever —
# silently no-op'ing every future zone enter/exit. That's the "locked out"
# bug. Re-triggering a tween mid-transition is already handled safely by
# the .kill() calls in apply_camera_zone/return_to_default, so no guard
# is needed at all.
var active_zones: Array = []
var current_zone = null
# =====================================================
# TRANSITION SETTINGS
# =====================================================
var current_transition_time := 1.0
var current_transition_type := Tween.TRANS_SINE
var current_ease_type := Tween.EASE_IN_OUT
# =====================================================
# FOLLOW VARIABLES
# =====================================================
var follow_velocity := 0.0
var look_ahead := 0.0
var look_ahead_velocity := 0.0
var camera_target_x := 0.0
# =====================================================
# CAMERA RIG / FOV
# =====================================================
var default_rig_z := 0.0
var target_rig_z := 0.0
var default_fov := 75.0
var target_fov := 75.0
# =====================================================
# READY
# =====================================================
func _ready():
	if target:
		camera_target_x = target.global_position.x
	if camera:
		default_fov = camera.fov
		target_fov = default_fov
	if camera_rig:
		default_rig_z = camera_rig.position.z
		target_rig_z = default_rig_z
# =====================================================
# PROCESS
# =====================================================
func _process(delta):
	if target == null:
		return
	# =====================================================
	# CINEMATIC MODE
	# =====================================================
	if current_zone and current_zone.lock_camera_position and current_zone.camera_target:
		var framed_x = current_zone.camera_target.global_position.x
		var framed_y = current_zone.camera_target.global_position.y
		var x_speed: float = current_zone.camera_x_speed
		global_position.x = lerp(global_position.x, framed_x, delta * x_speed)
		global_position.y = lerp(global_position.y, framed_y, delta * framing_follow_speed)
	# =====================================================
	# NORMAL MODE
	# =====================================================
	else:
		var delta_x = target.global_position.x - camera_target_x
		if abs(delta_x) > deadzone:
			camera_target_x += delta_x - sign(delta_x) * deadzone
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
		global_position.x = lerp(global_position.x, camera_target_x + look_ahead, delta * x_follow_speed)
		global_position.y = lerp(global_position.y, target.global_position.y, delta * 2.0)
# =====================================================
# SNAP
# =====================================================
func snap_to_player():
	if target == null:
		return
	global_position.x = target.global_position.x
	global_position.y = target.global_position.y
	camera_target_x = target.global_position.x
	follow_velocity = 0.0
	look_ahead = 0.0
	look_ahead_velocity = 0.0
	if camera_rig:
		camera_rig.position.z = target_rig_z
	if rig_tween:
		rig_tween.kill()
	if fov_tween:
		fov_tween.kill()
# =====================================================
# ZONE API
# =====================================================
# Called by a CameraZone (Area3D) when the player's body enters/exits it.
func push_camera_zone(zone):
	# Move `zone` to the top of the stack rather than just appending if
	# new. This is what makes overlapping zones work correctly: walking
	# backward into a previous zone while still standing inside the next
	# one re-enters it, bumps it back to the top, and switches the camera
	# immediately — instead of it staying stuck on whichever zone happened
	# to be entered first.
	active_zones.erase(zone)
	active_zones.append(zone)
	update_camera_zone()
func remove_camera_zone(zone):
	active_zones.erase(zone)
	update_camera_zone()
func update_camera_zone():
	if active_zones.is_empty():
		current_zone = null
		return_to_default()
		return
	# The most recently entered zone still overlapping the player wins —
	# not a static priority. A priority sort here is what caused the
	# lockout: with equal priorities the array order (i.e. entry order)
	# decided the winner, so re-entering an earlier zone while an overlap
	# with the newer one was still active did nothing.
	var new_zone = active_zones.back()
	if new_zone == current_zone:
		return
	apply_camera_zone(new_zone)
# =====================================================
# TRANSITION
# =====================================================
func apply_camera_zone(zone):
	if zone.lock_camera_position and zone.camera_target == null:
		push_warning("CameraZone '%s' has lock_camera_position on but no camera_target assigned — skipping." % zone.name)
		return
	current_zone = zone
	target_rig_z = zone.camera_target.global_position.z if zone.camera_target else default_rig_z
	target_fov = zone.camera_fov
	current_transition_time = zone.transition_time
	current_transition_type = zone.transition_type
	current_ease_type = zone.ease_type
	_tween_rig_and_fov(target_rig_z, target_fov)
func return_to_default():
	_tween_rig_and_fov(default_rig_z, default_fov)
func _tween_rig_and_fov(rig_z: float, fov: float):
	if rig_tween:
		rig_tween.kill()
	if fov_tween:
		fov_tween.kill()
	if camera_rig:
		rig_tween = create_tween()
		rig_tween.tween_property(
			camera_rig,
			"position:z",
			rig_z,
			current_transition_time
		).set_trans(current_transition_type).set_ease(current_ease_type)
	if camera:
		fov_tween = create_tween()
		fov_tween.tween_property(
			camera,
			"fov",
			fov,
			current_transition_time
		).set_trans(current_transition_type).set_ease(current_ease_type)
# =====================================================
# SMOOTH DAMP
# =====================================================
func smooth_damp(current, goal, velocity, smooth_time, delta):
	var omega = 2.0 / smooth_time
	var x = omega * delta
	var exp_factor = 1.0 / (
		1.0 + x + 0.48 * x * x + 0.235 * x * x * x
	)
	var change = current - goal
	var temp = (velocity + omega * change) * delta
	velocity = (velocity - omega * temp) * exp_factor
	var output = goal + (change + temp) * exp_factor
	return [output, velocity]
