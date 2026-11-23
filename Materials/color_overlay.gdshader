shader_type canvas_item;

// Everything drawn behind this ColorRect (your 3D scene, etc.)
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

// 0 = Multiply, 1 = Overlay, 2 = Soft Light
uniform int blend_mode : hint_enum("Multiply", "Overlay", "Soft Light") = 1;

// Blend layer: a flat color, optionally times a tiling texture (paper, grain, noise...)
uniform vec4 blend_color : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform bool use_texture = false;
uniform sampler2D blend_texture : source_color, repeat_enable, filter_linear;
uniform float texture_scale = 1.0; // 1.0 = texture's native pixel size on screen

uniform float strength : hint_range(0.0, 1.0) = 1.0;

vec3 blend_multiply(vec3 base, vec3 b) {
	return base * b;
}

vec3 blend_overlay(vec3 base, vec3 b) {
	vec3 low = 2.0 * base * b;
	vec3 high = 1.0 - 2.0 * (1.0 - base) * (1.0 - b);
	return mix(low, high, step(0.5, base));
}

vec3 blend_soft_light(vec3 base, vec3 b) {
	// Pegtop soft light: gentler than overlay, no hard edge at 0.5
	return (1.0 - 2.0 * b) * base * base + 2.0 * b * base;
}

void fragment() {
	vec3 base = texture(screen_tex, SCREEN_UV).rgb;

	vec4 layer = blend_color;
	if (use_texture) {
		vec2 tex_size = vec2(textureSize(blend_texture, 0));
		vec2 tex_uv = FRAGCOORD.xy / (tex_size * texture_scale);
		layer *= texture(blend_texture, tex_uv);
	}

	vec3 result;
	if (blend_mode == 0) {
		result = blend_multiply(base, layer.rgb);
	} else if (blend_mode == 1) {
		result = blend_overlay(base, layer.rgb);
	} else {
		result = blend_soft_light(base, layer.rgb);
	}

	// layer alpha and strength both fade the effect
	COLOR = vec4(mix(base, result, strength * layer.a), 1.0);
}