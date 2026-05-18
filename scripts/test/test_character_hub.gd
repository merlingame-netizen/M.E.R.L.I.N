## ═══════════════════════════════════════════════════════════════════════════════
## Test harness for CharacterHub (Sprint 12.4(e) validation)
## ═══════════════════════════════════════════════════════════════════════════════
## Validates the read-only UI displays MerlinProfile state correctly :
##   1. Empty profile : shows level 1, 0 XP, starter oghams
##   2. After grant : level/XP/oghams/stats reflect new state
##   3. After add_trait : active_traits panel shows the trait
##   4. set_profile then external mutation requires refresh() to reflect
##   5. Re-build is idempotent (re-_ready doesn't duplicate nodes)
##
## Usage: godot --headless --quit-after 8 res://scenes/TestCharacterHub.tscn
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

const HubScript = preload("res://scripts/character_hub.gd")
const ProfileSystemScript = preload("res://addons/merlin_ai/profile_system.gd")

var _failures: int = 0


func _ready() -> void:
	print("[TEST] CharacterHub harness starting...")
	await get_tree().process_frame
	_phase_1_empty_profile()
	_phase_2_after_xp_grant()
	_phase_3_after_trait_add()
	_phase_4_external_mutation_requires_refresh()
	_phase_5_rebuild_idempotent()

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


func _make_hub(profile = null) -> Control:
	var hub: Control = HubScript.new()
	add_child(hub)
	if profile:
		hub.set_profile(profile)
	return hub


func _make_profile() -> Node:
	var p: Node = ProfileSystemScript.new()
	add_child(p)
	p._apply_level_unlocks(1)
	return p


# ═══════════════════════════════════════════════════════════════════════════════
# PHASES
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_1_empty_profile() -> void:
	print("[TEST] Phase 1 - empty profile shows starter state")
	var profile := _make_profile()
	var hub := _make_hub(profile)
	hub.refresh()
	var s: Dictionary = hub.get_displayed_summary()
	_assert(s["level"] == 1, "level == 1")
	_assert(s["xp_total"] == 0, "xp_total == 0")
	_assert(s["n_unlocked_oghams"] == 3, "3 starter oghams visible")
	_assert(s["souffle_max"] == 5, "souffle_max == 5")
	hub.queue_free()
	profile.queue_free()


func _phase_2_after_xp_grant() -> void:
	print("[TEST] Phase 2 - XP grant reflected on refresh()")
	var profile := _make_profile()
	var hub := _make_hub(profile)
	profile.grant_xp(2600, "test")
	hub.refresh()
	var s: Dictionary = hub.get_displayed_summary()
	_assert(s["level"] == 5, "level == 5 after +2600 XP")
	_assert(s["xp_total"] == 2600, "xp_total == 2600")
	_assert(s["n_unlocked_oghams"] == 6, "+3 T2 oghams at L5 -> 6 total")
	_assert(s["souffle_max"] == 6, "souffle_max +1 at L5")
	hub.queue_free()
	profile.queue_free()


func _phase_3_after_trait_add() -> void:
	print("[TEST] Phase 3 - trait_add then refresh shows trait")
	var profile := _make_profile()
	var hub := _make_hub(profile)
	profile.add_trait({
		"trait_id": "trait_silence_attentif",
		"name": "Silence attentif",
		"prose": "Les vieux druides te reconnaissent comme une voix qui sait écouter.",
		"effect_spec": "BIAS_KNN:emotion:sagesse:+0.05",
		"rarity": "rare_emergence",
		"source": "adaptive_emergence",
	})
	hub.refresh()
	var s: Dictionary = hub.get_displayed_summary()
	_assert(s["n_traits"] == 1, "1 trait total")
	_assert(s["active_traits"].size() == 1, "1 active trait")
	if s["active_traits"].size() >= 1:
		_assert(s["active_traits"][0]["name"] == "Silence attentif", "trait name in snapshot")
	hub.queue_free()
	profile.queue_free()


func _phase_4_external_mutation_requires_refresh() -> void:
	print("[TEST] Phase 4 - external mutation needs explicit refresh()")
	var profile := _make_profile()
	var hub := _make_hub(profile)
	hub.refresh()
	var s_before: Dictionary = hub.get_displayed_summary()
	_assert(s_before["xp_total"] == 0, "before mutation: xp=0")
	profile.grant_xp(500, "external")
	var s_stale: Dictionary = hub.get_displayed_summary()
	_assert(s_stale["xp_total"] == 0, "snapshot still 0 before refresh")
	hub.refresh()
	var s_after: Dictionary = hub.get_displayed_summary()
	_assert(s_after["xp_total"] == 500, "after refresh: xp=500")
	hub.queue_free()
	profile.queue_free()


func _phase_5_rebuild_idempotent() -> void:
	print("[TEST] Phase 5 - _build_layout idempotent")
	var profile := _make_profile()
	var hub := _make_hub(profile)
	hub._build_layout()  # call again
	var root := hub.get_node_or_null("Root")
	_assert(root != null, "Root child exists")
	var n_roots := 0
	for child in hub.get_children():
		if child.name == "Root":
			n_roots += 1
	_assert(n_roots == 1, "exactly 1 Root node (got %d)" % n_roots)
	hub.queue_free()
	profile.queue_free()
