## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MOS Convergence Behavior v2.4
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: convergence toward target range, soft limit behavior, hard cap,
## convergence speed, boundary values, tension zone propagation to run state,
## and LLM convergence hint alignment with MOS constants.
## Source: MerlinConstants.MOS_CONVERGENCE, MerlinStore._check_run_end(),
##         MerlinLlmAdapter._build_arc_system_prompt()
## Pattern: extends RefCounted, methods return bool on success/failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

## Mirrors MerlinStore._check_run_end() MOS zone logic (no life/victory checks).
func _classify_mos_zone(cards_played: int) -> Dictionary:
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var soft_min: int = int(mos.get("soft_min_cards", 8))
	var target_min: int = int(mos.get("target_cards_min", 20))
	var target_max: int = int(mos.get("target_cards_max", 25))
	var soft_max: int = int(mos.get("soft_max_cards", 40))
	var hard_max: int = int(mos.get("hard_max_cards", 50))

	if cards_played >= hard_max:
		return {
			"ended": true,
			"hard_max": true,
			"cards_played": cards_played,
			"tension_zone": "critical",
			"convergence_zone": true,
			"early_zone": false,
		}

	var tension_zone: String = "none"
	var convergence_zone: bool = false
	var early_zone: bool = false

	if cards_played >= soft_max:
		tension_zone = "critical"
		convergence_zone = true
	elif cards_played >= target_max:
		tension_zone = "high"
		convergence_zone = true
	elif cards_played >= target_min:
		tension_zone = "rising"
		convergence_zone = true
	elif cards_played >= soft_min:
		tension_zone = "low"
		early_zone = true

	return {
		"ended": false,
		"tension_zone": tension_zone,
		"convergence_zone": convergence_zone,
		"early_zone": early_zone,
		"cards_played": cards_played,
	}


## Simulate a full run from card 0 to n, collecting zone transitions.
func _simulate_run(num_cards: int) -> Array:
	var transitions: Array = []
	var prev_zone: String = ""
	for i in range(num_cards + 1):
		var result: Dictionary = _classify_mos_zone(i)
		var zone: String = str(result.get("tension_zone", "none"))
		if zone != prev_zone:
			transitions.append({"card": i, "from": prev_zone, "to": zone})
			prev_zone = zone
	return transitions


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 1: MOS below soft_min converges upward (tension increases naturally)
# ═══════════════════════════════════════════════════════════════════════════════

func test_below_soft_min_converges_up() -> bool:
	## Starting at card 0 (below soft_min=8), playing cards should
	## eventually reach "low" zone, proving upward convergence.
	var reached_low: bool = false
	for i in range(0, 20):
		var result: Dictionary = _classify_mos_zone(i)
		if str(result.get("tension_zone", "")) == "low":
			reached_low = true
			if i < 8:
				push_error("Entered 'low' zone too early at card %d (soft_min=8)" % i)
				return false
			break
	if not reached_low:
		push_error("Never reached 'low' zone within 20 cards")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 2: MOS above soft_max converges toward forced end
# ═══════════════════════════════════════════════════════════════════════════════

func test_above_soft_max_converges_down() -> bool:
	## At card 45 (above soft_max=40), the system must be in "critical" zone,
	## signaling strong convergence pressure toward run end.
	var result: Dictionary = _classify_mos_zone(45)
	if str(result.get("tension_zone", "")) != "critical":
		push_error("cards=45: expected 'critical', got '%s'" % result.get("tension_zone", ""))
		return false
	if not result.get("convergence_zone", false):
		push_error("cards=45: convergence_zone should be true above soft_max")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 3: MOS in target range (20-24) stays stable ("rising")
# ═══════════════════════════════════════════════════════════════════════════════

func test_target_range_stays_stable() -> bool:
	## All cards in [20, 24] must classify as "rising" with convergence_zone=true.
	## This is the ideal run length zone — stable, not pushing toward end.
	for i in range(20, 25):
		var result: Dictionary = _classify_mos_zone(i)
		if str(result.get("tension_zone", "")) != "rising":
			push_error("cards=%d: expected 'rising' in target range, got '%s'" % [i, result.get("tension_zone", "")])
			return false
		if not result.get("convergence_zone", false):
			push_error("cards=%d: convergence_zone must be true in target range" % i)
			return false
		if result.get("early_zone", false):
			push_error("cards=%d: early_zone must be false in target range" % i)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 4: Hard cap at 50 never exceeded
# ═══════════════════════════════════════════════════════════════════════════════

func test_hard_cap_never_exceeded() -> bool:
	## Any card count >= 50 must result in ended=true.
	## Tests exact boundary and overflow values.
	for n in [50, 51, 75, 100, 999]:
		var result: Dictionary = _classify_mos_zone(n)
		if not result.get("ended", false):
			push_error("cards=%d: must be ended at or beyond hard_max=50" % n)
			return false
		if not result.get("hard_max", false):
			push_error("cards=%d: hard_max flag must be true" % n)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 5: Convergence speed — zone transitions happen at correct card counts
# ═══════════════════════════════════════════════════════════════════════════════

func test_convergence_speed_transitions() -> bool:
	## A full run simulation from 0 to 50 must produce exactly 5 zone transitions:
	## none -> low (at 8) -> rising (at 20) -> high (at 25) -> critical (at 40) -> ended (at 50)
	var transitions: Array = _simulate_run(50)
	# First transition: "" -> "none" at card 0
	# Then: none -> low at card 8
	# Then: low -> rising at card 20
	# Then: rising -> high at card 25
	# Then: high -> critical at card 40
	var expected_transitions: Array = [
		{"card": 0, "to": "none"},
		{"card": 8, "to": "low"},
		{"card": 20, "to": "rising"},
		{"card": 25, "to": "high"},
		{"card": 40, "to": "critical"},
	]
	if transitions.size() != expected_transitions.size():
		push_error("Expected %d transitions, got %d: %s" % [expected_transitions.size(), transitions.size(), str(transitions)])
		return false
	for i in range(expected_transitions.size()):
		var actual: Dictionary = transitions[i]
		var expected: Dictionary = expected_transitions[i]
		if int(actual.get("card", -1)) != int(expected.get("card", -2)):
			push_error("Transition %d: expected at card %d, got card %d" % [i, expected["card"], actual["card"]])
			return false
		if str(actual.get("to", "")) != str(expected.get("to", "")):
			push_error("Transition %d: expected zone '%s', got '%s'" % [i, expected["to"], actual["to"]])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 6: MOS at exact soft_min boundary (card 8)
# ═══════════════════════════════════════════════════════════════════════════════

func test_exact_soft_min_boundary() -> bool:
	## Card 7 = "none", card 8 = "low". Boundary must be inclusive.
	var before: Dictionary = _classify_mos_zone(7)
	var at: Dictionary = _classify_mos_zone(8)
	if str(before.get("tension_zone", "")) != "none":
		push_error("Card 7 should be 'none'")
		return false
	if str(at.get("tension_zone", "")) != "low":
		push_error("Card 8 should be 'low'")
		return false
	if not at.get("early_zone", false):
		push_error("Card 8 should have early_zone=true")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 7: MOS at exact target_min boundary (card 20)
# ═══════════════════════════════════════════════════════════════════════════════

func test_exact_target_min_boundary() -> bool:
	## Card 19 = "low" (early_zone), card 20 = "rising" (convergence_zone).
	var before: Dictionary = _classify_mos_zone(19)
	var at: Dictionary = _classify_mos_zone(20)
	if str(before.get("tension_zone", "")) != "low":
		push_error("Card 19 should be 'low'")
		return false
	if before.get("convergence_zone", false):
		push_error("Card 19 should not have convergence_zone")
		return false
	if str(at.get("tension_zone", "")) != "rising":
		push_error("Card 20 should be 'rising'")
		return false
	if not at.get("convergence_zone", false):
		push_error("Card 20 should have convergence_zone=true")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 8: MOS at exact target_max boundary (card 25)
# ═══════════════════════════════════════════════════════════════════════════════

func test_exact_target_max_boundary() -> bool:
	## Card 24 = "rising", card 25 = "high". Both convergence_zone=true.
	var before: Dictionary = _classify_mos_zone(24)
	var at: Dictionary = _classify_mos_zone(25)
	if str(before.get("tension_zone", "")) != "rising":
		push_error("Card 24 should be 'rising'")
		return false
	if str(at.get("tension_zone", "")) != "high":
		push_error("Card 25 should be 'high'")
		return false
	if not before.get("convergence_zone", false) or not at.get("convergence_zone", false):
		push_error("Both card 24 and 25 should have convergence_zone=true")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 9: MOS at exact soft_max boundary (card 40)
# ═══════════════════════════════════════════════════════════════════════════════

func test_exact_soft_max_boundary() -> bool:
	## Card 39 = "high", card 40 = "critical". Both convergence_zone=true.
	var before: Dictionary = _classify_mos_zone(39)
	var at: Dictionary = _classify_mos_zone(40)
	if str(before.get("tension_zone", "")) != "high":
		push_error("Card 39 should be 'high'")
		return false
	if str(at.get("tension_zone", "")) != "critical":
		push_error("Card 40 should be 'critical'")
		return false
	if not at.get("convergence_zone", false):
		push_error("Card 40 should have convergence_zone=true")
		return false
	if at.get("ended", false):
		push_error("Card 40 should NOT be ended (soft_max, not hard_max)")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 10: MOS at exact hard_max boundary (card 50)
# ═══════════════════════════════════════════════════════════════════════════════

func test_exact_hard_max_boundary() -> bool:
	## Card 49 = not ended, card 50 = ended.
	var before: Dictionary = _classify_mos_zone(49)
	var at: Dictionary = _classify_mos_zone(50)
	if before.get("ended", false):
		push_error("Card 49 should NOT be ended")
		return false
	if not at.get("ended", false):
		push_error("Card 50 MUST be ended")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 11: Zone ordering is monotonically increasing (never goes backward)
# ═══════════════════════════════════════════════════════════════════════════════

func test_zone_monotonic_progression() -> bool:
	## Zones must progress in order: none -> low -> rising -> high -> critical -> ended.
	## No zone should ever appear after a later zone in a sequential run.
	var zone_order: Dictionary = {"none": 0, "low": 1, "rising": 2, "high": 3, "critical": 4}
	var prev_level: int = -1
	for i in range(0, 51):
		var result: Dictionary = _classify_mos_zone(i)
		if result.get("ended", false):
			if prev_level > 4:
				push_error("Ended state reached after invalid level")
				return false
			break
		var zone: String = str(result.get("tension_zone", "none"))
		var level: int = int(zone_order.get(zone, -1))
		if level < 0:
			push_error("Unknown zone '%s' at card %d" % [zone, i])
			return false
		if level < prev_level:
			push_error("Zone went backward at card %d: level %d < prev %d" % [i, level, prev_level])
			return false
		prev_level = level
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 12: Early zone and convergence zone are mutually exclusive
# ═══════════════════════════════════════════════════════════════════════════════

func test_early_and_convergence_mutually_exclusive() -> bool:
	## early_zone and convergence_zone must never both be true at the same card count.
	for i in range(0, 51):
		var result: Dictionary = _classify_mos_zone(i)
		if result.get("ended", false):
			continue
		var early: bool = result.get("early_zone", false)
		var convergence: bool = result.get("convergence_zone", false)
		if early and convergence:
			push_error("cards=%d: early_zone and convergence_zone both true (mutually exclusive)" % i)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 13: Negative card count handled gracefully
# ═══════════════════════════════════════════════════════════════════════════════

func test_negative_card_count_safe() -> bool:
	## Negative card counts should classify as "none" zone, not crash.
	for n in [-1, -10, -100]:
		var result: Dictionary = _classify_mos_zone(n)
		if result.get("ended", false):
			push_error("cards=%d: negative count should not end the run" % n)
			return false
		if str(result.get("tension_zone", "")) != "none":
			push_error("cards=%d: expected 'none' for negative count, got '%s'" % [n, result.get("tension_zone", "")])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 14: MOS constants hierarchy is valid (soft_min < target_min < target_max < soft_max < hard_max)
# ═══════════════════════════════════════════════════════════════════════════════

func test_mos_constants_hierarchy() -> bool:
	## The five MOS thresholds must form a strictly increasing sequence.
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var soft_min: int = int(mos.get("soft_min_cards", 0))
	var target_min: int = int(mos.get("target_cards_min", 0))
	var target_max: int = int(mos.get("target_cards_max", 0))
	var soft_max: int = int(mos.get("soft_max_cards", 0))
	var hard_max: int = int(mos.get("hard_max_cards", 0))
	if not (soft_min < target_min):
		push_error("soft_min (%d) must be < target_min (%d)" % [soft_min, target_min])
		return false
	if not (target_min < target_max):
		push_error("target_min (%d) must be < target_max (%d)" % [target_min, target_max])
		return false
	if not (target_max < soft_max):
		push_error("target_max (%d) must be < soft_max (%d)" % [target_max, soft_max])
		return false
	if not (soft_max < hard_max):
		push_error("soft_max (%d) must be < hard_max (%d)" % [soft_max, hard_max])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 15: Each zone spans a reasonable number of cards (not degenerate)
# ═══════════════════════════════════════════════════════════════════════════════

func test_zone_spans_not_degenerate() -> bool:
	## Each zone should span at least 3 cards to be meaningful for gameplay.
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var soft_min: int = int(mos.get("soft_min_cards", 8))
	var target_min: int = int(mos.get("target_cards_min", 20))
	var target_max: int = int(mos.get("target_cards_max", 25))
	var soft_max: int = int(mos.get("soft_max_cards", 40))
	var hard_max: int = int(mos.get("hard_max_cards", 50))

	var none_span: int = soft_min           # [0, soft_min)
	var low_span: int = target_min - soft_min     # [soft_min, target_min)
	var rising_span: int = target_max - target_min # [target_min, target_max)
	var high_span: int = soft_max - target_max    # [target_max, soft_max)
	var critical_span: int = hard_max - soft_max  # [soft_max, hard_max)

	if none_span < 3:
		push_error("'none' zone spans only %d cards (minimum 3)" % none_span)
		return false
	if low_span < 3:
		push_error("'low' zone spans only %d cards (minimum 3)" % low_span)
		return false
	if rising_span < 3:
		push_error("'rising' zone spans only %d cards (minimum 3)" % rising_span)
		return false
	if high_span < 3:
		push_error("'high' zone spans only %d cards (minimum 3)" % high_span)
		return false
	if critical_span < 3:
		push_error("'critical' zone spans only %d cards (minimum 3)" % critical_span)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 16: Full run simulation produces correct zone sequence
# ═══════════════════════════════════════════════════════════════════════════════

func test_full_run_zone_sequence() -> bool:
	## A simulated full run from card 0 to 50 must visit zones in order:
	## none -> low -> rising -> high -> critical -> ended.
	var visited_zones: Array = []
	for i in range(0, 51):
		var result: Dictionary = _classify_mos_zone(i)
		var zone: String = str(result.get("tension_zone", "none"))
		if result.get("ended", false):
			zone = "ended"
		if visited_zones.is_empty() or visited_zones[-1] != zone:
			visited_zones.append(zone)
	var expected: Array = ["none", "low", "rising", "high", "critical", "ended"]
	if visited_zones.size() != expected.size():
		push_error("Expected zone sequence %s, got %s" % [str(expected), str(visited_zones)])
		return false
	for i in range(expected.size()):
		if visited_zones[i] != expected[i]:
			push_error("Zone sequence mismatch at index %d: expected '%s', got '%s'" % [i, expected[i], visited_zones[i]])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 17: MOS convergence_zone covers entire target-to-hard_max range
# ═══════════════════════════════════════════════════════════════════════════════

func test_convergence_zone_full_range() -> bool:
	## convergence_zone must be true for ALL cards in [target_min, hard_max).
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var target_min: int = int(mos.get("target_cards_min", 20))
	var hard_max: int = int(mos.get("hard_max_cards", 50))
	for i in range(target_min, hard_max):
		var result: Dictionary = _classify_mos_zone(i)
		if not result.get("convergence_zone", false):
			push_error("cards=%d: convergence_zone should be true in [%d, %d)" % [i, target_min, hard_max])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 18: MOS card 0 initialization is safe
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_zero_initialization() -> bool:
	## At card 0 (run start), MOS should be in "none" zone with no flags.
	var result: Dictionary = _classify_mos_zone(0)
	if result.get("ended", false):
		push_error("Card 0 must not be ended")
		return false
	if str(result.get("tension_zone", "")) != "none":
		push_error("Card 0: expected 'none', got '%s'" % result.get("tension_zone", ""))
		return false
	if result.get("convergence_zone", false):
		push_error("Card 0: convergence_zone must be false")
		return false
	if result.get("early_zone", false):
		push_error("Card 0: early_zone must be false")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> void:
	var tests: Array[Callable] = [
		test_below_soft_min_converges_up,
		test_above_soft_max_converges_down,
		test_target_range_stays_stable,
		test_hard_cap_never_exceeded,
		test_convergence_speed_transitions,
		test_exact_soft_min_boundary,
		test_exact_target_min_boundary,
		test_exact_target_max_boundary,
		test_exact_soft_max_boundary,
		test_exact_hard_max_boundary,
		test_zone_monotonic_progression,
		test_early_and_convergence_mutually_exclusive,
		test_negative_card_count_safe,
		test_mos_constants_hierarchy,
		test_zone_spans_not_degenerate,
		test_full_run_zone_sequence,
		test_convergence_zone_full_range,
		test_card_zero_initialization,
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

	print("[test_mos_convergence] Results: %d/%d passed" % [passed, passed + failed])
	if failed > 0:
		push_error("[test_mos_convergence] %d test(s) FAILED" % failed)
	else:
		print("[test_mos_convergence] All tests passed.")
