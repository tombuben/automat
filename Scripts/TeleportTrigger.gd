extends Area3D

@export var target_position: Node3D
@export var fade_manager: CanvasLayer
@export var player: CharacterBody3D
@export var camera: Node3D  # your camera root or rig

var busy := false


func _ready():
	body_entered.connect(_on_body_entered)


func _on_body_entered(body):

	if busy:
		return

	if body != player:
		return

	busy = true
	await _do_transition()


func _do_transition() -> void:

	# -------------------------------------------------
	# 1. LOCK PLAYER
	# -------------------------------------------------
	if "can_move" in player:
		player.can_move = false


	# -------------------------------------------------
	# 2. FADE OUT
	# -------------------------------------------------
	await fade_manager.fade_out()


	# -------------------------------------------------
	# 3. TELEPORT PLAYER
	# -------------------------------------------------
	player.global_transform = target_position.global_transform


	# -------------------------------------------------
	# 4. INSTANT CAMERA SNAP (NO SMOOTHING)
	# -------------------------------------------------
	camera.snap_to_player()

	# -------------------------------------------------
	# 5. FADE IN
	# -------------------------------------------------
	await fade_manager.fade_in()


	# -------------------------------------------------
	# 6. UNLOCK PLAYER
	# -------------------------------------------------
	if "can_move" in player:
		player.can_move = true

	busy = false
