class_name SceneDialogueManager extends Node

@export var dialogue_resource : DialogueResource
@export var dialogue_starting_point : String

func _ready() -> void:
	GlobalManager.scene_dialogue_manager = self
	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_starting_point)
	
func show_dialogue(dialogue_entry : String):
	if dialogue_entry not in dialogue_resource.get_titles():
		print("dialogue missing title " + dialogue_entry)
	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_entry)
	
