class_name MouseCursor extends Node2D

var rotation_target : float

func _ready() -> void:
	DialogueManager.dialogue_started.connect(on_dialogue_started)
	DialogueManager.dialogue_ended.connect(on_dialogue_closed)

func _process(delta: float) -> void:
	position = get_viewport().get_mouse_position()
	return

func on_dialogue_started(resource: Resource) -> void:
	visible = false

func on_dialogue_closed(resource: Resource) -> void:
	visible = true
