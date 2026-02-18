class_name ScaleInEffect
extends RichTextEffect

var bbcode = "scale"

func _process_custom_fx(char_fx):
	var t = char_fx.elapsed_time * 8.0
	var scale = clamp(t, 0.0, 1.0)

	# Ease out
	scale = 1.0 - pow(1.0 - scale, 3.0)

	# Modify font size instead of transform
	char_fx.font_size = int(char_fx.font_size * scale)

	return true
