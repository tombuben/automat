extends Area3D

@export var target_spawn: Node3D
@export var target_camera_zone: Area3D

@export var old_room: Node3D
@export var new_room: Node3D

@onready var fade := get_tree().get_first_node_in_group("fade_manager")

var triggered := false

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if triggered:
		return

	if not body is CharacterBody3D:
		return

	triggered = true

	await fade.fade_out(1.0)

	# --- Swap rooms ---
	if old_room:
		old_room.visible = false

	if new_room:
		new_room.visible = true

	# --- Move player ---
	body.global_position = target_spawn.global_position

	# --- Apply camera zone ---
	if body.has_method("get_camera_controller"):
		body.get_camera_controller().push_camera_zone(target_camera_zone)

	await fade.fade_in(1.0)

	triggered = false
