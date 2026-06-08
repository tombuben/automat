extends CanvasLayer

@export var text_label: RichTextLabel
@export var left_portrait: TextureRect
@export var right_portrait: TextureRect

@export var char_speed := 0.02

var lines: Array[String]
var portraits: Array[Texture2D]
var sides: Array[bool]

var index := 0
var active := false
var typing := false
var current_text := ""

var skip_requested := false


func _ready():
	hide()


# =====================================================
# START DIALOGUE
# =====================================================
func start(
	dialogue_lines: Array[String],
	dialogue_portraits: Array[Texture2D],
	dialogue_sides: Array[bool]
):

	lines = dialogue_lines
	portraits = dialogue_portraits
	sides = dialogue_sides

	index = 0
	active = true

	show()

	_show_next_line()


# =====================================================
# NEXT LINE
# =====================================================
func _show_next_line():

	if index >= lines.size():
		end()
		return

	current_text = lines[index]

	_update_portraits(index)

	index += 1

	await _type_text(current_text)

	# auto-wait for input after typing finishes
	skip_requested = false


# =====================================================
# PORTRAITS
# =====================================================
func _update_portraits(i: int):

	if i >= portraits.size():
		return

	var portrait = portraits[i]
	var is_left = (i < sides.size() and sides[i])

	if is_left:
		left_portrait.texture = portrait
		left_portrait.modulate = Color.WHITE
		right_portrait.modulate = Color(0.5, 0.5, 0.5)
	else:
		right_portrait.texture = portrait
		right_portrait.modulate = Color.WHITE
		left_portrait.modulate = Color(0.5, 0.5, 0.5)


# =====================================================
# TYPE TEXT
# =====================================================
func _type_text(text: String):

	typing = true
	text_label.text = ""

	for i in range(text.length()):

		# instant skip typing
		if skip_requested:
			text_label.text = current_text
			typing = false
			return

		text_label.text += text[i]
		await get_tree().create_timer(char_speed).timeout

	typing = false


# =====================================================
# INPUT (MOUSE + KEYBOARD)
# =====================================================
func _unhandled_input(event):

	if not active:
		return

	var pressed := false

	# keyboard
	if event.is_action_pressed("ui_accept"):
		pressed = true

	# mouse click
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			pressed = true

	if not pressed:
		return


	# -------------------------------------------------
	# If typing → skip to full text
	# -------------------------------------------------
	if typing:
		skip_requested = true
		text_label.text = current_text
		typing = false
		return


	# -------------------------------------------------
	# Otherwise → next line
	# -------------------------------------------------
	_show_next_line()


# =====================================================
# END
# =====================================================
func end():

	hide()

	active = false
	index = 0
