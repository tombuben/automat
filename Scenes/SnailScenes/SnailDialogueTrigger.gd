extends Area3D
## Walk the snail into this Area3D to start a dialogue.
## Needs a CollisionShape3D child. Set things up in the Inspector:
##   dialogue_ui    -> the TextBox CanvasLayer (SnailDialogue.gd)
##   dialogue_lines -> one entry per text box

signal dialogue_done

@export var dialogue_ui: CanvasLayer
@export_multiline var dialogue_lines: Array[String] = []
## Optional. If empty, any body in the "player" group triggers it.
@export var player: CharacterBody3D
@export var one_shot := true
## Stop the snail from walking while the dialogue is open.
@export var freeze_player := true

var triggered := false


func _ready():
	monitoring = true
	body_entered.connect(_on_body_entered)


func _is_player(body: Node) -> bool:
	if player:
		return body == player
	return body.is_in_group("player")


func _on_body_entered(body: Node):
	if triggered or not _is_player(body):
		return
	if dialogue_ui == null:
		push_error("%s: assign 'dialogue_ui' (the TextBox) in the Inspector." % name)
		return
	if dialogue_lines.is_empty():
		push_warning("%s: 'dialogue_lines' is empty." % name)
		return
	if dialogue_ui.active:
		return
	triggered = true
	_run_dialogue(body)


func _run_dialogue(body: Node):
	if freeze_player and "can_move" in body:
		body.can_move = false

	dialogue_ui.start(dialogue_lines)
	await dialogue_ui.dialogue_finished

	# Wait one physics frame so the click that closed the box
	# can't also be read as a "walk here" click.
	await get_tree().physics_frame
	if freeze_player and is_instance_valid(body) and "can_move" in body:
		body.can_move = true

	dialogue_done.emit()
	if not one_shot:
		triggered = false
