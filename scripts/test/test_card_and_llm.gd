## ═══════════════════════════════════════════════════════════════════════════════
## Test Suite — MerlinCardSystem + MerlinLlmAdapter
## ═══════════════════════════════════════════════════════════════════════════════
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error on fail.
## NO assert(), NO await, NO := with typed array/dictionary from const.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# FACTORY HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_card_system() -> MerlinCardSystem:
	var cs: MerlinCardSystem = MerlinCardSystem.new()
	return cs


func _make_llm_adapter() -> MerlinLlmAdapter:
	var llm: MerlinLlmAdapter = MerlinLlmAdapter.new()
	return llm


func _make_card() -> Dictionary:
	return {
		"id": "test_card_001",
		"type": "narrative",
		"narrative": "Le druide te regarde en silence.",
		"options": [
			{"label": "Combattre le korrigan", "verb": "combattre", "field": "force", "effects": [{"type": "DAMAGE_LIFE", "amount": 5}]},
			{"label": "Mediter pres du menhir", "verb": "mediter", "field": "esprit", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
			{"label": "Fuir dans la foret", "verb": "fuir", "field": "agilite", "effects": [{"type": "ADD_REPUTATION", "faction": "korrigans", "amount": -5}]},
		],
		"tags": ["test_tag"],
	}


func _make_run_state() -> Dictionary:
	return {
		"life_essence": 50,
		"card_index": 10,
		"cards_played": 10,
		"story_log": [],
		"active_tags": [],
		"active_promises": [],
		"hidden": {"karma": 0, "tension": 0, "player_profile": {"audace": 0, "prudence": 0, "altruisme": 0, "egoisme": 0}},
		"factions": {"druides": 0.0, "anciens": 0.0, "korrigans": 0.0, "niamh": 0.0, "ankou": 0.0},
		"current_biome": "foret_broceliande",
		"day": 3,
	}


func _make_valid_llm_card() -> Dictionary:
	return {
		"text": "La brume s'epaissit entre les chenes centenaires.",
		"options": [
			{"direction": "left", "label": "Observer", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
			{"direction": "right", "label": "Fuir", "effects": [{"type": "DAMAGE_LIFE", "amount": 2}]},
			{"direction": "left", "label": "Attendre", "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}]},
		],
		"tags": [],
	}


func _make_legacy_scene() -> Dictionary:
	return {
		"scene_id": "test_001",
		"biome": "foret_broceliande",
		"backdrop": "chene_ancien",
		"text_pages": ["Page un.", "Page deux."],
		"choices": [{"label": "A"}, {"label": "B"}],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN CARD SYSTEM — detect_lexical_field
# ═══════════════════════════════════════════════════════════════════════════════

func test_detect_field_combattre() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var result: String = cs.detect_lexical_field("Combattre le korrigan")
	if result != "vigueur":
		push_error("Expected 'vigueur' for 'combattre', got '%s'" % result)
		return false
	return true


func test_detect_field_mediter() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var result: String = cs.detect_lexical_field("Mediter pres du menhir")
	if result != "esprit":
		push_error("Expected 'esprit' for 'mediter', got '%s'" % result)
		return false
	return true


func test_detect_field_observer() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var result: String = cs.detect_lexical_field("Observer les environs")
	if result != "observation":
		push_error("Expected 'observation' for 'observer', got '%s'" % result)
		return false
	return true


func test_detect_field_dechiffrer() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var result: String = cs.detect_lexical_field("Dechiffrer les runes anciennes")
	if result != "logique":
		push_error("Expected 'logique' for 'dechiffrer', got '%s'" % result)
		return false
	return true


func test_detect_field_marchander() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var result: String = cs.detect_lexical_field("Marchander avec le lutin")
	if result != "bluff":
		push_error("Expected 'bluff' for 'marchander', got '%s'" % result)
		return false
	return true


func test_detect_field_cueillir() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var result: String = cs.detect_lexical_field("Cueillir des herbes magiques")
	if result != "chance":
		push_error("Expected 'chance' for 'cueillir', got '%s'" % result)
		return false
	return true


func test_detect_field_se_faufiler() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var result: String = cs.detect_lexical_field("Se faufiler entre les ombres")
	if result != "finesse":
		push_error("Expected 'finesse' for 'se faufiler', got '%s'" % result)
		return false
	return true


func test_detect_field_ecouter() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var result: String = cs.detect_lexical_field("Ecouter le murmure du vent")
	if result != "perception":
		push_error("Expected 'perception' for 'ecouter', got '%s'" % result)
		return false
	return true


func test_detect_field_unknown_falls_back() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var result: String = cs.detect_lexical_field("Danser sous la lune")
	if result != MerlinConstants.ACTION_VERB_FALLBACK_FIELD:
		push_error("Expected fallback '%s' for unknown verb, got '%s'" % [MerlinConstants.ACTION_VERB_FALLBACK_FIELD, result])
		return false
	return true


func test_detect_field_empty_string() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var result: String = cs.detect_lexical_field("")
	if result != MerlinConstants.ACTION_VERB_FALLBACK_FIELD:
		push_error("Expected fallback for empty string, got '%s'" % result)
		return false
	return true


func test_detect_field_case_insensitive() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var result: String = cs.detect_lexical_field("COMBATTRE LE DRAGON")
	if result != "vigueur":
		push_error("Expected 'vigueur' for uppercase 'COMBATTRE', got '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN CARD SYSTEM — _trust_tier_to_index
# ═══════════════════════════════════════════════════════════════════════════════

func test_trust_tier_T0() -> bool:
	var result: int = MerlinCardSystem._trust_tier_to_index("T0")
	if result != 0:
		push_error("T0 should map to 0, got %d" % result)
		return false
	return true


func test_trust_tier_T1() -> bool:
	var result: int = MerlinCardSystem._trust_tier_to_index("T1")
	if result != 1:
		push_error("T1 should map to 1, got %d" % result)
		return false
	return true


func test_trust_tier_T2() -> bool:
	var result: int = MerlinCardSystem._trust_tier_to_index("T2")
	if result != 2:
		push_error("T2 should map to 2, got %d" % result)
		return false
	return true


func test_trust_tier_T3() -> bool:
	var result: int = MerlinCardSystem._trust_tier_to_index("T3")
	if result != 3:
		push_error("T3 should map to 3, got %d" % result)
		return false
	return true


func test_trust_tier_unknown() -> bool:
	var result: int = MerlinCardSystem._trust_tier_to_index("T99")
	if result != 0:
		push_error("Unknown tier should map to 0, got %d" % result)
		return false
	return true


func test_trust_tier_empty() -> bool:
	var result: int = MerlinCardSystem._trust_tier_to_index("")
	if result != 0:
		push_error("Empty tier should map to 0, got %d" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN CARD SYSTEM — handle_merlin_direct
# ═══════════════════════════════════════════════════════════════════════════════

func test_merlin_direct_valid_option() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs.handle_merlin_direct(card, 0)
	if not result.get("ok", false):
		push_error("Expected ok=true for valid option index 0")
		return false
	if float(result.get("multiplier", 0.0)) != 1.0:
		push_error("Expected multiplier=1.0, got %f" % float(result.get("multiplier", 0.0)))
		return false
	if not result.get("skip_minigame", false):
		push_error("Expected skip_minigame=true")
		return false
	return true


func test_merlin_direct_returns_effects() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs.handle_merlin_direct(card, 1)
	if not result.get("ok", false):
		push_error("Expected ok=true for option 1")
		return false
	var effects: Array = result.get("effects", [])
	if effects.size() != 1:
		push_error("Expected 1 effect, got %d" % effects.size())
		return false
	var eff: Dictionary = effects[0]
	if str(eff.get("type", "")) != "HEAL_LIFE":
		push_error("Expected HEAL_LIFE effect, got '%s'" % str(eff.get("type", "")))
		return false
	return true


func test_merlin_direct_negative_index() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs.handle_merlin_direct(card, -1)
	if result.get("ok", true):
		push_error("Expected ok=false for negative index")
		return false
	return true


func test_merlin_direct_out_of_bounds() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs.handle_merlin_direct(card, 10)
	if result.get("ok", true):
		push_error("Expected ok=false for out-of-bounds index")
		return false
	if str(result.get("error", "")).is_empty():
		push_error("Expected error message for out-of-bounds")
		return false
	return true


func test_merlin_direct_empty_options() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {"options": []}
	var result: Dictionary = cs.handle_merlin_direct(card, 0)
	if result.get("ok", true):
		push_error("Expected ok=false for empty options")
		return false
	return true


func test_merlin_direct_last_option() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs.handle_merlin_direct(card, 2)
	if not result.get("ok", false):
		push_error("Expected ok=true for last option (index 2)")
		return false
	var effects: Array = result.get("effects", [])
	if effects.size() != 1:
		push_error("Expected 1 effect for option 2, got %d" % effects.size())
		return false
	if str(effects[0].get("type", "")) != "ADD_REPUTATION":
		push_error("Expected ADD_REPUTATION effect for option 2")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN CARD SYSTEM — apply_ogham_narrative
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_nuin_replaces_worst() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs.apply_ogham_narrative("nuin", card)
	if str(result.get("ogham_modified", "")) != "nuin":
		push_error("Expected ogham_modified='nuin'")
		return false
	var options: Array = result.get("options", [])
	var found_sagesse: bool = false
	for opt in options:
		if str(opt.get("label", "")).find("Frene") >= 0:
			found_sagesse = true
			break
	if not found_sagesse:
		push_error("Expected nuin to replace worst option with Frene label")
		return false
	return true


func test_ogham_huath_reveals_effects() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs.apply_ogham_narrative("huath", card)
	if str(result.get("ogham_modified", "")) != "huath":
		push_error("Expected ogham_modified='huath'")
		return false
	var options: Array = result.get("options", [])
	for opt in options:
		if not opt.get("effects_visible", false):
			push_error("huath should set effects_visible=true on all options")
			return false
	return true


func test_ogham_ioho_adds_ankou_rep() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs.apply_ogham_narrative("ioho", card)
	if str(result.get("ogham_modified", "")) != "ioho":
		push_error("Expected ogham_modified='ioho'")
		return false
	var options: Array = result.get("options", [])
	for opt in options:
		var effects: Array = opt.get("effects", [])
		var has_ankou: bool = false
		for eff in effects:
			if str(eff.get("type", "")) == "ADD_REPUTATION" and str(eff.get("faction", "")) == "ankou":
				has_ankou = true
				break
		if not has_ankou:
			push_error("ioho should add ankou reputation to every option")
			return false
	return true


func test_ogham_unknown_no_modification() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs.apply_ogham_narrative("beith", card)
	if result.has("ogham_modified"):
		push_error("Unknown ogham should not set ogham_modified")
		return false
	return true


func test_ogham_nuin_does_not_mutate_original() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card()
	var original_label: String = str(card["options"][0]["label"])
	var _result: Dictionary = cs.apply_ogham_narrative("nuin", card)
	var after_label: String = str(card["options"][0]["label"])
	if original_label != after_label:
		push_error("apply_ogham_narrative should not mutate the original card")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN CARD SYSTEM — _find_worst_option
# ═══════════════════════════════════════════════════════════════════════════════

func test_find_worst_damage_option() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var options: Array = [
		{"effects": [{"type": "HEAL_LIFE", "amount": 10}]},
		{"effects": [{"type": "DAMAGE_LIFE", "amount": 8}]},
		{"effects": [{"type": "HEAL_LIFE", "amount": 2}]},
	]
	var idx: int = cs._find_worst_option(options)
	if idx != 1:
		push_error("Expected worst option at index 1 (DAMAGE_LIFE), got %d" % idx)
		return false
	return true


func test_find_worst_mixed_effects() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var options: Array = [
		{"effects": [{"type": "HEAL_LIFE", "amount": 5}, {"type": "ADD_REPUTATION", "faction": "druides", "amount": 10}]},
		{"effects": [{"type": "DAMAGE_LIFE", "amount": 3}]},
		{"effects": [{"type": "HEAL_LIFE", "amount": 1}]},
	]
	# option 0: 5 + 10*0.5 = 10
	# option 1: -3
	# option 2: 1
	var idx: int = cs._find_worst_option(options)
	if idx != 1:
		push_error("Expected worst option at index 1, got %d" % idx)
		return false
	return true


func test_find_worst_all_healing() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var options: Array = [
		{"effects": [{"type": "HEAL_LIFE", "amount": 10}]},
		{"effects": [{"type": "HEAL_LIFE", "amount": 5}]},
		{"effects": [{"type": "HEAL_LIFE", "amount": 1}]},
	]
	var idx: int = cs._find_worst_option(options)
	if idx != 2:
		push_error("Expected worst at index 2 (lowest heal), got %d" % idx)
		return false
	return true


func test_find_worst_empty_effects() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var options: Array = [
		{"effects": []},
		{"effects": [{"type": "DAMAGE_LIFE", "amount": 5}]},
		{"effects": [{"type": "HEAL_LIFE", "amount": 3}]},
	]
	# option 0: score=0, option 1: score=-5, option 2: score=3
	var idx: int = cs._find_worst_option(options)
	if idx != 1:
		push_error("Expected worst at index 1, got %d" % idx)
		return false
	return true


func test_find_worst_reputation_weight() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var options: Array = [
		{"effects": [{"type": "ADD_REPUTATION", "faction": "korrigans", "amount": -20}]},
		{"effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 10}]},
		{"effects": [{"type": "HEAL_LIFE", "amount": 2}]},
	]
	# option 0: -20*0.5 = -10, option 1: 10*0.5 = 5, option 2: 2
	var idx: int = cs._find_worst_option(options)
	if idx != 0:
		push_error("Expected worst at index 0 (large negative rep), got %d" % idx)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN CARD SYSTEM — check_run_end
# ═══════════════════════════════════════════════════════════════════════════════

func test_check_run_end_death() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = {"life_essence": 0, "card_index": 5}
	var result: Dictionary = cs.check_run_end(state)
	if not result.get("ended", false):
		push_error("Expected ended=true for life=0")
		return false
	if str(result.get("reason", "")) != "death":
		push_error("Expected reason='death', got '%s'" % str(result.get("reason", "")))
		return false
	return true


func test_check_run_end_negative_life() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = {"life_essence": -5, "card_index": 3}
	var result: Dictionary = cs.check_run_end(state)
	if not result.get("ended", false):
		push_error("Expected ended=true for negative life")
		return false
	if str(result.get("reason", "")) != "death":
		push_error("Expected reason='death'")
		return false
	return true


func test_check_run_end_hard_max() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = {"life_essence": 50, "card_index": 50}
	var result: Dictionary = cs.check_run_end(state)
	if not result.get("ended", false):
		push_error("Expected ended=true for card_index=50 (hard_max)")
		return false
	if str(result.get("reason", "")) != "hard_max":
		push_error("Expected reason='hard_max', got '%s'" % str(result.get("reason", "")))
		return false
	return true


func test_check_run_end_beyond_hard_max() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = {"life_essence": 80, "card_index": 99}
	var result: Dictionary = cs.check_run_end(state)
	if not result.get("ended", false):
		push_error("Expected ended=true for card_index=99")
		return false
	return true


func test_check_run_end_none_zone() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = {"life_essence": 100, "card_index": 3}
	var result: Dictionary = cs.check_run_end(state)
	if result.get("ended", true):
		push_error("Expected ended=false for card_index=3")
		return false
	if str(result.get("tension_zone", "")) != "none":
		push_error("Expected tension_zone='none' for card_index=3, got '%s'" % str(result.get("tension_zone", "")))
		return false
	return true


func test_check_run_end_low_zone() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = {"life_essence": 80, "card_index": 10}
	var result: Dictionary = cs.check_run_end(state)
	if result.get("ended", true):
		push_error("Expected ended=false")
		return false
	if str(result.get("tension_zone", "")) != "low":
		push_error("Expected tension_zone='low' for card_index=10, got '%s'" % str(result.get("tension_zone", "")))
		return false
	if not result.get("early_zone", false):
		push_error("Expected early_zone=true for low zone")
		return false
	return true


func test_check_run_end_rising_zone() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = {"life_essence": 80, "card_index": 22}
	var result: Dictionary = cs.check_run_end(state)
	if str(result.get("tension_zone", "")) != "rising":
		push_error("Expected tension_zone='rising' for card_index=22, got '%s'" % str(result.get("tension_zone", "")))
		return false
	if not result.get("convergence_zone", false):
		push_error("Expected convergence_zone=true for rising")
		return false
	return true


func test_check_run_end_high_zone() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = {"life_essence": 80, "card_index": 30}
	var result: Dictionary = cs.check_run_end(state)
	if str(result.get("tension_zone", "")) != "high":
		push_error("Expected tension_zone='high' for card_index=30, got '%s'" % str(result.get("tension_zone", "")))
		return false
	return true


func test_check_run_end_critical_zone() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = {"life_essence": 80, "card_index": 42}
	var result: Dictionary = cs.check_run_end(state)
	if str(result.get("tension_zone", "")) != "critical":
		push_error("Expected tension_zone='critical' for card_index=42, got '%s'" % str(result.get("tension_zone", "")))
		return false
	if not result.get("convergence_zone", false):
		push_error("Expected convergence_zone=true for critical")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN CARD SYSTEM — resolve_card
# ═══════════════════════════════════════════════════════════════════════════════

func test_resolve_card_valid() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs.resolve_card(state, card, 0, 80)
	if not result.get("ok", false):
		push_error("Expected ok=true for valid resolve")
		return false
	var effects: Array = result.get("effects", [])
	if effects.is_empty():
		push_error("Expected at least one applied effect")
		return false
	return true


func test_resolve_card_increments_card_index() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card()
	var before_index: int = int(state.get("card_index", 0))
	var _result: Dictionary = cs.resolve_card(state, card, 0, 50)
	var after_index: int = int(state.get("card_index", 0))
	if after_index != before_index + 1:
		push_error("Expected card_index to increment by 1, was %d, now %d" % [before_index, after_index])
		return false
	return true


func test_resolve_card_increments_cards_played() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card()
	var before: int = int(state.get("cards_played", 0))
	var _result: Dictionary = cs.resolve_card(state, card, 1, 50)
	var after: int = int(state.get("cards_played", 0))
	if after != before + 1:
		push_error("Expected cards_played to increment by 1")
		return false
	return true


func test_resolve_card_invalid_index_negative() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs.resolve_card(state, card, -1, 50)
	if result.get("ok", true):
		push_error("Expected ok=false for negative index")
		return false
	return true


func test_resolve_card_invalid_index_too_high() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs.resolve_card(state, card, 99, 50)
	if result.get("ok", true):
		push_error("Expected ok=false for index=99")
		return false
	return true


func test_resolve_card_story_log_appended() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card()
	var _result: Dictionary = cs.resolve_card(state, card, 0, 75)
	var log: Array = state.get("story_log", [])
	if log.size() != 1:
		push_error("Expected story_log to have 1 entry, got %d" % log.size())
		return false
	var entry: Dictionary = log[0]
	if str(entry.get("card_id", "")) != "test_card_001":
		push_error("Expected card_id='test_card_001' in log entry")
		return false
	if int(entry.get("option_index", -1)) != 0:
		push_error("Expected option_index=0 in log entry")
		return false
	return true


func test_resolve_card_merlin_direct_multiplier() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card()
	card["type"] = "merlin_direct"
	var result: Dictionary = cs.resolve_card(state, card, 0, 0)
	if float(result.get("multiplier", 0.0)) != 1.0:
		push_error("Merlin direct should always have multiplier=1.0, got %f" % float(result.get("multiplier", 0.0)))
		return false
	return true


func test_resolve_card_story_log_capped_at_50() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card()
	# Pre-fill story_log with 55 entries
	var big_log: Array = []
	for i in range(55):
		big_log.append({"card_id": "old_%d" % i, "option_index": 0, "score": 50, "multiplier": 1.0, "effects_count": 0})
	state["story_log"] = big_log
	var _result: Dictionary = cs.resolve_card(state, card, 0, 50)
	var final_log: Array = state.get("story_log", [])
	if final_log.size() > 50:
		push_error("Expected story_log capped at 50, got %d" % final_log.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN CARD SYSTEM — _process_card_tags
# ═══════════════════════════════════════════════════════════════════════════════

func test_process_card_tags_adds_tags() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = _make_run_state()
	var card: Dictionary = _make_card()
	cs._process_card_tags(state, card)
	var tags: Array = state.get("active_tags", [])
	if not tags.has("test_tag"):
		push_error("Expected 'test_tag' in active_tags")
		return false
	return true


func test_process_card_tags_no_duplicates() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = _make_run_state()
	state["active_tags"] = ["test_tag"]
	var card: Dictionary = _make_card()
	cs._process_card_tags(state, card)
	var tags: Array = state.get("active_tags", [])
	var count: int = 0
	for t in tags:
		if str(t) == "test_tag":
			count += 1
	if count != 1:
		push_error("Expected exactly 1 'test_tag', got %d" % count)
		return false
	return true


func test_process_card_tags_empty_tags() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = _make_run_state()
	var card: Dictionary = {"tags": []}
	cs._process_card_tags(state, card)
	var tags: Array = state.get("active_tags", [])
	if tags.size() != 0:
		push_error("Expected 0 tags for card with empty tags, got %d" % tags.size())
		return false
	return true


func test_process_card_tags_no_tags_key() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var state: Dictionary = _make_run_state()
	var card: Dictionary = {"id": "no_tags_card"}
	cs._process_card_tags(state, card)
	var tags: Array = state.get("active_tags", [])
	if tags.size() != 0:
		push_error("Expected 0 tags for card without tags key, got %d" % tags.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN CARD SYSTEM — _validate_card
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_card_valid() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"text": "Un druide s'approche.",
		"options": [
			{"label": "Parler"},
			{"label": "Fuir"},
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if not result.get("valid", false):
		push_error("Expected valid=true for valid card, got error: '%s'" % str(result.get("error", "")))
		return false
	return true


func test_validate_card_missing_text() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"options": [{"label": "A"}, {"label": "B"}],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for missing text")
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
		push_error("Expected valid=false for empty text")
		return false
	return true


func test_validate_card_too_few_options() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"text": "Some text.",
		"options": [{"label": "Only one"}],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for <2 options")
		return false
	return true


func test_validate_card_option_missing_label() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"text": "Some text.",
		"options": [{"label": "A"}, {"effects": []}],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for option missing label")
		return false
	return true


func test_validate_card_non_dict_option() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {
		"text": "Some text.",
		"options": [{"label": "A"}, "not_a_dict"],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for non-dict option")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN CARD SYSTEM — _ensure_3_options
# ═══════════════════════════════════════════════════════════════════════════════

func test_ensure_3_options_already_3() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = _make_card()
	var result: Dictionary = cs._ensure_3_options(card)
	var options: Array = result.get("options", [])
	if options.size() != 3:
		push_error("Expected 3 options, got %d" % options.size())
		return false
	return true


func test_ensure_3_options_pads_from_1() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {"options": [{"label": "Solo"}]}
	var result: Dictionary = cs._ensure_3_options(card)
	var options: Array = result.get("options", [])
	if options.size() != 3:
		push_error("Expected 3 options after padding, got %d" % options.size())
		return false
	# First should be original
	if str(options[0].get("label", "")) != "Solo":
		push_error("First option should be preserved")
		return false
	# Padded ones should have default label
	if str(options[1].get("label", "")) != "Attendre et observer":
		push_error("Padded option should have default label")
		return false
	return true


func test_ensure_3_options_pads_from_0() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {"options": []}
	var result: Dictionary = cs._ensure_3_options(card)
	var options: Array = result.get("options", [])
	if options.size() != 3:
		push_error("Expected 3 padded options, got %d" % options.size())
		return false
	return true


func test_ensure_3_options_trims_from_5() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {"options": [
		{"label": "A"}, {"label": "B"}, {"label": "C"}, {"label": "D"}, {"label": "E"},
	]}
	var result: Dictionary = cs._ensure_3_options(card)
	var options: Array = result.get("options", [])
	if options.size() != 3:
		push_error("Expected trimmed to 3 options, got %d" % options.size())
		return false
	if str(options[2].get("label", "")) != "C":
		push_error("Third option should be 'C' after trim")
		return false
	return true


func test_ensure_3_options_does_not_mutate_original() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = {"options": [{"label": "Only"}]}
	var _result: Dictionary = cs._ensure_3_options(card)
	# Original should still have 1 option
	if card["options"].size() != 1:
		push_error("Original card should not be mutated")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN CARD SYSTEM — _get_emergency_card
# ═══════════════════════════════════════════════════════════════════════════════

func test_emergency_card_has_required_keys() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = cs._get_emergency_card()
	if not card.has("id"):
		push_error("Emergency card missing 'id'")
		return false
	if not card.has("type"):
		push_error("Emergency card missing 'type'")
		return false
	if not card.has("text"):
		push_error("Emergency card missing 'text'")
		return false
	if not card.has("options"):
		push_error("Emergency card missing 'options'")
		return false
	return true


func test_emergency_card_has_3_options() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = cs._get_emergency_card()
	var options: Array = card.get("options", [])
	if options.size() != 3:
		push_error("Emergency card should have 3 options, got %d" % options.size())
		return false
	return true


func test_emergency_card_type_is_narrative() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = cs._get_emergency_card()
	if str(card.get("type", "")) != "narrative":
		push_error("Emergency card type should be 'narrative'")
		return false
	return true


func test_emergency_card_options_have_effects() -> bool:
	var cs: MerlinCardSystem = _make_card_system()
	var card: Dictionary = cs._get_emergency_card()
	for opt in card.get("options", []):
		var effects: Array = opt.get("effects", [])
		if effects.is_empty():
			push_error("Emergency card option should have effects")
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — is_llm_ready
# ═══════════════════════════════════════════════════════════════════════════════

func test_llm_not_ready_without_ai() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	if llm.is_llm_ready():
		push_error("Expected is_llm_ready()=false when no AI wired")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — build_narrative_context
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_narrative_context_basic() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var state: Dictionary = {
		"run": _make_run_state(),
		"meta": {"talent_tree": {"unlocked": []}},
		"flags": {},
	}
	var ctx: Dictionary = llm.build_narrative_context(state)
	if not ctx.has("biome"):
		push_error("Missing 'biome' in narrative context")
		return false
	if not ctx.has("life_essence"):
		push_error("Missing 'life_essence'")
		return false
	if not ctx.has("factions"):
		push_error("Missing 'factions'")
		return false
	if not ctx.has("player_tendency"):
		push_error("Missing 'player_tendency'")
		return false
	return true


func test_build_narrative_context_extracts_life() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var run: Dictionary = _make_run_state()
	run["life_essence"] = 42
	var state: Dictionary = {"run": run, "meta": {"talent_tree": {"unlocked": []}}, "flags": {}}
	var ctx: Dictionary = llm.build_narrative_context(state)
	if int(ctx.get("life_essence", 0)) != 42:
		push_error("Expected life_essence=42, got %d" % int(ctx.get("life_essence", 0)))
		return false
	return true


func test_build_narrative_context_extracts_biome() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var run: Dictionary = _make_run_state()
	run["current_biome"] = "lande_sauvage"
	var state: Dictionary = {"run": run, "meta": {"talent_tree": {"unlocked": []}}, "flags": {}}
	var ctx: Dictionary = llm.build_narrative_context(state)
	if str(ctx.get("biome", "")) != "lande_sauvage":
		push_error("Expected biome='lande_sauvage', got '%s'" % str(ctx.get("biome", "")))
		return false
	return true


func test_build_narrative_context_extracts_karma() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var run: Dictionary = _make_run_state()
	run["hidden"] = {"karma": 7, "tension": 0, "player_profile": {"audace": 0, "prudence": 0}}
	var state: Dictionary = {"run": run, "meta": {"talent_tree": {"unlocked": []}}, "flags": {}}
	var ctx: Dictionary = llm.build_narrative_context(state)
	if int(ctx.get("karma", 0)) != 7:
		push_error("Expected karma=7, got %d" % int(ctx.get("karma", 0)))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — build_context
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_context_basic() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var state: Dictionary = {"run": _make_run_state(), "flags": {}}
	var ctx: Dictionary = llm.build_context(state)
	if not ctx.has("life_essence"):
		push_error("Missing 'life_essence' in context")
		return false
	if not ctx.has("factions"):
		push_error("Missing 'factions'")
		return false
	if not ctx.has("day"):
		push_error("Missing 'day'")
		return false
	if not ctx.has("cards_played"):
		push_error("Missing 'cards_played'")
		return false
	return true


func test_build_context_life_value() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var run: Dictionary = _make_run_state()
	run["life_essence"] = 77
	var state: Dictionary = {"run": run, "flags": {}}
	var ctx: Dictionary = llm.build_context(state)
	if int(ctx.get("life_essence", 0)) != 77:
		push_error("Expected life_essence=77, got %d" % int(ctx.get("life_essence", 0)))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — _build_faction_status_string
# ═══════════════════════════════════════════════════════════════════════════════

func test_faction_status_empty_tiers() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var state: Dictionary = {"run": {"faction_context": {"tiers": {}}}}
	var result: String = llm._build_faction_status_string(state)
	if not result.is_empty():
		push_error("Expected empty string for empty tiers, got '%s'" % result)
		return false
	return true


func test_faction_status_all_neutre() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var state: Dictionary = {"run": {"faction_context": {"tiers": {"druides": "neutre", "anciens": "neutre", "korrigans": "neutre", "niamh": "neutre", "ankou": "neutre"}}}}
	var result: String = llm._build_faction_status_string(state)
	if not result.is_empty():
		push_error("Expected empty string when all factions are neutre")
		return false
	return true


func test_faction_status_with_non_neutre() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var state: Dictionary = {"run": {"faction_context": {"tiers": {"druides": "honore", "anciens": "neutre", "korrigans": "hostile", "niamh": "neutre", "ankou": "neutre"}}}}
	var result: String = llm._build_faction_status_string(state)
	if result.is_empty():
		push_error("Expected non-empty string for non-neutre tiers")
		return false
	if result.find("Relations:") < 0:
		push_error("Expected 'Relations:' prefix in status string")
		return false
	if result.find("honore") < 0:
		push_error("Expected 'honore' in status string")
		return false
	return true


func test_faction_status_no_run_key() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var state: Dictionary = {}
	var result: String = llm._build_faction_status_string(state)
	if not result.is_empty():
		push_error("Expected empty string for missing run key")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — _get_player_tendency
# ═══════════════════════════════════════════════════════════════════════════════

func test_player_tendency_neutre_equal() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var hidden: Dictionary = {"player_profile": {"audace": 5, "prudence": 5}}
	var result: String = llm._get_player_tendency(hidden)
	if result != "neutre":
		push_error("Expected 'neutre' for equal audace/prudence, got '%s'" % result)
		return false
	return true


func test_player_tendency_agressif() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var hidden: Dictionary = {"player_profile": {"audace": 10, "prudence": 2}}
	var result: String = llm._get_player_tendency(hidden)
	if result != "agressif":
		push_error("Expected 'agressif' for audace>>prudence, got '%s'" % result)
		return false
	return true


func test_player_tendency_prudent() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var hidden: Dictionary = {"player_profile": {"audace": 1, "prudence": 8}}
	var result: String = llm._get_player_tendency(hidden)
	if result != "prudent":
		push_error("Expected 'prudent' for prudence>>audace, got '%s'" % result)
		return false
	return true


func test_player_tendency_neutre_small_gap() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var hidden: Dictionary = {"player_profile": {"audace": 7, "prudence": 5}}
	var result: String = llm._get_player_tendency(hidden)
	if result != "neutre":
		push_error("Expected 'neutre' for gap=2 (<=3), got '%s'" % result)
		return false
	return true


func test_player_tendency_empty_profile() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var hidden: Dictionary = {}
	var result: String = llm._get_player_tendency(hidden)
	if result != "neutre":
		push_error("Expected 'neutre' for missing profile, got '%s'" % result)
		return false
	return true


func test_player_tendency_threshold_exact() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	# audace=4, prudence=0: diff=4 > 3, should be agressif
	var hidden: Dictionary = {"player_profile": {"audace": 4, "prudence": 0}}
	var result: String = llm._get_player_tendency(hidden)
	if result != "agressif":
		push_error("Expected 'agressif' for audace=4, prudence=0 (diff=4>3), got '%s'" % result)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — _get_recent_story_log
# ═══════════════════════════════════════════════════════════════════════════════

func test_recent_story_log_empty() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var result: Array = llm._get_recent_story_log([], 5)
	if result.size() != 0:
		push_error("Expected empty array for empty log")
		return false
	return true


func test_recent_story_log_fewer_than_count() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var log: Array = [{"id": "a"}, {"id": "b"}]
	var result: Array = llm._get_recent_story_log(log, 5)
	if result.size() != 2:
		push_error("Expected 2 entries, got %d" % result.size())
		return false
	return true


func test_recent_story_log_exact_count() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var log: Array = [{"id": "a"}, {"id": "b"}, {"id": "c"}]
	var result: Array = llm._get_recent_story_log(log, 3)
	if result.size() != 3:
		push_error("Expected 3 entries, got %d" % result.size())
		return false
	return true


func test_recent_story_log_slices_last_n() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var log: Array = [{"id": "a"}, {"id": "b"}, {"id": "c"}, {"id": "d"}, {"id": "e"}]
	var result: Array = llm._get_recent_story_log(log, 2)
	if result.size() != 2:
		push_error("Expected 2 entries, got %d" % result.size())
		return false
	if str(result[0].get("id", "")) != "d":
		push_error("Expected first entry to be 'd', got '%s'" % str(result[0].get("id", "")))
		return false
	if str(result[1].get("id", "")) != "e":
		push_error("Expected second entry to be 'e', got '%s'" % str(result[1].get("id", "")))
		return false
	return true


func test_recent_story_log_does_not_mutate() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var log: Array = [{"id": "a"}, {"id": "b"}]
	var result: Array = llm._get_recent_story_log(log, 5)
	result.append({"id": "c"})
	if log.size() != 2:
		push_error("Original log should not be mutated")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — effects_to_codes
# ═══════════════════════════════════════════════════════════════════════════════

func test_effects_to_codes_heal() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var effects: Array = [{"type": "HEAL_LIFE", "amount": 5}]
	var codes: Array = llm.effects_to_codes(effects)
	if codes.size() != 1:
		push_error("Expected 1 code, got %d" % codes.size())
		return false
	if str(codes[0]) != "HEAL_LIFE:5":
		push_error("Expected 'HEAL_LIFE:5', got '%s'" % str(codes[0]))
		return false
	return true


func test_effects_to_codes_damage() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var effects: Array = [{"type": "DAMAGE_LIFE", "amount": 3}]
	var codes: Array = llm.effects_to_codes(effects)
	if codes.size() != 1:
		push_error("Expected 1 code, got %d" % codes.size())
		return false
	if str(codes[0]) != "DAMAGE_LIFE:3":
		push_error("Expected 'DAMAGE_LIFE:3', got '%s'" % str(codes[0]))
		return false
	return true


func test_effects_to_codes_reputation() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var effects: Array = [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 10}]
	var codes: Array = llm.effects_to_codes(effects)
	if codes.size() != 1:
		push_error("Expected 1 code, got %d" % codes.size())
		return false
	if str(codes[0]) != "ADD_REPUTATION:druides:10":
		push_error("Expected 'ADD_REPUTATION:druides:10', got '%s'" % str(codes[0]))
		return false
	return true


func test_effects_to_codes_multiple() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var effects: Array = [
		{"type": "HEAL_LIFE", "amount": 5},
		{"type": "DAMAGE_LIFE", "amount": 3},
		{"type": "ADD_REPUTATION", "faction": "ankou", "amount": -5},
	]
	var codes: Array = llm.effects_to_codes(effects)
	if codes.size() != 3:
		push_error("Expected 3 codes, got %d" % codes.size())
		return false
	return true


func test_effects_to_codes_empty() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var codes: Array = llm.effects_to_codes([])
	if codes.size() != 0:
		push_error("Expected 0 codes for empty effects")
		return false
	return true


func test_effects_to_codes_skips_non_dict() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var effects: Array = ["not_a_dict", {"type": "HEAL_LIFE", "amount": 1}]
	var codes: Array = llm.effects_to_codes(effects)
	if codes.size() != 1:
		push_error("Expected 1 code (skip non-dict), got %d" % codes.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — validate_scene (legacy)
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_scene_valid() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var scene: Dictionary = _make_legacy_scene()
	var result: Dictionary = llm.validate_scene(scene, null)
	if not result.get("ok", false):
		push_error("Expected ok=true for valid legacy scene")
		return false
	return true


func test_validate_scene_missing_key() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var scene: Dictionary = {
		"scene_id": "test",
		"biome": "foret",
		# Missing backdrop, text_pages, choices
	}
	var result: Dictionary = llm.validate_scene(scene, null)
	if result.get("ok", true):
		push_error("Expected ok=false for missing keys")
		return false
	var errors: Array = result.get("errors", [])
	if errors.is_empty():
		push_error("Expected at least one error message")
		return false
	return true


func test_validate_scene_preserves_scene_data() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var scene: Dictionary = _make_legacy_scene()
	var result: Dictionary = llm.validate_scene(scene, null)
	var validated: Dictionary = result.get("scene", {})
	if str(validated.get("scene_id", "")) != "test_001":
		push_error("Expected scene_id preserved in validated scene")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — get_category_llm_params
# ═══════════════════════════════════════════════════════════════════════════════

func test_category_llm_params_unknown_returns_defaults() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var params: Dictionary = llm.get_category_llm_params("nonexistent_category")
	if not params.has("max_tokens"):
		push_error("Expected 'max_tokens' in default params")
		return false
	if not params.has("temperature"):
		push_error("Expected 'temperature' in default params")
		return false
	if int(params.get("max_tokens", 0)) != int(MerlinLlmAdapter.LLM_PARAMS.get("max_tokens", 0)):
		push_error("Expected default max_tokens value")
		return false
	return true


func test_category_llm_params_returns_dict() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var params: Dictionary = llm.get_category_llm_params("some_category")
	if params.is_empty():
		push_error("Expected non-empty params dict")
		return false
	return true


func test_category_llm_params_has_top_p() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var params: Dictionary = llm.get_category_llm_params("whatever")
	if not params.has("top_p"):
		push_error("Expected 'top_p' in params")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — build_category_system_prompt
# ═══════════════════════════════════════════════════════════════════════════════

func test_category_system_prompt_unknown_returns_fallback() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var prompt: String = llm.build_category_system_prompt("nonexistent_xyz")
	if prompt.is_empty():
		push_error("Expected non-empty fallback prompt for unknown category")
		return false
	return true


func test_category_system_prompt_returns_string() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var prompt: String = llm.build_category_system_prompt("some_category")
	if typeof(prompt) != TYPE_STRING:
		push_error("Expected string type for system prompt")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — Constants validation
# ═══════════════════════════════════════════════════════════════════════════════

func test_llm_adapter_has_allowed_effect_types() -> bool:
	var types: Array = MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	if types.is_empty():
		push_error("ALLOWED_EFFECT_TYPES should not be empty")
		return false
	if not types.has("HEAL_LIFE"):
		push_error("ALLOWED_EFFECT_TYPES should contain HEAL_LIFE")
		return false
	if not types.has("DAMAGE_LIFE"):
		push_error("ALLOWED_EFFECT_TYPES should contain DAMAGE_LIFE")
		return false
	if not types.has("ADD_REPUTATION"):
		push_error("ALLOWED_EFFECT_TYPES should contain ADD_REPUTATION")
		return false
	return true


func test_llm_adapter_factions_match_constants() -> bool:
	var llm_factions: Array = MerlinLlmAdapter.FACTIONS
	var const_factions: Array = MerlinConstants.FACTIONS
	if llm_factions.size() != const_factions.size():
		push_error("LlmAdapter FACTIONS size mismatch with Constants")
		return false
	for f in llm_factions:
		if not const_factions.has(f):
			push_error("Faction '%s' in LlmAdapter not found in Constants" % str(f))
			return false
	return true


func test_llm_adapter_version_not_empty() -> bool:
	if MerlinLlmAdapter.VERSION.is_empty():
		push_error("VERSION should not be empty")
		return false
	return true


func test_llm_adapter_narrative_fallbacks_not_empty() -> bool:
	var fb: Array = MerlinLlmAdapter.NARRATIVE_FALLBACKS
	if fb.is_empty():
		push_error("NARRATIVE_FALLBACKS should not be empty")
		return false
	for text in fb:
		if str(text).length() < 10:
			push_error("Fallback text too short: '%s'" % str(text))
			return false
	return true


func test_llm_adapter_generic_labels_count() -> bool:
	var labels: Array = MerlinLlmAdapter.GENERIC_LABELS
	if labels.size() != 3:
		push_error("Expected 3 generic labels, got %d" % labels.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — Module initialization
# ═══════════════════════════════════════════════════════════════════════════════

func test_llm_adapter_modules_initialized() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	if llm._json_repair == null:
		push_error("_json_repair should be initialized")
		return false
	if llm._prompts == null:
		push_error("_prompts should be initialized")
		return false
	if llm._sanitizer == null:
		push_error("_sanitizer should be initialized")
		return false
	if llm._validator == null:
		push_error("_validator should be initialized")
		return false
	if llm._game_master == null:
		push_error("_game_master should be initialized")
		return false
	return true


func test_llm_adapter_merlin_ai_null_by_default() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	if llm._merlin_ai != null:
		push_error("_merlin_ai should be null by default")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN LLM ADAPTER — validate_faction_card (delegation)
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_faction_card_valid() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var card: Dictionary = _make_valid_llm_card()
	var result: Dictionary = llm.validate_faction_card(card)
	if not result.get("ok", false):
		push_error("Expected ok=true for valid faction card, errors: %s" % str(result.get("errors", [])))
		return false
	return true


func test_validate_faction_card_missing_text() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var card: Dictionary = {
		"options": [
			{"label": "A", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
			{"label": "B", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
		],
	}
	var result: Dictionary = llm.validate_faction_card(card)
	if result.get("ok", true):
		push_error("Expected ok=false for missing text")
		return false
	return true


func test_validate_faction_card_empty_options() -> bool:
	var llm: MerlinLlmAdapter = _make_llm_adapter()
	var card: Dictionary = {
		"text": "Some narrative text.",
		"options": [],
	}
	var result: Dictionary = llm.validate_faction_card(card)
	if result.get("ok", true):
		push_error("Expected ok=false for empty options")
		return false
	return true
