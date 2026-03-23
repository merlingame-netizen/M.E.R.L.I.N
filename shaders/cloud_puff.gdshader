shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 cloud_color : source_color = vec4(0.95, 0.97, 1.0, 0.5);
uniform float cloud_speed : hint_range(0.0, 2.0) = 0.3;
uniform float cloud_density : hint_range(0.0, 2.0) = 1.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p *= 2.0;
        a *= 0.5;
    }
    return v;
}

void fragment() {
    vec2 uv = UV * 2.0 - 1.0; // Center UV

    // Soft circular falloff
    float dist = length(uv);
    float circle = 1.0 - smoothstep(0.4, 1.0, dist);

    // Animated noise for cloud shape
    float n = fbm(uv * 1.5 + TIME * cloud_speed * 0.1);
    float cloud_shape = circle * n * cloud_density;
    cloud_shape = smoothstep(0.15, 0.5, cloud_shape);

    ALBEDO = cloud_color.rgb;
    ALPHA = cloud_shape * cloud_color.a;
}
