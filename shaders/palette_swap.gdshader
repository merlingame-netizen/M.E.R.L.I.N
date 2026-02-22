shader_type canvas_item;

// ═══════════════════════════════════════════════════════════════════════════════
// Palette Swap Shader — M.E.R.L.I.N.
// ═══════════════════════════════════════════════════════════════════════════════
// Swaps colors from a reference palette (row 0) to target palettes (rows 1+).
// Supports animated cycling for seasonal transitions, biome shifts, etc.
//
// Palette texture format (ImageTexture, filter = Nearest):
//   Row 0: Reference colors (the original sprite colors)
//   Row 1: Target palette A (e.g. printemps)
//   Row 2: Target palette B (e.g. ete)
//   Row 3: Target palette C (e.g. automne)
//   Row 4: Target palette D (e.g. hiver)
//
// Usage:
//   1. Create palette texture via MerlinPaletteSwap.create_season_palette()
//   2. Assign to this shader's `palette` uniform
//   3. Set `animation_fps` > 0 for auto-cycling, or `target_row` for manual control
// ═══════════════════════════════════════════════════════════════════════════════

// The palette grid texture (rows of colors, each pixel = one color)
uniform sampler2D palette : filter_nearest, repeat_disable;

// Animation speed (rows per second). Set 0 for manual row selection.
uniform float animation_fps : hint_range(0.0, 30.0, 0.1) = 0.0;

// Manual target row (1-based, ignored if animation_fps > 0)
uniform int target_row : hint_range(0, 16) = 1;

// Color match tolerance (0.0 = exact match, useful for anti-aliased sprites)
uniform float tolerance : hint_range(0.0, 0.1, 0.001) = 0.01;

// Blend factor between original and swapped (0.0 = original, 1.0 = fully swapped)
uniform float blend : hint_range(0.0, 1.0, 0.01) = 1.0;

void fragment() {
	vec4 original = texture(TEXTURE, UV);

	// Skip transparent pixels
	if (original.a < 0.01) {
		COLOR = original;
		return;
	}

	// Get palette dimensions
	ivec2 pal_size = textureSize(palette, 0);
	int num_colors = pal_size.x;
	int num_rows = pal_size.y;

	// Nothing to swap if palette is too small
	if (num_colors < 1 || num_rows < 2) {
		COLOR = original;
		return;
	}

	// Determine active target row
	int row = target_row;
	if (animation_fps > 0.0) {
		// Cycle through rows 1..num_rows-1
		int num_targets = num_rows - 1;
		float cycle = mod(TIME * animation_fps, float(num_targets));
		row = int(floor(cycle)) + 1;
	}
	row = clamp(row, 1, num_rows - 1);

	// Convert original color to integer for faster matching
	ivec3 orig_int = ivec3(round(original.rgb * 255.0));

	// Search reference row (row 0) for a matching color
	vec4 result = original;
	for (int i = 0; i < num_colors; i++) {
		// Sample reference color (row 0)
		vec2 ref_uv = vec2((float(i) + 0.5) / float(num_colors), 0.5 / float(num_rows));
		vec4 ref_color = texture(palette, ref_uv);

		// Integer comparison for accuracy
		ivec3 ref_int = ivec3(round(ref_color.rgb * 255.0));
		ivec3 diff = abs(orig_int - ref_int);
		int max_diff = max(diff.r, max(diff.g, diff.b));

		if (max_diff <= int(tolerance * 255.0)) {
			// Match found — sample target color from the active row
			vec2 target_uv = vec2(
				(float(i) + 0.5) / float(num_colors),
				(float(row) + 0.5) / float(num_rows)
			);
			vec4 target_color = texture(palette, target_uv);
			result = vec4(target_color.rgb, original.a);
			break;
		}
	}

	// Blend between original and swapped
	COLOR = mix(original, result, blend);
}
