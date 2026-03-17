## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinCardSystem (methods NOT covered by test_card_system.gd)
## ═══════════════════════════════════════════════════════════════════════════════
## Covers: card validation, _ensure_3_options, handle_merlin_direct,
## resolve_card, _process_card_tags, init_run structure, _trust_tier_to_index,
## _find_worst_option, _annotate_fields, check_run_end edge cases,
## _build_llm_context, get_event_category, emergency card, ogham ioho,
## option counting, effect processing, card pool selection logic.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


func _make_card_system() -> MerlinCardSystem:
	var cs: MerlinCardSystem = MerlinCardSystem.new()
	# No LLM, no effects engine, no RNG — pure logic tests
	return cs


func _make_run_state() -> Dictionary:
	return {
		"biome": "foret_broceliande",
		"active_ogham": "beith",
		"card_index": 0,
		"cards_played": 0,
		"active_promises": [],
		"promise_tracking": {},
		"story_log": [],
		"active_tags": [],
		"minigame_wins_this_run": 0,
		"total_healing_this_run": 0,
		"damage_taken_this_run": 0,
		"life_essence": 80,
	}


func _make_card_3_options() -> Dictionary:
	return {
		"id": "test_card_001",
		"type": "narrative",
		"text": "Un sentier s'ouvre devant toi.",
		"options": [
			{"label": "Observer les traces", "verb": "observer", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
			{"label": "Combattre le loup", "verb": "combattre", "effects": [{"type": "DAMAGE_LIFE", "amount": 5}]},
			{"label": "Mediter sous le chene", "verb": "mediter", "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
		],
		"tags": [],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# INIT RUN — structure validation
# ═══════════════════════════════════════════════════════════════════════════════

func test_init_run_returns_all_keys() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run: Dictionary = cs.init_run("foret_broceliande", "beith")
	var required_keys: Array = [
		"biome", "active_ogham", "card_index", "cards_played",
		"active_promises", "promise_tracking", "story_log",
		"active_tags", "minigame_wins_this_run",
		"total_healing_this_run", "damage_taken_this_run",
	]
	for key in required_keys:
		if not run.has(key):
			push_error("init_run missing key: %s" % key)
			return false
	return true


func test_init_run_biome_stored() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run: Dictionary = cs.init_run("lac_viviane", "luis")
	if str(run.get("biome", "")) != "lac_viviane":
		push_error("init_run biome: expected lac_viviane, got %s" % str(run.get("biome", "")))
		return false
	if str(run.get("active_ogham", "")) != "luis":
		push_error("init_run ogham: expected luis, got %s" % str(run.get("active_ogham", "")))
		return false
	return true


func test_init_run_counters_zero() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run: Dictionary = cs.init_run("foret_broceliande", "beith")
	if int(run.get("card_index", -1)) != 0:
		push_error("init_run card_index should be 0")
		return false
	if int(run.get("cards_played", -1)) != 0:
		push_error("init_run cards_played should be 0")
		return false
	return true


func test_init_run_clears_tracking() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	# First run
	cs.init_run("foret_broceliande", "beith")
	# Simulate some seen cards
	cs._event_cards_seen.append("evt_001")
	cs._promise_ids_taken.append("prm_001")
	cs._fastroute_seen.append("fr_001")
	# Second run should clear
	cs.init_run("lac_viviane", "luis")
	if cs._event_cards_seen.size() != 0:
		push_error("init_run should clear _event_cards_seen")
		return false
	if cs._promise_ids_taken.size() != 0:
		push_error("init_run should clear _promise_ids_taken")
		return false
	if cs._fastroute_seen.size() != 0:
		push_error("init_run should clear _fastroute_seen")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CARD VALIDATION (_validate_card)
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_card_valid() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"text": "Un druide t'attend.",
		"options": [
			{"label": "Parler"},
			{"label": "Fuir"},
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if not result.get("valid", false):
		push_error("_validate_card: valid card rejected — %s" % str(result.get("error", "")))
		return false
	return true


func test_validate_card_missing_text() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"options": [{"label": "A"}, {"label": "B"}],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("_validate_card: card without text should be invalid")
		return false
	return true


func test_validate_card_empty_text() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"text": "",
		"options": [{"label": "A"}, {"label": "B"}],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("_validate_card: card with empty text should be invalid")
		return false
	return true


func test_validate_card_too_few_options() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"text": "Un carrefour.",
		"options": [{"label": "A"}],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("_validate_card: card with 1 option should be invalid (need 2+)")
		return false
	return true


func test_validate_card_option_missing_label() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"text": "Un pont.",
		"options": [
			{"label": "Traverser"},
			{"effects": [{"type": "HEAL_LIFE", "amount": 1}]},
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("_validate_card: option without label should be invalid")
		return false
	return true


func test_validate_card_invalid_option_type() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"text": "Un chemin.",
		"options": [
			{"label": "A"},
			"not_a_dictionary",
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("_validate_card: non-Dictionary option should be invalid")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ENSURE 3 OPTIONS
# ═══════════════════════════════════════════════════════════════════════════════

func test_ensure_3_options_pads_to_3() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"options": [
			{"label": "A"},
		],
	}
	var result: Dictionary = cs._ensure_3_options(card)
	var options: Array = result.get("options", [])
	if options.size() != 3:
		push_error("_ensure_3_options: expected 3, got %d" % options.size())
		return false
	# Padded options should have a label
	if str(options[1].get("label", "")).is_empty():
		push_error("_ensure_3_options: padded option should have a label")
		return false
	return true


func test_ensure_3_options_trims_to_3() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"options": [
			{"label": "A"},
			{"label": "B"},
			{"label": "C"},
			{"label": "D"},
			{"label": "E"},
		],
	}
	var result: Dictionary = cs._ensure_3_options(card)
	var options: Array = result.get("options", [])
	if options.size() != 3:
		push_error("_ensure_3_options: expected 3 after trim, got %d" % options.size())
		return false
	# Should keep first 3
	if str(options[0].get("label", "")) != "A":
		push_error("_ensure_3_options: first option should be A")
		return false
	if str(options[2].get("label", "")) != "C":
		push_error("_ensure_3_options: third option should be C")
		return false
	return true


func test_ensure_3_options_exact_3_unchanged() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"options": [
			{"label": "A"},
			{"label": "B"},
			{"label": "C"},
		],
	}
	var result: Dictionary = cs._ensure_3_options(card)
	var options: Array = result.get("options", [])
	if options.size() != 3:
		push_error("_ensure_3_options: 3 options should stay as 3")
		return false
	return true


func test_ensure_3_options_does_not_mutate_original() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var original_options: Array = [{"label": "A"}]
	var card: Dictionary = {"options": original_options}
	cs._ensure_3_options(card)
	if original_options.size() != 1:
		push_error("_ensure_3_options: should not mutate original card")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# HANDLE MERLIN DIRECT
# ═══════════════════════════════════════════════════════════════════════════════

func test_handle_merlin_direct_valid_option() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card_3_options()
	card["type"] = "merlin_direct"
	var result: Dictionary = cs.handle_merlin_direct(card, 0)
	if not result.get("ok", false):
		push_error("handle_merlin_direct: valid option should return ok=true")
		return false
	if not result.get("skip_minigame", false):
		push_error("handle_merlin_direct: should set skip_minigame=true")
		return false
	var mult: float = float(result.get("multiplier", 0.0))
	if absf(mult - 1.0) > 0.001:
		push_error("handle_merlin_direct: multiplier should be 1.0, got %f" % mult)
		return false
	return true


func test_handle_merlin_direct_returns_effects() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card_3_options()
	var result: Dictionary = cs.handle_merlin_direct(card, 2)
	var effects: Array = result.get("effects", [])
	if effects.size() != 1:
		push_error("handle_merlin_direct: expected 1 effect, got %d" % effects.size())
		return false
	if str(effects[0].get("type", "")) != "HEAL_LIFE":
		push_error("handle_merlin_direct: expected HEAL_LIFE effect")
		return false
	return true


func test_handle_merlin_direct_invalid_index_negative() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card_3_options()
	var result: Dictionary = cs.handle_merlin_direct(card, -1)
	if result.get("ok", true):
		push_error("handle_merlin_direct: negative index should fail")
		return false
	return true


func test_handle_merlin_direct_invalid_index_too_high() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card_3_options()
	var result: Dictionary = cs.handle_merlin_direct(card, 5)
	if result.get("ok", true):
		push_error("handle_merlin_direct: out-of-range index should fail")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TRUST TIER TO INDEX
# ═══════════════════════════════════════════════════════════════════════════════

func test_trust_tier_to_index_all_tiers() -> bool:
	var expected: Dictionary = {"T0": 0, "T1": 1, "T2": 2, "T3": 3}
	for tier in expected:
		var idx: int = MerlinCardSystem._trust_tier_to_index(tier)
		if idx != int(expected[tier]):
			push_error("_trust_tier_to_index(%s): expected %d, got %d" % [tier, int(expected[tier]), idx])
			return false
	return true


func test_trust_tier_to_index_unknown_defaults_zero() -> bool:
	var idx: int = MerlinCardSystem._trust_tier_to_index("T99")
	if idx != 0:
		push_error("_trust_tier_to_index(T99): expected 0, got %d" % idx)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROCESS CARD TAGS
# ═══════════════════════════════════════════════════════════════════════════════

func test_process_card_tags_adds_new_tags() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run_state: Dictionary = _make_run_state()
	var card: Dictionary = {"tags": ["forest_visited", "druid_met"]}
	cs._process_card_tags(run_state, card)
	var tags: Array = run_state.get("active_tags", [])
	if tags.size() != 2:
		push_error("_process_card_tags: expected 2 tags, got %d" % tags.size())
		return false
	if not tags.has("forest_visited"):
		push_error("_process_card_tags: missing tag forest_visited")
		return false
	return true


func test_process_card_tags_no_duplicates() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run_state: Dictionary = _make_run_state()
	run_state["active_tags"] = ["forest_visited"]
	var card: Dictionary = {"tags": ["forest_visited", "druid_met"]}
	cs._process_card_tags(run_state, card)
	var tags: Array = run_state.get("active_tags", [])
	if tags.size() != 2:
		push_error("_process_card_tags: duplicate tag should not be added, got %d" % tags.size())
		return false
	return true


func test_process_card_tags_empty_tags_no_change() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run_state: Dictionary = _make_run_state()
	run_state["active_tags"] = ["existing"]
	var card: Dictionary = {"tags": []}
	cs._process_card_tags(run_state, card)
	var tags: Array = run_state.get("active_tags", [])
	if tags.size() != 1:
		push_error("_process_card_tags: empty tags should not change active_tags")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RESOLVE CARD
# ═══════════════════════════════════════════════════════════════════════════════

func test_resolve_card_valid_option() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run_state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card_3_options()
	var result: Dictionary = cs.resolve_card(run_state, card, 0, 80)
	if not result.get("ok", false):
		push_error("resolve_card: valid option should return ok=true")
		return false
	var applied: Array = result.get("effects", [])
	if applied.size() < 1:
		push_error("resolve_card: expected at least 1 applied effect")
		return false
	return true


func test_resolve_card_invalid_option_index() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run_state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card_3_options()
	var result: Dictionary = cs.resolve_card(run_state, card, 10, 50)
	if result.get("ok", true):
		push_error("resolve_card: out-of-range index should fail")
		return false
	return true


func test_resolve_card_increments_counters() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run_state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card_3_options()
	cs.resolve_card(run_state, card, 1, 70)
	if int(run_state.get("card_index", 0)) != 1:
		push_error("resolve_card: card_index should increment to 1")
		return false
	if int(run_state.get("cards_played", 0)) != 1:
		push_error("resolve_card: cards_played should increment to 1")
		return false
	return true


func test_resolve_card_appends_story_log() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run_state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card_3_options()
	cs.resolve_card(run_state, card, 0, 90)
	var log: Array = run_state.get("story_log", [])
	if log.size() != 1:
		push_error("resolve_card: story_log should have 1 entry, got %d" % log.size())
		return false
	var entry: Dictionary = log[0]
	if str(entry.get("card_id", "")) != "test_card_001":
		push_error("resolve_card: story_log card_id mismatch")
		return false
	if int(entry.get("option_index", -1)) != 0:
		push_error("resolve_card: story_log option_index should be 0")
		return false
	return true


func test_resolve_card_story_log_capped_at_50() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run_state: Dictionary = _make_run_state()
	# Pre-fill story_log with 50 entries
	var prefilled: Array = []
	for i in range(50):
		prefilled.append({"card_id": "old_%d" % i, "option_index": 0, "score": 50, "multiplier": 1.0, "effects_count": 1})
	run_state["story_log"] = prefilled
	var card: Dictionary = _make_card_3_options()
	cs.resolve_card(run_state, card, 0, 80)
	var log: Array = run_state.get("story_log", [])
	if log.size() > 50:
		push_error("resolve_card: story_log should be capped at 50, got %d" % log.size())
		return false
	# Last entry should be the new one
	var last: Dictionary = log[log.size() - 1]
	if str(last.get("card_id", "")) != "test_card_001":
		push_error("resolve_card: last story_log entry should be new card")
		return false
	return true


func test_resolve_card_merlin_direct_multiplier_1() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run_state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card_3_options()
	card["type"] = "merlin_direct"
	var result: Dictionary = cs.resolve_card(run_state, card, 0, 30)
	var mult: float = float(result.get("multiplier", 0.0))
	if absf(mult - 1.0) > 0.001:
		push_error("resolve_card merlin_direct: multiplier should be 1.0, got %f" % mult)
		return false
	return true


func test_resolve_card_processes_tags() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var run_state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card_3_options()
	card["tags"] = ["quest_started"]
	cs.resolve_card(run_state, card, 0, 80)
	var tags: Array = run_state.get("active_tags", [])
	if not tags.has("quest_started"):
		push_error("resolve_card: should process card tags into active_tags")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ANNOTATE FIELDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_annotate_fields_sets_field_and_minigame() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"options": [
			{"label": "Observer les traces"},
			{"label": "Combattre le loup"},
			{"label": "Mediter sous le chene"},
		],
	}
	cs._annotate_fields(card)
	var options: Array = card.get("options", [])
	for i in range(options.size()):
		var opt: Dictionary = options[i]
		if str(opt.get("field", "")).is_empty():
			push_error("_annotate_fields: option %d missing field" % i)
			return false
		if str(opt.get("minigame", "")).is_empty():
			push_error("_annotate_fields: option %d missing minigame" % i)
			return false
	return true


func test_annotate_fields_uses_explicit_verb() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"options": [
			{"label": "Some label", "verb": "combattre"},
		],
	}
	cs._annotate_fields(card)
	var opt: Dictionary = card["options"][0]
	# With explicit verb, field comes from detect_field_from_verb
	if str(opt.get("field", "")).is_empty():
		push_error("_annotate_fields: explicit verb should set field")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SELECT MINIGAME
# ═══════════════════════════════════════════════════════════════════════════════

func test_select_minigame_known_field_returns_valid() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	for field in MerlinConstants.FIELD_MINIGAMES:
		var mg: String = cs.select_minigame(field)
		if mg.is_empty():
			push_error("select_minigame('%s') returned empty" % field)
			return false
		var valid_mgs: Array = MerlinConstants.FIELD_MINIGAMES[field]
		if mg not in valid_mgs:
			push_error("select_minigame('%s') returned '%s' not in %s" % [field, mg, str(valid_mgs)])
			return false
	return true


func test_select_minigame_unknown_field_returns_fallback() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var mg: String = cs.select_minigame("nonexistent_field")
	if mg != "apaisement":
		push_error("select_minigame unknown field: expected 'apaisement', got '%s'" % mg)
		return false
	return true


func test_select_minigame_all_8_fields_covered() -> bool:
	var expected_fields: Array = ["chance", "bluff", "observation", "logique",
		"finesse", "vigueur", "esprit", "perception"]
	for field in expected_fields:
		if not MerlinConstants.FIELD_MINIGAMES.has(field):
			push_error("FIELD_MINIGAMES missing field '%s'" % field)
			return false
		var mgs: Array = MerlinConstants.FIELD_MINIGAMES[field]
		if mgs.is_empty():
			push_error("FIELD_MINIGAMES['%s'] has empty minigame list" % field)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FIND WORST OPTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_find_worst_option_damage_is_worst() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var options: Array = [
		{"label": "A", "effects": [{"type": "HEAL_LIFE", "amount": 10}]},
		{"label": "B", "effects": [{"type": "DAMAGE_LIFE", "amount": 15}]},
		{"label": "C", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
	]
	var idx: int = cs._find_worst_option(options)
	if idx != 1:
		push_error("_find_worst_option: option B (DAMAGE_LIFE 15) should be worst, got idx %d" % idx)
		return false
	return true


func test_find_worst_option_reputation_contributes() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var options: Array = [
		{"label": "A", "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 10}]},
		{"label": "B", "effects": []},
		{"label": "C", "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
	]
	# B has score 0, A has 10*0.5=5, C has 5 — B should be worst
	var idx: int = cs._find_worst_option(options)
	if idx != 1:
		push_error("_find_worst_option: empty effects option should be worst, got idx %d" % idx)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EMERGENCY CARD
# ═══════════════════════════════════════════════════════════════════════════════

func test_emergency_card_has_3_options() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = cs._get_emergency_card()
	var options: Array = card.get("options", [])
	if options.size() != 3:
		push_error("_get_emergency_card: expected 3 options, got %d" % options.size())
		return false
	return true


func test_emergency_card_is_narrative_type() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = cs._get_emergency_card()
	if str(card.get("type", "")) != "narrative":
		push_error("_get_emergency_card: type should be narrative")
		return false
	if str(card.get("text", "")).is_empty():
		push_error("_get_emergency_card: should have text")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM NARRATIVE — ioho (not covered by existing tests)
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_narrative_ioho_adds_ankou_rep() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card_3_options()
	var result: Dictionary = cs.apply_ogham_narrative("ioho", card)
	var options: Array = result.get("options", [])
	var tracker: Dictionary = {"all_have_ankou": true}
	for opt in options:
		if not (opt is Dictionary):
			continue
		var effects: Array = opt.get("effects", [])
		var has_ankou: bool = false
		for eff in effects:
			if eff is Dictionary and str(eff.get("type", "")) == "ADD_REPUTATION" and str(eff.get("faction", "")) == "ankou":
				has_ankou = true
		if not has_ankou:
			tracker["all_have_ankou"] = false
	if not tracker["all_have_ankou"]:
		push_error("ogham ioho: all options should have ADD_REPUTATION ankou effect")
		return false
	if str(result.get("ogham_modified", "")) != "ioho":
		push_error("ogham ioho: ogham_modified should be 'ioho'")
		return false
	return true


func test_ogham_narrative_ioho_does_not_mutate_original() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card_3_options()
	var original_effects_count: int = card["options"][0].get("effects", []).size()
	cs.apply_ogham_narrative("ioho", card)
	# Original should be unchanged (deep copy)
	var after_count: int = card["options"][0].get("effects", []).size()
	if after_count != original_effects_count:
		push_error("ogham ioho: should not mutate original card effects")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CHECK RUN END — high and critical zones (not in existing tests)
# ═══════════════════════════════════════════════════════════════════════════════

func test_check_run_end_high_zone() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var target_max: int = int(MerlinConstants.MOS_CONVERGENCE.get("target_cards_max", 25))
	var state: Dictionary = {"life_essence": 50, "card_index": target_max + 1}
	var result: Dictionary = cs.check_run_end(state)
	if str(result.get("tension_zone", "")) != "high":
		push_error("check_run_end high zone: expected 'high', got '%s'" % str(result.get("tension_zone", "")))
		return false
	if not result.get("convergence_zone", false):
		push_error("check_run_end high zone: should be in convergence_zone")
		return false
	return true


func test_check_run_end_critical_zone() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var soft_max: int = int(MerlinConstants.MOS_CONVERGENCE.get("soft_max_cards", 40))
	var state: Dictionary = {"life_essence": 50, "card_index": soft_max + 1}
	var result: Dictionary = cs.check_run_end(state)
	if str(result.get("tension_zone", "")) != "critical":
		push_error("check_run_end critical zone: expected 'critical', got '%s'" % str(result.get("tension_zone", "")))
		return false
	return true


func test_check_run_end_none_zone_early_cards() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = {"life_essence": 80, "card_index": 2}
	var result: Dictionary = cs.check_run_end(state)
	if str(result.get("tension_zone", "")) != "none":
		push_error("check_run_end: very early cards should have tension_zone='none'")
		return false
	if result.get("early_zone", true):
		push_error("check_run_end: card_index 2 should NOT be in early_zone")
		return false
	return true


func test_check_run_end_negative_life() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = {"life_essence": -5, "card_index": 3}
	var result: Dictionary = cs.check_run_end(state)
	if not result.get("ended", false):
		push_error("check_run_end: negative life should end run")
		return false
	if str(result.get("reason", "")) != "death":
		push_error("check_run_end: negative life reason should be death")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# GET EVENT CATEGORY — without selector
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_event_category_no_selector() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	cs._event_selector = null
	var result: Dictionary = cs.get_event_category({})
	if not result.is_empty():
		push_error("get_event_category: with no selector should return empty dict")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD LLM CONTEXT
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_llm_context_all_fields() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var context: Dictionary = {
		"biome": "marais_morrigane",
		"card_index": 5,
		"cards_played": 4,
		"active_ogham": "fearn",
		"life_essence": 60,
		"period": "crepuscule",
		"story_log": [{"card_id": "c1"}],
		"active_tags": ["tag_a"],
		"active_promises": [],
		"trust_tier": "T2",
		"faction_rep": {"druides": 50},
	}
	var result: Dictionary = cs._build_llm_context(context)
	if str(result.get("biome", "")) != "marais_morrigane":
		push_error("_build_llm_context: biome mismatch")
		return false
	if int(result.get("card_index", -1)) != 5:
		push_error("_build_llm_context: card_index mismatch")
		return false
	if str(result.get("trust_tier", "")) != "T2":
		push_error("_build_llm_context: trust_tier mismatch")
		return false
	if str(result.get("period", "")) != "crepuscule":
		push_error("_build_llm_context: period mismatch")
		return false
	return true


func test_build_llm_context_defaults() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var result: Dictionary = cs._build_llm_context({})
	if str(result.get("biome", "")) != "foret_broceliande":
		push_error("_build_llm_context: default biome should be foret_broceliande")
		return false
	if int(result.get("life_essence", 0)) != 100:
		push_error("_build_llm_context: default life_essence should be 100")
		return false
	if str(result.get("trust_tier", "")) != "T0":
		push_error("_build_llm_context: default trust_tier should be T0")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CARD TYPES CONSTANT
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_types_has_all_expected() -> bool:
	var expected: Array = ["narrative", "event", "promise", "merlin_direct"]
	for t in expected:
		if not MerlinCardSystem.CARD_TYPES.has(t):
			push_error("CARD_TYPES missing: %s" % t)
			return false
	if MerlinCardSystem.CARD_TYPES.size() != 4:
		push_error("CARD_TYPES should have exactly 4 types, got %d" % MerlinCardSystem.CARD_TYPES.size())
		return false
	return true
