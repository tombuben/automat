extends Node3D

@export var viewport_container: SubViewportContainer
@export var camera: Camera3D   # optional, only if you want direct access

@export var max_angle := 2.0
@export var smooth_speed := 5.0

var is_active := false


func _ready():
	if viewport_container:
		viewport_container.mouse_entered.connect(_on_mouse_entered)
		viewport_container.mouse_exited.connect(_on_mouse_exited)


func _process(delta):
	if not viewport_container:
		return

	var vp = viewport_container.get_viewport()
	var mouse_pos = vp.get_mouse_position()
	var rect = vp.get_visible_rect()

	if is_active:
		var offset = (mouse_pos / rect.size) - Vector2(0.5, 0.5)

		var target_rot_x = -offset.y * deg_to_rad(max_angle)
		var target_rot_y = -offset.x * deg_to_rad(max_angle)

		rotation.x = lerp(rotation.x, target_rot_x, delta * smooth_speed)
		rotation.y = lerp(rotation.y, target_rot_y, delta * smooth_speed)
	else:
		rotation.x = lerp(rotation.x, 0.0, delta * smooth_speed)
		rotation.y = lerp(rotation.y, 0.0, delta * smooth_speed)


func _on_mouse_entered():
	is_active = true


func _on_mouse_exited():
	is_active = false
