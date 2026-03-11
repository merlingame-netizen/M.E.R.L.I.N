shader_type canvas_item;

// Seasonal particle shader — snow, leaves, flowers, heat shimmer
// Renders procedural particles based on season type

uniform int season_type : hint_range(0, 3) = 0; // 0=spring, 1=summer, 2=autumn, 3=winter
uniform float particle_density : hint_range(0.0, 1.0) = 0.5;
uniform float animation_speed : hint_range(0.0, 5.0) = 1.0;
uniform vec4 particle_color : source_color = vec4(1.0);

// Noise function for particle distribution
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// 2D noise
float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
    vec2 uv = UV;
    float time = TIME * animation_speed;

    vec4 result = vec4(0.0);

    // Winter: falling snow
    if (season_type == 3) {
        vec2 grid_uv = uv * vec2(30.0, 50.0);
        vec2 grid_id = floor(grid_uv);
        vec2 grid_pos = fract(grid_uv);

        float particle_offset = rand(grid_id) * 6.28318;
        float fall_speed = 0.3 + rand(grid_id + vec2(1.0)) * 0.2;
        float y_pos = fract((grid_pos.y - time * fall_speed + particle_offset));
        float x_drift = sin(time * 2.0 + particle_offset) * 0.1;

        vec2 particle_pos = vec2(grid_pos.x + x_drift, y_pos);
        float particle_size = 0.02 + rand(grid_id + vec2(2.0)) * 0.01;

        float dist = length(particle_pos - vec2(0.5));
        float particle = smoothstep(particle_size, particle_size * 0.5, dist);

        if (rand(grid_id + vec2(3.0)) < particle_density) {
            result.rgb = particle_color.rgb;
            result.a = particle * particle_color.a;
        }
    }

    // Autumn: falling leaves
    else if (season_type == 2) {
        vec2 grid_uv = uv * vec2(20.0, 35.0);
        vec2 grid_id = floor(grid_uv);
        vec2 grid_pos = fract(grid_uv);

        float particle_offset = rand(grid_id) * 10.0;
        float fall_speed = 0.15 + rand(grid_id + vec2(1.0)) * 0.1;
        float y_pos = fract((grid_pos.y - time * fall_speed + particle_offset));
        float x_drift = sin(time * 1.5 + particle_offset) * 0.15;
        float rotation = time * 2.0 + particle_offset;

        vec2 particle_pos = vec2(grid_pos.x + x_drift - 0.5, y_pos - 0.5);
        mat2 rot = mat2(vec2(cos(rotation), -sin(rotation)),
                        vec2(sin(rotation), cos(rotation)));
        particle_pos = rot * particle_pos;

        // Leaf shape (rough triangle)
        float leaf_width = 0.03;
        float leaf_height = 0.05;
        float leaf_shape = step(abs(particle_pos.x), leaf_width) *
                          step(particle_pos.y, leaf_height) *
                          step(-leaf_height, particle_pos.y);

        if (rand(grid_id + vec2(2.0)) < particle_density) {
            result.rgb = particle_color.rgb;
            result.a = leaf_shape * particle_color.a;
        }
    }

    // Spring: floating flower petals
    else if (season_type == 0) {
        vec2 grid_uv = uv * vec2(25.0, 40.0);
        vec2 grid_id = floor(grid_uv);
        vec2 grid_pos = fract(grid_uv);

        float particle_offset = rand(grid_id) * 8.0;
        float rise_speed = 0.08 + rand(grid_id + vec2(1.0)) * 0.05;
        float y_pos = fract((grid_pos.y + time * rise_speed + particle_offset));
        float x_drift = sin(time * 1.8 + particle_offset) * 0.12;

        vec2 particle_pos = vec2(grid_pos.x + x_drift, y_pos);
        float particle_size = 0.015 + rand(grid_id + vec2(2.0)) * 0.008;

        float dist = length(particle_pos - vec2(0.5));
        float particle = smoothstep(particle_size, particle_size * 0.6, dist);

        if (rand(grid_id + vec2(3.0)) < particle_density) {
            result.rgb = particle_color.rgb;
            result.a = particle * particle_color.a * 0.8;
        }
    }

    // Summer: subtle heat haze tint (no particles)
    else if (season_type == 1) {
        float haze = noise(uv * 10.0 + time * 0.5) * 0.05 * particle_density;
        result.rgb = particle_color.rgb;
        result.a = haze;
    }

    // Output as transparent overlay — only particles are visible
    COLOR = result;
}
