extends TextureButton

@export var hover_offset: float = 10.0
@export var tween_duration: float = 0.15

# Define custom hover zone
@export var hover_margin_left: float = 20.0
@export var hover_margin_right: float = 20.0
@export var hover_margin_top: float = 20.0
@export var hover_margin_bottom: float = 20.0

var original_pos: Vector2
var tween: Tween

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	original_pos = position
	
	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)

# This controls the hover detection area
func _has_point(point: Vector2) -> bool:
	var rect = Rect2(
		Vector2(hover_margin_left, hover_margin_top),
		size - Vector2(
			hover_margin_left + hover_margin_right,
			hover_margin_top + hover_margin_bottom
		)
	)
	return rect.has_point(point)

func _on_enter():
	animate_to(original_pos.y - hover_offset)

func _on_exit():
	animate_to(original_pos.y)

func animate_to(target_y: float):
	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", target_y, tween_duration)
