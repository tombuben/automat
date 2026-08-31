class_name ClickToMove
extends Node3D
# =====================================================
# CLICK-TO-MOVE
# =====================================================
# Turns a left click into a target X position and emits it. Knows nothing
# about walking, gravity, or surfaces — just screen click -> world point.
#
# A click raycasts from the camera through the clicked screen point into
# the actual level collision (ground, slopes, platforms). If the click
# lands on open sky (no collision hit — common in this 2.5D view, which
# has a lot of open space above the playable strip), it falls back to
# intersecting a horizontal plane anchored at `last_floor_y` — the last
# known floor height, which the owning body is expected to keep updated
# via the public var below. This keeps the fallback geometrically
# sensible near platforms/slopes without ever consulting the camera for
# distance (camera-derived distance caused an earlier zone-crossing
# deadlock, since the camera only advances once the body enters the next
# zone's trigger).
#
# Usage: add as a child of the moving body. Connect to `move_requested`.
# Each physics frame, set `enabled` to whether input should be accepted
# and, whenever the body is grounded, set `last_floor_y` to its Y.
signal move_requested(target_x: float, hit_position: Vector3)
@export var click_marker_scene: PackedScene # optional: assign a "walk here" marker scene in the inspector
@export var custom_cursor: Texture2D # optional: assign a small cursor image in the inspector
@export var custom_cursor_hotspot := Vector2.ZERO # pixel offset within the image that is the "tip"
@export var custom_cursor_size := 32 # cursor is resized to this many pixels (width & height) regardless of source image size
@export var ray_max_distance := 1000.0
var enabled := true
var last_floor_y := 0.0
var _click_marker: ClickMarker
var _exclude_body: Node3D
var _camera: Camera3D
func _ready():
	# Assumes this node is a direct child of the physics body it's moving
	# for; that body is excluded from the click raycast so clicks can't
	# hit the snail's own collider.
	_exclude_body = get_parent()
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
	if not enabled:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(event.position)
# Call this when the owning body considers the walk target reached, to
# hide the marker.
func clear_marker():
	if _click_marker:
		_click_marker.hide_marker()
func _handle_click(screen_pos: Vector2):
	if not _camera:
		_camera = get_viewport().get_camera_3d()
	if not _camera:
		return
	var hit_pos: Variant = _raycast_screen_to_world(screen_pos)
	if hit_pos == null:
		hit_pos = _screen_to_fallback_ground(screen_pos)
	if hit_pos == null:
		return # genuinely no valid direction (e.g. camera looking edge-on)
	var hit_pos_v: Vector3 = hit_pos
	if _click_marker:
		_click_marker.show_at(hit_pos_v)
	move_requested.emit(hit_pos_v.x, hit_pos_v)
func _raycast_screen_to_world(screen_pos: Vector2) -> Variant:
	var space := get_world_3d().direct_space_state
	var ray_origin := _camera.project_ray_origin(screen_pos)
	var ray_dir := _camera.project_ray_normal(screen_pos)
	var ray_end := ray_origin + ray_dir * ray_max_distance
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	if _exclude_body:
		query.exclude = [_exclude_body]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return null
	return result["position"] as Vector3
# Used only when the click hits no collision at all (open sky). Intersects
# the click ray with a horizontal plane at the last known floor height, so
# the indicator and walk target land somewhere reasonable rather than
# failing silently — without involving the camera's distance or FOV.
func _screen_to_fallback_ground(screen_pos: Vector2) -> Variant:
	var ray_origin := _camera.project_ray_origin(screen_pos)
	var ray_dir := _camera.project_ray_normal(screen_pos)
	var plane := Plane(Vector3.UP, last_floor_y)
	return plane.intersects_ray(ray_origin, ray_dir)
