## =============================================================================
## test_biome_tree.gd — Unit tests for MerlinBiomeTree
## =============================================================================
## Rules: extends RefCounted, NO class_name, NO assert(), NO await
## All public test functions follow: func test_xxx() -> bool
## Failures emit push_error() via _fail() before returning false.
## Instance shared via _init() to avoid repeated .new() allocations.
## =============================================================================

extends RefCounted

var _tree: MerlinBiomeTree

func _init() -> void:
	_tree = MerlinBiomeTree.new()


func _fail(msg: String) -> bool:
	push_error(msg)
	return false


# =============================================================================
# HELPERS — minimal, immutable state builders
# =============================================================================

## Build a full gauges dict with sane defaults. Pass overrides as needed.
func _make_gauges(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {
		"esprit": 50,
		"vigueur": 50,
		"faveur": 50,
		"logique": 50,
		"ressources": 50,
	}
	for k in overrides:
		base[k] = overrides[k]
	return base


## Build a map_state dict. Overrides replace individual keys.
func _make_map_state(overrides: Dictionary = {}) -> Dictionary:
	var base: Dictionary = {
		"completed_biomes": [],
		"visited_biomes": [],
		"items_collected": [],
		"reputations": [],
		"tier_progress": {},
	}
	for k in overrides:
		base[k] = overrides[k]
	return base


## Build a store dict with faction reps and karma.
## faction_overrides replaces individual faction values.
func _make_store(faction_overrides: Dictionary = {}, karma: int = 0) -> Dictionary:
	var factions: Dictionary = {
		"druides": 50.0,
		"anciens": 50.0,
		"korrigans": 50.0,
		"niamh": 50.0,
		"ankou": 50.0,
	}
	for k in faction_overrides:
		factions[k] = faction_overrides[k]
	return {
		"run": {
			"factions": factions,
			"hidden": {"karma": karma},
		},
	}


# =============================================================================
# 1. CONSTANTS INTEGRITY
# =============================================================================

func test_root_biome_constant() -> bool:
	if MerlinBiomeTree.ROOT_BIOME != "foret_broceliande":
		return _fail("ROOT_BIOME expected 'foret_broceliande', got '%s'" % MerlinBiomeTree.ROOT_BIOME)
	return true


func test_biome_keys_count_is_eight() -> bool:
	if MerlinBiomeTree.BIOME_KEYS.size() != 8:
		return _fail("BIOME_KEYS should have 8 entries, got %d" % MerlinBiomeTree.BIOME_KEYS.size())
	return true


func test_biome_keys_contains_all_expected() -> bool:
	var expected: Array = [
		"foret_broceliande", "villages_celtes", "cotes_sauvages",
		"landes_bruyere", "marais_korrigans", "cercles_pierres",
		"collines_dolmens", "iles_mystiques",
	]
	for key in expected:
		if not key in MerlinBiomeTree.BIOME_KEYS:
			return _fail("BIOME_KEYS missing: '%s'" % key)
	return true


func test_all_biome_keys_have_tier_entry() -> bool:
	for key in MerlinBiomeTree.BIOME_KEYS:
		if not MerlinBiomeTree.BIOME_TIERS.has(key):
			return _fail("BIOME_TIERS missing entry for '%s'" % key)
	return true


func test_all_biome_keys_have_name_entry() -> bool:
	for key in MerlinBiomeTree.BIOME_KEYS:
		if not MerlinBiomeTree.BIOME_NAMES.has(key):
			return _fail("BIOME_NAMES missing entry for '%s'" % key)
	return true


func test_all_biome_names_are_non_empty() -> bool:
	for key in MerlinBiomeTree.BIOME_KEYS:
		var name_val: String = str(MerlinBiomeTree.BIOME_NAMES.get(key, ""))
		if name_val.is_empty():
			return _fail("BIOME_NAMES['%s'] is empty" % key)
	return true


func test_all_biome_keys_have_position_entry() -> bool:
	for key in MerlinBiomeTree.BIOME_KEYS:
		if not MerlinBiomeTree.BIOME_POSITIONS.has(key):
			return _fail("BIOME_POSITIONS missing entry for '%s'" % key)
	return true


func test_biome_positions_normalized_0_to_1() -> bool:
	for key in MerlinBiomeTree.BIOME_KEYS:
		var pos: Vector2 = MerlinBiomeTree.BIOME_POSITIONS.get(key, Vector2.ZERO)
		if pos.x < 0.0 or pos.x > 1.0:
			return _fail("BIOME_POSITIONS['%s'].x out of [0,1]: %f" % [key, pos.x])
		if pos.y < 0.0 or pos.y > 1.0:
			return _fail("BIOME_POSITIONS['%s'].y out of [0,1]: %f" % [key, pos.y])
	return true


func test_all_biome_keys_have_unlock_condition_entry() -> bool:
	for key in MerlinBiomeTree.BIOME_KEYS:
		if not MerlinBiomeTree.BIOME_UNLOCK_CONDITIONS.has(key):
			return _fail("BIOME_UNLOCK_CONDITIONS missing entry for '%s'" % key)
	return true


func test_biome_tree_edges_not_empty() -> bool:
	if MerlinBiomeTree.BIOME_TREE_EDGES.is_empty():
		return _fail("BIOME_TREE_EDGES must not be empty")
	return true


# =============================================================================
# 2. EDGE STRUCTURAL INTEGRITY
# =============================================================================

func test_edge_endpoints_are_valid_biome_keys() -> bool:
	for edge in MerlinBiomeTree.BIOME_TREE_EDGES:
		var from_key: String = str(edge["from"])
		var to_key: String = str(edge["to"])
		if not from_key in MerlinBiomeTree.BIOME_KEYS:
			return _fail("Edge 'from' not in BIOME_KEYS: '%s'" % from_key)
		if not to_key in MerlinBiomeTree.BIOME_KEYS:
			return _fail("Edge 'to' not in BIOME_KEYS: '%s'" % to_key)
	return true


func test_edges_have_no_self_loops() -> bool:
	for edge in MerlinBiomeTree.BIOME_TREE_EDGES:
		if str(edge["from"]) == str(edge["to"]):
			return _fail("Self-loop detected in edges: '%s'" % str(edge["from"]))
	return true


func test_edges_respect_tier_ordering() -> bool:
	for edge in MerlinBiomeTree.BIOME_TREE_EDGES:
		var from_tier: int = _tree.get_tier(str(edge["from"]))
		var to_tier: int = _tree.get_tier(str(edge["to"]))
		if from_tier >= to_tier:
			return _fail("Edge goes from tier %d to tier %d: '%s' -> '%s'" % [
				from_tier, to_tier, str(edge["from"]), str(edge["to"])
			])
	return true


# =============================================================================
# 3. TIER LOOKUPS
# =============================================================================

func test_get_tier_root_is_1() -> bool:
	var tier: int = _tree.get_tier("foret_broceliande")
	if tier != 1:
		return _fail("foret_broceliande should be tier 1, got %d" % tier)
	return true


func test_get_tier_villages_celtes_is_2() -> bool:
	if _tree.get_tier("villages_celtes") != 2:
		return _fail("villages_celtes should be tier 2")
	return true


func test_get_tier_cotes_sauvages_is_2() -> bool:
	if _tree.get_tier("cotes_sauvages") != 2:
		return _fail("cotes_sauvages should be tier 2")
	return true


func test_get_tier_landes_bruyere_is_3() -> bool:
	if _tree.get_tier("landes_bruyere") != 3:
		return _fail("landes_bruyere should be tier 3")
	return true


func test_get_tier_collines_dolmens_is_4() -> bool:
	if _tree.get_tier("collines_dolmens") != 4:
		return _fail("collines_dolmens should be tier 4")
	return true


func test_get_tier_iles_mystiques_is_5() -> bool:
	if _tree.get_tier("iles_mystiques") != 5:
		return _fail("iles_mystiques should be tier 5")
	return true


func test_get_tier_unknown_returns_0() -> bool:
	if _tree.get_tier("does_not_exist") != 0:
		return _fail("Unknown biome should return tier 0")
	return true


func test_get_biomes_at_tier_2_has_two_entries() -> bool:
	var t2: Array = _tree.get_biomes_at_tier(2)
	if t2.size() != 2:
		return _fail("Tier 2 should have 2 biomes, got %d" % t2.size())
	return true


func test_get_biomes_at_tier_3_has_three_entries() -> bool:
	var t3: Array = _tree.get_biomes_at_tier(3)
	if t3.size() != 3:
		return _fail("Tier 3 should have 3 biomes, got %d" % t3.size())
	if not "landes_bruyere" in t3:
		return _fail("Tier 3 missing 'landes_bruyere'")
	if not "marais_korrigans" in t3:
		return _fail("Tier 3 missing 'marais_korrigans'")
	if not "cercles_pierres" in t3:
		return _fail("Tier 3 missing 'cercles_pierres'")
	return true


func test_get_biomes_at_nonexistent_tier_returns_empty() -> bool:
	if not _tree.get_biomes_at_tier(99).is_empty():
		return _fail("Tier 99 should yield an empty array")
	return true


# =============================================================================
# 4. TREE TRAVERSAL
# =============================================================================

func test_get_children_root_has_two() -> bool:
	var children: Array = _tree.get_children("foret_broceliande")
	if children.size() != 2:
		return _fail("Root should have 2 children, got %d" % children.size())
	if not "villages_celtes" in children:
		return _fail("Root children missing 'villages_celtes'")
	if not "cotes_sauvages" in children:
		return _fail("Root children missing 'cotes_sauvages'")
	return true


func test_get_children_leaf_is_empty() -> bool:
	if not _tree.get_children("iles_mystiques").is_empty():
		return _fail("iles_mystiques (leaf) should have no children")
	return true


func test_get_children_collines_has_one_child() -> bool:
	var children: Array = _tree.get_children("collines_dolmens")
	if children.size() != 1:
		return _fail("collines_dolmens should have 1 child, got %d" % children.size())
	if str(children[0]) != "iles_mystiques":
		return _fail("collines_dolmens child should be 'iles_mystiques', got '%s'" % str(children[0]))
	return true


func test_get_children_unknown_biome_is_empty() -> bool:
	if not _tree.get_children("nonexistent").is_empty():
		return _fail("Unknown biome should return empty children")
	return true


func test_get_parents_root_is_empty() -> bool:
	if not _tree.get_parents("foret_broceliande").is_empty():
		return _fail("Root biome should have no parents")
	return true


func test_get_parents_collines_has_three() -> bool:
	var parents: Array = _tree.get_parents("collines_dolmens")
	if parents.size() != 3:
		return _fail("collines_dolmens should have 3 parents, got %d" % parents.size())
	for expected_parent in ["landes_bruyere", "marais_korrigans", "cercles_pierres"]:
		if not expected_parent in parents:
			return _fail("collines_dolmens parents missing '%s'" % expected_parent)
	return true


func test_get_parents_iles_mystiques_single() -> bool:
	var parents: Array = _tree.get_parents("iles_mystiques")
	if parents.size() != 1:
		return _fail("iles_mystiques should have 1 parent, got %d" % parents.size())
	if str(parents[0]) != "collines_dolmens":
		return _fail("iles_mystiques parent should be 'collines_dolmens', got '%s'" % str(parents[0]))
	return true


# =============================================================================
# 5. ACCESSIBILITY — root
# =============================================================================

func test_root_always_accessible() -> bool:
	if not _tree.is_biome_accessible("foret_broceliande", _make_map_state(), _make_gauges(), _make_store()):
		return _fail("Root biome should always be accessible")
	return true


func test_root_accessible_with_fully_empty_state() -> bool:
	if not _tree.is_biome_accessible("foret_broceliande", {}, {}, {}):
		return _fail("Root should be accessible even with fully empty state dicts")
	return true


# =============================================================================
# 6. ACCESSIBILITY — villages_celtes (OR: faveur >= 50 OR druides >= 50)
# =============================================================================

func test_villages_celtes_blocked_without_parent_completed() -> bool:
	# Even with perfect gauges and faction, parent not done means blocked
	var result: bool = _tree.is_biome_accessible(
		"villages_celtes",
		_make_map_state(),
		_make_gauges({"faveur": 100}),
		_make_store({"druides": 100.0})
	)
	if result:
		return _fail("villages_celtes should be blocked without foret_broceliande completed")
	return true


func test_villages_celtes_accessible_via_gauge_faveur() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"villages_celtes",
		_make_map_state({"completed_biomes": ["foret_broceliande"]}),
		_make_gauges({"faveur": 50}),
		_make_store({"druides": 0.0})
	)
	if not result:
		return _fail("villages_celtes should be accessible with faveur=50")
	return true


func test_villages_celtes_blocked_faveur_49() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"villages_celtes",
		_make_map_state({"completed_biomes": ["foret_broceliande"]}),
		_make_gauges({"faveur": 49}),
		_make_store({"druides": 0.0})
	)
	if result:
		return _fail("villages_celtes should be blocked with faveur=49 and druides=0")
	return true


func test_villages_celtes_accessible_via_druides_faction() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"villages_celtes",
		_make_map_state({"completed_biomes": ["foret_broceliande"]}),
		_make_gauges({"faveur": 0}),
		_make_store({"druides": 50.0})
	)
	if not result:
		return _fail("villages_celtes should be accessible with druides rep=50")
	return true


# =============================================================================
# 7. ACCESSIBILITY — cotes_sauvages (OR: ressources < 50 OR item bois_construction)
# =============================================================================

func test_cotes_sauvages_accessible_via_low_ressources() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"cotes_sauvages",
		_make_map_state({"completed_biomes": ["foret_broceliande"]}),
		_make_gauges({"ressources": 30}),
		_make_store()
	)
	if not result:
		return _fail("cotes_sauvages should be accessible with ressources=30 (< 50)")
	return true


func test_cotes_sauvages_boundary_ressources_50_not_satisfied() -> bool:
	# Condition is < 50 strictly; ressources == 50 should NOT satisfy it
	var result: bool = _tree.is_biome_accessible(
		"cotes_sauvages",
		_make_map_state({"completed_biomes": ["foret_broceliande"]}),
		_make_gauges({"ressources": 50}),
		_make_store()
	)
	if result:
		return _fail("cotes_sauvages: ressources=50 should NOT satisfy strict < 50")
	return true


func test_cotes_sauvages_accessible_via_item() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"cotes_sauvages",
		_make_map_state({"completed_biomes": ["foret_broceliande"], "items_collected": ["bois_construction"]}),
		_make_gauges({"ressources": 80}),
		_make_store()
	)
	if not result:
		return _fail("cotes_sauvages should be accessible with bois_construction item")
	return true


func test_cotes_sauvages_blocked_high_ressources_no_item() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"cotes_sauvages",
		_make_map_state({"completed_biomes": ["foret_broceliande"]}),
		_make_gauges({"ressources": 80}),
		_make_store()
	)
	if result:
		return _fail("cotes_sauvages should be blocked with ressources=80 and no item")
	return true


# =============================================================================
# 8. ACCESSIBILITY — landes_bruyere (AND: vigueur >= 75 AND item essences_bruyere)
# =============================================================================

func test_landes_bruyere_accessible_both_conditions() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"landes_bruyere",
		_make_map_state({
			"completed_biomes": ["foret_broceliande", "cotes_sauvages"],
			"items_collected": ["essences_bruyere"],
		}),
		_make_gauges({"vigueur": 75}),
		_make_store()
	)
	if not result:
		return _fail("landes_bruyere should be accessible with vigueur=75 AND essences_bruyere")
	return true


func test_landes_bruyere_blocked_missing_item() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"landes_bruyere",
		_make_map_state({"completed_biomes": ["foret_broceliande", "cotes_sauvages"]}),
		_make_gauges({"vigueur": 80}),
		_make_store()
	)
	if result:
		return _fail("landes_bruyere should be blocked without essences_bruyere item")
	return true


func test_landes_bruyere_blocked_low_vigueur() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"landes_bruyere",
		_make_map_state({
			"completed_biomes": ["foret_broceliande", "cotes_sauvages"],
			"items_collected": ["essences_bruyere"],
		}),
		_make_gauges({"vigueur": 74}),
		_make_store()
	)
	if result:
		return _fail("landes_bruyere should be blocked with vigueur=74 (< 75)")
	return true


func test_landes_bruyere_blocked_without_cotes_parent() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"landes_bruyere",
		_make_map_state({
			"completed_biomes": ["foret_broceliande"],
			"items_collected": ["essences_bruyere"],
		}),
		_make_gauges({"vigueur": 80}),
		_make_store()
	)
	if result:
		return _fail("landes_bruyere should be blocked without cotes_sauvages completed")
	return true


# =============================================================================
# 9. ACCESSIBILITY — marais_korrigans (OR: logique >= 60 OR amulette_marais)
# =============================================================================

func test_marais_korrigans_accessible_via_logique() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"marais_korrigans",
		_make_map_state({"completed_biomes": ["foret_broceliande", "cotes_sauvages"]}),
		_make_gauges({"logique": 60}),
		_make_store()
	)
	if not result:
		return _fail("marais_korrigans should be accessible with logique=60")
	return true


func test_marais_korrigans_accessible_via_amulette() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"marais_korrigans",
		_make_map_state({
			"completed_biomes": ["foret_broceliande", "cotes_sauvages"],
			"items_collected": ["amulette_marais"],
		}),
		_make_gauges({"logique": 0}),
		_make_store()
	)
	if not result:
		return _fail("marais_korrigans should be accessible with amulette_marais item")
	return true


# =============================================================================
# 10. ACCESSIBILITY — cercles_pierres (AND: esprit >= 70 AND reputation druide)
# =============================================================================

func test_cercles_pierres_accessible_both_conditions() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"cercles_pierres",
		_make_map_state({
			"completed_biomes": ["foret_broceliande", "villages_celtes"],
			"reputations": ["druide"],
		}),
		_make_gauges({"esprit": 70}),
		_make_store()
	)
	if not result:
		return _fail("cercles_pierres should be accessible with esprit=70 AND druide reputation")
	return true


func test_cercles_pierres_blocked_no_reputation() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"cercles_pierres",
		_make_map_state({"completed_biomes": ["foret_broceliande", "villages_celtes"]}),
		_make_gauges({"esprit": 80}),
		_make_store()
	)
	if result:
		return _fail("cercles_pierres should be blocked without 'druide' reputation")
	return true


func test_cercles_pierres_blocked_low_esprit() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"cercles_pierres",
		_make_map_state({
			"completed_biomes": ["foret_broceliande", "villages_celtes"],
			"reputations": ["druide"],
		}),
		_make_gauges({"esprit": 69}),
		_make_store()
	)
	if result:
		return _fail("cercles_pierres should be blocked with esprit=69 (< 70)")
	return true


# =============================================================================
# 11. ACCESSIBILITY — collines_dolmens (AND: any tier-3 parent + completed_tier3 >= 1 + karma > 0)
# =============================================================================

func test_collines_accessible_one_tier3_positive_karma() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"collines_dolmens",
		_make_map_state({"completed_biomes": ["foret_broceliande", "cotes_sauvages", "landes_bruyere"]}),
		_make_gauges(),
		_make_store({}, 1)
	)
	if not result:
		return _fail("collines_dolmens should be accessible with 1 tier-3 completed and karma=1")
	return true


func test_collines_blocked_no_tier3_parent() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"collines_dolmens",
		_make_map_state({"completed_biomes": ["foret_broceliande", "cotes_sauvages"]}),
		_make_gauges(),
		_make_store({}, 5)
	)
	if result:
		return _fail("collines_dolmens should be blocked when no tier-3 parent is completed")
	return true


func test_collines_blocked_negative_karma() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"collines_dolmens",
		_make_map_state({"completed_biomes": ["foret_broceliande", "cotes_sauvages", "landes_bruyere"]}),
		_make_gauges(),
		_make_store({}, -1)
	)
	if result:
		return _fail("collines_dolmens should be blocked with negative karma")
	return true


func test_collines_blocked_zero_karma() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"collines_dolmens",
		_make_map_state({"completed_biomes": ["foret_broceliande", "cotes_sauvages", "landes_bruyere"]}),
		_make_gauges(),
		_make_store({}, 0)
	)
	if result:
		return _fail("collines_dolmens should be blocked with karma=0 (condition requires > 0)")
	return true


# =============================================================================
# 12. ACCESSIBILITY — iles_mystiques (AND: collines done + completed_tier3 >= 3 + niamh >= 50)
# =============================================================================

func test_iles_mystiques_accessible_full_conditions() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"iles_mystiques",
		_make_map_state({"completed_biomes": [
			"foret_broceliande", "cotes_sauvages", "villages_celtes",
			"landes_bruyere", "marais_korrigans", "cercles_pierres",
			"collines_dolmens",
		]}),
		_make_gauges(),
		_make_store({"niamh": 50.0}, 1)
	)
	if not result:
		return _fail("iles_mystiques should be accessible with all conditions met")
	return true


func test_iles_mystiques_blocked_only_two_tier3() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"iles_mystiques",
		_make_map_state({"completed_biomes": [
			"foret_broceliande", "cotes_sauvages", "villages_celtes",
			"landes_bruyere", "marais_korrigans",  # only 2 tier-3
			"collines_dolmens",
		]}),
		_make_gauges(),
		_make_store({"niamh": 80.0}, 1)
	)
	if result:
		return _fail("iles_mystiques should be blocked with only 2 tier-3 biomes completed")
	return true


func test_iles_mystiques_blocked_niamh_49() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"iles_mystiques",
		_make_map_state({"completed_biomes": [
			"foret_broceliande", "cotes_sauvages", "villages_celtes",
			"landes_bruyere", "marais_korrigans", "cercles_pierres",
			"collines_dolmens",
		]}),
		_make_gauges(),
		_make_store({"niamh": 49.0}, 1)
	)
	if result:
		return _fail("iles_mystiques should be blocked with niamh=49 (< 50)")
	return true


func test_iles_mystiques_blocked_without_collines_parent() -> bool:
	var result: bool = _tree.is_biome_accessible(
		"iles_mystiques",
		_make_map_state({"completed_biomes": [
			"foret_broceliande", "cotes_sauvages", "villages_celtes",
			"landes_bruyere", "marais_korrigans", "cercles_pierres",
			# collines_dolmens intentionally absent
		]}),
		_make_gauges(),
		_make_store({"niamh": 80.0}, 1)
	)
	if result:
		return _fail("iles_mystiques should be blocked without collines_dolmens completed")
	return true


# =============================================================================
# 13. get_completed_tier3_count
# =============================================================================

func test_completed_tier3_count_zero_with_empty_state() -> bool:
	var count: int = _tree.get_completed_tier3_count({})
	if count != 0:
		return _fail("Tier-3 count with empty state should be 0, got %d" % count)
	return true


func test_completed_tier3_count_zero_only_lower_tiers() -> bool:
	var count: int = _tree.get_completed_tier3_count(
		_make_map_state({"completed_biomes": ["foret_broceliande", "villages_celtes", "cotes_sauvages"]})
	)
	if count != 0:
		return _fail("Tier-3 count should be 0 when only tier-1/2 biomes done, got %d" % count)
	return true


func test_completed_tier3_count_one() -> bool:
	var count: int = _tree.get_completed_tier3_count(
		_make_map_state({"completed_biomes": ["foret_broceliande", "cotes_sauvages", "landes_bruyere"]})
	)
	if count != 1:
		return _fail("Tier-3 count should be 1, got %d" % count)
	return true


func test_completed_tier3_count_two() -> bool:
	var count: int = _tree.get_completed_tier3_count(
		_make_map_state({"completed_biomes": ["landes_bruyere", "marais_korrigans"]})
	)
	if count != 2:
		return _fail("Tier-3 count should be 2, got %d" % count)
	return true


func test_completed_tier3_count_all_three() -> bool:
	var count: int = _tree.get_completed_tier3_count(
		_make_map_state({"completed_biomes": ["landes_bruyere", "marais_korrigans", "cercles_pierres"]})
	)
	if count != 3:
		return _fail("Tier-3 count should be 3, got %d" % count)
	return true


# =============================================================================
# 14. get_unlock_hint
# =============================================================================

func test_unlock_hint_root_returns_accessible() -> bool:
	var hint: String = _tree.get_unlock_hint("foret_broceliande", _make_gauges(), _make_map_state(), _make_store())
	if hint != "Accessible":
		return _fail("Root hint should be 'Accessible', got '%s'" % hint)
	return true


func test_unlock_hint_parent_not_completed_mentions_parent_name() -> bool:
	var hint: String = _tree.get_unlock_hint("villages_celtes", _make_gauges(), _make_map_state(), _make_store())
	# Hint should say "Completer Foret de Broceliande d'abord"
	if not "Broceliande" in hint:
		return _fail("Hint should reference parent biome name, got '%s'" % hint)
	if not "d'abord" in hint:
		return _fail("Hint should say 'd'abord', got '%s'" % hint)
	return true


func test_unlock_hint_shows_condition_text_when_parent_done() -> bool:
	var map_state: Dictionary = _make_map_state({"completed_biomes": ["foret_broceliande"]})
	var hint: String = _tree.get_unlock_hint("villages_celtes", _make_gauges(), map_state, _make_store())
	# Should return the hint string from BIOME_UNLOCK_CONDITIONS, not a parent message
	if "d'abord" in hint:
		return _fail("Should show condition hint, not parent-not-done message. Got '%s'" % hint)
	if hint.is_empty():
		return _fail("Hint should not be empty when parent is completed")
	return true


func test_unlock_hint_unknown_biome_returns_accessible() -> bool:
	var hint: String = _tree.get_unlock_hint("nonexistent_biome", _make_gauges(), _make_map_state(), _make_store())
	if hint != "Accessible":
		return _fail("Unknown biome hint should be 'Accessible', got '%s'" % hint)
	return true


# =============================================================================
# 15. EDGE CASES — empty / missing fields
# =============================================================================

func test_accessibility_empty_state_only_root_accessible() -> bool:
	if not _tree.is_biome_accessible("foret_broceliande", {}, {}, {}):
		return _fail("Root should be accessible with empty state")
	if _tree.is_biome_accessible("villages_celtes", {}, {}, {}):
		return _fail("villages_celtes should NOT be accessible with empty state")
	return true


func test_items_collected_missing_key_treated_as_empty() -> bool:
	# cotes_sauvages with ressources < 50 but items_collected key absent
	var map_state: Dictionary = {"completed_biomes": ["foret_broceliande"]}
	var result: bool = _tree.is_biome_accessible(
		"cotes_sauvages", map_state, _make_gauges({"ressources": 20}), _make_store()
	)
	if not result:
		return _fail("Should still be accessible via low ressources even without items_collected key")
	return true


func test_faction_rep_missing_key_defaults_to_50() -> bool:
	# druides absent from store — should default to 50.0 per implementation
	# villages_celtes needs druides >= 50 OR faveur >= 50
	# faveur set to 0 so it relies on faction default
	var store_no_faction: Dictionary = {"run": {"factions": {}, "hidden": {"karma": 0}}}
	var result: bool = _tree.is_biome_accessible(
		"villages_celtes",
		_make_map_state({"completed_biomes": ["foret_broceliande"]}),
		_make_gauges({"faveur": 0}),
		store_no_faction
	)
	if not result:
		return _fail("villages_celtes should be accessible when druides faction defaults to 50.0")
	return true
