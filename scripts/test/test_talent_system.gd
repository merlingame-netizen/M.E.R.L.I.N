## =============================================================================
## Unit Tests — MerlinTalentSystem
## =============================================================================
## Covers all public static methods of MerlinTalentSystem:
##   talent_exists, get_talent_node, get_all_talent_ids, get_branch_talents,
##   get_tier_talents, is_unlocked, prerequisites_met, can_unlock,
##   unlock_talent, get_available_talents, get_talent_effects,
##   get_reachable_talents, get_branch_total_cost, count_unlocked_in_branch,
##   get_completion_ratio, get_tree_summary + constants.
## Pattern: extends RefCounted, NO class_name, NO assert(), NO await.
## Each test returns bool. Initialize in _init().
## =============================================================================

extends RefCounted


# =============================================================================
# KNOWN VALID NODE IDs — taken directly from MerlinConstants.TALENT_NODES
# =============================================================================

const D1: String  = "druides_1"
const D2: String  = "druides_2"
const D3: String  = "druides_3"
const D4: String  = "druides_4"
const D5: String  = "druides_5"
const A1: String  = "anciens_1"
const A2: String  = "anciens_2"
const K1: String  = "korrigans_1"
const K2: String  = "korrigans_2"
const K4: String  = "korrigans_4"
const N1: String  = "niamh_1"
const N2: String  = "niamh_2"
const AN1: String = "ankou_1"
const AN2: String = "ankou_2"
const C1: String  = "central_1"
const C2: String  = "central_2"
const C4: String  = "central_4"
const HARMONIE: String = "harmonie_factions"
const PACTE: String    = "pacte_ombre_lumiere"
const EVEIL: String    = "eveil_ogham"
const INSTINCT: String = "instinct_sauvage"
const BOUCLE: String   = "boucle_eternelle"

# Expected total talent count from MerlinConstants.TALENT_NODES
# druides(5) + anciens(5) + korrigans(5) + niamh(5) + ankou(5) + central(4) + specials(6) = 35
const EXPECTED_TOTAL: int = 35
const EXPECTED_BRANCHES: int = 6


# =============================================================================
# HELPER
# =============================================================================

func _fail(msg: String) -> bool:
	push_error(msg)
	return false


# =============================================================================
# SECTION 1 — talent_exists
# =============================================================================

func test_talent_exists_valid_tier1() -> bool:
	if not MerlinTalentSystem.talent_exists(D1):
		return _fail("talent_exists: %s should exist" % D1)
	return true


func test_talent_exists_valid_special() -> bool:
	if not MerlinTalentSystem.talent_exists(HARMONIE):
		return _fail("talent_exists: %s should exist" % HARMONIE)
	return true


func test_talent_exists_invalid_empty_string() -> bool:
	if MerlinTalentSystem.talent_exists(""):
		return _fail("talent_exists: empty string should not exist")
	return true


func test_talent_exists_invalid_garbage() -> bool:
	if MerlinTalentSystem.talent_exists("not_a_real_node_xyz_999"):
		return _fail("talent_exists: garbage id should not exist")
	return true


func test_talent_exists_all_known_ids_present() -> bool:
	var ids: Array = [D1, D2, D3, D4, D5, A1, A2, K1, K2, K4, N1, N2, AN1, AN2,
		C1, C2, C4, HARMONIE, PACTE, EVEIL, INSTINCT, BOUCLE]
	for nid in ids:
		if not MerlinTalentSystem.talent_exists(nid):
			return _fail("talent_exists: known id %s not found" % nid)
	return true


# =============================================================================
# SECTION 2 — get_talent_node
# =============================================================================

func test_get_talent_node_returns_correct_name() -> bool:
	var node: Dictionary = MerlinTalentSystem.get_talent_node(D1)
	if node.is_empty():
		return _fail("get_talent_node: expected non-empty for %s" % D1)
	if str(node.get("name", "")) != "Vigueur du Chene":
		return _fail("get_talent_node: wrong name '%s'" % node.get("name", ""))
	return true


func test_get_talent_node_returns_correct_cost() -> bool:
	var node: Dictionary = MerlinTalentSystem.get_talent_node(D1)
	if int(node.get("cost", -1)) != 20:
		return _fail("get_talent_node: expected cost 20, got %d" % int(node.get("cost", -1)))
	return true


func test_get_talent_node_returns_correct_branch() -> bool:
	var node: Dictionary = MerlinTalentSystem.get_talent_node(D1)
	if str(node.get("branch", "")) != "druides":
		return _fail("get_talent_node: expected branch 'druides', got '%s'" % node.get("branch", ""))
	return true


func test_get_talent_node_returns_effect_dict() -> bool:
	var node: Dictionary = MerlinTalentSystem.get_talent_node(D1)
	var effect: Dictionary = node.get("effect", {})
	if effect.is_empty():
		return _fail("get_talent_node: expected non-empty effect dict")
	return true


func test_get_talent_node_invalid_returns_empty() -> bool:
	var node: Dictionary = MerlinTalentSystem.get_talent_node("does_not_exist")
	if not node.is_empty():
		return _fail("get_talent_node: invalid id should return empty dict, got %d keys" % node.size())
	return true


func test_get_talent_node_empty_string_returns_empty() -> bool:
	var node: Dictionary = MerlinTalentSystem.get_talent_node("")
	if not node.is_empty():
		return _fail("get_talent_node: empty string should return empty dict")
	return true


func test_get_talent_node_special_multi_prereq() -> bool:
	var node: Dictionary = MerlinTalentSystem.get_talent_node(HARMONIE)
	var prereqs: Array = node.get("prerequisites", [])
	if prereqs.size() != 3:
		return _fail("get_talent_node harmonie: expected 3 prereqs, got %d" % prereqs.size())
	return true


# =============================================================================
# SECTION 3 — get_all_talent_ids
# =============================================================================

func test_get_all_talent_ids_non_empty() -> bool:
	var ids: Array = MerlinTalentSystem.get_all_talent_ids()
	if ids.is_empty():
		return _fail("get_all_talent_ids: should not be empty")
	return true


func test_get_all_talent_ids_expected_count() -> bool:
	var ids: Array = MerlinTalentSystem.get_all_talent_ids()
	if ids.size() != EXPECTED_TOTAL:
		return _fail("get_all_talent_ids: expected %d, got %d" % [EXPECTED_TOTAL, ids.size()])
	return true


func test_get_all_talent_ids_contains_known_ids() -> bool:
	var ids: Array = MerlinTalentSystem.get_all_talent_ids()
	for nid in [D1, A1, K1, N1, AN1, C1, HARMONIE]:
		if not ids.has(nid):
			return _fail("get_all_talent_ids: missing expected id %s" % nid)
	return true


# =============================================================================
# SECTION 4 — get_branch_talents
# =============================================================================

func test_get_branch_talents_druides_count() -> bool:
	var branch: Array = MerlinTalentSystem.get_branch_talents("druides")
	if branch.size() != 5:
		return _fail("get_branch_talents druides: expected 5, got %d" % branch.size())
	return true


func test_get_branch_talents_all_belong_to_branch() -> bool:
	for b in MerlinTalentSystem.BRANCHES:
		var branch_ids: Array = MerlinTalentSystem.get_branch_talents(b)
		for nid in branch_ids:
			var node: Dictionary = MerlinTalentSystem.get_talent_node(nid)
			if str(node.get("branch", "")) != b:
				return _fail("get_branch_talents %s: node %s has wrong branch '%s'" % [b, nid, node.get("branch", "")])
	return true


func test_get_branch_talents_central_includes_specials() -> bool:
	# central branch includes central_1-4 + 6 special nodes = 10 total
	var central: Array = MerlinTalentSystem.get_branch_talents("central")
	if central.size() < 4:
		return _fail("get_branch_talents central: expected >= 4, got %d" % central.size())
	if not central.has(HARMONIE):
		return _fail("get_branch_talents central: should contain %s" % HARMONIE)
	return true


func test_get_branch_talents_invalid_returns_empty() -> bool:
	var result: Array = MerlinTalentSystem.get_branch_talents("nonexistent_branch")
	if not result.is_empty():
		return _fail("get_branch_talents invalid: expected empty, got %d" % result.size())
	return true


func test_get_branch_talents_each_branch_non_empty() -> bool:
	for b in MerlinTalentSystem.BRANCHES:
		var branch_ids: Array = MerlinTalentSystem.get_branch_talents(b)
		if branch_ids.is_empty():
			return _fail("get_branch_talents: branch %s returned empty" % b)
	return true


# =============================================================================
# SECTION 5 — get_tier_talents
# =============================================================================

func test_get_tier_talents_tier1_non_empty() -> bool:
	var tier1: Array = MerlinTalentSystem.get_tier_talents(1)
	if tier1.is_empty():
		return _fail("get_tier_talents(1): expected non-empty")
	return true


func test_get_tier_talents_tier1_all_have_correct_tier() -> bool:
	for nid in MerlinTalentSystem.get_tier_talents(1):
		var node: Dictionary = MerlinTalentSystem.get_talent_node(nid)
		if int(node.get("tier", 0)) != 1:
			return _fail("get_tier_talents(1): node %s has tier %d" % [nid, int(node.get("tier", 0))])
	return true


func test_get_tier_talents_tier1_covers_faction_branches() -> bool:
	# Each faction branch (druides/anciens/korrigans/niamh/ankou) has a tier-1 node
	var tier1: Array = MerlinTalentSystem.get_tier_talents(1)
	var faction_branches: Array = ["druides", "anciens", "korrigans", "niamh", "ankou"]
	var found: Dictionary = {}
	for nid in tier1:
		var node: Dictionary = MerlinTalentSystem.get_talent_node(nid)
		found[str(node.get("branch", ""))] = true
	for b in faction_branches:
		if not found.has(b):
			return _fail("get_tier_talents(1): no tier-1 node for faction branch %s" % b)
	return true


func test_get_tier_talents_tier5_count() -> bool:
	var tier5: Array = MerlinTalentSystem.get_tier_talents(5)
	# druides_5, anciens_5, korrigans_5, niamh_5, ankou_5 = 5
	if tier5.size() != 5:
		return _fail("get_tier_talents(5): expected 5, got %d" % tier5.size())
	return true


func test_get_tier_talents_zero_returns_empty() -> bool:
	var tier0: Array = MerlinTalentSystem.get_tier_talents(0)
	if not tier0.is_empty():
		return _fail("get_tier_talents(0): expected empty, got %d" % tier0.size())
	return true


func test_get_tier_talents_invalid_returns_empty() -> bool:
	var tier99: Array = MerlinTalentSystem.get_tier_talents(99)
	if not tier99.is_empty():
		return _fail("get_tier_talents(99): expected empty, got %d" % tier99.size())
	return true


# =============================================================================
# SECTION 6 — is_unlocked
# =============================================================================

func test_is_unlocked_true_when_in_list() -> bool:
	if not MerlinTalentSystem.is_unlocked(D1, [D1, A1]):
		return _fail("is_unlocked: expected true for %s in list" % D1)
	return true


func test_is_unlocked_false_when_not_in_list() -> bool:
	if MerlinTalentSystem.is_unlocked(A1, [D1]):
		return _fail("is_unlocked: expected false for %s not in list" % A1)
	return true


func test_is_unlocked_false_with_empty_list() -> bool:
	if MerlinTalentSystem.is_unlocked(D1, []):
		return _fail("is_unlocked: expected false with empty list")
	return true


func test_is_unlocked_invalid_id_with_empty_list() -> bool:
	if MerlinTalentSystem.is_unlocked("fake_xyz", []):
		return _fail("is_unlocked: expected false for nonexistent id")
	return true


# =============================================================================
# SECTION 7 — prerequisites_met
# =============================================================================

func test_prerequisites_met_tier1_no_prereqs() -> bool:
	# All tier-1 faction nodes have empty prerequisites
	for nid in [D1, A1, K1, N1, AN1]:
		if not MerlinTalentSystem.prerequisites_met(nid, []):
			return _fail("prerequisites_met: tier-1 node %s should have prereqs met with empty unlocked" % nid)
	return true


func test_prerequisites_met_tier2_with_prereq_unlocked() -> bool:
	if not MerlinTalentSystem.prerequisites_met(D2, [D1]):
		return _fail("prerequisites_met: %s should be met with %s unlocked" % [D2, D1])
	return true


func test_prerequisites_met_tier2_without_prereq() -> bool:
	if MerlinTalentSystem.prerequisites_met(D2, []):
		return _fail("prerequisites_met: %s should fail without %s" % [D2, D1])
	return true


func test_prerequisites_met_multi_prereq_partial_fail() -> bool:
	# harmonie_factions requires druides_1, anciens_1, korrigans_1
	if MerlinTalentSystem.prerequisites_met(HARMONIE, [D1, A1]):
		return _fail("prerequisites_met: %s should fail with only 2 of 3 prereqs" % HARMONIE)
	return true


func test_prerequisites_met_multi_prereq_all_met() -> bool:
	if not MerlinTalentSystem.prerequisites_met(HARMONIE, [D1, A1, K1]):
		return _fail("prerequisites_met: %s should pass with all 3 prereqs" % HARMONIE)
	return true


func test_prerequisites_met_pacte_requires_niamh1_ankou1() -> bool:
	# pacte_ombre_lumiere requires niamh_1 and ankou_1
	if MerlinTalentSystem.prerequisites_met(PACTE, [N1]):
		return _fail("prerequisites_met: %s should fail with only niamh_1" % PACTE)
	if not MerlinTalentSystem.prerequisites_met(PACTE, [N1, AN1]):
		return _fail("prerequisites_met: %s should pass with niamh_1 + ankou_1" % PACTE)
	return true


func test_prerequisites_met_nonexistent_node_returns_false() -> bool:
	if MerlinTalentSystem.prerequisites_met("fake_node_xyz", []):
		return _fail("prerequisites_met: nonexistent node should return false")
	return true


# =============================================================================
# SECTION 8 — can_unlock
# =============================================================================

func test_can_unlock_valid_tier1_enough_anam() -> bool:
	if not MerlinTalentSystem.can_unlock(D1, [], 100):
		return _fail("can_unlock: should be true for %s with 100 anam, no prereqs" % D1)
	return true


func test_can_unlock_exact_cost_boundary() -> bool:
	var cost: int = int(MerlinTalentSystem.get_talent_node(D1).get("cost", 0))
	if not MerlinTalentSystem.can_unlock(D1, [], cost):
		return _fail("can_unlock: should be true with exactly %d anam" % cost)
	return true


func test_can_unlock_one_below_cost_fails() -> bool:
	var cost: int = int(MerlinTalentSystem.get_talent_node(D1).get("cost", 0))
	if MerlinTalentSystem.can_unlock(D1, [], cost - 1):
		return _fail("can_unlock: should be false with %d anam (cost is %d)" % [cost - 1, cost])
	return true


func test_can_unlock_zero_anam_fails() -> bool:
	if MerlinTalentSystem.can_unlock(D1, [], 0):
		return _fail("can_unlock: should be false with 0 anam")
	return true


func test_can_unlock_already_unlocked_fails() -> bool:
	if MerlinTalentSystem.can_unlock(D1, [D1], 9999):
		return _fail("can_unlock: should be false when already unlocked")
	return true


func test_can_unlock_prereqs_not_met_fails() -> bool:
	# D2 requires D1 — without D1 it should not be unlockable
	if MerlinTalentSystem.can_unlock(D2, [], 9999):
		return _fail("can_unlock: should be false when prereqs not met")
	return true


func test_can_unlock_invalid_id_fails() -> bool:
	if MerlinTalentSystem.can_unlock("fake_xyz", [], 9999):
		return _fail("can_unlock: should be false for nonexistent node")
	return true


# =============================================================================
# SECTION 9 — unlock_talent
# =============================================================================

func test_unlock_talent_success() -> bool:
	var result: Dictionary = MerlinTalentSystem.unlock_talent(D1, [], 100)
	if not bool(result.get("ok", false)):
		return _fail("unlock_talent success: expected ok=true, got error='%s'" % result.get("error", ""))
	if str(result.get("node_id", "")) != D1:
		return _fail("unlock_talent success: expected node_id='%s', got '%s'" % [D1, result.get("node_id", "")])
	return true


func test_unlock_talent_deducts_cost() -> bool:
	var cost: int = int(MerlinTalentSystem.get_talent_node(D1).get("cost", 0))
	var result: Dictionary = MerlinTalentSystem.unlock_talent(D1, [], 100)
	var expected_anam: int = 100 - cost
	if int(result.get("new_anam", -1)) != expected_anam:
		return _fail("unlock_talent: expected new_anam=%d, got %d" % [expected_anam, int(result.get("new_anam", -1))])
	return true


func test_unlock_talent_appends_to_new_unlocked() -> bool:
	var result: Dictionary = MerlinTalentSystem.unlock_talent(D1, [], 100)
	var new_unlocked: Array = result.get("new_unlocked", [])
	if not new_unlocked.has(D1):
		return _fail("unlock_talent: new_unlocked should contain %s" % D1)
	return true


func test_unlock_talent_does_not_mutate_original_unlocked() -> bool:
	var original: Array = [A1]
	MerlinTalentSystem.unlock_talent(D1, original, 100)
	if original.has(D1):
		return _fail("unlock_talent: original unlocked array was mutated (immutability violation)")
	return true


func test_unlock_talent_already_unlocked_error() -> bool:
	var result: Dictionary = MerlinTalentSystem.unlock_talent(D1, [D1], 100)
	if bool(result.get("ok", true)):
		return _fail("unlock_talent: expected ok=false when already unlocked")
	if str(result.get("error", "")) != "already_unlocked":
		return _fail("unlock_talent: expected error='already_unlocked', got '%s'" % result.get("error", ""))
	return true


func test_unlock_talent_insufficient_anam_error() -> bool:
	var result: Dictionary = MerlinTalentSystem.unlock_talent(D1, [], 0)
	if bool(result.get("ok", true)):
		return _fail("unlock_talent: expected ok=false with 0 anam")
	if str(result.get("error", "")) != "insufficient_anam":
		return _fail("unlock_talent: expected error='insufficient_anam', got '%s'" % result.get("error", ""))
	return true


func test_unlock_talent_prereqs_not_met_error() -> bool:
	var result: Dictionary = MerlinTalentSystem.unlock_talent(D2, [], 9999)
	if bool(result.get("ok", true)):
		return _fail("unlock_talent: expected ok=false when prereqs not met")
	if str(result.get("error", "")) != "prerequisites_not_met":
		return _fail("unlock_talent: expected error='prerequisites_not_met', got '%s'" % result.get("error", ""))
	return true


func test_unlock_talent_unknown_id_error() -> bool:
	var result: Dictionary = MerlinTalentSystem.unlock_talent("fake_node_xyz", [], 9999)
	if bool(result.get("ok", true)):
		return _fail("unlock_talent: expected ok=false for unknown id")
	if str(result.get("error", "")) != "unknown_talent":
		return _fail("unlock_talent: expected error='unknown_talent', got '%s'" % result.get("error", ""))
	return true


# =============================================================================
# SECTION 10 — get_available_talents
# =============================================================================

func test_get_available_talents_no_unlocks_high_anam() -> bool:
	var available: Array = MerlinTalentSystem.get_available_talents([], 9999)
	# At minimum all tier-1 nodes with empty prereqs should be available
	if available.is_empty():
		return _fail("get_available_talents: expected non-empty with 9999 anam and no unlocks")
	return true


func test_get_available_talents_only_tier1_with_no_unlocks() -> bool:
	# With no prior unlocks, only nodes with empty prerequisites can be unlocked
	var available: Array = MerlinTalentSystem.get_available_talents([], 9999)
	for nid in available:
		var node: Dictionary = MerlinTalentSystem.get_talent_node(nid)
		var prereqs: Array = node.get("prerequisites", [])
		if not prereqs.is_empty():
			return _fail("get_available_talents: node %s has prereqs but appeared as available with no unlocks" % nid)
	return true


func test_get_available_talents_excludes_zero_anam() -> bool:
	# With 0 anam, nothing should be available (all nodes cost > 0)
	var available: Array = MerlinTalentSystem.get_available_talents([], 0)
	if not available.is_empty():
		return _fail("get_available_talents: expected empty with 0 anam, got %d" % available.size())
	return true


func test_get_available_talents_excludes_already_unlocked() -> bool:
	var available: Array = MerlinTalentSystem.get_available_talents([D1], 9999)
	if available.has(D1):
		return _fail("get_available_talents: already-unlocked %s should not appear" % D1)
	return true


func test_get_available_talents_tier2_unlocked_after_tier1() -> bool:
	# After unlocking D1 with enough anam, D2 should be available
	var available: Array = MerlinTalentSystem.get_available_talents([D1], 9999)
	if not available.has(D2):
		return _fail("get_available_talents: %s should be available after unlocking %s" % [D2, D1])
	return true


# =============================================================================
# SECTION 11 — get_talent_effects
# =============================================================================

func test_effects_empty_unlocked_returns_empty() -> bool:
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([])
	if not effects.is_empty():
		return _fail("get_talent_effects empty: expected empty dict, got %d keys" % effects.size())
	return true


func test_effects_life_bonus_from_druides1() -> bool:
	# druides_1: modify_start target=life value=10
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([D1])
	if int(effects.get("life_bonus", 0)) != 10:
		return _fail("get_talent_effects: life_bonus expected 10, got %d" % int(effects.get("life_bonus", 0)))
	return true


func test_effects_life_max_bonus_from_central1() -> bool:
	# central_1: modify_start target=life_max value=10
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([C1])
	if int(effects.get("life_max_bonus", 0)) != 10:
		return _fail("get_talent_effects: life_max_bonus expected 10, got %d" % int(effects.get("life_max_bonus", 0)))
	return true


func test_effects_drain_reduction_from_ankou1() -> bool:
	# ankou_1: drain_reduction value=1
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([AN1])
	if int(effects.get("drain_reduction", 0)) != 1:
		return _fail("get_talent_effects: drain_reduction expected 1, got %d" % int(effects.get("drain_reduction", 0)))
	return true


func test_effects_drain_reduction_stacks() -> bool:
	# ankou_1 (1) + druides_5 (2) = 3 total drain_reduction
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([AN1, D5])
	if int(effects.get("drain_reduction", 0)) != 3:
		return _fail("get_talent_effects: stacked drain_reduction expected 3, got %d" % int(effects.get("drain_reduction", 0)))
	return true


func test_effects_cooldown_reduction_global() -> bool:
	# korrigans_4 and central_2 both have cooldown_reduction category=null value=1 → total 2
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([K4, C2])
	if int(effects.get("cooldown_reduction_global", 0)) != 2:
		return _fail("get_talent_effects: cooldown_reduction_global expected 2, got %d" % int(effects.get("cooldown_reduction_global", 0)))
	return true


func test_effects_cooldown_reduction_category() -> bool:
	# druides_2: cooldown_reduction category=nature value=1
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([D2])
	if int(effects.get("cooldown_reduction_nature", 0)) != 1:
		return _fail("get_talent_effects: cooldown_reduction_nature expected 1, got %d" % int(effects.get("cooldown_reduction_nature", 0)))
	return true


func test_effects_minigame_bonus_field_specific() -> bool:
	# korrigans_2: minigame_bonus field=chance value=0.10
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([K2])
	var v: float = float(effects.get("minigame_bonus_chance", 0.0))
	if absf(v - 0.10) > 0.001:
		return _fail("get_talent_effects: minigame_bonus_chance expected 0.10, got %f" % v)
	return true


func test_effects_minigame_bonus_stacks_across_fields() -> bool:
	# ankou_2 (esprit 0.15) + korrigans_2 (chance 0.10) → separate keys, no cross-contamination
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([AN2, K2])
	var esprit: float = float(effects.get("minigame_bonus_esprit", 0.0))
	var chance: float = float(effects.get("minigame_bonus_chance", 0.0))
	if absf(esprit - 0.15) > 0.001:
		return _fail("get_talent_effects: minigame_bonus_esprit expected 0.15, got %f" % esprit)
	if absf(chance - 0.10) > 0.001:
		return _fail("get_talent_effects: minigame_bonus_chance expected 0.10, got %f" % chance)
	return true


func test_effects_score_global_bonus_stacks() -> bool:
	# anciens_2 (0.05) + central_4 (0.10) = 0.15
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([A2, C4])
	var v: float = float(effects.get("score_global_bonus", 0.0))
	if absf(v - 0.15) > 0.001:
		return _fail("get_talent_effects: score_global_bonus expected 0.15, got %f" % v)
	return true


func test_effects_heal_multiplier() -> bool:
	# druides_4: heal_bonus value=1.0
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([D4])
	var v: float = float(effects.get("heal_multiplier", 0.0))
	if absf(v - 1.0) > 0.001:
		return _fail("get_talent_effects: heal_multiplier expected 1.0, got %f" % v)
	return true


func test_effects_rep_gain_multiplier() -> bool:
	# niamh_2: rep_bonus value=0.10
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([N2])
	var v: float = float(effects.get("rep_gain_multiplier", 0.0))
	if absf(v - 0.10) > 0.001:
		return _fail("get_talent_effects: rep_gain_multiplier expected 0.10, got %f" % v)
	return true


func test_effects_special_rule_flag() -> bool:
	# anciens_1: special_rule id=reveal_one_effect → modifiers["reveal_one_effect"] = true
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([A1])
	if not bool(effects.get("reveal_one_effect", false)):
		return _fail("get_talent_effects: reveal_one_effect flag should be true")
	return true


func test_effects_skips_unknown_ids() -> bool:
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects(["fake_a", "fake_b", "garbage_xyz"])
	if not effects.is_empty():
		return _fail("get_talent_effects: unknown ids should produce empty dict, got %d keys" % effects.size())
	return true


func test_effects_mixed_valid_invalid_only_counts_valid() -> bool:
	# Only D1 is valid; fake_a is not — result should equal all-valid case
	var effects_pure: Dictionary = MerlinTalentSystem.get_talent_effects([D1])
	var effects_mixed: Dictionary = MerlinTalentSystem.get_talent_effects([D1, "fake_a"])
	if effects_pure.size() != effects_mixed.size():
		return _fail("get_talent_effects: invalid ids should be silently skipped (pure=%d keys, mixed=%d keys)" % [effects_pure.size(), effects_mixed.size()])
	return true


# =============================================================================
# SECTION 12 — Edge cases / additional coverage
# =============================================================================

func test_constants_branches_count() -> bool:
	if MerlinTalentSystem.BRANCHES.size() != EXPECTED_BRANCHES:
		return _fail("BRANCHES: expected %d, got %d" % [EXPECTED_BRANCHES, MerlinTalentSystem.BRANCHES.size()])
	return true


func test_constants_max_tier_is_five() -> bool:
	if MerlinTalentSystem.MAX_TIER != 5:
		return _fail("MAX_TIER: expected 5, got %d" % MerlinTalentSystem.MAX_TIER)
	return true


func test_get_branch_total_cost_druides() -> bool:
	# druides: 20+25+50+80+120 = 295
	var total: int = MerlinTalentSystem.get_branch_total_cost("druides")
	if total != 295:
		return _fail("get_branch_total_cost druides: expected 295, got %d" % total)
	return true


func test_get_branch_total_cost_invalid_is_zero() -> bool:
	if MerlinTalentSystem.get_branch_total_cost("nonexistent") != 0:
		return _fail("get_branch_total_cost invalid: expected 0")
	return true


func test_count_unlocked_in_branch_empty() -> bool:
	if MerlinTalentSystem.count_unlocked_in_branch("druides", []) != 0:
		return _fail("count_unlocked_in_branch: expected 0 with empty unlocked")
	return true


func test_count_unlocked_in_branch_partial() -> bool:
	var count: int = MerlinTalentSystem.count_unlocked_in_branch("druides", [D1, D2, A1])
	if count != 2:
		return _fail("count_unlocked_in_branch: expected 2, got %d" % count)
	return true


func test_count_unlocked_in_branch_ignores_invalid_ids() -> bool:
	var count: int = MerlinTalentSystem.count_unlocked_in_branch("druides", ["fake_node", D1])
	if count != 1:
		return _fail("count_unlocked_in_branch: invalid ids should be ignored, expected 1 got %d" % count)
	return true


func test_get_completion_ratio_zero_with_empty() -> bool:
	var ratio: float = MerlinTalentSystem.get_completion_ratio([])
	if absf(ratio) > 0.001:
		return _fail("get_completion_ratio: empty should be 0.0, got %f" % ratio)
	return true


func test_get_completion_ratio_invalid_ids_ignored() -> bool:
	var ratio: float = MerlinTalentSystem.get_completion_ratio(["fake_a", "fake_b"])
	if absf(ratio) > 0.001:
		return _fail("get_completion_ratio: invalid ids should not inflate ratio, got %f" % ratio)
	return true


func test_get_completion_ratio_one_valid() -> bool:
	var ratio: float = MerlinTalentSystem.get_completion_ratio([D1])
	var expected: float = 1.0 / float(EXPECTED_TOTAL)
	if absf(ratio - expected) > 0.001:
		return _fail("get_completion_ratio: expected ~%f, got %f" % [expected, ratio])
	return true


func test_get_tree_summary_empty_state() -> bool:
	var summary: Dictionary = MerlinTalentSystem.get_tree_summary([], 50)
	if int(summary.get("total_unlocked", -1)) != 0:
		return _fail("get_tree_summary: total_unlocked expected 0, got %d" % int(summary.get("total_unlocked", -1)))
	if int(summary.get("total_nodes", 0)) != EXPECTED_TOTAL:
		return _fail("get_tree_summary: total_nodes expected %d, got %d" % [EXPECTED_TOTAL, int(summary.get("total_nodes", 0))])
	if int(summary.get("anam", -1)) != 50:
		return _fail("get_tree_summary: anam expected 50, got %d" % int(summary.get("anam", -1)))
	return true


func test_get_tree_summary_branch_counts_with_unlocks() -> bool:
	var unlocked: Array = [D1, D2, A1]
	var summary: Dictionary = MerlinTalentSystem.get_tree_summary(unlocked, 200)
	if int(summary.get("total_unlocked", 0)) != 3:
		return _fail("get_tree_summary: total_unlocked expected 3, got %d" % int(summary.get("total_unlocked", 0)))
	var branches: Dictionary = summary.get("branches", {})
	if int(branches.get("druides", 0)) != 2:
		return _fail("get_tree_summary: druides count expected 2, got %d" % int(branches.get("druides", 0)))
	if int(branches.get("anciens", 0)) != 1:
		return _fail("get_tree_summary: anciens count expected 1, got %d" % int(branches.get("anciens", 0)))
	return true


func test_get_reachable_talents_empty_unlocked_has_tier1() -> bool:
	var reachable: Array = MerlinTalentSystem.get_reachable_talents([])
	if reachable.is_empty():
		return _fail("get_reachable_talents: expected non-empty with no unlocks")
	if not reachable.has(D1):
		return _fail("get_reachable_talents: %s should be reachable with no unlocks" % D1)
	return true


func test_get_reachable_talents_excludes_already_unlocked() -> bool:
	var reachable: Array = MerlinTalentSystem.get_reachable_talents([D1])
	if reachable.has(D1):
		return _fail("get_reachable_talents: should not contain already-unlocked %s" % D1)
	return true


func test_get_reachable_talents_includes_tier2_after_tier1() -> bool:
	var reachable: Array = MerlinTalentSystem.get_reachable_talents([D1])
	if not reachable.has(D2):
		return _fail("get_reachable_talents: %s should appear after unlocking %s" % [D2, D1])
	return true
