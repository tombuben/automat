extends Node3D

@export var height: float = 1.0        # How high it moves
@export var duration: float = 1.5      # Time to go up/down
@export var delay: float = 0.0         # Optional delay before starting
@export var easing: Tween.EaseType = Tween.EASE_IN_OUT
@export var transition: Tween.TransitionType = Tween.TRANS_SINE

var _start_position: Vector3
var _tween: Tween

func _ready():
	_start_position = global_position
	if delay > 0:
		await get_tree().create_timer(delay).timeout
	start_floating()

func start_floating():
	_tween = create_tween()
	_tween.set_loops() # infinite loop

	var up_pos = _start_position + Vector3.UP * height
	var down_pos = _start_position

	_tween.tween_property(self, "global_position", up_pos, duration)\
		.set_trans(transition).set_ease(easing)

	_tween.tween_property(self, "global_position", down_pos, duration)\
		.set_trans(transition).set_ease(easing)
