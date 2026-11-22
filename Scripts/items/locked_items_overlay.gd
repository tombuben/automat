class_name LockedItemsOverlay extends MeshInstance3D
## Marks the automat's item window. During dialogue the window turns green
## (LockedItems.gdshader) so the items look out of reach.
## Move and resize this quad in the editor to fit the window; it's hidden in game.

const SHADER := preload("res://Materials/shaders/LockedItems.gdshader")

@export var fade_in_time := 0.3
@export var fade_out_time := 0.3

## 0 = off, 1 = fully green.
var amount := 0.0
var shape : Polygon2D


func _ready() -> void:
	visible = false


func _process(delta : float) -> void:
	var cursor := GlobalManager.cursor_body
	if cursor == null:
		return
	if shape == null:
		_create_shape(cursor.get_viewport())

	var locked := cursor.in_dialogue
	var fade_time := fade_in_time if locked else fade_out_time
	amount = move_toward(amount, 1.0 if locked else 0.0, delta / max(fade_time, 0.001))
	shape.material.set_shader_parameter("amount", amount)
	shape.visible = amount > 0.0
	if shape.visible:
		_follow_quad()


## Drawn in the automat view's 2D layer, so the shader can read the finished 3D image under it.
func _create_shape(automat_viewport : Viewport) -> void:
	shape = Polygon2D.new()
	shape.name = "LockedItemsShape"
	shape.material = ShaderMaterial.new()
	shape.material.shader = SHADER
	automat_viewport.add_child(shape)
	tree_exiting.connect(shape.queue_free)


func _follow_quad() -> void:
	var camera := shape.get_viewport().get_camera_3d()
	var half : Vector2 = (mesh as QuadMesh).size / 2.0
	var corners := PackedVector2Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var point := global_transform * Vector3(corner.x * half.x, corner.y * half.y, 0.0)
		corners.append(camera.unproject_position(point))
	shape.polygon = corners
