class_name RandomItem extends RigidBody3D

@export var item_name : String
@export var item_type : Array[String]

var in_slot : ItemSlot

func take_out_of_slot() -> void:
	in_slot.slot_occupied = false
	freeze = false
	
func insert_to_slot(slot : ItemSlot) -> void:
	in_slot = slot
	in_slot.slot_occupied = true
	freeze = true
	slot.item_in_slot = self
	slot.reset_highlight()

func return_to_slot() -> void:
	freeze = true
	in_slot.slot_occupied = true
	in_slot.reset_highlight()
