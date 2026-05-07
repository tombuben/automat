extends CanvasLayer

@onready var rect := $ColorRect

var tween: Tween

func fade_out(duration := 1.0):
	if tween:
		tween.kill()

	tween = create_tween()

	tween.tween_property(
		rect,
		"modulate:a",
		1.0,
		duration
	)

	await tween.finished


func fade_in(duration := 1.0):
	if tween:
		tween.kill()

	tween = create_tween()

	tween.tween_property(
		rect,
		"modulate:a",
		0.0,
		duration
	)

	await tween.finished
