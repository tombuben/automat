@tool
class_name AimFrame extends Control
## The shooting frame in the world view: gradients, four corners and the charge bar.
## Shown while an item is in the hands; the corners tighten while charging.
## The corners are placed by this script as a square, also in the editor.

@export_group("Frame")
## Side of the square, as a fraction of the view's height.
@export_range(0.1, 1.0, 0.01) var frame_size := 0.78
## Centre of the square, as a fraction of the view (0.5, 0.5 = middle).
@export var frame_center := Vector2(0.5, 0.5)
## Size of each corner sprite, as a fraction of the view's height.
@export_range(0.01, 0.3, 0.005) var corner_size := 0.07

@export_group("Animation")
@export var fade_time := 0.15
## How far out the corners start when the frame appears (1 = in place).
@export var appear_scale := 1.12
## How far in the corners pull at full charge (1 = no change).
@export var charge_scale := 0.94
## How quickly the corners and the bar follow the charge.
@export var charge_follow_speed := 10.0

@export_group("Charge bar")
## The fill never gets shorter than this, so an empty bar still shows a small pill.
@export var fill_min_height := 24.0

@onready var corners : Control = $Corners
@onready var charge_bar : Control = $ChargeBar
@onready var charge_fill : Control = $ChargeBar/Fill
@onready var charge_number : Label = $ChargeBar/Number

## 0 = hidden, 1 = shown.
var amount := 0.0
var charge_amount := 0.0


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	modulate.a = 0.0
	visible = false


func _process(delta : float) -> void:
	_place_corners()
	if Engine.is_editor_hint():
		corners.scale = Vector2.ONE
		_update_charge_bar()
		return

	var world_view := GlobalManager.world_view
	var cursor := GlobalManager.cursor_body
	var active := world_view != null and world_view.object_to_shoot != null and not (cursor and cursor.in_dialogue)
	amount = move_toward(amount, 1.0 if active else 0.0, delta / max(fade_time, 0.001))
	modulate.a = amount
	visible = amount > 0.0

	var charge := 0.0
	if world_view and world_view.charging:
		charge = clamp(world_view.charge_duration / world_view.max_charge_duration, 0.0, 1.0)
	charge_amount = lerp(charge_amount, charge, 1.0 - exp(-charge_follow_speed * delta))

	var appear : float = lerp(appear_scale, 1.0, ease(amount, 0.4))
	corners.scale = Vector2.ONE * appear * lerp(1.0, charge_scale, charge_amount)
	_update_charge_bar()


## Puts the four corners on a square around frame_center.
func _place_corners() -> void:
	var view := size
	var center := view * frame_center
	var half := view.y * frame_size / 2.0
	var corner := Vector2.ONE * view.y * corner_size
	corners.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	corners.pivot_offset = center
	var places := {
		"TopLeft": center + Vector2(-half, -half),
		"TopRight": center + Vector2(half - corner.x, -half),
		"BottomLeft": center + Vector2(-half, half - corner.y),
		"BottomRight": center + Vector2(half - corner.x, half - corner.y),
	}
	for corner_name in places:
		var sprite := corners.get_node_or_null(corner_name) as Control
		if sprite == null:
			continue
		sprite.set_anchors_preset(Control.PRESET_TOP_LEFT)
		sprite.scale = Vector2.ONE
		sprite.position = places[corner_name]
		sprite.size = corner


## The fill grows out from the middle of the bar; the number stays put.
func _update_charge_bar() -> void:
	var fill_height : float = lerp(fill_min_height, charge_bar.size.y, charge_amount)
	charge_fill.offset_top = -fill_height / 2.0
	charge_fill.offset_bottom = fill_height / 2.0
	charge_number.text = "%03d" % roundi(charge_amount * 100.0)
