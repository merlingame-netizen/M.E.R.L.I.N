## ═══════════════════════════════════════════════════════════════════════════════
## MerlinVisualPalettes — Color palette data (extracted from MerlinVisual)
## ═══════════════════════════════════════════════════════════════════════════════
## All color constants: CRT_PALETTE, PALETTE (legacy), GBC, biome palettes,
## aspect colors, season colors, visual tag tints, LLM status colors.
## Access via MerlinVisual re-exports (public API unchanged).
## ═══════════════════════════════════════════════════════════════════════════════

class_name MerlinVisualPalettes
extends RefCounted


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
	"cyan_bright":    Color(0.50, 1.00, 0.95),
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

	# Transition backgrounds
	"transition_bg":  Color(0.08, 0.06, 0.04),

	# Death/defeat variant background (red-tinted deep black)
	"bg_death":       Color(0.04, 0.02, 0.02),

	# Biome identity colors (for map nodes, biome labels, ambient particles)
	"biome_broceliande":    Color(0.30, 0.50, 0.28),
	"biome_landes":         Color(0.55, 0.40, 0.55),
	"biome_cotes":          Color(0.35, 0.50, 0.65),
	"biome_villages":       Color(0.60, 0.45, 0.30),
	"biome_cercles":        Color(0.50, 0.50, 0.55),
	"biome_marais":         Color(0.30, 0.42, 0.30),
	"biome_dolmens":        Color(0.48, 0.55, 0.40),
	"biome_iles":           Color(0.25, 0.42, 0.60),

	# Biome tree map colors (slightly different shading for tree nodes)
	"biome_tree_broceliande": Color(0.32, 0.50, 0.28),
	"biome_tree_marais":      Color(0.30, 0.42, 0.28),
	"biome_tree_cercles":     Color(0.60, 0.55, 0.65),
	"biome_tree_dolmens":     Color(0.50, 0.52, 0.38),

	# Gauge colors (deprecated jauges system, kept for UI)
	"gauge_esprit":     Color(0.55, 0.40, 0.75),
	"gauge_vigueur":    Color(0.72, 0.35, 0.25),
	"gauge_faveur":     Color(0.65, 0.52, 0.34),
	"gauge_logique":    Color(0.35, 0.55, 0.70),
	"gauge_ressources": Color(0.48, 0.55, 0.30),

	# Faction identity colors (CRT-styled)
	"faction_druides":   Color(0.20, 0.80, 0.30),
	"faction_anciens":   Color(0.70, 0.55, 0.30),
	"faction_korrigans": Color(0.80, 0.40, 0.80),
	"faction_niamh":     Color(0.30, 0.70, 0.90),
	"faction_ankou":     Color(0.60, 0.20, 0.20),

	# Visual tag tints (mood-driven card panel modulation)
	"tint_danger":   Color(1.0, 0.7, 0.7),
	"tint_combat":   Color(1.0, 0.75, 0.75),
	"tint_mort":     Color(0.85, 0.75, 0.85),
	"tint_nuit":     Color(0.75, 0.78, 0.9),
	"tint_feu":      Color(1.0, 0.85, 0.7),
	"tint_terre":    Color(0.92, 0.88, 0.78),

	# Ambient biome particles (2D pixel FX)
	"particle_leaf_green":  Color(0.35, 0.55, 0.28),
	"particle_leaf_brown":  Color(0.55, 0.40, 0.25),
	"particle_dust_purple": Color(0.55, 0.40, 0.55, 0.5),
	"particle_mist_blue":   Color(0.38, 0.58, 0.75, 0.4),
	"particle_smoke_gray":  Color(0.5, 0.48, 0.45, 0.3),
	"particle_firefly":     Color(0.85, 0.75, 0.30, 0.6),
	"particle_phosphor":    Color(0.20, 0.45, 0.25, 0.4),
	"particle_grass":       Color(0.40, 0.60, 0.30, 0.3),
	"particle_mote":        Color(0.6, 0.55, 0.45, 0.2),

	# Coin minigame (gold coin face/edge/text)
	"coin_face":     Color(0.82, 0.72, 0.42),
	"coin_edge":     Color(0.62, 0.52, 0.22),
	"coin_text":     Color(0.18, 0.12, 0.05),

	# LLM source badge colors
	"badge_llm":      Color(0.18, 0.55, 0.28, 0.90),
	"badge_fallback": Color(0.72, 0.50, 0.10, 0.90),
	"badge_static":   Color(0.42, 0.40, 0.38, 0.75),
	"badge_error":    Color(0.70, 0.22, 0.18, 0.90),

	# Seasonal particle colors (MenuPrincipal)
	"season_autumn_leaf":  Color(0.85, 0.45, 0.15, 0.85),
	"season_autumn_pile":  Color(0.65, 0.35, 0.12, 0.75),
	"season_spring_petal": Color(1.0, 0.78, 0.85, 0.7),
	"season_spring_pile":  Color(0.95, 0.80, 0.85, 0.6),

	# Sky shader defaults (card scene compositor)
	"sky_top":        Color(0.06, 0.14, 0.08),
	"sky_mid":        Color(0.12, 0.28, 0.14),
	"sky_bottom":     Color(0.18, 0.40, 0.20),
	"sky_fog":        Color(0.6, 0.6, 0.65),
	"silhouette":     Color(0.08, 0.16, 0.10),

	# Atmospheric particles default
	"atmo_particle":  Color(0.3, 0.4, 0.3, 0.15),

	# Snow weather pixel
	"snow_pixel":     Color(0.9, 0.9, 0.95, 0.7),

	# Cursor colors (CRT ring + dot)
	"cursor_ring":    Color(0.22, 0.18, 0.14, 0.45),
	"cursor_dot":     Color(0.22, 0.18, 0.14, 0.8),

	# Progress sparkle (card text FX)
	"progress_sparkle": Color(0.70, 0.86, 1.0, 0.90),

	# Victory/milestone modulate tints (super-bright, >1.0 intentional)
	"victory_flash":    Color(1.4, 1.3, 0.8),
	"victory_settle":   Color(1.1, 1.1, 0.9),
	"milestone_gold":   Color(1.4, 1.1, 0.6),

	# Test environment fallback colors
	"test_bg":          Color(0.2, 0.3, 0.4),
	"test_fog":         Color(0.5, 0.5, 0.5),
}


# ═══════════════════════════════════════════════════════════════════════════════
# VISUAL_TAG_TINTS — Card panel mood modulation (from CRT_PALETTE)
# ═══════════════════════════════════════════════════════════════════════════════

const VISUAL_TAG_TINTS := {
	"danger":   Color(1.0, 0.7, 0.7, 1.0),
	"combat":   Color(1.0, 0.75, 0.75, 1.0),
	"mort":     Color(0.85, 0.75, 0.85, 1.0),
	"magie":    Color(0.85, 0.85, 1.0, 1.0),
	"sacre":    Color(0.9, 0.9, 1.0, 1.0),
	"mystere":  Color(0.8, 0.85, 0.95, 1.0),
	"nuit":     Color(0.75, 0.78, 0.9, 1.0),
	"brume":    Color(0.88, 0.9, 0.92, 1.0),
	"orage":    Color(0.8, 0.8, 0.88, 1.0),
	"feu":      Color(1.0, 0.85, 0.7, 1.0),
	"eau":      Color(0.8, 0.9, 1.0, 1.0),
	"terre":    Color(0.92, 0.88, 0.78, 1.0),
	"lumiere":  Color(1.0, 1.0, 0.9, 1.0),
	"soin":     Color(0.8, 1.0, 0.85, 1.0),
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
# ASPECT COLORS — CRT terminal colors for Corps/Ame/Monde aspects
# ═══════════════════════════════════════════════════════════════════════════════

# CRT terminal aspect colors (phosphor-style) — used by MenuPrincipalMerlin
const CRT_ASPECT_COLORS := {
	"Corps": Color(1.00, 0.40, 0.20),    # Red-orange (force, sanglier)
	"Ame":   Color(0.50, 0.40, 1.00),    # Blue-violet (mystic, corbeau)
	"Monde": Color(0.20, 1.00, 0.40),    # Green phosphor (nature, cerf)
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

## English -> French season key mapping (Calendar/Store use English, UI uses French)
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
	"iles": {"sky": Color(0.14, 0.22, 0.34), "mist": Color(0.30, 0.42, 0.56), "mid": Color(0.18, 0.30, 0.42), "accent": Color(0.50, 0.72, 0.88), "foreground": Color(0.08, 0.14, 0.22), "feature_density": 0.38},
}

const BIOME_COLORS := {
	"broceliande": {"primary": Color(0.18, 0.42, 0.22), "secondary": Color(0.35, 0.55, 0.28), "accent": Color(0.62, 0.78, 0.42)},
	"landes": {"primary": Color(0.55, 0.40, 0.52), "secondary": Color(0.60, 0.50, 0.36), "accent": Color(0.72, 0.52, 0.72)},
	"cotes": {"primary": Color(0.50, 0.48, 0.42), "secondary": Color(0.68, 0.62, 0.52), "accent": Color(0.38, 0.58, 0.75)},
	"villages": {"primary": Color(0.58, 0.44, 0.26), "secondary": Color(0.45, 0.38, 0.30), "accent": Color(0.82, 0.62, 0.32)},
	"cercles": {"primary": Color(0.50, 0.48, 0.46), "secondary": Color(0.38, 0.35, 0.32), "accent": Color(0.72, 0.78, 0.88)},
	"marais": {"primary": Color(0.28, 0.38, 0.25), "secondary": Color(0.22, 0.30, 0.35), "accent": Color(0.55, 0.72, 0.48)},
	"collines": {"primary": Color(0.42, 0.48, 0.30), "secondary": Color(0.55, 0.50, 0.35), "accent": Color(0.70, 0.56, 0.34)},
	"iles": {"primary": Color(0.25, 0.42, 0.60), "secondary": Color(0.38, 0.55, 0.72), "accent": Color(0.55, 0.78, 0.92)},
}

const BIOME_VISUALS := {
	"foret_broceliande": {"name": "Foret de Broceliande", "subtitle": "Le coeur ancestral", "symbol": "Y", "color": Color(0.32, 0.50, 0.28)},
	"landes_bruyere": {"name": "Landes de Bruyere", "subtitle": "Branche nord", "symbol": "*", "color": Color(0.55, 0.40, 0.55)},
	"cotes_sauvages": {"name": "Cotes Sauvages", "subtitle": "Branche ouest", "symbol": "~", "color": Color(0.35, 0.50, 0.65)},
	"villages_celtes": {"name": "Villages Celtes", "subtitle": "Branche est", "symbol": "H", "color": Color(0.60, 0.45, 0.30)},
	"cercles_pierres": {"name": "Cercles de Pierres", "subtitle": "Branche sud-est", "symbol": "O", "color": Color(0.50, 0.50, 0.55)},
	"marais_korrigans": {"name": "Marais des Korrigans", "subtitle": "Branche haute", "symbol": "x", "color": Color(0.30, 0.42, 0.30)},
	"collines_dolmens": {"name": "Collines aux Dolmens", "subtitle": "Branche haute", "symbol": "A", "color": Color(0.48, 0.55, 0.40)},
	"iles_mystiques": {"name": "Iles Mystiques", "subtitle": "Au-dela des brumes", "symbol": "~", "color": Color(0.30, 0.50, 0.70)},
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
	"iles": [
		Color(0.02, 0.04, 0.08),  Color(0.06, 0.10, 0.18),
		Color(0.10, 0.18, 0.30),  Color(0.18, 0.30, 0.46),
		Color(0.28, 0.44, 0.60),  Color(0.42, 0.60, 0.75),
		Color(0.60, 0.78, 0.88),  Color(0.78, 0.92, 1.00),
	],
}

# Per-biome CRT distortion profiles (noise, scanlines, glitch intensity)
const BIOME_CRT_PROFILES := {
	"broceliande": {"noise": 0.015, "scanline_opacity": 0.08, "glitch_probability": 0.003, "tint_blend": 0.025},
	"landes":      {"noise": 0.012, "scanline_opacity": 0.07, "glitch_probability": 0.002, "tint_blend": 0.020},
	"cotes":       {"noise": 0.018, "scanline_opacity": 0.06, "glitch_probability": 0.003, "tint_blend": 0.015},
	"villages":    {"noise": 0.008, "scanline_opacity": 0.05, "glitch_probability": 0.001, "tint_blend": 0.012},
	"cercles":     {"noise": 0.022, "scanline_opacity": 0.09, "glitch_probability": 0.005, "tint_blend": 0.028},
	"marais":      {"noise": 0.025, "scanline_opacity": 0.07, "glitch_probability": 0.006, "tint_blend": 0.024},
	"collines":    {"noise": 0.012, "scanline_opacity": 0.06, "glitch_probability": 0.002, "tint_blend": 0.016},
	"iles":        {"noise": 0.018, "scanline_opacity": 0.06, "glitch_probability": 0.004, "tint_blend": 0.020},
}
