class_name MouseCursor extends Node2D

enum State { DEFAULT, CLICKABLE, AIMING }

@export var default_texture : Texture2D = preload("res://Assets/cursor/cursor1.png")
## Used while hovering something that can be clicked (an item, a button) or dragging an item.
@export var clickable_texture : Texture2D = preload("res://Assets/cursor/cursor2.png")

@export_group("Aiming")
## Shown instead of the cursor while an item is ready to shoot and the mouse is over the world view.
## Leave empty to draw a simple placeholder crosshair.
@export var crosshair_texture : Texture2D = preload("res://Assets/cursor/crosshair.png")
@export var crosshair_scale := 0.4
@export var crosshair_color := Color(1, 1, 1, 0.9)

@export_group("Move particles")
## Spawned as a child if the cursor has no "MoveParticles" child of its own.
@export var move_particles_scene : PackedScene = preload("res://Prefabs/cursor_move_particles.tscn")
## Particles only emit while the mouse moves faster than this (pixels per second).
@export var particles_min_speed := 50.0

var state : State = State.DEFAULT

@onready var cursor_sprite : Sprite2D = get_node_or_null("Cursor")
@onready var move_particles : CPUParticles2D = get_node_or_null("MoveParticles")

var _last_position : Vector2

func _ready() -> void:
	_hide_system_cursor()
	if move_particles == null and move_particles_scene:
		move_particles = move_particles_scene.instantiate() as CPUParticles2D
		add_child(move_particles)
	DialogueManager.dialogue_started.connect(on_dialogue_started)
	DialogueManager.dialogue_ended.connect(on_dialogue_closed)
	position = get_viewport().get_mouse_position()
	_last_position = position
	_apply_state()

## Custom OS cursors set with Input.set_custom_mouse_cursor survive scene changes, so the snail
## scenes' cursor3/cursor4 would still show here under this drawn cursor. Put back the project's
## transparent cursor image (display/mouse_cursor/custom_image) for the shapes those scenes change.
func _hide_system_cursor() -> void:
	var hidden_image : Resource = null
	var image_path : String = ProjectSettings.get_setting("display/mouse_cursor/custom_image", "")
	if image_path != "":
		hidden_image = load(image_path)
	for shape in [Input.CURSOR_ARROW, Input.CURSOR_POINTING_HAND]:
		Input.set_custom_mouse_cursor(hidden_image, shape)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func _process(delta: float) -> void:
	position = get_viewport().get_mouse_position()
	_update_particles(delta)
	_last_position = position

	var new_state := _get_state()
	if new_state != state:
		state = new_state
		_apply_state()

func _get_state() -> State:
	var world_view := GlobalManager.world_view
	if world_view != null and world_view.object_to_shoot != null and world_view.get_mouse_in_view() != null:
		return State.AIMING
	if _is_hovering_clickable():
		return State.CLICKABLE
	return State.DEFAULT

func _is_hovering_clickable() -> bool:
	var cursor_body := GlobalManager.cursor_body
	if cursor_body != null and not cursor_body.in_dialogue:
		if cursor_body.dragging or cursor_body.moused_over_item != null:
			return true
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered is BaseButton and not hovered.disabled:
		return true
	return false

func _apply_state() -> void:
	if cursor_sprite:
		cursor_sprite.visible = state != State.AIMING
		match state:
			State.DEFAULT:
				if default_texture:
					cursor_sprite.texture = default_texture
			State.CLICKABLE:
				if clickable_texture:
					cursor_sprite.texture = clickable_texture
	queue_redraw()

func _update_particles(delta: float) -> void:
	if move_particles == null or delta <= 0.0:
		return
	var speed := position.distance_to(_last_position) / delta
	move_particles.emitting = visible and speed > particles_min_speed

func _draw() -> void:
	if state != State.AIMING:
		return
	if crosshair_texture:
		var size := crosshair_texture.get_size() * crosshair_scale
		draw_texture_rect(crosshair_texture, Rect2(-size / 2.0, size), false)
		return
	# Placeholder: four short lines around a gap, and a dot in the middle.
	var gap := 10.0 * crosshair_scale
	var length := 18.0 * crosshair_scale
	var width := 5.0 * crosshair_scale
	for direction in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(direction * gap, direction * (gap + length), crosshair_color, width)
	draw_circle(Vector2.ZERO, width * 0.6, crosshair_color)

func on_dialogue_started(resource: Resource) -> void:
	visible = false
	if move_particles:
		move_particles.emitting = false

func on_dialogue_closed(resource: Resource) -> void:
	visible = true
