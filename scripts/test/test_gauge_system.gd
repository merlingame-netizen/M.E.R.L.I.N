## =============================================================================
## test_gauge_system.gd — Unit Tests for MerlinGaugeSystem
## =============================================================================
## Covers: build_default_gauges, apply_delta, apply_biome_modifier,
## check_condition, check_conditions, get_gauge_percent,
## get_all_gauge_percents, get_gauge_display, get_biome_modifier,
## edge cases, and immutability guarantees.
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error on failure.
## =============================================================================

extends RefCounted


var _sys: MerlinGaugeSystem


func _init() -> void:
	_sys = MerlinGaugeSystem.new()


func _fail(msg: String) -> bool:
	push_error("[test_gauge_system] " + msg)
	return false


## Build a gauge dict from defaults, optionally overriding specific keys.
func _make_gauges(overrides: Dictionary = {}) -> Dictionary:
	var gauges: Dictionary = _sys.build_default_gauges()
	for key in overrides:
		gauges[key] = overrides[key]
	return gauges


# =============================================================================
# 1. build_default_gauges
# =============================================================================

func test_build_default_gauges_returns_five_keys() -> bool:
	var g: Dictionary = _sys.build_default_gauges()
	if g.size() != 5:
		return _fail("Expected 5 gauge keys, got %d" % g.size())
	return true


func test_build_default_gauges_has_esprit() -> bool:
	var g: Dictionary = _sys.build_default_gauges()
	if not g.has("esprit"):
		return _fail("Missing key 'esprit'")
	return true


func test_build_default_gauges_has_vigueur() -> bool:
	var g: Dictionary = _sys.build_default_gauges()
	if not g.has("vigueur"):
		return _fail("Missing key 'vigueur'")
	return true


func test_build_default_gauges_has_faveur() -> bool:
	var g: Dictionary = _sys.build_default_gauges()
	if not g.has("faveur"):
		return _fail("Missing key 'faveur'")
	return true


func test_build_default_gauges_has_logique() -> bool:
	var g: Dictionary = _sys.build_default_gauges()
	if not g.has("logique"):
		return _fail("Missing key 'logique'")
	return true


func test_build_default_gauges_has_ressources() -> bool:
	var g: Dictionary = _sys.build_default_gauges()
	if not g.has("ressources"):
		return _fail("Missing key 'ressources'")
	return true


func test_build_default_gauges_esprit_is_30() -> bool:
	var g: Dictionary = _sys.build_default_gauges()
	if int(g["esprit"]) != 30:
		return _fail("esprit default: expected 30, got %d" % int(g["esprit"]))
	return true


func test_build_default_gauges_vigueur_is_50() -> bool:
	var g: Dictionary = _sys.build_default_gauges()
	if int(g["vigueur"]) != 50:
		return _fail("vigueur default: expected 50, got %d" % int(g["vigueur"]))
	return true


func test_build_default_gauges_faveur_is_40() -> bool:
	var g: Dictionary = _sys.build_default_gauges()
	if int(g["faveur"]) != 40:
		return _fail("faveur default: expected 40, got %d" % int(g["faveur"]))
	return true


func test_build_default_gauges_logique_is_35() -> bool:
	var g: Dictionary = _sys.build_default_gauges()
	if int(g["logique"]) != 35:
		return _fail("logique default: expected 35, got %d" % int(g["logique"]))
	return true


func test_build_default_gauges_ressources_is_45() -> bool:
	var g: Dictionary = _sys.build_default_gauges()
	if int(g["ressources"]) != 45:
		return _fail("ressources default: expected 45, got %d" % int(g["ressources"]))
	return true


func test_build_default_gauges_all_values_in_range() -> bool:
	var g: Dictionary = _sys.build_default_gauges()
	for key in g:
		var v: int = int(g[key])
		if v < 0 or v > 100:
			return _fail("Default gauge '%s' out of range 0-100: %d" % [key, v])
	return true


# =============================================================================
# 2. apply_delta
# =============================================================================

func test_apply_delta_positive_adds_correctly() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 50})
	var result: Dictionary = _sys.apply_delta(g, {"esprit": 10})
	if int(result["esprit"]) != 60:
		return _fail("apply_delta +10: expected 60, got %d" % int(result["esprit"]))
	return true


func test_apply_delta_negative_subtracts_correctly() -> bool:
	var g: Dictionary = _make_gauges({"vigueur": 50})
	var result: Dictionary = _sys.apply_delta(g, {"vigueur": -20})
	if int(result["vigueur"]) != 30:
		return _fail("apply_delta -20: expected 30, got %d" % int(result["vigueur"]))
	return true


func test_apply_delta_clamps_below_min_to_zero() -> bool:
	var g: Dictionary = _make_gauges({"faveur": 10})
	var result: Dictionary = _sys.apply_delta(g, {"faveur": -50})
	if int(result["faveur"]) != 0:
		return _fail("apply_delta clamp min: expected 0, got %d" % int(result["faveur"]))
	return true


func test_apply_delta_clamps_above_max_to_100() -> bool:
	var g: Dictionary = _make_gauges({"logique": 90})
	var result: Dictionary = _sys.apply_delta(g, {"logique": 50})
	if int(result["logique"]) != 100:
		return _fail("apply_delta clamp max: expected 100, got %d" % int(result["logique"]))
	return true


func test_apply_delta_exact_boundary_at_zero() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 20})
	var result: Dictionary = _sys.apply_delta(g, {"esprit": -20})
	if int(result["esprit"]) != 0:
		return _fail("apply_delta exact min=0: expected 0, got %d" % int(result["esprit"]))
	return true


func test_apply_delta_exact_boundary_at_100() -> bool:
	var g: Dictionary = _make_gauges({"vigueur": 80})
	var result: Dictionary = _sys.apply_delta(g, {"vigueur": 20})
	if int(result["vigueur"]) != 100:
		return _fail("apply_delta exact max=100: expected 100, got %d" % int(result["vigueur"]))
	return true


func test_apply_delta_zero_delta_leaves_value_unchanged() -> bool:
	var g: Dictionary = _make_gauges({"logique": 35})
	var result: Dictionary = _sys.apply_delta(g, {"logique": 0})
	if int(result["logique"]) != 35:
		return _fail("apply_delta zero delta: expected 35, got %d" % int(result["logique"]))
	return true


func test_apply_delta_multiple_gauges_at_once() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 40, "vigueur": 60})
	var result: Dictionary = _sys.apply_delta(g, {"esprit": 15, "vigueur": -10})
	if int(result["esprit"]) != 55:
		return _fail("apply_delta multi esprit: expected 55, got %d" % int(result["esprit"]))
	if int(result["vigueur"]) != 50:
		return _fail("apply_delta multi vigueur: expected 50, got %d" % int(result["vigueur"]))
	return true


func test_apply_delta_ignores_unknown_key() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 50})
	var result: Dictionary = _sys.apply_delta(g, {"unknown_gauge": 99, "esprit": 5})
	if result.has("unknown_gauge"):
		return _fail("apply_delta: must not add unknown key to result")
	if int(result["esprit"]) != 55:
		return _fail("apply_delta: esprit expected 55, got %d" % int(result["esprit"]))
	return true


func test_apply_delta_unaffected_gauges_carry_through() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 30, "vigueur": 50})
	var result: Dictionary = _sys.apply_delta(g, {"esprit": 5})
	if int(result["vigueur"]) != 50:
		return _fail("apply_delta: vigueur should be unchanged at 50, got %d" % int(result["vigueur"]))
	return true


func test_apply_delta_empty_input_gauges_defaults_missing_to_50() -> bool:
	# apply_delta uses result.get(key, 50) for missing keys
	var result: Dictionary = _sys.apply_delta({}, {"esprit": 10})
	if int(result["esprit"]) != 60:
		return _fail("apply_delta empty input: esprit defaults to 50+10=60, got %d" % int(result["esprit"]))
	return true


func test_apply_delta_empty_delta_dict_returns_identical_values() -> bool:
	var g: Dictionary = _make_gauges()
	var result: Dictionary = _sys.apply_delta(g, {})
	for key in g:
		if int(result[key]) != int(g[key]):
			return _fail("apply_delta empty delta: %s changed from %d to %d" % [key, int(g[key]), int(result[key])])
	return true


# =============================================================================
# 3. apply_biome_modifier
# =============================================================================

func test_apply_biome_modifier_foret_esprit_scaled() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 50})
	# foret_broceliande: esprit modifier = 1.15, round(10 * 1.15) = 12 => 50+12 = 62
	var result: Dictionary = _sys.apply_biome_modifier(g, "foret_broceliande", {"esprit": 10})
	if int(result["esprit"]) != 62:
		return _fail("apply_biome_modifier foret esprit: expected 62, got %d" % int(result["esprit"]))
	return true


func test_apply_biome_modifier_foret_vigueur_reduced() -> bool:
	var g: Dictionary = _make_gauges({"vigueur": 50})
	# foret_broceliande: vigueur modifier = 0.90, round(10 * 0.90) = 9 => 50+9 = 59
	var result: Dictionary = _sys.apply_biome_modifier(g, "foret_broceliande", {"vigueur": 10})
	if int(result["vigueur"]) != 59:
		return _fail("apply_biome_modifier foret vigueur: expected 59, got %d" % int(result["vigueur"]))
	return true


func test_apply_biome_modifier_foret_ressources_reduced() -> bool:
	var g: Dictionary = _make_gauges({"ressources": 50})
	# foret_broceliande: ressources modifier = 0.85, round(20 * 0.85) = 17 => 50+17 = 67
	var result: Dictionary = _sys.apply_biome_modifier(g, "foret_broceliande", {"ressources": 20})
	if int(result["ressources"]) != 67:
		return _fail("apply_biome_modifier foret ressources: expected 67, got %d" % int(result["ressources"]))
	return true


func test_apply_biome_modifier_villages_faveur_boosted() -> bool:
	var g: Dictionary = _make_gauges({"faveur": 40})
	# villages_celtes: faveur modifier = 1.10, round(10 * 1.10) = 11 => 40+11 = 51
	var result: Dictionary = _sys.apply_biome_modifier(g, "villages_celtes", {"faveur": 10})
	if int(result["faveur"]) != 51:
		return _fail("apply_biome_modifier villages faveur: expected 51, got %d" % int(result["faveur"]))
	return true


func test_apply_biome_modifier_cotes_clear_vigueur_boosted() -> bool:
	var g: Dictionary = _make_gauges({"vigueur": 50})
	# cotes_sauvages clear: vigueur modifier = 1.05, round(10 * 1.05) = 11 => 50+11 = 61
	var result: Dictionary = _sys.apply_biome_modifier(g, "cotes_sauvages", {"vigueur": 10}, "clear")
	var expected: int = 50 + int(roundf(10.0 * 1.05))
	if int(result["vigueur"]) != expected:
		return _fail("apply_biome_modifier cotes clear vigueur: expected %d, got %d" % [expected, int(result["vigueur"])])
	return true


func test_apply_biome_modifier_cotes_storm_vigueur_reduced() -> bool:
	var g: Dictionary = _make_gauges({"vigueur": 50})
	# cotes_sauvages storm: vigueur modifier = 0.90, round(10 * 0.90) = 9 => 50+9 = 59
	var result: Dictionary = _sys.apply_biome_modifier(g, "cotes_sauvages", {"vigueur": 10}, "storm")
	if int(result["vigueur"]) != 59:
		return _fail("apply_biome_modifier cotes storm vigueur: expected 59, got %d" % int(result["vigueur"]))
	return true


func test_apply_biome_modifier_marais_logique_boosted() -> bool:
	var g: Dictionary = _make_gauges({"logique": 35})
	# marais_korrigans: logique modifier = 1.15, round(10 * 1.15) = 12 => 35+12 = 47
	var result: Dictionary = _sys.apply_biome_modifier(g, "marais_korrigans", {"logique": 10})
	if int(result["logique"]) != 47:
		return _fail("apply_biome_modifier marais logique: expected 47, got %d" % int(result["logique"]))
	return true


func test_apply_biome_modifier_cercles_pierres_esprit_boosted() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 30})
	# cercles_pierres: esprit modifier = 1.20, round(10 * 1.20) = 12 => 30+12 = 42
	var result: Dictionary = _sys.apply_biome_modifier(g, "cercles_pierres", {"esprit": 10})
	if int(result["esprit"]) != 42:
		return _fail("apply_biome_modifier cercles esprit: expected 42, got %d" % int(result["esprit"]))
	return true


func test_apply_biome_modifier_unknown_biome_no_modifier() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 30})
	# Unknown biome => modifier = 1.0, delta unchanged
	var result: Dictionary = _sys.apply_biome_modifier(g, "unknown_biome", {"esprit": 10})
	if int(result["esprit"]) != 40:
		return _fail("apply_biome_modifier unknown biome: expected 40, got %d" % int(result["esprit"]))
	return true


func test_apply_biome_modifier_empty_delta_leaves_gauges_unchanged() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 30})
	var result: Dictionary = _sys.apply_biome_modifier(g, "foret_broceliande", {})
	if int(result["esprit"]) != 30:
		return _fail("apply_biome_modifier empty delta: esprit should be 30, got %d" % int(result["esprit"]))
	return true


func test_apply_biome_modifier_collines_dolmens_esprit_and_faveur() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 50, "faveur": 50})
	# collines_dolmens: esprit=1.05, faveur=1.05
	# esprit: round(10 * 1.05) = 11 => 50+11 = 61
	# faveur: round(10 * 1.05) = 11 => 50+11 = 61
	var result: Dictionary = _sys.apply_biome_modifier(g, "collines_dolmens", {"esprit": 10, "faveur": 10})
	var expected_esprit: int = 50 + int(roundf(10.0 * 1.05))
	var expected_faveur: int = 50 + int(roundf(10.0 * 1.05))
	if int(result["esprit"]) != expected_esprit:
		return _fail("apply_biome_modifier collines esprit: expected %d, got %d" % [expected_esprit, int(result["esprit"])])
	if int(result["faveur"]) != expected_faveur:
		return _fail("apply_biome_modifier collines faveur: expected %d, got %d" % [expected_faveur, int(result["faveur"])])
	return true


# =============================================================================
# 4. check_condition — single condition
# =============================================================================

func test_check_condition_gte_true_at_boundary() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 70})
	var cond: Dictionary = {"gauge": "esprit", "op": ">=", "value": 70}
	if not _sys.check_condition(g, cond):
		return _fail("check_condition >= 70 with 70: should be true")
	return true


func test_check_condition_gte_false_below_boundary() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 69})
	var cond: Dictionary = {"gauge": "esprit", "op": ">=", "value": 70}
	if _sys.check_condition(g, cond):
		return _fail("check_condition >= 70 with 69: should be false")
	return true


func test_check_condition_gt_true_above_boundary() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 71})
	var cond: Dictionary = {"gauge": "esprit", "op": ">", "value": 70}
	if not _sys.check_condition(g, cond):
		return _fail("check_condition > 70 with 71: should be true")
	return true


func test_check_condition_gt_false_at_boundary() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 70})
	var cond: Dictionary = {"gauge": "esprit", "op": ">", "value": 70}
	if _sys.check_condition(g, cond):
		return _fail("check_condition > 70 with 70: should be false (strict)")
	return true


func test_check_condition_lte_true_at_boundary() -> bool:
	var g: Dictionary = _make_gauges({"vigueur": 20})
	var cond: Dictionary = {"gauge": "vigueur", "op": "<=", "value": 20}
	if not _sys.check_condition(g, cond):
		return _fail("check_condition <= 20 with 20: should be true")
	return true


func test_check_condition_lt_true_below_boundary() -> bool:
	var g: Dictionary = _make_gauges({"vigueur": 20})
	var cond: Dictionary = {"gauge": "vigueur", "op": "<", "value": 30}
	if not _sys.check_condition(g, cond):
		return _fail("check_condition < 30 with 20: should be true")
	return true


func test_check_condition_lt_false_at_boundary() -> bool:
	var g: Dictionary = _make_gauges({"vigueur": 30})
	var cond: Dictionary = {"gauge": "vigueur", "op": "<", "value": 30}
	if _sys.check_condition(g, cond):
		return _fail("check_condition < 30 with 30: should be false")
	return true


func test_check_condition_eq_true() -> bool:
	var g: Dictionary = _make_gauges({"logique": 50})
	var cond: Dictionary = {"gauge": "logique", "op": "==", "value": 50}
	if not _sys.check_condition(g, cond):
		return _fail("check_condition == 50 with 50: should be true")
	return true


func test_check_condition_eq_false() -> bool:
	var g: Dictionary = _make_gauges({"logique": 49})
	var cond: Dictionary = {"gauge": "logique", "op": "==", "value": 50}
	if _sys.check_condition(g, cond):
		return _fail("check_condition == 50 with 49: should be false")
	return true


func test_check_condition_neq_true() -> bool:
	var g: Dictionary = _make_gauges({"ressources": 45})
	var cond: Dictionary = {"gauge": "ressources", "op": "!=", "value": 30}
	if not _sys.check_condition(g, cond):
		return _fail("check_condition != 30 with 45: should be true")
	return true


func test_check_condition_neq_false_when_equal() -> bool:
	var g: Dictionary = _make_gauges({"ressources": 45})
	var cond: Dictionary = {"gauge": "ressources", "op": "!=", "value": 45}
	if _sys.check_condition(g, cond):
		return _fail("check_condition != 45 with 45: should be false")
	return true


func test_check_condition_unknown_gauge_returns_false() -> bool:
	var g: Dictionary = _make_gauges()
	var cond: Dictionary = {"gauge": "inexistant", "op": ">=", "value": 0}
	if _sys.check_condition(g, cond):
		return _fail("check_condition with unknown gauge key: should return false")
	return true


func test_check_condition_empty_gauge_key_returns_false() -> bool:
	var g: Dictionary = _make_gauges()
	var cond: Dictionary = {"gauge": "", "op": ">=", "value": 0}
	if _sys.check_condition(g, cond):
		return _fail("check_condition with empty gauge key: should return false")
	return true


func test_check_condition_unknown_op_returns_false() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 50})
	var cond: Dictionary = {"gauge": "esprit", "op": "~=", "value": 50}
	if _sys.check_condition(g, cond):
		return _fail("check_condition with unknown op '~=': should return false")
	return true


func test_check_condition_missing_gauge_in_state_defaults_to_zero() -> bool:
	# gauge key is valid but not present in the state dict => defaults to 0
	var cond: Dictionary = {"gauge": "esprit", "op": ">=", "value": 1}
	if _sys.check_condition({}, cond):
		return _fail("check_condition: missing gauge in state defaults to 0, >= 1 should be false")
	return true


func test_check_condition_missing_gauge_zero_passes_gte_zero() -> bool:
	var cond: Dictionary = {"gauge": "esprit", "op": ">=", "value": 0}
	if not _sys.check_condition({}, cond):
		return _fail("check_condition: missing gauge defaults to 0, >= 0 should be true")
	return true


# =============================================================================
# 5. check_conditions — multi-condition blocks
# =============================================================================

func test_check_conditions_and_all_pass() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 80, "vigueur": 60})
	var block: Dictionary = {
		"logic": "and",
		"conditions": [
			{"gauge": "esprit", "op": ">=", "value": 70},
			{"gauge": "vigueur", "op": ">=", "value": 50},
		],
	}
	if not _sys.check_conditions(g, block):
		return _fail("check_conditions AND all pass: should return true")
	return true


func test_check_conditions_and_one_fails() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 80, "vigueur": 30})
	var block: Dictionary = {
		"logic": "and",
		"conditions": [
			{"gauge": "esprit", "op": ">=", "value": 70},
			{"gauge": "vigueur", "op": ">=", "value": 50},
		],
	}
	if _sys.check_conditions(g, block):
		return _fail("check_conditions AND one fails: should return false")
	return true


func test_check_conditions_and_all_fail() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 20, "vigueur": 10})
	var block: Dictionary = {
		"logic": "and",
		"conditions": [
			{"gauge": "esprit", "op": ">=", "value": 70},
			{"gauge": "vigueur", "op": ">=", "value": 50},
		],
	}
	if _sys.check_conditions(g, block):
		return _fail("check_conditions AND all fail: should return false")
	return true


func test_check_conditions_or_one_passes() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 80, "vigueur": 10})
	var block: Dictionary = {
		"logic": "or",
		"conditions": [
			{"gauge": "esprit", "op": ">=", "value": 70},
			{"gauge": "vigueur", "op": ">=", "value": 50},
		],
	}
	if not _sys.check_conditions(g, block):
		return _fail("check_conditions OR one passes: should return true")
	return true


func test_check_conditions_or_none_passes() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 20, "vigueur": 10})
	var block: Dictionary = {
		"logic": "or",
		"conditions": [
			{"gauge": "esprit", "op": ">=", "value": 70},
			{"gauge": "vigueur", "op": ">=", "value": 50},
		],
	}
	if _sys.check_conditions(g, block):
		return _fail("check_conditions OR none pass: should return false")
	return true


func test_check_conditions_empty_conditions_returns_true() -> bool:
	var g: Dictionary = _make_gauges()
	var block: Dictionary = {"logic": "and", "conditions": []}
	if not _sys.check_conditions(g, block):
		return _fail("check_conditions empty block: should return true")
	return true


func test_check_conditions_non_gauge_entries_skipped_and_logic_returns_true() -> bool:
	# With logic="and" and all conditions lacking 'gauge' key, all are skipped.
	# Loop ends without returning false => final return is (logic == "and") => true.
	var g: Dictionary = _make_gauges()
	var block: Dictionary = {
		"logic": "and",
		"conditions": [{"item": "sword", "op": ">=", "value": 1}],
	}
	if not _sys.check_conditions(g, block):
		return _fail("check_conditions AND with only non-gauge entries: should return true")
	return true


func test_check_conditions_non_gauge_entries_skipped_or_logic_returns_false() -> bool:
	# With logic="or" and all conditions lacking 'gauge' key, all are skipped.
	# Loop ends without returning true => final return is (logic == "and") => false.
	var g: Dictionary = _make_gauges()
	var block: Dictionary = {
		"logic": "or",
		"conditions": [{"item": "sword", "op": ">=", "value": 1}],
	}
	if _sys.check_conditions(g, block):
		return _fail("check_conditions OR with only non-gauge entries: should return false")
	return true


# =============================================================================
# 6. get_gauge_percent
# =============================================================================

func test_get_gauge_percent_zero() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 0})
	var pct: float = _sys.get_gauge_percent(g, "esprit")
	if not is_equal_approx(pct, 0.0):
		return _fail("get_gauge_percent 0/100: expected 0.0, got %.3f" % pct)
	return true


func test_get_gauge_percent_full() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 100})
	var pct: float = _sys.get_gauge_percent(g, "esprit")
	if not is_equal_approx(pct, 1.0):
		return _fail("get_gauge_percent 100/100: expected 1.0, got %.3f" % pct)
	return true


func test_get_gauge_percent_half() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 50})
	var pct: float = _sys.get_gauge_percent(g, "esprit")
	if not is_equal_approx(pct, 0.5):
		return _fail("get_gauge_percent 50/100: expected 0.5, got %.3f" % pct)
	return true


func test_get_gauge_percent_unknown_key_returns_zero() -> bool:
	var g: Dictionary = _make_gauges()
	# Unknown gauge: GAUGES.get returns {}, max defaults to 100, value defaults to 0 => 0.0
	var pct: float = _sys.get_gauge_percent(g, "nonexistent")
	if not is_equal_approx(pct, 0.0):
		return _fail("get_gauge_percent unknown key: expected 0.0, got %.3f" % pct)
	return true


func test_get_gauge_percent_clamped_when_over_max() -> bool:
	# Inject a value beyond max to verify clampf in get_gauge_percent
	var g: Dictionary = _make_gauges({"esprit": 150})
	var pct: float = _sys.get_gauge_percent(g, "esprit")
	if pct > 1.0:
		return _fail("get_gauge_percent with value 150: expected clamp to 1.0, got %.3f" % pct)
	return true


func test_get_gauge_percent_empty_state_returns_zero() -> bool:
	var pct: float = _sys.get_gauge_percent({}, "esprit")
	if not is_equal_approx(pct, 0.0):
		return _fail("get_gauge_percent empty state: expected 0.0, got %.3f" % pct)
	return true


func test_get_all_gauge_percents_returns_five_keys() -> bool:
	var g: Dictionary = _make_gauges()
	var percents: Dictionary = _sys.get_all_gauge_percents(g)
	if percents.size() != 5:
		return _fail("get_all_gauge_percents: expected 5 keys, got %d" % percents.size())
	return true


func test_get_all_gauge_percents_values_in_range() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 50, "vigueur": 100, "faveur": 0, "logique": 25, "ressources": 75})
	var percents: Dictionary = _sys.get_all_gauge_percents(g)
	for key in percents:
		var v: float = float(percents[key])
		if v < 0.0 or v > 1.0:
			return _fail("get_all_gauge_percents: '%s' out of range 0.0-1.0: %.3f" % [key, v])
	return true


func test_get_all_gauge_percents_vigueur_full() -> bool:
	var g: Dictionary = _make_gauges({"vigueur": 100})
	var percents: Dictionary = _sys.get_all_gauge_percents(g)
	if not is_equal_approx(float(percents["vigueur"]), 1.0):
		return _fail("get_all_gauge_percents vigueur=100: expected 1.0, got %.3f" % float(percents["vigueur"]))
	return true


# =============================================================================
# 7. get_gauge_display
# =============================================================================

func test_get_gauge_display_has_all_required_keys() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 75})
	var display: Dictionary = _sys.get_gauge_display(g, "esprit")
	for key in ["key", "name", "icon", "color", "value", "max", "percent"]:
		if not display.has(key):
			return _fail("get_gauge_display: missing key '%s'" % key)
	return true


func test_get_gauge_display_key_and_name() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 75})
	var display: Dictionary = _sys.get_gauge_display(g, "esprit")
	if str(display["key"]) != "esprit":
		return _fail("get_gauge_display key: expected 'esprit', got '%s'" % str(display["key"]))
	if str(display["name"]) != "Esprit":
		return _fail("get_gauge_display name: expected 'Esprit', got '%s'" % str(display["name"]))
	return true


func test_get_gauge_display_value_and_max() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 75})
	var display: Dictionary = _sys.get_gauge_display(g, "esprit")
	if int(display["value"]) != 75:
		return _fail("get_gauge_display value: expected 75, got %d" % int(display["value"]))
	if int(display["max"]) != 100:
		return _fail("get_gauge_display max: expected 100, got %d" % int(display["max"]))
	return true


func test_get_gauge_display_percent_correct() -> bool:
	var g: Dictionary = _make_gauges({"logique": 50})
	var display: Dictionary = _sys.get_gauge_display(g, "logique")
	if not is_equal_approx(float(display["percent"]), 0.5):
		return _fail("get_gauge_display percent: expected 0.5, got %.3f" % float(display["percent"]))
	return true


func test_get_gauge_display_unknown_key_uses_fallbacks() -> bool:
	var g: Dictionary = _make_gauges()
	var display: Dictionary = _sys.get_gauge_display(g, "unknown")
	# name falls back to gauge_key, icon to "?", color to Color.WHITE, value to 0, max to 100
	if str(display["name"]) != "unknown":
		return _fail("get_gauge_display unknown name fallback: expected 'unknown', got '%s'" % str(display["name"]))
	if str(display["icon"]) != "?":
		return _fail("get_gauge_display unknown icon fallback: expected '?', got '%s'" % str(display["icon"]))
	return true


# =============================================================================
# 8. get_biome_modifier
# =============================================================================

func test_get_biome_modifier_foret_esprit() -> bool:
	var mod: float = _sys.get_biome_modifier("foret_broceliande", "esprit")
	if not is_equal_approx(mod, 1.15):
		return _fail("foret_broceliande esprit: expected 1.15, got %.3f" % mod)
	return true


func test_get_biome_modifier_foret_vigueur() -> bool:
	var mod: float = _sys.get_biome_modifier("foret_broceliande", "vigueur")
	if not is_equal_approx(mod, 0.90):
		return _fail("foret_broceliande vigueur: expected 0.90, got %.3f" % mod)
	return true


func test_get_biome_modifier_foret_ressources() -> bool:
	var mod: float = _sys.get_biome_modifier("foret_broceliande", "ressources")
	if not is_equal_approx(mod, 0.85):
		return _fail("foret_broceliande ressources: expected 0.85, got %.3f" % mod)
	return true


func test_get_biome_modifier_foret_unaffected_gauge_returns_1() -> bool:
	# foret_broceliande has no modifier for logique
	var mod: float = _sys.get_biome_modifier("foret_broceliande", "logique")
	if not is_equal_approx(mod, 1.0):
		return _fail("foret_broceliande logique: expected 1.0, got %.3f" % mod)
	return true


func test_get_biome_modifier_cotes_clear_vigueur() -> bool:
	var mod: float = _sys.get_biome_modifier("cotes_sauvages", "vigueur", "clear")
	if not is_equal_approx(mod, 1.05):
		return _fail("cotes_sauvages clear vigueur: expected 1.05, got %.3f" % mod)
	return true


func test_get_biome_modifier_cotes_storm_vigueur() -> bool:
	var mod: float = _sys.get_biome_modifier("cotes_sauvages", "vigueur", "storm")
	if not is_equal_approx(mod, 0.90):
		return _fail("cotes_sauvages storm vigueur: expected 0.90, got %.3f" % mod)
	return true


func test_get_biome_modifier_cotes_defaults_to_clear_when_weather_unknown() -> bool:
	# cotes_sauvages has weather-keyed structure; unknown weather falls back to "clear"
	var mod: float = _sys.get_biome_modifier("cotes_sauvages", "vigueur", "fog")
	var clear_mod: float = _sys.get_biome_modifier("cotes_sauvages", "vigueur", "clear")
	if not is_equal_approx(mod, clear_mod):
		return _fail("cotes_sauvages fog should fall back to clear modifier %.3f, got %.3f" % [clear_mod, mod])
	return true


func test_get_biome_modifier_landes_faveur_reduced() -> bool:
	var mod: float = _sys.get_biome_modifier("landes_bruyere", "faveur")
	if not is_equal_approx(mod, 0.90):
		return _fail("landes_bruyere faveur: expected 0.90, got %.3f" % mod)
	return true


func test_get_biome_modifier_landes_ressources_boosted() -> bool:
	var mod: float = _sys.get_biome_modifier("landes_bruyere", "ressources")
	if not is_equal_approx(mod, 1.20):
		return _fail("landes_bruyere ressources: expected 1.20, got %.3f" % mod)
	return true


func test_get_biome_modifier_marais_logique() -> bool:
	var mod: float = _sys.get_biome_modifier("marais_korrigans", "logique")
	if not is_equal_approx(mod, 1.15):
		return _fail("marais_korrigans logique: expected 1.15, got %.3f" % mod)
	return true


func test_get_biome_modifier_cercles_esprit() -> bool:
	var mod: float = _sys.get_biome_modifier("cercles_pierres", "esprit")
	if not is_equal_approx(mod, 1.20):
		return _fail("cercles_pierres esprit: expected 1.20, got %.3f" % mod)
	return true


func test_get_biome_modifier_collines_dolmens_esprit() -> bool:
	var mod: float = _sys.get_biome_modifier("collines_dolmens", "esprit")
	if not is_equal_approx(mod, 1.05):
		return _fail("collines_dolmens esprit: expected 1.05, got %.3f" % mod)
	return true


func test_get_biome_modifier_unknown_biome_returns_1() -> bool:
	var mod: float = _sys.get_biome_modifier("biome_inconnu", "esprit")
	if not is_equal_approx(mod, 1.0):
		return _fail("unknown biome: expected 1.0, got %.3f" % mod)
	return true


func test_get_biome_modifier_empty_biome_key_returns_1() -> bool:
	var mod: float = _sys.get_biome_modifier("", "esprit")
	if not is_equal_approx(mod, 1.0):
		return _fail("empty biome key: expected 1.0, got %.3f" % mod)
	return true


func test_get_biome_modifier_empty_gauge_key_returns_1() -> bool:
	var mod: float = _sys.get_biome_modifier("foret_broceliande", "")
	if not is_equal_approx(mod, 1.0):
		return _fail("empty gauge key in known biome: expected 1.0, got %.3f" % mod)
	return true


# =============================================================================
# 9. Immutability — input dicts must NOT be mutated
# =============================================================================

func test_apply_delta_does_not_mutate_input() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 50})
	var _result: Dictionary = _sys.apply_delta(g, {"esprit": 20})
	if int(g["esprit"]) != 50:
		return _fail("apply_delta mutated input: esprit changed from 50 to %d" % int(g["esprit"]))
	return true


func test_apply_biome_modifier_does_not_mutate_input() -> bool:
	var g: Dictionary = _make_gauges({"vigueur": 50})
	var _result: Dictionary = _sys.apply_biome_modifier(g, "foret_broceliande", {"vigueur": 20})
	if int(g["vigueur"]) != 50:
		return _fail("apply_biome_modifier mutated input: vigueur changed from 50 to %d" % int(g["vigueur"]))
	return true


func test_apply_delta_result_is_independent_from_input() -> bool:
	var g: Dictionary = _make_gauges({"esprit": 30})
	var result: Dictionary = _sys.apply_delta(g, {"esprit": 5})
	# Mutate result, confirm g is unaffected
	result["esprit"] = 99
	if int(g["esprit"]) != 30:
		return _fail("apply_delta result shares memory with input: mutating result changed g")
	return true


func test_build_default_gauges_each_call_is_independent() -> bool:
	var g1: Dictionary = _sys.build_default_gauges()
	var g2: Dictionary = _sys.build_default_gauges()
	g1["esprit"] = 99
	if int(g2["esprit"]) == 99:
		return _fail("build_default_gauges: two calls share the same dictionary")
	return true


# =============================================================================
# run_all — collect and report results
# =============================================================================

func run_all() -> Dictionary:
	var tests: Array = [
		"test_build_default_gauges_returns_five_keys",
		"test_build_default_gauges_has_esprit",
		"test_build_default_gauges_has_vigueur",
		"test_build_default_gauges_has_faveur",
		"test_build_default_gauges_has_logique",
		"test_build_default_gauges_has_ressources",
		"test_build_default_gauges_esprit_is_30",
		"test_build_default_gauges_vigueur_is_50",
		"test_build_default_gauges_faveur_is_40",
		"test_build_default_gauges_logique_is_35",
		"test_build_default_gauges_ressources_is_45",
		"test_build_default_gauges_all_values_in_range",
		"test_apply_delta_positive_adds_correctly",
		"test_apply_delta_negative_subtracts_correctly",
		"test_apply_delta_clamps_below_min_to_zero",
		"test_apply_delta_clamps_above_max_to_100",
		"test_apply_delta_exact_boundary_at_zero",
		"test_apply_delta_exact_boundary_at_100",
		"test_apply_delta_zero_delta_leaves_value_unchanged",
		"test_apply_delta_multiple_gauges_at_once",
		"test_apply_delta_ignores_unknown_key",
		"test_apply_delta_unaffected_gauges_carry_through",
		"test_apply_delta_empty_input_gauges_defaults_missing_to_50",
		"test_apply_delta_empty_delta_dict_returns_identical_values",
		"test_apply_biome_modifier_foret_esprit_scaled",
		"test_apply_biome_modifier_foret_vigueur_reduced",
		"test_apply_biome_modifier_foret_ressources_reduced",
		"test_apply_biome_modifier_villages_faveur_boosted",
		"test_apply_biome_modifier_cotes_clear_vigueur_boosted",
		"test_apply_biome_modifier_cotes_storm_vigueur_reduced",
		"test_apply_biome_modifier_marais_logique_boosted",
		"test_apply_biome_modifier_cercles_pierres_esprit_boosted",
		"test_apply_biome_modifier_unknown_biome_no_modifier",
		"test_apply_biome_modifier_empty_delta_leaves_gauges_unchanged",
		"test_apply_biome_modifier_collines_dolmens_esprit_and_faveur",
		"test_check_condition_gte_true_at_boundary",
		"test_check_condition_gte_false_below_boundary",
		"test_check_condition_gt_true_above_boundary",
		"test_check_condition_gt_false_at_boundary",
		"test_check_condition_lte_true_at_boundary",
		"test_check_condition_lt_true_below_boundary",
		"test_check_condition_lt_false_at_boundary",
		"test_check_condition_eq_true",
		"test_check_condition_eq_false",
		"test_check_condition_neq_true",
		"test_check_condition_neq_false_when_equal",
		"test_check_condition_unknown_gauge_returns_false",
		"test_check_condition_empty_gauge_key_returns_false",
		"test_check_condition_unknown_op_returns_false",
		"test_check_condition_missing_gauge_in_state_defaults_to_zero",
		"test_check_condition_missing_gauge_zero_passes_gte_zero",
		"test_check_conditions_and_all_pass",
		"test_check_conditions_and_one_fails",
		"test_check_conditions_and_all_fail",
		"test_check_conditions_or_one_passes",
		"test_check_conditions_or_none_passes",
		"test_check_conditions_empty_conditions_returns_true",
		"test_check_conditions_non_gauge_entries_skipped_and_logic_returns_true",
		"test_check_conditions_non_gauge_entries_skipped_or_logic_returns_false",
		"test_get_gauge_percent_zero",
		"test_get_gauge_percent_full",
		"test_get_gauge_percent_half",
		"test_get_gauge_percent_unknown_key_returns_zero",
		"test_get_gauge_percent_clamped_when_over_max",
		"test_get_gauge_percent_empty_state_returns_zero",
		"test_get_all_gauge_percents_returns_five_keys",
		"test_get_all_gauge_percents_values_in_range",
		"test_get_all_gauge_percents_vigueur_full",
		"test_get_gauge_display_has_all_required_keys",
		"test_get_gauge_display_key_and_name",
		"test_get_gauge_display_value_and_max",
		"test_get_gauge_display_percent_correct",
		"test_get_gauge_display_unknown_key_uses_fallbacks",
		"test_get_biome_modifier_foret_esprit",
		"test_get_biome_modifier_foret_vigueur",
		"test_get_biome_modifier_foret_ressources",
		"test_get_biome_modifier_foret_unaffected_gauge_returns_1",
		"test_get_biome_modifier_cotes_clear_vigueur",
		"test_get_biome_modifier_cotes_storm_vigueur",
		"test_get_biome_modifier_cotes_defaults_to_clear_when_weather_unknown",
		"test_get_biome_modifier_landes_faveur_reduced",
		"test_get_biome_modifier_landes_ressources_boosted",
		"test_get_biome_modifier_marais_logique",
		"test_get_biome_modifier_cercles_esprit",
		"test_get_biome_modifier_collines_dolmens_esprit",
		"test_get_biome_modifier_unknown_biome_returns_1",
		"test_get_biome_modifier_empty_biome_key_returns_1",
		"test_get_biome_modifier_empty_gauge_key_returns_1",
		"test_apply_delta_does_not_mutate_input",
		"test_apply_biome_modifier_does_not_mutate_input",
		"test_apply_delta_result_is_independent_from_input",
		"test_build_default_gauges_each_call_is_independent",
	]

	var passed: int = 0
	var failed: int = 0
	var failures: Array = []

	for test_name in tests:
		var result: bool = call(test_name)
		if result:
			passed += 1
		else:
			failed += 1
			failures.append(test_name)

	print("[test_gauge_system] %d/%d passed" % [passed, passed + failed])
	for f in failures:
		print("  FAIL: %s" % f)

	return {"passed": passed, "failed": failed, "failures": failures}
