extends TextureRect

@export var rotation_speed: float = 90.0

func _ready():
	pivot_offset = size / 2

func _process(delta):
	rotation_degrees += rotation_speed * delta
