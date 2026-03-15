class_name RotateAround
extends Node3D

@export var mouse_height_to_pos_curve: Curve
@export var max_yaw := 5.0
@export var max_pitch := 5.0
@export var rotation_speed := 5.0
@export var position_speed := 5.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var cursor_object: CursorBody = $"../CursorObject"

var original_pos: Vector3
var target_pos: Vector3

func _ready() -> void:
	original_pos = global_position
	target_pos = original_pos
	GlobalManager.rotate_around = self
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(delta: float) -> void:
	var viewport_rect = get_viewport().get_visible_rect()
	var mouse_pos = get_viewport().get_mouse_position()

	if not viewport_rect.has_point(mouse_pos):
		mouse_pos = viewport_rect.size / 2

	handle_camera_rotation(delta, mouse_pos)
	handle_camera_position(delta)

func handle_camera_rotation(delta: float, mouse_pos: Vector2) -> void:

	var rel = mouse_pos / get_viewport().get_visible_rect().size
	rel.x = clamp(rel.x, 0.0, 1.0)
	rel.y = clamp(rel.y, 0.0, 1.0)

	var yaw_angle = (rel.x - 0.5) * 2 * deg_to_rad(max_yaw)
	var pitch_angle = (0.5 - rel.y) * 2 * deg_to_rad(max_pitch)

	var current_quat = camera_pivot.basis.get_rotation_quaternion()
	var target_quat = Quaternion.from_euler(Vector3(pitch_angle, yaw_angle, 0))

	camera_pivot.basis = Basis(current_quat.slerp(target_quat, delta * rotation_speed))

func handle_camera_position(delta: float) -> void:

	var relative_position: float = -1.0

	if cursor_object.last_dragged_object and not cursor_object.last_dragged_object.in_slot:
		var obj_height = cursor_object.last_dragged_object.global_position.y
		relative_position = remap(obj_height, 0.5, 2.0, 1.0, -1.0)

	var height_pos: float = mouse_height_to_pos_curve.sample(relative_position) if mouse_height_to_pos_curve else relative_position
	target_pos.y = original_pos.y - height_pos * 0.6

	global_position = global_position.lerp(target_pos, delta * position_speed)
