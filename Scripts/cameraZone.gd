extends Area3D

@export var camera_fov: float = 90.0
@export var transition_time := 1.0

@export var transition_type: Tween.TransitionType = Tween.TRANS_SINE
@export var ease_type: Tween.EaseType = Tween.EASE_IN_OUT

@export var zone_priority := 0

# X framing toggle
@export var lock_camera_position := true

# NEW: Y comes from camera_target transform
@export var use_camera_target_y := false

@export var camera_target: Node3D


func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body):
	if body.has_method("get_camera_controller"):
		body.get_camera_controller().push_camera_zone(self)


func _on_body_exited(body):
	if body.has_method("get_camera_controller"):
		body.get_camera_controller().remove_camera_zone(self)
