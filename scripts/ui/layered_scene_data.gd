class_name LayeredSceneData
extends RefCounted
## Layer asset library for the CardSceneCompositor.
## Contains sky configs, midground silhouettes, subject sprites, and atmosphere configs.
## All driven by visual_tags + biome. Superset of PixelSceneData tag vocabulary.


# ═══════════════════════════════════════════════════════════════════════════════
# SKY CONFIGS — procedural gradient parameters per biome (card_sky.gdshader)
# ═══════════════════════════════════════════════════════════════════════════════
# Each entry defines 3 gradient bands (top, mid, bottom) for the sky shader.
# Season tint applied as uniform override at runtime.

static var SKIES := {
	"broceliande_day": {
		"top_color": Color(0.06, 0.14, 0.08),
		"mid_color": Color(0.12, 0.28, 0.14),
		"bottom_color": Color(0.18, 0.40, 0.20),
		"mid_position": 0.45,
		"biomes": ["foret_broceliande", "collines_dolmens"],
		"tags": ["foret", "arbres", "jour", "sentier"],
		"time_of_day": "day",
	},
	"broceliande_night": {
		"top_color": Color(0.02, 0.04, 0.02),
		"mid_color": Color(0.04, 0.08, 0.04),
		"bottom_color": Color(0.06, 0.12, 0.06),
		"mid_position": 0.40,
		"biomes": ["foret_broceliande", "collines_dolmens"],
		"tags": ["nuit", "nocturne", "etoiles"],
		"time_of_day": "night",
	},
	"marais_day": {
		"top_color": Color(0.10, 0.16, 0.14),
		"mid_color": Color(0.16, 0.24, 0.20),
		"bottom_color": Color(0.20, 0.32, 0.26),
		"mid_position": 0.50,
		"biomes": ["marais_korrigans"],
		"tags": ["marais", "eau", "brume"],
		"time_of_day": "day",
	},
	"marais_night": {
		"top_color": Color(0.03, 0.06, 0.05),
		"mid_color": Color(0.06, 0.10, 0.08),
		"bottom_color": Color(0.10, 0.16, 0.14),
		"mid_position": 0.45,
		"biomes": ["marais_korrigans"],
		"tags": ["nuit", "nocturne", "feux_follets"],
		"time_of_day": "night",
	},
	"landes_day": {
		"top_color": Color(0.10, 0.06, 0.12),
		"mid_color": Color(0.22, 0.14, 0.26),
		"bottom_color": Color(0.34, 0.22, 0.38),
		"mid_position": 0.42,
		"biomes": ["landes_bruyere"],
		"tags": ["lande", "bruyere", "vent", "pierre"],
		"time_of_day": "day",
	},
	"landes_night": {
		"top_color": Color(0.04, 0.02, 0.05),
		"mid_color": Color(0.08, 0.05, 0.10),
		"bottom_color": Color(0.14, 0.08, 0.16),
		"mid_position": 0.40,
		"biomes": ["landes_bruyere"],
		"tags": ["nuit", "nocturne", "etoiles"],
		"time_of_day": "night",
	},
	"cotes_day": {
		"top_color": Color(0.06, 0.10, 0.18),
		"mid_color": Color(0.14, 0.24, 0.36),
		"bottom_color": Color(0.22, 0.36, 0.48),
		"mid_position": 0.48,
		"biomes": ["cotes_sauvages"],
		"tags": ["cote", "mer", "vent", "falaise"],
		"time_of_day": "day",
	},
	"cotes_night": {
		"top_color": Color(0.02, 0.04, 0.08),
		"mid_color": Color(0.05, 0.08, 0.14),
		"bottom_color": Color(0.08, 0.14, 0.22),
		"mid_position": 0.44,
		"biomes": ["cotes_sauvages"],
		"tags": ["nuit", "nocturne", "mer"],
		"time_of_day": "night",
	},
	"villages_day": {
		"top_color": Color(0.12, 0.08, 0.04),
		"mid_color": Color(0.26, 0.18, 0.10),
		"bottom_color": Color(0.38, 0.28, 0.16),
		"mid_position": 0.45,
		"biomes": ["villages_celtes"],
		"tags": ["village", "maison", "feu", "marche"],
		"time_of_day": "day",
	},
	"villages_night": {
		"top_color": Color(0.04, 0.03, 0.02),
		"mid_color": Color(0.10, 0.06, 0.04),
		"bottom_color": Color(0.16, 0.10, 0.06),
		"mid_position": 0.42,
		"biomes": ["villages_celtes"],
		"tags": ["nuit", "nocturne", "feu"],
		"time_of_day": "night",
	},
	"cercles_day": {
		"top_color": Color(0.06, 0.06, 0.08),
		"mid_color": Color(0.16, 0.16, 0.22),
		"bottom_color": Color(0.26, 0.26, 0.34),
		"mid_position": 0.43,
		"biomes": ["cercles_pierres"],
		"tags": ["cercle", "menhir", "sacre", "ogham"],
		"time_of_day": "day",
	},
	"cercles_night": {
		"top_color": Color(0.02, 0.02, 0.04),
		"mid_color": Color(0.06, 0.06, 0.10),
		"bottom_color": Color(0.10, 0.10, 0.16),
		"mid_position": 0.40,
		"biomes": ["cercles_pierres"],
		"tags": ["nuit", "nocturne", "etoiles"],
		"time_of_day": "night",
	},
	"collines_day": {
		"top_color": Color(0.08, 0.10, 0.04),
		"mid_color": Color(0.20, 0.24, 0.12),
		"bottom_color": Color(0.32, 0.38, 0.20),
		"mid_position": 0.44,
		"biomes": ["collines_dolmens"],
		"tags": ["colline", "dolmen", "sentier"],
		"time_of_day": "day",
	},
	"iles_day": {
		"top_color": Color(0.04, 0.08, 0.16),
		"mid_color": Color(0.10, 0.20, 0.36),
		"bottom_color": Color(0.18, 0.32, 0.50),
		"mid_position": 0.46,
		"biomes": ["iles_mystiques"],
		"tags": ["ile", "mer", "brume", "mystique"],
		"time_of_day": "day",
	},
	"iles_night": {
		"top_color": Color(0.02, 0.03, 0.07),
		"mid_color": Color(0.04, 0.07, 0.14),
		"bottom_color": Color(0.06, 0.12, 0.22),
		"mid_position": 0.42,
		"biomes": ["iles_mystiques"],
		"tags": ["nuit", "nocturne", "lumiere"],
		"time_of_day": "night",
	},
}


# ═══════════════════════════════════════════════════════════════════════════════
# MIDGROUNDS — terrain silhouette parameters (card_silhouette.gdshader)
# ═══════════════════════════════════════════════════════════════════════════════
# Each entry defines noise-based silhouette shape + color.

static var MIDGROUNDS := {
	"broceliande_treeline": {
		"silhouette_color": Color(0.08, 0.16, 0.10),
		"height_base": 0.55,       ## Base height of silhouette (0.0 = top, 1.0 = bottom)
		"height_variation": 0.20,  ## How much noise displaces the silhouette
		"roughness": 0.65,         ## Noise frequency (higher = more jagged)
		"density": 0.80,           ## Feature density (tree crowns)
		"biomes": ["foret_broceliande"],
		"tags": ["foret", "arbres", "bois", "nature", "sentier"],
		"card_types": ["narrative", "event"],
		"idle_motion": {"type": "sway", "amplitude": 1.5, "period": 4.5},
	},
	"marais_deadtrees": {
		"silhouette_color": Color(0.10, 0.17, 0.15),
		"height_base": 0.60,
		"height_variation": 0.25,
		"roughness": 0.45,
		"density": 0.40,
		"biomes": ["marais_korrigans"],
		"tags": ["marais", "eau", "brume", "mort"],
		"card_types": ["narrative", "event"],
		"idle_motion": {"type": "sway", "amplitude": 0.8, "period": 6.0},
	},
	"broceliande_stones": {
		"silhouette_color": Color(0.12, 0.14, 0.10),
		"height_base": 0.70,
		"height_variation": 0.12,
		"roughness": 0.30,
		"density": 0.35,
		"biomes": ["foret_broceliande"],
		"tags": ["pierres", "dolmen", "sacre", "cercle"],
		"card_types": ["promise", "merlin_direct"],
		"idle_motion": {"type": "none"},
	},
	"marais_waterline": {
		"silhouette_color": Color(0.08, 0.14, 0.12),
		"height_base": 0.72,
		"height_variation": 0.08,
		"roughness": 0.20,
		"density": 0.90,
		"biomes": ["marais_korrigans"],
		"tags": ["eau", "reflet", "lac"],
		"card_types": ["promise", "merlin_direct"],
		"idle_motion": {"type": "drift", "amplitude": 1.0, "period": 3.0},
	},
	"landes_moorland": {
		"silhouette_color": Color(0.14, 0.10, 0.16),
		"height_base": 0.62,
		"height_variation": 0.12,
		"roughness": 0.35,
		"density": 0.45,
		"biomes": ["landes_bruyere"],
		"tags": ["lande", "bruyere", "vent", "pierre"],
		"card_types": ["narrative", "event"],
		"idle_motion": {"type": "sway", "amplitude": 1.2, "period": 5.0},
	},
	"cotes_cliffs": {
		"silhouette_color": Color(0.10, 0.14, 0.18),
		"height_base": 0.68,
		"height_variation": 0.18,
		"roughness": 0.50,
		"density": 0.35,
		"biomes": ["cotes_sauvages"],
		"tags": ["cote", "falaise", "roche", "mer"],
		"card_types": ["narrative", "event"],
		"idle_motion": {"type": "none"},
	},
	"villages_rooftops": {
		"silhouette_color": Color(0.16, 0.12, 0.08),
		"height_base": 0.60,
		"height_variation": 0.10,
		"roughness": 0.25,
		"density": 0.55,
		"biomes": ["villages_celtes"],
		"tags": ["village", "maison", "toit", "feu"],
		"card_types": ["narrative", "event"],
		"idle_motion": {"type": "none"},
	},
	"cercles_menhirs": {
		"silhouette_color": Color(0.10, 0.10, 0.12),
		"height_base": 0.70,
		"height_variation": 0.12,
		"roughness": 0.30,
		"density": 0.35,
		"biomes": ["cercles_pierres"],
		"tags": ["cercle", "menhir", "ogham", "sacre"],
		"card_types": ["narrative", "promise"],
		"idle_motion": {"type": "none"},
	},
	"collines_rolling": {
		"silhouette_color": Color(0.12, 0.14, 0.08),
		"height_base": 0.58,
		"height_variation": 0.22,
		"roughness": 0.55,
		"density": 0.50,
		"biomes": ["collines_dolmens"],
		"tags": ["colline", "dolmen", "sentier"],
		"card_types": ["narrative", "event"],
		"idle_motion": {"type": "sway", "amplitude": 1.0, "period": 5.5},
	},
	"iles_shore": {
		"silhouette_color": Color(0.06, 0.10, 0.16),
		"height_base": 0.65,
		"height_variation": 0.15,
		"roughness": 0.40,
		"density": 0.40,
		"biomes": ["iles_mystiques"],
		"tags": ["ile", "mer", "rivage", "mystique"],
		"card_types": ["narrative", "event"],
		"idle_motion": {"type": "drift", "amplitude": 1.5, "period": 4.0},
	},
}


# ═══════════════════════════════════════════════════════════════════════════════
# SUBJECTS — focal sprites (creature, NPC, object, event)
# ═══════════════════════════════════════════════════════════════════════════════
# These reference PixelSceneData grids upscaled at runtime via Image.
# "source_key" points to the original packed grid in PixelSceneData.CREATURES / PROPS.

static var SUBJECTS := {
	"cerf": {
		"source": "creatures",
		"source_key": "deer",
		"display_size": Vector2(192.0, 192.0),
		"anchor": Vector2(0.5, 0.8),
		"tags": ["cerf", "foret", "nature", "noble", "monde"],
		"biomes": ["foret_broceliande", "collines_dolmens"],
		"idle_motion": {"type": "breathe", "amplitude": 1.005, "period": 5.0},
	},
	"corbeau": {
		"source": "creatures",
		"source_key": "raven",
		"display_size": Vector2(128.0, 128.0),
		"anchor": Vector2(0.5, 0.4),
		"tags": ["corbeau", "ame", "mystere", "presage", "vol"],
		"biomes": ["foret_broceliande", "landes_bruyere", "marais_korrigans"],
		"idle_motion": {"type": "sway", "amplitude": 3.0, "period": 2.5},
	},
	"korrigan": {
		"source": "creatures",
		"source_key": "korrigan",
		"display_size": Vector2(160.0, 160.0),
		"anchor": Vector2(0.5, 0.85),
		"tags": ["korrigan", "rencontre", "malice", "fae", "danse"],
		"biomes": ["marais_korrigans", "foret_broceliande"],
		"idle_motion": {"type": "breathe", "amplitude": 1.008, "period": 3.0},
	},
	"loup": {
		"source": "creatures",
		"source_key": "wolf",
		"display_size": Vector2(176.0, 176.0),
		"anchor": Vector2(0.5, 0.85),
		"tags": ["loup", "danger", "combat", "corps", "predateur"],
		"biomes": ["foret_broceliande", "landes_bruyere"],
		"idle_motion": {"type": "breathe", "amplitude": 1.006, "period": 4.0},
	},
	"spectre": {
		"source": "creatures",
		"source_key": "ghost",
		"display_size": Vector2(144.0, 144.0),
		"anchor": Vector2(0.5, 0.6),
		"tags": ["spectre", "fantome", "mort", "ame", "brume", "feux_follets"],
		"biomes": ["marais_korrigans", "cercles_pierres"],
		"idle_motion": {"type": "drift", "amplitude": 4.0, "period": 3.5},
	},
}


# ═══════════════════════════════════════════════════════════════════════════════
# ATMOSPHERES — particle + overlay configs
# ═══════════════════════════════════════════════════════════════════════════════

static var ATMOSPHERES := {
	"fog_light": {
		"type": "particles",
		"particle_type": "fog",
		"count": 25,
		"color": Color(0.30, 0.40, 0.28, 0.12),
		"speed_range": Vector2(2.0, 8.0),
		"size_range": Vector2(20.0, 50.0),
		"direction": Vector2(1.0, 0.2),
		"tags": ["brume", "foret", "matin"],
		"biomes": ["foret_broceliande", "collines_dolmens"],
	},
	"fog_heavy": {
		"type": "particles",
		"particle_type": "fog",
		"count": 40,
		"color": Color(0.26, 0.36, 0.33, 0.20),
		"speed_range": Vector2(1.0, 5.0),
		"size_range": Vector2(30.0, 70.0),
		"direction": Vector2(0.5, -0.1),
		"tags": ["brume", "mystere", "marais", "nuit"],
		"biomes": ["marais_korrigans", "foret_broceliande"],
	},
	"wisps": {
		"type": "particles",
		"particle_type": "wisp",
		"count": 12,
		"color": Color(0.50, 0.80, 0.45, 0.25),
		"speed_range": Vector2(5.0, 15.0),
		"size_range": Vector2(3.0, 8.0),
		"direction": Vector2(0.0, -1.0),
		"tags": ["feux_follets", "magie", "spectre", "ame"],
		"biomes": ["marais_korrigans"],
	},
	"danger_pulse": {
		"type": "overlay",
		"overlay_color": Color(1.0, 0.20, 0.15, 0.08),
		"pulse_period": 1.5,
		"pulse_amplitude": 0.06,
		"tags": ["danger", "combat", "loup", "mort"],
		"biomes": [],  ## all biomes
	},
	"sacred_light": {
		"type": "particles",
		"particle_type": "wisp",
		"count": 8,
		"color": Color(0.80, 0.85, 1.0, 0.18),
		"speed_range": Vector2(2.0, 6.0),
		"size_range": Vector2(4.0, 10.0),
		"direction": Vector2(0.0, -0.8),
		"tags": ["sacre", "rituel", "dolmen", "cercle"],
		"biomes": [],
	},
	"magic_particles": {
		"type": "particles",
		"particle_type": "wisp",
		"count": 15,
		"color": Color(0.30, 0.85, 0.80, 0.20),
		"speed_range": Vector2(8.0, 20.0),
		"size_range": Vector2(2.0, 6.0),
		"direction": Vector2(0.3, -0.7),
		"tags": ["magie", "sort", "enchantement", "ogham"],
		"biomes": [],
	},
	"night_vignette": {
		"type": "overlay",
		"overlay_color": Color(0.02, 0.04, 0.02, 0.25),
		"pulse_period": 0.0,
		"pulse_amplitude": 0.0,
		"tags": ["nuit", "nocturne"],
		"biomes": [],
	},
	"rain": {
		"type": "particles",
		"particle_type": "rain",
		"count": 35,
		"color": Color(0.50, 0.60, 0.70, 0.15),
		"speed_range": Vector2(80.0, 140.0),
		"size_range": Vector2(1.0, 2.0),
		"direction": Vector2(0.15, 1.0),
		"tags": ["pluie", "meteo", "orage"],
		"biomes": [],
	},
}


# ═══════════════════════════════════════════════════════════════════════════════
# MODIFIER LAYER HINTS — card modifier → atmosphere/subject boost
# ═══════════════════════════════════════════════════════════════════════════════

static var MODIFIER_LAYER_HINTS := {
	"nocturne": {"sky_variant": "night", "atmo_key": "night_vignette"},
	"combat": {"subject_boost": ["loup", "sanglier"], "atmo_key": "danger_pulse"},
	"danger": {"atmo_key": "danger_pulse"},
	"mystere": {"atmo_key": "fog_heavy"},
	"sacre": {"atmo_key": "sacred_light"},
	"magie": {"atmo_key": "magic_particles"},
	"repos": {"subject_boost": ["feu", "camp"]},
	"rencontre": {"subject_boost": ["korrigan"]},
	"rituel": {"atmo_key": "sacred_light"},
	"meteo": {"atmo_key": "rain"},
	"commerce": {"subject_boost": ["village", "torche"]},
}


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME DEFAULT TAGS — fallback when LLM tag extraction fails (superset)
# ═══════════════════════════════════════════════════════════════════════════════

static var BIOME_DEFAULT_TAGS := {
	"foret_broceliande": ["foret", "arbres", "brume", "sentier"],
	"landes_bruyere": ["pierres", "brume", "sentier"],
	"cotes_sauvages": ["cote", "mer", "vent"],
	"villages_celtes": ["village", "feu", "maison"],
	"cercles_pierres": ["pierres", "cercle", "sacre"],
	"marais_korrigans": ["marais", "brume", "eau"],
	"collines_dolmens": ["foret", "dolmen", "sentier"],
	"iles_mystiques": ["ile", "mer", "brume", "lumiere"],
}
