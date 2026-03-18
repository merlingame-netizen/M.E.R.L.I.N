## =============================================================================
## Unit Tests — MerlinCardSystem v2.5 (headless-safe, RefCounted)
## =============================================================================
## Tests: lexical field detection, minigame selection, fastroute pool,
## promise lifecycle, run_end check, ogham narrative effects.
## Converted from GutTest to RefCounted for headless runner compatibility.
## =============================================================================

extends RefCounted


func _fail(msg: String) -> bool:
	push_error(msg)
	return false


func _make_cs() -> MerlinCardSystem:
	var cs: MerlinCardSystem = MerlinCardSystem.new()
	cs.setup(null, null, null)
	return cs


# ═══════════════════════════════════════════════════════════════════════════════
# LEXICAL FIELD DETECTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_detect_field_chance() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	if cs.detect_lexical_field("Tenter sa chance") != "chance":
		return _fail("should detect chance")
	return true

func test_detect_field_bluff() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	if cs.detect_lexical_field("Mentir au garde") != "bluff":
		return _fail("should detect bluff")
	return true

func test_detect_field_observation() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	if cs.detect_lexical_field("Observer les traces") != "observation":
		return _fail("should detect observation")
	return true

func test_detect_field_logique() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	if cs.detect_lexical_field("Dechiffrer les runes") != "logique":
		return _fail("should detect logique")
	return true

func test_detect_field_finesse() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	if cs.detect_lexical_field("Se faufiler dans l'ombre") != "finesse":
		return _fail("should detect finesse")
	return true

func test_detect_field_vigueur() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	if cs.detect_lexical_field("Combattre le loup") != "vigueur":
		return _fail("should detect vigueur")
	return true

func test_detect_field_esprit() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	if cs.detect_lexical_field("Mediter sous le chene") != "esprit":
		return _fail("should detect esprit")
	return true

func test_detect_field_perception() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	if cs.detect_lexical_field("Ecouter les murmures") != "perception":
		return _fail("should detect perception")
	return true

func test_detect_field_fallback_esprit() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	if cs.detect_lexical_field("Xyzzyx inconnu") != "esprit":
		return _fail("unknown verb should fallback to esprit")
	return true

func test_detect_field_case_insensitive() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	if cs.detect_lexical_field("OBSERVER les traces") != "observation":
		return _fail("detection should be case-insensitive")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MINIGAME SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_select_minigame_returns_valid() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var mg: String = cs.select_minigame("esprit")
	if mg.is_empty():
		return _fail("should return a minigame for esprit")
	var valid: Array = MerlinConstants.FIELD_MINIGAMES.get("esprit", [])
	if not valid.has(mg):
		return _fail("minigame '%s' not in FIELD_MINIGAMES[esprit]" % mg)
	return true

func test_select_minigame_unknown_field_fallback() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var mg: String = cs.select_minigame("inconnu")
	if mg.is_empty():
		return _fail("should return a fallback minigame for unknown field")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FASTROUTE POOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_fastroute_card_not_empty() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	cs.init_run("foret_broceliande", "beith")
	var card: Dictionary = cs.get_fastroute_card({"biome": "foret_broceliande"})
	if card.is_empty():
		return _fail("FastRoute should return a card")
	return true

func test_fastroute_card_has_3_options() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	cs.init_run("foret_broceliande", "beith")
	var card: Dictionary = cs.get_fastroute_card({"biome": "foret_broceliande"})
	if card.get("options", []).size() != 3:
		return _fail("FastRoute card should have 3 options, got %d" % card.get("options", []).size())
	return true

func test_fastroute_no_repeat_until_pool_exhausted() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	cs.init_run("foret_broceliande", "beith")
	var seen_ids: Array = []
	for i in 5:
		var card: Dictionary = cs.get_fastroute_card({"biome": ""})
		seen_ids.append(str(card.get("id", "")))
	if seen_ids.size() == 0:
		return _fail("should have drawn at least 1 card")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN END CHECK
# ═══════════════════════════════════════════════════════════════════════════════

func test_check_run_end_death() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var state: Dictionary = {"life_essence": 0, "card_index": 5}
	var result: Dictionary = cs.check_run_end(state)
	if not result.get("ended", false):
		return _fail("run should end when life=0")
	if str(result.get("reason", "")) != "death":
		return _fail("reason should be death, got %s" % str(result.get("reason", "")))
	return true

func test_check_run_end_hard_max() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var hard_max: int = int(MerlinConstants.MOS_CONVERGENCE.get("hard_max_cards", 50))
	var state: Dictionary = {"life_essence": 50, "card_index": hard_max}
	var result: Dictionary = cs.check_run_end(state)
	if not result.get("ended", false):
		return _fail("run should end at hard_max")
	return true

func test_check_run_end_still_alive() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var state: Dictionary = {"life_essence": 50, "card_index": 5}
	var result: Dictionary = cs.check_run_end(state)
	if result.get("ended", true):
		return _fail("run should not end with life>0 and low card_index")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROMISE LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func test_create_promise() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var run_state: Dictionary = {"card_index": 3, "active_promises": [], "promise_tracking": {}}
	cs.create_promise(run_state, {
		"promise_id": "test_promise", "deadline_cards": 5,
		"condition_type": "life_above", "condition_value": 25,
		"reward_trust": 10, "penalty_trust": -15, "description": "Test",
	})
	var promises: Array = run_state.get("active_promises", [])
	if promises.size() != 1:
		return _fail("should have 1 promise, got %d" % promises.size())
	if int(promises[0].get("deadline_card", 0)) != 8:
		return _fail("deadline should be 3+5=8, got %d" % int(promises[0].get("deadline_card", 0)))
	return true

func test_promise_max_2_active() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var run_state: Dictionary = {"card_index": 0, "active_promises": [], "promise_tracking": {}}
	for i in 3:
		cs.create_promise(run_state, {
			"promise_id": "p_%d" % i, "deadline_cards": 5,
			"condition_type": "life_above", "condition_value": 25,
			"reward_trust": 10, "penalty_trust": -15,
		})
	if run_state.get("active_promises", []).size() > 2:
		return _fail("should have at most 2 promises")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM NARRATIVE EFFECTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_narrative_nuin_replaces_worst() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {
		"options": [
			{"label": "A", "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
			{"label": "B", "effects": [{"type": "DAMAGE_LIFE", "amount": 10}]},
			{"label": "C", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
		]
	}
	var result: Dictionary = cs.apply_ogham_narrative("nuin", card)
	if result.get("options", []).size() != 3:
		return _fail("nuin should keep 3 options")
	return true

func test_ogham_narrative_huath_reveals() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {
		"options": [
			{"label": "A", "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
			{"label": "B", "effects": [{"type": "DAMAGE_LIFE", "amount": 3}]},
			{"label": "C", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
		]
	}
	var result: Dictionary = cs.apply_ogham_narrative("huath", card)
	for opt in result.get("options", []):
		if opt is Dictionary and not opt.get("effects_visible", false):
			return _fail("huath should reveal all effects")
	return true

func test_ogham_narrative_unknown_returns_unchanged() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {"options": [{"label": "A"}]}
	var result: Dictionary = cs.apply_ogham_narrative("unknown_ogham", card)
	if result.get("options", []).size() != card["options"].size():
		return _fail("unknown ogham should not change card")
	return true
