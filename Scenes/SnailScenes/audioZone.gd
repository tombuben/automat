extends Area3D

@export var player: Node3D
@export var music: AudioStreamPlayer3D

@export var fade_out_volume := -40.0

var is_inside := false
var tween: Tween
var target_volume := 0.0


func _ready():
	if music:
		target_volume = music.volume_db  # Remember the Inspector value.
		music.volume_db = fade_out_volume


func _process(_delta):
	if player == null or music == null:
		return

	var bodies = get_overlapping_bodies()

	var currently_inside := false
	for b in bodies:
		if b == player:
			currently_inside = true
			break

	if currently_inside and not is_inside:
		_enter_zone()
	elif not currently_inside and is_inside:
		_exit_zone()


func _enter_zone():
	is_inside = true

	music.play()

	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(music, "volume_db", target_volume, 2.0)


func _exit_zone():
	is_inside = false

	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(music, "volume_db", fade_out_volume, 1.5)
	tween.tween_callback(music.stop)
