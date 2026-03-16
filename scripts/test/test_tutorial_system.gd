## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — TutorialSystem
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: step progression, skip, completion persistence, hint text,
## signal emission, tooltip system, first-run detection, forced biome.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_mock_store() -> MerlinStore:
	var store: MerlinStore = MerlinStore.new()
	return store


func _make_tutorial(store: MerlinStore) -> TutorialSystem:
	var tutorial: TutorialSystem = TutorialSystem.new()
	tutorial.initialize(store)
	return tutorial


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: INITIAL STATE
# ═══════════════════════════════════════════════════════════════════════════════

func test_initial_state_not_complete() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	if tutorial.is_complete():
		push_error("Tutorial should not be complete initially")
		return false
	if tutorial.get_current_step() != TutorialSystem.TutorialStep.NONE:
		push_error("Initial step should be NONE, got: %d" % tutorial.get_current_step())
		return false
	return true


func test_initial_hint_text_empty() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	var hint: String = tutorial.get_hint_text()
	if not hint.is_empty():
		push_error("Hint should be empty before tutorial starts, got: %s" % hint)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: START TUTORIAL
# ═══════════════════════════════════════════════════════════════════════════════

func test_start_sets_intro_step() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	tutorial.start_tutorial()
	if tutorial.get_current_step() != TutorialSystem.TutorialStep.INTRO:
		push_error("After start, step should be INTRO, got: %d" % tutorial.get_current_step())
		return false
	return true


func test_start_emits_step_changed() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	var received: Array = []
	tutorial.step_changed.connect(func(step: int) -> void: received.append(step))
	tutorial.start_tutorial()
	if received.is_empty() or received[0] != TutorialSystem.TutorialStep.INTRO:
		push_error("step_changed should emit INTRO (0), got: %s" % str(received))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: STEP PROGRESSION
# ═══════════════════════════════════════════════════════════════════════════════

func test_advance_progresses_steps() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	tutorial.start_tutorial()
	# Advance through all steps
	var expected_steps: Array[int] = [
		TutorialSystem.TutorialStep.HUB_TOUR,
		TutorialSystem.TutorialStep.BIOME_SELECT,
		TutorialSystem.TutorialStep.OGHAM_INTRO,
		TutorialSystem.TutorialStep.FIRST_CARD,
		TutorialSystem.TutorialStep.FIRST_MINIGAME,
		TutorialSystem.TutorialStep.FIRST_EFFECTS,
		TutorialSystem.TutorialStep.COMPLETE,
	]
	for i in range(expected_steps.size()):
		tutorial.advance()
		var current: int = tutorial.get_current_step()
		if current != expected_steps[i]:
			push_error("Step %d: expected %d, got %d" % [i, expected_steps[i], current])
			return false
	return true


func test_advance_from_none_does_nothing() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	# Do NOT call start_tutorial — step is NONE
	tutorial.advance()
	if tutorial.get_current_step() != TutorialSystem.TutorialStep.NONE:
		push_error("Advance from NONE should stay at NONE")
		return false
	return true


func test_advance_past_complete_stays_complete() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	tutorial.start_tutorial()
	# Advance through all steps to COMPLETE
	for i in range(TutorialSystem.STEP_COUNT):
		tutorial.advance()
	# Try advancing past COMPLETE
	tutorial.advance()
	if tutorial.get_current_step() != TutorialSystem.TutorialStep.COMPLETE:
		push_error("Should stay at COMPLETE after extra advance")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: SKIP
# ═══════════════════════════════════════════════════════════════════════════════

func test_skip_marks_complete() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	tutorial.skip_tutorial()
	if not tutorial.is_complete():
		push_error("Skip should mark tutorial complete")
		return false
	if tutorial.get_current_step() != TutorialSystem.TutorialStep.COMPLETE:
		push_error("Skip should set step to COMPLETE")
		return false
	return true


func test_skip_emits_both_signals() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	var step_received: Array = []
	var completed_received: Array = []
	tutorial.step_changed.connect(func(step: int) -> void: step_received.append(step))
	tutorial.tutorial_completed.connect(func() -> void: completed_received.append(true))
	tutorial.skip_tutorial()
	if step_received.is_empty():
		push_error("Skip should emit step_changed")
		return false
	if completed_received.is_empty():
		push_error("Skip should emit tutorial_completed")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: COMPLETION PERSISTENCE
# ═══════════════════════════════════════════════════════════════════════════════

func test_completion_persists_in_meta() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	tutorial.skip_tutorial()
	var meta: Dictionary = store.state.get("meta", {})
	if not bool(meta.get("tutorial_completed", false)):
		push_error("tutorial_completed should be true in meta after skip")
		return false
	return true


func test_completed_tutorial_cannot_restart() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	tutorial.skip_tutorial()
	# Try to restart
	tutorial.start_tutorial()
	if tutorial.get_current_step() != TutorialSystem.TutorialStep.COMPLETE:
		push_error("Completed tutorial should not restart")
		return false
	return true


func test_loads_completion_from_existing_profile() -> bool:
	var store: MerlinStore = _make_mock_store()
	# Simulate a profile that already has tutorial_completed = true
	var meta: Dictionary = store.state.get("meta", {}).duplicate(true)
	meta["tutorial_completed"] = true
	store.state["meta"] = meta
	var tutorial: TutorialSystem = _make_tutorial(store)
	if not tutorial.is_complete():
		push_error("Should load completion from existing profile")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: HINT TEXTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_hint_text_for_each_step() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	tutorial.start_tutorial()
	# Check INTRO hint
	var intro_hint: String = tutorial.get_hint_text()
	if intro_hint.is_empty():
		push_error("INTRO step should have a hint text")
		return false
	if not intro_hint.contains("Merlin"):
		push_error("INTRO hint should mention Merlin")
		return false
	# Advance through all steps and verify each has a hint
	for i in range(TutorialSystem.STEP_COUNT - 1):
		tutorial.advance()
		var hint: String = tutorial.get_hint_text()
		if hint.is_empty():
			push_error("Step %d should have a hint text" % tutorial.get_current_step())
			return false
	return true


func test_step_name_returns_valid_string() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	if tutorial.get_current_step_name() != "NONE":
		push_error("Initial step name should be NONE")
		return false
	tutorial.start_tutorial()
	if tutorial.get_current_step_name() != "INTRO":
		push_error("After start, step name should be INTRO")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: TOOLTIP SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

func test_tooltip_shows_once() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	var text1: String = tutorial.try_show_tooltip("first_minigame")
	if text1.is_empty():
		push_error("First tooltip call should return text")
		return false
	var text2: String = tutorial.try_show_tooltip("first_minigame")
	if not text2.is_empty():
		push_error("Second tooltip call should return empty (already shown)")
		return false
	return true


func test_tooltip_unknown_trigger_returns_empty() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	var text: String = tutorial.try_show_tooltip("nonexistent_trigger")
	if not text.is_empty():
		push_error("Unknown trigger should return empty string")
		return false
	return true


func test_tooltip_flags_persist_in_meta() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	tutorial.try_show_tooltip("first_faction_change")
	var meta: Dictionary = store.state.get("meta", {})
	var flags: Dictionary = meta.get("tutorial_flags", {})
	if not bool(flags.get("first_faction_change", false)):
		push_error("Tooltip flag should persist in meta.tutorial_flags")
		return false
	return true


func test_shown_tooltip_count() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	if tutorial.get_shown_tooltip_count() != 0:
		push_error("Initial tooltip count should be 0")
		return false
	tutorial.try_show_tooltip("first_minigame")
	tutorial.try_show_tooltip("first_promise")
	if tutorial.get_shown_tooltip_count() != 2:
		push_error("After 2 tooltips, count should be 2, got: %d" % tutorial.get_shown_tooltip_count())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: FIRST RUN DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_first_run_detection() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	if not tutorial.is_first_run():
		push_error("Should detect first run when total_runs = 0 and not completed")
		return false
	return true


func test_not_first_run_after_completion() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	tutorial.skip_tutorial()
	if tutorial.is_first_run():
		push_error("Should not be first run after tutorial completion")
		return false
	return true


func test_forced_biome_on_first_run() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	var biome: String = tutorial.get_forced_biome()
	if biome != "foret_broceliande":
		push_error("First run should force foret_broceliande, got: %s" % biome)
		return false
	return true


func test_no_forced_biome_after_completion() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	tutorial.skip_tutorial()
	var biome: String = tutorial.get_forced_biome()
	if not biome.is_empty():
		push_error("No forced biome after tutorial completion, got: %s" % biome)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: COMPLETE STEP EMITS TUTORIAL_COMPLETED
# ═══════════════════════════════════════════════════════════════════════════════

func test_reaching_complete_emits_signal() -> bool:
	var store: MerlinStore = _make_mock_store()
	var tutorial: TutorialSystem = _make_tutorial(store)
	var completed_received: Array = []
	tutorial.tutorial_completed.connect(func() -> void: completed_received.append(true))
	tutorial.start_tutorial()
	# Advance through all steps to COMPLETE
	for i in range(TutorialSystem.STEP_COUNT - 1):
		tutorial.advance()
	if completed_received.is_empty():
		push_error("tutorial_completed signal should fire when reaching COMPLETE step")
		return false
	if not tutorial.is_complete():
		push_error("Tutorial should be marked complete")
		return false
	return true
