## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinMapSystem (STS-like world map) — 25 tests
## ═══════════════════════════════════════════════════════════════════════════════
## Covers: floor count, node count, types, connectivity (DAG), cards_count,
## revealed/visited state, node IDs, determinism, edge cases.
## Source: MerlinMapSystem.generate_map() + _node_count_for_floor +
##         _pick_node_type + _cards_for_node_type + _connect_floors
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error before false.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

const VALID_TYPES: Array = ["NARRATIVE", "EVENT", "PROMISE", "REST", "MERCHANT", "MYSTERY", "MERLIN"]
const REQUIRED_KEYS: Array = ["id", "floor", "index", "type", "connections", "x", "visited", "revealed", "cards_count"]
const DEFAULT_SEED: int = 42
const DEFAULT_FLOORS: int = 8


func _make_rng(seed_val: int = DEFAULT_SEED) -> MerlinRng:
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(seed_val)
	return rng


func _make_map(floors: int = DEFAULT_FLOORS, seed_val: int = DEFAULT_SEED) -> Array:
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
# FLOOR COUNT
# ═══════════════════════════════════════════════════════════════════════════════

func test_floor_count_matches_input() -> bool:
	var map8: Array = _make_map(8)
	if map8.size() != 8:
		push_error("Expected 8 floors, got %d" % map8.size())
		return false
	var map5: Array = _make_map(5)
	if map5.size() != 5:
		push_error("Expected 5 floors, got %d" % map5.size())
		return false
	var map10: Array = _make_map(10)
	if map10.size() != 10:
		push_error("Expected 10 floors, got %d" % map10.size())
		return false
	return true


func test_minimum_floor_count_clamped_to_three() -> bool:
	# generate_map uses maxi(3, floors) — all inputs < 3 produce 3 floors
	var map0: Array = _make_map(0)
	if map0.size() != 3:
		push_error("floors=0 should clamp to 3, got %d" % map0.size())
		return false
	var map1: Array = _make_map(1)
	if map1.size() != 3:
		push_error("floors=1 should clamp to 3, got %d" % map1.size())
		return false
	var map2: Array = _make_map(2)
	if map2.size() != 3:
		push_error("floors=2 should clamp to 3, got %d" % map2.size())
		return false
	return true


func test_exact_three_floors_is_valid() -> bool:
	var map: Array = _make_map(3)
	if map.size() != 3:
		push_error("floors=3 should produce exactly 3 floors, got %d" % map.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# NODE COUNT PER FLOOR
# ═══════════════════════════════════════════════════════════════════════════════

func test_first_floor_has_exactly_one_node() -> bool:
	var map: Array = _make_map()
	if map[0].size() != 1:
		push_error("First floor should have 1 node, got %d" % map[0].size())
		return false
	return true


func test_last_floor_has_exactly_one_node() -> bool:
	var map: Array = _make_map()
	if map[map.size() - 1].size() != 1:
		push_error("Last floor should have 1 node, got %d" % map[map.size() - 1].size())
		return false
	return true


func test_middle_floors_have_two_or_three_nodes() -> bool:
	var map: Array = _make_map()
	for floor_idx in range(1, map.size() - 1):
		var count: int = map[floor_idx].size()
		if count < 2 or count > 3:
			push_error("Middle floor %d has %d nodes (expected 2-3)" % [floor_idx, count])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# NODE TYPES
# ═══════════════════════════════════════════════════════════════════════════════

func test_first_floor_type_is_narrative() -> bool:
	var map: Array = _make_map()
	var node: Dictionary = map[0][0]
	if node["type"] != "NARRATIVE":
		push_error("First floor node type should be NARRATIVE, got %s" % node["type"])
		return false
	return true


func test_last_floor_type_is_merlin() -> bool:
	var map: Array = _make_map()
	var node: Dictionary = map[map.size() - 1][0]
	if node["type"] != "MERLIN":
		push_error("Last floor node type should be MERLIN, got %s" % node["type"])
		return false
	return true


func test_all_node_types_are_valid_strings() -> bool:
	var map: Array = _make_map()
	var nodes: Array = _all_nodes(map)
	for node in nodes:
		var t: String = node["type"]
		if not VALID_TYPES.has(t):
			push_error("Node %s has invalid type '%s'" % [node["id"], t])
			return false
	return true


func test_midpoint_floor_has_rest_or_merchant() -> bool:
	# _pick_node_type forces REST or MERCHANT at floor_idx == int(total / 2.0)
	var map: Array = _make_map()
	var midpoint: int = int(map.size() / 2.0)
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
		push_error("Midpoint floor %d has no REST/MERCHANT. Types: %s" % [midpoint, str(types)])
		return false
	return true


func test_merlin_only_on_last_floor() -> bool:
	# MERLIN weight=0 in weighted selection; only placed at floor total-1
	var map: Array = _make_map()
	for floor_idx in range(map.size() - 1):
		for node in map[floor_idx]:
			if node["type"] == "MERLIN":
				push_error("MERLIN node found on non-last floor %d (node %s)" % [floor_idx, node["id"]])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# NODE SCHEMA
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_nodes_have_required_keys() -> bool:
	var map: Array = _make_map()
	var nodes: Array = _all_nodes(map)
	for node in nodes:
		for key in REQUIRED_KEYS:
			if not node.has(key):
				push_error("Node %s missing required key '%s'" % [str(node.get("id", "?")), key])
				return false
	return true


func test_node_ids_follow_floor_index_format() -> bool:
	var map: Array = _make_map()
	for floor_idx in range(map.size()):
		for node in map[floor_idx]:
			var expected_id: String = "%d-%d" % [floor_idx, node["index"]]
			if node["id"] != expected_id:
				push_error("Node id='%s' expected='%s'" % [node["id"], expected_id])
				return false
	return true


func test_node_ids_are_unique() -> bool:
	var map: Array = _make_map()
	var seen: Dictionary = {}
	for node in _all_nodes(map):
		if seen.has(node["id"]):
			push_error("Duplicate node id: %s" % node["id"])
			return false
		seen[node["id"]] = true
	return true


func test_node_floor_field_matches_array_position() -> bool:
	var map: Array = _make_map()
	for floor_idx in range(map.size()):
		for node in map[floor_idx]:
			if node["floor"] != floor_idx:
				push_error("Node %s has floor=%d but is in array position %d" % [node["id"], node["floor"], floor_idx])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# VISITED / REVEALED STATE
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_nodes_start_unvisited() -> bool:
	var map: Array = _make_map()
	for node in _all_nodes(map):
		if node["visited"] != false:
			push_error("Node %s should start unvisited" % node["id"])
			return false
	return true


func test_first_two_floors_revealed() -> bool:
	var map: Array = _make_map()
	for floor_idx in range(map.size()):
		for node in map[floor_idx]:
			var expected: bool = floor_idx <= 1
			if node["revealed"] != expected:
				push_error("Node %s floor=%d: revealed=%s expected=%s" % [
					node["id"], floor_idx, str(node["revealed"]), str(expected)])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CARDS COUNT
# ═══════════════════════════════════════════════════════════════════════════════

func test_rest_and_merchant_have_zero_cards() -> bool:
	var map: Array = _make_map()
	for node in _all_nodes(map):
		if node["type"] == "REST" or node["type"] == "MERCHANT":
			if node["cards_count"] != 0:
				push_error("Node %s type=%s should have 0 cards, got %d" % [node["id"], node["type"], node["cards_count"]])
				return false
	return true


func test_cards_count_within_node_type_bounds() -> bool:
	var map: Array = _make_map()
	for node in _all_nodes(map):
		var ntype: String = node["type"]
		var type_data: Dictionary = MerlinMapSystem.NODE_TYPES.get(ntype, {})
		var cards_min: int = int(type_data.get("cards_min", 0))
		var cards_max: int = int(type_data.get("cards_max", 0))
		var cards: int = node["cards_count"]
		if cards_min <= 0 and cards_max <= 0:
			if cards != 0:
				push_error("Node %s type=%s: cards should be 0, got %d" % [node["id"], ntype, cards])
				return false
		else:
			if cards < cards_min or cards > cards_max:
				push_error("Node %s type=%s: cards=%d outside [%d,%d]" % [node["id"], ntype, cards, cards_min, cards_max])
				return false
	return true


func test_cards_count_non_negative() -> bool:
	var map: Array = _make_map()
	for node in _all_nodes(map):
		if node["cards_count"] < 0:
			push_error("Node %s has negative cards_count=%d" % [node["id"], node["cards_count"]])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CONNECTIVITY (DAG)
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_non_first_floor_node_has_at_least_one_parent() -> bool:
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
				push_error("Node %s (floor %d) has no parent in floor %d" % [node_id, floor_idx, floor_idx - 1])
				return false
	return true


func test_every_non_last_floor_node_has_at_least_one_child() -> bool:
	var map: Array = _make_map()
	for floor_idx in range(map.size() - 1):
		for node in map[floor_idx]:
			if node["connections"].is_empty():
				push_error("Node %s (floor %d) has no children" % [node["id"], floor_idx])
				return false
	return true


func test_no_node_has_more_than_three_connections() -> bool:
	var map: Array = _make_map()
	for node in _all_nodes(map):
		if node["connections"].size() > 3:
			push_error("Node %s has %d connections (max 3)" % [node["id"], node["connections"].size()])
			return false
	return true


func test_connections_reference_valid_node_ids() -> bool:
	# Build set of all node IDs, then verify every connection target exists
	var map: Array = _make_map()
	var all_ids: Dictionary = {}
	for node in _all_nodes(map):
		all_ids[node["id"]] = true
	for node in _all_nodes(map):
		for conn_id in node["connections"]:
			if not all_ids.has(conn_id):
				push_error("Node %s has connection to unknown id '%s'" % [node["id"], conn_id])
				return false
	return true


func test_connections_only_point_forward_one_floor() -> bool:
	# Each connection from floor N must target a node on floor N+1
	var map: Array = _make_map()
	for floor_idx in range(map.size() - 1):
		for node in map[floor_idx]:
			for conn_id in node["connections"]:
				# conn_id format: "floor-index"
				var parts: PackedStringArray = conn_id.split("-")
				if parts.size() < 2:
					push_error("Node %s connection '%s' has unexpected format" % [node["id"], conn_id])
					return false
				var target_floor: int = int(parts[0])
				if target_floor != floor_idx + 1:
					push_error("Node %s (floor %d) connects to '%s' (floor %d), expected floor %d" % [
						node["id"], floor_idx, conn_id, target_floor, floor_idx + 1])
					return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DETERMINISM
# ═══════════════════════════════════════════════════════════════════════════════

func test_map_structure_is_well_formed() -> bool:
	var map: Array = _make_map(8, 42)
	if map.size() != 8:
		push_error("Expected 8 floors, got %d" % map.size())
		return false
	for floor_idx in range(map.size()):
		var floor_nodes: Array = map[floor_idx]
		if floor_nodes.size() < 1:
			push_error("Floor %d has no nodes" % floor_idx)
			return false
		for node in floor_nodes:
			if not node.has("type") or not node.has("id") or not node.has("connections"):
				push_error("Floor %d node missing required keys" % floor_idx)
				return false
	return true


func test_different_seeds_produce_different_maps() -> bool:
	var map_a: Array = _make_map(8, 42)
	var map_b: Array = _make_map(8, 9999)
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
		push_error("Seeds 42 and 9999 produced identical middle floors (statistically improbable)")
		return false
	return true
