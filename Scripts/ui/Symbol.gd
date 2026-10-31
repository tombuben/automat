extends TextureRect

signal clicked(symbol)

@export var hover_scale: float = 1.15
@export var pulse_peak: float = 1.22

@export var hover_time: float = 0.18

var is_hovered := false
var base_scale := 1.0
var current_tween: Tween


func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size * 0.5

	mouse_entered.connect(_on_enter)
	mouse_exited.connect(_on_exit)


# -------------------------
# HOVER STATE (defines "rest scale")
# -------------------------
func _on_enter():
	is_hovered = true
	base_scale = hover_scale
	_tween_base()

func _on_exit():
	is_hovered = false
	base_scale = 1.0
	_tween_base()


func _tween_base():
	if current_tween:
		current_tween.kill()

	current_tween = create_tween()
	current_tween.set_trans(Tween.TRANS_CUBIC)
	current_tween.set_ease(Tween.EASE_OUT)

	current_tween.tween_property(
		self,
		"scale",
		Vector2.ONE * base_scale,
		hover_time
	)


# -------------------------
# INPUT
# -------------------------
func _gui_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			clicked.emit(self)


# -------------------------
# RIPPLE PULSE (additive, no hover conflict)
# -------------------------
func pulse(delay := 0.0):

	if current_tween:
		current_tween.kill()

	current_tween = create_tween()

	if delay > 0.0:
		current_tween.tween_interval(delay)

	var peak = base_scale * pulse_peak

	current_tween.set_trans(Tween.TRANS_BACK)
	current_tween.set_ease(Tween.EASE_OUT)

	# Anticipation (tiny squash)
	current_tween.tween_property(
		self,
		"scale",
		Vector2.ONE * (base_scale * 0.92),
		0.08
	)

	# Impact
	current_tween.tween_property(
		self,
		"scale",
		Vector2.ONE * peak,
		0.12
	)

	# Settle back to hover/base state
	current_tween.tween_property(
		self,
		"scale",
		Vector2.ONE * base_scale,
		0.16
	)
