shader_type spatial;

render_mode unshaded, cull_disabled, blend_mix;

uniform sampler2D albedo_texture : source_color;

uniform float sway_strength = 0.05;
uniform float sway_speed = 2.0;
uniform float sway_frequency = 4.0;

uniform float random_enabled = 0.0;
instance uniform float random_phase = 0.0;
instance uniform float random_strength = 1.0;

void vertex() {

	float h = clamp(VERTEX.y + 0.5, 0.0, 1.0);

	// IMPORTANT: avoid top edge entirely
	float height_mask = pow(smoothstep(0.0, 0.85, h), 2.5);

	float t = TIME * sway_speed;

	float wave = sin(t + h * sway_frequency);
	float rand_wave = sin(t * 0.7 + random_phase) * 0.5;

	wave = mix(wave, wave + rand_wave, random_enabled);

	float offset = wave * sway_strength * height_mask;

	VERTEX.x += offset;
}

void fragment() {

	// UV safety clamp (prevents edge sampling artifacts)
	vec2 uv = clamp(UV, vec2(0.001), vec2(0.999));

	vec4 tex = texture(albedo_texture, uv);

	ALBEDO = tex.rgb;
	ALPHA = tex.a;
}