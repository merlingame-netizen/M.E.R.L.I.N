## =============================================================================
## Unit Tests — EventCategorySelector v2.0
## =============================================================================
## Tests: weight computation, anti-repetition, sub-type selection, pity system,
## modifier system, history management, matrix conditions, triggers.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


# =============================================================================
# HELPERS
# =============================================================================

func _make_selector() -> EventCategorySelector:
	## Create a selector and inject test data (bypass file loading).
	var sel: EventCategorySelector = EventCategorySelector.new()
	# Inject categories directly
	sel._categories = {
		"narrative": {
			"label": "Narrative",
			"base_weight": 0.4,
			"narrator_guidance": "Tell a story",
			"effect_profile": {"healing": 0.3},
			"sub_types": {
				"dialogue": {"weight": 0.5, "triggers": {}},
				"lore": {"weight": 0.3, "triggers": {"min_cards_played": 5}},
				"mystery": {"weight": 0.2, "triggers": {"biome": ["foret", "marais"]}},
			},
		},
		"combat": {
			"label": "Combat",
			"base_weight": 0.3,
			"narrator_guidance": "Fight scene",
			"effect_profile": {"damage": 0.5},
			"sub_types": {
				"duel": {"weight": 0.6, "triggers": {}},
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
				"puzzle": {"weight": 0.5, "triggers": {}},
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


# =============================================================================
# INITIALIZATION & LOADING
# =============================================================================

func test_is_loaded_returns_true_when_categories_set() -> bool:
	var sel: EventCategorySelector = _make_selector()
	if not sel.is_loaded():
		push_error("is_loaded should return true after injection")
		return false
	return true


func test_is_loaded_returns_false_when_empty() -> bool:
	var sel: EventCategorySelector = EventCategorySelector.new()
	# Force unloaded state (constructor auto-loads if config file exists on disk)
	sel._categories = {}
	sel._is_loaded = false
	if sel.is_loaded():
		push_error("is_loaded should return false when categories cleared")
		return false
	return true


func test_select_event_returns_empty_when_not_loaded() -> bool:
	var sel: EventCategorySelector = EventCategorySelector.new()
	sel._categories = {}
	sel._is_loaded = false
	var result: Dictionary = sel.select_event({"run": {}})
	if not result.is_empty():
		push_error("select_event should return empty dict when not loaded")
		return false
	return true


# =============================================================================
# WEIGHT COMPUTATION
# =============================================================================

func test_base_weights_match_config() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var weights: Dictionary = sel._compute_category_weights(_make_run())
	# Without matrix or pity, weights should equal base_weight
	var expected_narrative: float = 0.4
	var actual: float = float(weights.get("narrative", 0.0))
	if absf(actual - expected_narrative) > 0.001:
		push_error("narrative base weight: expected %.3f, got %.3f" % [expected_narrative, actual])
		return false
	var expected_combat: float = 0.3
	actual = float(weights.get("combat", 0.0))
	if absf(actual - expected_combat) > 0.001:
		push_error("combat base weight: expected %.3f, got %.3f" % [expected_combat, actual])
		return false
	return true


func test_matrix_multiplier_applied() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._frequency_matrix = {
		"early_game": {
			"condition": {"cards_played_max": 10},
			"multipliers": {"narrative": 2.0, "combat": 0.5},
		},
	}
	var run: Dictionary = _make_run({"cards_played": 3})
	var weights: Dictionary = sel._compute_category_weights(run)
	# narrative: 0.4 * 2.0 = 0.8
	var w_narr: float = float(weights.get("narrative", 0.0))
	if absf(w_narr - 0.8) > 0.001:
		push_error("matrix multiplier narrative: expected 0.8, got %.3f" % w_narr)
		return false
	# combat: 0.3 * 0.5 = 0.15
	var w_combat: float = float(weights.get("combat", 0.0))
	if absf(w_combat - 0.15) > 0.001:
		push_error("matrix multiplier combat: expected 0.15, got %.3f" % w_combat)
		return false
	return true


func test_matrix_condition_cards_played_min() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._frequency_matrix = {
		"late_game": {
			"condition": {"cards_played_min": 15},
			"multipliers": {"faction": 3.0},
		},
	}
	# cards_played=5 < 15 => condition not met => no multiplier
	var weights_early: Dictionary = sel._compute_category_weights(_make_run({"cards_played": 5}))
	var w_faction_early: float = float(weights_early.get("faction", 0.0))
	if absf(w_faction_early - 0.1) > 0.001:
		push_error("faction should be base 0.1 when condition not met, got %.3f" % w_faction_early)
		return false
	# cards_played=20 >= 15 => condition met => 0.1 * 3.0 = 0.3
	var weights_late: Dictionary = sel._compute_category_weights(_make_run({"cards_played": 20}))
	var w_faction_late: float = float(weights_late.get("faction", 0.0))
	if absf(w_faction_late - 0.3) > 0.001:
		push_error("faction should be 0.3 when condition met, got %.3f" % w_faction_late)
		return false
	return true


func test_multiple_matrix_states_multiply() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._frequency_matrix = {
		"state_a": {
			"condition": {"cards_played_max": 20},
			"multipliers": {"narrative": 2.0},
		},
		"state_b": {
			"condition": {"cards_played_max": 20},
			"multipliers": {"narrative": 3.0},
		},
	}
	var weights: Dictionary = sel._compute_category_weights(_make_run({"cards_played": 5}))
	# narrative: 0.4 * 2.0 * 3.0 = 2.4
	var w: float = float(weights.get("narrative", 0.0))
	if absf(w - 2.4) > 0.01:
		push_error("multiple matrix states should multiply: expected 2.4, got %.3f" % w)
		return false
	return true


# =============================================================================
# PITY SYSTEM
# =============================================================================

func test_pity_override_life_below() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._pity_system = {
		"low_life_heal": {
			"condition": {"life_below": 20},
			"overrides": {"narrative": 3.0},
		},
	}
	# life=50 >= 20 => no pity
	var w_normal: Dictionary = sel._compute_category_weights(_make_run({"life_essence": 50}))
	var normal_narr: float = float(w_normal.get("narrative", 0.0))
	if absf(normal_narr - 0.4) > 0.001:
		push_error("pity should not activate at life=50, got %.3f" % normal_narr)
		return false
	# life=10 < 20 => pity: 0.4 * 3.0 = 1.2
	var w_pity: Dictionary = sel._compute_category_weights(_make_run({"life_essence": 10}))
	var pity_narr: float = float(w_pity.get("narrative", 0.0))
	if absf(pity_narr - 1.2) > 0.01:
		push_error("pity should boost narrative to 1.2, got %.3f" % pity_narr)
		return false
	return true


func test_pity_override_life_above() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._pity_system = {
		"high_life_challenge": {
			"condition": {"life_above": 80},
			"overrides": {"combat": 2.0},
		},
	}
	# life=50 <= 80 => no pity
	var w_normal: Dictionary = sel._compute_category_weights(_make_run({"life_essence": 50}))
	var normal_combat: float = float(w_normal.get("combat", 0.0))
	if absf(normal_combat - 0.3) > 0.001:
		push_error("pity should not activate at life=50, got %.3f" % normal_combat)
		return false
	# life=90 > 80 => pity: 0.3 * 2.0 = 0.6
	var w_pity: Dictionary = sel._compute_category_weights(_make_run({"life_essence": 90}))
	var pity_combat: float = float(w_pity.get("combat", 0.0))
	if absf(pity_combat - 0.6) > 0.01:
		push_error("pity should boost combat to 0.6, got %.3f" % pity_combat)
		return false
	return true


func test_pity_equilibre_condition() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel._pity_system = {
		"balanced": {
			"condition": {"all_aspects": "EQUILIBRE"},
			"overrides": {"exploration": 2.5},
		},
	}
	# All deltas within +-5 => EQUILIBRE => pity activates
	var run_eq: Dictionary = _make_run({"faction_rep_delta": {"druides": 2.0, "anciens": -3.0}})
	var w_eq: Dictionary = sel._compute_category_weights(run_eq)
	var expl_eq: float = float(w_eq.get("exploration", 0.0))
	if absf(expl_eq - 0.5) > 0.01:  # 0.2 * 2.5
		push_error("EQUILIBRE pity: expected 0.5, got %.3f" % expl_eq)
		return false
	# One delta > 5 => not EQUILIBRE => no pity
	var run_neq: Dictionary = _make_run({"faction_rep_delta": {"druides": 10.0}})
	var w_neq: Dictionary = sel._compute_category_weights(run_neq)
	var expl_neq: float = float(w_neq.get("exploration", 0.0))
	if absf(expl_neq - 0.2) > 0.01:
		push_error("non-EQUILIBRE: expected 0.2, got %.3f" % expl_neq)
		return false
	return true


# =============================================================================
# ANTI-REPETITION
# =============================================================================

func test_anti_repetition_penalizes_recent_category() -> bool:
	var sel: EventCategorySelector = _make_selector()
	# Record "narrative" as most recent
	sel.record_selection("narrative", "dialogue", 1)
	var weights: Dictionary = sel._compute_category_weights(_make_run())
	weights = sel._apply_anti_repetition(weights)
	# Gap=0 < min_gap=2 => penalty *0.1
	var w: float = float(weights.get("narrative", 0.0))
	var expected: float = 0.4 * 0.1
	if absf(w - expected) > 0.001:
		push_error("anti-rep penalty: expected %.3f, got %.3f" % [expected, w])
		return false
	return true


func test_anti_repetition_no_penalty_after_gap() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	sel.record_selection("combat", "duel", 2)
	sel.record_selection("exploration", "discovery", 3)
	# Gap for narrative = 2, min_gap = 2 => no penalty
	var weights: Dictionary = sel._compute_category_weights(_make_run())
	weights = sel._apply_anti_repetition(weights)
	var w: float = float(weights.get("narrative", 0.0))
	if absf(w - 0.4) > 0.001:
		push_error("no penalty after gap: expected 0.4, got %.3f" % w)
		return false
	return true


func test_anti_repetition_consecutive_penalty() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("combat", "duel", 1)
	sel.record_selection("combat", "ambush", 2)
	# 2 consecutive "combat" >= max_consecutive=2 => *0.05
	var weights: Dictionary = sel._compute_category_weights(_make_run())
	weights = sel._apply_anti_repetition(weights)
	var w: float = float(weights.get("combat", 0.0))
	# Also gap=0 penalty (*0.1), combined: 0.3 * 0.1 * 0.05
	var expected: float = 0.3 * 0.1 * 0.05
	if absf(w - expected) > 0.001:
		push_error("consecutive penalty: expected %.5f, got %.5f" % [expected, w])
		return false
	return true


# =============================================================================
# HISTORY MANAGEMENT
# =============================================================================

func test_record_selection_adds_entry() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	var hist: Array[Dictionary] = sel.get_history()
	if hist.size() != 1:
		push_error("history size: expected 1, got %d" % hist.size())
		return false
	if str(hist[0].get("category", "")) != "narrative":
		push_error("history category mismatch")
		return false
	return true


func test_history_window_trims() -> bool:
	var sel: EventCategorySelector = _make_selector()
	# Window is 10
	for i in range(15):
		sel.record_selection("cat_%d" % i, "sub", i)
	var hist: Array[Dictionary] = sel.get_history()
	if hist.size() != 10:
		push_error("history should trim to window=10, got %d" % hist.size())
		return false
	# First entry should be cat_5 (0-4 trimmed)
	if str(hist[0].get("category", "")) != "cat_5":
		push_error("oldest entry should be cat_5, got %s" % str(hist[0].get("category", "")))
		return false
	return true


func test_clear_history() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	sel.record_selection("combat", "duel", 2)
	sel.clear_history()
	if sel.get_history().size() != 0:
		push_error("clear_history should empty history")
		return false
	return true


func test_cards_since_last_category_never_used() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var gap: int = sel._cards_since_last_category("narrative")
	if gap != -1:
		push_error("never used category should return -1, got %d" % gap)
		return false
	return true


func test_cards_since_last_category_used() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	sel.record_selection("combat", "duel", 2)
	# narrative at index 0, history size=2, gap = (2-1) - 0 = 1
	var gap: int = sel._cards_since_last_category("narrative")
	if gap != 1:
		push_error("gap for narrative: expected 1, got %d" % gap)
		return false
	return true


func test_cards_since_last_subtype() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("narrative", "dialogue", 1)
	sel.record_selection("narrative", "lore", 2)
	sel.record_selection("combat", "duel", 3)
	# dialogue at index 0, size=3, gap = 2
	var gap: int = sel._cards_since_last_subtype("dialogue")
	if gap != 2:
		push_error("subtype gap: expected 2, got %d" % gap)
		return false
	return true


func test_count_consecutive() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("exploration", "discovery", 1)
	sel.record_selection("combat", "duel", 2)
	sel.record_selection("combat", "ambush", 3)
	sel.record_selection("combat", "duel", 4)
	var count: int = sel._count_consecutive("combat")
	if count != 3:
		push_error("consecutive combat: expected 3, got %d" % count)
		return false
	return true


func test_count_consecutive_broken_chain() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_selection("combat", "duel", 1)
	sel.record_selection("narrative", "dialogue", 2)
	sel.record_selection("combat", "ambush", 3)
	var count: int = sel._count_consecutive("combat")
	if count != 1:
		push_error("broken chain: expected 1, got %d" % count)
		return false
	return true


# =============================================================================
# FACTION DELTA TO STATE
# =============================================================================

func test_faction_delta_to_state_equilibre() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var state: String = sel._faction_delta_to_state(0.0)
	if state != "EQUILIBRE":
		push_error("delta=0 should be EQUILIBRE, got %s" % state)
		return false
	state = sel._faction_delta_to_state(5.0)
	if state != "EQUILIBRE":
		push_error("delta=5.0 should be EQUILIBRE, got %s" % state)
		return false
	state = sel._faction_delta_to_state(-5.0)
	if state != "EQUILIBRE":
		push_error("delta=-5.0 should be EQUILIBRE, got %s" % state)
		return false
	return true


func test_faction_delta_to_state_haut() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var state: String = sel._faction_delta_to_state(10.0)
	if state != "HAUT":
		push_error("delta=10 should be HAUT, got %s" % state)
		return false
	return true


func test_faction_delta_to_state_bas() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var state: String = sel._faction_delta_to_state(-10.0)
	if state != "BAS":
		push_error("delta=-10 should be BAS, got %s" % state)
		return false
	return true


# =============================================================================
# TRIGGER EVALUATION
# =============================================================================

func test_trigger_biome_match_boost() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var triggers: Dictionary = {"biome": ["foret", "marais"]}
	var bonus: float = sel._evaluate_triggers(triggers, {}, 5, 50, "foret", {}, 40, 0)
	if absf(bonus - 2.0) > 0.001:
		push_error("biome match should give 2.0, got %.3f" % bonus)
		return false
	return true


func test_trigger_biome_mismatch_penalty() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var triggers: Dictionary = {"biome": ["foret", "marais"]}
	var bonus: float = sel._evaluate_triggers(triggers, {}, 5, 50, "montagne", {}, 40, 0)
	if absf(bonus - 0.5) > 0.001:
		push_error("biome mismatch should give 0.5, got %.3f" % bonus)
		return false
	return true


func test_trigger_min_cards_played_blocks() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var triggers: Dictionary = {"min_cards_played": 10}
	var bonus: float = sel._evaluate_triggers(triggers, {}, 3, 50, "", {}, 40, 0)
	if absf(bonus) > 0.001:
		push_error("min_cards_played should block (0.0), got %.3f" % bonus)
		return false
	return true


func test_trigger_tension_above_met() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var triggers: Dictionary = {"tension_above": 60}
	var bonus: float = sel._evaluate_triggers(triggers, {}, 5, 50, "", {}, 70, 0)
	if absf(bonus - 1.5) > 0.001:
		push_error("tension_above met should give 1.5, got %.3f" % bonus)
		return false
	return true


func test_trigger_tension_above_not_met() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var triggers: Dictionary = {"tension_above": 60}
	var bonus: float = sel._evaluate_triggers(triggers, {}, 5, 50, "", {}, 40, 0)
	if absf(bonus - 0.5) > 0.001:
		push_error("tension_above not met should give 0.5, got %.3f" % bonus)
		return false
	return true


func test_trigger_life_below_met() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var triggers: Dictionary = {"life_below": 30}
	var bonus: float = sel._evaluate_triggers(triggers, {}, 5, 20, "", {}, 40, 0)
	if absf(bonus - 1.5) > 0.001:
		push_error("life_below met should give 1.5, got %.3f" % bonus)
		return false
	return true


func test_trigger_dominant_faction_above() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var triggers: Dictionary = {"dominant_faction_above": 60}
	var factions: Dictionary = {"druides": 70, "anciens": 20}
	var bonus: float = sel._evaluate_triggers(triggers, {}, 5, 50, "", {}, 40, 0, factions)
	if absf(bonus - 1.5) > 0.001:
		push_error("dominant_faction met should give 1.5, got %.3f" % bonus)
		return false
	return true


func test_trigger_flags_required_all_present() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var triggers: Dictionary = {"flags_required": ["quest_started", "npc_met"]}
	var flags: Dictionary = {"quest_started": true, "npc_met": true}
	var bonus: float = sel._evaluate_triggers(triggers, {}, 5, 50, "", flags, 40, 0)
	if absf(bonus - 1.0) > 0.001:
		push_error("all flags present should give 1.0, got %.3f" % bonus)
		return false
	return true


func test_trigger_flags_required_missing() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var triggers: Dictionary = {"flags_required": ["quest_started", "npc_met"]}
	var flags: Dictionary = {"quest_started": true}
	var bonus: float = sel._evaluate_triggers(triggers, {}, 5, 50, "", flags, 40, 0)
	if absf(bonus - 0.1) > 0.001:
		push_error("missing flag should give 0.1, got %.3f" % bonus)
		return false
	return true


# =============================================================================
# MATRIX CONDITION CHECKS
# =============================================================================

func test_matrix_condition_all_aspects_equilibre() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var condition: Dictionary = {"all_aspects": "EQUILIBRE"}
	var delta_eq: Dictionary = {"druides": 2.0, "anciens": -3.0}
	if not sel._check_matrix_condition(condition, 5, delta_eq):
		push_error("all deltas within +-5 should pass EQUILIBRE")
		return false
	var delta_neq: Dictionary = {"druides": 10.0, "anciens": -3.0}
	if sel._check_matrix_condition(condition, 5, delta_neq):
		push_error("delta=10 should fail EQUILIBRE")
		return false
	return true


func test_matrix_condition_any_aspect_haut() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var condition: Dictionary = {"any_aspect": ["HAUT"]}
	var delta_haut: Dictionary = {"druides": 15.0, "anciens": 0.0}
	if not sel._check_matrix_condition(condition, 5, delta_haut):
		push_error("delta=15 should match HAUT")
		return false
	var delta_none: Dictionary = {"druides": 3.0, "anciens": -2.0}
	if sel._check_matrix_condition(condition, 5, delta_none):
		push_error("all small deltas should not match HAUT")
		return false
	return true


# =============================================================================
# WEIGHTED SELECT
# =============================================================================

func test_weighted_select_single_entry() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var result: String = sel._weighted_select({"only": 1.0})
	if result != "only":
		push_error("single entry should always be selected, got %s" % result)
		return false
	return true


func test_weighted_select_empty_dict() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var result: String = sel._weighted_select({})
	if result != "":
		push_error("empty dict should return empty string, got %s" % result)
		return false
	return true


func test_weighted_select_zero_weights_fallback() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var result: String = sel._weighted_select({"a": 0.0, "b": 0.0})
	# When total <= 0, returns first key
	if result != "a":
		push_error("zero weights should fallback to first key, got %s" % result)
		return false
	return true


# =============================================================================
# SELECT EVENT (integration)
# =============================================================================

func test_select_event_returns_valid_structure() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var state: Dictionary = _make_game_state()
	var result: Dictionary = sel.select_event(state)
	if result.is_empty():
		push_error("select_event should return non-empty dict")
		return false
	if not result.has("category"):
		push_error("result missing 'category' key")
		return false
	if not result.has("sub_type"):
		push_error("result missing 'sub_type' key")
		return false
	if not result.has("label"):
		push_error("result missing 'label' key")
		return false
	if not result.has("narrator_guidance"):
		push_error("result missing 'narrator_guidance' key")
		return false
	var cat: String = str(result["category"])
	if cat not in ["narrative", "combat", "exploration", "faction"]:
		push_error("unexpected category: %s" % cat)
		return false
	return true


func test_select_event_category_in_known_set() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var known: Array[String] = sel.get_all_categories()
	# Run 50 times to check distribution
	for i in range(50):
		var result: Dictionary = sel.select_event(_make_game_state())
		if result.is_empty():
			continue
		var cat: String = str(result["category"])
		if cat not in known:
			push_error("category '%s' not in known set" % cat)
			return false
	return true


# =============================================================================
# DEBUG / QUERY
# =============================================================================

func test_get_all_categories() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var cats: Array[String] = sel.get_all_categories()
	if cats.size() != 4:
		push_error("expected 4 categories, got %d" % cats.size())
		return false
	if "narrative" not in cats or "combat" not in cats:
		push_error("missing expected categories")
		return false
	return true


func test_get_sub_types() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var subs: Array[String] = sel.get_sub_types("narrative")
	if subs.size() != 3:
		push_error("narrative should have 3 sub_types, got %d" % subs.size())
		return false
	if "dialogue" not in subs:
		push_error("missing 'dialogue' sub_type")
		return false
	return true


func test_get_category_info_exists() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var info: Dictionary = sel.get_category_info("narrative")
	if info.is_empty():
		push_error("get_category_info should return data for 'narrative'")
		return false
	if str(info.get("label", "")) != "Narrative":
		push_error("label mismatch")
		return false
	return true


func test_get_category_info_missing() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var info: Dictionary = sel.get_category_info("nonexistent")
	if not info.is_empty():
		push_error("missing category should return empty dict")
		return false
	return true


func test_get_debug_weights_not_loaded() -> bool:
	var sel: EventCategorySelector = EventCategorySelector.new()
	sel._categories = {}
	sel._is_loaded = false
	var weights: Dictionary = sel.get_debug_weights({"run": {}})
	if not weights.is_empty():
		push_error("debug weights should be empty when not loaded")
		return false
	return true


func test_get_debug_weights_loaded() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var weights: Dictionary = sel.get_debug_weights(_make_game_state())
	if weights.is_empty():
		push_error("debug weights should not be empty when loaded")
		return false
	if not weights.has("narrative"):
		push_error("debug weights missing 'narrative'")
		return false
	return true


# =============================================================================
# MODIFIER SYSTEM
# =============================================================================

func test_modifier_gap_never_used() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var gap: int = sel._modifier_gap("some_mod")
	if gap != -1:
		push_error("never used modifier should return -1, got %d" % gap)
		return false
	return true


func test_record_modifier_and_gap() -> bool:
	var sel: EventCategorySelector = _make_selector()
	sel.record_modifier("mod_a")
	sel.record_modifier("mod_b")
	sel.record_modifier("")
	# mod_a at index 0, size=3, gap = 2
	var gap: int = sel._modifier_gap("mod_a")
	if gap != 2:
		push_error("modifier gap: expected 2, got %d" % gap)
		return false
	return true


func test_record_modifier_trims_at_20() -> bool:
	var sel: EventCategorySelector = _make_selector()
	for i in range(25):
		sel.record_modifier("mod_%d" % i)
	if sel._modifier_history.size() != 20:
		push_error("modifier history should trim to 20, got %d" % sel._modifier_history.size())
		return false
	return true


func test_check_modifier_trigger_empty() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var result: bool = sel._check_modifier_trigger({}, _make_run())
	if not result:
		push_error("empty trigger should return true")
		return false
	return true


func test_check_modifier_trigger_dominant_faction() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var trigger: Dictionary = {"dominant_faction_above": 50}
	var run: Dictionary = _make_run({"factions": {"druides": 70, "anciens": 20}})
	if not sel._check_modifier_trigger(trigger, run):
		push_error("dominant faction 70 >= 50 should pass")
		return false
	var run_low: Dictionary = _make_run({"factions": {"druides": 30, "anciens": 20}})
	if sel._check_modifier_trigger(trigger, run_low):
		push_error("dominant faction 30 < 50 should fail")
		return false
	return true


func test_check_modifier_trigger_cards_played_min() -> bool:
	var sel: EventCategorySelector = _make_selector()
	var trigger: Dictionary = {"cards_played_min": 10}
	var run_ok: Dictionary = _make_run({"cards_played": 15})
	if not sel._check_modifier_trigger(trigger, run_ok):
		push_error("cards_played=15 >= 10 should pass")
		return false
	var run_fail: Dictionary = _make_run({"cards_played": 5})
	if sel._check_modifier_trigger(trigger, run_fail):
		push_error("cards_played=5 < 10 should fail")
		return false
	return true
