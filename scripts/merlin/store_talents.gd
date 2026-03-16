## ═══════════════════════════════════════════════════════════════════════════════
## Store Talents — Talent tree (Arbre de Vie) management
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_store.gd — pure delegation, no behavior changes.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name StoreTalents


## Scan unlocked talents and apply their effects to the current run.
static func apply_talent_effects_for_run(state: Dictionary) -> void:
	var unlocked: Array = state.get("meta", {}).get("talent_tree", {}).get("unlocked", [])
	if unlocked.is_empty():
		return

	var run: Dictionary = state.get("run", {})
	var modifiers: Dictionary = {}
	var life_max: int = MerlinConstants.LIFE_ESSENCE_MAX

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
						run["life_essence"] = mini(int(run.get("life_essence", 0)) + value, life_max)
					"life_max":
						life_max += value
						run["life_max"] = life_max
						run["life_essence"] = mini(int(run.get("life_essence", 0)) + value, life_max)

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
				modifiers[rule_id] = true

	run["talent_modifiers"] = modifiers
	state["run"] = run


static func get_talent_modifier(state: Dictionary, key: String, default_value: Variant = false) -> Variant:
	return state.get("run", {}).get("talent_modifiers", {}).get(key, default_value)


static func consume_talent_modifier(state: Dictionary, key: String) -> bool:
	var run: Dictionary = state.get("run", {})
	var modifiers: Dictionary = run.get("talent_modifiers", {})
	if modifiers.get(key, false):
		modifiers[key] = false
		run["talent_modifiers"] = modifiers
		state["run"] = run
		return true
	return false


static func is_talent_active(state: Dictionary, node_id: String) -> bool:
	var unlocked: Array = state.get("meta", {}).get("talent_tree", {}).get("unlocked", [])
	return unlocked.has(node_id)


static func can_unlock_talent(state: Dictionary, node_id: String) -> bool:
	if not MerlinConstants.TALENT_NODES.has(node_id):
		return false
	if is_talent_active(state, node_id):
		return false

	var node: Dictionary = MerlinConstants.TALENT_NODES[node_id]

	for prereq in node.get("prerequisites", []):
		if not is_talent_active(state, prereq):
			return false

	var cost: int = int(node.get("cost", 0))
	var anam: int = int(state.get("meta", {}).get("anam", 0))
	if anam < cost:
		return false
	return true


static func unlock_talent(state: Dictionary, node_id: String, save_system: MerlinSaveSystem) -> Dictionary:
	if not can_unlock_talent(state, node_id):
		return {"ok": false, "error": "Cannot unlock"}

	var node: Dictionary = MerlinConstants.TALENT_NODES[node_id]
	var cost: int = int(node.get("cost", 0))

	state["meta"]["anam"] = int(state.get("meta", {}).get("anam", 0)) - cost
	state["meta"]["talent_tree"]["unlocked"].append(node_id)

	save_system.save_profile(state.get("meta", {}))
	return {"ok": true, "node_id": node_id, "name": node.get("name", "")}


static func get_unlocked_talents(state: Dictionary) -> Array:
	return state.get("meta", {}).get("talent_tree", {}).get("unlocked", []).duplicate()


static func get_affordable_talents(state: Dictionary) -> Array:
	var affordable: Array = []
	for node_id in MerlinConstants.TALENT_NODES:
		if can_unlock_talent(state, node_id):
			affordable.append(node_id)
	return affordable
