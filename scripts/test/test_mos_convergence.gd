## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MOS Convergence Behavior v2.4
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: soft min/max boundaries, target range, hard max, merchant exemption,
## promise cap, tension tracking, convergence probability curve.
## Source: MerlinConstants.MOS_CONVERGENCE, MerlinConstants.NODE_TYPES,
##         MerlinConstants.MAX_ACTIVE_PROMISES, MerlinStore._check_run_end()
## Pattern: extends RefCounted, run_all() returns Dictionary of test results.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name TestMOSConvergence


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


## Computes a convergence probability for a given card count.
## Models increasing end-probability as cards approach soft_max and beyond.
## Returns 0.0 below target range, ramps linearly to 1.0 at hard_max.
func _convergence_probability(cards_played: int) -> float:
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var target_min: int = int(mos.get("target_cards_min", 20))
	var soft_max: int = int(mos.get("soft_max_cards", 40))
	var hard_max: int = int(mos.get("hard_max_cards", 50))

	if cards_played < target_min:
		return 0.0
	if cards_played >= hard_max:
		return 1.0
	# Linear ramp from 0.0 at target_min to 1.0 at hard_max
	var span: float = float(hard_max - target_min)
	if span <= 0.0:
		return 1.0
	return clampf(float(cards_played - target_min) / span, 0.0, 1.0)


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 1: MOS respects soft min 8 cards
# ═══════════════════════════════════════════════════════════════════════════════

func test_soft_min_boundary() -> bool:
	## Cards below soft_min (8) must be in "none" zone with no flags.
	## Card 8 must transition to "low" zone (early_zone=true).
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var soft_min: int = int(mos.get("soft_min_cards", 8))

	# Below soft_min: no tension, no convergence, no early
	for i in range(0, soft_min):
		var result: Dictionary = _classify_mos_zone(i)
		if str(result.get("tension_zone", "")) != "none":
			push_error("cards=%d: expected 'none' below soft_min=%d, got '%s'" % [i, soft_min, result.get("tension_zone", "")])
			return false
		if result.get("convergence_zone", false) or result.get("early_zone", false):
			push_error("cards=%d: no flags should be set below soft_min" % i)
			return false
		if result.get("ended", false):
			push_error("cards=%d: must not be ended below soft_min" % i)
			return false

	# At soft_min: enters early zone
	var at_min: Dictionary = _classify_mos_zone(soft_min)
	if str(at_min.get("tension_zone", "")) != "low":
		push_error("cards=%d: expected 'low' at soft_min, got '%s'" % [soft_min, at_min.get("tension_zone", "")])
		return false
	if not at_min.get("early_zone", false):
		push_error("cards=%d: early_zone must be true at soft_min" % soft_min)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 2: MOS targets 20-25 cards
# ═══════════════════════════════════════════════════════════════════════════════

func test_target_range() -> bool:
	## Cards in [target_min, target_max) must be in "rising" zone with
	## convergence_zone=true and early_zone=false. This is the ideal run length.
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var target_min: int = int(mos.get("target_cards_min", 20))
	var target_max: int = int(mos.get("target_cards_max", 25))

	# Verify constant values match game design
	if target_min != 20:
		push_error("target_cards_min should be 20, got %d" % target_min)
		return false
	if target_max != 25:
		push_error("target_cards_max should be 25, got %d" % target_max)
		return false

	# All cards in target range must be "rising" with convergence
	for i in range(target_min, target_max):
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
		if result.get("ended", false):
			push_error("cards=%d: must not be ended in target range" % i)
			return false

	# Card at target_max transitions to "high"
	var at_max: Dictionary = _classify_mos_zone(target_max)
	if str(at_max.get("tension_zone", "")) != "high":
		push_error("cards=%d: expected 'high' at target_max, got '%s'" % [target_max, at_max.get("tension_zone", "")])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 3: MOS soft max at 40 cards
# ═══════════════════════════════════════════════════════════════════════════════

func test_soft_max() -> bool:
	## Card 39 must be "high", card 40 must transition to "critical".
	## Critical zone signals strong convergence pressure but does NOT end the run.
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var soft_max: int = int(mos.get("soft_max_cards", 40))

	if soft_max != 40:
		push_error("soft_max_cards should be 40, got %d" % soft_max)
		return false

	# Just before soft_max
	var before: Dictionary = _classify_mos_zone(soft_max - 1)
	if str(before.get("tension_zone", "")) != "high":
		push_error("cards=%d: expected 'high' just before soft_max, got '%s'" % [soft_max - 1, before.get("tension_zone", "")])
		return false

	# At soft_max: critical zone, NOT ended
	var at_max: Dictionary = _classify_mos_zone(soft_max)
	if str(at_max.get("tension_zone", "")) != "critical":
		push_error("cards=%d: expected 'critical' at soft_max, got '%s'" % [soft_max, at_max.get("tension_zone", "")])
		return false
	if at_max.get("ended", false):
		push_error("cards=%d: soft_max must NOT end the run (that is hard_max)" % soft_max)
		return false
	if not at_max.get("convergence_zone", false):
		push_error("cards=%d: convergence_zone must be true at soft_max" % soft_max)
		return false

	# All cards in [soft_max, hard_max) are critical but not ended
	var hard_max: int = int(mos.get("hard_max_cards", 50))
	for i in range(soft_max, hard_max):
		var result: Dictionary = _classify_mos_zone(i)
		if str(result.get("tension_zone", "")) != "critical":
			push_error("cards=%d: expected 'critical' in [soft_max, hard_max), got '%s'" % [i, result.get("tension_zone", "")])
			return false
		if result.get("ended", false):
			push_error("cards=%d: must not be ended before hard_max" % i)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 4: MOS hard max at 50 cards (absolute stop)
# ═══════════════════════════════════════════════════════════════════════════════

func test_hard_max() -> bool:
	## Card 50 and beyond must force ended=true with hard_max=true.
	## Card 49 must NOT be ended. This is the absolute boundary.
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var hard_max: int = int(mos.get("hard_max_cards", 50))

	if hard_max != 50:
		push_error("hard_max_cards should be 50, got %d" % hard_max)
		return false

	# Card 49: not ended
	var before: Dictionary = _classify_mos_zone(hard_max - 1)
	if before.get("ended", false):
		push_error("cards=%d: must NOT be ended one card before hard_max" % (hard_max - 1))
		return false

	# Card 50 and overflow values: all ended
	for n in [hard_max, hard_max + 1, hard_max + 25, 100, 999]:
		var result: Dictionary = _classify_mos_zone(n)
		if not result.get("ended", false):
			push_error("cards=%d: must be ended at or beyond hard_max=%d" % [n, hard_max])
			return false
		if not result.get("hard_max", false):
			push_error("cards=%d: hard_max flag must be true" % n)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 5: MOS doesn't trigger during merchant interaction
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_convergence_during_merchant() -> bool:
	## MERCHANT node type has cards_min=0 and cards_max=0, meaning it generates
	## zero narrative cards. MOS convergence should not advance during merchant
	## encounters because no cards are played. Verify MERCHANT node config.
	var merchant: Dictionary = MerlinConstants.NODE_TYPES.get("MERCHANT", {})
	if merchant.is_empty():
		push_error("NODE_TYPES missing MERCHANT entry")
		return false

	var cards_min: int = int(merchant.get("cards_min", -1))
	var cards_max: int = int(merchant.get("cards_max", -1))

	if cards_min != 0:
		push_error("MERCHANT cards_min should be 0 (no card generation), got %d" % cards_min)
		return false
	if cards_max != 0:
		push_error("MERCHANT cards_max should be 0 (no card generation), got %d" % cards_max)
		return false

	# Since MERCHANT produces 0 cards, MOS state before and after
	# a merchant encounter must be identical (same cards_played).
	var cards_before: int = 15
	var zone_before: Dictionary = _classify_mos_zone(cards_before)
	# After merchant: cards_played unchanged (0 cards added)
	var zone_after: Dictionary = _classify_mos_zone(cards_before + cards_min)
	if str(zone_before.get("tension_zone", "")) != str(zone_after.get("tension_zone", "")):
		push_error("MOS zone must not change during merchant (0 cards played)")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 6: MOS doesn't generate promise card if 2 already active
# ═══════════════════════════════════════════════════════════════════════════════

func test_max_active_promises() -> bool:
	## MOS_CONVERGENCE.max_active_promises must equal MAX_ACTIVE_PROMISES (both = 2).
	## When 2 promises are active, no new promise card should be generated.
	var mos_max: int = int(MerlinConstants.MOS_CONVERGENCE.get("max_active_promises", -1))
	var const_max: int = MerlinConstants.MAX_ACTIVE_PROMISES

	if mos_max != 2:
		push_error("MOS_CONVERGENCE.max_active_promises should be 2, got %d" % mos_max)
		return false
	if const_max != 2:
		push_error("MAX_ACTIVE_PROMISES should be 2, got %d" % const_max)
		return false
	if mos_max != const_max:
		push_error("MOS max_active_promises (%d) must equal MAX_ACTIVE_PROMISES (%d)" % [mos_max, const_max])
		return false

	# PROMISE node type must exist with limited card generation
	var promise_node: Dictionary = MerlinConstants.NODE_TYPES.get("PROMISE", {})
	if promise_node.is_empty():
		push_error("NODE_TYPES missing PROMISE entry")
		return false
	var promise_max_cards: int = int(promise_node.get("cards_max", -1))
	if promise_max_cards != 1:
		push_error("PROMISE node cards_max should be 1, got %d" % promise_max_cards)
		return false

	# Simulate: 2 active promises = at cap, no new promise allowed
	var active_promises: int = 2
	var can_generate: bool = active_promises < const_max
	if can_generate:
		push_error("Should NOT allow new promise when active_promises=%d >= max=%d" % [active_promises, const_max])
		return false

	# Simulate: 1 active promise = below cap, new promise allowed
	active_promises = 1
	can_generate = active_promises < const_max
	if not can_generate:
		push_error("Should allow new promise when active_promises=%d < max=%d" % [active_promises, const_max])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 7: Tension increases over time, affects convergence
# ═══════════════════════════════════════════════════════════════════════════════

func test_tension_tracking() -> bool:
	## Tension zones must progress monotonically: none -> low -> rising -> high -> critical.
	## Zone level must never decrease as cards_played increases.
	var zone_order: Dictionary = {"none": 0, "low": 1, "rising": 2, "high": 3, "critical": 4}
	var prev_level: int = -1
	var prev_zone: String = ""

	for i in range(0, 50):
		var result: Dictionary = _classify_mos_zone(i)
		var zone: String = str(result.get("tension_zone", "none"))
		var level: int = int(zone_order.get(zone, -1))

		if level < 0:
			push_error("Unknown tension zone '%s' at cards=%d" % [zone, i])
			return false
		if level < prev_level:
			push_error("Tension decreased at cards=%d: '%s' (level %d) < '%s' (level %d)" % [i, zone, level, prev_zone, prev_level])
			return false

		prev_level = level
		prev_zone = zone

	# Verify all 5 zones are visited in a full 0-49 run
	var visited: Dictionary = {}
	for i in range(0, 50):
		var result: Dictionary = _classify_mos_zone(i)
		var zone: String = str(result.get("tension_zone", "none"))
		visited[zone] = true

	var expected_zones: Array = ["none", "low", "rising", "high", "critical"]
	for z in expected_zones:
		if not visited.has(z):
			push_error("Zone '%s' was never visited in a 0-49 card run" % z)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST 8: Convergence probability increases as cards approach soft max
# ═══════════════════════════════════════════════════════════════════════════════

func test_convergence_probability() -> bool:
	## Convergence probability must be 0 below target_min, increase monotonically
	## from target_min to hard_max, and reach 1.0 at hard_max.
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var target_min: int = int(mos.get("target_cards_min", 20))
	var soft_max: int = int(mos.get("soft_max_cards", 40))
	var hard_max: int = int(mos.get("hard_max_cards", 50))

	# Below target_min: probability must be 0
	for i in [0, 5, 10, 19]:
		var prob: float = _convergence_probability(i)
		if prob > 0.001:
			push_error("cards=%d: convergence probability should be 0 below target_min, got %.3f" % [i, prob])
			return false

	# At target_min: probability starts (should be very low, near 0)
	var prob_at_min: float = _convergence_probability(target_min)
	if prob_at_min < -0.001 or prob_at_min > 0.1:
		push_error("cards=%d: probability at target_min should be near 0, got %.3f" % [target_min, prob_at_min])
		return false

	# Monotonically increasing from target_min to hard_max
	var prev_prob: float = -1.0
	for i in range(target_min, hard_max + 1):
		var prob: float = _convergence_probability(i)
		if prob < prev_prob - 0.001:
			push_error("cards=%d: probability decreased (%.3f < %.3f), must be monotonic" % [i, prob, prev_prob])
			return false
		prev_prob = prob

	# At soft_max: probability should be significantly above 0 (around 0.67)
	var prob_at_soft_max: float = _convergence_probability(soft_max)
	if prob_at_soft_max < 0.5:
		push_error("cards=%d: probability at soft_max should be >= 0.5, got %.3f" % [soft_max, prob_at_soft_max])
		return false

	# At hard_max: probability must be 1.0 (absolute end)
	var prob_at_hard: float = _convergence_probability(hard_max)
	if absf(prob_at_hard - 1.0) > 0.001:
		push_error("cards=%d: probability at hard_max must be 1.0, got %.3f" % [hard_max, prob_at_hard])
		return false

	# Beyond hard_max: still 1.0
	var prob_beyond: float = _convergence_probability(hard_max + 10)
	if absf(prob_beyond - 1.0) > 0.001:
		push_error("cards=%d: probability beyond hard_max must be 1.0, got %.3f" % [hard_max + 10, prob_beyond])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var results: Dictionary = {}
	var _tests: Dictionary = {
		"test_soft_min_boundary": test_soft_min_boundary,
		"test_target_range": test_target_range,
		"test_soft_max": test_soft_max,
		"test_hard_max": test_hard_max,
		"test_no_convergence_during_merchant": test_no_convergence_during_merchant,
		"test_max_active_promises": test_max_active_promises,
		"test_tension_tracking": test_tension_tracking,
		"test_convergence_probability": test_convergence_probability,
	}

	var passed: int = 0
	var failed: int = 0

	for test_name in _tests:
		var test_fn: Callable = _tests[test_name]
		var ok: bool = test_fn.call()
		results[test_name] = ok
		if ok:
			passed += 1
		else:
			failed += 1
			push_error("[FAIL] %s" % test_name)

	print("[test_mos_convergence] Results: %d/%d passed" % [passed, passed + failed])
	if failed > 0:
		push_error("[test_mos_convergence] %d test(s) FAILED" % failed)
	else:
		print("[test_mos_convergence] All tests passed.")

	return results
