extends Node


# -----------------------------
# SCENES
# -----------------------------
var scenes: Array = [
	"res://Scenes/main_scene0.tscn",
	"res://Scenes/main_scene1.tscn",
]

func load_into_scene(index : int):
	print("loading into " + scenes[index])
	get_tree().change_scene_to_file(scenes[index])

# -----------------------------
# CHARACTERS
# -----------------------------
var characters: Dictionary = {}

# -----------------------------
# CHARACTER STATES
# -----------------------------
var character_states: Dictionary = {}

func get_state(character_name: String, key: String, default_value = null):
	if not character_states.has(character_name):
		character_states[character_name] = {}
	
	return character_states[character_name].get(key, default_value)

func set_state(character_name: String, key: String, value):
	if not character_states.has(character_name):
		character_states[character_name] = {}
	
	character_states[character_name][key] = value


func has_state(character_name: String, key: String) -> bool:
	return character_states.has(character_name) and character_states[character_name].has(key)


# -----------------------------
# PORTRAITS
# -----------------------------
var character_portraits: Dictionary = {
	"drowning_person": preload("res://portraits/drowning_person.png"),
	"automat": preload("res://portraits/automat.png"),
	"automatSad": preload("res://portraits/automatSad.png"),
	"default": preload("res://portraits/default.png"),
}

signal update_portrait(texture)

func show_portrait(speaker_name: String):
	var portrait = character_portraits.get(speaker_name, null)
	update_portrait.emit(portrait)


# -----------------------------
# EXISTING SYSTEMS
# -----------------------------
var cursor_body : CursorBody

var dispensor_selector : DispenserSelector
var hand_selection_ui : HandSelectionUI
var world_view : WorldView
var rotate_around : RotateAround

var scene_dialogue_manager : SceneDialogueManager
var dialogue_preview : DialoguePreview


# -----------------------------
# SIGNALS
# -----------------------------
signal play_animation(animation_name : String)
var current_animation_length : float

signal person_shoot_selection_started(person_name : String)
var item_that_hit : RandomItem

signal recieve_item(item : String)

# -----------------------------
# ITEM MANAGEMENT
# -----------------------------
var slots : Dictionary[String, ItemSlot] #TODO should clear when level changes

func change_slot_item_name(slot_node_name : String, new_item_name : String):
	if slot_node_name in slots:
		slots[slot_node_name].change_item_name(new_item_name)
	else:
		print("Unknown slot " + slot_node_name + " can't change name to " + new_item_name)
	
func change_slot_item_saying(slot_node_name : String, new_saying : String):
	if slot_node_name in slots:
		slots[slot_node_name].change_item_saying(new_saying)
	else:
		print("Unknown slot " + slot_node_name + " can't change saying to " + new_saying)
