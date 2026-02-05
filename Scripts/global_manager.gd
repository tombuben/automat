extends Node

var cursor_body : CursorBody

var dispensor_selector : DispenserSelector

var world_view : WorldView
var rotate_around : RotateAround

var screen_resizer : ScreenResizer

var scene_dialogue_manager : SceneDialogueManager


signal play_animation(animation_name : String)
var current_animation_length : float

signal person_shoot_selection_started(person_name : String)
var item_that_hit : RandomItem

signal recieve_item(item : String)
