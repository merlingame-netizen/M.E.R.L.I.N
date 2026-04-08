## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — Skeleton Map System (pre-run graph generation) — 18 tests
## ═══════════════════════════════════════════════════════════════════════════════
## Covers: MerlinRunGraph, MerlinSkeletonGenerator (procedural), LlmAdapterMapPrompt,
##         BIOME_NODE_RANGES, WEATHER_TYPES, DETOUR_REWARDS constants.
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error before false.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _sample_graph_data() -> Dictionary:
	return {
		"scenario_title": "Test Scenario",
		"scenario_synopsis": "A test adventure in Broceliande.",
		"biome": "foret_broceliande",
		"season": "printemps",
		"weather": "brume_legere",
		"total_main_nodes": 5,
		"total_detour_nodes": 2,
		"estimated_cards": 9,
		"nodes": [
			{"id": "n0", "type": "narrative", "label": "Start", "tone": "mystere", "next": ["n1"], "is_detour": false, "detour_entry": null, "floor": 0},
			{"id": "n1", "type": "event", "label": "Event", "tone": "tension", "next": ["n2"], "is_detour": false, "detour_entry": "d0", "floor": 1},
			{"id": "n2", "type": "rest", "label": "Rest", "tone": "soulagement", "next": ["n3"], "is_detour": false, "detour_entry": null, "floor": 2},
			{"id": "n3", "type": "narrative", "label": "Late", "tone": "climax", "next": ["n4"], "is_detour": false, "detour_entry": null, "floor": 3},
			{"id": "n4", "type": "merlin", "label": "Merlin", "tone": "sagesse", "next": [], "is_detour": false, "detour_entry": null, "floor": 4},
			{"id": "d0", "type": "detour_start", "label": "Grotte", "tone": "emerveillement", "next": ["d1"], "is_detour": true, "reward_hint": "anam_bonus", "floor": 1},
			{"id": "d1", "type": "detour_end", "label": "Retour", "tone": "soulagement", "next": ["n2"], "is_detour": true, "floor": 1},
		],
		"arc_events": [{"node_id": "n3", "arc_type": "climax_arc"}],
		"metadata": {"procedural_fallback": false},
	}


func _make_graph() -> MerlinRunGraph:
	return MerlinRunGraph.from_dict(_sample_graph_data())


# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_biome_node_ranges_exist() -> bool:
	for biome_id in MerlinConstants.BIOMES:
		if not MerlinConstants.BIOME_NODE_RANGES.has(biome_id):
			push_error("BIOME_NODE_RANGES missing key: %s" % biome_id)
			return false
		var r: Dictionary = MerlinConstants.BIOME_NODE_RANGES[biome_id]
		if int(r["main_min"]) > int(r["main_max"]):
			push_error("main_min > main_max for %s" % biome_id)
			return false
	return true


func test_weather_types_have_season_weights() -> bool:
	for wid in MerlinConstants.WEATHER_TYPES:
		var w: Dictionary = MerlinConstants.WEATHER_TYPES[wid]
		if not w.has("season_weight"):
			push_error("WEATHER_TYPES['%s'] missing season_weight" % wid)
			return false
		if not w.has("tone"):
			push_error("WEATHER_TYPES['%s'] missing tone" % wid)
			return false
	return true


func test_detour_rewards_valid() -> bool:
	if MerlinConstants.DETOUR_REWARDS.is_empty():
		push_error("DETOUR_REWARDS is empty")
		return false
	for rid in MerlinConstants.DETOUR_REWARDS:
		var r: Dictionary = MerlinConstants.DETOUR_REWARDS[rid]
		if not r.has("label"):
			push_error("DETOUR_REWARDS['%s'] missing label" % rid)
			return false
	return true


func test_skeleton_node_types_array() -> bool:
	if MerlinConstants.SKELETON_NODE_TYPES.size() != 9:
		push_error("Expected 9 SKELETON_NODE_TYPES, got %d" % MerlinConstants.SKELETON_NODE_TYPES.size())
		return false
	if not MerlinConstants.SKELETON_NODE_TYPES.has("detour_start"):
		push_error("SKELETON_NODE_TYPES missing detour_start")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN RUN GRAPH — from_dict
# ═══════════════════════════════════════════════════════════════════════════════

func test_graph_from_dict_parses_nodes() -> bool:
	var g: MerlinRunGraph = _make_graph()
	if g.nodes.size() != 7:
		push_error("Expected 7 nodes, got %d" % g.nodes.size())
		return false
	return true


func test_graph_main_path_excludes_detours() -> bool:
	var g: MerlinRunGraph = _make_graph()
	if g.main_path.size() != 5:
		push_error("Expected 5 main path nodes, got %d" % g.main_path.size())
		return false
	for nid in g.main_path:
		var node: Dictionary = g.nodes[nid]
		if node.get("is_detour", false):
			push_error("Main path contains detour node: %s" % nid)
			return false
	return true


func test_graph_serialization_roundtrip() -> bool:
	var g: MerlinRunGraph = _make_graph()
	var dict: Dictionary = g.to_dict()
	var g2: MerlinRunGraph = MerlinRunGraph.from_dict(dict)
	if g2.scenario_title != g.scenario_title:
		push_error("Title mismatch after roundtrip")
		return false
	if g2.nodes.size() != g.nodes.size():
		push_error("Node count mismatch after roundtrip: %d vs %d" % [g2.nodes.size(), g.nodes.size()])
		return false
	if g2.main_path.size() != g.main_path.size():
		push_error("Main path size mismatch after roundtrip")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN RUN GRAPH — validation
# ═══════════════════════════════════════════════════════════════════════════════

func test_graph_validates_ok() -> bool:
	var g: MerlinRunGraph = _make_graph()
	var result: Dictionary = g.validate()
	if not result["valid"]:
		push_error("Valid graph failed validation: %s" % str(result["errors"]))
		return false
	return true


func test_graph_rejects_wrong_first_node() -> bool:
	var data: Dictionary = _sample_graph_data()
	data["nodes"][0]["type"] = "event"
	var g: MerlinRunGraph = MerlinRunGraph.from_dict(data)
	var result: Dictionary = g.validate()
	if result["valid"]:
		push_error("Should reject graph with non-narrative first node")
		return false
	return true


func test_graph_rejects_wrong_last_node() -> bool:
	var data: Dictionary = _sample_graph_data()
	data["nodes"][4]["type"] = "narrative"
	var g: MerlinRunGraph = MerlinRunGraph.from_dict(data)
	var result: Dictionary = g.validate()
	if result["valid"]:
		push_error("Should reject graph with non-merlin last node")
		return false
	return true


func test_graph_rejects_broken_next_ref() -> bool:
	var data: Dictionary = _sample_graph_data()
	data["nodes"][0]["next"] = ["nonexistent"]
	var g: MerlinRunGraph = MerlinRunGraph.from_dict(data)
	var result: Dictionary = g.validate()
	if result["valid"]:
		push_error("Should reject graph with broken next reference")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN RUN GRAPH — navigation
# ═══════════════════════════════════════════════════════════════════════════════

func test_graph_navigation_start() -> bool:
	var g: MerlinRunGraph = _make_graph()
	var first: Dictionary = g.start()
	if str(first.get("id", "")) != "n0":
		push_error("start() should return n0, got %s" % str(first.get("id", "")))
		return false
	if not g.visited.has("n0"):
		push_error("n0 should be marked visited")
		return false
	return true


func test_graph_navigation_advance() -> bool:
	var g: MerlinRunGraph = _make_graph()
	g.start()
	var second: Dictionary = g.advance()
	if str(second.get("id", "")) != "n1":
		push_error("advance() should return n1, got %s" % str(second.get("id", "")))
		return false
	return true


func test_graph_navigation_detour() -> bool:
	var g: MerlinRunGraph = _make_graph()
	g.start()
	g.advance()  # n1

	if not g.has_detour():
		push_error("n1 should have a detour available")
		return false

	var detour: Dictionary = g.enter_detour("d0")
	if str(detour.get("id", "")) != "d0":
		push_error("enter_detour should return d0, got %s" % str(detour.get("id", "")))
		return false

	if not g.is_in_detour():
		push_error("Should be in detour after enter_detour()")
		return false

	var after: Dictionary = g.advance_detour()
	# d1 is detour_end, so it should exit and return n2
	if str(after.get("id", "")) != "n2":
		push_error("advance_detour from d0 should reach n2 via d1 exit, got %s" % str(after.get("id", "")))
		return false

	if g.is_in_detour():
		push_error("Should not be in detour after exiting")
		return false
	return true


func test_graph_navigation_finish() -> bool:
	var g: MerlinRunGraph = _make_graph()
	g.start()
	g.advance()  # n1
	g.advance()  # n2
	g.advance()  # n3
	g.advance()  # n4 (merlin, last)
	var past: Dictionary = g.advance()  # past end
	if not past.is_empty():
		push_error("Advancing past end should return empty dict")
		return false
	if not g.is_finished():
		push_error("Should be finished after advancing past last node")
		return false
	return true


func test_graph_progress() -> bool:
	var g: MerlinRunGraph = _make_graph()
	g.start()
	if g.progress() > 0.01:
		push_error("Progress at start should be ~0.0, got %.2f" % g.progress())
		return false
	g.advance()
	g.advance()
	g.advance()
	g.advance()
	if g.progress() < 0.99:
		push_error("Progress at end should be ~1.0, got %.2f" % g.progress())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROCEDURAL FALLBACK
# ═══════════════════════════════════════════════════════════════════════════════

func test_procedural_generates_valid_graph() -> bool:
	var ctx: Dictionary = {
		"biome_id": "foret_broceliande",
		"ogham_id": "beith",
		"faction_rep": 20,
		"previous_runs": 0,
		"explored_detours": [],
		"weather": "clair",
		"festival": "",
		"trust_tier": 0,
		"trust_value": 50,
	}
	var g: MerlinRunGraph = MerlinSkeletonGenerator._generate_procedural(ctx)
	var result: Dictionary = g.validate()
	if not result["valid"]:
		push_error("Procedural graph failed validation: %s" % str(result["errors"]))
		return false
	if g.main_path.size() < 10:
		push_error("Foret procedural should have >= 10 main nodes, got %d" % g.main_path.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# LLM PROMPT BUILDER
# ═══════════════════════════════════════════════════════════════════════════════

func test_prompt_builder_system_not_empty() -> bool:
	var sys: String = LlmAdapterMapPrompt.build_system_prompt()
	if sys.length() < 100:
		push_error("System prompt too short: %d chars" % sys.length())
		return false
	return true


func test_prompt_builder_user_contains_biome() -> bool:
	var ctx: Dictionary = {
		"biome_id": "marais_korrigans",
		"ogham_id": "gort",
		"faction_rep": 55,
		"previous_runs": 2,
		"explored_detours": ["d0"],
		"weather": "brouillard_epais",
		"festival": "",
		"trust_tier": 1,
		"trust_value": 35,
	}
	var user: String = LlmAdapterMapPrompt.build_user_prompt(ctx)
	if user.find("Marais") < 0 and user.find("marais") < 0:
		push_error("User prompt should mention biome name 'Marais'")
		return false
	if user.find("SYMPATHISANT") < 0:
		push_error("User prompt should mention SYMPATHISANT for rep=55")
		return false
	if user.find("brouillard") < 0:
		push_error("User prompt should mention weather 'brouillard'")
		return false
	return true
