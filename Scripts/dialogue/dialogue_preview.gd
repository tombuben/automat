class_name DialoguePreview
extends CanvasLayer

@export var dialogue_rich_text: RichTextLabel
@export var letters_per_second: float = 100

@export var preview_audio_player: AudioStreamPlayer
@export var audio_samples: Array[AudioStream]

@export var pitch_min := 0.95
@export var pitch_max := 1.05
@export var play_every_n_letters := 2

var tween: Tween
var typing_active := false


func _ready() -> void:
	GlobalManager.dialogue_preview = self
	visible = false


func show_preview(preview_text: String):
	dialogue_rich_text.text = preview_text
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
