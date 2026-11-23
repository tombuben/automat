class_name HoverFrame extends Control
## Four corners around the item under the mouse in the automat view.
## Appears on hover, disappears when the item is grabbed or the mouse leaves it.

## How much bigger than the item the square is (1 = tight).
@export var padding := 1.15
## Size of each corner sprite, in automat view pixels.
@export var corner_size := 22.0
@export var fade_in_time := 0.08
@export var fade_out_time := 0.1
## How much bigger the frame starts when it appears (1 = no pop).
@export var appear_scale := 1.25

@onready var top_left : Control = $TopLeft
@onready var top_right : Control = $TopRight
@onready var bottom_left : Control = $BottomLeft
@onready var bottom_right : Control = $BottomRight

## 0 = hidden, 1 = shown.
var amount := 0.0
var target : Node3D
## Square around the target, kept while fading out.
var frame_rect := Rect2()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a = 0.0
	visible = false


func _process(delta : float) -> void:
	var cursor := GlobalManager.cursor_body
	var hovered : Node3D = null
	if cursor and not cursor.in_dialogue and not cursor.dragging:
		hovered = cursor.moused_over_item
	if hovered != target:
		target = hovered
		if target:
			amount = 0.0

	if target and is_instance_valid(target):
		frame_rect = _get_square(target)
	var fade_time := fade_in_time if target else fade_out_time
	amount = move_toward(amount, 1.0 if target else 0.0, delta / max(fade_time, 0.001))
	modulate.a = amount
	visible = amount > 0.0
	if visible:
		_place_corners()


## The item's on-screen bounds, made square and padded.
func _get_square(item : Node3D) -> Rect2:
	var camera := get_viewport().get_camera_3d()
	var bounds := Rect2()
	var first := true
	for visual in item.find_children("*", "VisualInstance3D", true, false):
		if not visual.is_visible_in_tree():
			continue
		var box : AABB = visual.global_transform * visual.get_aabb()
		for i in 8:
			var point := camera.unproject_position(box.get_endpoint(i))
			if first:
				bounds = Rect2(point, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	var side := maxf(bounds.size.x, bounds.size.y) * padding
	return Rect2(bounds.get_center() - Vector2(side, side) / 2.0, Vector2(side, side))


func _place_corners() -> void:
	var pop : float = lerp(appear_scale, 1.0, ease(amount, 0.4))
	var center := frame_rect.get_center()
	var half := frame_rect.size.x / 2.0 * pop
	var corner := Vector2(corner_size, corner_size)
	top_left.position = center + Vector2(-half, -half)
	top_right.position = center + Vector2(half - corner_size, -half)
	bottom_left.position = center + Vector2(-half, half - corner_size)
	bottom_right.position = center + Vector2(half - corner_size, half - corner_size)
	for sprite in [top_left, top_right, bottom_left, bottom_right]:
		sprite.size = corner
