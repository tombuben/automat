extends CharacterBody3D
@export var speed := 4.0
@export var acceleration := 8.0
@export var deceleration := 12.0
@export var gravity := 20.0
@export var auto_stop_distance := 0.1
@export var arrival_radius := 1.0 # distance from the walk target where speed starts easing down toward 0
@export var camera_controller := Node3D
@export var sprite: AnimatedSprite3D
@onready var visual := $Visual
@onready var camera := get_viewport().get_camera_3d()
@onready var click_to_move: ClickToMove = $ClickToMove # see click_to_move.gd
var auto_move_x: float = NAN
var is_auto_walking := false
var can_move := true
var facing := 1.0
var _sprite_base_scale := Vector3.ONE
func get_camera_controller():
	return camera_controller
func _ready():
	floor_snap_length = 1.0
	floor_max_angle = deg_to_rad(80)
	floor_stop_on_slope = false
	up_direction = Vector3.UP
	if sprite:
		_sprite_base_scale = sprite.scale.abs()
		sprite.animation_finished.connect(_on_sprite_animation_finished)
	if click_to_move:
		click_to_move.last_floor_y = global_position.y
		click_to_move.move_requested.connect(_on_move_requested)
# =====================================================
# POINT-AND-CLICK INPUT
# =====================================================
# Click detection, raycasting, the cursor, and the ground marker all live
# in ClickToMove (a child node — see click_to_move.gd). This script only
# reacts to the target it emits and owns the actual walking toward it.
func _on_move_requested(target_x: float, _hit_position: Vector3):
	auto_move_x = target_x
	is_auto_walking = true
# =====================================================
# SURFACE MODE
# =====================================================
enum SurfaceMode { FLOOR, WALL }
var surface_mode := SurfaceMode.FLOOR
# When on a wall, store its normal so we know which way is "into" it
var wall_normal := Vector3.ZERO
# How far ahead to raycast for wall detection
const WALL_RAY_LENGTH := 0.4
var _smoothed_normal := Vector3.UP
func _physics_process(delta):
	if click_to_move:
		click_to_move.enabled = can_move
	if not can_move:
		velocity = Vector3.ZERO
		is_auto_walking = false
		auto_move_x = NAN
		_update_animation()
		move_and_slide()
		return
	# =====================================================
	# INPUT
	# =====================================================
	# Keyboard movement removed in favor of point-and-click (see _unhandled_input).
	# Left the variable here since the rest of the function still reads input_x.
	var input_x := 0.0
	# Uncomment to restore keyboard movement alongside point-and-click:
	# input_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	# if abs(input_x) > 0.01:
	# 	is_auto_walking = false
	# 	auto_move_x = NAN
	# =====================================================
	# AUTO WALK (now also driven by mouse clicks)
	# =====================================================
	if is_auto_walking:
		var distance := auto_move_x - global_position.x
		var abs_distance: float = abs(distance)
		if abs_distance <= auto_stop_distance:
			is_auto_walking = false
			auto_move_x = NAN
			input_x = 0.0
			if click_to_move:
				click_to_move.clear_marker()
		else:
			# Ease speed down as we approach the target instead of walking
			# at full speed right up until the hard stop — smoothstep gives
			# an S-curve (starts and ends gently) rather than a linear ramp,
			# which reads more naturally for something as unhurried as a
			# snail. sign(distance) is preserved regardless of how small
			# ease_t gets, so facing/direction stay correct throughout.
			var ease_t: float = smoothstep(0.0, arrival_radius, abs_distance)
			input_x = sign(distance) * ease_t
	if input_x != 0:
		facing = sign(input_x)
	# =====================================================
	# SURFACE MODE SWITCH
	# =====================================================
	match surface_mode:
		SurfaceMode.FLOOR:
			_process_floor_mode(delta, input_x)
		SurfaceMode.WALL:
			_process_wall_mode(delta, input_x)
	velocity.z = 0.0
	move_and_slide()
	_update_animation()
	_update_visual_yaw()
	_apply_slope_rotation(delta)
# =====================================================
# FLOOR MODE
# =====================================================
func _process_floor_mode(delta: float, input_x: float):
	var floor_normal := Vector3.UP
	if is_on_floor():
		floor_normal = get_floor_normal()
		if click_to_move:
			click_to_move.last_floor_y = global_position.y
	# Smooth normal for sprite tilt
	if is_on_floor():
		_smoothed_normal = _smoothed_normal.lerp(floor_normal, 12.0 * delta).normalized()
	else:
		_smoothed_normal = _smoothed_normal.lerp(Vector3.UP, 8.0 * delta).normalized()
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0:
			velocity.y = 0
		apply_floor_snap()
	# Move along surface tangent
	var surface_right := Vector3.RIGHT
	if is_on_floor() and floor_normal != Vector3.UP:
		surface_right = floor_normal.cross(Vector3.BACK).normalized()
	var target_speed := input_x * speed
	var current_speed := velocity.dot(surface_right)
	if input_x != 0.0:
		var new_speed := move_toward(current_speed, target_speed, acceleration * delta)
		velocity = velocity - surface_right * current_speed + surface_right * new_speed
	else:
		var new_speed := move_toward(current_speed, 0.0, deceleration * delta)
		velocity = velocity - surface_right * current_speed + surface_right * new_speed
	# Slope press
	if is_on_floor() and floor_normal != Vector3.UP and velocity.dot(surface_right) != 0.0:
		var press := -floor_normal * 2.0
		if press.y < 0.0:
			velocity.y += press.y * delta
	# Check for wall transition — only when moving and on floor
	if is_on_floor() and abs(input_x) > 0.01:
		_check_wall_transition(input_x)
# =====================================================
# WALL MODE
# =====================================================
func _process_wall_mode(delta: float, input_x: float):
	# On a wall, the snail moves vertically.
	# input_x maps to up/down: moving toward the wall = up, away = would detach.
	# We use input_x sign relative to wall_normal to determine up/down.
	# Positive input_x on a left-facing wall (-X normal) = moving right = upward.
	var wall_side: int = int(-sign(wall_normal.x))
	var input_vertical: float = input_x * float(wall_side)
	# Gravity pulls INTO the wall, not down
	var into_wall := -wall_normal
	velocity += into_wall * gravity * delta
	# Cancel any velocity component away from the wall so snail sticks
	var away_from_wall := wall_normal
	var away_speed := velocity.dot(away_from_wall)
	if away_speed > 0.0:
		velocity -= away_from_wall * away_speed
	# Vertical movement along the wall
	var current_vert := velocity.y
	if input_vertical != 0.0:
		velocity.y = move_toward(current_vert, input_vertical * speed, acceleration * delta)
	else:
		velocity.y = move_toward(current_vert, 0.0, deceleration * delta)
	# Smooth normal toward wall normal for sprite tilt
	_smoothed_normal = _smoothed_normal.lerp(wall_normal, 12.0 * delta).normalized()
	# Check if snail has reached the top (ray no longer hits wall)
	if not _wall_ray_hits(facing):
		_transition_to_floor()
		return
	# Also detach if wall contact is lost (e.g. walked off bottom)
	if not is_on_wall():
		_transition_to_floor()
# =====================================================
# WALL DETECTION
# =====================================================
func _check_wall_transition(input_x: float):
	if _wall_ray_hits(input_x):
		var hit_normal := _get_wall_ray_normal(input_x)
		if hit_normal != Vector3.ZERO:
			wall_normal = hit_normal
			surface_mode = SurfaceMode.WALL
			# Kill horizontal velocity, start with slight upward nudge
			velocity.x = 0.0
			velocity.y = speed * 0.5
func _wall_ray_hits(direction: float) -> bool:
	return _get_wall_ray_normal(direction) != Vector3.ZERO
func _get_wall_ray_normal(direction: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ray_dir := Vector3(sign(direction), 0.0, 0.0) * WALL_RAY_LENGTH
	var from := global_position
	var to := global_position + ray_dir
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return Vector3.ZERO
	var hit_normal: Vector3 = result["normal"]
	# Only count near-vertical surfaces as walls (normal is mostly horizontal)
	if abs(hit_normal.y) < 0.3:
		return hit_normal
	return Vector3.ZERO
func _transition_to_floor():
	surface_mode = SurfaceMode.FLOOR
	wall_normal = Vector3.ZERO
	# Kill wall-press velocity, let gravity and floor snap take over
	velocity.x = facing * speed * 0.3
	velocity.y = 0.0
# =====================================================
# VISUAL YAW
# =====================================================
func _update_visual_yaw():
	if not visual or not camera:
		return
	var cam_pos := camera.global_position
	var to_cam: Vector3 = cam_pos - visual.global_position
	to_cam.y = 0.0
	if to_cam.length_squared() < 0.0001:
		return
	var target_basis := Basis.looking_at(to_cam.normalized(), Vector3.UP)
	visual.global_transform.basis = Basis(
		Vector3(target_basis.x.x, 0.0, target_basis.x.z).normalized(),
		Vector3.UP,
		Vector3(target_basis.z.x, 0.0, target_basis.z.z).normalized()
	)
# =====================================================
# SLOPE / WALL ROTATION
# =====================================================
func _apply_slope_rotation(delta: float):
	if not sprite:
		return
	# _smoothed_normal points away from whatever surface the snail is on.
	# atan2 of its components gives the correct tilt angle in all cases:
	# flat floor = 0, right-ascending slope = positive, wall = ~±90°
	var surface_angle := atan2(_smoothed_normal.x, _smoothed_normal.y)
	sprite.rotation.z = lerp(sprite.rotation.z, surface_angle, 10.0 * delta)
	var yaw_basis := Basis(
		Vector3(visual.global_transform.basis.x.x, 0.0, visual.global_transform.basis.x.z).normalized(),
		Vector3.UP,
		Vector3(visual.global_transform.basis.z.x, 0.0, visual.global_transform.basis.z.z).normalized()
	)
	var tilt_basis := Basis(Vector3(0.0, 0.0, 1.0), sprite.rotation.z)
	sprite.global_transform.basis = yaw_basis * tilt_basis
	sprite.scale = Vector3(_sprite_base_scale.x * facing, _sprite_base_scale.y, _sprite_base_scale.z)
# =====================================================
# ANIMATION
# =====================================================
const ANIM_MOVE_THRESHOLD := 0.05
var _was_moving := false
var _playing_stop := false
func _on_sprite_animation_finished():
	if sprite.animation == "stop":
		_playing_stop = false
		sprite.play("idle")
func _update_animation():
	if not sprite:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var moving := horizontal_speed > ANIM_MOVE_THRESHOLD
	if moving:
		_was_moving = true
		if _playing_stop:
			_playing_stop = false
		if sprite.animation != "run":
			sprite.play("run")
	else:
		if _was_moving:
			# Just came to a stop — play "stop" once, then
			# _on_sprite_animation_finished hands off to "idle".
			_was_moving = false
			_playing_stop = true
			sprite.play("stop")
		elif not _playing_stop and sprite.animation != "idle":
			sprite.play("idle")
