## =============================================================================
## Unit Tests — MerlinScenarioManager
## =============================================================================
## Tests: scenario selection, start/stop, anchor system, condition checking,
## branch resolution, LLM context getters, state queries, save/load, edge cases.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


# =============================================================================
# HELPERS
# =============================================================================

func _make_manager() -> MerlinScenarioManager:
	var mgr := MerlinScenarioManager.new()
	# Bypass catalogue loading — we inject state directly
	mgr._loaded = true
	mgr._catalogue = {}
	return mgr


func _make_scenario(overrides: Dictionary = {}) -> Dictionary:
	var sc: Dictionary = {
		"id": "test_scenario_01",
		"title": "The Lost Ogham",
		"tone": "mysterious",
		"theme_injection": "A shadow looms over the ancient stones.",
		"dealer_intro_context": "The dealer speaks of forgotten paths.",
		"weight": 1.0,
		"biome_affinity": [],
		"ambient_tags": ["shadow", "stone"],
		"anchors": [],
	}
	for key in overrides:
		sc[key] = overrides[key]
	return sc


func _make_anchor(overrides: Dictionary = {}) -> Dictionary:
	var anchor: Dictionary = {
		"id": "anchor_01",
		"type": "encounter",
		"position": 5,
		"position_flex": 1,
		"condition": {},
		"prompt_override": "You face a guardian.",
		"flags_set": ["met_guardian"],
		"tone": "tense",
		"must_reference": ["guardian"],
		"branches": {},
	}
	for key in overrides:
		anchor[key] = overrides[key]
	return anchor


func _make_branched_anchor() -> Dictionary:
	return _make_anchor({
		"id": "anchor_branched",
		"branches": {
			"if_flag_allied": {
				"prompt_override": "The guardian greets you as an ally.",
				"flags_set": ["guardian_ally"],
				"tone": "warm",
			},
			"default": {
				"prompt_override": "The guardian blocks your path.",
				"flags_set": ["guardian_hostile"],
				"tone": "cold",
			},
		},
	})


# =============================================================================
# IS_SCENARIO_ACTIVE
# =============================================================================

func test_no_scenario_active_by_default() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	if mgr.is_scenario_active():
		push_error("New manager should have no active scenario")
		return false
	return true


func test_scenario_active_after_start() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr.start_scenario(_make_scenario())
	if not mgr.is_scenario_active():
		push_error("Scenario should be active after start_scenario")
		return false
	return true


# =============================================================================
# START_SCENARIO
# =============================================================================

func test_start_scenario_sets_state() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var sc: Dictionary = _make_scenario({"title": "Test Title"})
	mgr.start_scenario(sc)
	if mgr.active_scenario.get("title", "") != "Test Title":
		push_error("start_scenario should store scenario data")
		return false
	return true


func test_start_scenario_clears_previous_state() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr.start_scenario(_make_scenario())
	mgr.triggered_anchors.append("old_anchor")
	mgr.scenario_flags["old_flag"] = true
	# Start a new scenario — should clear
	mgr.start_scenario(_make_scenario({"id": "second"}))
	if mgr.triggered_anchors.size() != 0:
		push_error("start_scenario should clear triggered_anchors")
		return false
	if mgr.scenario_flags.size() != 0:
		push_error("start_scenario should clear scenario_flags")
		return false
	return true


func test_start_scenario_empty_dict_noop() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr.start_scenario(_make_scenario())
	mgr.start_scenario({})
	# Empty dict should not replace active scenario
	if not mgr.is_scenario_active():
		push_error("start_scenario({}) should be a no-op, scenario should remain active")
		return false
	return true


func test_start_scenario_deep_copies() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var sc: Dictionary = _make_scenario()
	mgr.start_scenario(sc)
	# Mutate original — should not affect manager
	sc["title"] = "MUTATED"
	if mgr.active_scenario.get("title", "") == "MUTATED":
		push_error("start_scenario should deep copy the scenario")
		return false
	return true


# =============================================================================
# SELECT_SCENARIO — weighted random
# =============================================================================

func test_select_scenario_empty_catalogue() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var result: Dictionary = mgr.select_scenario("forest", {})
	if not result.is_empty():
		push_error("Empty catalogue should return empty dict")
		return false
	return true


func test_select_scenario_single_candidate() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr._catalogue = {"sc1": _make_scenario({"id": "sc1", "biome_affinity": []})}
	var result: Dictionary = mgr.select_scenario("forest", {})
	if result.get("id", "") != "sc1":
		push_error("Single candidate should always be selected, got '%s'" % str(result.get("id", "")))
		return false
	return true


func test_select_scenario_filters_by_biome() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr._catalogue = {
		"sc_forest": _make_scenario({"id": "sc_forest", "biome_affinity": ["forest"]}),
		"sc_desert": _make_scenario({"id": "sc_desert", "biome_affinity": ["desert"]}),
	}
	# Run multiple times — should only get forest scenario
	for i in range(20):
		var result: Dictionary = mgr.select_scenario("forest", {})
		if result.get("id", "") != "sc_forest":
			push_error("Biome filter: expected sc_forest, got '%s'" % str(result.get("id", "")))
			return false
	return true


func test_select_scenario_empty_affinity_matches_all() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr._catalogue = {
		"sc_any": _make_scenario({"id": "sc_any", "biome_affinity": []}),
	}
	var result: Dictionary = mgr.select_scenario("volcano", {})
	if result.get("id", "") != "sc_any":
		push_error("Empty biome_affinity should match any biome")
		return false
	return true


func test_select_scenario_reduces_weight_for_seen() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr._catalogue = {
		"sc_seen": _make_scenario({"id": "sc_seen", "weight": 1.0, "biome_affinity": []}),
		"sc_new": _make_scenario({"id": "sc_new", "weight": 1.0, "biome_affinity": []}),
	}
	var meta: Dictionary = {"scenarios_seen": ["sc_seen"]}
	# Run many times — sc_new should appear more often (weight 1.0 vs 0.3)
	var count_new: int = 0
	var runs: int = 200
	for i in range(runs):
		var result: Dictionary = mgr.select_scenario("forest", meta)
		if result.get("id", "") == "sc_new":
			count_new += 1
	# Expected: sc_new ~77% of the time (1.0 / 1.3). Allow wide margin.
	if count_new < runs * 0.5:
		push_error("Seen reduction: sc_new selected only %d/%d times (expected >50%%)" % [count_new, runs])
		return false
	return true


func test_select_scenario_no_biome_match_returns_empty() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr._catalogue = {
		"sc_desert": _make_scenario({"id": "sc_desert", "biome_affinity": ["desert"]}),
	}
	var result: Dictionary = mgr.select_scenario("forest", {})
	if not result.is_empty():
		push_error("No matching biome should return empty dict")
		return false
	return true


# =============================================================================
# GET_ANCHOR_FOR_CARD
# =============================================================================

func test_get_anchor_no_active_scenario() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	if not result.is_empty():
		push_error("No active scenario should return empty dict")
		return false
	return true


func test_get_anchor_position_match() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({"position": 5, "position_flex": 1})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	if result.get("anchor_id", "") != "anchor_01":
		push_error("Anchor at exact position should trigger")
		return false
	return true


func test_get_anchor_position_flex_lower() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({"position": 5, "position_flex": 2})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	var result: Dictionary = mgr.get_anchor_for_card(3, {})
	if result.get("anchor_id", "") != "anchor_01":
		push_error("Anchor within flex range (lower) should trigger")
		return false
	return true


func test_get_anchor_position_flex_upper() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({"position": 5, "position_flex": 2})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	var result: Dictionary = mgr.get_anchor_for_card(7, {})
	if result.get("anchor_id", "") != "anchor_01":
		push_error("Anchor within flex range (upper) should trigger")
		return false
	return true


func test_get_anchor_out_of_range() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({"position": 5, "position_flex": 1})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	var result: Dictionary = mgr.get_anchor_for_card(10, {})
	if not result.is_empty():
		push_error("Anchor out of flex range should not trigger")
		return false
	return true


func test_get_anchor_already_triggered() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({"position": 5, "position_flex": 1})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	mgr.triggered_anchors.append("anchor_01")
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	if not result.is_empty():
		push_error("Already triggered anchor should be skipped")
		return false
	return true


func test_get_anchor_condition_blocks() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({
		"position": 5,
		"condition": {"flag": "needs_key"},
	})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	# No flags set — condition should fail
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	if not result.is_empty():
		push_error("Anchor with unmet flag condition should not trigger")
		return false
	return true


func test_get_anchor_condition_met_via_game_flags() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({
		"position": 5,
		"condition": {"flag": "needs_key"},
	})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	var result: Dictionary = mgr.get_anchor_for_card(5, {"needs_key": true})
	if result.get("anchor_id", "") != "anchor_01":
		push_error("Anchor with met game_flag condition should trigger")
		return false
	return true


func test_get_anchor_condition_met_via_scenario_flags() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({
		"position": 5,
		"condition": {"flag": "needs_key"},
	})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	mgr.scenario_flags["needs_key"] = true
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	if result.get("anchor_id", "") != "anchor_01":
		push_error("Anchor with met scenario_flag condition should trigger")
		return false
	return true


# =============================================================================
# CONDITION CHECKING (_check_condition is private, tested via get_anchor_for_card)
# =============================================================================

func test_condition_empty_always_true() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({"position": 5, "condition": {}})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	if result.get("anchor_id", "") != "anchor_01":
		push_error("Empty condition should always pass")
		return false
	return true


func test_condition_any_flag_or_logic() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({
		"position": 5,
		"condition": {"any_flag": ["flag_a", "flag_b"]},
	})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	# Neither flag set — should fail
	var result_none: Dictionary = mgr.get_anchor_for_card(5, {})
	if not result_none.is_empty():
		push_error("any_flag with no flags set should fail")
		return false
	# Reset triggered state and set one flag
	mgr.triggered_anchors.clear()
	var result_one: Dictionary = mgr.get_anchor_for_card(5, {"flag_b": true})
	if result_one.get("anchor_id", "") != "anchor_01":
		push_error("any_flag with one matching flag should pass")
		return false
	return true


func test_condition_all_flags_and_logic() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({
		"position": 5,
		"condition": {"all_flags": ["flag_x", "flag_y"]},
	})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	# Only one flag — should fail
	var result_partial: Dictionary = mgr.get_anchor_for_card(5, {"flag_x": true})
	if not result_partial.is_empty():
		push_error("all_flags with only one flag set should fail")
		return false
	# Both flags — should pass
	mgr.triggered_anchors.clear()
	var result_both: Dictionary = mgr.get_anchor_for_card(5, {"flag_x": true, "flag_y": true})
	if result_both.get("anchor_id", "") != "anchor_01":
		push_error("all_flags with all flags set should pass")
		return false
	return true


# =============================================================================
# BRANCH RESOLUTION (tested via get_anchor_for_card)
# =============================================================================

func test_branch_default_when_no_flag() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_branched_anchor()
	anchor["position"] = 5
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	if result.get("prompt_override", "") != "The guardian blocks your path.":
		push_error("Default branch should be selected when no flag matches")
		return false
	if result.get("tone", "") != "cold":
		push_error("Default branch tone should be 'cold', got '%s'" % result.get("tone", ""))
		return false
	return true


func test_branch_flag_match() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_branched_anchor()
	anchor["position"] = 5
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	mgr.scenario_flags["allied"] = true
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	if result.get("prompt_override", "") != "The guardian greets you as an ally.":
		push_error("Flag-matched branch should be selected")
		return false
	if result.get("tone", "") != "warm":
		push_error("Flag-matched branch tone should be 'warm'")
		return false
	return true


func test_branch_no_branches_returns_anchor_direct() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({
		"position": 5,
		"branches": {},
		"prompt_override": "Direct prompt.",
		"tone": "neutral",
	})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	if result.get("prompt_override", "") != "Direct prompt.":
		push_error("No branches should return anchor's own prompt_override")
		return false
	return true


# =============================================================================
# RESOLVE_ANCHOR
# =============================================================================

func test_resolve_anchor_marks_triggered() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor()
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	mgr.resolve_anchor("anchor_01", 0)
	if not mgr.triggered_anchors.has("anchor_01"):
		push_error("resolve_anchor should add anchor_id to triggered_anchors")
		return false
	return true


func test_resolve_anchor_idempotent() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor()
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	mgr.resolve_anchor("anchor_01", 0)
	mgr.resolve_anchor("anchor_01", 1)
	var count: int = 0
	for a in mgr.triggered_anchors:
		if a == "anchor_01":
			count += 1
	if count != 1:
		push_error("resolve_anchor called twice should only add once, got %d" % count)
		return false
	return true


func test_resolve_anchor_sets_flags() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({
		"flags_set": ["met_guardian"],
		"branches": {},
	})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	mgr.resolve_anchor("anchor_01", 0)
	if not mgr.scenario_flags.get("met_guardian", false):
		push_error("resolve_anchor should set flags from resolved branch")
		return false
	return true


# =============================================================================
# LLM CONTEXT GETTERS
# =============================================================================

func test_get_theme_injection_active() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr.start_scenario(_make_scenario({"theme_injection": "Dark clouds gather."}))
	var result: String = mgr.get_theme_injection()
	if result != "Dark clouds gather.":
		push_error("get_theme_injection: expected 'Dark clouds gather.', got '%s'" % result)
		return false
	return true


func test_get_theme_injection_inactive() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var result: String = mgr.get_theme_injection()
	if result != "":
		push_error("get_theme_injection with no active scenario should return ''")
		return false
	return true


func test_get_dealer_intro_override_active() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr.start_scenario(_make_scenario({
		"dealer_intro_context": "Intro text",
		"tone": "ominous",
		"title": "The Quest",
	}))
	var result: Dictionary = mgr.get_dealer_intro_override()
	if result.get("context", "") != "Intro text":
		push_error("dealer_intro context mismatch")
		return false
	if result.get("tone", "") != "ominous":
		push_error("dealer_intro tone mismatch")
		return false
	if result.get("title", "") != "The Quest":
		push_error("dealer_intro title mismatch")
		return false
	return true


func test_get_dealer_intro_override_inactive() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var result: Dictionary = mgr.get_dealer_intro_override()
	if not result.is_empty():
		push_error("get_dealer_intro_override with no active scenario should return {}")
		return false
	return true


func test_get_dealer_intro_override_empty_context() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr.start_scenario(_make_scenario({"dealer_intro_context": ""}))
	var result: Dictionary = mgr.get_dealer_intro_override()
	if not result.is_empty():
		push_error("get_dealer_intro_override with empty context should return {}")
		return false
	return true


func test_get_scenario_tone_active() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr.start_scenario(_make_scenario({"tone": "dark"}))
	if mgr.get_scenario_tone() != "dark":
		push_error("get_scenario_tone: expected 'dark'")
		return false
	return true


func test_get_scenario_tone_inactive() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	if mgr.get_scenario_tone() != "":
		push_error("get_scenario_tone with no active scenario should return ''")
		return false
	return true


func test_get_ambient_tags_active() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr.start_scenario(_make_scenario({"ambient_tags": ["fog", "ruin"]}))
	var tags: Array = mgr.get_ambient_tags()
	if tags.size() != 2:
		push_error("get_ambient_tags: expected 2 tags, got %d" % tags.size())
		return false
	if not tags.has("fog") or not tags.has("ruin"):
		push_error("get_ambient_tags: missing expected tags")
		return false
	return true


func test_get_ambient_tags_inactive() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var tags: Array = mgr.get_ambient_tags()
	if tags.size() != 0:
		push_error("get_ambient_tags with no active scenario should return []")
		return false
	return true


func test_get_scenario_title() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr.start_scenario(_make_scenario({"title": "Forgotten Path"}))
	if mgr.get_scenario_title() != "Forgotten Path":
		push_error("get_scenario_title mismatch")
		return false
	return true


func test_get_scenario_title_inactive() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	if mgr.get_scenario_title() != "":
		push_error("get_scenario_title with no active scenario should return ''")
		return false
	return true


# =============================================================================
# STATE QUERIES
# =============================================================================

func test_get_triggered_count() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	if mgr.get_triggered_count() != 0:
		push_error("Initial triggered count should be 0")
		return false
	mgr.triggered_anchors.append("a1")
	mgr.triggered_anchors.append("a2")
	if mgr.get_triggered_count() != 2:
		push_error("Triggered count should be 2, got %d" % mgr.get_triggered_count())
		return false
	return true


func test_get_total_anchors() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	if mgr.get_total_anchors() != 0:
		push_error("No active scenario: total anchors should be 0")
		return false
	mgr.start_scenario(_make_scenario({"anchors": [_make_anchor(), _make_anchor({"id": "a2"})]}))
	if mgr.get_total_anchors() != 2:
		push_error("Total anchors should be 2, got %d" % mgr.get_total_anchors())
		return false
	return true


func test_get_scenario_flags_returns_copy() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr.scenario_flags["test_flag"] = true
	var flags_copy: Dictionary = mgr.get_scenario_flags()
	flags_copy["injected"] = true
	# Original should not be affected
	if mgr.scenario_flags.has("injected"):
		push_error("get_scenario_flags should return a copy, not a reference")
		return false
	return true


# =============================================================================
# SAVE / LOAD
# =============================================================================

func test_save_state_structure() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr.start_scenario(_make_scenario({"id": "sc_42"}))
	mgr.triggered_anchors.append("a1")
	mgr.scenario_flags["flag_x"] = true
	var state: Dictionary = mgr.save_state()
	if state.get("active_scenario_id", "") != "sc_42":
		push_error("save_state: active_scenario_id mismatch")
		return false
	var saved_anchors: Array = state.get("triggered_anchors", [])
	if saved_anchors.size() != 1 or str(saved_anchors[0]) != "a1":
		push_error("save_state: triggered_anchors mismatch")
		return false
	var saved_flags: Dictionary = state.get("scenario_flags", {})
	if not saved_flags.get("flag_x", false):
		push_error("save_state: scenario_flags mismatch")
		return false
	return true


func test_load_state_empty_clears() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	mgr.start_scenario(_make_scenario())
	mgr.triggered_anchors.append("old")
	mgr.scenario_flags["old_flag"] = true
	mgr.load_state({})
	if mgr.is_scenario_active():
		push_error("load_state({}) should clear active scenario")
		return false
	if mgr.triggered_anchors.size() != 0:
		push_error("load_state({}) should clear triggered_anchors")
		return false
	if mgr.scenario_flags.size() != 0:
		push_error("load_state({}) should clear scenario_flags")
		return false
	return true


func test_load_state_restores_flags_and_anchors() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	# Put a scenario in the catalogue so load can find it
	mgr._catalogue = {"sc_restore": _make_scenario({"id": "sc_restore"})}
	var data: Dictionary = {
		"active_scenario_id": "sc_restore",
		"triggered_anchors": ["anchor_a", "anchor_b"],
		"scenario_flags": {"restored_flag": true},
	}
	mgr.load_state(data)
	if not mgr.is_scenario_active():
		push_error("load_state should restore active scenario from catalogue")
		return false
	if mgr.triggered_anchors.size() != 2:
		push_error("load_state should restore triggered_anchors, got %d" % mgr.triggered_anchors.size())
		return false
	if not mgr.scenario_flags.get("restored_flag", false):
		push_error("load_state should restore scenario_flags")
		return false
	return true


func test_load_state_unknown_scenario_clears() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var data: Dictionary = {
		"active_scenario_id": "nonexistent",
		"triggered_anchors": [],
		"scenario_flags": {},
	}
	mgr.load_state(data)
	if mgr.is_scenario_active():
		push_error("load_state with unknown scenario_id should not set active scenario")
		return false
	return true


# =============================================================================
# EDGE CASES
# =============================================================================

func test_anchor_with_non_dict_entries_skipped() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	# Anchors array with a non-Dictionary entry
	var anchors: Array = ["not_a_dict", _make_anchor({"position": 5})]
	mgr.start_scenario(_make_scenario({"anchors": anchors}))
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	if result.get("anchor_id", "") != "anchor_01":
		push_error("Non-dict anchor entries should be skipped, valid anchor should still trigger")
		return false
	return true


func test_multiple_anchors_first_matching_wins() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var a1: Dictionary = _make_anchor({"id": "first", "position": 5, "position_flex": 0})
	var a2: Dictionary = _make_anchor({"id": "second", "position": 5, "position_flex": 0})
	mgr.start_scenario(_make_scenario({"anchors": [a1, a2]}))
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	if result.get("anchor_id", "") != "first":
		push_error("First matching anchor should win, got '%s'" % result.get("anchor_id", ""))
		return false
	return true


func test_get_anchor_returns_must_reference() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({
		"position": 5,
		"must_reference": ["guardian", "stone_circle"],
	})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	var must_ref: Array = result.get("must_reference", [])
	if must_ref.size() != 2:
		push_error("must_reference should have 2 entries, got %d" % must_ref.size())
		return false
	return true


func test_get_anchor_returns_anchor_type() -> bool:
	var mgr: MerlinScenarioManager = _make_manager()
	var anchor: Dictionary = _make_anchor({"position": 5, "type": "boss"})
	mgr.start_scenario(_make_scenario({"anchors": [anchor]}))
	var result: Dictionary = mgr.get_anchor_for_card(5, {})
	if result.get("anchor_type", "") != "boss":
		push_error("anchor_type should be 'boss', got '%s'" % result.get("anchor_type", ""))
		return false
	return true
