class_name LockedItemsOverlay extends MeshInstance3D
## Marks the automat's item window, which is always drawn in shades of green
## (LockedItems.gdshader). The item under the mouse is drawn on top in its real colours.
## Move and resize this quad in the editor to fit the window; it's hidden in game.

const SHADER := preload("res://Materials/shaders/LockedItems.gdshader")
## Render layer for the item drawn in colour. Nothing else should use it.
const COLOUR_LAYER := 19

## Brightness of what's under the window (left = dark, right = bright) mapped to these colours.
@export var gradient : Gradient
## Corners drawn around the hovered item, on top of everything in the automat view.
@export var hover_frame_scene : PackedScene = preload("res://Prefabs/hover_frame.tscn")

var shape : Polygon2D
var automat_camera : Camera3D
var colour_viewport : SubViewport
var colour_camera : Camera3D
var coloured_item : Node3D


func _ready() -> void:
	visible = false


func _process(_delta : float) -> void:
	var cursor := GlobalManager.cursor_body
	if cursor == null:
		return
	if shape == null:
		_create_views(cursor.get_viewport())

	_follow_quad()
	_copy_camera()

	var hovered : Node3D = null
	if not cursor.in_dialogue and not cursor.dragging:
		hovered = cursor.moused_over_item
	if hovered != coloured_item:
		_set_coloured(coloured_item, false)
		coloured_item = hovered
		_set_coloured(coloured_item, true)


## Both are drawn in the automat view's 2D layer, on top of its 3D image:
## first the green window, then the coloured item over it.
func _create_views(automat_viewport : SubViewport) -> void:
	automat_camera = automat_viewport.get_camera_3d()
	automat_camera.cull_mask &= ~_layer_bit()

	shape = Polygon2D.new()
	shape.name = "LockedItemsShape"
	shape.material = ShaderMaterial.new()
	shape.material.shader = SHADER
	var gradient_texture := GradientTexture1D.new()
	gradient_texture.gradient = gradient
	shape.material.set_shader_parameter("gradient", gradient_texture)
	automat_viewport.add_child(shape)

	var colour_view := TextureRect.new()
	colour_view.name = "ColouredItemView"
	colour_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colour_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	colour_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	colour_viewport = SubViewport.new()
	colour_viewport.transparent_bg = true
	colour_viewport.msaa_3d = automat_viewport.msaa_3d
	colour_camera = Camera3D.new()
	colour_camera.cull_mask = _layer_bit()
	colour_viewport.add_child(colour_camera)
	colour_view.add_child(colour_viewport)
	colour_view.texture = colour_viewport.get_texture()
	automat_viewport.add_child(colour_view)

	tree_exiting.connect(shape.queue_free)
	tree_exiting.connect(colour_view.queue_free)
	if hover_frame_scene:
		var hover_frame := hover_frame_scene.instantiate()
		automat_viewport.add_child(hover_frame)
		tree_exiting.connect(hover_frame.queue_free)


func _follow_quad() -> void:
	var half : Vector2 = (mesh as QuadMesh).size / 2.0
	var corners := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var point := global_transform * Vector3(corner.x * half.x, corner.y * half.y, 0.0)
		corners.append(automat_camera.unproject_position(point))
	shape.polygon = corners


func _copy_camera() -> void:
	colour_viewport.size = automat_camera.get_viewport().size
	colour_camera.global_transform = automat_camera.global_transform
	colour_camera.projection = automat_camera.projection
	colour_camera.fov = automat_camera.fov
	colour_camera.size = automat_camera.size
	colour_camera.near = automat_camera.near
	colour_camera.far = automat_camera.far
	colour_camera.keep_aspect = automat_camera.keep_aspect
	colour_camera.h_offset = automat_camera.h_offset
	colour_camera.v_offset = automat_camera.v_offset
	colour_camera.environment = automat_camera.environment


static func _layer_bit() -> int:
	return 1 << (COLOUR_LAYER - 1)


## Moves the item to the colour layer, so only the colour view draws it, or back.
func _set_coloured(item : Node3D, coloured : bool) -> void:
	if item == null or not is_instance_valid(item):
		return
	for visual in item.find_children("*", "VisualInstance3D", true, false) + [item]:
		if not visual is VisualInstance3D:
			continue
		if coloured:
			visual.set_meta("layers_before_colour", visual.layers)
			visual.layers = _layer_bit()
		elif visual.has_meta("layers_before_colour"):
			visual.layers = visual.get_meta("layers_before_colour")
			visual.remove_meta("layers_before_colour")
