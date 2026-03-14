extends Node

var cursor_body : CursorBody

var dispensor_selector : DispenserSelector
var hand_selection_ui : HandSelectionUI
var world_view : WorldView
var rotate_around : RotateAround

var screen_resizer : ScreenResizer

var scene_dialogue_manager : SceneDialogueManager


signal play_animation(animation_name : String)
var current_animation_length : float

signal person_shoot_selection_started(person_name : String)
var item_that_hit : RandomItem

signal recieve_item(item : String)



#####

func expand_for_shooting(duration = 1.0):
	var tween = create_tween()
	var screen_size = 0.0
	tween.tween_property(screen_resizer, "ratio", screen_size, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)

func expand_for_selection(duration = 1.0):
	var tween = create_tween()
	var screen_size = screen_resizer.original_ration
	tween.tween_property(screen_resizer, "ratio", screen_size, duration)\
		.set_trans(Tween.TRANS_SINE)\
		.set_ease(Tween.EASE_OUT)
