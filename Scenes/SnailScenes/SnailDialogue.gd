extends CanvasLayer
@export var text_label: RichTextLabel
@export var left_portrait: TextureRect
@export var right_portrait: TextureRect
@export var dialogue_sfx: AudioStreamPlayer
@export var left_voice: AudioStream
@export var right_voice: AudioStream
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
	randomize()
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
		if left_voice:
			dialogue_sfx.stream = left_voice
	else:
		right_portrait.texture = portrait
		right_portrait.modulate = Color.WHITE
		left_portrait.modulate = Color(0.5, 0.5, 0.5)
		if right_voice:
			dialogue_sfx.stream = right_voice
# =====================================================
# TYPE TEXT
# =====================================================
func _type_text(text: String):
	typing = true
	text_label.text = ""
	# A SceneTreeTimer can never resolve faster than one process frame, so
	# create_timer(char_speed).timeout used to silently clamp char_speed
	# to "at least 1 frame per character" — anything below ~1/60s had no
	# effect. Accumulating elapsed time across frames instead lets more
	# than one character reveal per frame once char_speed is small, so
	# the slider actually has range below frame-rate speed.
	var revealed := 0
	var elapsed := 0.0
	while revealed < text.length():
		# Instant skip typing
		if skip_requested:
			text_label.text = current_text
			typing = false
			return
		elapsed += get_process_delta_time()
		var target_revealed: int = min(text.length(), int(elapsed / char_speed))
		while revealed < target_revealed:
			var c := text[revealed]
			text_label.text += c
			revealed += 1
			# Only play sounds for letters/numbers
			if c.is_valid_identifier():
				dialogue_sfx.stop()
				# Small pitch variation
				dialogue_sfx.pitch_scale = randf_range(0.95, 1.05)
				dialogue_sfx.play()
		await get_tree().process_frame
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
