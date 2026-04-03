class_name DialoguePreview extends CanvasLayer

@export var dialogue_rich_text : RichTextLabel
@export var letters_per_second : float = 100

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalManager.dialogue_preview = self
	visible = false

func show_preview(preview_text : String):
	dialogue_rich_text.text = preview_text
	dialogue_rich_text.visible_ratio = 0
	var tween = create_tween()
	tween.tween_property(dialogue_rich_text, "visible_ratio", 1, len(preview_text)/letters_per_second)
	visible = true
	
func hide_preview():
	visible = false
