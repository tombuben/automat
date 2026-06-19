extends CharacterBody3D

@export var speed := 4.0
@export var acceleration := 8.0
@export var deceleration := 12.0
@export var gravity := 20.0
@export var auto_stop_distance := 0.1
@export var camera_controller := Node3D
@export var sprite: Sprite3D

@onready var visual := $Visual
@onready var camera := get_viewport().get_camera_3d()

var auto_move_x: float = NAN
var is_auto_walking := false
var can_move := true
var facing := 1.0

func get_camera_controller():
	return camera_controller

# =====================================================
# POINT-AND-CLICK INPUT
# =====================================================
# A click raycasts from the camera through the clicked screen point into
# the actual level collision (ground, slopes, platforms). The hit point's
# X becomes the walk target, and the click marker is placed at the exact
# hit point — so the indicator always sits correctly on the ground, on
# slopes, on platforms, whatever is physically there. Walk distance is
# never capped, so it always matches exactly how far you clicked,
# regardless of camera zoom.
#
# If the click lands on open sky (no collision hit — common in this
# 2.5D view, which has a lot of open space above the playable strip), we
# fall back to intersecting a horizontal plane anchored at the LAST KNOWN
# FLOOR HEIGHT the snail was standing on (_last_floor_y, updated every
# frame the snail is grounded) — not the camera's depth/FOV, and not a
# single fixed level-wide height. This keeps the fallback geometrically
# sensible near platforms/slopes without ever consulting the camera for
# distance, which is what caused the earlier zone-crossing deadlock (the
# camera only advances once the player's body enters the next zone's
# Area3D trigger, so any walk-distance math derived from the camera's
# current view could never reach far enough to trigger that).
@export var click_marker_scene: PackedScene # optional: assign a "walk here" marker scene in the inspector
var _click_marker: Node3D
var _last_floor_y: float = 0.0

@export var custom_cursor: Texture2D # optional: assign a small cursor image in the inspector
@export var custom_cursor_hotspot := Vector2.ZERO # pixel offset within the image that is the "tip"
@export var custom_cursor_size := 32 # cursor is resized to this many pixels (width & height) regardless of source image size

func _ready():
	floor_snap_length = 1.0
	floor_max_angle = deg_to_rad(80)
	floor_stop_on_slope = false
	up_direction = Vector3.UP

	_last_floor_y = global_position.y

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if custom_cursor:
		var resized := _get_resized_cursor_texture(custom_cursor, custom_cursor_size)
		Input.set_custom_mouse_cursor(resized, Input.CURSOR_ARROW, custom_cursor_hotspot)

	if click_marker_scene:
		_click_marker = click_marker_scene.instantiate()
		_click_marker.visible = false
		get_tree().current_scene.add_child.call_deferred(_click_marker)

# Godot's custom cursor renders at the texture's native pixel size with no
# auto-scaling, so a large source image (e.g. 128px+) shows up as a huge
# cursor on screen even if the drawn icon itself is small. This downsamples
# the image to a sane fixed size first so any source image works correctly.
func _get_resized_cursor_texture(tex: Texture2D, target_size: int) -> ImageTexture:
	var img := tex.get_image()
	img.resize(target_size, target_size, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)

func _unhandled_input(event):
	if not can_move:
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)

func _handle_click(screen_pos: Vector2):
	if not camera:
		camera = get_viewport().get_camera_3d()
	if not camera:
		return

	var hit_pos: Variant = _raycast_screen_to_world(screen_pos)

	# Sky/void click — fall back to a plane at the last known floor height
	# rather than failing outright. This still uses no camera distance/FOV
	# math, just "where did the snail last stand."
	if hit_pos == null:
		hit_pos = _screen_to_fallback_ground(screen_pos)

	if hit_pos == null:
		return # genuinely no valid direction (e.g. camera looking edge-on)

	var hit_pos_v: Vector3 = hit_pos

	auto_move_x = hit_pos_v.x
	is_auto_walking = true

	if _click_marker:
		_click_marker.global_position = hit_pos_v
		_click_marker.visible = true

const RAY_MAX_DISTANCE := 1000.0

func _raycast_screen_to_world(screen_pos: Vector2) -> Variant:
	var space := get_world_3d().direct_space_state
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)
	var ray_end := ray_origin + ray_dir * RAY_MAX_DISTANCE

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [self] # don't let the click ray hit the snail's own body
	var result := space.intersect_ray(query)

	if result.is_empty():
		return null

	return result["position"] as Vector3

# Used only when the click hits no collision at all (open sky). Intersects
# the click ray with a horizontal plane at the snail's last known floor
# height, so the indicator and walk target land somewhere reasonable
# rather than failing silently — without involving the camera's distance
# or FOV in any way.
func _screen_to_fallback_ground(screen_pos: Vector2) -> Variant:
	var ray_origin := camera.project_ray_origin(screen_pos)
	var ray_dir := camera.project_ray_normal(screen_pos)

	var plane := Plane(Vector3.UP, _last_floor_y)
	return plane.intersects_ray(ray_origin, ray_dir)

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
	if not can_move:
		velocity = Vector3.ZERO
		is_auto_walking = false
		auto_move_x = NAN
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
		if abs(distance) <= auto_stop_distance:
			is_auto_walking = false
			auto_move_x = NAN
			input_x = 0.0
			if _click_marker:
				_click_marker.visible = false
		else:
			input_x = sign(distance)

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

	_update_visual_yaw()
	_apply_slope_rotation(delta)


# =====================================================
# FLOOR MODE
# =====================================================
func _process_floor_mode(delta: float, input_x: float):
	var floor_normal := Vector3.UP
	if is_on_floor():
		floor_normal = get_floor_normal()
		_last_floor_y = global_position.y

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

	sprite.scale.x = abs(sprite.scale.x) * facing
