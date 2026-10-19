extends CanvasLayer
## Single-speaker dialogue box. All visuals are real nodes in the scene:
##
##   TextBox (this script)
##   └─ Box               <- drag this to move everything together
##      ├─ Background     <- the sprite (wobble shader); resize it freely
##      ├─ Text           <- RichTextLabel; its WIDTH is the widest a line gets
##      └─ ContinueArrow  <- shown when a line has finished typing
##
## Lay it out in the editor exactly how a long line should look.
## In game the script keeps those proportions:
##   * Text never gets wider than you made it (long lines wrap at that width)
##   * Background keeps the same margins around the text
##   * ContinueArrow keeps the same spot relative to the Background's corner
## With fit_to_text on, short lines shrink the box around the text,
## keeping the Background's centre where you put it (see `pivot`).
##
## Usage:  $TextBox.start(["Hey.", "It's [wave]cold[/wave] out tonight."])

signal dialogue_finished

@export_group("Nodes")
@export var box: Control
@export var background: Control
@export var text_label: RichTextLabel
@export var continue_arrow: Control
@export var dialogue_sfx: AudioStreamPlayer

@export_group("Typing")
@export var char_speed := 0.02
@export var pitch_variation := 0.05

@export_group("Size")
## Shrink the box around short lines. Off = always the editor size.
@export var fit_to_text := true
## Narrowest the text area gets, in pixels.
@export var min_text_width := 60.0
## Never shrink the height below the editor layout.
@export var keep_editor_height := false

@export_group("Open / Close")
## Where the box scales from when it pops open/closed, and where it stays
## pinned when it resizes between lines.
@export_enum("Center", "Bottom", "Top") var pivot := 0
## Scale the box starts at when opening (0 = grows from nothing).
@export var open_from_scale := 0.6
@export var open_time := 0.45
@export var open_trans: Tween.TransitionType = Tween.TRANS_ELASTIC
@export var open_ease: Tween.EaseType = Tween.EASE_OUT
@export var close_time := 0.15
@export var close_trans: Tween.TransitionType = Tween.TRANS_BACK
@export var close_ease: Tween.EaseType = Tween.EASE_IN

@export_group("Resize Between Lines")
@export var resize_time := 0.18
@export var resize_trans: Tween.TransitionType = Tween.TRANS_BACK
@export var resize_ease: Tween.EaseType = Tween.EASE_OUT

@export_group("Idle Motion")
@export var sway_angle := 1.0
@export var sway_speed := 1.6
@export var bob_amount := 3.0

var lines: Array[String] = []
var index := 0
var active := false
var typing := false

# Editor layout, measured once (all in Box's local coordinates)
var _text_rect: Rect2
var _bg_rect: Rect2
var _arrow_rect: Rect2
var _margin_tl: Vector2      # Background top-left  -> Text top-left
var _margin_br: Vector2      # Text bottom-right    -> Background bottom-right
var _arrow_from_corner: Vector2
var _anchor_pt: Vector2      # pinned point of the Background (see `pivot`)

var _cur_bg: Rect2
var _box_base_pos := Vector2.ZERO
var _line_id := 0
var _time := 0.0
var _pop := 1.0
var _size_tween: Tween


func _ready():
	if box == null or text_label == null:
		push_error("SnailDialogue: assign 'box' and 'text_label' in the Inspector.")
		return
	_box_base_pos = box.position

	_text_rect = _local_rect(text_label)
	_bg_rect = _local_rect(background) if background else _text_rect
	_margin_tl = _text_rect.position - _bg_rect.position
	_margin_br = _bg_rect.end - _text_rect.end
	_anchor_pt = _pivot_of(_bg_rect)
	if continue_arrow:
		_arrow_rect = _local_rect(continue_arrow)
		_arrow_from_corner = _arrow_rect.position - _bg_rect.end
		continue_arrow.hide()

	# From here on the script positions the children itself,
	# so detach them from whatever anchors they had in the editor.
	for c in [background, text_label, continue_arrow]:
		if c:
			c.set_anchors_preset(Control.PRESET_TOP_LEFT, true)

	text_label.bbcode_enabled = true
	text_label.fit_content = false
	text_label.scroll_active = false
	text_label.clip_contents = false
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_bg_rect(_bg_rect)
	hide()


func _local_rect(c: Control) -> Rect2:
	# Rect of c in Box's local space (works for direct children)
	return Rect2(c.position, c.size)


# =====================================================
# START
# =====================================================
func start(dialogue_lines: Array, _unused_a = null, _unused_b = null):
	if dialogue_lines.is_empty():
		dialogue_finished.emit()
		return
	lines.assign(dialogue_lines)
	index = 0
	active = true
	_pop = open_from_scale
	show()
	create_tween().set_trans(open_trans).set_ease(open_ease) \
		.tween_property(self, "_pop", 1.0, open_time)
	_show_next_line()


# =====================================================
# NEXT LINE
# =====================================================
func _show_next_line():
	if index >= lines.size():
		end()
		return
	text_label.text = lines[index]
	index += 1
	text_label.visible_characters = 0
	if continue_arrow:
		continue_arrow.hide()
	_line_id += 1
	_fit_to_text()
	await _type_text(_line_id)


func _fit_to_text():
	var text_size := _text_rect.size
	if fit_to_text:
		var f: Font = text_label.get_theme_font("normal_font")
		var fs: int = text_label.get_theme_font_size("normal_font_size")
		var plain := text_label.get_parsed_text()
		var natural_w := f.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 6.0
		var w := clampf(natural_w, minf(min_text_width, _text_rect.size.x), _text_rect.size.x)
		# Let the label lay itself out at that width and ask how tall it is
		text_label.size = Vector2(w, 0)
		var h := maxf(float(text_label.get_content_height()),
			f.get_multiline_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, w, fs).y)
		if keep_editor_height:
			h = maxf(h, _text_rect.size.y)
		text_size = Vector2(w, h)

	var bg_size := text_size + _margin_tl + _margin_br
	var target := Rect2(_anchor_pt - _pivot_of(Rect2(Vector2.ZERO, bg_size)), bg_size)

	if _size_tween:
		_size_tween.kill()
	_size_tween = create_tween().set_trans(resize_trans).set_ease(resize_ease)
	_size_tween.tween_method(_apply_bg_rect, _cur_bg, target, resize_time)


## The point of a rect that stays fixed, depending on `pivot`.
func _pivot_of(r: Rect2) -> Vector2:
	match pivot:
		1: return Vector2(r.get_center().x, r.end.y)       # Bottom
		2: return Vector2(r.get_center().x, r.position.y)  # Top
		_: return r.get_center()                            # Center


## Place Background, Text and ContinueArrow for a given background rect.
func _apply_bg_rect(r: Rect2):
	_cur_bg = r
	if background:
		background.position = r.position
		background.size = r.size
	text_label.position = r.position + _margin_tl
	text_label.size = r.size - _margin_tl - _margin_br
	if continue_arrow:
		continue_arrow.position = r.end + _arrow_from_corner
		continue_arrow.size = _arrow_rect.size


# =====================================================
# TYPE TEXT
# =====================================================
func _type_text(my_id: int):
	typing = true
	var plain := text_label.get_parsed_text()
	var total := text_label.get_total_character_count()
	var revealed := 0
	var elapsed := 0.0
	while revealed < total:
		if my_id != _line_id or not typing:
			break
		elapsed += get_process_delta_time()
		var target := total if char_speed <= 0.0 else mini(total, int(elapsed / char_speed))
		if target > revealed:
			text_label.visible_characters = target
			if _has_voiced_char(plain, revealed, target):
				_blip()
			revealed = target
		await get_tree().process_frame
	if my_id == _line_id:
		typing = false
		text_label.visible_characters = -1
		if continue_arrow:
			continue_arrow.show()


func _has_voiced_char(plain: String, from: int, to: int) -> bool:
	for i in range(from, mini(to, plain.length())):
		var c := plain[i]
		if c.to_upper() != c.to_lower() or c.is_valid_int():
			return true
	return false


func _blip():
	if not dialogue_sfx or not dialogue_sfx.stream:
		return
	dialogue_sfx.stop()
	dialogue_sfx.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	dialogue_sfx.play()


# =====================================================
# INPUT (Space/Enter + left/right mouse)
# =====================================================
func _input(event):
	if not active:
		return
	var pressed: bool = event.is_action_pressed("ui_accept") or (
		event is InputEventMouseButton and event.pressed
		and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT])
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if typing:
		typing = false   # _type_text finishes the line and shows the arrow
	else:
		_show_next_line()


# =====================================================
# MOTION (pop, sway, bob) — applied to Box as a whole
# =====================================================
func _process(delta):
	if not visible or box == null:
		return
	_time += delta
	box.pivot_offset = _anchor_pt
	box.scale = Vector2.ONE * _pop
	box.rotation = deg_to_rad(sin(_time * sway_speed) * sway_angle)
	box.position = _box_base_pos + Vector2(0, sin(_time * sway_speed * 1.3) * bob_amount)
	if continue_arrow and continue_arrow.visible:
		continue_arrow.position.y = _cur_bg.end.y + _arrow_from_corner.y + sin(_time * 8.0) * 3.0


# =====================================================
# END
# =====================================================
func end():
	active = false
	typing = false
	_line_id += 1
	index = 0
	var t := create_tween().set_trans(close_trans).set_ease(close_ease)
	t.tween_property(self, "_pop", 0.0, close_time)
	await t.finished
	if not active:
		hide()
	dialogue_finished.emit()
