## ═══════════════════════════════════════════════════════════════════════════════
## Test SessionRegistry — Pure unit tests (no Node, no file I/O, no scene tree)
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage: initialization, decision tracking, engagement, wellness, getters,
##           trend calculation, event recording, end-session summary,
##           tilt detection, fatigue detection, faction interaction, LLM context,
##           get_summary_for_prompt, start_new_session reset, streak logic,
##           boundary values, edge cases.
## Run count: 40 tests.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
# NO class_name — avoids polluting the global namespace in test-only files


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _make_fresh() -> SessionRegistry:
	## Returns a SessionRegistry with history bypassed so _init disk load is safe.
	## We reset current + wellness manually to guarantee a clean state.
	var reg: SessionRegistry = SessionRegistry.new()
	# Override start_time so get_session_length_minutes() is deterministic
	reg.current["start_time"] = int(Time.get_unix_time_from_system())
	reg.current["cards_this_session"] = 0
	reg.current["runs_this_session"] = 0
	reg.current["deaths_this_session"] = 0
	reg.current["breaks_taken"] = 0
	reg.current["total_decision_time_ms"] = 0
	reg.current["rushed_decisions"] = 0
	reg.current["contemplated_decisions"] = 0
	reg.current["skill_uses"] = 0
	reg.current["faction_interactions"] = 0
	reg.wellness["long_session_warned"] = false
	reg.wellness["break_suggested"] = false
	reg.wellness["frustration_detected"] = false
	reg.wellness["fatigue_detected"] = false
	reg.wellness["tilt_detected"] = false
	reg.wellness["positive_momentum"] = false
	reg.engagement["faction_interaction_rate"] = 0.0
	reg.engagement["skill_usage_rate"] = 0.0
	reg.engagement["dialogue_skip_rate"] = 0.0
	reg._recent_decision_times.clear()
	reg.average_decision_time = 4.5
	reg.decision_time_trend = 0.0
	return reg


# ─────────────────────────────────────────────────────────────────────────────
# 1. INITIALIZATION
# ─────────────────────────────────────────────────────────────────────────────

func test_init_current_counters_are_zero() -> bool:
	var reg: SessionRegistry = _make_fresh()
	if reg.current["cards_this_session"] != 0:
		push_error("Expected cards_this_session == 0, got %d" % reg.current["cards_this_session"])
		return false
	if reg.current["deaths_this_session"] != 0:
		push_error("Expected deaths_this_session == 0, got %d" % reg.current["deaths_this_session"])
		return false
	return true


func test_init_wellness_flags_are_false() -> bool:
	var reg: SessionRegistry = _make_fresh()
	for key in reg.wellness:
		if reg.wellness[key] != false:
			push_error("Expected wellness.%s == false, got %s" % [key, str(reg.wellness[key])])
			return false
	return true


func test_init_average_decision_time_default() -> bool:
	var reg: SessionRegistry = _make_fresh()
	if not is_equal_approx(reg.average_decision_time, 4.5):
		push_error("Expected average_decision_time == 4.5, got %f" % reg.average_decision_time)
		return false
	return true


func test_init_engagement_medium() -> bool:
	var reg: SessionRegistry = _make_fresh()
	if reg.engagement["current_level"] != SessionRegistry.EngagementLevel.MEDIUM:
		push_error("Expected engagement level MEDIUM at init")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 2. DECISION RECORDING
# ─────────────────────────────────────────────────────────────────────────────

func test_record_decision_increments_card_count() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.record_decision(3000)
	reg.record_decision(3000)
	if reg.current["cards_this_session"] != 2:
		push_error("Expected 2 cards, got %d" % reg.current["cards_this_session"])
		return false
	return true


func test_record_decision_accumulates_total_time() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.record_decision(2000)
	reg.record_decision(4000)
	if reg.current["total_decision_time_ms"] != 6000:
		push_error("Expected total_decision_time_ms == 6000, got %d" % reg.current["total_decision_time_ms"])
		return false
	return true


func test_record_decision_classifies_rushed() -> bool:
	var reg: SessionRegistry = _make_fresh()
	# RUSHED_DECISION_MS = 1000; anything < 1000 is rushed
	reg.record_decision(500)
	reg.record_decision(800)
	if reg.current["rushed_decisions"] != 2:
		push_error("Expected 2 rushed decisions, got %d" % reg.current["rushed_decisions"])
		return false
	return true


func test_record_decision_classifies_contemplated() -> bool:
	var reg: SessionRegistry = _make_fresh()
	# CONTEMPLATED_DECISION_MS = 10000; anything > 10000 is contemplated
	reg.record_decision(12000)
	reg.record_decision(15000)
	if reg.current["contemplated_decisions"] != 2:
		push_error("Expected 2 contemplated decisions, got %d" % reg.current["contemplated_decisions"])
		return false
	return true


func test_record_decision_normal_not_classified() -> bool:
	var reg: SessionRegistry = _make_fresh()
	# Exactly at boundary (1000ms) is NOT rushed (< 1000 required), not contemplated
	reg.record_decision(1000)
	reg.record_decision(5000)
	if reg.current["rushed_decisions"] != 0:
		push_error("Expected 0 rushed, got %d" % reg.current["rushed_decisions"])
		return false
	if reg.current["contemplated_decisions"] != 0:
		push_error("Expected 0 contemplated, got %d" % reg.current["contemplated_decisions"])
		return false
	return true


func test_record_decision_updates_average() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.record_decision(4000)
	reg.record_decision(8000)
	# average = (4000 + 8000) / 2 / 1000 = 6.0 seconds
	if not is_equal_approx(reg.average_decision_time, 6.0):
		push_error("Expected average_decision_time == 6.0, got %f" % reg.average_decision_time)
		return false
	return true


func test_recent_decision_window_capped_at_20() -> bool:
	var reg: SessionRegistry = _make_fresh()
	for _i in range(25):
		reg.record_decision(3000)
	if reg._recent_decision_times.size() > 20:
		push_error("Expected _recent_decision_times.size() <= 20, got %d" % reg._recent_decision_times.size())
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 3. TREND CALCULATION
# ─────────────────────────────────────────────────────────────────────────────

func test_trend_zero_with_fewer_than_10_decisions() -> bool:
	var reg: SessionRegistry = _make_fresh()
	for _i in range(9):
		reg.record_decision(3000)
	if not is_equal_approx(reg.decision_time_trend, 0.0):
		push_error("Expected trend == 0.0 with < 10 decisions, got %f" % reg.decision_time_trend)
		return false
	return true


func test_trend_positive_when_slowing_down() -> bool:
	## Fill first 10 with fast decisions then 10 with slow; trend should be positive.
	var reg: SessionRegistry = _make_fresh()
	for _i in range(10):
		reg.record_decision(1000)
	for _i in range(10):
		reg.record_decision(9000)
	if reg.decision_time_trend <= 0.0:
		push_error("Expected positive trend when slowing down, got %f" % reg.decision_time_trend)
		return false
	return true


func test_trend_negative_when_speeding_up() -> bool:
	var reg: SessionRegistry = _make_fresh()
	for _i in range(10):
		reg.record_decision(9000)
	for _i in range(10):
		reg.record_decision(1000)
	if reg.decision_time_trend >= 0.0:
		push_error("Expected negative trend when speeding up, got %f" % reg.decision_time_trend)
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 4. EVENT RECORDING
# ─────────────────────────────────────────────────────────────────────────────

func test_record_death_increments_counter() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.record_death()
	reg.record_death()
	if reg.current["deaths_this_session"] != 2:
		push_error("Expected 2 deaths, got %d" % reg.current["deaths_this_session"])
		return false
	return true


func test_record_run_start_increments_counter() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.record_run_start()
	reg.record_run_start()
	if reg.current["runs_this_session"] != 2:
		push_error("Expected 2 runs, got %d" % reg.current["runs_this_session"])
		return false
	return true


func test_record_skill_use_updates_rate() -> bool:
	var reg: SessionRegistry = _make_fresh()
	# Record 4 cards then 2 skill uses → rate = 2/4 = 0.5
	for _i in range(4):
		reg.record_decision(3000)
	reg.record_skill_use()
	reg.record_skill_use()
	var expected_rate: float = 2.0 / maxf(1.0, float(reg.current["cards_this_session"]))
	if not is_equal_approx(reg.engagement["skill_usage_rate"], expected_rate):
		push_error("Expected skill_usage_rate == %f, got %f" % [expected_rate, reg.engagement["skill_usage_rate"]])
		return false
	return true


func test_record_break_increments_and_resets_flag() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.wellness["break_suggested"] = true
	reg.record_break()
	if reg.current["breaks_taken"] != 1:
		push_error("Expected breaks_taken == 1, got %d" % reg.current["breaks_taken"])
		return false
	if reg.wellness["break_suggested"] != false:
		push_error("Expected break_suggested reset to false after break")
		return false
	return true


func test_record_dialogue_skip_increases_rate() -> bool:
	var reg: SessionRegistry = _make_fresh()
	var initial: float = reg.engagement["dialogue_skip_rate"]
	reg.record_dialogue_skip()
	if reg.engagement["dialogue_skip_rate"] <= initial:
		push_error("Expected dialogue_skip_rate to increase, was %f, got %f" % [initial, reg.engagement["dialogue_skip_rate"]])
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 5. WELLNESS DETECTION (manual flag injection)
# ─────────────────────────────────────────────────────────────────────────────

func test_frustration_detected_with_many_deaths_and_high_rush_ratio() -> bool:
	var reg: SessionRegistry = _make_fresh()
	# Prime: 10 rushed cards (< 1000ms each) → rush_ratio = 1.0 > 0.4
	for _i in range(10):
		reg.record_decision(500)
	# 3 deaths — triggers _check_wellness → _detect_frustration
	reg.record_death()
	reg.record_death()
	reg.record_death()
	if not reg.wellness["frustration_detected"]:
		push_error("Expected frustration_detected == true after 3 deaths + high rush ratio")
		return false
	return true


func test_positive_momentum_conditions() -> bool:
	## Positive momentum triggers when: cards > 50, deaths == 0, no frustration/fatigue.
	var reg: SessionRegistry = _make_fresh()
	# Record 51 normal decisions (3000ms — not rushed, not contemplated) with zero deaths.
	# Each record_decision calls _check_wellness → _detect_positive_momentum.
	for _i in range(51):
		reg.record_decision(3000)
	if not reg.wellness["positive_momentum"]:
		push_error("Expected positive_momentum == true after 51 cards with 0 deaths")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 6. GETTERS
# ─────────────────────────────────────────────────────────────────────────────

func test_is_returning_player_false_initially() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.history["total_sessions"] = 0
	if reg.is_returning_player():
		push_error("Expected is_returning_player() == false when total_sessions == 0")
		return false
	return true


func test_is_returning_player_true_after_sessions() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.history["total_sessions"] = 1
	if not reg.is_returning_player():
		push_error("Expected is_returning_player() == true when total_sessions == 1")
		return false
	return true


func test_get_preferred_play_time_unknown_when_empty() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.history["preferred_play_times"] = []
	var result: String = reg.get_preferred_play_time()
	if result != "unknown":
		push_error("Expected 'unknown' for empty play times, got '%s'" % result)
		return false
	return true


func test_get_preferred_play_time_returns_most_common() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.history["preferred_play_times"] = ["morning", "evening", "evening", "morning", "morning"]
	var result: String = reg.get_preferred_play_time()
	if result != "morning":
		push_error("Expected 'morning' as most common, got '%s'" % result)
		return false
	return true


func test_get_time_of_day_mapping() -> bool:
	## _get_time_of_day is a pure helper — test all 4 branches.
	var reg: SessionRegistry = _make_fresh()
	var tracker: Dictionary = {"ok": true, "error": ""}

	var check: Callable = func(hour: int, expected: String) -> void:
		var result: String = reg._get_time_of_day(hour)
		if result != expected:
			tracker["ok"] = false
			tracker["error"] = "hour %d: expected '%s', got '%s'" % [hour, expected, result]

	check.call(6, "morning")
	check.call(11, "morning")
	check.call(12, "afternoon")
	check.call(17, "afternoon")
	check.call(18, "evening")
	check.call(21, "evening")
	check.call(22, "night")
	check.call(4, "night")
	check.call(0, "night")

	if not tracker["ok"]:
		push_error(tracker["error"])
		return false
	return true


func test_get_context_for_llm_contains_required_keys() -> bool:
	var reg: SessionRegistry = _make_fresh()
	var ctx: Dictionary = reg.get_context_for_llm()
	var required_keys: Array = [
		"cards_this_session", "session_length_minutes", "is_returning_player",
		"days_away", "is_long_session", "seems_frustrated", "seems_fatigued",
		"in_tilt", "in_flow", "engagement_level", "reading_speed",
		"total_sessions", "current_streak",
	]
	for k in required_keys:
		if not ctx.has(k):
			push_error("get_context_for_llm() missing key: %s" % k)
			return false
	return true


func test_end_session_increments_total_sessions() -> bool:
	var reg: SessionRegistry = _make_fresh()
	var initial_sessions: int = int(reg.history["total_sessions"])
	reg.end_session()
	if reg.history["total_sessions"] != initial_sessions + 1:
		push_error("Expected total_sessions to increment by 1")
		return false
	return true


func test_end_session_returns_summary_with_expected_keys() -> bool:
	var reg: SessionRegistry = _make_fresh()
	var summary: Dictionary = reg.end_session()
	var expected_keys: Array = [
		"duration_minutes", "cards_played", "runs", "deaths",
		"average_decision_time", "engagement_level", "wellness_alerts",
	]
	for k in expected_keys:
		if not summary.has(k):
			push_error("end_session() summary missing key: %s" % k)
			return false
	return true


func test_wellness_summary_collects_active_alerts() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.wellness["frustration_detected"] = true
	reg.wellness["tilt_detected"] = true
	var summary: Dictionary = reg.end_session()
	var alerts: Array = summary["wellness_alerts"]
	if "frustration" not in alerts:
		push_error("Expected 'frustration' in wellness_alerts")
		return false
	if "tilt" not in alerts:
		push_error("Expected 'tilt' in wellness_alerts")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 7. TILT DETECTION
# ─────────────────────────────────────────────────────────────────────────────

func test_tilt_detected_with_3_deaths_in_short_session() -> bool:
	## Tilt triggers when deaths >= TILT_DEATH_THRESHOLD (3) and session < 30 min.
	## A freshly started registry has start_time set to now, so session_length is ~0 min.
	var reg: SessionRegistry = _make_fresh()
	reg.record_death()
	reg.record_death()
	reg.record_death()
	# record_decision calls _check_wellness which calls _detect_tilt
	reg.record_decision(2000)
	if not reg.wellness["tilt_detected"]:
		push_error("Expected tilt_detected == true with 3 deaths in a fresh (< 30 min) session")
		return false
	return true


func test_tilt_not_detected_below_death_threshold() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.record_death()
	reg.record_death()
	reg.record_decision(2000)
	if reg.wellness["tilt_detected"]:
		push_error("Expected tilt_detected == false with only 2 deaths (threshold is 3)")
		return false
	return true


func test_tilt_flag_not_set_twice() -> bool:
	## Once tilt_detected is true the guard at the top of _detect_tilt must prevent re-entry.
	var reg: SessionRegistry = _make_fresh()
	reg.wellness["tilt_detected"] = true
	# Further deaths + decisions must not change the flag (it stays true, but no extra work)
	reg.record_death()
	reg.record_death()
	reg.record_decision(2000)
	if not reg.wellness["tilt_detected"]:
		push_error("tilt_detected should remain true once set")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 8. FATIGUE DETECTION
# ─────────────────────────────────────────────────────────────────────────────

func test_fatigue_not_detected_with_few_cards() -> bool:
	## Fatigue requires cards_this_session > 30 even if trend is very high.
	var reg: SessionRegistry = _make_fresh()
	# Strong slowing signal but only 9 decisions recorded
	for _i in range(5):
		reg.record_decision(500)
	for _i in range(4):
		reg.record_decision(12000)
	if reg.wellness["fatigue_detected"]:
		push_error("fatigue_detected should be false with < 30 cards")
		return false
	return true


func test_fatigue_not_detected_when_trend_below_threshold() -> bool:
	## Fatigue threshold is decision_time_trend > 0.5 (FATIGUE_SLOWDOWN_FACTOR - 1).
	## Constant pace should keep trend near 0.
	var reg: SessionRegistry = _make_fresh()
	for _i in range(35):
		reg.record_decision(4000)
	if reg.wellness["fatigue_detected"]:
		push_error("fatigue_detected should be false when pace is constant (trend ~0)")
		return false
	return true


func test_fatigue_detected_with_strong_slowdown_and_enough_cards() -> bool:
	var reg: SessionRegistry = _make_fresh()
	# First 15 fast, then 16 very slow → strong positive trend, total > 30 cards
	for _i in range(15):
		reg.record_decision(500)
	for _i in range(16):
		reg.record_decision(12000)
	if not reg.wellness["fatigue_detected"]:
		push_error("fatigue_detected should be true: trend=%f, cards=%d" % [reg.decision_time_trend, reg.current["cards_this_session"]])
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 9. FRUSTRATION DETECTION — EDGE CASES
# ─────────────────────────────────────────────────────────────────────────────

func test_frustration_not_detected_below_rush_ratio() -> bool:
	## rush_ratio must be > 0.4; with mostly slow decisions it should NOT trigger.
	var reg: SessionRegistry = _make_fresh()
	# 8 slow decisions, 1 rushed → rush_ratio = 1/9 ≈ 0.11 < 0.4
	for _i in range(8):
		reg.record_decision(4000)
	reg.record_decision(500)  # 1 rushed
	# 3 deaths to meet death threshold
	reg.record_death()
	reg.record_death()
	reg.record_death()
	reg.record_decision(2000)
	if reg.wellness["frustration_detected"]:
		push_error("frustration_detected should be false when rush_ratio < 0.4")
		return false
	return true


func test_frustration_flag_idempotent() -> bool:
	## Once set, further calls to _check_wellness must not clear it.
	var reg: SessionRegistry = _make_fresh()
	reg.wellness["frustration_detected"] = true
	reg.record_decision(500)
	if not reg.wellness["frustration_detected"]:
		push_error("frustration_detected should remain true once set")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 10. FACTION INTERACTION RATE
# ─────────────────────────────────────────────────────────────────────────────

func test_faction_interaction_rate_capped_at_one() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.record_run_start()  # 1 run → denominator = 1 * 5 = 5
	for _i in range(20):
		reg.record_faction_interaction()
	if reg.engagement["faction_interaction_rate"] > 1.0:
		push_error("faction_interaction_rate must not exceed 1.0, got %f" % reg.engagement["faction_interaction_rate"])
		return false
	return true


func test_faction_interaction_rate_increases_with_interactions() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.record_run_start()
	var before: float = reg.engagement["faction_interaction_rate"]
	reg.record_faction_interaction()
	if reg.engagement["faction_interaction_rate"] <= before:
		push_error("faction_interaction_rate should increase after record_faction_interaction()")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 11. ENGAGEMENT — READING SPEED
# ─────────────────────────────────────────────────────────────────────────────

func test_reading_speed_fast_when_avg_below_2s() -> bool:
	var reg: SessionRegistry = _make_fresh()
	# 10 decisions at 1500ms → avg = 1.5 s < 2.0
	for _i in range(10):
		reg.record_decision(1500)
	if reg.engagement["card_reading_speed"] != "fast":
		push_error("Expected reading speed 'fast' when avg < 2.0s, got '%s'" % reg.engagement["card_reading_speed"])
		return false
	return true


func test_reading_speed_slow_when_avg_above_8s() -> bool:
	var reg: SessionRegistry = _make_fresh()
	for _i in range(10):
		reg.record_decision(9000)
	if reg.engagement["card_reading_speed"] != "slow":
		push_error("Expected reading speed 'slow' when avg > 8.0s, got '%s'" % reg.engagement["card_reading_speed"])
		return false
	return true


func test_reading_speed_variable_with_high_trend() -> bool:
	## When |trend| > 0.3 and avg is in normal range, speed should be "variable".
	var reg: SessionRegistry = _make_fresh()
	# Build a strong trend: 10 decisions at 1000ms then 10 at 6000ms
	# avg after 20 decisions = (10*1000 + 10*6000) / 20 / 1000 = 3.5s (in normal range)
	# but trend will be strongly positive
	for _i in range(10):
		reg.record_decision(1000)
	for _i in range(10):
		reg.record_decision(6000)
	if reg.engagement["card_reading_speed"] != "variable":
		push_error("Expected reading speed 'variable' with high trend, got '%s' (trend=%f, avg=%f)" % [reg.engagement["card_reading_speed"], reg.decision_time_trend, reg.average_decision_time])
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 12. START_NEW_SESSION RESETS
# ─────────────────────────────────────────────────────────────────────────────

func test_start_new_session_resets_all_current_counters() -> bool:
	var reg: SessionRegistry = _make_fresh()
	for _i in range(5):
		reg.record_decision(3000)
	reg.record_death()
	reg.record_run_start()
	reg.start_new_session()
	var zero_keys: Array = ["cards_this_session", "deaths_this_session",
		"runs_this_session", "total_decision_time_ms",
		"rushed_decisions", "contemplated_decisions", "skill_uses", "faction_interactions"]
	for key in zero_keys:
		if reg.current[key] != 0:
			push_error("start_new_session() should reset current.%s to 0, got %d" % [key, reg.current[key]])
			return false
	return true


func test_start_new_session_resets_recent_decision_times() -> bool:
	var reg: SessionRegistry = _make_fresh()
	for _i in range(10):
		reg.record_decision(3000)
	reg.start_new_session()
	if reg._recent_decision_times.size() != 0:
		push_error("_recent_decision_times should be empty after start_new_session(), size=%d" % reg._recent_decision_times.size())
		return false
	return true


func test_start_new_session_resets_average_decision_time() -> bool:
	var reg: SessionRegistry = _make_fresh()
	for _i in range(5):
		reg.record_decision(9000)  # drives avg up
	reg.start_new_session()
	if not is_equal_approx(reg.average_decision_time, 4.5):
		push_error("average_decision_time should reset to 4.5, got %f" % reg.average_decision_time)
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 13. GET_SUMMARY_FOR_PROMPT
# ─────────────────────────────────────────────────────────────────────────────

func test_get_summary_for_prompt_returns_nonempty_string() -> bool:
	var reg: SessionRegistry = _make_fresh()
	var s: String = reg.get_summary_for_prompt()
	if s.is_empty():
		push_error("get_summary_for_prompt() should not return an empty string")
		return false
	return true


func test_get_summary_for_prompt_contains_session_line() -> bool:
	var reg: SessionRegistry = _make_fresh()
	for _i in range(3):
		reg.record_decision(3000)
	var s: String = reg.get_summary_for_prompt()
	if "Session" not in s:
		push_error("get_summary_for_prompt() should contain 'Session', got: %s" % s)
		return false
	return true


func test_get_summary_for_prompt_mentions_frustration_when_set() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.wellness["frustration_detected"] = true
	var s: String = reg.get_summary_for_prompt()
	if "frustre" not in s and "frustration" not in s.to_lower():
		push_error("get_summary_for_prompt() should mention frustration. Got: %s" % s)
		return false
	return true


func test_get_summary_for_prompt_mentions_fatigue_when_set() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.wellness["fatigue_detected"] = true
	var s: String = reg.get_summary_for_prompt()
	if "fatigue" not in s.to_lower() and "fatigue" not in s:
		push_error("get_summary_for_prompt() should mention fatigue. Got: %s" % s)
		return false
	return true


func test_get_summary_for_prompt_mentions_tilt_when_set() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.wellness["tilt_detected"] = true
	var s: String = reg.get_summary_for_prompt()
	if "tilt" not in s.to_lower():
		push_error("get_summary_for_prompt() should mention tilt. Got: %s" % s)
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 14. LLM CONTEXT REFLECTS LIVE STATE
# ─────────────────────────────────────────────────────────────────────────────

func test_get_context_reflects_frustration_flag() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.wellness["frustration_detected"] = true
	var ctx: Dictionary = reg.get_context_for_llm()
	if not ctx.get("seems_frustrated", false):
		push_error("get_context_for_llm().seems_frustrated should be true")
		return false
	return true


func test_get_context_reflects_tilt_flag() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.wellness["tilt_detected"] = true
	var ctx: Dictionary = reg.get_context_for_llm()
	if not ctx.get("in_tilt", false):
		push_error("get_context_for_llm().in_tilt should be true")
		return false
	return true


func test_get_context_reflects_flow_flag() -> bool:
	var reg: SessionRegistry = _make_fresh()
	reg.wellness["positive_momentum"] = true
	var ctx: Dictionary = reg.get_context_for_llm()
	if not ctx.get("in_flow", false):
		push_error("get_context_for_llm().in_flow should be true")
		return false
	return true


func test_get_context_reflects_cards_count() -> bool:
	var reg: SessionRegistry = _make_fresh()
	for _i in range(7):
		reg.record_decision(3000)
	var ctx: Dictionary = reg.get_context_for_llm()
	if int(ctx.get("cards_this_session", -1)) != 7:
		push_error("get_context_for_llm().cards_this_session should be 7, got %s" % str(ctx.get("cards_this_session")))
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# 15. BOUNDARY VALUES
# ─────────────────────────────────────────────────────────────────────────────

func test_record_decision_zero_ms_is_rushed() -> bool:
	## 0ms is < RUSHED_DECISION_MS (1000) so it must count as rushed.
	var reg: SessionRegistry = _make_fresh()
	reg.record_decision(0)
	if reg.current["rushed_decisions"] != 1:
		push_error("record_decision(0) should count as rushed, got %d" % reg.current["rushed_decisions"])
		return false
	return true


func test_record_decision_exactly_10000ms_not_contemplated() -> bool:
	## Contemplated requires > 10000, so exactly 10000 must NOT count.
	var reg: SessionRegistry = _make_fresh()
	reg.record_decision(10000)
	if reg.current["contemplated_decisions"] != 0:
		push_error("record_decision(10000) should NOT count as contemplated (needs > 10000), got %d" % reg.current["contemplated_decisions"])
		return false
	return true


func test_session_length_minutes_non_negative() -> bool:
	var reg: SessionRegistry = _make_fresh()
	var minutes: float = reg.get_session_length_minutes()
	if minutes < 0.0:
		push_error("get_session_length_minutes() must be >= 0.0, got %f" % minutes)
		return false
	return true


func test_end_session_cards_played_matches_recorded_decisions() -> bool:
	var reg: SessionRegistry = _make_fresh()
	for _i in range(9):
		reg.record_decision(3000)
	var summary: Dictionary = reg.end_session()
	if int(summary.get("cards_played", -1)) != 9:
		push_error("summary.cards_played should be 9, got %s" % str(summary.get("cards_played")))
		return false
	return true
