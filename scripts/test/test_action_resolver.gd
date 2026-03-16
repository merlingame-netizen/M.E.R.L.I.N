## =============================================================================
## Unit Tests — MerlinActionResolver
## =============================================================================
## Tests: resolve(), score calculation, chance/risk thresholds, hidden test
## mapping, verb->attribute mapping, posture/style modifiers, edge cases.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


func _make_context(overrides: Dictionary = {}) -> Dictionary:
	var ctx: Dictionary = {
		"state": {
			"run": {
				"posture": "",
				"momentum": 0,
				"fail_streak": 0,
				"difficulty_mod_next": 0,
			},
		},
		"costs": {},
		"gain": [],
	}
	for key in overrides:
		ctx[key] = overrides[key]
	return ctx


func _make_context_with_run(run_overrides: Dictionary) -> Dictionary:
	var ctx: Dictionary = _make_context()
	var run: Dictionary = ctx["state"]["run"]
	for key in run_overrides:
		run[key] = run_overrides[key]
	return ctx


# =============================================================================
# RESOLVE — basic structure
# =============================================================================

func test_resolve_returns_all_keys() -> bool:
	var resolver := MerlinActionResolver.new()
	var result: Dictionary = resolver.resolve("FORCE", "sub_a", _make_context())
	var expected_keys: Array = ["verb", "subchoice", "score", "chance", "risk", "hidden_test", "costs", "gain"]
	for key in expected_keys:
		if not result.has(key):
			push_error("resolve: missing key '%s'" % key)
			return false
	if str(result["verb"]) != "FORCE":
		push_error("resolve: verb should be 'FORCE', got '%s'" % result["verb"])
		return false
	if str(result["subchoice"]) != "sub_a":
		push_error("resolve: subchoice should be 'sub_a', got '%s'" % result["subchoice"])
		return false
	return true


func test_resolve_passes_costs_and_gain() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context({"costs": {"anam": 3}, "gain": ["HEAL_LIFE:5"]})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	if not result["costs"].has("anam"):
		push_error("resolve: costs should contain 'anam'")
		return false
	if result["gain"].size() != 1:
		push_error("resolve: gain should have 1 entry, got %d" % result["gain"].size())
		return false
	return true


# =============================================================================
# SCORE CALCULATION — base attribute
# =============================================================================

func test_base_score_is_10() -> bool:
	var resolver := MerlinActionResolver.new()
	var result: Dictionary = resolver.resolve("FORCE", "x", _make_context())
	if int(result["score"]) != 10:
		push_error("Base score should be 10, got %d" % int(result["score"]))
		return false
	return true


# =============================================================================
# POSTURE MODIFIERS
# =============================================================================

func test_posture_agressif_force() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context_with_run({"posture": "Agressif"})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	# Base 10 + Agressif FORCE +3 = 13
	if int(result["score"]) != 13:
		push_error("Agressif+FORCE: expected 13, got %d" % int(result["score"]))
		return false
	return true


func test_posture_prudence_logique() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context_with_run({"posture": "Prudence"})
	var result: Dictionary = resolver.resolve("LOGIQUE", "x", ctx)
	# Base 10 + Prudence LOGIQUE +2 = 12
	if int(result["score"]) != 12:
		push_error("Prudence+LOGIQUE: expected 12, got %d" % int(result["score"]))
		return false
	return true


func test_posture_ruse_finesse() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context_with_run({"posture": "Ruse"})
	var result: Dictionary = resolver.resolve("FINESSE", "x", ctx)
	# Base 10 + Ruse FINESSE +3 = 13
	if int(result["score"]) != 13:
		push_error("Ruse+FINESSE: expected 13, got %d" % int(result["score"]))
		return false
	return true


func test_posture_serenite_all_plus_one() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context_with_run({"posture": "Serenite"})
	var result_f: Dictionary = resolver.resolve("FORCE", "x", ctx)
	var result_l: Dictionary = resolver.resolve("LOGIQUE", "x", ctx)
	var result_fi: Dictionary = resolver.resolve("FINESSE", "x", ctx)
	# Base 10 + Serenite +1 each = 11
	if int(result_f["score"]) != 11 or int(result_l["score"]) != 11 or int(result_fi["score"]) != 11:
		push_error("Serenite: all verbs should score 11, got F=%d L=%d FI=%d" % [
			int(result_f["score"]), int(result_l["score"]), int(result_fi["score"])])
		return false
	return true


# =============================================================================
# STYLE MODIFIERS
# =============================================================================

func test_style_protecteur_logique() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context({"merlin_style": "protecteur"})
	var result: Dictionary = resolver.resolve("LOGIQUE", "x", ctx)
	# Base 10 + PROTECTEUR LOGIQUE +3 = 13
	if int(result["score"]) != 13:
		push_error("PROTECTEUR+LOGIQUE: expected 13, got %d" % int(result["score"]))
		return false
	return true


func test_style_aventureux_force() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context({"merlin_style": "aventureux"})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	# Base 10 + AVENTUREUX FORCE +2 = 12
	if int(result["score"]) != 12:
		push_error("AVENTUREUX+FORCE: expected 12, got %d" % int(result["score"]))
		return false
	return true


# =============================================================================
# MOMENTUM
# =============================================================================

func test_momentum_adds_to_score() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context_with_run({"momentum": 60})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	# Base 10 + momentum 60/20 = 3 → 13
	if int(result["score"]) != 13:
		push_error("Momentum 60: expected 13, got %d" % int(result["score"]))
		return false
	return true


# =============================================================================
# FAIL STREAK
# =============================================================================

func test_fail_streak_adds_to_score() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context_with_run({"fail_streak": 3})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	# Base 10 + fail_streak 3*5 = 15 → 25
	if int(result["score"]) != 25:
		push_error("Fail streak 3: expected 25, got %d" % int(result["score"]))
		return false
	return true


# =============================================================================
# BONUS / PENALTY
# =============================================================================

func test_bonus_penalty_applied() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context({"bonus": 10, "penalty": 3})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	# Base 10 + bonus 10 - penalty 3 = 17
	if int(result["score"]) != 17:
		push_error("Bonus/penalty: expected 17, got %d" % int(result["score"]))
		return false
	return true


# =============================================================================
# SCORE CLAMPING
# =============================================================================

func test_score_clamped_at_zero() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context({"penalty": 50})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	# Base 10 - 50 = -40, clamped to 0
	if int(result["score"]) != 0:
		push_error("Score clamp min: expected 0, got %d" % int(result["score"]))
		return false
	return true


func test_score_clamped_at_100() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context({"bonus": 200})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	# Base 10 + 200 = 210, clamped to 100
	if int(result["score"]) != 100:
		push_error("Score clamp max: expected 100, got %d" % int(result["score"]))
		return false
	return true


# =============================================================================
# CHANCE THRESHOLDS
# =============================================================================

func test_chance_low() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context()  # score = 10
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	if str(result["chance"]) != "Low":
		push_error("Chance at score 10: expected 'Low', got '%s'" % result["chance"])
		return false
	return true


func test_chance_medium() -> bool:
	var resolver := MerlinActionResolver.new()
	# Need score in 35-64 range. Base 10 + bonus 30 = 40
	var ctx: Dictionary = _make_context({"bonus": 30})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	if str(result["chance"]) != "Medium":
		push_error("Chance at score 40: expected 'Medium', got '%s'" % result["chance"])
		return false
	return true


func test_chance_high() -> bool:
	var resolver := MerlinActionResolver.new()
	# Need score >= 65. Base 10 + bonus 60 = 70
	var ctx: Dictionary = _make_context({"bonus": 60})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	if str(result["chance"]) != "High":
		push_error("Chance at score 70: expected 'High', got '%s'" % result["chance"])
		return false
	return true


# =============================================================================
# RISK THRESHOLDS
# =============================================================================

func test_risk_severe() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context()  # score = 10
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	if str(result["risk"]) != "Severe":
		push_error("Risk at score 10: expected 'Severe', got '%s'" % result["risk"])
		return false
	return true


func test_risk_moderate() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context({"bonus": 30})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	if str(result["risk"]) != "Moderate":
		push_error("Risk at score 40: expected 'Moderate', got '%s'" % result["risk"])
		return false
	return true


func test_risk_light() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context({"bonus": 60})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	if str(result["risk"]) != "Light":
		push_error("Risk at score 70: expected 'Light', got '%s'" % result["risk"])
		return false
	return true


# =============================================================================
# HIDDEN TEST TYPE MAPPING
# =============================================================================

func test_hidden_test_force_timing() -> bool:
	var resolver := MerlinActionResolver.new()
	var result: Dictionary = resolver.resolve("FORCE", "x", _make_context())
	if str(result["hidden_test"]["type"]) != "TIMING":
		push_error("FORCE hidden test: expected TIMING, got '%s'" % result["hidden_test"]["type"])
		return false
	return true


func test_hidden_test_logique_memory() -> bool:
	var resolver := MerlinActionResolver.new()
	var result: Dictionary = resolver.resolve("LOGIQUE", "x", _make_context())
	if str(result["hidden_test"]["type"]) != "MEMORY":
		push_error("LOGIQUE hidden test: expected MEMORY, got '%s'" % result["hidden_test"]["type"])
		return false
	return true


func test_hidden_test_finesse_aim() -> bool:
	var resolver := MerlinActionResolver.new()
	var result: Dictionary = resolver.resolve("FINESSE", "x", _make_context())
	if str(result["hidden_test"]["type"]) != "AIM":
		push_error("FINESSE hidden test: expected AIM, got '%s'" % result["hidden_test"]["type"])
		return false
	return true


func test_hidden_test_default_dice() -> bool:
	var resolver := MerlinActionResolver.new()
	var result: Dictionary = resolver.resolve("UNKNOWN_VERB", "x", _make_context())
	if str(result["hidden_test"]["type"]) != "DICE":
		push_error("Default hidden test: expected DICE, got '%s'" % result["hidden_test"]["type"])
		return false
	return true


# =============================================================================
# HIDDEN TEST DIFFICULTY
# =============================================================================

func test_hidden_test_difficulty_at_base_score() -> bool:
	var resolver := MerlinActionResolver.new()
	var result: Dictionary = resolver.resolve("FORCE", "x", _make_context())
	# score=10, difficulty = clamp(10 - 10/10, 1, 10) = clamp(9, 1, 10) = 9
	if int(result["hidden_test"]["difficulty"]) != 9:
		push_error("Difficulty at score 10: expected 9, got %d" % int(result["hidden_test"]["difficulty"]))
		return false
	return true


func test_hidden_test_difficulty_high_score() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context({"bonus": 90})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	# score=100, difficulty = clamp(10 - 100/10, 1, 10) = clamp(0, 1, 10) = 1
	if int(result["hidden_test"]["difficulty"]) != 1:
		push_error("Difficulty at score 100: expected 1, got %d" % int(result["hidden_test"]["difficulty"]))
		return false
	return true


func test_hidden_test_difficulty_mod_next() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context_with_run({"difficulty_mod_next": 3})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	# score=10, base_diff = 9, after mod: clamp(9 - 3, 1, 10) = 6
	if int(result["hidden_test"]["difficulty"]) != 6:
		push_error("Difficulty with mod_next 3: expected 6, got %d" % int(result["hidden_test"]["difficulty"]))
		return false
	return true


# =============================================================================
# CONTEXT-PROVIDED HIDDEN TEST PASSTHROUGH
# =============================================================================

func test_context_hidden_test_passthrough() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context({"hidden_test": {"type": "CUSTOM_TEST", "modifiers": {"speed": 2}}})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	if str(result["hidden_test"]["type"]) != "CUSTOM_TEST":
		push_error("Context hidden_test passthrough: expected CUSTOM_TEST, got '%s'" % result["hidden_test"]["type"])
		return false
	if not result["hidden_test"]["modifiers"].has("speed"):
		push_error("Context hidden_test modifiers should contain 'speed'")
		return false
	return true


# =============================================================================
# VERB -> ATTRIBUTE MAPPING
# =============================================================================

func test_verb_force_maps_to_power() -> bool:
	# Indirectly tested: FORCE uses "power" attribute. Since base is always 10,
	# we verify the resolver does not crash and returns a valid score.
	var resolver := MerlinActionResolver.new()
	var result: Dictionary = resolver.resolve("FORCE", "x", _make_context())
	if int(result["score"]) != 10:
		push_error("FORCE base score: expected 10, got %d" % int(result["score"]))
		return false
	return true


func test_verb_unknown_defaults_to_power() -> bool:
	var resolver := MerlinActionResolver.new()
	var result: Dictionary = resolver.resolve("BIZARRE", "x", _make_context())
	# Unknown verb maps to "power", base attribute still 10
	if int(result["score"]) != 10:
		push_error("Unknown verb base score: expected 10, got %d" % int(result["score"]))
		return false
	return true


# =============================================================================
# EDGE CASES
# =============================================================================

func test_empty_context() -> bool:
	var resolver := MerlinActionResolver.new()
	var result: Dictionary = resolver.resolve("FORCE", "x", {})
	if int(result["score"]) != 10:
		push_error("Empty context: expected base score 10, got %d" % int(result["score"]))
		return false
	if str(result["chance"]) != "Low":
		push_error("Empty context: expected Low chance")
		return false
	return true


func test_unknown_posture_ignored() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context_with_run({"posture": "Fantaisie"})
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	# Unknown posture adds 0, base stays 10
	if int(result["score"]) != 10:
		push_error("Unknown posture: expected 10, got %d" % int(result["score"]))
		return false
	return true


func test_combined_modifiers() -> bool:
	var resolver := MerlinActionResolver.new()
	var ctx: Dictionary = _make_context({
		"merlin_style": "aventureux",
		"bonus": 5,
		"penalty": 2,
	})
	ctx["state"]["run"]["posture"] = "Agressif"
	ctx["state"]["run"]["momentum"] = 40
	ctx["state"]["run"]["fail_streak"] = 1
	var result: Dictionary = resolver.resolve("FORCE", "x", ctx)
	# Base 10 + Agressif FORCE +3 + momentum 40/20=2 + AVENTUREUX FORCE +2
	# + fail_streak 1*5=5 + bonus 5 - penalty 2 = 10+3+2+2+5+5-2 = 25
	if int(result["score"]) != 25:
		push_error("Combined modifiers: expected 25, got %d" % int(result["score"]))
		return false
	return true
