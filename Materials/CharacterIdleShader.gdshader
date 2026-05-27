shader_type canvas_item;

uniform float amount = 0.03;
uniform float speed = 2.0;

void vertex() {
    float pulse = sin(TIME * speed) * amount;

    VERTEX.x *= 1.0 + pulse;
    VERTEX.y *= 1.0 - pulse;
}