extends AnimationPlayer

var auto_return_animations := {
	"hit": true
}

@export var default_return_time: float = 1.5

func _ready() -> void:
	GlobalManager.play_animation.connect(play_animation)


func play_animation(arg1, arg2 = null):
	var character_name: String
	var animation_name: String

	# CASE 1: Character animation
	if arg2 != null:
		character_name = arg1
		animation_name = arg2

		var character = GlobalManager.characters.get(character_name)
		if character == null:
			print("Character not found: ", character_name)
			return

		var animation_player: AnimationPlayer = character.find_child("AnimationPlayer", true, false)
		var sprite: AnimatedSprite3D = character.find_child("AnimatedSprite3D", true, false)

		if animation_player and animation_player.has_animation(animation_name):
			animation_player.play(animation_name, 0.1)
			GlobalManager.current_animation_length = animation_player.current_animation_length

		if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(animation_name):
			sprite.play(animation_name)

			# ONLY auto-return if explicitly marked
			if auto_return_animations.has(animation_name):
				var current_sprite = sprite

				await get_tree().create_timer(default_return_time).timeout

				if is_instance_valid(current_sprite) and current_sprite.sprite_frames:
					current_sprite.play("idle")

	# CASE 2: Global animation
	else:
		animation_name = arg1

		if has_animation(animation_name):
			play(animation_name, 0.1)
			GlobalManager.current_animation_length = current_animation_length
		else:
			print("Global animation missing: ", animation_name)
