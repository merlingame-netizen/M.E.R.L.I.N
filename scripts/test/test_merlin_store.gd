# test_merlin_store.gd
# GUT Unit Tests for MerlinStore (Central State Management)
# Created: 2026-02-22 by AUTODEV Testing Worker
# Purpose: Test aspect state transitions, game over detection, souffle economy
# Coverage: MerlinStore core functionality (SHIFT_ASPECT, check_run_end, souffle)

extends GutTest

# Reference to MerlinStore instance
var store: Node

## Setup: Create MerlinStore instance before each test
func before_each():
	store = preload("res://scripts/merlin/merlin_store.gd").new()
	add_child(store)
	# Initialize store with START_RUN action
	if store.has_method("dispatch"):
		store.dispatch({"type": "START_RUN"})

## Cleanup: Free MerlinStore instance after each test
func after_each():
	if is_instance_valid(store):
		store.queue_free()
	store = null

## TEST 1: SHIFT_ASPECT increases aspect value by delta
func test_aspect_shift_up():
	# Given: Store initialized with corps=0
	assert_not_null(store, "Store should be created")

	# When: Dispatch SHIFT_ASPECT with delta=+1
	if store.has_method("dispatch"):
		store.dispatch({"type": "SHIFT_ASPECT", "aspect": "corps", "delta": 1})

	# Then: Corps should be 1
	if store.has("state") and store.state.has("run") and store.state.run.has("aspects"):
		assert_eq(store.state.run.aspects.corps, 1, "Corps should be 1 after +1 shift")
	else:
		fail_test("Store does not have expected state structure")

## TEST 2: SHIFT_ASPECT decreases aspect value by delta
func test_aspect_shift_down():
	# Given: Store initialized with ame=0
	assert_not_null(store, "Store should be created")

	# When: Dispatch SHIFT_ASPECT with delta=-1
	if store.has_method("dispatch"):
		store.dispatch({"type": "SHIFT_ASPECT", "aspect": "ame", "delta": -1})

	# Then: Ame should be -1
	if store.has("state") and store.state.has("run") and store.state.run.has("aspects"):
		assert_eq(store.state.run.aspects.ame, -1, "Ame should be -1 after -1 shift")
	else:
		fail_test("Store does not have expected state structure")

## TEST 3: Aspect values are clamped at +3 (max extreme)
func test_aspect_clamping_max():
	# Given: Store with corps=2
	if store.has("state"):
		store.state.run.aspects.corps = 2

	# When: Dispatch SHIFT_ASPECT with delta=+2 (would result in 4)
	if store.has_method("dispatch"):
		store.dispatch({"type": "SHIFT_ASPECT", "aspect": "corps", "delta": 2})

	# Then: Corps should be clamped at 3
	if store.has("state") and store.state.has("run") and store.state.run.has("aspects"):
		assert_eq(store.state.run.aspects.corps, 3, "Corps should be clamped at +3 (max)")
	else:
		fail_test("Store does not have expected state structure")

## TEST 4: Aspect values are clamped at -3 (min extreme)
func test_aspect_clamping_min():
	# Given: Store with ame=-2
	if store.has("state"):
		store.state.run.aspects.ame = -2

	# When: Dispatch SHIFT_ASPECT with delta=-2 (would result in -4)
	if store.has_method("dispatch"):
		store.dispatch({"type": "SHIFT_ASPECT", "aspect": "ame", "delta": -2})

	# Then: Ame should be clamped at -3
	if store.has("state") and store.state.has("run") and store.state.run.has("aspects"):
		assert_eq(store.state.run.aspects.ame, -3, "Ame should be clamped at -3 (min)")
	else:
		fail_test("Store does not have expected state structure")

## TEST 5: Game over when 2 aspects reach extreme values (-3 or +3)
func test_game_over_two_extremes():
	# Given: Store with corps=3, ame=-3 (2 extremes)
	if store.has("state"):
		store.state.run.aspects.corps = 3
		store.state.run.aspects.ame = -3

	# When: Check run end condition
	var result = null
	if store.has_method("check_run_end"):
		result = store.check_run_end()

	# Then: Run should end (result.ended = true)
	if result != null:
		assert_true(result.ended, "Run should end with 2 extreme aspects")
		# Optionally verify ending type (fall ending expected)
		if result.has("ending_type"):
			assert_eq(result.ending_type, "fall", "Ending should be a fall ending")
	else:
		fail_test("check_run_end() did not return a result")

## TEST 6: Souffle is deducted when using souffle cost
func test_souffle_cost_deduction():
	# Given: Store with souffle=5
	if store.has("state"):
		store.state.run.souffle = 5

	# When: Dispatch USE_SOUFFLE with cost=2
	if store.has_method("dispatch"):
		store.dispatch({"type": "USE_SOUFFLE", "cost": 2})

	# Then: Souffle should be 3
	if store.has("state") and store.state.has("run"):
		assert_eq(store.state.run.souffle, 3, "Souffle should be 3 after deducting cost 2")
	else:
		fail_test("Store does not have expected state structure")

## TEST 7: Risk Mode activates when souffle reaches 0
func test_souffle_risk_mode():
	# Given: Store with souffle=1
	if store.has("state"):
		store.state.run.souffle = 1

	# When: Dispatch USE_SOUFFLE with cost=1
	if store.has_method("dispatch"):
		store.dispatch({"type": "USE_SOUFFLE", "cost": 1})

	# Then: Souffle should be 0 and risk_mode should be true
	if store.has("state") and store.state.has("run"):
		assert_eq(store.state.run.souffle, 0, "Souffle should be 0")
		if store.state.run.has("risk_mode"):
			assert_true(store.state.run.risk_mode, "Risk Mode should be activated")
		else:
			pending("risk_mode field not yet implemented in MerlinStore")
	else:
		fail_test("Store does not have expected state structure")

## NOTE: These tests assume MerlinStore implements:
## - dispatch(action: Dictionary) -> void
## - check_run_end() -> Dictionary {ended: bool, ending_type: String}
## - state.run.aspects.{corps, ame, monde}: int (-3 to +3)
## - state.run.souffle: int (0 to 7)
## - state.run.risk_mode: bool (optional)
##
## If MerlinStore structure differs, adapt tests accordingly.
## Priority: Run validate_editor_parse.ps1 after writing this file.
