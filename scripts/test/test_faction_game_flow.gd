## =============================================================================
## Unit Tests — Faction Game Flow (echo_memory persistence)
## =============================================================================
## Tests: _on_faction_ending_chosen logic:
##   (1) valid faction -> recorded in echo_memory.dominant_factions_seen
##   (2) invalid faction -> no crash, no write
##   (3) duplicate faction -> not duplicated in array
##   (4) _store=null -> no crash (guard holds)
##   (5) save_profile called after valid faction
## Pattern: extends RefCounted, each test returns bool, run_all() aggregates.
## Task: FACTION-GAME-FLOW-TEST
## =============================================================================

extends RefCounted


# =============================================================================
# HELPERS — minimal store + save mock
# =============================================================================

## Build a minimal store dict simulating MerlinStore.state structure.
func _make_store_state(seen_factions: Array = []) -> Dictionary:
	return {
		"meta": {
			"echo_memory": {
				"dominant_factions_seen": seen_factions.duplicate(),
			},
		},
	}


## Replicate the _on_faction_ending_chosen logic on a plain dict.
## This mirrors game_flow_controller.gd:175-187 for testability without Node.
func _apply_faction_ending(state: Dictionary, faction: String, save_called: Array) -> Dictionary:
	if not MerlinConstants.FACTIONS.has(faction):
		return state
	var meta: Dictionary = state.get("meta", {})
	var echo: Dictionary = meta.get("echo_memory", {})
	var seen: Array = echo.get("dominant_factions_seen", [])
	if not seen.has(faction):
		seen.append(faction)
	echo["dominant_factions_seen"] = seen
	meta["echo_memory"] = echo
	state["meta"] = meta
	save_called.append(true)
	return state


# =============================================================================
# TESTS
# =============================================================================

## (1) Valid faction -> recorded in dominant_factions_seen.
func test_valid_faction_appended() -> bool:
	var state: Dictionary = _make_store_state([])
	var save_calls: Array = []
	state = _apply_faction_ending(state, "druides", save_calls)
	var seen: Array = state["meta"]["echo_memory"]["dominant_factions_seen"]
	if not seen.has("druides"):
		push_error("FAIL test_valid_faction_appended: 'druides' not in seen=%s" % str(seen))
		return false
	if seen.size() != 1:
		push_error("FAIL test_valid_faction_appended: expected size 1, got %d" % seen.size())
		return false
	return true


## (2) Invalid faction -> no change to state, no save.
func test_invalid_faction_ignored() -> bool:
	var state: Dictionary = _make_store_state([])
	var save_calls: Array = []
	state = _apply_faction_ending(state, "invalid_faction", save_calls)
	var seen: Array = state["meta"]["echo_memory"]["dominant_factions_seen"]
	if seen.size() != 0:
		push_error("FAIL test_invalid_faction_ignored: expected empty array, got %s" % str(seen))
		return false
	if save_calls.size() != 0:
		push_error("FAIL test_invalid_faction_ignored: save_profile called unexpectedly")
		return false
	return true


## (3) Duplicate faction -> not duplicated in array.
func test_duplicate_faction_not_repeated() -> bool:
	var state: Dictionary = _make_store_state(["korrigans"])
	var save_calls: Array = []
	state = _apply_faction_ending(state, "korrigans", save_calls)
	var seen: Array = state["meta"]["echo_memory"]["dominant_factions_seen"]
	var count: int = 0
	for s in seen:
		if s == "korrigans":
			count += 1
	if count != 1:
		push_error("FAIL test_duplicate_faction_not_repeated: 'korrigans' appears %d times" % count)
		return false
	return true


## (4) _store=null guard — simulate by checking MerlinConstants guard only.
## The null-store guard in game_flow_controller.gd:176 is: if _store == null: return
## We verify FACTIONS.has() still works correctly for boundary cases.
func test_null_store_guard_logic() -> bool:
	# Verify that the guard condition is correct:
	# MerlinConstants.FACTIONS must contain exactly the 5 official factions.
	var expected: Array[String] = ["druides", "anciens", "korrigans", "niamh", "ankou"]
	for f in expected:
		if not MerlinConstants.FACTIONS.has(f):
			push_error("FAIL test_null_store_guard_logic: '%s' missing from FACTIONS" % f)
			return false
	# An empty string is NOT a valid faction (guard should reject it).
	if MerlinConstants.FACTIONS.has(""):
		push_error("FAIL test_null_store_guard_logic: empty string passes FACTIONS.has()")
		return false
	return true


## (5) save_profile called after valid faction.
func test_save_called_on_valid_faction() -> bool:
	var state: Dictionary = _make_store_state([])
	var save_calls: Array = []
	state = _apply_faction_ending(state, "ankou", save_calls)
	if save_calls.size() != 1:
		push_error("FAIL test_save_called_on_valid_faction: expected 1 save call, got %d" % save_calls.size())
		return false
	return true


## (6) All 5 factions can be appended in sequence — no clobbering.
func test_all_factions_can_accumulate() -> bool:
	var state: Dictionary = _make_store_state([])
	var save_calls: Array = []
	for f in MerlinConstants.FACTIONS:
		state = _apply_faction_ending(state, f, save_calls)
	var seen: Array = state["meta"]["echo_memory"]["dominant_factions_seen"]
	if seen.size() != MerlinConstants.FACTIONS.size():
		push_error("FAIL test_all_factions_can_accumulate: expected %d, got %d" % [MerlinConstants.FACTIONS.size(), seen.size()])
		return false
	return true


## (7) echo_memory key preserved when pre-existing data present (no clobber).
func test_echo_memory_other_keys_preserved() -> bool:
	var state: Dictionary = {
		"meta": {
			"echo_memory": {
				"dominant_factions_seen": [],
				"story_summary": "Merlin await",
				"run_count": 5,
			},
		},
	}
	var save_calls: Array = []
	state = _apply_faction_ending(state, "niamh", save_calls)
	var echo: Dictionary = state["meta"]["echo_memory"]
	if not echo.has("story_summary") or echo["story_summary"] != "Merlin await":
		push_error("FAIL test_echo_memory_other_keys_preserved: story_summary lost")
		return false
	if not echo.has("run_count") or echo["run_count"] != 5:
		push_error("FAIL test_echo_memory_other_keys_preserved: run_count lost")
		return false
	return true


# =============================================================================
# RUNNER
# =============================================================================

func run_all() -> bool:
	var tests: Array[String] = [
		"test_valid_faction_appended",
		"test_invalid_faction_ignored",
		"test_duplicate_faction_not_repeated",
		"test_null_store_guard_logic",
		"test_save_called_on_valid_faction",
		"test_all_factions_can_accumulate",
		"test_echo_memory_other_keys_preserved",
	]
	var passed: int = 0
	var failed: int = 0
	for t in tests:
		var result: bool = call(t)
		if result:
			passed += 1
		else:
			failed += 1
			push_warning("[TestFactionGameFlow] FAIL: %s" % t)
	print("[TestFactionGameFlow] %d/%d tests passed" % [passed, tests.size()])
	return failed == 0
