class_name ItemSlot extends Area3D

@export var item_in_slot : RandomItem
var item_backup : RandomItem
var slot_occupied : bool

var highlighted : bool
var old_item_position : Vector3
var old_item_rotation : Vector3
@onready var cursor_body : CursorBody = %CursorBody
@onready var tween = create_tween().set_parallel(true)

func _ready() -> void:
	item_backup = item_in_slot.duplicate()
	
	old_item_position = item_in_slot.global_position
	old_item_rotation = item_in_slot.rotation
	
	item_in_slot.insert_to_slot(self)
	connect("body_entered", on_body_entered)
	connect("body_exited", on_body_exited)
	cursor_body.stopped_dragging.connect(stopped_dragging)

func on_body_entered(body):
	if body is CursorBody:
		cursor_body = body
		
		var dispenser_body = GlobalManager.dispensor_selector.body_in_dispenser
		if not body.dragging and dispenser_body != item_in_slot:
			highlight_item()

func on_body_exited(body):
	if body is CursorBody:
		var dispenser_body = GlobalManager.dispensor_selector.body_in_dispenser
		if not body.dragging and dispenser_body != item_in_slot:
			reset_highlight()
		
func stopped_dragging(item : RandomItem):
	if GlobalManager.dispensor_selector.body_in_dispenser == item:
		return

	if not slot_occupied:
		item.return_to_slot()
		
	if item == item_in_slot:
		highlight_item()

func highlight_item():
	if item_in_slot == null:
		return
		
	highlighted = true
	item_in_slot.freeze = true
	if highlighted and item_in_slot.freeze:
		var duration = 0.1
		tween.kill()
		tween = create_tween()
		tween.tween_property(item_in_slot, "global_position", global_position, duration)
		tween.tween_property(item_in_slot, "rotation", rotation, duration)

func reset_highlight():
	if item_in_slot == null:
		return

	highlighted = false
	item_in_slot.freeze = true
	
	var duration = 0.1
	
	tween.kill()
	tween = create_tween()
	tween.tween_property(item_in_slot, "global_position", old_item_position, duration)
	tween.tween_property(item_in_slot, "rotation", old_item_rotation, duration)
	
func respawn():
	var new_item = item_backup.duplicate()
	add_child(new_item)
	new_item.global_position = old_item_position
	new_item.rotation = old_item_rotation
	new_item.insert_to_slot(self)
