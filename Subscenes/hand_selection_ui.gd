extends Control

@export var PutBackButton : BaseButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	PutBackButton.pressed.connect(put_back_pressed)
	pass # Replace with function body.

func put_back_pressed():
	var dispensor_selector = GlobalManager.dispensor_selector
	if dispensor_selector.body_in_dispenser:
		dispensor_selector.remove_from_dispenser()
