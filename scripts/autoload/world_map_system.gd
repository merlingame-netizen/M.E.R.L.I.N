## =============================================================================
## World Map System — Singleton Autoload for Biome Tree Navigation
## =============================================================================
## Orchestrates gauge-based biome progression across 4 tiers.
## Composes MerlinGaugeSystem + MerlinBiomeTree for condition checking.
## Interfaces with MerlinStore for state persistence.
##
## NOTE: This is DIFFERENT from MerlinMapSystem (STS-like intra-biome floor map).
## This system manages INTER-biome world navigation.
## =============================================================================

extends Node


# =============================================================================
# SIGNALS
# =============================================================================

signal gauges_changed(gauges: Dictionary)
signal biome_unlocked(biome_key: String)
signal biome_completed(biome_key: String)
signal map_state_changed(map_state: Dictionary)
signal fallback_event_triggered(biome_key: String, event_data: Dictionary)


# =============================================================================
# SUB-SYSTEMS
# =============================================================================

var _gauge_system := MerlinGaugeSystem.new()
var _biome_tree := MerlinBiomeTree.new()
var _store: Node = null  # MerlinStore, wired in _ready


# =============================================================================
# FALLBACK EVENT TEMPLATES — for when player can't access a biome
# =============================================================================

const FALLBACK_EVENTS: Dictionary = {
	"npc_encounter": {
		"type": "NPC",
		"title": "Rencontre sur le chemin",
		"description": "Un voyageur offre son aide en echange d'un service.",
		"gauge_rewards": {"faveur": 10, "ressources": 5},
	},
	"essence_trade": {
		"type": "TRADE",
		"title": "Marchands ambulants",
		"description": "Des marchands proposent un echange favorable.",
		"gauge_rewards": {"ressources": 15},
	},
	"druid_blessing": {
		"type": "BLESSING",
		"title": "Benediction druidique",
		"description": "Un druide itinerant partage sa sagesse.",
		"gauge_rewards": {"esprit": 10, "logique": 5},
	},
	"training_camp": {
		"type": "TRAINING",
		"title": "Campement d'entrainement",
		"description": "Des guerriers proposent un entrainement.",
		"gauge_rewards": {"vigueur": 15},
	},
}


# =============================================================================
# INITIALIZATION
# =============================================================================

func _ready() -> void:
	call_deferred("_deferred_wire_store")


func _deferred_wire_store() -> void:
	_store = get_node_or_null("/root/MerlinStore")
	if _store == null:
		push_warning("[WorldMapSystem] MerlinStore not found, will retry on access")


func _ensure_store() -> Node:
	if _store == null:
		_store = get_node_or_null("/root/MerlinStore")
	return _store


# =============================================================================
# STATE ACCESSORS
# =============================================================================

## Get current map progression state from store
func get_map_state() -> Dictionary:
	var store := _ensure_store()
	if store == null:
		return {}
	return store.get_map_progression()


## Get current gauges
func get_gauges() -> Dictionary:
	var store := _ensure_store()
	if store == null:
		return _gauge_system.build_default_gauges()
	return store.get_map_gauges()


## Get a single gauge value
func get_gauge(gauge_key: String) -> int:
	var store := _ensure_store()
	if store == null:
		return 0
	return store.get_map_gauge(gauge_key)


## Get current biome key
func get_current_biome() -> String:
	var store := _ensure_store()
	if store == null:
		return MerlinBiomeTree.ROOT_BIOME
	return store.get_current_biome()


## Get completed biomes list
func get_completed_biomes() -> Array:
	var store := _ensure_store()
	if store == null:
		return []
	return store.get_completed_biomes()


# =============================================================================
# GAUGE OPERATIONS
# =============================================================================

## Update gauges with a delta, applying current biome modifier.
## Returns new gauge values.
func update_gauges(raw_delta: Dictionary, weather: String = "clear") -> Dictionary:
	var store := _ensure_store()
	if store == null:
		return {}

	var current_biome: String = get_current_biome()
	var current_gauges: Dictionary = get_gauges()

	# Apply biome modifier to the delta
	var modified_gauges: Dictionary = _gauge_system.apply_biome_modifier(
		current_gauges, current_biome, raw_delta, weather
	)

	# Calculate the effective delta (modified - current)
	var effective_delta: Dictionary = {}
	for key in MerlinGaugeSystem.GAUGE_KEYS:
		var diff: int = int(modified_gauges.get(key, 0)) - int(current_gauges.get(key, 0))
		if diff != 0:
			effective_delta[key] = diff

	if effective_delta.is_empty():
		return current_gauges

	# Dispatch to store
	var result: Dictionary = await store.dispatch({
		"type": "MAP_UPDATE_GAUGES",
		"delta": effective_delta,
	})

	var new_gauges: Dictionary = result.get("gauges", modified_gauges)
	gauges_changed.emit(new_gauges)
	return new_gauges


## Update gauges directly without biome modifier (for events/fallbacks)
func update_gauges_direct(delta: Dictionary) -> Dictionary:
	var store := _ensure_store()
	if store == null:
		return {}

	var result: Dictionary = await store.dispatch({
		"type": "MAP_UPDATE_GAUGES",
		"delta": delta,
	})

	var new_gauges: Dictionary = result.get("gauges", {})
	gauges_changed.emit(new_gauges)
	return new_gauges


# =============================================================================
# BIOME NAVIGATION
# =============================================================================

## Check if a biome is accessible with current state
func is_biome_accessible(biome_key: String) -> bool:
	var store := _ensure_store()
	if store == null:
		return biome_key == MerlinBiomeTree.ROOT_BIOME

	var map_state: Dictionary = get_map_state()
	var gauges: Dictionary = get_gauges()
	return _biome_tree.is_biome_accessible(biome_key, map_state, gauges, store.state)


## Get all currently accessible biomes
func get_accessible_biomes() -> Array:
	var result: Array = []
	for biome_key in MerlinBiomeTree.BIOME_KEYS:
		if is_biome_accessible(biome_key):
			result.append(biome_key)
	return result


## Select a biome as current destination. Validates accessibility.
func select_biome(biome_key: String) -> Dictionary:
	if not is_biome_accessible(biome_key):
		var hint: String = get_unlock_hint(biome_key)
		return {"ok": false, "error": "Biome inaccessible", "hint": hint}

	var store := _ensure_store()
	if store == null:
		return {"ok": false, "error": "Store unavailable"}

	var result: Dictionary = await store.dispatch({
		"type": "MAP_SELECT_BIOME",
		"biome_key": biome_key,
	})

	map_state_changed.emit(get_map_state())
	return result


## Mark a biome as completed. Checks for newly unlocked biomes.
func complete_biome(biome_key: String) -> Dictionary:
	var store := _ensure_store()
	if store == null:
		return {"ok": false, "error": "Store unavailable"}

	# Get state before completion to detect new unlocks
	var previously_accessible: Array = get_accessible_biomes()

	var result: Dictionary = await store.dispatch({
		"type": "MAP_COMPLETE_BIOME",
		"biome_key": biome_key,
	})

	biome_completed.emit(biome_key)

	# Check for newly unlocked biomes
	var now_accessible: Array = get_accessible_biomes()
	for new_biome in now_accessible:
		if not new_biome in previously_accessible:
			biome_unlocked.emit(new_biome)

	map_state_changed.emit(get_map_state())
	return result


## Collect an item (stored in map_progression)
func collect_item(item_id: String) -> Dictionary:
	var store := _ensure_store()
	if store == null:
		return {"ok": false}

	var result: Dictionary = await store.dispatch({
		"type": "MAP_COLLECT_ITEM",
		"item_id": item_id,
	})

	map_state_changed.emit(get_map_state())
	return result


## Add a reputation (stored in map_progression)
func add_reputation(reputation_id: String) -> Dictionary:
	var store := _ensure_store()
	if store == null:
		return {"ok": false}

	var result: Dictionary = await store.dispatch({
		"type": "MAP_ADD_REPUTATION",
		"reputation_id": reputation_id,
	})

	map_state_changed.emit(get_map_state())
	return result


# =============================================================================
# HINTS & DISPLAY
# =============================================================================

## Get user-facing unlock hint for a biome
func get_unlock_hint(biome_key: String) -> String:
	var store := _ensure_store()
	if store == null:
		return "Conditions inconnues"
	var map_state: Dictionary = get_map_state()
	var gauges: Dictionary = get_gauges()
	return _biome_tree.get_unlock_hint(biome_key, gauges, map_state, store.state)


## Get gauge display info for UI rendering
func get_gauge_displays() -> Array:
	var gauges: Dictionary = get_gauges()
	var displays: Array = []
	for key in MerlinGaugeSystem.GAUGE_KEYS:
		displays.append(_gauge_system.get_gauge_display(gauges, key))
	return displays


## Get the biome modifier description for display
func get_biome_modifiers_text(biome_key: String) -> String:
	var parts: Array = []
	for gauge_key in MerlinGaugeSystem.GAUGE_KEYS:
		var mod: float = _gauge_system.get_biome_modifier(biome_key, gauge_key)
		if absf(mod - 1.0) > 0.01:
			var def: Dictionary = MerlinGaugeSystem.GAUGES.get(gauge_key, {})
			var name: String = str(def.get("name", gauge_key))
			var pct: int = int(roundf((mod - 1.0) * 100))
			var sign: String = "+" if pct > 0 else ""
			parts.append("%s %s%d%%" % [name, sign, pct])
	if parts.is_empty():
		return "Aucun modificateur"
	return ", ".join(parts)


# =============================================================================
# FALLBACK EVENTS — Alternative paths when conditions aren't met
# =============================================================================

## Generate a fallback event for a biome the player can't access yet.
## Returns event data or empty dict if no fallback available.
func get_fallback_event(biome_key: String) -> Dictionary:
	var conditions_block = MerlinBiomeTree.BIOME_UNLOCK_CONDITIONS.get(biome_key)
	if conditions_block == null:
		return {}

	var conditions: Array = conditions_block.get("conditions", [])
	var gauges: Dictionary = get_gauges()

	# Find which conditions are failing and suggest relevant fallback
	for cond in conditions:
		if cond.has("gauge"):
			var gauge_key: String = str(cond["gauge"])
			if not _gauge_system.check_condition(gauges, cond):
				return _pick_fallback_for_gauge(gauge_key)

		if cond.has("item"):
			return FALLBACK_EVENTS.get("essence_trade", {}).duplicate()

		if cond.has("reputation"):
			return FALLBACK_EVENTS.get("druid_blessing", {}).duplicate()

	return FALLBACK_EVENTS.get("npc_encounter", {}).duplicate()


func _pick_fallback_for_gauge(gauge_key: String) -> Dictionary:
	match gauge_key:
		"esprit":
			return FALLBACK_EVENTS.get("druid_blessing", {}).duplicate()
		"vigueur":
			return FALLBACK_EVENTS.get("training_camp", {}).duplicate()
		"faveur":
			return FALLBACK_EVENTS.get("npc_encounter", {}).duplicate()
		"logique":
			return FALLBACK_EVENTS.get("druid_blessing", {}).duplicate()
		"ressources":
			return FALLBACK_EVENTS.get("essence_trade", {}).duplicate()
		_:
			return FALLBACK_EVENTS.get("npc_encounter", {}).duplicate()
