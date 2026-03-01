extends Node3D

@onready var sprite: AnimatedSprite3D = $AnimatedSprite3D

func _ready():
	GlobalManager.play_animation.connect(_on_play_animation)

func _on_play_animation(animation_name: String):
	sprite.play(animation_name)
