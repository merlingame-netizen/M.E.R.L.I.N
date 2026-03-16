## ═══════════════════════════════════════════════════════════════════════════════
## Test — DecisionHistoryRegistry
## ═══════════════════════════════════════════════════════════════════════════════
## Unit tests for DecisionHistoryRegistry.
## Run via test runner — NO assert(), NO await, NO class_name.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

var _reg: DecisionHistoryRegistry

func _init() -> void:
	_reg = DecisionHistoryRegistry.new()
	_reg.reset_all()


func _fail(msg: String) -> bool:
	push_error(msg)
	return false


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _make_card(id: String, tags: Array = [], npc_id: String = "") -> Dictionary:
	return {
		"id": id,
		"type": "narrative",
		"tags": tags,
		"npc_id": npc_id,
		"options": [
			{"effects": [{"target": "vigueur", "value": -10}]},
			{"effects": [{"target": "esprit", "value": 5}]},
			{"effects": [{"target": "faveur", "value": 3}]},
		],
	}


func _make_ctx(day: int = 1, biome: String = "foret", gauges: Dictionary = {}) -> Dictionary:
	return {
		"day": day,
		"biome": biome,
		"gauges": gauges,
		"decision_time_ms": 2500,
	}


func _record_n(card: Dictionary, option: int, ctx: Dictionary, n: int) -> void:
	for i in range(n):
		_reg.record_choice(card, option, ctx)


# ─────────────────────────────────────────────────────────────────────────────
# 1. INIT / RESET
# ─────────────────────────────────────────────────────────────────────────────

func test_initial_run_is_empty() -> bool:
	_reg.reset_all()
	if _reg.current_run.size() != 0:
		return _fail("Expected empty current_run after reset_all, got %d" % _reg.current_run.size())
	return true


func test_reset_all_clears_npc_karma() -> bool:
	_reg.reset_all()
	var card := _make_card("c1", ["help"], "npc_druid")
	_reg.record_choice(card, 1, _make_ctx())
	_reg.reset_all()
	if _reg.npc_karma.size() != 0:
		return _fail("npc_karma should be empty after reset_all")
	return true


func test_reset_all_clears_patterns_detected() -> bool:
	_reg.reset_all()
	if _reg.patterns_detected.size() != 0:
		return _fail("patterns_detected should be empty after reset_all")
	return true


func test_reset_run_clears_current_run_only() -> bool:
	_reg.reset_all()
	var card := _make_card("c1", ["help"], "npc_a")
	_reg.record_choice(card, 1, _make_ctx())
	_reg.reset_run()
	if _reg.current_run.size() != 0:
		return _fail("current_run should be empty after reset_run")
	return true


func test_reset_run_preserves_karma() -> bool:
	_reg.reset_all()
	var card := _make_card("c1", ["help"], "npc_b")
	_reg.record_choice(card, 1, _make_ctx())
	_reg.reset_run()
	if not _reg.npc_karma.has("npc_b"):
		return _fail("npc_karma should survive reset_run")
	return true


func test_historical_summary_defaults() -> bool:
	_reg.reset_all()
	var hs: Dictionary = _reg.historical_summary
	if hs.total_choices != 0:
		return _fail("total_choices default should be 0")
	if not is_equal_approx(hs.left_ratio, 0.5):
		return _fail("left_ratio default should be 0.5")
	if not is_equal_approx(hs.center_ratio, 0.0):
		return _fail("center_ratio default should be 0.0")
	if not is_equal_approx(hs.right_ratio, 0.5):
		return _fail("right_ratio default should be 0.5")
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 2. RECORD CHOICE — BASIC
# ─────────────────────────────────────────────────────────────────────────────

func test_record_choice_appends_entry() -> bool:
	_reg.reset_all()
	var card := _make_card("card_01")
	_reg.record_choice(card, 0, _make_ctx())
	if _reg.current_run.size() != 1:
		return _fail("Expected 1 entry, got %d" % _reg.current_run.size())
	return true


func test_record_choice_stores_option() -> bool:
	_reg.reset_all()
	var card := _make_card("card_02")
	_reg.record_choice(card, 2, _make_ctx())
	var entry: Dictionary = _reg.current_run[0]
	if entry.option != 2:
		return _fail("Expected option=2, got %d" % entry.option)
	return true


func test_record_choice_stores_card_id() -> bool:
	_reg.reset_all()
	var card := _make_card("my_card_id")
	_reg.record_choice(card, 0, _make_ctx())
	var entry: Dictionary = _reg.current_run[0]
	if entry.card_id != "my_card_id":
		return _fail("card_id mismatch: %s" % entry.card_id)
	return true


func test_record_choice_stores_biome_and_day() -> bool:
	_reg.reset_all()
	var card := _make_card("c3")
	_reg.record_choice(card, 1, _make_ctx(7, "marais"))
	var entry: Dictionary = _reg.current_run[0]
	if entry.day != 7:
		return _fail("day mismatch: %d" % entry.day)
	if entry.biome != "marais":
		return _fail("biome mismatch: %s" % entry.biome)
	return true


func test_record_choice_stores_tags() -> bool:
	_reg.reset_all()
	var card := _make_card("c4", ["stranger", "help_request"])
	_reg.record_choice(card, 1, _make_ctx())
	var entry: Dictionary = _reg.current_run[0]
	if not ("stranger" in entry.tags):
		return _fail("tags should contain 'stranger'")
	return true


func test_record_choice_increments_total_choices() -> bool:
	_reg.reset_all()
	_reg.record_choice(_make_card("c5"), 0, _make_ctx())
	_reg.record_choice(_make_card("c6"), 1, _make_ctx())
	if _reg.historical_summary.total_choices != 2:
		return _fail("Expected total_choices=2, got %d" % _reg.historical_summary.total_choices)
	return true


func test_record_choice_gauges_before_stored() -> bool:
	_reg.reset_all()
	var ctx := _make_ctx(1, "foret", {"vigueur": 80, "esprit": 40})
	_reg.record_choice(_make_card("c7"), 0, ctx)
	var entry: Dictionary = _reg.current_run[0]
	if entry.gauges_before.get("vigueur") != 80:
		return _fail("gauges_before.vigueur should be 80")
	return true


func test_record_choice_gauges_after_initially_empty() -> bool:
	_reg.reset_all()
	_reg.record_choice(_make_card("c8"), 0, _make_ctx())
	var entry: Dictionary = _reg.current_run[0]
	if not entry.gauges_after.is_empty():
		return _fail("gauges_after should be empty until update_last_entry_gauges is called")
	return true


func test_update_last_entry_gauges_sets_values() -> bool:
	_reg.reset_all()
	_reg.record_choice(_make_card("c9"), 0, _make_ctx())
	_reg.update_last_entry_gauges({"vigueur": 60, "esprit": 55})
	var entry: Dictionary = _reg.current_run[0]
	if entry.gauges_after.get("esprit") != 55:
		return _fail("gauges_after.esprit should be 55, got %s" % str(entry.gauges_after.get("esprit")))
	return true


func test_update_last_entry_gauges_on_empty_run_is_safe() -> bool:
	_reg.reset_all()
	# Must not crash
	_reg.update_last_entry_gauges({"vigueur": 50})
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 3. CHOICE RATIOS
# ─────────────────────────────────────────────────────────────────────────────

func test_left_ratio_after_all_left_choices() -> bool:
	_reg.reset_all()
	for i in range(4):
		_reg.record_choice(_make_card("c_l%d" % i), 0, _make_ctx())
	if not is_equal_approx(_reg.historical_summary.left_ratio, 1.0):
		return _fail("left_ratio should be 1.0 after 4 left choices, got %f" % _reg.historical_summary.left_ratio)
	return true


func test_center_ratio_after_all_center_choices() -> bool:
	_reg.reset_all()
	for i in range(3):
		_reg.record_choice(_make_card("c_c%d" % i), 1, _make_ctx())
	if not is_equal_approx(_reg.historical_summary.center_ratio, 1.0):
		return _fail("center_ratio should be 1.0 after 3 center choices, got %f" % _reg.historical_summary.center_ratio)
	return true


func test_right_ratio_after_all_right_choices() -> bool:
	_reg.reset_all()
	for i in range(3):
		_reg.record_choice(_make_card("c_r%d" % i), 2, _make_ctx())
	if not is_equal_approx(_reg.historical_summary.right_ratio, 1.0):
		return _fail("right_ratio should be 1.0 after 3 right choices, got %f" % _reg.historical_summary.right_ratio)
	return true


func test_mixed_ratios_sum_to_one() -> bool:
	_reg.reset_all()
	_reg.record_choice(_make_card("m1"), 0, _make_ctx())
	_reg.record_choice(_make_card("m2"), 1, _make_ctx())
	_reg.record_choice(_make_card("m3"), 2, _make_ctx())
	var hs: Dictionary = _reg.historical_summary
	var total: float = hs.left_ratio + hs.center_ratio + hs.right_ratio
	if not is_equal_approx(total, 1.0):
		return _fail("Ratios should sum to 1.0, got %f" % total)
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 4. NPC KARMA
# ─────────────────────────────────────────────────────────────────────────────

func test_get_npc_karma_unknown_returns_zero() -> bool:
	_reg.reset_all()
	if _reg.get_npc_karma("unknown_npc") != 0:
		return _fail("Unknown NPC karma should be 0")
	return true


func test_npc_karma_increases_on_help_option_1() -> bool:
	_reg.reset_all()
	var card := _make_card("c10", ["help"], "druid_01")
	_reg.record_choice(card, 1, _make_ctx())
	var karma: int = _reg.get_npc_karma("druid_01")
	if karma != 10:
		return _fail("Karma should be 10 after helping (option=1 with 'help' tag), got %d" % karma)
	return true


func test_npc_karma_decreases_on_help_option_0() -> bool:
	_reg.reset_all()
	var card := _make_card("c11", ["help"], "druid_02")
	_reg.record_choice(card, 0, _make_ctx())
	var karma: int = _reg.get_npc_karma("druid_02")
	if karma != -5:
		return _fail("Karma should be -5 for option=0 with 'help' tag, got %d" % karma)
	return true


func test_npc_karma_decreases_on_betray_option_1() -> bool:
	_reg.reset_all()
	var card := _make_card("c12", ["betray"], "npc_x")
	_reg.record_choice(card, 1, _make_ctx())
	var karma: int = _reg.get_npc_karma("npc_x")
	if karma != -10:
		return _fail("Karma should be -10 for betray+option1, got %d" % karma)
	return true


func test_npc_karma_clamped_at_100() -> bool:
	_reg.reset_all()
	var card := _make_card("c13", ["help"], "npc_y")
	for i in range(15):
		_reg.record_choice(card, 1, _make_ctx())
	var karma: int = _reg.get_npc_karma("npc_y")
	if karma > 100:
		return _fail("NPC karma must not exceed 100, got %d" % karma)
	return true


func test_npc_karma_clamped_at_minus_100() -> bool:
	_reg.reset_all()
	var card := _make_card("c14", ["attack"], "npc_z")
	for i in range(10):
		_reg.record_choice(card, 1, _make_ctx())
	var karma: int = _reg.get_npc_karma("npc_z")
	if karma < -100:
		return _fail("NPC karma must not go below -100, got %d" % karma)
	return true


func test_npc_karma_no_change_without_npc_id() -> bool:
	_reg.reset_all()
	var card := _make_card("c15", ["help"])  # no npc_id
	_reg.record_choice(card, 1, _make_ctx())
	if _reg.npc_karma.size() != 0:
		return _fail("No karma entry should be created when npc_id is empty")
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 5. NPC RELATIONSHIP SUMMARY
# ─────────────────────────────────────────────────────────────────────────────

func test_relationship_allie_fidele_at_high_karma() -> bool:
	_reg.reset_all()
	_reg.npc_karma["npc_allie"] = 60
	if _reg.get_npc_relationship_summary("npc_allie") != "allie_fidele":
		return _fail("Karma 60 should give 'allie_fidele'")
	return true


func test_relationship_ami_at_moderate_karma() -> bool:
	_reg.reset_all()
	_reg.npc_karma["npc_ami"] = 30
	if _reg.get_npc_relationship_summary("npc_ami") != "ami":
		return _fail("Karma 30 should give 'ami'")
	return true


func test_relationship_neutre_at_zero_karma() -> bool:
	_reg.reset_all()
	_reg.npc_karma["npc_neutre"] = 0
	if _reg.get_npc_relationship_summary("npc_neutre") != "neutre":
		return _fail("Karma 0 should give 'neutre'")
	return true


func test_relationship_mefiant_at_negative_karma() -> bool:
	_reg.reset_all()
	_reg.npc_karma["npc_mef"] = -35
	if _reg.get_npc_relationship_summary("npc_mef") != "mefiant":
		return _fail("Karma -35 should give 'mefiant'")
	return true


func test_relationship_ennemi_at_very_negative_karma() -> bool:
	_reg.reset_all()
	_reg.npc_karma["npc_enn"] = -75
	if _reg.get_npc_relationship_summary("npc_enn") != "ennemi":
		return _fail("Karma -75 should give 'ennemi'")
	return true


func test_relationship_unknown_npc_is_neutre() -> bool:
	_reg.reset_all()
	if _reg.get_npc_relationship_summary("nobody") != "neutre":
		return _fail("Unknown NPC (karma 0) should be 'neutre'")
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 6. PATTERN DETECTION
# ─────────────────────────────────────────────────────────────────────────────

func test_no_pattern_before_min_occurrences() -> bool:
	_reg.reset_all()
	var card := _make_card("p1", ["stranger", "help_request"])
	# Only 4 choices — below PATTERN_MIN_OCCURRENCES (5)
	for i in range(4):
		_reg.record_choice(card, 1, _make_ctx())
	if _reg.has_pattern("always_helps_strangers"):
		return _fail("Pattern should not be detected before 5 occurrences")
	return true


func test_pattern_detected_after_min_occurrences_consistent() -> bool:
	_reg.reset_all()
	var card := _make_card("p2", ["stranger", "help_request"])
	for i in range(5):
		_reg.record_choice(card, 1, _make_ctx())
	if not _reg.has_pattern("always_helps_strangers"):
		return _fail("Pattern 'always_helps_strangers' should be detected after 5 consistent choices")
	return true


func test_pattern_not_detected_below_threshold() -> bool:
	_reg.reset_all()
	var card_yes := _make_card("p3a", ["promise"])
	var card_no := _make_card("p3b", ["promise"])
	# 3 declines (option=0), 3 accepts (option=1) → 50% consistency, below 70%
	for i in range(3):
		_reg.record_choice(card_yes, 0, _make_ctx())
	for i in range(3):
		_reg.record_choice(card_no, 1, _make_ctx())
	if _reg.has_pattern("avoids_promises"):
		return _fail("Pattern 'avoids_promises' should NOT be detected at 50% consistency")
	return true


func test_has_pattern_with_custom_confidence() -> bool:
	_reg.reset_all()
	var card := _make_card("p4", ["mystery", "investigate"])
	# 5 choices option=1 → 100% consistency → confidence = 1.0
	for i in range(5):
		_reg.record_choice(card, 1, _make_ctx())
	if not _reg.has_pattern("seeks_mystery", 0.9):
		return _fail("Pattern 'seeks_mystery' should pass confidence 0.9 at 100%")
	return true


func test_get_pattern_returns_empty_for_unknown() -> bool:
	_reg.reset_all()
	var p: Dictionary = _reg.get_pattern("nonexistent_pattern")
	if not p.is_empty():
		return _fail("get_pattern for unknown pattern should return empty dict")
	return true


func test_get_pattern_returns_confidence_key() -> bool:
	_reg.reset_all()
	var card := _make_card("p5", ["risky", "dangerous"])
	for i in range(5):
		_reg.record_choice(card, 1, _make_ctx())
	var p: Dictionary = _reg.get_pattern("takes_risks")
	if not p.has("confidence"):
		return _fail("Detected pattern should have a 'confidence' key")
	return true


func test_pattern_occurrences_stored() -> bool:
	_reg.reset_all()
	var card := _make_card("p6", ["conflict", "fight"])
	for i in range(6):
		_reg.record_choice(card, 0, _make_ctx())
	var p: Dictionary = _reg.get_pattern("avoids_conflict")
	if p.get("occurrences", 0) < 5:
		return _fail("Pattern occurrences should be >= 5, got %d" % p.get("occurrences", 0))
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 7. GAUGE PROTECTION TRACKING
# ─────────────────────────────────────────────────────────────────────────────

func test_gauge_protection_opportunity_counted_below_25() -> bool:
	_reg.reset_all()
	var ctx := _make_ctx(1, "foret", {"vigueur": 10})
	var card := _make_card("g1", [])
	_reg.record_choice(card, 0, ctx)
	if _reg.gauge_patterns["protects_vigueur"].opportunities < 1:
		return _fail("Should count protection opportunity when vigueur < 25")
	return true


func test_gauge_protection_opportunity_counted_above_75() -> bool:
	_reg.reset_all()
	var ctx := _make_ctx(1, "foret", {"vigueur": 90})
	var card := _make_card("g2", [])
	_reg.record_choice(card, 0, ctx)
	if _reg.gauge_patterns["protects_vigueur"].opportunities < 1:
		return _fail("Should count protection opportunity when vigueur > 75")
	return true


func test_gauge_protection_count_increments_when_protected() -> bool:
	_reg.reset_all()
	# vigueur=10 (low) → protect by choosing option 0 (effect target=vigueur, value=-10 is NOT protection)
	# We need a card with option that raises vigueur (positive effect on vigueur)
	var card := {
		"id": "g3",
		"type": "narrative",
		"tags": [],
		"npc_id": "",
		"options": [
			{"effects": [{"target": "vigueur", "value": 15}]},   # option 0 — raises vigueur
			{"effects": []},
			{"effects": []},
		],
	}
	var ctx := _make_ctx(1, "foret", {"vigueur": 20})
	_reg.record_choice(card, 0, ctx)
	if _reg.gauge_patterns["protects_vigueur"].count < 1:
		return _fail("protects_vigueur count should increment when raising a low-vigueur gauge")
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 8. GET PREVIOUS CHOICE ON TAG
# ─────────────────────────────────────────────────────────────────────────────

func test_get_previous_choice_on_tag_returns_correct_entry() -> bool:
	_reg.reset_all()
	_reg.record_choice(_make_card("t1", ["lore"]), 2, _make_ctx())
	_reg.record_choice(_make_card("t2", ["fight"]), 0, _make_ctx())
	var result: Dictionary = _reg.get_previous_choice_on_tag("lore")
	if result.get("card_id") != "t1":
		return _fail("Should return entry with 'lore' tag, got card_id=%s" % result.get("card_id", ""))
	return true


func test_get_previous_choice_on_tag_returns_last_match() -> bool:
	_reg.reset_all()
	_reg.record_choice(_make_card("t3", ["mystery"]), 0, _make_ctx())
	_reg.record_choice(_make_card("t4", ["mystery"]), 1, _make_ctx())
	var result: Dictionary = _reg.get_previous_choice_on_tag("mystery")
	if result.get("card_id") != "t4":
		return _fail("Should return LAST match for 'mystery', got %s" % result.get("card_id", ""))
	return true


func test_get_previous_choice_on_tag_returns_empty_when_not_found() -> bool:
	_reg.reset_all()
	_reg.record_choice(_make_card("t5", ["help"]), 1, _make_ctx())
	var result: Dictionary = _reg.get_previous_choice_on_tag("does_not_exist")
	if not result.is_empty():
		return _fail("Should return empty dict when tag is not found")
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 9. MAX RUN ENTRIES BUFFER
# ─────────────────────────────────────────────────────────────────────────────

func test_current_run_capped_at_200() -> bool:
	_reg.reset_all()
	for i in range(205):
		_reg.record_choice(_make_card("overflow_%d" % i), 0, _make_ctx())
	if _reg.current_run.size() > DecisionHistoryRegistry.MAX_CURRENT_RUN_ENTRIES:
		return _fail("current_run exceeded MAX_CURRENT_RUN_ENTRIES=%d, got %d" % [
			DecisionHistoryRegistry.MAX_CURRENT_RUN_ENTRIES, _reg.current_run.size()
		])
	return true


func test_oldest_entries_dropped_when_over_capacity() -> bool:
	_reg.reset_all()
	# First card
	_reg.record_choice(_make_card("first_card"), 0, _make_ctx())
	# Fill to overflow
	for i in range(DecisionHistoryRegistry.MAX_CURRENT_RUN_ENTRIES):
		_reg.record_choice(_make_card("filler_%d" % i), 1, _make_ctx())
	# "first_card" should have been pushed out
	var found := false
	for entry in _reg.current_run:
		if entry.card_id == "first_card":
			found = true
			break
	if found:
		return _fail("first_card should have been evicted from the capped buffer")
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 10. GET CONTEXT FOR LLM
# ─────────────────────────────────────────────────────────────────────────────

func test_get_context_for_llm_has_expected_keys() -> bool:
	_reg.reset_all()
	var ctx: Dictionary = _reg.get_context_for_llm()
	var required_keys := [
		"cards_this_run", "patterns", "npc_karma",
		"npcs_met_count", "recent_choices",
		"promise_acceptance_rate", "most_common_death_gauge"
	]
	for k in required_keys:
		if not ctx.has(k):
			return _fail("get_context_for_llm() missing key: %s" % k)
	return true


func test_get_context_for_llm_cards_this_run_count() -> bool:
	_reg.reset_all()
	for i in range(3):
		_reg.record_choice(_make_card("llm_%d" % i), 0, _make_ctx())
	var ctx: Dictionary = _reg.get_context_for_llm()
	if ctx.cards_this_run != 3:
		return _fail("cards_this_run should be 3, got %d" % ctx.cards_this_run)
	return true


func test_get_context_for_llm_recent_choices_max_5() -> bool:
	_reg.reset_all()
	for i in range(8):
		_reg.record_choice(_make_card("rc_%d" % i), 0, _make_ctx())
	var ctx: Dictionary = _reg.get_context_for_llm()
	if ctx.recent_choices.size() > 5:
		return _fail("recent_choices should be at most 5, got %d" % ctx.recent_choices.size())
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 11. GET CALLBACK NPCS
# ─────────────────────────────────────────────────────────────────────────────

func test_get_callback_npcs_empty_initially() -> bool:
	_reg.reset_all()
	if _reg.get_callback_npcs().size() != 0:
		return _fail("callback_npcs should be empty with no history")
	return true


func test_get_callback_npcs_requires_10_cards_gap() -> bool:
	_reg.reset_all()
	# Record interaction with npc then record 9 more cards (gap = 9, not enough)
	var card_npc := _make_card("npc_card", ["help"], "npc_recall")
	_reg.record_choice(card_npc, 1, _make_ctx())
	for i in range(9):
		_reg.record_choice(_make_card("filler_%d" % i), 0, _make_ctx())
	# manually set karma high enough
	_reg.npc_karma["npc_recall"] = 25
	var callbacks: Array = _reg.get_callback_npcs()
	var found := false
	for cb in callbacks:
		if cb.npc_id == "npc_recall":
			found = true
	if found:
		return _fail("NPC with only 9-card gap should NOT appear in callbacks (need >= 10)")
	return true


func test_get_callback_npcs_includes_relationship() -> bool:
	_reg.reset_all()
	_reg.npc_karma["npc_friend"] = 30
	_reg.npc_last_seen["npc_friend"] = 0
	# Add 10+ filler cards so current_run.size() - 0 >= 10
	for i in range(10):
		_reg.record_choice(_make_card("filler_%d" % i), 0, _make_ctx())
	var callbacks: Array = _reg.get_callback_npcs()
	var cb_npc: Dictionary = {}
	for cb in callbacks:
		if cb.npc_id == "npc_friend":
			cb_npc = cb
	if cb_npc.is_empty():
		return _fail("npc_friend should appear in callbacks (karma=30, 10 cards since seen)")
	if not cb_npc.has("relationship"):
		return _fail("callback entry should contain 'relationship' key")
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 12. ON RUN END — PROMISE TRACKING
# ─────────────────────────────────────────────────────────────────────────────

func test_on_run_end_updates_promise_acceptance_rate() -> bool:
	_reg.reset_all()
	# 2 promises accepted (option=1), 2 declined (option=0) → rate = 0.5
	for i in range(2):
		_reg.record_choice(_make_card("pr_yes_%d" % i, ["promise"]), 1, _make_ctx())
	for i in range(2):
		_reg.record_choice(_make_card("pr_no_%d" % i, ["promise"]), 0, _make_ctx())
	_reg.on_run_end({"final_gauges": {}, "victory": false})
	var rate: float = _reg.historical_summary.promise_acceptance_rate
	if not is_equal_approx(rate, 0.5):
		return _fail("Promise acceptance rate should be 0.5, got %f" % rate)
	return true


func test_on_run_end_resets_current_run() -> bool:
	_reg.reset_all()
	for i in range(3):
		_reg.record_choice(_make_card("end_%d" % i), 0, _make_ctx())
	_reg.on_run_end({"final_gauges": {}, "victory": true})
	if _reg.current_run.size() != 0:
		return _fail("current_run should be empty after on_run_end")
	return true


func test_on_run_end_tracks_death_gauge() -> bool:
	_reg.reset_all()
	_reg.record_choice(_make_card("death_card"), 0, _make_ctx())
	_reg.on_run_end({"final_gauges": {"vigueur": 0}, "victory": false})
	if _reg.historical_summary.most_common_death_gauge != "vigueur":
		return _fail("most_common_death_gauge should be 'vigueur', got '%s'" % _reg.historical_summary.most_common_death_gauge)
	return true


func test_on_run_end_victory_does_not_update_avg_gauge_at_death() -> bool:
	_reg.reset_all()
	_reg.record_choice(_make_card("win_card"), 0, _make_ctx())
	_reg.on_run_end({"final_gauges": {"vigueur": 5}, "victory": true})
	# No death_count entry expected
	var death_count: int = _reg.historical_summary.get("death_count", 0)
	if death_count != 0:
		return _fail("Victory run should NOT increment death_count, got %d" % death_count)
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 13. GET PATTERN FOR LLM (text generation)
# ─────────────────────────────────────────────────────────────────────────────

func test_get_pattern_for_llm_empty_when_no_patterns() -> bool:
	_reg.reset_all()
	var txt: String = _reg.get_pattern_for_llm()
	if txt != "":
		return _fail("get_pattern_for_llm should return empty string when no patterns detected")
	return true


func test_get_pattern_for_llm_returns_string() -> bool:
	_reg.reset_all()
	var card := _make_card("llm_p", ["stranger", "help_request"])
	for i in range(5):
		_reg.record_choice(card, 1, _make_ctx())
	var txt: String = _reg.get_pattern_for_llm()
	if not (txt is String):
		return _fail("get_pattern_for_llm should return a String")
	return true


func test_get_pattern_for_llm_mentions_pattern() -> bool:
	_reg.reset_all()
	var card := _make_card("llm_p2", ["stranger", "help_request"])
	for i in range(5):
		_reg.record_choice(card, 1, _make_ctx())
	var txt: String = _reg.get_pattern_for_llm()
	if txt.is_empty():
		return _fail("get_pattern_for_llm should produce non-empty text after pattern 'always_helps_strangers' is detected")
	return true
