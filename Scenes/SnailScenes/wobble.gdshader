shader_type canvas_item;
// Hand-drawn "boil" wobble for any sprite / NinePatchRect / TextureRect.
// Leave some transparent space around the image so the edges have room to move.

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

void fragment() {
	vec2 px = UV / TEXTURE_PIXEL_SIZE;               // position in texture pixels
	float frame = boil_fps > 0.0 ? floor(TIME * boil_fps) : 0.0;
	vec2 seed = vec2(frame * 17.31, frame * 9.71);

	vec2 boil = vec2(noise(px * wobble_scale + seed),
	                 noise(px * wobble_scale + seed + 41.7)) - 0.5;
	vec2 wave = vec2(sin(px.y * 0.08 + TIME * wave_speed),
	                 cos(px.x * 0.08 + TIME * wave_speed * 1.3));

	vec2 offset = (boil * 2.0 * wobble_amount + wave * wave_amount) * TEXTURE_PIXEL_SIZE;
	COLOR = texture(TEXTURE, UV + offset) * COLOR;
}
