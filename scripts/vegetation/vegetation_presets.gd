## VegetationPresets — Per-scene configuration factory for VegetationManager.
## Each preset returns a config Dictionary matching VegetationManager.setup() schema.

extends RefCounted

const BK: String = "res://Assets/bk_assets/"
const BI: String = "foret_broceliande/"


## BKForestTestRoom — static, 120m radius, full density, all 12 categories.
static func bk_forest_test_room() -> Dictionary:
	return {
		"mode": "static",
		"area": Rect2(-55.0, -55.0, 110.0, 110.0),
		"seed": 42,
		"path_clearance": 2.5,
		"exclusion_zones": [
			Rect2(-4.0, -26.0, 8.0, 8.0),  # Megalith hilltop clearing
		],
		"layers": {
			"trees": {
				"paths": _tree_paths(),
				"density": 0.06,
				"scale": Vector2(0.85, 1.3),
				"vis": Vector2(0.0, 40.0),
				"cluster": 0.3,
			},
			"bushes": {
				"paths": _bush_paths(),
				"density": 0.12,
				"scale": Vector2(0.7, 1.3),
				"vis": Vector2(2.0, 20.0),
			},
			"groundcover": {
				"paths": _groundcover_paths(),
				"density": 1.2,
				"scale": Vector2(0.5, 1.4),
				"vis": Vector2(1.0, 10.0),
			},
			"mushrooms": {
				"paths": _mushroom_paths(),
				"density": 0.06,
				"scale": Vector2(0.7, 1.3),
				"vis": Vector2(1.0, 12.0),
			},
			"deadwood": {
				"paths": _deadwood_paths(),
				"density": 0.03,
				"scale": Vector2(0.7, 1.3),
				"vis": Vector2(0.0, 25.0),
			},
			"rocks": {
				"paths": _rock_paths(),
				"density": 0.05,
				"scale": Vector2(0.6, 1.5),
				"vis": Vector2(0.0, 30.0),
			},
			"grass": {
				"enabled": true,
				"density": 4.0,
				"vis_end": 8.0,
				"color": Color(0.18, 0.42, 0.12, 0.9),
				"jitter": 0.25,
			},
			"canopy": {
				"enabled": true,
				"vis_end": 30.0,
			},
			"billboard": {
				"enabled": true,
				"vis": Vector2(35.0, 60.0),
				"ratio": 0.4,
			},
		},
	}


## BKShowcase — static, 80m radius, moderate density, turntable scene.
static func bk_showcase() -> Dictionary:
	return {
		"mode": "static",
		"area": Rect2(-40.0, -40.0, 80.0, 80.0),
		"seed": 77,
		"path_clearance": 0.0,
		"exclusion_zones": [
			Rect2(-5.0, -5.0, 10.0, 10.0),  # Center showcase area clear
		],
		"layers": {
			"trees": {
				"paths": _tree_paths(),
				"density": 0.03,
				"scale": Vector2(0.9, 1.2),
				"vis": Vector2(0.0, 40.0),
				"cluster": 0.2,
			},
			"bushes": {
				"paths": _bush_paths(),
				"density": 0.06,
				"scale": Vector2(0.7, 1.2),
				"vis": Vector2(2.0, 20.0),
			},
			"groundcover": {
				"paths": _groundcover_paths(),
				"density": 0.6,
				"scale": Vector2(0.5, 1.2),
				"vis": Vector2(1.0, 10.0),
			},
			"grass": {
				"enabled": true,
				"density": 2.0,
				"vis_end": 8.0,
				"color": Color(0.20, 0.45, 0.14, 0.9),
				"jitter": 0.2,
			},
			"canopy": {
				"enabled": true,
				"vis_end": 30.0,
			},
			"billboard": {
				"enabled": true,
				"vis": Vector2(30.0, 55.0),
				"ratio": 0.3,
			},
		},
	}


## MerlinCabinHub — static, small exterior, purely decorative.
static func merlin_cabin_exterior() -> Dictionary:
	return {
		"mode": "static",
		"area": Rect2(-12.0, -12.0, 24.0, 24.0),
		"seed": 99,
		"path_clearance": 0.0,
		"exclusion_zones": [
			Rect2(-4.0, -4.0, 8.0, 8.0),  # Cabin footprint
		],
		"layers": {
			"trees": {
				"paths": _tree_paths(),
				"density": 0.04,
				"scale": Vector2(0.9, 1.15),
				"vis": Vector2(0.0, 30.0),
			},
			"bushes": {
				"paths": _bush_paths(),
				"density": 0.08,
				"scale": Vector2(0.7, 1.1),
				"vis": Vector2(2.0, 18.0),
			},
			"grass": {
				"enabled": true,
				"density": 2.0,
				"vis_end": 8.0,
				"color": Color(0.18, 0.40, 0.12, 0.9),
				"jitter": 0.2,
			},
		},
	}


## BKTestRoom — static, small, light vegetation for vertex color testing.
static func bk_test_room() -> Dictionary:
	return {
		"mode": "static",
		"area": Rect2(-20.0, -20.0, 40.0, 40.0),
		"seed": 55,
		"path_clearance": 0.0,
		"exclusion_zones": [],
		"layers": {
			"trees": {
				"paths": _tree_paths(),
				"density": 0.02,
				"scale": Vector2(0.9, 1.1),
				"vis": Vector2(0.0, 30.0),
			},
			"grass": {
				"enabled": true,
				"density": 1.5,
				"vis_end": 8.0,
				"color": Color(0.20, 0.45, 0.14, 0.9),
				"jitter": 0.2,
			},
		},
	}


# ═══════════════════════════════════════════════════════════════════════════════
# ASSET PATH HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

static func _tree_paths() -> Array[String]:
	var paths: Array[String] = []
	for i in 6:
		paths.append(BK + "vegetation/" + BI + "tree_bk_foret_broceliande_%04d.glb" % i)
	return paths


static func _bush_paths() -> Array[String]:
	var paths: Array[String] = []
	for i in 6:
		paths.append(BK + "bushes/" + BI + "bush_bk_foret_broceliande_%04d.glb" % i)
	return paths


static func _groundcover_paths() -> Array[String]:
	var paths: Array[String] = []
	for i in 6:
		paths.append(BK + "groundcover/" + BI + "groundcover_bk_foret_broceliande_%04d.glb" % i)
	return paths


static func _mushroom_paths() -> Array[String]:
	var paths: Array[String] = []
	for i in 6:
		paths.append(BK + "mushrooms/" + BI + "mushroom_bk_foret_broceliande_%04d.glb" % i)
	return paths


static func _deadwood_paths() -> Array[String]:
	var paths: Array[String] = []
	for i in 6:
		paths.append(BK + "deadwood/" + BI + "deadwood_bk_foret_broceliande_%04d.glb" % i)
	return paths


static func _rock_paths() -> Array[String]:
	var paths: Array[String] = []
	for i in 6:
		paths.append(BK + "rocks/" + BI + "rock_bk_foret_broceliande_%04d.glb" % i)
	return paths
