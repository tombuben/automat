@tool
class_name Encounter extends Resource
## One stage of talking to a character. The item table in here replaces
## change_slot_item_* calls and the if/elif chains on item_that_hit.

@export var character : CharacterData
@export var dialogue : DialogueResource
## Title played when the encounter starts. Empty = no intro.
@export var intro_title : String
@export var reactions : Array[ItemReaction]

@export_group("Any other item")
@export var other_title : String
@export var other_animation : String = "hit"


func get_reaction(item_name : String) -> ItemReaction:
	for reaction in reactions:
		if reaction.item == item_name:
			return reaction
	return null
