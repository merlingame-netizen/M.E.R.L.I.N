## =============================================================================
## Test MerlinEventSystem — state mutation functions (headless-safe)
## =============================================================================
## Focuses on _update_fail_streak, _reset_one_shot_mods, and edge cases.
## Does NOT test run_scene full path (requires LLM adapter).
## =============================================================================

extends RefCounted


func run_all() -> Dictionary:
	var tests: Array[Callable] = [
		test_update_fail_streak_success_resets,
		test_update_fail_streak_increments_on_failure,
		test_update_fail_streak_multiple_failures,
		test_update_fail_streak_resets_after_streak,
		test_reset_one_shot_mods_zeroes_difficulty,
		test_reset_one_shot_mods_preserves_other_keys,
		test_state_without_run_key_fail_streak,
		test_state_without_run_key_reset_mods,
		test_combined_fail_streak_then_reset_mods,
		test_fail_streak_from_nonzero_difficulty_mod,
	]
	var passed: int = 0
	var failed: int = 0
	for t in tests:
		if t.call():
			passed += 1
		else:
			failed += 1
	return {"passed": passed, "failed": failed, "total": tests.size()}


func test_update_fail_streak_success_resets() -> bool:
	var es: MerlinEventSystem = MerlinEventSystem.new()
	var state: Dictionary = {"run": {"fail_streak": 3}}
	es._update_fail_streak(state, true)
	if state["run"]["fail_streak"] != 0:
		push_error("fail_streak should be 0 after success, got %d" % state["run"]["fail_streak"])
		return false
	return true


func test_update_fail_streak_increments_on_failure() -> bool:
	var es: MerlinEventSystem = MerlinEventSystem.new()
	var state: Dictionary = {"run": {"fail_streak": 0}}
	es._update_fail_streak(state, false)
	if state["run"]["fail_streak"] != 1:
		push_error("fail_streak should be 1 after one failure, got %d" % state["run"]["fail_streak"])
		return false
	return true


func test_update_fail_streak_multiple_failures() -> bool:
	var es: MerlinEventSystem = MerlinEventSystem.new()
	var state: Dictionary = {"run": {"fail_streak": 0}}
	es._update_fail_streak(state, false)
	es._update_fail_streak(state, false)
	es._update_fail_streak(state, false)
	if state["run"]["fail_streak"] != 3:
		push_error("fail_streak should be 3 after three failures, got %d" % state["run"]["fail_streak"])
		return false
	return true


func test_update_fail_streak_resets_after_streak() -> bool:
	var es: MerlinEventSystem = MerlinEventSystem.new()
	var state: Dictionary = {"run": {"fail_streak": 0}}
	es._update_fail_streak(state, false)
	es._update_fail_streak(state, false)
	es._update_fail_streak(state, false)
	es._update_fail_streak(state, true)
	if state["run"]["fail_streak"] != 0:
		push_error("fail_streak should reset to 0 after success, got %d" % state["run"]["fail_streak"])
		return false
	return true


func test_reset_one_shot_mods_zeroes_difficulty() -> bool:
	var es: MerlinEventSystem = MerlinEventSystem.new()
	var state: Dictionary = {"run": {"difficulty_mod_next": 5}}
	es._reset_one_shot_mods(state)
	if state["run"]["difficulty_mod_next"] != 0:
		push_error("difficulty_mod_next should be 0, got %d" % state["run"]["difficulty_mod_next"])
		return false
	return true


func test_reset_one_shot_mods_preserves_other_keys() -> bool:
	var es: MerlinEventSystem = MerlinEventSystem.new()
	var state: Dictionary = {"run": {"difficulty_mod_next": 3, "fail_streak": 2, "cards_played": 7}}
	es._reset_one_shot_mods(state)
	if state["run"]["difficulty_mod_next"] != 0:
		push_error("difficulty_mod_next should be 0, got %d" % state["run"]["difficulty_mod_next"])
		return false
	if state["run"]["fail_streak"] != 2:
		push_error("fail_streak should be preserved at 2, got %d" % state["run"]["fail_streak"])
		return false
	if state["run"]["cards_played"] != 7:
		push_error("cards_played should be preserved at 7, got %d" % state["run"]["cards_played"])
		return false
	return true


func test_state_without_run_key_fail_streak() -> bool:
	var es: MerlinEventSystem = MerlinEventSystem.new()
	var state: Dictionary = {}
	es._update_fail_streak(state, false)
	if not state.has("run"):
		push_error("state should have 'run' key after _update_fail_streak")
		return false
	if state["run"]["fail_streak"] != 1:
		push_error("fail_streak should be 1 on missing run key, got %d" % state["run"]["fail_streak"])
		return false
	return true


func test_state_without_run_key_reset_mods() -> bool:
	var es: MerlinEventSystem = MerlinEventSystem.new()
	var state: Dictionary = {}
	es._reset_one_shot_mods(state)
	if not state.has("run"):
		push_error("state should have 'run' key after _reset_one_shot_mods")
		return false
	if state["run"]["difficulty_mod_next"] != 0:
		push_error("difficulty_mod_next should be 0 on missing run key, got %d" % state["run"]["difficulty_mod_next"])
		return false
	return true


func test_combined_fail_streak_then_reset_mods() -> bool:
	var es: MerlinEventSystem = MerlinEventSystem.new()
	var state: Dictionary = {"run": {"fail_streak": 0, "difficulty_mod_next": -2}}
	es._update_fail_streak(state, false)
	es._update_fail_streak(state, false)
	es._reset_one_shot_mods(state)
	if state["run"]["fail_streak"] != 2:
		push_error("fail_streak should be 2 after two failures, got %d" % state["run"]["fail_streak"])
		return false
	if state["run"]["difficulty_mod_next"] != 0:
		push_error("difficulty_mod_next should be 0 after reset, got %d" % state["run"]["difficulty_mod_next"])
		return false
	return true


func test_fail_streak_from_nonzero_difficulty_mod() -> bool:
	var es: MerlinEventSystem = MerlinEventSystem.new()
	var state: Dictionary = {"run": {"fail_streak": 5, "difficulty_mod_next": -3}}
	es._update_fail_streak(state, true)
	if state["run"]["fail_streak"] != 0:
		push_error("fail_streak should reset to 0, got %d" % state["run"]["fail_streak"])
		return false
	if state["run"]["difficulty_mod_next"] != -3:
		push_error("difficulty_mod_next should be untouched by _update_fail_streak, got %d" % state["run"]["difficulty_mod_next"])
		return false
	return true
