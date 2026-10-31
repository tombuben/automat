@tool
extends EditorPlugin

const Board = preload("res://addons/dialogue_board/board.gd")

var board : Control


func _enter_tree() -> void:
	board = Board.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.saved.connect(_on_board_saved)
	board.colors_requested.connect(_on_colors_requested)
	board.open_resource_requested.connect(func(resource): EditorInterface.edit_resource(resource))
	board.play_requested.connect(func(scene_path): EditorInterface.play_custom_scene(scene_path))
	board.import_dialogue = _import_new_file
	EditorInterface.get_editor_main_screen().add_child(board)
	_make_visible(false)


func _exit_tree() -> void:
	if board:
		board.queue_free()


func _has_main_screen() -> bool:
	return true


func _make_visible(visible : bool) -> void:
	if board:
		board.visible = visible


func _get_plugin_name() -> String:
	return "Board"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon("GraphEdit", "EditorIcons")


func _on_colors_requested() -> void:
	EditorInterface.edit_resource(board.colors)


# The game reads the imported copy of a .dialogue file, so it has to be refreshed
func _on_board_saved(dialogue_path : String) -> void:
	EditorInterface.get_resource_filesystem().reimport_files([dialogue_path])


# New files are unknown to the editor until it is told about them
func _import_new_file(path : String) -> void:
	var file_system := EditorInterface.get_resource_filesystem()
	file_system.scan()
	# The import finishes shortly after the scan does
	var give_up_at := Time.get_ticks_msec() + 10000
	while not ResourceLoader.exists(path) and Time.get_ticks_msec() < give_up_at:
		await get_tree().process_frame
