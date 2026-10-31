@tool
class_name CharacterData extends Resource
## One character's identity, saved as a .tres file in res://Characters/.
## Dialogue lines find it by id, e.g. "printer: Hello" uses printer.tres.

## The name used in .dialogue files and in play_animation calls.
@export var id : String
## The name shown in the dialogue box.
@export var display_name : String
## Beep sounds played while this character talks.
@export var voice_sounds : Array[AudioStream]
