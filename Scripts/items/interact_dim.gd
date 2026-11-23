class_name InteractDim extends MeshInstance3D
## Darkens the automat while it can't be used (during dialogue), and fades out when the player can drag and shoot again.
## Place it between the automat sprites and the items: whatever is in front stays lit.
## How dark it gets is the alpha of its material's albedo colour.

const SHADER := preload("res://Materials/shaders/InteractDim.gdshader")

## This quad's area is left out of the darkening (the item window, which turns green instead).
@export var cut_out : MeshInstance3D
@export var fade_in_time := 0.5
@export var fade_out_time := 0.25

## 0 = hidden, 1 = fully dark.
var amount := 0.0
var dim_material : ShaderMaterial
var color : Color


func _ready() -> void:
	color = (mesh.surface_get_material(0) as BaseMaterial3D).albedo_color
	dim_material = ShaderMaterial.new()
	dim_material.shader = SHADER
	dim_material.set_shader_parameter("hole", _get_hole())
	material_override = dim_material
	_apply()


func _process(delta : float) -> void:
	var cursor := GlobalManager.cursor_body
	var locked := cursor != null and cursor.in_dialogue
	var fade_time := fade_in_time if locked else fade_out_time
	amount = move_toward(amount, 1.0 if locked else 0.0, delta / max(fade_time, 0.001))
	_apply()


func _apply() -> void:
	dim_material.set_shader_parameter("color", Color(color, color.a * amount))
	visible = amount > 0.0


func _get_hole() -> Vector4:
	if cut_out == null or not cut_out.mesh is QuadMesh:
		return Vector4.ZERO
	var half : Vector2 = (cut_out.mesh as QuadMesh).size / 2.0
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for corner in [Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1)]:
		var point := to_local(cut_out.global_transform * Vector3(corner.x * half.x, corner.y * half.y, 0.0))
		low = low.min(Vector2(point.x, point.y))
		high = high.max(Vector2(point.x, point.y))
	return Vector4(low.x, low.y, high.x, high.y)
