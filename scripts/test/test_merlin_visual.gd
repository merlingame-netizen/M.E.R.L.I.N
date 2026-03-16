## test_merlin_visual.gd
## Unit tests for MerlinVisual — centralized visual system constants & helpers.
## Covers: palette validity, GBC keys, font sizes, animation constants, UI constants,
##         season helpers, style factories, pixel transition config, biome palettes.
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error+return false.

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

static func _is_valid_color(c: Color) -> bool:
	## A Color is valid if its RGBA components are finite floats (not NaN/INF).
	## Note: values >1.0 are intentional for HDR tints (victory_flash, modulate).
	return is_finite(c.r) and is_finite(c.g) and is_finite(c.b) and is_finite(c.a)


static func _approx_eq(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) < eps


# ═══════════════════════════════════════════════════════════════════════════════
# 1. CRT_PALETTE — all values are valid Color objects
# ═══════════════════════════════════════════════════════════════════════════════

func test_crt_palette_all_valid_colors() -> bool:
	for key: String in MerlinVisual.CRT_PALETTE:
		var val: Variant = MerlinVisual.CRT_PALETTE[key]
		if not (val is Color):
			push_error("CRT_PALETTE[%s] is not a Color: %s" % [key, str(typeof(val))])
			return false
		if not _is_valid_color(val as Color):
			push_error("CRT_PALETTE[%s] has non-finite component" % key)
			return false
	return true


func test_crt_palette_has_core_keys() -> bool:
	var required: Array[String] = [
		"bg_deep", "bg_dark", "bg_panel", "bg_highlight",
		"phosphor", "phosphor_dim", "phosphor_bright",
		"amber", "amber_dim", "amber_bright",
		"cyan", "danger", "success", "warning",
		"border", "shadow", "inactive", "inactive_dark",
	]
	for key: String in required:
		if not MerlinVisual.CRT_PALETTE.has(key):
			push_error("CRT_PALETTE missing core key: " + key)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 2. PALETTE (legacy) — all values are valid Color objects
# ═══════════════════════════════════════════════════════════════════════════════

func test_palette_all_valid_colors() -> bool:
	for key: String in MerlinVisual.PALETTE:
		var val: Variant = MerlinVisual.PALETTE[key]
		if not (val is Color):
			push_error("PALETTE[%s] is not a Color: %s" % [key, str(typeof(val))])
			return false
		if not _is_valid_color(val as Color):
			push_error("PALETTE[%s] has non-finite component" % key)
			return false
	return true


func test_palette_has_core_keys() -> bool:
	var required: Array[String] = [
		"paper", "ink", "accent", "shadow", "danger", "success", "warning",
	]
	for key: String in required:
		if not MerlinVisual.PALETTE.has(key):
			push_error("PALETTE missing core key: " + key)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 3. GBC palette — expected keys and valid colors
# ═══════════════════════════════════════════════════════════════════════════════

func test_gbc_all_valid_colors() -> bool:
	for key: String in MerlinVisual.GBC:
		var val: Variant = MerlinVisual.GBC[key]
		if not (val is Color):
			push_error("GBC[%s] is not a Color: %s" % [key, str(typeof(val))])
			return false
		if not _is_valid_color(val as Color):
			push_error("GBC[%s] has non-finite component" % key)
			return false
	return true


func test_gbc_has_element_groups() -> bool:
	## GBC should have light/base/dark variants for each element group.
	var groups: Array[String] = [
		"grass", "water", "fire", "earth", "mystic", "ice", "thunder", "poison", "metal", "shadow", "light",
	]
	for g: String in groups:
		for suffix: String in ["_light", "", "_dark"]:
			var key: String = g + suffix
			if not MerlinVisual.GBC.has(key):
				push_error("GBC missing element key: " + key)
				return false
	return true


func test_gbc_has_ui_bars() -> bool:
	var bar_keys: Array[String] = [
		"hp_green", "hp_yellow", "hp_red", "hunger_orange", "happy_pink", "energy_blue",
	]
	for key: String in bar_keys:
		if not MerlinVisual.GBC.has(key):
			push_error("GBC missing UI bar key: " + key)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 4. Font size constants — all positive
# ═══════════════════════════════════════════════════════════════════════════════

func test_font_sizes_are_positive() -> bool:
	var sizes: Dictionary = {
		"TITLE_SIZE": MerlinVisual.TITLE_SIZE,
		"TITLE_SMALL": MerlinVisual.TITLE_SMALL,
		"BODY_SIZE": MerlinVisual.BODY_SIZE,
		"BODY_LARGE": MerlinVisual.BODY_LARGE,
		"BODY_SMALL": MerlinVisual.BODY_SMALL,
		"CAPTION_SIZE": MerlinVisual.CAPTION_SIZE,
		"CAPTION_LARGE": MerlinVisual.CAPTION_LARGE,
		"CAPTION_SMALL": MerlinVisual.CAPTION_SMALL,
		"CAPTION_TINY": MerlinVisual.CAPTION_TINY,
		"BUTTON_SIZE": MerlinVisual.BUTTON_SIZE,
	}
	for name: String in sizes:
		var val: int = sizes[name]
		if val <= 0:
			push_error("%s should be positive, got: %d" % [name, val])
			return false
	return true


func test_font_size_hierarchy() -> bool:
	## Title sizes > Body sizes > Caption sizes
	if MerlinVisual.TITLE_SIZE <= MerlinVisual.BODY_LARGE:
		push_error("TITLE_SIZE (%d) should be > BODY_LARGE (%d)" % [MerlinVisual.TITLE_SIZE, MerlinVisual.BODY_LARGE])
		return false
	if MerlinVisual.BODY_SIZE <= MerlinVisual.CAPTION_SIZE:
		push_error("BODY_SIZE (%d) should be > CAPTION_SIZE (%d)" % [MerlinVisual.BODY_SIZE, MerlinVisual.CAPTION_SIZE])
		return false
	if MerlinVisual.CAPTION_SIZE <= MerlinVisual.CAPTION_TINY:
		push_error("CAPTION_SIZE (%d) should be > CAPTION_TINY (%d)" % [MerlinVisual.CAPTION_SIZE, MerlinVisual.CAPTION_TINY])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 5. Animation constants — positive durations
# ═══════════════════════════════════════════════════════════════════════════════

func test_animation_durations_positive() -> bool:
	var durations: Dictionary = {
		"ANIM_FAST": MerlinVisual.ANIM_FAST,
		"ANIM_NORMAL": MerlinVisual.ANIM_NORMAL,
		"ANIM_SLOW": MerlinVisual.ANIM_SLOW,
		"ANIM_VERY_SLOW": MerlinVisual.ANIM_VERY_SLOW,
		"TW_DELAY": MerlinVisual.TW_DELAY,
		"TW_PUNCT_DELAY": MerlinVisual.TW_PUNCT_DELAY,
		"CRT_CURSOR_BLINK": MerlinVisual.CRT_CURSOR_BLINK,
		"CRT_BOOT_LINE_DELAY": MerlinVisual.CRT_BOOT_LINE_DELAY,
		"CRT_PHOSPHOR_FADE": MerlinVisual.CRT_PHOSPHOR_FADE,
		"CRT_GLITCH_DURATION": MerlinVisual.CRT_GLITCH_DURATION,
		"BREATHE_DURATION": MerlinVisual.BREATHE_DURATION,
		"CARD_FLOAT_DURATION": MerlinVisual.CARD_FLOAT_DURATION,
		"CARD_ENTRY_DURATION": MerlinVisual.CARD_ENTRY_DURATION,
		"CARD_EXIT_DURATION": MerlinVisual.CARD_EXIT_DURATION,
		"CARD_DEAL_DURATION": MerlinVisual.CARD_DEAL_DURATION,
	}
	for name: String in durations:
		var val: float = durations[name]
		if val <= 0.0:
			push_error("%s should be positive, got: %f" % [name, val])
			return false
	return true


func test_animation_speed_ordering() -> bool:
	## FAST < NORMAL < SLOW < VERY_SLOW
	if MerlinVisual.ANIM_FAST >= MerlinVisual.ANIM_NORMAL:
		push_error("ANIM_FAST (%f) should be < ANIM_NORMAL (%f)" % [MerlinVisual.ANIM_FAST, MerlinVisual.ANIM_NORMAL])
		return false
	if MerlinVisual.ANIM_NORMAL >= MerlinVisual.ANIM_SLOW:
		push_error("ANIM_NORMAL (%f) should be < ANIM_SLOW (%f)" % [MerlinVisual.ANIM_NORMAL, MerlinVisual.ANIM_SLOW])
		return false
	if MerlinVisual.ANIM_SLOW >= MerlinVisual.ANIM_VERY_SLOW:
		push_error("ANIM_SLOW (%f) should be < ANIM_VERY_SLOW (%f)" % [MerlinVisual.ANIM_SLOW, MerlinVisual.ANIM_VERY_SLOW])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 6. UI style constants — non-negative
# ═══════════════════════════════════════════════════════════════════════════════

func test_ui_constants_non_negative() -> bool:
	var vals: Dictionary = {
		"CARD_CORNER_RADIUS": MerlinVisual.CARD_CORNER_RADIUS,
		"CARD_BORDER_WIDTH": MerlinVisual.CARD_BORDER_WIDTH,
		"CARD_SHADOW_SIZE": MerlinVisual.CARD_SHADOW_SIZE,
		"CARD_PADDING": MerlinVisual.CARD_PADDING,
		"MIN_TOUCH_TARGET": MerlinVisual.MIN_TOUCH_TARGET,
		"OUTLINE_SIZE": MerlinVisual.OUTLINE_SIZE,
	}
	for name: String in vals:
		var val: int = vals[name]
		if val < 0:
			push_error("%s should be >= 0, got: %d" % [name, val])
			return false
	return true


func test_min_touch_target_at_least_44() -> bool:
	## WCAG recommends 44px minimum touch targets
	if MerlinVisual.MIN_TOUCH_TARGET < 44:
		push_error("MIN_TOUCH_TARGET (%d) should be >= 44 for accessibility" % MerlinVisual.MIN_TOUCH_TARGET)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 7. PIXEL_TRANSITION config dictionary
# ═══════════════════════════════════════════════════════════════════════════════

func test_pixel_transition_has_required_keys() -> bool:
	var required: Array[String] = [
		"default_block_size", "min_block_size", "max_block_size",
		"exit_duration", "enter_duration", "batch_size", "batch_delay",
		"input_unlock_progress", "bg_color",
	]
	for key: String in required:
		if not MerlinVisual.PIXEL_TRANSITION.has(key):
			push_error("PIXEL_TRANSITION missing key: " + key)
			return false
	return true


func test_pixel_transition_block_size_bounds() -> bool:
	var mn: int = MerlinVisual.PIXEL_TRANSITION["min_block_size"]
	var mx: int = MerlinVisual.PIXEL_TRANSITION["max_block_size"]
	var df: int = MerlinVisual.PIXEL_TRANSITION["default_block_size"]
	if mn <= 0:
		push_error("min_block_size should be > 0, got: %d" % mn)
		return false
	if mx < mn:
		push_error("max_block_size (%d) should be >= min_block_size (%d)" % [mx, mn])
		return false
	if df < mn or df > mx:
		push_error("default_block_size (%d) should be in [%d, %d]" % [df, mn, mx])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 8. SEASON constants — completeness and mapping
# ═══════════════════════════════════════════════════════════════════════════════

func test_season_key_map_covers_all_english_seasons() -> bool:
	var expected: Array[String] = ["spring", "summer", "autumn", "winter"]
	for s: String in expected:
		if not MerlinVisual.SEASON_KEY_MAP.has(s):
			push_error("SEASON_KEY_MAP missing English key: " + s)
			return false
	return true


func test_seasonal_palettes_cover_all_seasons() -> bool:
	var expected: Array[String] = ["spring", "summer", "autumn", "winter"]
	for s: String in expected:
		if not MerlinVisual.SEASONAL_PALETTES.has(s):
			push_error("SEASONAL_PALETTES missing season: " + s)
			return false
		var pal: Dictionary = MerlinVisual.SEASONAL_PALETTES[s]
		for key: String in ["fog_tint", "particle_color", "bg_modulate"]:
			if not pal.has(key):
				push_error("SEASONAL_PALETTES[%s] missing key: %s" % [s, key])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 9. BIOME CRT PALETTES — 8 colors per biome, darkest to brightest
# ═══════════════════════════════════════════════════════════════════════════════

func test_biome_crt_palettes_have_8_colors() -> bool:
	for biome: String in MerlinVisual.BIOME_CRT_PALETTES:
		var colors: Array = MerlinVisual.BIOME_CRT_PALETTES[biome]
		if colors.size() != 8:
			push_error("BIOME_CRT_PALETTES[%s] has %d colors, expected 8" % [biome, colors.size()])
			return false
		for i: int in range(8):
			if not (colors[i] is Color):
				push_error("BIOME_CRT_PALETTES[%s][%d] is not a Color" % [biome, i])
				return false
	return true


func test_biome_crt_palettes_luminance_increases() -> bool:
	## Each biome palette should go from dark (index 0) to bright (index 7).
	for biome: String in MerlinVisual.BIOME_CRT_PALETTES:
		var colors: Array = MerlinVisual.BIOME_CRT_PALETTES[biome]
		var prev_lum: float = -1.0
		for i: int in range(8):
			var c: Color = colors[i]
			var lum: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
			if lum < prev_lum - 0.001:
				push_error("BIOME_CRT_PALETTES[%s] luminance decreases at index %d (%.3f < %.3f)" % [biome, i, lum, prev_lum])
				return false
			prev_lum = lum
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 10. FONT_PATHS — structural integrity
# ═══════════════════════════════════════════════════════════════════════════════

func test_font_paths_keys_exist() -> bool:
	var required: Array[String] = ["title", "body", "terminal", "celtic"]
	for key: String in required:
		if not MerlinVisual.FONT_PATHS.has(key):
			push_error("FONT_PATHS missing key: " + key)
			return false
		var paths: Array = MerlinVisual.FONT_PATHS[key]
		if paths.is_empty():
			push_error("FONT_PATHS[%s] is empty" % key)
			return false
		for p: String in paths:
			if not p.begins_with("res://"):
				push_error("FONT_PATHS[%s] path does not start with res://: %s" % [key, p])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 11. FACTION colors in CRT_PALETTE
# ═══════════════════════════════════════════════════════════════════════════════

func test_faction_colors_present() -> bool:
	var factions: Array[String] = [
		"faction_druides", "faction_anciens", "faction_korrigans",
		"faction_niamh", "faction_ankou",
	]
	for key: String in factions:
		if not MerlinVisual.CRT_PALETTE.has(key):
			push_error("CRT_PALETTE missing faction color: " + key)
			return false
		var c: Color = MerlinVisual.CRT_PALETTE[key]
		if not _is_valid_color(c):
			push_error("CRT_PALETTE[%s] has non-finite component" % key)
			return false
	return true
