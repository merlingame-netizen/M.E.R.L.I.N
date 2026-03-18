## =============================================================================
## Unit Tests — MerlinReputationSystem (headless-safe, RefCounted)
## =============================================================================
## Covers: apply_delta, get_available_endings, get_unlocked_content,
##         get_dominant_faction, describe_factions, validation helpers,
##         instance API (add_reputation, clamp, cap_per_card, thresholds)
## Converted from GutTest to RefCounted for headless runner compatibility.
## =============================================================================

extends RefCounted


func _fail(msg: String) -> bool:
	push_error(msg)
	return false


func _make_factions(druides: float, anciens: float, korrigans: float, niamh: float, ankou: float) -> Dictionary:
	return {"druides": druides, "anciens": anciens, "korrigans": korrigans, "niamh": niamh, "ankou": ankou}


func _make_rep() -> MerlinReputationSystem:
	return MerlinReputationSystem.new()


# ═══════════════════════════════════════════════════════════════════════════════
# apply_delta (static)
# ═══════════════════════════════════════════════════════════════════════════════

func test_apply_delta_basic() -> bool:
	var factions: Dictionary = _make_factions(30.0, 0.0, 0.0, 0.0, 0.0)
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "druides", 20.0)
	if result["druides"] != 50.0:
		return _fail("apply_delta: expected 50, got %s" % str(result["druides"]))
	if factions["druides"] != 30.0:
		return _fail("apply_delta: original mutated")
	return true


func test_apply_delta_clamped_max() -> bool:
	var factions: Dictionary = _make_factions(90.0, 0.0, 0.0, 0.0, 0.0)
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "druides", 20.0)
	if result["druides"] != 100.0:
		return _fail("apply_delta clamp max: expected 100, got %s" % str(result["druides"]))
	return true


func test_apply_delta_clamped_min() -> bool:
	var factions: Dictionary = _make_factions(5.0, 0.0, 0.0, 0.0, 0.0)
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "druides", -20.0)
	if result["druides"] != 0.0:
		return _fail("apply_delta clamp min: expected 0, got %s" % str(result["druides"]))
	return true


func test_apply_delta_invalid_faction() -> bool:
	var factions: Dictionary = _make_factions(50.0, 0.0, 0.0, 0.0, 0.0)
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "humains", 10.0)
	if result.has("humains"):
		return _fail("apply_delta: invalid faction should not be added")
	if result["druides"] != 50.0:
		return _fail("apply_delta: other factions should be unchanged")
	return true


func test_apply_delta_negative() -> bool:
	var factions: Dictionary = _make_factions(60.0, 0.0, 0.0, 0.0, 0.0)
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "druides", -15.0)
	if result["druides"] != 45.0:
		return _fail("apply_delta negative: expected 45, got %s" % str(result["druides"]))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_available_endings
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_endings_below_threshold() -> bool:
	var factions: Dictionary = _make_factions(79.9, 79.9, 79.9, 79.9, 79.9)
	var endings: Array[String] = MerlinReputationSystem.get_available_endings(factions)
	if endings.size() != 0:
		return _fail("endings below 80: expected 0, got %d" % endings.size())
	return true


func test_single_ending_at_threshold() -> bool:
	var factions: Dictionary = _make_factions(80.0, 0.0, 0.0, 0.0, 0.0)
	var endings: Array[String] = MerlinReputationSystem.get_available_endings(factions)
	if endings.size() != 1 or not endings.has("druides"):
		return _fail("single ending at 80: expected [druides], got %s" % str(endings))
	return true


func test_multiple_endings_available() -> bool:
	var factions: Dictionary = _make_factions(85.0, 90.0, 0.0, 80.0, 0.0)
	var endings: Array[String] = MerlinReputationSystem.get_available_endings(factions)
	if endings.size() != 3:
		return _fail("multiple endings: expected 3, got %d" % endings.size())
	return true


func test_all_endings_at_100() -> bool:
	var factions: Dictionary = _make_factions(100.0, 100.0, 100.0, 100.0, 100.0)
	var endings: Array[String] = MerlinReputationSystem.get_available_endings(factions)
	if endings.size() != 5:
		return _fail("all endings at 100: expected 5, got %d" % endings.size())
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_unlocked_content
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_content_below_threshold() -> bool:
	var factions: Dictionary = _make_factions(49.9, 0.0, 0.0, 0.0, 0.0)
	var content: Array[String] = MerlinReputationSystem.get_unlocked_content(factions)
	if content.size() != 0:
		return _fail("content below 50: expected 0, got %d" % content.size())
	return true


func test_content_at_threshold() -> bool:
	var factions: Dictionary = _make_factions(50.0, 0.0, 0.0, 0.0, 0.0)
	var content: Array[String] = MerlinReputationSystem.get_unlocked_content(factions)
	if content.size() != 1 or not content.has("druides"):
		return _fail("content at 50: expected [druides], got %s" % str(content))
	return true


func test_ending_also_unlocks_content() -> bool:
	var factions: Dictionary = _make_factions(0.0, 80.0, 0.0, 0.0, 0.0)
	var content: Array[String] = MerlinReputationSystem.get_unlocked_content(factions)
	if not content.has("anciens"):
		return _fail("80 should unlock content too")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_dominant_faction
# ═══════════════════════════════════════════════════════════════════════════════

func test_dominant_faction_single() -> bool:
	var factions: Dictionary = _make_factions(0.0, 0.0, 75.0, 0.0, 0.0)
	var dominant: String = MerlinReputationSystem.get_dominant_faction(factions)
	if dominant != "korrigans":
		return _fail("dominant single: expected korrigans, got %s" % dominant)
	return true


func test_dominant_faction_all_zero() -> bool:
	var factions: Dictionary = _make_factions(0.0, 0.0, 0.0, 0.0, 0.0)
	var dominant: String = MerlinReputationSystem.get_dominant_faction(factions)
	if dominant != "":
		return _fail("dominant all zero: expected empty, got %s" % dominant)
	return true


func test_dominant_faction_uses_max() -> bool:
	var factions: Dictionary = _make_factions(60.0, 70.0, 65.0, 55.0, 45.0)
	var dominant: String = MerlinReputationSystem.get_dominant_faction(factions)
	if dominant != "anciens":
		return _fail("dominant max: expected anciens, got %s" % dominant)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# describe_factions
# ═══════════════════════════════════════════════════════════════════════════════

func test_describe_factions_format() -> bool:
	var factions: Dictionary = _make_factions(45.0, 12.0, 78.0, 5.0, 30.0)
	var desc: String = MerlinReputationSystem.describe_factions(factions)
	if not desc.contains("Druides:45") or not desc.contains("Korrigans:78"):
		return _fail("describe format missing expected content: %s" % desc)
	return true


func test_describe_factions_all_zero() -> bool:
	var factions: Dictionary = _make_factions(0.0, 0.0, 0.0, 0.0, 0.0)
	var desc: String = MerlinReputationSystem.describe_factions(factions)
	if desc.length() == 0 or not desc.contains("Druides:0"):
		return _fail("describe all zero: unexpected output")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# build_default_factions
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_default_factions() -> bool:
	var factions: Dictionary = MerlinReputationSystem.build_default_factions()
	if factions.size() != 5:
		return _fail("default factions: expected 5, got %d" % factions.size())
	for faction in MerlinReputationSystem.FACTIONS:
		if not factions.has(faction) or factions[faction] != 0.0:
			return _fail("default factions: %s missing or non-zero" % faction)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# is_valid_faction
# ═══════════════════════════════════════════════════════════════════════════════

func test_valid_factions() -> bool:
	for faction in MerlinReputationSystem.FACTIONS:
		if not MerlinReputationSystem.is_valid_faction(faction):
			return _fail("is_valid_faction: %s should be valid" % faction)
	return true


func test_invalid_faction() -> bool:
	if MerlinReputationSystem.is_valid_faction("humains"):
		return _fail("humains should be invalid")
	if MerlinReputationSystem.is_valid_faction(""):
		return _fail("empty string should be invalid")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_tier_label
# ═══════════════════════════════════════════════════════════════════════════════

func test_tier_label_honore() -> bool:
	if MerlinReputationSystem.get_tier_label(80.0) != "Honore":
		return _fail("tier 80 should be Honore, got %s" % MerlinReputationSystem.get_tier_label(80.0))
	if MerlinReputationSystem.get_tier_label(100.0) != "Honore":
		return _fail("tier 100 should be Honore")
	return true


func test_tier_label_sympathisant() -> bool:
	if MerlinReputationSystem.get_tier_label(50.0) != "Sympathisant":
		return _fail("tier 50 should be Sympathisant, got %s" % MerlinReputationSystem.get_tier_label(50.0))
	if MerlinReputationSystem.get_tier_label(79.9) != "Sympathisant":
		return _fail("tier 79.9 should be Sympathisant")
	return true


func test_tier_label_neutre() -> bool:
	if MerlinReputationSystem.get_tier_label(20.0) != "Neutre":
		return _fail("tier 20 should be Neutre, got %s" % MerlinReputationSystem.get_tier_label(20.0))
	if MerlinReputationSystem.get_tier_label(49.9) != "Neutre":
		return _fail("tier 49.9 should be Neutre")
	return true


func test_tier_label_mefiant() -> bool:
	if MerlinReputationSystem.get_tier_label(5.0) != "Mefiant":
		return _fail("tier 5 should be Mefiant, got %s" % MerlinReputationSystem.get_tier_label(5.0))
	if MerlinReputationSystem.get_tier_label(19.9) != "Mefiant":
		return _fail("tier 19.9 should be Mefiant")
	return true


func test_tier_label_hostile() -> bool:
	if MerlinReputationSystem.get_tier_label(0.0) != "Hostile":
		return _fail("tier 0 should be Hostile, got %s" % MerlinReputationSystem.get_tier_label(0.0))
	if MerlinReputationSystem.get_tier_label(4.9) != "Hostile":
		return _fail("tier 4.9 should be Hostile")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# INSTANCE API — Stateful reputation tracking
# ═══════════════════════════════════════════════════════════════════════════════

func test_initial_reputation_is_zero() -> bool:
	var rep: MerlinReputationSystem = _make_rep()
	for faction in MerlinReputationSystem.FACTIONS:
		if rep.get_reputation(faction) != 0.0:
			return _fail("initial rep for %s should be 0" % faction)
	return true


func test_add_reputation_clamps_0_100() -> bool:
	var rep: MerlinReputationSystem = _make_rep()
	rep.add_reputation("druides", 20.0)
	rep.add_reputation("druides", 20.0)
	rep.add_reputation("druides", 20.0)
	rep.add_reputation("druides", 20.0)
	rep.add_reputation("druides", 20.0)
	var val_max: float = rep.add_reputation("druides", 20.0)
	if val_max != 100.0:
		return _fail("clamp max: expected 100, got %s" % str(val_max))
	rep.reset()
	rep.add_reputation("ankou", 5.0)
	var val_min: float = rep.add_reputation("ankou", -20.0)
	if val_min != 0.0:
		return _fail("clamp min: expected 0, got %s" % str(val_min))
	return true


func test_reputation_threshold_50_content() -> bool:
	var rep: MerlinReputationSystem = _make_rep()
	if rep.has_content_threshold("druides"):
		return _fail("should not have content at 0")
	rep.add_reputation("druides", 20.0)
	rep.add_reputation("druides", 20.0)
	if rep.has_content_threshold("druides"):
		return _fail("should not have content at 40")
	rep.add_reputation("druides", 10.0)
	if not rep.has_content_threshold("druides"):
		return _fail("should have content at 50")
	return true


func test_reputation_threshold_80_ending() -> bool:
	var rep: MerlinReputationSystem = _make_rep()
	if rep.has_ending_threshold("korrigans"):
		return _fail("should not have ending at 0")
	rep.add_reputation("korrigans", 20.0)
	rep.add_reputation("korrigans", 20.0)
	rep.add_reputation("korrigans", 20.0)
	rep.add_reputation("korrigans", 20.0)
	if not rep.has_ending_threshold("korrigans"):
		return _fail("should have ending at 80")
	return true


func test_cross_run_persistence() -> bool:
	var rep: MerlinReputationSystem = _make_rep()
	rep.add_reputation("niamh", 15.0)
	rep.add_reputation("niamh", 10.0)
	var all_reps: Dictionary = rep.get_all_reputations()
	if float(all_reps["niamh"]) != 25.0:
		return _fail("persistence: expected 25, got %s" % str(all_reps["niamh"]))
	rep.reset()
	if rep.get_reputation("niamh") != 0.0:
		return _fail("reset should zero reputation")
	return true


func test_cap_per_card_20() -> bool:
	var rep: MerlinReputationSystem = _make_rep()
	var result: float = rep.add_reputation("anciens", 50.0)
	if result != 20.0:
		return _fail("cap +50 should give 20, got %s" % str(result))
	rep.reset()
	rep.add_reputation("anciens", 20.0)
	rep.add_reputation("anciens", 20.0)
	var result_neg: float = rep.add_reputation("anciens", -35.0)
	if result_neg != 20.0:
		return _fail("cap -35 from 40 should give 20, got %s" % str(result_neg))
	return true


func test_get_reputation_invalid_faction() -> bool:
	var rep: MerlinReputationSystem = _make_rep()
	if rep.get_reputation("humains") != 0.0:
		return _fail("invalid faction should return 0")
	return true


func test_add_reputation_invalid_faction() -> bool:
	var rep: MerlinReputationSystem = _make_rep()
	if rep.add_reputation("humains", 10.0) != -1.0:
		return _fail("invalid faction add should return -1")
	return true


func test_get_dominant_instance() -> bool:
	var rep: MerlinReputationSystem = _make_rep()
	rep.add_reputation("druides", 15.0)
	rep.add_reputation("ankou", 20.0)
	if rep.get_dominant() != "ankou":
		return _fail("dominant: expected ankou, got %s" % rep.get_dominant())
	return true


func test_get_all_reputations_returns_copy() -> bool:
	var rep: MerlinReputationSystem = _make_rep()
	rep.add_reputation("druides", 10.0)
	var copy: Dictionary = rep.get_all_reputations()
	copy["druides"] = 999.0
	if rep.get_reputation("druides") != 10.0:
		return _fail("modifying copy should not affect instance")
	return true
