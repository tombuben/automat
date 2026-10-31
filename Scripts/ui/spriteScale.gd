extends Area3D

@export var hover_scale := Vector3(1.2, 1.2, 1.2)
@export var duration := 0.15

@export var sprite := Sprite3D

var original_scale : Vector3

func _ready():
	original_scale = sprite.scale
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	create_tween().tween_property(
		sprite,
		"scale",
		hover_scale,
		duration
	)

func _on_mouse_exited():
	create_tween().tween_property(
		sprite,
		"scale",
		original_scale,
		duration
	)
