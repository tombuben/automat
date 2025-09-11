class_name RandomItem extends RigidBody3D

var in_slot : ItemSlot

func take_out_of_slot() -> void:
	if in_slot:
		in_slot.item_in_slot = null
		in_slot = null
	freeze = false
	
func insert_to_slot(slot : ItemSlot) -> void:
	in_slot = slot
	freeze = true
	slot.item_in_slot = self
	slot.reset_highlight()
