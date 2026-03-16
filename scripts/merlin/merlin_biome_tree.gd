## =============================================================================
## Merlin Biome Tree — Directed Tier-Based World Map Structure
## =============================================================================
## Defines the strict directed tree of 7 biomes across 4 tiers.
## No backtracking: Tier 1 -> Tier 2 -> Tier 3 -> Tier 4 (final).
## Conditions use the 5 continuous gauges from MerlinGaugeSystem,
## plus items, reputations, and faction reputation from the store.
## =============================================================================

extends RefCounted
class_name MerlinBiomeTree


# =============================================================================
# CONSTANTS
# =============================================================================

const ROOT_BIOME := "foret_broceliande"

const BIOME_KEYS: Array = [
	"foret_broceliande",
	"villages_celtes",
	"cotes_sauvages",
	"landes_bruyere",
	"marais_korrigans",
	"cercles_pierres",
	"collines_dolmens",
	"iles_mystiques",
]


# =============================================================================
# TIER DEFINITIONS
# =============================================================================

const BIOME_TIERS: Dictionary = {
	"foret_broceliande": 1,
	"villages_celtes": 2,
	"cotes_sauvages": 2,
	"landes_bruyere": 3,
	"marais_korrigans": 3,
	"cercles_pierres": 3,
	"collines_dolmens": 4,
	"iles_mystiques": 5,
}


# =============================================================================
# DIRECTED EDGES — parent -> child (no backtracking)
# =============================================================================

const BIOME_TREE_EDGES: Array = [
	{"from": "foret_broceliande", "to": "villages_celtes"},
	{"from": "foret_broceliande", "to": "cotes_sauvages"},
	{"from": "cotes_sauvages", "to": "landes_bruyere"},
	{"from": "cotes_sauvages", "to": "marais_korrigans"},
	{"from": "villages_celtes", "to": "cercles_pierres"},
	{"from": "landes_bruyere", "to": "collines_dolmens"},
	{"from": "marais_korrigans", "to": "collines_dolmens"},
	{"from": "cercles_pierres", "to": "collines_dolmens"},
	{"from": "collines_dolmens", "to": "iles_mystiques"},
]


# =============================================================================
# UNLOCK CONDITIONS — gauge-based + items + reputations + special
# =============================================================================
#
# Condition types:
#   {"gauge": "esprit", "op": ">=", "value": 70}     -> MerlinGaugeSystem check
#   {"item": "bois_construction"}                      -> item in items_collected
#   {"reputation": "druide"}                           -> rep in reputations
#   {"faction": "druides", "op": ">=", "value": 50}     -> faction reputation check
#   {"completed_tier3": 1}                              -> N tier-3 biomes completed
#   {"karma": "positive"}                               -> hidden karma > 0

const BIOME_UNLOCK_CONDITIONS: Dictionary = {
	"foret_broceliande": null,  # Always accessible (start)

	"villages_celtes": {
		"logic": "or",
		"requires_from": "foret_broceliande",
		"conditions": [
			{"gauge": "faveur", "op": ">=", "value": 50},
			{"faction": "druides", "op": ">=", "value": 50},
		],
		"hint": "Faveur >= 50% ou reputation druides >= 50",
	},

	"cotes_sauvages": {
		"logic": "or",
		"requires_from": "foret_broceliande",
		"conditions": [
			{"gauge": "ressources", "op": "<", "value": 50},
			{"item": "bois_construction"},
		],
		"hint": "Ressources < 50% ou posseder du bois de construction",
	},

	"landes_bruyere": {
		"logic": "and",
		"requires_from": "cotes_sauvages",
		"conditions": [
			{"gauge": "vigueur", "op": ">=", "value": 75},
			{"item": "essences_bruyere"},
		],
		"hint": "Vigueur >= 75% et essences de bruyere (depuis Cotes)",
	},

	"marais_korrigans": {
		"logic": "or",
		"requires_from": "cotes_sauvages",
		"conditions": [
			{"gauge": "logique", "op": ">=", "value": 60},
			{"item": "amulette_marais"},
		],
		"hint": "Logique >= 60% ou Amulette des marais (depuis Cotes)",
	},

	"cercles_pierres": {
		"logic": "and",
		"requires_from": "villages_celtes",
		"conditions": [
			{"gauge": "esprit", "op": ">=", "value": 70},
			{"reputation": "druide"},
		],
		"hint": "Esprit >= 70% et reputation aupres des druides (depuis Villages)",
	},

	"collines_dolmens": {
		"logic": "and",
		"requires_from": null,  # Any tier-3 biome
		"conditions": [
			{"completed_tier3": 1},
			{"karma": "positive"},
		],
		"hint": "Completer un biome de palier 3 et avoir un karma positif",
	},

	"iles_mystiques": {
		"logic": "and",
		"requires_from": "collines_dolmens",
		"conditions": [
			{"completed_tier3": 3},
			{"faction": "niamh", "op": ">=", "value": 50},
		],
		"hint": "Completer les 3 biomes de palier 3 et reputation niamh >= 50",
	},
}


# =============================================================================
# BIOME DISPLAY DATA
# =============================================================================

const BIOME_NAMES: Dictionary = {
	"foret_broceliande": "Foret de Broceliande",
	"villages_celtes": "Villages Celtes",
	"cotes_sauvages": "Cotes Sauvages",
	"landes_bruyere": "Landes de Bruyere",
	"marais_korrigans": "Marais des Korrigans",
	"cercles_pierres": "Cercles de Pierres",
	"collines_dolmens": "Collines aux Dolmens",
	"iles_mystiques": "Iles Mystiques",
}

## Biome identity colors for map tree nodes — references MerlinVisual.CRT_PALETTE.
## Initialized lazily to avoid autoload ordering issues.
static var BIOME_COLORS: Dictionary:
	get:
		if _biome_colors_cache.is_empty():
			_biome_colors_cache = {
				"foret_broceliande": MerlinVisual.CRT_PALETTE["biome_tree_broceliande"],
				"villages_celtes": MerlinVisual.CRT_PALETTE["biome_villages"],
				"cotes_sauvages": MerlinVisual.CRT_PALETTE["biome_cotes"],
				"landes_bruyere": MerlinVisual.CRT_PALETTE["biome_landes"],
				"marais_korrigans": MerlinVisual.CRT_PALETTE["biome_tree_marais"],
				"cercles_pierres": MerlinVisual.CRT_PALETTE["biome_tree_cercles"],
				"collines_dolmens": MerlinVisual.CRT_PALETTE["biome_tree_dolmens"],
				"iles_mystiques": MerlinVisual.CRT_PALETTE["biome_iles"],
			}
		return _biome_colors_cache
static var _biome_colors_cache: Dictionary = {}

## Map positions for UI — tier-based layout (bottom = start, top = final)
const BIOME_POSITIONS: Dictionary = {
	"foret_broceliande": Vector2(0.50, 0.82),
	"villages_celtes": Vector2(0.70, 0.58),
	"cotes_sauvages": Vector2(0.30, 0.58),
	"landes_bruyere": Vector2(0.18, 0.34),
	"marais_korrigans": Vector2(0.42, 0.34),
	"cercles_pierres": Vector2(0.72, 0.34),
	"collines_dolmens": Vector2(0.50, 0.12),
	"iles_mystiques": Vector2(0.86, 0.12),
}


# =============================================================================
# TREE TRAVERSAL
# =============================================================================

## Get children biomes of a given biome in the directed tree
func get_children(biome_key: String) -> Array:
	var children: Array = []
	for edge in BIOME_TREE_EDGES:
		if str(edge["from"]) == biome_key:
			children.append(str(edge["to"]))
	return children


## Get parent biomes of a given biome
func get_parents(biome_key: String) -> Array:
	var parents: Array = []
	for edge in BIOME_TREE_EDGES:
		if str(edge["to"]) == biome_key:
			parents.append(str(edge["from"]))
	return parents


## Get the tier of a biome (1-4)
func get_tier(biome_key: String) -> int:
	return int(BIOME_TIERS.get(biome_key, 0))


## Get biomes at a specific tier
func get_biomes_at_tier(tier: int) -> Array:
	var result: Array = []
	for key in BIOME_KEYS:
		if get_tier(key) == tier:
			result.append(key)
	return result


# =============================================================================
# ACCESSIBILITY CHECKS
# =============================================================================

## Check if a biome is accessible given current state.
## map_state: {completed_biomes, visited_biomes, items_collected, reputations, tier_progress}
## gauges: {esprit, vigueur, faveur, logique, ressources}
## store_state: full store state (for faction reputation checks, karma, etc.)
func is_biome_accessible(biome_key: String, map_state: Dictionary, gauges: Dictionary, store_state: Dictionary) -> bool:
	# Root is always accessible
	if biome_key == ROOT_BIOME:
		return true

	var conditions_block = BIOME_UNLOCK_CONDITIONS.get(biome_key)
	if conditions_block == null:
		return true

	# Check parent completion requirement
	var requires_from = conditions_block.get("requires_from")
	if requires_from != null:
		var completed: Array = map_state.get("completed_biomes", [])
		if not str(requires_from) in completed:
			return false
	else:
		# For collines_dolmens: any tier-3 parent must be completed
		if biome_key == "collines_dolmens":
			var completed: Array = map_state.get("completed_biomes", [])
			var has_tier3: bool = false
			for parent_key in get_parents(biome_key):
				if parent_key in completed:
					has_tier3 = true
					break
			if not has_tier3:
				return false

	# Evaluate conditions
	var logic: String = str(conditions_block.get("logic", "and"))
	var conditions: Array = conditions_block.get("conditions", [])

	if conditions.is_empty():
		return true

	var gauge_system := MerlinGaugeSystem.new()

	for cond in conditions:
		var result: bool = _evaluate_condition(cond, gauges, map_state, store_state, gauge_system)

		if logic == "or" and result:
			return true
		if logic == "and" and not result:
			return false

	return logic == "and"


## Get user-facing unlock hint for a biome
func get_unlock_hint(biome_key: String, gauges: Dictionary, map_state: Dictionary, store_state: Dictionary) -> String:
	var conditions_block = BIOME_UNLOCK_CONDITIONS.get(biome_key)
	if conditions_block == null:
		return "Accessible"

	var hint: String = str(conditions_block.get("hint", "Conditions inconnues"))

	# Check parent requirement
	var requires_from = conditions_block.get("requires_from")
	if requires_from != null:
		var completed: Array = map_state.get("completed_biomes", [])
		if not str(requires_from) in completed:
			var parent_name: String = str(BIOME_NAMES.get(str(requires_from), requires_from))
			return "Completer %s d'abord" % parent_name

	return hint


## Get how many tier-3 biomes have been completed
func get_completed_tier3_count(map_state: Dictionary) -> int:
	var count: int = 0
	var completed: Array = map_state.get("completed_biomes", [])
	var tier3_biomes: Array = get_biomes_at_tier(3)
	for biome_key in tier3_biomes:
		if biome_key in completed:
			count += 1
	return count


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

func _evaluate_condition(cond: Dictionary, gauges: Dictionary, map_state: Dictionary, store_state: Dictionary, gauge_system: MerlinGaugeSystem) -> bool:
	# Gauge condition
	if cond.has("gauge"):
		return gauge_system.check_condition(gauges, cond)

	# Item condition
	if cond.has("item"):
		var items: Array = map_state.get("items_collected", [])
		return str(cond["item"]) in items

	# Reputation condition
	if cond.has("reputation"):
		var reps: Array = map_state.get("reputations", [])
		return str(cond["reputation"]) in reps

	# Faction reputation condition
	if cond.has("faction"):
		var faction_name: String = str(cond["faction"])
		var op: String = str(cond.get("op", ">="))
		var threshold: float = float(cond.get("value", 50))
		var run_data: Dictionary = store_state.get("run", {})
		var factions: Dictionary = run_data.get("factions", {})
		var rep: float = float(factions.get(faction_name, 50.0))
		match op:
			">=":
				return rep >= threshold
			"<=":
				return rep <= threshold
			">":
				return rep > threshold
			"<":
				return rep < threshold
			_:
				return false

	# Completed tier-3 count
	if cond.has("completed_tier3"):
		var required: int = int(cond["completed_tier3"])
		return get_completed_tier3_count(map_state) >= required

	# Karma condition
	if cond.has("karma"):
		var karma_check: String = str(cond["karma"])
		var run_data: Dictionary = store_state.get("run", {})
		var hidden: Dictionary = run_data.get("hidden", {})
		var karma: int = int(hidden.get("karma", 0))
		match karma_check:
			"positive":
				return karma > 0
			"negative":
				return karma < 0
			"neutral":
				return karma == 0
			_:
				return false

	# Unknown condition type — fail safe
	push_warning("MerlinBiomeTree: unknown condition type: %s" % str(cond))
	return false
