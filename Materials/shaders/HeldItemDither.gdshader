shader_type canvas_item;
// Draws the item held in the world view hands, dithered while aiming so you can see through it.

// How much of the item is drawn while aiming. 1 = solid, 0 = invisible.
uniform float opacity : hint_range(0.0, 1.0) = 0.5;
// Size of one dither dot in pixels.
uniform float dot_size : hint_range(1.0, 8.0, 1.0) = 2.0;
// Keeps a solid edge this many pixels wide so the item's shape still reads. 0 = off.
uniform float edge_width : hint_range(0.0, 8.0, 1.0) = 0.0;
// Set by code: 0 = not aiming (solid), 1 = aiming (dithered).
uniform float aim_amount : hint_range(0.0, 1.0) = 1.0;

// Ordered 4x4 Bayer pattern, values 0..1.
float bayer2(vec2 a) {
	a = floor(a);
	return fract(dot(a, vec2(0.5, a.y * 0.75)));
}

float bayer4(vec2 a) {
	return bayer2(0.5 * a) * 0.25 + bayer2(a);
}

void fragment() {
	vec4 color = texture(TEXTURE, UV);
	float shown = mix(1.0, opacity, aim_amount);
	bool keep = bayer4(FRAGCOORD.xy / dot_size) < shown;

	if (!keep && edge_width > 0.0) {
		vec2 step_size = edge_width * TEXTURE_PIXEL_SIZE;
		float least_alpha = min(
			min(texture(TEXTURE, UV + vec2(step_size.x, 0.0)).a, texture(TEXTURE, UV - vec2(step_size.x, 0.0)).a),
			min(texture(TEXTURE, UV + vec2(0.0, step_size.y)).a, texture(TEXTURE, UV - vec2(0.0, step_size.y)).a));
		keep = least_alpha < 0.5;
	}

	COLOR = keep ? color : vec4(0.0);
}
