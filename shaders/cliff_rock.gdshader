shader_type spatial;
render_mode cull_back;

uniform vec4 rock_color_1 : source_color = vec4(0.38, 0.32, 0.24, 1.0);
uniform vec4 rock_color_2 : source_color = vec4(0.30, 0.25, 0.18, 1.0);
uniform vec4 moss_color : source_color = vec4(0.22, 0.38, 0.15, 1.0);
uniform float moss_amount : hint_range(0.0, 1.0) = 0.3;
uniform float roughness_val : hint_range(0.0, 1.0) = 0.95;

// Simple hash noise
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
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

void vertex() {
    // Subtle vertex displacement for rocky surface
    float n = noise(VERTEX.xz * 2.0) * 0.15;
    VERTEX.z += n * NORMAL.z;
    VERTEX.x += n * NORMAL.x;
}

void fragment() {
    // Rock color variation based on UV position
    float rock_noise = noise(UV * 8.0);
    vec3 rock = mix(rock_color_1.rgb, rock_color_2.rgb, rock_noise);

    // Moss on top-facing surfaces and crevices
    float moss_mask = smoothstep(0.4, 0.7, noise(UV * 4.0 + vec2(0.0, 3.7)));
    // More moss higher up (UV.y ~ 0 = top)
    moss_mask *= smoothstep(0.6, 0.2, UV.y) * moss_amount;
    rock = mix(rock, moss_color.rgb, moss_mask);

    // Subtle cracks/lines
    float crack = smoothstep(0.48, 0.50, noise(UV * vec2(2.0, 15.0)));
    rock *= 1.0 - crack * 0.15;

    ALBEDO = rock;
    ROUGHNESS = roughness_val;
    METALLIC = 0.0;
}
