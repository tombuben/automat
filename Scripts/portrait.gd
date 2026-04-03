extends TextureRect


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalManager.update_portrait.connect(update_portrait)


func update_portrait(new_texture):
	texture = new_texture
