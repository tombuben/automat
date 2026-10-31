@tool
class_name DialogueDoc extends RefCounted
## Reads a .dialogue file into conversations and writes it back.
##
## Each conversation is { title, rows, exit }. A row is one of:
##   { kind = "line", speaker, text, anim }   disposable_worker: Hello [#anim=grin]
##   { kind = "action", anim, wait }          do play_and_wait("small_worker_leave")
##   { kind = "character_action", target, anim }   do play("printer", "sad")
##   { kind = "wait", seconds }               do wait(3)
##   { kind = "load_scene", path }            do GlobalManager.load_scene("res://Scenes/x.tscn")
##   { kind = "shared", title }               =>< small_cups
##   { kind = "raw", text }                   anything else, kept exactly as written
## exit is what follows the last row: "END", "END!", a title, or "" for no jump.
## moves_on is true when the chapter moves to its next encounter afterwards.
## label is the name given to the window on the Board, stored as a "# label:" comment.

const END_JUMP := "END"
const LABEL_PREFIX := "# label: "

var path : String
var header : PackedStringArray = []
var conversations : Array = []

static var _line_regex := RegEx.create_from_string("^(\\w+): (.*?)(?:\\s*\\[#anim=(\\w+)\\])?\\s*$")
static var _action_regex := RegEx.create_from_string("^do play(_and_wait)?\\(\"([^\"]+)\"\\)\\s*$")
static var _character_action_regex := RegEx.create_from_string("^do play\\(\"([^\"]+)\", \"([^\"]+)\"\\)\\s*$")
static var _wait_regex := RegEx.create_from_string("^do wait\\(([0-9.]+)\\)\\s*$")
static var _tint_regex := RegEx.create_from_string("^\\[color=(#[0-9a-fA-F]+)\\]((?:(?!\\[/?color).)*)\\[/color\\]$")
static var _load_scene_regex := RegEx.create_from_string("^do GlobalManager\\.load_scene\\(\"([^\"]+)\"\\)\\s*$")
static var _shared_regex := RegEx.create_from_string("^=>< (\\S+)\\s*$")
static var _exit_regex := RegEx.create_from_string("^=> (\\S+)\\s*$")
static var _moves_on_regex := RegEx.create_from_string("^do next_encounter\\(\\)\\s*$")


static func load_file(file_path : String) -> DialogueDoc:
	var doc := DialogueDoc.new()
	doc.path = file_path
	doc.parse(FileAccess.get_file_as_string(file_path))
	return doc


func parse(text : String) -> void:
	header = []
	conversations = []
	var body : PackedStringArray = []
	var title := ""
	for raw_line in text.split("\n"):
		var line := raw_line.trim_suffix("\r")
		if line.begins_with("~ "):
			if title != "":
				conversations.append(_parse_conversation(title, body))
			title = line.trim_prefix("~ ").strip_edges()
			body = []
		elif line.strip_edges() == "":
			continue
		elif title == "":
			header.append(line)
		else:
			body.append(line)
	if title != "":
		conversations.append(_parse_conversation(title, body))


func _parse_conversation(title : String, body : PackedStringArray) -> Dictionary:
	var label := ""
	if body.size() > 0 and body[0].begins_with(LABEL_PREFIX):
		label = body[0].trim_prefix(LABEL_PREFIX).strip_edges()
		body = body.slice(1)
	var exit := ""
	var count := body.size()
	if count > 0:
		var jump := _exit_regex.search(body[count - 1])
		if jump:
			exit = jump.get_string(1)
			count -= 1
	var moves_on := false
	if count > 0 and _moves_on_regex.search(body[count - 1]):
		moves_on = true
		count -= 1
	var rows := []
	for i in count:
		rows.append(_parse_row(body[i]))
	return { title = title, label = label, rows = rows, exit = exit, moves_on = moves_on }


func _parse_row(line : String) -> Dictionary:
	var action := _action_regex.search(line)
	if action:
		return { kind = "action", anim = action.get_string(2), wait = action.get_string(1) != "" }
	var character_action := _character_action_regex.search(line)
	if character_action:
		return { kind = "character_action", target = character_action.get_string(1), anim = character_action.get_string(2) }
	var load_scene := _load_scene_regex.search(line)
	if load_scene:
		return { kind = "load_scene", path = load_scene.get_string(1) }
	var wait := _wait_regex.search(line)
	if wait:
		return { kind = "wait", seconds = wait.get_string(1) }
	var shared := _shared_regex.search(line)
	if shared:
		return { kind = "shared", title = shared.get_string(1) }
	var spoken := _line_regex.search(line)
	if spoken:
		var row := { kind = "line", speaker = spoken.get_string(1), text = spoken.get_string(2), anim = spoken.get_string(3), tint = "" }
		# A whole line in one color is shown in that color, without the tags
		var tinted := _tint_regex.search(row.text)
		if tinted:
			row.tint = tinted.get_string(1)
			row.text = tinted.get_string(2)
		return row
	return { kind = "raw", text = line }


func to_text() -> String:
	var out : PackedStringArray = []
	if not header.is_empty():
		out.append("\n".join(header))
	for conversation in conversations:
		var lines : PackedStringArray = ["~ " + conversation.title]
		if conversation.label != "":
			lines.append(LABEL_PREFIX + conversation.label)
		for row in conversation.rows:
			lines.append(_row_to_text(row))
		if conversation.moves_on:
			lines.append("do next_encounter()")
		if conversation.exit != "":
			lines.append("=> " + conversation.exit)
		out.append("\n".join(lines))
	return "\n\n".join(out) + "\n"


func _row_to_text(row : Dictionary) -> String:
	match row.kind:
		"line":
			var tag : String = " [#anim=%s]" % row.anim if row.anim != "" else ""
			var spoken_text : String = row.text
			if row.get("tint", "") != "":
				spoken_text = "[color=%s]%s[/color]" % [row.tint, row.text]
			return "%s: %s%s" % [row.speaker, spoken_text, tag]
		"action":
			return "do play%s(\"%s\")" % ["_and_wait" if row.wait else "", row.anim]
		"character_action":
			return "do play(\"%s\", \"%s\")" % [row.target, row.anim]
		"wait":
			return "do wait(%s)" % row.seconds
		"load_scene":
			return "do GlobalManager.load_scene(\"%s\")" % row.path
		"shared":
			return "=>< " + row.title
	return row.text


func get_conversation(title : String) -> Variant:
	for conversation in conversations:
		if conversation.title == title:
			return conversation
	return null


## Adds an empty conversation with a title nobody has to think about.
func add_conversation(base_name : String) -> Dictionary:
	var title := base_name
	var number := 2
	while get_conversation(title) != null:
		title = "%s_%d" % [base_name, number]
		number += 1
	var conversation := { title = title, label = "", rows = [], exit = END_JUMP, moves_on = false }
	conversations.append(conversation)
	return conversation


func save() -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(to_text())
	file.close()
	return OK
