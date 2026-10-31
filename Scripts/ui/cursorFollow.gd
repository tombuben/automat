extends Sprite3D

@export var follow_strength: float = 0.08
@export var follow_speed: float = 8.0

# Assign your viewport containers here
@export var left_viewport_container: Control
@export var right_viewport_container: Control

# Assign the cursor sprites for each viewport
@export var left_viewport_sprite: Texture2D
@export var right_viewport_sprite: Texture2D
@export var default_sprite: Texture2D

var base_position: Vector3

func _ready():
	base_position = global_position
	if default_sprite != null:
		texture = default_sprite

func _process(delta):
	var mouse_pos = get_viewport().get_mouse_position()

	var target_position = base_position

	# Determine which viewport the mouse is over and set sprite
	if left_viewport_container != null and left_viewport_container.get_global_rect().has_point(mouse_pos):
		if left_viewport_sprite != null:
			texture = left_viewport_sprite
		var rect = left_viewport_container.get_global_rect()
		var local_mouse = mouse_pos - rect.position
		var size = rect.size
		var normalized = (local_mouse / size - Vector2(0.5, 0.5)) * 2.0
		target_position = base_position + Vector3(normalized.x, -normalized.y, 0) * follow_strength

	elif right_viewport_container != null and right_viewport_container.get_global_rect().has_point(mouse_pos):
		if right_viewport_sprite != null:
			texture = right_viewport_sprite
		var rect = right_viewport_container.get_global_rect()
		var local_mouse = mouse_pos - rect.position
		var size = rect.size
		var normalized = (local_mouse / size - Vector2(0.5, 0.5)) * 2.0
		target_position = base_position + Vector3(normalized.x, -normalized.y, 0) * follow_strength

	else:
		# Not in any assigned viewport
		if default_sprite != null:
			texture = default_sprite

	# Smooth movement (lerp)
	global_position = global_position.lerp(target_position, delta * follow_speed)
