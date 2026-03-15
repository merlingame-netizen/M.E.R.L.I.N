## ═══════════════════════════════════════════════════════════════════════════════
## BiomeConfig — Visual preset for each biome's 3D environment
## ═══════════════════════════════════════════════════════════════════════════════
## Immutable resource holding sky, fog, ambient light, ground, and particle
## settings for a single biome. Use get_config(biome_id) to retrieve a preset.
## Colors reference MerlinVisual.BIOME_CRT_PALETTES where appropriate.
## ═══════════════════════════════════════════════════════════════════════════════

extends Resource
class_name BiomeConfig


# ═══════════════════════════════════════════════════════════════════════════════
# PROPERTIES
# ═══════════════════════════════════════════════════════════════════════════════

@export var biome_id: String = ""
@export var display_name: String = ""

# Sky
@export var sky_color: Color = Color(0.35, 0.55, 0.75)

# Ground
@export var ground_color: Color = Color(0.15, 0.25, 0.10)

# Fog
@export var fog_color: Color = Color(0.6, 0.7, 0.5)
@export var fog_density: float = 0.025

# Ambient light
@export var ambient_light_color: Color = Color(0.35, 0.40, 0.30)
@export var ambient_light_energy: float = 0.5

# Vegetation
@export var tree_density: float = 1.0

# Particles
@export var particle_type: String = "none"  # rain, fireflies, mist, snow, none


# ═══════════════════════════════════════════════════════════════════════════════
# VALID PARTICLE TYPES
# ═══════════════════════════════════════════════════════════════════════════════

const VALID_PARTICLE_TYPES: Array[String] = ["rain", "fireflies", "mist", "snow", "none"]

const FOG_DENSITY_MIN: float = 0.0
const FOG_DENSITY_MAX: float = 0.15
const AMBIENT_ENERGY_MIN: float = 0.1
const AMBIENT_ENERGY_MAX: float = 1.5
const TREE_DENSITY_MIN: float = 0.0
const TREE_DENSITY_MAX: float = 2.0


# ═══════════════════════════════════════════════════════════════════════════════
# FACTORY — Returns a BiomeConfig for the given biome_id
# ═══════════════════════════════════════════════════════════════════════════════

## Returns a BiomeConfig preset for the given biome_id.
## Falls back to foret_broceliande for unknown biome IDs.
static func get_config(biome_id: String) -> BiomeConfig:
	var presets: Dictionary = _build_presets()
	if presets.has(biome_id):
		return presets[biome_id]
	# Unknown biome: return default (foret_broceliande)
	return presets["foret_broceliande"]


## Returns an Array of all known biome IDs that have configs.
static func get_all_biome_ids() -> Array[String]:
	var ids: Array[String] = [
		"foret_broceliande", "landes_bruyere", "cotes_sauvages",
		"villages_celtes", "cercles_pierres", "marais_korrigans",
		"collines_dolmens", "iles_mystiques",
	]
	return ids


## Returns true if the given biome_id has a known config preset.
static func has_config(biome_id: String) -> bool:
	return biome_id in get_all_biome_ids()


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL — Build all presets
# ═══════════════════════════════════════════════════════════════════════════════

static func _make(
	p_biome_id: String,
	p_display_name: String,
	p_sky_color: Color,
	p_ground_color: Color,
	p_fog_color: Color,
	p_fog_density: float,
	p_ambient_light_color: Color,
	p_ambient_light_energy: float,
	p_tree_density: float,
	p_particle_type: String,
) -> BiomeConfig:
	var config: BiomeConfig = BiomeConfig.new()
	config.biome_id = p_biome_id
	config.display_name = p_display_name
	config.sky_color = p_sky_color
	config.ground_color = p_ground_color
	config.fog_color = p_fog_color
	config.fog_density = p_fog_density
	config.ambient_light_color = p_ambient_light_color
	config.ambient_light_energy = p_ambient_light_energy
	config.tree_density = p_tree_density
	config.particle_type = p_particle_type
	return config


static func _build_presets() -> Dictionary:
	# Colors drawn from MerlinVisual.BIOME_CRT_PALETTES indices:
	# [0] darkest ... [7] brightest
	# Sky uses index 6-7, ground uses 1-2, fog uses 3-4, ambient uses 4-5.
	var presets: Dictionary = {}

	# --- Foret de Broceliande: lush green forest, spring, mist ---
	presets["foret_broceliande"] = _make(
		"foret_broceliande",
		"Foret de Broceliande",
		Color(0.50, 0.80, 0.40),   # sky: bright green canopy light
		Color(0.08, 0.22, 0.10),   # ground: dark mossy
		Color(0.12, 0.35, 0.16),   # fog: green haze
		0.025,                      # fog_density: moderate woodland mist
		Color(0.30, 0.65, 0.30),   # ambient: filtered green
		0.5,                        # ambient_energy
		1.0,                        # tree_density: dense forest
		"mist",                     # particle_type
	)

	# --- Landes de Bruyere: purple heathland, autumn, fireflies ---
	presets["landes_bruyere"] = _make(
		"landes_bruyere",
		"Landes de Bruyere",
		Color(0.80, 0.55, 0.85),   # sky: pale purple
		Color(0.20, 0.10, 0.24),   # ground: dark heather
		Color(0.35, 0.18, 0.40),   # fog: purple haze
		0.018,                      # fog_density: light wind-swept
		Color(0.65, 0.40, 0.70),   # ambient: warm purple
		0.55,                       # ambient_energy
		0.3,                        # tree_density: sparse scrub
		"fireflies",                # particle_type
	)

	# --- Cotes Sauvages: ocean blue, summer, rain ---
	presets["cotes_sauvages"] = _make(
		"cotes_sauvages",
		"Cotes Sauvages",
		Color(0.55, 0.75, 0.85),   # sky: coastal blue
		Color(0.08, 0.16, 0.28),   # ground: wet dark sand
		Color(0.22, 0.42, 0.58),   # fog: sea mist
		0.030,                      # fog_density: coastal fog
		Color(0.35, 0.58, 0.72),   # ambient: ocean tint
		0.6,                        # ambient_energy
		0.2,                        # tree_density: sparse coastal
		"rain",                     # particle_type
	)

	# --- Villages Celtes: warm earth tones, summer, none ---
	presets["villages_celtes"] = _make(
		"villages_celtes",
		"Villages Celtes",
		Color(0.90, 0.65, 0.30),   # sky: warm golden
		Color(0.24, 0.14, 0.06),   # ground: packed earth
		Color(0.40, 0.24, 0.10),   # fog: dust haze
		0.010,                      # fog_density: minimal
		Color(0.75, 0.50, 0.22),   # ambient: warm firelight
		0.65,                       # ambient_energy: well-lit settlement
		0.4,                        # tree_density: scattered orchard
		"none",                     # particle_type
	)

	# --- Cercles de Pierres: monochrome stone, spring, mist ---
	presets["cercles_pierres"] = _make(
		"cercles_pierres",
		"Cercles de Pierres",
		Color(0.75, 0.75, 0.85),   # sky: pale stone blue
		Color(0.16, 0.16, 0.20),   # ground: grey stone
		Color(0.28, 0.28, 0.34),   # fog: stone mist
		0.035,                      # fog_density: thick ritual fog
		Color(0.58, 0.58, 0.68),   # ambient: cool grey
		0.4,                        # ambient_energy: dim mystical
		0.15,                       # tree_density: bare stone circle
		"mist",                     # particle_type
	)

	# --- Marais des Korrigans: murky green, autumn, fireflies ---
	presets["marais_korrigans"] = _make(
		"marais_korrigans",
		"Marais des Korrigans",
		Color(0.50, 0.72, 0.55),   # sky: sickly green
		Color(0.10, 0.18, 0.14),   # ground: dark bog
		Color(0.16, 0.28, 0.22),   # fog: swamp vapor
		0.045,                      # fog_density: thick swamp fog
		Color(0.35, 0.55, 0.42),   # ambient: murky green
		0.35,                       # ambient_energy: dim and oppressive
		0.5,                        # tree_density: gnarled swamp trees
		"fireflies",                # particle_type
	)

	# --- Collines aux Dolmens: yellow-green highlands, winter, snow ---
	presets["collines_dolmens"] = _make(
		"collines_dolmens",
		"Collines aux Dolmens",
		Color(0.75, 0.78, 0.42),   # sky: overcast yellow-green
		Color(0.18, 0.20, 0.10),   # ground: dried grass
		Color(0.30, 0.34, 0.16),   # fog: highland haze
		0.020,                      # fog_density: light highland mist
		Color(0.60, 0.65, 0.32),   # ambient: cold hillside
		0.45,                       # ambient_energy
		0.35,                       # tree_density: windswept shrubs
		"snow",                     # particle_type
	)

	# --- Iles Mystiques: deep ocean blue, winter, rain ---
	presets["iles_mystiques"] = _make(
		"iles_mystiques",
		"Iles Mystiques",
		Color(0.60, 0.78, 0.88),   # sky: ethereal blue
		Color(0.10, 0.18, 0.30),   # ground: dark ocean rock
		Color(0.18, 0.30, 0.46),   # fog: ocean mist
		0.040,                      # fog_density: heavy island fog
		Color(0.42, 0.60, 0.75),   # ambient: deep blue
		0.4,                        # ambient_energy: mystical dim
		0.25,                       # tree_density: sparse island vegetation
		"rain",                     # particle_type
	)

	return presets
