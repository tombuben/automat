shader_type spatial;

render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// Credit:
// Original fog shader by Gonkee
// Adapted for Sprite3D / QuadMesh in Godot 4 spatial shaders

uniform vec4 color : source_color = vec4(0.8, 0.9, 1.0, 0.5);

uniform int OCTAVES = 4;

uniform bool enable_pixelation = true;
uniform int pixelation_amount = 150;

uniform sampler2D fog_mask;

uniform vec2 fog_direction = vec2(1.0, 1.0);

uniform bool scroll_noise_tex = false;
uniform vec2 noise_scroll_direction = vec2(1.0, 0.0);

uniform float fog_scale = 20.0;

float rand(vec2 coord){
    return fract(sin(dot(coord, vec2(56.0, 78.0)) * 1000.0) * 1000.0);
}

float noise(vec2 coord){
    vec2 i = floor(coord);
    vec2 f = fract(coord);

    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));

    vec2 cubic = f * f * (3.0 - 2.0 * f);

    return mix(a, b, cubic.x)
        + (c - a) * cubic.y * (1.0 - cubic.x)
        + (d - b) * cubic.x * cubic.y;
}

float fbm(vec2 coord){
    float value = 0.0;
    float scale = 0.5;

    for(int i = 0; i < OCTAVES; i++){
        value += noise(coord) * scale;
        coord *= 2.0;
        scale *= 0.5;
    }

    return value;
}

void fragment() {

    vec2 grid_uv = UV;

    // Pixelation
    if (enable_pixelation) {
        grid_uv = round(UV * float(pixelation_amount))
                / float(pixelation_amount);
    }

    vec2 coord = grid_uv * fog_scale;

    // Optional scrolling
    if (scroll_noise_tex) {
        coord += noise_scroll_direction * TIME;
    }
   // Animated motion distortion
    vec2 motion = vec2(
        fbm(coord + fog_direction * TIME)
    );

    float final = fbm(coord + motion);

    // Fog mask texture
    float mask_value = texture(fog_mask, UV).r;

    final *= mask_value;

    ALBEDO = color.rgb;
    ALPHA = final * color.a * 0.5;
}