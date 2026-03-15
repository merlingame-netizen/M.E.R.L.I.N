## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Talent System — Arbre de Talents (faction-based, Anam currency)
## ═══════════════════════════════════════════════════════════════════════════════
## Standalone talent tree logic: unlock flow, prerequisites, effects computation.
## Data source: MerlinConstants.TALENT_NODES (~30 nodes, 6 branches).
## Integrates with MerlinStore via dispatch pattern (UNLOCK_TALENT action).
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name MerlinTalentSystem


# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

const BRANCHES: Array[String] = [
	"druides", "anciens", "korrigans", "niamh", "ankou", "central"
]

const MAX_TIER: int = 5


# ═══════════════════════════════════════════════════════════════════════════════
# STATE (immutable reads — caller owns the unlocked list)
# ═══════════════════════════════════════════════════════════════════════════════

## Check if a talent node ID exists in the catalogue.
static func talent_exists(node_id: String) -> bool:
	return MerlinConstants.TALENT_NODES.has(node_id)


## Get the full node definition (returns empty dict if not found).
static func get_talent_node(node_id: String) -> Dictionary:
	return MerlinConstants.TALENT_NODES.get(node_id, {})


## Get all node IDs in the catalogue.
static func get_all_talent_ids() -> Array:
	return MerlinConstants.TALENT_NODES.keys()


## Get all node IDs for a specific branch.
static func get_branch_talents(branch: String) -> Array:
	var result: Array = []
	for node_id in MerlinConstants.TALENT_NODES:
		var node: Dictionary = MerlinConstants.TALENT_NODES[node_id]
		if str(node.get("branch", "")) == branch:
			result.append(node_id)
	return result


## Get all node IDs at a specific tier.
static func get_tier_talents(tier: int) -> Array:
	var result: Array = []
	for node_id in MerlinConstants.TALENT_NODES:
		var node: Dictionary = MerlinConstants.TALENT_NODES[node_id]
		if int(node.get("tier", 0)) == tier:
			result.append(node_id)
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# UNLOCK LOGIC (pure functions — no side effects)
# ═══════════════════════════════════════════════════════════════════════════════

## Check if a talent is already unlocked.
static func is_unlocked(node_id: String, unlocked: Array) -> bool:
	return unlocked.has(node_id)


## Check if all prerequisites for a node are met.
static func prerequisites_met(node_id: String, unlocked: Array) -> bool:
	var node: Dictionary = get_talent_node(node_id)
	if node.is_empty():
		return false
	var prereqs: Array = node.get("prerequisites", [])
	for prereq in prereqs:
		if not unlocked.has(prereq):
			return false
	return true


## Check if a talent can be unlocked (exists, not yet unlocked, prereqs met, enough Anam).
static func can_unlock(node_id: String, unlocked: Array, anam: int) -> bool:
	if not talent_exists(node_id):
		return false
	if is_unlocked(node_id, unlocked):
		return false
	if not prerequisites_met(node_id, unlocked):
		return false
	var cost: int = int(get_talent_node(node_id).get("cost", 0))
	return anam >= cost


## Attempt to unlock a talent. Returns a result dictionary (immutable pattern).
## On success: {"ok": true, "node_id": ..., "name": ..., "cost": ..., "new_anam": ..., "new_unlocked": [...]}
## On failure: {"ok": false, "error": "..."}
static func unlock_talent(node_id: String, unlocked: Array, anam: int) -> Dictionary:
	if not talent_exists(node_id):
		return {"ok": false, "error": "unknown_talent"}
	if is_unlocked(node_id, unlocked):
		return {"ok": false, "error": "already_unlocked"}
	if not prerequisites_met(node_id, unlocked):
		return {"ok": false, "error": "prerequisites_not_met"}

	var node: Dictionary = get_talent_node(node_id)
	var cost: int = int(node.get("cost", 0))

	if anam < cost:
		return {"ok": false, "error": "insufficient_anam"}

	# Build new state (immutable — new array, not mutated)
	var new_unlocked: Array = unlocked.duplicate()
	new_unlocked.append(node_id)
	var new_anam: int = anam - cost

	return {
		"ok": true,
		"node_id": node_id,
		"name": str(node.get("name", "")),
		"cost": cost,
		"new_anam": new_anam,
		"new_unlocked": new_unlocked,
	}


## Get all talents that can currently be unlocked.
static func get_available_talents(unlocked: Array, anam: int) -> Array:
	var available: Array = []
	for node_id in MerlinConstants.TALENT_NODES:
		if can_unlock(node_id, unlocked, anam):
			available.append(node_id)
	return available


## Get all talents that have met prerequisites but may lack Anam.
static func get_reachable_talents(unlocked: Array) -> Array:
	var reachable: Array = []
	for node_id in MerlinConstants.TALENT_NODES:
		if not is_unlocked(node_id, unlocked) and prerequisites_met(node_id, unlocked):
			reachable.append(node_id)
	return reachable


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECTS COMPUTATION (pure function — returns modifier dictionary)
# ═══════════════════════════════════════════════════════════════════════════════

## Compute the aggregate modifiers from all unlocked talents.
## Returns a Dictionary of modifier keys → values, ready to apply at run start.
##
## Modifier keys produced:
##   "life_bonus"            : int   — bonus starting life
##   "life_max_bonus"        : int   — bonus max life
##   "drain_reduction"       : int   — reduce per-card drain
##   "cooldown_reduction_global" : int — global cooldown reduction
##   "cooldown_reduction_<cat>"  : int — category-specific cooldown reduction
##   "minigame_bonus_all"    : float — global minigame score bonus
##   "minigame_bonus_<field>": float — field-specific minigame score bonus
##   "score_global_bonus"    : float — global score bonus
##   "heal_multiplier"       : float — heal effect multiplier bonus
##   "rep_gain_multiplier"   : float — reputation gain multiplier bonus
##   "<special_rule_id>"     : bool  — special rule active flags
static func get_talent_effects(unlocked: Array) -> Dictionary:
	var modifiers: Dictionary = {}

	for node_id in unlocked:
		var node: Dictionary = MerlinConstants.TALENT_NODES.get(node_id, {})
		if node.is_empty():
			continue

		var effect: Dictionary = node.get("effect", {})
		var effect_type: String = str(effect.get("type", ""))

		match effect_type:
			"modify_start":
				var target: String = str(effect.get("target", ""))
				var value: int = int(effect.get("value", 0))
				match target:
					"life":
						modifiers["life_bonus"] = int(modifiers.get("life_bonus", 0)) + value
					"life_max":
						modifiers["life_max_bonus"] = int(modifiers.get("life_max_bonus", 0)) + value

			"cooldown_reduction":
				var category: Variant = effect.get("category", null)
				var value: int = int(effect.get("value", 0))
				if category == null:
					modifiers["cooldown_reduction_global"] = int(modifiers.get("cooldown_reduction_global", 0)) + value
				else:
					var key: String = "cooldown_reduction_" + str(category)
					modifiers[key] = int(modifiers.get(key, 0)) + value

			"minigame_bonus":
				var field: Variant = effect.get("field", null)
				var value: float = float(effect.get("value", 0.0))
				if field == null:
					modifiers["minigame_bonus_all"] = float(modifiers.get("minigame_bonus_all", 0.0)) + value
				else:
					var key: String = "minigame_bonus_" + str(field)
					modifiers[key] = float(modifiers.get(key, 0.0)) + value

			"score_global_bonus":
				var value: float = float(effect.get("value", 0.0))
				modifiers["score_global_bonus"] = float(modifiers.get("score_global_bonus", 0.0)) + value

			"drain_reduction":
				var value: int = int(effect.get("value", 0))
				modifiers["drain_reduction"] = int(modifiers.get("drain_reduction", 0)) + value

			"heal_bonus":
				var value: float = float(effect.get("value", 0.0))
				modifiers["heal_multiplier"] = float(modifiers.get("heal_multiplier", 0.0)) + value

			"rep_bonus":
				var value: float = float(effect.get("value", 0.0))
				modifiers["rep_gain_multiplier"] = float(modifiers.get("rep_gain_multiplier", 0.0)) + value

			"special_rule":
				var rule_id: String = str(effect.get("id", ""))
				if not rule_id.is_empty():
					modifiers[rule_id] = true

	return modifiers


# ═══════════════════════════════════════════════════════════════════════════════
# QUERY HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

## Get the total Anam cost to unlock all talents in a branch.
static func get_branch_total_cost(branch: String) -> int:
	var total: int = 0
	for node_id in MerlinConstants.TALENT_NODES:
		var node: Dictionary = MerlinConstants.TALENT_NODES[node_id]
		if str(node.get("branch", "")) == branch:
			total += int(node.get("cost", 0))
	return total


## Count how many talents are unlocked in a given branch.
static func count_unlocked_in_branch(branch: String, unlocked: Array) -> int:
	var count: int = 0
	for node_id in unlocked:
		var node: Dictionary = MerlinConstants.TALENT_NODES.get(node_id, {})
		if str(node.get("branch", "")) == branch:
			count += 1
	return count


## Get completion percentage for the entire talent tree (0.0 - 1.0).
static func get_completion_ratio(unlocked: Array) -> float:
	var total: int = MerlinConstants.TALENT_NODES.size()
	if total == 0:
		return 0.0
	var count: int = 0
	for node_id in unlocked:
		if MerlinConstants.TALENT_NODES.has(node_id):
			count += 1
	return float(count) / float(total)


## Build a summary for save/display purposes.
static func get_tree_summary(unlocked: Array, anam: int) -> Dictionary:
	var branch_counts: Dictionary = {}
	for branch in BRANCHES:
		branch_counts[branch] = count_unlocked_in_branch(branch, unlocked)

	return {
		"total_unlocked": unlocked.size(),
		"total_nodes": MerlinConstants.TALENT_NODES.size(),
		"completion": get_completion_ratio(unlocked),
		"anam": anam,
		"available_count": get_available_talents(unlocked, anam).size(),
		"branches": branch_counts,
	}
