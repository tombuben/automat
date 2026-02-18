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
@onready var pin = $PinJoint3D
var moused_over_item : RandomItem
var last_dragged_object : RandomItem

func _ready() -> void:
	GlobalManager.cursor_body = self

func move_cursor():
	var screen_position = get_viewport().get_mouse_position()
	var viewport_rect = get_viewport().get_visible_rect()
	var camera = get_viewport().get_camera_3d()
	var origin = camera.project_ray_origin(screen_position)
	var direction = camera.project_ray_normal(screen_position)
	
	var plane = Plane(Vector3(0,0,1), 0.5)
	var potential_position = plane.intersects_ray(origin, direction)
	if (potential_position != null):
		position = potential_position

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			start_drag()
		elif event.is_released():
			stop_drag()
			
	
func _physics_process(delta: float) -> void:
	move_cursor()
	var screen_position: Vector2 = get_viewport().get_mouse_position()
	var viewport_rect: Rect2 = get_viewport().get_visible_rect()
	var camera: Camera3D = get_viewport().get_camera_3d()
	var origin: Vector3 = camera.project_ray_origin(screen_position)
	var direction: Vector3 = camera.project_ray_normal(screen_position) * 1
	
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	
	var mask: int = 1 << 1	
	var params := PhysicsPointQueryParameters3D.new()
	params.position = global_position
	params.collision_mask = mask
	var result = space_state.intersect_point(params)
	if len(result) and result[0].collider is RigidBody3D:
		moused_over_item = result[0].collider
	else:
		moused_over_item = null
	
	
func start_drag():
	if moused_over_item == null:
		return
	
	moused_over_item.take_out_of_slot()
	pin.node_b = moused_over_item.get_path()
	dragging = true
	last_dragged_object = moused_over_item
	if last_dragged_object is RigidBody3D:
		last_dragged_object.axis_lock_angular_x = true
		last_dragged_object.axis_lock_angular_y = true
		last_dragged_object.axis_lock_angular_z = true
	emit_signal("started_dragging", moused_over_item)
	pass

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
	pass
