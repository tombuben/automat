shader_type canvas_item;

render_mode unshaded, blend_add;

uniform sampler2D noise_tex;
uniform sampler2D noise_tex2;

// movement
uniform vec2 direction1 = vec2(0.02, 0.01);
uniform vec2 direction2 = vec2(-0.01, 0.015);

uniform float speed1 = 0.02;
uniform float speed2 = 0.01;

// tiling
uniform float scale1 = 3.0;
uniform float scale2 = 1.5;

// look
uniform float intensity = 0.25;
uniform vec3 dust_color : source_color = vec3(1.0);

// shaping
uniform float threshold = 0.6;
uniform float softness = 0.2;
uniform float contrast = 1.5;

uniform float layer2_strength = 0.5;
uniform float flicker = 0.05;

float get_dust(sampler2D tex, vec2 uv, float t, float s) {
    float n = texture(tex, uv).r;
    n = pow(n, contrast);
    return smoothstep(t, t + s, n);
}

void fragment() {
    vec2 uv1 = UV * scale1;
    vec2 uv2 = UV * scale2;

    uv1 += TIME * direction1 * speed1;
    uv2 += TIME * direction2 * speed2;

    uv1 = fract(uv1);
    uv2 = fract(uv2);

    float dust1 = get_dust(noise_tex, uv1, threshold, softness);
    float dust2 = get_dust(noise_tex2, uv2, threshold * 0.8, softness * 1.2);

    float dust = dust1 + dust2 * layer2_strength;

    dust *= 1.0 + sin(TIME * 12.0) * flicker;

    vec3 col = dust_color * dust * intensity;

    COLOR = vec4(col, dust * intensity);
}