## =============================================================================
## Unit Tests — StoreTalents
## =============================================================================
## Tests: apply_talent_effects_for_run, get_talent_modifier, consume_talent_modifier,
## is_talent_active, can_unlock_talent, get_unlocked_talents, get_affordable_talents,
## edge cases.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


func _make_state(unlocked: Array = [], anam: int = 0, run_overrides: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"meta": {
			"anam": anam,
			"talent_tree": {
				"unlocked": unlocked.duplicate(),
			},
		},
		"run": {
			"life_essence": 50,
			"talent_modifiers": {},
		},
	}
	for key in run_overrides:
		state["run"][key] = run_overrides[key]
	return state


# =============================================================================
# IS_TALENT_ACTIVE
# =============================================================================

func test_is_talent_active_true() -> bool:
	var state: Dictionary = _make_state(["druides_1"])
	var result: bool = StoreTalents.is_talent_active(state, "druides_1")
	if not result:
		push_error("is_talent_active should return true for unlocked talent")
		return false
	return true


func test_is_talent_active_false() -> bool:
	var state: Dictionary = _make_state([])
	var result: bool = StoreTalents.is_talent_active(state, "druides_1")
	if result:
		push_error("is_talent_active should return false for locked talent")
		return false
	return true


# =============================================================================
# CAN_UNLOCK_TALENT
# =============================================================================

func test_can_unlock_tier1_with_enough_anam() -> bool:
	# druides_1 costs 20, no prerequisites
	var state: Dictionary = _make_state([], 20)
	var result: bool = StoreTalents.can_unlock_talent(state, "druides_1")
	if not result:
		push_error("can_unlock_talent should return true for tier-1 with enough anam")
		return false
	return true


func test_can_unlock_insufficient_anam() -> bool:
	# druides_1 costs 20, we only have 10
	var state: Dictionary = _make_state([], 10)
	var result: bool = StoreTalents.can_unlock_talent(state, "druides_1")
	if result:
		push_error("can_unlock_talent should return false with insufficient anam")
		return false
	return true


func test_can_unlock_already_active() -> bool:
	var state: Dictionary = _make_state(["druides_1"], 100)
	var result: bool = StoreTalents.can_unlock_talent(state, "druides_1")
	if result:
		push_error("can_unlock_talent should return false for already unlocked talent")
		return false
	return true


func test_can_unlock_missing_prerequisite() -> bool:
	# druides_2 requires druides_1, costs 25
	var state: Dictionary = _make_state([], 100)
	var result: bool = StoreTalents.can_unlock_talent(state, "druides_2")
	if result:
		push_error("can_unlock_talent should return false when prerequisite missing")
		return false
	return true


func test_can_unlock_with_prerequisite_met() -> bool:
	# druides_2 requires druides_1, costs 25
	var state: Dictionary = _make_state(["druides_1"], 25)
	var result: bool = StoreTalents.can_unlock_talent(state, "druides_2")
	if not result:
		push_error("can_unlock_talent should return true when prerequisite met and enough anam")
		return false
	return true


func test_can_unlock_nonexistent_node() -> bool:
	var state: Dictionary = _make_state([], 1000)
	var result: bool = StoreTalents.can_unlock_talent(state, "nonexistent_node_xyz")
	if result:
		push_error("can_unlock_talent should return false for nonexistent node")
		return false
	return true


# =============================================================================
# APPLY TALENT EFFECTS FOR RUN
# =============================================================================

func test_apply_effects_empty_unlocked() -> bool:
	var state: Dictionary = _make_state([])
	StoreTalents.apply_talent_effects_for_run(state)
	# Should not crash, and run should not have talent_modifiers set by the func
	# (it returns early before setting modifiers)
	return true


func test_apply_effects_modify_start_life() -> bool:
	# druides_1 effect: modify_start, target: life, value: 10
	var state: Dictionary = _make_state(["druides_1"], 0, {"life_essence": 50})
	StoreTalents.apply_talent_effects_for_run(state)
	var life: int = int(state["run"].get("life_essence", 0))
	if life != 60:
		push_error("life_essence should be 60 after druides_1 (+10), got %d" % life)
		return false
	return true


func test_apply_effects_life_clamped_at_max() -> bool:
	# druides_1 adds +10 life, starting at 95 should clamp to 100
	var state: Dictionary = _make_state(["druides_1"], 0, {"life_essence": 95})
	StoreTalents.apply_talent_effects_for_run(state)
	var life: int = int(state["run"].get("life_essence", 0))
	if life != 100:
		push_error("life_essence should be clamped at 100, got %d" % life)
		return false
	return true


func test_apply_effects_cooldown_reduction() -> bool:
	# druides_2 effect: cooldown_reduction, category: nature, value: 1
	var state: Dictionary = _make_state(["druides_2"])
	StoreTalents.apply_talent_effects_for_run(state)
	var mods: Dictionary = state["run"].get("talent_modifiers", {})
	var cd_val: int = int(mods.get("cooldown_reduction_nature", 0))
	if cd_val != 1:
		push_error("cooldown_reduction_nature should be 1, got %d" % cd_val)
		return false
	return true


func test_apply_effects_special_rule() -> bool:
	# anciens_1 effect: special_rule, id: reveal_one_effect
	var state: Dictionary = _make_state(["anciens_1"])
	StoreTalents.apply_talent_effects_for_run(state)
	var mods: Dictionary = state["run"].get("talent_modifiers", {})
	if not mods.get("reveal_one_effect", false):
		push_error("reveal_one_effect should be true after applying anciens_1")
		return false
	return true


# =============================================================================
# GET_TALENT_MODIFIER
# =============================================================================

func test_get_talent_modifier_existing() -> bool:
	var state: Dictionary = _make_state()
	state["run"]["talent_modifiers"] = {"drain_reduction": 2}
	var val: Variant = StoreTalents.get_talent_modifier(state, "drain_reduction", 0)
	if int(val) != 2:
		push_error("get_talent_modifier should return 2, got %s" % str(val))
		return false
	return true


func test_get_talent_modifier_missing_returns_default() -> bool:
	var state: Dictionary = _make_state()
	var val: Variant = StoreTalents.get_talent_modifier(state, "nonexistent_key", 42)
	if int(val) != 42:
		push_error("get_talent_modifier should return default 42, got %s" % str(val))
		return false
	return true


# =============================================================================
# CONSUME_TALENT_MODIFIER
# =============================================================================

func test_consume_modifier_true_when_active() -> bool:
	var state: Dictionary = _make_state()
	state["run"]["talent_modifiers"] = {"resist_damage_once": true}
	var consumed: bool = StoreTalents.consume_talent_modifier(state, "resist_damage_once")
	if not consumed:
		push_error("consume_talent_modifier should return true when modifier is active")
		return false
	# After consuming, it should be false
	var after: Variant = state["run"]["talent_modifiers"].get("resist_damage_once", true)
	if after:
		push_error("modifier should be false after consuming")
		return false
	return true


func test_consume_modifier_false_when_inactive() -> bool:
	var state: Dictionary = _make_state()
	state["run"]["talent_modifiers"] = {"resist_damage_once": false}
	var consumed: bool = StoreTalents.consume_talent_modifier(state, "resist_damage_once")
	if consumed:
		push_error("consume_talent_modifier should return false when modifier is inactive")
		return false
	return true


func test_consume_modifier_false_when_missing() -> bool:
	var state: Dictionary = _make_state()
	var consumed: bool = StoreTalents.consume_talent_modifier(state, "nonexistent_mod")
	if consumed:
		push_error("consume_talent_modifier should return false for missing key")
		return false
	return true


# =============================================================================
# GET_UNLOCKED_TALENTS
# =============================================================================

func test_get_unlocked_talents_returns_copy() -> bool:
	var state: Dictionary = _make_state(["druides_1", "anciens_1"])
	var unlocked: Array = StoreTalents.get_unlocked_talents(state)
	if unlocked.size() != 2:
		push_error("get_unlocked_talents should return 2 items, got %d" % unlocked.size())
		return false
	# Verify it is a copy (modifying returned array should not affect state)
	unlocked.append("fake_node")
	var original: Array = state["meta"]["talent_tree"]["unlocked"]
	if original.size() != 2:
		push_error("get_unlocked_talents should return a duplicate, not a reference")
		return false
	return true


# =============================================================================
# GET_AFFORDABLE_TALENTS
# =============================================================================

func test_get_affordable_talents_includes_unlockable() -> bool:
	# With 20 anam and no unlocked, all tier-1 nodes (cost 20) should be affordable
	var state: Dictionary = _make_state([], 20)
	var affordable: Array = StoreTalents.get_affordable_talents(state)
	if not "druides_1" in affordable:
		push_error("druides_1 should be affordable with 20 anam")
		return false
	return true


func test_get_affordable_talents_excludes_locked_prereqs() -> bool:
	# druides_2 requires druides_1, should not be affordable even with lots of anam
	var state: Dictionary = _make_state([], 1000)
	var affordable: Array = StoreTalents.get_affordable_talents(state)
	if "druides_2" in affordable:
		push_error("druides_2 should not be affordable without druides_1 unlocked")
		return false
	return true
