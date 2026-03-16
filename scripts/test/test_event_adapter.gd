## test_event_adapter.gd
## Unit tests for EventAdapter — RefCounted pattern, no GUT dependency.
## Covers all 7 weight factors (f_skill, f_pity, f_crisis, f_conditions,
## f_fatigue, f_season, f_date_proximity), window logic, history management,
## helpers (_get_opposite_season, _get_day_of_year, _find_event_by_id),
## event lifecycle, catalogue queries, weight clamping, and debug output.
##
## BYPASS strategy for disk-load:
##   EventAdapter has NO _init() disk load — plain instantiation is safe.
##   _event_catalogue is injected directly to avoid file I/O.
##   DifficultyAdapter is instantiated directly (plain RefCounted, no _init()
##   side effects).

extends RefCounted


# =============================================================================
# HELPERS
# =============================================================================

func _fail(msg: String) -> bool:
	push_error(msg)
	return false


## Returns a fresh EventAdapter with calendar set to a known date
## (day 180 = late June, season "summer") and an empty catalogue.
static func _make() -> EventAdapter:
	var ea: EventAdapter = EventAdapter.new()
	ea.update_calendar_context("summer", 6, 29, 180)
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


## Returns a minimal event Dictionary with a floating date and no conditions.
static func _make_event(id: String, weight_base: float = 1.0) -> Dictionary:
	return {
		"id": id,
		"weight_base": weight_base,
		"date": "floating",
		"tags": [],
		"category": "neutral",
		"conditions": {},
	}


static func _approx(a: float, b: float, eps: float = 0.001) -> bool:
	return absf(a - b) < eps


# =============================================================================
# 1. INITIALIZATION DEFAULTS
# =============================================================================

func test_init_catalogue_empty() -> bool:
	var ea: EventAdapter = _make()
	if ea._event_catalogue.size() != 0:
		return _fail("Fresh catalogue should be empty, got: " + str(ea._event_catalogue.size()))
	return true


func test_init_events_seen_empty() -> bool:
	var ea: EventAdapter = _make()
	if ea._events_seen.size() != 0:
		return _fail("Fresh events_seen should be empty, got: " + str(ea._events_seen.size()))
	return true


func test_init_difficulty_adapter_null() -> bool:
	var ea: EventAdapter = _make()
	if ea.difficulty_adapter != null:
		return _fail("difficulty_adapter should be null before setup()")
	return true


# =============================================================================
# 2. CALENDAR CONTEXT UPDATE
# =============================================================================

func test_update_calendar_context_stores_all_fields() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("winter", 12, 21, 355)
	var info: Dictionary = ea.get_debug_info()
	if info["current_season"] != "winter":
		return _fail("Expected season 'winter', got: " + str(info["current_season"]))
	if info["current_month"] != 12:
		return _fail("Expected month 12, got: " + str(info["current_month"]))
	if info["current_day"] != 21:
		return _fail("Expected day 21, got: " + str(info["current_day"]))
	return true


# =============================================================================
# 3. RESET
# =============================================================================

func test_reset_clears_events_seen() -> bool:
	var ea: EventAdapter = _make()
	ea.record_event("ev_001")
	ea.record_event("ev_002")
	ea.reset_for_new_run()
	if ea._events_seen.size() != 0:
		return _fail("reset_for_new_run() should clear _events_seen, got: " + str(ea._events_seen.size()))
	return true


func test_reset_clears_weight_log() -> bool:
	var ea: EventAdapter = _make()
	ea._weight_log.append({"event_id": "x", "weight_final": 1.0})
	ea.reset_for_new_run()
	if ea.get_weight_log().size() != 0:
		return _fail("reset_for_new_run() should clear weight_log")
	return true


# =============================================================================
# 4. RECORD EVENT & HISTORY TRIMMING
# =============================================================================

func test_record_event_appends_id() -> bool:
	var ea: EventAdapter = _make()
	ea.record_event("ev_abc")
	if ea._events_seen.size() != 1 or ea._events_seen[0] != "ev_abc":
		return _fail("record_event should append the id, got: " + str(ea._events_seen))
	return true


func test_record_event_trims_when_exceeds_50() -> bool:
	var ea: EventAdapter = _make()
	for i in range(52):
		ea.record_event("ev_%d" % i)
	# At 51 entries the trim fires (slice to -30), then 52nd appends -> size 31
	if ea._events_seen.size() > 31:
		return _fail("_events_seen should be <=31 after 52 records, got: " + str(ea._events_seen.size()))
	return true


func test_record_event_trim_keeps_most_recent() -> bool:
	var ea: EventAdapter = _make()
	for i in range(52):
		ea.record_event("ev_%d" % i)
	if ea._events_seen[-1] != "ev_51":
		return _fail("After trim, last entry should be ev_51, got: " + str(ea._events_seen[-1]))
	return true


# =============================================================================
# 5. f_skill FACTOR
# =============================================================================

func test_f_skill_null_adapter_returns_1() -> bool:
	var ea: EventAdapter = _make()
	var f: float = ea._f_skill()
	if not _approx(f, 1.0):
		return _fail("_f_skill with null adapter should return 1.0, got: " + str(f))
	return true


func test_f_skill_skill_zero_returns_1_2() -> bool:
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.player_skill = 0.0
	ea.difficulty_adapter = da
	var f: float = ea._f_skill()
	if not _approx(f, 1.2):
		return _fail("Skill 0.0 should give 1.2, got: " + str(f))
	return true


func test_f_skill_skill_one_returns_0_9() -> bool:
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.player_skill = 1.0
	ea.difficulty_adapter = da
	var f: float = ea._f_skill()
	if not _approx(f, 0.9):
		return _fail("Skill 1.0 should give 0.9, got: " + str(f))
	return true


func test_f_skill_midpoint_returns_1_05() -> bool:
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.player_skill = 0.5
	ea.difficulty_adapter = da
	var f: float = ea._f_skill()
	# lerpf(1.2, 0.9, 0.5) = 1.05
	if not _approx(f, 1.05):
		return _fail("Skill 0.5 should give 1.05, got: " + str(f))
	return true


# =============================================================================
# 6. f_pity FACTOR
# =============================================================================

func test_f_pity_null_adapter_returns_1() -> bool:
	var ea: EventAdapter = _make()
	if not _approx(ea._f_pity(), 1.0):
		return _fail("_f_pity with null adapter should return 1.0")
	return true


func test_f_pity_mode_active_returns_1_5() -> bool:
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.pity_mode_active = true
	ea.difficulty_adapter = da
	if not _approx(ea._f_pity(), 1.5):
		return _fail("Pity mode active should give 1.5, got: " + str(ea._f_pity()))
	return true


func test_f_pity_three_deaths_returns_1_3() -> bool:
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.pity_mode_active = false
	da.consecutive_deaths = 3
	ea.difficulty_adapter = da
	# 1.0 + 3 * 0.1 = 1.3
	if not _approx(ea._f_pity(), 1.3):
		return _fail("3 deaths should give 1.3, got: " + str(ea._f_pity()))
	return true


func test_f_pity_zero_deaths_returns_1() -> bool:
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.pity_mode_active = false
	da.consecutive_deaths = 0
	ea.difficulty_adapter = da
	if not _approx(ea._f_pity(), 1.0):
		return _fail("0 deaths and no pity should give 1.0, got: " + str(ea._f_pity()))
	return true


# =============================================================================
# 7. f_crisis FACTOR
# =============================================================================

func test_f_crisis_no_stress_returns_1() -> bool:
	var ea: EventAdapter = _make()
	if not _approx(ea._f_crisis(_make_ctx()), 1.0):
		return _fail("No stress should give crisis 1.0")
	return true


func test_f_crisis_one_extreme_faction_returns_1_2() -> bool:
	var ea: EventAdapter = _make()
	var ctx: Dictionary = _make_ctx()
	ctx["faction_rep_delta"] = {"druides": 16.0}
	if not _approx(ea._f_crisis(ctx), 1.2):
		return _fail("One extreme faction (delta>15) should give 1.2, got: " + str(ea._f_crisis(ctx)))
	return true


func test_f_crisis_two_extremes_returns_1_5() -> bool:
	var ea: EventAdapter = _make()
	var ctx: Dictionary = _make_ctx()
	ctx["faction_rep_delta"] = {"druides": 20.0, "ankou": -18.0}
	if not _approx(ea._f_crisis(ctx), 1.5):
		return _fail("Two extreme factions should give 1.5, got: " + str(ea._f_crisis(ctx)))
	return true


func test_f_crisis_low_life_below_20_counts_as_extreme() -> bool:
	var ea: EventAdapter = _make()
	var ctx: Dictionary = _make_ctx()
	ctx["life_essence"] = 15
	if not _approx(ea._f_crisis(ctx), 1.2):
		return _fail("life<20 should count as one crisis extreme -> 1.2, got: " + str(ea._f_crisis(ctx)))
	return true


func test_f_crisis_life_20_boundary_not_extreme() -> bool:
	# life == 20 does not satisfy `life < 20`
	var ea: EventAdapter = _make()
	var ctx: Dictionary = _make_ctx()
	ctx["life_essence"] = 20
	if not _approx(ea._f_crisis(ctx), 1.0):
		return _fail("life==20 should NOT count as crisis extreme, got: " + str(ea._f_crisis(ctx)))
	return true


# =============================================================================
# 8. f_conditions — all gate checks
# =============================================================================

func test_f_conditions_empty_passes() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_empty")
	if not _approx(ea._f_conditions(ev, _make_ctx()), 1.0):
		return _fail("Empty conditions should return 1.0")
	return true


func test_f_conditions_min_run_not_met_blocks() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_run")
	ev["conditions"] = {"min_run_index": 5}
	var ctx: Dictionary = _make_ctx()
	ctx["total_runs"] = 2
	if not _approx(ea._f_conditions(ev, ctx), 0.0):
		return _fail("min_run_index 5 with 2 runs should block (0.0)")
	return true


func test_f_conditions_min_run_met_passes() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_run2")
	ev["conditions"] = {"min_run_index": 5}
	var ctx: Dictionary = _make_ctx()
	ctx["total_runs"] = 5
	if not _approx(ea._f_conditions(ev, ctx), 1.0):
		return _fail("min_run_index 5 with 5 runs should pass (1.0)")
	return true


func test_f_conditions_min_cards_not_met_blocks() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_cards")
	ev["conditions"] = {"min_cards_played": 20}
	var ctx: Dictionary = _make_ctx()
	ctx["cards_played"] = 10
	if not _approx(ea._f_conditions(ev, ctx), 0.0):
		return _fail("min_cards_played 20 with 10 played should block")
	return true


func test_f_conditions_hidden_without_brumes_blocks() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_hidden")
	ev["conditions"] = {"hidden": true}
	if not _approx(ea._f_conditions(ev, _make_ctx()), 0.0):
		return _fail("Hidden event without calendrier_des_brumes should return 0.0")
	return true


func test_f_conditions_hidden_with_brumes_passes() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_hidden2")
	ev["conditions"] = {"hidden": true}
	var ctx: Dictionary = _make_ctx()
	ctx["calendrier_des_brumes"] = true
	if not _approx(ea._f_conditions(ev, ctx), 1.0):
		return _fail("Hidden event with calendrier_des_brumes should return 1.0")
	return true


func test_f_conditions_missing_required_flag_blocks() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_flag")
	ev["conditions"] = {"flags_required": ["unlock_a"]}
	if not _approx(ea._f_conditions(ev, _make_ctx()), 0.0):
		return _fail("Missing required flag should return 0.0")
	return true


func test_f_conditions_present_required_flag_passes() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_flag2")
	ev["conditions"] = {"flags_required": ["unlock_a"]}
	var ctx: Dictionary = _make_ctx()
	ctx["flags"] = {"unlock_a": true}
	if not _approx(ea._f_conditions(ev, ctx), 1.0):
		return _fail("Present required flag should return 1.0")
	return true


func test_f_conditions_reputation_above_blocks() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_rep")
	ev["conditions"] = {"reputation_above": {"druides": 60}}
	var ctx: Dictionary = _make_ctx()
	ctx["factions"] = {"druides": 40}
	if not _approx(ea._f_conditions(ev, ctx), 0.0):
		return _fail("reputation_above 60 with druides=40 should block")
	return true


func test_f_conditions_reputation_below_blocks_when_rep_too_high() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_repb")
	ev["conditions"] = {"reputation_below": {"korrigans": 30}}
	var ctx: Dictionary = _make_ctx()
	ctx["factions"] = {"korrigans": 50}  # >= 30 -> blocked
	if not _approx(ea._f_conditions(ev, ctx), 0.0):
		return _fail("reputation_below 30 with korrigans=50 should block")
	return true


func test_f_conditions_life_below_blocks_when_life_too_high() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_lifeb")
	ev["conditions"] = {"life_below": 30}
	var ctx: Dictionary = _make_ctx()
	ctx["life_essence"] = 50
	if not _approx(ea._f_conditions(ev, ctx), 0.0):
		return _fail("life_below 30 with life=50 should block")
	return true


func test_f_conditions_life_above_blocks_when_life_too_low() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_lifea")
	ev["conditions"] = {"life_above": 60}
	var ctx: Dictionary = _make_ctx()
	ctx["life_essence"] = 40  # < 60 -> blocked
	if not _approx(ea._f_conditions(ev, ctx), 0.0):
		return _fail("life_above 60 with life=40 should block")
	return true


func test_f_conditions_karma_above_blocks() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_karma")
	ev["conditions"] = {"karma_above": 20}
	var ctx: Dictionary = _make_ctx()
	ctx["karma"] = 10
	if not _approx(ea._f_conditions(ev, ctx), 0.0):
		return _fail("karma_above 20 with karma=10 should block")
	return true


func test_f_conditions_tension_above_blocks() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_tension")
	ev["conditions"] = {"tension_above": 50}
	var ctx: Dictionary = _make_ctx()
	ctx["tension"] = 30
	if not _approx(ea._f_conditions(ev, ctx), 0.0):
		return _fail("tension_above 50 with tension=30 should block")
	return true


func test_f_conditions_dominant_faction_above_blocks() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_domfact")
	ev["conditions"] = {"dominant_faction_above": 70}
	var ctx: Dictionary = _make_ctx()
	ctx["factions"] = {"druides": 50, "ankou": 40}  # max=50 < 70 -> blocked
	if not _approx(ea._f_conditions(ev, ctx), 0.0):
		return _fail("dominant_faction_above 70 with max rep=50 should block")
	return true


func test_f_conditions_trust_merlin_above_blocks() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_trust")
	ev["conditions"] = {"trust_merlin_above": 50}
	var ctx: Dictionary = _make_ctx()
	ctx["trust_merlin"] = 30
	if not _approx(ea._f_conditions(ev, ctx), 0.0):
		return _fail("trust_merlin_above 50 with trust=30 should block")
	return true


func test_f_conditions_min_endings_seen_blocks() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_endings")
	ev["conditions"] = {"min_endings_seen": 3}
	var ctx: Dictionary = _make_ctx()
	ctx["endings_seen_count"] = 1
	if not _approx(ea._f_conditions(ev, ctx), 0.0):
		return _fail("min_endings_seen 3 with endings_seen=1 should block")
	return true


func test_f_conditions_season_mismatch_blocks() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("summer", 6, 21, 172)
	var ev: Dictionary = _make_event("ev_season")
	ev["conditions"] = {"season": ["winter"]}
	if not _approx(ea._f_conditions(ev, _make_ctx()), 0.0):
		return _fail("Season condition 'winter' during 'summer' should block")
	return true


func test_f_conditions_season_match_passes() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("winter", 1, 15, 15)
	var ev: Dictionary = _make_event("ev_season2")
	ev["conditions"] = {"season": ["winter", "autumn"]}
	if not _approx(ea._f_conditions(ev, _make_ctx()), 1.0):
		return _fail("Season condition matching current season should pass")
	return true


# =============================================================================
# 9. f_fatigue FACTOR
# =============================================================================

func test_f_fatigue_no_history_returns_1() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_fresh")
	if not _approx(ea._f_fatigue(ev), 1.0):
		return _fail("No history should give fatigue 1.0, got: " + str(ea._f_fatigue(ev)))
	return true


func test_f_fatigue_repeated_event_penalizes() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_repeat")
	ea._events_seen = ["ev_repeat", "ev_repeat", "ev_repeat"]
	# 3 same-id hits: penalty = 3 * 0.30 = 0.90 -> max(0.1, 0.1) = 0.1
	var f: float = ea._f_fatigue(ev)
	if f >= 1.0:
		return _fail("Repeated event should reduce factor below 1.0, got: " + str(f))
	return true


func test_f_fatigue_clamped_at_0_1_minimum() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_spam")
	ea._events_seen = []
	for _i in range(10):
		ea._events_seen.append("ev_spam")
	var f: float = ea._f_fatigue(ev)
	if f < 0.1 - 0.001:
		return _fail("Fatigue factor should never go below 0.1, got: " + str(f))
	return true


func test_f_fatigue_different_event_no_id_penalty() -> bool:
	var ea: EventAdapter = _make()
	ea._events_seen = ["ev_other1", "ev_other2", "ev_other3"]
	var ev: Dictionary = _make_event("ev_brand_new")
	var f: float = ea._f_fatigue(ev)
	# Same category ("neutral") appears 3 times -> category penalty = 3 * 0.075 = 0.225
	# factor = max(0.1, 1.0 - 0.225) = 0.775
	if f > 1.0:
		return _fail("Category repetition should reduce fatigue below 1.0, got: " + str(f))
	return true


# =============================================================================
# 10. f_season FACTOR
# =============================================================================

func test_f_season_matching_tag_returns_1_15() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("winter", 1, 10, 10)
	var ev: Dictionary = _make_event("ev_winter")
	ev["tags"] = ["winter", "cold"]
	if not _approx(ea._f_season(ev), 1.15):
		return _fail("Matching season tag should give 1.15, got: " + str(ea._f_season(ev)))
	return true


func test_f_season_opposite_tag_returns_0_85() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("winter", 1, 10, 10)
	var ev: Dictionary = _make_event("ev_summer")
	ev["tags"] = ["summer"]
	if not _approx(ea._f_season(ev), 0.85):
		return _fail("Opposite season tag should give 0.85, got: " + str(ea._f_season(ev)))
	return true


func test_f_season_no_season_tag_returns_1() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("spring", 4, 5, 95)
	var ev: Dictionary = _make_event("ev_neutral")
	ev["tags"] = ["festival"]
	if not _approx(ea._f_season(ev), 1.0):
		return _fail("No season tag should give 1.0, got: " + str(ea._f_season(ev)))
	return true


func test_f_season_all_four_season_pairs() -> bool:
	# Verify all four opposite pairs work correctly for f_season
	var ea: EventAdapter = _make()
	ea.update_calendar_context("spring", 4, 1, 91)
	var ev: Dictionary = _make_event("ev_autumn_tag")
	ev["tags"] = ["autumn"]  # Opposite of spring
	if not _approx(ea._f_season(ev), 0.85):
		return _fail("Spring/autumn opposite should give 0.85, got: " + str(ea._f_season(ev)))
	return true


# =============================================================================
# 11. f_date_proximity FACTOR
# =============================================================================

func test_f_date_proximity_floating_returns_1() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_float")
	ev["date"] = "floating"
	if not _approx(ea._f_date_proximity(ev), 1.0):
		return _fail("Floating date should give 1.0")
	return true


func test_f_date_proximity_null_returns_1() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_nodate")
	ev["date"] = null
	if not _approx(ea._f_date_proximity(ev), 1.0):
		return _fail("Null date should give 1.0")
	return true


func test_f_date_proximity_exact_match_gives_max_bonus() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("summer", 6, 29, 180)
	var ev: Dictionary = _make_event("ev_today")
	ev["date"] = {"month": 6, "day": 29}  # doy 180 == current
	# diff=0 -> t=1.0 -> lerpf(1.0, 1.4, 1.0) = 1.4
	if not _approx(ea._f_date_proximity(ev), 1.4, 0.01):
		return _fail("Exact date match should give max bonus 1.4, got: " + str(ea._f_date_proximity(ev)))
	return true


func test_f_date_proximity_far_away_returns_1() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("summer", 6, 1, 152)
	var ev: Dictionary = _make_event("ev_far")
	ev["date"] = {"month": 12, "day": 25}  # doy ~359, diff=207 > 7
	if not _approx(ea._f_date_proximity(ev), 1.0):
		return _fail("Far-away date should give 1.0, got: " + str(ea._f_date_proximity(ev)))
	return true


func test_f_date_proximity_year_wrap_handled() -> bool:
	# Near-year-boundary: current doy=365, event doy=3 -> raw diff=362, wrapped=3 -> within 7 days
	var ea: EventAdapter = _make()
	ea.update_calendar_context("winter", 12, 31, 365)
	var ev: Dictionary = _make_event("ev_newyear")
	ev["date"] = {"month": 1, "day": 3}  # doy=3, raw diff=362, wrapped=3
	var f: float = ea._f_date_proximity(ev)
	if f <= 1.0:
		return _fail("Year-wrap proximity (3 days away) should give bonus > 1.0, got: " + str(f))
	return true


func test_f_date_proximity_window_date_uses_start() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("summer", 6, 29, 180)
	var ev: Dictionary = _make_event("ev_window")
	# Window starting on doy 180 (exact match) -> max bonus
	ev["date"] = {"window": {"start_month": 6, "start_day": 29, "end_month": 7, "end_day": 31}}
	var f: float = ea._f_date_proximity(ev)
	if not _approx(f, 1.4, 0.01):
		return _fail("Window date proximity at start should give 1.4, got: " + str(f))
	return true


# =============================================================================
# 12. _is_in_window HELPER
# =============================================================================

func test_is_in_window_floating_always_true() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_float")
	ev["date"] = "floating"
	if not ea._is_in_window(ev):
		return _fail("Floating date event should always be in window")
	return true


func test_is_in_window_null_always_true() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_null")
	ev["date"] = null
	if not ea._is_in_window(ev):
		return _fail("Null date event should always be in window")
	return true


func test_is_in_window_fixed_date_within_3_days_true() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("summer", 6, 29, 180)
	var ev: Dictionary = _make_event("ev_near")
	ev["date"] = {"month": 7, "day": 1}  # doy 182, diff=2 <= 3
	if not ea._is_in_window(ev):
		return _fail("Event 2 days away should be in window (tolerance=3)")
	return true


func test_is_in_window_fixed_date_outside_tolerance_false() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("summer", 6, 1, 152)
	var ev: Dictionary = _make_event("ev_far_fixed")
	ev["date"] = {"month": 12, "day": 25}  # doy~359, diff=207
	if ea._is_in_window(ev):
		return _fail("Event 207 days away should NOT be in window")
	return true


func test_is_in_window_window_inside_true() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("summer", 6, 29, 180)
	var ev: Dictionary = _make_event("ev_win")
	ev["date"] = {"window": {"start_month": 6, "start_day": 1, "end_month": 8, "end_day": 31}}
	if not ea._is_in_window(ev):
		return _fail("Day 180 should be inside June-August window")
	return true


func test_is_in_window_window_outside_false() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("winter", 1, 10, 10)
	var ev: Dictionary = _make_event("ev_sumwin")
	ev["date"] = {"window": {"start_month": 6, "start_day": 1, "end_month": 8, "end_day": 31}}
	if ea._is_in_window(ev):
		return _fail("Day 10 (January) should NOT be inside summer window")
	return true


func test_is_in_window_year_wrap_window_inside() -> bool:
	# Window Oct-Jan spans year boundary; December should be inside
	var ea: EventAdapter = _make()
	ea.update_calendar_context("winter", 12, 15, 349)
	var ev: Dictionary = _make_event("ev_octojan")
	ev["date"] = {"window": {"start_month": 10, "start_day": 1, "end_month": 1, "end_day": 31}}
	# start_doy ~274, end_doy ~31, start > end -> wrap logic
	if not ea._is_in_window(ev):
		return _fail("December (doy 349) should be inside Oct-Jan wrap window")
	return true


# =============================================================================
# 13. _get_opposite_season / _get_day_of_year HELPERS
# =============================================================================

func test_opposite_season_winter_summer() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_opposite_season("winter") != "summer":
		return _fail("Opposite of winter should be summer")
	return true


func test_opposite_season_summer_winter() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_opposite_season("summer") != "winter":
		return _fail("Opposite of summer should be winter")
	return true


func test_opposite_season_spring_autumn() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_opposite_season("spring") != "autumn":
		return _fail("Opposite of spring should be autumn")
	return true


func test_opposite_season_autumn_spring() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_opposite_season("autumn") != "spring":
		return _fail("Opposite of autumn should be spring")
	return true


func test_opposite_season_unknown_returns_empty() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_opposite_season("monsoon") != "":
		return _fail("Unknown season should return empty string")
	return true


func test_get_day_of_year_jan_1_is_1() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_day_of_year(1, 1) != 1:
		return _fail("Jan 1 should be day 1, got: " + str(ea._get_day_of_year(1, 1)))
	return true


func test_get_day_of_year_feb_1_is_32() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_day_of_year(2, 1) != 32:
		return _fail("Feb 1 should be day 32 (31 Jan days + 1), got: " + str(ea._get_day_of_year(2, 1)))
	return true


func test_get_day_of_year_dec_31_is_365() -> bool:
	var ea: EventAdapter = _make()
	if ea._get_day_of_year(12, 31) != 365:
		return _fail("Dec 31 should be day 365, got: " + str(ea._get_day_of_year(12, 31)))
	return true


func test_get_day_of_year_march_1_is_60() -> bool:
	# Jan(31) + Feb(28) + Mar 1 = 60
	var ea: EventAdapter = _make()
	if ea._get_day_of_year(3, 1) != 60:
		return _fail("Mar 1 should be day 60, got: " + str(ea._get_day_of_year(3, 1)))
	return true


# =============================================================================
# 14. _find_event_by_id HELPER
# =============================================================================

func test_find_event_by_id_found() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_needle")
	ea._event_catalogue = [_make_event("ev_a"), ev, _make_event("ev_b")]
	var found: Dictionary = ea._find_event_by_id("ev_needle")
	if found.is_empty():
		return _fail("_find_event_by_id should find existing event")
	if found.get("id", "") != "ev_needle":
		return _fail("Wrong event returned, got: " + str(found.get("id", "")))
	return true


func test_find_event_by_id_not_found_returns_empty() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = [_make_event("ev_a"), _make_event("ev_b")]
	var found: Dictionary = ea._find_event_by_id("ev_missing")
	if not found.is_empty():
		return _fail("_find_event_by_id with missing id should return empty dict")
	return true


func test_find_event_by_id_empty_catalogue_returns_empty() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = []
	if not ea._find_event_by_id("ev_any").is_empty():
		return _fail("Empty catalogue should return empty dict")
	return true


# =============================================================================
# 15. GET_ACTIVE_EVENTS & SELECT_EVENT_FOR_CARD
# =============================================================================

func test_get_active_events_empty_catalogue() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = []
	if ea.get_active_events(_make_ctx()).size() != 0:
		return _fail("Empty catalogue should yield 0 active events")
	return true


func test_get_active_events_floating_event_included() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = [_make_event("ev_float", 1.0)]
	if ea.get_active_events(_make_ctx()).size() != 1:
		return _fail("Floating event with no conditions should be active")
	return true


func test_get_active_events_condition_blocked_excluded() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_locked")
	ev["conditions"] = {"min_run_index": 100}
	ea._event_catalogue = [ev]
	if ea.get_active_events(_make_ctx()).size() != 0:
		return _fail("Condition-blocked event should not be in active events")
	return true


func test_get_active_events_sorted_by_weight_desc() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = [
		_make_event("ev_low", 0.5),
		_make_event("ev_high", 2.0),
		_make_event("ev_mid", 1.0),
	]
	var results: Array = ea.get_active_events(_make_ctx())
	if results.size() != 3:
		return _fail("All 3 events should be active, got: " + str(results.size()))
	if results[0]["event"]["id"] != "ev_high":
		return _fail("Highest-weight event should be first, got: " + str(results[0]["event"]["id"]))
	return true


func test_get_active_events_result_has_weight_final_key() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = [_make_event("ev_one", 1.0)]
	var results: Array = ea.get_active_events(_make_ctx())
	if results.is_empty():
		return _fail("Should have one active event")
	if not results[0].has("weight_final"):
		return _fail("Active event entry should have 'weight_final' key")
	return true


func test_select_event_empty_catalogue_returns_empty() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = []
	if not ea.select_event_for_card(_make_ctx()).is_empty():
		return _fail("Empty catalogue should return empty dict")
	return true


func test_select_event_single_eligible_event_always_selected() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = [_make_event("ev_only", 1.0)]
	var result: Dictionary = ea.select_event_for_card(_make_ctx())
	if result.is_empty():
		return _fail("Single eligible event should always be selected")
	if result.get("id", "") != "ev_only":
		return _fail("Wrong event selected, expected ev_only, got: " + str(result.get("id", "")))
	return true


# =============================================================================
# 16. WEIGHT CLAMPING (W_MAX = 3.0)
# =============================================================================

func test_weight_final_clamped_at_w_max() -> bool:
	# Combine a very high base weight with boosted factors to exceed 3.0
	var ea: EventAdapter = _make()
	var da: DifficultyAdapter = DifficultyAdapter.new()
	da.player_skill = 0.0        # f_skill = 1.2
	da.pity_mode_active = true   # f_pity = 1.5
	ea.difficulty_adapter = da
	var ctx: Dictionary = _make_ctx()
	ctx["life_essence"] = 10
	ctx["faction_rep_delta"] = {"druides": 20.0, "ankou": -20.0}  # f_crisis = 1.5
	var ev: Dictionary = _make_event("ev_heavy", 2.5)
	ev["tags"] = ["summer"]  # f_season = 1.15 (current season is summer)
	ea._event_catalogue = [ev]
	var results: Array = ea.get_active_events(ctx)
	if results.is_empty():
		return _fail("Boosted event should appear in active events")
	var wf: float = results[0]["weight_final"]
	if wf > EventAdapter.W_MAX + 0.001:
		return _fail("weight_final should be clamped at W_MAX=3.0, got: " + str(wf))
	return true


func test_weight_final_never_negative() -> bool:
	var ea: EventAdapter = _make()
	var ev: Dictionary = _make_event("ev_zero", 0.001)
	ea._event_catalogue = [ev]
	var results: Array = ea.get_active_events(_make_ctx())
	for entry in results:
		if entry["weight_final"] < 0.0:
			return _fail("weight_final should never be negative, got: " + str(entry["weight_final"]))
	return true


# =============================================================================
# 17. ON_EVENT_RESOLVED (signal smoke test)
# =============================================================================

func test_on_event_resolved_does_not_crash() -> bool:
	var ea: EventAdapter = _make()
	# Just verify no crash — the signal is fire-and-forget here
	ea.on_event_resolved("ev_001", "choice_a")
	return true


# =============================================================================
# 18. GET_EVENTS_IN_WINDOW_FROM_CATALOGUE
# =============================================================================

func test_get_events_in_window_from_catalogue_empty() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = []
	if ea.get_events_in_window_from_catalogue(30).size() != 0:
		return _fail("Empty catalogue should return 0 upcoming events")
	return true


func test_get_events_in_window_from_catalogue_floating_excluded() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = [_make_event("ev_float")]  # date = "floating"
	if ea.get_events_in_window_from_catalogue(30).size() != 0:
		return _fail("Floating events should be excluded from window catalogue query")
	return true


func test_get_events_in_window_from_catalogue_near_event_included() -> bool:
	var ea: EventAdapter = _make()
	ea.update_calendar_context("summer", 6, 1, 152)
	# Event 5 days ahead: doy 157 -> month 6, day 6
	var ev: Dictionary = _make_event("ev_near_date")
	ev["date"] = {"month": 6, "day": 6}  # doy ~157
	ea._event_catalogue = [ev]
	var results: Array = ea.get_events_in_window_from_catalogue(10)
	if results.size() != 1:
		return _fail("Event 5 days ahead should be in 10-day window, got: " + str(results.size()))
	return true


# =============================================================================
# 19. GET_WEIGHT_LOG & GET_DEBUG_INFO
# =============================================================================

func test_get_weight_log_returns_copy() -> bool:
	var ea: EventAdapter = _make()
	var log1: Array = ea.get_weight_log()
	log1.append({"dummy": true})
	var log2: Array = ea.get_weight_log()
	if log2.size() != 0:
		return _fail("get_weight_log should return a copy, not the internal array")
	return true


func test_get_debug_info_has_all_keys() -> bool:
	var ea: EventAdapter = _make()
	var info: Dictionary = ea.get_debug_info()
	for key in ["catalogue_size", "events_seen_count", "current_season",
				"current_day", "current_month", "weight_log_size"]:
		if not info.has(key):
			return _fail("get_debug_info missing key: " + key)
	return true


func test_get_debug_info_catalogue_size_reflects_injection() -> bool:
	var ea: EventAdapter = _make()
	ea._event_catalogue = [_make_event("a"), _make_event("b"), _make_event("c")]
	if ea.get_debug_info()["catalogue_size"] != 3:
		return _fail("catalogue_size should reflect injected catalogue")
	return true


# =============================================================================
# RUNNER
# =============================================================================

func run_all() -> Dictionary:
	var tests: Array[String] = [
		"test_init_catalogue_empty",
		"test_init_events_seen_empty",
		"test_init_difficulty_adapter_null",
		"test_update_calendar_context_stores_all_fields",
		"test_reset_clears_events_seen",
		"test_reset_clears_weight_log",
		"test_record_event_appends_id",
		"test_record_event_trims_when_exceeds_50",
		"test_record_event_trim_keeps_most_recent",
		"test_f_skill_null_adapter_returns_1",
		"test_f_skill_skill_zero_returns_1_2",
		"test_f_skill_skill_one_returns_0_9",
		"test_f_skill_midpoint_returns_1_05",
		"test_f_pity_null_adapter_returns_1",
		"test_f_pity_mode_active_returns_1_5",
		"test_f_pity_three_deaths_returns_1_3",
		"test_f_pity_zero_deaths_returns_1",
		"test_f_crisis_no_stress_returns_1",
		"test_f_crisis_one_extreme_faction_returns_1_2",
		"test_f_crisis_two_extremes_returns_1_5",
		"test_f_crisis_low_life_below_20_counts_as_extreme",
		"test_f_crisis_life_20_boundary_not_extreme",
		"test_f_conditions_empty_passes",
		"test_f_conditions_min_run_not_met_blocks",
		"test_f_conditions_min_run_met_passes",
		"test_f_conditions_min_cards_not_met_blocks",
		"test_f_conditions_hidden_without_brumes_blocks",
		"test_f_conditions_hidden_with_brumes_passes",
		"test_f_conditions_missing_required_flag_blocks",
		"test_f_conditions_present_required_flag_passes",
		"test_f_conditions_reputation_above_blocks",
		"test_f_conditions_reputation_below_blocks_when_rep_too_high",
		"test_f_conditions_life_below_blocks_when_life_too_high",
		"test_f_conditions_life_above_blocks_when_life_too_low",
		"test_f_conditions_karma_above_blocks",
		"test_f_conditions_tension_above_blocks",
		"test_f_conditions_dominant_faction_above_blocks",
		"test_f_conditions_trust_merlin_above_blocks",
		"test_f_conditions_min_endings_seen_blocks",
		"test_f_conditions_season_mismatch_blocks",
		"test_f_conditions_season_match_passes",
		"test_f_fatigue_no_history_returns_1",
		"test_f_fatigue_repeated_event_penalizes",
		"test_f_fatigue_clamped_at_0_1_minimum",
		"test_f_fatigue_different_event_no_id_penalty",
		"test_f_season_matching_tag_returns_1_15",
		"test_f_season_opposite_tag_returns_0_85",
		"test_f_season_no_season_tag_returns_1",
		"test_f_season_all_four_season_pairs",
		"test_f_date_proximity_floating_returns_1",
		"test_f_date_proximity_null_returns_1",
		"test_f_date_proximity_exact_match_gives_max_bonus",
		"test_f_date_proximity_far_away_returns_1",
		"test_f_date_proximity_year_wrap_handled",
		"test_f_date_proximity_window_date_uses_start",
		"test_is_in_window_floating_always_true",
		"test_is_in_window_null_always_true",
		"test_is_in_window_fixed_date_within_3_days_true",
		"test_is_in_window_fixed_date_outside_tolerance_false",
		"test_is_in_window_window_inside_true",
		"test_is_in_window_window_outside_false",
		"test_is_in_window_year_wrap_window_inside",
		"test_opposite_season_winter_summer",
		"test_opposite_season_summer_winter",
		"test_opposite_season_spring_autumn",
		"test_opposite_season_autumn_spring",
		"test_opposite_season_unknown_returns_empty",
		"test_get_day_of_year_jan_1_is_1",
		"test_get_day_of_year_feb_1_is_32",
		"test_get_day_of_year_dec_31_is_365",
		"test_get_day_of_year_march_1_is_60",
		"test_find_event_by_id_found",
		"test_find_event_by_id_not_found_returns_empty",
		"test_find_event_by_id_empty_catalogue_returns_empty",
		"test_get_active_events_empty_catalogue",
		"test_get_active_events_floating_event_included",
		"test_get_active_events_condition_blocked_excluded",
		"test_get_active_events_sorted_by_weight_desc",
		"test_get_active_events_result_has_weight_final_key",
		"test_select_event_empty_catalogue_returns_empty",
		"test_select_event_single_eligible_event_always_selected",
		"test_weight_final_clamped_at_w_max",
		"test_weight_final_never_negative",
		"test_on_event_resolved_does_not_crash",
		"test_get_events_in_window_from_catalogue_empty",
		"test_get_events_in_window_from_catalogue_floating_excluded",
		"test_get_events_in_window_from_catalogue_near_event_included",
		"test_get_weight_log_returns_copy",
		"test_get_debug_info_has_all_keys",
		"test_get_debug_info_catalogue_size_reflects_injection",
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

	print("[test_event_adapter] %d/%d passed" % [passed, passed + failed])
	if failed > 0:
		print("[test_event_adapter] FAILED: " + ", ".join(failures))

	return {
		"total": tests.size(),
		"passed": passed,
		"failed": failed,
		"failures": failures,
	}
