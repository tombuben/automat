shader_type canvas_item;
// Turns everything under it into shades of green, so the items look locked behind glass.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// Darkest and lightest green. Everything underneath is mapped between these by brightness.
uniform vec4 dark_color : source_color = vec4(0.06, 0.26, 0.13, 1.0);
uniform vec4 light_color : source_color = vec4(0.58, 0.86, 0.55, 1.0);
// Pushes the brightness apart (above 1) or together (below 1).
uniform float contrast : hint_range(0.0, 3.0) = 1.2;
// Brightens (positive) or darkens (negative) before the colours are mapped.
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
// Number of flat shades. 0 = smooth.
uniform float steps : hint_range(0.0, 8.0, 1.0) = 4.0;
// Set by code: 0 = off, 1 = fully green.
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 under = texture(screen_texture, SCREEN_UV).rgb;
	float shade = dot(under, vec3(0.299, 0.587, 0.114));
	shade = clamp((shade - 0.5) * contrast + 0.5 + brightness, 0.0, 1.0);
	if (steps > 0.0) {
		shade = floor(shade * steps + 0.5) / steps;
	}
	vec3 green = mix(dark_color.rgb, light_color.rgb, shade);
	COLOR = vec4(mix(under, green, amount), 1.0);
}
