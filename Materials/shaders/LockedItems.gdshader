shader_type canvas_item;
// Turns everything under it into shades of green, so the items look locked behind glass.
// Each pixel's brightness picks a colour from the gradient: left = dark, right = bright.
// The gradient is set on the LockedItemsOverlay node.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform sampler2D gradient : filter_linear, repeat_disable;

// Pushes the brightness apart (above 1) or together (below 1) before picking a colour.
uniform float contrast : hint_range(0.0, 3.0) = 1.0;
// Brightens (positive) or darkens (negative) before picking a colour.
uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
// Number of flat shades. 0 = smooth.
uniform float steps : hint_range(0.0, 8.0, 1.0) = 0.0;
// 0 = original colours, 1 = fully green.
uniform float amount : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec3 under = texture(screen_texture, SCREEN_UV).rgb;
	float shade = dot(under, vec3(0.299, 0.587, 0.114));
	shade = clamp((shade - 0.5) * contrast + 0.5 + brightness, 0.0, 1.0);
	if (steps > 0.0) {
		shade = floor(shade * steps + 0.5) / steps;
	}
	vec3 green = texture(gradient, vec2(shade, 0.5)).rgb;
	COLOR = vec4(mix(under, green, amount), 1.0);
}
