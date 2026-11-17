class_name MouseCursor extends Node2D

## Shown instead of the cursor while an item is ready to shoot and the mouse is over the world view.
## Leave empty to draw a simple placeholder crosshair.
@export var crosshair_texture : Texture2D
@export var crosshair_scale := 1.0
@export var crosshair_color := Color(1, 1, 1, 0.9)

var rotation_target : float
var aiming := false
@onready var cursor_sprite : Node2D = get_node_or_null("Cursor")

func _ready() -> void:
	DialogueManager.dialogue_started.connect(on_dialogue_started)
	DialogueManager.dialogue_ended.connect(on_dialogue_closed)

func _process(delta: float) -> void:
	position = get_viewport().get_mouse_position()
	_update_aiming()

func _update_aiming() -> void:
	var world_view := GlobalManager.world_view
	var now_aiming := world_view != null and world_view.object_to_shoot != null and world_view.get_mouse_in_view() != null
	if now_aiming == aiming:
		return
	aiming = now_aiming
	if cursor_sprite:
		cursor_sprite.visible = not aiming
	queue_redraw()

func _draw() -> void:
	if not aiming:
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

func on_dialogue_closed(resource: Resource) -> void:
	visible = true
