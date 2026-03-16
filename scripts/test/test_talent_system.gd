## =============================================================================
## Unit Tests — MerlinTalentSystem (complement to test_talent_tree.gd)
## =============================================================================
## Covers public methods NOT tested by test_talent_tree.gd:
## get_talent_node, get_tier_talents, is_unlocked, prerequisites_met,
## can_unlock, get_reachable_talents, get_branch_total_cost,
## count_unlocked_in_branch, effects edge cases, constants, summary values.
## Pattern: extends RefCounted, each test returns bool.
## =============================================================================

extends RefCounted


# =============================================================================
# CONSTANTS — valid IDs from MerlinConstants.TALENT_NODES
# =============================================================================

const DRUIDES_1: String = "druides_1"
const DRUIDES_2: String = "druides_2"
const ANCIENS_1: String = "anciens_1"
const ANCIENS_2: String = "anciens_2"
const KORRIGANS_1: String = "korrigans_1"
const KORRIGANS_4: String = "korrigans_4"
const NIAMH_1: String = "niamh_1"
const NIAMH_2: String = "niamh_2"
const ANKOU_1: String = "ankou_1"
const CENTRAL_1: String = "central_1"
const CENTRAL_2: String = "central_2"
const CENTRAL_4: String = "central_4"
const HARMONIE: String = "harmonie_factions"


# =============================================================================
# TESTS — get_talent_node
# =============================================================================

func test_get_talent_node_valid() -> bool:
	var node: Dictionary = MerlinTalentSystem.get_talent_node(DRUIDES_1)
	if node.is_empty():
		push_error("get_talent_node: expected non-empty dict for %s" % DRUIDES_1)
		return false
	if str(node.get("name", "")) != "Vigueur du Chene":
		push_error("get_talent_node: expected name 'Vigueur du Chene', got '%s'" % node.get("name", ""))
		return false
	if int(node.get("cost", -1)) != 20:
		push_error("get_talent_node: expected cost 20, got %d" % int(node.get("cost", -1)))
		return false
	return true


func test_get_talent_node_invalid() -> bool:
	var node: Dictionary = MerlinTalentSystem.get_talent_node("nonexistent_xyz")
	if not node.is_empty():
		push_error("get_talent_node: expected empty dict for nonexistent node, got %d keys" % node.size())
		return false
	return true


# =============================================================================
# TESTS — get_tier_talents
# =============================================================================

func test_get_tier_talents_tier1() -> bool:
	var tier1: Array = MerlinTalentSystem.get_tier_talents(1)
	if tier1.is_empty():
		push_error("get_tier_talents(1): expected non-empty")
		return false
	# All tier-1 nodes should have tier == 1
	for nid in tier1:
		var node: Dictionary = MerlinTalentSystem.get_talent_node(nid)
		if int(node.get("tier", 0)) != 1:
			push_error("get_tier_talents(1): node %s has tier %d" % [nid, int(node.get("tier", 0))])
			return false
	return true


func test_get_tier_talents_tier1_contains_all_branches() -> bool:
	var tier1: Array = MerlinTalentSystem.get_tier_talents(1)
	# Each of the 6 branches should have at least one tier-1 node
	var branches_found: Dictionary = {}
	for nid in tier1:
		var node: Dictionary = MerlinTalentSystem.get_talent_node(nid)
		var branch: String = str(node.get("branch", ""))
		branches_found[branch] = true
	for branch in MerlinTalentSystem.BRANCHES:
		if not branches_found.has(branch):
			push_error("get_tier_talents(1): missing branch %s" % branch)
			return false
	return true


func test_get_tier_talents_invalid_tier() -> bool:
	var tier99: Array = MerlinTalentSystem.get_tier_talents(99)
	if not tier99.is_empty():
		push_error("get_tier_talents(99): expected empty, got %d items" % tier99.size())
		return false
	return true


# =============================================================================
# TESTS — is_unlocked
# =============================================================================

func test_is_unlocked_true() -> bool:
	var unlocked: Array = [DRUIDES_1, ANCIENS_1]
	var result: bool = MerlinTalentSystem.is_unlocked(DRUIDES_1, unlocked)
	if not result:
		push_error("is_unlocked: expected true for %s in unlocked list" % DRUIDES_1)
		return false
	return true


func test_is_unlocked_false() -> bool:
	var unlocked: Array = [DRUIDES_1]
	var result: bool = MerlinTalentSystem.is_unlocked(ANCIENS_1, unlocked)
	if result:
		push_error("is_unlocked: expected false for %s not in unlocked list" % ANCIENS_1)
		return false
	return true


func test_is_unlocked_empty_list() -> bool:
	var result: bool = MerlinTalentSystem.is_unlocked(DRUIDES_1, [])
	if result:
		push_error("is_unlocked: expected false with empty unlocked list")
		return false
	return true


# =============================================================================
# TESTS — prerequisites_met
# =============================================================================

func test_prerequisites_met_tier1_no_prereqs() -> bool:
	# Tier-1 nodes have empty prerequisites, should always be met
	var result: bool = MerlinTalentSystem.prerequisites_met(DRUIDES_1, [])
	if not result:
		push_error("prerequisites_met: tier-1 node should have no prerequisites")
		return false
	return true


func test_prerequisites_met_tier2_with_tier1() -> bool:
	var result: bool = MerlinTalentSystem.prerequisites_met(DRUIDES_2, [DRUIDES_1])
	if not result:
		push_error("prerequisites_met: druides_2 prereqs should be met with druides_1 unlocked")
		return false
	return true


func test_prerequisites_met_tier2_without_tier1() -> bool:
	var result: bool = MerlinTalentSystem.prerequisites_met(DRUIDES_2, [])
	if result:
		push_error("prerequisites_met: druides_2 should fail without druides_1")
		return false
	return true


func test_prerequisites_met_multi_prereqs() -> bool:
	# harmonie_factions requires druides_1, anciens_1, korrigans_1
	var result_partial: bool = MerlinTalentSystem.prerequisites_met(HARMONIE, [DRUIDES_1, ANCIENS_1])
	if result_partial:
		push_error("prerequisites_met: harmonie should fail with only 2 of 3 prereqs")
		return false
	var result_full: bool = MerlinTalentSystem.prerequisites_met(HARMONIE, [DRUIDES_1, ANCIENS_1, KORRIGANS_1])
	if not result_full:
		push_error("prerequisites_met: harmonie should pass with all 3 prereqs")
		return false
	return true


func test_prerequisites_met_nonexistent_node() -> bool:
	var result: bool = MerlinTalentSystem.prerequisites_met("fake_node_xyz", [])
	if result:
		push_error("prerequisites_met: nonexistent node should return false")
		return false
	return true


# =============================================================================
# TESTS — can_unlock
# =============================================================================

func test_can_unlock_valid() -> bool:
	var result: bool = MerlinTalentSystem.can_unlock(DRUIDES_1, [], 100)
	if not result:
		push_error("can_unlock: should be true for valid tier-1 with enough anam")
		return false
	return true


func test_can_unlock_already_unlocked() -> bool:
	var result: bool = MerlinTalentSystem.can_unlock(DRUIDES_1, [DRUIDES_1], 100)
	if result:
		push_error("can_unlock: should be false when already unlocked")
		return false
	return true


func test_can_unlock_insufficient_anam() -> bool:
	var result: bool = MerlinTalentSystem.can_unlock(DRUIDES_1, [], 0)
	if result:
		push_error("can_unlock: should be false with 0 anam")
		return false
	return true


func test_can_unlock_exact_cost() -> bool:
	var cost: int = int(MerlinTalentSystem.get_talent_node(DRUIDES_1).get("cost", 0))
	var result: bool = MerlinTalentSystem.can_unlock(DRUIDES_1, [], cost)
	if not result:
		push_error("can_unlock: should be true with exact cost (%d anam)" % cost)
		return false
	return true


# =============================================================================
# TESTS — get_reachable_talents
# =============================================================================

func test_reachable_talents_empty_unlocked() -> bool:
	var reachable: Array = MerlinTalentSystem.get_reachable_talents([])
	if reachable.is_empty():
		push_error("get_reachable_talents: expected non-empty with no unlocks (tier-1 nodes)")
		return false
	# All reachable should have empty prerequisites (tier-1)
	for nid in reachable:
		var node: Dictionary = MerlinTalentSystem.get_talent_node(nid)
		var prereqs: Array = node.get("prerequisites", [])
		if not prereqs.is_empty():
			push_error("get_reachable_talents: node %s has prereqs but appeared as reachable" % nid)
			return false
	return true


func test_reachable_talents_excludes_unlocked() -> bool:
	var reachable: Array = MerlinTalentSystem.get_reachable_talents([DRUIDES_1])
	if reachable.has(DRUIDES_1):
		push_error("get_reachable_talents: should not contain already-unlocked %s" % DRUIDES_1)
		return false
	return true


func test_reachable_includes_tier2_when_tier1_unlocked() -> bool:
	var reachable: Array = MerlinTalentSystem.get_reachable_talents([DRUIDES_1])
	if not reachable.has(DRUIDES_2):
		push_error("get_reachable_talents: should contain %s when %s is unlocked" % [DRUIDES_2, DRUIDES_1])
		return false
	return true


# =============================================================================
# TESTS — get_branch_total_cost
# =============================================================================

func test_branch_total_cost_druides() -> bool:
	var total: int = MerlinTalentSystem.get_branch_total_cost("druides")
	# druides: 20 + 25 + 50 + 80 + 120 = 295
	if total != 295:
		push_error("get_branch_total_cost druides: expected 295, got %d" % total)
		return false
	return true


func test_branch_total_cost_invalid_branch() -> bool:
	var total: int = MerlinTalentSystem.get_branch_total_cost("nonexistent_branch")
	if total != 0:
		push_error("get_branch_total_cost invalid: expected 0, got %d" % total)
		return false
	return true


# =============================================================================
# TESTS — count_unlocked_in_branch
# =============================================================================

func test_count_unlocked_in_branch_none() -> bool:
	var count: int = MerlinTalentSystem.count_unlocked_in_branch("druides", [])
	if count != 0:
		push_error("count_unlocked_in_branch empty: expected 0, got %d" % count)
		return false
	return true


func test_count_unlocked_in_branch_partial() -> bool:
	var count: int = MerlinTalentSystem.count_unlocked_in_branch("druides", [DRUIDES_1, DRUIDES_2, ANCIENS_1])
	if count != 2:
		push_error("count_unlocked_in_branch partial: expected 2, got %d" % count)
		return false
	return true


func test_count_unlocked_ignores_invalid_ids() -> bool:
	var count: int = MerlinTalentSystem.count_unlocked_in_branch("druides", ["fake_node", DRUIDES_1])
	if count != 1:
		push_error("count_unlocked_in_branch with invalid: expected 1, got %d" % count)
		return false
	return true


# =============================================================================
# TESTS — get_talent_effects (edge cases not in test_talent_tree.gd)
# =============================================================================

func test_effects_cooldown_reduction_global() -> bool:
	# korrigans_4 and central_2 both have global cooldown_reduction (category=null), value=1 each
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([KORRIGANS_4, CENTRAL_2])
	var global_cd: int = int(effects.get("cooldown_reduction_global", 0))
	if global_cd != 2:
		push_error("effects global cooldown: expected 2, got %d" % global_cd)
		return false
	return true


func test_effects_cooldown_reduction_category() -> bool:
	# druides_2 has cooldown_reduction category="nature", value=1
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([DRUIDES_2])
	var nature_cd: int = int(effects.get("cooldown_reduction_nature", 0))
	if nature_cd != 1:
		push_error("effects category cooldown: expected 1, got %d" % nature_cd)
		return false
	return true


func test_effects_minigame_bonus_field() -> bool:
	# korrigans_2 has minigame_bonus field="chance", value=0.10
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects(["korrigans_2"])
	var bonus: float = float(effects.get("minigame_bonus_chance", 0.0))
	if absf(bonus - 0.10) > 0.001:
		push_error("effects minigame_bonus_chance: expected 0.10, got %f" % bonus)
		return false
	return true


func test_effects_score_global_bonus() -> bool:
	# anciens_2 has score_global_bonus 0.05, central_4 has 0.10
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([ANCIENS_2, CENTRAL_4])
	var bonus: float = float(effects.get("score_global_bonus", 0.0))
	if absf(bonus - 0.15) > 0.001:
		push_error("effects score_global_bonus stacked: expected 0.15, got %f" % bonus)
		return false
	return true


func test_effects_heal_bonus() -> bool:
	# druides_4 has heal_bonus value=1.0
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects(["druides_4"])
	var heal: float = float(effects.get("heal_multiplier", 0.0))
	if absf(heal - 1.0) > 0.001:
		push_error("effects heal_multiplier: expected 1.0, got %f" % heal)
		return false
	return true


func test_effects_life_max_bonus() -> bool:
	# central_1 has modify_start target="life_max", value=10
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([CENTRAL_1])
	var lm_bonus: int = int(effects.get("life_max_bonus", 0))
	if lm_bonus != 10:
		push_error("effects life_max_bonus: expected 10, got %d" % lm_bonus)
		return false
	return true


func test_effects_skips_unknown_node_ids() -> bool:
	# Passing unknown IDs should not crash, should produce empty effects
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects(["fake_a", "fake_b"])
	if not effects.is_empty():
		push_error("effects with unknown ids: expected empty, got %d keys" % effects.size())
		return false
	return true


# =============================================================================
# TESTS — Constants
# =============================================================================

func test_branches_constant() -> bool:
	var branches: Array[String] = MerlinTalentSystem.BRANCHES
	if branches.size() != 6:
		push_error("BRANCHES: expected 6, got %d" % branches.size())
		return false
	if not branches.has("druides") or not branches.has("central"):
		push_error("BRANCHES: missing expected branch names")
		return false
	return true


func test_max_tier_constant() -> bool:
	var max_tier: int = MerlinTalentSystem.MAX_TIER
	if max_tier != 5:
		push_error("MAX_TIER: expected 5, got %d" % max_tier)
		return false
	return true


# =============================================================================
# TESTS — get_tree_summary values
# =============================================================================

func test_tree_summary_values_empty() -> bool:
	var summary: Dictionary = MerlinTalentSystem.get_tree_summary([], 50)
	if int(summary.get("total_unlocked", -1)) != 0:
		push_error("summary total_unlocked: expected 0, got %d" % int(summary.get("total_unlocked", -1)))
		return false
	if int(summary.get("anam", -1)) != 50:
		push_error("summary anam: expected 50, got %d" % int(summary.get("anam", -1)))
		return false
	var completion: float = float(summary.get("completion", -1.0))
	if absf(completion) > 0.001:
		push_error("summary completion: expected 0.0, got %f" % completion)
		return false
	var branches_dict: Dictionary = summary.get("branches", {})
	for branch in MerlinTalentSystem.BRANCHES:
		if int(branches_dict.get(branch, -1)) != 0:
			push_error("summary branch %s: expected 0, got %d" % [branch, int(branches_dict.get(branch, -1))])
			return false
	return true


func test_tree_summary_with_unlocks() -> bool:
	var unlocked: Array = [DRUIDES_1, DRUIDES_2, ANCIENS_1]
	var summary: Dictionary = MerlinTalentSystem.get_tree_summary(unlocked, 200)
	if int(summary.get("total_unlocked", 0)) != 3:
		push_error("summary total_unlocked: expected 3, got %d" % int(summary.get("total_unlocked", 0)))
		return false
	var branches_dict: Dictionary = summary.get("branches", {})
	if int(branches_dict.get("druides", 0)) != 2:
		push_error("summary druides count: expected 2, got %d" % int(branches_dict.get("druides", 0)))
		return false
	if int(branches_dict.get("anciens", 0)) != 1:
		push_error("summary anciens count: expected 1, got %d" % int(branches_dict.get("anciens", 0)))
		return false
	return true


# =============================================================================
# TESTS — Completion ratio edge cases
# =============================================================================

func test_completion_ratio_ignores_invalid_ids() -> bool:
	var ratio: float = MerlinTalentSystem.get_completion_ratio(["fake_a", "fake_b"])
	if absf(ratio) > 0.001:
		push_error("completion_ratio with invalid ids: expected 0.0, got %f" % ratio)
		return false
	return true


func test_completion_ratio_mixed_valid_invalid() -> bool:
	var ratio_valid: float = MerlinTalentSystem.get_completion_ratio([DRUIDES_1])
	var ratio_mixed: float = MerlinTalentSystem.get_completion_ratio([DRUIDES_1, "fake_node"])
	if absf(ratio_valid - ratio_mixed) > 0.001:
		push_error("completion_ratio: invalid ids should not inflate ratio (valid=%f, mixed=%f)" % [ratio_valid, ratio_mixed])
		return false
	return true


# =============================================================================
# TESTS — get_branch_talents edge case
# =============================================================================

func test_get_branch_talents_invalid_branch() -> bool:
	var result: Array = MerlinTalentSystem.get_branch_talents("nonexistent_branch")
	if not result.is_empty():
		push_error("get_branch_talents invalid: expected empty, got %d" % result.size())
		return false
	return true
