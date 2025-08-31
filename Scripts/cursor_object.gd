extends AnimatableBody3D

@onready var pin = $PinJoint3D
var hoveredItem

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
		else:
			stop_drag()
			
	
func _physics_process(delta: float) -> void:
	move_cursor()
	var screen_position = get_viewport().get_mouse_position()
	var viewport_rect = get_viewport().get_visible_rect()
	var camera = get_viewport().get_camera_3d()
	var origin = camera.project_ray_origin(screen_position)
	var direction = camera.project_ray_normal(screen_position) * 1
	
	var space_state = get_world_3d().direct_space_state
	
	var collision_mask = 1 << 1
	var query = PhysicsRayQueryParameters3D.create(origin, origin + direction, collision_mask)
	var result = space_state.intersect_ray(query)
	if result:
		hoveredItem = result.collider
	
func start_drag():
	pin.node_b = hoveredItem.get_path()
	pass

func stop_drag():
	# maybe add impulse? probably not needed though because of AnimatableBody
	pin.node_b = NodePath("")
	pass
