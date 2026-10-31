extends Node3D

@onready var anim = $bgPerson1

func _ready():
	randomize()
	anim.play()
	
	# Jump to a random frame
	anim.frame = randi() % anim.sprite_frames.get_frame_count(anim.animation)
