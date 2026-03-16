## =============================================================================
## Unit Tests — MerlinPromiseSystem
## =============================================================================
## Tests: create_promise, resolve_promise, check_promises, tracking updates,
## condition evaluation (all 7 types), edge cases, max cap, duplicates.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


func _make_run_state(overrides: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"card_index": 0,
		"life_essence": 80,
		"active_promises": [],
		"promise_tracking": {},
	}
	for key in overrides:
		state[key] = overrides[key]
	return state


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


# =============================================================================
# CREATE PROMISE — basic
# =============================================================================

func test_create_promise_success() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	var ok: bool = sys.create_promise(run, _make_promise_data())
	if not ok:
		push_error("create_promise should return true on valid data")
		return false
	var active: Array = run.get("active_promises", [])
	if active.size() != 1:
		push_error("active_promises should have 1 entry, got %d" % active.size())
		return false
	return true


func test_create_promise_stores_correct_fields() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state({"card_index": 3})
	var data: Dictionary = _make_promise_data({"deadline_cards": 7})
	sys.create_promise(run, data)
	var p: Dictionary = run["active_promises"][0]
	if str(p.get("promise_id", "")) != "test_promise_1":
		push_error("promise_id mismatch: got '%s'" % p.get("promise_id", ""))
		return false
	if int(p.get("created_at_card", -1)) != 3:
		push_error("created_at_card: expected 3, got %d" % int(p.get("created_at_card", -1)))
		return false
	if int(p.get("deadline_card", -1)) != 10:
		push_error("deadline_card: expected 10 (3+7), got %d" % int(p.get("deadline_card", -1)))
		return false
	return true


func test_create_promise_empty_id_rejected() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	var ok: bool = sys.create_promise(run, _make_promise_data({"promise_id": ""}))
	if ok:
		push_error("create_promise should reject empty promise_id")
		return false
	return true


func test_create_promise_duplicate_rejected() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	var ok: bool = sys.create_promise(run, _make_promise_data())
	if ok:
		push_error("create_promise should reject duplicate promise_id")
		return false
	if run["active_promises"].size() != 1:
		push_error("active_promises should still have 1 entry after duplicate")
		return false
	return true


func test_create_promise_max_cap() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	# Fill to MAX_ACTIVE_PROMISES (2)
	sys.create_promise(run, _make_promise_data({"promise_id": "p1"}))
	sys.create_promise(run, _make_promise_data({"promise_id": "p2"}))
	var ok: bool = sys.create_promise(run, _make_promise_data({"promise_id": "p3"}))
	if ok:
		push_error("create_promise should reject when max (%d) reached" % MerlinConstants.MAX_ACTIVE_PROMISES)
		return false
	if run["active_promises"].size() != 2:
		push_error("active_promises should have %d entries, got %d" % [MerlinConstants.MAX_ACTIVE_PROMISES, run["active_promises"].size()])
		return false
	return true


func test_create_promise_initializes_tracking() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	var tracking: Dictionary = run.get("promise_tracking", {})
	if not tracking.has("test_promise_1"):
		push_error("promise_tracking should have entry for 'test_promise_1'")
		return false
	var track: Dictionary = tracking["test_promise_1"]
	if int(track.get("minigame_wins", -1)) != 0:
		push_error("tracking minigame_wins should init to 0")
		return false
	if int(track.get("safe_choices", -1)) != 0:
		push_error("tracking safe_choices should init to 0")
		return false
	return true


# =============================================================================
# RESOLVE PROMISE
# =============================================================================

func test_resolve_promise_kept() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var result: Dictionary = sys.resolve_promise("p1", true)
	if str(result.get("promise_id", "")) != "p1":
		push_error("resolve kept: promise_id mismatch")
		return false
	if not result.get("kept", false):
		push_error("resolve kept: should be true")
		return false
	var expected_delta: int = int(MerlinConstants.TRUST_DELTAS.get("promise_kept", 10))
	if int(result.get("trust_delta", 0)) != expected_delta:
		push_error("resolve kept: trust_delta expected %d, got %d" % [expected_delta, int(result.get("trust_delta", 0))])
		return false
	return true


func test_resolve_promise_broken() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var result: Dictionary = sys.resolve_promise("p1", false)
	if result.get("kept", true):
		push_error("resolve broken: kept should be false")
		return false
	var expected_delta: int = int(MerlinConstants.TRUST_DELTAS.get("promise_broken", -15))
	if int(result.get("trust_delta", 0)) != expected_delta:
		push_error("resolve broken: trust_delta expected %d, got %d" % [expected_delta, int(result.get("trust_delta", 0))])
		return false
	return true


# =============================================================================
# CHECK PROMISES — deadline evaluation
# =============================================================================

func test_check_promises_not_expired() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state({"card_index": 2})
	sys.create_promise(run, _make_promise_data({"deadline_cards": 5}))
	var results: Array = sys.check_promises(run)
	if results.size() != 0:
		push_error("check_promises: promise not expired yet, expected 0 results, got %d" % results.size())
		return false
	if run["active_promises"].size() != 1:
		push_error("check_promises: promise should remain active")
		return false
	return true


func test_check_promises_expired_kept() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	# card_index=0, deadline_cards=3 => deadline_card=3
	var run: Dictionary = _make_run_state({"life_essence": 80})
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 3,
		"condition_type": "life_above",
		"condition_value": 50,
	}))
	# Advance to deadline
	run["card_index"] = 3
	var results: Array = sys.check_promises(run)
	if results.size() != 1:
		push_error("check expired: expected 1 result, got %d" % results.size())
		return false
	if not results[0].get("kept", false):
		push_error("check expired: life_essence=80 >= 50, should be kept")
		return false
	if run["active_promises"].size() != 0:
		push_error("check expired: promise should be removed from active")
		return false
	return true


func test_check_promises_expired_broken() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state({"life_essence": 30})
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 2,
		"condition_type": "life_above",
		"condition_value": 50,
	}))
	run["card_index"] = 2
	var results: Array = sys.check_promises(run)
	if results.size() != 1:
		push_error("check broken: expected 1 result, got %d" % results.size())
		return false
	if results[0].get("kept", true):
		push_error("check broken: life_essence=30 < 50, should be broken")
		return false
	return true


func test_check_promises_cleans_tracking() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({"deadline_cards": 1}))
	run["card_index"] = 1
	sys.check_promises(run)
	var tracking: Dictionary = run.get("promise_tracking", {})
	if tracking.has("test_promise_1"):
		push_error("check_promises should erase tracking for resolved promise")
		return false
	return true


# =============================================================================
# CONDITION EVALUATION — all 7 types
# =============================================================================

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


func test_condition_no_safe_met() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data({
		"deadline_cards": 2,
		"condition_type": "no_safe",
	}))
	# No safe choices made
	run["card_index"] = 2
	var results: Array = sys.check_promises(run)
	if results.size() != 1 or not results[0].get("kept", false):
		push_error("no_safe: 0 safe choices, should be kept")
		return false
	return true


func test_condition_no_safe_broken() -> bool:
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


func test_condition_unknown_type_is_broken() -> bool:
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
		push_error("unknown condition_type should evaluate to broken")
		return false
	return true


# =============================================================================
# TRACKING UPDATES
# =============================================================================

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


func test_tracking_tag_no_duplicates() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	sys.create_promise(run, _make_promise_data())
	sys.update_promise_tracking(run, "tag_acquired", {"tag": "brave"})
	sys.update_promise_tracking(run, "tag_acquired", {"tag": "brave"})
	var tags: Array = run["promise_tracking"]["test_promise_1"].get("tags_acquired", [])
	if tags.size() != 1:
		push_error("tag_acquired should not duplicate, got %d entries" % tags.size())
		return false
	return true


# =============================================================================
# EDGE CASES
# =============================================================================

func test_check_promises_empty_active() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	var results: Array = sys.check_promises(run)
	if results.size() != 0:
		push_error("check_promises on empty active should return 0 results")
		return false
	return true


func test_tracking_update_no_promises_no_crash() -> bool:
	var sys: MerlinPromiseSystem = MerlinPromiseSystem.new()
	var run: Dictionary = _make_run_state()
	# No promises created, tracking update should not crash
	sys.update_promise_tracking(run, "minigame_win", {})
	return true
