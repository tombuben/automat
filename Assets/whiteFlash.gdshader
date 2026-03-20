shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, depth_prepass_alpha;

uniform bool active = false;
uniform vec4 flash_color = vec4(1.0,1.0,1.0,1.0);
uniform sampler2D tex;

void fragment() {
    vec4 col = texture(tex, UV);

    if (active) {
        ALBEDO = flash_color.rgb;
    } else {
        ALBEDO = col.rgb;
    }

    ALPHA = col.a;
}