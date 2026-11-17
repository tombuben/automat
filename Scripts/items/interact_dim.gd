class_name InteractDim extends MeshInstance3D
## Darkens the automat while the player can drag and shoot items, and fades out for dialogue.
## Place it between the automat sprites and the items: whatever is in front stays lit.
## How dark it gets is the alpha of its material's albedo colour.

@export var fade_in_time := 0.5
@export var fade_out_time := 0.25

## 0 = hidden, 1 = fully dark.
var amount := 0.0
var dim_material : StandardMaterial3D
var max_alpha : float


func _ready() -> void:
	# Its own copy, so fading doesn't change the material saved in the scene.
	dim_material = mesh.surface_get_material(0).duplicate()
	material_override = dim_material
	max_alpha = dim_material.albedo_color.a
	_apply()


func _process(delta : float) -> void:
	var cursor := GlobalManager.cursor_body
	var interactive := cursor != null and not cursor.in_dialogue
	var fade_time := fade_in_time if interactive else fade_out_time
	amount = move_toward(amount, 1.0 if interactive else 0.0, delta / max(fade_time, 0.001))
	_apply()


func _apply() -> void:
	dim_material.albedo_color.a = max_alpha * amount
	visible = amount > 0.0
