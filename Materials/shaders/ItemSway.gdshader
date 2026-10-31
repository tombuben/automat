shader_type spatial;

uniform float sway_amount = 0.02;
uniform float random_phase = 0.0;

void vertex() {
    float angle =
        (
            sin(TIME * 0.31 + random_phase)
            + sin(TIME * 0.17 + random_phase * 1.7)
        )
        * sway_amount;

    vec3 v = VERTEX;

    // pivot point near the bottom of the model
    v.y += 0.5;

    float c = cos(angle);
    float s = sin(angle);

    vec2 rotated;
    rotated.x = v.x * c - v.y * s;
    rotated.y = v.x * s + v.y * c;

    v.xy = rotated;

    v.y -= 0.5;

    // tiny vertical movement
    v.y += sin(TIME * 0.23 + random_phase) * 0.005;

    VERTEX = v;
}