## test_event_adapter.gd
## Unit tests for EventAdapter — RefCounted pattern, no GUT dependency.
## Covers: calendar context, weight factors (f_skill, f_pity, f_crisis,
##         f_conditions, f_fatigue, f_season, f_date_proximity), window logic,
##         fatigue/history management, helpers (_get_opposite_season,
##         _get_day_of_year), debug info, and reset.
##
## BYPASS strategy for disk-load:
##   EventAdapter has NO _init() disk load — plain instantiation is safe.
##   For tests requiring DifficultyAdapter, instantiate DifficultyAdapter
##   directly (it is also a plain RefCounted with no _init() side effects).
##
##   For tests exercising catalogue-dependent logic, inject _event_catalogue
##   directly with hand-crafted dictionaries to avoid file I/O.

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

## Returns a fresh EventAdapter with calendar set to a known safe date
## (day 180 = late June, season "summer") and an empty catalogue.
static func _make() -> EventAdapter:
	var ea: EventAdapter = EventAdapter.new()
	ea.update_calendar_context("summer", 6, 29, 180)
	# Leave _event_catalogue empty (no file I/O needed for most tests)
	return ea


## Returns a minimal game_context Dictionary for condition tests.
static func _make_ctx() -> Dictionary:
	return {
		"total_runs": 0,
		"cards_played": 0,
		"life_essence": 100,
		"faction_rep_delta": {},
		"factions": {},
		"flags": {},
		"karma": 0,
		"tension": 0,
		"trust_merlin": 0,
		"endings_seen_count": 0,
		"calendrier_des_brumes": false,
	}


## Returns a minimal event Dictionary with no conditions and a floating date.
static func _make_event(id: String, weight_base: float = 1.0) -> Dictionary:
	return {
		"id": id,
		"weight_base": weight_base,
		"date": "floating",
		"tags": [],
		"category": "neutral",
		"conditions": {},
	}


static func _approx_eq(a: float, b: float, epsilon: float = 0.001) -> bool:
	return absf(a - b) < epsilon


# ═══════════════════════════════════════════════════════════════════════════════
# 1. INITIALIZATION DEFAULTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_init_catalogue_empty() -> bool:
	var ea: EventAdapter = _make()
	if ea._event_catalogue.size() != 0:
		push_error("Fresh EventAdapter should have empty catalogue, got: " + str(ea._event_catalogue.size()))
		return false
	return true


func test_init_events_seen_empty() -> bool:
	var ea: EventAdapter = _make()
	if ea._events_seen.size() != 0:
		push_error("Fresh EventAdapter should have empty events_seen, got: " + str(ea._events_seen.size()))
		return false
	return true


func test_init_difficulty_adapter_null() -> bool:
	var ea: EventAdapter = _make()
	if ea.difficulty_adapter != null:
		push_error("difficulty_adapter should be null before setup()")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 2. CALENDAR CONTEXT UPDATE
# ═══════════════════════════════════════════════════════════════════════════════

func test_update_calendar_context_stores_values() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("winter", 12, 21, 355)
	var info: Dictionary = ea.get_debug_info()
	if info["current_season"] != "winter":
		push_error("Expected season 'winter', got: " + str(info["current_season"]))
		return false
	if info["current_month"] != 12:
		push_error("Expected month 12, got: " + str(info["current_month"]))
		return false
	if info["current_day"] != 21:
		push_error("Expected day 21, got: " + str(info["current_day"]))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 3. RESET
# ═══════════════════════════════════════════════════════════════════════════════

func test_reset_for_new_run_clears_events_seen() -> bool:
	var ea: EventAdapter = _make()
	ea.record_event("ev_001")
	ea.record_event("ev_002")
	ea.reset_for_new_run()
	if ea._events_seen.size() != 0:
		push_error("reset_for_new_run() should clear _events_seen, got size: " + str(ea._events_seen.size()))
		return false
	return true


func test_reset_for_new_run_clears_weight_log() -> bool:
	var ea: EventAdapter = _make()
	# Inject a log entry directly
	ea._weight_log.append({"event_id": "x", "weight_final": 1.0})
	ea.reset_for_new_run()
	if ea.get_weight_log().size() != 0:
		push_error("reset_for_new_run() should clear weight_log, got size: " + str(ea.get_weight_log().size()))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 4. RECORD EVENT & HISTORY TRIMMING
# ═══════════════════════════════════════════════════════════════════════════════

func test_record_event_appends_id() -> bool:
	var ea: EventAdapter = _make()
	ea.record_event("ev_abc")
	if ea._events_seen.size() != 1 or ea._events_seen[0] != "ev_abc":
		push_error("record_event should append the event id, got: " + str(ea._events_seen))
		return false
	return true


func test_record_event_trims_when_exceeds_50() -> bool:
	var ea: EventAdapter = _make()
	for i in range(52):
		ea.record_event("ev_%d" % i)
	# Trim triggers at 51 (slice to last 30), then 52nd append → size=31
	if ea._events_seen.size() > 31:
		push_error("_events_seen should be at most 31 after 52 records, got: " + str(ea._events_seen.size()))
		return false
	return true


func test_record_event_trim_keeps_most_recent() -> bool:
	var ea: EventAdapter = _make()
	for i in range(52):
		ea.record_event("ev_%d" % i)
	# The last recorded entry should be "ev_51" (most recent)
	if ea._events_seen[-1] != "ev_51":
		push_error("After trim, last entry should be most recent ev_51, got: " + str(ea._events_seen[-1]))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 5. _f_skill FACTOR
# ═══════════════════════════════════════════════════════════════════════════════

func test_f_skill_returns_1_when_no_adapter() -> bool:
	var ea: EventAdapter = _make()
	# difficulty_adapter is null -> factor must be 1.0
	var factor: float = ea._f_skill()
	if not _approx_eq(factor, 1.0):
		push_error("_f_skill with null adapter should return 1.0, got: " + str(factor))
		return false
	return true


func test_f_skill_novice_returns_1_2() -> bool:
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.player_skill = 0.0
	ea.difficulty_adapter = da
	var factor: float = ea._f_skill()
	if not _approx_eq(factor, 1.2):
		push_error("Skill 0.0 should give factor 1.2, got: " + str(factor))
		return false
	return true


func test_f_skill_master_returns_0_9() -> bool:
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.player_skill = 1.0
	ea.difficulty_adapter = da
	var factor: float = ea._f_skill()
	if not _approx_eq(factor, 0.9):
		push_error("Skill 1.0 should give factor 0.9, got: " + str(factor))
		return false
	return true


func test_f_skill_midpoint_returns_1_05() -> bool:
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.player_skill = 0.5
	ea.difficulty_adapter = da
	var factor: float = ea._f_skill()
	# lerpf(1.2, 0.9, 0.5) = 1.05
	if not _approx_eq(factor, 1.05):
		push_error("Skill 0.5 should give factor 1.05, got: " + str(factor))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 6. _f_pity FACTOR
# ═══════════════════════════════════════════════════════════════════════════════

func test_f_pity_returns_1_when_no_adapter() -> bool:
	var ea: EventAdapter = _make()
	var factor: float = ea._f_pity()
	if not _approx_eq(factor, 1.0):
		push_error("_f_pity with null adapter should return 1.0, got: " + str(factor))
		return false
	return true


func test_f_pity_returns_1_5_when_pity_active() -> bool:
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.pity_mode_active = true
	ea.difficulty_adapter = da
	var factor: float = ea._f_pity()
	if not _approx_eq(factor, 1.5):
		push_error("Pity mode active should give factor 1.5, got: " + str(factor))
		return false
	return true


func test_f_pity_scales_with_consecutive_deaths() -> bool:
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.pity_mode_active = false
	da.consecutive_deaths = 3
	ea.difficulty_adapter = da
	var factor: float = ea._f_pity()
	# 1.0 + 3 * 0.1 = 1.3
	if not _approx_eq(factor, 1.3):
		push_error("3 consecutive deaths should give factor 1.3, got: " + str(factor))
		return false
	return true


func test_f_pity_returns_1_with_zero_deaths() -> bool:
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.pity_mode_active = false
	da.consecutive_deaths = 0
	ea.difficulty_adapter = da
	var factor: float = ea._f_pity()
	if not _approx_eq(factor, 1.0):
		push_error("0 consecutive deaths with no pity should give factor 1.0, got: " + str(factor))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 7. _f_crisis FACTOR
# ═══════════════════════════════════════════════════════════════════════════════

func test_f_crisis_returns_1_no_stress() -> bool:
	var ea: EventAdapter = _make()
	var ctx: Dictionary = _make_ctx()
	var factor: float = ea._f_crisis(ctx)
	if not _approx_eq(factor, 1.0):
		push_error("No stress should give crisis factor 1.0, got: " + str(factor))
		return false
	return true


func test_f_crisis_returns_1_2_with_one_extreme_faction() -> bool:
	var ea: EventAdapter = _make()
	var ctx: Dictionary = _make_ctx()
	ctx["faction_rep_delta"] = {"druides": 16.0}  # absf > 15
	var factor: float = ea._f_crisis(ctx)
	if not _approx_eq(factor, 1.2):
		push_error("One extreme faction should give crisis factor 1.2, got: " + str(factor))
		return false
	return true


func test_f_crisis_returns_1_5_with_two_extremes() -> bool:
	var ea: EventAdapter = _make()
	var ctx: Dictionary = _make_ctx()
	ctx["faction_rep_delta"] = {"druides": 20.0, "ankou": -18.0}
	var factor: float = ea._f_crisis(ctx)
	if not _approx_eq(factor, 1.5):
		push_error("Two extreme factions should give crisis factor 1.5, got: " + str(factor))
		return false
	return true


func test_f_crisis_low_life_counts_as_one_extreme() -> bool:
	var ea: EventAdapter = _make()
	var ctx: Dictionary = _make_ctx()
	ctx["life_essence"] = 15  # < 20 threshold
	var factor: float = ea._f_crisis(ctx)
	# One extreme (life < 20) -> 1.2
	if not _approx_eq(factor, 1.2):
		push_error("Low life should count as one crisis extreme -> 1.2, got: " + str(factor))
		return false
	return true


func test_f_crisis_low_life_plus_faction_gives_1_5() -> bool:
	var ea: EventAdapter = _make()
	var ctx: Dictionary = _make_ctx()
	ctx["life_essence"] = 10
	ctx["faction_rep_delta"] = {"korrigans": 16.0}
	var factor: float = ea._f_crisis(ctx)
	if not _approx_eq(factor, 1.5):
		push_error("Low life + extreme faction should give 1.5, got: " + str(factor))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 8. _f_conditions — gate checks
# ═══════════════════════════════════════════════════════════════════════════════

func test_f_conditions_empty_conditions_passes() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_001")
	var ctx: Dictionary = _make_ctx()
	var factor: float = ea._f_conditions(ev, ctx)
	if not _approx_eq(factor, 1.0):
		push_error("Empty conditions should return 1.0, got: " + str(factor))
		return false
	return true


func test_f_conditions_min_run_not_met_returns_0() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_002")
	ev["conditions"] = {"min_run_index": 5}
	var ctx: Dictionary = _make_ctx()
	ctx["total_runs"] = 2
	var factor: float = ea._f_conditions(ev, ctx)
	if not _approx_eq(factor, 0.0):
		push_error("min_run_index 5 with only 2 runs should return 0.0, got: " + str(factor))
		return false
	return true


func test_f_conditions_min_run_met_passes() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_003")
	ev["conditions"] = {"min_run_index": 5}
	var ctx: Dictionary = _make_ctx()
	ctx["total_runs"] = 5
	var factor: float = ea._f_conditions(ev, ctx)
	if not _approx_eq(factor, 1.0):
		push_error("min_run_index 5 with 5 runs should return 1.0, got: " + str(factor))
		return false
	return true


func test_f_conditions_min_cards_not_met_returns_0() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_004")
	ev["conditions"] = {"min_cards_played": 20}
	var ctx: Dictionary = _make_ctx()
	ctx["cards_played"] = 10
	var factor: float = ea._f_conditions(ev, ctx)
	if not _approx_eq(factor, 0.0):
		push_error("min_cards_played 20 with 10 cards should return 0.0, got: " + str(factor))
		return false
	return true


func test_f_conditions_hidden_without_flag_returns_0() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_005")
	ev["conditions"] = {"hidden": true}
	var ctx: Dictionary = _make_ctx()
	ctx["calendrier_des_brumes"] = false
	var factor: float = ea._f_conditions(ev, ctx)
	if not _approx_eq(factor, 0.0):
		push_error("Hidden event without calendrier_des_brumes should return 0.0, got: " + str(factor))
		return false
	return true


func test_f_conditions_hidden_with_flag_passes() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_006")
	ev["conditions"] = {"hidden": true}
	var ctx: Dictionary = _make_ctx()
	ctx["calendrier_des_brumes"] = true
	var factor: float = ea._f_conditions(ev, ctx)
	if not _approx_eq(factor, 1.0):
		push_error("Hidden event with calendrier_des_brumes should return 1.0, got: " + str(factor))
		return false
	return true


func test_f_conditions_required_flag_missing_returns_0() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_007")
	ev["conditions"] = {"flags_required": ["special_unlock"]}
	var ctx: Dictionary = _make_ctx()
	# flags dict does not contain "special_unlock"
	var factor: float = ea._f_conditions(ev, ctx)
	if not _approx_eq(factor, 0.0):
		push_error("Missing required flag should return 0.0, got: " + str(factor))
		return false
	return true


func test_f_conditions_required_flag_present_passes() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_008")
	ev["conditions"] = {"flags_required": ["special_unlock"]}
	var ctx: Dictionary = _make_ctx()
	ctx["flags"] = {"special_unlock": true}
	var factor: float = ea._f_conditions(ev, ctx)
	if not _approx_eq(factor, 1.0):
		push_error("Present required flag should return 1.0, got: " + str(factor))
		return false
	return true


func test_f_conditions_life_below_blocks_when_life_too_high() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_009")
	ev["conditions"] = {"life_below": 30}
	var ctx: Dictionary = _make_ctx()
	ctx["life_essence"] = 50  # >= 30 -> blocked
	var factor: float = ea._f_conditions(ev, ctx)
	if not _approx_eq(factor, 0.0):
		push_error("life_below 30 with life 50 should return 0.0, got: " + str(factor))
		return false
	return true


func test_f_conditions_trust_merlin_above_blocks() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_010")
	ev["conditions"] = {"trust_merlin_above": 50}
	var ctx: Dictionary = _make_ctx()
	ctx["trust_merlin"] = 30  # < 50 -> blocked
	var factor: float = ea._f_conditions(ev, ctx)
	if not _approx_eq(factor, 0.0):
		push_error("trust_merlin_above 50 with trust 30 should return 0.0, got: " + str(factor))
		return false
	return true


func test_f_conditions_reputation_above_blocks() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_011")
	ev["conditions"] = {"reputation_above": {"druides": 60}}
	var ctx: Dictionary = _make_ctx()
	ctx["factions"] = {"druides": 40}  # < 60 -> blocked
	var factor: float = ea._f_conditions(ev, ctx)
	if not _approx_eq(factor, 0.0):
		push_error("reputation_above 60 with druides=40 should return 0.0, got: " + str(factor))
		return false
	return true


func test_f_conditions_season_wrong_blocks() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("summer", 6, 21, 172)
	var ev: Dictionary = _make_event("ev_012")
	ev["conditions"] = {"season": ["winter"]}
	var ctx: Dictionary = _make_ctx()
	var factor: float = ea._f_conditions(ev, ctx)
	if not _approx_eq(factor, 0.0):
		push_error("Season condition 'winter' with current season 'summer' should return 0.0, got: " + str(factor))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 9. _f_fatigue FACTOR
# ═══════════════════════════════════════════════════════════════════════════════

func test_f_fatigue_no_history_returns_1() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_fresh")
	var factor: float = ea._f_fatigue(ev)
	if not _approx_eq(factor, 1.0):
		push_error("No history should give fatigue factor 1.0, got: " + str(factor))
		return false
	return true


func test_f_fatigue_same_event_repeated_penalizes() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_repeat")
	ea._events_seen = ["ev_repeat", "ev_repeat", "ev_repeat"]
	var factor: float = ea._f_fatigue(ev)
	# Each same-id hit adds FATIGUE_PENALTY_PER_REPEAT * 2 = 0.30 each -> 0.90 penalty
	# factor = max(0.1, 1.0 - 0.90) = 0.1
	if factor >= 1.0:
		push_error("Repeated event should reduce fatigue factor below 1.0, got: " + str(factor))
		return false
	return true


func test_f_fatigue_clamped_at_0_1() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_spam")
	# Fill history with the same event ID (well beyond penalty cap)
	ea._events_seen = []
	for _i in range(10):
		ea._events_seen.append("ev_spam")
	var factor: float = ea._f_fatigue(ev)
	if factor < 0.1 - 0.001:
		push_error("Fatigue factor should be clamped at minimum 0.1, got: " + str(factor))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 10. _f_season FACTOR
# ═══════════════════════════════════════════════════════════════════════════════

func test_f_season_match_gives_1_15() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("winter", 1, 10, 10)
	var ev: Dictionary = _make_event("ev_winter")
	ev["tags"] = ["winter", "cold"]
	var factor: float = ea._f_season(ev)
	if not _approx_eq(factor, 1.15):
		push_error("Season match should give factor 1.15, got: " + str(factor))
		return false
	return true


func test_f_season_opposite_gives_0_85() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("winter", 1, 10, 10)
	var ev: Dictionary = _make_event("ev_summer")
	ev["tags"] = ["summer"]  # Opposite of winter
	var factor: float = ea._f_season(ev)
	if not _approx_eq(factor, 0.85):
		push_error("Opposite season tag should give factor 0.85, got: " + str(factor))
		return false
	return true


func test_f_season_neutral_gives_1_0() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("spring", 4, 5, 95)
	var ev: Dictionary = _make_event("ev_neutral")
	ev["tags"] = ["festival"]  # No season tag at all
	var factor: float = ea._f_season(ev)
	if not _approx_eq(factor, 1.0):
		push_error("No season tag should give factor 1.0, got: " + str(factor))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 11. _f_date_proximity FACTOR
# ═══════════════════════════════════════════════════════════════════════════════

func test_f_date_proximity_floating_returns_1() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_float")
	ev["date"] = "floating"
	var factor: float = ea._f_date_proximity(ev)
	if not _approx_eq(factor, 1.0):
		push_error("Floating date should give proximity factor 1.0, got: " + str(factor))
		return false
	return true


func test_f_date_proximity_null_date_returns_1() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_nodate")
	ev["date"] = null
	var factor: float = ea._f_date_proximity(ev)
	if not _approx_eq(factor, 1.0):
		push_error("Null date should give proximity factor 1.0, got: " + str(factor))
		return false
	return true


func test_f_date_proximity_exact_day_gives_max_bonus() -> bool:
	var ea: EventAdapter = _make()
	# Set current day to day 180 (June 29 approximately)
	ea.update_calendar_context("summer", 6, 29, 180)
	var ev: Dictionary = _make_event("ev_today")
	# Event date matches exactly: month=6, day=29 -> doy=180
	ev["date"] = {"month": 6, "day": 29}
	var factor: float = ea._f_date_proximity(ev)
	# diff = 0 -> t = 1.0 -> lerpf(1.0, 1.4, 1.0) = 1.4
	if not _approx_eq(factor, 1.4, 0.01):
		push_error("Exact date match should give max bonus 1.4, got: " + str(factor))
		return false
	return true


func test_f_date_proximity_far_away_returns_1() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("summer", 6, 1, 152)
	var ev: Dictionary = _make_event("ev_far")
	# Day of year for Dec 25 = ~359, diff = 359-152 = 207 > DATE_PROXIMITY_BONUS_DAYS
	ev["date"] = {"month": 12, "day": 25}
	var factor: float = ea._f_date_proximity(ev)
	if not _approx_eq(factor, 1.0):
		push_error("Far-away date should give factor 1.0, got: " + str(factor))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 12. _is_in_window HELPER
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_in_window_floating_always_true() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_float")
	ev["date"] = "floating"
	if not ea._is_in_window(ev):
		push_error("Floating date event should always be in window")
		return false
	return true


func test_is_in_window_null_date_always_true() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_null")
	ev["date"] = null
	if not ea._is_in_window(ev):
		push_error("Null date event should always be in window")
		return false
	return true


func test_is_in_window_fixed_date_within_3_days() -> bool:
	var ea: EventAdapter = _make()
	# Current day_of_year = 180, event doy = 182 (diff = 2 <= 3)
	ea.update_calendar_context("summer", 6, 29, 180)
	var ev: Dictionary = _make_event("ev_near")
	ev["date"] = {"month": 7, "day": 1}  # July 1 = doy 182
	if not ea._is_in_window(ev):
		push_error("Event 2 days away should be in window (tolerance = 3)")
		return false
	return true


func test_is_in_window_fixed_date_outside_tolerance() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("summer", 6, 1, 152)
	var ev: Dictionary = _make_event("ev_far_fixed")
	# Dec 25 = doy ~359, diff from 152 = 207 >> 3
	ev["date"] = {"month": 12, "day": 25}
	if ea._is_in_window(ev):
		push_error("Event 207 days away should NOT be in window")
		return false
	return true


func test_is_in_window_date_window_current_inside() -> bool:
	var ea: EventAdapter = _make()
	# Current day = 180 (late June)
	ea.update_calendar_context("summer", 6, 29, 180)
	var ev: Dictionary = _make_event("ev_window")
	ev["date"] = {"window": {"start_month": 6, "start_day": 1, "end_month": 8, "end_day": 31}}
	# Window doy: start = ~152, end = ~243; current 180 is inside
	if not ea._is_in_window(ev):
		push_error("Current day 180 should be inside window June-August")
		return false
	return true


func test_is_in_window_date_window_current_outside() -> bool:
	var ea: EventAdapter = _make()
	# Current day = 10 (January)
	ea.update_calendar_context("winter", 1, 10, 10)
	var ev: Dictionary = _make_event("ev_summer_window")
	ev["date"] = {"window": {"start_month": 6, "start_day": 1, "end_month": 8, "end_day": 31}}
	if ea._is_in_window(ev):
		push_error("Current day 10 (January) should NOT be inside summer window")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 13. _get_opposite_season HELPER
# ═══════════════════════════════════════════════════════════════════════════════

func test_opposite_season_winter_is_summer() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_opposite_season("winter") != "summer":
		push_error("Opposite of winter should be summer")
		return false
	return true


func test_opposite_season_summer_is_winter() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_opposite_season("summer") != "winter":
		push_error("Opposite of summer should be winter")
		return false
	return true


func test_opposite_season_spring_is_autumn() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_opposite_season("spring") != "autumn":
		push_error("Opposite of spring should be autumn")
		return false
	return true


func test_opposite_season_autumn_is_spring() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_opposite_season("autumn") != "spring":
		push_error("Opposite of autumn should be spring")
		return false
	return true


func test_opposite_season_unknown_returns_empty() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_opposite_season("monsoon") != "":
		push_error("Unknown season should return empty string")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 14. _get_day_of_year HELPER
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_day_of_year_jan_1_is_1() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_day_of_year(1, 1) != 1:
		push_error("Jan 1 should be day 1, got: " + str(ea._get_day_of_year(1, 1)))
		return false
	return true


func test_get_day_of_year_feb_1_is_32() -> bool:
	var ea: EventAdapter = _make()
	# January has 31 days -> Feb 1 = day 32
	if ea._get_day_of_year(2, 1) != 32:
		push_error("Feb 1 should be day 32, got: " + str(ea._get_day_of_year(2, 1)))
		return false
	return true


func test_get_day_of_year_dec_31_is_365() -> bool:
	var ea: EventAdapter = _make()
	# Sum of all months: 31+28+31+30+31+30+31+31+30+31+30 = 334 + 31 = 365
	if ea._get_day_of_year(12, 31) != 365:
		push_error("Dec 31 should be day 365, got: " + str(ea._get_day_of_year(12, 31)))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 15. GET_ACTIVE_EVENTS & SELECT_EVENT
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_active_events_empty_catalogue_returns_empty() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = []
	var results: Array = ea.get_active_events(_make_ctx())
	if results.size() != 0:
		push_error("Empty catalogue should yield no active events, got: " + str(results.size()))
		return false
	return true


func test_get_active_events_floating_event_included() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_float", 1.0)
	ea._event_catalogue = [ev]
	var results: Array = ea.get_active_events(_make_ctx())
	if results.size() != 1:
		push_error("Floating event with no conditions should appear in active events, got: " + str(results.size()))
		return false
	return true


func test_get_active_events_condition_blocked_event_excluded() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_locked", 1.0)
	ev["conditions"] = {"min_run_index": 100}  # impossible to meet
	ea._event_catalogue = [ev]
	var results: Array = ea.get_active_events(_make_ctx())
	if results.size() != 0:
		push_error("Condition-blocked event should not appear in active events, got: " + str(results.size()))
		return false
	return true


func test_get_active_events_sorted_by_weight_desc() -> bool:
	var ea: EventAdapter = _make()
	var ev_low: Dictionary = _make_event("ev_low", 0.5)
	var ev_high: Dictionary = _make_event("ev_high", 2.0)
	var ev_mid: Dictionary = _make_event("ev_mid", 1.0)
	ea._event_catalogue = [ev_low, ev_high, ev_mid]
	var results: Array = ea.get_active_events(_make_ctx())
	if results.size() != 3:
		push_error("All 3 events should be active, got: " + str(results.size()))
		return false
	if results[0]["event"]["id"] != "ev_high":
		push_error("Highest weight event should come first, got: " + str(results[0]["event"]["id"]))
		return false
	return true


func test_select_event_for_card_empty_catalogue_returns_empty() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = []
	var result: Dictionary = ea.select_event_for_card(_make_ctx())
	if not result.is_empty():
		push_error("Empty catalogue should return empty dict from select_event_for_card")
		return false
	return true


func test_select_event_for_card_single_event_always_selected() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_only", 1.0)
	ea._event_catalogue = [ev]
	var result: Dictionary = ea.select_event_for_card(_make_ctx())
	if result.is_empty():
		push_error("Single eligible event should always be selected")
		return false
	if result.get("id", "") != "ev_only":
		push_error("Wrong event selected, expected ev_only, got: " + str(result.get("id", "")))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 16. DEBUG INFO
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_debug_info_has_required_keys() -> bool:
	var ea: EventAdapter = _make()
	var info: Dictionary = ea.get_debug_info()
	for key in ["catalogue_size", "events_seen_count", "current_season",
				"current_day", "current_month", "weight_log_size"]:
		if not info.has(key):
			push_error("get_debug_info missing key: " + key)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var tests: Array[String] = [
		"test_init_catalogue_empty",
		"test_init_events_seen_empty",
		"test_init_difficulty_adapter_null",
		"test_update_calendar_context_stores_values",
		"test_reset_for_new_run_clears_events_seen",
		"test_reset_for_new_run_clears_weight_log",
		"test_record_event_appends_id",
		"test_record_event_trims_when_exceeds_50",
		"test_record_event_trim_keeps_most_recent",
		"test_f_skill_returns_1_when_no_adapter",
		"test_f_skill_novice_returns_1_2",
		"test_f_skill_master_returns_0_9",
		"test_f_skill_midpoint_returns_1_05",
		"test_f_pity_returns_1_when_no_adapter",
		"test_f_pity_returns_1_5_when_pity_active",
		"test_f_pity_scales_with_consecutive_deaths",
		"test_f_pity_returns_1_with_zero_deaths",
		"test_f_crisis_returns_1_no_stress",
		"test_f_crisis_returns_1_2_with_one_extreme_faction",
		"test_f_crisis_returns_1_5_with_two_extremes",
		"test_f_crisis_low_life_counts_as_one_extreme",
		"test_f_crisis_low_life_plus_faction_gives_1_5",
		"test_f_conditions_empty_conditions_passes",
		"test_f_conditions_min_run_not_met_returns_0",
		"test_f_conditions_min_run_met_passes",
		"test_f_conditions_min_cards_not_met_returns_0",
		"test_f_conditions_hidden_without_flag_returns_0",
		"test_f_conditions_hidden_with_flag_passes",
		"test_f_conditions_required_flag_missing_returns_0",
		"test_f_conditions_required_flag_present_passes",
		"test_f_conditions_life_below_blocks_when_life_too_high",
		"test_f_conditions_trust_merlin_above_blocks",
		"test_f_conditions_reputation_above_blocks",
		"test_f_conditions_season_wrong_blocks",
		"test_f_fatigue_no_history_returns_1",
		"test_f_fatigue_same_event_repeated_penalizes",
		"test_f_fatigue_clamped_at_0_1",
		"test_f_season_match_gives_1_15",
		"test_f_season_opposite_gives_0_85",
		"test_f_season_neutral_gives_1_0",
		"test_f_date_proximity_floating_returns_1",
		"test_f_date_proximity_null_date_returns_1",
		"test_f_date_proximity_exact_day_gives_max_bonus",
		"test_f_date_proximity_far_away_returns_1",
		"test_is_in_window_floating_always_true",
		"test_is_in_window_null_date_always_true",
		"test_is_in_window_fixed_date_within_3_days",
		"test_is_in_window_fixed_date_outside_tolerance",
		"test_is_in_window_date_window_current_inside",
		"test_is_in_window_date_window_current_outside",
		"test_opposite_season_winter_is_summer",
		"test_opposite_season_summer_is_winter",
		"test_opposite_season_spring_is_autumn",
		"test_opposite_season_autumn_is_spring",
		"test_opposite_season_unknown_returns_empty",
		"test_get_day_of_year_jan_1_is_1",
		"test_get_day_of_year_feb_1_is_32",
		"test_get_day_of_year_dec_31_is_365",
		"test_get_active_events_empty_catalogue_returns_empty",
		"test_get_active_events_floating_event_included",
		"test_get_active_events_condition_blocked_event_excluded",
		"test_get_active_events_sorted_by_weight_desc",
		"test_select_event_for_card_empty_catalogue_returns_empty",
		"test_select_event_for_card_single_event_always_selected",
		"test_get_debug_info_has_required_keys",
	]
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []
	for test_name in tests:
		var result: bool = call(test_name)
		if result:
			passed += 1
		else:
			failed += 1
			failures.append(test_name)
	return {
		"total": tests.size(),
		"passed": passed,
		"failed": failed,
		"failures": failures,
	}
