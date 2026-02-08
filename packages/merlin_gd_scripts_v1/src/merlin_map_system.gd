extends RefCounted
class_name DruMapSystem

const DEFAULT_FLOORS := 8

func generate_map(floors: int, rng: DruRng, config: Dictionary = {}) -> Array:
	var total: int = max(2, floors)
	var map: Array = []
	for floor_idx in range(total):
		var node_count: int = _node_count_for_floor(floor_idx, total, rng)
		var floor_nodes: Array = []
		for i in range(node_count):
			var node_type: String = _pick_node_type(floor_idx, total, rng, config)
			var x_pos: float = 50.0 if node_count == 1 else 20.0 + (60.0 / float(node_count - 1)) * float(i)
			floor_nodes.append({
				"id": "%d-%d" % [floor_idx, i],
				"floor": floor_idx,
				"index": i,
				"type": node_type,
				"connections": [],
				"x": x_pos,
			})
		if floor_idx > 0:
			var prev_floor: Array = map[floor_idx - 1]
			for node in floor_nodes:
				for prev_node in prev_floor:
					if rng.randf() > 0.3 or prev_floor.size() == 1:
						prev_node["connections"].append(node["id"])
			for prev_node in prev_floor:
				if prev_node["connections"].is_empty():
					prev_node["connections"].append(floor_nodes[0]["id"])
		map.append(floor_nodes)
	return map


func _node_count_for_floor(floor_idx: int, total: int, rng: DruRng) -> int:
	if floor_idx == 0 or floor_idx == total - 1:
		return 1
	return rng.randi_range(2, 3)


func _pick_node_type(floor_idx: int, total: int, rng: DruRng, config: Dictionary) -> String:
	if floor_idx == 0:
		return "EVENT"
	if floor_idx == total - 1:
		return "BOSS"
	if floor_idx == int(total / 2):
		return "HEAL" if rng.randf() > 0.5 else "SHOP"

	var roll: float = rng.randf()
	var combat_chance: float = float(config.get("combat_chance", 0.40))
	var elite_chance: float = float(config.get("elite_chance", 0.10))
	var shop_chance: float = float(config.get("shop_chance", 0.10))
	var heal_chance: float = float(config.get("heal_chance", 0.10))

	if roll < combat_chance:
		return "COMBAT"
	if roll < combat_chance + elite_chance:
		return "ELITE"
	if roll < combat_chance + elite_chance + shop_chance:
		return "SHOP"
	if roll < combat_chance + elite_chance + shop_chance + heal_chance:
		return "HEAL"
	return "EVENT"
