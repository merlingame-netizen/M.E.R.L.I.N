## ═══════════════════════════════════════════════════════════════════════════════
## MerlinVisual — Centralized Visual System (Autoload Singleton)
## ═══════════════════════════════════════════════════════════════════════════════
## Single source of truth for ALL visual constants.
## Palette data lives in MerlinVisualPalettes (merlin_visual_palettes.gd).
## This file re-exports all palette constants for backward compatibility.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node


# ═══════════════════════════════════════════════════════════════════════════════
# RE-EXPORTED PALETTE CONSTANTS (public API unchanged)
# ═══════════════════════════════════════════════════════════════════════════════

const CRT_PALETTE := MerlinVisualPalettes.CRT_PALETTE
const VISUAL_TAG_TINTS := MerlinVisualPalettes.VISUAL_TAG_TINTS
const PALETTE := MerlinVisualPalettes.PALETTE
const REWARD_BADGE := MerlinVisualPalettes.REWARD_BADGE
const GBC := MerlinVisualPalettes.GBC
const CRT_ASPECT_COLORS := MerlinVisualPalettes.CRT_ASPECT_COLORS
const TIME_OF_DAY_COLORS := MerlinVisualPalettes.TIME_OF_DAY_COLORS
const MODULATE_PULSE := MerlinVisualPalettes.MODULATE_PULSE
const MODULATE_GLOW := MerlinVisualPalettes.MODULATE_GLOW
const MODULATE_GLOW_DIM := MerlinVisualPalettes.MODULATE_GLOW_DIM
const MODULATE_HIGHLIGHT := MerlinVisualPalettes.MODULATE_HIGHLIGHT
const LLM_STATUS := MerlinVisualPalettes.LLM_STATUS
const SEASON_COLORS := MerlinVisualPalettes.SEASON_COLORS
const SEASON_TINTS := MerlinVisualPalettes.SEASON_TINTS
const SEASON_KEY_MAP := MerlinVisualPalettes.SEASON_KEY_MAP
const SEASONAL_PALETTES := MerlinVisualPalettes.SEASONAL_PALETTES
const BIOME_ART_PROFILES := MerlinVisualPalettes.BIOME_ART_PROFILES
const BIOME_COLORS := MerlinVisualPalettes.BIOME_COLORS
const BIOME_VISUALS := MerlinVisualPalettes.BIOME_VISUALS
const BIOME_CRT_PALETTES := MerlinVisualPalettes.BIOME_CRT_PALETTES
const BIOME_CRT_PROFILES := MerlinVisualPalettes.BIOME_CRT_PROFILES


# ═══════════════════════════════════════════════════════════════════════════════
# FONTS — Paths & Sizes
# ═══════════════════════════════════════════════════════════════════════════════

const FONT_PATHS := {
	"title": ["res://resources/fonts/terminal/VT323-Regular.ttf"],
	"body": ["res://resources/fonts/terminal/VT323-Regular.ttf"],
	"terminal": ["res://resources/fonts/terminal/VT323-Regular.ttf"],
	"celtic": ["res://resources/fonts/celtic_bit/celtic-bit.ttf"],
	# Legacy fonts (rollback)
	"title_legacy": ["res://resources/fonts/morris/MorrisRomanBlack.otf", "res://resources/fonts/morris/MorrisRomanBlack.ttf"],
	"body_legacy": ["res://resources/fonts/morris/MorrisRomanBlackAlt.otf", "res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"],
}

const TITLE_SIZE := 52
const TITLE_SMALL := 38
const BODY_SIZE := 22
const BODY_LARGE := 26
const BODY_SMALL := 17
const CAPTION_SIZE := 16
const CAPTION_LARGE := 14
const CAPTION_SMALL := 13
const CAPTION_TINY := 10
const BUTTON_SIZE := 22

# Outline defaults for CRT readability (phosphor on dark CRT + scanlines)
const OUTLINE_SIZE := 2
const OUTLINE_COLOR: Color = Color(0.02, 0.04, 0.02)

var _font_cache: Dictionary = {}


func get_font(type: String) -> Font:
	if _font_cache.has(type):
		return _font_cache[type]
	var result: Font = null
	if FONT_PATHS.has(type):
		for path: String in FONT_PATHS[type]:
			if ResourceLoader.exists(path):
				var res: Resource = load(path)
				if res is Font:
					result = res
					break
	_font_cache[type] = result
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# SEASON HELPERS
# ═══════════════════════════════════════════════════════════════════════════════


func get_current_season() -> String:
	## Returns current real-world season as English key (spring/summer/autumn/winter).
	var today := Time.get_date_dict_from_system()
	var m: int = today.get("month", 1)
	if m >= 3 and m <= 5:
		return "spring"
	elif m >= 6 and m <= 8:
		return "summer"
	elif m >= 9 and m <= 11:
		return "autumn"
	return "winter"


func get_seasonal_tint() -> Color:
	## Returns the current season's French-keyed tint from SEASON_TINTS.
	var fr_key: String = SEASON_KEY_MAP.get(get_current_season(), "hiver")
	return SEASON_TINTS.get(fr_key, Color(1, 1, 1))


func get_seasonal_palette() -> Dictionary:
	## Returns current season's full visual palette (fog_tint, particle_color, bg_modulate).
	return SEASONAL_PALETTES.get(get_current_season(), SEASONAL_PALETTES["winter"])


# ═══════════════════════════════════════════════════════════════════════════════
# ANIMATION CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

# UI reaction speeds
const ANIM_FAST := 0.2
const ANIM_NORMAL := 0.3
const ANIM_SLOW := 0.5
const ANIM_VERY_SLOW := 1.5

# Typewriter (terminal-speed for CRT aesthetic)
const TW_DELAY := 0.015
const TW_PUNCT_DELAY := 0.060
const TW_BLIP_FREQ := 880.0
const TW_BLIP_DURATION := 0.018
const TW_BLIP_VOLUME := 0.04

# CRT terminal animations
const CRT_CURSOR_BLINK := 0.53
const CRT_BOOT_LINE_DELAY := 0.12
const CRT_PHOSPHOR_FADE := 0.4
const CRT_GLITCH_DURATION := 0.08

# Breathing / ambient
const BREATHE_DURATION := 5.0
const BREATHE_SCALE_MIN := 1.0
const BREATHE_SCALE_MAX := 1.005

# Card float
const CARD_FLOAT_OFFSET := 5.0
const CARD_FLOAT_DURATION := 2.8

# Card animation — dramatic timings
const CARD_ENTRY_DURATION := 0.65
const CARD_ENTRY_OVERSHOOT := 1.10
const CARD_ENTRY_SETTLE := 0.20
const CARD_EXIT_DURATION := 0.55
const CARD_DEAL_DURATION := 0.35
const CARD_DEAL_ARC_HEIGHT := 60.0

# Fake 3D card tilt (perspective effect on mouse hover)
const CARD_3D_TILT_MAX := 7.0         # Max rotation degrees (visible but not excessive)
const CARD_3D_SCALE_HOVER := 1.055    # Noticeable enlargement on hover
const CARD_3D_SHADOW_SHIFT := 10.0    # Dynamic shadow offset shift (px)
const CARD_3D_TILT_SPEED := 8.0       # Interpolation speed (slightly smoother)
const CARD_3D_SHINE_ALPHA := 0.10     # Visible highlight overlay

# Layered sprite system (feature flag — set true to use CardSceneCompositor)
const USE_LAYERED_SPRITES := true
const LAYER_REVEAL_STAGGER := 0.08    # Delay between each layer fade-in
const LAYER_REVEAL_SLIDE := 10.0      # Slide-up offset in pixels
const LAYER_REVEAL_DURATION := 0.30   # Per-layer reveal duration
const PARALLAX_MAX_SHIFT := 8.0       # Max parallax offset in pixels on hover
const SELECTION_STAMP_SCALE := 1.03   # Card scale on option selection
const LAYER_ILLUSTRATION_SIZE := Vector2(440.0, 220.0)

# Option button animation
const OPTION_STAGGER_DELAY := 0.12
const OPTION_SLIDE_DURATION := 0.35
const OPTION_SLIDE_OFFSET := 40.0

# Easing defaults
const EASING_UI: int = Tween.EASE_OUT
const TRANS_UI: int = Tween.TRANS_SINE
const EASING_PATH: int = Tween.EASE_IN_OUT
const TRANS_PATH: int = Tween.TRANS_CUBIC

# Pixel transition system (PixelTransition autoload)
const PIXEL_TRANSITION := {
	"default_block_size": 10,
	"min_block_size": 6,
	"max_block_size": 16,
	"exit_duration": 0.6,
	"enter_duration": 0.8,
	"batch_size": 8,
	"batch_delay": 0.012,
	"input_unlock_progress": 0.7,
	"bg_color": Color(0.02, 0.04, 0.02),
}


# ═══════════════════════════════════════════════════════════════════════════════
# CRT ANIMATION HELPERS
# ═══════════════════════════════════════════════════════════════════════════════


## Create a blinking cursor label (appended to typewriter text)
static func create_cursor_blink(parent: Node) -> Timer:
	var cursor := Label.new()
	cursor.text = "_"
	cursor.add_theme_color_override("font_color", CRT_PALETTE["phosphor"])
	cursor.name = "CRTCursor"
	parent.add_child(cursor)
	var timer := Timer.new()
	timer.wait_time = CRT_CURSOR_BLINK
	timer.autostart = true
	timer.timeout.connect(func() -> void: cursor.visible = not cursor.visible)
	parent.add_child(timer)
	return timer


## Phosphor text reveal — text fades in from dim to bright phosphor green
static func phosphor_reveal(label: Label, duration: float = 0.4) -> Tween:
	var dim: Color = CRT_PALETTE["phosphor_dim"]
	var bright: Color = CRT_PALETTE["phosphor"]
	label.add_theme_color_override("font_color", dim)
	label.modulate.a = 0.0
	var tw := label.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_EXPO)
	tw.tween_property(label, "modulate:a", 1.0, duration * 0.3)
	tw.tween_method(
		func(t: float) -> void:
			label.add_theme_color_override("font_color", dim.lerp(bright, t)),
		0.0, 1.0, duration * 0.7
	)
	return tw


## Phosphor fade-out — text dims with afterglow (old CRT phosphor persistence)
static func phosphor_fade(label: Label, duration: float = 0.6) -> Tween:
	var tw := label.create_tween()
	tw.set_ease(Tween.EASE_IN)
	tw.set_trans(Tween.TRANS_QUAD)
	tw.tween_method(
		func(t: float) -> void:
			var c: Color = CRT_PALETTE["phosphor"].lerp(CRT_PALETTE["phosphor_dim"], t)
			label.add_theme_color_override("font_color", c)
			label.modulate.a = 1.0 - (t * 0.85),
		0.0, 1.0, duration
	)
	return tw


## CRT boot line — types a line with staggered character delay (terminal boot sequence feel)
static func boot_line_type(label: Label, full_text: String, char_delay: float = -1.0) -> void:
	if char_delay < 0.0:
		char_delay = CRT_BOOT_LINE_DELAY
	label.text = ""
	label.add_theme_color_override("font_color", CRT_PALETTE["phosphor"])
	var tree := label.get_tree()
	if tree == null:
		label.text = full_text
		return
	for i in range(full_text.length()):
		label.text += full_text[i]
		await tree.create_timer(char_delay).timeout
		if not label.is_inside_tree():
			return


## CRT glitch pulse — flash the screen effect briefly
static func glitch_pulse(duration: float = -1.0) -> void:
	if duration < 0.0:
		duration = CRT_GLITCH_DURATION
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var fx: Node = tree.root.get_node_or_null("ScreenEffects")
	if fx and fx.has_method("glitch_pulse"):
		fx.glitch_pulse(duration)


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME CRT HELPERS
# ═══════════════════════════════════════════════════════════════════════════════


## Generate an 8x1 palette texture from a biome's CRT palette (for palette_swap.gdshader)
static func create_biome_palette_texture(biome: String) -> ImageTexture:
	var colors: Array = BIOME_CRT_PALETTES.get(biome, BIOME_CRT_PALETTES["broceliande"])
	var image := Image.create(8, 1, false, Image.FORMAT_RGBA8)
	for i in range(8):
		image.set_pixel(i, 0, colors[i])
	return ImageTexture.create_from_image(image)


## Apply biome CRT profile to ScreenDither (CRTLayer autoload)
static func apply_biome_crt(biome: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var crt: Node = tree.root.get_node_or_null("ScreenDither")
	if crt == null:
		return
	var palette: Array = BIOME_CRT_PALETTES.get(biome, BIOME_CRT_PALETTES["broceliande"])
	var profile: Dictionary = BIOME_CRT_PROFILES.get(biome, BIOME_CRT_PROFILES["broceliande"])
	# Set phosphor tint to biome's mid-bright color (index 5)
	crt.set_phosphor_tint(palette[5])
	# Apply biome distortion profile
	for param_name: String in profile:
		crt.set_shader_parameter(param_name, profile[param_name])


# ═══════════════════════════════════════════════════════════════════════════════
# UI STYLE HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

const CARD_CORNER_RADIUS := 0
const CARD_BORDER_WIDTH := 1
const CARD_SHADOW_SIZE := 0
const CARD_PADDING := 24
const MIN_TOUCH_TARGET := 48


static func celtic_ornament() -> String:
	return "\u27C2\u2022\u27C2\u27C2#\u27C2\u27C2\u2022\u27C2"


## Button normal — dark bg with dim border
static func make_button_normal() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CRT_PALETTE["bg_dark"]
	style.border_color = CRT_PALETTE["border"]
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(12)
	return style


## Button hover — highlighted bg with phosphor border
static func make_button_hover() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CRT_PALETTE["bg_highlight"]
	style.border_color = CRT_PALETTE["phosphor_dim"]
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(12)
	return style


## Button pressed — amber flash with bright border
static func make_button_pressed() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(CRT_PALETTE["amber"].r, CRT_PALETTE["amber"].g, CRT_PALETTE["amber"].b, 0.20)
	style.border_color = CRT_PALETTE["amber"]
	style.set_border_width_all(1)
	style.set_corner_radius_all(0)
	style.set_content_margin_all(12)
	return style


## Apply full CRT button theme (normal/hover/pressed + phosphor text)
static func apply_button_theme(button: Button) -> void:
	button.add_theme_stylebox_override("normal", make_button_normal())
	button.add_theme_stylebox_override("hover", make_button_hover())
	button.add_theme_stylebox_override("pressed", make_button_pressed())
	button.add_theme_color_override("font_color", CRT_PALETTE["phosphor"])
	button.add_theme_color_override("font_hover_color", CRT_PALETTE["phosphor_bright"])
	button.add_theme_color_override("font_pressed_color", CRT_PALETTE["amber"])
	button.custom_minimum_size.y = MIN_TOUCH_TARGET


# ═══════════════════════════════════════════════════════════════════════════════
# CACHED STYLE FACTORIES — Central style registry (Phase 1 migration)
# ═══════════════════════════════════════════════════════════════════════════════
# Use these instead of scattered StyleBoxFlat.new() calls.
# Call with unique=true when the node will animate/modify the style at runtime.

static var _style_cache: Dictionary = {}


static func _get_or_create(key: String, creator: Callable, unique: bool = false) -> StyleBoxFlat:
	if unique:
		return creator.call()
	if not _style_cache.has(key):
		_style_cache[key] = creator.call()
	return _style_cache[key]


## Clock/status panel — CRT status bar with amber border
static func make_clock_panel_style(unique: bool = false) -> StyleBoxFlat:
	return _get_or_create("clock_panel", func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(CRT_PALETTE.bg_dark.r, CRT_PALETTE.bg_dark.g, CRT_PALETTE.bg_dark.b, 0.92)
		s.border_color = CRT_PALETTE.amber_dim
		s.set_border_width_all(1)
		s.set_corner_radius_all(0)
		s.content_margin_left = 10
		s.content_margin_right = 10
		s.content_margin_top = 5
		s.content_margin_bottom = 4
		return s
	, unique)


## Card panel — terminal card frame with amber border (visibilite maximale vs biome)
static func make_card_panel_style(unique: bool = false) -> StyleBoxFlat:
	return _get_or_create("card_panel", func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = CRT_PALETTE.bg_deep          # Plus sombre, pleine opacite
		s.border_color = CRT_PALETTE.amber        # Ambre chaud = contraste fort
		s.set_border_width_all(3)                 # 2->3px, plus lisible
		s.set_corner_radius_all(0)
		s.shadow_size = 0
		return s
	, unique)


## Card illustration — deep black for pixel art rendering
static func make_card_illustration_style(unique: bool = false) -> StyleBoxFlat:
	return _get_or_create("card_illo", func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(CRT_PALETTE.bg_deep.r, CRT_PALETTE.bg_deep.g, CRT_PALETTE.bg_deep.b, 0.99)
		s.border_color = Color(CRT_PALETTE.border.r, CRT_PALETTE.border.g, CRT_PALETTE.border.b, 0.5)
		s.set_border_width_all(1)
		s.set_corner_radius_all(0)
		s.set_content_margin_all(6)
		return s
	, unique)


## Card body — terminal reading area with amber-dim border
static func make_card_body_style(unique: bool = false) -> StyleBoxFlat:
	return _get_or_create("card_body", func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(CRT_PALETTE.bg_deep.r, CRT_PALETTE.bg_deep.g, CRT_PALETTE.bg_deep.b, 0.99)
		s.border_color = Color(CRT_PALETTE.amber_dim.r, CRT_PALETTE.amber_dim.g, CRT_PALETTE.amber_dim.b, 0.75)
		s.set_border_width_all(2)                 # 1->2px, plus visible
		s.set_corner_radius_all(0)
		s.content_margin_left = 18
		s.content_margin_right = 18
		s.content_margin_top = 12
		s.content_margin_bottom = 12
		return s
	, unique)


## Discard pile card — dim terminal card with amber trace
static func make_discard_card_style(unique: bool = false) -> StyleBoxFlat:
	return _get_or_create("discard_card", func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(CRT_PALETTE.bg_deep.r, CRT_PALETTE.bg_deep.g, CRT_PALETTE.bg_deep.b, 0.70)
		s.border_color = Color(CRT_PALETTE.amber_dim.r, CRT_PALETTE.amber_dim.g, CRT_PALETTE.amber_dim.b, 0.60)
		s.set_border_width_all(1)
		s.set_corner_radius_all(0)
		s.shadow_size = 0
		return s
	, unique)


## Progress bar background — dark terminal track
static func make_bar_bg_style(unique: bool = false) -> StyleBoxFlat:
	return _get_or_create("bar_bg", func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(CRT_PALETTE.bg_deep.r, CRT_PALETTE.bg_deep.g, CRT_PALETTE.bg_deep.b, 0.70)
		s.border_color = CRT_PALETTE.border
		s.set_border_width_all(1)
		s.set_corner_radius_all(0)
		return s
	, unique)


## Progress bar fill — colored fill (resolves from CRT_PALETTE first, then PALETTE)
static func make_bar_fill_style(color_key: String = "danger", unique: bool = false) -> StyleBoxFlat:
	var cache_key := "bar_fill_%s" % color_key
	return _get_or_create(cache_key, func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		if CRT_PALETTE.has(color_key):
			s.bg_color = CRT_PALETTE[color_key]
		elif PALETTE.has(color_key):
			s.bg_color = PALETTE[color_key]
		else:
			s.bg_color = CRT_PALETTE.danger
		s.set_corner_radius_all(0)
		return s
	, unique)


## Modal overlay — deep black with phosphor border
static func make_modal_style(unique: bool = false) -> StyleBoxFlat:
	return _get_or_create("modal", func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(0.01, 0.02, 0.01, 0.92)
		s.border_color = CRT_PALETTE.phosphor_dim
		s.set_border_width_all(2)
		s.set_corner_radius_all(0)
		s.set_content_margin_all(20)
		return s
	, unique)


## Section panel — terminal sub-panel with dim border
static func make_section_panel_style(unique: bool = false) -> StyleBoxFlat:
	return _get_or_create("section_panel", func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(CRT_PALETTE.bg_panel.r, CRT_PALETTE.bg_panel.g, CRT_PALETTE.bg_panel.b, 0.90)
		s.border_color = Color(CRT_PALETTE.border.r, CRT_PALETTE.border.g, CRT_PALETTE.border.b, 0.40)
		s.set_border_width_all(1)
		s.set_corner_radius_all(0)
		s.set_content_margin_all(12)
		return s
	, unique)


## Option button — terminal choice with colored left accent
static func make_option_button_style(accent_color: Color, _unique: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = CRT_PALETTE.bg_dark
	s.border_color = accent_color
	s.border_width_left = 3
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.set_corner_radius_all(0)
	s.content_margin_left = 16
	s.content_margin_right = 14
	s.content_margin_top = 11
	s.content_margin_bottom = 11
	s.shadow_size = 0
	return s


## Apply CRT option button theme (normal/hover/pressed with accent)
static func apply_option_button_theme(btn: Button, accent_color: Color) -> void:
	var normal := make_option_button_style(accent_color)
	btn.add_theme_stylebox_override("normal", normal)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = CRT_PALETTE.bg_highlight
	hover.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 1.0)
	btn.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.18)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", CRT_PALETTE.phosphor)
	btn.add_theme_color_override("font_hover_color", CRT_PALETTE.phosphor_bright)
	btn.add_theme_color_override("font_pressed_color", CRT_PALETTE.amber)
	btn.custom_minimum_size.y = MIN_TOUCH_TARGET


## CRT terminal option style — thick left border accent, sharp corners, fully opaque
static func make_celtic_option_style(accent_color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(CRT_PALETTE.bg_deep.r, CRT_PALETTE.bg_deep.g, CRT_PALETTE.bg_deep.b, 0.97)
	s.border_color = accent_color
	s.border_width_left = 6   # 5->6px : accent dominant gauche
	s.border_width_right = 2  # 1->2px : cadre visible
	s.border_width_top = 2    # 1->2px
	s.border_width_bottom = 2 # 1->2px
	s.set_corner_radius_all(0)
	s.shadow_size = 0
	s.content_margin_left = 18
	s.content_margin_right = 16
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	return s


## Apply CRT terminal option theme (normal/hover/pressed/disabled)
static func apply_celtic_option_theme(btn: Button, accent_color: Color) -> void:
	var normal := make_celtic_option_style(accent_color)
	btn.add_theme_stylebox_override("normal", normal)

	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.10)
	hover.border_width_left = 7
	btn.add_theme_stylebox_override("hover", hover)

	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.20)
	pressed.border_width_left = 3
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled_style: StyleBoxFlat = normal.duplicate()
	disabled_style.bg_color = Color(CRT_PALETTE.inactive.r, CRT_PALETTE.inactive.g, CRT_PALETTE.inactive.b, 0.3)
	disabled_style.border_color = CRT_PALETTE.inactive_dark
	btn.add_theme_stylebox_override("disabled", disabled_style)

	btn.add_theme_color_override("font_color", CRT_PALETTE.phosphor)
	btn.add_theme_color_override("font_hover_color", accent_color)
	btn.add_theme_color_override("font_pressed_color", CRT_PALETTE.amber)
	btn.add_theme_color_override("font_disabled_color", CRT_PALETTE.inactive_dark)
	btn.custom_minimum_size = Vector2(280, 56)


## Apply progress bar theme (bg + fill with custom color)
static func apply_bar_theme(bar: ProgressBar, fill_color_key: String = "danger") -> void:
	bar.add_theme_stylebox_override("background", make_bar_bg_style())
	bar.add_theme_stylebox_override("fill", make_bar_fill_style(fill_color_key))


## Load and return the Merlin theme resource
static func get_merlin_theme() -> Theme:
	var theme_path := "res://themes/merlin_theme.tres"
	if ResourceLoader.exists(theme_path):
		return load(theme_path)
	return null


## Apply the Merlin theme to a root Control node (all children inherit)
static func apply_theme_to_root(root: Control) -> void:
	var theme := get_merlin_theme()
	if theme:
		root.theme = theme


## Responsive font size — delegates to MerlinResponsive if available
static func responsive_size(base: int) -> int:
	var mr: Node = Engine.get_main_loop().root.get_node_or_null("MerlinResponsive") if Engine.get_main_loop() else null
	if mr and mr.has_method("get_font_size"):
		return mr.get_font_size(base)
	return base


## Apply responsive font size override to a Control node
static func apply_responsive_font(control: Control, base_size: int, font_type: String = "body") -> void:
	var font: Font = MerlinVisual.get_font(font_type)
	if font:
		control.add_theme_font_override("font", font)
	control.add_theme_font_size_override("font_size", responsive_size(base_size))


# ═══════════════════════════════════════════════════════════════════════════════
# KINGDOM TWO CROWNS PORTRAIT HELPERS (D.2)
# ═══════════════════════════════════════════════════════════════════════════════
# Pipeline: pixel art reference -> shader + palette swap -> GBC aesthetic


## Create a Kingdom Two Crowns style portrait material (palette swap + outline)
## @param biome: biome key for palette selection (default "broceliande")
## @return ShaderMaterial configured for Kingdom Two Crowns aesthetic
static func create_kingdom_portrait_material(biome: String = "broceliande") -> ShaderMaterial:
	var shader: Shader = load("res://shaders/palette_swap.gdshader")
	var material := ShaderMaterial.new()
	material.shader = shader

	# Create palette texture from biome CRT palette
	var palette_tex: ImageTexture = create_kingdom_palette(biome)
	material.set_shader_parameter("palette", palette_tex)
	material.set_shader_parameter("target_row", 1)
	material.set_shader_parameter("tolerance", 0.02)
	material.set_shader_parameter("blend", 1.0)

	return material


## Create Kingdom Two Crowns palette texture (reference row + target row)
## @param biome: biome key for target palette
## @return ImageTexture with reference colors (row 0) and biome palette (row 1)
static func create_kingdom_palette(biome: String = "broceliande") -> ImageTexture:
	var biome_colors: Array = BIOME_CRT_PALETTES.get(biome, BIOME_CRT_PALETTES["broceliande"])

	# Reference palette — standard grayscale 8 levels (what the pixel art uses)
	var reference_palette: Array = [
		Color(0.00, 0.00, 0.00),  # Black (darkest)
		Color(0.14, 0.14, 0.14),  # Very dark gray
		Color(0.29, 0.29, 0.29),  # Dark gray
		Color(0.43, 0.43, 0.43),  # Medium-dark gray
		Color(0.57, 0.57, 0.57),  # Medium gray
		Color(0.71, 0.71, 0.71),  # Medium-light gray
		Color(0.86, 0.86, 0.86),  # Light gray
		Color(1.00, 1.00, 1.00),  # White (brightest)
	]

	# Create 8x2 image (8 colors wide, 2 rows tall)
	var img := Image.create(8, 2, false, Image.FORMAT_RGBA8)

	# Row 0: reference palette (grayscale)
	for i: int in range(8):
		img.set_pixel(i, 0, reference_palette[i])

	# Row 1: target palette (biome CRT colors)
	for i: int in range(8):
		img.set_pixel(i, 1, biome_colors[i])

	return ImageTexture.create_from_image(img)


## Apply Kingdom Two Crowns style to a TextureRect (portrait node)
## @param portrait: TextureRect containing pixel art
## @param biome: biome key for palette (default current biome or "broceliande")
static func apply_kingdom_portrait(portrait: TextureRect, biome: String = "") -> void:
	if biome.is_empty():
		biome = "broceliande"  # Default fallback

	var material: ShaderMaterial = create_kingdom_portrait_material(biome)
	portrait.material = material

	# Ensure texture filtering is off (pixel-perfect)
	if portrait.texture:
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
