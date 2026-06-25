extends Control

@export var wave_strength := 0.035
@export var wave_jitter := 0.008

var symbols = []


func _ready():
	randomize()

	symbols.clear()

	for child in get_children():
		if child.has_signal("clicked"):
			symbols.append(child)
			child.clicked.connect(_on_symbol_clicked)


func _on_symbol_clicked(origin):

	for symbol in symbols:

		var distance = origin.global_position.distance_to(
			symbol.global_position
		)

		# Non-linear timing produces a nicer wave.
		var delay = sqrt(distance) * wave_strength

		# Small random offset makes the ripple feel organic.
		delay += randf_range(
			-wave_jitter,
			 wave_jitter
		)

		symbol.pulse(max(delay, 0.0))
