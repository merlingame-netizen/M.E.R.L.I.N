extends Node
## Test GameTimeManager — Validates time normalization, periods, seasons,
## moon phases, light intensity, and LLM context format.
## Exit 0 = all pass, 1 = any failure.

var _pass_count: int = 0
var _fail_count: int = 0


func _ready() -> void:
	_log("=== TEST GAME TIME MANAGER ===")
	await get_tree().process_frame

	test_initial_state()
	test_time_of_day_mapping()
	test_season_cycle()
	test_light_intensity_range()
	test_llm_context_format()
	test_moon_advance()
	test_set_season_valid()
	test_set_season_invalid()
	test_check_festival()
	test_period_boundaries()

	_log("=== RESULTS: %d passed, %d failed ===" % [_pass_count, _fail_count])
	get_tree().quit(1 if _fail_count > 0 else 0)


# ─── Tests ──────────────────────────────────────────────────────────────────

func test_initial_state() -> void:
	var gtm: Node = _get_gtm()
	if gtm == null:
		return

	_assert_true(
		gtm.current_time_normalized >= 0.0 and gtm.current_time_normalized <= 1.0,
		"initial normalized time in [0,1]"
	)
	_assert_true(
		gtm.current_season in gtm.SEASONS,
		"initial season is valid"
	)
	_assert_true(
		gtm.moon_phase in gtm.MOON_PHASES,
		"initial moon_phase is valid"
	)
	_assert_true(
		gtm.active_festival is String,
		"active_festival is String"
	)


func test_time_of_day_mapping() -> void:
	## Verify _period_from_hour returns correct period for known hours.
	var gtm: Node = _get_gtm()
	if gtm == null:
		return

	var expected: Dictionary = {
		0: "nuit",
		3: "nuit",
		5: "aube",
		6: "aube",
		7: "matin",
		10: "matin",
		11: "midi",
		13: "midi",
		14: "apres-midi",
		17: "apres-midi",
		18: "crepuscule",
		20: "crepuscule",
		21: "nuit",
		23: "nuit",
	}

	for hour in expected:
		var result: String = gtm._period_from_hour(hour)
		_assert_equal(result, expected[hour], "hour %d -> %s" % [hour, expected[hour]])


func test_season_cycle() -> void:
	var gtm: Node = _get_gtm()
	if gtm == null:
		return

	# Save original
	var original: String = gtm.current_season

	for s in gtm.SEASONS:
		gtm.set_season(s)
		_assert_equal(gtm.current_season, s, "set_season(%s)" % s)
		_assert_equal(gtm.get_season(), s, "get_season() after set(%s)" % s)

	# Restore
	gtm.set_season(original)


func test_light_intensity_range() -> void:
	var gtm: Node = _get_gtm()
	if gtm == null:
		return

	# Test at several normalized times
	var test_points: Array[float] = [0.0, 0.1, 0.25, 0.4, 0.5, 0.6, 0.75, 0.9, 0.99]
	for t in test_points:
		var saved: float = gtm.current_time_normalized
		gtm.current_time_normalized = t
		var intensity: float = gtm.get_light_intensity()
		_assert_true(
			intensity >= 0.0 and intensity <= 1.0,
			"light intensity at t=%.2f is %.3f (in [0,1])" % [t, intensity]
		)
		gtm.current_time_normalized = saved

	# Verify midnight is dark
	var saved_t: float = gtm.current_time_normalized
	gtm.current_time_normalized = 0.0
	var midnight: float = gtm.get_light_intensity()
	_assert_true(midnight < 0.05, "midnight intensity < 0.05 (got %.3f)" % midnight)

	# Verify noon is bright
	gtm.current_time_normalized = 0.5
	var noon: float = gtm.get_light_intensity()
	_assert_true(noon > 0.9, "noon intensity > 0.9 (got %.3f)" % noon)

	gtm.current_time_normalized = saved_t


func test_llm_context_format() -> void:
	var gtm: Node = _get_gtm()
	if gtm == null:
		return

	var ctx: Dictionary = gtm.get_context_for_llm()
	var required_keys: Array[String] = [
		"time_of_day", "time_normalized", "light_intensity",
		"season", "moon_phase", "festival", "reputation_bonus",
	]
	for key in required_keys:
		_assert_true(ctx.has(key), "LLM context has key '%s'" % key)

	_assert_true(ctx["time_of_day"] is String, "time_of_day is String")
	_assert_true(ctx["time_normalized"] is float, "time_normalized is float")
	_assert_true(ctx["light_intensity"] is float, "light_intensity is float")
	_assert_true(ctx["season"] is String, "season is String")
	_assert_true(ctx["moon_phase"] is String, "moon_phase is String")
	_assert_true(ctx["festival"] is String, "festival is String")
	_assert_true(ctx["reputation_bonus"] is Dictionary, "reputation_bonus is Dictionary")


func test_moon_advance() -> void:
	var gtm: Node = _get_gtm()
	if gtm == null:
		return

	var initial_phase: String = gtm.moon_phase
	var initial_index: int = gtm.MOON_PHASES.find(initial_phase)
	gtm.advance_moon()
	var expected_index: int = (initial_index + 1) % gtm.MOON_PHASES.size()
	_assert_equal(
		gtm.moon_phase, gtm.MOON_PHASES[expected_index],
		"advance_moon cycles to next phase"
	)

	# Full cycle should return to start
	for _i in range(gtm.MOON_PHASES.size() - 1):
		gtm.advance_moon()
	_assert_equal(
		gtm.moon_phase, gtm.MOON_PHASES[initial_index],
		"full moon cycle returns to start"
	)


func test_set_season_valid() -> void:
	var gtm: Node = _get_gtm()
	if gtm == null:
		return

	var original: String = gtm.current_season
	gtm.set_season("hiver")
	_assert_equal(gtm.current_season, "hiver", "set_season hiver")
	gtm.set_season(original)


func test_set_season_invalid() -> void:
	var gtm: Node = _get_gtm()
	if gtm == null:
		return

	var original: String = gtm.current_season
	gtm.set_season("invalid_season")
	_assert_equal(
		gtm.current_season, original,
		"set_season with invalid value does not change season"
	)


func test_check_festival() -> void:
	var gtm: Node = _get_gtm()
	if gtm == null:
		return

	var result: String = gtm.check_festival()
	_assert_true(result is String, "check_festival returns String")
	# Either empty or a valid festival key
	if result != "":
		_assert_true(
			gtm.CELTIC_FESTIVALS.has(result),
			"check_festival result '%s' is a valid festival key" % result
		)


func test_period_boundaries() -> void:
	## Ensure all 6 periods are reachable.
	var gtm: Node = _get_gtm()
	if gtm == null:
		return

	var all_periods: Dictionary = {}
	for h in range(24):
		var p: String = gtm._period_from_hour(h)
		all_periods[p] = true

	var expected_periods: Array[String] = [
		"nuit", "aube", "matin", "midi", "apres-midi", "crepuscule"
	]
	for ep in expected_periods:
		_assert_true(all_periods.has(ep), "period '%s' is reachable" % ep)


# ─── Helpers ────────────────────────────────────────────────────────────────

func _get_gtm() -> Node:
	var gtm: Node = get_node_or_null("/root/GameTimeManager")
	if gtm == null:
		_fail("GameTimeManager autoload not found")
		return null
	return gtm


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
		_log("  PASS: %s" % label)
	else:
		_fail_count += 1
		_log("  FAIL: %s" % label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		_pass_count += 1
		_log("  PASS: %s" % label)
	else:
		_fail_count += 1
		_log("  FAIL: %s (got '%s', expected '%s')" % [label, str(actual), str(expected)])


func _fail(msg: String) -> void:
	_fail_count += 1
	_log("  FAIL: %s" % msg)


func _log(msg: String) -> void:
	print("[TIME-TEST] %s" % msg)
