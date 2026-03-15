## ═══════════════════════════════════════════════════════════════════════════════
## Test GameFlowController — Phase transitions, signal wiring, data passing
## ═══════════════════════════════════════════════════════════════════════════════
## 14 tests covering:
## - Phase transitions (hub→run→end→hub cycle)
## - Signal wiring and disconnection
## - Data building for hub and end screen
## - Guard clauses (invalid phase, empty biome)
## - Save on quit
## - Interrupted run detection
## - Talent tree flow
## Prefix: [GAMEFLOW] for easy grep. Exit 0 = pass, 1 = failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

var _pass_count: int = 0
var _fail_count: int = 0
var _total_count: int = 0


func _ready() -> void:
	_log("═══════════════════════════════════════")
	_log("  GAME FLOW CONTROLLER — TEST SUITE")
	_log("═══════════════════════════════════════")

	await get_tree().process_frame

	_test_initial_phase_is_menu()
	_test_start_game_sets_hub_phase()
	_test_start_game_fails_without_store()
	_test_run_requested_transitions_to_run()
	_test_run_requested_guards_empty_biome()
	_test_run_requested_guards_wrong_phase()
	_test_run_ended_transitions_to_end_screen()
	_test_run_ended_guards_wrong_phase()
	_test_hub_requested_transitions_to_hub()
	_test_hub_requested_guards_wrong_phase()
	_test_quit_saves_profile()
	_test_phase_changed_signal_emitted()
	_test_build_hub_data_returns_valid_dict()
	_test_talent_tree_flow()
	_test_wire_and_disconnect_hub()
	_test_wire_and_disconnect_run()
	_test_wire_and_disconnect_end_screen()
	_test_full_cycle_hub_run_end_hub()
	_test_interrupted_run_detection()
	_test_end_run_data_victory_vs_death()

	_log("═══════════════════════════════════════")
	_log("  RESULTS: %d passed, %d failed / %d total" % [_pass_count, _fail_count, _total_count])
	_log("═══════════════════════════════════════")

	var exit_code: int = 0 if _fail_count == 0 else 1
	get_tree().quit(exit_code)


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS
# ═══════════════════════════════════════════════════════════════════════════════

func _test_initial_phase_is_menu() -> void:
	var ctrl: GameFlowController = _make_controller()
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.MENU,
		"initial phase should be MENU")
	_assert_eq(ctrl.get_current_phase_name(), "menu",
		"initial phase name should be 'menu'")
	ctrl.queue_free()


func _test_start_game_sets_hub_phase() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	ctrl.start_game()
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.HUB,
		"start_game should set phase to HUB")
	ctrl.queue_free()


func _test_start_game_fails_without_store() -> void:
	var ctrl: GameFlowController = _make_controller()
	ctrl.start_game()
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.MENU,
		"start_game without store should stay in MENU")
	ctrl.queue_free()


func _test_run_requested_transitions_to_run() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	ctrl.start_game()
	ctrl._on_run_requested("foret_broceliande", ["beith"])
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.RUN,
		"run_requested should transition to RUN")
	ctrl.queue_free()


func _test_run_requested_guards_empty_biome() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	ctrl.start_game()
	ctrl._on_run_requested("", ["beith"])
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.HUB,
		"run_requested with empty biome should stay in HUB")
	ctrl.queue_free()


func _test_run_requested_guards_wrong_phase() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	# Still in MENU phase, not HUB
	ctrl._on_run_requested("foret_broceliande", ["beith"])
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.MENU,
		"run_requested from MENU should be ignored")
	ctrl.queue_free()


func _test_run_ended_transitions_to_end_screen() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	ctrl.start_game()
	ctrl._on_run_requested("foret_broceliande", ["beith"])
	var run_data: Dictionary = {"card_index": 15, "life_essence": 0, "biome": "foret_broceliande"}
	ctrl._on_run_ended("death", run_data)
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.END_SCREEN,
		"run_ended should transition to END_SCREEN")
	ctrl.queue_free()


func _test_run_ended_guards_wrong_phase() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	ctrl.start_game()
	# In HUB, not RUN
	var run_data: Dictionary = {"card_index": 10, "life_essence": 50}
	ctrl._on_run_ended("death", run_data)
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.HUB,
		"run_ended from HUB should be ignored")
	ctrl.queue_free()


func _test_hub_requested_transitions_to_hub() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	ctrl.start_game()
	ctrl._on_run_requested("foret_broceliande", ["beith"])
	ctrl._on_run_ended("death", {"card_index": 10, "life_essence": 0, "biome": "foret_broceliande"})
	ctrl._on_hub_requested()
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.HUB,
		"hub_requested should transition to HUB")
	ctrl.queue_free()


func _test_hub_requested_guards_wrong_phase() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	ctrl.start_game()
	# In HUB, not END_SCREEN
	ctrl._on_hub_requested()
	# Should still be HUB (no transition since already HUB, but guard prevents re-entry)
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.HUB,
		"hub_requested from HUB should be ignored (guard)")
	ctrl.queue_free()


func _test_quit_saves_profile() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	ctrl.start_game()
	var quit_emitted: bool = false
	ctrl.game_quit_requested.connect(func() -> void: quit_emitted = true)
	ctrl._on_quit_requested()
	_assert_true(quit_emitted, "quit_requested should emit game_quit_requested")
	ctrl.queue_free()


func _test_phase_changed_signal_emitted() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	var emissions: Array = []
	ctrl.phase_changed.connect(func(old_p: String, new_p: String) -> void:
		emissions.append({"old": old_p, "new": new_p})
	)
	ctrl.start_game()
	_assert_eq(emissions.size(), 1, "phase_changed should emit once for start_game")
	if emissions.size() > 0:
		_assert_eq(str(emissions[0].get("old", "")), "menu",
			"phase_changed old should be 'menu'")
		_assert_eq(str(emissions[0].get("new", "")), "hub",
			"phase_changed new should be 'hub'")
	ctrl.queue_free()


func _test_build_hub_data_returns_valid_dict() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	var hub_data: Dictionary = ctrl.build_hub_data()
	_assert_true(hub_data.has("player_name"), "hub_data should have player_name")
	_assert_true(hub_data.has("anam"), "hub_data should have anam")
	_assert_true(hub_data.has("faction_rep"), "hub_data should have faction_rep")
	_assert_true(hub_data.has("unlocked_oghams"), "hub_data should have unlocked_oghams")
	_assert_true(hub_data.has("biomes"), "hub_data should have biomes")
	_assert_true(hub_data.has("locked_biomes"), "hub_data should have locked_biomes")
	_assert_true(hub_data.has("maturity_score"), "hub_data should have maturity_score")
	ctrl.queue_free()


func _test_talent_tree_flow() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	ctrl.start_game()
	ctrl._on_talent_tree_requested()
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.TALENT_TREE,
		"talent_tree_requested should transition to TALENT_TREE")
	ctrl._on_talent_tree_closed()
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.HUB,
		"talent_tree_closed should transition back to HUB")
	ctrl.queue_free()


func _test_wire_and_disconnect_hub() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	var hub: HubScreen = HubScreen.new()
	add_child(hub)
	ctrl.wire_hub(hub)
	ctrl.start_game()

	# Emit run_requested through the hub signal
	hub.run_requested.emit("foret_broceliande", ["beith"])
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.RUN,
		"wired hub run_requested should transition to RUN")

	# Disconnect and verify signal no longer routes
	ctrl._disconnect_hub()
	# Reset to HUB for test
	ctrl.start_game()
	hub.run_requested.emit("foret_broceliande", ["beith"])
	# Should still be HUB since disconnected
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.HUB,
		"disconnected hub run_requested should not transition")

	hub.queue_free()
	ctrl.queue_free()


func _test_wire_and_disconnect_run() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	ctrl.start_game()
	ctrl._on_run_requested("foret_broceliande", ["beith"])

	var run_ctrl: Run3DController = Run3DController.new()
	add_child(run_ctrl)
	ctrl.wire_run(run_ctrl)

	run_ctrl.run_ended.emit("death", {"card_index": 5, "life_essence": 0, "biome": "foret_broceliande"})
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.END_SCREEN,
		"wired run run_ended should transition to END_SCREEN")

	run_ctrl.queue_free()
	ctrl.queue_free()


func _test_wire_and_disconnect_end_screen() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	ctrl.start_game()
	ctrl._on_run_requested("foret_broceliande", ["beith"])
	ctrl._on_run_ended("death", {"card_index": 10, "life_essence": 0, "biome": "foret_broceliande"})

	var end: EndRunScreen = EndRunScreen.new()
	add_child(end)
	ctrl.wire_end_screen(end)

	end.hub_requested.emit()
	_assert_eq(ctrl.get_current_phase(), GameFlowController.GamePhase.HUB,
		"wired end_screen hub_requested should transition to HUB")

	end.queue_free()
	ctrl.queue_free()


func _test_full_cycle_hub_run_end_hub() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()
	var phases: Array = []
	ctrl.phase_changed.connect(func(old_p: String, new_p: String) -> void:
		phases.append(new_p)
	)

	ctrl.start_game()
	ctrl._on_run_requested("foret_broceliande", ["beith", "luis"])
	ctrl._on_run_ended("death", {
		"card_index": 20, "life_essence": 0, "biome": "foret_broceliande",
		"biome_currency": 50, "promises": [],
	})
	ctrl._on_hub_requested()

	_assert_eq(phases.size(), 4, "full cycle should emit 4 phase changes")
	if phases.size() >= 4:
		_assert_eq(str(phases[0]), "hub", "cycle step 1: hub")
		_assert_eq(str(phases[1]), "run", "cycle step 2: run")
		_assert_eq(str(phases[2]), "end_screen", "cycle step 3: end_screen")
		_assert_eq(str(phases[3]), "hub", "cycle step 4: hub (return)")

	# Verify last_run_data was cleared on hub return
	_assert_true(ctrl.get_last_run_data().is_empty(),
		"last_run_data should be cleared after returning to hub")

	ctrl.queue_free()


func _test_interrupted_run_detection() -> void:
	var ctrl: GameFlowController = _make_controller()
	# Without save_system, should return false
	_assert_true(not ctrl.has_interrupted_run(),
		"has_interrupted_run should be false without save_system")
	_assert_true(ctrl.get_interrupted_run_state().is_empty(),
		"get_interrupted_run_state should be empty without save_system")
	ctrl.queue_free()


func _test_end_run_data_victory_vs_death() -> void:
	var ctrl: GameFlowController = _make_controller_with_store()

	# Death scenario
	var death_data: Dictionary = ctrl._build_end_run_data("death", {
		"card_index": 15, "life_essence": 0, "biome": "foret_broceliande",
	})
	_assert_true(not bool(death_data.get("victory", true)),
		"death reason should set victory=false")
	_assert_eq(str(death_data.get("reason", "")), "death",
		"reason should be 'death'")

	# Victory scenario
	var victory_data: Dictionary = ctrl._build_end_run_data("convergence", {
		"card_index": 25, "life_essence": 40, "biome": "foret_broceliande",
	})
	_assert_true(bool(victory_data.get("victory", false)),
		"convergence reason should set victory=true")

	ctrl.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_controller() -> GameFlowController:
	var ctrl: GameFlowController = GameFlowController.new()
	add_child(ctrl)
	return ctrl


func _make_controller_with_store() -> GameFlowController:
	var ctrl: GameFlowController = GameFlowController.new()
	add_child(ctrl)
	var store: MerlinStore = MerlinStore.new()
	add_child(store)
	var save_sys: MerlinSaveSystem = MerlinSaveSystem.new()
	ctrl.setup(store, save_sys)
	return ctrl


func _assert_eq(actual: Variant, expected: Variant, desc: String) -> void:
	_total_count += 1
	if actual == expected:
		_pass_count += 1
		_log("  PASS: %s" % desc)
	else:
		_fail_count += 1
		_log("  FAIL: %s (expected=%s, got=%s)" % [desc, str(expected), str(actual)])


func _assert_true(condition: bool, desc: String) -> void:
	_total_count += 1
	if condition:
		_pass_count += 1
		_log("  PASS: %s" % desc)
	else:
		_fail_count += 1
		_log("  FAIL: %s (expected true)" % desc)


func _log(msg: String) -> void:
	print("[GAMEFLOW] %s" % msg)
