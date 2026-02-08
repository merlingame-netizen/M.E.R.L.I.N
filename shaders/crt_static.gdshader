shader_type canvas_item;

// CRT Static/Snow Effect - Effet de neige cathodique
// Basé sur les shaders de godotshaders.com (CC0)

uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float noise_speed : hint_range(1.0, 100.0) = 50.0;
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.4;
uniform float scanline_count : hint_range(100.0, 800.0) = 400.0;
uniform float grain_intensity : hint_range(0.0, 1.0) = 0.8;
uniform float flicker_intensity : hint_range(0.0, 0.5) = 0.15;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.3;
uniform vec4 tint : source_color = vec4(0.85, 0.9, 0.95, 1.0);

// Fonction de bruit pseudo-aleatoire rapide
float rand(vec2 co) {
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

// Bruit anime
float noise(vec2 uv, float t) {
    vec2 i = floor(uv);
    vec2 f = fract(uv);

    float a = rand(i + vec2(0.0, 0.0) + t);
    float b = rand(i + vec2(1.0, 0.0) + t);
    float c = rand(i + vec2(0.0, 1.0) + t);
    float d = rand(i + vec2(1.0, 1.0) + t);

    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

void fragment() {
    vec2 uv = UV;

    // Bruit statique principal (haute frequence, tres rapide)
    float static_noise = rand(uv * 500.0 + TIME * noise_speed);

    // Couche de bruit grossier
    float coarse_noise = noise(uv * 80.0 + TIME * noise_speed * 0.3, floor(TIME * 30.0));

    // Combine les bruits
    float combined_noise = mix(static_noise, coarse_noise, 0.4) * grain_intensity;

    // Scanlines horizontales
    float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
    scanline = pow(scanline, 1.5) * scanline_opacity;

    // Flicker global (variation de luminosite)
    float flicker = 1.0 - flicker_intensity * rand(vec2(floor(TIME * 15.0), 0.0));

    // Lignes de balayage verticales occasionnelles (interference)
    float v_interference = 0.0;
    float interference_pos = fract(TIME * 0.3) * 1.4 - 0.2;
    if (abs(uv.y - interference_pos) < 0.03) {
        v_interference = (1.0 - abs(uv.y - interference_pos) / 0.03) * 0.3;
    }

    // Vignette (assombrit les bords)
    vec2 center_dist = uv - 0.5;
    float vignette = 1.0 - dot(center_dist, center_dist) * vignette_intensity * 3.0;
    vignette = clamp(vignette, 0.0, 1.0);

    // Distorsion de bord CRT
    float edge_darken = 1.0 - pow(abs(uv.x - 0.5) * 2.0, 6.0) * 0.15;
    edge_darken *= 1.0 - pow(abs(uv.y - 0.5) * 2.0, 6.0) * 0.15;

    // Assemblage final
    float brightness = combined_noise * flicker * vignette * edge_darken;
    brightness += v_interference;
    brightness -= scanline * 0.5;
    brightness = clamp(brightness, 0.0, 1.0);

    // Couleur finale avec teinte
    vec3 final_color = tint.rgb * brightness;

    COLOR = vec4(final_color, intensity);
}
