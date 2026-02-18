extends AnimationPlayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalManager.play_animation.connect(play_animation)

func play_animation(animation_name : String):
	if not has_animation(animation_name):
		print("Animation " + animation_name + " is missing!")
		return
	play(animation_name, 0.1)
	GlobalManager.current_animation_length = current_animation_length
