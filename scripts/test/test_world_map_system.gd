## =============================================================================
## Unit Tests — WorldMapSystem
## =============================================================================
## Tests: fallback events, gauge modifier text, pick_fallback_for_gauge,
## store-null defaults, sub-system delegation, FALLBACK_EVENTS structure.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


## Helper: create a WorldMapSystem instance (extends Node, no scene tree).
## Store will be null, so store-dependent methods return safe defaults.
func _make_system() -> Node:
	var sys: Node = load("res://scripts/autoload/world_map_system.gd").new()
	return sys


## Helper: cleanup node to avoid orphan warnings
func _free_system(sys: Node) -> void:
	sys.free()


# =============================================================================
# FALLBACK_EVENTS CONSTANT — structure validation
# =============================================================================

func test_fallback_events_has_four_entries() -> bool:
	var count: int = WorldMapSystem.FALLBACK_EVENTS.size()
	if count != 4:
		push_error("FALLBACK_EVENTS should have 4 entries, got %d" % count)
		return false
	return true


func test_fallback_events_keys() -> bool:
	var expected: Array = ["npc_encounter", "essence_trade", "druid_blessing", "training_camp"]
	for key in expected:
		if not WorldMapSystem.FALLBACK_EVENTS.has(key):
			push_error("FALLBACK_EVENTS missing key '%s'" % key)
			return false
	return true


func test_fallback_events_structure() -> bool:
	var required_fields: Array = ["type", "title", "description", "gauge_rewards"]
	for event_key in WorldMapSystem.FALLBACK_EVENTS:
		var event: Dictionary = WorldMapSystem.FALLBACK_EVENTS[event_key]
		for field in required_fields:
			if not event.has(field):
				push_error("FALLBACK_EVENTS['%s'] missing field '%s'" % [event_key, field])
				return false
	return true


func test_fallback_events_gauge_rewards_are_dicts() -> bool:
	for event_key in WorldMapSystem.FALLBACK_EVENTS:
		var event: Dictionary = WorldMapSystem.FALLBACK_EVENTS[event_key]
		var rewards = event.get("gauge_rewards")
		if not rewards is Dictionary:
			push_error("FALLBACK_EVENTS['%s'].gauge_rewards is not Dictionary" % event_key)
			return false
		if rewards.is_empty():
			push_error("FALLBACK_EVENTS['%s'].gauge_rewards is empty" % event_key)
			return false
	return true


func test_fallback_npc_encounter_type() -> bool:
	var event: Dictionary = WorldMapSystem.FALLBACK_EVENTS["npc_encounter"]
	if str(event["type"]) != "NPC":
		push_error("npc_encounter type: expected 'NPC', got '%s'" % event["type"])
		return false
	return true


func test_fallback_training_camp_rewards() -> bool:
	var event: Dictionary = WorldMapSystem.FALLBACK_EVENTS["training_camp"]
	var rewards: Dictionary = event["gauge_rewards"]
	if not rewards.has("vigueur"):
		push_error("training_camp gauge_rewards missing 'vigueur'")
		return false
	if int(rewards["vigueur"]) != 15:
		push_error("training_camp vigueur reward: expected 15, got %d" % int(rewards["vigueur"]))
		return false
	return true


# =============================================================================
# STORE-NULL DEFAULTS — safe behavior without scene tree
# =============================================================================

func test_get_map_state_no_store_returns_empty() -> bool:
	var sys: Node = _make_system()
	var result: Dictionary = sys.get_map_state()
	_free_system(sys)
	if not result.is_empty():
		push_error("get_map_state with no store should return {}, got %s" % str(result))
		return false
	return true


func test_get_gauges_no_store_returns_defaults() -> bool:
	var sys: Node = _make_system()
	var result: Dictionary = sys.get_gauges()
	_free_system(sys)
	# Should return build_default_gauges() from gauge_system
	if result.is_empty():
		push_error("get_gauges with no store should return default gauges, got empty")
		return false
	for key in MerlinGaugeSystem.GAUGE_KEYS:
		if not result.has(key):
			push_error("get_gauges default missing key '%s'" % key)
			return false
	return true


func test_get_gauge_no_store_returns_zero() -> bool:
	var sys: Node = _make_system()
	var result: int = sys.get_gauge("esprit")
	_free_system(sys)
	if result != 0:
		push_error("get_gauge with no store should return 0, got %d" % result)
		return false
	return true


func test_get_current_biome_no_store_returns_root() -> bool:
	var sys: Node = _make_system()
	var result: String = sys.get_current_biome()
	_free_system(sys)
	if result != MerlinBiomeTree.ROOT_BIOME:
		push_error("get_current_biome no store: expected '%s', got '%s'" % [MerlinBiomeTree.ROOT_BIOME, result])
		return false
	return true


func test_get_completed_biomes_no_store_returns_empty() -> bool:
	var sys: Node = _make_system()
	var result: Array = sys.get_completed_biomes()
	_free_system(sys)
	if not result.is_empty():
		push_error("get_completed_biomes no store: expected [], got %s" % str(result))
		return false
	return true


func test_is_biome_accessible_root_no_store() -> bool:
	var sys: Node = _make_system()
	var result: bool = sys.is_biome_accessible(MerlinBiomeTree.ROOT_BIOME)
	_free_system(sys)
	if not result:
		push_error("Root biome should always be accessible even without store")
		return false
	return true


func test_is_biome_accessible_non_root_no_store() -> bool:
	var sys: Node = _make_system()
	var result: bool = sys.is_biome_accessible("villages_celtes")
	_free_system(sys)
	# Without store, non-root biomes should not be accessible (returns biome_key == ROOT)
	if result:
		push_error("Non-root biome should not be accessible without store")
		return false
	return true


# =============================================================================
# GET_BIOME_MODIFIERS_TEXT — pure logic via _gauge_system
# =============================================================================

func test_biome_modifiers_text_no_modifiers() -> bool:
	var sys: Node = _make_system()
	var text: String = sys.get_biome_modifiers_text("unknown_biome")
	_free_system(sys)
	if text != "Aucun modificateur":
		push_error("Unknown biome modifiers text: expected 'Aucun modificateur', got '%s'" % text)
		return false
	return true


func test_biome_modifiers_text_foret() -> bool:
	var sys: Node = _make_system()
	var text: String = sys.get_biome_modifiers_text("foret_broceliande")
	_free_system(sys)
	# foret_broceliande has esprit +15%, vigueur -10%, ressources -15%
	if text.is_empty():
		push_error("foret_broceliande should have modifier text, got empty")
		return false
	if text.find("Esprit") == -1:
		push_error("foret modifiers should mention 'Esprit', got '%s'" % text)
		return false
	if text.find("+15%") == -1:
		push_error("foret modifiers should contain '+15%%', got '%s'" % text)
		return false
	return true


func test_biome_modifiers_text_villages_celtes() -> bool:
	var sys: Node = _make_system()
	var text: String = sys.get_biome_modifiers_text("villages_celtes")
	_free_system(sys)
	# villages_celtes has faveur +10%
	if text.find("Faveur") == -1:
		push_error("villages_celtes modifiers should mention 'Faveur', got '%s'" % text)
		return false
	if text.find("+10%") == -1:
		push_error("villages_celtes modifiers should contain '+10%%', got '%s'" % text)
		return false
	return true


# =============================================================================
# _PICK_FALLBACK_FOR_GAUGE — private but testable via get_fallback_event path
# =============================================================================

func test_pick_fallback_esprit_returns_druid_blessing() -> bool:
	var sys: Node = _make_system()
	var result: Dictionary = sys._pick_fallback_for_gauge("esprit")
	_free_system(sys)
	if str(result.get("type", "")) != "BLESSING":
		push_error("Fallback for esprit: expected BLESSING, got '%s'" % result.get("type", ""))
		return false
	return true


func test_pick_fallback_vigueur_returns_training() -> bool:
	var sys: Node = _make_system()
	var result: Dictionary = sys._pick_fallback_for_gauge("vigueur")
	_free_system(sys)
	if str(result.get("type", "")) != "TRAINING":
		push_error("Fallback for vigueur: expected TRAINING, got '%s'" % result.get("type", ""))
		return false
	return true


func test_pick_fallback_faveur_returns_npc() -> bool:
	var sys: Node = _make_system()
	var result: Dictionary = sys._pick_fallback_for_gauge("faveur")
	_free_system(sys)
	if str(result.get("type", "")) != "NPC":
		push_error("Fallback for faveur: expected NPC, got '%s'" % result.get("type", ""))
		return false
	return true


func test_pick_fallback_ressources_returns_trade() -> bool:
	var sys: Node = _make_system()
	var result: Dictionary = sys._pick_fallback_for_gauge("ressources")
	_free_system(sys)
	if str(result.get("type", "")) != "TRADE":
		push_error("Fallback for ressources: expected TRADE, got '%s'" % result.get("type", ""))
		return false
	return true


func test_pick_fallback_logique_returns_druid_blessing() -> bool:
	var sys: Node = _make_system()
	var result: Dictionary = sys._pick_fallback_for_gauge("logique")
	_free_system(sys)
	if str(result.get("type", "")) != "BLESSING":
		push_error("Fallback for logique: expected BLESSING, got '%s'" % result.get("type", ""))
		return false
	return true


func test_pick_fallback_unknown_returns_npc() -> bool:
	var sys: Node = _make_system()
	var result: Dictionary = sys._pick_fallback_for_gauge("unknown_gauge")
	_free_system(sys)
	if str(result.get("type", "")) != "NPC":
		push_error("Fallback for unknown: expected NPC, got '%s'" % result.get("type", ""))
		return false
	return true


func test_pick_fallback_returns_duplicate() -> bool:
	var sys: Node = _make_system()
	var result_a: Dictionary = sys._pick_fallback_for_gauge("esprit")
	var result_b: Dictionary = sys._pick_fallback_for_gauge("esprit")
	_free_system(sys)
	# Mutating one should not affect the other (duplicate check)
	result_a["type"] = "MUTATED"
	if str(result_b.get("type", "")) == "MUTATED":
		push_error("_pick_fallback_for_gauge should return duplicates, not references")
		return false
	return true


# =============================================================================
# GET_GAUGE_DISPLAYS — delegates to _gauge_system
# =============================================================================

func test_get_gauge_displays_returns_five() -> bool:
	var sys: Node = _make_system()
	var displays: Array = sys.get_gauge_displays()
	_free_system(sys)
	if displays.size() != 5:
		push_error("get_gauge_displays should return 5 entries, got %d" % displays.size())
		return false
	return true


func test_get_gauge_displays_has_required_keys() -> bool:
	var sys: Node = _make_system()
	var displays: Array = sys.get_gauge_displays()
	_free_system(sys)
	var required_fields: Array = ["key", "name", "icon", "color", "value", "max", "percent"]
	for display in displays:
		for field in required_fields:
			if not display.has(field):
				push_error("Gauge display missing field '%s'" % field)
				return false
	return true
