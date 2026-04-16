## ═══════════════════════════════════════════════════════════════════════════════
## Smoke Test Suite — 32 fast health-check tests
## ═══════════════════════════════════════════════════════════════════════════════
## Each test < 10ms. No scene loading, no disk I/O, no network.
## Usage:
##   var t = TestSmoke.new()
##   var r: Dictionary = t.run_all()
##   print(r)  # {"passed": 32, "failed": 0, "results": [...]}
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name TestSmoke

var _pass_count: int = 0
var _fail_count: int = 0
var _results: Array = []


func run_all() -> Dictionary:
	_pass_count = 0
	_fail_count = 0
	_results.clear()
	var methods: Array = get_method_list()
	for m in methods:
		if str(m["name"]).begins_with("test_"):
			_run_test(str(m["name"]))
	return {"passed": _pass_count, "failed": _fail_count, "results": _results}


func _run_test(method_name: String) -> void:
	var ok: bool = call(method_name)
	if ok:
		_pass_count += 1
	else:
		_fail_count += 1
	_results.append({"name": method_name, "passed": ok})


func _assert(condition: bool, msg: String = "") -> bool:
	if not condition:
		push_warning("[FAIL] %s" % msg)
	return condition


# ═══════════════════════════════════════════════════════════════════════════════
# 1. CONSTANTS INTEGRITY (8 tests)
# ═══════════════════════════════════════════════════════════════════════════════

func test_oghams_has_18_entries() -> bool:
	return _assert(
		MerlinConstants.OGHAM_FULL_SPECS.size() == 18,
		"OGHAM_FULL_SPECS should have 18 entries, got %d" % MerlinConstants.OGHAM_FULL_SPECS.size()
	)


func test_biomes_has_8_entries() -> bool:
	return _assert(
		MerlinConstants.BIOMES.size() == 8,
		"BIOMES should have 8 entries, got %d" % MerlinConstants.BIOMES.size()
	)


func test_factions_has_5_entries() -> bool:
	return _assert(
		MerlinConstants.FACTIONS.size() == 5,
		"FACTIONS should have 5 entries, got %d" % MerlinConstants.FACTIONS.size()
	)


func test_lexical_fields_has_8_entries() -> bool:
	return _assert(
		MerlinConstants.ACTION_VERBS.size() == 8,
		"ACTION_VERBS (lexical fields) should have 8 entries, got %d" % MerlinConstants.ACTION_VERBS.size()
	)


func test_minigame_catalogue_has_keys() -> bool:
	return _assert(
		MerlinConstants.MINIGAME_CATALOGUE.size() > 0,
		"MINIGAME_CATALOGUE should not be empty"
	)


func test_mos_convergence_values() -> bool:
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var ok_all: bool = (
		int(mos.get("soft_min_cards", -1)) == 8
		and int(mos.get("target_cards_min", -1)) == 20
		and int(mos.get("target_cards_max", -1)) == 25
		and int(mos.get("soft_max_cards", -1)) == 40
		and int(mos.get("hard_max_cards", -1)) == 50
	)
	return _assert(ok_all, "MOS_CONVERGENCE values mismatch")


func test_faction_score_start_is_neutral() -> bool:
	return _assert(
		MerlinConstants.FACTION_SCORE_START == 20,
		"FACTION_SCORE_START should be 20 (neutral), got %d" % MerlinConstants.FACTION_SCORE_START
	)


func test_multiplier_table_non_empty() -> bool:
	return _assert(
		MerlinConstants.MULTIPLIER_TABLE.size() > 0,
		"MULTIPLIER_TABLE should not be empty"
	)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. STORE STATE (6 tests)
# ═══════════════════════════════════════════════════════════════════════════════

func _build_store_state() -> Dictionary:
	var store: MerlinStore = MerlinStore.new()
	var s: Dictionary = store.build_default_state()
	store.free()
	return s


func test_store_state_is_dictionary() -> bool:
	var s: Dictionary = _build_store_state()
	return _assert(typeof(s) == TYPE_DICTIONARY, "build_default_state should return Dictionary")


func test_store_state_has_factions_with_5() -> bool:
	var s: Dictionary = _build_store_state()
	var run: Dictionary = s.get("run", {})
	var factions: Dictionary = run.get("factions", {})
	return _assert(factions.size() == 5, "run.factions should have 5 entries, got %d" % factions.size())


func test_store_state_has_life_100() -> bool:
	var s: Dictionary = _build_store_state()
	var run: Dictionary = s.get("run", {})
	var life: int = int(run.get("life_essence", -1))
	return _assert(life == 100, "run.life_essence should be 100, got %d" % life)


func test_store_state_has_anam_zero() -> bool:
	var s: Dictionary = _build_store_state()
	var meta: Dictionary = s.get("meta", {})
	var anam: int = int(meta.get("anam", -1))
	return _assert(anam == 0, "meta.anam should be 0, got %d" % anam)


func test_store_state_has_phase() -> bool:
	var s: Dictionary = _build_store_state()
	return _assert(s.has("phase"), "state should have 'phase' key")


func test_store_state_phase_is_title() -> bool:
	var s: Dictionary = _build_store_state()
	var phase: String = str(s.get("phase", ""))
	return _assert(phase == "title", "initial phase should be 'title', got '%s'" % phase)


# ═══════════════════════════════════════════════════════════════════════════════
# 3. SYSTEMS INSTANTIATION (6 tests)
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_system_instantiates() -> bool:
	var sys: MerlinSaveSystem = MerlinSaveSystem.new()
	return _assert(sys != null, "MerlinSaveSystem.new() should succeed")


func test_reputation_system_instantiates() -> bool:
	var sys: MerlinReputationSystem = MerlinReputationSystem.new()
	return _assert(sys != null, "MerlinReputationSystem.new() should succeed")


func test_effect_engine_instantiates() -> bool:
	var sys: MerlinEffectEngine = MerlinEffectEngine.new()
	return _assert(sys != null, "MerlinEffectEngine.new() should succeed")


func test_card_system_instantiates() -> bool:
	var sys: MerlinCardSystem = MerlinCardSystem.new()
	return _assert(sys != null, "MerlinCardSystem.new() should succeed")


func test_error_handler_instantiates() -> bool:
	var sys: ErrorHandler = ErrorHandler.new()
	var ok: bool = sys != null
	if sys != null:
		sys.free()
	return _assert(ok, "ErrorHandler.new() should succeed")


func test_tutorial_system_instantiates() -> bool:
	var sys: TutorialSystem = TutorialSystem.new()
	var ok: bool = sys != null
	if sys != null:
		sys.free()
	return _assert(ok, "TutorialSystem.new() should succeed")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. EFFECT ENGINE (4 tests)
# ═══════════════════════════════════════════════════════════════════════════════

func test_effect_add_reputation_valid() -> bool:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	return _assert(
		engine.validate_effect("ADD_REPUTATION:druides:10"),
		"ADD_REPUTATION:druides:10 should be valid"
	)


func test_effect_heal_life_valid() -> bool:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	return _assert(
		engine.validate_effect("HEAL_LIFE:5"),
		"HEAL_LIFE:5 should be valid"
	)


func test_effect_damage_life_valid() -> bool:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	return _assert(
		engine.validate_effect("DAMAGE_LIFE:3"),
		"DAMAGE_LIFE:3 should be valid"
	)


func test_effect_cap_reputation_enforced() -> bool:
	var capped_pos: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", 50)
	var capped_neg: int = MerlinEffectEngine.cap_effect("ADD_REPUTATION", -50)
	return _assert(
		capped_pos == 20 and capped_neg == -20,
		"ADD_REPUTATION should cap to +/-20, got +%d / %d" % [capped_pos, capped_neg]
	)


# ═══════════════════════════════════════════════════════════════════════════════
# 5. CARD VALIDATION (4 tests)
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_valid_structure_passes() -> bool:
	var card_sys: MerlinCardSystem = MerlinCardSystem.new()
	var card: Dictionary = {
		"text": "Un druide vous interpelle au bord du sentier.",
		"options": [
			{"label": "Ecouter", "effects": [{"type": "HEAL_LIFE", "amount": 2}]},
			{"label": "Ignorer", "effects": [{"type": "DAMAGE_LIFE", "amount": 1}]},
			{"label": "Fuir", "effects": [{"type": "ADD_ANAM", "amount": 3}]},
		],
	}
	var result: Dictionary = card_sys._validate_card(card)
	return _assert(result.get("valid", false) == true, "Valid card should pass validation")


func test_card_missing_text_fails() -> bool:
	var card_sys: MerlinCardSystem = MerlinCardSystem.new()
	var card: Dictionary = {
		"options": [
			{"label": "A", "effects": []},
			{"label": "B", "effects": []},
		],
	}
	var result: Dictionary = card_sys._validate_card(card)
	return _assert(result.get("valid", false) == false, "Card without text should fail validation")


func test_card_too_few_options_fails() -> bool:
	var card_sys: MerlinCardSystem = MerlinCardSystem.new()
	var card: Dictionary = {
		"text": "Some narrative text.",
		"options": [
			{"label": "Only one", "effects": []},
		],
	}
	var result: Dictionary = card_sys._validate_card(card)
	return _assert(result.get("valid", false) == false, "Card with <2 options should fail")


func test_card_empty_text_fails() -> bool:
	var card_sys: MerlinCardSystem = MerlinCardSystem.new()
	var card: Dictionary = {
		"text": "",
		"options": [
			{"label": "A", "effects": []},
			{"label": "B", "effects": []},
		],
	}
	var result: Dictionary = card_sys._validate_card(card)
	return _assert(result.get("valid", false) == false, "Card with empty text should fail")


# ═══════════════════════════════════════════════════════════════════════════════
# 6. REPUTATION SYSTEM (4 tests)
# ═══════════════════════════════════════════════════════════════════════════════

func test_rep_starts_at_faction_score_start() -> bool:
	var s: Dictionary = _build_store_state()
	var meta: Dictionary = s.get("meta", {})
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	var all_at_start: bool = true
	for faction in MerlinConstants.FACTIONS:
		if int(faction_rep.get(faction, -1)) != MerlinConstants.FACTION_SCORE_START:
			all_at_start = false
			break
	return _assert(all_at_start, "All factions should start at FACTION_SCORE_START (%d)" % MerlinConstants.FACTION_SCORE_START)


func test_rep_clamped_0_to_100() -> bool:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	# Test upper clamp: 95 + 20 (capped to +20) => 100
	var state_upper: Dictionary = {
		"meta": {"faction_rep": {"druides": 95}},
		"run": {},
	}
	engine.apply_effects(state_upper, ["ADD_REPUTATION:druides:20"])
	var rep_upper: int = int(state_upper.get("meta", {}).get("faction_rep", {}).get("druides", -1))

	# Test lower clamp: 5 + (-20) (capped to -20) => 0
	var state_lower: Dictionary = {
		"meta": {"faction_rep": {"druides": 5}},
		"run": {},
	}
	engine.apply_effects(state_lower, ["ADD_REPUTATION:druides:-20"])
	var rep_lower: int = int(state_lower.get("meta", {}).get("faction_rep", {}).get("druides", -1))

	return _assert(
		rep_upper == 100 and rep_lower == 0,
		"Rep should clamp 0-100, got upper=%d lower=%d" % [rep_upper, rep_lower]
	)


func test_rep_tier_threshold_50() -> bool:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	var tier: String = engine._score_to_tier(50)
	return _assert(tier == "sympathisant", "Score 50 should be 'sympathisant', got '%s'" % tier)


func test_rep_tier_threshold_80() -> bool:
	var engine: MerlinEffectEngine = MerlinEffectEngine.new()
	var tier: String = engine._score_to_tier(80)
	return _assert(tier == "honore", "Score 80 should be 'honore', got '%s'" % tier)
