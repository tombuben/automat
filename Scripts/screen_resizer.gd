class_name ScreenResizer extends Control

@export var left_subviewport : SubViewport
@onready var left_subviewport_container : SubViewportContainer = left_subviewport.get_parent()
@export var right_subviewport : SubViewport
@onready var right_subviewport_container : SubViewportContainer = right_subviewport.get_parent()

@export var divider : ColorRect

@export var dialogue_resource : DialogueResource
@export var ratio : float
var original_ration : float

func _ready() -> void:
	GlobalManager.screen_resizer = self
	
	var viewport = get_viewport()
	ratio = left_subviewport.size.x / float(viewport.size.x)
	original_ration = ratio
	DialogueManager.show_dialogue_balloon(dialogue_resource, "day1_start")
	

func _process(delta: float) -> void:
	var viewport = get_viewport()
	left_subviewport_container.size.x = ratio * float(viewport.size.x)
	right_subviewport_container.size.x = viewport.size.x - left_subviewport.size.x
	right_subviewport_container.position.x = left_subviewport.size.x
	
	divider.position.x = left_subviewport.size.x - divider.size.x / 2.0
