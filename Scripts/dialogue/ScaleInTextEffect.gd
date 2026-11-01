class_name ScaleInEffect
extends RichTextEffect
## Grows each letter from nothing to full size at the moment it gets revealed.

var bbcode = "scale"

## The label this effect is installed on. It tells us which letters are revealed.
var label: RichTextLabel
## How long one letter takes to reach full size, in seconds. 0 turns the growing off.
var grow_time := 0.15

# Letter index -> the time that letter was first revealed.
var _reveal_times := {}


## Call this every time the text starts revealing from the beginning.
func restart() -> void:
	_reveal_times.clear()


func _process_custom_fx(char_fx : CharFXTransform) -> bool:
	if grow_time <= 0.0 or label == null:
		return true

	var index := char_fx.range.x
	if label.visible_characters >= 0 and index >= label.visible_characters:
		return true

	if not _reveal_times.has(index):
		_reveal_times[index] = char_fx.elapsed_time

	var progress := clampf((char_fx.elapsed_time - _reveal_times[index]) / grow_time, 0.0, 1.0)
	if progress >= 1.0:
		return true

	# Ease out
	var size := maxf(1.0 - pow(1.0 - progress, 3.0), 0.01)

	# Grow from the middle of the letter instead of its bottom left corner
	var font_size := label.get_theme_font_size(&"normal_font_size")
	var advance := TextServerManager.get_primary_interface().font_get_glyph_advance(char_fx.font, font_size, char_fx.glyph_index)
	var middle := Vector2(advance.x * 0.5, font_size * -0.3)
	char_fx.transform = char_fx.transform.translated_local(middle).scaled_local(Vector2(size, size)).translated_local(-middle)

	return true
