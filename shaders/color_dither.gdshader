shader_type canvas_item;

// ═══════════════════════════════════════════════════════════════════════════════
// Color Dither Shader — M.E.R.L.I.N.
// ═══════════════════════════════════════════════════════════════════════════════
// Applies ordered (Bayer) dithering with palette quantization.
// Creates a warm, parchment-friendly retro pixel art look.
//
// Modes:
//   - Screen post-process: use with SCREEN_TEXTURE on a ColorRect
//   - Sprite dithering: apply directly to Sprite2D/TextureRect material
//
// Palette quantization reduces colors to `color_levels` per channel,
// then applies Bayer 4x4 dithering to simulate in-between tones.
// ═══════════════════════════════════════════════════════════════════════════════

// Color levels per channel (lower = more retro, 4 = Game Boy Color feel)
uniform float color_levels : hint_range(2.0, 32.0, 1.0) = 8.0;

// Dither strength (0.0 = no dithering, 1.0 = full Bayer pattern)
uniform float dither_strength : hint_range(0.0, 1.0, 0.01) = 0.5;

// Warm tint — shifts dither towards parchment tones
uniform vec4 warm_tint : source_color = vec4(0.96, 0.93, 0.88, 1.0);

// Tint blend (0.0 = no tint, 1.0 = full warm overlay)
uniform float tint_blend : hint_range(0.0, 1.0, 0.01) = 0.15;

// Pixelate factor (1.0 = no pixelation, higher = blockier)
uniform float pixel_scale : hint_range(1.0, 8.0, 1.0) = 1.0;

// 4x4 Bayer dithering matrix (normalized to 0..1 range)
float bayer4x4(ivec2 pos) {
	// Classic 4x4 ordered dither thresholds
	int x = pos.x % 4;
	int y = pos.y % 4;
	int index = x + y * 4;

	// Bayer matrix values (0-15) normalized
	float values[16] = float[16](
		0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
		12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
		3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
		15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
	);
	return values[index];
}

void fragment() {
	// Optional pixelation
	vec2 uv = UV;
	if (pixel_scale > 1.0) {
		vec2 tex_size = vec2(textureSize(TEXTURE, 0));
		uv = floor(uv * tex_size / pixel_scale) * pixel_scale / tex_size;
	}

	vec4 col = texture(TEXTURE, uv);

	// Skip transparent pixels
	if (col.a < 0.01) {
		COLOR = col;
		return;
	}

	// Apply warm parchment tint
	col.rgb = mix(col.rgb, warm_tint.rgb, tint_blend);

	// Get screen-space pixel position for dither pattern
	ivec2 screen_pos = ivec2(FRAGCOORD.xy);
	float threshold = bayer4x4(screen_pos);

	// Quantize with dithering
	float levels = color_levels - 1.0;
	vec3 dithered = col.rgb * levels;

	// Add Bayer offset before quantization
	dithered += (threshold - 0.5) * dither_strength;

	// Quantize
	dithered = floor(dithered + 0.5) / levels;
	dithered = clamp(dithered, 0.0, 1.0);

	COLOR = vec4(dithered, col.a);
}
