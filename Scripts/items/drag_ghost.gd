class_name DragGhost extends CanvasLayer
## Draws the dragged item above both panels. The real item stays hidden in the
## left viewport while dragging, because that viewport would clip it at its edge.

@export var follow_speed := 25.0
## How much bigger the item gets while it's over the right panel.
@export var over_view_scale := 1.1

@onready var view : SubViewportContainer = $View
@onready var camera : Camera3D = $View/SubViewport/Camera3D

var real_item : RandomItem
var ghost : RandomItem
var screen_position : Vector2
var base_scale : Vector3
var over_view := false


func _ready() -> void:
	GlobalManager.drag_ghost = self


func _process(delta : float) -> void:
	if ghost == null:
		return
	screen_position = screen_position.lerp(view.get_local_mouse_position(), 1.0 - exp(-follow_speed * delta))
	_place_ghost()

	var is_over_view : bool = GlobalManager.world_view.get_mouse_in_view() != null
	if is_over_view != over_view:
		over_view = is_over_view
		var tween := ghost.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(ghost, "scale", base_scale * (over_view_scale if over_view else 1.0), 0.2)


func show_item(item : RandomItem) -> void:
	real_item = item
	view.visible = true

	ghost = item.duplicate()
	ghost.freeze = true
	camera.get_parent().add_child(ghost)
	ghost.global_basis = item.global_basis
	base_scale = ghost.scale
	over_view = false

	# Match the size and position the item has on screen right now, so it doesn't pop.
	var source_viewport := GlobalManager.cursor_body.get_viewport()
	var source_container := source_viewport.get_parent() as SubViewportContainer
	var source_camera := source_viewport.get_camera_3d()
	var canvas_per_pixel : float = source_container.size.y / source_viewport.size.y
	var item_pixel := source_camera.unproject_position(item.global_position)
	var pixels_per_unit := item_pixel.distance_to(source_camera.unproject_position(item.global_position + Vector3.UP))
	camera.size = view.size.y / (pixels_per_unit * canvas_per_pixel)

	var to_view := view.get_global_transform_with_canvas().affine_inverse() * source_container.get_global_transform_with_canvas()
	screen_position = to_view * (item_pixel * canvas_per_pixel)
	_place_ghost()

	item.visible = false


func hide_item() -> void:
	if ghost == null:
		return
	ghost.queue_free()
	ghost = null
	real_item.visible = true
	real_item = null
	view.visible = false


func _place_ghost() -> void:
	ghost.global_position = camera.project_position(screen_position, camera.position.z)
