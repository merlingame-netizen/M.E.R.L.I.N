## =============================================================================
## Merlin Scenario Manager — Hand of Fate 2-style quest system
## =============================================================================
## Manages run-spanning scenarios with anchor cards at specific positions,
## conditional branching, and thematic injection into LLM prompts.
## =============================================================================

extends RefCounted
class_name MerlinScenarioManager

signal scenario_started(scenario_id: String)
signal anchor_triggered(anchor_id: String, card_index: int)
signal scenario_resolved(scenario_id: String, resolution: String)

const CATALOGUE_PATH := "res://data/ai/scenarios/scenario_catalogue.json"

# =============================================================================
# STATE
# =============================================================================

var active_scenario: Dictionary = {}
var triggered_anchors: Array[String] = []
var scenario_flags: Dictionary = {}
var _catalogue: Dictionary = {}
var _loaded := false


# =============================================================================
# CATALOGUE LOADING
# =============================================================================

func _ensure_loaded() -> void:
	if _loaded:
		return
	if not FileAccess.file_exists(CATALOGUE_PATH):
		push_warning("[ScenarioManager] Catalogue not found: %s" % CATALOGUE_PATH)
		_loaded = true
		return
	var f := FileAccess.open(CATALOGUE_PATH, FileAccess.READ)
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK:
		push_error("[ScenarioManager] JSON parse error: %s" % json.get_error_message())
		_loaded = true
		return
	var data: Dictionary = json.data if json.data is Dictionary else {}
	_catalogue = data.get("scenarios", {})
	_loaded = true
	print("[ScenarioManager] Loaded %d scenarios" % _catalogue.size())


# =============================================================================
# SCENARIO SELECTION
# =============================================================================

func select_scenario(biome: String, meta: Dictionary) -> Dictionary:
	## Select a scenario for this run based on biome affinity and meta-progression.
	## Returns empty dict for a scenario-free run.
	_ensure_loaded()
	if _catalogue.is_empty():
		return {}

	var scenarios_seen: Array = meta.get("scenarios_seen", [])
	var candidates: Array[Dictionary] = []
	var total_weight: float = 0.0

	for key in _catalogue:
		var sc: Dictionary = _catalogue[key]
		var affinity: Array = sc.get("biome_affinity", [])
		# Filter by biome affinity (empty = all biomes)
		if not affinity.is_empty() and not affinity.has(biome):
			continue
		# Reduce weight for recently seen scenarios (not hard exclude — allow replays)
		var base_weight: float = float(sc.get("weight", 1.0))
		if scenarios_seen.has(key):
			base_weight *= 0.3
		candidates.append({"scenario": sc, "weight": base_weight})
		total_weight += base_weight

	if candidates.is_empty() or total_weight <= 0.0:
		return {}

	# Weighted random selection
	var roll: float = randf() * total_weight
	var cumul: float = 0.0
	for c in candidates:
		cumul += float(c["weight"])
		if roll <= cumul:
			return c["scenario"]

	return candidates[-1]["scenario"]


func start_scenario(scenario: Dictionary) -> void:
	## Initialize a scenario for the current run.
	if scenario.is_empty():
		return
	active_scenario = scenario.duplicate(true)
	triggered_anchors.clear()
	scenario_flags.clear()
	scenario_started.emit(str(scenario.get("id", "")))
	print("[ScenarioManager] Started scenario: %s" % str(scenario.get("title", "")))


# =============================================================================
# ANCHOR SYSTEM
# =============================================================================

func get_anchor_for_card(card_index: int, game_flags: Dictionary) -> Dictionary:
	## Check if an anchor should trigger at this card position.
	## Returns the resolved anchor (with branch selection) or empty dict.
	if not is_scenario_active():
		return {}

	var anchors: Array = active_scenario.get("anchors", [])
	for anchor in anchors:
		if not anchor is Dictionary:
			continue
		var anchor_id: String = str(anchor.get("id", ""))

		# Skip already triggered
		if triggered_anchors.has(anchor_id):
			continue

		# Check position (+/- flex)
		var pos: int = int(anchor.get("position", 0))
		var flex: int = int(anchor.get("position_flex", 1))
		if card_index < pos - flex or card_index > pos + flex:
			continue

		# Check condition
		if not _check_condition(anchor.get("condition", {}), game_flags):
			continue

		# Resolve branch
		var resolved := _resolve_branch(anchor, game_flags)
		resolved["anchor_id"] = anchor_id
		resolved["anchor_type"] = str(anchor.get("type", ""))
		resolved["must_reference"] = anchor.get("must_reference", [])
		return resolved

	return {}


func resolve_anchor(anchor_id: String, chosen_option: int) -> void:
	## Mark anchor as triggered and apply its flags/tags.
	if triggered_anchors.has(anchor_id):
		return
	triggered_anchors.append(anchor_id)

	# Find anchor data and apply flags
	var anchors: Array = active_scenario.get("anchors", [])
	for anchor in anchors:
		if not anchor is Dictionary:
			continue
		if str(anchor.get("id", "")) != anchor_id:
			continue

		# Apply flags from resolved branch
		var resolved := _resolve_branch(anchor, scenario_flags)
		var flags_to_set: Array = resolved.get("flags_set", [])
		for flag in flags_to_set:
			scenario_flags[str(flag)] = true

		var tags_to_add: Array = anchor.get("tags_add", [])
		# Tags are returned for the caller to apply via effect engine
		break

	anchor_triggered.emit(anchor_id, -1)
	print("[ScenarioManager] Anchor resolved: %s (option %d)" % [anchor_id, chosen_option])


# =============================================================================
# CONTEXT FOR LLM
# =============================================================================

func get_theme_injection() -> String:
	## Returns the thematic text to inject into every card's LLM prompt.
	if not is_scenario_active():
		return ""
	return str(active_scenario.get("theme_injection", ""))


func get_dealer_intro_override() -> Dictionary:
	## Returns override context for the dealer monologue in TransitionBiome.
	if not is_scenario_active():
		return {}
	var context: String = str(active_scenario.get("dealer_intro_context", ""))
	if context.is_empty():
		return {}
	return {
		"context": context,
		"tone": str(active_scenario.get("tone", "")),
		"title": str(active_scenario.get("title", "")),
	}


func get_scenario_tone() -> String:
	## Returns the dominant tone for this scenario.
	if not is_scenario_active():
		return ""
	return str(active_scenario.get("tone", ""))


func get_ambient_tags() -> Array:
	## Returns ambient tags for non-anchor cards.
	if not is_scenario_active():
		return []
	return active_scenario.get("ambient_tags", [])


func get_scenario_title() -> String:
	if not is_scenario_active():
		return ""
	return str(active_scenario.get("title", ""))


# =============================================================================
# STATE QUERIES
# =============================================================================

func is_scenario_active() -> bool:
	return not active_scenario.is_empty()


func get_triggered_count() -> int:
	return triggered_anchors.size()


func get_total_anchors() -> int:
	if not is_scenario_active():
		return 0
	return active_scenario.get("anchors", []).size()


func get_scenario_flags() -> Dictionary:
	return scenario_flags.duplicate()


# =============================================================================
# SAVE / LOAD
# =============================================================================

func save_state() -> Dictionary:
	return {
		"active_scenario_id": str(active_scenario.get("id", "")),
		"triggered_anchors": triggered_anchors.duplicate(),
		"scenario_flags": scenario_flags.duplicate(),
	}


func load_state(data: Dictionary) -> void:
	if data.is_empty():
		active_scenario = {}
		triggered_anchors.clear()
		scenario_flags.clear()
		return

	_ensure_loaded()
	var scenario_id: String = str(data.get("active_scenario_id", ""))
	if not scenario_id.is_empty() and _catalogue.has(scenario_id):
		active_scenario = _catalogue[scenario_id].duplicate(true)
	else:
		active_scenario = {}

	var saved_anchors: Array = data.get("triggered_anchors", [])
	triggered_anchors.clear()
	for a in saved_anchors:
		triggered_anchors.append(str(a))

	var saved_flags: Dictionary = data.get("scenario_flags", {})
	scenario_flags.clear()
	for key in saved_flags:
		scenario_flags[str(key)] = saved_flags[key]


# =============================================================================
# PRIVATE HELPERS
# =============================================================================

func _check_condition(condition: Dictionary, flags: Dictionary) -> bool:
	## Evaluate anchor condition against current flags.
	if condition.is_empty():
		return true

	# Single flag check
	var flag_name: String = str(condition.get("flag", ""))
	if not flag_name.is_empty():
		# Check both scenario_flags and game_flags
		return scenario_flags.get(flag_name, false) or flags.get(flag_name, false)

	# Any-flag check (OR)
	var any_flags: Array = condition.get("any_flag", [])
	if not any_flags.is_empty():
		for f in any_flags:
			if scenario_flags.get(str(f), false) or flags.get(str(f), false):
				return true
		return false

	# All-flags check (AND)
	var all_flags: Array = condition.get("all_flags", [])
	if not all_flags.is_empty():
		for f in all_flags:
			if not (scenario_flags.get(str(f), false) or flags.get(str(f), false)):
				return false
		return true

	return true


func _resolve_branch(anchor: Dictionary, flags: Dictionary) -> Dictionary:
	## Select the appropriate branch based on current flags.
	var branches: Dictionary = anchor.get("branches", {})
	if branches.is_empty():
		# No branches — return anchor directly
		return {
			"prompt_override": str(anchor.get("prompt_override", "")),
			"flags_set": anchor.get("flags_set", []),
			"tone": str(anchor.get("tone", "")),
		}

	# Check flag-based branches first (if_flag_xxx)
	for branch_key in branches:
		if not str(branch_key).begins_with("if_flag_"):
			continue
		var flag_name: String = str(branch_key).substr(8)  # Remove "if_flag_"
		if scenario_flags.get(flag_name, false) or flags.get(flag_name, false):
			var branch: Dictionary = branches[branch_key]
			return {
				"prompt_override": str(branch.get("prompt_override", "")),
				"flags_set": branch.get("flags_set", []),
				"tone": str(branch.get("tone", "")),
			}

	# Default branch
	var default_branch: Dictionary = branches.get("default", {})
	return {
		"prompt_override": str(default_branch.get("prompt_override", "")),
		"flags_set": default_branch.get("flags_set", []),
		"tone": str(default_branch.get("tone", "")),
	}
