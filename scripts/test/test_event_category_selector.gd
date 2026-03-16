## =============================================================================
## Tests — EventCategorySelector
## =============================================================================
## Covers: weighted selection, anti-repetition, sub-type selection, pity system,
## modifier system, history management, matrix conditions, trigger evaluation,
## debug/query helpers, and edge cases.
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error before false.
## =============================================================================

extends RefCounted


# =============================================================================
# HELPERS
# =============================================================================

func _fail(msg: String) -> bool:
	push_error(msg)
	return false


func _make_selector() -> EventCategorySelector:
	## Create an EventCategorySelector with fully injected state.
	## Bypasses file I/O so tests run headless without res:// data files.
	var sel: EventCategorySelector = EventCategorySelector.new()
	sel._categories = {
		"narrative": {
			"label": "Narrative",
			"base_weight": 0.4,
			"narrator_guidance": "Tell a story",
			"effect_profile": {"healing": 0.3},
			"sub_types": {
				"dialogue": {"weight": 0.5, "triggers": {}},
				"lore":     {"weight": 0.3, "triggers": {"min_cards_played": 5}},
				"mystery":  {"weight": 0.2, "triggers": {"biome": ["foret", "marais"]}},
			},
		},
		"combat": {
			"label": "Combat",
			"base_weight": 0.3,
			"narrator_guidance": "Fight scene",
			"effect_profile": {"damage": 0.5},
			"sub_types": {
				"duel":   {"weight": 0.6, "triggers": {}},
				"ambush": {"weight": 0.4, "triggers": {"tension_above": 60}},
			},
		},
		"exploration": {
			"label": "Exploration",
			"base_weight": 0.2,
			"narrator_guidance": "Discover something",
			"effect_profile": {},
			"sub_types": {
				"discovery": {"weight": 0.5, "triggers": {}},
				"puzzle":    {"weight": 0.5, "triggers": {}},
			},
		},
		"faction": {
			"label": "Faction",
			"base_weight": 0.1,
			"narrator_guidance": "Faction event",
			"effect_profile": {},
			"sub_types": {
				"alliance": {"weight": 0.5, "triggers": {"dominant_faction_above": 60}},
				"betrayal": {"weight": 0.5, "triggers": {"karma_above": 20}},
			},
		},
	}
	sel._frequency_matrix = {}
	sel._pity_system = {}
	sel._anti_repetition = {
		"min_gap_same_category": 2,
		"max_consecutive_same_category": 2,
		"min_gap_same_subtype": 4,
		"history_window": 10,
	}
	sel._is_loaded = true
	return sel


func _make_run(overrides: Dictionary = {}) -> Dictionary:
	var run: Dictionary = {
		"cards_played": 5,
		"life_essence": 50,
		"current_biome": "foret",
		"faction_rep_delta": {},
		"factions": {"druides": 30, "anciens": 20, "korrigans": 15, "niamh": 10, "ankou": 10},
		"flags": {},
		"hidden": {"tension": 40, "karma": 0},
	}
	for key in overrides:
		run[key] = overrides[key]
	return run


func _make_game_state(run_overrides: Dictionary = {}) -> Dictionary:
	return {"run": _make_run(run_overrides)}


func _init() -> void:
	pass


# =============================================================================
# 1. LOADING / is_loaded
# =============================================================================

func test_is_loaded_true_after_injection() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if not sel.is_loaded():
		return _fail("is_loaded() should return true after state injection")
	return true


func test_is_loaded_false_when_cleared() -> bool:
	var sel: EventCategorySelector = EventCategorySelector.new()
	sel._categories = {}
	sel._is_loaded = false
	if sel.is_loaded():
		return _fail("is_loaded() should return false when _is_loaded=false")
	return true


func test_select_event_empty_when_not_loaded() -> bool:
	var sel: EventCategorySelector = EventCategorySelector.new()
	sel._categories = {}
	sel._is_loaded = false
	var result: Dictionary = sel.select_event({"run": {}})
	if not result.is_empty():
		return _fail("select_event should return {} when not loaded")
	return true


# =============================================================================
# 2. WEIGHT COMPUTATION — base weights
# =============================================================================

func test_base_weights_match_config() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var weights: Dictionary = sel._compute_category_weights(_make_run())
	var w_narr: float = float(weights.get("narrative", -1.0))
	if absf(w_narr - 0.4) > 0.001:
		return _fail("narrative base_weight: expected 0.400, got %.4f" % w_narr)
	var w_comb: float = float(weights.get("combat", -1.0))
	if absf(w_comb - 0.3) > 0.001:
		return _fail("combat base_weight: expected 0.300, got %.4f" % w_comb)
	return true


func test_base_weights_all_categories_present() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var weights: Dictionary = sel._compute_category_weights(_make_run())
	for cat in ["narrative", "combat", "exploration", "faction"]:
		if not weights.has(cat):
			return _fail("_compute_category_weights missing key '%s'" % cat)
	return true


# =============================================================================
# 3. FREQUENCY MATRIX
# =============================================================================

func test_matrix_multiplier_applied_when_condition_met() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._frequency_matrix = {
		"early_game": {
			"condition": {"cards_played_max": 10},
			"multipliers": {"narrative": 2.0, "combat": 0.5},
		},
	}
	var weights: Dictionary = sel._compute_category_weights(_make_run({"cards_played": 3}))
	var w_narr: float = float(weights.get("narrative", 0.0))
	if absf(w_narr - 0.8) > 0.001:
		return _fail("narrative with 2x multiplier: expected 0.800, got %.4f" % w_narr)
	var w_comb: float = float(weights.get("combat", 0.0))
	if absf(w_comb - 0.15) > 0.001:
		return _fail("combat with 0.5x multiplier: expected 0.150, got %.4f" % w_comb)
	return true


func test_matrix_multiplier_not_applied_when_condition_not_met() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._frequency_matrix = {
		"late_game": {
			"condition": {"cards_played_min": 15},
			"multipliers": {"faction": 3.0},
		},
	}
	var weights: Dictionary = sel._compute_category_weights(_make_run({"cards_played": 5}))
	var w: float = float(weights.get("faction", 0.0))
	if absf(w - 0.1) > 0.001:
		return _fail("faction at cards=5 < min=15: expected 0.100, got %.4f" % w)
	return true


func test_multiple_matrix_states_combine_multiplicatively() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._frequency_matrix = {
		"state_a": {"condition": {"cards_played_max": 20}, "multipliers": {"narrative": 2.0}},
		"state_b": {"condition": {"cards_played_max": 20}, "multipliers": {"narrative": 3.0}},
	}
	var weights: Dictionary = sel._compute_category_weights(_make_run({"cards_played": 5}))
	var w: float = float(weights.get("narrative", 0.0))
	if absf(w - 2.4) > 0.01:
		return _fail("2x * 3x matrix: expected 2.400, got %.4f" % w)
	return true


func test_matrix_meta_key_is_skipped() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._frequency_matrix = {
		"_meta": {"version": "1.0"},
		"boost": {"condition": {"cards_played_max": 100}, "multipliers": {"combat": 2.0}},
	}
	var weights: Dictionary = sel._compute_category_weights(_make_run())
	var w: float = float(weights.get("combat", 0.0))
	if w <= 0.3:
		return _fail("_meta key should be skipped; boost multiplier should apply, got %.4f" % w)
	return true


# =============================================================================
# 4. PITY SYSTEM
# =============================================================================

func test_pity_life_below_activates() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._pity_system = {
		"low_life": {
			"condition": {"life_below": 20},
			"overrides": {"narrative": 3.0},
		},
	}
	var w_pity: Dictionary = sel._compute_category_weights(_make_run({"life_essence": 10}))
	var w: float = float(w_pity.get("narrative", 0.0))
	if absf(w - 1.2) > 0.01:
		return _fail("pity life_below=20 with life=10: expected 1.200, got %.4f" % w)
	return true


func test_pity_life_below_does_not_activate_above_threshold() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._pity_system = {
		"low_life": {
			"condition": {"life_below": 20},
			"overrides": {"narrative": 3.0},
		},
	}
	var w_normal: Dictionary = sel._compute_category_weights(_make_run({"life_essence": 50}))
	var w: float = float(w_normal.get("narrative", 0.0))
	if absf(w - 0.4) > 0.001:
		return _fail("pity should not activate at life=50, got %.4f" % w)
	return true


func test_pity_life_above_activates() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._pity_system = {
		"high_life": {
			"condition": {"life_above": 80},
			"overrides": {"combat": 2.0},
		},
	}
	var w_pity: Dictionary = sel._compute_category_weights(_make_run({"life_essence": 90}))
	var w: float = float(w_pity.get("combat", 0.0))
	if absf(w - 0.6) > 0.01:
		return _fail("pity life_above=80 with life=90: expected 0.600, got %.4f" % w)
	return true


func test_pity_equilibre_condition_activates() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._pity_system = {
		"balanced": {
			"condition": {"all_aspects": "EQUILIBRE"},
			"overrides": {"exploration": 2.5},
		},
	}
	var run_eq: Dictionary = _make_run({"faction_rep_delta": {"druides": 2.0, "anciens": -3.0}})
	var w_eq: Dictionary = sel._compute_category_weights(run_eq)
	var w: float = float(w_eq.get("exploration", 0.0))
	if absf(w - 0.5) > 0.01:
		return _fail("EQUILIBRE pity: expected 0.500, got %.4f" % w)
	return true


func test_pity_equilibre_condition_does_not_activate_when_not_balanced() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._pity_system = {
		"balanced": {
			"condition": {"all_aspects": "EQUILIBRE"},
			"overrides": {"exploration": 2.5},
		},
	}
	var run_neq: Dictionary = _make_run({"faction_rep_delta": {"druides": 10.0}})
	var w_neq: Dictionary = sel._compute_category_weights(run_neq)
	var w: float = float(w_neq.get("exploration", 0.0))
	if absf(w - 0.2) > 0.01:
		return _fail("non-EQUILIBRE: expected 0.200, got %.4f" % w)
	return true


# =============================================================================
# 5. ANTI-REPETITION
# =============================================================================

func test_anti_rep_penalizes_recent_category() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	var weights: Dictionary = sel._compute_category_weights(_make_run())
	weights = sel._apply_anti_repetition(weights)
	var w: float = float(weights.get("narrative", 0.0))
	var expected: float = 0.4 * 0.1
	if absf(w - expected) > 0.001:
		return _fail("anti-rep gap=0 penalty: expected %.4f, got %.4f" % [expected, w])
	return true


func test_anti_rep_no_penalty_at_min_gap() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	sel.record_selection("combat", "duel", 2)
	sel.record_selection("exploration", "discovery", 3)
	# narrative gap = 2, min_gap_same_category = 2 => no penalty
	var weights: Dictionary = sel._compute_category_weights(_make_run())
	weights = sel._apply_anti_repetition(weights)
	var w: float = float(weights.get("narrative", 0.0))
	if absf(w - 0.4) > 0.001:
		return _fail("no penalty at gap==min_gap: expected 0.400, got %.4f" % w)
	return true


func test_anti_rep_consecutive_penalty() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("combat", "duel", 1)
	sel.record_selection("combat", "ambush", 2)
	# consecutive=2 >= max_consecutive=2 => *0.05; gap=0 => *0.1
	var weights: Dictionary = sel._compute_category_weights(_make_run())
	weights = sel._apply_anti_repetition(weights)
	var w: float = float(weights.get("combat", 0.0))
	var expected: float = 0.3 * 0.1 * 0.05
	if absf(w - expected) > 0.0001:
		return _fail("consecutive penalty: expected %.5f, got %.5f" % [expected, w])
	return true


func test_anti_rep_does_not_mutate_input() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	var original: Dictionary = {"narrative": 1.0, "combat": 1.0}
	var _result: Dictionary = sel._apply_anti_repetition(original)
	if original["narrative"] != 1.0:
		return _fail("_apply_anti_repetition must not mutate the input dictionary")
	return true


# =============================================================================
# 6. HISTORY MANAGEMENT
# =============================================================================

func test_record_selection_adds_entry() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	var hist: Array[Dictionary] = sel.get_history()
	if hist.size() != 1:
		return _fail("expected 1 history entry, got %d" % hist.size())
	if str(hist[0].get("category", "")) != "narrative":
		return _fail("history entry category mismatch")
	if str(hist[0].get("sub_type", "")) != "dialogue":
		return _fail("history entry sub_type mismatch")
	if int(hist[0].get("card_num", -1)) != 1:
		return _fail("history entry card_num mismatch")
	return true


func test_history_window_trims_to_max() -> bool:
	var sel: EventCategorySelector = _make_selector()
	# window = 10
	for i in range(15):
		sel.record_selection("cat_%d" % i, "sub", i)
	var hist: Array[Dictionary] = sel.get_history()
	if hist.size() != 10:
		return _fail("history should trim to window=10, got %d" % hist.size())
	# After trimming, index 0 should be cat_5
	if str(hist[0].get("category", "")) != "cat_5":
		return _fail("oldest retained entry should be cat_5, got '%s'" % str(hist[0].get("category", "")))
	return true


func test_clear_history_empties() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	sel.record_selection("combat", "duel", 2)
	sel.clear_history()
	if sel.get_history().size() != 0:
		return _fail("clear_history() should empty history")
	return true


func test_get_history_returns_duplicate() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	var h1: Array[Dictionary] = sel.get_history()
	h1.clear()
	if sel.get_history().size() == 0:
		return _fail("get_history() must return a copy, not a reference")
	return true


# =============================================================================
# 7. _cards_since_last_category / _cards_since_last_subtype
# =============================================================================

func test_cards_since_last_category_never_used() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._cards_since_last_category("narrative") != -1:
		return _fail("never-used category should return -1")
	return true


func test_cards_since_last_category_just_used() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	if sel._cards_since_last_category("narrative") != 0:
		return _fail("gap should be 0 immediately after recording")
	return true


func test_cards_since_last_category_two_later() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	sel.record_selection("combat", "duel", 2)
	sel.record_selection("exploration", "discovery", 3)
	if sel._cards_since_last_category("narrative") != 2:
		return _fail("gap for narrative should be 2 after two subsequent entries")
	return true


func test_cards_since_last_subtype_never_used() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._cards_since_last_subtype("dialogue") != -1:
		return _fail("never-used sub_type should return -1")
	return true


func test_cards_since_last_subtype_correct_gap() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	sel.record_selection("narrative", "lore", 2)
	sel.record_selection("combat", "duel", 3)
	# dialogue at index 0, size=3, gap = 2
	if sel._cards_since_last_subtype("dialogue") != 2:
		return _fail("dialogue sub_type gap should be 2, got %d" % sel._cards_since_last_subtype("dialogue"))
	return true


# =============================================================================
# 8. _count_consecutive
# =============================================================================

func test_count_consecutive_zero_on_empty() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._count_consecutive("combat") != 0:
		return _fail("empty history should give consecutive=0")
	return true


func test_count_consecutive_three_in_a_row() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("exploration", "discovery", 1)
	sel.record_selection("combat", "duel", 2)
	sel.record_selection("combat", "ambush", 3)
	sel.record_selection("combat", "duel", 4)
	if sel._count_consecutive("combat") != 3:
		return _fail("consecutive combat should be 3, got %d" % sel._count_consecutive("combat"))
	return true


func test_count_consecutive_breaks_on_different() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("combat", "duel", 1)
	sel.record_selection("narrative", "dialogue", 2)
	sel.record_selection("combat", "ambush", 3)
	if sel._count_consecutive("combat") != 1:
		return _fail("chain broken by narrative; expected 1, got %d" % sel._count_consecutive("combat"))
	return true


# =============================================================================
# 9. _faction_delta_to_state
# =============================================================================

func test_faction_delta_equilibre_at_zero() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._faction_delta_to_state(0.0) != "EQUILIBRE":
		return _fail("delta=0 should be EQUILIBRE")
	return true


func test_faction_delta_equilibre_at_boundary_plus5() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._faction_delta_to_state(5.0) != "EQUILIBRE":
		return _fail("delta=5.0 (boundary) should be EQUILIBRE")
	return true


func test_faction_delta_equilibre_at_boundary_minus5() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._faction_delta_to_state(-5.0) != "EQUILIBRE":
		return _fail("delta=-5.0 (boundary) should be EQUILIBRE")
	return true


func test_faction_delta_haut() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._faction_delta_to_state(10.0) != "HAUT":
		return _fail("delta=10 should be HAUT")
	return true


func test_faction_delta_bas() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._faction_delta_to_state(-10.0) != "BAS":
		return _fail("delta=-10 should be BAS")
	return true


func test_faction_delta_just_above_5_is_haut() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._faction_delta_to_state(5.01) != "HAUT":
		return _fail("delta=5.01 should be HAUT")
	return true


# =============================================================================
# 10. MATRIX CONDITION CHECKS
# =============================================================================

func test_matrix_condition_empty_always_true() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if not sel._check_matrix_condition({}, 5, {}):
		return _fail("empty condition should always return true")
	return true


func test_matrix_condition_cards_max_pass() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if not sel._check_matrix_condition({"cards_played_max": 10}, 5, {}):
		return _fail("cards=5 <= max=10 should pass")
	return true


func test_matrix_condition_cards_max_fail() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._check_matrix_condition({"cards_played_max": 5}, 6, {}):
		return _fail("cards=6 > max=5 should fail")
	return true


func test_matrix_condition_cards_min_pass() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if not sel._check_matrix_condition({"cards_played_min": 5}, 10, {}):
		return _fail("cards=10 >= min=5 should pass")
	return true


func test_matrix_condition_cards_min_fail() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._check_matrix_condition({"cards_played_min": 10}, 5, {}):
		return _fail("cards=5 < min=10 should fail")
	return true


func test_matrix_condition_equilibre_passes() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var cond: Dictionary = {"all_aspects": "EQUILIBRE"}
	var delta: Dictionary = {"druides": 3.0, "anciens": -2.0}
	if not sel._check_matrix_condition(cond, 0, delta):
		return _fail("all deltas <=5 should satisfy EQUILIBRE")
	return true


func test_matrix_condition_equilibre_fails_on_extreme() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var cond: Dictionary = {"all_aspects": "EQUILIBRE"}
	var delta: Dictionary = {"druides": 10.0}
	if sel._check_matrix_condition(cond, 0, delta):
		return _fail("delta=10 should break EQUILIBRE")
	return true


func test_matrix_condition_any_aspect_haut_passes() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var cond: Dictionary = {"any_aspect": ["HAUT"]}
	var delta: Dictionary = {"druides": 20.0}
	if not sel._check_matrix_condition(cond, 0, delta):
		return _fail("delta=20 should satisfy any_aspect=[HAUT]")
	return true


func test_matrix_condition_any_aspect_not_found_fails() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var cond: Dictionary = {"any_aspect": ["BAS"]}
	var delta: Dictionary = {"druides": 3.0}  # EQUILIBRE
	if sel._check_matrix_condition(cond, 0, delta):
		return _fail("EQUILIBRE delta should not satisfy any_aspect=[BAS]")
	return true


# =============================================================================
# 11. TRIGGER EVALUATION
# =============================================================================

func test_trigger_empty_returns_1() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var bonus: float = sel._evaluate_triggers({}, {}, 0, 100, "foret", {}, 40, 0)
	if absf(bonus - 1.0) > 0.001:
		return _fail("empty triggers should give bonus=1.0, got %.4f" % bonus)
	return true


func test_trigger_biome_match_boosts() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var bonus: float = sel._evaluate_triggers({"biome": ["foret", "marais"]}, {}, 5, 50, "foret", {}, 40, 0)
	if absf(bonus - 2.0) > 0.001:
		return _fail("matching biome should give bonus=2.0, got %.4f" % bonus)
	return true


func test_trigger_biome_mismatch_penalizes() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var bonus: float = sel._evaluate_triggers({"biome": ["foret"]}, {}, 5, 50, "montagne", {}, 40, 0)
	if absf(bonus - 0.5) > 0.001:
		return _fail("mismatching biome should give bonus=0.5, got %.4f" % bonus)
	return true


func test_trigger_min_cards_blocks_when_below() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var bonus: float = sel._evaluate_triggers({"min_cards_played": 10}, {}, 3, 100, "", {}, 40, 0)
	if absf(bonus) > 0.001:
		return _fail("cards=3 < min=10 should block (bonus=0), got %.4f" % bonus)
	return true


func test_trigger_tension_above_boosts() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var bonus: float = sel._evaluate_triggers({"tension_above": 60}, {}, 0, 100, "", {}, 80, 0)
	if absf(bonus - 1.5) > 0.001:
		return _fail("tension=80 >= 60 should give bonus=1.5, got %.4f" % bonus)
	return true


func test_trigger_tension_above_penalizes_when_below() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var bonus: float = sel._evaluate_triggers({"tension_above": 60}, {}, 0, 100, "", {}, 40, 0)
	if absf(bonus - 0.5) > 0.001:
		return _fail("tension=40 < 60 should give bonus=0.5, got %.4f" % bonus)
	return true


func test_trigger_life_below_boosts() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var bonus: float = sel._evaluate_triggers({"life_below": 30}, {}, 0, 20, "", {}, 40, 0)
	if absf(bonus - 1.5) > 0.001:
		return _fail("life=20 < 30 should give bonus=1.5, got %.4f" % bonus)
	return true


func test_trigger_karma_above_boosts() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var bonus: float = sel._evaluate_triggers({"karma_above": 50}, {}, 0, 100, "", {}, 40, 70)
	if absf(bonus - 1.5) > 0.001:
		return _fail("karma=70 >= 50 should give bonus=1.5, got %.4f" % bonus)
	return true


func test_trigger_dominant_faction_above_boosts() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var factions: Dictionary = {"druides": 70, "anciens": 20}
	var bonus: float = sel._evaluate_triggers({"dominant_faction_above": 60}, {}, 0, 100, "", {}, 40, 0, factions)
	if absf(bonus - 1.5) > 0.001:
		return _fail("max_rep=70 >= 60 should give bonus=1.5, got %.4f" % bonus)
	return true


func test_trigger_flags_required_all_present_no_penalty() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var flags: Dictionary = {"quest_started": true, "npc_met": true}
	var bonus: float = sel._evaluate_triggers({"flags_required": ["quest_started", "npc_met"]}, {}, 0, 100, "", flags, 40, 0)
	if absf(bonus - 1.0) > 0.001:
		return _fail("all flags present should give bonus=1.0, got %.4f" % bonus)
	return true


func test_trigger_flags_required_missing_penalizes() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var flags: Dictionary = {"quest_started": true}  # npc_met absent
	var bonus: float = sel._evaluate_triggers({"flags_required": ["quest_started", "npc_met"]}, {}, 0, 100, "", flags, 40, 0)
	if absf(bonus - 0.1) > 0.001:
		return _fail("missing flag should give bonus=0.1, got %.4f" % bonus)
	return true


# =============================================================================
# 12. _weighted_select
# =============================================================================

func test_weighted_select_single_entry() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._weighted_select({"only": 1.0}) != "only":
		return _fail("single entry should always be selected")
	return true


func test_weighted_select_empty_dict_returns_empty_string() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._weighted_select({}) != "":
		return _fail("empty dict should return ''")
	return true


func test_weighted_select_zero_total_fallback_to_first_key() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var result: String = sel._weighted_select({"alpha": 0.0, "beta": 0.0})
	if result != "alpha":
		return _fail("zero-total weights should fallback to first key 'alpha', got '%s'" % result)
	return true


func test_weighted_select_heavy_dominates() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var wins: int = 0
	for _i in range(100):
		if sel._weighted_select({"heavy": 10000.0, "light": 0.0001}) == "heavy":
			wins += 1
	if wins < 95:
		return _fail("heavy entry should win 95+/100 times, won %d" % wins)
	return true


# =============================================================================
# 13. SELECT EVENT — integration
# =============================================================================

func test_select_event_returns_required_keys() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var result: Dictionary = sel.select_event(_make_game_state())
	for key in ["category", "sub_type", "label", "narrator_guidance", "effect_profile"]:
		if not result.has(key):
			return _fail("select_event result missing key '%s'" % key)
	return true


func test_select_event_category_in_known_set() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var known: Array[String] = sel.get_all_categories()
	for _i in range(20):
		var result: Dictionary = sel.select_event(_make_game_state())
		if result.is_empty():
			continue
		var cat: String = str(result["category"])
		if cat not in known:
			return _fail("select_event returned unknown category '%s'" % cat)
	return true


func test_select_event_sub_type_belongs_to_category() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var result: Dictionary = sel.select_event(_make_game_state())
	var cat: Dictionary = sel._categories.get(str(result["category"]), {})
	var subs: Dictionary = cat.get("sub_types", {})
	if not subs.has(result["sub_type"]):
		return _fail("sub_type '%s' not found in category '%s'" % [result["sub_type"], result["category"]])
	return true


# =============================================================================
# 14. DEBUG / QUERY
# =============================================================================

func test_get_all_categories_size_and_content() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var cats: Array[String] = sel.get_all_categories()
	if cats.size() != 4:
		return _fail("expected 4 categories, got %d" % cats.size())
	for expected in ["narrative", "combat", "exploration", "faction"]:
		if expected not in cats:
			return _fail("get_all_categories missing '%s'" % expected)
	return true


func test_get_sub_types_correct_content() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var subs: Array[String] = sel.get_sub_types("narrative")
	if subs.size() != 3:
		return _fail("narrative should have 3 sub_types, got %d" % subs.size())
	if "dialogue" not in subs:
		return _fail("missing 'dialogue' sub_type")
	return true


func test_get_sub_types_empty_for_unknown() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel.get_sub_types("ghost_category").size() != 0:
		return _fail("unknown category should return empty sub_types")
	return true


func test_get_category_info_returns_data() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var info: Dictionary = sel.get_category_info("narrative")
	if info.is_empty():
		return _fail("get_category_info('narrative') should not be empty")
	if str(info.get("label", "")) != "Narrative":
		return _fail("label should be 'Narrative', got '%s'" % str(info.get("label", "")))
	return true


func test_get_category_info_empty_for_unknown() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if not sel.get_category_info("nonexistent").is_empty():
		return _fail("unknown category should return empty dict")
	return true


func test_get_debug_weights_empty_when_not_loaded() -> bool:
	var sel: EventCategorySelector = EventCategorySelector.new()
	sel._is_loaded = false
	if not sel.get_debug_weights({"run": {}}).is_empty():
		return _fail("get_debug_weights should return {} when not loaded")
	return true


func test_get_debug_weights_contains_all_categories() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var dw: Dictionary = sel.get_debug_weights(_make_game_state())
	for cat in ["narrative", "combat", "exploration", "faction"]:
		if not dw.has(cat):
			return _fail("get_debug_weights missing category '%s'" % cat)
	return true


# =============================================================================
# 15. MODIFIER SYSTEM
# =============================================================================

func test_modifier_gap_never_used_returns_minus1() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._modifier_gap("storm") != -1:
		return _fail("never-used modifier should return -1")
	return true


func test_modifier_gap_immediately_after_record() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_modifier("storm")
	if sel._modifier_gap("storm") != 0:
		return _fail("gap should be 0 immediately after recording")
	return true


func test_modifier_gap_increases_with_entries() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_modifier("storm")
	sel.record_modifier("calm")
	sel.record_modifier("fog")
	if sel._modifier_gap("storm") != 2:
		return _fail("gap should be 2 after 2 subsequent entries, got %d" % sel._modifier_gap("storm"))
	return true


func test_record_modifier_trims_to_20() -> bool:
	var sel: EventCategorySelector = _make_selector()
	for i in range(25):
		sel.record_modifier("mod_%d" % i)
	if sel._modifier_history.size() != 20:
		return _fail("modifier history should trim to 20, got %d" % sel._modifier_history.size())
	return true


func test_select_modifier_returns_empty_when_not_loaded() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._modifiers_loaded = false
	if not sel.select_modifier(_make_game_state(), "narrative").is_empty():
		return _fail("select_modifier should return {} when modifiers not loaded")
	return true


func test_select_modifier_skips_anchor_card() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._modifiers_loaded = true
	sel._modifier_rules = {
		"scenario_anchor_never_modified": true,
		"max_consecutive_modified": 3,
		"min_gap_same_modifier": 5,
	}
	sel._modifiers = {
		"storm": {
			"probability": 1.0,
			"category_exclusions": [],
			"trigger": {},
			"label": "Storm",
			"prompt_injection": "",
			"effect_modifier": {},
			"minigame_pool": [],
		}
	}
	var state: Dictionary = _make_game_state({"current_card_is_anchor": true})
	if not sel.select_modifier(state, "narrative").is_empty():
		return _fail("anchor card should never receive a modifier")
	return true


func test_check_modifier_trigger_empty_returns_true() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if not sel._check_modifier_trigger({}, _make_run()):
		return _fail("empty trigger should always return true")
	return true


func test_check_modifier_trigger_dominant_faction_passes() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var trigger: Dictionary = {"dominant_faction_above": 50}
	var run: Dictionary = _make_run({"factions": {"druides": 70, "anciens": 20}})
	if not sel._check_modifier_trigger(trigger, run):
		return _fail("dominant faction 70 >= 50 should pass")
	return true


func test_check_modifier_trigger_dominant_faction_fails() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var trigger: Dictionary = {"dominant_faction_above": 50}
	var run: Dictionary = _make_run({"factions": {"druides": 30, "anciens": 20}})
	if sel._check_modifier_trigger(trigger, run):
		return _fail("dominant faction 30 < 50 should fail")
	return true


func test_check_modifier_trigger_cards_played_min_passes() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if not sel._check_modifier_trigger({"cards_played_min": 10}, _make_run({"cards_played": 15})):
		return _fail("cards=15 >= min=10 should pass")
	return true


func test_check_modifier_trigger_cards_played_min_fails() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if sel._check_modifier_trigger({"cards_played_min": 10}, _make_run({"cards_played": 5})):
		return _fail("cards=5 < min=10 should fail")
	return true
