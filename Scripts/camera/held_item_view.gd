class_name HeldItemView extends TextureRect
## Draws the item in the world view hands through its own camera, on top of the
## world view, so HeldItemDither.gdshader can dither it without touching its materials.

const HELD_LAYER := 20
const DITHER_SHADER := preload("res://Materials/shaders/HeldItemDither.gdshader")

var world_view : WorldView
var viewport : SubViewport
var camera : Camera3D
## 0 = solid, 1 = dithered. Follows whether the mouse is aiming in the world view.
var aim_amount := 0.0
var aim_fade_speed := 8.0


static func layer_bit() -> int:
	return 1 << (HELD_LAYER - 1)


func _init(view : WorldView) -> void:
	world_view = view
	name = "HeldItemView"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	stretch_mode = TextureRect.STRETCH_SCALE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Runs after the world view has moved the camera this frame.
	process_priority = 1000

	viewport = SubViewport.new()
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)

	camera = Camera3D.new()
	camera.cull_mask = layer_bit()
	viewport.add_child(camera)

	texture = viewport.get_texture()
	material = ShaderMaterial.new()
	material.shader = DITHER_SHADER


func _ready() -> void:
	var main_viewport := world_view.get_viewport() as SubViewport
	viewport.msaa_3d = main_viewport.msaa_3d
	viewport.screen_space_aa = main_viewport.screen_space_aa
	camera.environment = world_view.environment


func _process(delta : float) -> void:
	viewport.size = world_view.get_viewport().size
	camera.global_transform = world_view.global_transform
	camera.projection = world_view.projection
	camera.fov = world_view.fov
	camera.size = world_view.size
	camera.near = world_view.near
	camera.far = world_view.far
	camera.keep_aspect = world_view.keep_aspect
	camera.h_offset = world_view.h_offset
	camera.v_offset = world_view.v_offset

	var aiming := world_view.get_mouse_in_view() != null
	aim_amount = move_toward(aim_amount, 1.0 if aiming else 0.0, delta * aim_fade_speed)
	material.set_shader_parameter("aim_amount", aim_amount)


## Moves every visual part of the item to the held layer, so only this view draws it.
func hold(item : Node) -> void:
	for visual in _get_visuals(item):
		visual.set_meta("layers_before_hold", visual.layers)
		visual.layers = layer_bit()


func release(item : Node) -> void:
	for visual in _get_visuals(item):
		if visual.has_meta("layers_before_hold"):
			visual.layers = visual.get_meta("layers_before_hold")
			visual.remove_meta("layers_before_hold")


func _get_visuals(node : Node) -> Array[VisualInstance3D]:
	var visuals : Array[VisualInstance3D] = []
	if node is VisualInstance3D:
		visuals.append(node)
	for child in node.get_children():
		visuals.append_array(_get_visuals(child))
	return visuals
