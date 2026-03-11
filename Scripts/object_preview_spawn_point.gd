class_name ObjectPreviewSpawnPoint extends Node3D

@export var rotation_speed := 1.0

var is_dragging := false
var target_rotation_y : float
var current_rotation_y : float
var last_mouse_position : Vector2

func _ready():
	# Initialize the current rotation
	current_rotation_y = rotation.y
	target_rotation_y = current_rotation_y

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Perform raycast to check if click is on this node or its children
			var viewport = get_viewport()
			var camera = viewport.get_camera_3d()
			if camera:
				var ray_origin = camera.project_ray_origin(viewport.get_mouse_position())
				var ray_direction = camera.project_ray_normal(viewport.get_mouse_position())

				var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 100.0)
				var space_state = get_world_3d().direct_space_state
				var result = space_state.intersect_ray(query)
				# Check if the clicked object is this node or one of its descendants
				if result.has("collider"):
					var collider : RigidBody3D = result["collider"]
					if is_ancestor_of(collider) or collider == self:
						is_dragging = true
						last_mouse_position = viewport.get_mouse_position()
		else:
			is_dragging = false

	if event is InputEventMouseMotion and is_dragging:
		var current_mouse_position = get_viewport().get_mouse_position()
		var delta = last_mouse_position - current_mouse_position

		# Update target rotation based on mouse movement
		target_rotation_y -= delta.x * rotation_speed * 0.01

		last_mouse_position = current_mouse_position

func _process(delta):
	# Smoothly interpolate rotation in process
	target_rotation_y += delta
	current_rotation_y = lerp(current_rotation_y, target_rotation_y, 10.0 * delta)

	# Apply the rotation
	rotation = Vector3(0, current_rotation_y, 0)
	
func spawn_item(item_to_spawn : RandomItem):
	remove_item()
	var object_preview = item_to_spawn.duplicate()
	object_preview.freeze = true
	object_preview.rotation = Vector3.ZERO
	object_preview.position = Vector3.ZERO
	add_child(object_preview)

func remove_item():
	for child in get_children():
		remove_child(child)
		child.queue_free()
