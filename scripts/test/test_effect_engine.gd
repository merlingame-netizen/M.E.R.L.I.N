## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinEffectEngine v2.4
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: apply_effects (ADD_REPUTATION, HEAL_LIFE, DAMAGE_LIFE), cap_effect,
## invalid effect types, ogham protection, validate_effect.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


func _make_state() -> Dictionary:
	return {
		"run": {
			"life_essence": 50,
			"anam": 0,
		},
		"meta": {
			"faction_rep": {
				"druides": 10, "anciens": 10, "korrigans": 10, "niamh": 10, "ankou": 10,
			},
		},
		"effect_log": [],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# ADD_REPUTATION
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_reputation_effect() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	var result: Dictionary = engine.apply_effects(state, ["ADD_REPUTATION:druides:15"])
	if result["applied"].size() != 1:
		push_error("ADD_REPUTATION: expected 1 applied, got %d" % result["applied"].size())
		return false
	var new_rep: int = int(state["meta"]["faction_rep"]["druides"])
	if new_rep != 25:  # 10 + 15
		push_error("ADD_REPUTATION: expected 25, got %d" % new_rep)
		return false
	return true


func test_add_reputation_clamped_max() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	state["meta"]["faction_rep"]["druides"] = 90
	engine.apply_effects(state, ["ADD_REPUTATION:druides:20"])
	var rep: int = int(state["meta"]["faction_rep"]["druides"])
	if rep != 100:
		push_error("ADD_REPUTATION clamp max: expected 100, got %d" % rep)
		return false
	return true


func test_add_reputation_clamped_min() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	state["meta"]["faction_rep"]["druides"] = 5
	engine.apply_effects(state, ["ADD_REPUTATION:druides:-20"])
	var rep: int = int(state["meta"]["faction_rep"]["druides"])
	if rep != 0:
		push_error("ADD_REPUTATION clamp min: expected 0, got %d" % rep)
		return false
	return true


func test_add_reputation_invalid_faction() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	var result: Dictionary = engine.apply_effects(state, ["ADD_REPUTATION:humains:10"])
	if result["rejected"].size() != 1:
		push_error("Invalid faction should be rejected")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# HEAL_LIFE
# ═══════════════════════════════════════════════════════════════════════════════

func test_heal_life_effect() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	state["run"]["life_essence"] = 40
	var result: Dictionary = engine.apply_effects(state, ["HEAL_LIFE:10"])
	if result["applied"].size() != 1:
		push_error("HEAL_LIFE: expected 1 applied")
		return false
	var life: int = int(state["run"]["life_essence"])
	if life != 50:
		push_error("HEAL_LIFE: expected 50, got %d" % life)
		return false
	return true


func test_heal_life_clamped_at_max() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	state["run"]["life_essence"] = 95
	engine.apply_effects(state, ["HEAL_LIFE:15"])
	var life: int = int(state["run"]["life_essence"])
	if life != MerlinConstants.LIFE_ESSENCE_MAX:
		push_error("HEAL_LIFE clamp max: expected %d, got %d" % [MerlinConstants.LIFE_ESSENCE_MAX, life])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DAMAGE_LIFE
# ═══════════════════════════════════════════════════════════════════════════════

func test_damage_life_effect() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	state["run"]["life_essence"] = 50
	var result: Dictionary = engine.apply_effects(state, ["DAMAGE_LIFE:8"])
	if result["applied"].size() != 1:
		push_error("DAMAGE_LIFE: expected 1 applied")
		return false
	var life: int = int(state["run"]["life_essence"])
	if life != 42:
		push_error("DAMAGE_LIFE: expected 42, got %d" % life)
		return false
	return true


func test_damage_life_clamped_at_zero() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	state["run"]["life_essence"] = 5
	engine.apply_effects(state, ["DAMAGE_LIFE:15"])
	var life: int = int(state["run"]["life_essence"])
	if life != 0:
		push_error("DAMAGE_LIFE clamp min: expected 0, got %d" % life)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT CAPS — static cap_effect
# ═══════════════════════════════════════════════════════════════════════════════

func test_cap_effect_reputation_max() -> bool:
	var capped: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", 50)
	if capped != 20:
		push_error("cap_effect ADD_REPUTATION max: expected 20, got %d" % capped)
		return false
	return true


func test_cap_effect_reputation_min() -> bool:
	var capped: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", -50)
	if capped != -20:
		push_error("cap_effect ADD_REPUTATION min: expected -20, got %d" % capped)
		return false
	return true


func test_cap_effect_heal_life() -> bool:
	# Max heal is 18 per EFFECT_CAPS
	var capped: int = MerlinEffectEngine.cap_effect("HEAL_LIFE", 99)
	if capped != 18:
		push_error("cap_effect HEAL_LIFE max: expected 18, got %d" % capped)
		return false
	return true


func test_cap_effect_damage_life() -> bool:
	# Max damage is 15 per EFFECT_CAPS
	var capped: int = MerlinEffectEngine.cap_effect("DAMAGE_LIFE", 99)
	if capped != 15:
		push_error("cap_effect DAMAGE_LIFE max: expected 15, got %d" % capped)
		return false
	return true


func test_cap_effect_uncapped_type_unchanged() -> bool:
	# Types not in the match should pass through unchanged
	var val: int = MerlinEffectEngine.cap_effect("ADD_ANAM", 999)
	if val != 999:
		push_error("cap_effect uncapped: expected 999, got %d" % val)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# INVALID EFFECT TYPE
# ═══════════════════════════════════════════════════════════════════════════════

func test_invalid_effect_type_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	var result: Dictionary = engine.apply_effects(state, ["EXPLODE_EVERYTHING:99"])
	if result["rejected"].size() != 1:
		push_error("Unknown effect should be rejected, got %d rejected" % result["rejected"].size())
		return false
	if result["errors"].size() != 1:
		push_error("Unknown effect should produce 1 error")
		return false
	return true


func test_empty_effects_array() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	var result: Dictionary = engine.apply_effects(state, [])
	if result["applied"].size() != 0:
		push_error("Empty effects: applied should be 0")
		return false
	if result["rejected"].size() != 0:
		push_error("Empty effects: rejected should be 0")
		return false
	return true


func test_non_string_effect_rejected() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	var result: Dictionary = engine.apply_effects(state, [42, null, {"type": "HEAL_LIFE"}])
	if result["rejected"].size() != 3:
		push_error("Non-string effects should all be rejected, got %d" % result["rejected"].size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATE_EFFECT
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_effect_valid() -> bool:
	var engine := MerlinEffectEngine.new()
	if not engine.validate_effect("HEAL_LIFE:5"):
		push_error("validate_effect: HEAL_LIFE:5 should be valid")
		return false
	if not engine.validate_effect("ADD_REPUTATION:druides:10"):
		push_error("validate_effect: ADD_REPUTATION:druides:10 should be valid")
		return false
	return true


func test_validate_effect_invalid() -> bool:
	var engine := MerlinEffectEngine.new()
	if engine.validate_effect("UNKNOWN_CODE:5"):
		push_error("validate_effect: unknown code should be invalid")
		return false
	if engine.validate_effect("HEAL_LIFE"):
		push_error("validate_effect: missing args should be invalid")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT LOG
# ═══════════════════════════════════════════════════════════════════════════════

func test_effect_log_recorded() -> bool:
	var engine := MerlinEffectEngine.new()
	var state := _make_state()
	engine.apply_effects(state, ["HEAL_LIFE:5"], "TEST_SOURCE")
	var log: Array = state.get("effect_log", [])
	if log.size() == 0:
		push_error("Effect log should have at least 1 entry")
		return false
	var entry: Dictionary = log[0]
	if str(entry.get("source", "")) != "TEST_SOURCE":
		push_error("Effect log source mismatch: %s" % entry.get("source", ""))
		return false
	if str(entry.get("status", "")) != "applied":
		push_error("Effect log status should be 'applied'")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM PROTECTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_protection_empty_ogham_passthrough() -> bool:
	var effects: Array = [
		{"code": "DAMAGE_LIFE", "amount": 5},
		{"code": "HEAL_LIFE", "amount": 3},
	]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "")
	if filtered.size() != 2:
		push_error("Empty ogham: all effects should pass through, got %d" % filtered.size())
		return false
	return true


func test_ogham_protection_luis_blocks_first_negative() -> bool:
	# Luis = block_first_negative
	var effects: Array = [
		{"code": "DAMAGE_LIFE", "amount": 5},
		{"code": "DAMAGE_LIFE", "amount": 3},
		{"code": "HEAL_LIFE", "amount": 5},
	]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "luis")
	# First DAMAGE_LIFE should be removed (1 block), second remains
	if filtered.size() != 2:
		push_error("luis block_first_negative: expected 2 effects, got %d" % filtered.size())
		return false
	# HEAL_LIFE and second DAMAGE_LIFE should remain
	var has_damage := false
	var has_heal := false
	for eff in filtered:
		if str(eff.get("code", "")) == "DAMAGE_LIFE":
			has_damage = true
		if str(eff.get("code", "")) == "HEAL_LIFE":
			has_heal = true
	if not has_damage or not has_heal:
		push_error("luis: second DAMAGE and HEAL should remain")
		return false
	return true


func test_ogham_protection_eadhadh_cancels_all_negatives() -> bool:
	# eadhadh = cancel_all_negatives
	var effects: Array = [
		{"code": "DAMAGE_LIFE", "amount": 5},
		{"code": "HEAL_LIFE", "amount": 3},
		{"code": "DAMAGE_LIFE", "amount": 10},
	]
	var filtered: Array = MerlinEffectEngine.apply_ogham_protection(effects, "eadhadh")
	for eff in filtered:
		if str(eff.get("code", "")) == "DAMAGE_LIFE":
			push_error("eadhadh: all DAMAGE_LIFE should be removed")
			return false
	if filtered.size() != 1:
		push_error("eadhadh: only HEAL_LIFE should remain, got %d" % filtered.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MULTIPLIER — get_multiplier
# ═══════════════════════════════════════════════════════════════════════════════

func test_multiplier_critical_success() -> bool:
	var factor: float = MerlinEffectEngine.get_multiplier(95)
	if not is_equal_approx(factor, 1.5):
		push_error("Multiplier at 95 should be 1.5, got %f" % factor)
		return false
	return true


func test_multiplier_critical_failure() -> bool:
	var factor: float = MerlinEffectEngine.get_multiplier(10)
	if not is_equal_approx(factor, -1.5):
		push_error("Multiplier at 10 should be -1.5, got %f" % factor)
		return false
	return true


func test_multiplier_partial_success() -> bool:
	var factor: float = MerlinEffectEngine.get_multiplier(60)
	if not is_equal_approx(factor, 0.5):
		push_error("Multiplier at 60 should be 0.5, got %f" % factor)
		return false
	return true


func test_multiplier_out_of_range_defaults_1() -> bool:
	var factor: float = MerlinEffectEngine.get_multiplier(200)
	if not is_equal_approx(factor, 1.0):
		push_error("Out-of-range multiplier should default to 1.0, got %f" % factor)
		return false
	return true
