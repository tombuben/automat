shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
// Darkens everything behind it, except a rectangle cut out of it (the item window).

uniform vec4 color : source_color = vec4(0.0, 0.0, 0.0, 0.55);
// The cut-out in the quad's own space: min x, min y, max x, max y. Set by code.
uniform vec4 hole = vec4(0.0);

varying vec2 local_position;

void vertex() {
	local_position = VERTEX.xy;
}

void fragment() {
	if (all(greaterThan(local_position, hole.xy)) && all(lessThan(local_position, hole.zw))) {
		discard;
	}
	ALBEDO = color.rgb;
	ALPHA = color.a;
}
