@tool
class_name BoardColors extends Resource
## Every color on the Board. Saved as colors.tres, changes show up immediately.

@export_group("Wires")
## Wires that start a conversation.
@export var wire := Color("1bffc2"):
	set(value):
		wire = value
		emit_changed()
## Gold wires and labels: the story moving on.
@export var flow := Color("ffc14d"):
	set(value):
		flow = value
		emit_changed()

@export_group("Boxes")
@export var conversation_box := Color("232529"):
	set(value):
		conversation_box = value
		emit_changed()
@export var conversation_title := Color("3d3d3d"):
	set(value):
		conversation_title = value
		emit_changed()
@export var stage_box := Color("1f1f1f"):
	set(value):
		stage_box = value
		emit_changed()
@export var stage_title := Color("3d3d3d"):
	set(value):
		stage_title = value
		emit_changed()
## The NEXT and COMES AFTER boxes.
@export var next_box := Color("1f1f1f"):
	set(value):
		next_box = value
		emit_changed()
@export var next_title := Color("3d3d3d"):
	set(value):
		next_title = value
		emit_changed()
## Outline of the selected box.
@export var selected_outline := Color("ffffff"):
	set(value):
		selected_outline = value
		emit_changed()

@export_group("Text")
## What characters say, the most important text on the Board.
@export var text := Color("f2f2f2"):
	set(value):
		text = value
		emit_changed()
## Labels, speakers, row buttons: everything that should step back.
@export var muted_text := Color("8a8f98"):
	set(value):
		muted_text = value
		emit_changed()
## An animation that is set on a line.
@export var accent_text := Color("ff9ecb"):
	set(value):
		accent_text = value
		emit_changed()
## Rows that play an animation or wait.
@export var action_text := Color("8fb8ff"):
	set(value):
		action_text = value
		emit_changed()
@export var preview_text := Color("1bffc2"):
	set(value):
		preview_text = value
		emit_changed()
## Yellow rows of dialogue script.
@export var script_text := Color("bfbf8c"):
	set(value):
		script_text = value
		emit_changed()

@export_group("Fields")
## Behind the text you type.
@export var text_field := Color("1b1d20"):
	set(value):
		text_field = value
		emit_changed()
## Dropdowns and buttons.
@export var button := Color("3a3a3a"):
	set(value):
		button = value
		emit_changed()

@export_group("Background")
@export var background := Color("2c2c2c"):
	set(value):
		background = value
		emit_changed()
@export var grid_lines := Color(1, 1, 1, 0.07):
	set(value):
		grid_lines = value
		emit_changed()

@export_group("Status")
@export var status_ok := Color(0.6, 0.9, 0.65):
	set(value):
		status_ok = value
		emit_changed()
@export var status_problem := Color(1.0, 0.45, 0.4):
	set(value):
		status_problem = value
		emit_changed()

@export_tool_button("Reset to defaults") var reset_button = reset


func reset() -> void:
	var defaults := (get_script() as GDScript).new() as BoardColors
	for property in get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and typeof(get(property.name)) == TYPE_COLOR:
			set(property.name, defaults.get(property.name))
