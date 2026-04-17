shader_type canvas_item;

// PSX/N64 Retro Post-Process — M.E.R.L.I.N.
// Full-screen shader simulating PS1-era rendering limitations:
// - 15-bit color quantization (5 bits per channel = 32 levels)
// - Bayer 8x8 ordered dithering
// - Time-of-day color tinting
// - Seasonal color grading
// - Subtle film grain
// - Optional resolution downscale (pixelation)

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

// PSX color reduction
uniform float color_depth : hint_range(4.0, 64.0, 1.0) = 24.0;
uniform float dither_strength : hint_range(0.0, 1.0, 0.01) = 0.35;

// Time-of-day tint (RGBA: RGB = tint color, A = blend strength)
uniform vec4 time_tint = vec4(1.0, 1.0, 0.95, 0.0);

// Season color grading (multiplicative RGB, no sRGB conversion)
uniform vec3 season_grade = vec3(1.0, 1.0, 1.0);

// Film grain
uniform float grain_amount : hint_range(0.0, 0.15, 0.005) = 0.03;

// Resolution downscale
uniform float pixel_scale : hint_range(1.0, 6.0, 0.5) = 1.0;

// Master intensity (0 = bypass, 1 = full effect)
uniform float intensity : hint_range(0.0, 1.0, 0.01) = 1.0;

// Animated time for grain
uniform float time_offset : hint_range(0.0, 1000.0) = 0.0;


// Bayer 8x8 dithering matrix (normalized 0..1)
float bayer8x8(ivec2 pos) {
	int x = pos.x % 8;
	int y = pos.y % 8;
	int index = x + y * 8;

	float m[64] = float[64](
		 0.0, 32.0,  8.0, 40.0,  2.0, 34.0, 10.0, 42.0,
		48.0, 16.0, 56.0, 24.0, 50.0, 18.0, 58.0, 26.0,
		12.0, 44.0,  4.0, 36.0, 14.0, 46.0,  6.0, 38.0,
		60.0, 28.0, 52.0, 20.0, 62.0, 30.0, 54.0, 22.0,
		 3.0, 35.0, 11.0, 43.0,  1.0, 33.0,  9.0, 41.0,
		51.0, 19.0, 59.0, 27.0, 49.0, 17.0, 57.0, 25.0,
		15.0, 47.0,  7.0, 39.0, 13.0, 45.0,  5.0, 37.0,
		63.0, 31.0, 55.0, 23.0, 61.0, 29.0, 53.0, 21.0
	);
	return m[index] / 64.0;
}

// Pseudo-random hash for film grain
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;

	// Resolution downscale (pixelation)
	if (pixel_scale > 1.01) {
		uv = floor(uv * screen_size / pixel_scale) * pixel_scale / screen_size;
	}

	vec4 original = texture(SCREEN_TEXTURE, uv);

	// Early exit if intensity is zero
	if (intensity < 0.001) {
		COLOR = original;
		return;
	}

	vec3 col = original.rgb;

	// 1. Season color grading (multiplicative)
	col *= season_grade;

	// 2. Time-of-day tint (blend toward tint color)
	col = mix(col, time_tint.rgb * col, time_tint.a);

	// 3. Bayer dithering + color quantization
	ivec2 screen_pos = ivec2(FRAGCOORD.xy);
	float threshold = bayer8x8(screen_pos);

	float levels = color_depth - 1.0;
	vec3 quantized = col * levels;
	quantized += (threshold - 0.5) * dither_strength;
	quantized = floor(quantized + 0.5) / levels;
	quantized = clamp(quantized, 0.0, 1.0);

	// 4. Film grain
	float grain = (hash(FRAGCOORD.xy + vec2(time_offset * 7.31, time_offset * 3.17)) - 0.5) * grain_amount;
	quantized += grain;
	quantized = clamp(quantized, 0.0, 1.0);

	// Mix original and processed based on intensity
	COLOR = vec4(mix(original.rgb, quantized, intensity), original.a);
}
