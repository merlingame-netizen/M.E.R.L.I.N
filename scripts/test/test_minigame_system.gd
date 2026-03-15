## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinMiniGameSystem (8 lexical fields, headless mode)
## ═══════════════════════════════════════════════════════════════════════════════
## 20+ tests: all 8 fields produce valid scores, difficulty scaling,
## deterministic headless mode, unknown type fallback, signal emission,
## modifier bonus, success threshold, time_ms range, edge cases.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


func _make_system(seed_val: int = 42) -> MerlinMiniGameSystem:
	var sys: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(seed_val)
	sys.set_rng(rng)
	return sys


# ═══════════════════════════════════════════════════════════════════════════════
# BASIC FIELD VALIDITY — Each field returns score in 0-100
# ═══════════════════════════════════════════════════════════════════════════════

func test_vigueur_returns_valid_score() -> bool:
	var sys: MerlinMiniGameSystem = _make_system()
	var result: Dictionary = sys.run("vigueur", 5)
	return _assert_valid_result(result, "vigueur")


func test_esprit_returns_valid_score() -> bool:
	var sys: MerlinMiniGameSystem = _make_system()
	var result: Dictionary = sys.run("esprit", 5)
	return _assert_valid_result(result, "esprit")


func test_bluff_returns_valid_score() -> bool:
	var sys: MerlinMiniGameSystem = _make_system()
	var result: Dictionary = sys.run("bluff", 5)
	return _assert_valid_result(result, "bluff")


func test_logique_returns_valid_score() -> bool:
	var sys: MerlinMiniGameSystem = _make_system()
	var result: Dictionary = sys.run("logique", 5)
	return _assert_valid_result(result, "logique")


func test_observation_returns_valid_score() -> bool:
	var sys: MerlinMiniGameSystem = _make_system()
	var result: Dictionary = sys.run("observation", 5)
	return _assert_valid_result(result, "observation")


func test_perception_returns_valid_score() -> bool:
	var sys: MerlinMiniGameSystem = _make_system()
	var result: Dictionary = sys.run("perception", 5)
	return _assert_valid_result(result, "perception")


func test_finesse_returns_valid_score() -> bool:
	var sys: MerlinMiniGameSystem = _make_system()
	var result: Dictionary = sys.run("finesse", 5)
	return _assert_valid_result(result, "finesse")


func test_chance_returns_valid_score() -> bool:
	var sys: MerlinMiniGameSystem = _make_system()
	var result: Dictionary = sys.run("chance", 5)
	return _assert_valid_result(result, "chance")


# ═══════════════════════════════════════════════════════════════════════════════
# DIFFICULTY SCALING — Lower difficulty should produce higher average scores
# ═══════════════════════════════════════════════════════════════════════════════

func test_difficulty_scaling_vigueur() -> bool:
	return _assert_difficulty_scaling("vigueur")


func test_difficulty_scaling_logique() -> bool:
	return _assert_difficulty_scaling("logique")


func test_difficulty_scaling_esprit() -> bool:
	return _assert_difficulty_scaling("esprit")


# ═══════════════════════════════════════════════════════════════════════════════
# HEADLESS DETERMINISM — Same seed = same result
# ═══════════════════════════════════════════════════════════════════════════════

func test_deterministic_with_same_seed() -> bool:
	var sys1: MerlinMiniGameSystem = _make_system(123)
	var sys2: MerlinMiniGameSystem = _make_system(123)
	var r1: Dictionary = sys1.run("vigueur", 5)
	var r2: Dictionary = sys2.run("vigueur", 5)
	if r1["score"] != r2["score"]:
		push_error("Determinism failed: seed 123 gave score %d vs %d" % [r1["score"], r2["score"]])
		return false
	return true


func test_different_seeds_differ() -> bool:
	var sys1: MerlinMiniGameSystem = _make_system(100)
	var sys2: MerlinMiniGameSystem = _make_system(999)
	# Run multiple to increase chance of divergence
	var scores1: Array[int] = []
	var scores2: Array[int] = []
	for field in MerlinMiniGameSystem.VALID_FIELDS:
		scores1.append(sys1.run(field, 5)["score"])
		scores2.append(sys2.run(field, 5)["score"])
	if scores1 == scores2:
		push_error("Different seeds produced identical scores across all 8 fields")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# UNKNOWN TYPE FALLBACK
# ═══════════════════════════════════════════════════════════════════════════════

func test_unknown_type_returns_valid_result() -> bool:
	var sys: MerlinMiniGameSystem = _make_system()
	var result: Dictionary = sys.run("UNKNOWN_TYPE", 5)
	if not result.has("score"):
		push_error("Unknown type did not return score")
		return false
	var score: int = int(result["score"])
	if score < 0 or score > 100:
		push_error("Unknown type score out of range: %d" % score)
		return false
	return true


func test_unknown_type_uses_generic_field_name() -> bool:
	var sys: MerlinMiniGameSystem = _make_system()
	var result: Dictionary = sys.run("NONEXISTENT", 5)
	if str(result.get("type", "")) != "nonexistent":
		push_error("Unknown type field should be lowercased input, got: %s" % result.get("type", ""))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SUCCESS THRESHOLD — score >= 80 is success
# ═══════════════════════════════════════════════════════════════════════════════

func test_success_threshold_high_score() -> bool:
	# With difficulty 1 and seed 42, most fields should score high
	var sys: MerlinMiniGameSystem = _make_system(42)
	var result: Dictionary = sys.run("vigueur", 1)
	var score: int = int(result["score"])
	var success: bool = bool(result["success"])
	if score >= 80 and not success:
		push_error("Score %d >= 80 but success is false" % score)
		return false
	if score < 80 and success:
		push_error("Score %d < 80 but success is true" % score)
		return false
	return true


func test_success_threshold_consistency() -> bool:
	# Run 20 rounds, verify success flag matches threshold
	var sys: MerlinMiniGameSystem = _make_system(77)
	for i in range(20):
		var field: String = MerlinMiniGameSystem.VALID_FIELDS[i % 8]
		var result: Dictionary = sys.run(field, i % 10 + 1)
		var score: int = int(result["score"])
		var success: bool = bool(result["success"])
		if (score >= 80) != success:
			push_error("Score %d: success=%s mismatch (field=%s)" % [score, str(success), field])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MODIFIER BONUS
# ═══════════════════════════════════════════════════════════════════════════════

func test_bonus_modifier_increases_score() -> bool:
	var sys1: MerlinMiniGameSystem = _make_system(50)
	var sys2: MerlinMiniGameSystem = _make_system(50)
	var r_base: Dictionary = sys1.run("logique", 5)
	var r_bonus: Dictionary = sys2.run("logique", 5, {"bonus": 0.2})
	var base_score: int = int(r_base["score"])
	var bonus_score: int = int(r_bonus["score"])
	# Bonus of 0.2 adds 20 to the raw score (before clamping)
	if bonus_score < base_score:
		push_error("Bonus modifier did not increase score: base=%d bonus=%d" % [base_score, bonus_score])
		return false
	return true


func test_bonus_modifier_clamped_at_100() -> bool:
	var sys: MerlinMiniGameSystem = _make_system(42)
	var result: Dictionary = sys.run("chance", 1, {"bonus": 5.0})
	var score: int = int(result["score"])
	if score > 100:
		push_error("Score with large bonus exceeded 100: %d" % score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TIME_MS RANGE — 5-15 seconds (bible spec) with small variance
# ═══════════════════════════════════════════════════════════════════════════════

func test_time_ms_within_range() -> bool:
	var sys: MerlinMiniGameSystem = _make_system(42)
	for field in MerlinMiniGameSystem.VALID_FIELDS:
		var result: Dictionary = sys.run(field, 5)
		var time_ms: int = int(result["time_ms"])
		# Allow 4000-18000 (5-15s base with +-2s variance)
		if time_ms < 3000 or time_ms > 18000:
			push_error("time_ms out of range for %s: %d" % [field, time_ms])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DIFFICULTY CLAMPING — Values outside 1-10 are clamped
# ═══════════════════════════════════════════════════════════════════════════════

func test_difficulty_clamped_below_1() -> bool:
	var sys: MerlinMiniGameSystem = _make_system(42)
	var result: Dictionary = sys.run("vigueur", -5)
	return _assert_valid_result(result, "vigueur")


func test_difficulty_clamped_above_10() -> bool:
	var sys: MerlinMiniGameSystem = _make_system(42)
	var result: Dictionary = sys.run("vigueur", 99)
	return _assert_valid_result(result, "vigueur")


# ═══════════════════════════════════════════════════════════════════════════════
# VALID_FIELDS CONSTANT
# ═══════════════════════════════════════════════════════════════════════════════

func test_valid_fields_count() -> bool:
	if MerlinMiniGameSystem.VALID_FIELDS.size() != 8:
		push_error("VALID_FIELDS should have 8 entries, got %d" % MerlinMiniGameSystem.VALID_FIELDS.size())
		return false
	return true


func test_valid_fields_match_constants() -> bool:
	# All fields from MerlinConstants.FIELD_MINIGAMES should be in VALID_FIELDS
	var expected: Array[String] = ["chance", "bluff", "observation", "logique", "finesse", "vigueur", "esprit", "perception"]
	for field in expected:
		if not MerlinMiniGameSystem.VALID_FIELDS.has(field):
			push_error("VALID_FIELDS missing field: %s" % field)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CASE INSENSITIVITY
# ═══════════════════════════════════════════════════════════════════════════════

func test_case_insensitive_field_name() -> bool:
	var sys: MerlinMiniGameSystem = _make_system(42)
	var r1: Dictionary = sys.run("VIGUEUR", 5)
	if str(r1.get("type", "")) != "vigueur":
		push_error("Field name not lowercased: %s" % r1.get("type", ""))
		return false
	return _assert_valid_result(r1, "vigueur")


# ═══════════════════════════════════════════════════════════════════════════════
# RESULT DICTIONARY SHAPE
# ═══════════════════════════════════════════════════════════════════════════════

func test_result_has_all_keys() -> bool:
	var sys: MerlinMiniGameSystem = _make_system()
	var result: Dictionary = sys.run("esprit", 5)
	var required_keys: Array[String] = ["type", "success", "score", "time_ms"]
	for key in required_keys:
		if not result.has(key):
			push_error("Result missing key: %s" % key)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _assert_valid_result(result: Dictionary, expected_type: String) -> bool:
	if not result.has("score"):
		push_error("Result for %s missing 'score'" % expected_type)
		return false
	var score: int = int(result["score"])
	if score < 0 or score > 100:
		push_error("Score for %s out of range: %d" % [expected_type, score])
		return false
	if str(result.get("type", "")) != expected_type:
		push_error("Type mismatch: expected %s, got %s" % [expected_type, result.get("type", "")])
		return false
	if not result.has("success"):
		push_error("Result for %s missing 'success'" % expected_type)
		return false
	if not result.has("time_ms"):
		push_error("Result for %s missing 'time_ms'" % expected_type)
		return false
	return true


func _assert_difficulty_scaling(field: String) -> bool:
	# Run 50 rounds at difficulty 1 and 50 at difficulty 10.
	# Average score at diff 1 should be higher than at diff 10.
	var sum_easy: int = 0
	var sum_hard: int = 0
	for i in range(50):
		var sys_easy: MerlinMiniGameSystem = _make_system(i * 7 + 1)
		var sys_hard: MerlinMiniGameSystem = _make_system(i * 7 + 1)
		sum_easy += int(sys_easy.run(field, 1)["score"])
		sum_hard += int(sys_hard.run(field, 10)["score"])
	var avg_easy: float = float(sum_easy) / 50.0
	var avg_hard: float = float(sum_hard) / 50.0
	if avg_easy <= avg_hard:
		push_error("Difficulty scaling failed for %s: avg_easy=%.1f <= avg_hard=%.1f" % [field, avg_easy, avg_hard])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> void:
	var tests: Array[Callable] = [
		# 8 field validity tests
		test_vigueur_returns_valid_score,
		test_esprit_returns_valid_score,
		test_bluff_returns_valid_score,
		test_logique_returns_valid_score,
		test_observation_returns_valid_score,
		test_perception_returns_valid_score,
		test_finesse_returns_valid_score,
		test_chance_returns_valid_score,
		# Difficulty scaling
		test_difficulty_scaling_vigueur,
		test_difficulty_scaling_logique,
		test_difficulty_scaling_esprit,
		# Headless determinism
		test_deterministic_with_same_seed,
		test_different_seeds_differ,
		# Unknown type fallback
		test_unknown_type_returns_valid_result,
		test_unknown_type_uses_generic_field_name,
		# Success threshold
		test_success_threshold_high_score,
		test_success_threshold_consistency,
		# Modifier bonus
		test_bonus_modifier_increases_score,
		test_bonus_modifier_clamped_at_100,
		# Time range
		test_time_ms_within_range,
		# Difficulty clamping
		test_difficulty_clamped_below_1,
		test_difficulty_clamped_above_10,
		# VALID_FIELDS
		test_valid_fields_count,
		test_valid_fields_match_constants,
		# Case insensitivity
		test_case_insensitive_field_name,
		# Result shape
		test_result_has_all_keys,
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

	print("[test_minigame_system] Results: %d/%d passed" % [passed, passed + failed])
	if failed > 0:
		push_error("[test_minigame_system] %d test(s) FAILED" % failed)
	else:
		print("[test_minigame_system] All tests passed.")
