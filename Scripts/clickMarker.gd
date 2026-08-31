class_name ClickMarker
extends Node3D
# =====================================================
# CLICK MARKER
# =====================================================
# The "walk here" indicator placed at a click's world position.
#
# Driven entirely through show_at()/hide_marker() — never through the
# `visible` property directly. Earlier this replayed its pop animation
# from _notification(NOTIFICATION_VISIBILITY_CHANGED), which only fires
# when `visible` actually flips false->true. Clicking again while the
# marker was still mid-fade (visible already true) was a no-op, so the
# animation never restarted and the marker could finish fading to
# invisible right as the new click landed. show_at() always restarts the
# pop, regardless of current visibility.
@export var visual: Sprite3D
@export var lifetime: float = 0.5
@export var start_scale: float = 0.6
@export var end_scale: float = 1.0
var _tween: Tween
func _ready() -> void:
	scale = Vector3.ONE * start_scale
	if visual:
		# Keep the marker a constant screen size regardless of how far
		# away the click landed (Sprite3D otherwise shrinks with distance
		# like any other 3D quad).
		visual.fixed_size = true
		# Always draw on top of world geometry/sprites instead of getting
		# sorted behind them.
		visual.no_depth_test = true
		visual.render_priority = 10
		visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
# Call to (re)place the marker and play its pop-in animation. Safe to
# call repeatedly, including while a previous pop is still playing.
func show_at(world_pos: Vector3) -> void:
	global_position = world_pos
	visible = true
	_play_pop()
# Call when the walk target is reached (or superseded) to hide the marker
# and cancel any in-flight animation cleanly.
func hide_marker() -> void:
	if _tween:
		_tween.kill()
	visible = false
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
	_tween.tween_callback(hide_marker)
