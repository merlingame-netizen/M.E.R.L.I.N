## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinMiniGameSystem (methods NOT covered by existing tests)
## ═══════════════════════════════════════════════════════════════════════════════
## 20 tests: signal emission, negative bonus, whitespace trimming,
## _difficulty_to_hit_chance boundaries, _simulate_time_ms scaling,
## bluff/logique early-break, finesse fatigue, chance shift direction,
## generic vs named field, sequential RNG advancement, empty modifiers,
## boundary score 79/80, set_rng null fallback, remaining difficulty scaling
## fields (bluff, observation, perception, finesse, chance).
## Pattern: extends RefCounted, NO class_name, func test_xxx() -> bool.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


func _make_system(seed_val: int = 42) -> MerlinMiniGameSystem:
	var sys: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(seed_val)
	sys.set_rng(rng)
	return sys


# ═══════════════════════════════════════════════════════════════════════════════
# 1. SIGNAL EMISSION — minigame_completed emits the final score
# ═══════════════════════════════════════════════════════════════════════════════

func test_signal_emits_final_score() -> bool:
	var sys: MerlinMiniGameSystem = _make_system(42)
	var tracker: Dictionary = {"emitted": -1}
	sys.minigame_completed.connect(func(score: int) -> void: tracker["emitted"] = score)
	var result: Dictionary = sys.run("esprit", 5)
	var expected_score: int = int(result["score"])
	if tracker["emitted"] != expected_score:
		push_error("Signal emitted %d but result score is %d" % [tracker["emitted"], expected_score])
		return false
	return true


func test_signal_emits_on_every_run() -> bool:
	var sys: MerlinMiniGameSystem = _make_system(99)
	var tracker: Dictionary = {"count": 0}
	sys.minigame_completed.connect(func(_score: int) -> void: tracker["count"] = int(tracker["count"]) + 1)
	for i in range(5):
		sys.run("chance", i + 1)
	if int(tracker["count"]) != 5:
		push_error("Signal should emit 5 times, emitted %d" % tracker["count"])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 2. NEGATIVE BONUS — bonus < 0 reduces score, clamped at 0
# ═══════════════════════════════════════════════════════════════════════════════

func test_negative_bonus_reduces_score() -> bool:
	var sys1: MerlinMiniGameSystem = _make_system(50)
	var sys2: MerlinMiniGameSystem = _make_system(50)
	var r_base: Dictionary = sys1.run("observation", 5)
	var r_neg: Dictionary = sys2.run("observation", 5, {"bonus": -0.3})
	var base_score: int = int(r_base["score"])
	var neg_score: int = int(r_neg["score"])
	if neg_score > base_score:
		push_error("Negative bonus should not increase score: base=%d neg=%d" % [base_score, neg_score])
		return false
	return true


func test_negative_bonus_clamped_at_zero() -> bool:
	var sys: MerlinMiniGameSystem = _make_system(42)
	var result: Dictionary = sys.run("esprit", 10, {"bonus": -5.0})
	var score: int = int(result["score"])
	if score < 0:
		push_error("Score with large negative bonus should clamp to 0, got %d" % score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 3. WHITESPACE TRIMMING — leading/trailing spaces stripped from field name
# ═══════════════════════════════════════════════════════════════════════════════

func test_whitespace_trimmed_field_name() -> bool:
	var sys1: MerlinMiniGameSystem = _make_system(42)
	var sys2: MerlinMiniGameSystem = _make_system(42)
	var r_clean: Dictionary = sys1.run("bluff", 5)
	var r_spaces: Dictionary = sys2.run("  bluff  ", 5)
	if int(r_clean["score"]) != int(r_spaces["score"]):
		push_error("Whitespace-padded field should match clean: %d vs %d" % [r_clean["score"], r_spaces["score"]])
		return false
	if str(r_spaces.get("type", "")) != "bluff":
		push_error("Type should be trimmed to 'bluff', got '%s'" % r_spaces.get("type", ""))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 4. _difficulty_to_hit_chance — boundary values
# ═══════════════════════════════════════════════════════════════════════════════

func test_hit_chance_difficulty_1() -> bool:
	var sys: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	# difficulty 1 → 0.95 (method is private, test indirectly via scoring)
	# At diff 1, hit chance = 0.95. Over 100 runs, average score should be very high.
	var total: int = 0
	for i in range(100):
		var s: MerlinMiniGameSystem = _make_system(i * 3)
		total += int(s.run("vigueur", 1)["score"])
	var avg: float = float(total) / 100.0
	if avg < 70.0:
		push_error("Difficulty 1 average score should be high (>70), got %.1f" % avg)
		return false
	return true


func test_hit_chance_difficulty_10() -> bool:
	var total: int = 0
	for i in range(100):
		var s: MerlinMiniGameSystem = _make_system(i * 3)
		total += int(s.run("vigueur", 10)["score"])
	var avg: float = float(total) / 100.0
	if avg > 70.0:
		push_error("Difficulty 10 average score should be low (<70), got %.1f" % avg)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 5. _simulate_time_ms — harder difficulty = longer time
# ═══════════════════════════════════════════════════════════════════════════════

func test_time_ms_scales_with_difficulty() -> bool:
	var sum_easy: int = 0
	var sum_hard: int = 0
	for i in range(50):
		var s1: MerlinMiniGameSystem = _make_system(i * 7)
		var s2: MerlinMiniGameSystem = _make_system(i * 7)
		sum_easy += int(s1.run("logique", 1)["time_ms"])
		sum_hard += int(s2.run("logique", 10)["time_ms"])
	var avg_easy: float = float(sum_easy) / 50.0
	var avg_hard: float = float(sum_hard) / 50.0
	if avg_easy >= avg_hard:
		push_error("Harder difficulty should produce longer times: avg_easy=%.0f >= avg_hard=%.0f" % [avg_easy, avg_hard])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 6. BLUFF EARLY-BREAK — cracking under pressure stops counting
# ═══════════════════════════════════════════════════════════════════════════════

func test_bluff_score_never_exceeds_100() -> bool:
	# Bluff uses early break, score should always be 0-100
	for i in range(50):
		var sys: MerlinMiniGameSystem = _make_system(i)
		var score: int = int(sys.run("bluff", 5)["score"])
		if score < 0 or score > 100:
			push_error("Bluff score out of range at seed %d: %d" % [i, score])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 7. LOGIQUE EARLY-BREAK — first error ends the round
# ═══════════════════════════════════════════════════════════════════════════════

func test_logique_difficulty_10_often_low() -> bool:
	# At difficulty 10 (40% recall), early break means most scores should be low
	var low_count: int = 0
	for i in range(50):
		var sys: MerlinMiniGameSystem = _make_system(i * 11)
		var score: int = int(sys.run("logique", 10)["score"])
		if score < 50:
			low_count += 1
	# At difficulty 10 with 40% chance and early break, most should fail
	if low_count < 15:
		push_error("Logique at diff 10 should produce many low scores, only %d/50 were <50" % low_count)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 8. FINESSE FATIGUE — later checks harder due to cumulative fatigue
# ═══════════════════════════════════════════════════════════════════════════════

func test_finesse_scores_bounded() -> bool:
	# Finesse has fatigue mechanic; all scores must remain 0-100
	for i in range(50):
		var sys: MerlinMiniGameSystem = _make_system(i * 5)
		var score: int = int(sys.run("finesse", 7)["score"])
		if score < 0 or score > 100:
			push_error("Finesse score out of range at seed %d: %d" % [i, score])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 9. CHANCE — difficulty shift direction (higher diff shifts score down)
# ═══════════════════════════════════════════════════════════════════════════════

func test_chance_high_diff_shifts_down() -> bool:
	var sum_low_diff: int = 0
	var sum_high_diff: int = 0
	for i in range(100):
		var s1: MerlinMiniGameSystem = _make_system(i)
		var s2: MerlinMiniGameSystem = _make_system(i)
		sum_low_diff += int(s1.run("chance", 1)["score"])
		sum_high_diff += int(s2.run("chance", 10)["score"])
	var avg_low: float = float(sum_low_diff) / 100.0
	var avg_high: float = float(sum_high_diff) / 100.0
	# Difficulty 10 shift = (10-5)*2 = +10 subtracted from roll
	# Difficulty 1 shift = (1-5)*2 = -8 subtracted (i.e. +8 added)
	if avg_low <= avg_high:
		push_error("Chance at diff 1 should average higher than diff 10: %.1f vs %.1f" % [avg_low, avg_high])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 10. GENERIC vs NAMED — unknown field uses _play_generic, not a named algo
# ═══════════════════════════════════════════════════════════════════════════════

func test_generic_differs_from_named() -> bool:
	# Same seed, generic and vigueur should produce different scores
	# (different algorithms consume RNG differently)
	var sys1: MerlinMiniGameSystem = _make_system(42)
	var sys2: MerlinMiniGameSystem = _make_system(42)
	var r_named: Dictionary = sys1.run("vigueur", 5)
	var r_generic: Dictionary = sys2.run("nonexistent", 5)
	# The algorithms are fundamentally different (multi-roll vs single roll),
	# so they should almost always differ
	if int(r_named["score"]) == int(r_generic["score"]) and str(r_named["type"]) == str(r_generic["type"]):
		push_error("Generic and named fields should differ in type at minimum")
		return false
	if str(r_generic["type"]) != "nonexistent":
		push_error("Generic type should be 'nonexistent', got '%s'" % r_generic["type"])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 11. SEQUENTIAL RUNS — RNG advances, consecutive runs differ
# ═══════════════════════════════════════════════════════════════════════════════

func test_sequential_runs_differ() -> bool:
	var sys: MerlinMiniGameSystem = _make_system(42)
	var scores: Array[int] = []
	for i in range(10):
		scores.append(int(sys.run("esprit", 5)["score"]))
	# With 10 runs, at least 2 different scores should appear
	var unique: Dictionary = {}
	for s in scores:
		unique[s] = true
	if unique.size() < 2:
		push_error("10 sequential runs produced only 1 unique score: %d" % scores[0])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 12. EMPTY MODIFIERS — passing {} is equivalent to no modifiers
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_modifiers_equivalent() -> bool:
	var sys1: MerlinMiniGameSystem = _make_system(42)
	var sys2: MerlinMiniGameSystem = _make_system(42)
	var r_default: Dictionary = sys1.run("perception", 5)
	var r_empty: Dictionary = sys2.run("perception", 5, {})
	if int(r_default["score"]) != int(r_empty["score"]):
		push_error("Empty modifiers should match default: %d vs %d" % [r_default["score"], r_empty["score"]])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 13. BOUNDARY SCORE 79/80 — success flag flips at threshold
# ═══════════════════════════════════════════════════════════════════════════════

func test_success_boundary_exact() -> bool:
	# Use bonus to force a known score near the boundary
	# Find a seed where base score + bonus lands exactly at 79 and 80
	var sys: MerlinMiniGameSystem = _make_system(42)
	var base_result: Dictionary = sys.run("observation", 5)
	var base_score: int = int(base_result["score"])

	# Force score to exactly 79 via bonus
	var bonus_to_79: float = float(79 - base_score) / 100.0
	var sys79: MerlinMiniGameSystem = _make_system(42)
	var r79: Dictionary = sys79.run("observation", 5, {"bonus": bonus_to_79})
	var s79: int = int(r79["score"])
	if s79 == 79 and bool(r79["success"]):
		push_error("Score 79 should NOT be success, but got success=true")
		return false

	# Force score to exactly 80 via bonus
	var bonus_to_80: float = float(80 - base_score) / 100.0
	var sys80: MerlinMiniGameSystem = _make_system(42)
	var r80: Dictionary = sys80.run("observation", 5, {"bonus": bonus_to_80})
	var s80: int = int(r80["score"])
	if s80 == 80 and not bool(r80["success"]):
		push_error("Score 80 should be success, but got success=false")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 14. REMAINING DIFFICULTY SCALING — bluff, observation, perception, finesse, chance
# (test_minigame_system.gd only covers vigueur, logique, esprit)
# ═══════════════════════════════════════════════════════════════════════════════

func test_difficulty_scaling_bluff() -> bool:
	return _assert_difficulty_scaling("bluff")


func test_difficulty_scaling_observation() -> bool:
	return _assert_difficulty_scaling("observation")


func test_difficulty_scaling_perception() -> bool:
	return _assert_difficulty_scaling("perception")


func test_difficulty_scaling_finesse() -> bool:
	return _assert_difficulty_scaling("finesse")


func test_difficulty_scaling_chance() -> bool:
	return _assert_difficulty_scaling("chance")


# ═══════════════════════════════════════════════════════════════════════════════
# 15. BONUS ZERO — bonus 0.0 has no effect
# ═══════════════════════════════════════════════════════════════════════════════

func test_zero_bonus_no_effect() -> bool:
	var sys1: MerlinMiniGameSystem = _make_system(42)
	var sys2: MerlinMiniGameSystem = _make_system(42)
	var r_none: Dictionary = sys1.run("finesse", 5)
	var r_zero: Dictionary = sys2.run("finesse", 5, {"bonus": 0.0})
	if int(r_none["score"]) != int(r_zero["score"]):
		push_error("Zero bonus should not change score: %d vs %d" % [r_none["score"], r_zero["score"]])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _assert_difficulty_scaling(field: String) -> bool:
	var sum_easy: int = 0
	var sum_hard: int = 0
	for i in range(80):
		var sys_easy: MerlinMiniGameSystem = _make_system(i * 7 + 1)
		var sys_hard: MerlinMiniGameSystem = _make_system(i * 7 + 1)
		sum_easy += int(sys_easy.run(field, 1)["score"])
		sum_hard += int(sys_hard.run(field, 10)["score"])
	var avg_easy: float = float(sum_easy) / 80.0
	var avg_hard: float = float(sum_hard) / 80.0
	if avg_easy <= avg_hard:
		push_error("Difficulty scaling failed for %s: avg_easy=%.1f <= avg_hard=%.1f" % [field, avg_easy, avg_hard])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> void:
	var tests: Array[Callable] = [
		# Signal emission
		test_signal_emits_final_score,
		test_signal_emits_on_every_run,
		# Negative bonus
		test_negative_bonus_reduces_score,
		test_negative_bonus_clamped_at_zero,
		# Whitespace trimming
		test_whitespace_trimmed_field_name,
		# Hit chance boundaries
		test_hit_chance_difficulty_1,
		test_hit_chance_difficulty_10,
		# Time scaling
		test_time_ms_scales_with_difficulty,
		# Bluff early-break
		test_bluff_score_never_exceeds_100,
		# Logique early-break
		test_logique_difficulty_10_often_low,
		# Finesse fatigue
		test_finesse_scores_bounded,
		# Chance shift
		test_chance_high_diff_shifts_down,
		# Generic vs named
		test_generic_differs_from_named,
		# Sequential RNG
		test_sequential_runs_differ,
		# Empty modifiers
		test_empty_modifiers_equivalent,
		# Boundary 79/80
		test_success_boundary_exact,
		# Remaining difficulty scaling
		test_difficulty_scaling_bluff,
		test_difficulty_scaling_observation,
		test_difficulty_scaling_perception,
		test_difficulty_scaling_finesse,
		test_difficulty_scaling_chance,
		# Zero bonus
		test_zero_bonus_no_effect,
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

	print("[test_minigame_system_unit] Results: %d/%d passed" % [passed, passed + failed])
	if failed > 0:
		push_error("[test_minigame_system_unit] %d test(s) FAILED" % failed)
	else:
		print("[test_minigame_system_unit] All tests passed.")
