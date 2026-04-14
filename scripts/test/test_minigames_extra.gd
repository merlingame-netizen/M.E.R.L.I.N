## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — 7 Extra Minigames (Volonte, Apaisement, Combat Rituel,
##   Course, Meditation, Ombres, Sang-Froid)
## ═══════════════════════════════════════════════════════════════════════════════
## Tests pure-logic scoring helpers by replicating the scoring formulas from
## each minigame's _finish_game / _end_game / _release method.
## Pattern: extends RefCounted, run_all() returns Dictionary of test results.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# VOLONTE — mg_volonte.gd
# Score = (hits / ROUND_COUNT) * 100 - misses * 8, clamped 0-100
# ═══════════════════════════════════════════════════════════════════════════════

func _volonte_score(hits: int, misses: int, round_count: int) -> int:
	var accuracy: float = float(hits) / float(round_count)
	var miss_penalty: int = misses * 8
	return clampi(int(accuracy * 100.0) - miss_penalty, 0, 100)


func test_volonte_perfect() -> bool:
	# 6/6 hits, 0 misses = 100
	var score: int = _volonte_score(6, 0, 6)
	if score != 100:
		push_error("Volonte perfect: expected 100, got %d" % score)
		return false
	return true


func test_volonte_all_miss() -> bool:
	# 0/6 hits, 6 misses = max(0 - 48, 0) = 0
	var score: int = _volonte_score(0, 6, 6)
	if score != 0:
		push_error("Volonte all miss: expected 0, got %d" % score)
		return false
	return true


func test_volonte_partial_with_penalties() -> bool:
	# 4/6 hits, 2 misses = 66 - 16 = 50
	var score: int = _volonte_score(4, 2, 6)
	if score != 50:
		push_error("Volonte partial: expected 50, got %d" % score)
		return false
	return true


func test_volonte_success_threshold() -> bool:
	# success = score >= 50
	var score_pass: int = _volonte_score(4, 2, 6)  # 50
	var score_fail: int = _volonte_score(3, 2, 6)  # 50 - 16 = 34
	if not (score_pass >= 50):
		push_error("Volonte 4h/2m should pass threshold, score=%d" % score_pass)
		return false
	if score_fail >= 50:
		push_error("Volonte 3h/2m should fail threshold, score=%d" % score_fail)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# APAISEMENT — mg_apaisement.gd
# Score = average of per-beat accuracy scores, clamped 0-100
# Timing accuracy thresholds: <0.08 = 100, <0.15 = 75, <0.25 = 40, else 10
# ═══════════════════════════════════════════════════════════════════════════════

func _apaisement_timing_accuracy(distance: float) -> int:
	if distance < 0.08:
		return 100
	elif distance < 0.15:
		return 75
	elif distance < 0.25:
		return 40
	else:
		return 10


func _apaisement_score(scores: Array[int]) -> int:
	if scores.is_empty():
		return 10
	var total: int = 0
	for s in scores:
		total += s
	return clampi(int(float(total) / float(scores.size())), 0, 100)


func test_apaisement_perfect_timing() -> bool:
	# All 5 beats at distance < 0.08 = accuracy 100 each = avg 100
	var scores: Array[int] = [100, 100, 100, 100, 100]
	var score: int = _apaisement_score(scores)
	if score != 100:
		push_error("Apaisement perfect: expected 100, got %d" % score)
		return false
	return true


func test_apaisement_all_missed() -> bool:
	# All 5 beats at distance >= 0.25 = accuracy 10 each = avg 10
	var scores: Array[int] = [10, 10, 10, 10, 10]
	var score: int = _apaisement_score(scores)
	if score != 10:
		push_error("Apaisement all missed: expected 10, got %d" % score)
		return false
	return true


func test_apaisement_empty_scores() -> bool:
	# No beats pressed = fallback 10
	var scores: Array[int] = []
	var score: int = _apaisement_score(scores)
	if score != 10:
		push_error("Apaisement empty: expected 10, got %d" % score)
		return false
	return true


func test_apaisement_timing_bands() -> bool:
	# Test each accuracy band
	var a1: int = _apaisement_timing_accuracy(0.05)
	var a2: int = _apaisement_timing_accuracy(0.10)
	var a3: int = _apaisement_timing_accuracy(0.20)
	var a4: int = _apaisement_timing_accuracy(0.40)
	if a1 != 100:
		push_error("Apaisement timing 0.05: expected 100, got %d" % a1)
		return false
	if a2 != 75:
		push_error("Apaisement timing 0.10: expected 75, got %d" % a2)
		return false
	if a3 != 40:
		push_error("Apaisement timing 0.20: expected 40, got %d" % a3)
		return false
	if a4 != 10:
		push_error("Apaisement timing 0.40: expected 10, got %d" % a4)
		return false
	return true


func test_apaisement_mixed_scores() -> bool:
	# Mix: 100+75+40+10+75 = 300, avg = 60
	var scores: Array[int] = [100, 75, 40, 10, 75]
	var score: int = _apaisement_score(scores)
	if score != 60:
		push_error("Apaisement mixed: expected 60, got %d" % score)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# COMBAT RITUEL — mg_combat_rituel.gd
# base_score = (hits / ROUND_COUNT) * 80
# speed_bonus = clamp(20 - avg_ms / 50, 0, 20) (only if hits > 0)
# score = clamp(base_score + speed_bonus, 0, 100)
# success = hits >= 3
# ═══════════════════════════════════════════════════════════════════════════════

func _combat_rituel_score(hits: int, total_reaction_ms: int, round_count: int) -> Dictionary:
	var base_score: int = int(float(hits) / float(round_count) * 80.0)
	var speed_bonus: int = 0
	if hits > 0:
		var avg_ms: float = float(total_reaction_ms) / float(hits)
		speed_bonus = clampi(int(20.0 - avg_ms / 50.0), 0, 20)
	var score: int = clampi(base_score + speed_bonus, 0, 100)
	var success: bool = hits >= 3
	return {"score": score, "success": success, "speed_bonus": speed_bonus}


func test_combat_rituel_perfect_fast() -> bool:
	# 5/5 hits, avg 100ms each = base 80 + bonus clamp(20 - 2, 0, 20) = 18 -> total 98
	var result: Dictionary = _combat_rituel_score(5, 500, 5)
	if int(result["score"]) != 98:
		push_error("Combat rituel perfect fast: expected 98, got %d" % int(result["score"]))
		return false
	if not bool(result["success"]):
		push_error("Combat rituel perfect fast: should be success")
		return false
	return true


func test_combat_rituel_zero_hits() -> bool:
	# 0 hits = base 0, no speed bonus = 0
	var result: Dictionary = _combat_rituel_score(0, 0, 5)
	if int(result["score"]) != 0:
		push_error("Combat rituel zero hits: expected 0, got %d" % int(result["score"]))
		return false
	if bool(result["success"]):
		push_error("Combat rituel zero hits: should not be success")
		return false
	return true


func test_combat_rituel_slow_hits() -> bool:
	# 5/5 hits, avg 1500ms = base 80 + clamp(20-30, 0, 20) = 80 + 0 = 80
	var result: Dictionary = _combat_rituel_score(5, 7500, 5)
	if int(result["score"]) != 80:
		push_error("Combat rituel slow: expected 80, got %d" % int(result["score"]))
		return false
	return true


func test_combat_rituel_threshold() -> bool:
	# 3 hits = success, 2 hits = fail
	var r3: Dictionary = _combat_rituel_score(3, 600, 5)
	var r2: Dictionary = _combat_rituel_score(2, 400, 5)
	if not bool(r3["success"]):
		push_error("Combat rituel 3 hits should be success")
		return false
	if bool(r2["success"]):
		push_error("Combat rituel 2 hits should not be success")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# COURSE — mg_course.gd
# base_score = progress * 70 (progress = taps / required, capped at 1.0)
# time_bonus = (time_left / max_time) * 30 (only if completed and time_left > 0)
# score = clamp(base_score + time_bonus, 0, 100)
# success = progress >= 0.7
# ═══════════════════════════════════════════════════════════════════════════════

func _course_score(taps: int, required_taps: int, time_left: float, max_time: float) -> Dictionary:
	var progress: float = minf(float(taps) / float(required_taps), 1.0)
	var base_score: int = int(progress * 70.0)
	var time_bonus: int = 0
	if taps >= required_taps and time_left > 0:
		var time_ratio: float = clampf(time_left / max_time, 0.0, 1.0)
		time_bonus = int(time_ratio * 30.0)
	var score: int = clampi(base_score + time_bonus, 0, 100)
	var success: bool = progress >= 0.7
	return {"score": score, "success": success, "time_bonus": time_bonus}


func test_course_completed_fast() -> bool:
	# 20/20 taps, 3s left of 5s max = base 70 + bonus int(0.6*30)=18 = 88
	var result: Dictionary = _course_score(20, 20, 3.0, 5.0)
	if int(result["score"]) != 88:
		push_error("Course fast: expected 88, got %d" % int(result["score"]))
		return false
	if not bool(result["success"]):
		push_error("Course fast: should be success")
		return false
	return true


func test_course_timeout_partial() -> bool:
	# 10/20 taps, time ran out = base 35, no bonus = 35, progress 0.5 < 0.7 = fail
	var result: Dictionary = _course_score(10, 20, 0.0, 5.0)
	if int(result["score"]) != 35:
		push_error("Course partial: expected 35, got %d" % int(result["score"]))
		return false
	if bool(result["success"]):
		push_error("Course partial: should not be success")
		return false
	return true


func test_course_zero_taps() -> bool:
	# 0 taps = 0 score
	var result: Dictionary = _course_score(0, 20, 0.0, 5.0)
	if int(result["score"]) != 0:
		push_error("Course zero taps: expected 0, got %d" % int(result["score"]))
		return false
	return true


func test_course_barely_passing() -> bool:
	# 14/20 taps = progress 0.7, base 49, no time bonus (not completed) = 49, success = true
	var result: Dictionary = _course_score(14, 20, 0.0, 5.0)
	if not bool(result["success"]):
		push_error("Course 70%% progress should be success")
		return false
	if int(result["score"]) != 49:
		push_error("Course 70%%: expected 49, got %d" % int(result["score"]))
		return false
	return true



# ═══════════════════════════════════════════════════════════════════════════════
# OMBRES — mg_ombres.gd
# base_score = (hits / ROUND_COUNT) * 80
# speed_bonus = clamp(20 - avg_ms / 75, 0, 20) (only if hits > 0)
# score = clamp(base_score + speed_bonus, 0, 100)
# success = hits >= 3
# ═══════════════════════════════════════════════════════════════════════════════

func _ombres_score(hits: int, total_reaction_ms: int, round_count: int) -> Dictionary:
	var base_score: int = int(float(hits) / float(round_count) * 80.0)
	var speed_bonus: int = 0
	if hits > 0:
		var avg_ms: float = float(total_reaction_ms) / float(hits)
		speed_bonus = clampi(int(20.0 - avg_ms / 75.0), 0, 20)
	var score: int = clampi(base_score + speed_bonus, 0, 100)
	var success: bool = hits >= 3
	return {"score": score, "success": success}


func test_ombres_perfect_fast() -> bool:
	# 5/5 hits, avg 150ms = base 80 + clamp(20-2, 0, 20) = 18 -> 98
	var result: Dictionary = _ombres_score(5, 750, 5)
	if int(result["score"]) != 98:
		push_error("Ombres perfect fast: expected 98, got %d" % int(result["score"]))
		return false
	return true


func test_ombres_zero_hits() -> bool:
	var result: Dictionary = _ombres_score(0, 0, 5)
	if int(result["score"]) != 0:
		push_error("Ombres zero: expected 0, got %d" % int(result["score"]))
		return false
	if bool(result["success"]):
		push_error("Ombres zero should not be success")
		return false
	return true


func test_ombres_slow_hits() -> bool:
	# 5/5 hits, avg 2000ms = base 80 + clamp(20-26, 0, 20) = 0 bonus -> 80
	var result: Dictionary = _ombres_score(5, 10000, 5)
	if int(result["score"]) != 80:
		push_error("Ombres slow: expected 80, got %d" % int(result["score"]))
		return false
	return true


func test_ombres_threshold() -> bool:
	var r3: Dictionary = _ombres_score(3, 900, 5)
	var r2: Dictionary = _ombres_score(2, 600, 5)
	if not bool(r3["success"]):
		push_error("Ombres 3 hits should be success")
		return false
	if bool(r2["success"]):
		push_error("Ombres 2 hits should not be success")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SANG-FROID — mg_sang_froid.gd
# Sweet spot zone: bar_value between sweet_min and sweet_max
# In zone: score = 70 + precision * 30 (precision = closeness to center)
# Overshoot: score = clamp(50 * (1 - overshoot_ratio), 10, 50)
# Undershoot: score = clamp(40 * (bar_value / sweet_min), 5, 40)
# ═══════════════════════════════════════════════════════════════════════════════

func _sang_froid_score(bar_value: float, sweet_min: float, sweet_max: float) -> Dictionary:
	var score: int = 0
	var success: bool = false

	if bar_value >= sweet_min and bar_value <= sweet_max:
		var sweet_center: float = (sweet_min + sweet_max) / 2.0
		var precision: float = 1.0 - absf(bar_value - sweet_center) / ((sweet_max - sweet_min) / 2.0)
		score = 70 + int(precision * 30.0)
		success = true
	elif bar_value > sweet_max:
		var overshoot: float = (bar_value - sweet_max) / (1.0 - sweet_max)
		score = clampi(int(50.0 * (1.0 - overshoot)), 10, 50)
	else:
		var undershoot: float = bar_value / sweet_min
		score = clampi(int(40.0 * undershoot), 5, 40)

	return {"score": score, "success": success}


func test_sang_froid_perfect_center() -> bool:
	# Bar exactly at center of sweet zone (0.65 to 0.85) = center 0.75
	var result: Dictionary = _sang_froid_score(0.75, 0.65, 0.85)
	# precision = 1.0 - 0/0.1 = 1.0, score = 70 + 30 = 100
	if int(result["score"]) != 100:
		push_error("Sang-froid center: expected 100, got %d" % int(result["score"]))
		return false
	if not bool(result["success"]):
		push_error("Sang-froid center: should be success")
		return false
	return true


func test_sang_froid_edge_of_zone() -> bool:
	# At sweet_min exactly (0.65): precision = 1.0 - 0.1/0.1 = 0.0, score = 70
	var result: Dictionary = _sang_froid_score(0.65, 0.65, 0.85)
	if int(result["score"]) != 70:
		push_error("Sang-froid edge: expected 70, got %d" % int(result["score"]))
		return false
	if not bool(result["success"]):
		push_error("Sang-froid edge: should be success")
		return false
	return true


func test_sang_froid_overshoot() -> bool:
	# bar_value = 0.90, sweet_max = 0.85 → overshoot, score in [10, 50]
	var result: Dictionary = _sang_froid_score(0.90, 0.65, 0.85)
	var score: int = int(result["score"])
	if score < 10 or score > 50:
		push_error("Sang-froid overshoot: score %d out of range [10,50]" % score)
		return false
	if bool(result["success"]):
		push_error("Sang-froid overshoot: should not be success")
		return false
	return true


func test_sang_froid_undershoot() -> bool:
	# bar_value = 0.325, sweet_min = 0.65
	# undershoot = 0.325 / 0.65 = 0.5
	# score = clamp(40 * 0.5, 5, 40) = 20, not success
	var result: Dictionary = _sang_froid_score(0.325, 0.65, 0.85)
	if int(result["score"]) != 20:
		push_error("Sang-froid undershoot: expected 20, got %d" % int(result["score"]))
		return false
	if bool(result["success"]):
		push_error("Sang-froid undershoot: should not be success")
		return false
	return true


func test_sang_froid_max_overshoot() -> bool:
	# bar_value = 1.0 (auto-fail max)
	# overshoot = (1.0 - 0.85) / (1.0 - 0.85) = 1.0
	# score = clamp(50 * 0, 10, 50) = 10 (floor)
	var result: Dictionary = _sang_froid_score(1.0, 0.65, 0.85)
	if int(result["score"]) != 10:
		push_error("Sang-froid max overshoot: expected 10, got %d" % int(result["score"]))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CROSS-MINIGAME — shared behaviors
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_scores_clamp_0_100() -> bool:
	# Verify extreme inputs never produce out-of-range scores
	var v1: int = _volonte_score(100, 0, 6)     # way over 100
	var v2: int = _volonte_score(0, 100, 6)      # way under 0
	var c1: int = int(_course_score(100, 5, 99.0, 5.0)["score"])  # over
	if v1 > 100 or v1 < 0:
		push_error("Volonte extreme high out of range: %d" % v1)
		return false
	if v2 > 100 or v2 < 0:
		push_error("Volonte extreme low out of range: %d" % v2)
		return false
	if c1 > 100 or c1 < 0:
		push_error("Course extreme out of range: %d" % c1)
		return false
	return true


func test_difficulty_round_delay_volonte() -> bool:
	# Volonte: round_delay = max(3.0 - difficulty * 0.15, 1.2)
	# difficulty 1 -> 2.85, difficulty 10 -> max(1.5, 1.2) = 1.5
	var delay_d1: float = maxf(3.0 - 1 * 0.15, 1.2)
	var delay_d10: float = maxf(3.0 - 10 * 0.15, 1.2)
	if not is_equal_approx(delay_d1, 2.85):
		push_error("Volonte delay d1: expected 2.85, got %f" % delay_d1)
		return false
	if not is_equal_approx(delay_d10, 1.5):
		push_error("Volonte delay d10: expected 1.5, got %f" % delay_d10)
		return false
	return true


func test_difficulty_required_taps_course() -> bool:
	# Course: required_taps = 15 + difficulty * 3
	# difficulty 1 -> 18, difficulty 10 -> 45
	var taps_d1: int = 15 + 1 * 3
	var taps_d10: int = 15 + 10 * 3
	if taps_d1 != 18:
		push_error("Course taps d1: expected 18, got %d" % taps_d1)
		return false
	if taps_d10 != 45:
		push_error("Course taps d10: expected 45, got %d" % taps_d10)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL — Returns Dictionary {test_name: bool}
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var results: Dictionary = {}
	var tests: Array[Array] = [
		# Volonte (4)
		["test_volonte_perfect", test_volonte_perfect],
		["test_volonte_all_miss", test_volonte_all_miss],
		["test_volonte_partial_with_penalties", test_volonte_partial_with_penalties],
		["test_volonte_success_threshold", test_volonte_success_threshold],
		# Apaisement (5)
		["test_apaisement_perfect_timing", test_apaisement_perfect_timing],
		["test_apaisement_all_missed", test_apaisement_all_missed],
		["test_apaisement_empty_scores", test_apaisement_empty_scores],
		["test_apaisement_timing_bands", test_apaisement_timing_bands],
		["test_apaisement_mixed_scores", test_apaisement_mixed_scores],
		# Combat Rituel (4)
		["test_combat_rituel_perfect_fast", test_combat_rituel_perfect_fast],
		["test_combat_rituel_zero_hits", test_combat_rituel_zero_hits],
		["test_combat_rituel_slow_hits", test_combat_rituel_slow_hits],
		["test_combat_rituel_threshold", test_combat_rituel_threshold],
		# Course (4)
		["test_course_completed_fast", test_course_completed_fast],
		["test_course_timeout_partial", test_course_timeout_partial],
		["test_course_zero_taps", test_course_zero_taps],
		["test_course_barely_passing", test_course_barely_passing],
		# Ombres (4)
		["test_ombres_perfect_fast", test_ombres_perfect_fast],
		["test_ombres_zero_hits", test_ombres_zero_hits],
		["test_ombres_slow_hits", test_ombres_slow_hits],
		["test_ombres_threshold", test_ombres_threshold],
		# Sang-Froid (5)
		["test_sang_froid_perfect_center", test_sang_froid_perfect_center],
		["test_sang_froid_edge_of_zone", test_sang_froid_edge_of_zone],
		["test_sang_froid_overshoot", test_sang_froid_overshoot],
		["test_sang_froid_undershoot", test_sang_froid_undershoot],
		["test_sang_froid_max_overshoot", test_sang_froid_max_overshoot],
		# Cross-minigame (3)
		["test_all_scores_clamp_0_100", test_all_scores_clamp_0_100],
		["test_difficulty_round_delay_volonte", test_difficulty_round_delay_volonte],
		["test_difficulty_required_taps_course", test_difficulty_required_taps_course],
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

	print("[test_minigames_extra] Results: %d/%d passed" % [passed, passed + failed])
	if failed > 0:
		push_error("[test_minigames_extra] %d test(s) FAILED" % failed)
	else:
		print("[test_minigames_extra] All tests passed.")

	return results
