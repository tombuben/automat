extends Sprite3D

@export var follow_strength: float = 0.08
@export var follow_speed: float = 8.0
@export var target_viewport_container: Control  # Drag your LEFT viewport container here

var base_position: Vector3

func _ready():
	base_position = global_position

func _process(delta):
	var mouse_pos = get_viewport().get_mouse_position()

	# Get viewport container rect (screen space)
	var rect = target_viewport_container.get_global_rect()

	var target_position = base_position

	# Check if mouse is inside the correct viewport area
	if rect.has_point(mouse_pos):
		var local_mouse = mouse_pos - rect.position
		var size = rect.size
		
		# Normalize to -1 to 1
		var normalized = (local_mouse / size - Vector2(0.5, 0.5)) * 2.0
		
		var offset = Vector3(normalized.x, -normalized.y, 0) * follow_strength
		target_position = base_position + offset

	# Smooth movement (either following or returning)
	global_position = global_position.lerp(target_position, delta * follow_speed)
