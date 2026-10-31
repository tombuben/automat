@tool
extends VBoxContainer
## The Board screen: one character on one graph, reading left to right like a story.
## Previews live in the conversation they trigger. Who comes next is always decided by
## the chapter list in the Inspector: a gold wire only says "this conversation moves on".

signal saved(dialogue_path : String)
signal colors_requested
signal open_resource_requested(resource : Resource)
signal play_requested(scene_path : String)

const BoardSetup = preload("res://addons/dialogue_board/board_setup.gd")
const DEFAULT_CHAPTER := "res://resources/Chapters/office/office_chapter.tres"
const LAST_CHAPTER_SECTION := "board"
const LAYOUT_PATH := "res://addons/dialogue_board/layout.cfg"
const NODE_WIDTH := 820.0
const STAGE_WIDTH := 300.0
const GAP := 140.0
const ITEM_COLUMN := 170.0
const SPEAKER_COLUMN := 185.0
const COLLAPSED_WIDTH := 360.0
const COMPACT_COLUMN := 400.0
const SECTION_FONT_SIZE := 11
const SPOKEN_FONT_SIZE := 16
const SCRIPT_FONT_SIZE := 13
const ANIMATION_COLUMN := 130.0
## Stage box ports, in order.
const PORT_INTRO := 0
const PORT_ITEMS := 1
const PORT_OTHER := 2
const TYPE_DIALOGUE := 0
const TYPE_FLOW := 1
const MENU_CONVERSATION := 0
const MENU_MOVE_ON := 1
const MENU_NEW_STAGE := 2
const COLORS_PATH := "res://addons/dialogue_board/colors.tres"

var colors : BoardColors
var colors_save_queued := false
var chapter : Chapter
var doc : DialogueDoc
## One entry per character: { id, name }
var characters : Array = []
## The open character's stages: { name, source, encounter, is_new }. source is only touched on save.
var stages : Array = []
var open_character_index := -1
var character_id := ""
var dirty := false

var graph : GraphEdit
var picker : OptionButton
var chapter_picker : OptionButton
var chapter_paths : Array = []
## Set by the plugin. Makes a brand-new .dialogue file loadable.
var import_dialogue : Callable = func(_path): pass
var status : Label
var drop_menu : PopupMenu
var menu_from := ""
var menu_position := Vector2.ZERO

var items : Array = []
var speakers : Array = []
var scene_animations : Array = []
var character_animations := {}

var positions := {}
var sizes := {}
## Titles of the conversations shown small.
var collapsed := {}
var conversation_nodes := {}
var rebuild_queued := false
var focus_after_rebuild := ""


func _ready() -> void:
	_load_colors()
	_build_ui()
	_apply_colors()
	_refresh_chapter_list()
	visibility_changed.connect(_on_visibility_changed)
	if chapter_paths.is_empty():
		_set_status("No chapters yet. Click New chapter", colors.status_ok)
		return
	open_chapter(_last_chapter())


func _build_ui() -> void:
	var story_bar := HBoxContainer.new()
	add_child(story_bar)
	story_bar.add_child(_muted_label("Chapter"))
	chapter_picker = OptionButton.new()
	chapter_picker.item_selected.connect(_on_chapter_selected)
	story_bar.add_child(chapter_picker)
	story_bar.add_child(_button("New chapter", _ask_new_chapter))
	story_bar.add_child(_button("Order", _open_order))
	story_bar.add_child(VSeparator.new())
	story_bar.add_child(_muted_label("Character"))
	picker = OptionButton.new()
	picker.item_selected.connect(_on_picker_selected)
	story_bar.add_child(picker)
	story_bar.add_child(_button("+ Character", _ask_new_character))
	story_bar.add_child(_button("+ Stage", func(): if not stages.is_empty(): add_stage()))
	story_bar.add_child(_button("Edit character", func(): if not stages.is_empty(): open_resource_requested.emit(stages[0].source.character)))
	story_bar.add_child(VSeparator.new())
	story_bar.add_child(_button("Save", save))
	story_bar.add_child(_button("Reload", func(): if not characters.is_empty(): open_character(open_character_index)))
	story_bar.add_child(VSeparator.new())
	story_bar.add_child(_button("Play", play_chapter.bind(false)))
	story_bar.add_child(_button("Play from here", play_chapter.bind(true)))
	story_bar.add_child(_button("Check", check_chapter))

	var view_bar := HBoxContainer.new()
	add_child(view_bar)
	view_bar.add_child(_button("Arrange", arrange))
	view_bar.add_child(_button("Collapse all", func(): _set_all_collapsed(true)))
	view_bar.add_child(_button("Expand all", func(): _set_all_collapsed(false)))
	view_bar.add_child(_button("Colors", func(): colors_requested.emit()))
	status = Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.clip_text = true
	view_bar.add_child(status)

	graph = GraphEdit.new()
	graph.size_flags_vertical = Control.SIZE_EXPAND_FILL
	graph.right_disconnects = true
	graph.show_arrange_button = false
	graph.add_valid_connection_type(TYPE_DIALOGUE, TYPE_FLOW)
	graph.connection_request.connect(_on_connection_request)
	graph.disconnection_request.connect(_on_disconnection_request)
	graph.connection_to_empty.connect(_on_connection_to_empty)
	add_child(graph)

	drop_menu = PopupMenu.new()
	drop_menu.id_pressed.connect(_on_menu_pressed)
	add_child(drop_menu)


# =====================================================
# COLORS
# =====================================================
func _load_colors() -> void:
	if ResourceLoader.exists(COLORS_PATH):
		colors = load(COLORS_PATH)
	else:
		colors = BoardColors.new()
		ResourceSaver.save(colors, COLORS_PATH)
		colors.take_over_path(COLORS_PATH)
	colors.changed.connect(_on_colors_changed)


func _on_colors_changed() -> void:
	_apply_colors()
	if chapter:
		_queue_rebuild()
	if not colors_save_queued:
		colors_save_queued = true
		_save_colors.call_deferred()


func _save_colors() -> void:
	colors_save_queued = false
	ResourceSaver.save(colors, COLORS_PATH)


func _apply_colors() -> void:
	var board_theme := Theme.new()
	board_theme.set_stylebox("panel", "GraphEdit", _flat(colors.background))
	board_theme.set_color("grid_major", "GraphEdit", colors.grid_lines)
	board_theme.set_color("grid_minor", "GraphEdit", Color(colors.grid_lines, colors.grid_lines.a * 0.5))
	board_theme.set_color("font_color", "Label", colors.text)
	board_theme.set_color("font_color", "GraphNodeTitleLabel", colors.text)
	board_theme.set_color("font_color", "TextEdit", colors.text)
	board_theme.set_font_size("font_size", "TextEdit", SPOKEN_FONT_SIZE)
	board_theme.set_constant("line_spacing", "TextEdit", 3)
	board_theme.set_constant("separation", "GraphNode", 7)
	board_theme.set_constant("separation", "HBoxContainer", 8)
	board_theme.set_constant("separation", "VBoxContainer", 6)
	board_theme.set_stylebox("normal", "TextEdit", _field_style(false))
	board_theme.set_stylebox("focus", "TextEdit", _field_style(true))
	for type in ["Button", "OptionButton"]:
		board_theme.set_color("font_color", type, colors.text)
		board_theme.set_stylebox("normal", type, _flat(colors.button, 4.0))
		board_theme.set_stylebox("hover", type, _flat(colors.button.lightened(0.12), 4.0))
		board_theme.set_stylebox("pressed", type, _flat(colors.button.darkened(0.15), 4.0))
	graph.theme = board_theme


## Text fields read as plain text, and only show an underline while you type in them.
func _field_style(focused : bool) -> StyleBoxFlat:
	var style := _flat(colors.text_field.lightened(0.05) if focused else colors.text_field)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 5.0
	if focused:
		style.border_width_bottom = 2
		style.border_color = colors.wire
	return style


func _flat(color : Color, margin : float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(margin)
	return style


## Gives a box its background, title bar and selected outline.
func _style_box(node : GraphNode, body : Color, title : Color) -> void:
	var panel := _flat(body, 14.0)
	var selected := panel.duplicate() as StyleBoxFlat
	selected.set_border_width_all(2)
	selected.border_color = colors.selected_outline
	node.add_theme_stylebox_override("panel", panel)
	node.add_theme_stylebox_override("panel_selected", selected)
	node.add_theme_stylebox_override("titlebar", _flat(title, 8.0))
	node.add_theme_stylebox_override("titlebar_selected", _flat(title.lightened(0.1), 8.0))


# =====================================================
# DROPDOWN CONTENTS
# =====================================================
func _load_lists() -> void:
	items = []
	scene_animations = []
	character_animations = {}

	speakers = []
	for file_name in ResourceLoader.list_directory(BoardSetup.CHARACTERS_DIR):
		var data := load(BoardSetup.CHARACTERS_DIR + file_name) as CharacterData
		if data:
			speakers.append(data.id)
	speakers.sort()

	if not ResourceLoader.exists(chapter.scene_path):
		_use_default_items()
		return
	var scene : Node = (ResourceLoader.load(chapter.scene_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	_collect_items(scene)
	if items.is_empty():
		_use_default_items()
	var player := scene.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if player:
		scene_animations = Array(player.get_animation_list())
		scene_animations.sort()
	for id in speakers:
		var names := Array(chapter.get_character_animations(scene, id))
		names.sort()
		character_animations[id] = names
	scene.free()


## The items of this chapter are whatever its scene has in the slots.
func _collect_items(node : Node) -> void:
	var item_name = node.get("item_name")
	if item_name is String and item_name != "" and item_name not in items:
		items.append(item_name)
	for child in node.get_children():
		_collect_items(child)


func _use_default_items() -> void:
	for property in ItemReaction.new().get_property_list():
		if property.name == "item":
			items = Array(property.hint_string.split(","))


func _find_characters() -> void:
	characters = []
	for encounter in chapter.encounters:
		var data : CharacterData = encounter.character
		if not characters.any(func(character): return character.id == data.id):
			characters.append({ id = data.id, name = data.display_name })


## Picks up order changes made in the Inspector, keeping the open character open.
func _sync_with_chapter() -> void:
	_find_characters()
	picker.clear()
	if characters.is_empty():
		_show_empty_chapter()
		return
	var reopen := 0
	for i in characters.size():
		picker.add_item(characters[i].name)
		if characters[i].id == character_id:
			reopen = i
	open_character(reopen)


func _on_visibility_changed() -> void:
	if is_visible_in_tree() and not dirty and chapter:
		_sync_with_chapter()


func _on_chapter_changed() -> void:
	if dirty:
		_set_status("The chapter order changed. Save or Reload to see it here", colors.status_problem)
	else:
		_sync_with_chapter.call_deferred()


func _encounter_name(encounter : Encounter) -> String:
	return encounter.resource_path.get_file().get_basename()


# =====================================================
# CHAPTERS, CHARACTERS AND ORDER
# =====================================================
func _refresh_chapter_list() -> void:
	chapter_paths = BoardSetup.find_chapters()
	chapter_picker.clear()
	for path in chapter_paths:
		chapter_picker.add_item(path.get_file().trim_suffix(BoardSetup.CHAPTER_SUFFIX))
		if chapter and path == chapter.resource_path:
			chapter_picker.select(chapter_picker.item_count - 1)


func _last_chapter() -> String:
	var layout := ConfigFile.new()
	layout.load(LAYOUT_PATH)
	var last : String = layout.get_value(LAST_CHAPTER_SECTION, "chapter", DEFAULT_CHAPTER)
	return last if last in chapter_paths else chapter_paths[0]


func open_chapter(path : String) -> void:
	if chapter and chapter.changed.is_connected(_on_chapter_changed):
		chapter.changed.disconnect(_on_chapter_changed)
	chapter = load(path)
	chapter.changed.connect(_on_chapter_changed)
	character_id = ""
	var layout := ConfigFile.new()
	layout.load(LAYOUT_PATH)
	layout.set_value(LAST_CHAPTER_SECTION, "chapter", path)
	layout.save(LAYOUT_PATH)
	_refresh_chapter_list()
	_load_lists()
	_sync_with_chapter()


func _on_chapter_selected(index : int) -> void:
	if dirty:
		_refresh_chapter_list()
		_set_status("Save or Reload before switching", colors.status_problem)
		return
	open_chapter(chapter_paths[index])


func _show_empty_chapter() -> void:
	stages = []
	doc = null
	dirty = false
	conversation_nodes = {}
	graph.clear_connections()
	for child in graph.get_children():
		if child is GraphNode:
			graph.remove_child(child)
			child.queue_free()
	_set_status("This chapter is empty. Click + Character to start", colors.status_ok)


func _ask(title : String, fields : Array, on_confirm : Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = title
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(420, 0)
	for field in fields:
		box.add_child(field)
	dialog.add_child(box)
	dialog.confirmed.connect(on_confirm)
	dialog.visibility_changed.connect(func(): if not dialog.visible: dialog.queue_free.call_deferred())
	add_child(dialog)
	dialog.popup_centered()
	for field in fields:
		if field is LineEdit:
			field.grab_focus.call_deferred()
			dialog.register_text_enter(field)
			break


func _plain_option(values : Array, labels : Array, selected : String) -> OptionButton:
	var option := OptionButton.new()
	for i in values.size():
		option.add_item(labels[i])
		option.set_item_metadata(i, values[i])
		if values[i] == selected:
			option.select(i)
	return option


func _ask_new_chapter() -> void:
	if dirty:
		_set_status("Save or Reload first", colors.status_problem)
		return
	var name_field := LineEdit.new()
	name_field.placeholder_text = "Chapter name, like Junkyard"
	var scenes := BoardSetup.find_scenes()
	var current_scene := chapter.scene_path if chapter else ""
	var scene := _plain_option(scenes, scenes.map(func(path): return path.get_file()), current_scene)
	var copy := CheckBox.new()
	copy.text = "Make a copy of this scene for the chapter"
	copy.button_pressed = true
	_ask("New chapter", [_label("Name"), name_field, _label("Scene"), scene, copy], func():
		var result := BoardSetup.create_chapter(name_field.text, scene.get_item_metadata(scene.selected), copy.button_pressed)
		if result.error != "":
			_set_status(result.error, colors.status_problem)
			return
		open_chapter(result.path)
		if result.note != "":
			_set_status(result.note, colors.status_problem))


func _ask_new_character() -> void:
	if not chapter:
		_set_status("Create a chapter first", colors.status_problem)
		return
	if dirty:
		_set_status("Save or Reload first", colors.status_problem)
		return
	var name_field := LineEdit.new()
	name_field.placeholder_text = "Name, like Mouse. An existing character can be reused"
	var voices := BoardSetup.find_voices()
	var voice := _plain_option([""] + voices, ["No voice yet"] + voices.map(func(path): return path.get_file()), "")
	_ask("New character", [_label("Name"), name_field, _label("Voice"), voice], func():
		var result : Dictionary = await BoardSetup.create_character(chapter, name_field.text, voice.get_item_metadata(voice.selected), import_dialogue)
		if result.error != "":
			_set_status(result.error, colors.status_problem)
			return
		character_id = result.id
		_load_lists()
		_sync_with_chapter()
		if result.note != "":
			_set_status(result.note, colors.status_problem))


func _open_order() -> void:
	if not chapter:
		return
	if dirty:
		_set_status("Save or Reload before changing the order", colors.status_problem)
		return
	var panel := PopupPanel.new()
	var list := VBoxContainer.new()
	panel.add_child(list)
	add_child(panel)
	panel.popup_hide.connect(panel.queue_free)
	_fill_order(list)
	panel.popup_centered(Vector2i(460, 0))


func _fill_order(list : VBoxContainer) -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	list.add_child(_section_label("WHO COMES AFTER WHOM"))
	for i in chapter.encounters.size():
		var encounter : Encounter = chapter.encounters[i]
		var row := HBoxContainer.new()
		var label := _label("%d.  %s" % [i + 1, _encounter_title(encounter)])
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(_quiet_button("↑", "Earlier", _move_encounter.bind(i, -1, list)))
		row.add_child(_quiet_button("↓", "Later", _move_encounter.bind(i, 1, list)))
		row.add_child(_quiet_button("×", "Remove from this chapter. Its files stay", _remove_encounter.bind(i, list)))
		list.add_child(row)


func _encounter_title(encounter : Encounter) -> String:
	var same : Array = chapter.encounters.filter(func(other): return other.character.id == encounter.character.id)
	if same.size() == 1:
		return encounter.character.display_name
	return "%s, stage %d" % [encounter.character.display_name, same.find(encounter) + 1]


func _move_encounter(index : int, direction : int, list : VBoxContainer) -> void:
	var target := index + direction
	if target < 0 or target >= chapter.encounters.size():
		return
	var order : Array[Encounter] = chapter.encounters.duplicate()
	var moved := order[index]
	order.remove_at(index)
	order.insert(target, moved)
	chapter.encounters = order
	BoardSetup.save_keeping_uid(chapter)
	_fill_order.call_deferred(list)


func _remove_encounter(index : int, list : VBoxContainer) -> void:
	var order : Array[Encounter] = chapter.encounters.duplicate()
	order.remove_at(index)
	chapter.encounters = order
	BoardSetup.save_keeping_uid(chapter)
	_fill_order.call_deferred(list)


# =====================================================
# TESTING
# =====================================================
## Saves, then runs the chapter's scene, optionally from the open character.
func play_chapter(from_here : bool) -> void:
	if not chapter:
		return
	if dirty:
		save()
	if dirty:
		return
	if from_here and not stages.is_empty():
		var note := FileAccess.open(BoardSetup.PLAY_FROM_FILE, FileAccess.WRITE)
		note.store_string(stages[0].name)
		note.close()
	else:
		DirAccess.remove_absolute(BoardSetup.PLAY_FROM_FILE)
	play_requested.emit(chapter.scene_path)


func check_chapter() -> void:
	if not chapter:
		return
	var problems : Array = chapter.check_for_mistakes()
	if problems.is_empty():
		_set_status("No mistakes found", colors.status_ok)
	else:
		_set_status("%d to fix: %s" % [problems.size(), problems[0]] + (" (rest in Output)" if problems.size() > 1 else ""), colors.status_problem)


# =====================================================
# OPEN / SAVE
# =====================================================
func _on_picker_selected(index : int) -> void:
	if dirty:
		picker.select(open_character_index)
		_set_status("Save or Reload before switching", colors.status_problem)
		return
	open_character(index)


func open_character(index : int) -> void:
	open_character_index = index
	picker.select(index)
	character_id = characters[index].id
	stages = []
	for source in chapter.encounters:
		if source.character.id == character_id:
			stages.append({ name = _encounter_name(source), source = source, encounter = source.duplicate(true), is_new = false })
	doc = DialogueDoc.load_file(stages[0].source.dialogue.resource_path)
	dirty = false
	_load_layout()
	_build_graph()
	graph.set_deferred("scroll_offset", Vector2(-40, -40))


func _open_character_id(id : String) -> void:
	if dirty:
		_set_status("Save or Reload before switching", colors.status_problem)
		return
	for i in characters.size():
		if characters[i].id == id:
			open_character(i)
			return


func save() -> void:
	if not doc:
		return
	_read_layout()
	var result := doc.save()
	var chapter_changed := false
	for stage in stages:
		if result != OK:
			break
		var source : Encounter = stage.source
		source.intro_title = stage.encounter.intro_title
		source.other_title = stage.encounter.other_title
		source.other_animation = stage.encounter.other_animation
		source.reactions = stage.encounter.reactions
		var path := _stage_path(stage)
		# ResourceSaver can drop the file's uid, and other files refer to it
		var uid := ResourceLoader.get_resource_uid(path)
		result = ResourceSaver.save(source, path)
		if result == OK and uid != ResourceUID.INVALID_ID:
			ResourceSaver.set_uid(path, uid)
		if stage.is_new and result == OK:
			source.take_over_path(path)
			_insert_in_chapter(source)
			stage.is_new = false
			chapter_changed = true
	if result == OK and chapter_changed:
		var chapter_uid := ResourceLoader.get_resource_uid(chapter.resource_path)
		result = ResourceSaver.save(chapter, chapter.resource_path)
		if result == OK and chapter_uid != ResourceUID.INVALID_ID:
			ResourceSaver.set_uid(chapter.resource_path, chapter_uid)
	if result != OK:
		_set_status("Could not save: " + error_string(result), colors.status_problem)
		return
	_save_layout()
	saved.emit(doc.path)
	open_character(open_character_index)
	if status.text.begins_with("OK"):
		_set_status("Saved", colors.status_ok)


func _stage_path(stage : Dictionary) -> String:
	return chapter.resource_path.get_base_dir().path_join(stage.name + ".tres")


## New stages go right after this character's last one.
func _insert_in_chapter(source : Encounter) -> void:
	var at := chapter.encounters.size()
	for i in chapter.encounters.size():
		if chapter.encounters[i].character.id == character_id:
			at = i + 1
	chapter.encounters.insert(at, source)


func add_stage() -> Dictionary:
	var number := stages.size() + 1
	var new_name := "%s_stage_%d" % [character_id, number]
	while ResourceLoader.exists(chapter.resource_path.get_base_dir().path_join(new_name + ".tres")):
		number += 1
		new_name = "%s_stage_%d" % [character_id, number]
	var source := Encounter.new()
	source.character = stages[0].source.character
	source.dialogue = stages[0].source.dialogue
	var stage := { name = new_name, source = source, encounter = source.duplicate(true), is_new = true }
	stages.append(stage)
	_mark_dirty()
	_queue_rebuild()
	return stage


func arrange() -> void:
	if not doc:
		return
	positions = {}
	sizes = {}
	conversation_nodes = {}
	for child in graph.get_children():
		if child is GraphNode:
			graph.remove_child(child)
			child.queue_free()
	_build_graph()
	graph.set_deferred("scroll_offset", Vector2(-40, -40))
	_mark_dirty()


func _load_layout() -> void:
	positions = {}
	sizes = {}
	collapsed = {}
	var layout := ConfigFile.new()
	if layout.load(LAYOUT_PATH) != OK or not layout.has_section(doc.path):
		return
	for key in layout.get_section_keys(doc.path):
		if key.begins_with("collapsed_"):
			collapsed[key.trim_prefix("collapsed_")] = true
		elif key.begins_with("size_"):
			sizes[key.trim_prefix("size_")] = layout.get_value(doc.path, key)
		else:
			positions[key] = layout.get_value(doc.path, key)


func _save_layout() -> void:
	var layout := ConfigFile.new()
	layout.load(LAYOUT_PATH)
	if layout.has_section(doc.path):
		layout.erase_section(doc.path)
	for key in positions:
		layout.set_value(doc.path, key, positions[key])
	for key in sizes:
		layout.set_value(doc.path, "size_" + key, sizes[key])
	for key in collapsed:
		layout.set_value(doc.path, "collapsed_" + key, true)
	layout.save(LAYOUT_PATH)


func _read_layout() -> void:
	if not doc:
		return
	for child in graph.get_children():
		if child is GraphNode:
			positions[String(child.name)] = child.position_offset


# =====================================================
# DRAWING THE GRAPH
# =====================================================
func _queue_rebuild() -> void:
	if rebuild_queued:
		return
	rebuild_queued = true
	_build_graph.call_deferred()


func _build_graph() -> void:
	rebuild_queued = false
	_read_layout()
	graph.clear_connections()
	for child in graph.get_children():
		if child is GraphNode:
			graph.remove_child(child)
			child.queue_free()
	conversation_nodes = {}

	_place_defaults()
	for stage in stages:
		_add_node(_build_stage_node(stage))
	for conversation in doc.conversations:
		var node := _build_conversation_node(conversation)
		_add_node(node)
		conversation_nodes[conversation.title] = node
	for stage in stages:
		var next = _next_encounter(stage)
		if next != null and next.character.id != character_id:
			_add_node(_build_flow_box(_next_box_name(stage), "NEXT: " + next.character.display_name, next.character.id, true))
		var previous = _previous_encounter(stage)
		if previous != null and previous.character.id != character_id:
			_add_node(_build_flow_box(_from_box_name(stage), "COMES AFTER: " + previous.character.display_name, previous.character.id, false))

	_draw_connections()
	_refresh_status()
	_fit_nodes_to_content()
	if focus_after_rebuild != "" and conversation_nodes.has(focus_after_rebuild):
		var node : GraphNode = conversation_nodes[focus_after_rebuild]
		_focus_text(node)
	focus_after_rebuild = ""


## Wrapping text only knows its real height once the box has its width, and a
## GraphNode never shrinks by itself, so every box is fitted after the first layout.
func _fit_nodes_to_content() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for child in graph.get_children():
		if child is GraphNode and is_instance_valid(child):
			child.size.y = 0


func _add_node(node : GraphNode) -> void:
	var key := String(node.name)
	if positions.has(key):
		node.position_offset = positions[key]
	if sizes.has(key) and not collapsed.has(key):
		node.custom_minimum_size.x = maxf(node.custom_minimum_size.x, sizes[key].x)
	node.resizable = true
	node.resize_request.connect(func(new_size):
		node.custom_minimum_size.x = new_size.x
		node.size = new_size
		if not collapsed.has(key):
			sizes[key] = new_size
		_mark_dirty())
	graph.add_child(node)


## Story order, left to right: a stage, then its conversations in columns, then the next stage.
func _place_defaults() -> void:
	var column_width := _column_width()
	var x := 0.0
	for stage in stages:
		var previous = _previous_encounter(stage)
		if previous != null and previous.character.id != character_id:
			if not positions.has(_from_box_name(stage)):
				positions[_from_box_name(stage)] = Vector2(x, 0)
			x += STAGE_WIDTH + GAP
		if not positions.has(_stage_key(stage)):
			positions[_stage_key(stage)] = Vector2(x, 0)
		var column_y := {}
		var columns := 0
		var queue := []
		for title in _stage_titles(stage.encounter):
			queue.append([title, 0])
		var first_column := x + STAGE_WIDTH + GAP
		while not queue.is_empty():
			var entry : Array = queue.pop_front()
			var conversation = doc.get_conversation(entry[0])
			if conversation == null:
				continue
			columns = maxi(columns, entry[1] + 1)
			queue.append([conversation.exit, entry[1] + 1])
			for row in conversation.rows:
				if row.kind == "shared":
					queue.append([row.title, entry[1] + 1])
			if positions.has(entry[0]):
				continue
			var y : float = column_y.get(entry[1], 0.0)
			positions[entry[0]] = Vector2(first_column + entry[1] * (column_width + GAP), y)
			column_y[entry[1]] = y + _estimated_height(conversation)
		x = first_column + columns * (column_width + GAP)
		var next = _next_encounter(stage)
		if next != null and next.character.id != character_id:
			if not positions.has(_next_box_name(stage)):
				positions[_next_box_name(stage)] = Vector2(x, 0)
			x += STAGE_WIDTH + GAP
	var loose_y := 0.0
	for conversation in doc.conversations:
		if not positions.has(conversation.title):
			positions[conversation.title] = Vector2(x, loose_y)
			loose_y += _estimated_height(conversation)


## Columns tighten up when every conversation is collapsed.
func _column_width() -> float:
	for conversation in doc.conversations:
		if not collapsed.has(conversation.title):
			return NODE_WIDTH
	return COMPACT_COLUMN


func _estimated_height(conversation : Dictionary) -> float:
	if collapsed.has(conversation.title):
		return 110.0
	var height : float = 190.0 + 60.0 * conversation.rows.size()
	for stage in stages:
		for reaction in stage.encounter.reactions:
			if reaction.dialogue_title == conversation.title:
				height += 44.0
	return height + 40.0


func _stage_key(stage : Dictionary) -> String:
	return "stage_" + stage.name


func _stage_named(key : String) -> Variant:
	for stage in stages:
		if _stage_key(stage) == key:
			return stage
	return null


func _stage_label(stage : Dictionary) -> String:
	return "Stage %d" % (stages.find(stage) + 1)


func _draw_connections() -> void:
	graph.clear_connections()
	for stage in stages:
		var key := _stage_key(stage)
		var encounter : Encounter = stage.encounter
		if conversation_nodes.has(encounter.intro_title):
			graph.connect_node(key, PORT_INTRO, encounter.intro_title, 0)
		var wired := {}
		for reaction in encounter.reactions:
			if conversation_nodes.has(reaction.dialogue_title) and not wired.has(reaction.dialogue_title):
				wired[reaction.dialogue_title] = true
				graph.connect_node(key, PORT_ITEMS, reaction.dialogue_title, 0)
		if conversation_nodes.has(encounter.other_title):
			graph.connect_node(key, PORT_OTHER, encounter.other_title, 0)
	for title in conversation_nodes:
		var conversation = doc.get_conversation(title)
		if conversation_nodes.has(conversation.exit):
			graph.connect_node(title, 0, conversation.exit, 0)
		if conversation.moves_on:
			for stage in _stages_reaching(title):
				var target := _next_node_name(stage)
				if target != "":
					graph.connect_node(title, 0, target, 0)
	for stage in stages:
		var previous = _previous_encounter(stage)
		if previous != null and previous.character.id != character_id:
			graph.connect_node(_from_box_name(stage), 0, _stage_key(stage), 0)
	_refresh_endings()


## The stages from which this conversation can play.
func _stages_reaching(title : String) -> Array:
	var reaching := []
	for stage in stages:
		var queue := _stage_titles(stage.encounter)
		var seen := {}
		while not queue.is_empty():
			var current : String = queue.pop_front()
			if seen.has(current):
				continue
			seen[current] = true
			var conversation = doc.get_conversation(current)
			if conversation == null:
				continue
			queue.append(conversation.exit)
			for row in conversation.rows:
				if row.kind == "shared":
					queue.append(row.title)
		if seen.has(title):
			reaching.append(stage)
	return reaching


## Encounters in play order, the way the chapter list will have them after saving.
func _play_order() -> Array:
	var order : Array = chapter.encounters.duplicate()
	var at := 0
	for i in order.size():
		if order[i].character.id == character_id:
			at = i + 1
	for stage in stages:
		if stage.is_new:
			order.insert(at, stage.source)
			at += 1
	return order


func _next_encounter(stage : Dictionary) -> Variant:
	var order := _play_order()
	var index := order.find(stage.source)
	return order[index + 1] if index + 1 < order.size() else null


func _previous_encounter(stage : Dictionary) -> Variant:
	var order := _play_order()
	var index := order.find(stage.source)
	return order[index - 1] if index > 0 else null


func _next_box_name(stage : Dictionary) -> String:
	return "next_" + stage.name


func _from_box_name(stage : Dictionary) -> String:
	return "from_" + stage.name


## The node a stage's gold wire ends on. Empty for the last encounter in the chapter.
func _next_node_name(stage : Dictionary) -> String:
	var next = _next_encounter(stage)
	if next == null:
		return ""
	for other in stages:
		if other.source == next:
			return _stage_key(other)
	return _next_box_name(stage)


func _next_label(stage : Dictionary) -> String:
	var next = _next_encounter(stage)
	if next == null:
		return "nothing, this is the last in the chapter"
	if next.character.id == character_id:
		for other in stages:
			if other.source == next:
				return _stage_label(other).to_lower()
	return next.character.display_name


## Every conversation a stage starts directly.
func _stage_titles(encounter : Encounter) -> Array:
	var titles := []
	for title in [encounter.intro_title] + encounter.reactions.map(func(reaction): return reaction.dialogue_title) + [encounter.other_title]:
		if title != "" and title not in titles:
			titles.append(title)
	return titles


func _build_flow_box(node_name : String, text : String, other_character : String, is_target : bool) -> GraphNode:
	var node := GraphNode.new()
	node.name = node_name
	node.title = text
	node.custom_minimum_size.x = STAGE_WIDTH
	_style_box(node, colors.next_box, colors.next_title)
	node.add_child(_button("Open", _open_character_id.bind(other_character)))
	if is_target:
		node.set_slot(0, true, TYPE_FLOW, colors.flow, false, 0, colors.flow)
	else:
		node.set_slot(0, false, 0, colors.flow, true, TYPE_FLOW, colors.flow)
	return node


func _build_stage_node(stage : Dictionary) -> GraphNode:
	var node := GraphNode.new()
	node.name = _stage_key(stage)
	var encounter : Encounter = stage.encounter
	node.title = "%s, stage %d" % [encounter.character.display_name, stages.find(stage) + 1]
	node.custom_minimum_size.x = STAGE_WIDTH
	_style_box(node, colors.stage_box, colors.stage_title)
	node.add_child(_port_label("When they appear"))
	node.add_child(_port_label("Item choices"))
	node.add_child(_port_label("Any other item"))
	node.set_slot(PORT_INTRO, true, TYPE_FLOW, colors.flow, true, TYPE_DIALOGUE, colors.wire)
	node.set_slot(PORT_ITEMS, false, 0, colors.wire, true, TYPE_DIALOGUE, colors.wire)
	node.set_slot(PORT_OTHER, false, 0, colors.wire, true, TYPE_DIALOGUE, colors.wire)
	return node


func _port_label(text : String) -> Label:
	var label := _label(text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return label


func _build_conversation_node(conversation : Dictionary) -> GraphNode:
	var node := GraphNode.new()
	node.name = conversation.title
	node.title = _conversation_heading(conversation)
	node.tooltip_text = "Title in the file: " + conversation.title
	node.custom_minimum_size.x = NODE_WIDTH
	_style_box(node, colors.conversation_box, colors.conversation_title)
	var titlebar := node.get_titlebar_hbox()
	var collapse_button := _quiet_button("▾", "Collapse or expand", _toggle_collapsed.bind(conversation.title))
	collapse_button.name = "CollapseButton"
	titlebar.add_child(collapse_button)
	titlebar.add_child(_quiet_button("✎", "Rename this window", _start_rename.bind(conversation, node)))
	titlebar.add_child(_quiet_button("×", "Delete this conversation", _delete_conversation.bind(conversation.title)))
	node.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.double_click and event.position.y < titlebar.size.y:
			_start_rename(conversation, node))

	var start_label := _section_label("DIALOGUE START")
	start_label.name = "StartLabel"
	start_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.add_child(start_label)
	for stage in stages:
		_add_start_rows(node, stage, conversation)
	node.add_child(HSeparator.new())
	node.set_meta("first_row", node.get_child_count())
	for row in conversation.rows:
		node.add_child(_build_row(conversation, row))
	_refresh_speaker_labels(conversation, node)

	var buttons := HBoxContainer.new()
	var add_line := _button("+ Line", _add_row.bind(conversation, "line"))
	add_line.tooltip_text = "Or press Enter in a line"
	buttons.add_child(add_line)
	buttons.add_child(_quiet_button("+ Animation", "", _add_row.bind(conversation, "action")))
	buttons.add_child(_quiet_button("+ Wait", "", _add_row.bind(conversation, "wait")))
	buttons.add_child(_quiet_button("+ Load scene", "Ends the chapter by going to a scene", _add_row.bind(conversation, "load_scene")))
	buttons.add_child(_quiet_button("+ Script", "", _add_row.bind(conversation, "raw")))
	node.add_child(buttons)

	var ending := _label("")
	ending.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ending.name = "Ending"
	node.add_child(ending)
	_set_conversation_slots(node)
	_apply_collapsed(conversation, node)
	return node


## What starts this conversation, written above its lines so it reads like a script.
func _add_start_rows(node : GraphNode, stage : Dictionary, conversation : Dictionary) -> void:
	var encounter : Encounter = stage.encounter
	var prefix := _stage_label(stage) + ": " if stages.size() > 1 else ""
	if encounter.intro_title == conversation.title:
		node.add_child(_muted_label(prefix + "When they appear"))
	var has_items := false
	for reaction in encounter.reactions:
		if reaction.dialogue_title == conversation.title:
			has_items = true
			node.add_child(_build_item_row(stage, reaction, prefix))
	if has_items:
		var add_item := _quiet_button(prefix + "+ Item", "Another item that starts this conversation", _add_reaction.bind(stage, conversation))
		add_item.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		node.add_child(add_item)
	if encounter.other_title == conversation.title:
		var other := HBoxContainer.new()
		var label := _muted_label(prefix + "Any other item, on hit:")
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		other.add_child(label)
		var animation := _option(_with_none(character_animations.get(character_id, [])), encounter.other_animation, func(value):
			encounter.other_animation = value
			_mark_dirty())
		animation.custom_minimum_size.x = ANIMATION_COLUMN
		other.add_child(animation)
		node.add_child(other)


func _build_item_row(stage : Dictionary, reaction : ItemReaction, prefix : String) -> VBoxContainer:
	var column := VBoxContainer.new()
	var row := HBoxContainer.new()
	column.add_child(row)
	var encounter : Encounter = stage.encounter
	if prefix != "":
		row.add_child(_muted_label(prefix.trim_suffix(": ")))
	var free_items := items.filter(func(item): return item == reaction.item or not _item_used(encounter, item))
	var item := _option(free_items, reaction.item, func(value):
		reaction.item = value
		_mark_dirty()
		_queue_rebuild())
	item.custom_minimum_size.x = ITEM_COLUMN
	row.add_child(item)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(_muted_label("ON HIT"))
	var animation := _animation_option(character_animations.get(character_id, []), reaction.animation, func(value):
		reaction.animation = value
		_mark_dirty())
	row.add_child(animation)
	row.add_child(_quiet_button("×", "Remove this item", func():
		encounter.reactions.erase(reaction)
		_mark_dirty()
		_queue_rebuild()))

	var preview_row := HBoxContainer.new()
	preview_row.add_child(_section_label("PREVIEW"))
	var preview := _text_box(reaction.preview, "What the automat says on hover", func(value):
		reaction.preview = value
		_mark_dirty())
	preview.add_theme_color_override("font_color", colors.preview_text)
	preview_row.add_child(preview)
	column.add_child(preview_row)
	return column


## GraphNode slots belong to child positions, so they move when rows are added.
func _set_conversation_slots(node : GraphNode) -> void:
	node.clear_all_slots()
	if collapsed.has(String(node.name)):
		# Only one row is visible, so it carries both wires
		node.set_slot(0, true, TYPE_DIALOGUE, colors.wire, true, TYPE_DIALOGUE, colors.flow)
		return
	node.set_slot(0, true, TYPE_DIALOGUE, colors.wire, false, 0, colors.wire)
	node.set_slot(node.get_child_count() - 1, false, 0, colors.wire, true, TYPE_DIALOGUE, colors.flow)


func _refresh_endings() -> void:
	for title in conversation_nodes:
		var conversation = doc.get_conversation(title)
		var ending := conversation_nodes[title].get_node("Ending") as Label
		if conversation.moves_on:
			var reaching := _stages_reaching(title)
			ending.text = "Then, NEXT: " + (_next_label(reaching[0]) if not reaching.is_empty() else "whatever follows its stage")
			ending.add_theme_color_override("font_color", colors.flow)
		elif doc.get_conversation(conversation.exit) != null:
			ending.text = "Then: continues"
			ending.remove_theme_color_override("font_color")
		else:
			ending.text = "Then: back to choosing items (drag from here to continue)"
			ending.remove_theme_color_override("font_color")
		_update_collapsed_summary(conversation, conversation_nodes[title])


func _build_row(conversation : Dictionary, data : Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	match data.kind:
		"line":
			var animation_holder := HBoxContainer.new()
			var speaker := _quiet_option(speakers, data.speaker, func(value):
				data.speaker = value
				data.anim = ""
				_mark_dirty()
				_fill_line_animations(animation_holder, data)
				_update_heading(conversation)
				_refresh_speaker_labels(conversation))
			speaker.custom_minimum_size.x = SPEAKER_COLUMN
			speaker.name = "Speaker"
			row.add_child(speaker)
			var text := _text_box(data.text, "What they say", func(value):
				data.text = value
				_mark_dirty()
				_update_heading(conversation), _insert_line_after.bind(conversation, data))
			if data.get("tint", "") != "":
				text.add_theme_color_override("font_color", Color.html(data.tint))
			row.add_child(text)
			_fill_line_animations(animation_holder, data)
			row.add_child(animation_holder)
		"action":
			row.add_child(_action_label("Play"))
			var animation := _quiet_option(scene_animations, data.anim, func(value):
				data.anim = value
				_mark_dirty(), colors.action_text)
			animation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(animation)
			var wait := CheckBox.new()
			wait.text = "Wait to finish"
			wait.add_theme_color_override("font_color", colors.muted_text)
			wait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			wait.tooltip_text = "Wait for the animation to finish before continuing"
			wait.button_pressed = data.wait
			wait.toggled.connect(func(value):
				data.wait = value
				_mark_dirty())
			row.add_child(wait)
		"character_action":
			row.add_child(_action_label("Play"))
			var anim_holder := HBoxContainer.new()
			var target := _quiet_option(speakers, data.target, func(value):
				data.target = value
				_mark_dirty()
				_fill_character_action(anim_holder, data), colors.action_text)
			target.custom_minimum_size.x = SPEAKER_COLUMN
			row.add_child(target)
			_fill_character_action(anim_holder, data)
			anim_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(anim_holder)
		"wait":
			row.add_child(_action_label("Wait"))
			var seconds := SpinBox.new()
			seconds.min_value = 0.0
			seconds.max_value = 600.0
			seconds.step = 0.1
			seconds.suffix = "s"
			seconds.value = float(data.seconds)
			seconds.custom_minimum_size.x = 110
			seconds.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			seconds.value_changed.connect(func(value):
				data.seconds = String.num(value, 2)
				_mark_dirty())
			row.add_child(seconds)
			var wait_spacer := Control.new()
			wait_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(wait_spacer)
		"load_scene":
			row.add_child(_action_label("Load scene"))
			var scene_option := _quiet_option(BoardSetup.find_scenes(), data.path, func(value):
				data.path = value
				_mark_dirty(), colors.action_text)
			scene_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(scene_option)
		"shared":
			row.add_child(_action_label("Also plays"))
			var shared := _quiet_option(doc.conversations.map(func(c): return c.title), data.title, func(value):
				data.title = value
				_mark_dirty()
				_update_heading(conversation), colors.action_text)
			shared.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(shared)
		_:
			var script_text := _text_box(data.text, "Dialogue script, kept as written", func(value):
				data.text = value
				_mark_dirty(), _insert_line_after.bind(conversation, data))
			script_text.add_theme_color_override("font_color", colors.script_text)
			script_text.add_theme_font_size_override("font_size", SCRIPT_FONT_SIZE)
			row.add_child(script_text)

	row.add_child(_quiet_button("↑", "Move up", _move_row.bind(conversation, data, row, -1)))
	row.add_child(_quiet_button("↓", "Move down", _move_row.bind(conversation, data, row, 1)))
	row.add_child(_quiet_button("×", "Remove", _remove_row.bind(conversation, data, row)))
	return row


func _fill_line_animations(holder : HBoxContainer, data : Dictionary) -> void:
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	holder.add_child(_animation_option(character_animations.get(data.speaker, []), data.anim, func(value):
		data.anim = value
		_mark_dirty()))


func _fill_character_action(holder : HBoxContainer, data : Dictionary) -> void:
	for child in holder.get_children():
		holder.remove_child(child)
		child.queue_free()
	var option := _quiet_option(character_animations.get(data.target, []), data.anim, func(value):
		data.anim = value
		_mark_dirty(), colors.action_text)
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.add_child(option)


## Like a script: the name is only strong when the speaker changes.
func _refresh_speaker_labels(conversation : Dictionary, node : GraphNode = null) -> void:
	if node == null:
		node = conversation_nodes.get(conversation.title)
	if node == null:
		return
	var previous := ""
	var first_row : int = node.get_meta("first_row")
	for i in conversation.rows.size():
		var data : Dictionary = conversation.rows[i]
		if data.kind != "line":
			previous = ""
			continue
		var speaker := node.get_child(first_row + i).get_node_or_null("Speaker") as Control
		if speaker:
			speaker.modulate.a = 0.45 if data.speaker == previous else 1.0
		previous = data.speaker


func _conversation_heading(conversation : Dictionary) -> String:
	if conversation.label != "":
		return conversation.label
	for row in conversation.rows:
		if row.kind == "line" and row.text != "":
			return "%s: %s" % [row.speaker, row.text.left(48)]
	for row in conversation.rows:
		if row.kind == "shared":
			return "Plays " + row.title
	return "New conversation"


func _update_heading(conversation : Dictionary) -> void:
	if conversation_nodes.has(conversation.title):
		conversation_nodes[conversation.title].title = _conversation_heading(conversation)


# =====================================================
# RENAMING AND COLLAPSING
# =====================================================
## Swaps the title for a text field. Enter or clicking away keeps the name; empty goes back to the first line.
func _start_rename(conversation : Dictionary, node : GraphNode) -> void:
	var titlebar := node.get_titlebar_hbox()
	if titlebar.has_node("RenameField"):
		return
	var field := LineEdit.new()
	field.name = "RenameField"
	field.text = conversation.label
	field.placeholder_text = "Name this window"
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.title = ""
	titlebar.add_child(field)
	titlebar.move_child(field, 0)
	var finish := func():
		if not is_instance_valid(field):
			return
		_rename_conversation(conversation, field.text)
		titlebar.remove_child(field)
		field.queue_free()
	field.text_submitted.connect(func(_text): finish.call())
	field.focus_exited.connect(func(): finish.call_deferred())
	field.grab_focus.call_deferred()
	field.select_all.call_deferred()


func _rename_conversation(conversation : Dictionary, new_label : String) -> void:
	var clean := new_label.strip_edges()
	if clean != conversation.label:
		conversation.label = clean
		_mark_dirty()
	_update_heading(conversation)


func _toggle_collapsed(title : String) -> void:
	_read_layout()
	if collapsed.has(title):
		collapsed.erase(title)
	else:
		collapsed[title] = true
	_save_layout()
	_refresh_collapsed(doc.get_conversation(title))
	_draw_connections()


func _set_all_collapsed(value : bool) -> void:
	if not doc:
		return
	_read_layout()
	for conversation in doc.conversations:
		if value:
			collapsed[conversation.title] = true
		else:
			collapsed.erase(conversation.title)
	_save_layout()
	for conversation in doc.conversations:
		_refresh_collapsed(conversation)
	_draw_connections()


func _refresh_collapsed(conversation : Dictionary) -> void:
	var node : GraphNode = conversation_nodes[conversation.title]
	_apply_collapsed(conversation, node)
	_set_conversation_slots(node)


func _apply_collapsed(conversation : Dictionary, node : GraphNode) -> void:
	var is_collapsed := collapsed.has(conversation.title)
	for i in node.get_child_count():
		node.get_child(i).visible = i == 0 or not is_collapsed
	(node.get_titlebar_hbox().get_node("CollapseButton") as Button).text = "▸" if is_collapsed else "▾"
	var width := NODE_WIDTH
	if is_collapsed:
		width = COLLAPSED_WIDTH
	elif sizes.has(conversation.title):
		width = maxf(width, sizes[conversation.title].x)
	node.custom_minimum_size.x = width
	node.size = Vector2(width, 0)
	_update_collapsed_summary(conversation, node)
	if is_collapsed:
		_set_conversation_slots(node)


## What a collapsed window still tells you: its items, its length, where it goes.
func _update_collapsed_summary(conversation : Dictionary, node : GraphNode) -> void:
	var start_label := node.get_node("StartLabel") as Label
	if not collapsed.has(conversation.title):
		start_label.text = "DIALOGUE START"
		return
	var starts := []
	for stage in stages:
		if stage.encounter.intro_title == conversation.title:
			starts.append("appears")
		if stage.encounter.other_title == conversation.title and "any other item" not in starts:
			starts.append("any other item")
		for reaction in stage.encounter.reactions:
			if reaction.dialogue_title == conversation.title and reaction.item not in starts:
				starts.append(reaction.item)
	var lines : int = conversation.rows.filter(func(row): return row.kind == "line").size()
	var parts : Array = [", ".join(starts)] if not starts.is_empty() else []
	parts.append("1 line" if lines == 1 else "%d lines" % lines)
	if conversation.moves_on:
		var reaching := _stages_reaching(conversation.title)
		parts.append("NEXT: " + (_next_label(reaching[0]) if not reaching.is_empty() else "follows its stage"))
	elif doc.get_conversation(conversation.exit) != null:
		parts.append("continues")
	start_label.text = "  ·  ".join(parts)


# =====================================================
# EDITING LINES (only touches the one row, so it is instant)
# =====================================================
func _item_used(encounter : Encounter, item : String) -> bool:
	for reaction in encounter.reactions:
		if reaction.item == item:
			return true
	return false


func _row_index(conversation : Dictionary, data : Dictionary) -> int:
	for i in conversation.rows.size():
		if is_same(conversation.rows[i], data):
			return i
	return -1


func _insert_row(conversation : Dictionary, data : Dictionary, at : int) -> Control:
	conversation.rows.insert(at, data)
	var row := _build_row(conversation, data)
	var node : GraphNode = conversation_nodes[conversation.title]
	node.add_child(row)
	node.move_child(row, node.get_meta("first_row") + at)
	_set_conversation_slots(node)
	_refresh_speaker_labels(conversation, node)
	_mark_dirty()
	return row


func _add_row(conversation : Dictionary, kind : String) -> void:
	var data : Dictionary
	match kind:
		"line":
			data = { kind = "line", speaker = _last_speaker(conversation), text = "", anim = "", tint = "" }
		"wait":
			data = { kind = "wait", seconds = "1" }
		"load_scene":
			data = { kind = "load_scene", path = _first_other_scene() }
		"action":
			data = { kind = "action", anim = scene_animations[0] if not scene_animations.is_empty() else "", wait = false }
		_:
			data = { kind = "raw", text = "" }
	_focus_text(_insert_row(conversation, data, conversation.rows.size()))


func _insert_line_after(conversation : Dictionary, data : Dictionary) -> void:
	var line := { kind = "line", speaker = data.get("speaker", _last_speaker(conversation)), text = "", anim = "", tint = data.get("tint", "") }
	_focus_text(_insert_row(conversation, line, _row_index(conversation, data) + 1))


func _first_other_scene() -> String:
	for path in BoardSetup.find_scenes():
		if path != chapter.scene_path:
			return path
	return chapter.scene_path


func _last_speaker(conversation : Dictionary) -> String:
	for i in range(conversation.rows.size() - 1, -1, -1):
		if conversation.rows[i].kind == "line":
			return conversation.rows[i].speaker
	return character_id


func _focus_text(parent : Node) -> void:
	for child in parent.get_children():
		if child is TextEdit:
			child.grab_focus.call_deferred()
			return
		_focus_text(child)


func _move_row(conversation : Dictionary, data : Dictionary, row : Control, direction : int) -> void:
	var index := _row_index(conversation, data)
	var target := index + direction
	if target < 0 or target >= conversation.rows.size():
		return
	conversation.rows.remove_at(index)
	conversation.rows.insert(target, data)
	var node : GraphNode = conversation_nodes[conversation.title]
	node.move_child(row, node.get_meta("first_row") + target)
	_mark_dirty()
	_refresh_speaker_labels(conversation, node)
	_update_heading(conversation)


func _remove_row(conversation : Dictionary, data : Dictionary, row : Control) -> void:
	conversation.rows.remove_at(_row_index(conversation, data))
	var node : GraphNode = conversation_nodes[conversation.title]
	node.remove_child(row)
	row.queue_free()
	_set_conversation_slots(node)
	_refresh_speaker_labels(conversation, node)
	node.size.y = 0
	_mark_dirty()
	_update_heading(conversation)


# =====================================================
# EDITING WIRES
# =====================================================
func _add_reaction(stage : Dictionary, conversation : Dictionary) -> bool:
	for item in items:
		if not _item_used(stage.encounter, item):
			var reaction := ItemReaction.new()
			reaction.item = item
			reaction.dialogue_title = conversation.title
			stage.encounter.reactions.append(reaction)
			_mark_dirty()
			_queue_rebuild()
			return true
	_set_status("Every item already has a conversation in this stage", colors.status_problem)
	return false


func _delete_conversation(title : String) -> void:
	for stage in stages:
		var encounter : Encounter = stage.encounter
		if encounter.intro_title == title:
			encounter.intro_title = ""
		if encounter.other_title == title:
			encounter.other_title = ""
		var kept : Array[ItemReaction] = []
		for reaction in encounter.reactions:
			if reaction.dialogue_title != title:
				kept.append(reaction)
		encounter.reactions = kept
	for conversation in doc.conversations:
		if conversation.exit == title:
			conversation.exit = DialogueDoc.END_JUMP
		conversation.rows = conversation.rows.filter(func(row): return row.kind != "shared" or row.title != title)
	doc.conversations.erase(doc.get_conversation(title))
	positions.erase(title)
	sizes.erase(title)
	_mark_dirty()
	_queue_rebuild()


## Points a stage port or a conversation's ending at a conversation. Empty title clears it.
func _set_target(from_node : String, from_port : int, title : String) -> void:
	var stage = _stage_named(from_node)
	if stage == null:
		var conversation = doc.get_conversation(from_node)
		conversation.exit = title if title != "" else DialogueDoc.END_JUMP
		if title != "":
			conversation.moves_on = false
		_mark_dirty()
		return
	var encounter : Encounter = stage.encounter
	match from_port:
		PORT_INTRO:
			encounter.intro_title = title
		PORT_OTHER:
			encounter.other_title = title
		PORT_ITEMS:
			if title != "":
				_add_reaction(stage, doc.get_conversation(title))
	_mark_dirty()


func _set_moves_on(from_title : String, value : bool) -> void:
	var conversation = doc.get_conversation(from_title)
	conversation.moves_on = value
	if value:
		conversation.exit = DialogueDoc.END_JUMP
	_mark_dirty()
	_queue_rebuild()


func _on_connection_request(from_node : StringName, from_port : int, to_node : StringName, _to_port : int) -> void:
	var from := String(from_node)
	var to := String(to_node)
	if conversation_nodes.has(to):
		_set_target(from, from_port, to)
		_queue_rebuild()
		return
	if not conversation_nodes.has(from):
		_set_status("A gold wire starts from the end of a conversation", colors.status_problem)
		return
	_set_moves_on(from, true)


func _on_disconnection_request(from_node : StringName, from_port : int, to_node : StringName, _to_port : int) -> void:
	var from := String(from_node)
	var to := String(to_node)
	if not conversation_nodes.has(to):
		if conversation_nodes.has(from):
			_set_moves_on(from, false)
		return
	var stage = _stage_named(from)
	if stage and from_port == PORT_ITEMS:
		var kept : Array[ItemReaction] = []
		for reaction in stage.encounter.reactions:
			if reaction.dialogue_title != to:
				kept.append(reaction)
		stage.encounter.reactions = kept
		_mark_dirty()
	else:
		_set_target(from, from_port, "")
	_queue_rebuild()


## Dropping a wire on empty space: a stage always wants a new conversation, while the
## end of a conversation can also move the story on.
func _on_connection_to_empty(from_node : StringName, from_port : int, release_position : Vector2) -> void:
	var from := String(from_node)
	var graph_position := (release_position + graph.scroll_offset) / graph.zoom
	var stage = _stage_named(from)
	if stage:
		_create_conversation_from(from, from_port, graph_position)
		return
	if not conversation_nodes.has(from):
		return
	menu_from = from
	menu_position = graph_position
	drop_menu.clear()
	drop_menu.add_item("New conversation", MENU_CONVERSATION)
	drop_menu.add_item("Move on to what comes next", MENU_MOVE_ON)
	drop_menu.add_item("Move on to a new stage of this character", MENU_NEW_STAGE)
	drop_menu.popup(Rect2i(Vector2i(graph.get_screen_position() + release_position), Vector2i.ZERO))


func _on_menu_pressed(id : int) -> void:
	if id == MENU_CONVERSATION:
		_create_conversation_from(menu_from, 0, menu_position)
	elif id == MENU_MOVE_ON:
		_set_moves_on(menu_from, true)
	elif id == MENU_NEW_STAGE:
		var stage := add_stage()
		positions[_stage_key(stage)] = menu_position
		_set_moves_on(menu_from, true)


func _create_conversation_from(from : String, from_port : int, at : Vector2) -> void:
	var stage = _stage_named(from)
	var base := "conversation"
	if stage and from_port == PORT_INTRO:
		base = "intro"
	var conversation := doc.add_conversation(base)
	conversation.rows.append({ kind = "line", speaker = character_id, text = "", anim = "", tint = "" })
	positions[conversation.title] = at
	focus_after_rebuild = conversation.title
	_set_target(from, from_port, conversation.title)
	_queue_rebuild()


# =====================================================
# STATUS
# =====================================================
func _mark_dirty() -> void:
	dirty = true
	_refresh_status()


func _problems() -> Array:
	var problems := []
	if character_animations.get(character_id, []).is_empty():
		problems.append("%s is not in the scene, or their prefab has no animations" % character_id)
	var wired := {}
	for stage in stages:
		var encounter : Encounter = stage.encounter
		for title in _stage_titles(encounter):
			wired[title] = true
		for reaction in encounter.reactions:
			if reaction.preview.strip_edges() == "":
				problems.append("%s in %s has no preview" % [reaction.item, _stage_label(stage).to_lower()])
	for conversation in doc.conversations:
		wired[conversation.exit] = true
		for row in conversation.rows:
			if row.kind == "shared":
				wired[row.title] = true
		if conversation.moves_on:
			for stage in _stages_reaching(conversation.title):
				if _next_encounter(stage) == null:
					problems.append("\"%s\" moves on, but %s" % [_conversation_heading(conversation), _next_label(stage)])
	for conversation in doc.conversations:
		var heading := _conversation_heading(conversation)
		if conversation.rows.is_empty():
			problems.append("an empty conversation")
		if not wired.has(conversation.title):
			problems.append("\"%s\" is not wired to anything" % heading)
		for row in conversation.rows:
			if row.kind == "line" and row.text.strip_edges() == "":
				problems.append("an empty line in \"%s\"" % heading)
	return problems


func _refresh_status() -> void:
	if not doc:
		return
	var problems := _problems()
	var prefix := "Unsaved. " if dirty else ""
	if problems.is_empty():
		_set_status(prefix + "OK", colors.status_ok)
	else:
		_set_status(prefix + "Check: " + ", ".join(problems), colors.status_problem)


func _set_status(text : String, color : Color) -> void:
	status.text = text
	status.add_theme_color_override("font_color", color)


# =====================================================
# SMALL UI HELPERS
# =====================================================
func _label(text : String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _muted_label(text : String) -> Label:
	var label := _label(text)
	label.add_theme_color_override("font_color", colors.muted_text)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _section_label(text : String) -> Label:
	var label := _muted_label(text)
	label.add_theme_font_size_override("font_size", SECTION_FONT_SIZE)
	return label


func _action_label(text : String) -> Label:
	var label := _label(text)
	label.add_theme_color_override("font_color", colors.action_text)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.custom_minimum_size.x = 72
	return label


## For everything that should stay out of the way until you need it.
func _quiet_button(text : String, tooltip : String, on_pressed : Callable) -> Button:
	var button := _button(text, on_pressed)
	button.flat = true
	button.tooltip_text = tooltip
	button.add_theme_color_override("font_color", colors.muted_text)
	button.add_theme_color_override("font_hover_color", colors.text)
	return button


func _quiet_option(values : Array, current : String, on_pick : Callable, color : Variant = null) -> OptionButton:
	var option := _option(values, current, on_pick)
	option.flat = true
	if current in values:
		var font_color : Color = color if color != null else colors.muted_text
		option.add_theme_color_override("font_color", font_color)
		option.add_theme_color_override("font_hover_color", colors.text)
		option.add_theme_color_override("font_pressed_color", colors.text)
	return option


## Quiet while empty, and stands out once an animation is chosen.
func _animation_option(values : Array, current : String, on_pick : Callable) -> OptionButton:
	var option : OptionButton
	option = _quiet_option(_with_none(values), current, func(value):
		option.add_theme_color_override("font_color", colors.accent_text if value != "" else colors.muted_text)
		on_pick.call(value), colors.accent_text if current != "" else colors.muted_text)
	option.custom_minimum_size.x = ANIMATION_COLUMN
	return option


func _button(text : String, on_pressed : Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(on_pressed)
	return button


func _with_none(values : Array) -> Array:
	return [""] + values


## A text box that wraps and grows as you type. A dialogue line stays one line in the
## file, so Enter runs on_enter (usually: start the next line) instead of breaking it.
func _text_box(text : String, placeholder : String, on_change : Callable, on_enter : Callable = Callable()) -> TextEdit:
	var box := TextEdit.new()
	box.text = text
	box.placeholder_text = placeholder
	box.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.scroll_fit_content_height = true
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.custom_minimum_size.x = 120
	box.text_changed.connect(func():
		if "\n" in box.text:
			box.text = box.text.replace("\n", " ")
			box.set_caret_column(box.text.length())
		on_change.call(box.text))
	box.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			box.accept_event()
			if on_enter.is_valid():
				on_enter.call())
	return box


## A dropdown of values. A saved value missing from the list stays selected and is marked.
func _option(values : Array, current : String, on_pick : Callable) -> OptionButton:
	var option := OptionButton.new()
	option.fit_to_longest_item = false
	option.clip_text = true
	option.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for value in values:
		option.add_item(value if value != "" else "no animation")
		option.set_item_metadata(option.item_count - 1, value)
		if value == current:
			option.select(option.item_count - 1)
	if current not in values:
		option.add_item(current + " (missing!)")
		option.set_item_metadata(option.item_count - 1, current)
		option.select(option.item_count - 1)
		option.add_theme_color_override("font_color", colors.status_problem)
	option.item_selected.connect(func(index): on_pick.call(option.get_item_metadata(index)))
	return option
