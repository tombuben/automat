shader_type spatial;

render_mode unshaded, cull_front, depth_draw_opaque;

uniform vec4 outline_color : source_color = vec4(0.0,0.0,0.0,1.0);
uniform float outline_size : hint_range(0.0,10.0) = 2.0;

void vertex() {

	// transform vertex normally
	vec4 clip_pos = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);

	// transform normal to view space
	vec3 view_normal = normalize((MODELVIEW_MATRIX * vec4(NORMAL,0.0)).xyz);

	// push vertex in screen space
	clip_pos.xy += view_normal.xy * outline_size * clip_pos.w / VIEWPORT_SIZE;

	POSITION = clip_pos;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}