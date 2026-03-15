## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinTalentSystem (Arbre de Talents)
## ═══════════════════════════════════════════════════════════════════════════════
## Covers: unlock flow, prerequisites, effects computation, Anam cost,
## branch queries, edge cases (double unlock, unknown talent, etc.).
## Pattern: extends RefCounted, each test returns bool, run_all() aggregates.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name TestTalentTree


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

## First tier-1 node with no prerequisites (always exists in catalogue).
const TIER1_ID: String = "druides_1"
const TIER2_ID: String = "druides_2"
const TIER3_ID: String = "druides_3"


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS — Catalogue & existence
# ═══════════════════════════════════════════════════════════════════════════════

func test_talent_exists_valid() -> bool:
	var ok: bool = MerlinTalentSystem.talent_exists(TIER1_ID)
	if not ok:
		push_error("talent_exists: expected true for %s" % TIER1_ID)
		return false
	return true


func test_talent_exists_invalid() -> bool:
	var ok: bool = MerlinTalentSystem.talent_exists("nonexistent_xyz")
	if ok:
		push_error("talent_exists: expected false for nonexistent talent")
		return false
	return true


func test_get_all_talent_ids_not_empty() -> bool:
	var ids: Array = MerlinTalentSystem.get_all_talent_ids()
	if ids.is_empty():
		push_error("get_all_talent_ids: returned empty array")
		return false
	return true


func test_get_branch_talents_druides() -> bool:
	var branch_ids: Array = MerlinTalentSystem.get_branch_talents("druides")
	if branch_ids.size() < 3:
		push_error("get_branch_talents druides: expected >= 3, got %d" % branch_ids.size())
		return false
	for nid in branch_ids:
		var node: Dictionary = MerlinTalentSystem.get_talent_node(nid)
		if str(node.get("branch", "")) != "druides":
			push_error("get_branch_talents: node %s has branch %s, expected druides" % [nid, node.get("branch", "")])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS — Unlock flow
# ═══════════════════════════════════════════════════════════════════════════════

func test_unlock_tier1_with_enough_anam() -> bool:
	var unlocked: Array = []
	var anam: int = 100
	var result: Dictionary = MerlinTalentSystem.unlock_talent(TIER1_ID, unlocked, anam)
	if not result.get("ok", false):
		push_error("unlock tier1: expected ok=true, got error=%s" % result.get("error", ""))
		return false
	var new_unlocked: Array = result.get("new_unlocked", [])
	if not new_unlocked.has(TIER1_ID):
		push_error("unlock tier1: new_unlocked does not contain %s" % TIER1_ID)
		return false
	var expected_cost: int = int(MerlinTalentSystem.get_talent_node(TIER1_ID).get("cost", 0))
	var new_anam: int = int(result.get("new_anam", -1))
	if new_anam != anam - expected_cost:
		push_error("unlock tier1: expected new_anam=%d, got %d" % [anam - expected_cost, new_anam])
		return false
	return true


func test_unlock_insufficient_anam() -> bool:
	var unlocked: Array = []
	var anam: int = 0
	var result: Dictionary = MerlinTalentSystem.unlock_talent(TIER1_ID, unlocked, anam)
	if result.get("ok", false):
		push_error("unlock with 0 anam: expected ok=false")
		return false
	if result.get("error", "") != "insufficient_anam":
		push_error("unlock with 0 anam: expected error=insufficient_anam, got %s" % result.get("error", ""))
		return false
	return true


func test_unlock_already_unlocked() -> bool:
	var unlocked: Array = [TIER1_ID]
	var anam: int = 999
	var result: Dictionary = MerlinTalentSystem.unlock_talent(TIER1_ID, unlocked, anam)
	if result.get("ok", false):
		push_error("unlock already unlocked: expected ok=false")
		return false
	if result.get("error", "") != "already_unlocked":
		push_error("unlock already unlocked: expected error=already_unlocked, got %s" % result.get("error", ""))
		return false
	return true


func test_unlock_unknown_talent() -> bool:
	var result: Dictionary = MerlinTalentSystem.unlock_talent("fake_node_xyz", [], 999)
	if result.get("ok", false):
		push_error("unlock unknown: expected ok=false")
		return false
	if result.get("error", "") != "unknown_talent":
		push_error("unlock unknown: expected error=unknown_talent, got %s" % result.get("error", ""))
		return false
	return true


func test_unlock_prerequisites_not_met() -> bool:
	# Tier 2 requires tier 1
	var unlocked: Array = []
	var anam: int = 999
	var result: Dictionary = MerlinTalentSystem.unlock_talent(TIER2_ID, unlocked, anam)
	if result.get("ok", false):
		push_error("unlock tier2 without tier1: expected ok=false")
		return false
	if result.get("error", "") != "prerequisites_not_met":
		push_error("unlock tier2 without tier1: expected error=prerequisites_not_met, got %s" % result.get("error", ""))
		return false
	return true


func test_unlock_chain_tier1_then_tier2() -> bool:
	var unlocked: Array = []
	var anam: int = 999

	# Unlock tier 1 first
	var r1: Dictionary = MerlinTalentSystem.unlock_talent(TIER1_ID, unlocked, anam)
	if not r1.get("ok", false):
		push_error("chain: tier1 unlock failed: %s" % r1.get("error", ""))
		return false

	# Now unlock tier 2 using the new state
	var r2: Dictionary = MerlinTalentSystem.unlock_talent(
		TIER2_ID, r1.get("new_unlocked", []), int(r1.get("new_anam", 0))
	)
	if not r2.get("ok", false):
		push_error("chain: tier2 unlock failed: %s" % r2.get("error", ""))
		return false

	var final_unlocked: Array = r2.get("new_unlocked", [])
	if not final_unlocked.has(TIER1_ID) or not final_unlocked.has(TIER2_ID):
		push_error("chain: final_unlocked missing expected nodes")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS — Available talents
# ═══════════════════════════════════════════════════════════════════════════════

func test_available_talents_empty_unlocked() -> bool:
	# With no unlocks and enough Anam, all tier-1 nodes (no prereqs) should be available
	var available: Array = MerlinTalentSystem.get_available_talents([], 999)
	if available.is_empty():
		push_error("available with 999 anam and empty unlocked: expected non-empty")
		return false
	# Every available talent should have empty prerequisites
	for nid in available:
		var node: Dictionary = MerlinTalentSystem.get_talent_node(nid)
		var prereqs: Array = node.get("prerequisites", [])
		if not prereqs.is_empty():
			push_error("available: node %s has non-empty prereqs but appeared in available list" % nid)
			return false
	return true


func test_available_talents_zero_anam() -> bool:
	var available: Array = MerlinTalentSystem.get_available_talents([], 0)
	if not available.is_empty():
		push_error("available with 0 anam: expected empty, got %d items" % available.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS — Effects computation
# ═══════════════════════════════════════════════════════════════════════════════

func test_effects_empty_unlocked() -> bool:
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([])
	if not effects.is_empty():
		push_error("effects with empty unlocked: expected empty dict, got %d keys" % effects.size())
		return false
	return true


func test_effects_druides_1_life_bonus() -> bool:
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects([TIER1_ID])
	# druides_1 has effect: {"type": "modify_start", "target": "life", "value": 10}
	var life_bonus: int = int(effects.get("life_bonus", 0))
	if life_bonus != 10:
		push_error("effects druides_1: expected life_bonus=10, got %d" % life_bonus)
		return false
	return true


func test_effects_stack_drain_reduction() -> bool:
	# ankou_1 has drain_reduction=1, druides_5 has drain_reduction=2
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects(["ankou_1", "druides_5"])
	var drain: int = int(effects.get("drain_reduction", 0))
	if drain != 3:
		push_error("effects stacked drain: expected 3, got %d" % drain)
		return false
	return true


func test_effects_special_rule_flag() -> bool:
	# anciens_1 has special_rule with id "reveal_one_effect"
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects(["anciens_1"])
	if not effects.get("reveal_one_effect", false):
		push_error("effects anciens_1: expected reveal_one_effect=true")
		return false
	return true


func test_effects_rep_bonus() -> bool:
	# niamh_2 has rep_bonus 0.10
	var effects: Dictionary = MerlinTalentSystem.get_talent_effects(["niamh_2"])
	var rep_mult: float = float(effects.get("rep_gain_multiplier", 0.0))
	if absf(rep_mult - 0.10) > 0.001:
		push_error("effects niamh_2: expected rep_gain_multiplier=0.10, got %f" % rep_mult)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TESTS — Query helpers
# ═══════════════════════════════════════════════════════════════════════════════

func test_completion_ratio_zero() -> bool:
	var ratio: float = MerlinTalentSystem.get_completion_ratio([])
	if ratio != 0.0:
		push_error("completion_ratio empty: expected 0.0, got %f" % ratio)
		return false
	return true


func test_completion_ratio_increases() -> bool:
	var r0: float = MerlinTalentSystem.get_completion_ratio([])
	var r1: float = MerlinTalentSystem.get_completion_ratio([TIER1_ID])
	if r1 <= r0:
		push_error("completion_ratio: expected r1 > r0, got r0=%f r1=%f" % [r0, r1])
		return false
	return true


func test_immutability_unlock_does_not_mutate_input() -> bool:
	var original: Array = []
	var anam: int = 999
	var _result: Dictionary = MerlinTalentSystem.unlock_talent(TIER1_ID, original, anam)
	if not original.is_empty():
		push_error("immutability: original array was mutated after unlock")
		return false
	return true


func test_tree_summary_structure() -> bool:
	var summary: Dictionary = MerlinTalentSystem.get_tree_summary([], 100)
	var required_keys: Array = ["total_unlocked", "total_nodes", "completion", "anam", "available_count", "branches"]
	for key in required_keys:
		if not summary.has(key):
			push_error("tree_summary: missing key %s" % key)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN ALL
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> void:
	var tests: Array[Callable] = [
		test_talent_exists_valid,
		test_talent_exists_invalid,
		test_get_all_talent_ids_not_empty,
		test_get_branch_talents_druides,
		test_unlock_tier1_with_enough_anam,
		test_unlock_insufficient_anam,
		test_unlock_already_unlocked,
		test_unlock_unknown_talent,
		test_unlock_prerequisites_not_met,
		test_unlock_chain_tier1_then_tier2,
		test_available_talents_empty_unlocked,
		test_available_talents_zero_anam,
		test_effects_empty_unlocked,
		test_effects_druides_1_life_bonus,
		test_effects_stack_drain_reduction,
		test_effects_special_rule_flag,
		test_effects_rep_bonus,
		test_completion_ratio_zero,
		test_completion_ratio_increases,
		test_immutability_unlock_does_not_mutate_input,
		test_tree_summary_structure,
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

	print("[test_talent_tree] Results: %d/%d passed" % [passed, passed + failed])
	if failed > 0:
		push_error("[test_talent_tree] %d test(s) FAILED" % failed)
	else:
		print("[test_talent_tree] All tests passed.")
