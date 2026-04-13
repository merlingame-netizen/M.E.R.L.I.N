## =============================================================================
## Comprehensive Tests -- MerlinEffectEngine v2.4
## =============================================================================
## ~70 tests covering all public and internal methods:
## validate_effect, apply_effects, _parse_effect, _apply_life_delta,
## _apply_hidden_counter, _apply_global_flag, _apply_tag, _queue_card,
## _trigger_arc, _add_promise, _create_promise, _fulfill_promise,
## _break_promise, _apply_progress_mission, _apply_narrative_debt,
## _score_to_tier, _apply_faction_reputation, _apply_add_anam,
## _apply_unlock_ogham, _apply_biome_currency, _apply_offering,
## get_multiplier, get_multiplier_label, cap_effect, scale_and_cap,
## apply_ogham_protection, _is_negative_effect, detect_field_from_verb,
## pick_minigame_for_field.
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error on fail.
## =============================================================================

extends RefCounted


func _make_state() -> Dictionary:
	return {
		"run": {
			"life_essence": 50,
			"cards_played": 5,
			"hidden": {"karma": 0, "tension": 0},
			"active_tags": [],
			"card_queue": [],
			"promises": [],
			"active_promises": [],
			"mission": {"progress": 0, "total": 10},
			"unlocked_oghams": [],
			"biome_currency": 20,
			"anam": 10,
			"day": 3,
		},
		"meta": {
			"faction_rep": {},
			"anam": 100,
		},
		"flags": {},
		"effect_log": [],
	}


# =============================================================================
# 1. validate_effect
# =============================================================================

func test_validate_effect_valid_heal() -> bool:
	var engine := MerlinEffectEngine.new()
	if not engine.validate_effect("HEAL_LIFE:5"):
		push_error("validate_effect: HEAL_LIFE:5 should be valid")
		return false
	return true


func test_validate_effect_valid_reputation() -> bool:
	var engine := MerlinEffectEngine.new()
	if not engine.validate_effect("ADD_REPUTATION:druides:10"):
		push_error("validate_effect: ADD_REPUTATION:druides:10 should be valid")
		return false
	return true


func test_validate_effect_valid_narrative_debt() -> bool:
	var engine := MerlinEffectEngine.new()
	if not engine.validate_effect("ADD_NARRATIVE_DEBT:trahison:desc"):
		push_error("validate_effect: ADD_NARRATIVE_DEBT should be valid with 2 args")
		return false
	return true


func test_validate_effect_invalid_unknown_code() -> bool:
	var engine := MerlinEffectEngine.new()
	if engine.validate_effect("EXPLODE:99"):
		push_error("validate_effect: unknown code should be invalid")
		return false
	return true


func test_validate_effect_invalid_missing_args() -> bool:
	var engine := MerlinEffectEngine.new()
	if engine.validate_effect("HEAL_LIFE"):
		push_error("validate_effect: missing args should be invalid")
		return false
	return true


func test_validate_effect_invalid_too_many_args() -> bool:
	var engine := MerlinEffectEngine.new()
	if engine.validate_effect("HEAL_LIFE:5:extra"):
		push_error("validate_effect: too many args should be invalid")
		return false
	return true


# =============================================================================
# 2. apply_effects
# =============================================================================

func test_apply_effects_multiple_applied() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["HEAL_LIFE:5", "DAMAGE_LIFE:3"])
	if result["applied"].size() != 2:
		push_error("apply_effects: expected 2 applied, got %d" % result["applied"].size())
		return false
	return true


func test_apply_effects_mixed_applied_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["HEAL_LIFE:5", "BOGUS:1", "DAMAGE_LIFE:3"])
	if result["applied"].size() != 2:
		push_error("apply_effects mixed: expected 2 applied, got %d" % result["applied"].size())
		return false
	if result["rejected"].size() != 1:
		push_error("apply_effects mixed: expected 1 rejected, got %d" % result["rejected"].size())
		return false
	if result["errors"].size() != 1:
		push_error("apply_effects mixed: expected 1 error, got %d" % result["errors"].size())
		return false
	return true


func test_apply_effects_empty_array() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, [])
	if result["applied"].size() != 0 or result["rejected"].size() != 0:
		push_error("apply_effects empty: should have 0 applied and 0 rejected")
		return false
	return true


func test_apply_effects_non_string_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, [42, null])
	if result["rejected"].size() != 2:
		push_error("apply_effects non-string: expected 2 rejected, got %d" % result["rejected"].size())
		return false
	return true


func test_apply_effects_records_log() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["HEAL_LIFE:5"], "TEST_SRC")
	var log: Array = state.get("effect_log", [])
	if log.size() == 0:
		push_error("apply_effects log: should have entries")
		return false
	var entry: Dictionary = log[0]
	if str(entry.get("source", "")) != "TEST_SRC":
		push_error("apply_effects log: source mismatch")
		return false
	if str(entry.get("status", "")) != "applied":
		push_error("apply_effects log: status should be applied")
		return false
	return true


# =============================================================================
# 3. _parse_effect (tested indirectly via validate + apply)
# =============================================================================

func test_parse_all_valid_codes_correct_arg_count() -> bool:
	var engine := MerlinEffectEngine.new()
	var test_cases: Dictionary = {
		"PROGRESS_MISSION:1": true,
		"ADD_KARMA:10": true,
		"ADD_TENSION:15": true,
		"ADD_NARRATIVE_DEBT:type:desc": true,
		"DAMAGE_LIFE:2": true,
		"HEAL_LIFE:1": true,
		"SET_FLAG:key:val": true,
		"ADD_TAG:tag": true,
		"REMOVE_TAG:tag": true,
		"QUEUE_CARD:card_id": true,
		"TRIGGER_ARC:arc_id": true,
		"ADD_PROMISE:id:5": true,
		"CREATE_PROMISE:id:5:desc": true,
		"FULFILL_PROMISE:id": true,
		"BREAK_PROMISE:id": true,
		"ADD_REPUTATION:druides:10": true,
		"ADD_ANAM:5": true,
		"ADD_BIOME_CURRENCY:10": true,
		"UNLOCK_OGHAM:beith": true,
		"OFFERING:10:HEAL_LIFE:5": true,
		"PLAY_SFX:sound": true,
		"SHOW_DIALOG:dialog": true,
		"TRIGGER_EVENT:event": true,
	}
	for code in test_cases:
		var valid: bool = engine.validate_effect(code)
		if valid != test_cases[code]:
			push_error("parse_all_codes: %s expected %s, got %s" % [code, str(test_cases[code]), str(valid)])
			return false
	return true


func test_parse_wrong_arg_count_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var bad_cases: Array = [
		"HEAL_LIFE",           # needs 1, has 0
		"HEAL_LIFE:1:2",       # needs 1, has 2
		"ADD_REPUTATION:x",    # needs 2, has 1
		"SET_FLAG:x",          # needs 2, has 1
		"CREATE_PROMISE:a:b",  # needs 3, has 2
	]
	for code in bad_cases:
		if engine.validate_effect(code):
			push_error("parse_wrong_args: %s should be invalid" % code)
			return false
	return true


# =============================================================================
# 4. _apply_life_delta (DAMAGE_LIFE, HEAL_LIFE)
# =============================================================================

func test_damage_life_basic() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["DAMAGE_LIFE:8"])
	var life: int = int(state["run"]["life_essence"])
	if life != 42:
		push_error("DAMAGE_LIFE basic: expected 42, got %d" % life)
		return false
	return true


func test_damage_life_clamp_at_zero() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["run"]["life_essence"] = 3
	engine.apply_effects(state, ["DAMAGE_LIFE:50"])
	var life: int = int(state["run"]["life_essence"])
	if life != 0:
		push_error("DAMAGE_LIFE clamp zero: expected 0, got %d" % life)
		return false
	return true


func test_heal_life_basic() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["run"]["life_essence"] = 40
	engine.apply_effects(state, ["HEAL_LIFE:10"])
	var life: int = int(state["run"]["life_essence"])
	if life != 50:
		push_error("HEAL_LIFE basic: expected 50, got %d" % life)
		return false
	return true


func test_heal_life_clamp_at_max() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["run"]["life_essence"] = 95
	engine.apply_effects(state, ["HEAL_LIFE:20"])
	var life: int = int(state["run"]["life_essence"])
	if life != 100:
		push_error("HEAL_LIFE clamp max: expected 100, got %d" % life)
		return false
	return true


func test_damage_life_at_zero_stays_zero() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["run"]["life_essence"] = 0
	engine.apply_effects(state, ["DAMAGE_LIFE:5"])
	var life: int = int(state["run"]["life_essence"])
	if life != 0:
		push_error("DAMAGE_LIFE at zero: expected 0, got %d" % life)
		return false
	return true


func test_heal_life_at_max_stays_max() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["run"]["life_essence"] = 100
	engine.apply_effects(state, ["HEAL_LIFE:10"])
	var life: int = int(state["run"]["life_essence"])
	if life != 100:
		push_error("HEAL_LIFE at max: expected 100, got %d" % life)
		return false
	return true


# =============================================================================
# 5. _apply_hidden_counter (karma, tension)
# =============================================================================

func test_karma_positive() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_KARMA:25"])
	var karma: int = int(state["run"]["hidden"]["karma"])
	if karma != 25:
		push_error("ADD_KARMA positive: expected 25, got %d" % karma)
		return false
	return true


func test_karma_clamp_max_100() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_KARMA:200"])
	var karma: int = int(state["run"]["hidden"]["karma"])
	if karma != 100:
		push_error("ADD_KARMA clamp max: expected 100, got %d" % karma)
		return false
	return true


func test_karma_clamp_min_neg100() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_KARMA:-200"])
	var karma: int = int(state["run"]["hidden"]["karma"])
	if karma != -100:
		push_error("ADD_KARMA clamp min: expected -100, got %d" % karma)
		return false
	return true


func test_tension_positive() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_TENSION:30"])
	var tension: int = int(state["run"]["hidden"]["tension"])
	if tension != 30:
		push_error("ADD_TENSION positive: expected 30, got %d" % tension)
		return false
	return true


func test_tension_clamp_max_100() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_TENSION:150"])
	var tension: int = int(state["run"]["hidden"]["tension"])
	if tension != 100:
		push_error("ADD_TENSION clamp max: expected 100, got %d" % tension)
		return false
	return true


func test_tension_clamp_min_zero() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_TENSION:-50"])
	var tension: int = int(state["run"]["hidden"]["tension"])
	if tension != 0:
		push_error("ADD_TENSION clamp min: expected 0, got %d" % tension)
		return false
	return true


func test_hidden_counter_other_key_no_clamp() -> bool:
	# Directly call the internal method via apply_effects using a known path
	# We use karma-like delta but test a hypothetical "other" key scenario
	# This is tested indirectly: karma and tension have specific clamps,
	# any other key would get unclamped (current + delta)
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	# Set karma to 50, add 60 -> clamped at 100
	state["run"]["hidden"]["karma"] = 50
	engine.apply_effects(state, ["ADD_KARMA:60"])
	var karma: int = int(state["run"]["hidden"]["karma"])
	if karma != 100:
		push_error("karma 50+60 clamp: expected 100, got %d" % karma)
		return false
	return true


# =============================================================================
# 6. _apply_global_flag (SET_FLAG)
# =============================================================================

func test_set_flag_true() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["SET_FLAG:met_druide:true"])
	if not state["flags"].get("met_druide", false):
		push_error("SET_FLAG true: met_druide should be true")
		return false
	return true


func test_set_flag_false() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["SET_FLAG:some_flag:false"])
	if state["flags"].get("some_flag", true):
		push_error("SET_FLAG false: some_flag should be false")
		return false
	return true


func test_set_flag_one() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["SET_FLAG:flag_a:1"])
	if not state["flags"].get("flag_a", false):
		push_error("SET_FLAG '1': flag_a should be true")
		return false
	return true


func test_set_flag_flag_on() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["SET_FLAG:flag_b:flag_on"])
	if not state["flags"].get("flag_b", false):
		push_error("SET_FLAG 'flag_on': flag_b should be true")
		return false
	return true


func test_set_flag_arbitrary_value_is_false() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["SET_FLAG:flag_c:maybe"])
	if state["flags"].get("flag_c", true):
		push_error("SET_FLAG 'maybe': should be false (not a truthy value)")
		return false
	return true


# =============================================================================
# 7. _apply_tag (ADD_TAG, REMOVE_TAG)
# =============================================================================

func test_add_tag_basic() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_TAG:war_brewing"])
	if not state["run"]["active_tags"].has("war_brewing"):
		push_error("ADD_TAG: war_brewing should be present")
		return false
	return true


func test_add_tag_no_duplicate() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_TAG:peace"])
	engine.apply_effects(state, ["ADD_TAG:peace"])
	var count: int = 0
	for t in state["run"]["active_tags"]:
		if str(t) == "peace":
			count += 1
	if count != 1:
		push_error("ADD_TAG duplicate: should appear once, got %d" % count)
		return false
	return true


func test_remove_tag_basic() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_TAG:peace"])
	engine.apply_effects(state, ["REMOVE_TAG:peace"])
	if state["run"]["active_tags"].has("peace"):
		push_error("REMOVE_TAG: peace should be removed")
		return false
	return true


func test_remove_tag_nonexistent_ok() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["REMOVE_TAG:ghost_tag"])
	if result["applied"].size() != 1:
		push_error("REMOVE_TAG nonexistent: should still be applied (no-op)")
		return false
	return true


# =============================================================================
# 8. _queue_card
# =============================================================================

func test_queue_card_basic() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["QUEUE_CARD:card_finale"])
	var queue: Array = state["run"]["card_queue"]
	if queue.size() != 1 or str(queue[0]) != "card_finale":
		push_error("QUEUE_CARD: expected [card_finale]")
		return false
	return true


func test_queue_card_multiple() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["QUEUE_CARD:c1"])
	engine.apply_effects(state, ["QUEUE_CARD:c2"])
	var queue: Array = state["run"]["card_queue"]
	if queue.size() != 2:
		push_error("QUEUE_CARD multiple: expected 2, got %d" % queue.size())
		return false
	return true


# =============================================================================
# 9. _trigger_arc
# =============================================================================

func test_trigger_arc_basic() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["TRIGGER_ARC:druide_arc"])
	if str(state["run"].get("current_arc", "")) != "druide_arc":
		push_error("TRIGGER_ARC: expected druide_arc")
		return false
	return true


func test_trigger_arc_overwrites() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["TRIGGER_ARC:arc_a"])
	engine.apply_effects(state, ["TRIGGER_ARC:arc_b"])
	if str(state["run"].get("current_arc", "")) != "arc_b":
		push_error("TRIGGER_ARC overwrite: expected arc_b")
		return false
	return true


# =============================================================================
# 10. _add_promise (cap at 2 active)
# =============================================================================

func test_add_promise_basic() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["ADD_PROMISE:oath_01:10"])
	if result["applied"].size() != 1:
		push_error("ADD_PROMISE basic: expected 1 applied")
		return false
	var promises: Array = state["run"]["active_promises"]
	if promises.size() != 1:
		push_error("ADD_PROMISE: expected 1 promise")
		return false
	var p: Dictionary = promises[0]
	if str(p.get("id", "")) != "oath_01":
		push_error("ADD_PROMISE: wrong id")
		return false
	if str(p.get("status", "")) != "active":
		push_error("ADD_PROMISE: status should be active")
		return false
	if int(p.get("made_at_card", -1)) != 5:
		push_error("ADD_PROMISE: made_at_card should be 5")
		return false
	return true


func test_add_promise_cap_at_two() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_PROMISE:p1:10"])
	engine.apply_effects(state, ["ADD_PROMISE:p2:10"])
	var result: Dictionary = engine.apply_effects(state, ["ADD_PROMISE:p3:10"])
	if result["rejected"].size() != 1:
		push_error("ADD_PROMISE cap: 3rd should be rejected")
		return false
	if state["run"]["active_promises"].size() != 2:
		push_error("ADD_PROMISE cap: should have exactly 2")
		return false
	return true


# =============================================================================
# 11. _create_promise
# =============================================================================

func test_create_promise_basic() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_001:5:Find the relic"])
	var promises: Array = state["run"]["active_promises"]
	if promises.size() != 1:
		push_error("CREATE_PROMISE: expected 1 promise")
		return false
	var p: Dictionary = promises[0]
	if str(p.get("id", "")) != "oath_001":
		push_error("CREATE_PROMISE: wrong id")
		return false
	if int(p.get("deadline_cards", 0)) != 5:  # deadline_cards arg = 5
		push_error("CREATE_PROMISE: deadline_cards should be 5, got %d" % int(p.get("deadline_cards", 0)))
		return false
	if str(p.get("status", "")) != "active":
		push_error("CREATE_PROMISE: status should be active")
		return false
	return true


# =============================================================================
# 12. _fulfill_promise
# =============================================================================

func test_fulfill_promise_success() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_001:5:desc"])
	engine.apply_effects(state, ["FULFILL_PROMISE:oath_001"])
	var p: Dictionary = state["run"]["active_promises"][0]
	if str(p.get("status", "")) != "fulfilled":
		push_error("FULFILL_PROMISE: status should be fulfilled")
		return false
	return true


func test_fulfill_promise_not_found_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["FULFILL_PROMISE:ghost"])
	if result["rejected"].size() != 1:
		push_error("FULFILL_PROMISE not found: should be rejected")
		return false
	return true


# =============================================================================
# 13. _break_promise
# =============================================================================

func test_break_promise_success() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_002:3:desc"])
	engine.apply_effects(state, ["BREAK_PROMISE:oath_002"])
	var p: Dictionary = state["run"]["active_promises"][0]
	if str(p.get("status", "")) != "broken":
		push_error("BREAK_PROMISE: status should be broken")
		return false
	return true


func test_break_promise_not_found_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["BREAK_PROMISE:ghost"])
	if result["rejected"].size() != 1:
		push_error("BREAK_PROMISE not found: should be rejected")
		return false
	return true


# =============================================================================
# 14. _apply_progress_mission
# =============================================================================

func test_progress_mission_basic() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["PROGRESS_MISSION:3"])
	var progress: int = int(state["run"]["mission"]["progress"])
	if progress != 3:
		push_error("PROGRESS_MISSION: expected 3, got %d" % progress)
		return false
	return true


func test_progress_mission_capped_at_total() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["PROGRESS_MISSION:99"])
	var progress: int = int(state["run"]["mission"]["progress"])
	if progress != 10:
		push_error("PROGRESS_MISSION cap: expected 10, got %d" % progress)
		return false
	return true


func test_progress_mission_incremental() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["PROGRESS_MISSION:4"])
	engine.apply_effects(state, ["PROGRESS_MISSION:4"])
	var progress: int = int(state["run"]["mission"]["progress"])
	if progress != 8:
		push_error("PROGRESS_MISSION incremental: expected 8, got %d" % progress)
		return false
	return true


# =============================================================================
# 15. _apply_narrative_debt
# =============================================================================

func test_narrative_debt_basic() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_NARRATIVE_DEBT:trahison:La trahison reviendra"])
	var debts: Array = state["run"]["hidden"]["narrative_debt"]
	if debts.size() != 1:
		push_error("NARRATIVE_DEBT: expected 1, got %d" % debts.size())
		return false
	var d: Dictionary = debts[0]
	if str(d.get("type", "")) != "trahison":
		push_error("NARRATIVE_DEBT: wrong type")
		return false
	if str(d.get("description", "")) != "La trahison reviendra":
		push_error("NARRATIVE_DEBT: wrong description")
		return false
	if int(d.get("created_card", -1)) != 5:
		push_error("NARRATIVE_DEBT: created_card should be 5")
		return false
	if d.get("resolved", true) != false:
		push_error("NARRATIVE_DEBT: resolved should be false")
		return false
	return true


func test_narrative_debt_multiple() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_NARRATIVE_DEBT:trahison:desc1"])
	engine.apply_effects(state, ["ADD_NARRATIVE_DEBT:mensonge:desc2"])
	var debts: Array = state["run"]["hidden"]["narrative_debt"]
	if debts.size() != 2:
		push_error("NARRATIVE_DEBT multiple: expected 2, got %d" % debts.size())
		return false
	return true


# =============================================================================
# 16. _score_to_tier
# =============================================================================

func test_score_to_tier_hostile() -> bool:
	var engine := MerlinEffectEngine.new()
	var tier: String = engine._score_to_tier(0)
	if tier != "hostile":
		push_error("score_to_tier 0: expected hostile, got %s" % tier)
		return false
	return true


func test_score_to_tier_hostile_boundary() -> bool:
	var engine := MerlinEffectEngine.new()
	var tier: String = engine._score_to_tier(4)
	if tier != "hostile":
		push_error("score_to_tier 4: expected hostile, got %s" % tier)
		return false
	return true


func test_score_to_tier_mefiant() -> bool:
	var engine := MerlinEffectEngine.new()
	var tier: String = engine._score_to_tier(5)
	if tier != "mefiant":
		push_error("score_to_tier 5: expected mefiant, got %s" % tier)
		return false
	return true


func test_score_to_tier_mefiant_upper() -> bool:
	var engine := MerlinEffectEngine.new()
	var tier: String = engine._score_to_tier(19)
	if tier != "mefiant":
		push_error("score_to_tier 19: expected mefiant, got %s" % tier)
		return false
	return true


func test_score_to_tier_neutre() -> bool:
	var engine := MerlinEffectEngine.new()
	var tier: String = engine._score_to_tier(20)
	if tier != "neutre":
		push_error("score_to_tier 20: expected neutre, got %s" % tier)
		return false
	return true


func test_score_to_tier_sympathisant() -> bool:
	var engine := MerlinEffectEngine.new()
	var tier: String = engine._score_to_tier(50)
	if tier != "sympathisant":
		push_error("score_to_tier 50: expected sympathisant, got %s" % tier)
		return false
	return true


func test_score_to_tier_honore() -> bool:
	var engine := MerlinEffectEngine.new()
	var tier: String = engine._score_to_tier(80)
	if tier != "honore":
		push_error("score_to_tier 80: expected honore, got %s" % tier)
		return false
	return true


func test_score_to_tier_honore_max() -> bool:
	var engine := MerlinEffectEngine.new()
	var tier: String = engine._score_to_tier(100)
	if tier != "honore":
		push_error("score_to_tier 100: expected honore, got %s" % tier)
		return false
	return true


# =============================================================================
# 17. _apply_faction_reputation
# =============================================================================

func test_faction_reputation_basic() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["meta"]["faction_rep"]["druides"] = 10
	engine.apply_effects(state, ["ADD_REPUTATION:druides:15"])
	var rep: int = int(state["meta"]["faction_rep"]["druides"])
	if rep != 25:
		push_error("ADD_REPUTATION basic: expected 25, got %d" % rep)
		return false
	return true


func test_faction_reputation_per_card_cap_positive() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["meta"]["faction_rep"]["anciens"] = 10
	engine.apply_effects(state, ["ADD_REPUTATION:anciens:50"])
	var rep: int = int(state["meta"]["faction_rep"]["anciens"])
	if rep != 30:  # 10 + 20 (capped)
		push_error("ADD_REPUTATION cap+: expected 30, got %d" % rep)
		return false
	return true


func test_faction_reputation_per_card_cap_negative() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["meta"]["faction_rep"]["korrigans"] = 50
	engine.apply_effects(state, ["ADD_REPUTATION:korrigans:-50"])
	var rep: int = int(state["meta"]["faction_rep"]["korrigans"])
	if rep != 30:  # 50 + (-20) capped
		push_error("ADD_REPUTATION cap-: expected 30, got %d" % rep)
		return false
	return true


func test_faction_reputation_clamp_at_100() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["meta"]["faction_rep"]["niamh"] = 90
	engine.apply_effects(state, ["ADD_REPUTATION:niamh:20"])
	var rep: int = int(state["meta"]["faction_rep"]["niamh"])
	if rep != 100:
		push_error("ADD_REPUTATION clamp 100: expected 100, got %d" % rep)
		return false
	return true


func test_faction_reputation_clamp_at_zero() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["meta"]["faction_rep"]["ankou"] = 5
	engine.apply_effects(state, ["ADD_REPUTATION:ankou:-20"])
	var rep: int = int(state["meta"]["faction_rep"]["ankou"])
	if rep != 0:
		push_error("ADD_REPUTATION clamp 0: expected 0, got %d" % rep)
		return false
	return true


func test_faction_reputation_invalid_faction_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["ADD_REPUTATION:humains:10"])
	if result["rejected"].size() != 1:
		push_error("ADD_REPUTATION invalid faction: should be rejected")
		return false
	return true


func test_faction_reputation_builds_context() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["meta"]["faction_rep"]["druides"] = 10
	engine.apply_effects(state, ["ADD_REPUTATION:druides:20"])
	var ctx: Dictionary = state["run"].get("faction_context", {})
	if ctx.is_empty():
		push_error("faction_context should be built after ADD_REPUTATION")
		return false
	return true


# =============================================================================
# 18. _apply_add_anam
# =============================================================================

func test_add_anam_positive() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_ANAM:15"])
	if int(state["run"]["anam"]) != 25:  # 10 + 15
		push_error("ADD_ANAM positive run: expected 25, got %d" % int(state["run"]["anam"]))
		return false
	if int(state["meta"]["anam"]) != 115:  # 100 + 15
		push_error("ADD_ANAM positive meta: expected 115, got %d" % int(state["meta"]["anam"]))
		return false
	return true


func test_add_anam_zero_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["ADD_ANAM:0"])
	if result["rejected"].size() != 1:
		push_error("ADD_ANAM zero: should be rejected")
		return false
	return true


func test_add_anam_negative_floors_at_zero() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["run"]["anam"] = 5
	state["meta"]["anam"] = 5
	engine.apply_effects(state, ["ADD_ANAM:-100"])
	if int(state["run"]["anam"]) != 0:
		push_error("ADD_ANAM neg run: expected 0, got %d" % int(state["run"]["anam"]))
		return false
	if int(state["meta"]["anam"]) != 0:
		push_error("ADD_ANAM neg meta: expected 0, got %d" % int(state["meta"]["anam"]))
		return false
	return true


# =============================================================================
# 19. _apply_unlock_ogham
# =============================================================================

func test_unlock_ogham_valid() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["UNLOCK_OGHAM:beith"])
	if result["applied"].size() != 1:
		push_error("UNLOCK_OGHAM valid: should be applied")
		return false
	if not state["run"]["unlocked_oghams"].has("beith"):
		push_error("UNLOCK_OGHAM: beith should be in list")
		return false
	return true


func test_unlock_ogham_invalid_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["UNLOCK_OGHAM:fake_ogham_xyz"])
	if result["rejected"].size() != 1:
		push_error("UNLOCK_OGHAM invalid: should be rejected")
		return false
	return true


func test_unlock_ogham_no_duplicate() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["UNLOCK_OGHAM:beith"])
	engine.apply_effects(state, ["UNLOCK_OGHAM:beith"])
	var count: int = 0
	for o in state["run"]["unlocked_oghams"]:
		if str(o) == "beith":
			count += 1
	if count != 1:
		push_error("UNLOCK_OGHAM duplicate: should appear once, got %d" % count)
		return false
	return true


# =============================================================================
# 20. _apply_biome_currency
# =============================================================================

func test_biome_currency_add() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_BIOME_CURRENCY:8"])
	if int(state["run"]["biome_currency"]) != 28:
		push_error("BIOME_CURRENCY add: expected 28, got %d" % int(state["run"]["biome_currency"]))
		return false
	return true


func test_biome_currency_subtract_floor_zero() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_BIOME_CURRENCY:-100"])
	if int(state["run"]["biome_currency"]) != 0:
		push_error("BIOME_CURRENCY floor: expected 0, got %d" % int(state["run"]["biome_currency"]))
		return false
	return true


# =============================================================================
# 21. _apply_offering
# =============================================================================

func test_offering_success() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["OFFERING:10:HEAL_LIFE:5"])
	if result["applied"].size() != 1:
		push_error("OFFERING success: should be applied")
		return false
	if int(state["run"]["biome_currency"]) != 10:  # 20 - 10
		push_error("OFFERING: currency should be 10, got %d" % int(state["run"]["biome_currency"]))
		return false
	if int(state["run"]["life_essence"]) != 55:  # 50 + 5
		push_error("OFFERING: life should be 55, got %d" % int(state["run"]["life_essence"]))
		return false
	return true


func test_offering_insufficient_currency_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["run"]["biome_currency"] = 3
	var result: Dictionary = engine.apply_effects(state, ["OFFERING:10:HEAL_LIFE:5"])
	if result["rejected"].size() != 1:
		push_error("OFFERING insufficient: should be rejected")
		return false
	return true


func test_offering_invalid_reward_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["OFFERING:5:BOGUS_REWARD:99"])
	if result["rejected"].size() != 1:
		push_error("OFFERING invalid reward: should be rejected")
		return false
	return true


# =============================================================================
# 22. get_multiplier (static)
# =============================================================================

func test_get_multiplier_echec_critique() -> bool:
	var f: float = MerlinEffectEngine.get_multiplier(10)
	if not is_equal_approx(f, -1.5):
		push_error("multiplier 10: expected -1.5, got %f" % f)
		return false
	return true


func test_get_multiplier_echec() -> bool:
	var f: float = MerlinEffectEngine.get_multiplier(35)
	if not is_equal_approx(f, -1.0):
		push_error("multiplier 35: expected -1.0, got %f" % f)
		return false
	return true


func test_get_multiplier_reussite_partielle() -> bool:
	var f: float = MerlinEffectEngine.get_multiplier(65)
	if not is_equal_approx(f, 0.5):
		push_error("multiplier 65: expected 0.5, got %f" % f)
		return false
	return true


func test_get_multiplier_reussite() -> bool:
	var f: float = MerlinEffectEngine.get_multiplier(85)
	if not is_equal_approx(f, 1.0):
		push_error("multiplier 85: expected 1.0, got %f" % f)
		return false
	return true


func test_get_multiplier_reussite_critique() -> bool:
	var f: float = MerlinEffectEngine.get_multiplier(95)
	if not is_equal_approx(f, 1.5):
		push_error("multiplier 95: expected 1.5, got %f" % f)
		return false
	return true


func test_get_multiplier_out_of_range() -> bool:
	var f: float = MerlinEffectEngine.get_multiplier(200)
	if not is_equal_approx(f, 1.0):
		push_error("multiplier 200: expected 1.0 (default), got %f" % f)
		return false
	return true


func test_get_multiplier_boundary_20() -> bool:
	var f: float = MerlinEffectEngine.get_multiplier(20)
	if not is_equal_approx(f, -1.5):
		push_error("multiplier 20: expected -1.5 (echec_critique range), got %f" % f)
		return false
	return true


func test_get_multiplier_boundary_21() -> bool:
	var f: float = MerlinEffectEngine.get_multiplier(21)
	if not is_equal_approx(f, -1.0):
		push_error("multiplier 21: expected -1.0 (echec range), got %f" % f)
		return false
	return true


# =============================================================================
# 23. get_multiplier_label (static)
# =============================================================================

func test_get_multiplier_label_values() -> bool:
	var cases: Dictionary = {
		10: "echec_critique",
		35: "echec",
		65: "reussite_partielle",
		85: "reussite",
		95: "reussite_critique",
	}
	for score in cases:
		var label: String = MerlinEffectEngine.get_multiplier_label(score)
		if label != cases[score]:
			push_error("multiplier_label %d: expected %s, got %s" % [score, cases[score], label])
			return false
	return true


func test_get_multiplier_label_out_of_range() -> bool:
	var label: String = MerlinEffectEngine.get_multiplier_label(200)
	if label != "reussite":
		push_error("multiplier_label 200: expected reussite (default), got %s" % label)
		return false
	return true


# =============================================================================
# 24. cap_effect (static)
# =============================================================================

func test_cap_effect_reputation_max() -> bool:
	var c: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", 50)
	if c != 20:
		push_error("cap_effect rep max: expected 20, got %d" % c)
		return false
	return true


func test_cap_effect_reputation_min() -> bool:
	var c: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", -50)
	if c != -20:
		push_error("cap_effect rep min: expected -20, got %d" % c)
		return false
	return true


func test_cap_effect_heal_life() -> bool:
	var c: int = MerlinEffectEngine.cap_effect("HEAL_LIFE", 99)
	if c != 18:
		push_error("cap_effect HEAL_LIFE: expected 18, got %d" % c)
		return false
	return true


func test_cap_effect_damage_life() -> bool:
	var c: int = MerlinEffectEngine.cap_effect("DAMAGE_LIFE", 99)
	if c != 15:
		push_error("cap_effect DAMAGE_LIFE: expected 15, got %d" % c)
		return false
	return true


func test_cap_effect_biome_currency() -> bool:
	var c: int = MerlinEffectEngine.cap_effect("ADD_BIOME_CURRENCY", 99)
	if c != 10:
		push_error("cap_effect BIOME_CURRENCY: expected 10, got %d" % c)
		return false
	return true


func test_cap_effect_unknown_passthrough() -> bool:
	var c: int = MerlinEffectEngine.cap_effect("ADD_ANAM", 999)
	if c != 999:
		push_error("cap_effect unknown: expected 999, got %d" % c)
		return false
	return true


func test_cap_effect_within_range_unchanged() -> bool:
	var c: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", 10)
	if c != 10:
		push_error("cap_effect within range: expected 10, got %d" % c)
		return false
	return true


# =============================================================================
# 25. scale_and_cap (static)
# =============================================================================

func test_scale_and_cap_positive_multiplier() -> bool:
	# raw=10, multiplier=1.5 -> 15, cap DAMAGE_LIFE 15 -> 15
	var r: int = MerlinEffectEngine.scale_and_cap("DAMAGE_LIFE", 10, 1.5)
	if r != 15:
		push_error("scale_and_cap pos: expected 15, got %d" % r)
		return false
	return true


func test_scale_and_cap_negative_multiplier() -> bool:
	# raw=10, multiplier=-1.5 -> abs=15, negated=-15, cap ADD_REPUTATION min -20 -> -15
	var r: int = MerlinEffectEngine.scale_and_cap("ADD_REPUTATION", 10, -1.5)
	if r != -15:
		push_error("scale_and_cap neg: expected -15, got %d" % r)
		return false
	return true


func test_scale_and_cap_exceeds_cap() -> bool:
	# raw=20, multiplier=1.5 -> 30, cap ADD_REPUTATION max 20 -> 20
	var r: int = MerlinEffectEngine.scale_and_cap("ADD_REPUTATION", 20, 1.5)
	if r != 20:
		push_error("scale_and_cap exceeds: expected 20, got %d" % r)
		return false
	return true


# =============================================================================
# 26. apply_ogham_protection (static)
# =============================================================================

func test_ogham_protection_empty_ogham_passthrough() -> bool:
	var effects: Array = [
		{"code": "DAMAGE_LIFE", "amount": 5},
		{"code": "HEAL_LIFE", "amount": 3},
	]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "")
	if filtered.size() != 2:
		push_error("ogham empty: all should pass, got %d" % filtered.size())
		return false
	return true


func test_ogham_protection_luis_blocks_first_negative() -> bool:
	var effects: Array = [
		{"code": "DAMAGE_LIFE", "amount": 5},
		{"code": "DAMAGE_LIFE", "amount": 3},
		{"code": "HEAL_LIFE", "amount": 5},
	]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "luis")
	if filtered.size() != 2:
		push_error("luis: expected 2 remaining, got %d" % filtered.size())
		return false
	return true


func test_ogham_protection_gort_reduces_high_damage() -> bool:
	var effects: Array = [
		{"code": "DAMAGE_LIFE", "amount": 15},
		{"code": "HEAL_LIFE", "amount": 5},
	]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "gort")
	if int(filtered[0].get("amount", 0)) != 5:
		push_error("gort: high damage should be reduced to 5, got %d" % int(filtered[0].get("amount", 0)))
		return false
	return true


func test_ogham_protection_gort_ignores_low_damage() -> bool:
	var effects: Array = [{"code": "DAMAGE_LIFE", "amount": 8}]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "gort")
	if int(filtered[0].get("amount", 0)) != 8:
		push_error("gort low: should be unchanged, got %d" % int(filtered[0].get("amount", 0)))
		return false
	return true


func test_ogham_protection_gort_immutability() -> bool:
	var effects: Array = [{"code": "DAMAGE_LIFE", "amount": 15}]
	MerlinEffectEngine.apply_ogham_protection(effects, "gort")
	if int(effects[0].get("amount", 0)) != 15:
		push_error("gort: original array should not be mutated")
		return false
	return true


func test_ogham_protection_eadhadh_cancels_all_negatives() -> bool:
	var effects: Array = [
		{"code": "DAMAGE_LIFE", "amount": 5},
		{"code": "HEAL_LIFE", "amount": 3},
		{"code": "DAMAGE_LIFE", "amount": 10},
		{"code": "ADD_REPUTATION", "amount": -5},
	]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "eadhadh")
	if filtered.size() != 1:
		push_error("eadhadh: expected 1 (HEAL only), got %d" % filtered.size())
		return false
	if str(filtered[0].get("code", "")) != "HEAL_LIFE":
		push_error("eadhadh: remaining should be HEAL_LIFE")
		return false
	return true


# =============================================================================
# 27. _is_negative_effect (static, tested via eadhadh)
# =============================================================================

func test_is_negative_damage_life() -> bool:
	var effects: Array = [{"code": "DAMAGE_LIFE", "amount": 1}]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "eadhadh")
	if filtered.size() != 0:
		push_error("DAMAGE_LIFE should be negative, eadhadh should remove it")
		return false
	return true


func test_is_negative_reputation_negative() -> bool:
	var effects: Array = [{"code": "ADD_REPUTATION", "amount": -10}]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "eadhadh")
	if filtered.size() != 0:
		push_error("Negative ADD_REPUTATION should be removed by eadhadh")
		return false
	return true


func test_is_not_negative_reputation_positive() -> bool:
	var effects: Array = [{"code": "ADD_REPUTATION", "amount": 10}]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "eadhadh")
	if filtered.size() != 1:
		push_error("Positive ADD_REPUTATION should NOT be removed by eadhadh")
		return false
	return true


func test_is_not_negative_heal() -> bool:
	var effects: Array = [{"code": "HEAL_LIFE", "amount": 5}]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "eadhadh")
	if filtered.size() != 1:
		push_error("HEAL_LIFE should NOT be negative")
		return false
	return true


# =============================================================================
# 28. detect_field_from_verb (static)
# =============================================================================

func test_detect_field_combattre() -> bool:
	var field: String = MerlinEffectEngine.detect_field_from_verb("combattre")
	if field != "vigueur":
		push_error("detect_field combattre: expected vigueur, got %s" % field)
		return false
	return true


func test_detect_field_observer() -> bool:
	var field: String = MerlinEffectEngine.detect_field_from_verb("observer")
	if field != "observation":
		push_error("detect_field observer: expected observation, got %s" % field)
		return false
	return true


func test_detect_field_marchander() -> bool:
	var field: String = MerlinEffectEngine.detect_field_from_verb("marchander")
	if field != "bluff":
		push_error("detect_field marchander: expected bluff, got %s" % field)
		return false
	return true


func test_detect_field_case_insensitive() -> bool:
	var field: String = MerlinEffectEngine.detect_field_from_verb("COMBATTRE")
	if field != "vigueur":
		push_error("detect_field case: expected vigueur, got %s" % field)
		return false
	return true


func test_detect_field_unknown_fallback() -> bool:
	var field: String = MerlinEffectEngine.detect_field_from_verb("teleporter")
	if field != MerlinConstants.ACTION_VERB_FALLBACK_FIELD:
		push_error("detect_field fallback: expected %s, got %s" % [MerlinConstants.ACTION_VERB_FALLBACK_FIELD, field])
		return false
	return true


func test_detect_field_with_spaces() -> bool:
	var field: String = MerlinEffectEngine.detect_field_from_verb("  calmer  ")
	if field != "esprit":
		push_error("detect_field spaces: expected esprit, got %s" % field)
		return false
	return true


# =============================================================================
# 29. pick_minigame_for_field (static)
# =============================================================================

func test_pick_minigame_logique() -> bool:
	var mg: String = MerlinEffectEngine.pick_minigame_for_field("logique")
	if mg != "runes":
		push_error("pick_minigame logique: expected runes, got %s" % mg)
		return false
	return true


func test_pick_minigame_chance() -> bool:
	var mg: String = MerlinEffectEngine.pick_minigame_for_field("chance")
	if mg != "herboristerie":
		push_error("pick_minigame chance: expected herboristerie, got %s" % mg)
		return false
	return true


func test_pick_minigame_unknown_fallback() -> bool:
	var mg: String = MerlinEffectEngine.pick_minigame_for_field("nonexistent")
	if mg != "apaisement":
		push_error("pick_minigame fallback: expected apaisement, got %s" % mg)
		return false
	return true


func test_pick_minigame_returns_valid_string() -> bool:
	# All known fields should return a non-empty string
	var fields: Array = ["chance", "bluff", "observation", "logique", "finesse", "vigueur", "esprit", "perception"]
	for field in fields:
		var mg: String = MerlinEffectEngine.pick_minigame_for_field(field)
		if mg.is_empty():
			push_error("pick_minigame %s: returned empty string" % field)
			return false
	return true


# =============================================================================
# FIRE-AND-FORGET effects
# =============================================================================

func test_fire_and_forget_all_applied() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, [
		"PLAY_SFX:heal_chime",
		"SHOW_DIALOG:merlin_warns",
		"TRIGGER_EVENT:merchant_appears",
	])
	if result["applied"].size() != 3:
		push_error("fire-and-forget: expected 3 applied, got %d" % result["applied"].size())
		return false
	return true
