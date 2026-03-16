## =============================================================================
## Unit Tests — MerlinPromiseSystem
## =============================================================================
## Tests: create_promise, resolve_promise, check_promises, tracking updates,
## condition evaluation (all 7 types), edge cases, max cap, duplicates.
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error on fail.
## =============================================================================
## Coverage: 46 tests
##   - create_promise            : 10 tests (valid data, cap, duplicates, fields)
##   - resolve_promise           :  5 tests (kept/broken trust deltas, id passthrough)
##   - check_promises            :  8 tests (deadline, kept/broken, cleanup, boundary)
##   - update_promise_tracking   :  7 tests (all 6 event types + no-promise no-crash)
##   - _evaluate_promise_condition: 11 tests (all 7 types, boundary, unknown, wrong faction)
##   - edge cases + integration  :  5 tests (non-dict, missing key, multi-faction, all promises, lifecycle)
## =============================================================================

extends RefCounted


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _make_run_state(cards: int = 0, life: int = 80) -> Dictionary:
	return {
		"card_index": cards,
		"life_essence": life,
		"active_promises": [],
		"promise_tracking": {},
	}


func _make_promise_data(overrides: Dictionary = {}) -> Dictionary:
	var data: Dictionary = {
		"promise_id": "test_promise_1",
		"deadline_cards": 5,
		"condition_type": "life_above",
		"condition_value": 50,
		"condition_faction": "",
		"reward_trust": 10,
		"penalty_trust": -15,
		"description": "Test promise",
	}
	for key in overrides:
		data[key] = overrides[key]
	return data


# ─────────────────────────────────────────────────────────────────────────────
# GROUP 1 — create_promise
# ─────────────────────────────────────────────────────────────────────────────

func test_create_promise_returns_true_on_valid_data() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	var ok: bool = sys.create_promise(run, _make_promise_data())
	if not ok:
		push_error("create_promise should return true on valid data")
		return false
	return true


func test_create_promise_appends_to_active_promises() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	var active: Array = run.get("active_promises", [])
	if active.size() != 1:
		push_error("active_promises should have 1 entry, got %d" % active.size())
		return false
	return true


func test_create_promise_stores_deadline_relative_to_card_index() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state(3)
	sys.create_promise(run, _make_promise_data({"deadline_cards": 7}))
	var p: Dictionary = run["active_promises"][0]
	var expected_deadline: int = 3 + 7
	if int(p.get("deadline_card", -1)) != expected_deadline:
		push_error("deadline_card: expected %d (3+7), got %d" % [expected_deadline, int(p.get("deadline_card", -1))])
		return false
	return true


func test_create_promise_stores_created_at_card() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state(5)
	sys.create_promise(run, _make_promise_data())
	var p: Dictionary = run["active_promises"][0]
	if int(p.get("created_at_card", -1)) != 5:
		push_error("created_at_card: expected 5, got %d" % int(p.get("created_at_card", -1)))
		return false
	return true


func test_create_promise_stores_condition_type_and_value() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({
		"condition_type": "minigame_wins",
		"condition_value": 3,
	}))
	var p: Dictionary = run["active_promises"][0]
	if str(p.get("condition_type", "")) != "minigame_wins":
		push_error("condition_type stored incorrectly: '%s'" % p.get("condition_type", ""))
		return false
	if int(p.get("condition_value", -1)) != 3:
		push_error("condition_value stored incorrectly: %d" % int(p.get("condition_value", -1)))
		return false
	return true


func test_create_promise_initializes_all_tracking_counters() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	var tracking: Dictionary = run.get("promise_tracking", {})
	if not tracking.has("test_promise_1"):
		push_error("promise_tracking should have entry for 'test_promise_1'")
		return false
	var track: Dictionary = tracking["test_promise_1"]
	if int(track.get("minigame_wins", -1)) != 0:
		push_error("tracking minigame_wins should init to 0, got %d" % int(track.get("minigame_wins", -1)))
		return false
	if int(track.get("healing_done", -1)) != 0:
		push_error("tracking healing_done should init to 0, got %d" % int(track.get("healing_done", -1)))
		return false
	if int(track.get("damage_taken", -1)) != 0:
		push_error("tracking damage_taken should init to 0, got %d" % int(track.get("damage_taken", -1)))
		return false
	if int(track.get("safe_choices", -1)) != 0:
		push_error("tracking safe_choices should init to 0, got %d" % int(track.get("safe_choices", -1)))
		return false
	var tags: Array = track.get("tags_acquired", [])
	if tags.size() != 0:
		push_error("tracking tags_acquired should init to empty array, got %d entries" % tags.size())
		return false
	return true


func test_create_promise_rejects_empty_id() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	var ok: bool = sys.create_promise(run, _make_promise_data({"promise_id": ""}))
	if ok:
		push_error("create_promise should reject empty promise_id")
		return false
	if run.get("active_promises", []).size() != 0:
		push_error("active_promises should remain empty after rejected empty id")
		return false
	return true


func test_create_promise_rejects_duplicate_id() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	var ok: bool = sys.create_promise(run, _make_promise_data())
	if ok:
		push_error("create_promise should reject duplicate promise_id")
		return false
	if run["active_promises"].size() != 1:
		push_error("active_promises should still have 1 entry after duplicate, got %d" % run["active_promises"].size())
		return false
	return true


func test_create_promise_caps_at_max_active() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({"promise_id": "p1"}))
	sys.create_promise(run, _make_promise_data({"promise_id": "p2"}))
	var ok: bool = sys.create_promise(run, _make_promise_data({"promise_id": "p3"}))
	if ok:
		push_error("create_promise should return false when at max (%d)" % MerlinConstants.MAX_ACTIVE_PROMISES)
		return false
	if run["active_promises"].size() != MerlinConstants.MAX_ACTIVE_PROMISES:
		push_error("active_promises should have %d entries, got %d" % [MerlinConstants.MAX_ACTIVE_PROMISES, run["active_promises"].size()])
		return false
	return true


func test_create_promise_second_slot_allowed() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({"promise_id": "p1"}))
	var ok: bool = sys.create_promise(run, _make_promise_data({"promise_id": "p2"}))
	if not ok:
		push_error("create_promise should allow second promise (max is %d)" % MerlinConstants.MAX_ACTIVE_PROMISES)
		return false
	if run["active_promises"].size() != 2:
		push_error("active_promises should have 2 entries, got %d" % run["active_promises"].size())
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# GROUP 2 — resolve_promise
# ─────────────────────────────────────────────────────────────────────────────

func test_resolve_promise_kept_trust_delta() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var result: Dictionary = sys.resolve_promise("p1", true)
	var expected: int = int(MerlinConstants.TRUST_DELTAS.get("promise_kept", 10))
	if int(result.get("trust_delta", 0)) != expected:
		push_error("resolve kept: trust_delta expected %d, got %d" % [expected, int(result.get("trust_delta", 0))])
		return false
	return true


func test_resolve_promise_broken_trust_delta() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var result: Dictionary = sys.resolve_promise("p1", false)
	var expected: int = int(MerlinConstants.TRUST_DELTAS.get("promise_broken", -15))
	if int(result.get("trust_delta", 0)) != expected:
		push_error("resolve broken: trust_delta expected %d, got %d" % [expected, int(result.get("trust_delta", 0))])
		return false
	return true


func test_resolve_promise_returns_kept_flag_true() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var result: Dictionary = sys.resolve_promise("x", true)
	if not result.get("kept", false):
		push_error("resolve: kept should be true when kept=true")
		return false
	return true


func test_resolve_promise_returns_kept_flag_false() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var result: Dictionary = sys.resolve_promise("x", false)
	if result.get("kept", true):
		push_error("resolve: kept should be false when kept=false")
		return false
	return true


func test_resolve_promise_passthrough_id() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var result: Dictionary = sys.resolve_promise("my_promise_id", true)
	if str(result.get("promise_id", "")) != "my_promise_id":
		push_error("resolve: promise_id should pass through, got '%s'" % str(result.get("promise_id", "")))
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# GROUP 3 — check_promises
# ─────────────────────────────────────────────────────────────────────────────

func test_check_promises_empty_active_returns_empty() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	var results: Array = sys.check_promises(run)
	if results.size() != 0:
		push_error("check_promises on empty active_promises should return 0 results, got %d" % results.size())
		return false
	return true


func test_check_promises_before_deadline_stays_active() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	# card_index=2, deadline_cards=5 => deadline_card=5; card_index < 5 so not expired
	var run: Dictionary = _make_run_state(2)
	sys.create_promise(run, _make_promise_data({"deadline_cards": 5}))
	var results: Array = sys.check_promises(run)
	if results.size() != 0:
		push_error("check_promises: promise not expired (card 2 < deadline 5), expected 0 results, got %d" % results.size())
		return false
	if run["active_promises"].size() != 1:
		push_error("check_promises: promise should remain active, got %d" % run["active_promises"].size())
		return false
	return true


func test_check_promises_at_exact_deadline_resolves() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	# card_index=0, deadline_cards=3 => deadline_card=3; advance to card_index=3
	var run: Dictionary = _make_run_state(0, 80)
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 3,
		"condition_type": "life_above",
		"condition_value": 50,
	}))
	run["card_index"] = 3
	var results: Array = sys.check_promises(run)
	if results.size() != 1:
		push_error("check expired at exact deadline: expected 1 result, got %d" % results.size())
		return false
	return true


func test_check_promises_expired_kept_when_condition_met() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state(0, 80)
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 3,
		"condition_type": "life_above",
		"condition_value": 50,
	}))
	run["card_index"] = 3
	var results: Array = sys.check_promises(run)
	if not results[0].get("kept", false):
		push_error("life_essence=80 >= 50: promise should be kept")
		return false
	return true


func test_check_promises_expired_broken_when_condition_not_met() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state(0, 30)
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 2,
		"condition_type": "life_above",
		"condition_value": 50,
	}))
	run["card_index"] = 2
	var results: Array = sys.check_promises(run)
	if results.size() != 1 or results[0].get("kept", true):
		push_error("life_essence=30 < 50: promise should be broken")
		return false
	return true


func test_check_promises_removes_resolved_from_active() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({"deadline_cards": 1}))
	run["card_index"] = 1
	sys.check_promises(run)
	if run["active_promises"].size() != 0:
		push_error("check_promises: resolved promise should be removed from active_promises")
		return false
	return true


func test_check_promises_cleans_tracking_entry() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({"deadline_cards": 1}))
	run["card_index"] = 1
	sys.check_promises(run)
	var tracking: Dictionary = run.get("promise_tracking", {})
	if tracking.has("test_promise_1"):
		push_error("check_promises should erase tracking entry for resolved promise")
		return false
	return true


func test_check_promises_two_promises_one_expires() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state(0, 80)
	sys.create_promise(run, _make_promise_data({"promise_id": "short", "deadline_cards": 2}))
	sys.create_promise(run, _make_promise_data({"promise_id": "long", "deadline_cards": 10}))
	run["card_index"] = 2
	var results: Array = sys.check_promises(run)
	if results.size() != 1:
		push_error("check_promises: only 1 should expire, got %d" % results.size())
		return false
	if str(results[0].get("promise_id", "")) != "short":
		push_error("check_promises: 'short' should have expired, got '%s'" % str(results[0].get("promise_id", "")))
		return false
	if run["active_promises"].size() != 1:
		push_error("check_promises: 'long' should remain active, got %d" % run["active_promises"].size())
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# GROUP 4 — update_promise_tracking
# ─────────────────────────────────────────────────────────────────────────────

func test_tracking_faction_gain_accumulates() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	sys.update_promise_tracking(run, "faction_gain", {"faction": "druides", "amount": 5})
	sys.update_promise_tracking(run, "faction_gain", {"faction": "druides", "amount": 3})
	var track: Dictionary = run["promise_tracking"]["test_promise_1"]
	var gained: float = float(track.get("faction_gained", {}).get("druides", 0.0))
	if abs(gained - 8.0) > 0.01:
		push_error("faction_gain should accumulate to 8.0, got %f" % gained)
		return false
	return true


func test_tracking_minigame_win_increments() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	sys.update_promise_tracking(run, "minigame_win", {})
	sys.update_promise_tracking(run, "minigame_win", {})
	var track: Dictionary = run["promise_tracking"]["test_promise_1"]
	if int(track.get("minigame_wins", 0)) != 2:
		push_error("minigame_wins should be 2 after 2 wins, got %d" % int(track.get("minigame_wins", 0)))
		return false
	return true


func test_tracking_healing_accumulates() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	sys.update_promise_tracking(run, "healing", {"amount": 10})
	sys.update_promise_tracking(run, "healing", {"amount": 8})
	var track: Dictionary = run["promise_tracking"]["test_promise_1"]
	if int(track.get("healing_done", 0)) != 18:
		push_error("healing_done should be 18, got %d" % int(track.get("healing_done", 0)))
		return false
	return true


func test_tracking_damage_increments_by_hit_not_amount() -> bool:
	# damage event increments damage_taken by 1 per event, not by data.amount
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	sys.update_promise_tracking(run, "damage", {})
	sys.update_promise_tracking(run, "damage", {})
	var track: Dictionary = run["promise_tracking"]["test_promise_1"]
	if int(track.get("damage_taken", 0)) != 2:
		push_error("damage_taken should be 2 after 2 hits, got %d" % int(track.get("damage_taken", 0)))
		return false
	return true


func test_tracking_safe_choice_increments() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	sys.update_promise_tracking(run, "safe_choice", {})
	sys.update_promise_tracking(run, "safe_choice", {})
	sys.update_promise_tracking(run, "safe_choice", {})
	var track: Dictionary = run["promise_tracking"]["test_promise_1"]
	if int(track.get("safe_choices", 0)) != 3:
		push_error("safe_choices should be 3, got %d" % int(track.get("safe_choices", 0)))
		return false
	return true


func test_tracking_tag_acquired_no_duplicates() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	sys.update_promise_tracking(run, "tag_acquired", {"tag": "brave"})
	sys.update_promise_tracking(run, "tag_acquired", {"tag": "brave"})
	var tags: Array = run["promise_tracking"]["test_promise_1"].get("tags_acquired", [])
	if tags.size() != 1:
		push_error("tag_acquired should not store duplicates, got %d entries" % tags.size())
		return false
	return true


func test_tracking_update_with_no_promises_does_not_crash() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	# No promises created; update should iterate over nothing and not crash
	sys.update_promise_tracking(run, "minigame_win", {})
	sys.update_promise_tracking(run, "faction_gain", {"faction": "druides", "amount": 5})
	sys.update_promise_tracking(run, "damage", {})
	return true


# ─────────────────────────────────────────────────────────────────────────────
# GROUP 5 — _evaluate_promise_condition (tested through check_promises)
# ─────────────────────────────────────────────────────────────────────────────

func test_condition_life_above_met_at_boundary() -> bool:
	# life_essence == condition_value exactly should be kept (>=)
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state(0, 50)
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 1,
		"condition_type": "life_above",
		"condition_value": 50,
	}))
	run["card_index"] = 1
	var results: Array = sys.check_promises(run)
	if not results[0].get("kept", false):
		push_error("life_above boundary: life=50 >= 50 should be kept")
		return false
	return true


func test_condition_life_above_broken_just_below() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state(0, 49)
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 1,
		"condition_type": "life_above",
		"condition_value": 50,
	}))
	run["card_index"] = 1
	var results: Array = sys.check_promises(run)
	if results[0].get("kept", true):
		push_error("life_above boundary: life=49 < 50 should be broken")
		return false
	return true


func test_condition_faction_gain_met() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 2,
		"condition_type": "faction_gain",
		"condition_value": 10,
		"condition_faction": "druides",
	}))
	sys.update_promise_tracking(run, "faction_gain", {"faction": "druides", "amount": 12})
	run["card_index"] = 2
	var results: Array = sys.check_promises(run)
	if results.size() != 1 or not results[0].get("kept", false):
		push_error("faction_gain: 12 >= 10, should be kept")
		return false
	return true


func test_condition_faction_gain_broken_wrong_faction() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 2,
		"condition_type": "faction_gain",
		"condition_value": 5,
		"condition_faction": "anciens",
	}))
	# Gain in a different faction
	sys.update_promise_tracking(run, "faction_gain", {"faction": "druides", "amount": 20})
	run["card_index"] = 2
	var results: Array = sys.check_promises(run)
	if results.size() != 1 or results[0].get("kept", true):
		push_error("faction_gain: gain was in 'druides' but condition is 'anciens', should be broken")
		return false
	return true


func test_condition_minigame_wins_met() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 3,
		"condition_type": "minigame_wins",
		"condition_value": 2,
	}))
	sys.update_promise_tracking(run, "minigame_win", {})
	sys.update_promise_tracking(run, "minigame_win", {})
	run["card_index"] = 3
	var results: Array = sys.check_promises(run)
	if results.size() != 1 or not results[0].get("kept", false):
		push_error("minigame_wins: 2 >= 2, should be kept")
		return false
	return true


func test_condition_no_safe_kept_with_zero_safe_choices() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 2,
		"condition_type": "no_safe",
	}))
	run["card_index"] = 2
	var results: Array = sys.check_promises(run)
	if results.size() != 1 or not results[0].get("kept", false):
		push_error("no_safe: 0 safe choices, should be kept")
		return false
	return true


func test_condition_no_safe_broken_when_safe_choice_made() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 2,
		"condition_type": "no_safe",
	}))
	sys.update_promise_tracking(run, "safe_choice", {})
	run["card_index"] = 2
	var results: Array = sys.check_promises(run)
	if results.size() != 1 or results[0].get("kept", true):
		push_error("no_safe: 1 safe choice made, should be broken")
		return false
	return true


func test_condition_tag_acquired_met() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 2,
		"condition_type": "tag_acquired",
		"condition_value": "hero",
	}))
	sys.update_promise_tracking(run, "tag_acquired", {"tag": "hero"})
	run["card_index"] = 2
	var results: Array = sys.check_promises(run)
	if results.size() != 1 or not results[0].get("kept", false):
		push_error("tag_acquired: 'hero' acquired, should be kept")
		return false
	return true


func test_condition_accept_damage_met() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 3,
		"condition_type": "accept_damage",
		"condition_value": 2,
	}))
	sys.update_promise_tracking(run, "damage", {})
	sys.update_promise_tracking(run, "damage", {})
	run["card_index"] = 3
	var results: Array = sys.check_promises(run)
	if results.size() != 1 or not results[0].get("kept", false):
		push_error("accept_damage: 2 >= 2, should be kept")
		return false
	return true


func test_condition_total_healing_met() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 3,
		"condition_type": "total_healing",
		"condition_value": 15,
	}))
	sys.update_promise_tracking(run, "healing", {"amount": 10})
	sys.update_promise_tracking(run, "healing", {"amount": 8})
	run["card_index"] = 3
	var results: Array = sys.check_promises(run)
	if results.size() != 1 or not results[0].get("kept", false):
		push_error("total_healing: 18 >= 15, should be kept")
		return false
	return true


func test_condition_unknown_type_evaluates_to_broken() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 1,
		"condition_type": "nonexistent_condition",
		"condition_value": 1,
	}))
	run["card_index"] = 1
	var results: Array = sys.check_promises(run)
	if results.size() != 1 or results[0].get("kept", true):
		push_error("unknown condition_type should fall through to broken (false)")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# GROUP 6 — Edge cases
# ─────────────────────────────────────────────────────────────────────────────

func test_check_promises_handles_non_dict_in_active_array() -> bool:
	# If active_promises contains a non-dict entry it should be skipped
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	run["active_promises"] = ["not_a_dict", 42, null]
	run["card_index"] = 99
	var results: Array = sys.check_promises(run)
	if results.size() != 0:
		push_error("non-dict entries in active_promises should be skipped, got %d results" % results.size())
		return false
	return true


func test_create_promise_missing_promise_id_key_rejected() -> bool:
	# A dict with no "promise_id" key at all — get returns "" (empty)
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	var data: Dictionary = {
		"deadline_cards": 5,
		"condition_type": "life_above",
		"condition_value": 50,
	}
	var ok: bool = sys.create_promise(run, data)
	if ok:
		push_error("create_promise should reject data with no 'promise_id' key (empty string fallback)")
		return false
	return true


func test_tracking_faction_gain_multiple_factions_independent() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	sys.update_promise_tracking(run, "faction_gain", {"faction": "druides", "amount": 10})
	sys.update_promise_tracking(run, "faction_gain", {"faction": "anciens", "amount": 7})
	var gained: Dictionary = run["promise_tracking"]["test_promise_1"].get("faction_gained", {})
	if abs(float(gained.get("druides", 0.0)) - 10.0) > 0.01:
		push_error("druides gain should be 10.0, got %f" % float(gained.get("druides", 0.0)))
		return false
	if abs(float(gained.get("anciens", 0.0)) - 7.0) > 0.01:
		push_error("anciens gain should be 7.0, got %f" % float(gained.get("anciens", 0.0)))
		return false
	return true


func test_tracking_updates_all_active_promises() -> bool:
	# When two promises are active, update_promise_tracking must update both
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({"promise_id": "alpha"}))
	sys.create_promise(run, _make_promise_data({"promise_id": "beta"}))
	sys.update_promise_tracking(run, "minigame_win", {})
	var alpha_wins: int = int(run["promise_tracking"]["alpha"].get("minigame_wins", 0))
	var beta_wins: int = int(run["promise_tracking"]["beta"].get("minigame_wins", 0))
	if alpha_wins != 1 or beta_wins != 1:
		push_error("Both promises should receive minigame_win: alpha=%d, beta=%d" % [alpha_wins, beta_wins])
		return false
	return true


func test_full_promise_lifecycle_kept() -> bool:
	# Integration: create → track → advance to deadline → check resolves as kept
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state(0, 60)
	var ok: bool = sys.create_promise(run, _make_promise_data({
		"promise_id": "lifecycle_test",
		"deadline_cards": 4,
		"condition_type": "minigame_wins",
		"condition_value": 2,
	}))
	if not ok:
		push_error("lifecycle: create_promise failed")
		return false
	sys.update_promise_tracking(run, "minigame_win", {})
	sys.update_promise_tracking(run, "minigame_win", {})
	# Not expired yet
	run["card_index"] = 3
	var partial: Array = sys.check_promises(run)
	if partial.size() != 0:
		push_error("lifecycle: should not expire at card 3 (deadline=4), got %d results" % partial.size())
		return false
	# Now expire
	run["card_index"] = 4
	var results: Array = sys.check_promises(run)
	if results.size() != 1:
		push_error("lifecycle: expected 1 result at deadline, got %d" % results.size())
		return false
	if not results[0].get("kept", false):
		push_error("lifecycle: 2 wins >= 2, should be kept")
		return false
	if run["active_promises"].size() != 0:
		push_error("lifecycle: active_promises should be empty after resolution")
		return false
	if run["promise_tracking"].has("lifecycle_test"):
		push_error("lifecycle: tracking should be cleaned up after resolution")
		return false
	var expected_delta: int = int(MerlinConstants.TRUST_DELTAS.get("promise_kept", 10))
	if int(results[0].get("trust_delta", 0)) != expected_delta:
		push_error("lifecycle: trust_delta expected %d, got %d" % [expected_delta, int(results[0].get("trust_delta", 0))])
		return false
	return true
