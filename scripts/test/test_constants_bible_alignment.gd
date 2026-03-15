## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — Constants vs Bible v2.4 Alignment
## ═══════════════════════════════════════════════════════════════════════════════
## Verifies that code constants in MerlinConstants match the values defined
## in GAME_DESIGN_BIBLE.md v2.4. Catches drift between design and code.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# FACTIONS
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_faction_ids_exist() -> bool:
	var expected: Array[String] = ["druides", "anciens", "korrigans", "niamh", "ankou"]
	if MerlinConstants.FACTIONS.size() != expected.size():
		push_error("FACTIONS: expected %d, got %d" % [expected.size(), MerlinConstants.FACTIONS.size()])
		return false
	for f in expected:
		if not MerlinConstants.FACTIONS.has(f):
			push_error("FACTIONS: missing faction '%s'" % f)
			return false
	return true


func test_faction_thresholds_match_bible() -> bool:
	# Bible v2.4 s.2.3: content=50, ending=80
	if MerlinConstants.FACTION_THRESHOLD_CONTENT != 50:
		push_error("FACTION_THRESHOLD_CONTENT: expected 50, got %d" % MerlinConstants.FACTION_THRESHOLD_CONTENT)
		return false
	if MerlinConstants.FACTION_THRESHOLD_ENDING != 80:
		push_error("FACTION_THRESHOLD_ENDING: expected 80, got %d" % MerlinConstants.FACTION_THRESHOLD_ENDING)
		return false
	return true


func test_faction_score_bounds() -> bool:
	# Bible v2.4 s.2.3: 0.0 to 100.0
	if MerlinConstants.FACTION_SCORE_MIN != 0:
		push_error("FACTION_SCORE_MIN: expected 0, got %d" % MerlinConstants.FACTION_SCORE_MIN)
		return false
	if MerlinConstants.FACTION_SCORE_MAX != 100:
		push_error("FACTION_SCORE_MAX: expected 100, got %d" % MerlinConstants.FACTION_SCORE_MAX)
		return false
	if MerlinConstants.FACTION_SCORE_START != 0:
		push_error("FACTION_SCORE_START: expected 0, got %d" % MerlinConstants.FACTION_SCORE_START)
		return false
	return true


func test_faction_info_covers_all_factions() -> bool:
	for f in MerlinConstants.FACTIONS:
		if not MerlinConstants.FACTION_INFO.has(f):
			push_error("FACTION_INFO: missing entry for '%s'" % f)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# BIOMES
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_biome_ids_exist() -> bool:
	var expected: Array[String] = [
		"foret_broceliande", "landes_bruyere", "cotes_sauvages",
		"villages_celtes", "cercles_pierres", "marais_korrigans",
		"collines_dolmens", "iles_mystiques",
	]
	if MerlinConstants.BIOMES.size() != 8:
		push_error("BIOMES: expected 8, got %d" % MerlinConstants.BIOMES.size())
		return false
	for b in expected:
		if not MerlinConstants.BIOMES.has(b):
			push_error("BIOMES: missing biome '%s'" % b)
			return false
	return true


func test_biome_maturity_thresholds_match_bible() -> bool:
	# Bible v2.4 s.4.1: specific thresholds per biome
	var expected: Dictionary = {
		"foret_broceliande": 0,
		"landes_bruyere": 15,
		"cotes_sauvages": 15,
		"villages_celtes": 25,
		"cercles_pierres": 30,
		"marais_korrigans": 40,
		"collines_dolmens": 50,
		"iles_mystiques": 75,
	}
	for biome_key in expected:
		var biome_data: Dictionary = MerlinConstants.BIOMES.get(biome_key, {})
		var threshold: int = int(biome_data.get("maturity_threshold", -1))
		if threshold != int(expected[biome_key]):
			push_error("BIOME %s maturity: expected %d, got %d" % [biome_key, expected[biome_key], threshold])
			return false
	return true


func test_biome_keys_array_matches_biomes_dict() -> bool:
	if MerlinConstants.BIOME_KEYS.size() != MerlinConstants.BIOMES.size():
		push_error("BIOME_KEYS size (%d) != BIOMES size (%d)" % [MerlinConstants.BIOME_KEYS.size(), MerlinConstants.BIOMES.size()])
		return false
	for key in MerlinConstants.BIOME_KEYS:
		if not MerlinConstants.BIOMES.has(key):
			push_error("BIOME_KEYS has '%s' not in BIOMES dict" % key)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAMS
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_count_is_18() -> bool:
	var count: int = MerlinConstants.OGHAM_FULL_SPECS.size()
	if count != 18:
		push_error("OGHAM_FULL_SPECS: expected 18 oghams, got %d" % count)
		return false
	return true


func test_all_ogham_ids_exist() -> bool:
	var expected: Array[String] = [
		"beith", "coll", "ailm",
		"luis", "gort", "eadhadh",
		"duir", "tinne", "onn",
		"nuin", "huath", "straif",
		"quert", "ruis", "saille",
		"muin", "ioho", "ur",
	]
	for ogham_id in expected:
		if not MerlinConstants.OGHAM_FULL_SPECS.has(ogham_id):
			push_error("OGHAM_FULL_SPECS: missing ogham '%s'" % ogham_id)
			return false
	return true


func test_ogham_starters_match_bible() -> bool:
	# Bible v2.4 s.2.2: 3 starters: beith, luis, quert (cost 0)
	var starters: Array = MerlinConstants.OGHAM_STARTER_SKILLS
	if starters.size() != 3:
		push_error("OGHAM_STARTER_SKILLS: expected 3, got %d" % starters.size())
		return false
	for s in ["beith", "luis", "quert"]:
		if not starters.has(s):
			push_error("OGHAM_STARTER_SKILLS: missing starter '%s'" % s)
			return false
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(s, {})
		if int(spec.get("cost_anam", -1)) != 0:
			push_error("Starter ogham '%s' should have cost_anam=0, got %d" % [s, spec.get("cost_anam", -1)])
			return false
		if not spec.get("starter", false):
			push_error("Starter ogham '%s' should have starter=true" % s)
			return false
	return true


func test_ogham_cooldowns_match_bible() -> bool:
	# Bible v2.4 s.2.2 catalogue: specific cooldowns per ogham
	var expected_cooldowns: Dictionary = {
		"beith": 3, "coll": 5, "ailm": 4,
		"luis": 4, "gort": 6, "eadhadh": 8,
		"duir": 4, "tinne": 5, "onn": 7,
		"nuin": 6, "huath": 5, "straif": 10,
		"quert": 4, "ruis": 8, "saille": 6,
		"muin": 7, "ioho": 12, "ur": 10,
	}
	for ogham_key in expected_cooldowns:
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_key, {})
		var actual: int = int(spec.get("cooldown", -1))
		var expected_val: int = int(expected_cooldowns[ogham_key])
		if actual != expected_val:
			push_error("Ogham '%s' cooldown: expected %d, got %d" % [ogham_key, expected_val, actual])
			return false
	return true


func test_ogham_costs_match_bible() -> bool:
	# Bible v2.4 s.2.2 catalogue: specific Anam costs per ogham
	var expected_costs: Dictionary = {
		"beith": 0, "coll": 80, "ailm": 60,
		"luis": 0, "gort": 100, "eadhadh": 150,
		"duir": 70, "tinne": 120, "onn": 90,
		"nuin": 80, "huath": 100, "straif": 140,
		"quert": 0, "ruis": 130, "saille": 90,
		"muin": 110, "ioho": 160, "ur": 140,
	}
	for ogham_key in expected_costs:
		var spec: Dictionary = MerlinConstants.OGHAM_FULL_SPECS.get(ogham_key, {})
		var actual: int = int(spec.get("cost_anam", -1))
		var expected_val: int = int(expected_costs[ogham_key])
		if actual != expected_val:
			push_error("Ogham '%s' cost_anam: expected %d, got %d" % [ogham_key, expected_val, actual])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# LEXICAL FIELDS & MINIGAMES
# ═══════════════════════════════════════════════════════════════════════════════

func test_lexical_fields_count_is_8() -> bool:
	# Bible v2.4 s.2.5: 8 champs lexicaux
	var count: int = MerlinConstants.ACTION_VERBS.size()
	if count != 8:
		push_error("ACTION_VERBS: expected 8 fields, got %d" % count)
		return false
	return true


func test_all_lexical_fields_exist() -> bool:
	var expected: Array[String] = [
		"chance", "bluff", "observation", "logique",
		"finesse", "vigueur", "esprit", "perception",
	]
	for field in expected:
		if not MerlinConstants.ACTION_VERBS.has(field):
			push_error("ACTION_VERBS: missing field '%s'" % field)
			return false
		if not MerlinConstants.FIELD_MINIGAMES.has(field):
			push_error("FIELD_MINIGAMES: missing field '%s'" % field)
			return false
	return true


func test_field_minigames_mapping_matches_bible() -> bool:
	# Bible v2.4 s.2.5: specific mappings
	var expected: Dictionary = {
		"chance": ["herboristerie"],
		"bluff": ["negociation"],
		"observation": ["fouille", "regard"],
		"logique": ["runes"],
		"finesse": ["ombres", "equilibre"],
		"vigueur": ["combat_rituel", "course"],
		"esprit": ["apaisement", "volonte", "sang_froid"],
		"perception": ["traces", "echo"],
	}
	for field in expected:
		var actual: Array = MerlinConstants.FIELD_MINIGAMES.get(field, [])
		var expected_arr: Array = expected[field]
		if actual.size() != expected_arr.size():
			push_error("FIELD_MINIGAMES[%s]: expected %d minigames, got %d" % [field, expected_arr.size(), actual.size()])
			return false
		for mg in expected_arr:
			if not actual.has(mg):
				push_error("FIELD_MINIGAMES[%s]: missing minigame '%s'" % [field, mg])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT TYPES & CAPS
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_effect_types_in_engine() -> bool:
	# Bible v2.4 s.6.5: authorized effects
	var expected_effects: Array[String] = [
		"ADD_REPUTATION", "HEAL_LIFE", "DAMAGE_LIFE", "UNLOCK_OGHAM",
		"ADD_TAG", "REMOVE_TAG", "TRIGGER_EVENT", "PLAY_SFX",
		"ADD_BIOME_CURRENCY", "SHOW_DIALOG",
	]
	var engine := MerlinEffectEngine.new()
	for effect_type in expected_effects:
		if not MerlinEffectEngine.VALID_CODES.has(effect_type):
			push_error("VALID_CODES: missing effect type '%s'" % effect_type)
			return false
	return true


func test_effect_caps_match_bible() -> bool:
	# Bible v2.4 s.6.5: caps
	var caps: Dictionary = MerlinConstants.EFFECT_CAPS
	if int(caps["ADD_REPUTATION"]["max"]) != 20:
		push_error("EFFECT_CAPS ADD_REPUTATION max: expected 20")
		return false
	if int(caps["ADD_REPUTATION"]["min"]) != -20:
		push_error("EFFECT_CAPS ADD_REPUTATION min: expected -20")
		return false
	if int(caps["HEAL_LIFE"]["max"]) != 18:
		push_error("EFFECT_CAPS HEAL_LIFE max: expected 18")
		return false
	if int(caps["DAMAGE_LIFE"]["max"]) != 15:
		push_error("EFFECT_CAPS DAMAGE_LIFE max: expected 15")
		return false
	if int(caps["ADD_BIOME_CURRENCY"]["max"]) != 10:
		push_error("EFFECT_CAPS ADD_BIOME_CURRENCY max: expected 10")
		return false
	if int(caps["effects_per_option"]) != 3:
		push_error("EFFECT_CAPS effects_per_option: expected 3")
		return false
	if float(caps["score_bonus_cap"]) != 2.0:
		push_error("EFFECT_CAPS score_bonus_cap: expected 2.0")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MOS CONVERGENCE
# ═══════════════════════════════════════════════════════════════════════════════

func test_mos_thresholds_match_bible() -> bool:
	# Bible v2.4 s.3.2: soft_min=8, target=20-25, soft_max=40, hard_max=50
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	if int(mos["soft_min_cards"]) != 8:
		push_error("MOS soft_min_cards: expected 8, got %d" % mos["soft_min_cards"])
		return false
	if int(mos["target_cards_min"]) != 20:
		push_error("MOS target_cards_min: expected 20, got %d" % mos["target_cards_min"])
		return false
	if int(mos["target_cards_max"]) != 25:
		push_error("MOS target_cards_max: expected 25, got %d" % mos["target_cards_max"])
		return false
	if int(mos["soft_max_cards"]) != 40:
		push_error("MOS soft_max_cards: expected 40, got %d" % mos["soft_max_cards"])
		return false
	if int(mos["hard_max_cards"]) != 50:
		push_error("MOS hard_max_cards: expected 50, got %d" % mos["hard_max_cards"])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# LIFE / VIE
# ═══════════════════════════════════════════════════════════════════════════════

func test_life_caps_match_bible() -> bool:
	# Bible v2.4 s.2.1: max=100, start=100, drain=1, low_threshold=25
	if MerlinConstants.LIFE_ESSENCE_MAX != 100:
		push_error("LIFE_ESSENCE_MAX: expected 100, got %d" % MerlinConstants.LIFE_ESSENCE_MAX)
		return false
	if MerlinConstants.LIFE_ESSENCE_START != 100:
		push_error("LIFE_ESSENCE_START: expected 100, got %d" % MerlinConstants.LIFE_ESSENCE_START)
		return false
	if MerlinConstants.LIFE_ESSENCE_DRAIN_PER_CARD != 1:
		push_error("LIFE_ESSENCE_DRAIN_PER_CARD: expected 1, got %d" % MerlinConstants.LIFE_ESSENCE_DRAIN_PER_CARD)
		return false
	if MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD != 25:
		push_error("LIFE_ESSENCE_LOW_THRESHOLD: expected 25, got %d" % MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD)
		return false
	if MerlinConstants.LIFE_ESSENCE_HEAL_PER_REST != 18:
		push_error("LIFE_ESSENCE_HEAL_PER_REST: expected 18, got %d" % MerlinConstants.LIFE_ESSENCE_HEAL_PER_REST)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TRUST / CONFIANCE MERLIN
# ═══════════════════════════════════════════════════════════════════════════════

func test_trust_tiers_match_bible() -> bool:
	# Bible v2.4 s.6.3: T0=0-24, T1=25-49, T2=50-74, T3=75-100
	var tiers: Dictionary = MerlinConstants.TRUST_TIERS
	if int(tiers["T0"]["range_min"]) != 0 or int(tiers["T0"]["range_max"]) != 24:
		push_error("TRUST_TIERS T0: expected 0-24")
		return false
	if int(tiers["T1"]["range_min"]) != 25 or int(tiers["T1"]["range_max"]) != 49:
		push_error("TRUST_TIERS T1: expected 25-49")
		return false
	if int(tiers["T2"]["range_min"]) != 50 or int(tiers["T2"]["range_max"]) != 74:
		push_error("TRUST_TIERS T2: expected 50-74")
		return false
	if int(tiers["T3"]["range_min"]) != 75 or int(tiers["T3"]["range_max"]) != 100:
		push_error("TRUST_TIERS T3: expected 75-100")
		return false
	return true


func test_trust_deltas_match_bible() -> bool:
	# Bible v2.4 s.6.3: promise_kept=+10, promise_broken=-15
	var deltas: Dictionary = MerlinConstants.TRUST_DELTAS
	if int(deltas["promise_kept"]) != 10:
		push_error("TRUST_DELTAS promise_kept: expected 10, got %d" % deltas["promise_kept"])
		return false
	if int(deltas["promise_broken"]) != -15:
		push_error("TRUST_DELTAS promise_broken: expected -15, got %d" % deltas["promise_broken"])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MULTIPLIER TABLE
# ═══════════════════════════════════════════════════════════════════════════════

func test_multiplier_table_match_bible() -> bool:
	# Bible v2.4 s.2.5: 5 tiers of score->factor
	var table: Array = MerlinConstants.MULTIPLIER_TABLE
	if table.size() != 5:
		push_error("MULTIPLIER_TABLE: expected 5 entries, got %d" % table.size())
		return false
	# Echec critique: 0-20 -> -1.5
	if int(table[0]["range_min"]) != 0 or int(table[0]["range_max"]) != 20 or float(table[0]["factor"]) != -1.5:
		push_error("MULTIPLIER_TABLE[0]: expected 0-20 -> -1.5")
		return false
	# Echec: 21-50 -> -1.0
	if int(table[1]["range_min"]) != 21 or int(table[1]["range_max"]) != 50 or float(table[1]["factor"]) != -1.0:
		push_error("MULTIPLIER_TABLE[1]: expected 21-50 -> -1.0")
		return false
	# Reussite partielle: 51-79 -> 0.5
	if int(table[2]["range_min"]) != 51 or int(table[2]["range_max"]) != 79 or float(table[2]["factor"]) != 0.5:
		push_error("MULTIPLIER_TABLE[2]: expected 51-79 -> 0.5")
		return false
	# Reussite: 80-94 -> 1.0
	if int(table[3]["range_min"]) != 80 or int(table[3]["range_max"]) != 94 or float(table[3]["factor"]) != 1.0:
		push_error("MULTIPLIER_TABLE[3]: expected 80-94 -> 1.0")
		return false
	# Reussite critique: 95-100 -> 1.5
	if int(table[4]["range_min"]) != 95 or int(table[4]["range_max"]) != 100 or float(table[4]["factor"]) != 1.5:
		push_error("MULTIPLIER_TABLE[4]: expected 95-100 -> 1.5")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ANAM REWARDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_anam_rewards_match_bible() -> bool:
	# Bible v2.4 s.2.4: base=10, victory=15, minigame=2, threshold=80, etc.
	var rewards: Dictionary = MerlinConstants.ANAM_REWARDS
	if int(rewards["base"]) != 10:
		push_error("ANAM_REWARDS base: expected 10")
		return false
	if int(rewards["victory_bonus"]) != 15:
		push_error("ANAM_REWARDS victory_bonus: expected 15")
		return false
	if int(rewards["minigame_won"]) != 2:
		push_error("ANAM_REWARDS minigame_won: expected 2")
		return false
	if int(rewards["minigame_threshold"]) != 80:
		push_error("ANAM_REWARDS minigame_threshold: expected 80")
		return false
	if int(rewards["ogham_used"]) != 1:
		push_error("ANAM_REWARDS ogham_used: expected 1")
		return false
	if int(rewards["faction_honored"]) != 5:
		push_error("ANAM_REWARDS faction_honored: expected 5")
		return false
	if int(rewards["death_cap_cards"]) != 30:
		push_error("ANAM_REWARDS death_cap_cards: expected 30")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# REPUTATION SYSTEM ALIGNMENT
# ═══════════════════════════════════════════════════════════════════════════════

func test_reputation_system_constants_match() -> bool:
	# MerlinReputationSystem must mirror MerlinConstants
	if MerlinReputationSystem.VALUE_MIN != float(MerlinConstants.FACTION_SCORE_MIN):
		push_error("ReputationSystem VALUE_MIN != FACTION_SCORE_MIN")
		return false
	if MerlinReputationSystem.VALUE_MAX != float(MerlinConstants.FACTION_SCORE_MAX):
		push_error("ReputationSystem VALUE_MAX != FACTION_SCORE_MAX")
		return false
	if MerlinReputationSystem.THRESHOLD_CONTENT != float(MerlinConstants.FACTION_THRESHOLD_CONTENT):
		push_error("ReputationSystem THRESHOLD_CONTENT != FACTION_THRESHOLD_CONTENT")
		return false
	if MerlinReputationSystem.THRESHOLD_ENDING != float(MerlinConstants.FACTION_THRESHOLD_ENDING):
		push_error("ReputationSystem THRESHOLD_ENDING != FACTION_THRESHOLD_ENDING")
		return false
	if MerlinReputationSystem.FACTIONS.size() != MerlinConstants.FACTIONS.size():
		push_error("ReputationSystem FACTIONS count mismatch")
		return false
	for f in MerlinConstants.FACTIONS:
		if not MerlinReputationSystem.FACTIONS.has(f):
			push_error("ReputationSystem FACTIONS missing '%s'" % f)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CARD TYPE WEIGHTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_type_weights_match_bible() -> bool:
	# Bible v2.4 s.3.4: narrative=80%, event=10%, promise=5%, merlin_direct=5%
	var weights: Dictionary = MerlinConstants.CARD_TYPE_WEIGHTS
	if absf(float(weights.get("narrative", 0)) - 0.80) > 0.01:
		push_error("CARD_TYPE_WEIGHTS narrative: expected 0.80")
		return false
	if absf(float(weights.get("event", 0)) - 0.10) > 0.01:
		push_error("CARD_TYPE_WEIGHTS event: expected 0.10")
		return false
	if absf(float(weights.get("promise", 0)) - 0.05) > 0.01:
		push_error("CARD_TYPE_WEIGHTS promise: expected 0.05")
		return false
	if absf(float(weights.get("merlin_direct", 0)) - 0.05) > 0.01:
		push_error("CARD_TYPE_WEIGHTS merlin_direct: expected 0.05")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MATURITY WEIGHTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_maturity_weights_match_bible() -> bool:
	# Bible v2.4 s.4.1: total_runs=2, fins_vues=5, oghams_debloques=3, max_faction_rep=1
	var w: Dictionary = MerlinConstants.MATURITY_WEIGHTS
	if int(w.get("total_runs", 0)) != 2:
		push_error("MATURITY_WEIGHTS total_runs: expected 2")
		return false
	if int(w.get("fins_vues", 0)) != 5:
		push_error("MATURITY_WEIGHTS fins_vues: expected 5")
		return false
	if int(w.get("oghams_debloques", 0)) != 3:
		push_error("MATURITY_WEIGHTS oghams_debloques: expected 3")
		return false
	if int(w.get("max_faction_rep", 0)) != 1:
		push_error("MATURITY_WEIGHTS max_faction_rep: expected 1")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SAVE SYSTEM COMPLETENESS
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_profile_has_all_fields() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	var required: Array[String] = [
		"anam", "total_runs", "faction_rep", "trust_merlin",
		"talent_tree", "oghams", "endings_seen", "arc_tags",
		"biome_runs", "biomes_unlocked", "tutorial_flags", "stats",
	]
	for key in required:
		if not profile.has(key):
			push_error("Default profile missing key: '%s'" % key)
			return false
	# faction_rep must have all 5 factions
	var rep: Dictionary = profile.get("faction_rep", {})
	for f in MerlinConstants.FACTIONS:
		if not rep.has(f):
			push_error("Default profile faction_rep missing '%s'" % f)
			return false
	return true


func test_save_run_state_has_critical_fields() -> bool:
	var run_state: Dictionary = MerlinSaveSystem._get_default_run_state()
	var required: Array[String] = [
		"biome", "card_index", "life_essence", "life_max",
		"biome_currency", "active_ogham", "cooldowns", "promises",
		"active", "anam", "cards_played", "day", "hidden",
	]
	for key in required:
		if not run_state.has(key):
			push_error("Default run_state missing key: '%s'" % key)
			return false
	# life_essence must start at bible value
	if int(run_state["life_essence"]) != MerlinConstants.LIFE_ESSENCE_START:
		push_error("Default run_state life_essence != LIFE_ESSENCE_START")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# IN-GAME PERIODS
# ═══════════════════════════════════════════════════════════════════════════════

func test_in_game_periods_match_bible() -> bool:
	# Bible v2.4 s.7.2: 4 periods, 5 cards each
	var periods: Dictionary = MerlinConstants.IN_GAME_PERIODS
	if periods.size() != 4:
		push_error("IN_GAME_PERIODS: expected 4, got %d" % periods.size())
		return false
	for p in ["aube", "jour", "crepuscule", "nuit"]:
		if not periods.has(p):
			push_error("IN_GAME_PERIODS: missing period '%s'" % p)
			return false
	# Nuit bonus should be 0.15 (higher than others at 0.10)
	if absf(float(periods["nuit"]["bonus"]) - 0.15) > 0.01:
		push_error("IN_GAME_PERIODS nuit bonus: expected 0.15")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var tests: Array[String] = [
		"test_all_faction_ids_exist",
		"test_faction_thresholds_match_bible",
		"test_faction_score_bounds",
		"test_faction_info_covers_all_factions",
		"test_all_biome_ids_exist",
		"test_biome_maturity_thresholds_match_bible",
		"test_biome_keys_array_matches_biomes_dict",
		"test_ogham_count_is_18",
		"test_all_ogham_ids_exist",
		"test_ogham_starters_match_bible",
		"test_ogham_cooldowns_match_bible",
		"test_ogham_costs_match_bible",
		"test_lexical_fields_count_is_8",
		"test_all_lexical_fields_exist",
		"test_field_minigames_mapping_matches_bible",
		"test_all_effect_types_in_engine",
		"test_effect_caps_match_bible",
		"test_mos_thresholds_match_bible",
		"test_life_caps_match_bible",
		"test_trust_tiers_match_bible",
		"test_trust_deltas_match_bible",
		"test_multiplier_table_match_bible",
		"test_anam_rewards_match_bible",
		"test_reputation_system_constants_match",
		"test_card_type_weights_match_bible",
		"test_maturity_weights_match_bible",
		"test_save_profile_has_all_fields",
		"test_save_run_state_has_critical_fields",
		"test_in_game_periods_match_bible",
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
	print("[BibleAlignment] %d/%d passed (%d failed)" % [passed, total, failed])
	for f in failures:
		print("  FAIL: %s" % f)
	return {"passed": passed, "failed": failed, "total": total, "failures": failures}
