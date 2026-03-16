## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinMapSystem (STS-like world map)
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: generate_map structure, floor counts, node types, connections,
## revealed/visited state, cards_count constraints, determinism, edge cases.
## Source: MerlinMapSystem.generate_map() + NODE_TYPES
## Pattern: extends RefCounted, methods return bool on success/failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

const REQUIRED_KEYS: Array = ["id", "floor", "index", "type", "connections", "x", "visited", "revealed", "cards_count"]
const SEED: int = 42
const DEFAULT_FLOORS: int = 8


func _make_rng(seed_val: int = SEED) -> MerlinRng:
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(seed_val)
	return rng


func _make_map(floors: int = DEFAULT_FLOORS, seed_val: int = SEED) -> Array:
	var sys: MerlinMapSystem = MerlinMapSystem.new()
	var rng: MerlinRng = _make_rng(seed_val)
	return sys.generate_map(floors, rng)


func _all_nodes(map: Array) -> Array:
	var nodes: Array = []
	for floor_nodes in map:
		for node in floor_nodes:
			nodes.append(node)
	return nodes


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: generate_map returns correct number of floors
# ═══════════════════════════════════════════════════════════════════════════════

func test_floor_count_matches_input() -> bool:
	var map: Array = _make_map(8)
	if map.size() != 8:
		push_error("Expected 8 floors, got %d" % map.size())
		return false
	var map5: Array = _make_map(5)
	if map5.size() != 5:
		push_error("Expected 5 floors, got %d" % map5.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: floors < 3 are clamped to 3
# ═══════════════════════════════════════════════════════════════════════════════

func test_minimum_floor_count_is_three() -> bool:
	var map1: Array = _make_map(1)
	if map1.size() != 3:
		push_error("floors=1 should clamp to 3, got %d" % map1.size())
		return false
	var map2: Array = _make_map(2)
	if map2.size() != 3:
		push_error("floors=2 should clamp to 3, got %d" % map2.size())
		return false
	var map0: Array = _make_map(0)
	if map0.size() != 3:
		push_error("floors=0 should clamp to 3, got %d" % map0.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: first floor has exactly 1 NARRATIVE node
# ═══════════════════════════════════════════════════════════════════════════════

func test_first_floor_is_single_narrative() -> bool:
	var map: Array = _make_map()
	var first: Array = map[0]
	if first.size() != 1:
		push_error("First floor should have 1 node, got %d" % first.size())
		return false
	if first[0]["type"] != "NARRATIVE":
		push_error("First floor node should be NARRATIVE, got %s" % first[0]["type"])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: last floor has exactly 1 MERLIN node
# ═══════════════════════════════════════════════════════════════════════════════

func test_last_floor_is_single_merlin() -> bool:
	var map: Array = _make_map()
	var last: Array = map[map.size() - 1]
	if last.size() != 1:
		push_error("Last floor should have 1 node, got %d" % last.size())
		return false
	if last[0]["type"] != "MERLIN":
		push_error("Last floor node should be MERLIN, got %s" % last[0]["type"])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: middle floors have 2-3 nodes each
# ═══════════════════════════════════════════════════════════════════════════════

func test_middle_floors_have_two_or_three_nodes() -> bool:
	var map: Array = _make_map()
	for floor_idx in range(1, map.size() - 1):
		var count: int = map[floor_idx].size()
		if count < 2 or count > 3:
			push_error("Middle floor %d has %d nodes (expected 2-3)" % [floor_idx, count])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: midpoint floor has REST or MERCHANT type
# ═══════════════════════════════════════════════════════════════════════════════

func test_midpoint_floor_has_rest_or_merchant() -> bool:
	var map: Array = _make_map()
	var total: int = map.size()
	var midpoint: int = int(total / 2.0)
	var mid_floor: Array = map[midpoint]
	var found: bool = false
	for node in mid_floor:
		if node["type"] == "REST" or node["type"] == "MERCHANT":
			found = true
			break
	if not found:
		var types: Array = []
		for node in mid_floor:
			types.append(node["type"])
		push_error("Midpoint floor %d has no REST/MERCHANT node. Types: %s" % [midpoint, str(types)])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: every node has all required keys
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_nodes_have_required_keys() -> bool:
	var map: Array = _make_map()
	var nodes: Array = _all_nodes(map)
	for node in nodes:
		for key in REQUIRED_KEYS:
			if not node.has(key):
				push_error("Node %s missing key '%s'" % [str(node.get("id", "?")), key])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: first 2 floors revealed, rest not
# ═══════════════════════════════════════════════════════════════════════════════

func test_revealed_state() -> bool:
	var map: Array = _make_map()
	for floor_idx in range(map.size()):
		for node in map[floor_idx]:
			var expected: bool = floor_idx <= 1
			if node["revealed"] != expected:
				push_error("Node %s: revealed=%s, expected=%s" % [node["id"], str(node["revealed"]), str(expected)])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: all nodes start unvisited
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_nodes_unvisited() -> bool:
	var map: Array = _make_map()
	var nodes: Array = _all_nodes(map)
	for node in nodes:
		if node["visited"] != false:
			push_error("Node %s should be unvisited" % node["id"])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: every current-floor node has at least 1 parent connection
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_node_has_parent_connection() -> bool:
	var map: Array = _make_map()
	for floor_idx in range(1, map.size()):
		for node in map[floor_idx]:
			var node_id: String = node["id"]
			var has_parent: bool = false
			for prev_node in map[floor_idx - 1]:
				if prev_node["connections"].has(node_id):
					has_parent = true
					break
			if not has_parent:
				push_error("Node %s has no parent connection from floor %d" % [node_id, floor_idx - 1])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: every previous-floor node has at least 1 child connection
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_parent_has_child_connection() -> bool:
	var map: Array = _make_map()
	for floor_idx in range(map.size() - 1):
		for node in map[floor_idx]:
			if node["connections"].is_empty():
				push_error("Node %s on floor %d has no child connections" % [node["id"], floor_idx])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: no node has more than 3 connections
# ═══════════════════════════════════════════════════════════════════════════════

func test_max_three_connections() -> bool:
	var map: Array = _make_map()
	var nodes: Array = _all_nodes(map)
	for node in nodes:
		if node["connections"].size() > 3:
			push_error("Node %s has %d connections (max 3)" % [node["id"], node["connections"].size()])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: cards_count matches NODE_TYPES constraints
# ═══════════════════════════════════════════════════════════════════════════════

func test_cards_count_within_type_bounds() -> bool:
	var map: Array = _make_map()
	var nodes: Array = _all_nodes(map)
	for node in nodes:
		var ntype: String = node["type"]
		var type_data: Dictionary = MerlinMapSystem.NODE_TYPES.get(ntype, {})
		var cards_min: int = int(type_data.get("cards_min", 0))
		var cards_max: int = int(type_data.get("cards_max", 0))
		var cards: int = node["cards_count"]
		if cards_min <= 0 and cards_max <= 0:
			if cards != 0:
				push_error("Node %s type=%s should have 0 cards, got %d" % [node["id"], ntype, cards])
				return false
		else:
			if cards < cards_min or cards > cards_max:
				push_error("Node %s type=%s cards=%d outside [%d,%d]" % [node["id"], ntype, cards, cards_min, cards_max])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: REST and MERCHANT nodes have 0 cards
# ═══════════════════════════════════════════════════════════════════════════════

func test_rest_merchant_zero_cards() -> bool:
	var map: Array = _make_map()
	var nodes: Array = _all_nodes(map)
	for node in nodes:
		if node["type"] == "REST" or node["type"] == "MERCHANT":
			if node["cards_count"] != 0:
				push_error("Node %s type=%s should have 0 cards, got %d" % [node["id"], node["type"], node["cards_count"]])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: deterministic — same seed produces same map
# ═══════════════════════════════════════════════════════════════════════════════

func test_deterministic_same_seed() -> bool:
	var map_a: Array = _make_map(8, 42)
	var map_b: Array = _make_map(8, 42)
	if map_a.size() != map_b.size():
		push_error("Same seed produced different floor counts: %d vs %d" % [map_a.size(), map_b.size()])
		return false
	for floor_idx in range(map_a.size()):
		if map_a[floor_idx].size() != map_b[floor_idx].size():
			push_error("Floor %d: different node counts %d vs %d" % [floor_idx, map_a[floor_idx].size(), map_b[floor_idx].size()])
			return false
		for node_idx in range(map_a[floor_idx].size()):
			var a: Dictionary = map_a[floor_idx][node_idx]
			var b: Dictionary = map_b[floor_idx][node_idx]
			if a["id"] != b["id"] or a["type"] != b["type"] or a["cards_count"] != b["cards_count"]:
				push_error("Floor %d node %d differs: %s vs %s" % [floor_idx, node_idx, str(a), str(b)])
				return false
			if str(a["connections"]) != str(b["connections"]):
				push_error("Floor %d node %d connections differ" % [floor_idx, node_idx])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: different seeds produce different maps
# ═══════════════════════════════════════════════════════════════════════════════

func test_different_seeds_differ() -> bool:
	var map_a: Array = _make_map(8, 42)
	var map_b: Array = _make_map(8, 999)
	var any_diff: bool = false
	for floor_idx in range(1, mini(map_a.size(), map_b.size()) - 1):
		if map_a[floor_idx].size() != map_b[floor_idx].size():
			any_diff = true
			break
		for node_idx in range(mini(map_a[floor_idx].size(), map_b[floor_idx].size())):
			if map_a[floor_idx][node_idx]["type"] != map_b[floor_idx][node_idx]["type"]:
				any_diff = true
				break
		if any_diff:
			break
	if not any_diff:
		push_error("Seeds 42 and 999 produced identical middle floors (highly improbable)")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TEST: node IDs follow "floor-index" format and are unique
# ═══════════════════════════════════════════════════════════════════════════════

func test_node_ids_unique_and_formatted() -> bool:
	var map: Array = _make_map()
	var seen: Dictionary = {}
	for floor_idx in range(map.size()):
		for node in map[floor_idx]:
			var expected_id: String = "%d-%d" % [floor_idx, node["index"]]
			if node["id"] != expected_id:
				push_error("Node id=%s expected=%s" % [node["id"], expected_id])
				return false
			if seen.has(node["id"]):
				push_error("Duplicate node id: %s" % node["id"])
				return false
			seen[node["id"]] = true
	return true
