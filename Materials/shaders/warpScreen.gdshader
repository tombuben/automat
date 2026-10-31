shader_type canvas_item;

uniform sampler2D screen_tex : hint_default_black, filter_linear;

uniform float strength : hint_range(-1.0, 1.0) = 0.2;
uniform float radius : hint_range(0.0, 1.0) = 0.6;
uniform float softness : hint_range(0.01, 1.0) = 0.4;
uniform float falloff : hint_range(0.5, 4.0) = 2.0;

void fragment() {
    vec2 uv = UV;

    vec2 center = vec2(0.5);
    vec2 dir = uv - center;

    float dist = length(dir);

    // Smooth mask (stable version)
    float mask = smoothstep(radius, radius - softness, dist);

    // Stable falloff (prevents jitter)
    float influence = pow(clamp(dist, 0.0, 1.0), falloff);

    // Apply distortion
    vec2 offset = dir * influence * mask * strength;

    vec2 warped_uv = uv + offset;

    // 🔥 CRITICAL: clamp to prevent flicker
    warped_uv = clamp(warped_uv, 0.001, 0.999);

    COLOR = texture(screen_tex, warped_uv);
}