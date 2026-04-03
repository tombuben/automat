class_name ItemSlot extends Area3D

@export var item_in_slot : RandomItem
var item_backup : RandomItem
var slot_occupied : bool

var highlighted : bool
var old_item_position : Vector3
var old_item_scale : Vector3

@onready var cursor_body : CursorBody = %CursorBody
@onready var tween : Tween = create_tween().set_parallel(true)

func _ready() -> void:
	GlobalManager.slots[name] = self
	
	item_backup = item_in_slot.duplicate()
	
	old_item_position = item_in_slot.position
	old_item_scale = item_in_slot.scale
	
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
	
	GlobalManager.dialogue_preview.show_preview(item_in_slot.saying)
	
	highlighted = true
	item_in_slot.freeze = true
	
	var duration := 0.1
	
	tween.kill()
	tween = create_tween().set_parallel(true)

	# keep position tween (needed for drag logic)
	tween.tween_property(item_in_slot, "global_position", global_position, duration)

	# scale up slightly
	tween.tween_property(item_in_slot, "scale", old_item_scale * 1.1, duration)

func reset_highlight():
	if item_in_slot == null:
		return

	#this should be probably managed globally, so one item doesn't reset other items preview
	if GlobalManager.dialogue_preview:
		GlobalManager.dialogue_preview.hide_preview()

	highlighted = false
	item_in_slot.freeze = true
	
	var duration := 0.1
	
	tween.kill()
	tween = create_tween().set_parallel(true)

	# return to original position
	tween.tween_property(item_in_slot, "position", old_item_position, duration)

	# return to original scale
	tween.tween_property(item_in_slot, "scale", old_item_scale, duration)

func respawn():
	var new_item = item_backup.duplicate()
	add_child(new_item)
	new_item.position = old_item_position
	new_item.scale = old_item_scale
	new_item.insert_to_slot(self)
	
func change_item_name(new_item_name : String):
	item_in_slot.item_name = new_item_name
	item_backup.item_name = new_item_name
	
func change_item_saying(new_item_saying : String):
	item_in_slot.saying = new_item_saying
	item_backup.saying = new_item_saying
