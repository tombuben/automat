shader_type canvas_item;

uniform float speed = 2.0;
uniform float strength = 0.02;

void vertex() {
    float wave = sin(TIME * speed);
    float influence = 1.0 - UV.y;

    VERTEX.y += wave * strength * influence;
}