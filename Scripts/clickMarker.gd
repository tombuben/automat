extends Node3D

@export var visual: Sprite3D

@export var lifetime: float = 0.5
@export var start_scale: float = 0.6
@export var end_scale: float = 1.0

var _tween: Tween


func _ready() -> void:
	scale = Vector3.ONE * start_scale


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_play_pop()


func _play_pop() -> void:

	if _tween:
		_tween.kill()

	scale = Vector3.ONE * start_scale

	if visual:
		visual.modulate.a = 1.0

	_tween = create_tween()
	_tween.set_parallel(true)

	_tween.tween_property(
		self,
		"scale",
		Vector3.ONE * end_scale,
		lifetime
	)

	if visual:
		_tween.tween_property(
			visual,
			"modulate:a",
			0.0,
			lifetime
		)

	_tween.set_parallel(false)
	_tween.tween_callback(_hide_marker)


func _hide_marker() -> void:
	visible = false
