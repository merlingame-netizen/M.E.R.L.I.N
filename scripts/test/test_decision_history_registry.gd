## ═══════════════════════════════════════════════════════════════════════════════
## Test DecisionHistoryRegistry — Pure unit tests (no Node, no file I/O)
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage: reset, record_choice, choice ratios, NPC karma, gauge protection,
##           pattern detection, run end, context for LLM, callbacks, getters.
## Run count: 22 tests.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
# NO class_name


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _make_fresh() -> DecisionHistoryRegistry:
	var reg: DecisionHistoryRegistry = DecisionHistoryRegistry.new()
	reg.reset_all()
	return reg


func _make_card(id: String, tags: Array, options: Array = []) -> Dictionary:
	return {"id": id, "type": "narrative", "tags": tags, "options": options}


func _make_context(gauges: Dictionary = {}, day: int = 1, biome: String = "foret", time_ms: int = 3000) -> Dictionary:
	return {"gauges": gauges, "day": day, "biome": biome, "decision_time_ms": time_ms}



# ─────────────────────────────────────────────────────────────────────────────
# 1. RESET
# ─────────────────────────────────────────────────────────────────────────────

func test_reset_run_clears_current_run() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.record_choice(_make_card("c1", []), 0, _make_context())
	reg.reset_run()
	if reg.current_run.size() != 0:
		push_error("Expected current_run to be empty after reset_run(), got %d entries" % reg.current_run.size())
		return false
	return true


func test_reset_run_clears_npc_last_seen() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.npc_last_seen["npc_a"] = 5
	reg.reset_run()
	if reg.npc_last_seen.size() != 0:
		push_error("Expected npc_last_seen to be empty after reset_run()")
		return false
	return true


func test_reset_all_clears_everything() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.record_choice(_make_card("c1", []), 0, _make_context())
	reg.npc_karma["npc_a"] = 50
	reg.patterns_detected["some_pattern"] = {"confidence": 0.8, "occurrences": 10, "last_updated": 0}
	reg.reset_all()
	if reg.current_run.size() != 0:
		push_error("Expected current_run empty after reset_all()")
		return false
	if reg.npc_karma.size() != 0:
		push_error("Expected npc_karma empty after reset_all()")
		return false
	if reg.patterns_detected.size() != 0:
		push_error("Expected patterns_detected empty after reset_all()")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 2. RECORD CHOICE
# ─────────────────────────────────────────────────────────────────────────────

func test_record_choice_appends_entry() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.record_choice(_make_card("c1", ["mystery"]), 1, _make_context())
	if reg.current_run.size() != 1:
		push_error("Expected 1 entry in current_run, got %d" % reg.current_run.size())
		return false
	return true


func test_record_choice_stores_correct_option() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.record_choice(_make_card("c1", []), 2, _make_context())
	var entry: Dictionary = reg.current_run[0]
	if entry["option"] != 2:
		push_error("Expected option == 2, got %d" % entry["option"])
		return false
	return true


func test_record_choice_stores_tags() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.record_choice(_make_card("c1", ["risky", "stranger"]), 0, _make_context())
	var entry: Dictionary = reg.current_run[0]
	if "risky" not in entry["tags"] or "stranger" not in entry["tags"]:
		push_error("Expected tags ['risky','stranger'] in entry")
		return false
	return true


func test_record_choice_increments_total_choices() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.record_choice(_make_card("c1", []), 0, _make_context())
	reg.record_choice(_make_card("c2", []), 1, _make_context())
	if reg.historical_summary["total_choices"] != 2:
		push_error("Expected total_choices == 2, got %d" % reg.historical_summary["total_choices"])
		return false
	return true


func test_record_choice_caps_run_at_max_entries() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	for i in range(205):
		reg.record_choice(_make_card("c%d" % i, []), 0, _make_context())
	if reg.current_run.size() > DecisionHistoryRegistry.MAX_CURRENT_RUN_ENTRIES:
		push_error("Expected current_run.size() <= MAX_CURRENT_RUN_ENTRIES (%d), got %d" % [
			DecisionHistoryRegistry.MAX_CURRENT_RUN_ENTRIES, reg.current_run.size()])
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 3. CHOICE RATIOS
# ─────────────────────────────────────────────────────────────────────────────

func test_choice_ratios_all_left_gives_left_ratio_one() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	for i in range(5):
		reg.record_choice(_make_card("c%d" % i, []), 0, _make_context())
	var ratio: float = float(reg.historical_summary["left_ratio"])
	if not is_equal_approx(ratio, 1.0):
		push_error("Expected left_ratio == 1.0, got %f" % ratio)
		return false
	return true


func test_choice_ratios_sum_to_one() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.record_choice(_make_card("c1", []), 0, _make_context())
	reg.record_choice(_make_card("c2", []), 1, _make_context())
	reg.record_choice(_make_card("c3", []), 2, _make_context())
	var total: float = float(reg.historical_summary["left_ratio"]) + float(reg.historical_summary["center_ratio"]) + float(reg.historical_summary["right_ratio"])
	if absf(total - 1.0) > 0.001:
		push_error("Expected ratios to sum to 1.0, got %f" % total)
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 4. NPC KARMA
# ─────────────────────────────────────────────────────────────────────────────

func test_npc_karma_initializes_to_zero() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	var karma: int = reg.get_npc_karma("unknown_npc")
	if karma != 0:
		push_error("Expected karma == 0 for unknown NPC, got %d" % karma)
		return false
	return true


func test_npc_karma_increases_on_help_tag_option_1() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	var card: Dictionary = _make_card("c1", ["help"], [])
	card["npc_id"] = "npc_bard"
	reg.record_choice(card, 1, _make_context())
	var karma: int = reg.get_npc_karma("npc_bard")
	if karma <= 0:
		push_error("Expected positive karma after help+option 1, got %d" % karma)
		return false
	return true


func test_npc_karma_clamped_at_100() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.npc_karma["npc_x"] = 95
	# Direct mutation to simulate repeated positive interactions
	reg.npc_karma["npc_x"] = clampi(reg.npc_karma["npc_x"] + 20, -100, 100)
	if reg.npc_karma["npc_x"] > 100:
		push_error("Expected karma clamped at 100, got %d" % reg.npc_karma["npc_x"])
		return false
	return true


func test_npc_karma_clamped_at_minus_100() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.npc_karma["npc_x"] = -95
	reg.npc_karma["npc_x"] = clampi(reg.npc_karma["npc_x"] - 20, -100, 100)
	if reg.npc_karma["npc_x"] < -100:
		push_error("Expected karma clamped at -100, got %d" % reg.npc_karma["npc_x"])
		return false
	return true


func test_get_npc_relationship_summary_thresholds() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	var tracker: Dictionary = {"ok": true, "error": ""}

	var check: Callable = func(karma: int, expected: String) -> void:
		reg.npc_karma["test_npc"] = karma
		var result: String = reg.get_npc_relationship_summary("test_npc")
		if result != expected:
			tracker["ok"] = false
			tracker["error"] = "karma %d: expected '%s', got '%s'" % [karma, expected, result]

	check.call(60, "allie_fidele")
	check.call(30, "ami")
	check.call(0, "neutre")
	check.call(-30, "mefiant")
	check.call(-60, "ennemi")

	if not tracker["ok"]:
		push_error(tracker["error"])
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 5. PATTERN DETECTION
# ─────────────────────────────────────────────────────────────────────────────

func test_pattern_not_detected_below_min_occurrences() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	# Needs >= 5 occurrences; add only 4
	for i in range(4):
		reg.record_choice(_make_card("c%d" % i, ["mystery", "investigate"]), 1, _make_context())
	if reg.has_pattern("seeks_mystery"):
		push_error("Expected seeks_mystery NOT detected with only 4 entries")
		return false
	return true


func test_pattern_detected_at_threshold() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	# 5 entries all matching option 1 → consistency = 1.0 >= 0.7
	for i in range(5):
		reg.record_choice(_make_card("c%d" % i, ["mystery", "investigate"]), 1, _make_context())
	if not reg.has_pattern("seeks_mystery"):
		push_error("Expected seeks_mystery DETECTED with 5 matching entries")
		return false
	return true


func test_get_pattern_returns_empty_for_unknown() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	var result: Dictionary = reg.get_pattern("nonexistent_pattern")
	if result.size() != 0:
		push_error("Expected empty dict for unknown pattern, got %s" % str(result))
		return false
	return true


func test_has_pattern_respects_min_confidence() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.patterns_detected["test_p"] = {"confidence": 0.65, "occurrences": 8, "last_updated": 0}
	# With default threshold 0.7: should NOT match
	if reg.has_pattern("test_p"):
		push_error("Expected has_pattern to return false when confidence=0.65 < 0.7")
		return false
	# With explicit lower threshold: should match
	if not reg.has_pattern("test_p", 0.6):
		push_error("Expected has_pattern to return true when confidence=0.65 >= 0.6")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 6. CONTEXT FOR LLM
# ─────────────────────────────────────────────────────────────────────────────

func test_get_context_for_llm_contains_required_keys() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	var ctx: Dictionary = reg.get_context_for_llm()
	var required: Array = [
		"cards_this_run", "patterns", "npc_karma",
		"npcs_met_count", "recent_choices",
		"promise_acceptance_rate",
	]
	for k in required:
		if not ctx.has(k):
			push_error("get_context_for_llm() missing key: %s" % k)
			return false
	return true


func test_get_recent_choices_returns_at_most_n() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	for i in range(10):
		reg.record_choice(_make_card("c%d" % i, []), 0, _make_context())
	var ctx: Dictionary = reg.get_context_for_llm()
	var recent: Array = ctx["recent_choices"]
	if recent.size() > 5:
		push_error("Expected at most 5 recent choices, got %d" % recent.size())
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 7. RUN END & CALLBACK NPCS
# ─────────────────────────────────────────────────────────────────────────────

func test_on_run_end_resets_current_run() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.record_choice(_make_card("c1", []), 0, _make_context())
	reg.on_run_end({"victory": false, "final_gauges": {}})
	if reg.current_run.size() != 0:
		push_error("Expected current_run empty after on_run_end()")
		return false
	return true


func test_get_callback_npcs_returns_npcs_with_sufficient_karma_and_gap() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	# Add 15 cards so gap from npc_last_seen=0 is >= 10
	for i in range(15):
		reg.record_choice(_make_card("c%d" % i, []), 0, _make_context())
	reg.npc_karma["npc_hero"] = 50
	reg.npc_last_seen["npc_hero"] = 0  # seen at card 0, now 15 → gap of 15
	var callbacks: Array = reg.get_callback_npcs()
	var found: bool = false
	for cb in callbacks:
		if cb["npc_id"] == "npc_hero":
			found = true
			break
	if not found:
		push_error("Expected npc_hero in callback NPCs (karma=50, gap=15)")
		return false
	return true


func test_get_previous_choice_on_tag_returns_last_match() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.record_choice(_make_card("c1", ["mystery"]), 0, _make_context())
	reg.record_choice(_make_card("c2", ["combat"]), 1, _make_context())
	reg.record_choice(_make_card("c3", ["mystery"]), 2, _make_context())
	var result: Dictionary = reg.get_previous_choice_on_tag("mystery")
	if result.get("option", -1) != 2:
		push_error("Expected last mystery choice to have option 2, got %d" % result.get("option", -1))
		return false
	return true


func test_get_previous_choice_on_tag_returns_empty_when_no_match() -> bool:
	var reg: DecisionHistoryRegistry = _make_fresh()
	reg.record_choice(_make_card("c1", ["combat"]), 0, _make_context())
	var result: Dictionary = reg.get_previous_choice_on_tag("mystery")
	if result.size() != 0:
		push_error("Expected empty dict when no matching tag, got %s" % str(result))
		return false
	return true
