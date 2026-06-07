extends AudioStreamPlayer

@export var audio_samples : Array[AudioStream]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%DialogueLabel.spoke.connect(on_spoke)
	GlobalManager.update_audio_beeps.connect(update_audio_beeps)

func update_audio_beeps(new_beep_array: Array[AudioStream]):
	audio_samples = new_beep_array

func on_spoke(letter: String, letter_index: int, speed: float) -> void:
	if not playing:
		stream = audio_samples.pick_random()
		play()
