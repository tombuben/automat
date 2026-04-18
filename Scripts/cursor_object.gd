class_name CursorBody extends AnimatableBody3D

## public

func get_dragged_item() -> RigidBody3D:
	if not dragging:
		return null
	return last_dragged_object

var dragging : bool = false
signal started_dragging(item)
signal stopped_dragging(item)

## private
@export var open_hands: AnimatedSprite3D

@export var cursor_visual_path: NodePath
var cursor_visual: Node

@onready var pin = $PinJoint3D
var moused_over_item : RandomItem
var last_dragged_object : RandomItem

# --- movement scaling ---
@export var min_scale: float = 0.6
@export var max_scale: float = 1.2
@export var speed_for_min: float = 1500.0
@export var scale_smoothing: float = 10.0

# --- click feel ---
@export var click_squash: float = 0.85
@export var click_return_speed: float = 18.0

var _click_strength: float = 0.0

var _last_mouse_pos: Vector2
var _mouse_speed: float = 0.0
var _base_scale_3d: Vector3 = Vector3.ONE
var _base_scale_2d: Vector2 = Vector2.ONE

func _ready() -> void:
	GlobalManager.cursor_body = self
	_last_mouse_pos = get_viewport().get_mouse_position()

	if cursor_visual_path != NodePath():
		cursor_visual = get_node(cursor_visual_path)

		if cursor_visual is Node3D:
			_base_scale_3d = cursor_visual.scale
		elif cursor_visual is Node2D:
			_base_scale_2d = cursor_visual.scale


func move_cursor():
	var screen_position = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	var origin = camera.project_ray_origin(screen_position)
	var direction = camera.project_ray_normal(screen_position)

	var plane = Plane(Vector3(0,0,1), 0.5)
	var potential_position = plane.intersects_ray(origin, direction)
	if potential_position != null:
		position = potential_position


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_click_strength = 1.0
			start_drag()
		elif event.is_released():
			stop_drag()


func _physics_process(delta: float) -> void:
	move_cursor()

	var current_mouse_pos = get_viewport().get_mouse_position()

	# --- mouse speed ---
	_mouse_speed = current_mouse_pos.distance_to(_last_mouse_pos) / delta

	# --- base scale from movement ---
	var t = clamp(_mouse_speed / speed_for_min, 0.0, 1.0)
	var base_scale = lerp(max_scale, min_scale, t)

	# --- click impulse (IMPORTANT FIX) ---
	_click_strength = lerp(_click_strength, 0.0, click_return_speed * delta)

	var click_offset = (click_squash - 1.0) * _click_strength
	var target_scale = base_scale + click_offset * base_scale

	# --- apply to visual ---
	if cursor_visual:
		if cursor_visual is Node3D:
			var target_vec3 = _base_scale_3d * target_scale
			cursor_visual.scale = cursor_visual.scale.lerp(target_vec3, scale_smoothing * delta)

		elif cursor_visual is Node2D:
			var target_vec2 = _base_scale_2d * target_scale
			cursor_visual.scale = cursor_visual.scale.lerp(target_vec2, scale_smoothing * delta)


	# --- collision ---
	var camera: Camera3D = get_viewport().get_camera_3d()
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	var mask: int = 1 << 1
	var params := PhysicsPointQueryParameters3D.new()
	params.position = global_position
	params.collision_mask = mask

	var result = space_state.intersect_point(params)
	if len(result) and result[0].collider is RandomItem:
		moused_over_item = result[0].collider
	else:
		moused_over_item = null

	_last_mouse_pos = current_mouse_pos


func start_drag():
	if moused_over_item == null:
		return

	if GlobalManager.dispensor_selector.body_in_dispenser and moused_over_item != GlobalManager.dispensor_selector.body_in_dispenser:
		GlobalManager.dispensor_selector.remove_from_dispenser()

	moused_over_item.take_out_of_slot()
	pin.node_b = moused_over_item.get_path()
	dragging = true
	last_dragged_object = moused_over_item

	if last_dragged_object is RigidBody3D:
		last_dragged_object.axis_lock_angular_x = true
		last_dragged_object.axis_lock_angular_y = true
		last_dragged_object.axis_lock_angular_z = true

	emit_signal("started_dragging", moused_over_item)

	open_hands.stop()
	open_hands.play("open_hand")


func stop_drag():
	if not dragging:
		return

	pin.node_b = NodePath("")
	dragging = false

	if last_dragged_object is RigidBody3D:
		last_dragged_object.axis_lock_angular_x = false
		last_dragged_object.axis_lock_angular_y = false
		last_dragged_object.axis_lock_angular_z = false

	emit_signal("stopped_dragging", last_dragged_object)

	open_hands.stop()
	open_hands.play("close_hand")
