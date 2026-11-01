class_name GrowingDialogueLabel
extends DialogueLabel
## A DialogueLabel whose letters grow in one by one.
## Typing speed is seconds_per_step, from DialogueLabel.

## How long one letter takes to reach full size, in seconds. 0 turns the growing off.
@export var letter_grow_time := 0.15

var scale_in_effect := ScaleInEffect.new()


func _ready() -> void:
	super()
	scale_in_effect.label = self
	scale_in_effect.grow_time = letter_grow_time
	custom_effects = [scale_in_effect]


func _update_text() -> void:
	text = "[scale]%s[/scale]" % dialogue_line.text


func type_out() -> void:
	scale_in_effect.restart()
	super()
