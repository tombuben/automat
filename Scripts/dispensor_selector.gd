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
	if body_in_dispenser:
		remove_from_dispenser()

	body_in_dispenser = body
	body.freeze = true

	show_ui(body)
	hold_item(body)

	# Expand screen when item is selected
	GlobalManager.expand_for_shooting()

func show_ui(item : RandomItem):
	GlobalManager.hand_selection_ui.show_ui_for_item(item)

func hide_ui():
	GlobalManager.hand_selection_ui.hide_ui()

func hold_item(body : RandomItem):
	var tween = create_tween()
	var duration = 0.1
	tween.tween_property(body, "global_position", global_position, duration)
	tween.tween_property(body, "rotation", rotation, duration)

func start_shooting(body : RandomItem):
	GlobalManager.world_view.spawn_duplicate(body)

func _on_body_exited(body):
	if body is RandomItem and not body.freeze:
		remove_from_dispenser()
		GlobalManager.expand_for_selection()

func stop_holding():
	var cursor = GlobalManager.cursor_body
	cursor.stopped_dragging.disconnect(set_body_async)
	
	if body_in_dispenser:
		body_in_dispenser.return_to_slot()

	body_in_dispenser = null
	
	hide_ui()

	# Shrink screen when item is removed / put back
	GlobalManager.expand_for_selection()

func remove_from_dispenser():
	GlobalManager.world_view.delete_object_to_shoot()
	stop_holding()

func update_rotation(charge_duration : float):
	if body_in_dispenser:
		body_in_dispenser.rotate_z(charge_duration / 5)

func shoot_from_dispenser():

	var tween = create_tween()
	tween.tween_property(body_in_dispenser, "global_position", global_position + Vector3.BACK, 0.1)
	await tween.finished

	body_in_dispenser.in_slot.respawn()
	body_in_dispenser.queue_free()
	body_in_dispenser = null

	GlobalManager.expand_for_selection(0.5)
