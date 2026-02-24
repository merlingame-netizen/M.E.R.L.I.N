## ═══════════════════════════════════════════════════════════════════════════════
## MerlinVisual — Centralized Visual System (Autoload Singleton)
## ═══════════════════════════════════════════════════════════════════════════════
## Single source of truth for ALL visual constants:
## - CRT_PALETTE (active) — CRT terminal druido-tech aesthetic
## - PALETTE (legacy) — Parchemin Mystique Breton (rollback)
## - BIOME_CRT_PALETTES — 8 colors per biome (strict)
## - CRT_ASPECT_COLORS — Triade in terminal phosphor
## - GBC & Jugdral21 (reference palettes, biome pixel art)
## - Font references & sizes (VT323 monospace terminal)
## - Animation constants & easing defaults
## - Panel style helpers (CRT terminal panels)
## ═══════════════════════════════════════════════════════════════════════════════

extends Node


# ═══════════════════════════════════════════════════════════════════════════════
# CRT_PALETTE — CRT Terminal Druido-Tech (active palette)
# ═══════════════════════════════════════════════════════════════════════════════
# Merlin is an AI from the future. The player sees through a CRT terminal.
# Dark backgrounds, phosphor green text, amber accents, cyan mystic highlights.

const CRT_PALETTE := {
	# Terminal backgrounds (dark with green tinge)
	"bg_deep":        Color(0.02, 0.04, 0.02),
	"bg_dark":        Color(0.04, 0.08, 0.04),
	"bg_panel":       Color(0.06, 0.12, 0.06),
	"bg_highlight":   Color(0.08, 0.16, 0.08),

	# Phosphor text (primary green)
	"phosphor":       Color(0.20, 1.00, 0.40),
	"phosphor_dim":   Color(0.12, 0.60, 0.24),
	"phosphor_bright": Color(0.40, 1.00, 0.60),
	"phosphor_glow":  Color(0.20, 1.00, 0.40, 0.15),

	# Amber accent (secondary terminal color)
	"amber":          Color(1.00, 0.75, 0.20),
	"amber_dim":      Color(0.60, 0.45, 0.12),
	"amber_bright":   Color(1.00, 0.85, 0.40),

	# Celtic mystic (tertiary — magic/special)
	"cyan":           Color(0.30, 0.85, 0.80),
	"cyan_dim":       Color(0.15, 0.42, 0.40),

	# Status colors (terminal-style)
	"danger":         Color(1.00, 0.20, 0.15),
	"success":        Color(0.20, 1.00, 0.40),
	"warning":        Color(1.00, 0.75, 0.20),
	"inactive":       Color(0.20, 0.25, 0.20),
	"inactive_dark":  Color(0.12, 0.15, 0.12),

	# Structural
	"border":         Color(0.12, 0.30, 0.14),
	"border_bright":  Color(0.20, 0.50, 0.24),
	"shadow":         Color(0.00, 0.00, 0.00, 0.40),
	"scanline":       Color(0.00, 0.00, 0.00, 0.15),
	"line":           Color(0.12, 0.30, 0.14, 0.25),
	"mist":           Color(0.10, 0.20, 0.10, 0.20),

	# Souffle d'Ogham
	"souffle":        Color(0.30, 0.85, 0.80),
	"souffle_full":   Color(1.00, 0.85, 0.40),

	# Gameplay UI
	"ogham_glow":     Color(0.30, 0.85, 0.80),
	"bestiole":       Color(0.30, 0.70, 0.90),

	# CeltOS Intro — boot sequence
	"block":          Color(0.20, 1.00, 0.40),
	"block_alt":      Color(0.15, 0.75, 0.30),
	"eye_cyan":       Color(0.30, 0.85, 0.80),
	"eye_white":      Color(0.60, 1.00, 0.70),
	"eye_deep":       Color(0.02, 0.06, 0.04),
	"eye_outer":      Color(0.10, 0.30, 0.20),
	"eye_bright":     Color(0.40, 1.00, 0.60),
	"slit_glow":      Color(1.00, 0.85, 0.40),

	# Choice buttons (quiz, dialogues)
	"choice_normal":  Color(0.12, 0.60, 0.24),
	"choice_hover":   Color(0.20, 1.00, 0.40),
	"choice_selected": Color(1.00, 0.75, 0.20),

	# Calendar events
	"event_today":    Color(1.00, 0.75, 0.20),
	"event_past":     Color(0.20, 0.25, 0.20),

	# Map UI
	"locked":         Color(0.15, 0.20, 0.15, 0.50),

	# Reward badge (card hover)
	"reward_bg":      Color(0.04, 0.08, 0.04, 0.92),
	"reward_border":  Color(0.20, 1.00, 0.40, 0.75),

	# LLM Status Bar
	"llm_bg":         Color(0.02, 0.04, 0.02, 0.85),
	"llm_bg_hover":   Color(0.04, 0.08, 0.04, 0.95),
	"llm_text":       Color(0.20, 1.00, 0.40),
	"llm_success":    Color(0.20, 1.00, 0.40),
	"llm_warning":    Color(1.00, 0.75, 0.20),
	"llm_error":      Color(1.00, 0.20, 0.15),
}

# ═══════════════════════════════════════════════════════════════════════════════
# PALETTE — Parchemin Mystique Breton (legacy, kept for gradual migration)
# ═══════════════════════════════════════════════════════════════════════════════
# Scenes will be migrated from PALETTE to CRT_PALETTE one by one.
# Once all scenes are migrated, PALETTE can be removed.

const PALETTE := {
	# Paper tones
	"paper": Color(0.965, 0.945, 0.905),
	"paper_dark": Color(0.935, 0.905, 0.855),
	"paper_warm": Color(0.955, 0.930, 0.890),

	# Ink tones
	"ink": Color(0.22, 0.18, 0.14),
	"ink_soft": Color(0.38, 0.32, 0.26),
	"ink_faded": Color(0.50, 0.44, 0.38, 0.35),

	# Accent (bronze/gold)
	"accent": Color(0.58, 0.44, 0.26),
	"accent_soft": Color(0.65, 0.52, 0.34),
	"accent_glow": Color(0.72, 0.58, 0.38, 0.25),

	# Structural
	"shadow": Color(0.25, 0.20, 0.16, 0.18),
	"line": Color(0.40, 0.34, 0.28, 0.12),
	"mist": Color(0.94, 0.92, 0.88, 0.35),

	# Celtic metals & elements
	"celtic_gold": Color(0.68, 0.55, 0.32),
	"celtic_brown": Color(0.45, 0.36, 0.28),
	"celtic_green": Color(0.35, 0.55, 0.28),
	"celtic_red": Color(0.72, 0.28, 0.22),
	"celtic_purple": Color(0.52, 0.38, 0.62),

	# Gameplay UI
	"ogham_glow": Color(0.45, 0.62, 0.32),
	"bestiole": Color(0.42, 0.60, 0.72),

	# Status
	"danger": Color(0.72, 0.28, 0.22),
	"success": Color(0.32, 0.58, 0.28),
	"warning": Color(0.72, 0.58, 0.22),

	# Souffle d'Ogham
	"souffle": Color(0.30, 0.70, 0.90),
	"souffle_full": Color(0.85, 0.75, 0.30),

	# UI neutral
	"inactive": Color(0.50, 0.50, 0.50),
	"inactive_dark": Color(0.40, 0.40, 0.40),

	# Calendar events
	"event_today": Color(0.68, 0.55, 0.32),  # celtic_gold
	"event_past": Color(0.50, 0.44, 0.38),   # ink_faded without alpha

	# Map UI
	"locked": Color(0.50, 0.44, 0.38, 0.50),  # Locked biome nodes

	# CeltOS Intro — boot sequence blocks & eye animation
	"block": Color(0.65, 0.52, 0.34),           # Logo block (amber)
	"block_alt": Color(0.58, 0.44, 0.26),       # Logo block alternate (bronze)
	"eye_cyan": Color(0.30, 0.85, 0.80),        # Eye main color (teal)
	"eye_white": Color(0.95, 0.95, 0.90),       # Eye highlight (warm white)
	"eye_deep": Color(0.08, 0.12, 0.15),        # Eye base (very dark)
	"eye_outer": Color(0.15, 0.40, 0.45),       # Outer iris (dark teal)
	"eye_bright": Color(0.60, 0.95, 0.90),      # Bright accent (cyan-white)
	"slit_glow": Color(0.85, 0.75, 0.30),       # Pupil slit (golden)

	# Choice buttons (quiz, dialogues)
	"choice_normal": Color(0.92, 0.88, 0.80),   # Warm parchment text
	"choice_hover": Color(0.68, 0.55, 0.32),    # Celtic gold highlight
	"choice_selected": Color(0.35, 0.55, 0.28), # Celtic green confirm
}

# Reward badge tooltip styling (card option hover — uses CRT_PALETTE)
const REWARD_BADGE := {
	"bg": Color(0.04, 0.08, 0.04, 0.92),
	"border": Color(0.20, 1.00, 0.40, 0.75),
}


# ═══════════════════════════════════════════════════════════════════════════════
# JUGDRAL21 — Medieval pixel art palette (Lospec, 21 colors)
# ═══════════════════════════════════════════════════════════════════════════════
# Source: https://lospec.com/palette-list/jugdral21
# "Medieval theme with focus on midtones, greens through browns.
#  Highlights muted, dark tones saturated for colorful shadows."
# Tags: fantasy, earthy, dim, nature, medieval, restrained, dusty

const JUGDRAL21 := {
	"deep_bark":    Color("#1a120e"),  # Darkest brown-black
	"shadow_plum":  Color("#2c1c22"),  # Dark plum shadow
	"slate":        Color("#363339"),  # Cool dark gray
	"stone":        Color("#4c4651"),  # Medium gray-purple
	"blood":        Color("#552320"),  # Dark red-brown
	"rust":         Color("#764535"),  # Warm rust
	"bronze":       Color("#785f39"),  # Warm bronze
	"ember":        Color("#944a42"),  # Warm red
	"deep_blue":    Color("#212a64"),  # Deep royal blue
	"storm":        Color("#374351"),  # Blue-gray
	"moss":         Color("#3d5c52"),  # Dark teal-green
	"jade":         Color("#5c947c"),  # Bright jade green
	"forest":       Color("#3f6f46"),  # Forest green
	"leaf":         Color("#53693d"),  # Leaf green
	"sage":         Color("#768148"),  # Sage/olive
	"sky_wash":     Color("#98aad8"),  # Muted sky blue
	"honey":        Color("#c49256"),  # Warm honey gold
	"sand":         Color("#a88d7b"),  # Sandy warm gray
	"parchment":    Color("#c0b8ad"),  # Light warm gray
	"cloud":        Color("#e3dbe0"),  # Near-white warm
	"wheat":        Color("#d8ce98"),  # Warm wheat yellow
}

# Mapping: Jugdral21 -> M.E.R.L.I.N. semantic roles
# Used by Parchemin+ style for unified pixel art across all scenes
const PARCHMENT_PLUS := {
	# Backgrounds
	"bg_light": Color("#e3dbe0"),     # cloud — lightest bg
	"bg_warm": Color("#c0b8ad"),      # parchment — standard paper
	"bg_mid": Color("#a88d7b"),       # sand — darker panels

	# Inks & outlines
	"ink_deep": Color("#1a120e"),     # deep_bark — darkest outlines
	"ink_warm": Color("#2c1c22"),     # shadow_plum — warm dark
	"ink_mid": Color("#4c4651"),      # stone — medium text

	# Accents & metals
	"gold": Color("#c49256"),         # honey — celtic gold equivalent
	"bronze": Color("#785f39"),       # bronze — secondary metal
	"wheat": Color("#d8ce98"),        # wheat — highlight, glow

	# Nature (biomes)
	"forest": Color("#3f6f46"),       # forest — Broceliande
	"moss": Color("#3d5c52"),         # moss — Marais
	"jade": Color("#5c947c"),         # jade — highlight nature
	"sage": Color("#768148"),         # sage — Collines, Landes
	"leaf": Color("#53693d"),         # leaf — mid nature

	# Warmth (Corps, fire, villages)
	"rust": Color("#764535"),         # rust — Corps aspect
	"ember": Color("#944a42"),        # ember — danger, fire
	"blood": Color("#552320"),        # blood — dark danger

	# Cool (Ame, mystery, circles)
	"deep_blue": Color("#212a64"),    # deep_blue — Ame aspect
	"storm": Color("#374351"),        # storm — mystery, night
	"sky_wash": Color("#98aad8"),     # sky_wash — light magic

	# Neutral structure
	"slate": Color("#363339"),        # slate — UI borders
	"stone": Color("#4c4651"),        # stone — disabled states
}


# ═══════════════════════════════════════════════════════════════════════════════
# GBC PALETTE — Game Boy Color inspired (from game_manager.gd)
# ═══════════════════════════════════════════════════════════════════════════════

const GBC := {
	# Base grays
	"white": Color("#e8e8e8"),
	"cream": Color("#f8f0d8"),
	"light_gray": Color("#b8b0a0"),
	"gray": Color("#787870"),
	"dark_gray": Color("#484840"),
	"black": Color("#181810"),

	# Nature
	"grass_light": Color("#88d850"),
	"grass": Color("#48a028"),
	"grass_dark": Color("#306018"),

	# Water
	"water_light": Color("#78c8f0"),
	"water": Color("#3888c8"),
	"water_dark": Color("#205898"),

	# Fire
	"fire_light": Color("#f8a850"),
	"fire": Color("#e07028"),
	"fire_dark": Color("#a04818"),

	# Earth
	"earth_light": Color("#d0b080"),
	"earth": Color("#a08058"),
	"earth_dark": Color("#685030"),

	# Mystic/Arcane
	"mystic_light": Color("#c0a0e0"),
	"mystic": Color("#8868b0"),
	"mystic_dark": Color("#504078"),

	# Ice
	"ice_light": Color("#d0f0f8"),
	"ice": Color("#90d0e8"),
	"ice_dark": Color("#5898b8"),

	# Thunder
	"thunder_light": Color("#f8f080"),
	"thunder": Color("#e8c830"),
	"thunder_dark": Color("#a89020"),

	# Poison
	"poison_light": Color("#c888d0"),
	"poison": Color("#a050a8"),
	"poison_dark": Color("#683870"),

	# Metal
	"metal_light": Color("#c8c8d0"),
	"metal": Color("#909098"),
	"metal_dark": Color("#585860"),

	# Shadow
	"shadow_light": Color("#686078"),
	"shadow": Color("#403848"),
	"shadow_dark": Color("#201820"),

	# Light
	"light_light": Color("#f8f8c0"),
	"light": Color("#f0e890"),
	"light_dark": Color("#c8b858"),

	# UI bars
	"hp_green": Color("#48a028"),
	"hp_yellow": Color("#e8c030"),
	"hp_red": Color("#d03028"),
	"hunger_orange": Color("#e08028"),
	"happy_pink": Color("#e080a0"),
	"energy_blue": Color("#4898d0"),
}


# ═══════════════════════════════════════════════════════════════════════════════
# ASPECT COLORS — Triade system (Corps/Ame/Monde)
# ═══════════════════════════════════════════════════════════════════════════════

const ASPECT_COLORS := {
	"Corps": Color(0.55, 0.40, 0.25),    # Earthy brown (GBC earth)
	"Ame": Color(0.40, 0.45, 0.70),      # Ethereal purple (GBC mystic)
	"Monde": Color(0.35, 0.55, 0.35),    # Forest green (GBC grass)
}

const ASPECT_COLORS_LIGHT := {
	"Corps": Color(0.72, 0.58, 0.38),    # earth_light
	"Ame": Color(0.62, 0.58, 0.82),      # mystic_light
	"Monde": Color(0.50, 0.72, 0.50),    # grass_light
}

const ASPECT_COLORS_DARK := {
	"Corps": Color(0.40, 0.30, 0.18),    # earth_dark
	"Ame": Color(0.30, 0.25, 0.47),      # mystic_dark
	"Monde": Color(0.22, 0.38, 0.22),    # grass_dark
}

# CRT terminal Triade colors (phosphor-style)
const CRT_ASPECT_COLORS := {
	"Corps": Color(1.00, 0.40, 0.20),    # Red-orange (force, sanglier)
	"Ame":   Color(0.50, 0.40, 1.00),    # Blue-violet (mystic, corbeau)
	"Monde": Color(0.20, 1.00, 0.40),    # Green phosphor (nature, cerf)
}
const CRT_ASPECT_COLORS_LIGHT := {
	"Corps": Color(1.00, 0.60, 0.40),
	"Ame":   Color(0.70, 0.60, 1.00),
	"Monde": Color(0.40, 1.00, 0.60),
}
const CRT_ASPECT_COLORS_DARK := {
	"Corps": Color(0.60, 0.24, 0.12),
	"Ame":   Color(0.30, 0.24, 0.60),
	"Monde": Color(0.12, 0.60, 0.24),
}


# ═══════════════════════════════════════════════════════════════════════════════
# TIME-OF-DAY COLORS (for MenuPrincipal ambient overlays)
# ═══════════════════════════════════════════════════════════════════════════════

const TIME_OF_DAY_COLORS := {
	"night":     Color(0.10, 0.12, 0.25, 0.35),
	"dawn":      Color(0.45, 0.28, 0.15, 0.20),
	"morning":   Color(0.95, 0.90, 0.80, 0.05),
	"midday":    Color(1.0, 1.0, 0.95, 0.0),
	"afternoon": Color(0.90, 0.82, 0.65, 0.08),
	"dusk":      Color(0.55, 0.25, 0.10, 0.25),
	"evening":   Color(0.20, 0.15, 0.28, 0.30),
}


# ═══════════════════════════════════════════════════════════════════════════════
# MODULATE ANIMATION CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const MODULATE_PULSE := Color(1.06, 1.06, 1.06)
const MODULATE_GLOW := Color(1.3, 1.3, 1.3)
const MODULATE_GLOW_DIM := Color(1.15, 1.15, 1.15)
const MODULATE_HIGHLIGHT := Color(1.5, 1.5, 1.5)


# ═══════════════════════════════════════════════════════════════════════════════
# LLM STATUS COLORS (for llm_status_bar.gd)
# ═══════════════════════════════════════════════════════════════════════════════

const LLM_STATUS := {
	"bg": Color(0.18, 0.15, 0.12, 0.85),
	"bg_hover": Color(0.22, 0.18, 0.14, 0.95),
	"text": Color(0.85, 0.80, 0.75),
	"success": Color(0.32, 0.58, 0.28),
	"warning": Color(0.72, 0.58, 0.22),
	"error": Color(0.72, 0.28, 0.22),
}


# ═══════════════════════════════════════════════════════════════════════════════
# SEASON COLORS
# ═══════════════════════════════════════════════════════════════════════════════

const SEASON_COLORS := {
	"printemps": Color(0.45, 0.70, 0.40),
	"ete": Color(0.40, 0.65, 0.85),
	"automne": Color(0.80, 0.55, 0.25),
	"hiver": Color(0.60, 0.45, 0.70),
}

const SEASON_TINTS := {
	"printemps": Color(1.02, 1.07, 1.00),
	"ete": Color(1.08, 1.04, 0.95),
	"automne": Color(1.10, 0.92, 0.82),
	"hiver": Color(0.84, 0.90, 1.08),
}

## English → French season key mapping (Calendar/Store use English, UI uses French)
const SEASON_KEY_MAP := {
	"spring": "printemps", "summer": "ete", "autumn": "automne", "winter": "hiver",
}

## Seasonal visual palettes for scene-wide color grading (CAL-REQ Phase 6)
const SEASONAL_PALETTES := {
	"spring": {
		"fog_tint": Color(0.88, 0.94, 0.85, 0.30),
		"particle_color": Color(0.70, 0.90, 0.60, 0.15),
		"bg_modulate": Color(1.02, 1.06, 1.00),
	},
	"summer": {
		"fog_tint": Color(0.95, 0.92, 0.85, 0.25),
		"particle_color": Color(0.95, 0.90, 0.60, 0.12),
		"bg_modulate": Color(1.06, 1.03, 0.96),
	},
	"autumn": {
		"fog_tint": Color(0.92, 0.85, 0.78, 0.32),
		"particle_color": Color(0.90, 0.70, 0.45, 0.18),
		"bg_modulate": Color(1.08, 0.94, 0.86),
	},
	"winter": {
		"fog_tint": Color(0.85, 0.88, 0.95, 0.35),
		"particle_color": Color(0.80, 0.85, 0.95, 0.20),
		"bg_modulate": Color(0.88, 0.92, 1.06),
	},
}


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
# BIOME ART PROFILES (per-biome pixel landscape colors)
# ═══════════════════════════════════════════════════════════════════════════════

const BIOME_ART_PROFILES := {
	"broceliande": {"sky": Color(0.16, 0.24, 0.14), "mist": Color(0.30, 0.38, 0.24), "mid": Color(0.14, 0.30, 0.16), "accent": Color(0.42, 0.56, 0.30), "foreground": Color(0.08, 0.16, 0.10), "feature_density": 0.64},
	"landes": {"sky": Color(0.28, 0.22, 0.34), "mist": Color(0.44, 0.36, 0.52), "mid": Color(0.36, 0.24, 0.34), "accent": Color(0.64, 0.46, 0.62), "foreground": Color(0.24, 0.17, 0.23), "feature_density": 0.48},
	"cotes": {"sky": Color(0.20, 0.28, 0.36), "mist": Color(0.34, 0.42, 0.50), "mid": Color(0.30, 0.34, 0.36), "accent": Color(0.54, 0.66, 0.74), "foreground": Color(0.16, 0.21, 0.24), "feature_density": 0.50},
	"villages": {"sky": Color(0.30, 0.23, 0.16), "mist": Color(0.48, 0.37, 0.26), "mid": Color(0.38, 0.28, 0.20), "accent": Color(0.74, 0.52, 0.30), "foreground": Color(0.22, 0.16, 0.12), "feature_density": 0.55},
	"cercles": {"sky": Color(0.23, 0.24, 0.27), "mist": Color(0.36, 0.38, 0.41), "mid": Color(0.28, 0.29, 0.30), "accent": Color(0.66, 0.70, 0.76), "foreground": Color(0.18, 0.18, 0.20), "feature_density": 0.42},
	"marais": {"sky": Color(0.17, 0.24, 0.22), "mist": Color(0.26, 0.36, 0.33), "mid": Color(0.20, 0.30, 0.25), "accent": Color(0.52, 0.66, 0.50), "foreground": Color(0.10, 0.17, 0.15), "feature_density": 0.60},
	"collines": {"sky": Color(0.26, 0.29, 0.19), "mist": Color(0.42, 0.45, 0.30), "mid": Color(0.34, 0.39, 0.22), "accent": Color(0.70, 0.56, 0.34), "foreground": Color(0.20, 0.22, 0.13), "feature_density": 0.52},
}

const BIOME_COLORS := {
	"broceliande": {"primary": Color(0.18, 0.42, 0.22), "secondary": Color(0.35, 0.55, 0.28), "accent": Color(0.62, 0.78, 0.42)},
	"landes": {"primary": Color(0.55, 0.40, 0.52), "secondary": Color(0.60, 0.50, 0.36), "accent": Color(0.72, 0.52, 0.72)},
	"cotes": {"primary": Color(0.50, 0.48, 0.42), "secondary": Color(0.68, 0.62, 0.52), "accent": Color(0.38, 0.58, 0.75)},
	"villages": {"primary": Color(0.58, 0.44, 0.26), "secondary": Color(0.45, 0.38, 0.30), "accent": Color(0.82, 0.62, 0.32)},
	"cercles": {"primary": Color(0.50, 0.48, 0.46), "secondary": Color(0.38, 0.35, 0.32), "accent": Color(0.72, 0.78, 0.88)},
	"marais": {"primary": Color(0.28, 0.38, 0.25), "secondary": Color(0.22, 0.30, 0.35), "accent": Color(0.55, 0.72, 0.48)},
	"collines": {"primary": Color(0.42, 0.48, 0.30), "secondary": Color(0.55, 0.50, 0.35), "accent": Color(0.70, 0.56, 0.34)},
}

const BIOME_VISUALS := {
	"foret_broceliande": {"name": "Foret de Broceliande", "subtitle": "Le coeur ancestral", "symbol": "Y", "color": Color(0.32, 0.50, 0.28)},
	"landes_bruyere": {"name": "Landes de Bruyere", "subtitle": "Branche nord", "symbol": "*", "color": Color(0.55, 0.40, 0.55)},
	"cotes_sauvages": {"name": "Cotes Sauvages", "subtitle": "Branche ouest", "symbol": "~", "color": Color(0.35, 0.50, 0.65)},
	"villages_celtes": {"name": "Villages Celtes", "subtitle": "Branche est", "symbol": "H", "color": Color(0.60, 0.45, 0.30)},
	"cercles_pierres": {"name": "Cercles de Pierres", "subtitle": "Branche sud-est", "symbol": "O", "color": Color(0.50, 0.50, 0.55)},
	"marais_korrigans": {"name": "Marais des Korrigans", "subtitle": "Branche haute", "symbol": "x", "color": Color(0.30, 0.42, 0.30)},
	"collines_dolmens": {"name": "Collines aux Dolmens", "subtitle": "Branche haute", "symbol": "A", "color": Color(0.48, 0.55, 0.40)},
}


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME CRT PALETTES — 8 strict colors per biome (index 0=darkest, 7=brightest)
# ═══════════════════════════════════════════════════════════════════════════════
# Each biome has a unique 8-color CRT phosphor palette rendered through scanlines.

const BIOME_CRT_PALETTES := {
	"broceliande": [
		Color(0.02, 0.06, 0.02),  Color(0.04, 0.12, 0.06),
		Color(0.08, 0.22, 0.10),  Color(0.12, 0.35, 0.16),
		Color(0.20, 0.50, 0.24),  Color(0.30, 0.65, 0.30),
		Color(0.50, 0.80, 0.40),  Color(0.70, 1.00, 0.50),
	],
	"landes": [
		Color(0.06, 0.02, 0.06),  Color(0.12, 0.06, 0.14),
		Color(0.20, 0.10, 0.24),  Color(0.35, 0.18, 0.40),
		Color(0.50, 0.28, 0.55),  Color(0.65, 0.40, 0.70),
		Color(0.80, 0.55, 0.85),  Color(0.95, 0.70, 1.00),
	],
	"cotes": [
		Color(0.02, 0.04, 0.08),  Color(0.04, 0.08, 0.16),
		Color(0.08, 0.16, 0.28),  Color(0.14, 0.28, 0.42),
		Color(0.22, 0.42, 0.58),  Color(0.35, 0.58, 0.72),
		Color(0.55, 0.75, 0.85),  Color(0.75, 0.90, 1.00),
	],
	"villages": [
		Color(0.06, 0.04, 0.02),  Color(0.14, 0.08, 0.04),
		Color(0.24, 0.14, 0.06),  Color(0.40, 0.24, 0.10),
		Color(0.58, 0.36, 0.16),  Color(0.75, 0.50, 0.22),
		Color(0.90, 0.65, 0.30),  Color(1.00, 0.80, 0.40),
	],
	"cercles": [
		Color(0.03, 0.03, 0.04),  Color(0.08, 0.08, 0.10),
		Color(0.16, 0.16, 0.20),  Color(0.28, 0.28, 0.34),
		Color(0.42, 0.42, 0.50),  Color(0.58, 0.58, 0.68),
		Color(0.75, 0.75, 0.85),  Color(0.90, 0.90, 1.00),
	],
	"marais": [
		Color(0.02, 0.04, 0.03),  Color(0.06, 0.10, 0.08),
		Color(0.10, 0.18, 0.14),  Color(0.16, 0.28, 0.22),
		Color(0.24, 0.40, 0.30),  Color(0.35, 0.55, 0.42),
		Color(0.50, 0.72, 0.55),  Color(0.65, 0.90, 0.70),
	],
	"collines": [
		Color(0.04, 0.04, 0.02),  Color(0.10, 0.10, 0.06),
		Color(0.18, 0.20, 0.10),  Color(0.30, 0.34, 0.16),
		Color(0.45, 0.50, 0.24),  Color(0.60, 0.65, 0.32),
		Color(0.75, 0.78, 0.42),  Color(0.90, 0.92, 0.55),
	],
}

# Per-biome CRT distortion profiles (noise, scanlines, glitch intensity)
const BIOME_CRT_PROFILES := {
	"broceliande": {"noise": 0.03, "scanline_opacity": 0.15, "glitch_probability": 0.005, "tint_blend": 0.06},
	"landes":      {"noise": 0.022, "scanline_opacity": 0.13, "glitch_probability": 0.004, "tint_blend": 0.05},
	"cotes":       {"noise": 0.038, "scanline_opacity": 0.11, "glitch_probability": 0.006, "tint_blend": 0.04},
	"villages":    {"noise": 0.015, "scanline_opacity": 0.10, "glitch_probability": 0.002, "tint_blend": 0.035},
	"cercles":     {"noise": 0.045, "scanline_opacity": 0.18, "glitch_probability": 0.009, "tint_blend": 0.07},
	"marais":      {"noise": 0.052, "scanline_opacity": 0.14, "glitch_probability": 0.012, "tint_blend": 0.06},
	"collines":    {"noise": 0.022, "scanline_opacity": 0.11, "glitch_probability": 0.003, "tint_blend": 0.04},
}


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
# UI STYLE HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

const CARD_CORNER_RADIUS := 0
const CARD_BORDER_WIDTH := 1
const CARD_SHADOW_SIZE := 0
const CARD_PADDING := 24
const MIN_TOUCH_TARGET := 48


static func celtic_ornament() -> String:
	return "\u27C2\u2022\u27C2\u27C2#\u27C2\u27C2\u2022\u27C2"


## Terminal panel — dark bg with phosphor border, CRT aesthetic
static func make_parchment_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CRT_PALETTE["bg_panel"]
	style.border_color = CRT_PALETTE["border"]
	style.set_border_width_all(CARD_BORDER_WIDTH)
	style.set_corner_radius_all(CARD_CORNER_RADIUS)
	style.shadow_size = CARD_SHADOW_SIZE
	style.set_content_margin_all(CARD_PADDING)
	return style


## Deep terminal panel — darkest bg for cave/grotte scenes
static func make_grotte_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CRT_PALETTE["bg_deep"]
	style.border_color = CRT_PALETTE["border"]
	style.set_border_width_all(CARD_BORDER_WIDTH)
	style.set_corner_radius_all(CARD_CORNER_RADIUS)
	style.shadow_size = CARD_SHADOW_SIZE
	style.set_content_margin_all(CARD_PADDING)
	return style


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


## Apply CRT label style — default phosphor text on dark terminal with outline for readability.
## The subtle outline (bg_deep color) ensures phosphor text stays readable on
## intermediate CRT backgrounds and through scanline overlay.
static func apply_label_style(label: Label, font_type: String, font_size: int, color_key: String = "phosphor", outline: bool = true) -> void:
	var font: Font = MerlinVisual.new().get_font(font_type)
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	var palette: Dictionary = CRT_PALETTE if CRT_PALETTE.has(color_key) else PALETTE
	label.add_theme_color_override("font_color", palette[color_key])
	if outline:
		label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
		label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)


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


## Card panel — terminal card frame with phosphor border
static func make_card_panel_style(unique: bool = false) -> StyleBoxFlat:
	return _get_or_create("card_panel", func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = CRT_PALETTE.bg_dark
		s.border_color = CRT_PALETTE.border_bright
		s.set_border_width_all(2)
		s.set_corner_radius_all(0)
		s.shadow_size = 0
		return s
	, unique)


## Card illustration — deep black for pixel art rendering
static func make_card_illustration_style(unique: bool = false) -> StyleBoxFlat:
	return _get_or_create("card_illo", func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(CRT_PALETTE.bg_deep.r, CRT_PALETTE.bg_deep.g, CRT_PALETTE.bg_deep.b, 0.90)
		s.border_color = Color(CRT_PALETTE.border.r, CRT_PALETTE.border.g, CRT_PALETTE.border.b, 0.5)
		s.set_border_width_all(1)
		s.set_corner_radius_all(0)
		s.set_content_margin_all(6)
		return s
	, unique)


## Card body — terminal reading area with dim border
static func make_card_body_style(unique: bool = false) -> StyleBoxFlat:
	return _get_or_create("card_body", func() -> StyleBoxFlat:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(CRT_PALETTE.bg_panel.r, CRT_PALETTE.bg_panel.g, CRT_PALETTE.bg_panel.b, 0.96)
		s.border_color = Color(CRT_PALETTE.border.r, CRT_PALETTE.border.g, CRT_PALETTE.border.b, 0.40)
		s.set_border_width_all(1)
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


## CRT terminal option style — thick left border accent, sharp corners
static func make_celtic_option_style(accent_color: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(CRT_PALETTE.bg_dark.r, CRT_PALETTE.bg_dark.g, CRT_PALETTE.bg_dark.b, 0.95)
	s.border_color = accent_color
	s.border_width_left = 5
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
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


# ═══════════════════════════════════════════════════════════════════════════════
# KINGDOM TWO CROWNS PORTRAIT HELPERS (D.2)
# ═══════════════════════════════════════════════════════════════════════════════
# Pipeline: pixel art reference → shader + palette swap → GBC aesthetic


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
