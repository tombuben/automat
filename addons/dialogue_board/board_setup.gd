@tool
extends RefCounted
## Creates the files behind a chapter or character, so nobody has to make them by hand.

const CHAPTERS_DIR := "res://resources/Chapters/"
const DIALOGUES_DIR := "res://resources/Dialogues/"
const CHARACTERS_DIR := "res://resources/Characters/"
const PREFABS_DIR := "res://Prefabs/NPCs/"
const BASE_PREFAB := "res://Prefabs/random_person.tscn"
const SCENES_DIR := "res://Scenes/"
const VOICES_DIR := "res://Assets/Audio/SpeakingSFX/"
const CHAPTER_SUFFIX := "_chapter.tres"
## Tells the game which encounter to start from when testing. Read once, then deleted.
const PLAY_FROM_FILE := "user://board_play_from.txt"


static func slug(text : String) -> String:
	var cleaned := RegEx.create_from_string("[^a-z0-9]+").sub(text.strip_edges().to_lower(), "_", true)
	return cleaned.trim_prefix("_").trim_suffix("_")


static func find_chapters() -> Array:
	var found := _find_files("res://resources/", CHAPTER_SUFFIX)
	found.sort()
	return found


static func _find_files(folder : String, extension : String) -> Array:
	var found := []
	for file_name in DirAccess.get_files_at(folder):
		if file_name.ends_with(extension):
			found.append(folder + file_name)
	for child in DirAccess.get_directories_at(folder):
		found.append_array(_find_files(folder + child + "/", extension))
	found.sort()
	return found


static func find_scenes() -> Array:
	# The dialogue balloon lives in Scenes too, but nobody plays it as a level
	return _find_files(SCENES_DIR, ".tscn").filter(func(path): return not path.contains("/DialogueBubble/"))


static func find_voices() -> Array:
	return _find_files(VOICES_DIR, ".wav")


# =====================================================
# CHAPTERS
# =====================================================
## Returns { path, error, note }. error is empty when it worked.
static func create_chapter(display_name : String, template_scene : String, make_copy : bool) -> Dictionary:
	var id := slug(display_name)
	if id == "":
		return { error = "Give the chapter a name" }
	var folder := CHAPTERS_DIR + id + "/"
	var path := folder + id + CHAPTER_SUFFIX
	if FileAccess.file_exists(path):
		return { error = "A chapter called %s already exists" % id }

	var scene_path := template_scene
	if make_copy:
		scene_path = SCENES_DIR + id + ".tscn"
		if FileAccess.file_exists(scene_path):
			return { error = "A scene called %s.tscn already exists" % id }
		var text := FileAccess.get_file_as_string(template_scene)
		# The copy needs its own identity, Godot gives it a new uid
		text = RegEx.create_from_string(" uid=\"uid://[a-z0-9]+\"(?=\\]\\n)").sub(text, "")
		_write(scene_path, text)

	DirAccess.make_dir_recursive_absolute(folder)
	var chapter := Chapter.new()
	chapter.scene_path = scene_path
	var result := ResourceSaver.save(chapter, path)
	if result != OK:
		return { error = "Could not save the chapter: " + error_string(result) }

	var note := ""
	if not attach_chapter_to_scene(scene_path, path):
		note = "Set Chapter on the scene's dialogue manager node yourself"
	return { path = path, error = "", note = note }


## Points the scene's SceneDialogueManager at this chapter.
static func attach_chapter_to_scene(scene_path : String, chapter_path : String) -> bool:
	var text := FileAccess.get_file_as_string(scene_path)
	var script_line := RegEx.create_from_string("\\[ext_resource [^\\]]*path=\"res://[^\"]*scene_dialogue_manager\\.gd\" id=\"([^\"]+)\"\\]").search(text)
	if script_line == null:
		return false
	var script_id := script_line.get_string(1)
	var node_regex := RegEx.create_from_string("script = ExtResource\\(\"%s\"\\)\\n((?:[a-z_]+ = [^\\n]*\\n)*)" % script_id)
	var node := node_regex.search(text)
	if node == null:
		return false
	# The old chapter or dialogue is no longer used by this node
	for old in RegEx.create_from_string("(?:chapter|dialogue_resource) = ExtResource\\(\"([^\"]+)\"\\)").search_all(node.get_string(1)):
		text = RegEx.create_from_string("\\[ext_resource [^\\]]*id=\"%s\"\\]\\n" % old.get_string(1)).sub(text, "")
	node = node_regex.search(text)
	var kept := ""
	for line in node.get_string(1).split("\n", false):
		if not (line.begins_with("chapter = ") or line.begins_with("dialogue_resource = ") or line.begins_with("dialogue_starting_point = ")):
			kept += line + "\n"
	text = text.replace(node.get_string(0), "script = ExtResource(\"%s\")\n%schapter = ExtResource(\"board_chapter\")\n" % [script_id, kept])
	_write(scene_path, _add_ext_resource(text, "[ext_resource type=\"Resource\" path=\"%s\" id=\"board_chapter\"]\n" % chapter_path))
	return true


# =====================================================
# CHARACTERS
# =====================================================
## Makes everything a character needs and adds them to the end of the chapter.
## Returns { id, error, note }. import_dialogue must make a new .dialogue file loadable.
static func create_character(chapter : Chapter, display_name : String, voice_path : String, import_dialogue : Callable) -> Dictionary:
	var id := slug(display_name)
	if id == "":
		return { error = "Give the character a name" }
	for encounter in chapter.encounters:
		if encounter.character.id == id:
			return { error = "%s is already in this chapter" % display_name }

	var data_path := CHARACTERS_DIR + id + ".tres"
	var data : CharacterData
	if ResourceLoader.exists(data_path):
		data = load(data_path)
	else:
		data = CharacterData.new()
		data.id = id
		data.display_name = display_name.strip_edges()
		if voice_path != "":
			data.voice_sounds.append(load(voice_path))
		ResourceSaver.save(data, data_path)
		data.take_over_path(data_path)

	var prefab_path := PREFABS_DIR + id + ".tscn"
	if not FileAccess.file_exists(prefab_path):
		_write(prefab_path, _prefab_text(id, data_path))

	var chapter_folder := chapter.resource_path.get_base_dir()
	var dialogue_folder := DIALOGUES_DIR + chapter_folder.get_file() + "/"
	DirAccess.make_dir_recursive_absolute(dialogue_folder)
	var dialogue_path := dialogue_folder + id + ".dialogue"
	if not FileAccess.file_exists(dialogue_path):
		_write(dialogue_path, "~ intro\n%s: ...\n=> END\n" % id)
	await import_dialogue.call(dialogue_path)
	if not ResourceLoader.exists(dialogue_path):
		return { error = "Godot has not imported %s yet. Click back into the editor and try again" % dialogue_path }

	var encounter := Encounter.new()
	encounter.character = data
	encounter.dialogue = load(dialogue_path)
	encounter.intro_title = "intro"
	var encounter_path := chapter_folder.path_join(id + ".tres")
	var result := ResourceSaver.save(encounter, encounter_path)
	if result != OK:
		return { error = "Could not save the encounter: " + error_string(result) }
	encounter.take_over_path(encounter_path)

	var order : Array[Encounter] = chapter.encounters.duplicate()
	order.append(encounter)
	chapter.encounters = order
	save_keeping_uid(chapter)

	var note := ""
	if not add_to_scene(chapter.scene_path, id, prefab_path):
		note = "Could not place %s in the scene, drag their prefab in yourself" % id
	return { id = id, error = "", note = note }


static func _prefab_text(id : String, data_path : String) -> String:
	return """[gd_scene format=3]

[ext_resource type="PackedScene" path="%s" id="1_base"]
[ext_resource type="Resource" path="%s" id="2_data"]

[sub_resource type="SpriteFrames" id="SpriteFrames_board"]
animations = [{
"frames": [],
"loop": true,
"name": &"hit",
"speed": 5.0
}, {
"frames": [],
"loop": true,
"name": &"idle",
"speed": 5.0
}]

[node name="%s" instance=ExtResource("1_base")]
person_name = "%s"
character = ExtResource("2_data")

[node name="AnimatedSprite3D" type="AnimatedSprite3D" parent="RigidBody3D"]
sprite_frames = SubResource("SpriteFrames_board")
animation = &"idle"
autoplay = "idle"
""" % [BASE_PREFAB, data_path, id, id]


## Adds the prefab next to the scene's other characters, unless it is there already.
static func add_to_scene(scene_path : String, id : String, prefab_path : String) -> bool:
	if not FileAccess.file_exists(scene_path):
		return false
	var text := FileAccess.get_file_as_string(scene_path)
	if RegEx.create_from_string("(?i)\\[node name=\"%s\"" % id).search(text):
		return true
	var holder := RegEx.create_from_string("\\[node name=\"Characters\"[^\\]]* parent=\"([^\"]+)\"").search(text)
	if holder == null:
		return false
	var parent := "Characters" if holder.get_string(1) == "." else holder.get_string(1) + "/Characters"
	var resource_id := "board_" + id
	text = _add_ext_resource(text, "[ext_resource type=\"PackedScene\" path=\"%s\" id=\"%s\"]\n" % [prefab_path, resource_id])
	var node := "[node name=\"%s\" parent=\"%s\" instance=ExtResource(\"%s\")]\n\n" % [id, parent, resource_id]
	var connections := text.find("[connection ")
	text = text.insert(connections, node) if connections != -1 else text.trim_suffix("\n") + "\n\n" + node
	_write(scene_path, text)
	return true


# =====================================================
# HELPERS
# =====================================================
## ResourceSaver can drop a file's uid, and other files refer to it.
static func save_keeping_uid(resource : Resource) -> Error:
	var path := resource.resource_path
	var uid := ResourceLoader.get_resource_uid(path)
	var result := ResourceSaver.save(resource, path)
	if result == OK and uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid(path, uid)
	return result


static func _add_ext_resource(text : String, line : String) -> String:
	var last := -1
	for found in RegEx.create_from_string("(?m)^\\[ext_resource [^\\n]*\\n").search_all(text):
		last = found.get_end()
	if last == -1:
		last = text.find("\n\n") + 2
	return text.insert(last, line)


static func _write(path : String, text : String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
