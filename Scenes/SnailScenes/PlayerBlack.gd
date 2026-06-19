extends Area3D

@export var player_visual: Node3D

@export var target_color: Color = Color.BLACK
@export var transition_time: float = 1.0

var original_modulate: Color
var color_tween: Tween


func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if player_visual:
		original_modulate = player_visual.modulate


func _on_body_entered(body):

	if not body.has_method("get_camera_controller"):
		return

	if player_visual == null:
		return

	start_color_tween(target_color)


func _on_body_exited(body):

	if not body.has_method("get_camera_controller"):
		return

	if player_visual == null:
		return

	start_color_tween(original_modulate)


func start_color_tween(target: Color):

	if color_tween:
		color_tween.kill()

	color_tween = create_tween()

	color_tween.tween_property(
		player_visual,
		"modulate",
		target,
		transition_time
	)
