shader_type canvas_item;

uniform sampler2D bg_tex : repeat_enable;
uniform vec2 scroll_speed = vec2(0.1, 0.0);
uniform vec2 texture_scale = vec2(4.0, 4.0);

void fragment() {
    vec2 uv = UV * texture_scale;
    uv += scroll_speed * TIME;

    COLOR = texture(bg_tex, uv);
}