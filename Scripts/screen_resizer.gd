class_name ScreenResizer extends Control

@export var left_subviewport : SubViewport
@onready var left_subviewport_container : SubViewportContainer = left_subviewport.get_parent()

@export var right_subviewport : SubViewport

@export var divider : ColorRect

@export var dialogue_resource : DialogueResource

@export var ratio : float
var original_ration : float

# -------------------------
# TWEEN SETTINGS
# -------------------------
@export var resize_duration : float = 0.25
@export var resize_trans : Tween.TransitionType = Tween.TRANS_CUBIC
@export var resize_ease : Tween.EaseType = Tween.EASE_OUT

var resize_tween : Tween

func _ready() -> void:
	GlobalManager.screen_resizer = self
	
	var viewport = get_viewport()
	ratio = left_subviewport.size.x / float(viewport.size.x)
	original_ration = ratio
	
	DialogueManager.show_dialogue_balloon(dialogue_resource, "day1_start")

func _process(delta: float) -> void:
	var viewport = get_viewport()

	var left_width = ratio * float(viewport.size.x)

	left_subviewport_container.size.x = left_width

	
	divider.position.x = left_width - divider.size.x / 2.0

# -------------------------
# RESIZE FUNCTION (USE THIS)
# -------------------------
func resize_to(new_ratio : float) -> void:

	new_ratio = clamp(new_ratio, 0.0, 1.0)

	# Kill previous tween so it doesn't stack
	if resize_tween and resize_tween.is_valid():
		resize_tween.kill()

	resize_tween = create_tween()

	resize_tween.tween_property(
		self,
		"ratio",
		new_ratio,
		resize_duration
	).set_trans(resize_trans).set_ease(resize_ease)

# -------------------------
# RESET
# -------------------------
func reset_ratio() -> void:
	resize_to(original_ration)
