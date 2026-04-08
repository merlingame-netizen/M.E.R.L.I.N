## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Run Graph — Pre-generated scenario skeleton for a single run.
## ═══════════════════════════════════════════════════════════════════════════════
## Holds the node graph produced by the LLM (or procedural fallback).
## Provides navigation: advance along main path, enter/exit detours.
## Serializable to/from Dictionary for save/load.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name MerlinRunGraph


# ── Data ────────────────────────────────────────────────────────────────────

var scenario_title: String = ""
var scenario_synopsis: String = ""
var biome: String = ""
var season: String = ""
var weather: String = ""
var total_main_nodes: int = 0
var total_detour_nodes: int = 0
var estimated_cards: int = 0

## All nodes keyed by id: { "n0": {id, type, label, tone, next, ...}, ... }
var nodes: Dictionary = {}

## Ordered list of main-path node ids (excludes detour nodes).
var main_path: Array[String] = []

## Arc events: [{node_id, arc_type, arc_name?}]
var arc_events: Array[Dictionary] = []

## Generation metadata.
var metadata: Dictionary = {}

## Chapter break indices into main_path (where new paragraphs start in synopsis).
var chapter_breaks: Array[int] = []


# ── Navigation state ────────────────────────────────────────────────────────

## Index into main_path for current position (or -1 if not started).
var _current_main_index: int = -1

## If in a detour, the detour node id currently active. Empty if on main path.
var _current_detour_id: String = ""

## Stack of detour node ids traversed in current detour.
var _detour_stack: Array[String] = []

## Set of visited node ids.
var visited: Dictionary = {}


# ── Construction ────────────────────────────────────────────────────────────

## Build graph from a parsed LLM JSON dictionary.
static func from_dict(data: Dictionary) -> MerlinRunGraph:
	var graph: MerlinRunGraph = MerlinRunGraph.new()
	graph.scenario_title = str(data.get("scenario_title", ""))
	graph.scenario_synopsis = str(data.get("scenario_synopsis", ""))
	graph.biome = str(data.get("biome", ""))
	graph.season = str(data.get("season", ""))
	graph.weather = str(data.get("weather", ""))
	graph.total_main_nodes = int(data.get("total_main_nodes", 0))
	graph.total_detour_nodes = int(data.get("total_detour_nodes", 0))
	graph.estimated_cards = int(data.get("estimated_cards", 0))
	graph.metadata = data.get("metadata", {})

	# Parse chapter breaks.
	var breaks: Array = data.get("chapter_breaks", [])
	for b in breaks:
		graph.chapter_breaks.append(int(b))

	# Parse nodes array into dictionary keyed by id.
	var nodes_array: Array = data.get("nodes", [])
	for node_data in nodes_array:
		if node_data is Dictionary and node_data.has("id"):
			var nid: String = str(node_data["id"])
			graph.nodes[nid] = node_data

	# Build main_path: ordered non-detour nodes by floor.
	var main_nodes: Array[Dictionary] = []
	for nid in graph.nodes:
		var node: Dictionary = graph.nodes[nid]
		var is_detour: bool = node.get("is_detour", false)
		if not is_detour:
			main_nodes.append(node)
	main_nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("floor", 0)) < int(b.get("floor", 0))
	)
	graph.main_path.clear()
	for node in main_nodes:
		graph.main_path.append(str(node["id"]))

	# Parse arc_events.
	graph.arc_events = []
	var arcs: Array = data.get("arc_events", [])
	for arc in arcs:
		if arc is Dictionary:
			graph.arc_events.append(arc)

	return graph


## Serialize to Dictionary for save/load.
func to_dict() -> Dictionary:
	var nodes_array: Array[Dictionary] = []
	for nid in nodes:
		nodes_array.append(nodes[nid])
	return {
		"scenario_title": scenario_title,
		"scenario_synopsis": scenario_synopsis,
		"biome": biome,
		"season": season,
		"weather": weather,
		"total_main_nodes": total_main_nodes,
		"total_detour_nodes": total_detour_nodes,
		"estimated_cards": estimated_cards,
		"nodes": nodes_array,
		"arc_events": arc_events,
		"chapter_breaks": chapter_breaks,
		"metadata": metadata,
	}


# ── Validation ──────────────────────────────────────────────────────────────

## Validate the graph structure. Returns {"valid": bool, "errors": Array[String]}.
func validate() -> Dictionary:
	var errors: Array[String] = []

	if nodes.is_empty():
		errors.append("Graph has no nodes")
		return {"valid": false, "errors": errors}

	if main_path.is_empty():
		errors.append("Main path is empty")
		return {"valid": false, "errors": errors}

	# First node must be narrative.
	var first_node: Dictionary = nodes.get(main_path[0], {})
	if str(first_node.get("type", "")) != "narrative":
		errors.append("First node must be type 'narrative', got '%s'" % str(first_node.get("type", "")))

	# Last node must be merlin.
	var last_node: Dictionary = nodes.get(main_path[main_path.size() - 1], {})
	if str(last_node.get("type", "")) != "merlin":
		errors.append("Last node must be type 'merlin', got '%s'" % str(last_node.get("type", "")))

	# All next references must point to existing nodes.
	for nid in nodes:
		var node: Dictionary = nodes[nid]
		var next_ids: Array = node.get("next", [])
		for next_id in next_ids:
			if not nodes.has(str(next_id)):
				errors.append("Node '%s' references non-existent next '%s'" % [nid, str(next_id)])

	# Detour integrity: every detour_start must have a matching detour_end that reconnects.
	var detour_starts: Array[String] = []
	var detour_ends: Array[String] = []
	for nid in nodes:
		var node: Dictionary = nodes[nid]
		var ntype: String = str(node.get("type", ""))
		if ntype == "detour_start":
			detour_starts.append(nid)
		elif ntype == "detour_end":
			detour_ends.append(nid)

	if detour_starts.size() != detour_ends.size():
		errors.append("Detour start/end count mismatch: %d starts, %d ends" % [detour_starts.size(), detour_ends.size()])

	# Each detour_end must connect back to a main-path node.
	for de_id in detour_ends:
		var de_node: Dictionary = nodes.get(de_id, {})
		var de_next: Array = de_node.get("next", [])
		var reconnects: bool = false
		for next_id in de_next:
			var target: Dictionary = nodes.get(str(next_id), {})
			if not target.get("is_detour", false):
				reconnects = true
				break
		if not reconnects:
			errors.append("Detour end '%s' does not reconnect to main path" % de_id)

	# Estimated cards within MOS bounds.
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var soft_min: int = int(mos.get("soft_min_cards", 8))
	var hard_max: int = int(mos.get("hard_max_cards", 50))
	if estimated_cards < soft_min:
		errors.append("estimated_cards (%d) below MOS soft_min (%d)" % [estimated_cards, soft_min])
	if estimated_cards > hard_max:
		errors.append("estimated_cards (%d) above MOS hard_max (%d)" % [estimated_cards, hard_max])

	# No orphan nodes (every node except first must be referenced by at least one
	# other node via "next" or "detour_entry").
	var referenced: Dictionary = {}
	for nid in nodes:
		var node: Dictionary = nodes[nid]
		for next_id in node.get("next", []):
			referenced[str(next_id)] = true
		var det_entry: String = str(node.get("detour_entry", ""))
		if det_entry != "" and det_entry != "null" and det_entry != "<null>":
			referenced[det_entry] = true
	for nid in nodes:
		if nid != main_path[0] and not referenced.has(nid):
			errors.append("Orphan node '%s' (not referenced by any other node)" % nid)

	return {"valid": errors.is_empty(), "errors": errors}


# ── Navigation ──────────────────────────────────────────────────────────────

## Start the run. Returns the first node.
func start() -> Dictionary:
	_current_main_index = 0
	_current_detour_id = ""
	_detour_stack.clear()
	visited.clear()
	if main_path.is_empty():
		return {}
	var nid: String = main_path[0]
	visited[nid] = true
	return nodes.get(nid, {})


## Get the current active node.
func current_node() -> Dictionary:
	if _current_detour_id != "":
		return nodes.get(_current_detour_id, {})
	if _current_main_index < 0 or _current_main_index >= main_path.size():
		return {}
	return nodes.get(main_path[_current_main_index], {})


## Advance to the next main-path node. Returns the node or empty if run ended.
func advance() -> Dictionary:
	# If in detour, exit first.
	if _current_detour_id != "":
		return _exit_detour()

	_current_main_index += 1
	if _current_main_index >= main_path.size():
		return {}  # Run ended
	var nid: String = main_path[_current_main_index]
	visited[nid] = true
	return nodes.get(nid, {})


## Enter a detour from the current main-path node.
## detour_id must be a detour_start node id referenced by the current node.
func enter_detour(detour_id: String) -> Dictionary:
	if not nodes.has(detour_id):
		push_warning("[MerlinRunGraph] Detour '%s' not found" % detour_id)
		return advance()
	var detour_node: Dictionary = nodes[detour_id]
	if str(detour_node.get("type", "")) != "detour_start":
		push_warning("[MerlinRunGraph] Node '%s' is not detour_start" % detour_id)
		return advance()
	_current_detour_id = detour_id
	_detour_stack.clear()
	_detour_stack.append(detour_id)
	visited[detour_id] = true
	return detour_node


## Advance within the current detour. Returns next detour node or exits if done.
func advance_detour() -> Dictionary:
	if _current_detour_id == "":
		return advance()

	var current: Dictionary = nodes.get(_current_detour_id, {})
	var next_ids: Array = current.get("next", [])
	if next_ids.is_empty():
		return _exit_detour()

	# Follow first next (detours are linear).
	var next_id: String = str(next_ids[0])
	var next_node: Dictionary = nodes.get(next_id, {})

	# If next is detour_end, mark visited and exit detour.
	if str(next_node.get("type", "")) == "detour_end":
		visited[next_id] = true
		_detour_stack.append(next_id)
		return _exit_detour()

	# Continue in detour.
	_current_detour_id = next_id
	_detour_stack.append(next_id)
	visited[next_id] = true
	return next_node


## Check if the current node has a detour available.
func has_detour() -> bool:
	var node: Dictionary = current_node()
	var entry: String = str(node.get("detour_entry", ""))
	return entry != "" and entry != "null" and nodes.has(entry)


## Get the detour_entry id for the current node (or empty).
func get_detour_id() -> String:
	var node: Dictionary = current_node()
	var entry: String = str(node.get("detour_entry", ""))
	if entry == "null":
		return ""
	return entry


## Is the run finished? (past last main node and not in detour)
func is_finished() -> bool:
	return _current_main_index >= main_path.size() and _current_detour_id == ""


## Progress ratio 0.0 to 1.0.
func progress() -> float:
	if main_path.is_empty():
		return 0.0
	return clampf(float(_current_main_index) / float(main_path.size() - 1), 0.0, 1.0)


## Whether currently in a detour.
func is_in_detour() -> bool:
	return _current_detour_id != ""


## Get all node ids (main + detour) in visit order for journey recap.
func get_visited_path() -> Array[String]:
	var path: Array[String] = []
	for nid in main_path:
		if visited.has(nid):
			path.append(nid)
	# Detour nodes visited are interleaved — sort by visit order is implicit
	# since visited is marked during traversal.
	for nid in nodes:
		if visited.has(nid) and not main_path.has(nid):
			path.append(nid)
	return path


# ── Private ─────────────────────────────────────────────────────────────────

func _exit_detour() -> Dictionary:
	_current_detour_id = ""
	_detour_stack.clear()
	# Advance to next main node.
	_current_main_index += 1
	if _current_main_index >= main_path.size():
		return {}
	var nid: String = main_path[_current_main_index]
	visited[nid] = true
	return nodes.get(nid, {})
