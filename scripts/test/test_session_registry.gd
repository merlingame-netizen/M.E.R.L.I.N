## ═══════════════════════════════════════════════════════════════════════════════
## Test SessionRegistry — Pure unit tests (no Node, no file I/O, no scene tree)
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage: initialization, decision tracking, engagement, wellness, getters,
##           trend calculation, event recording, end-session summary.
## Run count: 22 tests.
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
	for i in range(25):
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
	for i in range(9):
		reg.record_decision(3000)
	if not is_equal_approx(reg.decision_time_trend, 0.0):
		push_error("Expected trend == 0.0 with < 10 decisions, got %f" % reg.decision_time_trend)
		return false
	return true


func test_trend_positive_when_slowing_down() -> bool:
	## Fill first 10 with fast decisions then 10 with slow; trend should be positive.
	var reg: SessionRegistry = _make_fresh()
	for i in range(10):
		reg.record_decision(1000)
	for i in range(10):
		reg.record_decision(9000)
	if reg.decision_time_trend <= 0.0:
		push_error("Expected positive trend when slowing down, got %f" % reg.decision_time_trend)
		return false
	return true


func test_trend_negative_when_speeding_up() -> bool:
	var reg: SessionRegistry = _make_fresh()
	for i in range(10):
		reg.record_decision(9000)
	for i in range(10):
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
	for i in range(4):
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
	for i in range(10):
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
	for i in range(51):
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
