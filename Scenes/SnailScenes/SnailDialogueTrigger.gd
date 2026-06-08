extends Area3D

@export var player: CharacterBody3D
@export var dialogue_ui: CanvasLayer

@export_multiline var dialogue_lines: Array[String]
@export var speaker_is_left: Array[bool]
@export var speaker_portraits: Array[Texture2D]

@export var one_shot := true

var triggered := false


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):

	if body != player:
		return

	if triggered:
		return

	if one_shot:
		triggered = true

	await _run_dialogue()


func _run_dialogue():

	player.can_move = false

	dialogue_ui.start(
		dialogue_lines,
		speaker_portraits,
		speaker_is_left
	)

	while dialogue_ui.active:
		await get_tree().process_frame

	player.can_move = true

	if not one_shot:
		triggered = false
