class_name ScreenResizer extends Control

@export var left_subviewport : SubViewport
@onready var left_subviewport_container : SubViewportContainer = left_subviewport.get_parent()
@export var right_subviewport : SubViewport
@onready var right_subviewport_container : SubViewportContainer = right_subviewport.get_parent()

@export var divider : ColorRect

var ratio : float

func _ready() -> void:
	GlobalManager.screen_resizer = self
	
	var viewport = get_viewport()
	ratio = left_subviewport.size.x / float(viewport.size.x)
	print(left_subviewport.size.x)
	print(viewport.size.x)
	print(ratio)

func _process(delta: float) -> void:
	var viewport = get_viewport()
	left_subviewport.size.x = ratio * float(viewport.size.x)
	
	right_subviewport.size.x = viewport.size.x - left_subviewport.size.x
	right_subviewport_container.position.x = left_subviewport.size.x
	
	divider.position.x = left_subviewport.size.x - divider.size.x / 2.0
