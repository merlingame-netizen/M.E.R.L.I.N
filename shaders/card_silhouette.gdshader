shader_type canvas_item;
// Procedural terrain silhouette for card illustration.
// Noise-based treeline/terrain boundary. Transparent above, solid color below.

uniform vec4 silhouette_color : source_color = vec4(0.08, 0.16, 0.10, 1.0);
uniform float height_base : hint_range(0.3, 0.9) = 0.55;
uniform float height_variation : hint_range(0.0, 0.4) = 0.20;
uniform float roughness : hint_range(0.1, 2.0) = 0.65;
uniform float density : hint_range(0.1, 1.0) = 0.80;
uniform float time_offset = 0.0;  // Random seed per card (avoids same silhouette)

// Hash function
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Value noise
float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Multi-octave noise for terrain shape
float terrain_noise(float x) {
	float n = 0.0;
	float freq = roughness * 4.0;
	float amp = 1.0;
	float total_amp = 0.0;

	// 3 octaves for organic treeline
	for (int i = 0; i < 3; i++) {
		n += value_noise(vec2(x * freq + time_offset, float(i) * 17.3)) * amp;
		total_amp += amp;
		freq *= 2.2;
		amp *= 0.45;
	}
	return n / total_amp;
}

void fragment() {
	float x = UV.x;
	float y = UV.y;

	// Compute terrain height at this x position
	float noise_val = terrain_noise(x);

	// Main silhouette boundary
	float terrain_y = height_base - height_variation * noise_val;

	// Add "crown" bumps for tree canopy effect (density controls frequency)
	float crown_noise = value_noise(vec2(x * density * 12.0 + time_offset, 0.5));
	float crown_height = crown_noise * height_variation * 0.4 * density;
	terrain_y -= crown_height;

	// Below terrain = solid color, above = transparent
	if (y >= terrain_y) {
		// Slight vertical gradient for depth (darker at bottom)
		float depth_factor = (y - terrain_y) / (1.0 - terrain_y);
		float darken = mix(1.0, 0.7, depth_factor * 0.5);
		vec3 color = silhouette_color.rgb * darken;

		// Subtle horizontal variation for texture
		float tex_noise = value_noise(vec2(x * 20.0 + time_offset, y * 15.0));
		color += (tex_noise - 0.5) * 0.02;

		COLOR = vec4(color, silhouette_color.a);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	}
}
