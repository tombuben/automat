class_name SceneDialogueManager extends Node

@export var dialogue_resource : DialogueResource
@export var dialogue_starting_point : String

var started := false

func _ready() -> void:
	print("SceneDialogueManager START:", self)

	# 🧨 Prevent double start on same instance
	if started:
		return
	started = true

	# 🔥 Kill any previous manager
	if GlobalManager.scene_dialogue_manager and GlobalManager.scene_dialogue_manager != self:
		print("KILLING OLD MANAGER:", GlobalManager.scene_dialogue_manager)
		GlobalManager.scene_dialogue_manager.queue_free()

	# ✅ Register this one as the active manager
	GlobalManager.scene_dialogue_manager = self

	# ▶️ Start dialogue
	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_starting_point)


func show_dialogue(dialogue_entry : String):
	if dialogue_entry not in dialogue_resource.get_titles():
		print("dialogue missing title " + dialogue_entry)
		return
	
	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_entry)
