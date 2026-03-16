## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinEffectEngine (methods NOT covered by test_effect_engine.gd)
## ═══════════════════════════════════════════════════════════════════════════════
## Covers: PROGRESS_MISSION, ADD_KARMA, ADD_TENSION, ADD_NARRATIVE_DEBT,
## SET_FLAG, ADD_TAG, REMOVE_TAG, QUEUE_CARD, TRIGGER_ARC, ADD_PROMISE,
## CREATE_PROMISE, FULFILL_PROMISE, BREAK_PROMISE, ADD_ANAM, UNLOCK_OGHAM,
## ADD_BIOME_CURRENCY, OFFERING, fire-and-forget effects, scale_and_cap,
## gort ogham protection, activate_ogham, detect_field_from_verb,
## pick_minigame_for_field, get_multiplier_label, faction_context building.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


func _make_state() -> Dictionary:
	return {
		"run": {
			"life_essence": 50,
			"anam": 0,
			"cards_played": 5,
			"mission": {"progress": 2, "total": 10},
			"hidden": {"karma": 0, "tension": 0},
			"active_tags": [],
			"card_queue": [],
			"promises": [],
			"active_promises": [],
			"unlocked_oghams": [],
			"biome_currency": 20,
			"day": 3,
		},
		"meta": {
			"faction_rep": {
				"druides": 10, "anciens": 10, "korrigans": 10, "niamh": 10, "ankou": 10,
			},
			"anam": 0,
		},
		"effect_log": [],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# PROGRESS_MISSION
# ═══════════════════════════════════════════════════════════════════════════════

func test_progress_mission_increments() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["PROGRESS_MISSION:3"])
	if result["applied"].size() != 1:
		push_error("PROGRESS_MISSION: expected 1 applied, got %d" % result["applied"].size())
		return false
	var progress: int = int(state["run"]["mission"]["progress"])
	if progress != 5:  # 2 + 3
		push_error("PROGRESS_MISSION: expected 5, got %d" % progress)
		return false
	return true


func test_progress_mission_clamped_at_total() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["PROGRESS_MISSION:99"])
	var progress: int = int(state["run"]["mission"]["progress"])
	if progress != 10:  # clamped to total
		push_error("PROGRESS_MISSION clamp: expected 10, got %d" % progress)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ADD_KARMA / ADD_TENSION
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_karma_positive() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_KARMA:25"])
	var karma: int = int(state["run"]["hidden"]["karma"])
	if karma != 25:
		push_error("ADD_KARMA: expected 25, got %d" % karma)
		return false
	return true


func test_add_karma_clamped_range() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_KARMA:-200"])
	var karma: int = int(state["run"]["hidden"]["karma"])
	if karma != -100:  # clamped to [-100, 100]
		push_error("ADD_KARMA clamp min: expected -100, got %d" % karma)
		return false
	return true


func test_add_tension_clamped_at_100() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_TENSION:150"])
	var tension: int = int(state["run"]["hidden"]["tension"])
	if tension != 100:  # clamped to [0, 100]
		push_error("ADD_TENSION clamp max: expected 100, got %d" % tension)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ADD_NARRATIVE_DEBT
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_narrative_debt() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["ADD_NARRATIVE_DEBT:trahison:La trahison reviendra"])
	if result["applied"].size() != 1:
		push_error("ADD_NARRATIVE_DEBT: expected 1 applied")
		return false
	var debts: Array = state["run"]["hidden"]["narrative_debt"]
	if debts.size() != 1:
		push_error("ADD_NARRATIVE_DEBT: expected 1 debt, got %d" % debts.size())
		return false
	var debt: Dictionary = debts[0]
	if str(debt.get("type", "")) != "trahison":
		push_error("ADD_NARRATIVE_DEBT: wrong type: %s" % debt.get("type", ""))
		return false
	if int(debt.get("created_card", -1)) != 5:
		push_error("ADD_NARRATIVE_DEBT: wrong created_card: %d" % int(debt.get("created_card", -1)))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SET_FLAG / ADD_TAG / REMOVE_TAG / QUEUE_CARD / TRIGGER_ARC
# ═══════════════════════════════════════════════════════════════════════════════

func test_set_flag_true() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["SET_FLAG:met_druide:true"])
	var flags: Dictionary = state.get("flags", {})
	if not flags.get("met_druide", false):
		push_error("SET_FLAG: met_druide should be true")
		return false
	return true


func test_set_flag_false_value() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["SET_FLAG:some_flag:false"])
	var flags: Dictionary = state.get("flags", {})
	if flags.get("some_flag", true):
		push_error("SET_FLAG: 'false' string should set flag to false")
		return false
	return true


func test_add_tag_and_remove_tag() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_TAG:war_brewing"])
	var tags: Array = state["run"]["active_tags"]
	if not tags.has("war_brewing"):
		push_error("ADD_TAG: war_brewing should be present")
		return false
	# Add duplicate — should not create second entry
	engine.apply_effects(state, ["ADD_TAG:war_brewing"])
	tags = state["run"]["active_tags"]
	var tracker: Dictionary = {"count": 0}
	for t in tags:
		if str(t) == "war_brewing":
			tracker["count"] = int(tracker["count"]) + 1
	if int(tracker["count"]) != 1:
		push_error("ADD_TAG: duplicate should be prevented, got %d" % int(tracker["count"]))
		return false
	# Remove
	engine.apply_effects(state, ["REMOVE_TAG:war_brewing"])
	tags = state["run"]["active_tags"]
	if tags.has("war_brewing"):
		push_error("REMOVE_TAG: war_brewing should be removed")
		return false
	return true


func test_queue_card() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["QUEUE_CARD:card_finale"])
	var queue: Array = state["run"]["card_queue"]
	if queue.size() != 1 or str(queue[0]) != "card_finale":
		push_error("QUEUE_CARD: expected [card_finale], got %s" % str(queue))
		return false
	return true


func test_trigger_arc() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["TRIGGER_ARC:druide_arc"])
	var current_arc: String = str(state["run"].get("current_arc", ""))
	if current_arc != "druide_arc":
		push_error("TRIGGER_ARC: expected druide_arc, got %s" % current_arc)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROMISE SYSTEM — ADD_PROMISE (cap 2), CREATE/FULFILL/BREAK_PROMISE
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_promise_basic() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["ADD_PROMISE:oath_01:10"])
	if result["applied"].size() != 1:
		push_error("ADD_PROMISE: expected 1 applied")
		return false
	var promises: Array = state["run"]["promises"]
	if promises.size() != 1:
		push_error("ADD_PROMISE: expected 1 promise, got %d" % promises.size())
		return false
	var p: Dictionary = promises[0]
	if str(p.get("status", "")) != "active":
		push_error("ADD_PROMISE: status should be active")
		return false
	if int(p.get("made_at_card", -1)) != 5:
		push_error("ADD_PROMISE: made_at_card should be 5 (cards_played)")
		return false
	return true


func test_add_promise_cap_at_two() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_PROMISE:oath_01:10"])
	engine.apply_effects(state, ["ADD_PROMISE:oath_02:10"])
	var result: Dictionary = engine.apply_effects(state, ["ADD_PROMISE:oath_03:10"])
	# Third promise should be rejected (cap 2 active)
	if result["rejected"].size() != 1:
		push_error("ADD_PROMISE cap: 3rd promise should be rejected")
		return false
	var promises: Array = state["run"]["promises"]
	if promises.size() != 2:
		push_error("ADD_PROMISE cap: should have exactly 2, got %d" % promises.size())
		return false
	return true


func test_create_and_fulfill_promise() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_001:5:Find the relic"])
	var promises: Array = state["run"]["active_promises"]
	if promises.size() != 1:
		push_error("CREATE_PROMISE: expected 1, got %d" % promises.size())
		return false
	var p: Dictionary = promises[0]
	if int(p.get("deadline_day", 0)) != 8:  # day 3 + 5
		push_error("CREATE_PROMISE: deadline_day should be 8, got %d" % int(p.get("deadline_day", 0)))
		return false
	# Fulfill
	engine.apply_effects(state, ["FULFILL_PROMISE:oath_001"])
	promises = state["run"]["active_promises"]
	if str(promises[0].get("status", "")) != "fulfilled":
		push_error("FULFILL_PROMISE: status should be fulfilled")
		return false
	return true


func test_break_promise() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_002:3:Protect the village"])
	engine.apply_effects(state, ["BREAK_PROMISE:oath_002"])
	var promises: Array = state["run"]["active_promises"]
	if str(promises[0].get("status", "")) != "broken":
		push_error("BREAK_PROMISE: status should be broken")
		return false
	return true


func test_fulfill_nonexistent_promise_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["FULFILL_PROMISE:ghost_promise"])
	if result["rejected"].size() != 1:
		push_error("FULFILL_PROMISE nonexistent: should be rejected")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ADD_ANAM — dual update (run + meta), zero rejection
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_anam_positive() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_ANAM:15"])
	var run_anam: int = int(state["run"]["anam"])
	var meta_anam: int = int(state["meta"]["anam"])
	if run_anam != 15:
		push_error("ADD_ANAM run: expected 15, got %d" % run_anam)
		return false
	if meta_anam != 15:
		push_error("ADD_ANAM meta: expected 15, got %d" % meta_anam)
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
		push_error("ADD_ANAM negative: run anam should floor at 0")
		return false
	if int(state["meta"]["anam"]) != 0:
		push_error("ADD_ANAM negative: meta anam should floor at 0")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# UNLOCK_OGHAM / ADD_BIOME_CURRENCY
# ═══════════════════════════════════════════════════════════════════════════════

func test_unlock_ogham_valid() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["UNLOCK_OGHAM:beith"])
	if result["applied"].size() != 1:
		push_error("UNLOCK_OGHAM valid: should be applied")
		return false
	if not state["run"]["unlocked_oghams"].has("beith"):
		push_error("UNLOCK_OGHAM: beith should be in unlocked list")
		return false
	return true


func test_unlock_ogham_invalid_name_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["UNLOCK_OGHAM:fake_ogham"])
	if result["rejected"].size() != 1:
		push_error("UNLOCK_OGHAM invalid: should be rejected")
		return false
	return true


func test_unlock_ogham_duplicate_no_double() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["UNLOCK_OGHAM:beith"])
	engine.apply_effects(state, ["UNLOCK_OGHAM:beith"])
	var unlocked: Array = state["run"]["unlocked_oghams"]
	var tracker: Dictionary = {"count": 0}
	for o in unlocked:
		if str(o) == "beith":
			tracker["count"] = int(tracker["count"]) + 1
	if int(tracker["count"]) != 1:
		push_error("UNLOCK_OGHAM duplicate: should only appear once, got %d" % int(tracker["count"]))
		return false
	return true


func test_add_biome_currency() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_BIOME_CURRENCY:8"])
	var currency: int = int(state["run"]["biome_currency"])
	if currency != 28:  # 20 + 8
		push_error("ADD_BIOME_CURRENCY: expected 28, got %d" % currency)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# OFFERING — cost + reward chain
# ═══════════════════════════════════════════════════════════════════════════════

func test_offering_success_heal() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	# OFFERING:cost:reward_type:reward_value → OFFERING:10:HEAL_LIFE:5
	var result: Dictionary = engine.apply_effects(state, ["OFFERING:10:HEAL_LIFE:5"])
	if result["applied"].size() != 1:
		push_error("OFFERING success: should be applied")
		return false
	var currency: int = int(state["run"]["biome_currency"])
	if currency != 10:  # 20 - 10
		push_error("OFFERING: currency should be 10, got %d" % currency)
		return false
	var life: int = int(state["run"]["life_essence"])
	if life != 55:  # 50 + 5
		push_error("OFFERING: life should be 55, got %d" % life)
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


# ═══════════════════════════════════════════════════════════════════════════════
# FIRE-AND-FORGET — PLAY_SFX, SHOW_DIALOG, TRIGGER_EVENT
# ═══════════════════════════════════════════════════════════════════════════════

func test_fire_and_forget_applied() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, [
		"PLAY_SFX:heal_chime",
		"SHOW_DIALOG:merlin_warns",
		"TRIGGER_EVENT:merchant_appears",
	])
	if result["applied"].size() != 3:
		push_error("Fire-and-forget: all 3 should be applied, got %d" % result["applied"].size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# scale_and_cap — multiplier + cap pipeline
# ═══════════════════════════════════════════════════════════════════════════════

func test_scale_and_cap_positive_multiplier() -> bool:
	# raw=10, multiplier=1.5 → scaled=15 → cap DAMAGE_LIFE max 15 → 15
	var result: int = MerlinEffectEngine.scale_and_cap("DAMAGE_LIFE", 10, 1.5)
	if result != 15:
		push_error("scale_and_cap positive: expected 15, got %d" % result)
		return false
	return true


func test_scale_and_cap_negative_multiplier() -> bool:
	# raw=10, multiplier=-1.5 → scaled=int(10*1.5)=15 → negated=-15 → cap ADD_REPUTATION min -20 → -15
	var result: int = MerlinEffectEngine.scale_and_cap("ADD_REPUTATION", 10, -1.5)
	if result != -15:
		push_error("scale_and_cap negative: expected -15, got %d" % result)
		return false
	return true


func test_scale_and_cap_exceeds_cap() -> bool:
	# raw=20, multiplier=1.5 → scaled=30 → cap ADD_REPUTATION max 20 → 20
	var result: int = MerlinEffectEngine.scale_and_cap("ADD_REPUTATION", 20, 1.5)
	if result != 20:
		push_error("scale_and_cap exceeds: expected 20, got %d" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM PROTECTION — gort (reduce_high_damage)
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_protection_gort_reduces_high_damage() -> bool:
	var effects: Array = [
		{"code": "DAMAGE_LIFE", "amount": 15},
		{"code": "HEAL_LIFE", "amount": 5},
	]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "gort")
	# gort: damage > 10 reduced to 5
	var damage_eff: Dictionary = filtered[0]
	if int(damage_eff.get("amount", 0)) != 5:
		push_error("gort: high damage should be reduced to 5, got %d" % int(damage_eff.get("amount", 0)))
		return false
	# Original should NOT be mutated (immutability)
	if int(effects[0].get("amount", 0)) != 15:
		push_error("gort: original array should not be mutated")
		return false
	return true


func test_ogham_protection_gort_ignores_low_damage() -> bool:
	var effects: Array = [
		{"code": "DAMAGE_LIFE", "amount": 8},
	]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "gort")
	if int(filtered[0].get("amount", 0)) != 8:
		push_error("gort: damage <= threshold should be unchanged, got %d" % int(filtered[0].get("amount", 0)))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _is_negative_effect — negative ADD_REPUTATION
# ═══════════════════════════════════════════════════════════════════════════════

func test_eadhadh_removes_negative_reputation() -> bool:
	var effects: Array = [
		{"code": "ADD_REPUTATION", "amount": -10},
		{"code": "ADD_REPUTATION", "amount": 10},
		{"code": "HEAL_LIFE", "amount": 5},
	]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "eadhadh")
	# Negative ADD_REPUTATION should be removed, positive kept
	if filtered.size() != 2:
		push_error("eadhadh neg rep: expected 2 remaining, got %d" % filtered.size())
		return false
	for eff in filtered:
		if str(eff.get("code", "")) == "ADD_REPUTATION" and int(eff.get("amount", 0)) < 0:
			push_error("eadhadh: negative ADD_REPUTATION should have been removed")
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FACTION CONTEXT — built after ADD_REPUTATION
# ═══════════════════════════════════════════════════════════════════════════════

func test_faction_context_built_on_reputation_change() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_REPUTATION:druides:20"])
	var ctx: Dictionary = state["run"].get("faction_context", {})
	if ctx.is_empty():
		push_error("faction_context: should be populated after ADD_REPUTATION")
		return false
	var dominant: String = str(ctx.get("dominant", ""))
	if dominant != "druides":
		push_error("faction_context: dominant should be druides, got %s" % dominant)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# REPUTATION PER-CARD CAP ±20
# ═══════════════════════════════════════════════════════════════════════════════

func test_reputation_per_card_cap() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	# Attempt to add 50 reputation — should be capped to 20
	engine.apply_effects(state, ["ADD_REPUTATION:druides:50"])
	var rep: int = int(state["meta"]["faction_rep"]["druides"])
	if rep != 30:  # 10 + 20 (capped delta)
		push_error("Reputation per-card cap: expected 30, got %d" % rep)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# detect_field_from_verb / pick_minigame_for_field
# ═══════════════════════════════════════════════════════════════════════════════

func test_detect_field_from_known_verb() -> bool:
	var field: String = MerlinEffectEngine.detect_field_from_verb("combattre")
	if field != "vigueur":
		push_error("detect_field: combattre should map to vigueur, got %s" % field)
		return false
	return true


func test_detect_field_from_unknown_verb_fallback() -> bool:
	var field: String = MerlinEffectEngine.detect_field_from_verb("teleporter")
	if field != MerlinConstants.ACTION_VERB_FALLBACK_FIELD:
		push_error("detect_field fallback: should be %s, got %s" % [MerlinConstants.ACTION_VERB_FALLBACK_FIELD, field])
		return false
	return true


func test_pick_minigame_for_known_field() -> bool:
	var mg: String = MerlinEffectEngine.pick_minigame_for_field("logique")
	if mg != "runes":
		push_error("pick_minigame logique: expected runes, got %s" % mg)
		return false
	return true


func test_pick_minigame_for_unknown_field_fallback() -> bool:
	var mg: String = MerlinEffectEngine.pick_minigame_for_field("nonexistent_field")
	if mg != "apaisement":
		push_error("pick_minigame fallback: expected apaisement, got %s" % mg)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_multiplier_label
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_multiplier_label_critical_success() -> bool:
	var label: String = MerlinEffectEngine.get_multiplier_label(95)
	if label != "reussite_critique":
		push_error("get_multiplier_label 95: expected reussite_critique, got %s" % label)
		return false
	return true


func test_get_multiplier_label_out_of_range() -> bool:
	var label: String = MerlinEffectEngine.get_multiplier_label(200)
	if label != "reussite":
		push_error("get_multiplier_label 200: expected reussite (default), got %s" % label)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# REPUTATION EDGE CASES
# ═══════════════════════════════════════════════════════════════════════════════

func test_reputation_invalid_faction_returns_false() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["ADD_REPUTATION:nonexistent:15"])
	if result["rejected"].size() != 1:
		push_error("Invalid faction: expected 1 rejected, got %d" % result["rejected"].size())
		return false
	return true


func test_reputation_clamped_at_zero() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["meta"]["faction_rep"]["druides"] = 5
	engine.apply_effects(state, ["ADD_REPUTATION:druides:-20"])
	var score: int = int(state["meta"]["faction_rep"]["druides"])
	if score != 0:
		push_error("Rep floor: expected 0, got %d" % score)
		return false
	return true


func test_reputation_clamped_at_hundred() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["meta"]["faction_rep"]["druides"] = 95
	engine.apply_effects(state, ["ADD_REPUTATION:druides:20"])
	var score: int = int(state["meta"]["faction_rep"]["druides"])
	if score != 100:
		push_error("Rep ceiling: expected 100, got %d" % score)
		return false
	return true


func test_reputation_per_card_cap_20() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["meta"]["faction_rep"]["druides"] = 50
	engine.apply_effects(state, ["ADD_REPUTATION:druides:50"])
	var score: int = int(state["meta"]["faction_rep"]["druides"])
	# Should be capped at 50 + 20 = 70 (not 100)
	if score != 70:
		push_error("Per-card cap: expected 70, got %d" % score)
		return false
	return true


func test_reputation_rebuilds_faction_context() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	state["run"]["faction_context"] = ""
	engine.apply_effects(state, ["ADD_REPUTATION:druides:10"])
	var ctx: String = str(state["run"].get("faction_context", ""))
	if ctx.is_empty():
		push_error("Faction context not rebuilt after reputation change")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROMISE VALIDATION EDGE CASES
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_promise_empty_id_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["ADD_PROMISE::5"])
	var promises: Array = state["run"].get("promises", [])
	if promises.size() != 0:
		push_error("Empty promise_id: expected 0 promises, got %d" % promises.size())
		return false
	return true


func test_create_promise_empty_id_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["CREATE_PROMISE::5:test"])
	var promises: Array = state["run"].get("active_promises", [])
	if promises.size() != 0:
		push_error("Empty promise_id create: expected 0 promises, got %d" % promises.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MINIGAME SCORE CLAMP (process_card boundary)
# ═══════════════════════════════════════════════════════════════════════════════

func test_process_card_negative_score_clamped() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var card: Dictionary = {
		"type": "standard",
		"options": [{"effects": ["HEAL_LIFE:5"]}],
	}
	var result: Dictionary = engine.process_card(state, card, 0, -50)
	var steps: Array = result.get("steps_completed", [])
	if not steps.has("score"):
		push_error("Negative score clamp: pipeline did not reach score step")
		return false
	var mult: float = float(result.get("multiplier", 0.0))
	if mult > 0.25 or mult < 0.0:
		push_error("Negative score clamp: expected 0.0-0.25 multiplier, got %f" % mult)
		return false
	return true


func test_process_card_over_100_score_clamped() -> bool:
	var engine := MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	var card: Dictionary = {
		"type": "standard",
		"options": [{"effects": ["HEAL_LIFE:5"]}],
	}
	var result: Dictionary = engine.process_card(state, card, 0, 999)
	# Should clamp to 100, giving reussite multiplier
	var mult: float = float(result.get("multiplier", 0.0))
	if mult < 1.0:
		push_error("Over-100 score clamp: expected >=1.0 multiplier, got %f" % mult)
		return false
	return true
