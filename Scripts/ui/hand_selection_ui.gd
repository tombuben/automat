class_name HandSelectionUI extends Control

@export var put_back_button : BaseButton
@export var launch_button : BaseButton
@export var object_preview_spawn_point: ObjectPreviewSpawnPoint
@export var item_name_label : RichTextLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	hide_ui()
	GlobalManager.hand_selection_ui = self
	put_back_button.pressed.connect(put_back_pressed)
	launch_button.pressed.connect(launch_button_pressed)
	
func put_back_pressed():
	var dispensor_selector = GlobalManager.dispensor_selector
	if dispensor_selector.body_in_dispenser:
		dispensor_selector.remove_from_dispenser()

func launch_button_pressed():
	var dispensor_selector = GlobalManager.dispensor_selector
	if dispensor_selector.body_in_dispenser:
		dispensor_selector.start_shooting(dispensor_selector.body_in_dispenser)
	hide_ui()

func show_ui_for_item(item : RandomItem):
	visible = true
	item_name_label.visible_ratio = 1.0
	item_name_label.text = item.item_name
	object_preview_spawn_point.spawn_item(item)

func hide_ui():
	visible = false
	object_preview_spawn_point.remove_item()
