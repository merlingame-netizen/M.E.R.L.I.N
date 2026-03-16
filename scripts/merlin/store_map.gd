## ═══════════════════════════════════════════════════════════════════════════════
## Store Map — World map progression helpers
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_store.gd — pure delegation, no behavior changes.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name StoreMap


static func update_gauges(state: Dictionary, action: Dictionary) -> Dictionary:
	var delta: Dictionary = action.get("delta", {})
	if delta.is_empty():
		return {"ok": false, "error": "No delta provided"}
	var map_prog: Dictionary = state.get("map_progression", {})
	var gauges: Dictionary = map_prog.get("gauges", {})
	var gauge_sys := MerlinGaugeSystem.new()
	var new_gauges: Dictionary = gauge_sys.apply_delta(gauges, delta)
	map_prog["gauges"] = new_gauges
	state["map_progression"] = map_prog
	return {"ok": true, "gauges": new_gauges}


static func complete_biome(state: Dictionary, action: Dictionary) -> Dictionary:
	var biome_key: String = str(action.get("biome_key", ""))
	if biome_key.is_empty():
		return {"ok": false, "error": "No biome_key"}
	var map_prog: Dictionary = state.get("map_progression", {})
	var completed: Array = map_prog.get("completed_biomes", [])
	if not biome_key in completed:
		completed.append(biome_key)
	map_prog["completed_biomes"] = completed
	var tree := MerlinBiomeTree.new()
	var tier: int = tree.get_tier(biome_key)
	var current_tier: int = int(map_prog.get("tier_progress", 1))
	if tier > current_tier:
		map_prog["tier_progress"] = tier
	state["map_progression"] = map_prog
	return {"ok": true, "completed_biomes": completed}


static func collect_item(state: Dictionary, action: Dictionary) -> Dictionary:
	var item_id: String = str(action.get("item_id", ""))
	if item_id.is_empty():
		return {"ok": false, "error": "No item_id"}
	var map_prog: Dictionary = state.get("map_progression", {})
	var items: Array = map_prog.get("items_collected", [])
	if not item_id in items:
		items.append(item_id)
	map_prog["items_collected"] = items
	state["map_progression"] = map_prog
	return {"ok": true, "items_collected": items}


static func add_reputation(state: Dictionary, action: Dictionary) -> Dictionary:
	var rep_id: String = str(action.get("reputation_id", ""))
	if rep_id.is_empty():
		return {"ok": false, "error": "No reputation_id"}
	var map_prog: Dictionary = state.get("map_progression", {})
	var reps: Array = map_prog.get("reputations", [])
	if not rep_id in reps:
		reps.append(rep_id)
	map_prog["reputations"] = reps
	state["map_progression"] = map_prog
	return {"ok": true, "reputations": reps}


static func select_biome(state: Dictionary, action: Dictionary) -> Dictionary:
	var biome_key: String = str(action.get("biome_key", ""))
	if biome_key.is_empty():
		return {"ok": false, "error": "No biome_key"}
	var map_prog: Dictionary = state.get("map_progression", {})
	map_prog["current_biome"] = biome_key
	var visited: Array = map_prog.get("visited_biomes", [])
	if not biome_key in visited:
		visited.append(biome_key)
	map_prog["visited_biomes"] = visited
	state["map_progression"] = map_prog
	return {"ok": true, "current_biome": biome_key}
