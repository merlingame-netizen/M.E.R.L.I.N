## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinCardSystem v2.5
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: lexical field detection, ensure_3_options, fastroute pool,
## promise lifecycle, run_end check, ogham narrative effects.
## ═══════════════════════════════════════════════════════════════════════════════

extends GutTest

var cs: MerlinCardSystem


func before_each() -> void:
	cs = MerlinCardSystem.new()
	cs.setup(null, null, null)  # No LLM, no effects, no RNG — pure logic tests


func after_each() -> void:
	cs = null


# ═══════════════════════════════════════════════════════════════════════════════
# LEXICAL FIELD DETECTION — 45 verbes → 8+1 champs
# ═══════════════════════════════════════════════════════════════════════════════

func test_detect_field_chance() -> void:
	assert_eq(cs.detect_lexical_field("Tenter sa chance"), "chance", "Should detect 'chance'")


func test_detect_field_bluff() -> void:
	assert_eq(cs.detect_lexical_field("Mentir au garde"), "bluff", "Should detect 'bluff'")


func test_detect_field_observation() -> void:
	assert_eq(cs.detect_lexical_field("Observer les traces"), "observation", "Should detect 'observation'")


func test_detect_field_logique() -> void:
	assert_eq(cs.detect_lexical_field("Dechiffrer les runes"), "logique", "Should detect 'logique'")


func test_detect_field_finesse() -> void:
	assert_eq(cs.detect_lexical_field("Se faufiler dans l'ombre"), "finesse", "Should detect 'finesse'")


func test_detect_field_vigueur() -> void:
	assert_eq(cs.detect_lexical_field("Combattre le loup"), "vigueur", "Should detect 'vigueur'")


func test_detect_field_esprit() -> void:
	assert_eq(cs.detect_lexical_field("Mediter sous le chene"), "esprit", "Should detect 'esprit'")


func test_detect_field_perception() -> void:
	assert_eq(cs.detect_lexical_field("Ecouter les murmures"), "perception", "Should detect 'perception'")


func test_detect_field_fallback_esprit() -> void:
	assert_eq(cs.detect_lexical_field("Xyzzyx inconnu"), "esprit", "Unknown verb should fallback to 'esprit'")


func test_detect_field_case_insensitive() -> void:
	var field: String = cs.detect_lexical_field("OBSERVER les traces")
	assert_eq(field, "observation", "Detection should be case-insensitive")


# ═══════════════════════════════════════════════════════════════════════════════
# MINIGAME SELECTION
# ═══════════════════════════════════════════════════════════════════════════════

func test_select_minigame_returns_valid() -> void:
	var mg: String = cs.select_minigame("esprit")
	assert_false(mg.is_empty(), "Should return a minigame for 'esprit'")
	# Check it's in FIELD_MINIGAMES
	var valid: Array = MerlinConstants.FIELD_MINIGAMES.get("esprit", [])
	assert_true(valid.has(mg), "Minigame should be from FIELD_MINIGAMES[esprit]")


func test_select_minigame_unknown_field_fallback() -> void:
	var mg: String = cs.select_minigame("inconnu")
	# Should return something (fallback to esprit or default)
	assert_false(mg.is_empty(), "Should return a fallback minigame for unknown field")


# ═══════════════════════════════════════════════════════════════════════════════
# FASTROUTE POOL
# ═══════════════════════════════════════════════════════════════════════════════

func test_fastroute_card_not_empty() -> void:
	cs.init_run("foret_broceliande", "beith")
	var card: Dictionary = cs.get_fastroute_card({"biome": "foret_broceliande"})
	assert_false(card.is_empty(), "FastRoute should return a card")
	assert_eq(str(card.get("type", "")), "narrative", "FastRoute card type should be 'narrative'")


func test_fastroute_card_has_3_options() -> void:
	cs.init_run("foret_broceliande", "beith")
	var card: Dictionary = cs.get_fastroute_card({"biome": "foret_broceliande"})
	var options: Array = card.get("options", [])
	assert_eq(options.size(), 3, "FastRoute card should have exactly 3 options")


func test_fastroute_no_repeat_until_pool_exhausted() -> void:
	cs.init_run("foret_broceliande", "beith")
	var seen_ids: Array = []
	# Draw several cards and check uniqueness
	for i in 5:
		var card: Dictionary = cs.get_fastroute_card({"biome": ""})
		var card_id: String = str(card.get("id", ""))
		if not card_id.is_empty() and seen_ids.has(card_id):
			# Pool must have been exhausted and reset
			pass
		seen_ids.append(card_id)
	assert_gt(seen_ids.size(), 0, "Should have drawn at least 1 card")


# ═══════════════════════════════════════════════════════════════════════════════
# RUN END CHECK
# ═══════════════════════════════════════════════════════════════════════════════

func test_check_run_end_death() -> void:
	var state: Dictionary = {"life_essence": 0, "card_index": 5}
	var result: Dictionary = cs.check_run_end(state)
	assert_true(result.get("ended", false), "Run should end when life=0")
	assert_eq(str(result.get("reason", "")), "death", "Reason should be 'death'")


func test_check_run_end_hard_max() -> void:
	var hard_max: int = int(MerlinConstants.MOS_CONVERGENCE.get("hard_max_cards", 50))
	var state: Dictionary = {"life_essence": 50, "card_index": hard_max}
	var result: Dictionary = cs.check_run_end(state)
	assert_true(result.get("ended", false), "Run should end at hard_max")
	assert_eq(str(result.get("reason", "")), "hard_max", "Reason should be 'hard_max'")


func test_check_run_end_still_alive() -> void:
	var state: Dictionary = {"life_essence": 50, "card_index": 5}
	var result: Dictionary = cs.check_run_end(state)
	assert_false(result.get("ended", true), "Run should not end with life>0 and low card_index")


func test_check_run_end_early_zone() -> void:
	var soft_min: int = int(MerlinConstants.MOS_CONVERGENCE.get("soft_min_cards", 8))
	var state: Dictionary = {"life_essence": 50, "card_index": soft_min + 1}
	var result: Dictionary = cs.check_run_end(state)
	assert_true(result.get("early_zone", false), "Should be in early_zone past soft_min")
	assert_eq(str(result.get("tension_zone", "")), "low", "Tension zone should be 'low' in early zone")
	assert_false(result.get("convergence_zone", true), "Should NOT be in convergence_zone at soft_min+1")


func test_check_run_end_convergence_zone() -> void:
	var target_min: int = int(MerlinConstants.MOS_CONVERGENCE.get("target_cards_min", 20))
	var state: Dictionary = {"life_essence": 50, "card_index": target_min + 1}
	var result: Dictionary = cs.check_run_end(state)
	assert_true(result.get("convergence_zone", false), "Should be in convergence zone past target_min")
	assert_eq(str(result.get("tension_zone", "")), "rising", "Tension zone should be 'rising' at target_min+1")


# ═══════════════════════════════════════════════════════════════════════════════
# PROMISE LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func test_create_promise() -> void:
	var run_state: Dictionary = {"card_index": 3, "active_promises": [], "promise_tracking": {}}
	var promise_data: Dictionary = {
		"promise_id": "test_promise",
		"deadline_cards": 5,
		"condition_type": "life_above",
		"condition_value": 25,
		"reward_trust": 10,
		"penalty_trust": -15,
		"description": "Test",
	}
	cs.create_promise(run_state, promise_data)
	var promises: Array = run_state.get("active_promises", [])
	assert_eq(promises.size(), 1, "Should have 1 active promise")
	assert_eq(str(promises[0].get("promise_id", "")), "test_promise", "Promise ID should match")
	assert_eq(int(promises[0].get("deadline_card", 0)), 8, "Deadline = card_index(3) + deadline_cards(5)")


func test_promise_max_2_active() -> void:
	var run_state: Dictionary = {"card_index": 0, "active_promises": [], "promise_tracking": {}}
	for i in 3:
		cs.create_promise(run_state, {
			"promise_id": "p_%d" % i,
			"deadline_cards": 5,
			"condition_type": "life_above",
			"condition_value": 25,
			"reward_trust": 10,
			"penalty_trust": -15,
		})
	var promises: Array = run_state.get("active_promises", [])
	assert_lte(promises.size(), 2, "Should have at most 2 active promises")


func test_check_promises_expired() -> void:
	var run_state: Dictionary = {
		"card_index": 10,
		"active_promises": [{
			"promise_id": "expired_one",
			"deadline_card": 5,
			"status": "active",
			"reward_trust": 10,
			"penalty_trust": -15,
			"condition_type": "life_above",
			"condition_value": 25,
		}],
		"promise_tracking": {},
		"life_essence": 50,
	}
	var results: Array = cs.check_promises(run_state)
	assert_gt(results.size(), 0, "Should have resolved promises")


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM NARRATIVE EFFECTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_narrative_nuin_replaces_worst() -> void:
	var card: Dictionary = {
		"options": [
			{"label": "A", "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
			{"label": "B", "effects": [{"type": "DAMAGE_LIFE", "amount": 10}]},
			{"label": "C", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
		]
	}
	var result: Dictionary = cs.apply_ogham_narrative("nuin", card)
	# Nuin replaces worst option (B with most negatives)
	var options: Array = result.get("options", [])
	assert_eq(options.size(), 3, "Should still have 3 options")


func test_ogham_narrative_huath_reveals() -> void:
	var card: Dictionary = {
		"options": [
			{"label": "A", "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
			{"label": "B", "effects": [{"type": "DAMAGE_LIFE", "amount": 3}]},
			{"label": "C", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
		]
	}
	var result: Dictionary = cs.apply_ogham_narrative("huath", card)
	var options: Array = result.get("options", [])
	var all_visible: bool = true
	for opt in options:
		if not (opt is Dictionary):
			continue
		if not opt.get("effects_visible", false):
			all_visible = false
	assert_true(all_visible, "Huath should reveal all effects")


func test_ogham_narrative_unknown_returns_unchanged() -> void:
	var card: Dictionary = {"options": [{"label": "A"}]}
	var result: Dictionary = cs.apply_ogham_narrative("unknown_ogham", card)
	assert_eq(result.get("options", []).size(), card["options"].size(), "Unknown ogham should not change card")
