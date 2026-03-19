## =====================================================================
## BiomeWalkConfigs — All 8 biome configurations for 3D walk scenes
## =====================================================================
## Each biome has: zones, atmosphere (terrain/fog/ambient colors),
## tile preferences (which GLB tiles to use), and walk parameters.
## Used by the terrain builder to generate the correct visuals per biome.
## =====================================================================

extends RefCounted
class_name BiomeWalkConfigs

const TILE_BASE := "res://archive/3d_models/Tiles_Low_Poly/"

static func get_config(biome_key: String) -> Dictionary:
	var configs: Dictionary = _all_configs()
	return configs.get(biome_key, configs["foret_broceliande"])


static func get_all_biome_keys() -> Array:
	return _all_configs().keys()


static func _all_configs() -> Dictionary:
	return {
		"foret_broceliande": {
			"name": "Foret de Broceliande",
			"zones": ["La Lisiere", "La Foret Dense", "Le Dolmen", "La Mare Enchantee", "La Foret Profonde", "La Fontaine de Barenton", "Le Cercle de Pierres"],
			"terrain_color": Color(0.15, 0.25, 0.10),
			"fog_color": Color(0.6, 0.7, 0.5),
			"fog_density": 0.025,
			"ambient_color": Color(0.35, 0.40, 0.30),
			"sky_top": Color(0.35, 0.55, 0.75),
			"tiles": ["Tile_01_Grass_Flat", "Tile_04_Grass_Lush", "Tile_05_Grass_Dark", "Tile_30_Moss"],
			"season": "spring",
			"walk_speed": 3.5,
		},
		"landes_bruyere": {
			"name": "Landes de Bruyere",
			"zones": ["La Bruyere Rase", "Le Cairn Solitaire", "La Lande Ventee", "Le Promontoire", "Le Vallon Abrite"],
			"terrain_color": Color(0.25, 0.18, 0.12),
			"fog_color": Color(0.55, 0.50, 0.45),
			"fog_density": 0.015,
			"ambient_color": Color(0.40, 0.35, 0.30),
			"sky_top": Color(0.50, 0.55, 0.60),
			"tiles": ["Tile_03_Grass_Dry", "Tile_06_Dirt_Flat", "Tile_07_Dirt_Rough", "Tile_29_Gravel"],
			"season": "autumn",
			"walk_speed": 4.0,
		},
		"cotes_sauvages": {
			"name": "Cotes Sauvages",
			"zones": ["La Plage de Galets", "La Falaise", "La Grotte Marine", "Le Phare de Sein", "L'Anse Cachee"],
			"terrain_color": Color(0.18, 0.22, 0.28),
			"fog_color": Color(0.60, 0.65, 0.70),
			"fog_density": 0.020,
			"ambient_color": Color(0.35, 0.40, 0.45),
			"sky_top": Color(0.40, 0.55, 0.70),
			"tiles": ["Tile_13_Sand_Flat", "Tile_14_Sand_Dune", "Tile_16_Sand_Wet", "Tile_26_Stone_Flat"],
			"season": "summer",
			"walk_speed": 3.0,
		},
		"villages_celtes": {
			"name": "Villages Celtes",
			"zones": ["L'Entree du Village", "La Place du Marche", "La Forge de Cadogan", "Le Puits des Souhaits", "Le Champ de Ble"],
			"terrain_color": Color(0.20, 0.18, 0.12),
			"fog_color": Color(0.65, 0.60, 0.50),
			"fog_density": 0.010,
			"ambient_color": Color(0.45, 0.40, 0.35),
			"sky_top": Color(0.50, 0.60, 0.70),
			"tiles": ["Tile_06_Dirt_Flat", "Tile_08_Dirt_Dark", "Tile_38_Path_Grass", "Tile_34_Trans_Grass_Dirt"],
			"season": "summer",
			"walk_speed": 3.0,
		},
		"cercles_pierres": {
			"name": "Cercles de Pierres",
			"zones": ["L'Approche", "Le Premier Cercle", "Le Menhir Central", "Le Dolmen Sacre", "L'Alignement"],
			"terrain_color": Color(0.12, 0.14, 0.16),
			"fog_color": Color(0.45, 0.45, 0.50),
			"fog_density": 0.030,
			"ambient_color": Color(0.30, 0.30, 0.35),
			"sky_top": Color(0.30, 0.35, 0.45),
			"tiles": ["Tile_26_Stone_Flat", "Tile_27_Stone_Rough", "Tile_28_Stone_Dark", "Tile_39_Grass_Rocky"],
			"season": "autumn",
			"walk_speed": 2.5,
		},
		"marais_korrigans": {
			"name": "Marais des Korrigans",
			"zones": ["L'Oree Boueuse", "Les Feux Follets", "Le Tertre de Gwen Du", "La Mare Noire", "L'Ile Flottante"],
			"terrain_color": Color(0.10, 0.18, 0.12),
			"fog_color": Color(0.40, 0.50, 0.40),
			"fog_density": 0.040,
			"ambient_color": Color(0.25, 0.30, 0.25),
			"sky_top": Color(0.25, 0.35, 0.30),
			"tiles": ["Tile_10_Mud_Wet", "Tile_11_Mud_Deep", "Tile_12_Mud_Puddle", "Tile_31_Swamp"],
			"season": "autumn",
			"walk_speed": 2.5,
		},
		"collines_dolmens": {
			"name": "Collines aux Dolmens",
			"zones": ["Le Pied des Collines", "Le Sentier des Os", "La Caverne d'Ildiko", "Le Dolmen Fissure", "Le Sommet Venteux"],
			"terrain_color": Color(0.18, 0.16, 0.10),
			"fog_color": Color(0.50, 0.48, 0.42),
			"fog_density": 0.018,
			"ambient_color": Color(0.35, 0.33, 0.28),
			"sky_top": Color(0.45, 0.48, 0.55),
			"tiles": ["Tile_07_Dirt_Rough", "Tile_09_Dirt_Red", "Tile_27_Stone_Rough", "Tile_29_Gravel"],
			"season": "winter",
			"walk_speed": 3.0,
		},
		"iles_mystiques": {
			"name": "Iles Mystiques",
			"zones": ["Le Rivage Brumeux", "Le Jardin Eternel", "Le Miroir d'Eau", "Le Pommier d'Or", "Le Passage d'Avalon"],
			"terrain_color": Color(0.12, 0.18, 0.25),
			"fog_color": Color(0.55, 0.60, 0.70),
			"fog_density": 0.035,
			"ambient_color": Color(0.30, 0.35, 0.45),
			"sky_top": Color(0.35, 0.45, 0.65),
			"tiles": ["Tile_21_Water_Shallow", "Tile_24_Beach_Edge", "Tile_25_ShallowWater_Sand", "Tile_15_Sand_Dark"],
			"season": "spring",
			"walk_speed": 2.0,
		},
	}
