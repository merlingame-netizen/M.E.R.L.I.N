shader_type canvas_item;

uniform vec2 press_uv = vec2(0.5, 0.5);
uniform float press_strength = 0.0;
uniform float press_radius = 0.23;

void fragment() {
    vec2 uv = UV;
    float dist = distance(uv, press_uv);
    float falloff = smoothstep(press_radius, 0.0, dist);
    float strength = press_strength * falloff * 0.08;
    vec2 dir = (uv - press_uv) / max(dist, 0.0001);
    uv -= dir * strength;
    COLOR = texture(TEXTURE, uv) * COLOR;
}
