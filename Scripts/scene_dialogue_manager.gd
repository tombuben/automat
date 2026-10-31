class_name SceneDialogueManager extends Node

@export var dialogue_resource : DialogueResource
@export var dialogue_starting_point : String
## When set, the scene runs this chapter and the two fields above are ignored.
@export var chapter : Chapter

var started := false

var encounter_index := -1
var encounter : Encounter
var in_conversation := false
var move_on_after_conversation := false

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

	if chapter:
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
		if chapter.encounters.is_empty():
			push_warning("This chapter has no encounters yet")
			return
		_start_encounter(_first_encounter_index())
		return

	# ▶️ Start dialogue
	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_starting_point)


func show_dialogue(dialogue_entry : String):
	if dialogue_entry not in dialogue_resource.get_titles():
		print("dialogue missing title " + dialogue_entry)
		return
	
	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_entry)


func character_hit(person_name : String, item : RandomItem) -> void:
	if not chapter:
		show_dialogue(person_name + "_hit")
		return

	if in_conversation or encounter == null or encounter.character.id != person_name:
		return

	var reaction := encounter.get_reaction(item.item_name)
	var title := encounter.other_title
	var animation := encounter.other_animation
	if reaction:
		animation = reaction.animation
		if reaction.dialogue_title != "":
			title = reaction.dialogue_title

	if animation != "":
		play(person_name, animation)
	if title != "":
		_say(title)


## The Board's "Play from here" leaves a note saying where to start.
func _first_encounter_index() -> int:
	const PLAY_FROM_FILE := "user://board_play_from.txt"
	if not OS.is_debug_build() or not FileAccess.file_exists(PLAY_FROM_FILE):
		return 0
	var target := FileAccess.get_file_as_string(PLAY_FROM_FILE).strip_edges()
	DirAccess.remove_absolute(PLAY_FROM_FILE)
	for i in chapter.encounters.size():
		if chapter.encounters[i].resource_path.get_file().get_basename() == target:
			return i
	return 0


func _start_encounter(index : int) -> void:
	encounter_index = index
	encounter = chapter.encounters[index]
	if encounter.intro_title != "":
		_say(encounter.intro_title)
	else:
		_apply_previews()


func _apply_previews() -> void:
	var color := chapter.preview_color.to_html(false)
	for reaction in encounter.reactions:
		GlobalManager.set_item_preview(reaction.item, "[color=#%s]%s[/color]" % [color, reaction.preview])


func _say(title : String) -> void:
	in_conversation = true
	DialogueManager.show_dialogue_balloon(encounter.dialogue, title, [self])


func _on_dialogue_ended(_resource : DialogueResource) -> void:
	if not in_conversation:
		return
	in_conversation = false

	if move_on_after_conversation:
		move_on_after_conversation = false
		if encounter_index + 1 < chapter.encounters.size():
			_start_encounter(encounter_index + 1)
			return
		push_error("next_encounter: this is the last encounter in the chapter")
	_apply_previews()


# -----------------------------
# SHORTCUTS FOR .dialogue FILES
# -----------------------------
## Moves to the next encounter in the chapter's list when this conversation ends.
func next_encounter() -> void:
	move_on_after_conversation = true


func play(animation_or_character : String, character_animation : String = "") -> void:
	if character_animation == "":
		GlobalManager.play_animation.emit(animation_or_character)
	else:
		GlobalManager.play_animation.emit(animation_or_character, character_animation)


func play_and_wait(animation_name : String) -> void:
	GlobalManager.play_animation.emit(animation_name)
	await get_tree().create_timer(GlobalManager.current_animation_length).timeout
