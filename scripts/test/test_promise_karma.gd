## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — Promise & Karma Systems
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: CREATE_PROMISE, FULFILL_PROMISE, BREAK_PROMISE, ADD_KARMA, limits,
## clamping, boundary conditions, empty-list handling, promise/karma interaction.
## Pattern: extends RefCounted, each test returns bool, run_all() aggregates.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


func _make_state() -> Dictionary:
	return {
		"run": {
			"life_essence": 50,
			"day": 1,
			"hidden": {},
			"active_promises": [],
		},
		"meta": {
			"faction_rep": {
				"druides": 10, "anciens": 10, "korrigans": 10, "niamh": 10, "ankou": 10,
			},
		},
		"effect_log": [],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# CREATE_PROMISE
# ═══════════════════════════════════════════════════════════════════════════════

func test_create_promise_adds_to_active_promises() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	var result: Dictionary = engine.apply_effects(
		state, ["CREATE_PROMISE:oath_001:5:Protect the village"]
	)
	if result["applied"].size() != 1:
		push_error("CREATE_PROMISE: expected 1 applied, got %d" % result["applied"].size())
		return false
	var promises: Array = state["run"].get("active_promises", [])
	if promises.size() != 1:
		push_error("CREATE_PROMISE: expected 1 promise in list, got %d" % promises.size())
		return false
	var p: Dictionary = promises[0]
	if str(p.get("id", "")) != "oath_001":
		push_error("CREATE_PROMISE: wrong id '%s'" % p.get("id", ""))
		return false
	if str(p.get("status", "")) != "active":
		push_error("CREATE_PROMISE: expected status 'active', got '%s'" % p.get("status", ""))
		return false
	return true


func test_create_promise_deadline_computed_from_day() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	state["run"]["day"] = 3
	engine.apply_effects(state, ["CREATE_PROMISE:oath_002:7:Guard the shrine"])
	var promises: Array = state["run"].get("active_promises", [])
	if promises.is_empty():
		push_error("CREATE_PROMISE deadline: no promise created")
		return false
	var deadline: int = int(promises[0].get("deadline_day", 0))
	if deadline != 10:  # day 3 + 7
		push_error("CREATE_PROMISE deadline: expected 10, got %d" % deadline)
		return false
	return true


func test_create_promise_invalid_arg_count_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	# CREATE_PROMISE requires 3 args; providing only 2 should be rejected
	var result: Dictionary = engine.apply_effects(state, ["CREATE_PROMISE:oath_bad:5"])
	if result["rejected"].size() != 1:
		push_error("CREATE_PROMISE bad args: expected 1 rejected, got %d" % result["rejected"].size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MAX_ACTIVE_PROMISES LIMIT
# ═══════════════════════════════════════════════════════════════════════════════

func test_max_active_promises_constant_is_two() -> bool:
	# MOS_CONVERGENCE and MAX_ACTIVE_PROMISES const must both equal 2
	var mos_max: int = int(MerlinConstants.MOS_CONVERGENCE.get("max_active_promises", -1))
	if mos_max != 2:
		push_error("MOS_CONVERGENCE.max_active_promises: expected 2, got %d" % mos_max)
		return false
	if MerlinConstants.MAX_ACTIVE_PROMISES != 2:
		push_error("MAX_ACTIVE_PROMISES: expected 2, got %d" % MerlinConstants.MAX_ACTIVE_PROMISES)
		return false
	return true


func test_two_promises_can_be_created() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_a:3:First vow"])
	engine.apply_effects(state, ["CREATE_PROMISE:oath_b:5:Second vow"])
	var promises: Array = state["run"].get("active_promises", [])
	if promises.size() != 2:
		push_error("Two promises: expected 2, got %d" % promises.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FULFILL_PROMISE
# ═══════════════════════════════════════════════════════════════════════════════

func test_fulfill_promise_sets_status_fulfilled() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_001:5:A noble vow"])
	var result: Dictionary = engine.apply_effects(state, ["FULFILL_PROMISE:oath_001"])
	if result["applied"].size() != 1:
		push_error("FULFILL_PROMISE: expected 1 applied, got %d" % result["applied"].size())
		return false
	var promises: Array = state["run"].get("active_promises", [])
	var status: String = str(promises[0].get("status", ""))
	if status != "fulfilled":
		push_error("FULFILL_PROMISE: expected 'fulfilled', got '%s'" % status)
		return false
	return true


func test_fulfill_promise_nonexistent_returns_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	# No promise created — FULFILL_PROMISE must fail cleanly
	var result: Dictionary = engine.apply_effects(state, ["FULFILL_PROMISE:ghost_oath"])
	if result["rejected"].size() != 1:
		push_error("FULFILL_PROMISE unknown: expected 1 rejected, got %d" % result["rejected"].size())
		return false
	return true


func test_fulfill_promise_does_not_affect_other_promise() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_a:3:Vow A"])
	engine.apply_effects(state, ["CREATE_PROMISE:oath_b:5:Vow B"])
	engine.apply_effects(state, ["FULFILL_PROMISE:oath_a"])
	var promises: Array = state["run"].get("active_promises", [])
	var status_b: String = ""
	for p in promises:
		if str(p.get("id", "")) == "oath_b":
			status_b = str(p.get("status", ""))
	if status_b != "active":
		push_error("FULFILL_PROMISE: oath_b should remain 'active', got '%s'" % status_b)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# BREAK_PROMISE
# ═══════════════════════════════════════════════════════════════════════════════

func test_break_promise_sets_status_broken() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_001:5:A fragile vow"])
	var result: Dictionary = engine.apply_effects(state, ["BREAK_PROMISE:oath_001"])
	if result["applied"].size() != 1:
		push_error("BREAK_PROMISE: expected 1 applied, got %d" % result["applied"].size())
		return false
	var promises: Array = state["run"].get("active_promises", [])
	var status: String = str(promises[0].get("status", ""))
	if status != "broken":
		push_error("BREAK_PROMISE: expected 'broken', got '%s'" % status)
		return false
	return true


func test_break_promise_nonexistent_returns_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	var result: Dictionary = engine.apply_effects(state, ["BREAK_PROMISE:ghost_oath"])
	if result["rejected"].size() != 1:
		push_error("BREAK_PROMISE unknown: expected 1 rejected, got %d" % result["rejected"].size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ADD_KARMA
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_karma_increases_hidden_karma() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	var result: Dictionary = engine.apply_effects(state, ["ADD_KARMA:10"])
	if result["applied"].size() != 1:
		push_error("ADD_KARMA: expected 1 applied, got %d" % result["applied"].size())
		return false
	var karma: int = int(state["run"]["hidden"].get("karma", 0))
	if karma != 10:
		push_error("ADD_KARMA: expected 10, got %d" % karma)
		return false
	return true


func test_add_karma_accumulates_across_calls() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	engine.apply_effects(state, ["ADD_KARMA:5"])
	engine.apply_effects(state, ["ADD_KARMA:7"])
	var karma: int = int(state["run"]["hidden"].get("karma", 0))
	if karma != 12:
		push_error("ADD_KARMA accumulate: expected 12, got %d" % karma)
		return false
	return true


func test_add_karma_negative_decreases_karma() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	engine.apply_effects(state, ["ADD_KARMA:10"])
	engine.apply_effects(state, ["ADD_KARMA:-4"])
	var karma: int = int(state["run"]["hidden"].get("karma", 0))
	if karma != 6:
		push_error("ADD_KARMA negative: expected 6, got %d" % karma)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# KARMA CAPPING — ADD_REPUTATION uses ±20 cap; karma itself is unclamped
## per _apply_hidden_counter (only tension is clamped, karma is not)
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_karma_cap_effect_reputation_at_positive_boundary() -> bool:
	# ADD_REPUTATION cap_effect: +20 is the boundary, must stay at 20
	var capped: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", 20)
	if capped != 20:
		push_error("cap_effect ADD_REPUTATION at +20 boundary: expected 20, got %d" % capped)
		return false
	return true


func test_add_karma_cap_effect_reputation_at_negative_boundary() -> bool:
	# ADD_REPUTATION cap_effect: -20 is the boundary, must stay at -20
	var capped: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", -20)
	if capped != -20:
		push_error("cap_effect ADD_REPUTATION at -20 boundary: expected -20, got %d" % capped)
		return false
	return true


func test_add_karma_cap_effect_reputation_above_max_clamped() -> bool:
	var capped: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", 25)
	if capped != 20:
		push_error("cap_effect ADD_REPUTATION over max: expected 20, got %d" % capped)
		return false
	return true


func test_add_karma_cap_effect_reputation_below_min_clamped() -> bool:
	var capped: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", -25)
	if capped != -20:
		push_error("cap_effect ADD_REPUTATION under min: expected -20, got %d" % capped)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROMISE / KARMA INTERACTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_fulfill_then_add_karma_positive_interaction() -> bool:
	# Fulfilling a promise and then adding karma should both succeed independently
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_honor:3:Honor the elders"])
	engine.apply_effects(state, ["FULFILL_PROMISE:oath_honor"])
	engine.apply_effects(state, ["ADD_KARMA:10"])
	var promises: Array = state["run"].get("active_promises", [])
	var status: String = str(promises[0].get("status", ""))
	var karma: int = int(state["run"]["hidden"].get("karma", 0))
	if status != "fulfilled":
		push_error("Fulfill+karma: promise status should be 'fulfilled', got '%s'" % status)
		return false
	if karma != 10:
		push_error("Fulfill+karma: karma should be 10, got %d" % karma)
		return false
	return true


func test_break_then_add_karma_negative_interaction() -> bool:
	# Breaking a promise and adding negative karma — both must apply
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_shadow:4:Spare the prisoner"])
	engine.apply_effects(state, ["BREAK_PROMISE:oath_shadow"])
	engine.apply_effects(state, ["ADD_KARMA:-15"])
	var promises: Array = state["run"].get("active_promises", [])
	var status: String = str(promises[0].get("status", ""))
	var karma: int = int(state["run"]["hidden"].get("karma", 0))
	if status != "broken":
		push_error("Break+karma: promise status should be 'broken', got '%s'" % status)
		return false
	if karma != -15:
		push_error("Break+karma: karma should be -15, got %d" % karma)
		return false
	return true


func test_trust_deltas_promise_kept_value() -> bool:
	# bible v2.4: promise_kept = +10 trust
	var delta: int = int(MerlinConstants.TRUST_DELTAS.get("promise_kept", 0))
	if delta != 10:
		push_error("TRUST_DELTAS.promise_kept: expected 10, got %d" % delta)
		return false
	return true


func test_trust_deltas_promise_broken_value() -> bool:
	# bible v2.4: promise_broken = -15 trust
	var delta: int = int(MerlinConstants.TRUST_DELTAS.get("promise_broken", 0))
	if delta != -15:
		push_error("TRUST_DELTAS.promise_broken: expected -15, got %d" % delta)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EMPTY PROMISE LIST HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

func test_fulfill_on_empty_list_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	# active_promises is empty — FULFILL_PROMISE must not crash and must reject
	var result: Dictionary = engine.apply_effects(state, ["FULFILL_PROMISE:any_id"])
	if result["rejected"].size() != 1:
		push_error("FULFILL empty list: expected 1 rejected, got %d" % result["rejected"].size())
		return false
	# State must remain consistent
	var promises: Array = state["run"].get("active_promises", [])
	if promises.size() != 0:
		push_error("FULFILL empty list: promise list should remain empty")
		return false
	return true


func test_break_on_empty_list_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	var result: Dictionary = engine.apply_effects(state, ["BREAK_PROMISE:any_id"])
	if result["rejected"].size() != 1:
		push_error("BREAK empty list: expected 1 rejected, got %d" % result["rejected"].size())
		return false
	var promises: Array = state["run"].get("active_promises", [])
	if promises.size() != 0:
		push_error("BREAK empty list: promise list should remain empty")
		return false
	return true


func test_add_karma_zero_on_empty_state() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	# karma not yet set — starting from implicit 0
	engine.apply_effects(state, ["ADD_KARMA:0"])
	var karma: int = int(state["run"]["hidden"].get("karma", 0))
	if karma != 0:
		push_error("ADD_KARMA zero: expected 0, got %d" % karma)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> void:
	var tests: Array[Callable] = [
		test_create_promise_adds_to_active_promises,
		test_create_promise_deadline_computed_from_day,
		test_create_promise_invalid_arg_count_rejected,
		test_max_active_promises_constant_is_two,
		test_two_promises_can_be_created,
		test_fulfill_promise_sets_status_fulfilled,
		test_fulfill_promise_nonexistent_returns_rejected,
		test_fulfill_promise_does_not_affect_other_promise,
		test_break_promise_sets_status_broken,
		test_break_promise_nonexistent_returns_rejected,
		test_add_karma_increases_hidden_karma,
		test_add_karma_accumulates_across_calls,
		test_add_karma_negative_decreases_karma,
		test_add_karma_cap_effect_reputation_at_positive_boundary,
		test_add_karma_cap_effect_reputation_at_negative_boundary,
		test_add_karma_cap_effect_reputation_above_max_clamped,
		test_add_karma_cap_effect_reputation_below_min_clamped,
		test_fulfill_then_add_karma_positive_interaction,
		test_break_then_add_karma_negative_interaction,
		test_trust_deltas_promise_kept_value,
		test_trust_deltas_promise_broken_value,
		test_fulfill_on_empty_list_rejected,
		test_break_on_empty_list_rejected,
		test_add_karma_zero_on_empty_state,
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

	print("[test_promise_karma] Results: %d/%d passed" % [passed, passed + failed])
	if failed > 0:
		push_error("[test_promise_karma] %d test(s) FAILED" % failed)
	else:
		print("[test_promise_karma] All tests passed.")
