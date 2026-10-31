@tool
class_name Chapter extends Resource
## The encounters of a scene, in play order. Drag to reorder.

@export var encounters : Array[Encounter]
@export var preview_color : Color = Color("1bffc2")
## The scene this chapter runs in. Used to check animation names.
@export_file("*.tscn") var scene_path : String
@export_tool_button("Check for mistakes") var check_button = check_for_mistakes


func check_for_mistakes() -> Array[String]:
	var problems : Array[String] = []
	var scene : Node = load(scene_path).instantiate() if ResourceLoader.exists(scene_path) else null
	if scene == null:
		problems.append("Chapter: scene_path is not set, skipping animation checks")

	var checked_files := {}
	for i in encounters.size():
		var encounter := encounters[i]
		var label := "Encounter %d (%s)" % [i + 1, encounter.resource_path.get_file()]
		if encounter.character == null or encounter.dialogue == null:
			problems.append("%s: character or dialogue is empty" % label)
			continue

		var titles := encounter.dialogue.get_titles()
		var used_items := {}
		_check_title(encounter.intro_title, titles, label + " intro", problems)
		_check_title(encounter.other_title, titles, label + " any other item", problems)
		_check_animation(scene, encounter.character.id, encounter.other_animation, label, problems)
		for reaction in encounter.reactions:
			var row := "%s, %s" % [label, reaction.item]
			if used_items.has(reaction.item):
				problems.append("%s: this item is in the table twice" % row)
			used_items[reaction.item] = true
			_check_title(reaction.dialogue_title, titles, row, problems)
			_check_animation(scene, encounter.character.id, reaction.animation, row, problems)
			if reaction.dialogue_title == "" and encounter.other_title == "":
				problems.append("%s: no dialogue_title and no 'any other item' title" % row)
			if reaction.next_encounter and i == encounters.size() - 1:
				problems.append("%s: next_encounter is on, but this is the last encounter" % row)

		var path := encounter.dialogue.resource_path
		if not checked_files.has(path):
			checked_files[path] = true
			_check_dialogue_file(path, scene, problems)

	if scene:
		scene.free()

	if problems.is_empty():
		print("Chapter check: no mistakes found")
	for problem in problems:
		push_warning("Chapter check: " + problem)
	return problems


func _check_title(title : String, titles : PackedStringArray, label : String, problems : Array[String]) -> void:
	if title != "" and title not in titles:
		problems.append("%s: dialogue title '%s' does not exist" % [label, title])


func _check_dialogue_file(path : String, scene : Node, problems : Array[String]) -> void:
	var label := path.get_file()
	var lines := FileAccess.get_file_as_string(path).split("\n")
	var speaker_regex := RegEx.create_from_string("^\\s*([A-Za-z_0-9]+):\\s")
	var tag_regex := RegEx.create_from_string("\\[#anim=([A-Za-z_0-9]+)\\]")
	var play_regex := RegEx.create_from_string("^\\s*do play(?:_and_wait)?\\(\"([^\"]+)\"(?:, \"([^\"]+)\")?\\)")
	var character_ids := {}
	for file_name in ResourceLoader.list_directory("res://Characters/"):
		character_ids[(load("res://Characters/" + file_name) as CharacterData).id] = true

	for i in lines.size():
		var row := "%s line %d" % [label, i + 1]
		var play := play_regex.search(lines[i])
		if play:
			if play.get_string(2) != "":
				_check_animation(scene, play.get_string(1), play.get_string(2), row, problems)
			elif scene and not (scene.get_node("AnimationPlayer") as AnimationPlayer).has_animation(play.get_string(1)):
				problems.append("%s: scene has no animation '%s'" % [row, play.get_string(1)])
			continue
		var speaker := speaker_regex.search(lines[i])
		if speaker and speaker.get_string(1) != "else":
			if not character_ids.has(speaker.get_string(1)):
				problems.append("%s: unknown speaker '%s'" % [row, speaker.get_string(1)])
			var tag := tag_regex.search(lines[i])
			if tag:
				_check_animation(scene, speaker.get_string(1), tag.get_string(1), row, problems)


func _check_animation(scene : Node, character_id : String, animation : String, label : String, problems : Array[String]) -> void:
	if scene == null or animation == "":
		return
	var person := _find_person(scene, character_id)
	if person == null:
		problems.append("%s: scene has no character '%s'" % [label, character_id])
		return
	var player := person.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var sprite := person.find_child("AnimatedSprite3D", true, false) as AnimatedSprite3D
	var found := player != null and player.has_animation(animation)
	found = found or (sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation))
	if not found:
		problems.append("%s: '%s' has no animation '%s'" % [label, character_id, animation])


func _find_person(node : Node, character_id : String) -> Node:
	# Scripts like random_person.gd don't run in the editor, so the name counts too
	var data = node.get("character")
	if (data is CharacterData and data.id == character_id) or String(node.name).to_lower() == character_id:
		return node
	for child in node.get_children():
		var found := _find_person(child, character_id)
		if found:
			return found
	return null
