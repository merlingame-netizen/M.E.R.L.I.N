## =============================================================================
## Unit Tests — StoreFactions
## =============================================================================
## Tests: faction_score_to_tier, build_and_store_faction_context, trust,
## periods, biome affinity, apply_faction_run_bonuses, edge cases.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


func _make_state(overrides: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"meta": {"faction_rep": {}, "trust_merlin": 0},
		"run": {"life_essence": 50},
	}
	for key in overrides:
		if key == "meta" or key == "run":
			var section: Dictionary = state[key]
			var ovr: Dictionary = overrides[key]
			for k in ovr:
				section[k] = ovr[k]
		else:
			state[key] = overrides[key]
	return state


func _make_state_with_reps(reps: Dictionary) -> Dictionary:
	return _make_state({"meta": {"faction_rep": reps}})


## All factions at neutral (20) so only the tested faction triggers bonuses.
func _neutral_reps() -> Dictionary:
	return {"druides": 20, "anciens": 20, "korrigans": 20, "niamh": 20, "ankou": 20}


# =============================================================================
# FACTION SCORE TO TIER
# =============================================================================

func test_tier_hostile_at_zero() -> bool:
	var tier: String = StoreFactions.faction_score_to_tier(0)
	if tier != "hostile":
		push_error("Tier at 0: expected 'hostile', got '%s'" % tier)
		return false
	return true


func test_tier_hostile_at_4() -> bool:
	var tier: String = StoreFactions.faction_score_to_tier(4)
	if tier != "hostile":
		push_error("Tier at 4: expected 'hostile', got '%s'" % tier)
		return false
	return true


func test_tier_mefiant_at_5() -> bool:
	var tier: String = StoreFactions.faction_score_to_tier(5)
	if tier != "mefiant":
		push_error("Tier at 5: expected 'mefiant', got '%s'" % tier)
		return false
	return true


func test_tier_neutre_at_20() -> bool:
	var tier: String = StoreFactions.faction_score_to_tier(20)
	if tier != "neutre":
		push_error("Tier at 20: expected 'neutre', got '%s'" % tier)
		return false
	return true


func test_tier_sympathisant_at_50() -> bool:
	var tier: String = StoreFactions.faction_score_to_tier(50)
	if tier != "sympathisant":
		push_error("Tier at 50: expected 'sympathisant', got '%s'" % tier)
		return false
	return true


func test_tier_honore_at_80() -> bool:
	var tier: String = StoreFactions.faction_score_to_tier(80)
	if tier != "honore":
		push_error("Tier at 80: expected 'honore', got '%s'" % tier)
		return false
	return true


func test_tier_honore_at_100() -> bool:
	var tier: String = StoreFactions.faction_score_to_tier(100)
	if tier != "honore":
		push_error("Tier at 100: expected 'honore', got '%s'" % tier)
		return false
	return true


# =============================================================================
# BUILD AND STORE FACTION CONTEXT
# =============================================================================

func test_context_keys_present() -> bool:
	var state: Dictionary = _make_state()
	StoreFactions.build_and_store_faction_context(state)
	var ctx: Dictionary = state["run"].get("faction_context", {})
	var expected_keys: Array = ["dominant", "tiers", "active_effects"]
	for key in expected_keys:
		if not ctx.has(key):
			push_error("faction_context: missing key '%s'" % key)
			return false
	return true


func test_context_dominant_is_highest() -> bool:
	var state: Dictionary = _make_state_with_reps({"druides": 60, "ankou": 30, "korrigans": 10})
	StoreFactions.build_and_store_faction_context(state)
	var ctx: Dictionary = state["run"]["faction_context"]
	if str(ctx["dominant"]) != "druides":
		push_error("Dominant: expected 'druides', got '%s'" % str(ctx["dominant"]))
		return false
	return true


func test_context_tiers_computed() -> bool:
	var state: Dictionary = _make_state_with_reps({"druides": 85, "anciens": 55, "korrigans": 25, "niamh": 8, "ankou": 2})
	StoreFactions.build_and_store_faction_context(state)
	var tiers: Dictionary = state["run"]["faction_context"]["tiers"]
	var expected: Dictionary = {"druides": "honore", "anciens": "sympathisant", "korrigans": "neutre", "niamh": "mefiant", "ankou": "hostile"}
	for faction in expected:
		if str(tiers.get(faction, "")) != expected[faction]:
			push_error("Tier for %s: expected '%s', got '%s'" % [faction, expected[faction], str(tiers.get(faction, ""))])
			return false
	return true


func test_context_active_effects_excludes_neutre() -> bool:
	var state: Dictionary = _make_state_with_reps({"druides": 25, "anciens": 80})
	StoreFactions.build_and_store_faction_context(state)
	var effects: Array = state["run"]["faction_context"]["active_effects"]
	for effect in effects:
		if str(effect["faction"]) == "druides":
			push_error("active_effects should not contain 'druides' (tier=neutre)")
			return false
	# anciens at 80 = honore, should be present
	var found_anciens: bool = false
	for effect in effects:
		if str(effect["faction"]) == "anciens":
			found_anciens = true
	if not found_anciens:
		push_error("active_effects should contain 'anciens' (tier=honore)")
		return false
	return true


func test_context_all_zero_dominant_empty() -> bool:
	var state: Dictionary = _make_state()
	StoreFactions.build_and_store_faction_context(state)
	var ctx: Dictionary = state["run"]["faction_context"]
	if str(ctx["dominant"]) != "":
		push_error("Dominant with all 0: expected '', got '%s'" % str(ctx["dominant"]))
		return false
	return true


# =============================================================================
# UPDATE TRUST
# =============================================================================

func test_trust_positive_delta() -> bool:
	var state: Dictionary = _make_state({"meta": {"trust_merlin": 30}})
	var result: Dictionary = StoreFactions.update_trust(state, 10)
	if int(result["old"]) != 30:
		push_error("Trust old: expected 30, got %d" % int(result["old"]))
		return false
	if int(result["new"]) != 40:
		push_error("Trust new: expected 40, got %d" % int(result["new"]))
		return false
	return true


func test_trust_clamped_at_100() -> bool:
	var state: Dictionary = _make_state({"meta": {"trust_merlin": 95}})
	var result: Dictionary = StoreFactions.update_trust(state, 20)
	if int(result["new"]) != 100:
		push_error("Trust clamp max: expected 100, got %d" % int(result["new"]))
		return false
	return true


func test_trust_clamped_at_0() -> bool:
	var state: Dictionary = _make_state({"meta": {"trust_merlin": 5}})
	var result: Dictionary = StoreFactions.update_trust(state, -20)
	if int(result["new"]) != 0:
		push_error("Trust clamp min: expected 0, got %d" % int(result["new"]))
		return false
	return true


func test_trust_zero_delta_returns_empty() -> bool:
	var state: Dictionary = _make_state({"meta": {"trust_merlin": 50}})
	var result: Dictionary = StoreFactions.update_trust(state, 0)
	if not result.is_empty():
		push_error("Trust delta 0: expected empty dict, got %d keys" % result.size())
		return false
	return true


# =============================================================================
# GET TRUST TIER
# =============================================================================

func test_trust_tier_T0() -> bool:
	var state: Dictionary = _make_state({"meta": {"trust_merlin": 10}})
	var tier: String = StoreFactions.get_trust_tier(state)
	if tier != "T0":
		push_error("Trust tier at 10: expected 'T0', got '%s'" % tier)
		return false
	return true


func test_trust_tier_T3() -> bool:
	var state: Dictionary = _make_state({"meta": {"trust_merlin": 80}})
	var tier: String = StoreFactions.get_trust_tier(state)
	if tier != "T3":
		push_error("Trust tier at 80: expected 'T3', got '%s'" % tier)
		return false
	return true


# =============================================================================
# GET PERIOD
# =============================================================================

func test_period_aube() -> bool:
	var period: String = StoreFactions.get_period(3)
	if period != "aube":
		push_error("Period at card 3: expected 'aube', got '%s'" % period)
		return false
	return true


func test_period_nuit_default() -> bool:
	var period: String = StoreFactions.get_period(25)
	if period != "nuit":
		push_error("Period at card 25: expected 'nuit' (default), got '%s'" % period)
		return false
	return true


# =============================================================================
# GET PERIOD BONUS
# =============================================================================

func test_period_bonus_matching_faction() -> bool:
	# Card 3 = aube, factions = ["druides"], bonus = 0.10
	var bonus: float = StoreFactions.get_period_bonus(3, "druides")
	if absf(bonus - 0.10) > 0.001:
		push_error("Period bonus druides at aube: expected 0.10, got %.3f" % bonus)
		return false
	return true


func test_period_bonus_non_matching_faction() -> bool:
	# Card 3 = aube, factions = ["druides"] — ankou not in list
	var bonus: float = StoreFactions.get_period_bonus(3, "ankou")
	if absf(bonus) > 0.001:
		push_error("Period bonus ankou at aube: expected 0.0, got %.3f" % bonus)
		return false
	return true


# =============================================================================
# BIOME AFFINITY
# =============================================================================

func test_biome_affinity_matching_ogham() -> bool:
	# foret_broceliande has oghams_affinity: ["quert", "huath", "coll"]
	var result: Dictionary = StoreFactions.get_biome_affinity_bonus("foret_broceliande", "quert")
	if absf(float(result["score_bonus"]) - 0.10) > 0.001:
		push_error("Biome affinity match: expected score_bonus 0.10, got %.3f" % float(result["score_bonus"]))
		return false
	if int(result["cooldown_reduction"]) != 1:
		push_error("Biome affinity match: expected cooldown_reduction 1, got %d" % int(result["cooldown_reduction"]))
		return false
	return true


func test_biome_affinity_no_match() -> bool:
	var result: Dictionary = StoreFactions.get_biome_affinity_bonus("foret_broceliande", "straif")
	if absf(float(result["score_bonus"])) > 0.001:
		push_error("Biome affinity no match: expected score_bonus 0.0, got %.3f" % float(result["score_bonus"]))
		return false
	if int(result["cooldown_reduction"]) != 0:
		push_error("Biome affinity no match: expected cooldown_reduction 0, got %d" % int(result["cooldown_reduction"]))
		return false
	return true


func test_biome_affinity_unknown_biome() -> bool:
	var result: Dictionary = StoreFactions.get_biome_affinity_bonus("unknown_biome", "quert")
	if absf(float(result["score_bonus"])) > 0.001:
		push_error("Unknown biome: expected score_bonus 0.0, got %.3f" % float(result["score_bonus"]))
		return false
	return true


# =============================================================================
# FESTIVAL DETECTION
# =============================================================================

func test_festival_returns_dict_structure() -> bool:
	var result: Dictionary = StoreFactions.get_active_festival()
	if not result.has("active") or not result.has("id") or not result.has("faction"):
		push_error("festival: result missing required keys")
		return false
	return true


func test_all_festivals_defined_in_constants() -> bool:
	var expected: Array = ["imbolc", "beltane", "lughnasadh", "samhain"]
	for fest in expected:
		if not MerlinConstants.FESTIVALS.has(fest):
			push_error("festival: FESTIVALS missing '%s'" % fest)
			return false
		var f: Dictionary = MerlinConstants.FESTIVALS[fest]
		if str(f.get("faction", "")).is_empty():
			push_error("festival: '%s' missing faction" % fest)
			return false
		if int(f.get("rep_bonus", 0)) <= 0:
			push_error("festival: '%s' has no rep_bonus" % fest)
			return false
	return true


func test_festival_factions_are_valid() -> bool:
	for fest_id in MerlinConstants.FESTIVALS:
		var faction: String = str(MerlinConstants.FESTIVALS[fest_id].get("faction", ""))
		if not MerlinReputationSystem.is_valid_faction(faction):
			push_error("festival: '%s' has invalid faction '%s'" % [fest_id, faction])
			return false
	return true


# =============================================================================
# APPLY FACTION RUN BONUSES
# =============================================================================

func test_run_bonus_heal_druides_honore() -> bool:
	var state: Dictionary = _make_state({"run": {"life_essence": 50}})
	var reps: Dictionary = _neutral_reps()
	reps["druides"] = 85
	state["meta"]["faction_rep"] = reps
	StoreFactions.build_and_store_faction_context(state)
	StoreFactions.apply_faction_run_bonuses(state)
	# druides honore = HEAL_LIFE 15 → 50+15=65
	if int(state["run"]["life_essence"]) != 65:
		push_error("Druides honore heal: expected 65, got %d" % int(state["run"]["life_essence"]))
		return false
	return true


func test_run_bonus_damage_ankou_hostile() -> bool:
	var state: Dictionary = _make_state({"run": {"life_essence": 50}})
	var reps: Dictionary = _neutral_reps()
	reps["ankou"] = 0
	state["meta"]["faction_rep"] = reps
	StoreFactions.build_and_store_faction_context(state)
	StoreFactions.apply_faction_run_bonuses(state)
	# ankou hostile = DAMAGE_LIFE 15 → 50-15=35
	if int(state["run"]["life_essence"]) != 35:
		push_error("Ankou hostile damage: expected 35, got %d" % int(state["run"]["life_essence"]))
		return false
	return true


func test_run_bonus_life_clamped_at_max() -> bool:
	var state: Dictionary = _make_state({"run": {"life_essence": 95}})
	var reps: Dictionary = _neutral_reps()
	reps["druides"] = 85
	state["meta"]["faction_rep"] = reps
	StoreFactions.build_and_store_faction_context(state)
	StoreFactions.apply_faction_run_bonuses(state)
	# druides honore = HEAL_LIFE 15 → 95+15=110, clamped to 100
	if int(state["run"]["life_essence"]) != 100:
		push_error("Life clamp max: expected 100, got %d" % int(state["run"]["life_essence"]))
		return false
	return true


func test_run_bonus_life_clamped_at_zero() -> bool:
	var state: Dictionary = _make_state({"run": {"life_essence": 5}})
	var reps: Dictionary = _neutral_reps()
	reps["ankou"] = 0
	state["meta"]["faction_rep"] = reps
	StoreFactions.build_and_store_faction_context(state)
	StoreFactions.apply_faction_run_bonuses(state)
	# ankou hostile = DAMAGE_LIFE 15 → 5-15=-10, clamped to 0
	if int(state["run"]["life_essence"]) != 0:
		push_error("Life clamp min: expected 0, got %d" % int(state["run"]["life_essence"]))
		return false
	return true


func test_run_bonus_neutre_no_effect() -> bool:
	var state: Dictionary = _make_state({"run": {"life_essence": 50}})
	var reps: Dictionary = _neutral_reps()
	state["meta"]["faction_rep"] = reps
	StoreFactions.build_and_store_faction_context(state)
	StoreFactions.apply_faction_run_bonuses(state)
	# all factions neutre = no entry in FACTION_RUN_BONUSES → no effect
	if int(state["run"]["life_essence"]) != 50:
		push_error("Neutre no effect: expected 50, got %d" % int(state["run"]["life_essence"]))
		return false
	return true
