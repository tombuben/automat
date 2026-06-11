extends Node


# -----------------------------
# SCENES
# -----------------------------
var scenes: Array = [
	"res://Scenes/main_scene0.tscn",
	"res://Scenes/SnailScenes/SnailScene1.tscn",
	"res://Scenes/main_scene1.tscn",
	"res://Scenes/main_scene2.tscn",
	
]

func load_into_scene(index: int):
	if index < 0 or index >= scenes.size():
		push_error("Invalid scene index: " + str(index))
		return

	load_scene(scenes[index])


func load_scene(scene_path: String):
	if not ResourceLoader.exists(scene_path):
		push_error("Scene does not exist: " + scene_path)
		return

	print("loading into " + scene_path)
	get_tree().change_scene_to_file(scene_path)

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
# DIALOGUE AUDIO BEEPS
# -----------------------------

var GenericCharacterSounds001 = preload("res://Assets/Audio/SpeakingSFX/GenericCharacterSounds001.wav")
var GenericCharacterSounds002 = preload("res://Assets/Audio/SpeakingSFX/GenericCharacterSounds002.wav")
var GenericCharacterSounds003 = preload("res://Assets/Audio/SpeakingSFX/GenericCharacterSounds003.wav")

var character_beeps: Dictionary[String, Array] = {
	"drowning_person": [GenericCharacterSounds001, GenericCharacterSounds002],
	"hugahugaman": [GenericCharacterSounds001, GenericCharacterSounds002],
	"default": [GenericCharacterSounds001, GenericCharacterSounds002, GenericCharacterSounds003],
}

signal update_audio_beeps(beep_array: Array[AudioStream])

func set_audio_beeps(speaker_name: String):
	var beeps : Array[AudioStream] = []
	beeps.assign(character_beeps.get(speaker_name, null))
	update_audio_beeps.emit(beeps)

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

# GLOBAL INPUT
func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
