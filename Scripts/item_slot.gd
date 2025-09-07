extends Area3D

@export var item_in_slot : RigidBody3D
var highlighted : bool
var old_item_position : Vector3
var old_item_rotation : Vector3
var cursor_body : CursorBody
@onready var tween = create_tween().set_parallel(true)


func _ready() -> void:
	item_in_slot.freeze = true
	old_item_position = item_in_slot.global_position
	old_item_rotation = item_in_slot.rotation
	connect("body_entered", on_body_entered)
	connect("body_exited", on_body_exited)

func on_body_entered(body):
	if body is CursorBody:
		cursor_body = body
		
		print_debug("connect higlight")
		cursor_body.stopped_dragging.connect(stopped_dragging)
		if not body.dragging and item_in_slot.freeze:
			highlight_item()

func on_body_exited(body):
	if body is CursorBody:
		if not body.dragging and item_in_slot.freeze:
			reset_highlight()
		
		print_debug("disconnect higlight")
		body.stopped_dragging.disconnect(stopped_dragging)

func stopped_dragging(item):
	if item == item_in_slot or \
	  not cursor_body.dragging and item_in_slot.freeze:
		highlight_item()

func highlight_item():
	print_debug("highlight")
	highlighted = true
	item_in_slot.freeze = true
	if highlighted and item_in_slot.freeze:
		var duration = 0.1
		tween.kill()
		tween = create_tween()
		tween.tween_property(item_in_slot, "global_position", global_position, duration)
		tween.tween_property(item_in_slot, "rotation", rotation, duration)
	return
	
	while highlighted and item_in_slot.freeze:
		var item_pos = item_in_slot.position
		var item_rot = item_in_slot.rotation
		var cursor_pos = cursor_body.position
		var delta = get_process_delta_time()
		var pos_speed = 1
		var rot_speed = 2
		item_in_slot.global_position = item_pos.move_toward(global_position, delta * pos_speed)
		item_in_slot.rotation = item_rot.move_toward(rotation, delta * rot_speed)
		await get_tree().process_frame
	print_debug("ended highlight")
	
func reset_highlight():
	highlighted = false
	item_in_slot.freeze = true
	
	var duration = 0.1
	
	tween.kill()
	tween = create_tween()
	tween.tween_property(item_in_slot, "global_position", old_item_position, duration)
	tween.tween_property(item_in_slot, "rotation", old_item_rotation, duration)
