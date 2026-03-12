## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Biome System — 7 Celtic Biomes for TRIADE
## ═══════════════════════════════════════════════════════════════════════════════
## Manages biome definitions, aspect biases, passive effects, ogham bonuses,
## unlock conditions, and LLM context generation.
## Adapts the documented percentage-based modifiers to TRIADE discrete states
## via probability weights (aspect_bias) and periodic passive effects.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name MerlinBiomeSystem

# ═══════════════════════════════════════════════════════════════════════════════
# TUNING — External balance file (optional override)
# ═══════════════════════════════════════════════════════════════════════════════

const TUNING_PATH := "res://data/balance/tuning.json"
var _tuning: Dictionary = {}
var _tuning_loaded: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME DATA — 7 biomes adapted for TRIADE (3 aspects, discrete states)
# ═══════════════════════════════════════════════════════════════════════════════
#
# aspect_bias: Probability weights for card generation.
#   1.0 = neutral, >1.0 = more cards affecting that aspect, <1.0 = fewer.
#   Used by LLM (via RAG context) and fallback pool (weighted selection).
#
# passive: Automatic effect applied every N cards played in this biome.
#   Represents the environment's influence on the voyager.
#
# ogham_bonus: Oghams with reduced cooldown in this biome.
#
# difficulty: Tension modifier (-1 = easier, 0 = normal, +1/+2 = harder).
#
# unlock: Conditions to access this biome (null = always available).

const BIOMES: Dictionary = {
	"foret_broceliande": {
		"name": "Foret de Broceliande",
		"subtitle": "Ou les arbres ont des yeux",
		"theme": "Nature ancienne, mystere vegetal, brume enchantee, korrigans",
		"color": Color(0.30, 0.50, 0.28),
		"aspect_bias": {"Corps": 1.2, "Ame": 1.0, "Monde": 0.8},
		"passive": {"every_n": 5, "aspect": "Ame", "direction": "up"},
		"difficulty": 0,
		"ogham_bonus": ["quert", "huath", "coll"],
		"ogham_cooldown_reduction": 1,
		"flux_offset": {"terre": 10, "esprit": 0, "lien": -5},
		"favored_season": "spring",
		"unlock": null,
		"creatures": "fees, korrigans, loups anciens, arbres animes",
		"atmosphere": "brume perpetuelle, lumiere filtree, echos de voix anciennes",
	},
	"landes_bruyere": {
		"name": "Landes de Bruyere",
		"subtitle": "L'horizon sans fin",
		"theme": "Survie, solitude, endurance, vent hurlant",
		"color": Color(0.55, 0.40, 0.55),
		"aspect_bias": {"Corps": 0.8, "Ame": 1.2, "Monde": 1.0},
		"passive": {"every_n": 6, "aspect": "Corps", "direction": "down"},
		"difficulty": 1,
		"ogham_bonus": ["luis", "onn", "saille"],
		"ogham_cooldown_reduction": 1,
		"flux_offset": {"terre": 5, "esprit": 5, "lien": 5},
		"favored_season": "autumn",
		"unlock": {"min_runs": 2},
		"creatures": "rapaces, lievres, ermites, esprits du vent",
		"atmosphere": "landes balayees par le vent, ciel immense, bruyere violette",
	},
	"cotes_sauvages": {
		"name": "Cotes Sauvages",
		"subtitle": "L'ocean murmurant",
		"theme": "Commerce, exploration, danger maritime, tempetes",
		"color": Color(0.35, 0.50, 0.65),
		"aspect_bias": {"Corps": 1.0, "Ame": 0.8, "Monde": 1.2},
		"passive": {"every_n": 5, "aspect": "Monde", "direction": "up"},
		"difficulty": 0,
		"ogham_bonus": ["muin", "nuin", "tinne"],
		"ogham_cooldown_reduction": 1,
		"flux_offset": {"terre": -5, "esprit": 0, "lien": 10},
		"favored_season": "summer",
		"unlock": {"min_runs": 3},
		"creatures": "phoques, mouettes, marchands etrangers, sirenes",
		"atmosphere": "falaises battues par les vagues, sel et algues, ports de peche",
	},
	"villages_celtes": {
		"name": "Villages Celtes",
		"subtitle": "Flammes obstinees de l'humanite",
		"theme": "Politique, social, intrigues, assemblee tribale",
		"color": Color(0.60, 0.45, 0.30),
		"aspect_bias": {"Corps": 0.8, "Ame": 1.0, "Monde": 1.2},
		"passive": {"every_n": 4, "aspect": "Monde", "direction": "up"},
		"difficulty": -1,
		"ogham_bonus": ["duir", "coll", "beith"],
		"ogham_cooldown_reduction": 1,
		"flux_offset": {"terre": 0, "esprit": -5, "lien": 0},
		"favored_season": "summer",
		"unlock": {"min_runs": 5},
		"creatures": "villageois, chefs de clan, druides, forgerons",
		"atmosphere": "huttes rondes, feux de camp, assemblees, rumeurs",
	},
	"cercles_pierres": {
		"name": "Cercles de Pierres",
		"subtitle": "Ou le temps hesite",
		"theme": "Magie, spirituel, liminal, rituels druidiques",
		"color": Color(0.50, 0.50, 0.55),
		"aspect_bias": {"Corps": 1.0, "Ame": 1.4, "Monde": 0.8},
		"passive": {"every_n": 4, "aspect": "Ame", "direction": "up"},
		"difficulty": 1,
		"ogham_bonus": ["ioho", "straif", "ruis"],
		"ogham_cooldown_reduction": 2,
		"flux_offset": {"terre": 0, "esprit": 15, "lien": 5},
		"favored_season": "winter",
		"unlock": {"min_runs": 8, "min_endings": 2},
		"creatures": "esprits ancestraux, druides anciens, ombres du passe",
		"atmosphere": "menhirs milleniares, energie palpable, etoiles differentes",
	},
	"marais_korrigans": {
		"name": "Marais des Korrigans",
		"subtitle": "Deception et feux follets",
		"theme": "Danger, mystere, tentation, tresors caches",
		"color": Color(0.30, 0.42, 0.30),
		"aspect_bias": {"Corps": 1.2, "Ame": 1.0, "Monde": 0.8},
		"passive": {"every_n": 5, "aspect": "Corps", "direction": "down"},
		"difficulty": 2,
		"ogham_bonus": ["gort", "eadhadh", "luis"],
		"ogham_cooldown_reduction": 1,
		"flux_offset": {"terre": -10, "esprit": 5, "lien": 15},
		"favored_season": "autumn",
		"unlock": {"min_runs": 10, "required_ending": "harmonie"},
		"creatures": "korrigans, feux follets, creatures des tourbieres, morts-vivants",
		"atmosphere": "eaux stagnantes, brume epaisse, lumieres trompeuses",
	},
	"collines_dolmens": {
		"name": "Collines aux Dolmens",
		"subtitle": "Les os de la terre",
		"theme": "Sagesse, ancestral, memoire, paix profonde",
		"color": Color(0.48, 0.55, 0.40),
		"aspect_bias": {"Corps": 1.0, "Ame": 1.0, "Monde": 1.0},
		"passive": {"every_n": 7, "aspect": "random", "direction": "random"},
		"difficulty": 0,
		"ogham_bonus": ["quert", "ailm", "coll"],
		"ogham_cooldown_reduction": 1,
		"flux_offset": {"terre": 5, "esprit": 5, "lien": -5},
		"favored_season": "spring",
		"unlock": {"min_runs": 15, "min_endings": 5},
		"creatures": "esprits d'anciens rois, sages, animaux paisibles",
		"atmosphere": "collines douces, dolmens et tumulus, air paisible et lourd de memoire",
	},
	"iles_mystiques": {
		"name": "Iles Mystiques",
		"subtitle": "Au-dela des brumes",
		"theme": "Transcendance, passage, monde invisible, liminalite absolue",
		"color": Color(0.25, 0.42, 0.60),
		"aspect_bias": {"Corps": 0.8, "Ame": 1.4, "Monde": 1.0},
		"passive": {"every_n": 4, "aspect": "random", "direction": "random"},
		"difficulty": 3,
		"ogham_bonus": ["ailm", "ruis", "ioho"],
		"ogham_cooldown_reduction": 2,
		"flux_offset": {"terre": -5, "esprit": 15, "lien": 10},
		"favored_season": "samhain",
		"unlock": {"min_runs": 20, "min_endings": 5, "required_ending": "transcendance"},
		"creatures": "selkies, banshees, fees des vagues, esprits anciens, gardienne Morgane",
		"atmosphere": "brume eternelle, vagues phosphorescentes, chants lointains, tour en ruines",
	},
}


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME ACCESS
# ═══════════════════════════════════════════════════════════════════════════════

func get_biome(biome_key: String) -> Dictionary:
	var tuned: Variant = _get_tuned_biome(biome_key)
	if tuned is Dictionary and not tuned.is_empty():
		return tuned
	return BIOMES.get(biome_key, {})


func get_all_biome_keys() -> Array:
	return MerlinConstants.BIOME_KEYS.duplicate()


func get_biome_name(biome_key: String) -> String:
	var biome: Dictionary = get_biome(biome_key)
	return str(biome.get("name", biome_key))


func get_biome_color(biome_key: String) -> Color:
	var biome: Dictionary = get_biome(biome_key)
	return biome.get("color", Color.WHITE) as Color


# ═══════════════════════════════════════════════════════════════════════════════
# ASPECT BIAS — Influences card generation probabilities
# ═══════════════════════════════════════════════════════════════════════════════

func get_aspect_bias(biome_key: String) -> Dictionary:
	var biome: Dictionary = get_biome(biome_key)
	return biome.get("aspect_bias", {"Corps": 1.0, "Ame": 1.0, "Monde": 1.0})


# ═══════════════════════════════════════════════════════════════════════════════
# PASSIVE EFFECTS — Periodic biome influence
# ═══════════════════════════════════════════════════════════════════════════════

func should_trigger_passive(biome_key: String, cards_played: int) -> bool:
	var biome: Dictionary = get_biome(biome_key)
	var passive: Dictionary = biome.get("passive", {})
	var every_n: int = int(passive.get("every_n", 0))
	if every_n <= 0 or cards_played <= 0:
		return false
	return (cards_played % every_n) == 0


func get_passive_effect(biome_key: String, cards_played: int) -> Dictionary:
	if not should_trigger_passive(biome_key, cards_played):
		return {}

	var biome: Dictionary = get_biome(biome_key)
	var passive: Dictionary = biome.get("passive", {})
	var direction: String = str(passive.get("direction", ""))

	# Handle "random" direction for Collines aux Dolmens
	if direction == "random":
		direction = ["up", "down"][randi() % 2]

	if direction.is_empty():
		return {}

	if direction == "up":
		return {"type": "HEAL_LIFE", "amount": 5}
	else:
		return {"type": "DAMAGE_LIFE", "amount": 5}


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM BONUSES — Reduced cooldown for biome-aligned oghams
# ═══════════════════════════════════════════════════════════════════════════════

func get_ogham_cooldown_bonus(biome_key: String, ogham_id: String) -> int:
	var biome: Dictionary = get_biome(biome_key)
	var bonus_list: Array = biome.get("ogham_bonus", [])
	if ogham_id in bonus_list:
		return int(biome.get("ogham_cooldown_reduction", 1))
	return 0


# ═══════════════════════════════════════════════════════════════════════════════
# DIFFICULTY — Tension modifier for this biome
# ═══════════════════════════════════════════════════════════════════════════════

func get_difficulty_modifier(biome_key: String) -> int:
	var biome: Dictionary = get_biome(biome_key)
	return int(biome.get("difficulty", 0))


# ═══════════════════════════════════════════════════════════════════════════════
# FLUX OFFSET — Starting flux adjustment
# ═══════════════════════════════════════════════════════════════════════════════

func get_flux_offset(biome_key: String) -> Dictionary:
	var biome: Dictionary = get_biome(biome_key)
	return biome.get("flux_offset", {"terre": 0, "esprit": 0, "lien": 0})


# ═══════════════════════════════════════════════════════════════════════════════
# SEASON AFFINITY
# ═══════════════════════════════════════════════════════════════════════════════

func get_favored_season(biome_key: String) -> String:
	var biome: Dictionary = get_biome(biome_key)
	return str(biome.get("favored_season", ""))


func is_in_favored_season(biome_key: String, current_season: String) -> bool:
	return get_favored_season(biome_key) == current_season


# ═══════════════════════════════════════════════════════════════════════════════
# UNLOCK CONDITIONS
# ═══════════════════════════════════════════════════════════════════════════════

func is_unlocked(biome_key: String, meta: Dictionary) -> bool:
	var biome: Dictionary = get_biome(biome_key)
	var unlock: Variant = biome.get("unlock")
	if unlock == null:
		return true  # No condition = always available

	if not unlock is Dictionary:
		return true

	var total_runs: int = int(meta.get("total_runs", 0))
	var endings_seen: Array = meta.get("endings_seen", [])

	# Check minimum runs
	var min_runs: int = int(unlock.get("min_runs", 0))
	if min_runs > 0 and total_runs < min_runs:
		return false

	# Check minimum endings
	var min_endings: int = int(unlock.get("min_endings", 0))
	if min_endings > 0 and endings_seen.size() < min_endings:
		return false

	# Check required specific ending
	var required_ending: String = str(unlock.get("required_ending", ""))
	if not required_ending.is_empty() and not required_ending in endings_seen:
		return false

	return true


func get_unlock_hint(biome_key: String) -> String:
	var biome: Dictionary = get_biome(biome_key)
	var unlock: Variant = biome.get("unlock")
	if unlock == null or not unlock is Dictionary:
		return ""

	var hints: Array = []
	var min_runs: int = int(unlock.get("min_runs", 0))
	if min_runs > 0:
		hints.append("%d runs" % min_runs)
	var min_endings: int = int(unlock.get("min_endings", 0))
	if min_endings > 0:
		hints.append("%d fins" % min_endings)
	var required_ending: String = str(unlock.get("required_ending", ""))
	if not required_ending.is_empty():
		hints.append("fin \"%s\"" % required_ending)

	if hints.is_empty():
		return ""
	return "Requiert: " + ", ".join(hints)


# ═══════════════════════════════════════════════════════════════════════════════
# GAUGE MODIFIER BRIDGE — Delegates to MerlinGaugeSystem
# ═══════════════════════════════════════════════════════════════════════════════

## Get gauge modifier for a biome (bridges to MerlinGaugeSystem constants).
## Returns multiplicator (1.0 = neutral, >1.0 = boost, <1.0 = penalty).
func get_gauge_modifier(biome_key: String, gauge_key: String, weather: String = "clear") -> float:
	var gauge_sys := MerlinGaugeSystem.new()
	return gauge_sys.get_biome_modifier(biome_key, gauge_key, weather)


## Check biome accessibility via WorldMapSystem (gauge-based tree) with legacy fallback.
## Prefers WorldMapSystem if available, otherwise falls back to legacy is_unlocked().
func is_unlocked_v2(biome_key: String, meta: Dictionary, tree_root: Node = null) -> bool:
	# Try WorldMapSystem first (gauge-based tree navigation)
	var wms: Node = null
	if tree_root:
		wms = tree_root.get_node_or_null("/root/WorldMapSystem")
	if wms and wms.has_method("is_biome_accessible"):
		return wms.is_biome_accessible(biome_key)
	# Fallback to legacy unlock conditions (min_runs, min_endings)
	return is_unlocked(biome_key, meta)


# ═══════════════════════════════════════════════════════════════════════════════
# LLM CONTEXT — Biome context string for RAG injection
# ═══════════════════════════════════════════════════════════════════════════════

func get_biome_context_for_llm(biome_key: String) -> String:
	var biome: Dictionary = get_biome(biome_key)
	if biome.is_empty():
		return ""

	var name_str: String = str(biome.get("name", biome_key))
	var theme: String = str(biome.get("theme", ""))
	var atmosphere: String = str(biome.get("atmosphere", ""))
	var creatures: String = str(biome.get("creatures", ""))

	# Build concise context for LLM (within RAG token budget)
	var parts: Array = ["BIOME: %s" % name_str]
	if not theme.is_empty():
		parts.append("Theme: %s" % theme)
	if not atmosphere.is_empty():
		parts.append("Ambiance: %s" % atmosphere)
	if not creatures.is_empty():
		parts.append("Creatures: %s" % creatures)

	return ". ".join(parts)


# ═══════════════════════════════════════════════════════════════════════════════
# TUNING — External balance file (optional)
# ═══════════════════════════════════════════════════════════════════════════════

func _load_tuning() -> void:
	if _tuning_loaded:
		return
	_tuning_loaded = true
	if not FileAccess.file_exists(TUNING_PATH):
		return
	var file := FileAccess.open(TUNING_PATH, FileAccess.READ)
	if file == null:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		_tuning = json.data
	file.close()


func get_tuning(section: String, key: String = "") -> Variant:
	_load_tuning()
	var section_data: Variant = _tuning.get(section, null)
	if key.is_empty():
		return section_data
	if section_data is Dictionary:
		return section_data.get(key, null)
	return null


func _get_tuned_biome(biome_key: String) -> Dictionary:
	_load_tuning()
	var biomes_data: Variant = _tuning.get("biomes", null)
	if biomes_data is Dictionary and biomes_data.has(biome_key):
		# Merge tuning overrides with hardcoded defaults
		var base: Dictionary = BIOMES.get(biome_key, {}).duplicate(true)
		var overrides: Dictionary = biomes_data[biome_key]
		for k in overrides:
			base[k] = overrides[k]
		return base
	return {}
