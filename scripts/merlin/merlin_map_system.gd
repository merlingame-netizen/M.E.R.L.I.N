## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Map System — STS-like world map for TRIADE
## ═══════════════════════════════════════════════════════════════════════════════
## Generates a floor-based map with typed nodes and connections.
## Node types: NARRATIVE, EVENT, PROMISE, REST, MERCHANT, MYSTERY, MERLIN.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name MerlinMapSystem

## Node types for map generation (weights + card ranges).
const NODE_TYPES: Dictionary = {
	"NARRATIVE": {"weight": 5.0, "cards_min": 2, "cards_max": 4},
	"EVENT":     {"weight": 2.0, "cards_min": 1, "cards_max": 2},
	"PROMISE":   {"weight": 1.0, "cards_min": 1, "cards_max": 3},
	"REST":      {"weight": 1.5, "cards_min": 0, "cards_max": 0},
	"MERCHANT":  {"weight": 1.0, "cards_min": 0, "cards_max": 0},
	"MYSTERY":   {"weight": 1.0, "cards_min": 1, "cards_max": 2},
	"MERLIN":    {"weight": 0.0, "cards_min": 1, "cards_max": 1},
}


func generate_map(floors: int, rng: MerlinRng, config: Dictionary = {}) -> Array:
	var total: int = maxi(3, floors)
	var map: Array = []

	for floor_idx in range(total):
		var node_count: int = _node_count_for_floor(floor_idx, total, rng)
		var floor_nodes: Array = []

		for i in range(node_count):
			var node_type: String = _pick_node_type(floor_idx, total, rng, config)
			var cards_count: int = _cards_for_node_type(node_type, rng)
			var x_pos: float = 50.0 if node_count == 1 else 15.0 + (70.0 / float(maxi(node_count - 1, 1))) * float(i)
			floor_nodes.append({
				"id": "%d-%d" % [floor_idx, i],
				"floor": floor_idx,
				"index": i,
				"type": node_type,
				"connections": [],
				"x": x_pos,
				"visited": false,
				"revealed": floor_idx <= 1,
				"cards_count": cards_count,
			})

		# Connect to previous floor
		if floor_idx > 0:
			_connect_floors(map[floor_idx - 1], floor_nodes, rng)

		map.append(floor_nodes)

	return map


func _node_count_for_floor(floor_idx: int, total: int, rng: MerlinRng) -> int:
	if floor_idx == 0 or floor_idx == total - 1:
		return 1
	# Middle floors: 2-3 nodes
	return rng.randi_range(2, 3)


func _pick_node_type(floor_idx: int, total: int, rng: MerlinRng, _config: Dictionary) -> String:
	# Fixed types for first and last floor
	if floor_idx == 0:
		return "NARRATIVE"
	if floor_idx == total - 1:
		return "MERLIN"

	# Midpoint: force REST or MERCHANT
	if floor_idx == int(total / 2.0):
		return "REST" if rng.randf() > 0.5 else "MERCHANT"

	# Weighted random selection from TRIADE node types
	var types: Dictionary = NODE_TYPES
	var total_weight: float = 0.0
	for type_key in types:
		# Don't randomly place MERLIN nodes (only at end)
		if type_key == "MERLIN":
			continue
		total_weight += float(types[type_key].get("weight", 0.0))

	var roll: float = rng.randf() * total_weight
	var cumulative: float = 0.0
	for type_key in types:
		if type_key == "MERLIN":
			continue
		cumulative += float(types[type_key].get("weight", 0.0))
		if roll < cumulative:
			return type_key

	return "NARRATIVE"


func _cards_for_node_type(node_type: String, rng: MerlinRng) -> int:
	var type_data: Dictionary = NODE_TYPES.get(node_type, {})
	var cards_min: int = int(type_data.get("cards_min", 1))
	var cards_max: int = int(type_data.get("cards_max", 3))
	if cards_min <= 0 and cards_max <= 0:
		return 0
	return rng.randi_range(cards_min, cards_max)


func _connect_floors(prev_floor: Array, cur_floor: Array, rng: MerlinRng) -> void:
	# Ensure every current node has at least 1 parent
	for node in cur_floor:
		var parent_idx: int = rng.randi() % prev_floor.size()
		var parent: Dictionary = prev_floor[parent_idx]
		if not parent["connections"].has(node["id"]):
			parent["connections"].append(node["id"])

	# Ensure every previous node has at least 1 child
	for prev_node in prev_floor:
		if prev_node["connections"].is_empty():
			prev_node["connections"].append(cur_floor[0]["id"])

	# Add extra connections (max 3 per parent)
	for prev_node in prev_floor:
		if prev_node["connections"].size() >= 3:
			continue
		for node in cur_floor:
			if prev_node["connections"].size() >= 3:
				break
			if not prev_node["connections"].has(node["id"]) and rng.randf() > 0.55:
				prev_node["connections"].append(node["id"])
