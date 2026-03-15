## =============================================================================
## Merlin Gauge System — 5 Continuous Gauges for World Map Progression
## =============================================================================
## Manages Esprit, Vigueur, Faveur, Logique, Ressources (0-100 scale).
## All methods are pure functions returning new dictionaries (immutable).
## =============================================================================

extends RefCounted
class_name MerlinGaugeSystem


# =============================================================================
# GAUGE DEFINITIONS
# =============================================================================

const GAUGES: Dictionary = {
	"esprit": {
		"name": "Esprit",
		"description": "Savoir spirituel et magique",
		"icon": "\u2726",
		"color": Color(0.55, 0.40, 0.75),
		"default": 30,
		"min": 0,
		"max": 100,
	},
	"vigueur": {
		"name": "Vigueur",
		"description": "Endurance physique et resistance",
		"icon": "\u2694",
		"color": Color(0.72, 0.35, 0.25),
		"default": 50,
		"min": 0,
		"max": 100,
	},
	"faveur": {
		"name": "Faveur",
		"description": "Reputation et liens sociaux",
		"icon": "\u2665",
		"color": Color(0.65, 0.52, 0.34),
		"default": 40,
		"min": 0,
		"max": 100,
	},
	"logique": {
		"name": "Logique",
		"description": "Raisonnement et analyse",
		"icon": "@",
		"color": Color(0.35, 0.55, 0.70),
		"default": 35,
		"min": 0,
		"max": 100,
	},
	"ressources": {
		"name": "Ressources",
		"description": "Biens materiels et reserves",
		"icon": "<>",
		"color": Color(0.48, 0.55, 0.30),
		"default": 45,
		"min": 0,
		"max": 100,
	},
}

const GAUGE_KEYS: Array = ["esprit", "vigueur", "faveur", "logique", "ressources"]


# =============================================================================
# BIOME GAUGE MODIFIERS — Multiplicateurs sur gains/pertes de jauges
# =============================================================================

const BIOME_MODIFIERS: Dictionary = {
	"foret_broceliande": {"esprit": 1.15, "vigueur": 0.90, "ressources": 0.85},
	"villages_celtes": {"faveur": 1.10},
	"cotes_sauvages": {
		"clear": {"vigueur": 1.05},
		"storm": {"vigueur": 0.90},
	},
	"landes_bruyere": {"faveur": 0.90, "ressources": 1.20},
	"marais_korrigans": {"logique": 1.15, "ressources": 0.85},
	"cercles_pierres": {"esprit": 1.20, "vigueur": 0.90},
	"collines_dolmens": {"esprit": 1.05, "faveur": 1.05, "ressources": 0.85},
}


# =============================================================================
# PURE FUNCTIONS — All return new dictionaries, never mutate input
# =============================================================================

## Build default gauge values for a new game
func build_default_gauges() -> Dictionary:
	var gauges: Dictionary = {}
	for key in GAUGE_KEYS:
		var def: Dictionary = GAUGES.get(key, {})
		gauges[key] = int(def.get("default", 50))
	return gauges


## Apply a delta to gauges, clamped to min/max. Returns new dictionary.
func apply_delta(gauges: Dictionary, delta: Dictionary) -> Dictionary:
	var result: Dictionary = gauges.duplicate()
	for key in delta:
		if not key in GAUGE_KEYS:
			continue
		var def: Dictionary = GAUGES.get(key, {})
		var gauge_min: int = int(def.get("min", 0))
		var gauge_max: int = int(def.get("max", 100))
		var current: int = int(result.get(key, 50))
		var new_value: int = clampi(current + int(delta[key]), gauge_min, gauge_max)
		result[key] = new_value
	return result


## Apply biome modifier to a raw delta, then apply to gauges. Returns new dict.
func apply_biome_modifier(gauges: Dictionary, biome_key: String, raw_delta: Dictionary, weather: String = "clear") -> Dictionary:
	var modified_delta: Dictionary = _get_modified_delta(biome_key, raw_delta, weather)
	return apply_delta(gauges, modified_delta)


## Check a single condition against current gauges.
## Condition format: {"gauge": "esprit", "op": ">=", "value": 70}
func check_condition(gauges: Dictionary, condition: Dictionary) -> bool:
	var gauge_key: String = str(condition.get("gauge", ""))
	if gauge_key.is_empty() or not gauge_key in GAUGE_KEYS:
		return false

	var op: String = str(condition.get("op", ">="))
	var threshold: int = int(condition.get("value", 0))
	var current: int = int(gauges.get(gauge_key, 0))

	match op:
		">=":
			return current >= threshold
		">":
			return current > threshold
		"<=":
			return current <= threshold
		"<":
			return current < threshold
		"==":
			return current == threshold
		"!=":
			return current != threshold
		_:
			push_warning("MerlinGaugeSystem: unknown operator '%s'" % op)
			return false


## Check multiple conditions with logic ("and" / "or").
## Format: {"logic": "and", "conditions": [cond1, cond2, ...]}
func check_conditions(gauges: Dictionary, conditions_block: Dictionary) -> bool:
	var logic: String = str(conditions_block.get("logic", "and"))
	var conditions: Array = conditions_block.get("conditions", [])

	if conditions.is_empty():
		return true

	for cond in conditions:
		# Skip non-gauge conditions (items, reputations, etc.)
		if not cond.has("gauge"):
			continue

		var result: bool = check_condition(gauges, cond)
		if logic == "or" and result:
			return true
		if logic == "and" and not result:
			return false

	# For "or": no condition passed
	# For "and": all conditions passed
	return logic == "and"


## Get gauge as float percentage (0.0 to 1.0)
func get_gauge_percent(gauges: Dictionary, gauge_key: String) -> float:
	var def: Dictionary = GAUGES.get(gauge_key, {})
	var gauge_max: float = float(def.get("max", 100))
	if gauge_max <= 0.0:
		return 0.0
	var current: float = float(gauges.get(gauge_key, 0))
	return clampf(current / gauge_max, 0.0, 1.0)


## Get all gauges as percentages
func get_all_gauge_percents(gauges: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in GAUGE_KEYS:
		result[key] = get_gauge_percent(gauges, key)
	return result


## Get display info for a gauge (name, icon, color, current value, percent)
func get_gauge_display(gauges: Dictionary, gauge_key: String) -> Dictionary:
	var def: Dictionary = GAUGES.get(gauge_key, {})
	return {
		"key": gauge_key,
		"name": str(def.get("name", gauge_key)),
		"icon": str(def.get("icon", "?")),
		"color": def.get("color", Color.WHITE),
		"value": int(gauges.get(gauge_key, 0)),
		"max": int(def.get("max", 100)),
		"percent": get_gauge_percent(gauges, gauge_key),
	}


## Get the biome modifier for a specific gauge
func get_biome_modifier(biome_key: String, gauge_key: String, weather: String = "clear") -> float:
	var mods: Dictionary = BIOME_MODIFIERS.get(biome_key, {})

	# Handle weather-dependent modifiers (cotes_sauvages)
	if mods.has("clear") or mods.has("storm"):
		var weather_mods: Dictionary = mods.get(weather, mods.get("clear", {}))
		return float(weather_mods.get(gauge_key, 1.0))

	return float(mods.get(gauge_key, 1.0))


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

func _get_modified_delta(biome_key: String, raw_delta: Dictionary, weather: String) -> Dictionary:
	var result: Dictionary = {}
	for key in raw_delta:
		if not key in GAUGE_KEYS:
			continue
		var modifier: float = get_biome_modifier(biome_key, key, weather)
		var raw_value: float = float(raw_delta[key])
		result[key] = int(roundf(raw_value * modifier))
	return result
