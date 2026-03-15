## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — Confiance Merlin (Trust System)
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: tier calculation, clamping 0-100, mid-run immediate change,
## card filtering by trust tier, persistence, edge cases, signal emission.
## Pattern: extends RefCounted, each test returns bool, run_all() aggregates.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_store_state() -> Dictionary:
	return {
		"meta": {
			"trust_merlin": 0,
			"anam": 0,
			"total_runs": 0,
			"faction_rep": {
				"druides": 0.0, "anciens": 0.0, "korrigans": 0.0,
				"niamh": 0.0, "ankou": 0.0,
			},
		},
		"run": {
			"life_essence": 100,
			"active": true,
		},
		"effect_log": [],
	}


func _set_trust(state: Dictionary, value: int) -> void:
	var meta: Dictionary = state.get("meta", {})
	meta["trust_merlin"] = value
	state["meta"] = meta


func _get_trust(state: Dictionary) -> int:
	return int(state.get("meta", {}).get("trust_merlin", 0))


# ═══════════════════════════════════════════════════════════════════════════════
# TIER CALCULATION — T0 (0-24), T1 (25-49), T2 (50-74), T3 (75-100)
# ═══════════════════════════════════════════════════════════════════════════════

func test_tier_t0_at_zero() -> bool:
	var tiers: Dictionary = MerlinConstants.TRUST_TIERS
	var tier: Dictionary = tiers.get("T0", {})
	if int(tier.get("range_min", -1)) != 0:
		push_error("T0 range_min should be 0")
		return false
	if int(tier.get("range_max", -1)) != 24:
		push_error("T0 range_max should be 24")
		return false
	return true


func test_tier_t1_range() -> bool:
	var tier: Dictionary = MerlinConstants.TRUST_TIERS.get("T1", {})
	if int(tier.get("range_min", -1)) != 25 or int(tier.get("range_max", -1)) != 49:
		push_error("T1 should be 25-49, got %d-%d" % [tier.get("range_min", -1), tier.get("range_max", -1)])
		return false
	return true


func test_tier_t2_range() -> bool:
	var tier: Dictionary = MerlinConstants.TRUST_TIERS.get("T2", {})
	if int(tier.get("range_min", -1)) != 50 or int(tier.get("range_max", -1)) != 74:
		push_error("T2 should be 50-74")
		return false
	return true


func test_tier_t3_range() -> bool:
	var tier: Dictionary = MerlinConstants.TRUST_TIERS.get("T3", {})
	if int(tier.get("range_min", -1)) != 75 or int(tier.get("range_max", -1)) != 100:
		push_error("T3 should be 75-100")
		return false
	return true


func test_tier_boundary_24_is_t0() -> bool:
	# Value 24 should be T0 (0-24)
	var tiers: Dictionary = MerlinConstants.TRUST_TIERS
	var tier: Dictionary = tiers.get("T0", {})
	var in_t0: bool = 24 >= int(tier.get("range_min", 0)) and 24 <= int(tier.get("range_max", 0))
	if not in_t0:
		push_error("Trust 24 should be in T0")
		return false
	return true


func test_tier_boundary_25_is_t1() -> bool:
	# Value 25 should be T1 (25-49)
	var tier: Dictionary = MerlinConstants.TRUST_TIERS.get("T1", {})
	var in_t1: bool = 25 >= int(tier.get("range_min", 0)) and 25 <= int(tier.get("range_max", 0))
	if not in_t1:
		push_error("Trust 25 should be in T1")
		return false
	return true


func test_tier_boundary_75_is_t3() -> bool:
	# Value 75 should be T3 (75-100)
	var tier: Dictionary = MerlinConstants.TRUST_TIERS.get("T3", {})
	var in_t3: bool = 75 >= int(tier.get("range_min", 0)) and 75 <= int(tier.get("range_max", 0))
	if not in_t3:
		push_error("Trust 75 should be in T3")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CLAMPING — Trust must stay 0-100
# ═══════════════════════════════════════════════════════════════════════════════

func test_clamp_lower_bound() -> bool:
	# clampi(0 + (-10), 0, 100) should be 0
	var result: int = clampi(0 + (-10), 0, 100)
	if result != 0:
		push_error("Clamp lower: expected 0, got %d" % result)
		return false
	return true


func test_clamp_upper_bound() -> bool:
	# clampi(95 + 20, 0, 100) should be 100
	var result: int = clampi(95 + 20, 0, 100)
	if result != 100:
		push_error("Clamp upper: expected 100, got %d" % result)
		return false
	return true


func test_clamp_large_negative_stays_zero() -> bool:
	var result: int = clampi(10 + (-500), 0, 100)
	if result != 0:
		push_error("Large negative clamp: expected 0, got %d" % result)
		return false
	return true


func test_clamp_large_positive_stays_hundred() -> bool:
	var result: int = clampi(50 + 500, 0, 100)
	if result != 100:
		push_error("Large positive clamp: expected 100, got %d" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TRUST DELTAS — Constants from bible v2.4
# ═══════════════════════════════════════════════════════════════════════════════

func test_trust_delta_promise_kept_is_10() -> bool:
	var delta: int = int(MerlinConstants.TRUST_DELTAS.get("promise_kept", 0))
	if delta != 10:
		push_error("promise_kept delta should be 10, got %d" % delta)
		return false
	return true


func test_trust_delta_promise_broken_is_neg15() -> bool:
	var delta: int = int(MerlinConstants.TRUST_DELTAS.get("promise_broken", 0))
	if delta != -15:
		push_error("promise_broken delta should be -15, got %d" % delta)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MID-RUN CHANGE — Trust changes immediately, not deferred
# ═══════════════════════════════════════════════════════════════════════════════

func test_mid_run_trust_change_immediate() -> bool:
	# Simulate: trust starts at 20, apply +10 → should be 30 immediately
	var old: int = 20
	var delta: int = 10
	var new_val: int = clampi(old + delta, 0, 100)
	if new_val != 30:
		push_error("Mid-run: expected 30, got %d" % new_val)
		return false
	return true


func test_mid_run_tier_changes_after_delta() -> bool:
	# Trust at 23 (T0), apply +5 → 28 (T1). Tier should change mid-run.
	var old: int = 23
	var new_val: int = clampi(old + 5, 0, 100)
	# Check new tier
	var found_tier: String = ""
	for tier_key in MerlinConstants.TRUST_TIERS:
		var tier: Dictionary = MerlinConstants.TRUST_TIERS[tier_key]
		if new_val >= int(tier.get("range_min", 0)) and new_val <= int(tier.get("range_max", 100)):
			found_tier = tier_key
			break
	if found_tier != "T1":
		push_error("After +5 from 23, tier should be T1, got %s" % found_tier)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CARD FILTERING — merlin_direct cards filtered by trust_tier_min
# ═══════════════════════════════════════════════════════════════════════════════

func test_trust_tier_to_index_t0() -> bool:
	var idx: int = MerlinCardSystem._trust_tier_to_index("T0")
	if idx != 0:
		push_error("T0 index should be 0, got %d" % idx)
		return false
	return true


func test_trust_tier_to_index_t3() -> bool:
	var idx: int = MerlinCardSystem._trust_tier_to_index("T3")
	if idx != 3:
		push_error("T3 index should be 3, got %d" % idx)
		return false
	return true


func test_trust_tier_to_index_invalid_defaults_t0() -> bool:
	var idx: int = MerlinCardSystem._trust_tier_to_index("T99")
	if idx != 0:
		push_error("Invalid tier should default to 0, got %d" % idx)
		return false
	return true


func test_card_filter_t0_sees_only_t0_cards() -> bool:
	# Simulate: pool has T0 and T2 cards. At T0, only T0 cards visible.
	var pool: Array = [
		{"id": "md_001", "trust_tier_min": "T0", "text": "a", "options": []},
		{"id": "md_002", "trust_tier_min": "T2", "text": "b", "options": []},
	]
	var tier_index: int = MerlinCardSystem._trust_tier_to_index("T0")
	var visible: Array = []
	for card in pool:
		var required: String = str(card.get("trust_tier_min", "T0"))
		if MerlinCardSystem._trust_tier_to_index(required) <= tier_index:
			visible.append(card)
	if visible.size() != 1:
		push_error("T0 should see 1 card, got %d" % visible.size())
		return false
	if str(visible[0].get("id", "")) != "md_001":
		push_error("T0 should see md_001")
		return false
	return true


func test_card_filter_t2_sees_t0_t1_t2_cards() -> bool:
	var pool: Array = [
		{"id": "md_001", "trust_tier_min": "T0"},
		{"id": "md_002", "trust_tier_min": "T1"},
		{"id": "md_003", "trust_tier_min": "T2"},
		{"id": "md_004", "trust_tier_min": "T3"},
	]
	var tier_index: int = MerlinCardSystem._trust_tier_to_index("T2")
	var visible: Array = []
	for card in pool:
		var required: String = str(card.get("trust_tier_min", "T0"))
		if MerlinCardSystem._trust_tier_to_index(required) <= tier_index:
			visible.append(card)
	if visible.size() != 3:
		push_error("T2 should see 3 cards (T0+T1+T2), got %d" % visible.size())
		return false
	return true


func test_card_filter_t3_sees_all_cards() -> bool:
	var pool: Array = [
		{"id": "md_001", "trust_tier_min": "T0"},
		{"id": "md_002", "trust_tier_min": "T1"},
		{"id": "md_003", "trust_tier_min": "T2"},
		{"id": "md_004", "trust_tier_min": "T3"},
	]
	var tier_index: int = MerlinCardSystem._trust_tier_to_index("T3")
	var visible: Array = []
	for card in pool:
		var required: String = str(card.get("trust_tier_min", "T0"))
		if MerlinCardSystem._trust_tier_to_index(required) <= tier_index:
			visible.append(card)
	if visible.size() != 4:
		push_error("T3 should see all 4 cards, got %d" % visible.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PERSISTENCE — trust_merlin in profile meta
# ═══════════════════════════════════════════════════════════════════════════════

func test_default_profile_trust_is_zero() -> bool:
	var state: Dictionary = _make_store_state()
	var trust: int = _get_trust(state)
	if trust != 0:
		push_error("Default trust should be 0, got %d" % trust)
		return false
	return true


func test_trust_persists_after_set() -> bool:
	var state: Dictionary = _make_store_state()
	_set_trust(state, 42)
	var trust: int = _get_trust(state)
	if trust != 42:
		push_error("Trust should persist as 42, got %d" % trust)
		return false
	return true


func test_save_system_default_has_trust_merlin() -> bool:
	# Save system profile must include trust_merlin in meta
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	save.reset_profile()
	var meta: Dictionary = save.load_or_create_profile()
	if not meta.has("trust_merlin"):
		push_error("Default profile meta missing trust_merlin key")
		save.reset_profile()
		return false
	if int(meta.get("trust_merlin", -1)) != 0:
		push_error("Default trust_merlin should be 0")
		save.reset_profile()
		return false
	save.reset_profile()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EDGE CASES
# ═══════════════════════════════════════════════════════════════════════════════

func test_zero_delta_no_change() -> bool:
	var old: int = 50
	var new_val: int = clampi(old + 0, 0, 100)
	if new_val != 50:
		push_error("Zero delta: expected 50, got %d" % new_val)
		return false
	return true


func test_exact_boundary_100() -> bool:
	var val: int = clampi(100, 0, 100)
	# 100 should be in T3
	var tier: Dictionary = MerlinConstants.TRUST_TIERS.get("T3", {})
	var in_t3: bool = val >= int(tier.get("range_min", 0)) and val <= int(tier.get("range_max", 0))
	if not in_t3:
		push_error("Trust 100 should be T3")
		return false
	return true


func test_exact_boundary_0() -> bool:
	var val: int = clampi(0, 0, 100)
	var tier: Dictionary = MerlinConstants.TRUST_TIERS.get("T0", {})
	var in_t0: bool = val >= int(tier.get("range_min", 0)) and val <= int(tier.get("range_max", 0))
	if not in_t0:
		push_error("Trust 0 should be T0")
		return false
	return true


func test_successive_deltas_accumulate() -> bool:
	# 0 → +30 → +30 → +30 = 90 (not 100 because no clamp needed yet)
	var trust: int = 0
	trust = clampi(trust + 30, 0, 100)
	trust = clampi(trust + 30, 0, 100)
	trust = clampi(trust + 30, 0, 100)
	if trust != 90:
		push_error("Successive +30: expected 90, got %d" % trust)
		return false
	return true


func test_successive_deltas_clamp_at_100() -> bool:
	# 0 → +40 → +40 → +40 = 100 (clamped)
	var trust: int = 0
	trust = clampi(trust + 40, 0, 100)
	trust = clampi(trust + 40, 0, 100)
	trust = clampi(trust + 40, 0, 100)
	if trust != 100:
		push_error("Successive +40 clamped: expected 100, got %d" % trust)
		return false
	return true


func test_negative_deltas_clamp_at_zero() -> bool:
	# 30 → -20 → -20 = 0 (clamped, not -10)
	var trust: int = 30
	trust = clampi(trust + (-20), 0, 100)
	trust = clampi(trust + (-20), 0, 100)
	if trust != 0:
		push_error("Negative deltas clamped: expected 0, got %d" % trust)
		return false
	return true


func test_all_four_tiers_covered() -> bool:
	# Verify no gap in tier ranges: 0-24, 25-49, 50-74, 75-100
	var expected: Array = [
		{"key": "T0", "min": 0, "max": 24},
		{"key": "T1", "min": 25, "max": 49},
		{"key": "T2", "min": 50, "max": 74},
		{"key": "T3", "min": 75, "max": 100},
	]
	for e in expected:
		var tier: Dictionary = MerlinConstants.TRUST_TIERS.get(str(e["key"]), {})
		if int(tier.get("range_min", -1)) != int(e["min"]):
			push_error("Tier %s range_min mismatch" % str(e["key"]))
			return false
		if int(tier.get("range_max", -1)) != int(e["max"]):
			push_error("Tier %s range_max mismatch" % str(e["key"]))
			return false
	return true


func test_tier_labels_exist() -> bool:
	# Each tier must have a label for UI display
	for tier_key in MerlinConstants.TRUST_TIERS:
		var tier: Dictionary = MerlinConstants.TRUST_TIERS[tier_key]
		var label: String = str(tier.get("label", ""))
		if label.is_empty():
			push_error("Tier %s missing label" % tier_key)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> void:
	var tests: Array[Callable] = [
		# Tier calculation
		test_tier_t0_at_zero,
		test_tier_t1_range,
		test_tier_t2_range,
		test_tier_t3_range,
		test_tier_boundary_24_is_t0,
		test_tier_boundary_25_is_t1,
		test_tier_boundary_75_is_t3,
		test_all_four_tiers_covered,
		test_tier_labels_exist,
		# Clamping
		test_clamp_lower_bound,
		test_clamp_upper_bound,
		test_clamp_large_negative_stays_zero,
		test_clamp_large_positive_stays_hundred,
		# Trust deltas
		test_trust_delta_promise_kept_is_10,
		test_trust_delta_promise_broken_is_neg15,
		# Mid-run immediate change
		test_mid_run_trust_change_immediate,
		test_mid_run_tier_changes_after_delta,
		# Card filtering by tier
		test_trust_tier_to_index_t0,
		test_trust_tier_to_index_t3,
		test_trust_tier_to_index_invalid_defaults_t0,
		test_card_filter_t0_sees_only_t0_cards,
		test_card_filter_t2_sees_t0_t1_t2_cards,
		test_card_filter_t3_sees_all_cards,
		# Persistence
		test_default_profile_trust_is_zero,
		test_trust_persists_after_set,
		test_save_system_default_has_trust_merlin,
		# Edge cases
		test_zero_delta_no_change,
		test_exact_boundary_100,
		test_exact_boundary_0,
		test_successive_deltas_accumulate,
		test_successive_deltas_clamp_at_100,
		test_negative_deltas_clamp_at_zero,
	]

	var passed: int = 0
	var failed: int = 0

	for test in tests:
		var ok: bool = test.call()
		if ok:
			passed += 1
		else:
			failed += 1
			push_error("[FAIL] %s" % test.get_method())

	print("[test_confiance_merlin] Results: %d/%d passed" % [passed, passed + failed])
	if failed > 0:
		push_error("[test_confiance_merlin] %d test(s) FAILED" % failed)
	else:
		print("[test_confiance_merlin] All tests passed.")
