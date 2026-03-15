## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — Minigame Scoring System v2.4
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: MULTIPLIER_TABLE score bands, score_bonus_cap (x2.0), effects_per_option
## cap (3 max), scale_and_cap, score_to_d20, ogham bonus, edge cases.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# MULTIPLIER TABLE — Five score bands (bible v2.4 s.6.5)
# 0-20 = echec_critique (-1.5), 21-50 = echec (-1.0),
# 51-79 = reussite_partielle (0.5), 80-94 = reussite (1.0),
# 95-100 = reussite_critique (1.5)
# ═══════════════════════════════════════════════════════════════════════════════

func test_multiplier_table_echec_critique_lower_bound() -> bool:
	var factor: float = MerlinEffectEngine.get_multiplier(0)
	if not is_equal_approx(factor, -1.5):
		push_error("Multiplier at 0: expected -1.5, got %f" % factor)
		return false
	return true


func test_multiplier_table_echec_critique_upper_bound() -> bool:
	var factor: float = MerlinEffectEngine.get_multiplier(20)
	if not is_equal_approx(factor, -1.5):
		push_error("Multiplier at 20: expected -1.5, got %f" % factor)
		return false
	return true


func test_multiplier_table_echec_band() -> bool:
	# Score 21-50 = echec (-1.0)
	var at_21: float = MerlinEffectEngine.get_multiplier(21)
	var at_50: float = MerlinEffectEngine.get_multiplier(50)
	if not is_equal_approx(at_21, -1.0):
		push_error("Multiplier at 21: expected -1.0, got %f" % at_21)
		return false
	if not is_equal_approx(at_50, -1.0):
		push_error("Multiplier at 50: expected -1.0, got %f" % at_50)
		return false
	return true


func test_multiplier_table_reussite_partielle_band() -> bool:
	# Score 51-79 = reussite_partielle (0.5)
	var at_51: float = MerlinEffectEngine.get_multiplier(51)
	var at_79: float = MerlinEffectEngine.get_multiplier(79)
	if not is_equal_approx(at_51, 0.5):
		push_error("Multiplier at 51: expected 0.5, got %f" % at_51)
		return false
	if not is_equal_approx(at_79, 0.5):
		push_error("Multiplier at 79: expected 0.5, got %f" % at_79)
		return false
	return true


func test_multiplier_table_reussite_band() -> bool:
	# Score 80-94 = reussite (1.0)
	var at_80: float = MerlinEffectEngine.get_multiplier(80)
	var at_94: float = MerlinEffectEngine.get_multiplier(94)
	if not is_equal_approx(at_80, 1.0):
		push_error("Multiplier at 80: expected 1.0, got %f" % at_80)
		return false
	if not is_equal_approx(at_94, 1.0):
		push_error("Multiplier at 94: expected 1.0, got %f" % at_94)
		return false
	return true


func test_multiplier_table_reussite_critique_band() -> bool:
	# Score 95-100 = reussite_critique (1.5)
	var at_95: float = MerlinEffectEngine.get_multiplier(95)
	var at_100: float = MerlinEffectEngine.get_multiplier(100)
	if not is_equal_approx(at_95, 1.5):
		push_error("Multiplier at 95: expected 1.5, got %f" % at_95)
		return false
	if not is_equal_approx(at_100, 1.5):
		push_error("Multiplier at 100: expected 1.5, got %f" % at_100)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MULTIPLIER LABEL — get_multiplier_label
# ═══════════════════════════════════════════════════════════════════════════════

func test_multiplier_label_bands() -> bool:
	var pairs: Array = [
		[10, "echec_critique"],
		[35, "echec"],
		[65, "reussite_partielle"],
		[85, "reussite"],
		[97, "reussite_critique"],
	]
	for pair in pairs:
		var label: String = MerlinEffectEngine.get_multiplier_label(int(pair[0]))
		if label != str(pair[1]):
			push_error("Label at score %d: expected '%s', got '%s'" % [pair[0], pair[1], label])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# OUT-OF-RANGE EDGE CASES
# ═══════════════════════════════════════════════════════════════════════════════

func test_multiplier_out_of_range_defaults_1() -> bool:
	# Scores outside 0-100 are not in any band → default 1.0
	var factor: float = MerlinEffectEngine.get_multiplier(200)
	if not is_equal_approx(factor, 1.0):
		push_error("Out-of-range score 200: expected default 1.0, got %f" % factor)
		return false
	return true


func test_multiplier_negative_score_edge_case() -> bool:
	# Negative scores are not in any range; should fall through to default 1.0
	var factor: float = MerlinEffectEngine.get_multiplier(-5)
	if not is_equal_approx(factor, 1.0):
		push_error("Negative score -5: expected default 1.0, got %f" % factor)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SCALE_AND_CAP — Multiplier applied to raw amount, then capped
# ═══════════════════════════════════════════════════════════════════════════════

func test_scale_and_cap_heal_life_reussite() -> bool:
	# score=85 → factor 1.0; raw 10 → scaled 10; cap 18 → result 10
	var result: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 10, 1.0)
	if result != 10:
		push_error("scale_and_cap HEAL_LIFE x1.0: expected 10, got %d" % result)
		return false
	return true


func test_scale_and_cap_heal_life_critique() -> bool:
	# factor 1.5; raw 14 → scaled 21; cap 18 → result 18
	var result: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 14, 1.5)
	if result != 18:
		push_error("scale_and_cap HEAL_LIFE x1.5: expected 18 (cap), got %d" % result)
		return false
	return true


func test_scale_and_cap_damage_echec_critique() -> bool:
	# factor -1.5; raw 8 → scaled -12; cap_effect with negative preserves sign
	# cap_effect("DAMAGE_LIFE", -12) → mini(-12, 15) = -12 (negative, so stays)
	var result: int = MerlinEffectEngine.scale_and_cap("DAMAGE_LIFE", 8, -1.5)
	# abs(8)*1.5 = 12, sign is negative → -12; cap_effect("DAMAGE_LIFE", -12) = mini(-12,15) = -12
	if result != -12:
		push_error("scale_and_cap DAMAGE_LIFE x-1.5: expected -12, got %d" % result)
		return false
	return true


func test_scale_and_cap_reputation_over_cap() -> bool:
	# raw 15 * 1.5 = 22.5 → int = 22; cap ADD_REPUTATION max 20 → result 20
	var result: int = MerlinEffectEngine.scale_and_cap("ADD_REPUTATION", 15, 1.5)
	if result != 20:
		push_error("scale_and_cap ADD_REPUTATION x1.5 over cap: expected 20, got %d" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SCORE_BONUS_CAP — x2.0 global cap (bible v2.4 s.6.5 EFFECT_CAPS)
# ═══════════════════════════════════════════════════════════════════════════════

func test_score_bonus_cap_value() -> bool:
	var cap: float = float(MerlinConstants.EFFECT_CAPS.get("score_bonus_cap", 0.0))
	if not is_equal_approx(cap, 2.0):
		push_error("score_bonus_cap should be 2.0, got %f" % cap)
		return false
	return true


func test_multiplier_does_not_exceed_score_bonus_cap() -> bool:
	# The maximum factor in any band is 1.5 (reussite_critique)
	# Per bible: score_bonus_cap = 2.0. The table max (1.5) must be <= 2.0.
	var score_bonus_cap: float = float(MerlinConstants.EFFECT_CAPS.get("score_bonus_cap", 0.0))
	var max_factor: float = 0.0
	for entry in MerlinConstants.MULTIPLIER_TABLE:
		var f: float = absf(float(entry["factor"]))
		if f > max_factor:
			max_factor = f
	if max_factor > score_bonus_cap:
		push_error("Max multiplier factor %f exceeds score_bonus_cap %f" % [max_factor, score_bonus_cap])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECTS_PER_OPTION CAP — max 3 effects per option (bible v2.4)
# ═══════════════════════════════════════════════════════════════════════════════

func test_effects_per_option_cap_value() -> bool:
	var cap: int = int(MerlinConstants.EFFECT_CAPS.get("effects_per_option", 0))
	if cap != 3:
		push_error("effects_per_option cap should be 3, got %d" % cap)
		return false
	return true


func test_effects_per_option_enforcement() -> bool:
	# Simulate enforcing cap: taking only first 3 of a 5-effect list
	var effects: Array = [
		"HEAL_LIFE:5",
		"ADD_REPUTATION:druides:10",
		"ADD_ANAM:3",
		"DAMAGE_LIFE:2",
		"ADD_BIOME_CURRENCY:4",
	]
	var cap: int = int(MerlinConstants.EFFECT_CAPS.get("effects_per_option", 3))
	var capped_effects: Array = effects.slice(0, cap)
	if capped_effects.size() != 3:
		push_error("effects_per_option enforcement: expected 3, got %d" % capped_effects.size())
		return false
	# Verify the excess effects are not included
	if capped_effects.has("DAMAGE_LIFE:2") or capped_effects.has("ADD_BIOME_CURRENCY:4"):
		push_error("effects_per_option: 4th and 5th effects should be excluded")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SCORE_TO_D20 — MiniGameBase conversion (used for narrative flavor)
# ═══════════════════════════════════════════════════════════════════════════════

func test_score_to_d20_perfect_score() -> bool:
	var d20: int = MiniGameBase.score_to_d20(100)
	if d20 != 20:
		push_error("score_to_d20(100): expected 20, got %d" % d20)
		return false
	return true


func test_score_to_d20_zero_score() -> bool:
	var d20: int = MiniGameBase.score_to_d20(0)
	if d20 != 1:
		push_error("score_to_d20(0): expected 1, got %d" % d20)
		return false
	return true


func test_score_to_d20_critical_fail_boundary() -> bool:
	# score <= 10 → d20 = 1
	var d20: int = MiniGameBase.score_to_d20(10)
	if d20 != 1:
		push_error("score_to_d20(10): expected 1, got %d" % d20)
		return false
	return true


func test_score_to_d20_high_score_range() -> bool:
	# score 96-100 → d20 = 20; 51-75 → d20 in 11-15
	var d20_perfect: int = MiniGameBase.score_to_d20(100)
	if d20_perfect != 20:
		push_error("score_to_d20(100): expected 20, got %d" % d20_perfect)
		return false
	var d20_mid: int = MiniGameBase.score_to_d20(60)
	if d20_mid < 11 or d20_mid > 15:
		push_error("score_to_d20(60): expected 11-15, got %d" % d20_mid)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM BONUS — get_ogham_bonus field matching
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_bonus_matching_field() -> bool:
	# "reveal" category → bonus field "observation"; game field "observation" → +10
	var bonus: int = MiniGameRegistry.get_ogham_bonus("reveal", "observation")
	if bonus != 10:
		push_error("Ogham bonus matching field: expected 10, got %d" % bonus)
		return false
	return true


func test_ogham_bonus_non_matching_field() -> bool:
	# "reveal" category → bonus field "observation"; game field "finesse" → 0
	var bonus: int = MiniGameRegistry.get_ogham_bonus("reveal", "finesse")
	if bonus != 0:
		push_error("Ogham bonus non-matching field: expected 0, got %d" % bonus)
		return false
	return true


func test_ogham_bonus_special_universal() -> bool:
	# "special" category → +5 for any field
	var bonus: int = MiniGameRegistry.get_ogham_bonus("special", "vigueur")
	if bonus != 5:
		push_error("Ogham bonus special universal: expected 5, got %d" % bonus)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FAVEURS THRESHOLDS — Faveurs rewards (MerlinConstants)
# ═══════════════════════════════════════════════════════════════════════════════

func test_faveurs_win_threshold() -> bool:
	# Win = score >= 80 (ANAM_REWARDS.minigame_threshold)
	var threshold: int = int(MerlinConstants.ANAM_REWARDS.get("minigame_threshold", 0))
	if threshold != 80:
		push_error("Minigame win threshold: expected 80, got %d" % threshold)
		return false
	return true


func test_faveurs_per_win_value() -> bool:
	var per_win: int = MerlinConstants.FAVEURS_PER_MINIGAME_WIN
	if per_win != 3:
		push_error("FAVEURS_PER_MINIGAME_WIN: expected 3, got %d" % per_win)
		return false
	return true


func test_faveurs_per_play_value() -> bool:
	var per_play: int = MerlinConstants.FAVEURS_PER_MINIGAME_PLAY
	if per_play != 1:
		push_error("FAVEURS_PER_MINIGAME_PLAY: expected 1, got %d" % per_play)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MULTIPLIER APPLIES CORRECTLY TO EFFECT — Integration smoke test
# ═══════════════════════════════════════════════════════════════════════════════

func test_multiplier_applies_to_heal_effect_via_engine() -> bool:
	# Simulate: score 85 → factor 1.0; HEAL_LIFE:8 → heals 8
	var factor: float = MerlinEffectEngine.get_multiplier(85)
	var scaled: int = MerlinEffectEngine.scale_and_cap("HEAL_LIFE", 8, factor)
	if scaled != 8:
		push_error("HEAL_LIFE:8 x1.0 should give 8, got %d" % scaled)
		return false
	return true


func test_multiplier_applies_to_reputation_effect_echec() -> bool:
	# score 35 → factor -1.0; ADD_REPUTATION:druides:10 → -10 reputation
	var factor: float = MerlinEffectEngine.get_multiplier(35)
	if not is_equal_approx(factor, -1.0):
		push_error("Factor at 35: expected -1.0, got %f" % factor)
		return false
	var scaled: int = MerlinEffectEngine.scale_and_cap("ADD_REPUTATION", 10, factor)
	if scaled != -10:
		push_error("ADD_REPUTATION:10 x-1.0 should give -10, got %d" % scaled)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> void:
	var tests: Array[Callable] = [
		test_multiplier_table_echec_critique_lower_bound,
		test_multiplier_table_echec_critique_upper_bound,
		test_multiplier_table_echec_band,
		test_multiplier_table_reussite_partielle_band,
		test_multiplier_table_reussite_band,
		test_multiplier_table_reussite_critique_band,
		test_multiplier_label_bands,
		test_multiplier_out_of_range_defaults_1,
		test_multiplier_negative_score_edge_case,
		test_scale_and_cap_heal_life_reussite,
		test_scale_and_cap_heal_life_critique,
		test_scale_and_cap_damage_echec_critique,
		test_scale_and_cap_reputation_over_cap,
		test_score_bonus_cap_value,
		test_multiplier_does_not_exceed_score_bonus_cap,
		test_effects_per_option_cap_value,
		test_effects_per_option_enforcement,
		test_score_to_d20_perfect_score,
		test_score_to_d20_zero_score,
		test_score_to_d20_critical_fail_boundary,
		test_score_to_d20_high_score_range,
		test_ogham_bonus_matching_field,
		test_ogham_bonus_non_matching_field,
		test_ogham_bonus_special_universal,
		test_faveurs_win_threshold,
		test_faveurs_per_win_value,
		test_faveurs_per_play_value,
		test_multiplier_applies_to_heal_effect_via_engine,
		test_multiplier_applies_to_reputation_effect_echec,
	]

	var passed: int = 0
	var failed: int = 0

	for test in tests:
		var ok: bool = test.call()
		if ok:
			passed += 1
		else:
			failed += 1
			push_error("[FAIL] %s" % test.get_method())

	print("[test_minigame_scoring] Results: %d/%d passed" % [passed, passed + failed])
	if failed > 0:
		push_error("[test_minigame_scoring] %d test(s) FAILED" % failed)
	else:
		print("[test_minigame_scoring] All tests passed.")
