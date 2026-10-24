shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;
// 3D version of wobble.gdshader, for Sprite3D / AnimatedSprite3D.
// Use it through wobble_sprite_3d.gd (attach that script to the sprite):
// the script feeds the current animation frame into `sprite_texture`.
// Leave some transparent space around each frame so the edges have room to move.

uniform sampler2D sprite_texture : source_color, filter_linear;
// Copied from the sprite's Billboard setting by the script.
uniform bool billboard = true;

// How far the edges wobble, in texture pixels.
uniform float wobble_amount : hint_range(0.0, 10.0) = 2.0;
// How many times per second the wobble jumps to a new shape (low = hand-drawn feel).
uniform float boil_fps : hint_range(0.0, 30.0) = 8.0;
// Size of the wobble "bumps" (smaller = bigger, smoother bumps).
uniform float wobble_scale : hint_range(0.005, 0.5) = 0.06;
// Gentle continuous wave on top of the boil, in texture pixels.
uniform float wave_amount : hint_range(0.0, 10.0) = 0.6;
uniform float wave_speed : hint_range(0.0, 10.0) = 2.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
	           mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	if (billboard) {
		// Face the camera, keep the node's position and scale
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
			INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
			vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
			vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
			vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
			vec4(0.0, 0.0, 0.0, 1.0));
		MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	}
}

void fragment() {
	vec2 tex_size = vec2(textureSize(sprite_texture, 0));
	vec2 px = UV * tex_size;                          // position in texture pixels
	float frame = boil_fps > 0.0 ? floor(TIME * boil_fps) : 0.0;
	vec2 seed = vec2(frame * 17.31, frame * 9.71);

	vec2 boil = vec2(noise(px * wobble_scale + seed),
	                 noise(px * wobble_scale + seed + 41.7)) - 0.5;
	vec2 wave = vec2(sin(px.y * 0.08 + TIME * wave_speed),
	                 cos(px.x * 0.08 + TIME * wave_speed * 1.3));

	vec2 offset = (boil * 2.0 * wobble_amount + wave * wave_amount) / tex_size;
	vec4 c = texture(sprite_texture, UV + offset);
	ALBEDO = c.rgb * COLOR.rgb;   // COLOR = the sprite's Modulate
	ALPHA = c.a * COLOR.a;
}
