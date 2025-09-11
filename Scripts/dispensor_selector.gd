class_name DispenserSelector extends Area3D

var body_in_dispenser : RandomItem

func _ready() -> void:
	GlobalManager.dispensor_selector = self
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _on_body_entered(body):
	if body is RandomItem:
		
		print("body entered")
		body_in_dispenser = body
		set_body_async(body)
		
func set_body_async(body : RigidBody3D) -> void:
	var cursor = GlobalManager.cursor_body
	cursor.stopped_dragging.disconnect(set_body_async)
	if cursor.get_dragged_item() == body:
		cursor.stopped_dragging.connect(set_body_async)
	else:
		body.freeze = true
		var tween = create_tween()
		var duration = 0.1
		tween.tween_property(body, "global_position", global_position, duration)
		tween.tween_property(body, "rotation", rotation, duration)
		GlobalManager.world_view.spawn_duplicate(body)

func _on_body_exited(body):
	if body is RandomItem and not body.freeze:
		var cursor = GlobalManager.cursor_body
		cursor.stopped_dragging.disconnect(set_body_async)
		GlobalManager.world_view.delete_object_to_shoot()
		body_in_dispenser = null
		
func update_rotation(charge_duration : float):
	body_in_dispenser.rotate_z(charge_duration / 5)

func shoot_from_dispenser():
	body_in_dispenser.queue_free()
	body_in_dispenser = null
