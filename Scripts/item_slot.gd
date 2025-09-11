class_name ItemSlot extends Area3D

@export var item_in_slot : RandomItem
var highlighted : bool
var old_item_position : Vector3
var old_item_rotation : Vector3
var cursor_body : CursorBody
@onready var tween = create_tween().set_parallel(true)

func _ready() -> void:
	old_item_position = item_in_slot.global_position
	old_item_rotation = item_in_slot.rotation
	
	item_in_slot.insert_to_slot(self)
	connect("body_entered", on_body_entered)
	connect("body_exited", on_body_exited)

func on_body_entered(body):
	if body is CursorBody:
		cursor_body = body
		
		cursor_body.stopped_dragging.connect(stopped_dragging)
		if not body.dragging and item_in_slot and item_in_slot.in_slot:
			highlight_item()

func on_body_exited(body):
	if body is CursorBody:
		if not body.dragging and item_in_slot and item_in_slot.in_slot:
			reset_highlight()
		
		body.stopped_dragging.disconnect(stopped_dragging)

func stopped_dragging(item : RandomItem):
	if not item_in_slot:
		item.insert_to_slot(self)
		
	if item == item_in_slot:
		highlight_item()
		pass
	elif	 not cursor_body.dragging and item_in_slot.in_slot:
		highlight_item()
		pass

func highlight_item():
	highlighted = true
	item_in_slot.freeze = true
	if highlighted and item_in_slot.freeze:
		var duration = 0.1
		tween.kill()
		tween = create_tween()
		tween.tween_property(item_in_slot, "global_position", global_position, duration)
		tween.tween_property(item_in_slot, "rotation", rotation, duration)
	return
	
func reset_highlight():
	highlighted = false
	item_in_slot.freeze = true
	
	var duration = 0.1
	
	tween.kill()
	tween = create_tween()
	tween.tween_property(item_in_slot, "global_position", old_item_position, duration)
	tween.tween_property(item_in_slot, "rotation", old_item_rotation, duration)
