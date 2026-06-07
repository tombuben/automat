class_name DialoguePreview extends CanvasLayer

@export var dialogue_rich_text : RichTextLabel
@export var letters_per_second : float = 100

@export var preview_audio_player : AudioStreamPlayer
@export var audio_samples : Array[AudioStream]

var tween : Tween = create_tween()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalManager.dialogue_preview = self
	visible = false

func show_preview(preview_text : String):
	dialogue_rich_text.text = preview_text
	dialogue_rich_text.visible_ratio = 0
	tween.kill()
	tween = create_tween()
	var duration = len(preview_text)/letters_per_second
	
	tween.tween_property(dialogue_rich_text, "visible_ratio", 1, duration)
	tween.tween_method(on_spoke, 0.0, 1.0, duration)
	visible = true
	
func hide_preview():
	# mozna bude potreba odkomentovat s kratsim zvukem
	#preview_audio_player.stop()
	tween.kill()
	visible = false

func on_spoke(progress: float) -> void:
	if not preview_audio_player.playing:
		preview_audio_player.stream = audio_samples.pick_random()
		preview_audio_player.play()
