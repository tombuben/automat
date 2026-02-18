class_name DispenserSelector extends Area3D

var body_in_dispenser : RandomItem

func _ready() -> void:
	GlobalManager.dispensor_selector = self
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)

func _on_body_entered(body):
	if body is RandomItem:
		set_body_async(body)

func set_body_async(body : RandomItem) -> void:
	var cursor = GlobalManager.cursor_body
	cursor.stopped_dragging.disconnect(set_body_async)
	if cursor.get_dragged_item() == body:
		cursor.stopped_dragging.connect(set_body_async)
	else:
		set_body(body)

func set_body(body : RandomItem) -> void:
	remove_from_dispenser()
	body_in_dispenser = body
	body.freeze = true
	show_ui(body)
	start_shooting(body)

func show_ui(body : RandomItem):
	pass

func start_shooting(body : RandomItem):
	var tween = create_tween()
	var duration = 0.1
	tween.tween_property(body, "global_position", global_position, duration)
	tween.tween_property(body, "rotation", rotation, duration)
	GlobalManager.world_view.spawn_duplicate(body)
	expand_for_shooting()

func _on_body_exited(body):
	if body is RandomItem and not body.freeze:
		remove_from_dispenser()
		expand_for_selection()
	
func remove_from_dispenser():
	var cursor = GlobalManager.cursor_body
	cursor.stopped_dragging.disconnect(set_body_async)
	GlobalManager.world_view.delete_object_to_shoot()
	
	if body_in_dispenser:
		body_in_dispenser.return_to_slot()
	body_in_dispenser = null
	

func update_rotation(charge_duration : float):
	body_in_dispenser.rotate_z(charge_duration / 5)

func shoot_from_dispenser():

	var tween = create_tween()
	tween.tween_property(body_in_dispenser, "global_position", global_position + Vector3.BACK, 0.1)
	await tween.finished
	body_in_dispenser.in_slot.respawn()
	
	body_in_dispenser.queue_free()
	body_in_dispenser = null

	expand_for_selection(0.5)

func expand_for_shooting(duration = 1.0):
	return

	var tween = create_tween()
	var screen_size = 0.0
	tween.tween_property(GlobalManager.screen_resizer, "ratio", screen_size, duration)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)

func expand_for_selection(duration = 1.0):
	return

	var tween = create_tween()
	var screen_size = 0.6
	tween.tween_property(GlobalManager.screen_resizer, "ratio", screen_size, duration)\
		.set_trans(Tween.TRANS_BOUNCE)\
		.set_ease(Tween.EASE_OUT)
