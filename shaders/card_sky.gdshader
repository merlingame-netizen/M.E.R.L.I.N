shader_type canvas_item;
// Procedural sky gradient for card illustration — 3-band vertical gradient
// with weather effects (fog, clouds, rain streaks).
// Driven by biome + season + weather uniforms from CardSceneCompositor.

// Sky gradient
uniform vec4 top_color : source_color = vec4(0.06, 0.14, 0.08, 1.0);
uniform vec4 mid_color : source_color = vec4(0.12, 0.28, 0.14, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.18, 0.40, 0.20, 1.0);
uniform float mid_position : hint_range(0.2, 0.8) = 0.45;
uniform vec4 season_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Base noise
uniform float noise_strength : hint_range(0.0, 0.05) = 0.015;
uniform float time_scale : hint_range(0.0, 1.0) = 0.08;

// Weather uniforms
uniform float fog_density : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fog_color : source_color = vec4(0.6, 0.6, 0.65, 1.0);
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.0;
uniform float rain_intensity : hint_range(0.0, 1.0) = 0.0;


// ── Noise functions ─────────────────────────────────────────────────────────

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

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

// Multi-octave noise for clouds
float fbm(vec2 p, int octaves) {
	float val = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	for (int i = 0; i < octaves; i++) {
		val += value_noise(p * freq) * amp;
		freq *= 2.1;
		amp *= 0.48;
	}
	return val;
}


void fragment() {
	float y = UV.y;

	// 3-band gradient: top -> mid -> bottom
	vec3 color;
	if (y < mid_position) {
		float t = y / mid_position;
		color = mix(top_color.rgb, mid_color.rgb, t);
	} else {
		float t = (y - mid_position) / (1.0 - mid_position);
		color = mix(mid_color.rgb, bottom_color.rgb, t);
	}

	// Subtle base noise for organic feel
	float n = value_noise(UV * 8.0 + vec2(TIME * time_scale, 0.0));
	color += (n - 0.5) * noise_strength;

	// Apply season tint (multiplicative)
	color *= season_tint.rgb;

	// ── Weather: Clouds ─────────────────────────────────────────────────
	if (cloud_cover > 0.01) {
		// Slow-scrolling cloud layer using fbm noise
		vec2 cloud_uv = UV * vec2(3.0, 1.5) + vec2(TIME * 0.02, TIME * 0.005);
		float cloud_noise = fbm(cloud_uv, 3);
		// Threshold: higher cloud_cover = lower threshold = more cloud visible
		float threshold = 1.0 - cloud_cover;
		float cloud_mask = smoothstep(threshold, threshold + 0.25, cloud_noise);
		// Clouds are lighter than sky, blended with fog_color for consistency
		vec3 cloud_color = mix(color * 1.3, fog_color.rgb, 0.4);
		color = mix(color, cloud_color, cloud_mask * cloud_cover * 0.6);
	}

	// ── Weather: Rain streaks ───────────────────────────────────────────
	if (rain_intensity > 0.01) {
		// Vertical streaks moving downward
		float rain_x = floor(UV.x * 40.0 + 0.5);  // 40 column grid
		float rain_seed = hash(vec2(rain_x, 0.0));
		float rain_y = fract(UV.y * 3.0 - TIME * 2.5 - rain_seed * 10.0);
		// Thin bright streaks
		float streak = smoothstep(0.0, 0.02, rain_y) * smoothstep(0.15, 0.04, rain_y);
		// Only some columns have rain
		float column_active = step(1.0 - rain_intensity * 0.7, rain_seed);
		float rain_alpha = streak * column_active * rain_intensity * 0.15;
		color = mix(color, vec3(0.6, 0.65, 0.72), rain_alpha);
	}

	// ── Weather: Fog blend (applied last, washes out everything) ────────
	if (fog_density > 0.01) {
		// Fog is denser near bottom (horizon)
		float fog_gradient = mix(0.3, 1.0, y);
		float fog_amount = fog_density * fog_gradient;
		color = mix(color, fog_color.rgb, fog_amount);
	}

	COLOR = vec4(color, 1.0);
}
