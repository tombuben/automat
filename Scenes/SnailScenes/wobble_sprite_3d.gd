@tool
extends SpriteBase3D
## Attach to a Sprite3D or AnimatedSprite3D to make it wobble like the textbox.
## Adds wobble_3d.gdshader as the Material Override if none is set; tweak the
## wobble in Geometry > Material Override > Shader Parameters.
## Works in the editor too, so you can preview it.

const WOBBLE_SHADER := preload("wobble_3d.gdshader")

var _last_tex: Texture2D


func _ready():
	_ensure_material()
	_sync()


func _process(_delta):
	_sync()


func _ensure_material():
	if material_override is ShaderMaterial:
		return
	var m := ShaderMaterial.new()
	m.shader = WOBBLE_SHADER
	material_override = m


func _current_texture() -> Texture2D:
	var me: Node = self
	if me is AnimatedSprite3D:
		var a: AnimatedSprite3D = me
		if a.sprite_frames and a.sprite_frames.has_animation(a.animation):
			return a.sprite_frames.get_frame_texture(a.animation, a.frame)
		return null
	return get("texture")


func _sync():
	var mat := material_override as ShaderMaterial
	if mat == null:
		return
	mat.set_shader_parameter("billboard", billboard != BaseMaterial3D.BILLBOARD_DISABLED)
	var tex := _current_texture()
	if tex == _last_tex:
		return
	_last_tex = tex
	# A frame cut from a spritesheet is an AtlasTexture: the sprite's UVs
	# already point into the full sheet, so hand the shader the whole sheet.
	while tex is AtlasTexture:
		tex = (tex as AtlasTexture).atlas
	mat.set_shader_parameter("sprite_texture", tex)
