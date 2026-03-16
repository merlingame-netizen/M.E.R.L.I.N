## =============================================================================
## Unit Tests — MerlinGaugeSystem
## =============================================================================
## Tests: build_default_gauges, apply_delta, biome modifiers, check_condition,
## check_conditions, get_gauge_percent, get_all_gauge_percents,
## get_gauge_display, get_biome_modifier, immutability, edge cases.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


func _make_gauges(overrides: Dictionary = {}) -> Dictionary:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = sys.build_default_gauges()
	for key in overrides:
		gauges[key] = overrides[key]
	return gauges


# =============================================================================
# BUILD DEFAULT GAUGES
# =============================================================================

func test_build_default_gauges_has_all_keys() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = sys.build_default_gauges()
	var expected: Array = ["esprit", "vigueur", "faveur", "logique", "ressources"]
	for key in expected:
		if not gauges.has(key):
			push_error("build_default_gauges: missing key '%s'" % key)
			return false
	if gauges.size() != 5:
		push_error("build_default_gauges: expected 5 keys, got %d" % gauges.size())
		return false
	return true


func test_build_default_gauges_values() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = sys.build_default_gauges()
	var expected: Dictionary = {"esprit": 30, "vigueur": 50, "faveur": 40, "logique": 35, "ressources": 45}
	for key in expected:
		if int(gauges[key]) != int(expected[key]):
			push_error("build_default_gauges: %s expected %d, got %d" % [key, int(expected[key]), int(gauges[key])])
			return false
	return true


# =============================================================================
# APPLY DELTA — basic operations
# =============================================================================

func test_apply_delta_positive() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 50})
	var result: Dictionary = sys.apply_delta(gauges, {"esprit": 10})
	if int(result["esprit"]) != 60:
		push_error("apply_delta +10: expected 60, got %d" % int(result["esprit"]))
		return false
	return true


func test_apply_delta_negative() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"vigueur": 50})
	var result: Dictionary = sys.apply_delta(gauges, {"vigueur": -20})
	if int(result["vigueur"]) != 30:
		push_error("apply_delta -20: expected 30, got %d" % int(result["vigueur"]))
		return false
	return true


func test_apply_delta_clamps_at_zero() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"faveur": 10})
	var result: Dictionary = sys.apply_delta(gauges, {"faveur": -50})
	if int(result["faveur"]) != 0:
		push_error("apply_delta clamp min: expected 0, got %d" % int(result["faveur"]))
		return false
	return true


func test_apply_delta_clamps_at_100() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"logique": 90})
	var result: Dictionary = sys.apply_delta(gauges, {"logique": 50})
	if int(result["logique"]) != 100:
		push_error("apply_delta clamp max: expected 100, got %d" % int(result["logique"]))
		return false
	return true


func test_apply_delta_multiple_gauges() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 40, "vigueur": 60})
	var result: Dictionary = sys.apply_delta(gauges, {"esprit": 15, "vigueur": -10})
	if int(result["esprit"]) != 55:
		push_error("apply_delta multi esprit: expected 55, got %d" % int(result["esprit"]))
		return false
	if int(result["vigueur"]) != 50:
		push_error("apply_delta multi vigueur: expected 50, got %d" % int(result["vigueur"]))
		return false
	return true


func test_apply_delta_ignores_unknown_keys() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 50})
	var result: Dictionary = sys.apply_delta(gauges, {"unknown_gauge": 99, "esprit": 5})
	if result.has("unknown_gauge"):
		push_error("apply_delta: should not add unknown key")
		return false
	if int(result["esprit"]) != 55:
		push_error("apply_delta: esprit expected 55, got %d" % int(result["esprit"]))
		return false
	return true


# =============================================================================
# IMMUTABILITY — apply_delta must not mutate input
# =============================================================================

func test_apply_delta_does_not_mutate_input() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 50})
	var _result: Dictionary = sys.apply_delta(gauges, {"esprit": 20})
	if int(gauges["esprit"]) != 50:
		push_error("apply_delta mutated input: esprit changed from 50 to %d" % int(gauges["esprit"]))
		return false
	return true


# =============================================================================
# BIOME MODIFIERS
# =============================================================================

func test_biome_modifier_foret_esprit() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var mod: float = sys.get_biome_modifier("foret_broceliande", "esprit")
	if not is_equal_approx(mod, 1.15):
		push_error("foret_broceliande esprit modifier: expected 1.15, got %.2f" % mod)
		return false
	return true


func test_biome_modifier_unknown_biome_returns_1() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var mod: float = sys.get_biome_modifier("biome_inconnu", "esprit")
	if not is_equal_approx(mod, 1.0):
		push_error("unknown biome modifier: expected 1.0, got %.2f" % mod)
		return false
	return true


func test_biome_modifier_unknown_gauge_returns_1() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var mod: float = sys.get_biome_modifier("foret_broceliande", "faveur")
	if not is_equal_approx(mod, 1.0):
		push_error("foret faveur modifier: expected 1.0, got %.2f" % mod)
		return false
	return true


func test_biome_modifier_weather_storm() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var mod: float = sys.get_biome_modifier("cotes_sauvages", "vigueur", "storm")
	if not is_equal_approx(mod, 0.90):
		push_error("cotes storm vigueur: expected 0.90, got %.2f" % mod)
		return false
	return true


func test_biome_modifier_weather_clear() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var mod: float = sys.get_biome_modifier("cotes_sauvages", "vigueur", "clear")
	if not is_equal_approx(mod, 1.05):
		push_error("cotes clear vigueur: expected 1.05, got %.2f" % mod)
		return false
	return true


func test_apply_biome_modifier_scales_delta() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 50})
	# foret_broceliande esprit = 1.15, delta 10 → round(10*1.15) = 12
	var result: Dictionary = sys.apply_biome_modifier(gauges, "foret_broceliande", {"esprit": 10})
	if int(result["esprit"]) != 62:
		push_error("apply_biome_modifier: expected 62, got %d" % int(result["esprit"]))
		return false
	return true


# =============================================================================
# CHECK CONDITION — single condition
# =============================================================================

func test_check_condition_gte_pass() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 70})
	var cond: Dictionary = {"gauge": "esprit", "op": ">=", "value": 70}
	if not sys.check_condition(gauges, cond):
		push_error("check_condition >= 70 with 70: should pass")
		return false
	return true


func test_check_condition_gte_fail() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 69})
	var cond: Dictionary = {"gauge": "esprit", "op": ">=", "value": 70}
	if sys.check_condition(gauges, cond):
		push_error("check_condition >= 70 with 69: should fail")
		return false
	return true


func test_check_condition_lt() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"vigueur": 20})
	var cond: Dictionary = {"gauge": "vigueur", "op": "<", "value": 30}
	if not sys.check_condition(gauges, cond):
		push_error("check_condition < 30 with 20: should pass")
		return false
	return true


func test_check_condition_eq() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"logique": 50})
	var cond: Dictionary = {"gauge": "logique", "op": "==", "value": 50}
	if not sys.check_condition(gauges, cond):
		push_error("check_condition == 50 with 50: should pass")
		return false
	return true


func test_check_condition_invalid_gauge_returns_false() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges()
	var cond: Dictionary = {"gauge": "inexistant", "op": ">=", "value": 0}
	if sys.check_condition(gauges, cond):
		push_error("check_condition with invalid gauge: should return false")
		return false
	return true


func test_check_condition_unknown_op_returns_false() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 50})
	var cond: Dictionary = {"gauge": "esprit", "op": "~=", "value": 50}
	if sys.check_condition(gauges, cond):
		push_error("check_condition with unknown op: should return false")
		return false
	return true


# =============================================================================
# CHECK CONDITIONS — multi-condition blocks
# =============================================================================

func test_check_conditions_and_all_pass() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 80, "vigueur": 60})
	var block: Dictionary = {
		"logic": "and",
		"conditions": [
			{"gauge": "esprit", "op": ">=", "value": 70},
			{"gauge": "vigueur", "op": ">=", "value": 50},
		],
	}
	if not sys.check_conditions(gauges, block):
		push_error("check_conditions AND all pass: should return true")
		return false
	return true


func test_check_conditions_and_one_fails() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 80, "vigueur": 30})
	var block: Dictionary = {
		"logic": "and",
		"conditions": [
			{"gauge": "esprit", "op": ">=", "value": 70},
			{"gauge": "vigueur", "op": ">=", "value": 50},
		],
	}
	if sys.check_conditions(gauges, block):
		push_error("check_conditions AND one fails: should return false")
		return false
	return true


func test_check_conditions_or_one_passes() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 80, "vigueur": 10})
	var block: Dictionary = {
		"logic": "or",
		"conditions": [
			{"gauge": "esprit", "op": ">=", "value": 70},
			{"gauge": "vigueur", "op": ">=", "value": 50},
		],
	}
	if not sys.check_conditions(gauges, block):
		push_error("check_conditions OR one passes: should return true")
		return false
	return true


func test_check_conditions_empty_returns_true() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges()
	var block: Dictionary = {"logic": "and", "conditions": []}
	if not sys.check_conditions(gauges, block):
		push_error("check_conditions empty: should return true")
		return false
	return true


# =============================================================================
# GET GAUGE PERCENT
# =============================================================================

func test_get_gauge_percent_mid() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 50})
	var pct: float = sys.get_gauge_percent(gauges, "esprit")
	if not is_equal_approx(pct, 0.5):
		push_error("get_gauge_percent 50/100: expected 0.5, got %.3f" % pct)
		return false
	return true


func test_get_gauge_percent_zero() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"logique": 0})
	var pct: float = sys.get_gauge_percent(gauges, "logique")
	if not is_equal_approx(pct, 0.0):
		push_error("get_gauge_percent 0/100: expected 0.0, got %.3f" % pct)
		return false
	return true


func test_get_all_gauge_percents() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 50, "vigueur": 100, "faveur": 0, "logique": 25, "ressources": 75})
	var percents: Dictionary = sys.get_all_gauge_percents(gauges)
	if percents.size() != 5:
		push_error("get_all_gauge_percents: expected 5 entries, got %d" % percents.size())
		return false
	if not is_equal_approx(float(percents["vigueur"]), 1.0):
		push_error("get_all_gauge_percents vigueur: expected 1.0, got %.3f" % float(percents["vigueur"]))
		return false
	return true


# =============================================================================
# GET GAUGE DISPLAY
# =============================================================================

func test_get_gauge_display_structure() -> bool:
	var sys: MerlinGaugeSystem = MerlinGaugeSystem.new()
	var gauges: Dictionary = _make_gauges({"esprit": 75})
	var display: Dictionary = sys.get_gauge_display(gauges, "esprit")
	var required_keys: Array = ["key", "name", "icon", "color", "value", "max", "percent"]
	for key in required_keys:
		if not display.has(key):
			push_error("get_gauge_display: missing key '%s'" % key)
			return false
	if str(display["key"]) != "esprit":
		push_error("get_gauge_display key: expected 'esprit', got '%s'" % str(display["key"]))
		return false
	if str(display["name"]) != "Esprit":
		push_error("get_gauge_display name: expected 'Esprit', got '%s'" % str(display["name"]))
		return false
	if int(display["value"]) != 75:
		push_error("get_gauge_display value: expected 75, got %d" % int(display["value"]))
		return false
	if int(display["max"]) != 100:
		push_error("get_gauge_display max: expected 100, got %d" % int(display["max"]))
		return false
	return true
