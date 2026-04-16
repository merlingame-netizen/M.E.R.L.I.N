## =============================================================================
## Unit Tests — StoreRun
## =============================================================================
## Tests: init_run, generate_mission, progress_mission, resolve_choice,
## update_player_profile, check_run_end, get_victory_type, handle_run_end,
## check_promise_deadlines, calculate_run_rewards, calculate_maturity_score,
## can_unlock_biome, get_unlockable_biomes, init_calendar_context.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


func _make_state(overrides: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"run": {
			"active": false,
			"life_essence": MerlinConstants.LIFE_ESSENCE_START,
			"anam": 0,
			"mission": {},
			"cards_played": 0,
			"day": 1,
			"story_log": [],
			"active_tags": [],
			"active_promises": [],
			"current_biome": "",
			"biome_passive_counter": 0,
			"hidden": {
				"karma": 0,
				"tension": 0,
				"player_profile": {"audace": 0, "prudence": 0, "altruisme": 0, "egoisme": 0},
				"resonances_active": [],
				"narrative_debt": [],
			},
			"power_bonuses": {},
		},
		"meta": {
			"total_runs": 0,
			"total_cards_played": 0,
			"endings_seen": [],
			"anam": 0,
			"faction_rep": {},
			"oghams": {"owned": []},
			"stats": {},
			"biome_runs": {},
		},
	}
	for key in overrides:
		state[key] = overrides[key]
	return state


func _make_run_state(run_overrides: Dictionary) -> Dictionary:
	var state: Dictionary = _make_state()
	var run: Dictionary = state["run"]
	for key in run_overrides:
		run[key] = run_overrides[key]
	state["run"] = run
	return state


func _make_rng(seed_val: int = 42) -> MerlinRng:
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(seed_val)
	return rng


func _noop_effect(_effect: Dictionary) -> void:
	pass


func _collect_effects(collector: Array) -> Callable:
	return func(effect: Dictionary) -> void:
		collector.append(effect)


# =============================================================================
# GENERATE_MISSION
# =============================================================================

func test_generate_mission_returns_valid_structure() -> bool:
	var rng: MerlinRng = _make_rng(1)
	var mission: Dictionary = StoreRun.generate_mission(rng)
	var expected_keys: Array = ["type", "target", "description", "progress", "total", "revealed"]
	for key in expected_keys:
		if not mission.has(key):
			push_error("generate_mission: missing key '%s'" % key)
			return false
	return true


func test_generate_mission_progress_starts_at_zero() -> bool:
	var rng: MerlinRng = _make_rng(10)
	var mission: Dictionary = StoreRun.generate_mission(rng)
	if int(mission["progress"]) != 0:
		push_error("generate_mission: progress should be 0, got %d" % int(mission["progress"]))
		return false
	return true


func test_generate_mission_not_revealed() -> bool:
	var rng: MerlinRng = _make_rng(20)
	var mission: Dictionary = StoreRun.generate_mission(rng)
	if bool(mission["revealed"]) != false:
		push_error("generate_mission: revealed should be false")
		return false
	return true


func test_generate_mission_type_is_known_template() -> bool:
	var rng: MerlinRng = _make_rng(30)
	var mission: Dictionary = StoreRun.generate_mission(rng)
	var templates: Dictionary = MerlinConstants.MISSION_TEMPLATES
	if not templates.has(str(mission["type"])):
		push_error("generate_mission: type '%s' not in MISSION_TEMPLATES" % str(mission["type"]))
		return false
	return true


func test_generate_mission_total_is_positive() -> bool:
	var rng: MerlinRng = _make_rng(50)
	var mission: Dictionary = StoreRun.generate_mission(rng)
	if int(mission["total"]) <= 0:
		push_error("generate_mission: total should be > 0, got %d" % int(mission["total"]))
		return false
	return true


func test_generate_mission_deterministic_with_same_seed() -> bool:
	var rng_a: MerlinRng = _make_rng(99)
	var rng_b: MerlinRng = _make_rng(99)
	var mission_a: Dictionary = StoreRun.generate_mission(rng_a)
	var mission_b: Dictionary = StoreRun.generate_mission(rng_b)
	if str(mission_a["type"]) != str(mission_b["type"]):
		push_error("generate_mission: same seed should produce same type")
		return false
	if int(mission_a["total"]) != int(mission_b["total"]):
		push_error("generate_mission: same seed should produce same total")
		return false
	return true


# =============================================================================
# PROGRESS_MISSION
# =============================================================================

func test_progress_mission_increments() -> bool:
	var state: Dictionary = _make_run_state({"mission": {"progress": 0, "total": 10}})
	var result: Dictionary = StoreRun.progress_mission(state, 3)
	if int(result["progress"]) != 3:
		push_error("progress_mission: expected 3, got %d" % int(result["progress"]))
		return false
	if bool(result["complete"]):
		push_error("progress_mission: should not be complete at 3/10")
		return false
	return true


func test_progress_mission_clamps_at_total() -> bool:
	var state: Dictionary = _make_run_state({"mission": {"progress": 8, "total": 10}})
	var result: Dictionary = StoreRun.progress_mission(state, 5)
	if int(result["progress"]) != 10:
		push_error("progress_mission: expected clamped at 10, got %d" % int(result["progress"]))
		return false
	if not bool(result["complete"]):
		push_error("progress_mission: should be complete at 10/10")
		return false
	return true


func test_progress_mission_already_complete() -> bool:
	var state: Dictionary = _make_run_state({"mission": {"progress": 10, "total": 10}})
	var result: Dictionary = StoreRun.progress_mission(state, 1)
	if int(result["progress"]) != 10:
		push_error("progress_mission: should stay at 10, got %d" % int(result["progress"]))
		return false
	if not bool(result["complete"]):
		push_error("progress_mission: should still be complete")
		return false
	return true


func test_progress_mission_zero_step() -> bool:
	var state: Dictionary = _make_run_state({"mission": {"progress": 5, "total": 10}})
	var result: Dictionary = StoreRun.progress_mission(state, 0)
	if int(result["progress"]) != 5:
		push_error("progress_mission: zero step should keep progress at 5, got %d" % int(result["progress"]))
		return false
	return true


func test_progress_mission_updates_state() -> bool:
	var state: Dictionary = _make_run_state({"mission": {"progress": 2, "total": 10}})
	StoreRun.progress_mission(state, 4)
	var updated_progress: int = int(state["run"]["mission"]["progress"])
	if updated_progress != 6:
		push_error("progress_mission: state should reflect 6, got %d" % updated_progress)
		return false
	return true


# =============================================================================
# UPDATE_PLAYER_PROFILE
# =============================================================================

func test_update_player_profile_left_increments_prudence() -> bool:
	var state: Dictionary = _make_state()
	StoreRun.update_player_profile(state, MerlinConstants.CardOption.LEFT)
	var profile: Dictionary = state["run"]["hidden"]["player_profile"]
	if int(profile["prudence"]) != 1:
		push_error("LEFT should increment prudence to 1, got %d" % int(profile["prudence"]))
		return false
	if int(profile["audace"]) != 0:
		push_error("LEFT should not change audace, got %d" % int(profile["audace"]))
		return false
	return true


func test_update_player_profile_right_increments_audace() -> bool:
	var state: Dictionary = _make_state()
	StoreRun.update_player_profile(state, MerlinConstants.CardOption.RIGHT)
	var profile: Dictionary = state["run"]["hidden"]["player_profile"]
	if int(profile["audace"]) != 1:
		push_error("RIGHT should increment audace to 1, got %d" % int(profile["audace"]))
		return false
	if int(profile["prudence"]) != 0:
		push_error("RIGHT should not change prudence, got %d" % int(profile["prudence"]))
		return false
	return true


func test_update_player_profile_center_no_change() -> bool:
	var state: Dictionary = _make_state()
	StoreRun.update_player_profile(state, MerlinConstants.CardOption.CENTER)
	var profile: Dictionary = state["run"]["hidden"]["player_profile"]
	if int(profile["prudence"]) != 0 or int(profile["audace"]) != 0:
		push_error("CENTER should not change any profile value")
		return false
	return true


func test_update_player_profile_accumulates() -> bool:
	var state: Dictionary = _make_state()
	StoreRun.update_player_profile(state, MerlinConstants.CardOption.LEFT)
	StoreRun.update_player_profile(state, MerlinConstants.CardOption.LEFT)
	StoreRun.update_player_profile(state, MerlinConstants.CardOption.RIGHT)
	var profile: Dictionary = state["run"]["hidden"]["player_profile"]
	if int(profile["prudence"]) != 2:
		push_error("Two LEFTs should give prudence=2, got %d" % int(profile["prudence"]))
		return false
	if int(profile["audace"]) != 1:
		push_error("One RIGHT should give audace=1, got %d" % int(profile["audace"]))
		return false
	return true


# =============================================================================
# GET_VICTORY_TYPE
# =============================================================================

func test_victory_type_harmonie() -> bool:
	var state: Dictionary = _make_state()
	state["run"]["hidden"]["karma"] = 5
	var result: String = StoreRun.get_victory_type(state)
	if result != "harmonie":
		push_error("karma=5 should give harmonie, got '%s'" % result)
		return false
	return true


func test_victory_type_harmonie_high_karma() -> bool:
	var state: Dictionary = _make_state()
	state["run"]["hidden"]["karma"] = 20
	var result: String = StoreRun.get_victory_type(state)
	if result != "harmonie":
		push_error("karma=20 should give harmonie, got '%s'" % result)
		return false
	return true


func test_victory_type_victoire_amere() -> bool:
	var state: Dictionary = _make_state()
	state["run"]["hidden"]["karma"] = -5
	var result: String = StoreRun.get_victory_type(state)
	if result != "victoire_amere":
		push_error("karma=-5 should give victoire_amere, got '%s'" % result)
		return false
	return true


func test_victory_type_prix_paye_zero() -> bool:
	var state: Dictionary = _make_state()
	state["run"]["hidden"]["karma"] = 0
	var result: String = StoreRun.get_victory_type(state)
	if result != "prix_paye":
		push_error("karma=0 should give prix_paye, got '%s'" % result)
		return false
	return true


func test_victory_type_prix_paye_boundary() -> bool:
	var state: Dictionary = _make_state()
	state["run"]["hidden"]["karma"] = 4
	var result: String = StoreRun.get_victory_type(state)
	if result != "prix_paye":
		push_error("karma=4 should give prix_paye, got '%s'" % result)
		return false
	state["run"]["hidden"]["karma"] = -4
	result = StoreRun.get_victory_type(state)
	if result != "prix_paye":
		push_error("karma=-4 should give prix_paye, got '%s'" % result)
		return false
	return true


# =============================================================================
# CHECK_RUN_END — Life depletion
# =============================================================================

func test_check_run_end_life_zero_ends_run() -> bool:
	var state: Dictionary = _make_run_state({"life_essence": 0, "cards_played": 5, "day": 3})
	var result: Dictionary = StoreRun.check_run_end(state)
	if not bool(result["ended"]):
		push_error("life=0 should end run")
		return false
	if not result.has("life_depleted"):
		push_error("life=0 should have life_depleted flag")
		return false
	return true


func test_check_run_end_life_negative_ends_run() -> bool:
	var state: Dictionary = _make_run_state({"life_essence": -10, "cards_played": 2, "day": 1})
	var result: Dictionary = StoreRun.check_run_end(state)
	if not bool(result["ended"]):
		push_error("life=-10 should end run")
		return false
	return true


func test_check_run_end_life_positive_continues() -> bool:
	var state: Dictionary = _make_run_state({"life_essence": 50, "cards_played": 5, "mission": {"progress": 0, "total": 10}})
	var result: Dictionary = StoreRun.check_run_end(state)
	if bool(result["ended"]):
		push_error("life=50 should not end run")
		return false
	return true


# =============================================================================
# CHECK_RUN_END — Victory
# =============================================================================

func test_check_run_end_victory_mission_complete() -> bool:
	var state: Dictionary = _make_run_state({
		"life_essence": 50,
		"cards_played": MerlinConstants.MIN_CARDS_FOR_VICTORY,
		"mission": {"progress": 10, "total": 10},
		"hidden": {"karma": 5, "tension": 0, "player_profile": {}, "resonances_active": [], "narrative_debt": []},
	})
	var result: Dictionary = StoreRun.check_run_end(state)
	if not bool(result["ended"]):
		push_error("mission complete + enough cards should end run")
		return false
	if not result.has("victory"):
		push_error("should have victory flag")
		return false
	return true


func test_check_run_end_no_victory_insufficient_cards() -> bool:
	var state: Dictionary = _make_run_state({
		"life_essence": 50,
		"cards_played": MerlinConstants.MIN_CARDS_FOR_VICTORY - 1,
		"mission": {"progress": 10, "total": 10},
	})
	var result: Dictionary = StoreRun.check_run_end(state)
	if bool(result["ended"]):
		push_error("mission complete but not enough cards should NOT end run")
		return false
	return true


# =============================================================================
# CHECK_RUN_END — Hard max / MOS zones
# =============================================================================

func test_check_run_end_hard_max() -> bool:
	var hard_max: int = int(MerlinConstants.MOS_CONVERGENCE.get("hard_max_cards", 50))
	var state: Dictionary = _make_run_state({
		"life_essence": 50,
		"cards_played": hard_max,
		"mission": {"progress": 0, "total": 10},
	})
	var result: Dictionary = StoreRun.check_run_end(state)
	if not bool(result["ended"]):
		push_error("hard_max cards should end run")
		return false
	if not result.has("hard_max"):
		push_error("should have hard_max flag")
		return false
	return true


func test_check_run_end_tension_zone_none() -> bool:
	var state: Dictionary = _make_run_state({
		"life_essence": 80,
		"cards_played": 3,
		"mission": {"progress": 0, "total": 10},
	})
	var result: Dictionary = StoreRun.check_run_end(state)
	if bool(result["ended"]):
		push_error("3 cards should not end run")
		return false
	if str(result["tension_zone"]) != "none":
		push_error("3 cards should be tension_zone=none, got '%s'" % str(result["tension_zone"]))
		return false
	return true


func test_check_run_end_tension_zone_low() -> bool:
	var soft_min: int = int(MerlinConstants.MOS_CONVERGENCE.get("soft_min_cards", 8))
	var state: Dictionary = _make_run_state({
		"life_essence": 80,
		"cards_played": soft_min,
		"mission": {"progress": 0, "total": 10},
	})
	var result: Dictionary = StoreRun.check_run_end(state)
	if str(result["tension_zone"]) != "low":
		push_error("soft_min cards should be tension_zone=low, got '%s'" % str(result["tension_zone"]))
		return false
	if not bool(result["early_zone"]):
		push_error("soft_min cards should be early_zone=true")
		return false
	return true


func test_check_run_end_tension_zone_rising() -> bool:
	var target_min: int = int(MerlinConstants.MOS_CONVERGENCE.get("target_cards_min", 20))
	var state: Dictionary = _make_run_state({
		"life_essence": 80,
		"cards_played": target_min,
		"mission": {"progress": 0, "total": 10},
	})
	var result: Dictionary = StoreRun.check_run_end(state)
	if str(result["tension_zone"]) != "rising":
		push_error("target_min cards should be tension_zone=rising, got '%s'" % str(result["tension_zone"]))
		return false
	if not bool(result["convergence_zone"]):
		push_error("target_min should set convergence_zone=true")
		return false
	return true


func test_check_run_end_tension_zone_critical() -> bool:
	var soft_max: int = int(MerlinConstants.MOS_CONVERGENCE.get("soft_max_cards", 40))
	var state: Dictionary = _make_run_state({
		"life_essence": 80,
		"cards_played": soft_max,
		"mission": {"progress": 0, "total": 10},
	})
	var result: Dictionary = StoreRun.check_run_end(state)
	if str(result["tension_zone"]) != "critical":
		push_error("soft_max cards should be tension_zone=critical, got '%s'" % str(result["tension_zone"]))
		return false
	return true


# =============================================================================
# CHECK_PROMISE_DEADLINES
# =============================================================================

func test_promise_deadline_not_reached() -> bool:
	var effects: Array = []
	var state: Dictionary = _make_run_state({
		"day": 3,
		"active_promises": [{"status": "active", "deadline_day": 5}],
	})
	StoreRun.check_promise_deadlines(state, _collect_effects(effects))
	if effects.size() > 0:
		push_error("promise with deadline=5 on day=3 should not trigger effects")
		return false
	var promise: Dictionary = state["run"]["active_promises"][0]
	if str(promise["status"]) != "active":
		push_error("promise should remain active")
		return false
	return true


func test_promise_deadline_exceeded_breaks_promise() -> bool:
	var effects: Array = []
	var state: Dictionary = _make_run_state({
		"day": 6,
		"active_promises": [{"status": "active", "deadline_day": 5}],
	})
	StoreRun.check_promise_deadlines(state, _collect_effects(effects))
	var promise: Dictionary = state["run"]["active_promises"][0]
	if str(promise["status"]) != "broken":
		push_error("promise past deadline should be broken, got '%s'" % str(promise["status"]))
		return false
	if effects.size() != 2:
		push_error("broken promise should produce 2 effects (karma + tension), got %d" % effects.size())
		return false
	return true


func test_promise_deadline_multiple_broken() -> bool:
	var effects: Array = []
	var state: Dictionary = _make_run_state({
		"day": 10,
		"active_promises": [
			{"status": "active", "deadline_day": 5},
			{"status": "active", "deadline_day": 8},
			{"status": "completed", "deadline_day": 3},
		],
	})
	StoreRun.check_promise_deadlines(state, _collect_effects(effects))
	# 2 active promises broken, each produces 2 effects = 4 total
	if effects.size() != 4:
		push_error("2 broken promises should produce 4 effects, got %d" % effects.size())
		return false
	return true


func test_promise_deadline_zero_ignored() -> bool:
	var effects: Array = []
	var state: Dictionary = _make_run_state({
		"day": 5,
		"active_promises": [{"status": "active", "deadline_day": 0}],
	})
	StoreRun.check_promise_deadlines(state, _collect_effects(effects))
	if effects.size() > 0:
		push_error("promise with deadline_day=0 should be ignored")
		return false
	return true


# =============================================================================
# CALCULATE_RUN_REWARDS
# =============================================================================

func test_rewards_base_anam() -> bool:
	var state: Dictionary = _make_state()
	var run_data: Dictionary = {"victory": true, "cards_played": 10, "minigames_won": 0, "oghams_used": 0}
	var rewards: Dictionary = StoreRun.calculate_run_rewards(state, run_data)
	var expected: int = MerlinConstants.ANAM_BASE_REWARD + MerlinConstants.ANAM_VICTORY_BONUS
	if int(rewards["anam"]) != expected:
		push_error("victory rewards: expected %d, got %d" % [expected, int(rewards["anam"])])
		return false
	return true


func test_rewards_minigames_and_oghams() -> bool:
	var state: Dictionary = _make_state()
	var run_data: Dictionary = {"victory": true, "cards_played": 10, "minigames_won": 5, "oghams_used": 3}
	var rewards: Dictionary = StoreRun.calculate_run_rewards(state, run_data)
	var expected: int = MerlinConstants.ANAM_BASE_REWARD + MerlinConstants.ANAM_VICTORY_BONUS
	expected += 5 * MerlinConstants.ANAM_PER_MINIGAME
	expected += 3 * MerlinConstants.ANAM_PER_OGHAM
	if int(rewards["anam"]) != expected:
		push_error("rewards with minigames+oghams: expected %d, got %d" % [expected, int(rewards["anam"])])
		return false
	return true


func test_rewards_faction_honored_bonus() -> bool:
	var state: Dictionary = _make_state()
	state["meta"]["faction_rep"] = {"druides": 80.0, "anciens": 50.0}
	var run_data: Dictionary = {"victory": true, "cards_played": 10, "minigames_won": 0, "oghams_used": 0}
	var rewards: Dictionary = StoreRun.calculate_run_rewards(state, run_data)
	var expected: int = MerlinConstants.ANAM_BASE_REWARD + MerlinConstants.ANAM_VICTORY_BONUS + MerlinConstants.ANAM_FACTION_HONORE
	if int(rewards["anam"]) != expected:
		push_error("faction honored (1 at 80): expected %d, got %d" % [expected, int(rewards["anam"])])
		return false
	return true


func test_rewards_death_cap_ratio() -> bool:
	var state: Dictionary = _make_state()
	var death_cap: int = int(MerlinConstants.ANAM_REWARDS.get("death_cap_cards", 30))
	# Death at 15 cards = ratio 0.5
	var run_data: Dictionary = {"victory": false, "cards_played": 15, "minigames_won": 0, "oghams_used": 0}
	var rewards: Dictionary = StoreRun.calculate_run_rewards(state, run_data)
	var base_anam: int = MerlinConstants.ANAM_BASE_REWARD
	var expected: int = int(float(base_anam) * (15.0 / float(death_cap)))
	if int(rewards["anam"]) != expected:
		push_error("death cap ratio: expected %d, got %d" % [expected, int(rewards["anam"])])
		return false
	return true


func test_rewards_death_full_cards_cap_at_one() -> bool:
	var state: Dictionary = _make_state()
	var death_cap: int = int(MerlinConstants.ANAM_REWARDS.get("death_cap_cards", 30))
	# Death at death_cap+10 cards = ratio capped at 1.0
	var run_data: Dictionary = {"victory": false, "cards_played": death_cap + 10, "minigames_won": 0, "oghams_used": 0}
	var rewards: Dictionary = StoreRun.calculate_run_rewards(state, run_data)
	var expected: int = MerlinConstants.ANAM_BASE_REWARD
	if int(rewards["anam"]) != expected:
		push_error("death cap at 1.0: expected %d, got %d" % [expected, int(rewards["anam"])])
		return false
	return true


func test_rewards_never_negative() -> bool:
	var state: Dictionary = _make_state()
	var run_data: Dictionary = {"victory": false, "cards_played": 0, "minigames_won": 0, "oghams_used": 0}
	var rewards: Dictionary = StoreRun.calculate_run_rewards(state, run_data)
	if int(rewards["anam"]) < 0:
		push_error("rewards should never be negative, got %d" % int(rewards["anam"]))
		return false
	return true


# =============================================================================
# CALCULATE_MATURITY_SCORE
# =============================================================================

func test_maturity_score_empty_state() -> bool:
	var state: Dictionary = _make_state()
	var score: int = StoreRun.calculate_maturity_score(state)
	if score != 0:
		push_error("empty state maturity score should be 0, got %d" % score)
		return false
	return true


func test_maturity_score_with_runs() -> bool:
	var state: Dictionary = _make_state()
	state["meta"]["total_runs"] = 5
	var expected: int = 5 * int(MerlinConstants.MATURITY_WEIGHTS.get("total_runs", 2))
	var score: int = StoreRun.calculate_maturity_score(state)
	if score != expected:
		push_error("5 runs maturity: expected %d, got %d" % [expected, score])
		return false
	return true


func test_maturity_score_with_endings() -> bool:
	var state: Dictionary = _make_state()
	state["meta"]["endings_seen"] = ["Harmonie", "Victoire Amere"]
	var expected: int = 2 * int(MerlinConstants.MATURITY_WEIGHTS.get("fins_vues", 5))
	var score: int = StoreRun.calculate_maturity_score(state)
	if score != expected:
		push_error("2 endings maturity: expected %d, got %d" % [expected, score])
		return false
	return true


func test_maturity_score_with_oghams() -> bool:
	var state: Dictionary = _make_state()
	state["meta"]["oghams"] = {"owned": ["beith", "luis", "nuin"]}
	var expected: int = 3 * int(MerlinConstants.MATURITY_WEIGHTS.get("oghams_debloques", 3))
	var score: int = StoreRun.calculate_maturity_score(state)
	if score != expected:
		push_error("3 oghams maturity: expected %d, got %d" % [expected, score])
		return false
	return true


func test_maturity_score_with_faction_rep() -> bool:
	var state: Dictionary = _make_state()
	state["meta"]["faction_rep"] = {"druides": 60.0, "ankou": 30.0}
	var expected: int = 60 * int(MerlinConstants.MATURITY_WEIGHTS.get("max_faction_rep", 1))
	var score: int = StoreRun.calculate_maturity_score(state)
	if score != expected:
		push_error("faction rep maturity: expected %d, got %d" % [expected, score])
		return false
	return true


func test_maturity_score_combined() -> bool:
	var state: Dictionary = _make_state()
	state["meta"]["total_runs"] = 3
	state["meta"]["endings_seen"] = ["A"]
	state["meta"]["oghams"] = {"owned": ["beith", "luis"]}
	state["meta"]["faction_rep"] = {"druides": 40.0}
	var w: Dictionary = MerlinConstants.MATURITY_WEIGHTS
	var expected: int = 3 * int(w["total_runs"]) + 1 * int(w["fins_vues"]) + 2 * int(w["oghams_debloques"]) + 40 * int(w["max_faction_rep"])
	var score: int = StoreRun.calculate_maturity_score(state)
	if score != expected:
		push_error("combined maturity: expected %d, got %d" % [expected, score])
		return false
	return true


# =============================================================================
# CAN_UNLOCK_BIOME / GET_UNLOCKABLE_BIOMES
# =============================================================================

func test_can_unlock_biome_starter() -> bool:
	var state: Dictionary = _make_state()
	# foret_broceliande threshold = 0, maturity score = 0
	var can: bool = StoreRun.can_unlock_biome(state, "foret_broceliande")
	if not can:
		push_error("foret_broceliande (threshold=0) should be unlockable with score=0")
		return false
	return true


func test_can_unlock_biome_insufficient_score() -> bool:
	var state: Dictionary = _make_state()
	# iles_mystiques threshold = 75, maturity score = 0
	var can: bool = StoreRun.can_unlock_biome(state, "iles_mystiques")
	if can:
		push_error("iles_mystiques (threshold=75) should NOT be unlockable with score=0")
		return false
	return true


func test_can_unlock_biome_unknown_biome() -> bool:
	var state: Dictionary = _make_state()
	# Unknown biome defaults to threshold 999
	var can: bool = StoreRun.can_unlock_biome(state, "nonexistent_biome")
	if can:
		push_error("unknown biome should NOT be unlockable (threshold=999)")
		return false
	return true


func test_get_unlockable_biomes_starter_only() -> bool:
	var state: Dictionary = _make_state()
	var biomes: Array = StoreRun.get_unlockable_biomes(state)
	if not biomes.has("foret_broceliande"):
		push_error("foret_broceliande should be unlockable at score=0")
		return false
	if biomes.has("iles_mystiques"):
		push_error("iles_mystiques should NOT be unlockable at score=0")
		return false
	return true


func test_get_unlockable_biomes_high_maturity() -> bool:
	var state: Dictionary = _make_state()
	# Set high enough maturity to unlock everything (75+ needed for iles_mystiques)
	state["meta"]["total_runs"] = 20
	state["meta"]["endings_seen"] = ["A", "B", "C"]
	state["meta"]["oghams"] = {"owned": ["a", "b", "c", "d", "e"]}
	state["meta"]["faction_rep"] = {"druides": 80.0}
	var score: int = StoreRun.calculate_maturity_score(state)
	if score < 75:
		push_error("test setup: maturity score %d is too low, need >= 75" % score)
		return false
	var biomes: Array = StoreRun.get_unlockable_biomes(state)
	var all_biomes: Array = MerlinConstants.BIOME_MATURITY_THRESHOLDS.keys()
	for biome_id in all_biomes:
		if not biomes.has(biome_id):
			push_error("all biomes should be unlockable at score=%d, missing '%s'" % [score, biome_id])
			return false
	return true


# =============================================================================
# CHECK_RUN_END — Score calculation
# =============================================================================

func test_check_run_end_death_score() -> bool:
	var state: Dictionary = _make_run_state({"life_essence": 0, "cards_played": 7, "day": 2})
	var result: Dictionary = StoreRun.check_run_end(state)
	if int(result["score"]) != 70:
		push_error("death score: expected 7*10=70, got %d" % int(result["score"]))
		return false
	return true


func test_check_run_end_victory_score() -> bool:
	var state: Dictionary = _make_run_state({
		"life_essence": 50,
		"cards_played": MerlinConstants.MIN_CARDS_FOR_VICTORY,
		"mission": {"progress": 10, "total": 10},
		"hidden": {"karma": 5, "tension": 0, "player_profile": {}, "resonances_active": [], "narrative_debt": []},
	})
	var result: Dictionary = StoreRun.check_run_end(state)
	var expected_score: int = MerlinConstants.MIN_CARDS_FOR_VICTORY * 20
	if int(result["score"]) != expected_score:
		push_error("victory score: expected %d, got %d" % [expected_score, int(result["score"])])
		return false
	return true


# =============================================================================
# CHECK_RUN_END — Faction Endings (T-GDC-FACTION-ENDING-INTEGRATION)
# =============================================================================

func test_check_run_end_faction_ending_at_rep_80() -> bool:
	## Faction with rep >= 80 must appear in faction_endings_available.
	var state: Dictionary = _make_state()
	state["run"]["life_essence"] = 0
	state["run"]["cards_played"] = 5
	state["meta"]["faction_rep"] = {"druides": 80.0, "anciens": 40.0, "korrigans": 0.0, "niamh": 0.0, "ankou": 0.0}
	var result: Dictionary = StoreRun.check_run_end(state)
	if not result.has("faction_endings_available"):
		push_error("faction_ending_rep80: result missing faction_endings_available key")
		return false
	var endings: Array = result["faction_endings_available"]
	if not endings.has("druides"):
		push_error("faction_ending_rep80: druides at 80.0 should be in faction_endings_available, got %s" % str(endings))
		return false
	if endings.has("anciens"):
		push_error("faction_ending_rep80: anciens at 40.0 should NOT be in faction_endings_available")
		return false
	return true


func test_check_run_end_faction_ending_rep79_excluded() -> bool:
	## Faction at rep 79 must NOT appear in faction_endings_available.
	var state: Dictionary = _make_state()
	state["run"]["life_essence"] = 0
	state["run"]["cards_played"] = 5
	state["meta"]["faction_rep"] = {"druides": 79.0, "anciens": 0.0, "korrigans": 0.0, "niamh": 0.0, "ankou": 0.0}
	var result: Dictionary = StoreRun.check_run_end(state)
	var endings: Array = result.get("faction_endings_available", [])
	if endings.has("druides"):
		push_error("faction_ending_rep79: druides at 79.0 should NOT be in faction_endings_available")
		return false
	return true


func test_check_run_end_faction_ending_two_factions() -> bool:
	## Two factions >= 80 must both appear (player gets choice UI).
	var state: Dictionary = _make_state()
	state["run"]["life_essence"] = 0
	state["run"]["cards_played"] = 5
	state["meta"]["faction_rep"] = {"druides": 85.0, "anciens": 90.0, "korrigans": 20.0, "niamh": 0.0, "ankou": 0.0}
	var result: Dictionary = StoreRun.check_run_end(state)
	var endings: Array = result.get("faction_endings_available", [])
	if not endings.has("druides") or not endings.has("anciens"):
		push_error("faction_ending_two: both druides(85) and anciens(90) should be in endings, got %s" % str(endings))
		return false
	if endings.has("korrigans"):
		push_error("faction_ending_two: korrigans(20) should NOT be in endings")
		return false
	return true


func test_check_run_end_faction_ending_empty_rep() -> bool:
	## No faction_rep set → faction_endings_available should be empty array.
	var state: Dictionary = _make_state()
	state["run"]["life_essence"] = 0
	state["run"]["cards_played"] = 5
	# faction_rep not set in meta
	var result: Dictionary = StoreRun.check_run_end(state)
	var endings: Array = result.get("faction_endings_available", [])
	if not endings.is_empty():
		push_error("faction_ending_empty: empty faction_rep should yield empty endings, got %s" % str(endings))
		return false
	return true


func test_check_run_end_faction_ending_present_in_victory() -> bool:
	## faction_endings_available must be present on victory path too (bible s.3.8).
	var state: Dictionary = _make_run_state({
		"life_essence": 50,
		"cards_played": MerlinConstants.MIN_CARDS_FOR_VICTORY,
		"mission": {"progress": 10, "total": 10},
		"hidden": {"karma": 5, "tension": 0, "player_profile": {}, "resonances_active": [], "narrative_debt": []},
	})
	state["meta"]["faction_rep"] = {"druides": 80.0}
	var result: Dictionary = StoreRun.check_run_end(state)
	if not result.has("faction_endings_available"):
		push_error("faction_ending_victory: faction_endings_available missing from victory result")
		return false
	var endings: Array = result["faction_endings_available"]
	if not endings.has("druides"):
		push_error("faction_ending_victory: druides(80) missing from endings on victory path")
		return false
	return true
