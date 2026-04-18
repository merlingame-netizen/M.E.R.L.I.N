## test_reputation_unit.gd
## Unit tests for MerlinReputationSystem — RefCounted pattern, no GUT dependency.
## Covers edge cases and methods NOT tested in test_reputation_system.gd (GUT).
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error+return false.

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

static func _make(d: float, a: float, k: float, n: float, ak: float) -> Dictionary:
	return {
		"druides": d,
		"anciens": a,
		"korrigans": k,
		"niamh": n,
		"ankou": ak,
	}


static func _approx_eq(a: float, b: float, epsilon: float = 0.001) -> bool:
	return absf(a - b) < epsilon


# ═══════════════════════════════════════════════════════════════════════════════
# get_tier_label — Correct thresholds per source (Honore>=80, Sympathisant>=50,
#                  Neutre>=20, Mefiant>=5, Hostile<5)
# ═══════════════════════════════════════════════════════════════════════════════

func test_tier_label_honore_at_80() -> bool:
	var label: String = MerlinReputationSystem.get_tier_label(80.0)
	if label != "Honore":
		push_error("Expected 'Honore' at 80.0, got: " + label)
		return false
	return true


func test_tier_label_honore_at_100() -> bool:
	var label: String = MerlinReputationSystem.get_tier_label(100.0)
	if label != "Honore":
		push_error("Expected 'Honore' at 100.0, got: " + label)
		return false
	return true


func test_tier_label_sympathisant_at_50() -> bool:
	var label: String = MerlinReputationSystem.get_tier_label(50.0)
	if label != "Sympathisant":
		push_error("Expected 'Sympathisant' at 50.0, got: " + label)
		return false
	return true


func test_tier_label_sympathisant_at_79() -> bool:
	var label: String = MerlinReputationSystem.get_tier_label(79.9)
	if label != "Sympathisant":
		push_error("Expected 'Sympathisant' at 79.9, got: " + label)
		return false
	return true


func test_tier_label_neutre_boundaries() -> bool:
	var at_20: String = MerlinReputationSystem.get_tier_label(20.0)
	var at_49: String = MerlinReputationSystem.get_tier_label(49.9)
	if at_20 != "Neutre":
		push_error("Expected 'Neutre' at 20.0, got: " + at_20)
		return false
	if at_49 != "Neutre":
		push_error("Expected 'Neutre' at 49.9, got: " + at_49)
		return false
	return true


func test_tier_label_mefiant_boundaries() -> bool:
	var at_5: String = MerlinReputationSystem.get_tier_label(5.0)
	var at_19: String = MerlinReputationSystem.get_tier_label(19.9)
	if at_5 != "Mefiant":
		push_error("Expected 'Mefiant' at 5.0, got: " + at_5)
		return false
	if at_19 != "Mefiant":
		push_error("Expected 'Mefiant' at 19.9, got: " + at_19)
		return false
	return true


func test_tier_label_hostile_below_5() -> bool:
	var at_0: String = MerlinReputationSystem.get_tier_label(0.0)
	var at_4: String = MerlinReputationSystem.get_tier_label(4.9)
	if at_0 != "Hostile":
		push_error("Expected 'Hostile' at 0.0, got: " + at_0)
		return false
	if at_4 != "Hostile":
		push_error("Expected 'Hostile' at 4.9, got: " + at_4)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# apply_delta — edge cases not covered by GUT tests
# ═══════════════════════════════════════════════════════════════════════════════

func test_apply_delta_zero_is_noop() -> bool:
	var factions: Dictionary = _make(40.0, 20.0, 10.0, 5.0, 0.0)
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "druides", 0.0)
	if not _approx_eq(result["druides"], 40.0):
		push_error("Zero delta should not change value, got: " + str(result["druides"]))
		return false
	return true


func test_apply_delta_empty_dict() -> bool:
	var empty: Dictionary = {}
	var result: Dictionary = MerlinReputationSystem.apply_delta(empty, "druides", 10.0)
	# druides is valid faction, missing key defaults to 0.0 → 0+10=10
	if not _approx_eq(result.get("druides", -1.0), 10.0):
		push_error("apply_delta on empty dict should create entry at delta value, got: " + str(result))
		return false
	return true


func test_apply_delta_preserves_other_factions() -> bool:
	var factions: Dictionary = _make(10.0, 20.0, 30.0, 40.0, 50.0)
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "korrigans", 15.0)
	if not _approx_eq(result["druides"], 10.0):
		push_error("druides should be unchanged")
		return false
	if not _approx_eq(result["anciens"], 20.0):
		push_error("anciens should be unchanged")
		return false
	if not _approx_eq(result["korrigans"], 45.0):
		push_error("korrigans should be 45.0, got: " + str(result["korrigans"]))
		return false
	if not _approx_eq(result["niamh"], 40.0):
		push_error("niamh should be unchanged")
		return false
	if not _approx_eq(result["ankou"], 50.0):
		push_error("ankou should be unchanged")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# Instance API — add_reputation cap edge cases
# ═══════════════════════════════════════════════════════════════════════════════

func test_add_reputation_exact_cap_positive() -> bool:
	var rep: MerlinReputationSystem = MerlinReputationSystem.new()
	var expected: float = float(MerlinConstants.FACTION_SCORE_START) + 20.0
	var result: float = rep.add_reputation("druides", 20.0)
	if not _approx_eq(result, expected):
		push_error("Exact +20 from start should give %f, got: %f" % [expected, result])
		return false
	return true


func test_add_reputation_exact_cap_negative() -> bool:
	var rep: MerlinReputationSystem = MerlinReputationSystem.new()
	var s: float = float(MerlinConstants.FACTION_SCORE_START)
	rep.add_reputation("ankou", 20.0)
	rep.add_reputation("ankou", 20.0)  # now at s+40
	var expected: float = s + 40.0 - 20.0
	var result: float = rep.add_reputation("ankou", -20.0)
	if not _approx_eq(result, expected):
		push_error("Exact -20 from %f should give %f, got: %f" % [s + 40.0, expected, result])
		return false
	return true


func test_add_reputation_multiple_factions_independent() -> bool:
	var rep: MerlinReputationSystem = MerlinReputationSystem.new()
	var s: float = float(MerlinConstants.FACTION_SCORE_START)
	rep.add_reputation("druides", 15.0)
	rep.add_reputation("ankou", 10.0)
	rep.add_reputation("niamh", 20.0)
	if not _approx_eq(rep.get_reputation("druides"), s + 15.0):
		push_error("druides should be %f" % (s + 15.0))
		return false
	if not _approx_eq(rep.get_reputation("ankou"), s + 10.0):
		push_error("ankou should be %f" % (s + 10.0))
		return false
	if not _approx_eq(rep.get_reputation("niamh"), s + 20.0):
		push_error("niamh should be %f" % (s + 20.0))
		return false
	if not _approx_eq(rep.get_reputation("korrigans"), s):
		push_error("korrigans should still be %f" % s)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# has_content_threshold / has_ending_threshold — invalid faction
# ═══════════════════════════════════════════════════════════════════════════════

func test_has_content_threshold_invalid_faction() -> bool:
	var rep: MerlinReputationSystem = MerlinReputationSystem.new()
	# Invalid faction defaults to 0.0, which is < 50 → false
	var result: bool = rep.has_content_threshold("humains")
	if result:
		push_error("Invalid faction should not have content threshold")
		return false
	return true


func test_has_ending_threshold_invalid_faction() -> bool:
	var rep: MerlinReputationSystem = MerlinReputationSystem.new()
	var result: bool = rep.has_ending_threshold("humains")
	if result:
		push_error("Invalid faction should not have ending threshold")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_dominant — tie-breaking (first in FACTIONS order wins)
# ═══════════════════════════════════════════════════════════════════════════════

func test_dominant_tie_first_wins() -> bool:
	# druides and anciens both at 50 — druides comes first in FACTIONS array
	var factions: Dictionary = _make(50.0, 50.0, 0.0, 0.0, 0.0)
	var dominant: String = MerlinReputationSystem.get_dominant_faction(factions)
	if dominant != "druides":
		push_error("On tie, first faction in FACTIONS order should win, got: " + dominant)
		return false
	return true


func test_dominant_instance_after_reset() -> bool:
	var result: String = MerlinReputationSystem.get_dominant_faction({})
	if result != "":
		push_error("Empty factions dict should have no dominant, got: " + result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_available_endings / get_unlocked_content — empty dict
# ═══════════════════════════════════════════════════════════════════════════════

func test_available_endings_empty_dict() -> bool:
	var empty: Dictionary = {}
	var endings: Array[String] = MerlinReputationSystem.get_available_endings(empty)
	if endings.size() != 0:
		push_error("Empty dict should yield no endings, got: " + str(endings.size()))
		return false
	return true


func test_unlocked_content_empty_dict() -> bool:
	var empty: Dictionary = {}
	var content: Array[String] = MerlinReputationSystem.get_unlocked_content(empty)
	if content.size() != 0:
		push_error("Empty dict should yield no content, got: " + str(content.size()))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# describe_factions — partial/empty dict
# ═══════════════════════════════════════════════════════════════════════════════

func test_describe_factions_empty_dict() -> bool:
	var empty: Dictionary = {}
	var desc: String = MerlinReputationSystem.describe_factions(empty)
	# All factions should appear with value 0
	if not desc.contains("Druides:0"):
		push_error("Empty dict description should contain Druides:0, got: " + desc)
		return false
	if not desc.contains("Ankou:0"):
		push_error("Empty dict description should contain Ankou:0, got: " + desc)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# reset — double reset is safe
# ═══════════════════════════════════════════════════════════════════════════════

func test_double_reset_safe() -> bool:
	var rep: MerlinReputationSystem = MerlinReputationSystem.new()
	rep.add_reputation("druides", 15.0)
	rep.reset()
	rep.reset()
	var expected: float = float(MerlinConstants.FACTION_SCORE_START)
	var val: float = rep.get_reputation("druides")
	if not _approx_eq(val, expected):
		push_error("Double reset should leave all at %f, got: %f" % [expected, val])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS sanity
# ═══════════════════════════════════════════════════════════════════════════════

func test_constants_values() -> bool:
	if MerlinReputationSystem.FACTIONS.size() != 5:
		push_error("Expected 5 factions, got: " + str(MerlinReputationSystem.FACTIONS.size()))
		return false
	if not _approx_eq(MerlinReputationSystem.THRESHOLD_CONTENT, 50.0):
		push_error("THRESHOLD_CONTENT should be 50.0")
		return false
	if not _approx_eq(MerlinReputationSystem.THRESHOLD_ENDING, 80.0):
		push_error("THRESHOLD_ENDING should be 80.0")
		return false
	if not _approx_eq(MerlinReputationSystem.CAP_PER_CARD, 20.0):
		push_error("CAP_PER_CARD should be 20.0")
		return false
	if not _approx_eq(MerlinReputationSystem.VALUE_MIN, 0.0):
		push_error("VALUE_MIN should be 0.0")
		return false
	if not _approx_eq(MerlinReputationSystem.VALUE_MAX, 100.0):
		push_error("VALUE_MAX should be 100.0")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var tests: Array[String] = [
		"test_tier_label_honore_at_80",
		"test_tier_label_honore_at_100",
		"test_tier_label_sympathisant_at_50",
		"test_tier_label_sympathisant_at_79",
		"test_tier_label_neutre_boundaries",
		"test_tier_label_mefiant_boundaries",
		"test_tier_label_hostile_below_5",
		"test_apply_delta_zero_is_noop",
		"test_apply_delta_empty_dict",
		"test_apply_delta_preserves_other_factions",
		"test_add_reputation_exact_cap_positive",
		"test_add_reputation_exact_cap_negative",
		"test_add_reputation_multiple_factions_independent",
		"test_has_content_threshold_invalid_faction",
		"test_has_ending_threshold_invalid_faction",
		"test_dominant_tie_first_wins",
		"test_dominant_instance_after_reset",
		"test_available_endings_empty_dict",
		"test_unlocked_content_empty_dict",
		"test_describe_factions_empty_dict",
		"test_double_reset_safe",
		"test_constants_values",
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
