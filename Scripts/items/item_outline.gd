class_name ItemOutline
## Gives an item an even outline (Materials/shaders/OutlineShader.gdshader).
##
## Every mesh under the item draws the outline material as its material_overlay, so the outline
## is the item's own mesh, drawn again back faces only and pushed outward by a fixed number of
## pixels. No scaled copies to line up by hand, and it hides behind other objects with the item.
##
## Meshes with hard edges store each corner as several vertices with different normals, which
## would push apart and open gaps in the outline. So the mesh is swapped for a copy that also
## carries a smoothed normal per position in CUSTOM0, which the shader pushes along instead.
##
## Where the shape curves inward (a duck's neck), the pushed-out back faces would show as a line
## across the item itself. So the item's materials write STENCIL_REF into the stencil buffer, and the
## outline only draws where that value isn't: around the item, never on top of it.

const OUTLINE_MATERIAL := preload("res://Materials/materials/OutlineShaderMat.tres")
## Must match the reference value in OutlineShader.gdshader.
const STENCIL_REF := 1

## Smoothed copies, keyed by source mesh, so every instance of an item shares one copy.
static var _smoothed_meshes := {}
## Stencil-writing copies of the item materials, keyed by the original material.
static var _stencil_materials := {}


## Adds the outline to every MeshInstance3D under root, including ones inside imported models.
static func apply(root: Node, material: Material = OUTLINE_MATERIAL) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		mesh_instance.mesh = get_smoothed_mesh(mesh_instance.mesh)
		mesh_instance.material_overlay = material
		if mesh_instance.material_override != null:
			mesh_instance.material_override = get_stencil_material(mesh_instance.material_override)
		for surface in mesh_instance.get_surface_override_material_count():
			var override := mesh_instance.get_surface_override_material(surface)
			if override != null:
				mesh_instance.set_surface_override_material(surface, get_stencil_material(override))


## Returns a copy of source with smoothed normals in CUSTOM0 (cached), or source itself if it
## can't be converted (blend shapes) or already is a smoothed copy.
static func get_smoothed_mesh(source: Mesh) -> Mesh:
	if _smoothed_meshes.has(source):
		return _smoothed_meshes[source]
	if source.has_meta(&"outline_smoothed"):
		return source
	if source is ArrayMesh and (source as ArrayMesh).get_blend_shape_count() > 0:
		return source

	# Vertices closer than this count as the same position. Relative to the mesh size, because
	# some imported meshes are tiny and scaled up hundreds of times by their node.
	var tolerance := maxf(source.get_aabb().get_longest_axis_size() * 0.0001, 0.0000001)

	var result := ArrayMesh.new()
	for surface in source.get_surface_count():
		var arrays := source.surface_get_arrays(surface)
		var primitive := Mesh.PRIMITIVE_TRIANGLES
		if source is ArrayMesh:
			primitive = (source as ArrayMesh).surface_get_primitive_type(surface)

		var flags := 0
		if arrays[Mesh.ARRAY_NORMAL] != null and arrays[Mesh.ARRAY_CUSTOM0] == null:
			arrays[Mesh.ARRAY_CUSTOM0] = _smoothed_normals(arrays[Mesh.ARRAY_VERTEX], arrays[Mesh.ARRAY_NORMAL], tolerance)
			flags = Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT

		result.add_surface_from_arrays(primitive, arrays, [], {}, flags)
		result.surface_set_material(surface, get_stencil_material(source.surface_get_material(surface)))

	if source is ArrayMesh:
		result.shadow_mesh = (source as ArrayMesh).shadow_mesh
	result.resource_name = source.resource_name
	result.set_meta(&"outline_smoothed", true)
	_smoothed_meshes[source] = result
	return result


## Returns a copy of material that also writes STENCIL_REF into the stencil buffer (cached).
## ShaderMaterials can't be changed this way; on those the outline may cross the item.
static func get_stencil_material(material: Material) -> Material:
	if not material is BaseMaterial3D:
		return material
	if _stencil_materials.has(material):
		return _stencil_materials[material]
	if material.has_meta(&"outline_stencil"):
		return material
	var copy := material.duplicate() as BaseMaterial3D
	copy.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	copy.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	copy.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	copy.stencil_reference = STENCIL_REF
	copy.set_meta(&"outline_stencil", true)
	_stencil_materials[material] = copy
	return copy


## For each vertex, the average of the distinct normals found at its position, as flat RGB floats.
static func _smoothed_normals(vertices: PackedVector3Array, normals: PackedVector3Array, tolerance: float) -> PackedFloat32Array:
	var snap := Vector3.ONE * tolerance

	# Distinct normals per position. Duplicates (UV seams) are skipped so they don't weigh more.
	var normals_at := {}
	for i in vertices.size():
		var key := vertices[i].snapped(snap)
		var list: Array = normals_at.get(key, [])
		var normal := normals[i]
		var already_listed := false
		for other: Vector3 in list:
			if other.dot(normal) > 0.999:
				already_listed = true
				break
		if not already_listed:
			list.append(normal)
			normals_at[key] = list

	var averaged := {}
	for key: Vector3 in normals_at:
		var sum := Vector3.ZERO
		for normal: Vector3 in normals_at[key]:
			sum += normal
		averaged[key] = sum

	var out := PackedFloat32Array()
	out.resize(vertices.size() * 3)
	for i in vertices.size():
		var sum: Vector3 = averaged[vertices[i].snapped(snap)]
		# Opposite normals (both sides of a thin sheet) cancel out; keep the original then.
		var smooth := sum.normalized() if sum.length() > 0.001 else normals[i]
		out[i * 3] = smooth.x
		out[i * 3 + 1] = smooth.y
		out[i * 3 + 2] = smooth.z
	return out
