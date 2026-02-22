shader_type canvas_item;

// ═══════════════════════════════════════════════════════════════════════════════
// Screen Dither Post-Process — M.E.R.L.I.N.
// ═══════════════════════════════════════════════════════════════════════════════
// Full-screen Bayer 4x4 dithering applied as a post-process via CanvasLayer.
// Reads SCREEN_TEXTURE, applies warm parchment tint + ordered dithering.
// Use with ScreenDitherLayer.gd on a CanvasLayer (layer 100).
// ═══════════════════════════════════════════════════════════════════════════════

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform float color_levels : hint_range(2.0, 32.0, 1.0) = 8.0;
uniform float dither_strength : hint_range(0.0, 1.0, 0.01) = 0.4;
uniform vec4 warm_tint : source_color = vec4(0.96, 0.93, 0.88, 1.0);
uniform float tint_blend : hint_range(0.0, 1.0, 0.01) = 0.12;
uniform float pixel_scale : hint_range(1.0, 8.0, 1.0) = 1.0;
uniform float intensity : hint_range(0.0, 1.0, 0.01) = 1.0;

float bayer4x4(ivec2 pos) {
	int x = pos.x % 4;
	int y = pos.y % 4;
	int index = x + y * 4;
	float values[16] = float[16](
		0.0 / 16.0,  8.0 / 16.0,  2.0 / 16.0, 10.0 / 16.0,
		12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0,  6.0 / 16.0,
		3.0 / 16.0, 11.0 / 16.0,  1.0 / 16.0,  9.0 / 16.0,
		15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0,  5.0 / 16.0
	);
	return values[index];
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;

	// Optional pixelation
	if (pixel_scale > 1.0) {
		uv = floor(uv * screen_size / pixel_scale) * pixel_scale / screen_size;
	}

	vec4 original = texture(SCREEN_TEXTURE, uv);

	// Apply warm parchment tint
	vec4 col = original;
	col.rgb = mix(col.rgb, warm_tint.rgb, tint_blend);

	// Bayer dithering
	ivec2 screen_pos = ivec2(FRAGCOORD.xy);
	float threshold = bayer4x4(screen_pos);

	float levels = color_levels - 1.0;
	vec3 dithered = col.rgb * levels;
	dithered += (threshold - 0.5) * dither_strength;
	dithered = floor(dithered + 0.5) / levels;
	dithered = clamp(dithered, 0.0, 1.0);

	// Mix between original and dithered based on intensity
	COLOR = vec4(mix(original.rgb, dithered, intensity), original.a);
}
