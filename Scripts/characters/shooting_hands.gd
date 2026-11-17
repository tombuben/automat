class_name ShootingHands extends Node3D
## The automat's hands in the world view. Every AnimatedSprite3D child plays
## these animations from its SpriteFrames, and skips the ones it doesn't have:
##   idle, reach, hold, charge - looping, while that is happening
##   catch, throw - play once (turn Loop off), then go back to the looping ones

## How far above the spawn point the held item rests.
@export var item_rest_height := 0.2
## How much the hands trail behind the camera tilt. 0 = glued to the camera.
@export var tilt_lag := 0.35
@export var tilt_lag_speed := 4.0

@onready var world_view : WorldView = get_parent()
@onready var base_position : Vector3 = position
var lagged_tilt := Vector3.ZERO

var current_animation : StringName
var once_animation : StringName
var playing_once := false


func _process(delta : float) -> void:
	_follow_tilt(delta)

	if playing_once:
		if _is_once_animation_playing():
			return
		playing_once = false
		current_animation = &""

	var wanted := _get_looping_animation()
	if wanted != current_animation:
		current_animation = wanted
		_play(wanted)


## The hands are attached to the camera, so to lag they shift the way the world
## does when the camera turns, just less and only until they catch up.
func _follow_tilt(delta : float) -> void:
	lagged_tilt = lagged_tilt.lerp(world_view.tilt, 1.0 - exp(-tilt_lag_speed * delta))
	var behind := world_view.tilt - lagged_tilt
	var distance := -base_position.z
	position = base_position + Vector3(behind.y, -behind.x, 0.0) * distance * tilt_lag


func catch_item() -> void:
	_play_once(&"catch")


func throw_item() -> void:
	_play_once(&"throw")


func _get_looping_animation() -> StringName:
	if world_view.charging:
		return &"charge"
	if world_view.object_to_shoot:
		return &"hold"
	var cursor := GlobalManager.cursor_body
	if cursor and cursor.dragging:
		return &"reach"
	return &"idle"


func _play_once(animation : StringName) -> void:
	if _play(animation):
		once_animation = animation
		playing_once = true


## Returns whether any sprite has this animation.
func _play(animation : StringName) -> bool:
	var played := false
	for sprite in _get_sprites():
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(animation):
			sprite.play(animation)
			played = true
	return played


func _is_once_animation_playing() -> bool:
	for sprite in _get_sprites():
		# A hand without this animation keeps looping its last one, so it doesn't count.
		var frames := sprite.sprite_frames
		if frames and sprite.animation == once_animation and sprite.is_playing() and not frames.get_animation_loop(once_animation):
			return true
	return false


func _get_sprites() -> Array[AnimatedSprite3D]:
	var sprites : Array[AnimatedSprite3D] = []
	for child in get_children():
		if child is AnimatedSprite3D:
			sprites.append(child)
	return sprites
