extends AudioStreamPlayer

@export var audio_samples: Array[AudioStream]
@export var letters_per_beep := 2

# The current speaker's voice. Overrides audio_samples while it is set.
var speaker_samples: Array[AudioStream] = []

func _ready() -> void:
	%DialogueLabel.spoke.connect(on_spoke)
	GlobalManager.update_audio_beeps.connect(update_audio_beeps)

func update_audio_beeps(new_beep_array: Array[AudioStream]):
	audio_samples = new_beep_array

func on_spoke(letter: String, letter_index: int, speed: float) -> void:
	# Ignore spaces and punctuation.
	if letter in [" ", ".", ",", "!", "?", ":", ";"]:
		return

	# Only beep every N letters.
	if letter_index % letters_per_beep != 0:
		return

	stream = speaker_samples.pick_random() if not speaker_samples.is_empty() else audio_samples.pick_random()
	play()
