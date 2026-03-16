## ═══════════════════════════════════════════════════════════════════════════════
## Test MOS Convergence — StoreRun.check_run_end + get_victory_type
## ═══════════════════════════════════════════════════════════════════════════════
## Calls StoreRun static methods directly (no local mirror).
## Covers:
##   - Death ending (life_essence=0, negative)
##   - Hard max (50 cards) — ended=true, hard_max=true
##   - All MOS zone exact boundary values: 0,7,8,19,20,24,25,39,40,49,50
##   - Score calculations (death: cards*10, victory: cards*20, hard_max: cards*10)
##   - Victory type (harmonie / victoire_amere / prix_paye) + boundary karma
##   - Edge cases (empty state, missing run, missing life_essence, missing cards)
##   - Victory path (mission complete + MIN_CARDS_FOR_VICTORY guard)
##   - Result shape invariants (ended=false for all mid-run states)
##   - Monotonic tension zone progression across 0..49
##   - Promise cap: max_active_promises = 2
## Pattern: extends RefCounted (NO class_name), func test_xxx() -> bool:,
##          push_error() before return false, NO assert(), NO await, NO class_name.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted

var _pass_count: int = 0
var _fail_count: int = 0


func _init() -> void:
	pass


# ─── HELPERS ──────────────────────────────────────────────────────────────────

## Minimal valid state. life_essence lives inside run (real StoreRun layout).
## Mission is always incomplete (progress=0) so the victory path is not taken
## unless the test explicitly sets it.
func _make_state(life_essence: int = 100, cards_played: int = 0, karma: int = 0) -> Dictionary:
	return {
		"run": {
			"life_essence": life_essence,
			"cards_played": cards_played,
			"day": 1,
			"mission": {"progress": 0, "total": 10},
			"hidden": {"karma": karma, "tension": 0},
		},
	}


## State with mission complete and cards_played at or above MIN_CARDS_FOR_VICTORY.
func _make_victory_state(karma: int = 0, cards_played: int = 25) -> Dictionary:
	return {
		"run": {
			"life_essence": 100,
			"cards_played": cards_played,
			"day": 5,
			"mission": {"progress": 10, "total": 10},
			"hidden": {"karma": karma, "tension": 0},
		},
	}


func _ok(test_name: String) -> void:
	_pass_count += 1


func _fail(test_name: String, detail: String) -> void:
	push_error("[FAIL] %s — %s" % [test_name, detail])
	_fail_count += 1


# ─── DEATH ENDING ─────────────────────────────────────────────────────────────

func test_death_at_zero_life() -> bool:
	var state: Dictionary = _make_state(0, 10)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", false) != true:
		_fail("death_at_zero_life", "ended must be true when life_essence=0")
		return false
	if result.get("life_depleted", false) != true:
		_fail("death_at_zero_life", "life_depleted must be true")
		return false
	_ok("death_at_zero_life")
	return true


func test_death_at_negative_life() -> bool:
	var state: Dictionary = _make_state(-10, 5)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", false) != true:
		_fail("death_at_negative_life", "ended must be true when life_essence<0")
		return false
	if result.get("life_depleted", false) != true:
		_fail("death_at_negative_life", "life_depleted must be true")
		return false
	_ok("death_at_negative_life")
	return true


func test_death_score_equals_cards_times_10() -> bool:
	var state: Dictionary = _make_state(0, 7)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("score", -1) != 70:
		_fail("death_score", "expected score=70 (7*10), got %d" % result.get("score", -1))
		return false
	_ok("death_score")
	return true


func test_death_score_with_zero_cards() -> bool:
	var state: Dictionary = _make_state(0, 0)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("score", -1) != 0:
		_fail("death_score_zero_cards", "expected score=0, got %d" % result.get("score", -1))
		return false
	_ok("death_score_zero_cards")
	return true


func test_death_cards_played_in_result() -> bool:
	var state: Dictionary = _make_state(0, 12)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("cards_played", -1) != 12:
		_fail("death_cards_played", "expected 12, got %d" % result.get("cards_played", -1))
		return false
	_ok("death_cards_played")
	return true


func test_death_days_survived_in_result() -> bool:
	var state: Dictionary = _make_state(0, 5)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("days_survived", -1) != 1:
		_fail("death_days_survived", "expected 1, got %d" % result.get("days_survived", -1))
		return false
	_ok("death_days_survived")
	return true


func test_death_ending_has_non_empty_title() -> bool:
	var state: Dictionary = _make_state(0, 3)
	var result: Dictionary = StoreRun.check_run_end(state)
	var ending: Dictionary = result.get("ending", {})
	var title: String = str(ending.get("title", ""))
	if title.is_empty():
		_fail("death_ending_title", "ending.title must be non-empty on death")
		return false
	_ok("death_ending_title")
	return true


func test_death_result_has_no_tension_zone() -> bool:
	var state: Dictionary = _make_state(0, 15)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.has("tension_zone"):
		_fail("death_no_tension_zone", "death result must not include tension_zone field")
		return false
	_ok("death_no_tension_zone")
	return true


func test_life_1_is_not_death() -> bool:
	var state: Dictionary = _make_state(1, 10)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("life_depleted", false) == true:
		_fail("life_1_not_death", "life_essence=1 must not trigger death")
		return false
	_ok("life_1_not_death")
	return true


# ─── HARD MAX ─────────────────────────────────────────────────────────────────

func test_hard_max_at_exactly_50_cards() -> bool:
	var state: Dictionary = _make_state(100, 50)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", false) != true:
		_fail("hard_max_50", "ended must be true at cards_played=50")
		return false
	if result.get("hard_max", false) != true:
		_fail("hard_max_50", "hard_max must be true at cards_played=50")
		return false
	_ok("hard_max_50")
	return true


func test_hard_max_score_equals_cards_times_10() -> bool:
	var state: Dictionary = _make_state(100, 50)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("score", -1) != 500:
		_fail("hard_max_score", "expected score=500 (50*10), got %d" % result.get("score", -1))
		return false
	_ok("hard_max_score")
	return true


func test_hard_max_cards_played_in_result() -> bool:
	var state: Dictionary = _make_state(100, 50)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("cards_played", -1) != 50:
		_fail("hard_max_cards_played", "expected 50, got %d" % result.get("cards_played", -1))
		return false
	_ok("hard_max_cards_played")
	return true


func test_hard_max_days_survived_in_result() -> bool:
	var state: Dictionary = _make_state(100, 50)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("days_survived", -1) != 1:
		_fail("hard_max_days_survived", "expected 1, got %d" % result.get("days_survived", -1))
		return false
	_ok("hard_max_days_survived")
	return true


func test_hard_max_overflow_beyond_50_also_triggers() -> bool:
	var state: Dictionary = _make_state(100, 60)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", false) != true:
		_fail("hard_max_overflow", "ended must be true for cards_played=60")
		return false
	if result.get("hard_max", false) != true:
		_fail("hard_max_overflow", "hard_max must be true for cards_played=60")
		return false
	_ok("hard_max_overflow")
	return true


func test_hard_max_result_has_no_tension_zone() -> bool:
	var state: Dictionary = _make_state(100, 50)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.has("tension_zone"):
		_fail("hard_max_no_tension_zone", "hard_max result must not include tension_zone")
		return false
	_ok("hard_max_no_tension_zone")
	return true


# ─── MOS ZONE EXACT BOUNDARY VALUES ──────────────────────────────────────────

## 0 cards → tension_zone="none", convergence_zone=false, early_zone=false
func test_zone_boundary_0_cards() -> bool:
	var state: Dictionary = _make_state(100, 0)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", true) != false:
		_fail("zone_0", "must not be ended at 0 cards")
		return false
	if result.get("tension_zone", "") != "none":
		_fail("zone_0", "tension_zone must be 'none', got '%s'" % result.get("tension_zone", ""))
		return false
	if result.get("convergence_zone", true) != false:
		_fail("zone_0", "convergence_zone must be false at 0 cards")
		return false
	if result.get("early_zone", true) != false:
		_fail("zone_0", "early_zone must be false at 0 cards")
		return false
	_ok("zone_0")
	return true


## 7 cards → below soft_min (8), tension_zone="none"
func test_zone_boundary_7_cards_below_soft_min() -> bool:
	var state: Dictionary = _make_state(100, 7)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", true) != false:
		_fail("zone_7", "must not be ended at 7 cards")
		return false
	if result.get("tension_zone", "") != "none":
		_fail("zone_7", "tension_zone must be 'none' at 7 (below soft_min=8), got '%s'" % result.get("tension_zone", ""))
		return false
	if result.get("convergence_zone", true) != false:
		_fail("zone_7", "convergence_zone must be false below soft_min")
		return false
	if result.get("early_zone", true) != false:
		_fail("zone_7", "early_zone must be false below soft_min")
		return false
	_ok("zone_7")
	return true


## 8 cards → exact soft_min: tension_zone="low", early_zone=true
func test_zone_boundary_8_cards_exact_soft_min() -> bool:
	var state: Dictionary = _make_state(100, 8)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", true) != false:
		_fail("zone_8", "must not be ended at 8 cards")
		return false
	if result.get("tension_zone", "") != "low":
		_fail("zone_8", "tension_zone must be 'low' at exact soft_min=8, got '%s'" % result.get("tension_zone", ""))
		return false
	if result.get("convergence_zone", true) != false:
		_fail("zone_8", "convergence_zone must be false in early_zone")
		return false
	if result.get("early_zone", false) != true:
		_fail("zone_8", "early_zone must be true at soft_min=8")
		return false
	_ok("zone_8")
	return true


## 19 cards → still below target_min (20), tension_zone="low"
func test_zone_boundary_19_cards_still_low() -> bool:
	var state: Dictionary = _make_state(100, 19)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", true) != false:
		_fail("zone_19", "must not be ended at 19 cards")
		return false
	if result.get("tension_zone", "") != "low":
		_fail("zone_19", "tension_zone must be 'low' at 19 (below target_min=20), got '%s'" % result.get("tension_zone", ""))
		return false
	if result.get("convergence_zone", true) != false:
		_fail("zone_19", "convergence_zone must be false below target_min")
		return false
	if result.get("early_zone", false) != true:
		_fail("zone_19", "early_zone must be true between soft_min and target_min")
		return false
	_ok("zone_19")
	return true


## 20 cards → exact target_min: tension_zone="rising", convergence_zone=true
func test_zone_boundary_20_cards_exact_target_min() -> bool:
	var state: Dictionary = _make_state(100, 20)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", true) != false:
		_fail("zone_20", "must not be ended at 20 cards")
		return false
	if result.get("tension_zone", "") != "rising":
		_fail("zone_20", "tension_zone must be 'rising' at exact target_min=20, got '%s'" % result.get("tension_zone", ""))
		return false
	if result.get("convergence_zone", false) != true:
		_fail("zone_20", "convergence_zone must be true at target_min=20")
		return false
	if result.get("early_zone", true) != false:
		_fail("zone_20", "early_zone must be false in convergence zone")
		return false
	_ok("zone_20")
	return true


## 24 cards → still below target_max (25), tension_zone="rising"
func test_zone_boundary_24_cards_still_rising() -> bool:
	var state: Dictionary = _make_state(100, 24)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", true) != false:
		_fail("zone_24", "must not be ended at 24 cards")
		return false
	if result.get("tension_zone", "") != "rising":
		_fail("zone_24", "tension_zone must be 'rising' at 24 (below target_max=25), got '%s'" % result.get("tension_zone", ""))
		return false
	if result.get("convergence_zone", false) != true:
		_fail("zone_24", "convergence_zone must be true in target range")
		return false
	if result.get("early_zone", true) != false:
		_fail("zone_24", "early_zone must be false in target range")
		return false
	_ok("zone_24")
	return true


## 25 cards → exact target_max: tension_zone="high", convergence_zone=true
## (Mission incomplete so no victory path is taken)
func test_zone_boundary_25_cards_exact_target_max() -> bool:
	var state: Dictionary = _make_state(100, 25)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", true) != false:
		_fail("zone_25", "must not be ended at 25 cards with incomplete mission")
		return false
	if result.get("tension_zone", "") != "high":
		_fail("zone_25", "tension_zone must be 'high' at exact target_max=25, got '%s'" % result.get("tension_zone", ""))
		return false
	if result.get("convergence_zone", false) != true:
		_fail("zone_25", "convergence_zone must be true at target_max=25")
		return false
	if result.get("early_zone", true) != false:
		_fail("zone_25", "early_zone must be false at target_max=25")
		return false
	_ok("zone_25")
	return true


## 39 cards → just below soft_max (40), tension_zone="high"
func test_zone_boundary_39_cards_still_high() -> bool:
	var state: Dictionary = _make_state(100, 39)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", true) != false:
		_fail("zone_39", "must not be ended at 39 cards")
		return false
	if result.get("tension_zone", "") != "high":
		_fail("zone_39", "tension_zone must be 'high' at 39 (below soft_max=40), got '%s'" % result.get("tension_zone", ""))
		return false
	if result.get("convergence_zone", false) != true:
		_fail("zone_39", "convergence_zone must be true below soft_max")
		return false
	if result.get("early_zone", true) != false:
		_fail("zone_39", "early_zone must be false below soft_max")
		return false
	_ok("zone_39")
	return true


## 40 cards → exact soft_max: tension_zone="critical", convergence_zone=true, NOT ended
func test_zone_boundary_40_cards_exact_soft_max() -> bool:
	var state: Dictionary = _make_state(100, 40)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", true) != false:
		_fail("zone_40", "soft_max must NOT end the run (only hard_max does)")
		return false
	if result.get("tension_zone", "") != "critical":
		_fail("zone_40", "tension_zone must be 'critical' at exact soft_max=40, got '%s'" % result.get("tension_zone", ""))
		return false
	if result.get("convergence_zone", false) != true:
		_fail("zone_40", "convergence_zone must be true at soft_max=40")
		return false
	if result.get("early_zone", true) != false:
		_fail("zone_40", "early_zone must be false at soft_max=40")
		return false
	_ok("zone_40")
	return true


## 49 cards → just below hard_max (50), still "critical" and not ended
func test_zone_boundary_49_cards_still_critical() -> bool:
	var state: Dictionary = _make_state(100, 49)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", true) != false:
		_fail("zone_49", "must not be ended at 49 cards (hard_max=50)")
		return false
	if result.get("tension_zone", "") != "critical":
		_fail("zone_49", "tension_zone must be 'critical' at 49, got '%s'" % result.get("tension_zone", ""))
		return false
	if result.get("convergence_zone", false) != true:
		_fail("zone_49", "convergence_zone must be true at 49")
		return false
	if result.get("early_zone", true) != false:
		_fail("zone_49", "early_zone must be false at 49")
		return false
	_ok("zone_49")
	return true


## 50 cards → hard_max: ended=true, hard_max=true
func test_zone_boundary_50_cards_is_hard_max() -> bool:
	var state: Dictionary = _make_state(100, 50)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", false) != true:
		_fail("zone_50", "ended must be true at hard_max=50")
		return false
	if result.get("hard_max", false) != true:
		_fail("zone_50", "hard_max must be true at cards_played=50")
		return false
	_ok("zone_50")
	return true


# ─── CARDS_PLAYED IN ZONE RESULT ─────────────────────────────────────────────

func test_zone_result_contains_cards_played() -> bool:
	var state: Dictionary = _make_state(100, 15)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("cards_played", -1) != 15:
		_fail("zone_cards_played", "cards_played must equal 15 in zone result")
		return false
	_ok("zone_cards_played")
	return true


# ─── RESULT SHAPE INVARIANTS ──────────────────────────────────────────────────

## All mid-run states (life>0, cards<50, mission incomplete) must return ended=false.
func test_all_mid_run_states_have_ended_false() -> bool:
	var samples: Array[int] = [0, 1, 7, 8, 15, 19, 20, 24, 25, 30, 39, 40, 49]
	for c in samples:
		var state: Dictionary = _make_state(100, c)
		var result: Dictionary = StoreRun.check_run_end(state)
		if result.get("ended", true) != false:
			_fail("mid_run_ended_false", "ended must be false for cards_played=%d (life=100)" % c)
			return false
	_ok("mid_run_ended_false")
	return true


## All mid-run results must contain the cards_played key.
func test_all_zone_results_have_cards_played_key() -> bool:
	var samples: Array[int] = [0, 8, 20, 40]
	for c in samples:
		var state: Dictionary = _make_state(100, c)
		var result: Dictionary = StoreRun.check_run_end(state)
		if not result.has("cards_played"):
			_fail("zone_has_cards_played", "cards_played key missing for cards=%d" % c)
			return false
	_ok("zone_has_cards_played")
	return true


## Tension zones must be monotonically non-decreasing across 0..49 cards.
func test_tension_zone_is_monotonically_non_decreasing() -> bool:
	var zone_order: Dictionary = {"none": 0, "low": 1, "rising": 2, "high": 3, "critical": 4}
	var prev_level: int = 0
	for i in range(0, 50):
		var state: Dictionary = _make_state(100, i)
		var result: Dictionary = StoreRun.check_run_end(state)
		if result.get("ended", false):
			break
		var zone: String = str(result.get("tension_zone", "none"))
		var level: int = int(zone_order.get(zone, -1))
		if level < 0:
			_fail("monotonic_tension", "unknown tension_zone '%s' at cards=%d" % [zone, i])
			return false
		if level < prev_level:
			_fail("monotonic_tension", "tension decreased at cards=%d: '%s' < prev level %d" % [i, zone, prev_level])
			return false
		prev_level = level
	_ok("monotonic_tension")
	return true


## All five tension zones must appear in a 0..49 run.
func test_all_tension_zones_are_visited_in_full_run() -> bool:
	var visited: Dictionary = {}
	for i in range(0, 50):
		var state: Dictionary = _make_state(100, i)
		var result: Dictionary = StoreRun.check_run_end(state)
		if result.get("ended", false):
			break
		visited[str(result.get("tension_zone", ""))] = true
	var expected: Array[String] = ["none", "low", "rising", "high", "critical"]
	for z in expected:
		if not visited.has(z):
			_fail("all_zones_visited", "zone '%s' was never visited in 0..49" % z)
			return false
	_ok("all_zones_visited")
	return true


# ─── VICTORY PATH ─────────────────────────────────────────────────────────────

func test_victory_requires_mission_complete() -> bool:
	# Mission not complete → no victory even at 25 cards
	var state: Dictionary = _make_state(100, 25)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", true) != false:
		_fail("no_victory_without_mission", "must not end when mission is incomplete at 25 cards")
		return false
	if result.get("victory", false) == true:
		_fail("no_victory_without_mission", "victory must not be true with incomplete mission")
		return false
	_ok("no_victory_without_mission")
	return true


func test_victory_triggers_when_mission_complete_at_min_cards() -> bool:
	var state: Dictionary = _make_victory_state(0, 25)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("ended", false) != true:
		_fail("victory_at_25", "ended must be true when mission complete at 25 cards")
		return false
	if result.get("victory", false) != true:
		_fail("victory_at_25", "victory must be true when mission complete at 25 cards")
		return false
	_ok("victory_at_25")
	return true


func test_victory_score_equals_cards_times_20() -> bool:
	var state: Dictionary = _make_victory_state(0, 25)
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("score", -1) != 500:
		_fail("victory_score", "expected score=500 (25*20), got %d" % result.get("score", -1))
		return false
	_ok("victory_score")
	return true


func test_victory_does_not_trigger_below_min_cards() -> bool:
	# 24 cards with complete mission — MIN_CARDS_FOR_VICTORY = 25, must not end
	var state: Dictionary = {
		"run": {
			"life_essence": 100,
			"cards_played": 24,
			"day": 3,
			"mission": {"progress": 10, "total": 10},
			"hidden": {"karma": 0, "tension": 0},
		},
	}
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("victory", false) == true:
		_fail("victory_below_min_cards", "victory must not trigger at 24 cards (min=25)")
		return false
	_ok("victory_below_min_cards")
	return true


func test_victory_ending_has_non_empty_title() -> bool:
	var state: Dictionary = _make_victory_state(0, 25)
	var result: Dictionary = StoreRun.check_run_end(state)
	var ending: Dictionary = result.get("ending", {})
	var title: String = str(ending.get("title", ""))
	if title.is_empty():
		_fail("victory_ending_title", "ending.title must be non-empty on victory")
		return false
	_ok("victory_ending_title")
	return true


# ─── GET_VICTORY_TYPE ─────────────────────────────────────────────────────────

func test_victory_type_harmonie_at_karma_5() -> bool:
	var state: Dictionary = _make_state(100, 30, 5)
	var result: String = StoreRun.get_victory_type(state)
	if result != "harmonie":
		_fail("victory_type_harmonie_5", "expected 'harmonie', got '%s'" % result)
		return false
	_ok("victory_type_harmonie_5")
	return true


func test_victory_type_harmonie_at_high_karma() -> bool:
	var state: Dictionary = _make_state(100, 30, 10)
	var result: String = StoreRun.get_victory_type(state)
	if result != "harmonie":
		_fail("victory_type_harmonie_10", "expected 'harmonie', got '%s'" % result)
		return false
	_ok("victory_type_harmonie_10")
	return true


func test_victory_type_victoire_amere_at_karma_minus_5() -> bool:
	var state: Dictionary = _make_state(100, 30, -5)
	var result: String = StoreRun.get_victory_type(state)
	if result != "victoire_amere":
		_fail("victory_type_amere_-5", "expected 'victoire_amere', got '%s'" % result)
		return false
	_ok("victory_type_amere_-5")
	return true


func test_victory_type_victoire_amere_at_low_karma() -> bool:
	var state: Dictionary = _make_state(100, 30, -10)
	var result: String = StoreRun.get_victory_type(state)
	if result != "victoire_amere":
		_fail("victory_type_amere_-10", "expected 'victoire_amere', got '%s'" % result)
		return false
	_ok("victory_type_amere_-10")
	return true


## Neutral karma (strictly between -5 and +5) → "prix_paye" (real implementation)
func test_victory_type_prix_paye_at_karma_0() -> bool:
	var state: Dictionary = _make_state(100, 30, 0)
	var result: String = StoreRun.get_victory_type(state)
	if result != "prix_paye":
		_fail("victory_type_neutral_0", "expected 'prix_paye', got '%s'" % result)
		return false
	_ok("victory_type_neutral_0")
	return true


func test_victory_type_prix_paye_at_karma_4() -> bool:
	var state: Dictionary = _make_state(100, 30, 4)
	var result: String = StoreRun.get_victory_type(state)
	if result != "prix_paye":
		_fail("victory_type_neutral_4", "expected 'prix_paye', got '%s'" % result)
		return false
	_ok("victory_type_neutral_4")
	return true


func test_victory_type_prix_paye_at_karma_minus_4() -> bool:
	var state: Dictionary = _make_state(100, 30, -4)
	var result: String = StoreRun.get_victory_type(state)
	if result != "prix_paye":
		_fail("victory_type_neutral_-4", "expected 'prix_paye', got '%s'" % result)
		return false
	_ok("victory_type_neutral_-4")
	return true


## Boundary: karma=4 must NOT be harmonie (threshold is >= 5)
func test_victory_type_karma_4_is_not_harmonie() -> bool:
	var state: Dictionary = _make_state(100, 30, 4)
	var result: String = StoreRun.get_victory_type(state)
	if result == "harmonie":
		_fail("boundary_4_not_harmonie", "karma=4 must not qualify as 'harmonie' (threshold >= 5)")
		return false
	_ok("boundary_4_not_harmonie")
	return true


## Boundary: karma=-4 must NOT be victoire_amere (threshold is <= -5)
func test_victory_type_karma_minus_4_is_not_amere() -> bool:
	var state: Dictionary = _make_state(100, 30, -4)
	var result: String = StoreRun.get_victory_type(state)
	if result == "victoire_amere":
		_fail("boundary_-4_not_amere", "karma=-4 must not qualify as 'victoire_amere' (threshold <= -5)")
		return false
	_ok("boundary_-4_not_amere")
	return true


# ─── EDGE CASES ───────────────────────────────────────────────────────────────

func test_empty_state_returns_dictionary() -> bool:
	var state: Dictionary = {}
	var result: Dictionary = StoreRun.check_run_end(state)
	if typeof(result) != TYPE_DICTIONARY:
		_fail("empty_state_type", "must return Dictionary even for empty state")
		return false
	if not result.has("ended"):
		_fail("empty_state_ended_key", "result must contain 'ended' key")
		return false
	_ok("empty_state")
	return true


func test_missing_run_key_returns_dictionary() -> bool:
	var state: Dictionary = {"meta": {}}
	var result: Dictionary = StoreRun.check_run_end(state)
	if typeof(result) != TYPE_DICTIONARY:
		_fail("missing_run_type", "must return Dictionary when 'run' key is absent")
		return false
	if not result.has("ended"):
		_fail("missing_run_ended_key", "result must contain 'ended' key")
		return false
	_ok("missing_run_key")
	return true


## When life_essence is absent the fallback is LIFE_ESSENCE_START=100, so no death.
func test_missing_life_essence_defaults_to_100_no_death() -> bool:
	var state: Dictionary = {
		"run": {
			"cards_played": 5,
			"day": 1,
			"mission": {"progress": 0, "total": 10},
			"hidden": {"karma": 0},
		},
	}
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("life_depleted", false) == true:
		_fail("missing_life_essence", "life_essence absent → defaults to 100, must not trigger death")
		return false
	_ok("missing_life_essence")
	return true


## When cards_played is absent it defaults to 0, so no hard_max or tension zones.
func test_missing_cards_played_defaults_to_0() -> bool:
	var state: Dictionary = {
		"run": {
			"life_essence": 100,
			"day": 1,
			"mission": {"progress": 0, "total": 10},
			"hidden": {"karma": 0},
		},
	}
	var result: Dictionary = StoreRun.check_run_end(state)
	if result.get("hard_max", false) == true:
		_fail("missing_cards_played", "missing cards_played defaults to 0, must not trigger hard_max")
		return false
	if result.get("tension_zone", "") != "none":
		_fail("missing_cards_played", "missing cards_played → tension_zone must be 'none'")
		return false
	_ok("missing_cards_played")
	return true


func test_get_victory_type_empty_state_defaults_to_prix_paye() -> bool:
	var state: Dictionary = {}
	var result: String = StoreRun.get_victory_type(state)
	if result != "prix_paye":
		_fail("victory_empty_state", "empty state → karma=0 → expected 'prix_paye', got '%s'" % result)
		return false
	_ok("victory_empty_state")
	return true


func test_get_victory_type_missing_hidden_defaults_to_prix_paye() -> bool:
	var state: Dictionary = {"run": {"life_essence": 100, "cards_played": 30}}
	var result: String = StoreRun.get_victory_type(state)
	if result != "prix_paye":
		_fail("victory_missing_hidden", "missing hidden → karma=0 → expected 'prix_paye', got '%s'" % result)
		return false
	_ok("victory_missing_hidden")
	return true


# ─── PROMISE CAP CONSTANT ─────────────────────────────────────────────────────

func test_max_active_promises_is_2() -> bool:
	var mos_max: int = int(MerlinConstants.MOS_CONVERGENCE.get("max_active_promises", -1))
	if mos_max != 2:
		_fail("max_active_promises", "MOS_CONVERGENCE.max_active_promises must be 2, got %d" % mos_max)
		return false
	_ok("max_active_promises")
	return true


# ─── RUNNER ───────────────────────────────────────────────────────────────────

func run_all() -> bool:
	print("[MOS] === MOS Convergence Test Suite ===")

	# Death ending
	test_death_at_zero_life()
	test_death_at_negative_life()
	test_death_score_equals_cards_times_10()
	test_death_score_with_zero_cards()
	test_death_cards_played_in_result()
	test_death_days_survived_in_result()
	test_death_ending_has_non_empty_title()
	test_death_result_has_no_tension_zone()
	test_life_1_is_not_death()

	# Hard max
	test_hard_max_at_exactly_50_cards()
	test_hard_max_score_equals_cards_times_10()
	test_hard_max_cards_played_in_result()
	test_hard_max_days_survived_in_result()
	test_hard_max_overflow_beyond_50_also_triggers()
	test_hard_max_result_has_no_tension_zone()

	# MOS zone exact boundaries
	test_zone_boundary_0_cards()
	test_zone_boundary_7_cards_below_soft_min()
	test_zone_boundary_8_cards_exact_soft_min()
	test_zone_boundary_19_cards_still_low()
	test_zone_boundary_20_cards_exact_target_min()
	test_zone_boundary_24_cards_still_rising()
	test_zone_boundary_25_cards_exact_target_max()
	test_zone_boundary_39_cards_still_high()
	test_zone_boundary_40_cards_exact_soft_max()
	test_zone_boundary_49_cards_still_critical()
	test_zone_boundary_50_cards_is_hard_max()

	# Cards_played in result
	test_zone_result_contains_cards_played()

	# Result shape invariants
	test_all_mid_run_states_have_ended_false()
	test_all_zone_results_have_cards_played_key()
	test_tension_zone_is_monotonically_non_decreasing()
	test_all_tension_zones_are_visited_in_full_run()

	# Victory path
	test_victory_requires_mission_complete()
	test_victory_triggers_when_mission_complete_at_min_cards()
	test_victory_score_equals_cards_times_20()
	test_victory_does_not_trigger_below_min_cards()
	test_victory_ending_has_non_empty_title()

	# get_victory_type
	test_victory_type_harmonie_at_karma_5()
	test_victory_type_harmonie_at_high_karma()
	test_victory_type_victoire_amere_at_karma_minus_5()
	test_victory_type_victoire_amere_at_low_karma()
	test_victory_type_prix_paye_at_karma_0()
	test_victory_type_prix_paye_at_karma_4()
	test_victory_type_prix_paye_at_karma_minus_4()
	test_victory_type_karma_4_is_not_harmonie()
	test_victory_type_karma_minus_4_is_not_amere()

	# Edge cases
	test_empty_state_returns_dictionary()
	test_missing_run_key_returns_dictionary()
	test_missing_life_essence_defaults_to_100_no_death()
	test_missing_cards_played_defaults_to_0()
	test_get_victory_type_empty_state_defaults_to_prix_paye()
	test_get_victory_type_missing_hidden_defaults_to_prix_paye()

	# Promise cap
	test_max_active_promises_is_2()

	var total: int = _pass_count + _fail_count
	print("[MOS] === RESULTS: %d/%d passed ===" % [_pass_count, total])
	if _fail_count > 0:
		print("[MOS] FAILURES: %d" % _fail_count)
		return false
	print("[MOS] ALL PASS")
	return true
