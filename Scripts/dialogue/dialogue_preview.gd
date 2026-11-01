class_name DialoguePreview
extends CanvasLayer

@export var dialogue_rich_text: RichTextLabel
@export var letters_per_second: float = 40
## How long one letter takes to reach full size, in seconds. 0 turns the growing off.
@export var letter_grow_time := 0.15

@export var preview_audio_player: AudioStreamPlayer
@export var audio_samples: Array[AudioStream]

@export var pitch_min := 0.95
@export var pitch_max := 1.05
@export var play_every_n_letters := 2

var tween: Tween
var typing_active := false
var scale_in_effect := ScaleInEffect.new()


func _ready() -> void:
	GlobalManager.dialogue_preview = self
	visible = false

	scale_in_effect.label = dialogue_rich_text
	scale_in_effect.grow_time = letter_grow_time
	dialogue_rich_text.custom_effects = [scale_in_effect]


func show_preview(preview_text: String):
	scale_in_effect.restart()
	dialogue_rich_text.text = "[scale]%s[/scale]" % preview_text
	dialogue_rich_text.visible_ratio = 0

	if tween:
		tween.kill()

	tween = create_tween()

	var duration = float(preview_text.length()) / letters_per_second

	tween.tween_property(dialogue_rich_text, "visible_ratio", 1, duration)

	visible = true

	_start_audio_typing(preview_text)


func hide_preview():
	if tween:
		tween.kill()

	typing_active = false
	visible = false


# -------------------------------------------------
# RELIABLE AUDIO TYPING SYSTEM (FIXED)
# -------------------------------------------------
func _start_audio_typing(text: String) -> void:
	typing_active = true

	var i := 0

	while typing_active and i < text.length():
		await get_tree().create_timer(1.0 / letters_per_second).timeout

		var c := text[i]

		# skip silent characters
		if c in [" ", ".", ",", "!", "?", ":", ";"]:
			i += 1
			continue

		# spacing control
		if i % play_every_n_letters != 0:
			i += 1
			continue

		if audio_samples.is_empty():
			i += 1
			continue

		preview_audio_player.stream = audio_samples.pick_random()
		preview_audio_player.pitch_scale = randf_range(pitch_min, pitch_max)
		preview_audio_player.play()

		i += 1
