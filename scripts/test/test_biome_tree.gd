## =============================================================================
## Unit Tests — MerlinBiomeTree
## =============================================================================
## Tests: tree traversal, tier lookups, accessibility checks, condition
## evaluation (gauges, items, reputations, factions, karma, tier3 count),
## unlock hints, edge cases.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


# =============================================================================
# HELPERS
# =============================================================================

func _make_map_state(overrides: Dictionary = {}) -> Dictionary:
	var state: Dictionary = {
		"completed_biomes": [],
		"visited_biomes": [],
		"items_collected": [],
		"reputations": [],
		"tier_progress": {},
	}
	for key in overrides:
		state[key] = overrides[key]
	return state


func _make_gauges(overrides: Dictionary = {}) -> Dictionary:
	var gauges: Dictionary = {
		"esprit": 50,
		"vigueur": 50,
		"faveur": 50,
		"logique": 50,
		"ressources": 50,
	}
	for key in overrides:
		gauges[key] = overrides[key]
	return gauges


func _make_store(faction_overrides: Dictionary = {}, karma: int = 0) -> Dictionary:
	var factions: Dictionary = {
		"druides": 50.0,
		"anciens": 50.0,
		"korrigans": 50.0,
		"niamh": 50.0,
		"ankou": 50.0,
	}
	for key in faction_overrides:
		factions[key] = faction_overrides[key]
	return {
		"run": {
			"factions": factions,
			"hidden": {"karma": karma},
		},
	}


# =============================================================================
# CONSTANTS INTEGRITY
# =============================================================================

func test_biome_keys_count() -> bool:
	if MerlinBiomeTree.BIOME_KEYS.size() != 8:
		push_error("BIOME_KEYS should have 8 entries, got %d" % MerlinBiomeTree.BIOME_KEYS.size())
		return false
	return true


func test_root_biome_is_foret() -> bool:
	if MerlinBiomeTree.ROOT_BIOME != "foret_broceliande":
		push_error("ROOT_BIOME should be 'foret_broceliande', got '%s'" % MerlinBiomeTree.ROOT_BIOME)
		return false
	return true


func test_all_biome_keys_have_tiers() -> bool:
	for key in MerlinBiomeTree.BIOME_KEYS:
		if not MerlinBiomeTree.BIOME_TIERS.has(key):
			push_error("Biome '%s' missing from BIOME_TIERS" % key)
			return false
	return true


func test_all_biome_keys_have_names() -> bool:
	for key in MerlinBiomeTree.BIOME_KEYS:
		if not MerlinBiomeTree.BIOME_NAMES.has(key):
			push_error("Biome '%s' missing from BIOME_NAMES" % key)
			return false
	return true


func test_all_biome_keys_have_positions() -> bool:
	for key in MerlinBiomeTree.BIOME_KEYS:
		if not MerlinBiomeTree.BIOME_POSITIONS.has(key):
			push_error("Biome '%s' missing from BIOME_POSITIONS" % key)
			return false
	return true


func test_all_biome_keys_have_unlock_conditions() -> bool:
	for key in MerlinBiomeTree.BIOME_KEYS:
		if not MerlinBiomeTree.BIOME_UNLOCK_CONDITIONS.has(key):
			push_error("Biome '%s' missing from BIOME_UNLOCK_CONDITIONS" % key)
			return false
	return true


# =============================================================================
# TREE TRAVERSAL — get_children
# =============================================================================

func test_get_children_root() -> bool:
	var tree := MerlinBiomeTree.new()
	var children: Array = tree.get_children("foret_broceliande")
	if children.size() != 2:
		push_error("Root should have 2 children, got %d" % children.size())
		return false
	if "villages_celtes" not in children:
		push_error("Root children should include 'villages_celtes'")
		return false
	if "cotes_sauvages" not in children:
		push_error("Root children should include 'cotes_sauvages'")
		return false
	return true


func test_get_children_leaf() -> bool:
	var tree := MerlinBiomeTree.new()
	var children: Array = tree.get_children("iles_mystiques")
	if children.size() != 0:
		push_error("iles_mystiques should have 0 children, got %d" % children.size())
		return false
	return true


func test_get_children_collines_has_one_child() -> bool:
	var tree := MerlinBiomeTree.new()
	var children: Array = tree.get_children("collines_dolmens")
	if children.size() != 1:
		push_error("collines_dolmens should have 1 child, got %d" % children.size())
		return false
	if str(children[0]) != "iles_mystiques":
		push_error("collines_dolmens child should be 'iles_mystiques', got '%s'" % str(children[0]))
		return false
	return true


func test_get_children_unknown_biome() -> bool:
	var tree := MerlinBiomeTree.new()
	var children: Array = tree.get_children("biome_inexistant")
	if children.size() != 0:
		push_error("Unknown biome should have 0 children, got %d" % children.size())
		return false
	return true


# =============================================================================
# TREE TRAVERSAL — get_parents
# =============================================================================

func test_get_parents_root_has_none() -> bool:
	var tree := MerlinBiomeTree.new()
	var parents: Array = tree.get_parents("foret_broceliande")
	if parents.size() != 0:
		push_error("Root should have 0 parents, got %d" % parents.size())
		return false
	return true


func test_get_parents_collines_has_three() -> bool:
	var tree := MerlinBiomeTree.new()
	var parents: Array = tree.get_parents("collines_dolmens")
	if parents.size() != 3:
		push_error("collines_dolmens should have 3 parents, got %d" % parents.size())
		return false
	if "landes_bruyere" not in parents:
		push_error("collines_dolmens parents should include 'landes_bruyere'")
		return false
	if "marais_korrigans" not in parents:
		push_error("collines_dolmens parents should include 'marais_korrigans'")
		return false
	if "cercles_pierres" not in parents:
		push_error("collines_dolmens parents should include 'cercles_pierres'")
		return false
	return true


# =============================================================================
# TIER LOOKUPS
# =============================================================================

func test_get_tier_root() -> bool:
	var tree := MerlinBiomeTree.new()
	var tier: int = tree.get_tier("foret_broceliande")
	if tier != 1:
		push_error("foret_broceliande tier should be 1, got %d" % tier)
		return false
	return true


func test_get_tier_unknown_returns_zero() -> bool:
	var tree := MerlinBiomeTree.new()
	var tier: int = tree.get_tier("biome_inexistant")
	if tier != 0:
		push_error("Unknown biome tier should be 0, got %d" % tier)
		return false
	return true


func test_get_biomes_at_tier_3() -> bool:
	var tree := MerlinBiomeTree.new()
	var tier3: Array = tree.get_biomes_at_tier(3)
	if tier3.size() != 3:
		push_error("Tier 3 should have 3 biomes, got %d" % tier3.size())
		return false
	if "landes_bruyere" not in tier3:
		push_error("Tier 3 should include 'landes_bruyere'")
		return false
	if "marais_korrigans" not in tier3:
		push_error("Tier 3 should include 'marais_korrigans'")
		return false
	if "cercles_pierres" not in tier3:
		push_error("Tier 3 should include 'cercles_pierres'")
		return false
	return true


func test_get_biomes_at_tier_nonexistent() -> bool:
	var tree := MerlinBiomeTree.new()
	var tier99: Array = tree.get_biomes_at_tier(99)
	if tier99.size() != 0:
		push_error("Tier 99 should have 0 biomes, got %d" % tier99.size())
		return false
	return true


# =============================================================================
# ACCESSIBILITY — Root biome
# =============================================================================

func test_root_always_accessible() -> bool:
	var tree := MerlinBiomeTree.new()
	var result: bool = tree.is_biome_accessible("foret_broceliande", _make_map_state(), _make_gauges(), _make_store())
	if not result:
		push_error("Root biome should always be accessible")
		return false
	return true


# =============================================================================
# ACCESSIBILITY — OR logic (villages_celtes: faveur >= 50 OR druides >= 50)
# =============================================================================

func test_villages_celtes_accessible_via_gauge() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({"completed_biomes": ["foret_broceliande"]})
	var gauges: Dictionary = _make_gauges({"faveur": 50})
	var result: bool = tree.is_biome_accessible("villages_celtes", map_state, gauges, _make_store({"druides": 0.0}))
	if not result:
		push_error("villages_celtes should be accessible with faveur >= 50")
		return false
	return true


func test_villages_celtes_accessible_via_faction() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({"completed_biomes": ["foret_broceliande"]})
	var gauges: Dictionary = _make_gauges({"faveur": 0})
	var result: bool = tree.is_biome_accessible("villages_celtes", map_state, gauges, _make_store({"druides": 50.0}))
	if not result:
		push_error("villages_celtes should be accessible with druides rep >= 50")
		return false
	return true


func test_villages_celtes_blocked_without_parent() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state()
	var gauges: Dictionary = _make_gauges({"faveur": 100})
	var result: bool = tree.is_biome_accessible("villages_celtes", map_state, gauges, _make_store({"druides": 100.0}))
	if result:
		push_error("villages_celtes should be blocked without foret_broceliande completed")
		return false
	return true


# =============================================================================
# ACCESSIBILITY — OR logic with item (cotes_sauvages: ressources < 50 OR item)
# =============================================================================

func test_cotes_sauvages_accessible_via_low_ressources() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({"completed_biomes": ["foret_broceliande"]})
	var gauges: Dictionary = _make_gauges({"ressources": 30})
	var result: bool = tree.is_biome_accessible("cotes_sauvages", map_state, gauges, _make_store())
	if not result:
		push_error("cotes_sauvages should be accessible with ressources < 50")
		return false
	return true


func test_cotes_sauvages_accessible_via_item() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": ["foret_broceliande"],
		"items_collected": ["bois_construction"],
	})
	var gauges: Dictionary = _make_gauges({"ressources": 80})
	var result: bool = tree.is_biome_accessible("cotes_sauvages", map_state, gauges, _make_store())
	if not result:
		push_error("cotes_sauvages should be accessible with bois_construction item")
		return false
	return true


func test_cotes_sauvages_blocked_high_ressources_no_item() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({"completed_biomes": ["foret_broceliande"]})
	var gauges: Dictionary = _make_gauges({"ressources": 80})
	var result: bool = tree.is_biome_accessible("cotes_sauvages", map_state, gauges, _make_store())
	if result:
		push_error("cotes_sauvages should be blocked with high ressources and no item")
		return false
	return true


# =============================================================================
# ACCESSIBILITY — AND logic (landes_bruyere: vigueur >= 75 AND item)
# =============================================================================

func test_landes_bruyere_accessible_all_conditions() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": ["foret_broceliande", "cotes_sauvages"],
		"items_collected": ["essences_bruyere"],
	})
	var gauges: Dictionary = _make_gauges({"vigueur": 75})
	var result: bool = tree.is_biome_accessible("landes_bruyere", map_state, gauges, _make_store())
	if not result:
		push_error("landes_bruyere should be accessible with vigueur >= 75 and item")
		return false
	return true


func test_landes_bruyere_blocked_missing_item() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": ["foret_broceliande", "cotes_sauvages"],
	})
	var gauges: Dictionary = _make_gauges({"vigueur": 80})
	var result: bool = tree.is_biome_accessible("landes_bruyere", map_state, gauges, _make_store())
	if result:
		push_error("landes_bruyere should be blocked without essences_bruyere item")
		return false
	return true


func test_landes_bruyere_blocked_low_vigueur() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": ["foret_broceliande", "cotes_sauvages"],
		"items_collected": ["essences_bruyere"],
	})
	var gauges: Dictionary = _make_gauges({"vigueur": 50})
	var result: bool = tree.is_biome_accessible("landes_bruyere", map_state, gauges, _make_store())
	if result:
		push_error("landes_bruyere should be blocked with vigueur < 75")
		return false
	return true


# =============================================================================
# ACCESSIBILITY — AND with reputation (cercles_pierres: esprit >= 70 AND rep)
# =============================================================================

func test_cercles_pierres_accessible() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": ["foret_broceliande", "villages_celtes"],
		"reputations": ["druide"],
	})
	var gauges: Dictionary = _make_gauges({"esprit": 70})
	var result: bool = tree.is_biome_accessible("cercles_pierres", map_state, gauges, _make_store())
	if not result:
		push_error("cercles_pierres should be accessible with esprit >= 70 and druide rep")
		return false
	return true


func test_cercles_pierres_blocked_no_reputation() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": ["foret_broceliande", "villages_celtes"],
	})
	var gauges: Dictionary = _make_gauges({"esprit": 80})
	var result: bool = tree.is_biome_accessible("cercles_pierres", map_state, gauges, _make_store())
	if result:
		push_error("cercles_pierres should be blocked without druide reputation")
		return false
	return true


# =============================================================================
# ACCESSIBILITY — collines_dolmens (any tier-3 parent + tier3 count + karma)
# =============================================================================

func test_collines_accessible_with_tier3_and_karma() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": ["foret_broceliande", "cotes_sauvages", "landes_bruyere"],
	})
	var gauges: Dictionary = _make_gauges()
	var store: Dictionary = _make_store({}, 5)
	var result: bool = tree.is_biome_accessible("collines_dolmens", map_state, gauges, store)
	if not result:
		push_error("collines_dolmens should be accessible with 1 tier-3 completed and positive karma")
		return false
	return true


func test_collines_blocked_no_tier3_parent_completed() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": ["foret_broceliande", "cotes_sauvages"],
	})
	var store: Dictionary = _make_store({}, 5)
	var result: bool = tree.is_biome_accessible("collines_dolmens", map_state, _make_gauges(), store)
	if result:
		push_error("collines_dolmens should be blocked without any tier-3 parent completed")
		return false
	return true


func test_collines_blocked_negative_karma() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": ["foret_broceliande", "cotes_sauvages", "landes_bruyere"],
	})
	var store: Dictionary = _make_store({}, -3)
	var result: bool = tree.is_biome_accessible("collines_dolmens", map_state, _make_gauges(), store)
	if result:
		push_error("collines_dolmens should be blocked with negative karma")
		return false
	return true


# =============================================================================
# ACCESSIBILITY — iles_mystiques (3 tier-3 + niamh >= 50)
# =============================================================================

func test_iles_mystiques_accessible() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": [
			"foret_broceliande", "cotes_sauvages", "villages_celtes",
			"landes_bruyere", "marais_korrigans", "cercles_pierres",
			"collines_dolmens",
		],
	})
	var store: Dictionary = _make_store({"niamh": 60.0}, 5)
	var result: bool = tree.is_biome_accessible("iles_mystiques", map_state, _make_gauges(), store)
	if not result:
		push_error("iles_mystiques should be accessible with 3 tier-3 and niamh >= 50")
		return false
	return true


func test_iles_mystiques_blocked_low_niamh() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": [
			"foret_broceliande", "cotes_sauvages", "villages_celtes",
			"landes_bruyere", "marais_korrigans", "cercles_pierres",
			"collines_dolmens",
		],
	})
	var store: Dictionary = _make_store({"niamh": 30.0})
	var result: bool = tree.is_biome_accessible("iles_mystiques", map_state, _make_gauges(), store)
	if result:
		push_error("iles_mystiques should be blocked with niamh < 50")
		return false
	return true


# =============================================================================
# COMPLETED TIER-3 COUNT
# =============================================================================

func test_completed_tier3_count_zero() -> bool:
	var tree := MerlinBiomeTree.new()
	var count: int = tree.get_completed_tier3_count(_make_map_state())
	if count != 0:
		push_error("Tier-3 count should be 0 with empty completed, got %d" % count)
		return false
	return true


func test_completed_tier3_count_partial() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": ["foret_broceliande", "landes_bruyere", "marais_korrigans"],
	})
	var count: int = tree.get_completed_tier3_count(map_state)
	if count != 2:
		push_error("Tier-3 count should be 2, got %d" % count)
		return false
	return true


func test_completed_tier3_count_all() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({
		"completed_biomes": ["landes_bruyere", "marais_korrigans", "cercles_pierres"],
	})
	var count: int = tree.get_completed_tier3_count(map_state)
	if count != 3:
		push_error("Tier-3 count should be 3, got %d" % count)
		return false
	return true


# =============================================================================
# UNLOCK HINTS
# =============================================================================

func test_unlock_hint_root_accessible() -> bool:
	var tree := MerlinBiomeTree.new()
	var hint: String = tree.get_unlock_hint("foret_broceliande", _make_gauges(), _make_map_state(), _make_store())
	if hint != "Accessible":
		push_error("Root hint should be 'Accessible', got '%s'" % hint)
		return false
	return true


func test_unlock_hint_parent_not_completed() -> bool:
	var tree := MerlinBiomeTree.new()
	var hint: String = tree.get_unlock_hint("villages_celtes", _make_gauges(), _make_map_state(), _make_store())
	if hint.find("Completer") == -1:
		push_error("Hint should mention 'Completer' when parent not done, got '%s'" % hint)
		return false
	if hint.find("Broceliande") == -1:
		push_error("Hint should mention parent name, got '%s'" % hint)
		return false
	return true


func test_unlock_hint_shows_conditions_when_parent_done() -> bool:
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({"completed_biomes": ["foret_broceliande"]})
	var hint: String = tree.get_unlock_hint("villages_celtes", _make_gauges(), map_state, _make_store())
	if hint.find("Faveur") == -1 and hint.find("druides") == -1:
		push_error("Hint should describe conditions when parent done, got '%s'" % hint)
		return false
	return true


# =============================================================================
# EDGE CASES
# =============================================================================

func test_accessibility_empty_map_state() -> bool:
	var tree := MerlinBiomeTree.new()
	# Only root should be accessible with empty state
	var root_ok: bool = tree.is_biome_accessible("foret_broceliande", {}, {}, {})
	if not root_ok:
		push_error("Root should be accessible even with empty state")
		return false
	var villages_ok: bool = tree.is_biome_accessible("villages_celtes", {}, {}, {})
	if villages_ok:
		push_error("villages_celtes should NOT be accessible with empty state")
		return false
	return true


func test_cotes_sauvages_boundary_ressources_50() -> bool:
	# ressources < 50 is the condition; exactly 50 should NOT satisfy it
	var tree := MerlinBiomeTree.new()
	var map_state: Dictionary = _make_map_state({"completed_biomes": ["foret_broceliande"]})
	var gauges: Dictionary = _make_gauges({"ressources": 50})
	var result: bool = tree.is_biome_accessible("cotes_sauvages", map_state, gauges, _make_store())
	if result:
		push_error("cotes_sauvages: ressources == 50 should NOT satisfy < 50 condition")
		return false
	return true
