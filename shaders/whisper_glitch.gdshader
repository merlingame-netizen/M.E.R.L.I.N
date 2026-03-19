shader_type canvas_item;

// Whisper Glitch — Subtle reality stutter for meta-narrative cards.
// Apply to a ColorRect overlay when a whisper card appears.
// The effect is intentionally subtle: small horizontal shifts,
// brief scanline artifacts, slight color separation.
// Should feel like the world "hiccuping", not a full glitch.

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform float time_scale : hint_range(0.1, 5.0) = 1.5;
uniform float shift_amount : hint_range(0.0, 0.02) = 0.005;
uniform float scanline_strength : hint_range(0.0, 0.5) = 0.15;
uniform vec4 tint_color : source_color = vec4(0.2, 0.8, 0.4, 0.05);

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME * time_scale;

	// Only apply when intensity > 0
	if (intensity < 0.01) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
		return;
	}

	// Horizontal shift — brief displacement every ~2 seconds
	float shift_trigger = step(0.95, fract(t * 0.5));
	float h_shift = shift_amount * shift_trigger * sin(uv.y * 40.0 + t * 10.0);

	// Chromatic aberration — subtle RGB split
	float r = textureLod(SCREEN_TEXTURE, uv + vec2(h_shift, 0.0), 0.0).r;
	float g = textureLod(SCREEN_TEXTURE, uv, 0.0).g;
	float b = textureLod(SCREEN_TEXTURE, uv - vec2(h_shift, 0.0), 0.0).b;

	// Scanline flicker — thin horizontal lines
	float scanline = sin(uv.y * 800.0 + t * 5.0) * scanline_strength * shift_trigger;

	// Combine
	vec3 glitched = vec3(r, g, b) + scanline;

	// Apply tint
	glitched = mix(glitched, tint_color.rgb, tint_color.a * intensity);

	COLOR = vec4(glitched - textureLod(SCREEN_TEXTURE, uv, 0.0).rgb, intensity * 0.3);
}
