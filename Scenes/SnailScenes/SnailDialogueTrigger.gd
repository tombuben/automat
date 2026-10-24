extends Area3D
## Interactable zone (Kentucky Route Zero style).
## Needs a CollisionShape3D child — that shape is the "radius".
##
## Start mode
##   On Enter : the action starts as soon as the snail walks in.
##   On Click : a button (your AnimatedSprite3D) appears while the snail is
##              inside; clicking it starts the action.
## Action
##   Dialogue   : shows dialogue_lines in the TextBox.
##   Next Scene : fades out and loads target_scene.
##
## On Click: the snail first walks to the spot under the button (or walk_target),
## pauses for pause_before_action, then the action starts. Clicking somewhere
## else while it walks cancels.
##
## Button animations (all optional — any that exist on the sprite are used):
##   "appear" (plays once, then "idle"), "idle", "hover", "click"

signal interaction_started
signal dialogue_done

enum StartMode { ON_ENTER, ON_CLICK }
enum Action { DIALOGUE, NEXT_SCENE }

@export var start_mode: StartMode = StartMode.ON_ENTER
@export var action: Action = Action.DIALOGUE
## Optional. If empty, any body in the "player" group counts.
@export var player: CharacterBody3D
## Off = can be used again after walking out and back in.
@export var one_shot := true
## Stop the snail from walking while the dialogue / scene change runs.
@export var freeze_player := true

@export_group("Dialogue")
@export var dialogue_ui: CanvasLayer
@export_multiline var dialogue_lines: Array[String] = []

@export_group("Next Scene")
@export_file("*.tscn") var target_scene: String
@export var fade_manager: CanvasLayer

@export_group("Button (On Click)")
## The clickable icon. Place it in the scene where it should float.
@export var button: AnimatedSprite3D
## Extra clickable margin around the sprite, in screen pixels.
@export var click_padding := 8.0
@export var appear_time := 0.25
@export var hover_scale := 1.15

@export_group("Walk Over (On Click)")
## Walk the snail to the button before starting.
@export var walk_to_button := true
## Optional: walk here instead of under the button (only its X is used).
@export var walk_target: Node3D
## Pause after arriving, before the dialogue / scene change starts.
@export var pause_before_action := 0.25
## Give up walking after this many seconds (e.g. something blocks the way)
## and start the action anyway.
@export var max_walk_time := 6.0

var used := false
var busy := false
var _player_inside: Node = null
var _button_shown := false
var _hovered := false
var _button_base_scale := Vector3.ONE
var _button_tween: Tween
var _approach_id := 0


func _ready():
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if button:
		_button_base_scale = button.scale
		button.visible = false
		button.animation_finished.connect(_on_button_anim_finished)


func _is_player(body: Node) -> bool:
	if player:
		return body == player
	return body.is_in_group("player")


# =====================================================
# ENTER / EXIT
# =====================================================
func _on_body_entered(body: Node):
	if not _is_player(body):
		return
	_player_inside = body
	if not _can_interact():
		return
	if start_mode == StartMode.ON_ENTER:
		_interact()
	else:
		_show_button()


func _on_body_exited(body: Node):
	if body != _player_inside:
		return
	_player_inside = null
	_hide_button()
	if not one_shot and not busy:
		used = false


func _can_interact() -> bool:
	return not busy and not (one_shot and used)


# =====================================================
# CLICKING THE BUTTON
# =====================================================
# _input runs before the snail's click-to-move (_unhandled_input), and the
# click is marked handled, so clicking the button never makes the snail walk.
func _input(event):
	if not _button_shown:
		return
	if event is InputEventMouseMotion:
		_set_hovered(_mouse_over_button(event.position))
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and _mouse_over_button(event.position):
		get_viewport().set_input_as_handled()
		_play_if_exists("click")
		_approach_then_interact()


func _mouse_over_button(screen_pos: Vector2) -> bool:
	var cam := get_viewport().get_camera_3d()
	if cam == null or button == null:
		return false
	# Project the sprite's 3D bounding box onto the screen
	var aabb := button.get_aabb()
	var xf := button.global_transform
	var rect := Rect2()
	var first := true
	for i in 8:
		var world := xf * aabb.get_endpoint(i)
		if cam.is_position_behind(world):
			return false
		var p := cam.unproject_position(world)
		if first:
			rect = Rect2(p, Vector2.ZERO)
			first = false
		else:
			rect = rect.expand(p)
	return rect.grow(click_padding).has_point(screen_pos)


func _set_hovered(h: bool):
	if h == _hovered:
		return
	_hovered = h
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if h else Input.CURSOR_ARROW)
	if h:
		_play_if_exists("hover")
	else:
		_play_if_exists("idle")
	_tween_button_scale(hover_scale if h else 1.0, 0.12)


# =====================================================
# BUTTON SHOW / HIDE
# =====================================================
func _show_button():
	if button == null:
		push_warning("%s: start mode is On Click but no 'button' is assigned." % name)
		return
	_button_shown = true
	button.visible = true
	button.scale = _button_base_scale * 0.01
	if not _play_if_exists("appear"):
		_play_if_exists("idle")
	_tween_button_scale(1.0, appear_time, Tween.TRANS_BACK)


func _hide_button():
	if button == null or not _button_shown:
		return
	_button_shown = false
	if _hovered:
		_set_hovered(false)
	_tween_button_scale(0.01, appear_time * 0.6, Tween.TRANS_BACK, Tween.EASE_IN)
	_button_tween.tween_callback(func(): if not _button_shown: button.visible = false)


func _tween_button_scale(mult: float, time: float,
		trans := Tween.TRANS_SINE, ease_type := Tween.EASE_OUT):
	if _button_tween:
		_button_tween.kill()
	_button_tween = create_tween().set_trans(trans).set_ease(ease_type)
	_button_tween.tween_property(button, "scale", _button_base_scale * mult, time)


func _play_if_exists(anim: String) -> bool:
	if button and button.sprite_frames and button.sprite_frames.has_animation(anim):
		button.play(anim)
		return true
	return false


func _on_button_anim_finished():
	if button.animation in ["appear", "click"]:
		_play_if_exists("hover" if _hovered else "idle")


# =====================================================
# WALK OVER, THEN ACT
# =====================================================
func _approach_then_interact():
	var body := _player_inside
	if not walk_to_button or body == null or not ("auto_move_x" in body):
		_interact()
		return
	busy = true            # no double clicks while walking
	_hide_button()
	_approach_id += 1
	var my_id := _approach_id
	var target_node: Node3D = walk_target if walk_target else button
	var target_x: float = target_node.global_position.x

	body.auto_move_x = target_x
	body.is_auto_walking = true

	var t := 0.0
	while true:
		await get_tree().physics_frame
		if my_id != _approach_id or not is_instance_valid(body):
			return
		t += get_physics_process_delta_time()
		# Player clicked somewhere else -> cancel
		var new_target = body.auto_move_x
		if body.is_auto_walking and (typeof(new_target) != TYPE_FLOAT
				or is_nan(new_target) or absf(new_target - target_x) > 0.001):
			busy = false
			if _player_inside and _can_interact():
				_show_button()
			return
		if not body.is_auto_walking or t >= max_walk_time:
			break

	# Arrived: stop, settle, then act
	body.is_auto_walking = false
	body.auto_move_x = NAN
	if freeze_player and "can_move" in body:
		body.can_move = false
	if pause_before_action > 0.0:
		await get_tree().create_timer(pause_before_action).timeout
	busy = false
	_interact(body)


# =====================================================
# THE ACTION
# =====================================================
func _interact(body: Node = null):
	if not _can_interact():
		return
	busy = true
	used = true
	_hide_button()
	interaction_started.emit()
	if body == null:
		body = _player_inside
	if freeze_player and body and "can_move" in body:
		body.can_move = false

	match action:
		Action.DIALOGUE:
			await _run_dialogue()
		Action.NEXT_SCENE:
			await _change_scene()
			return

	# Wait one physics frame so the click that closed the box
	# can't also be read as a "walk here" click.
	await get_tree().physics_frame
	if freeze_player and is_instance_valid(body) and "can_move" in body:
		body.can_move = true
	busy = false
	dialogue_done.emit()

	# Repeatable and still standing here -> offer the button again
	if not one_shot:
		used = false
		if _player_inside and start_mode == StartMode.ON_CLICK:
			_show_button()


func _run_dialogue():
	if dialogue_ui == null:
		push_error("%s: assign 'dialogue_ui' (the TextBox) in the Inspector." % name)
		return
	if dialogue_lines.is_empty():
		push_warning("%s: 'dialogue_lines' is empty." % name)
		return
	dialogue_ui.start(dialogue_lines)
	await dialogue_ui.dialogue_finished


func _change_scene():
	if target_scene.is_empty():
		push_error("%s: set 'target_scene' in the Inspector." % name)
		busy = false
		return
	if fade_manager:
		await fade_manager.fade_out()
	get_tree().change_scene_to_file(target_scene)
