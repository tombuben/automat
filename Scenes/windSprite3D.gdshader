shader_type spatial;

render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D albedo_texture : source_color;

uniform float wind_strength : hint_range(0.0, 1.0) = 0.15;
uniform float wind_speed : hint_range(0.0, 5.0) = 1.2;
uniform float wind_scale : hint_range(0.0, 10.0) = 2.0;

void vertex() {
	float height_mask = UV.y;

	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	float wind =
		sin(world_pos.x * wind_scale + TIME * wind_speed) +
		cos(world_pos.z * wind_scale + TIME * wind_speed);

	wind *= 0.5;

	VERTEX.x += wind * height_mask * wind_strength;
	VERTEX.z += wind * height_mask * wind_strength * 0.3;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}