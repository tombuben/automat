extends Node

var cursor_body : CursorBody

var dispensor_selector : DispenserSelector

var world_view : WorldView
var rotate_around : RotateAround

var screen_resizer : ScreenResizer


signal play_animation(animation_name : String)
var played_animation_duration : float

signal person_shoot_selection_started(person_name : String)
var person_hit_with_item : String

signal recieve_item(item : String)
