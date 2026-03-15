## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MOS Convergence System v2.4
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: MOS zone constants, tension_zone labels at each boundary,
## convergence_zone flag, early_zone flag, hard_max forced end,
## and that zone transitions occur at exact card counts.
## Source: MerlinConstants.MOS_CONVERGENCE + MerlinStore._check_run_end()
## Pattern: extends RefCounted, methods return bool on success/failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

## Simulate the MOS zone classification logic (mirrors MerlinStore._check_run_end).
## Returns the same dict shape: {ended, tension_zone, convergence_zone, early_zone, cards_played}
## NOTE: does NOT reproduce life/victory checks — isolated to MOS zone logic only.
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


# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANT VALUES — MOS_CONVERGENCE dictionary (bible v2.4 s.6.2)
# ═══════════════════════════════════════════════════════════════════════════════

func test_mos_constants_values() -> bool:
	## MOS_CONVERGENCE must define soft_min=8, target_min=20, target_max=25,
	## soft_max=40, hard_max=50, max_active_promises=2.
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	if not mos.has("soft_min_cards"):
		push_error("MOS_CONVERGENCE missing key: soft_min_cards")
		return false
	if int(mos["soft_min_cards"]) != 8:
		push_error("soft_min_cards: expected 8, got %d" % int(mos["soft_min_cards"]))
		return false
	if int(mos["target_cards_min"]) != 20:
		push_error("target_cards_min: expected 20, got %d" % int(mos["target_cards_min"]))
		return false
	if int(mos["target_cards_max"]) != 25:
		push_error("target_cards_max: expected 25, got %d" % int(mos["target_cards_max"]))
		return false
	if int(mos["soft_max_cards"]) != 40:
		push_error("soft_max_cards: expected 40, got %d" % int(mos["soft_max_cards"]))
		return false
	if int(mos["hard_max_cards"]) != 50:
		push_error("hard_max_cards: expected 50, got %d" % int(mos["hard_max_cards"]))
		return false
	if int(mos.get("max_active_promises", -1)) != 2:
		push_error("max_active_promises: expected 2, got %d" % int(mos.get("max_active_promises", -1)))
		return false
	return true


func test_mos_min_cards_for_victory_aligns() -> bool:
	## MIN_CARDS_FOR_VICTORY should equal MOS target_cards_max (25).
	var expected: int = int(MerlinConstants.MOS_CONVERGENCE.get("target_cards_max", -1))
	if MerlinConstants.MIN_CARDS_FOR_VICTORY != expected:
		push_error("MIN_CARDS_FOR_VICTORY=%d should equal MOS target_cards_max=%d" % [
			MerlinConstants.MIN_CARDS_FOR_VICTORY, expected])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# BELOW SOFT_MIN (cards < 8) — zone "none", no flags
# ═══════════════════════════════════════════════════════════════════════════════

func test_mos_zone_none_below_soft_min() -> bool:
	## Cards 0-7: tension_zone must be "none", no convergence, no early.
	for n in [0, 1, 7]:
		var result: Dictionary = _classify_mos_zone(n)
		if result.get("ended", false):
			push_error("cards=%d: should not be ended at below soft_min" % n)
			return false
		if str(result.get("tension_zone", "")) != "none":
			push_error("cards=%d: expected tension_zone='none', got '%s'" % [n, result.get("tension_zone", "")])
			return false
		if result.get("convergence_zone", false):
			push_error("cards=%d: convergence_zone should be false below soft_min" % n)
			return false
		if result.get("early_zone", false):
			push_error("cards=%d: early_zone should be false below soft_min" % n)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EARLY ZONE (8 <= cards < 20) — zone "low", early_zone=true
# ═══════════════════════════════════════════════════════════════════════════════

func test_mos_zone_low_at_soft_min_boundary() -> bool:
	## Card 8 (= soft_min) must enter early_zone with tension_zone "low".
	var result: Dictionary = _classify_mos_zone(8)
	if result.get("ended", false):
		push_error("cards=8: should not be ended")
		return false
	if str(result.get("tension_zone", "")) != "low":
		push_error("cards=8: expected tension_zone='low', got '%s'" % result.get("tension_zone", ""))
		return false
	if not result.get("early_zone", false):
		push_error("cards=8: early_zone should be true at soft_min")
		return false
	if result.get("convergence_zone", false):
		push_error("cards=8: convergence_zone should be false in early zone")
		return false
	return true


func test_mos_zone_low_spans_8_to_19() -> bool:
	## Cards 8-19: all must be tension_zone="low", early_zone=true.
	for n in [8, 10, 15, 19]:
		var result: Dictionary = _classify_mos_zone(n)
		if str(result.get("tension_zone", "")) != "low":
			push_error("cards=%d: expected 'low', got '%s'" % [n, result.get("tension_zone", "")])
			return false
		if not result.get("early_zone", false):
			push_error("cards=%d: early_zone should be true" % n)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TARGET RANGE (20 <= cards < 25) — zone "rising", convergence=true
# ═══════════════════════════════════════════════════════════════════════════════

func test_mos_zone_rising_at_target_min() -> bool:
	## Card 20 (= target_cards_min) must set tension_zone="rising", convergence_zone=true.
	var result: Dictionary = _classify_mos_zone(20)
	if str(result.get("tension_zone", "")) != "rising":
		push_error("cards=20: expected 'rising', got '%s'" % result.get("tension_zone", ""))
		return false
	if not result.get("convergence_zone", false):
		push_error("cards=20: convergence_zone should be true at target_min")
		return false
	if result.get("early_zone", false):
		push_error("cards=20: early_zone should be false in target range")
		return false
	return true


func test_mos_zone_rising_spans_20_to_24() -> bool:
	## Cards 20-24: tension_zone="rising", convergence_zone=true, early_zone=false.
	for n in [20, 21, 22, 23, 24]:
		var result: Dictionary = _classify_mos_zone(n)
		if str(result.get("tension_zone", "")) != "rising":
			push_error("cards=%d: expected 'rising', got '%s'" % [n, result.get("tension_zone", "")])
			return false
		if not result.get("convergence_zone", false):
			push_error("cards=%d: convergence_zone should be true" % n)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ABOVE TARGET_MAX (25 <= cards < 40) — zone "high", convergence=true
# ═══════════════════════════════════════════════════════════════════════════════

func test_mos_zone_high_at_target_max() -> bool:
	## Card 25 (= target_cards_max) must set tension_zone="high", convergence_zone=true.
	var result: Dictionary = _classify_mos_zone(25)
	if str(result.get("tension_zone", "")) != "high":
		push_error("cards=25: expected 'high', got '%s'" % result.get("tension_zone", ""))
		return false
	if not result.get("convergence_zone", false):
		push_error("cards=25: convergence_zone should be true at target_max")
		return false
	return true


func test_mos_zone_high_spans_25_to_39() -> bool:
	## Cards 25-39: tension_zone="high", convergence_zone=true.
	for n in [25, 30, 39]:
		var result: Dictionary = _classify_mos_zone(n)
		if str(result.get("tension_zone", "")) != "high":
			push_error("cards=%d: expected 'high', got '%s'" % [n, result.get("tension_zone", "")])
			return false
		if not result.get("convergence_zone", false):
			push_error("cards=%d: convergence_zone should be true" % n)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SOFT_MAX (40 <= cards < 50) — zone "critical", convergence=true
# ═══════════════════════════════════════════════════════════════════════════════

func test_mos_zone_critical_at_soft_max() -> bool:
	## Card 40 (= soft_max_cards) must set tension_zone="critical", convergence_zone=true.
	var result: Dictionary = _classify_mos_zone(40)
	if result.get("ended", false):
		push_error("cards=40: should not be ended before hard_max")
		return false
	if str(result.get("tension_zone", "")) != "critical":
		push_error("cards=40: expected 'critical', got '%s'" % result.get("tension_zone", ""))
		return false
	if not result.get("convergence_zone", false):
		push_error("cards=40: convergence_zone should be true at soft_max")
		return false
	return true


func test_mos_zone_critical_spans_40_to_49() -> bool:
	## Cards 40-49: tension_zone="critical", ended=false (hard_max not yet reached).
	for n in [40, 45, 49]:
		var result: Dictionary = _classify_mos_zone(n)
		if result.get("ended", false):
			push_error("cards=%d: should not be ended before hard_max=50" % n)
			return false
		if str(result.get("tension_zone", "")) != "critical":
			push_error("cards=%d: expected 'critical', got '%s'" % [n, result.get("tension_zone", "")])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# HARD_MAX (cards >= 50) — forced run end
# ═══════════════════════════════════════════════════════════════════════════════

func test_mos_hard_max_forces_run_end() -> bool:
	## Card 50 (= hard_max_cards) must set ended=true and hard_max=true.
	var result: Dictionary = _classify_mos_zone(50)
	if not result.get("ended", false):
		push_error("cards=50: ended must be true at hard_max")
		return false
	if not result.get("hard_max", false):
		push_error("cards=50: hard_max flag must be true")
		return false
	return true


func test_mos_hard_max_enforced_beyond_50() -> bool:
	## Cards > 50 must also be ended (overflow guard).
	for n in [51, 60, 100]:
		var result: Dictionary = _classify_mos_zone(n)
		if not result.get("ended", false):
			push_error("cards=%d: ended must be true beyond hard_max" % n)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ZONE TRANSITIONS — exact boundary card counts
# ═══════════════════════════════════════════════════════════════════════════════

func test_mos_zone_transition_7_to_8() -> bool:
	## Card 7 = "none", card 8 = "low" — transition at soft_min.
	var before: Dictionary = _classify_mos_zone(7)
	var after: Dictionary = _classify_mos_zone(8)
	if str(before.get("tension_zone", "")) != "none":
		push_error("cards=7 should be 'none', got '%s'" % before.get("tension_zone", ""))
		return false
	if str(after.get("tension_zone", "")) != "low":
		push_error("cards=8 should be 'low', got '%s'" % after.get("tension_zone", ""))
		return false
	return true


func test_mos_zone_transition_19_to_20() -> bool:
	## Card 19 = "low", card 20 = "rising" — transition at target_min.
	var before: Dictionary = _classify_mos_zone(19)
	var after: Dictionary = _classify_mos_zone(20)
	if str(before.get("tension_zone", "")) != "low":
		push_error("cards=19 should be 'low', got '%s'" % before.get("tension_zone", ""))
		return false
	if str(after.get("tension_zone", "")) != "rising":
		push_error("cards=20 should be 'rising', got '%s'" % after.get("tension_zone", ""))
		return false
	return true


func test_mos_zone_transition_24_to_25() -> bool:
	## Card 24 = "rising", card 25 = "high" — transition at target_max.
	var before: Dictionary = _classify_mos_zone(24)
	var after: Dictionary = _classify_mos_zone(25)
	if str(before.get("tension_zone", "")) != "rising":
		push_error("cards=24 should be 'rising', got '%s'" % before.get("tension_zone", ""))
		return false
	if str(after.get("tension_zone", "")) != "high":
		push_error("cards=25 should be 'high', got '%s'" % after.get("tension_zone", ""))
		return false
	return true


func test_mos_zone_transition_39_to_40() -> bool:
	## Card 39 = "high", card 40 = "critical" — transition at soft_max.
	var before: Dictionary = _classify_mos_zone(39)
	var after: Dictionary = _classify_mos_zone(40)
	if str(before.get("tension_zone", "")) != "high":
		push_error("cards=39 should be 'high', got '%s'" % before.get("tension_zone", ""))
		return false
	if str(after.get("tension_zone", "")) != "critical":
		push_error("cards=40 should be 'critical', got '%s'" % after.get("tension_zone", ""))
		return false
	return true


func test_mos_zone_transition_49_to_50() -> bool:
	## Card 49 = not ended, card 50 = ended — transition at hard_max.
	var before: Dictionary = _classify_mos_zone(49)
	var after: Dictionary = _classify_mos_zone(50)
	if before.get("ended", false):
		push_error("cards=49 should not be ended")
		return false
	if not after.get("ended", false):
		push_error("cards=50 should be ended")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CONVERGENCE FLAG — only set in target range or above
# ═══════════════════════════════════════════════════════════════════════════════

func test_mos_convergence_flag_off_in_early_zone() -> bool:
	## Early zone (cards 8-19) must NOT set convergence_zone.
	for n in [8, 12, 19]:
		var result: Dictionary = _classify_mos_zone(n)
		if result.get("convergence_zone", false):
			push_error("cards=%d: convergence_zone should be false in early zone" % n)
			return false
	return true


func test_mos_convergence_flag_on_from_target_min() -> bool:
	## From card 20 onward, convergence_zone must be true (up to but not including hard_max forced end).
	for n in [20, 24, 25, 39, 40, 49]:
		var result: Dictionary = _classify_mos_zone(n)
		if not result.get("convergence_zone", false):
			push_error("cards=%d: convergence_zone should be true from target_min" % n)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EARLY_ZONE FLAG — exclusively in the early zone (8-19)
# ═══════════════════════════════════════════════════════════════════════════════

func test_mos_early_zone_flag_exclusive() -> bool:
	## early_zone should be true only in range [8, 19]. Outside this range it must be false.
	for n_on in [8, 10, 15, 19]:
		var result: Dictionary = _classify_mos_zone(n_on)
		if not result.get("early_zone", false):
			push_error("cards=%d: early_zone should be true in range [8,19]" % n_on)
			return false
	for n_off in [0, 7, 20, 25, 40]:
		var result: Dictionary = _classify_mos_zone(n_off)
		if result.get("early_zone", false):
			push_error("cards=%d: early_zone should be false outside [8,19]" % n_off)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> void:
	var tests: Array[Callable] = [
		test_mos_constants_values,
		test_mos_min_cards_for_victory_aligns,
		test_mos_zone_none_below_soft_min,
		test_mos_zone_low_at_soft_min_boundary,
		test_mos_zone_low_spans_8_to_19,
		test_mos_zone_rising_at_target_min,
		test_mos_zone_rising_spans_20_to_24,
		test_mos_zone_high_at_target_max,
		test_mos_zone_high_spans_25_to_39,
		test_mos_zone_critical_at_soft_max,
		test_mos_zone_critical_spans_40_to_49,
		test_mos_hard_max_forces_run_end,
		test_mos_hard_max_enforced_beyond_50,
		test_mos_zone_transition_7_to_8,
		test_mos_zone_transition_19_to_20,
		test_mos_zone_transition_24_to_25,
		test_mos_zone_transition_39_to_40,
		test_mos_zone_transition_49_to_50,
		test_mos_convergence_flag_off_in_early_zone,
		test_mos_convergence_flag_on_from_target_min,
		test_mos_early_zone_flag_exclusive,
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

	print("[test_mos] Results: %d/%d passed" % [passed, passed + failed])
	if failed > 0:
		push_error("[test_mos] %d test(s) FAILED" % failed)
	else:
		print("[test_mos] All tests passed.")
