## ═══════════════════════════════════════════════════════════════════════════════
## BiomeWalkConfig — Resource definition for walkable biome configuration
## ═══════════════════════════════════════════════════════════════════════════════
## Each biome (Broceliande, Landes, Cotes, etc.) has a .tres resource file
## that defines zones, atmosphere, assets, and event parameters.
## Used by broceliande_forest_3d.gd to configure the 3D walk scene.
## ═══════════════════════════════════════════════════════════════════════════════

extends Resource
class_name BiomeWalkConfig

# ═══════════════════════════════════════════════════════════════════════════════
# IDENTITY
# ═══════════════════════════════════════════════════════════════════════════════

@export var biome_key: String = "foret_broceliande"
@export var biome_name: String = "Foret de Broceliande"
@export var biome_subtitle: String = "Ou les arbres ont des yeux"

# ═══════════════════════════════════════════════════════════════════════════════
# ZONES
# ═══════════════════════════════════════════════════════════════════════════════

@export var zone_count: int = 7
@export var zone_names: Array[String] = [
	"La Lisiere", "La Foret Dense", "Le Dolmen",
	"La Mare Enchantee", "La Foret Profonde",
	"La Fontaine de Barenton", "Le Cercle de Pierres",
]
@export var zone_spacing: float = 35.0

# ═══════════════════════════════════════════════════════════════════════════════
# ATMOSPHERE
# ═══════════════════════════════════════════════════════════════════════════════

@export var terrain_color: Color = Color(0.15, 0.25, 0.10)
@export var fog_color: Color = Color(0.6, 0.7, 0.5)
@export var fog_density: float = 0.025
@export var ambient_color: Color = Color(0.35, 0.40, 0.30)
@export var ambient_energy: float = 0.5
@export var sky_top_color: Color = Color(0.35, 0.55, 0.75)
@export var sky_bottom_color: Color = Color(0.55, 0.65, 0.50)
@export var favored_season: String = "spring"

# ═══════════════════════════════════════════════════════════════════════════════
# ASSETS (paths to GLB models)
# ═══════════════════════════════════════════════════════════════════════════════

@export var tree_models: Array[String] = []
@export var bush_models: Array[String] = []
@export var detail_models: Dictionary = {}
@export var special_trees: Dictionary = {}
@export var biome_assets: Dictionary = {}  # POIs, megaliths, structures, decor

# ═══════════════════════════════════════════════════════════════════════════════
# EVENTS
# ═══════════════════════════════════════════════════════════════════════════════

@export var event_interval: Vector2 = Vector2(45.0, 90.0)
@export var event_cooldown: float = 20.0

# ═══════════════════════════════════════════════════════════════════════════════
# VFX KEYWORD OVERRIDES (biome-specific, merged with defaults)
# ═══════════════════════════════════════════════════════════════════════════════

@export var vfx_keyword_overrides: Dictionary = {}

# ═══════════════════════════════════════════════════════════════════════════════
# GAMEPLAY MODIFIERS (from MerlinBiomeSystem)
# ═══════════════════════════════════════════════════════════════════════════════

@export var aspect_bias: Dictionary = {"Corps": 1.0, "Ame": 1.0, "Monde": 1.0}
@export var difficulty: int = 0
@export var creatures_desc: String = ""
@export var atmosphere_desc: String = ""
