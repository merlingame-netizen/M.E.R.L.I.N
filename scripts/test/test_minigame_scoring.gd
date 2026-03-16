## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — Minigame Scoring & Score-to-Effect Multiplier System v2.4
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: score range validation, MULTIPLIER_TABLE bands, effect scaling,
## score_bonus_cap (x2.0), effects_per_option cap (3), ADD_REPUTATION cap (+-20),
## HEAL_LIFE cap (18), DAMAGE_LIFE cap (15/22), zero score, perfect score.
## Pattern: extends RefCounted, run_all() returns Dictionary of test results.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name TestMinigameScoring


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_state() -> Dictionary:
	return {
		"run": {
			"life_essence": 50,
			"anam": 0,
			"biome_currency": 0,
		},
		"meta": {
			"faction_rep": {
				"druides": 10, "anciens": 10, "korrigans": 10,
				"niamh": 10, "ankou": 10,
			},
		},
		"effect_log": [],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 1. test_score_range — scores are 0.0 to 1.0 (mapped to 0-100 int in engine)
# MiniGameBase._complete clamps score to 0-100 via clampi.
# ═══════════════════════════════════════════════════════════════════════════════

func test_score_range() -> bool:
	# Verify clampi behavior matches MiniGameBase._complete logic
	var score_low: int = clampi(-10, 0, 100)
	var score_high: int = clampi(150, 0, 100)
	var score_mid: int = clampi(50, 0, 100)
	if score_low != 0:
		push_error("Score below 0 should clamp to 0, got %d" % score_low)
		return false
	if score_high != 100:
		push_error("Score above 100 should clamp to 100, got %d" % score_high)
		return false
	if score_mid != 50:
		push_error("Score 50 should stay 50, got %d" % score_mid)
		return false
	# Verify MULTIPLIER_TABLE covers full 0-100 range without gaps
	var covered: Array[bool] = []
	covered.resize(101)
	covered.fill(false)
	for entry in MerlinConstants.MULTIPLIER_TABLE:
		var rmin: int = int(entry["range_min"])
		var rmax: int = int(entry["range_max"])
		for i in range(rmin, rmax + 1):
			if i >= 0 and i <= 100:
				covered[i] = true
	for i in range(101):
		if not covered[i]:
			push_error("Score %d not covered by any MULTIPLIER_TABLE band" % i)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 2. test_multiplier_table — score brackets produce correct multipliers
# 0-20 = echec_critique (-1.5), 21-50 = echec (-1.0),
# 51-79 = reussite_partielle (0.5), 80-94 = reussite (1.0),
# 95-100 = reussite_critique (1.5)
# ═══════════════════════════════════════════════════════════════════════════════

func test_multiplier_table() -> bool:
	var expectations: Array = [
		[0, -1.5],
		[10, -1.5],
		[20, -1.5],
		[21, -1.0],
		[35, -1.0],
		[50, -1.0],
		[51, 0.5],
		[65, 0.5],
		[79, 0.5],
		[80, 1.0],
		[87, 1.0],
		[94, 1.0],
		[95, 1.5],
		[100, 1.5],
	]
	for pair in expectations:
		var score: int = int(pair[0])
		var expected: float = float(pair[1])
		var actual: float = MerlinEffectEngine.get_multiplier(score)
		if not is_equal_approx(actual, expected):
			push_error("Multiplier at score %d: expected %f, got %f" % [score, expected, actual])
			return false
	# Verify labels match bands
	var label_pairs: Array = [
		[10, "echec_critique"],
		[35, "echec"],
		[65, "reussite_partielle"],
		[85, "reussite"],
		[97, "reussite_critique"],
	]
	for pair in label_pairs:
		var label: String = MerlinEffectEngine.get_multiplier_label(int(pair[0]))
		if label != str(pair[1]):
			push_error("Label at score %d: expected '%s', got '%s'" % [pair[0], pair[1], label])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 3. test_effect_scaling — score 0.5 (50) = partial effect, 1.0 (100) = full
# score 50 → echec band (-1.0), score 85 → reussite (1.0), score 100 → 1.5
# ═══════════════════════════════════════════════════════════════════════════════

func test_effect_scaling() -> bool:
	# Score 85 (reussite, factor 1.0): raw 10 HEAL stays 10
	var factor_85: float = MerlinEffectEngine.get_multiplier(85)
	var heal_85: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 10, factor_85)
	if heal_85 != 10:
		push_error("HEAL_LIFE:10 at score 85 (x1.0): expected 10, got %d" % heal_85)
		return false
	# Score 65 (reussite_partielle, factor 0.5): raw 10 HEAL = 5
	var factor_65: float = MerlinEffectEngine.get_multiplier(65)
	var heal_65: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 10, factor_65)
	if heal_65 != 5:
		push_error("HEAL_LIFE:10 at score 65 (x0.5): expected 5, got %d" % heal_65)
		return false
	# Score 97 (reussite_critique, factor 1.5): raw 10 HEAL = 15
	var factor_97: float = MerlinEffectEngine.get_multiplier(97)
	var heal_97: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 10, factor_97)
	if heal_97 != 15:
		push_error("HEAL_LIFE:10 at score 97 (x1.5): expected 15, got %d" % heal_97)
		return false
	# Reputation scaling: score 35 (echec, -1.0): raw 10 rep = -10
	var factor_35: float = MerlinEffectEngine.get_multiplier(35)
	var rep_35: int = MerlinEffectEngine.scale_and_cap("ADD_REPUTATION", 10, factor_35)
	if rep_35 != -10:
		push_error("ADD_REPUTATION:10 at score 35 (x-1.0): expected -10, got %d" % rep_35)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 4. test_bonus_cap — score bonus additifs, global cap x2.0
# ═══════════════════════════════════════════════════════════════════════════════

func test_bonus_cap() -> bool:
	# Verify score_bonus_cap constant exists and equals 2.0
	var cap: float = float(MerlinConstants.EFFECT_CAPS.get("score_bonus_cap", 0.0))
	if not is_equal_approx(cap, 2.0):
		push_error("score_bonus_cap should be 2.0, got %f" % cap)
		return false
	# Verify no multiplier factor (absolute value) exceeds the cap
	var max_factor: float = 0.0
	for entry in MerlinConstants.MULTIPLIER_TABLE:
		var f: float = absf(float(entry["factor"]))
		if f > max_factor:
			max_factor = f
	if max_factor > cap:
		push_error("Max multiplier factor %f exceeds score_bonus_cap %f" % [max_factor, cap])
		return false
	# Simulate additive bonuses clamped to cap
	var base_factor: float = 1.5  # reussite_critique
	var ogham_bonus: float = 0.3
	var combined: float = minf(base_factor + ogham_bonus, cap)
	if not is_equal_approx(combined, 1.8):
		push_error("Combined 1.5+0.3 should be 1.8, got %f" % combined)
		return false
	# Verify capping at 2.0
	var over_cap: float = minf(1.5 + 0.8, cap)
	if not is_equal_approx(over_cap, 2.0):
		push_error("Combined 1.5+0.8 should cap at 2.0, got %f" % over_cap)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 5. test_effect_count_cap — max 3 effects per option
# ═══════════════════════════════════════════════════════════════════════════════

func test_effect_count_cap() -> bool:
	var cap: int = int(MerlinConstants.EFFECT_CAPS.get("effects_per_option", 0))
	if cap != 3:
		push_error("effects_per_option cap should be 3, got %d" % cap)
		return false
	# Simulate enforcement: only first 3 of 5 effects kept
	var effects: Array = [
		"HEAL_LIFE:5",
		"ADD_REPUTATION:druides:10",
		"ADD_ANAM:3",
		"DAMAGE_LIFE:2",
		"ADD_BIOME_CURRENCY:4",
	]
	var capped: Array = effects.slice(0, cap)
	if capped.size() != 3:
		push_error("Capped effects should be 3, got %d" % capped.size())
		return false
	if capped.has("DAMAGE_LIFE:2") or capped.has("ADD_BIOME_CURRENCY:4"):
		push_error("4th and 5th effects should be excluded after capping")
		return false
	# Exactly 3 effects should pass through
	var three_effects: Array = ["HEAL_LIFE:5", "ADD_ANAM:3", "DAMAGE_LIFE:2"]
	var capped_three: Array = three_effects.slice(0, cap)
	if capped_three.size() != 3:
		push_error("Exactly 3 effects should not be trimmed, got %d" % capped_three.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 6. test_add_rep_cap — ADD_REPUTATION capped at +-20 per faction per card
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_rep_cap() -> bool:
	var cap_data: Dictionary = MerlinConstants.EFFECT_CAPS.get("ADD_REPUTATION", {})
	var cap_max: int = int(cap_data.get("max", 0))
	var cap_min: int = int(cap_data.get("min", 0))
	if cap_max != 20:
		push_error("ADD_REPUTATION max cap should be 20, got %d" % cap_max)
		return false
	if cap_min != -20:
		push_error("ADD_REPUTATION min cap should be -20, got %d" % cap_min)
		return false
	# Verify cap_effect enforces the bounds
	var capped_over: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", 30)
	if capped_over != 20:
		push_error("cap_effect(ADD_REPUTATION, 30) should be 20, got %d" % capped_over)
		return false
	var capped_under: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", -25)
	if capped_under != -20:
		push_error("cap_effect(ADD_REPUTATION, -25) should be -20, got %d" % capped_under)
		return false
	var capped_normal: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", 15)
	if capped_normal != 15:
		push_error("cap_effect(ADD_REPUTATION, 15) should be 15, got %d" % capped_normal)
		return false
	# Verify via effect engine apply (integration)
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	var state: Dictionary = _make_state()
	engine.apply_effects(state, ["ADD_REPUTATION:druides:15"], "TEST")
	var rep: int = int(state["meta"]["faction_rep"]["druides"])
	if rep != 25:  # 10 start + 15
		push_error("After ADD_REPUTATION:druides:15, expected 25, got %d" % rep)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 7. test_heal_cap — HEAL_LIFE capped at 18
# ═══════════════════════════════════════════════════════════════════════════════

func test_heal_cap() -> bool:
	var cap_max: int = int(MerlinConstants.EFFECT_CAPS.get("HEAL_LIFE", {}).get("max", 0))
	if cap_max != 18:
		push_error("HEAL_LIFE max cap should be 18, got %d" % cap_max)
		return false
	# cap_effect should enforce the limit
	var capped: int = MerlinEffectEngine.cap_effect("HEAL_LIFE", 25)
	if capped != 18:
		push_error("cap_effect(HEAL_LIFE, 25) should be 18, got %d" % capped)
		return false
	# Normal value passes through
	var normal: int = MerlinEffectEngine.cap_effect("HEAL_LIFE", 12)
	if normal != 12:
		push_error("cap_effect(HEAL_LIFE, 12) should be 12, got %d" % normal)
		return false
	# scale_and_cap with critique multiplier: 14 * 1.5 = 21 -> capped to 18
	var scaled: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 14, 1.5)
	if scaled != 18:
		push_error("scale_and_cap(HEAL_LIFE, 14, 1.5) should cap at 18, got %d" % scaled)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 8. test_damage_cap — DAMAGE_LIFE capped at 15 (critical 22)
# ═══════════════════════════════════════════════════════════════════════════════

func test_damage_cap() -> bool:
	var cap_normal: int = int(MerlinConstants.EFFECT_CAPS.get("DAMAGE_LIFE", {}).get("max", 0))
	if cap_normal != 15:
		push_error("DAMAGE_LIFE max cap should be 15, got %d" % cap_normal)
		return false
	var cap_critical: int = int(MerlinConstants.EFFECT_CAPS.get("DAMAGE_CRITICAL", {}).get("max", 0))
	if cap_critical != 22:
		push_error("DAMAGE_CRITICAL max cap should be 22, got %d" % cap_critical)
		return false
	# cap_effect enforces normal damage cap
	var capped: int = MerlinEffectEngine.cap_effect("DAMAGE_LIFE", 20)
	if capped != 15:
		push_error("cap_effect(DAMAGE_LIFE, 20) should be 15, got %d" % capped)
		return false
	var normal: int = MerlinEffectEngine.cap_effect("DAMAGE_LIFE", 10)
	if normal != 10:
		push_error("cap_effect(DAMAGE_LIFE, 10) should be 10, got %d" % normal)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 9. test_zero_score — score 0 produces minimal/no effects (echec_critique -1.5)
# ═══════════════════════════════════════════════════════════════════════════════

func test_zero_score() -> bool:
	# Score 0 is in echec_critique band, factor = -1.5
	var factor: float = MerlinEffectEngine.get_multiplier(0)
	if not is_equal_approx(factor, -1.5):
		push_error("Factor at score 0: expected -1.5, got %f" % factor)
		return false
	# HEAL_LIFE with negative factor: raw 10 * abs(-1.5) = 15, then negated = -15
	# cap_effect(HEAL_LIFE, -15) = mini(-15, 18) = -15
	# In practice, negative heal means no healing occurs (or damage)
	var scaled_heal: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 10, factor)
	if scaled_heal != -15:
		push_error("HEAL_LIFE:10 at score 0 (x-1.5): expected -15, got %d" % scaled_heal)
		return false
	# D20 equivalent at score 0 = 1 (critical fail)
	var d20: int = MiniGameBase.score_to_d20(0)
	if d20 != 1:
		push_error("score_to_d20(0): expected 1, got %d" % d20)
		return false
	# Label should be echec_critique
	var label: String = MerlinEffectEngine.get_multiplier_label(0)
	if label != "echec_critique":
		push_error("Label at score 0: expected 'echec_critique', got '%s'" % label)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 10. test_perfect_score — score 100 produces full effects (reussite_critique 1.5)
# ═══════════════════════════════════════════════════════════════════════════════

func test_perfect_score() -> bool:
	# Score 100 is in reussite_critique band, factor = 1.5
	var factor: float = MerlinEffectEngine.get_multiplier(100)
	if not is_equal_approx(factor, 1.5):
		push_error("Factor at score 100: expected 1.5, got %f" % factor)
		return false
	# HEAL_LIFE: raw 10 * 1.5 = 15 (within cap 18)
	var heal: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 10, factor)
	if heal != 15:
		push_error("HEAL_LIFE:10 at score 100 (x1.5): expected 15, got %d" % heal)
		return false
	# ADD_REPUTATION: raw 15 * 1.5 = 22 -> capped at 20
	var rep: int = MerlinEffectEngine.scale_and_cap("ADD_REPUTATION", 15, factor)
	if rep != 20:
		push_error("ADD_REPUTATION:15 at score 100 (x1.5): expected 20 (capped), got %d" % rep)
		return false
	# DAMAGE_LIFE: raw 10 * 1.5 = 15 (at cap exactly)
	var dmg: int = MerlinEffectEngine.scale_and_cap("DAMAGE_LIFE", 10, factor)
	if dmg != 15:
		push_error("DAMAGE_LIFE:10 at score 100 (x1.5): expected 15, got %d" % dmg)
		return false
	# D20 equivalent at score 100 = 20 (critical success)
	var d20: int = MiniGameBase.score_to_d20(100)
	if d20 != 20:
		push_error("score_to_d20(100): expected 20, got %d" % d20)
		return false
	# Label should be reussite_critique
	var label: String = MerlinEffectEngine.get_multiplier_label(100)
	if label != "reussite_critique":
		push_error("Label at score 100: expected 'reussite_critique', got '%s'" % label)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL — Returns Dictionary {test_name: bool}
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var results: Dictionary = {}
	var tests: Array[Array] = [
		["test_score_range", test_score_range],
		["test_multiplier_table", test_multiplier_table],
		["test_effect_scaling", test_effect_scaling],
		["test_bonus_cap", test_bonus_cap],
		["test_effect_count_cap", test_effect_count_cap],
		["test_add_rep_cap", test_add_rep_cap],
		["test_heal_cap", test_heal_cap],
		["test_damage_cap", test_damage_cap],
		["test_zero_score", test_zero_score],
		["test_perfect_score", test_perfect_score],
	]

	var passed: int = 0
	var failed: int = 0

	for entry in tests:
		var name: String = str(entry[0])
		var callable: Callable = entry[1]
		var ok: bool = callable.call()
		results[name] = ok
		if ok:
			passed += 1
		else:
			failed += 1
			push_error("[FAIL] %s" % name)

	print("[test_minigame_scoring] Results: %d/%d passed" % [passed, passed + failed])
	if failed > 0:
		push_error("[test_minigame_scoring] %d test(s) FAILED" % failed)
	else:
		print("[test_minigame_scoring] All tests passed.")

	return results
