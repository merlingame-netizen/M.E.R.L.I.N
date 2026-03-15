extends RefCounted
## Unit Tests — MerlinEffectEngine
## Tests: validate all 21 effect codes, apply effects, protection, multiplier, capping.

const EffectEngine = preload("res://scripts/merlin/merlin_effect_engine.gd")


func _make_engine() -> RefCounted:
	return EffectEngine.new()


func _make_state() -> Dictionary:
	return {
		"run": {
			"life_essence": MerlinConstants.LIFE_ESSENCE_START,
			"active_tags": [],
			"card_queue": [],
			"current_arc": "",
			"active_promises": [],
			"day": 1,
			"hidden": {},
			"mission": {"progress": 0, "total": 10},
			"biome_currency": 0,
			"unlocked_oghams": [],
			"anam": 0,
			"cards_played": 0,
		},
		"meta": {
			"anam": 0,
			"faction_rep": {
				"druides": 10.0, "anciens": 10.0, "korrigans": 10.0,
				"niamh": 10.0, "ankou": 10.0,
			},
		},
		"flags": {},
		"effect_log": [],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION — All 21 effect codes
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_all_valid_codes() -> bool:
	var engine: RefCounted = _make_engine()
	var test_cases: Array = [
		"PROGRESS_MISSION:1",
		"ADD_KARMA:10",
		"ADD_TENSION:15",
		"ADD_NARRATIVE_DEBT:trahison:La trahison reviendra",
		"DAMAGE_LIFE:2",
		"HEAL_LIFE:1",
		"SET_FLAG:met_druide:true",
		"ADD_TAG:war_brewing",
		"REMOVE_TAG:peace",
		"QUEUE_CARD:card_finale",
		"TRIGGER_ARC:druide_arc",
		"CREATE_PROMISE:oath_001:5:description",
		"FULFILL_PROMISE:oath_001",
		"BREAK_PROMISE:oath_001",
		"ADD_REPUTATION:druides:15",
		"ADD_ANAM:5",
		"ADD_BIOME_CURRENCY:10",
		"UNLOCK_OGHAM:beith",
		"PLAY_SFX:heal_chime",
		"SHOW_DIALOG:merlin_warns",
		"TRIGGER_EVENT:merchant_appears",
	]
	for effect_str in test_cases:
		if not engine.validate_effect(effect_str):
			push_error("Should validate: %s" % effect_str)
			return false
	return true


func test_validate_rejects_unknown_code() -> bool:
	var engine: RefCounted = _make_engine()
	if engine.validate_effect("UNKNOWN_CODE:123"):
		push_error("Should reject unknown code")
		return false
	return true


func test_validate_rejects_wrong_arg_count() -> bool:
	var engine: RefCounted = _make_engine()
	# ADD_KARMA expects 1 arg, giving 2
	if engine.validate_effect("ADD_KARMA:10:extra"):
		push_error("Should reject wrong arg count")
		return false
	# ADD_REPUTATION expects 2 args, giving 1
	if engine.validate_effect("ADD_REPUTATION:druides"):
		push_error("Should reject missing arg")
		return false
	return true


func test_validate_rejects_empty() -> bool:
	var engine: RefCounted = _make_engine()
	if engine.validate_effect(""):
		push_error("Should reject empty effect")
		return false
	return true


func test_narrative_debt_colon_in_description_breaks() -> bool:
	# KNOWN LIMITATION: colon-delimited format means descriptions containing ":"
	# will be parsed as extra args and rejected. LLM output must avoid colons.
	var engine: RefCounted = _make_engine()
	if engine.validate_effect("ADD_NARRATIVE_DEBT:trahison:Attention: le retour"):
		push_error("Colon in description produces 3 args (expected 2) — known limitation")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# APPLY — Life effects
# ═══════════════════════════════════════════════════════════════════════════════

func test_apply_damage_life() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	var before: int = int(state["run"]["life_essence"])
	engine.apply_effects(state, ["DAMAGE_LIFE:5"])
	var after: int = int(state["run"]["life_essence"])
	if after != before - 5:
		push_error("Expected life %d, got %d" % [before - 5, after])
		return false
	return true


func test_apply_heal_life() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	state["run"]["life_essence"] = 50
	engine.apply_effects(state, ["HEAL_LIFE:10"])
	var after: int = int(state["run"]["life_essence"])
	if after != 60:
		push_error("Expected life 60, got %d" % after)
		return false
	return true


func test_life_clamped_at_zero() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	state["run"]["life_essence"] = 3
	engine.apply_effects(state, ["DAMAGE_LIFE:50"])
	var after: int = int(state["run"]["life_essence"])
	if after != 0:
		push_error("Life should clamp at 0, got %d" % after)
		return false
	return true


func test_life_clamped_at_max() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	state["run"]["life_essence"] = MerlinConstants.LIFE_ESSENCE_MAX - 2
	engine.apply_effects(state, ["HEAL_LIFE:50"])
	var after: int = int(state["run"]["life_essence"])
	if after != MerlinConstants.LIFE_ESSENCE_MAX:
		push_error("Life should clamp at max, got %d" % after)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# APPLY — Tags & Flags
# ═══════════════════════════════════════════════════════════════════════════════

func test_apply_add_tag() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_TAG:war_brewing"])
	var tags: Array = state["run"].get("active_tags", [])
	if not tags.has("war_brewing"):
		push_error("Tag not added")
		return false
	return true


func test_apply_remove_tag() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	state["run"]["active_tags"] = ["peace", "trade"]
	engine.apply_effects(state, ["REMOVE_TAG:peace"])
	var tags: Array = state["run"].get("active_tags", [])
	if tags.has("peace"):
		push_error("Tag not removed")
		return false
	if not tags.has("trade"):
		push_error("Other tag should remain")
		return false
	return true


func test_apply_set_flag() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["SET_FLAG:met_druide:true"])
	var flags: Dictionary = state.get("flags", {})
	if not flags.get("met_druide", false):
		push_error("Flag not set")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# APPLY — Reputation
# ═══════════════════════════════════════════════════════════════════════════════

func test_apply_add_reputation() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_REPUTATION:druides:15"])
	var rep: int = int(state["meta"]["faction_rep"].get("druides", 0))
	if rep != 25:
		push_error("Expected rep 25, got %d" % rep)
		return false
	return true


func test_reputation_clamped_at_bounds() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	state["meta"]["faction_rep"]["druides"] = 95
	engine.apply_effects(state, ["ADD_REPUTATION:druides:20"])
	var rep: int = int(state["meta"]["faction_rep"].get("druides", 0))
	if rep != MerlinConstants.FACTION_SCORE_MAX:
		push_error("Rep should clamp at max %d, got %d" % [MerlinConstants.FACTION_SCORE_MAX, rep])
		return false
	return true


func test_reputation_invalid_faction_rejected() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["ADD_REPUTATION:goblins:10"])
	if result["rejected"].is_empty():
		push_error("Invalid faction should be rejected")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# APPLY — Promises
# ═══════════════════════════════════════════════════════════════════════════════

func test_create_promise() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_001:5:Save the village"])
	var promises: Array = state["run"].get("active_promises", [])
	if promises.size() != 1:
		push_error("Expected 1 promise, got %d" % promises.size())
		return false
	if promises[0].get("id") != "oath_001":
		push_error("Wrong promise id")
		return false
	if promises[0].get("status") != "active":
		push_error("Promise should be active")
		return false
	return true


func test_fulfill_promise() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_001:5:desc"])
	engine.apply_effects(state, ["FULFILL_PROMISE:oath_001"])
	var promises: Array = state["run"].get("active_promises", [])
	if promises[0].get("status") != "fulfilled":
		push_error("Promise should be fulfilled")
		return false
	return true


func test_break_promise() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["CREATE_PROMISE:oath_001:5:desc"])
	engine.apply_effects(state, ["BREAK_PROMISE:oath_001"])
	var promises: Array = state["run"].get("active_promises", [])
	if promises[0].get("status") != "broken":
		push_error("Promise should be broken")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# APPLY — Anam, Currency, Queue, Arc, Mission
# ═══════════════════════════════════════════════════════════════════════════════

func test_apply_add_anam() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_ANAM:5"])
	if int(state["run"].get("anam", 0)) != 5:
		push_error("Run anam should be 5")
		return false
	if int(state["meta"].get("anam", 0)) != 5:
		push_error("Meta anam should be 5")
		return false
	return true


func test_apply_add_anam_zero_rejected() -> bool:
	# NOTE: validate_effect("ADD_ANAM:0") returns true (arg count OK),
	# but apply rejects it (_apply_add_anam returns false for amount=0).
	# This is a known inconsistency — validation checks syntax, not semantics.
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, ["ADD_ANAM:0"])
	if result["rejected"].is_empty():
		push_error("ADD_ANAM:0 should be rejected at apply time")
		return false
	return true


func test_apply_biome_currency() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_BIOME_CURRENCY:10"])
	if int(state["run"].get("biome_currency", 0)) != 10:
		push_error("Currency should be 10")
		return false
	return true


func test_apply_queue_card() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["QUEUE_CARD:card_finale"])
	var queue: Array = state["run"].get("card_queue", [])
	if not queue.has("card_finale"):
		push_error("Card not queued")
		return false
	return true


func test_apply_trigger_arc() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["TRIGGER_ARC:druide_arc"])
	if state["run"].get("current_arc") != "druide_arc":
		push_error("Arc not set")
		return false
	return true


func test_apply_progress_mission() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["PROGRESS_MISSION:3"])
	var progress: int = int(state["run"]["mission"].get("progress", 0))
	if progress != 3:
		push_error("Mission progress should be 3, got %d" % progress)
		return false
	return true


func test_apply_hidden_karma() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_KARMA:10"])
	var karma: int = int(state["run"]["hidden"].get("karma", 0))
	if karma != 10:
		push_error("Karma should be 10, got %d" % karma)
		return false
	return true


func test_apply_tension_clamped() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	state["run"]["hidden"] = {"tension": 95}
	engine.apply_effects(state, ["ADD_TENSION:20"])
	var tension: int = int(state["run"]["hidden"].get("tension", 0))
	if tension != 100:
		push_error("Tension should clamp at 100, got %d" % tension)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# APPLY — Fire-and-forget (SFX, Dialog, Event)
# ═══════════════════════════════════════════════════════════════════════════════

func test_fire_and_forget_applied() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, [
		"PLAY_SFX:heal_chime", "SHOW_DIALOG:merlin_warns", "TRIGGER_EVENT:merchant_appears"
	])
	if result["applied"].size() != 3:
		push_error("All 3 fire-and-forget should be applied")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MULTIPLIER & CAPPING
# ═══════════════════════════════════════════════════════════════════════════════

func test_multiplier_score_0() -> bool:
	var m: float = EffectEngine.get_multiplier(0)
	# Score 0 = echec_critique → factor -1.5
	if m != -1.5:
		push_error("Score 0 multiplier should be -1.5, got %f" % m)
		return false
	return true


func test_multiplier_score_100() -> bool:
	var m: float = EffectEngine.get_multiplier(100)
	if m != 1.5:
		push_error("Score 100 multiplier should be 1.5 (reussite_critique), got %f" % m)
		return false
	return true


func test_multiplier_boundaries() -> bool:
	# echec_critique: 0-20
	if EffectEngine.get_multiplier(20) != -1.5:
		push_error("Score 20 should be echec_critique (-1.5)")
		return false
	# echec: 21-50
	if EffectEngine.get_multiplier(21) != -1.0:
		push_error("Score 21 should be echec (-1.0)")
		return false
	if EffectEngine.get_multiplier(50) != -1.0:
		push_error("Score 50 should be echec (-1.0)")
		return false
	# reussite_partielle: 51-79
	if EffectEngine.get_multiplier(51) != 0.5:
		push_error("Score 51 should be reussite_partielle (0.5)")
		return false
	if EffectEngine.get_multiplier(79) != 0.5:
		push_error("Score 79 should be reussite_partielle (0.5)")
		return false
	# reussite: 80-94
	if EffectEngine.get_multiplier(80) != 1.0:
		push_error("Score 80 should be reussite (1.0)")
		return false
	# reussite_critique: 95-100
	if EffectEngine.get_multiplier(95) != 1.5:
		push_error("Score 95 should be reussite_critique (1.5)")
		return false
	return true


func test_cap_reputation() -> bool:
	var capped: int = EffectEngine.cap_effect("ADD_REPUTATION", 50)
	if capped > 20:
		push_error("Reputation should cap at 20, got %d" % capped)
		return false
	return true


func test_cap_negative_reputation() -> bool:
	var capped: int = EffectEngine.cap_effect("ADD_REPUTATION", -50)
	if capped < -20:
		push_error("Negative reputation should cap at -20, got %d" % capped)
		return false
	return true


func test_scale_and_cap() -> bool:
	# Case 1: scaled value below cap (10*1.5=15 < 20)
	var r1: int = EffectEngine.scale_and_cap("ADD_REPUTATION", 10, 1.5)
	if r1 != 15:
		push_error("Expected 15, got %d" % r1)
		return false
	# Case 2: scaled value exceeds cap (15*2=30, capped to 20)
	var r2: int = EffectEngine.scale_and_cap("ADD_REPUTATION", 15, 2.0)
	if r2 != 20:
		push_error("Expected capped at 20, got %d" % r2)
		return false
	# Case 3: negative multiplier produces negative result
	var r3: int = EffectEngine.scale_and_cap("ADD_REPUTATION", 10, -1.5)
	if r3 >= 0:
		push_error("Negative multiplier should produce negative, got %d" % r3)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# NEGATIVE EFFECT DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_negative_effect_damage() -> bool:
	if not EffectEngine._is_negative_effect({"code": "DAMAGE_LIFE", "amount": 5}):
		push_error("DAMAGE_LIFE should be negative")
		return false
	return true


func test_negative_effect_negative_rep() -> bool:
	if not EffectEngine._is_negative_effect({"code": "ADD_REPUTATION", "amount": -10}):
		push_error("Negative ADD_REPUTATION should be negative")
		return false
	return true


func test_positive_rep_not_negative() -> bool:
	if EffectEngine._is_negative_effect({"code": "ADD_REPUTATION", "amount": 10}):
		push_error("Positive ADD_REPUTATION should not be negative")
		return false
	return true


func test_heal_not_negative() -> bool:
	if EffectEngine._is_negative_effect({"code": "HEAL_LIFE", "amount": 5}):
		push_error("HEAL_LIFE should not be negative")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT LOG
# ═══════════════════════════════════════════════════════════════════════════════

func test_effect_log_recorded() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["HEAL_LIFE:5", "ADD_TAG:test"], "CARD")
	var log: Array = state.get("effect_log", [])
	if log.size() != 2:
		push_error("Expected 2 log entries, got %d" % log.size())
		return false
	if log[0].get("source") != "CARD":
		push_error("Source should be CARD")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MIXED — Applied + Rejected in same batch
# ═══════════════════════════════════════════════════════════════════════════════

func test_mixed_batch() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, [
		"HEAL_LIFE:5",
		"UNKNOWN_CODE:123",
		"ADD_TAG:test",
	])
	if result["applied"].size() != 2:
		push_error("Expected 2 applied, got %d" % result["applied"].size())
		return false
	if result["rejected"].size() != 1:
		push_error("Expected 1 rejected, got %d" % result["rejected"].size())
		return false
	return true


func test_non_string_effect_rejected() -> bool:
	var engine: RefCounted = _make_engine()
	var state: Dictionary = _make_state()
	var result: Dictionary = engine.apply_effects(state, [123, null])
	if result["rejected"].size() != 2:
		push_error("Non-string effects should be rejected")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# VERB DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_detect_field_from_verb_combat() -> bool:
	var field: String = EffectEngine.detect_field_from_verb("attaquer")
	if field.is_empty():
		push_error("Should detect a field for 'attaquer'")
		return false
	return true


func test_detect_field_fallback() -> bool:
	var field: String = EffectEngine.detect_field_from_verb("xyzunknownverb")
	if field != MerlinConstants.ACTION_VERB_FALLBACK_FIELD:
		push_error("Unknown verb should fallback to %s" % MerlinConstants.ACTION_VERB_FALLBACK_FIELD)
		return false
	return true
