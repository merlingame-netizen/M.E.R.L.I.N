shader_type canvas_item;
render_mode unshaded;

// =============================================================================
// CRT Terminal Shader — M.E.R.L.I.N. Unified Post-Process
// =============================================================================
// Combines: screen_distortion (mood system) + screen_dither (Bayer dithering)
// + CRT scanlines + phosphor tint + color quantization
// Single-pass post-process for the CRT druido-tech aesthetic.
// Used by CRTLayer (CanvasLayer 100). Driven by ScreenEffects mood system.
// =============================================================================

// === SCREEN TEXTURE ===
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// === MASTER CONTROLS ===
uniform float global_intensity : hint_range(0.0, 1.0) = 0.6;

// === CRT CURVATURE ===
uniform float curvature : hint_range(0.0, 0.15) = 0.04;

// === CRT SCANLINES ===
uniform float scanline_opacity : hint_range(0.0, 1.0) = 0.18;
uniform float scanline_count : hint_range(100.0, 800.0) = 400.0;

// === PHOSPHOR TINT ===
uniform vec4 phosphor_tint : source_color = vec4(0.2, 1.0, 0.4, 1.0);
uniform float tint_blend : hint_range(0.0, 1.0) = 0.06;

// === DITHERING (Bayer 4x4) ===
uniform float dither_strength : hint_range(0.0, 1.0) = 0.3;
uniform float color_levels : hint_range(2.0, 32.0, 1.0) = 8.0;

// === PHOSPHOR GLOW ===
uniform float phosphor_glow : hint_range(0.0, 1.0) = 0.12;

// === CHROMATIC ABERRATION (edge only) ===
uniform bool chromatic_enabled = true;
uniform float chromatic_intensity : hint_range(0.0, 0.01) = 0.0008;
uniform float chromatic_falloff : hint_range(1.0, 4.0) = 3.0;

// === SCANLINE WOBBLE ===
uniform bool scanline_enabled = true;
uniform float scanline_wobble_intensity : hint_range(0.0, 0.005) = 0.0003;
uniform float scanline_wobble_frequency : hint_range(0.0, 100.0) = 30.0;
uniform float scanline_wobble_speed : hint_range(0.0, 5.0) = 0.8;

// === MICRO GLITCHES ===
uniform bool glitch_enabled = true;
uniform float glitch_probability : hint_range(0.0, 0.3) = 0.005;
uniform float glitch_intensity : hint_range(0.0, 0.02) = 0.004;
uniform float glitch_line_height : hint_range(0.001, 0.05) = 0.015;

// === BARREL DISTORTION (legacy compat — added to curvature) ===
uniform bool barrel_enabled = true;
uniform float barrel_intensity : hint_range(0.0, 0.1) = 0.003;

// === COLOR SHIFTING ===
uniform bool color_shift_enabled = true;
uniform float color_shift_intensity : hint_range(0.0, 0.02) = 0.0006;
uniform float color_shift_speed : hint_range(0.0, 2.0) = 0.3;

// === TEMPORAL NOISE (grain) ===
uniform bool noise_enabled = true;
uniform float noise_intensity : hint_range(0.0, 0.1) = 0.015;
uniform float noise_speed : hint_range(1.0, 60.0) = 24.0;

// === VIGNETTE ===
uniform bool vignette_enabled = true;
uniform float vignette_intensity : hint_range(0.0, 0.5) = 0.12;
uniform float vignette_softness : hint_range(0.1, 1.0) = 0.55;

// === BRIGHTNESS FLICKER ===
uniform bool flicker_enabled = true;
uniform float flicker_intensity : hint_range(0.0, 0.05) = 0.006;
uniform float flicker_speed : hint_range(1.0, 30.0) = 12.0;


// === UTILITY FUNCTIONS ===

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

float hash(float n) {
	return fract(sin(n) * 43758.5453);
}

// Bayer 4x4 ordered dithering matrix
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


// === MAIN FRAGMENT ===

void fragment() {
	vec2 uv = UV;
	vec2 center_dist = uv - 0.5;
	float dist_from_center = length(center_dist);

	// ─── STAGE 1: UV DISTORTIONS ─────────────────────────────────────

	// CRT Curvature (barrel distortion)
	if (global_intensity >= 0.001) {
		float r2 = dot(center_dist, center_dist);

		// Combined curvature: dedicated CRT curve + legacy barrel
		float total_curve = curvature + (barrel_enabled ? barrel_intensity : 0.0);
		if (total_curve > 0.0) {
			float distort = 1.0 + r2 * total_curve * global_intensity;
			uv = 0.5 + center_dist * distort;
		}

		// Scanline wobble
		if (scanline_enabled && scanline_wobble_intensity > 0.0) {
			float wobble = sin(uv.y * scanline_wobble_frequency + TIME * scanline_wobble_speed);
			wobble += sin(uv.y * scanline_wobble_frequency * 2.3 + TIME * scanline_wobble_speed * 0.7) * 0.5;
			uv.x += wobble * scanline_wobble_intensity * global_intensity;
		}

		// Micro glitches
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
	}

	// Black outside CRT bounds (curved edges)
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
		return;
	}

	// ─── STAGE 2: COLOR SAMPLING ─────────────────────────────────────

	vec4 col;

	// Color shifting offset
	vec2 color_offset = vec2(0.0);
	if (color_shift_enabled && color_shift_intensity > 0.0 && global_intensity >= 0.001) {
		float shift_time = TIME * color_shift_speed;
		color_offset.x = sin(shift_time + uv.y * 5.0) * color_shift_intensity * global_intensity;
		color_offset.y = cos(shift_time * 0.7 + uv.x * 5.0) * color_shift_intensity * 0.5 * global_intensity;
	}

	// Chromatic aberration (edge-weighted RGB split)
	if (chromatic_enabled && chromatic_intensity > 0.0 && global_intensity >= 0.001) {
		float edge_factor = pow(dist_from_center * 2.0, chromatic_falloff);
		float ca_amount = chromatic_intensity * edge_factor * global_intensity;
		vec2 ca_offset = normalize(center_dist + 0.001) * ca_amount;

		float r = texture(screen_texture, uv + ca_offset + color_offset).r;
		float g = texture(screen_texture, uv + color_offset * 0.5).g;
		float b = texture(screen_texture, uv - ca_offset + color_offset).b;
		col = vec4(r, g, b, 1.0);
	} else {
		col = texture(screen_texture, uv + color_offset);
	}

	// ─── STAGE 3: COLOR PROCESSING ───────────────────────────────────

	if (global_intensity >= 0.001) {
		// Temporal noise (grain)
		if (noise_enabled && noise_intensity > 0.0) {
			float grain = rand(uv * 500.0 + floor(TIME * noise_speed)) - 0.5;
			col.rgb += grain * noise_intensity * global_intensity;
		}

		// Brightness flicker
		if (flicker_enabled && flicker_intensity > 0.0) {
			float flick = 1.0 + (rand(vec2(floor(TIME * flicker_speed), 0.0)) - 0.5) * flicker_intensity * global_intensity * 2.0;
			col.rgb *= flick;
		}

		// Phosphor tint (biome-driven green/amber/colored)
		if (tint_blend > 0.0) {
			col.rgb = mix(col.rgb, col.rgb * phosphor_tint.rgb, tint_blend * global_intensity);
		}

		// CRT Scanlines (horizontal dark bands)
		if (scanline_opacity > 0.0) {
			float scanline = sin(uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
			scanline = pow(scanline, 1.5);
			col.rgb *= 1.0 - (scanline * scanline_opacity * global_intensity);
		}

		// Phosphor glow (bright pixels bloom slightly)
		if (phosphor_glow > 0.0) {
			float luminance = dot(col.rgb, vec3(0.299, 0.587, 0.114));
			float bloom_factor = smoothstep(0.5, 1.0, luminance) * phosphor_glow * global_intensity;
			col.rgb += col.rgb * bloom_factor;
		}

		// Vignette (CRT edge darkening)
		if (vignette_enabled && vignette_intensity > 0.0) {
			float vignette = 1.0 - smoothstep(vignette_softness, 1.0, dist_from_center * 2.0);
			col.rgb *= mix(1.0, vignette, vignette_intensity * global_intensity);
		}
	}

	// ─── STAGE 4: DITHERING ──────────────────────────────────────────

	if (dither_strength > 0.0 && global_intensity >= 0.001) {
		ivec2 screen_pos = ivec2(FRAGCOORD.xy);
		float threshold = bayer4x4(screen_pos);

		float levels = color_levels - 1.0;
		vec3 dithered = col.rgb * levels;
		dithered += (threshold - 0.5) * dither_strength * global_intensity;
		dithered = floor(dithered + 0.5) / levels;
		dithered = clamp(dithered, 0.0, 1.0);

		col.rgb = dithered;
	}

	// Clamp final output
	col.rgb = clamp(col.rgb, 0.0, 1.0);
	COLOR = col;
}
