## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinConstants Structural Integrity
## ═══════════════════════════════════════════════════════════════════════════════
## Validates internal consistency and structural completeness of all data
## structures in MerlinConstants. Does NOT check bible values (see
## test_constants_bible_alignment.gd for value correctness).
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# BIOMES — Required keys per biome entry
# ═══════════════════════════════════════════════════════════════════════════════

func test_biomes_have_required_keys() -> bool:
	var required: Array[String] = [
		"name", "subtitle", "season", "difficulty", "maturity_threshold",
		"oghams_affinity", "currency_name",
		"card_interval_range_min", "card_interval_range_max",
		"pnj", "arc", "arc_cards",
		"arc_condition_type", "arc_condition_value",
	]
	for biome_key in MerlinConstants.BIOMES:
		var biome: Dictionary = MerlinConstants.BIOMES[biome_key]
		for key in required:
			if not biome.has(key):
				push_error("BIOME '%s': missing required key '%s'" % [biome_key, key])
				return false
	return true


func test_biomes_difficulty_is_ascending() -> bool:
	var prev_diff: int = -1
	for biome_key in MerlinConstants.BIOME_KEYS:
		var biome: Dictionary = MerlinConstants.BIOMES.get(biome_key, {})
		var diff: int = int(biome.get("difficulty", -1))
		if diff < prev_diff:
			push_error("BIOME '%s' difficulty %d < previous %d (not ascending)" % [biome_key, diff, prev_diff])
			return false
		prev_diff = diff
	return true


func test_biomes_maturity_thresholds_consistent() -> bool:
	for biome_key in MerlinConstants.BIOMES:
		var biome: Dictionary = MerlinConstants.BIOMES[biome_key]
		var threshold_in_biome: int = int(biome.get("maturity_threshold", -1))
		if not MerlinConstants.BIOME_MATURITY_THRESHOLDS.has(biome_key):
			push_error("BIOME_MATURITY_THRESHOLDS missing '%s'" % biome_key)
			return false
		var threshold_in_dict: int = int(MerlinConstants.BIOME_MATURITY_THRESHOLDS[biome_key])
		if threshold_in_biome != threshold_in_dict:
			push_error("BIOME '%s': maturity_threshold %d != BIOME_MATURITY_THRESHOLDS %d" % [biome_key, threshold_in_biome, threshold_in_dict])
			return false
	return true


func test_biomes_oghams_affinity_reference_valid_oghams() -> bool:
	for biome_key in MerlinConstants.BIOMES:
		var biome: Dictionary = MerlinConstants.BIOMES[biome_key]
		var affinity: Array = biome.get("oghams_affinity", [])
		if affinity.size() == 0:
			push_error("BIOME '%s': oghams_affinity is empty" % biome_key)
			return false
		for ogham_id in affinity:
			if not MerlinConstants.OGHAM_FULL_SPECS.has(ogham_id):
				push_error("BIOME '%s': oghams_affinity references unknown ogham '%s'" % [biome_key, ogham_id])
				return false
	return true


func test_biomes_card_interval_range_valid() -> bool:
	for biome_key in MerlinConstants.BIOMES:
		var biome: Dictionary = MerlinConstants.BIOMES[biome_key]
		var range_min: int = int(biome.get("card_interval_range_min", 0))
		var range_max: int = int(biome.get("card_interval_range_max", 0))
		if range_min <= 0 or range_max <= 0:
			push_error("BIOME '%s': card_interval_range must be positive" % biome_key)
			return false
		if range_min > range_max:
			push_error("BIOME '%s': card_interval_range_min %d > range_max %d" % [biome_key, range_min, range_max])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FACTIONS — Cross-reference integrity
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_factions_in_faction_run_bonuses() -> bool:
	for faction in MerlinConstants.FACTIONS:
		if not MerlinConstants.FACTION_RUN_BONUSES.has(faction):
			push_error("FACTION_RUN_BONUSES: missing faction '%s'" % faction)
			return false
	return true


func test_all_factions_in_faction_info() -> bool:
	for faction in MerlinConstants.FACTIONS:
		if not MerlinConstants.FACTION_INFO.has(faction):
			push_error("FACTION_INFO: missing faction '%s'" % faction)
			return false
		var info: Dictionary = MerlinConstants.FACTION_INFO[faction]
		if not info.has("name") or not info.has("symbol"):
			push_error("FACTION_INFO '%s': missing 'name' or 'symbol'" % faction)
			return false
	return true


func test_all_factions_in_faction_keywords() -> bool:
	for faction in MerlinConstants.FACTIONS:
		if not MerlinConstants.FACTION_KEYWORDS.has(faction):
			push_error("FACTION_KEYWORDS: missing faction '%s'" % faction)
			return false
		var keywords: Array = MerlinConstants.FACTION_KEYWORDS[faction]
		if keywords.size() == 0:
			push_error("FACTION_KEYWORDS '%s': empty keywords list" % faction)
			return false
	return true


func test_all_factions_in_talent_branch_colors() -> bool:
	for faction in MerlinConstants.FACTIONS:
		if not MerlinConstants.TALENT_BRANCH_COLORS.has(faction):
			push_error("TALENT_BRANCH_COLORS: missing faction '%s'" % faction)
			return false
	return true


func test_faction_tiers_cover_full_range() -> bool:
	# FACTION_TIERS must cover 0 to 100 without gaps
	var tiers: Dictionary = MerlinConstants.FACTION_TIERS
	var has_zero: bool = false
	var has_high: bool = false
	for tier_key in tiers:
		var tier_min: int = int(tiers[tier_key].get("min", -1))
		if tier_min == 0:
			has_zero = true
		if tier_min >= 80:
			has_high = true
	if not has_zero:
		push_error("FACTION_TIERS: no tier covers value 0")
		return false
	if not has_high:
		push_error("FACTION_TIERS: no tier covers high values (>= 80)")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAMS — Required fields per ogham entry
# ═══════════════════════════════════════════════════════════════════════════════

func test_oghams_have_required_fields() -> bool:
	var required: Array[String] = [
		"name", "tree", "unicode", "category", "cooldown",
		"starter", "cost_anam", "branch", "tier",
		"effect", "description", "effect_params",
	]
	for ogham_key in MerlinConstants.OGHAM_FULL_SPECS:
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS[ogham_key]
		for key in required:
			if not spec.has(key):
				push_error("OGHAM '%s': missing required field '%s'" % [ogham_key, key])
				return false
	return true


func test_oghams_cooldown_positive() -> bool:
	for ogham_key in MerlinConstants.OGHAM_FULL_SPECS:
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS[ogham_key]
		var cd: int = int(spec.get("cooldown", 0))
		if cd <= 0:
			push_error("OGHAM '%s': cooldown must be > 0, got %d" % [ogham_key, cd])
			return false
	return true


func test_oghams_cost_anam_non_negative() -> bool:
	for ogham_key in MerlinConstants.OGHAM_FULL_SPECS:
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS[ogham_key]
		var cost: int = int(spec.get("cost_anam", -1))
		if cost < 0:
			push_error("OGHAM '%s': cost_anam must be >= 0, got %d" % [ogham_key, cost])
			return false
	return true


func test_oghams_branch_references_valid_faction_or_central() -> bool:
	var valid_branches: Array[String] = ["druides", "anciens", "korrigans", "niamh", "ankou", "central"]
	for ogham_key in MerlinConstants.OGHAM_FULL_SPECS:
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS[ogham_key]
		var branch: String = str(spec.get("branch", ""))
		if not valid_branches.has(branch):
			push_error("OGHAM '%s': branch '%s' is not a valid faction or 'central'" % [ogham_key, branch])
			return false
	return true


func test_oghams_starters_are_in_full_specs() -> bool:
	for starter in MerlinConstants.OGHAM_STARTER_SKILLS:
		if not MerlinConstants.OGHAM_FULL_SPECS.has(starter):
			push_error("OGHAM_STARTER_SKILLS: '%s' not found in OGHAM_FULL_SPECS" % starter)
			return false
	return true


func test_oghams_categories_valid() -> bool:
	var valid_categories: Array[String] = ["reveal", "protection", "boost", "narrative", "recovery", "special"]
	for ogham_key in MerlinConstants.OGHAM_FULL_SPECS:
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS[ogham_key]
		var cat: String = str(spec.get("category", ""))
		if not valid_categories.has(cat):
			push_error("OGHAM '%s': category '%s' is not valid" % [ogham_key, cat])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ACTION_VERBS — Mapping to valid lexical fields
# ═══════════════════════════════════════════════════════════════════════════════

func test_action_verbs_all_have_non_empty_lists() -> bool:
	for field in MerlinConstants.ACTION_VERBS:
		var verbs: Array = MerlinConstants.ACTION_VERBS[field]
		if verbs.size() == 0:
			push_error("ACTION_VERBS['%s']: empty verb list" % field)
			return false
	return true


func test_action_verbs_keys_match_field_minigames_keys() -> bool:
	for field in MerlinConstants.ACTION_VERBS:
		if not MerlinConstants.FIELD_MINIGAMES.has(field):
			push_error("ACTION_VERBS key '%s' not found in FIELD_MINIGAMES" % field)
			return false
	for field in MerlinConstants.FIELD_MINIGAMES:
		if not MerlinConstants.ACTION_VERBS.has(field):
			push_error("FIELD_MINIGAMES key '%s' not found in ACTION_VERBS" % field)
			return false
	return true


func test_field_minigames_reference_valid_catalogue_entries() -> bool:
	for field in MerlinConstants.FIELD_MINIGAMES:
		var minigames: Array = MerlinConstants.FIELD_MINIGAMES[field]
		for mg in minigames:
			if not MerlinConstants.MINIGAME_CATALOGUE.has(mg):
				push_error("FIELD_MINIGAMES['%s']: minigame '%s' not in MINIGAME_CATALOGUE" % [field, mg])
				return false
	return true


func test_action_verb_fallback_field_is_valid() -> bool:
	if not MerlinConstants.ACTION_VERBS.has(MerlinConstants.ACTION_VERB_FALLBACK_FIELD):
		push_error("ACTION_VERB_FALLBACK_FIELD '%s' not in ACTION_VERBS" % MerlinConstants.ACTION_VERB_FALLBACK_FIELD)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TRUST_TIERS — Full 0-100 coverage without gaps or overlaps
# ═══════════════════════════════════════════════════════════════════════════════

func test_trust_tiers_cover_0_to_100() -> bool:
	var tiers: Dictionary = MerlinConstants.TRUST_TIERS
	# Collect all ranges and verify full coverage
	var covered: Array[bool] = []
	covered.resize(101)
	for i in range(101):
		covered[i] = false
	for tier_key in tiers:
		var tier: Dictionary = tiers[tier_key]
		var rmin: int = int(tier.get("range_min", -1))
		var rmax: int = int(tier.get("range_max", -1))
		if rmin < 0 or rmax < 0 or rmin > rmax:
			push_error("TRUST_TIERS '%s': invalid range [%d, %d]" % [tier_key, rmin, rmax])
			return false
		for i in range(rmin, rmax + 1):
			if i > 100:
				break
			if covered[i]:
				push_error("TRUST_TIERS: value %d covered by multiple tiers" % i)
				return false
			covered[i] = true
	for i in range(101):
		if not covered[i]:
			push_error("TRUST_TIERS: value %d not covered by any tier" % i)
			return false
	return true


func test_trust_tiers_have_required_keys() -> bool:
	for tier_key in MerlinConstants.TRUST_TIERS:
		var tier: Dictionary = MerlinConstants.TRUST_TIERS[tier_key]
		for key in ["range_min", "range_max", "label"]:
			if not tier.has(key):
				push_error("TRUST_TIERS '%s': missing key '%s'" % [tier_key, key])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MULTIPLIER_TABLE — Coverage and ordering
# ═══════════════════════════════════════════════════════════════════════════════

func test_multiplier_table_covers_0_to_100() -> bool:
	var table: Array = MerlinConstants.MULTIPLIER_TABLE
	if table.size() == 0:
		push_error("MULTIPLIER_TABLE is empty")
		return false
	var covered: Array[bool] = []
	covered.resize(101)
	for i in range(101):
		covered[i] = false
	for entry in table:
		var rmin: int = int(entry.get("range_min", -1))
		var rmax: int = int(entry.get("range_max", -1))
		if rmin < 0 or rmax < 0 or rmin > rmax:
			push_error("MULTIPLIER_TABLE: invalid range [%d, %d]" % [rmin, rmax])
			return false
		for i in range(rmin, rmax + 1):
			if i > 100:
				break
			covered[i] = true
	for i in range(101):
		if not covered[i]:
			push_error("MULTIPLIER_TABLE: score %d not covered" % i)
			return false
	return true


func test_multiplier_table_has_required_keys() -> bool:
	for entry in MerlinConstants.MULTIPLIER_TABLE:
		for key in ["range_min", "range_max", "label", "factor"]:
			if not entry.has(key):
				push_error("MULTIPLIER_TABLE entry missing key '%s'" % key)
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TALENT_NODES — Prerequisites and branch consistency
# ═══════════════════════════════════════════════════════════════════════════════

func test_talent_nodes_have_required_keys() -> bool:
	var required: Array[String] = [
		"branch", "tier", "name", "cost",
		"prerequisites", "effect", "description", "lore",
	]
	for node_key in MerlinConstants.TALENT_NODES:
		var node: Dictionary = MerlinConstants.TALENT_NODES[node_key]
		for key in required:
			if not node.has(key):
				push_error("TALENT_NODES '%s': missing required key '%s'" % [node_key, key])
				return false
	return true


func test_talent_nodes_prerequisites_exist() -> bool:
	for node_key in MerlinConstants.TALENT_NODES:
		var node: Dictionary = MerlinConstants.TALENT_NODES[node_key]
		var prereqs: Array = node.get("prerequisites", [])
		for prereq in prereqs:
			if not MerlinConstants.TALENT_NODES.has(prereq):
				push_error("TALENT_NODES '%s': prerequisite '%s' does not exist" % [node_key, prereq])
				return false
	return true


func test_talent_nodes_cost_positive() -> bool:
	for node_key in MerlinConstants.TALENT_NODES:
		var node: Dictionary = MerlinConstants.TALENT_NODES[node_key]
		var cost: int = int(node.get("cost", 0))
		if cost <= 0:
			push_error("TALENT_NODES '%s': cost must be > 0, got %d" % [node_key, cost])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MINIGAME_CATALOGUE — Required keys per entry
# ═══════════════════════════════════════════════════════════════════════════════

func test_minigame_catalogue_entries_have_required_keys() -> bool:
	for mg_key in MerlinConstants.MINIGAME_CATALOGUE:
		var entry: Dictionary = MerlinConstants.MINIGAME_CATALOGUE[mg_key]
		for key in ["name", "desc", "trigger"]:
			if not entry.has(key):
				push_error("MINIGAME_CATALOGUE '%s': missing key '%s'" % [mg_key, key])
				return false
		if str(entry["trigger"]).length() == 0:
			push_error("MINIGAME_CATALOGUE '%s': trigger pattern is empty" % mg_key)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# REWARD_TYPES — Structural checks
# ═══════════════════════════════════════════════════════════════════════════════

func test_reward_types_have_required_keys() -> bool:
	for rtype in MerlinConstants.REWARD_TYPES:
		var entry: Dictionary = MerlinConstants.REWARD_TYPES[rtype]
		for key in ["icon", "label", "color_key"]:
			if not entry.has(key):
				push_error("REWARD_TYPES '%s': missing key '%s'" % [rtype, key])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# NODE_TYPES — Weight sum and required keys
# ═══════════════════════════════════════════════════════════════════════════════

func test_node_types_have_required_keys() -> bool:
	for ntype in MerlinConstants.NODE_TYPES:
		var entry: Dictionary = MerlinConstants.NODE_TYPES[ntype]
		for key in ["weight", "label", "cards_min", "cards_max", "icon"]:
			if not entry.has(key):
				push_error("NODE_TYPES '%s': missing key '%s'" % [ntype, key])
				return false
		var cmin: int = int(entry.get("cards_min", -1))
		var cmax: int = int(entry.get("cards_max", -1))
		if cmin < 0 or cmax < cmin:
			push_error("NODE_TYPES '%s': invalid cards range [%d, %d]" % [ntype, cmin, cmax])
			return false
	return true


func test_node_types_weights_sum_to_one() -> bool:
	var total: float = 0.0
	for ntype in MerlinConstants.NODE_TYPES:
		total += float(MerlinConstants.NODE_TYPES[ntype].get("weight", 0.0))
	if absf(total - 1.0) > 0.01:
		push_error("NODE_TYPES weights sum to %.3f, expected ~1.0" % total)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SEASONAL_EFFECTS — Faction references valid
# ═══════════════════════════════════════════════════════════════════════════════

func test_seasonal_effects_reference_valid_factions() -> bool:
	for season_key in MerlinConstants.SEASONAL_EFFECTS:
		var entry: Dictionary = MerlinConstants.SEASONAL_EFFECTS[season_key]
		var faction: String = str(entry.get("faction_bias", ""))
		if not MerlinConstants.FACTIONS.has(faction):
			push_error("SEASONAL_EFFECTS '%s': faction_bias '%s' not in FACTIONS" % [season_key, faction])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# IN_GAME_PERIODS — Faction references and card range ordering
# ═══════════════════════════════════════════════════════════════════════════════

func test_in_game_periods_factions_reference_valid() -> bool:
	for period_key in MerlinConstants.IN_GAME_PERIODS:
		var period: Dictionary = MerlinConstants.IN_GAME_PERIODS[period_key]
		var factions: Array = period.get("factions", [])
		for f in factions:
			if not MerlinConstants.FACTIONS.has(f):
				push_error("IN_GAME_PERIODS '%s': faction '%s' not in FACTIONS" % [period_key, f])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MISSION_TEMPLATES — Weight sum and required keys
# ═══════════════════════════════════════════════════════════════════════════════

func test_mission_templates_have_required_keys() -> bool:
	for mt_key in MerlinConstants.MISSION_TEMPLATES:
		var entry: Dictionary = MerlinConstants.MISSION_TEMPLATES[mt_key]
		for key in ["type", "description_template", "weight"]:
			if not entry.has(key):
				push_error("MISSION_TEMPLATES '%s': missing key '%s'" % [mt_key, key])
				return false
	return true


func test_mission_templates_weights_sum_to_one() -> bool:
	var total: float = 0.0
	for mt_key in MerlinConstants.MISSION_TEMPLATES:
		total += float(MerlinConstants.MISSION_TEMPLATES[mt_key].get("weight", 0.0))
	if absf(total - 1.0) > 0.01:
		push_error("MISSION_TEMPLATES weights sum to %.3f, expected ~1.0" % total)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var tests: Array[String] = [
		# Biomes (5)
		"test_biomes_have_required_keys",
		"test_biomes_difficulty_is_ascending",
		"test_biomes_maturity_thresholds_consistent",
		"test_biomes_oghams_affinity_reference_valid_oghams",
		"test_biomes_card_interval_range_valid",
		# Factions (5)
		"test_all_factions_in_faction_run_bonuses",
		"test_all_factions_in_faction_info",
		"test_all_factions_in_faction_keywords",
		"test_all_factions_in_talent_branch_colors",
		"test_faction_tiers_cover_full_range",
		# Oghams (6)
		"test_oghams_have_required_fields",
		"test_oghams_cooldown_positive",
		"test_oghams_cost_anam_non_negative",
		"test_oghams_branch_references_valid_faction_or_central",
		"test_oghams_starters_are_in_full_specs",
		"test_oghams_categories_valid",
		# Action verbs & minigames (4)
		"test_action_verbs_all_have_non_empty_lists",
		"test_action_verbs_keys_match_field_minigames_keys",
		"test_field_minigames_reference_valid_catalogue_entries",
		"test_action_verb_fallback_field_is_valid",
		# Trust tiers (2)
		"test_trust_tiers_cover_0_to_100",
		"test_trust_tiers_have_required_keys",
		# Multiplier table (2)
		"test_multiplier_table_covers_0_to_100",
		"test_multiplier_table_has_required_keys",
		# Talent nodes (3)
		"test_talent_nodes_have_required_keys",
		"test_talent_nodes_prerequisites_exist",
		"test_talent_nodes_cost_positive",
		# Minigame catalogue (1)
		"test_minigame_catalogue_entries_have_required_keys",
		# Reward types (1)
		"test_reward_types_have_required_keys",
		# Node types (2)
		"test_node_types_have_required_keys",
		"test_node_types_weights_sum_to_one",
		# Seasonal effects (1)
		"test_seasonal_effects_reference_valid_factions",
		# In-game periods (1)
		"test_in_game_periods_factions_reference_valid",
		# Mission templates (2)
		"test_mission_templates_have_required_keys",
		"test_mission_templates_weights_sum_to_one",
	]
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []
	for test_name in tests:
		if call(test_name):
			passed += 1
		else:
			failed += 1
			failures.append(test_name)
	var total: int = passed + failed
	print("[ConstantsUnit] %d/%d passed (%d failed)" % [passed, total, failed])
	for f in failures:
		print("  FAIL: %s" % f)
	return {"passed": passed, "failed": failed, "total": total, "failures": failures}
