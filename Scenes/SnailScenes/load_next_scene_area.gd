extends Area3D

@export_file("*.tscn") var target_scene: String
@export var fade_manager: CanvasLayer
@export var player: CharacterBody3D

var busy := false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if busy:
		return

	if body != player:
		return

	busy = true
	await _change_scene()

func _change_scene() -> void:

	# -----------------------------------------
	# 1. LOCK PLAYER
	# -----------------------------------------
	if "can_move" in player:
		player.can_move = false

	# -----------------------------------------
	# 2. FADE OUT
	# -----------------------------------------
	await fade_manager.fade_out()

	# -----------------------------------------
	# 3. LOAD SCENE
	# -----------------------------------------
	get_tree().change_scene_to_file(target_scene)
