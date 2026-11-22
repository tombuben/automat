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
## Empty = the automat's openHands, found through the "automat_open_hands" group.
@export var open_hands: AnimatedSprite3D

@onready var pin = $PinJoint3D
var moused_over_item : RandomItem
var last_dragged_object : RandomItem
var in_dialogue : bool = false

@onready var original_collision_layer = collision_layer

func _enter_tree() -> void:
	# Registered before any _ready, so item slots can find the cursor in theirs
	GlobalManager.cursor_body = self

func _ready() -> void:
	if open_hands == null:
		open_hands = get_tree().get_first_node_in_group(&"automat_open_hands")

	DialogueManager.dialogue_started.connect(on_dialogue_started)
	DialogueManager.dialogue_ended.connect(on_dialogue_closed)

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
			start_drag()
		elif event.is_released():
			stop_drag()

func _physics_process(delta: float) -> void:
	move_cursor()

	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state

	var mask: int = 1 << 1
	var params := PhysicsPointQueryParameters3D.new()
	params.position = global_position
	params.collision_mask = mask

	var result = space_state.intersect_point(params)
	if len(result) and result[0].collider is RandomItem and result[0].collider.visible:
		moused_over_item = result[0].collider
	else:
		moused_over_item = null

func start_drag():
	if moused_over_item == null or in_dialogue or GlobalManager.world_view.throw_in_flight:
		return

	GlobalManager.world_view.put_back_loaded_item()

	moused_over_item.take_out_of_slot()
	pin.node_b = moused_over_item.get_path()
	dragging = true
	last_dragged_object = moused_over_item

	if last_dragged_object is RigidBody3D:
		last_dragged_object.axis_lock_angular_x = true
		last_dragged_object.axis_lock_angular_y = true
		last_dragged_object.axis_lock_angular_z = true

	GlobalManager.drag_ghost.show_item(moused_over_item)

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

	GlobalManager.drag_ghost.hide_item()

	var drop_position = GlobalManager.world_view.get_mouse_in_view()
	if drop_position != null and not in_dialogue:
		GlobalManager.world_view.load_item(last_dragged_object, drop_position)

	emit_signal("stopped_dragging", last_dragged_object)

	open_hands.stop()
	open_hands.play("close_hand")

func on_dialogue_started(resource: Resource) -> void:
	collision_layer = 0
	in_dialogue = true

func on_dialogue_closed(resource: Resource) -> void:
	collision_layer = original_collision_layer
	in_dialogue = false
