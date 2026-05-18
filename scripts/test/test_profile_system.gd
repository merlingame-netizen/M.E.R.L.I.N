## ═══════════════════════════════════════════════════════════════════════════════
## Test harness for MerlinProfile (Sprint 12.4 in-game port validation)
## ═══════════════════════════════════════════════════════════════════════════════
## Mirrors the Python smoke that was run on tools/profile_system.py :
##   1. Init fresh profile at user://test_profile.json -> verify L1 starter
##   2. XP curve consistency (static functions)
##   3. grant_xp_from_run on a synthetic v731 trace -> verify XP breakdown
##   4. grant_xp(5000) -> verify L1 -> L7 level-up cascade + unlocks
##   5. add_trait x2 + duplicate -> verify trait_slots_active cap
##      add_memory_slot x4 -> verify memory_slots_total cap
##   6. save + reload -> verify persistence
##
## Usage:
##   godot --headless --quit-after 5 res://scenes/TestProfileSystem.tscn
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

const ProfileSystemScript = preload("res://addons/merlin_ai/profile_system.gd")

const TEST_PROFILE_PATH := "user://test_profile.json"

var _failures: int = 0


func _ready() -> void:
	print("[TEST] MerlinProfile harness starting...")
	# Remove any stale test profile.
	if FileAccess.file_exists(TEST_PROFILE_PATH):
		var globalised := ProjectSettings.globalize_path(TEST_PROFILE_PATH)
		DirAccess.remove_absolute(globalised)

	var profile: Node = ProfileSystemScript.new()
	add_child(profile)

	_phase_1_init(profile)
	_phase_2_xp_curve()
	_phase_3_grant_from_run(profile)
	_phase_4_level_cascade(profile)
	_phase_5_traits_and_memory(profile)
	_phase_6_persist_and_reload(profile)

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


func _phase_1_init(profile: Node) -> void:
	print("[TEST] Phase 1 - fresh init")
	var ok: bool = profile.load_profile(TEST_PROFILE_PATH)
	_assert(ok, "load_profile returned true")
	var s: Dictionary = profile.summary()
	_assert(s["level"] == 1, "level == 1")
	_assert(s["xp_total"] == 0, "xp_total == 0")
	_assert(s["souffle_max"] == 5, "souffle_max == 5")
	_assert(s["essence_max"] == 20, "essence_max == 20")
	_assert(s["n_unlocked_oghams"] == 3, "3 starter oghams")
	for ogham in ["beith", "luis", "nion"]:
		_assert(ogham in s["unlocked_oghams"], "ogham %s in unlocked" % ogham)


func _phase_2_xp_curve() -> void:
	print("[TEST] Phase 2 - XP curve consistency")
	_assert(ProfileSystemScript.total_xp_for_level(1) == 100, "L1 = 100 XP")
	_assert(ProfileSystemScript.total_xp_for_level(5) == 2500, "L5 = 2500 XP")
	_assert(ProfileSystemScript.total_xp_for_level(10) == 10000, "L10 = 10000 XP")
	_assert(ProfileSystemScript.total_xp_for_level(30) == 90000, "L30 = 90000 XP")
	_assert(ProfileSystemScript.level_from_total_xp(0) == 1, "xp=0 -> L1")
	_assert(ProfileSystemScript.level_from_total_xp(100) == 1, "xp=100 -> L1 (floor)")
	_assert(ProfileSystemScript.level_from_total_xp(2500) == 5, "xp=2500 -> L5")
	_assert(ProfileSystemScript.level_from_total_xp(10000) == 10, "xp=10000 -> L10")
	_assert(ProfileSystemScript.xp_to_next_level(5000) > 0, "xp_to_next_level > 0 mid-curve")


func _phase_3_grant_from_run(profile: Node) -> void:
	print("[TEST] Phase 3 - XP from run heuristic")
	# Synthetic run mirroring the Python smoke numbers (5 successes, 1 tag,
	# 2 karma, faction rep druides=10, life=75).
	var synthetic_run := {
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
			"faction_rep": {"druides": 10, "ankou": 5},
			"tags": ["geste_accueil"],
			"karma": 2,
			"life_essence": 75,
		},
	}
	var events: Array = profile.grant_xp_from_run(synthetic_run)
	_assert(events.size() >= 2, "events returned")
	var run_event := events[0] as Dictionary
	_assert(run_event["event"] == "run_completed", "first event = run_completed")
	var bd := run_event["xp_breakdown"] as Dictionary
	_assert(int(bd["base_completion"]) == 100, "base = 100")
	_assert(int(bd["dc_success_bonus"]) == 150, "5 successes x 30 = 150")
	_assert(int(bd["faction_emergence_bonus"]) == 50, "emergence rep>=10 = 50")
	_assert(int(bd["tag_bonus"]) == 10, "1 tag x 10 = 10")
	_assert(int(bd["karma_bonus"]) == 10, "2 karma x 5 = 10")
	_assert(int(bd["life_bonus"]) == 0, "life=75 below 80, no bonus")
	_assert(int(run_event["xp_total_from_run"]) == 320, "total = 320 XP")


func _phase_4_level_cascade(profile: Node) -> void:
	print("[TEST] Phase 4 - level-up cascade")
	var events: Array = profile.grant_xp(5000, "debug")
	var s: Dictionary = profile.summary()
	_assert(s["level"] == 7, "level == 7 after +5000")
	_assert(s["xp_total"] == 5320, "xp_total == 5320")
	_assert(s["souffle_max"] == 6, "souffle_max +1 from L5 = 6")
	_assert(s["essence_max"] == 25, "essence_max +5 from L5 = 25")
	_assert(s["n_unlocked_oghams"] == 6, "+3 T2 oghams at L5 = 6 total")
	for ogham in ["fearn", "saille", "huath"]:
		_assert(ogham in s["unlocked_oghams"], "ogham %s unlocked at L5+" % ogham)
	_assert(int(profile.character["trait_slots_active"]) == 3, "trait_slots_active == 3 at L7")
	_assert(int(profile.character["memory_slots_total"]) == 2, "memory_slots_total == 2 at L7")
	var level_up_count := 0
	for e in events:
		if e.get("event", "") == "level_up":
			level_up_count += 1
	_assert(level_up_count == 6, "6 level-up events fired (L1->L7)")


func _phase_5_traits_and_memory(profile: Node) -> void:
	print("[TEST] Phase 5 - trait + memory cap")
	var t1 := {
		"trait_id": "trait_liminal_observeur",
		"name": "Le seuil des regards",
		"prose": "Tu te tiens au bord.",
		"effect_spec": "BIAS_KNN:emotion:fascination:+0.05",
		"rarity": "rare_emergence",
		"source": "adaptive_emergence",
	}
	var t2 := {
		"trait_id": "trait_promesse_tenue",
		"name": "Parole de chene",
		"prose": "Une promesse honoree.",
		"effect_spec": "UNLOCK_OPTION_TAG:promesse_tenue",
		"rarity": "commune",
		"source": "adaptive_emergence",
	}
	_assert(profile.add_trait(t1), "trait 1 added")
	_assert(profile.add_trait(t2), "trait 2 added")
	_assert(not profile.add_trait(t1), "duplicate trait_id rejected")
	var s: Dictionary = profile.summary()
	_assert(s["n_traits"] == 2, "2 traits total")
	_assert(s["active_traits"].size() == 2, "2 active (cap 3)")

	_assert(profile.add_memory_slot("sanglier_soigne", 1), "memslot 1 added")
	_assert(profile.add_memory_slot("cercle_brise", 1), "memslot 2 added")
	_assert(not profile.add_memory_slot("overflow_test", 1), "memslot 3 rejected (cap 2)")
	_assert(not profile.add_memory_slot("sanglier_soigne", 1), "duplicate tag rejected")
	var s2: Dictionary = profile.summary()
	_assert(s2["memory_slots"].size() == 2, "2 memory slots pinned")


func _phase_6_persist_and_reload(profile: Node) -> void:
	print("[TEST] Phase 6 - persist + reload")
	var ok: bool = profile.save_profile()
	_assert(ok, "save_profile returned true")
	_assert(FileAccess.file_exists(TEST_PROFILE_PATH), "test profile file exists on disk")

	var reloaded: Node = ProfileSystemScript.new()
	add_child(reloaded)
	var ok2: bool = reloaded.load_profile(TEST_PROFILE_PATH)
	_assert(ok2, "reload from disk")
	var s: Dictionary = reloaded.summary()
	_assert(s["level"] == 7, "reloaded level == 7")
	_assert(s["n_traits"] == 2, "reloaded traits == 2")
	_assert(s["memory_slots"].size() == 2, "reloaded memory == 2")
	_assert(s["unlocked_oghams"].size() == 6, "reloaded oghams == 6")
