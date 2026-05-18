## ═══════════════════════════════════════════════════════════════════════════════
## Test harness for RunCompletionHook (Sprint 12.4(d) validation)
## ═══════════════════════════════════════════════════════════════════════════════
## Validates the end-of-run hook without depending on a live MerlinStore or
## Python sidecar.
##
## Phases:
##   1. process_run_end with synthetic run -> profile updated, events returned
##   2. run_recorded signal fires with events
##   3. build_run_dict_from_store with a mock store-like Node
##   4. Profile persists across hook instances (load + grant + reload)
##   5. Idle path : adaptive_traits disabled (env unset) -> no sidecar attempt
##
## Usage: godot --headless --quit-after 12 res://scenes/TestRunCompletionHook.tscn
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

const HookScript = preload("res://scripts/run_completion_hook.gd")
const ProfileSystemScript = preload("res://addons/merlin_ai/profile_system.gd")

const TEST_PROFILE_PATH := "user://test_run_completion_profile.json"

var _failures: int = 0


func _ready() -> void:
	print("[TEST] RunCompletionHook harness starting...")
	for suffix in ["", ".phase2", ".phase4", ".phase5"]:
		var p: String = TEST_PROFILE_PATH + suffix
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

	_phase_1_process_run_end()
	_phase_2_signal_fires()
	_phase_3_build_from_store()
	_phase_4_persistence_across_instances()
	_phase_5_adaptive_disabled_by_default()

	if _failures == 0:
		print("[TEST] ALL PHASES PASSED")
		get_tree().quit(0)
	else:
		printerr("[TEST] %d FAILURES" % _failures)
		get_tree().quit(1)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  %s" % msg)
	else:
		printerr("  FAIL  %s" % msg)
		_failures += 1


# ═══════════════════════════════════════════════════════════════════════════════
# PHASES
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_1_process_run_end() -> void:
	print("[TEST] Phase 1 - process_run_end + XP from synthetic run")
	var hook: Node = HookScript.new()
	add_child(hook)
	hook.set_profile_path(TEST_PROFILE_PATH)

	var run_dict := {
		"cards_played": [
			{"dc_result": "success"},
			{"dc_result": "partial"},
			{"dc_result": "success"},
			{"dc_result": "failure"},
			{"dc_result": "success"},
			{"dc_result": "partial"},
			{"dc_result": "success"},
			{"dc_result": "success"},
		],
		"final_state": {
			"faction_rep": {"druides": 12, "ankou": 4},
			"tags": ["geste_accueil"],
			"karma": 2,
			"life_essence": 80,
		},
	}
	var events: Array = hook.process_run_end(run_dict)
	_assert(events.size() >= 2, "events returned (got %d)" % events.size())
	var run_event: Dictionary = events[0]
	_assert(run_event["event"] == "run_completed", "first event = run_completed")
	# Expected XP : 100 base + 150 (5*30) + 50 emergence + 10 tag + 10 karma + 50 life = 370
	_assert(int(run_event["xp_total_from_run"]) == 370, "XP = 370 (got %d)" % int(run_event["xp_total_from_run"]))

	var summary: Dictionary = hook.get_profile_summary()
	_assert(summary["xp_total"] == 370, "profile xp_total == 370")
	_assert(summary["completed_runs"] == 1, "completed_runs == 1")
	hook.queue_free()


func _phase_2_signal_fires() -> void:
	print("[TEST] Phase 2 - run_recorded signal fires")
	var hook: Node = HookScript.new()
	add_child(hook)
	hook.set_profile_path(TEST_PROFILE_PATH + ".phase2")

	var signal_payloads: Array = []
	hook.run_recorded.connect(func(events): signal_payloads.append(events))

	var run_dict := {
		"cards_played": [{"dc_result": "success"}],
		"final_state": {"faction_rep": {"druides": 5}, "tags": [], "karma": 0, "life_essence": 70},
	}
	hook.process_run_end(run_dict)
	_assert(signal_payloads.size() == 1, "signal fired exactly once (got %d)" % signal_payloads.size())
	if signal_payloads.size() >= 1:
		var events: Array = signal_payloads[0]
		_assert(events.size() >= 2, "payload contains events (got %d)" % events.size())
	hook.queue_free()


func _phase_3_build_from_store() -> void:
	print("[TEST] Phase 3 - build_run_dict_from_store with mock store")
	var hook: Node = HookScript.new()
	add_child(hook)

	# Mock store exposing get_state() (the preferred path in the hook).
	var mock_script := GDScript.new()
	mock_script.source_code = """extends Node
func get_state() -> Dictionary:
	return {
		\"faction_rep\": {\"niamh\": 7},
		\"life_essence\": 55,
		\"karma\": 3,
		\"tags\": [\"regard_attentif\"],
		\"cards_played\": [{\"dc_result\": \"partial\"}],
	}
"""
	mock_script.reload()
	var mock_store := Node.new()
	mock_store.set_script(mock_script)
	add_child(mock_store)

	var run_dict: Dictionary = hook.build_run_dict_from_store(mock_store)
	_assert(not run_dict.is_empty(), "non-empty run_dict")
	var rep: Dictionary = run_dict["final_state"]["faction_rep"]
	_assert(int(rep.get("niamh", 0)) == 7, "faction_rep.niamh == 7 (got %s)" % rep)
	_assert(int(run_dict["final_state"]["life_essence"]) == 55, "life_essence == 55")
	_assert(int(run_dict["final_state"]["karma"]) == 3, "karma == 3")
	var tags: Array = run_dict["final_state"]["tags"]
	_assert(tags.size() >= 1 and String(tags[0]) == "regard_attentif", "tags propagated")
	_assert(run_dict["cards_played"].size() == 1, "cards_played has 1 entry")

	var empty: Dictionary = hook.build_run_dict_from_store(null)
	_assert(empty.is_empty(), "null store returns empty dict")

	hook.queue_free()
	mock_store.queue_free()


func _phase_4_persistence_across_instances() -> void:
	print("[TEST] Phase 4 - profile persists between hook instances")
	var test_path := TEST_PROFILE_PATH + ".phase4"

	var hook1: Node = HookScript.new()
	add_child(hook1)
	hook1.set_profile_path(test_path)
	hook1.process_run_end({
		"cards_played": [{"dc_result": "success"}, {"dc_result": "success"}],
		"final_state": {"faction_rep": {"druides": 12}, "tags": [], "karma": 0, "life_essence": 80},
	})
	var s1: Dictionary = hook1.get_profile_summary()
	hook1.queue_free()

	var hook2: Node = HookScript.new()
	add_child(hook2)
	hook2.set_profile_path(test_path)
	hook2.process_run_end({
		"cards_played": [{"dc_result": "success"}],
		"final_state": {"faction_rep": {"druides": 5}, "tags": [], "karma": 0, "life_essence": 60},
	})
	var s2: Dictionary = hook2.get_profile_summary()
	_assert(s2["completed_runs"] == 2, "completed_runs persisted (=2, got %d)" % s2["completed_runs"])
	_assert(s2["xp_total"] > s1["xp_total"], "xp_total increased (%d > %d)" % [s2["xp_total"], s1["xp_total"]])
	hook2.queue_free()


func _phase_5_adaptive_disabled_by_default() -> void:
	print("[TEST] Phase 5 - adaptive_traits OFF by default (no sidecar attempt)")
	var hook: Node = HookScript.new()
	add_child(hook)
	hook.set_profile_path(TEST_PROFILE_PATH + ".phase5")
	var sidecar_attempts: Array = []
	hook.sidecar_spawned.connect(func(pid): sidecar_attempts.append({"event": "spawn", "pid": pid}))
	hook.sidecar_error.connect(func(msg): sidecar_attempts.append({"event": "error", "msg": msg}))
	hook.process_run_end({
		"cards_played": [{"dc_result": "success"}],
		"final_state": {"faction_rep": {"druides": 12}, "tags": ["t"], "karma": 0, "life_essence": 80},
	})
	_assert(sidecar_attempts.is_empty(), "no sidecar signals when env unset (got %d)" % sidecar_attempts.size())
	hook.queue_free()
