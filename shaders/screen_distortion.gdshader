shader_type canvas_item;
render_mode unshaded;

// Screen Distortion Shader - Subtle, Realistic Monitor Imperfections
// For DRU: Le Jeu des Oghams - Designed for mobile performance
// All effects are designed to be barely noticeable, creating subliminal unease

// === MASTER CONTROLS ===
uniform float global_intensity : hint_range(0.0, 1.0) = 0.35;

// === CHROMATIC ABERRATION (edge only) ===
uniform bool chromatic_enabled = true;
uniform float chromatic_intensity : hint_range(0.0, 0.01) = 0.0003;
uniform float chromatic_falloff : hint_range(1.0, 4.0) = 3.0;

// === SCANLINE WOBBLE ===
uniform bool scanline_enabled = true;
uniform float scanline_wobble_intensity : hint_range(0.0, 0.005) = 0.0001;
uniform float scanline_wobble_frequency : hint_range(0.0, 100.0) = 30.0;
uniform float scanline_wobble_speed : hint_range(0.0, 5.0) = 0.8;

// === MICRO GLITCHES (rare, brief) ===
uniform bool glitch_enabled = true;
uniform float glitch_probability : hint_range(0.0, 0.1) = 0.003;
uniform float glitch_intensity : hint_range(0.0, 0.02) = 0.003;
uniform float glitch_line_height : hint_range(0.001, 0.05) = 0.015;

// === BARREL DISTORTION ===
uniform bool barrel_enabled = true;
uniform float barrel_intensity : hint_range(0.0, 0.1) = 0.001;

// === COLOR SHIFTING/BLEEDING ===
uniform bool color_shift_enabled = true;
uniform float color_shift_intensity : hint_range(0.0, 0.02) = 0.0004;
uniform float color_shift_speed : hint_range(0.0, 2.0) = 0.3;

// === TEMPORAL NOISE (grain) ===
uniform bool noise_enabled = true;
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.008;
uniform float noise_speed : hint_range(1.0, 60.0) = 24.0;

// === VIGNETTE ===
uniform bool vignette_enabled = true;
uniform float vignette_intensity : hint_range(0.0, 0.5) = 0.06;
uniform float vignette_softness : hint_range(0.1, 1.0) = 0.6;

// === SUBTLE BRIGHTNESS FLICKER ===
uniform bool flicker_enabled = true;
uniform float flicker_intensity : hint_range(0.0, 0.05) = 0.003;
uniform float flicker_speed : hint_range(1.0, 30.0) = 12.0;

// === SCREEN TEXTURE (for post-processing) ===
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// === UTILITY FUNCTIONS ===

// Fast pseudo-random (mobile optimized)
float rand(vec2 co) {
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

// Hash for glitch timing
float hash(float n) {
    return fract(sin(n) * 43758.5453);
}

// Smooth noise
float noise(vec2 uv) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);
    f = f * f * (3.0 - 2.0 * f); // smoothstep

    float a = rand(i);
    float b = rand(i + vec2(1.0, 0.0));
    float c = rand(i + vec2(0.0, 1.0));
    float d = rand(i + vec2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// === MAIN FRAGMENT ===

void fragment() {
    // Default output
    vec4 col = texture(screen_texture, UV);

    // Only apply effects if global intensity > 0
    if (global_intensity >= 0.001) {
        vec2 uv = UV;
        vec2 center_dist = uv - 0.5;
        float dist_from_center = length(center_dist);

        // === BARREL DISTORTION ===
    if (barrel_enabled && barrel_intensity > 0.0) {
        float r2 = dot(center_dist, center_dist);
        float distort = 1.0 + r2 * barrel_intensity * global_intensity;
        uv = 0.5 + center_dist * distort;
    }

    // === SCANLINE WOBBLE ===
    if (scanline_enabled && scanline_wobble_intensity > 0.0) {
        float wobble = sin(uv.y * scanline_wobble_frequency + TIME * scanline_wobble_speed);
        wobble += sin(uv.y * scanline_wobble_frequency * 2.3 + TIME * scanline_wobble_speed * 0.7) * 0.5;
        uv.x += wobble * scanline_wobble_intensity * global_intensity;
    }

    // === MICRO GLITCHES ===
    if (glitch_enabled && glitch_probability > 0.0) {
        float glitch_time = floor(TIME * 10.0);
        float glitch_trigger = hash(glitch_time);

        if (glitch_trigger < glitch_probability * global_intensity) {
            float glitch_y = hash(glitch_time + 100.0);
            if (abs(uv.y - glitch_y) < glitch_line_height) {
                float glitch_offset = (hash(glitch_time + uv.y * 100.0) - 0.5) * 2.0;
                uv.x += glitch_offset * glitch_intensity * global_intensity;
            }
        }
    }

    // === COLOR SHIFTING ===
    vec2 color_offset = vec2(0.0);
    if (color_shift_enabled && color_shift_intensity > 0.0) {
        float shift_time = TIME * color_shift_speed;
        color_offset.x = sin(shift_time + uv.y * 5.0) * color_shift_intensity * global_intensity;
        color_offset.y = cos(shift_time * 0.7 + uv.x * 5.0) * color_shift_intensity * 0.5 * global_intensity;
    }

    // === CHROMATIC ABERRATION (edge weighted) ===
    if (chromatic_enabled && chromatic_intensity > 0.0) {
        float edge_factor = pow(dist_from_center * 2.0, chromatic_falloff);
        float ca_amount = chromatic_intensity * edge_factor * global_intensity;

        vec2 ca_offset = normalize(center_dist + 0.001) * ca_amount;

        // Sample RGB with offset + color shifting
        float r = texture(screen_texture, uv + ca_offset + color_offset).r;
        float g = texture(screen_texture, uv + color_offset * 0.5).g;
        float b = texture(screen_texture, uv - ca_offset + color_offset).b;
        float a = texture(screen_texture, uv).a;

        col = vec4(r, g, b, a);
    } else {
        col = texture(screen_texture, uv + color_offset);
    }

    // === TEMPORAL NOISE (grain) ===
    if (noise_enabled && noise_intensity > 0.0) {
        float grain = rand(uv * 500.0 + floor(TIME * noise_speed)) - 0.5;
        col.rgb += grain * noise_intensity * global_intensity;
    }

    // === BRIGHTNESS FLICKER ===
    if (flicker_enabled && flicker_intensity > 0.0) {
        float flick = 1.0 + (rand(vec2(floor(TIME * flicker_speed), 0.0)) - 0.5) * flicker_intensity * global_intensity * 2.0;
        col.rgb *= flick;
    }

    // === VIGNETTE ===
    if (vignette_enabled && vignette_intensity > 0.0) {
        float vignette = 1.0 - smoothstep(vignette_softness, 1.0, dist_from_center * 2.0);
        col.rgb *= mix(1.0, vignette, vignette_intensity * global_intensity);
    }

        // Clamp output
        col.rgb = clamp(col.rgb, 0.0, 1.0);
    } // end if (global_intensity >= 0.001)

    COLOR = col;
}
