## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinLlmAdapter card validation
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: validate_faction_card(), _validate_faction_option(), _validate_faction_effect()
## Coverage: required fields, faction names, ADD_REPUTATION caps, UNLOCK_OGHAM keys,
## effect count limits, DAMAGE_LIFE/HEAL_LIFE clamping, unknown effect types.
## Pattern: extends RefCounted, methods return false on failure. run_all() runner.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _make_adapter() -> MerlinLlmAdapter:
	return MerlinLlmAdapter.new()


## Build a minimal valid card with 3 options (no effects by default).
func _make_valid_card(text: String = "La brume s'epaissit entre les chenes.") -> Dictionary:
	return {
		"text": text,
		"options": [
			{"label": "Escalader", "effects": []},
			{"label": "Observer",  "effects": []},
			{"label": "Partir",    "effects": []},
		],
	}


## Build a single effect dictionary.
func _make_effect(type: String, extra: Dictionary = {}) -> Dictionary:
	var e: Dictionary = {"type": type}
	for k in extra:
		e[k] = extra[k]
	return e


# ─────────────────────────────────────────────────────────────────────────────
# VALID CARD
# ─────────────────────────────────────────────────────────────────────────────

func test_valid_card_passes_validation() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Valid card should pass validation, errors: %s" % str(result["errors"]))
		return false
	return true


func test_valid_card_result_has_card_key() -> bool:
	var adapter := _make_adapter()
	var result: Dictionary = adapter.validate_faction_card(_make_valid_card())
	if result["card"].is_empty():
		push_error("Validated card dict should not be empty")
		return false
	return true


func test_valid_card_gets_llm_generated_tag() -> bool:
	var adapter := _make_adapter()
	var result: Dictionary = adapter.validate_faction_card(_make_valid_card())
	var tags: Array = result["card"].get("tags", [])
	if not tags.has("llm_generated"):
		push_error("Validated card must have 'llm_generated' tag, got: %s" % str(tags))
		return false
	return true


func test_valid_card_gets_id_assigned() -> bool:
	var adapter := _make_adapter()
	var result: Dictionary = adapter.validate_faction_card(_make_valid_card())
	var id: String = str(result["card"].get("id", ""))
	if id.is_empty():
		push_error("Validated card must have a non-empty id assigned")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# MISSING REQUIRED FIELDS
# ─────────────────────────────────────────────────────────────────────────────

func test_missing_text_field_rejected() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	card.erase("text")
	var result: Dictionary = adapter.validate_faction_card(card)
	if result["ok"]:
		push_error("Card without 'text' field should fail validation")
		return false
	return true


func test_empty_text_field_rejected() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card("")
	var result: Dictionary = adapter.validate_faction_card(card)
	if result["ok"]:
		push_error("Card with empty 'text' should fail validation")
		return false
	return true


func test_missing_options_array_rejected() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	card.erase("options")
	var result: Dictionary = adapter.validate_faction_card(card)
	if result["ok"]:
		push_error("Card without 'options' should fail validation")
		return false
	return true


func test_options_not_array_rejected() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	card["options"] = "not_an_array"
	var result: Dictionary = adapter.validate_faction_card(card)
	if result["ok"]:
		push_error("Card with non-array 'options' should fail validation")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# EMPTY OPTIONS ARRAY
# ─────────────────────────────────────────────────────────────────────────────

func test_empty_options_array_rejected() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	card["options"] = []
	var result: Dictionary = adapter.validate_faction_card(card)
	if result["ok"]:
		push_error("Card with 0 options should fail validation (need 2-3)")
		return false
	return true


func test_one_option_rejected() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	card["options"] = [{"label": "Solo", "effects": []}]
	var result: Dictionary = adapter.validate_faction_card(card)
	if result["ok"]:
		push_error("Card with only 1 option should fail validation (need 2-3)")
		return false
	return true


func test_four_options_rejected() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	card["options"] = [
		{"label": "A", "effects": []},
		{"label": "B", "effects": []},
		{"label": "C", "effects": []},
		{"label": "D", "effects": []},
	]
	var result: Dictionary = adapter.validate_faction_card(card)
	if result["ok"]:
		push_error("Card with 4 options should fail validation (max is 3)")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# ADD_REPUTATION — valid faction
# ─────────────────────────────────────────────────────────────────────────────

func test_add_reputation_valid_faction_accepted() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("ADD_REPUTATION", {"faction": "druides", "amount": 10.0})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card with valid ADD_REPUTATION (druides) should pass: %s" % str(result["errors"]))
		return false
	var opt_effects: Array = result["card"]["options"][0]["effects"]
	if opt_effects.size() != 1:
		push_error("ADD_REPUTATION effect should survive validation, got %d effects" % opt_effects.size())
		return false
	return true


func test_add_reputation_all_factions_accepted() -> bool:
	var adapter := _make_adapter()
	var factions: Array = ["druides", "anciens", "korrigans", "niamh", "ankou"]
	for faction in factions:
		var card: Dictionary = _make_valid_card()
		var effect: Dictionary = _make_effect("ADD_REPUTATION", {"faction": faction, "amount": 5.0})
		card["options"][0]["effects"] = [effect]
		var result: Dictionary = adapter.validate_faction_card(card)
		if not result["ok"]:
			push_error("ADD_REPUTATION with faction '%s' should pass validation" % faction)
			return false
		var effects: Array = result["card"]["options"][0]["effects"]
		if effects.is_empty():
			push_error("ADD_REPUTATION with faction '%s' was stripped unexpectedly" % faction)
			return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# ADD_REPUTATION — invalid faction name
# ─────────────────────────────────────────────────────────────────────────────

func test_add_reputation_invalid_faction_rejected() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("ADD_REPUTATION", {"faction": "orcs", "amount": 10.0})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card should still pass overall (invalid effect is silently stripped)")
		return false
	# The invalid-faction effect must be stripped
	var opt_effects: Array = result["card"]["options"][0]["effects"]
	if opt_effects.size() != 0:
		push_error("ADD_REPUTATION with unknown faction 'orcs' must be stripped, got %d effects" % opt_effects.size())
		return false
	return true


func test_add_reputation_empty_faction_stripped() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("ADD_REPUTATION", {"faction": "", "amount": 5.0})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card overall should still pass")
		return false
	var opt_effects: Array = result["card"]["options"][0]["effects"]
	if opt_effects.size() != 0:
		push_error("ADD_REPUTATION with empty faction must be stripped")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# ADD_REPUTATION — amount capped at ±20 (SEC-3)
# ─────────────────────────────────────────────────────────────────────────────

func test_add_reputation_amount_capped_positive() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("ADD_REPUTATION", {"faction": "anciens", "amount": 99.0})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card should pass, errors: %s" % str(result["errors"]))
		return false
	var validated_amount: float = float(result["card"]["options"][0]["effects"][0]["amount"])
	if validated_amount != 20.0:
		push_error("ADD_REPUTATION amount 99 should be capped to 20.0, got %.1f" % validated_amount)
		return false
	return true


func test_add_reputation_amount_capped_negative() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("ADD_REPUTATION", {"faction": "korrigans", "amount": -50.0})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card should pass, errors: %s" % str(result["errors"]))
		return false
	var validated_amount: float = float(result["card"]["options"][0]["effects"][0]["amount"])
	if validated_amount != -20.0:
		push_error("ADD_REPUTATION amount -50 should be capped to -20.0, got %.1f" % validated_amount)
		return false
	return true


func test_add_reputation_amount_within_bounds_unchanged() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("ADD_REPUTATION", {"faction": "niamh", "amount": 15.0})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		return false
	var validated_amount: float = float(result["card"]["options"][0]["effects"][0]["amount"])
	if validated_amount != 15.0:
		push_error("ADD_REPUTATION amount 15 should remain 15.0, got %.1f" % validated_amount)
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# UNLOCK_OGHAM — valid ogham key
# ─────────────────────────────────────────────────────────────────────────────

func test_unlock_ogham_valid_key_accepted() -> bool:
	var adapter := _make_adapter()
	# "beith" is a known starter ogham in OGHAM_FULL_SPECS
	var effect: Dictionary = _make_effect("UNLOCK_OGHAM", {"ogham": "beith"})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card with UNLOCK_OGHAM 'beith' should pass: %s" % str(result["errors"]))
		return false
	var opt_effects: Array = result["card"]["options"][0]["effects"]
	if opt_effects.size() != 1:
		push_error("UNLOCK_OGHAM 'beith' effect must survive validation")
		return false
	if str(opt_effects[0].get("ogham", "")) != "beith":
		push_error("UNLOCK_OGHAM ogham key must be preserved as 'beith'")
		return false
	return true


func test_unlock_ogham_non_starter_key_accepted() -> bool:
	var adapter := _make_adapter()
	# "duir" exists in OGHAM_FULL_SPECS but is not a starter
	var effect: Dictionary = _make_effect("UNLOCK_OGHAM", {"ogham": "duir"})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("UNLOCK_OGHAM 'duir' should pass (valid OGHAM_FULL_SPECS key)")
		return false
	var opt_effects: Array = result["card"]["options"][0]["effects"]
	if opt_effects.is_empty():
		push_error("UNLOCK_OGHAM 'duir' must not be stripped")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# UNLOCK_OGHAM — invalid ogham key (SEC-5)
# ─────────────────────────────────────────────────────────────────────────────

func test_unlock_ogham_invalid_key_rejected() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("UNLOCK_OGHAM", {"ogham": "excalibur"})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card overall should still pass (bad ogham is silently stripped)")
		return false
	var opt_effects: Array = result["card"]["options"][0]["effects"]
	if opt_effects.size() != 0:
		push_error("UNLOCK_OGHAM 'excalibur' must be stripped (not in OGHAM_FULL_SPECS)")
		return false
	return true


func test_unlock_ogham_empty_key_stripped() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("UNLOCK_OGHAM", {"ogham": ""})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card overall should still pass")
		return false
	var opt_effects: Array = result["card"]["options"][0]["effects"]
	if opt_effects.size() != 0:
		push_error("UNLOCK_OGHAM with empty ogham key must be stripped")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# TOO MANY EFFECTS PER OPTION (>3)
# ─────────────────────────────────────────────────────────────────────────────

func test_effects_exactly_3_all_kept() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [
		_make_effect("HEAL_LIFE",        {"amount": 5}),
		_make_effect("ADD_REPUTATION",   {"faction": "druides", "amount": 5.0}),
		_make_effect("ADD_KARMA",        {"amount": 2}),
	]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card with 3 valid effects should pass: %s" % str(result["errors"]))
		return false
	var opt_effects: Array = result["card"]["options"][0]["effects"]
	if opt_effects.size() != 3:
		push_error("All 3 valid effects should be kept, got %d" % opt_effects.size())
		return false
	return true


func test_four_valid_effects_all_survive_adapter() -> bool:
	# _validate_faction_option does NOT cap at 3 — it passes all valid effects through.
	# The GDD v2.4 sec 13 "max 3 effects/option" rule is enforced by the caller
	# (MerlinCardSystem), not by the adapter validator. This test documents that contract.
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [
		_make_effect("HEAL_LIFE",    {"amount": 5}),
		_make_effect("DAMAGE_LIFE",  {"amount": 3}),
		_make_effect("ADD_KARMA",    {"amount": 1}),
		_make_effect("ADD_TENSION",  {"amount": 2}),
	]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card with 4 valid effects should still pass adapter validation")
		return false
	var opt_effects: Array = result["card"]["options"][0]["effects"]
	if opt_effects.size() != 4:
		push_error("Adapter should preserve all 4 valid effects (cap is caller-side), got %d" % opt_effects.size())
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# EFFECT TYPE NOT IN ALLOWED_EFFECT_TYPES
# ─────────────────────────────────────────────────────────────────────────────

func test_unknown_effect_type_stripped() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("GRANT_SWORD", {"amount": 1})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card should still pass overall (unknown effect stripped silently)")
		return false
	var opt_effects: Array = result["card"]["options"][0]["effects"]
	if opt_effects.size() != 0:
		push_error("Unknown effect type 'GRANT_SWORD' must be stripped")
		return false
	return true


func test_triade_effect_type_stripped() -> bool:
	# Triade system was removed — ADD_TRIADE not in ALLOWED_EFFECT_TYPES
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("ADD_TRIADE", {"amount": 3})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card should pass overall")
		return false
	var opt_effects: Array = result["card"]["options"][0]["effects"]
	if opt_effects.size() != 0:
		push_error("Removed Triade effect 'ADD_TRIADE' must be stripped")
		return false
	return true


func test_decay_rep_effect_stripped() -> bool:
	# DECAY_REPUTATION was removed in v2.1
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("DECAY_REPUTATION", {"faction": "druides"})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card should pass overall")
		return false
	var opt_effects: Array = result["card"]["options"][0]["effects"]
	if opt_effects.size() != 0:
		push_error("Removed effect 'DECAY_REPUTATION' must be stripped")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# DAMAGE_LIFE / HEAL_LIFE — amount clamped to [1, 20]
# ─────────────────────────────────────────────────────────────────────────────

func test_damage_life_amount_clamped_to_max() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("DAMAGE_LIFE", {"amount": 999})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("DAMAGE_LIFE card should pass, errors: %s" % str(result["errors"]))
		return false
	var validated_amount: int = int(result["card"]["options"][0]["effects"][0]["amount"])
	if validated_amount != 20:
		push_error("DAMAGE_LIFE 999 should be clamped to 20, got %d" % validated_amount)
		return false
	return true


func test_damage_life_amount_clamped_to_min() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("DAMAGE_LIFE", {"amount": 0})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("DAMAGE_LIFE card should pass")
		return false
	var validated_amount: int = int(result["card"]["options"][0]["effects"][0]["amount"])
	if validated_amount != 1:
		push_error("DAMAGE_LIFE 0 should be clamped to minimum 1, got %d" % validated_amount)
		return false
	return true


func test_heal_life_amount_clamped_to_max() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("HEAL_LIFE", {"amount": 100})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("HEAL_LIFE card should pass, errors: %s" % str(result["errors"]))
		return false
	var validated_amount: int = int(result["card"]["options"][0]["effects"][0]["amount"])
	if validated_amount != 20:
		push_error("HEAL_LIFE 100 should be clamped to 20, got %d" % validated_amount)
		return false
	return true


func test_heal_life_amount_clamped_to_min() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("HEAL_LIFE", {"amount": -5})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("HEAL_LIFE card should pass")
		return false
	var validated_amount: int = int(result["card"]["options"][0]["effects"][0]["amount"])
	if validated_amount != 1:
		push_error("HEAL_LIFE -5 should be clamped to minimum 1, got %d" % validated_amount)
		return false
	return true


func test_damage_life_amount_within_bounds_unchanged() -> bool:
	var adapter := _make_adapter()
	var effect: Dictionary = _make_effect("DAMAGE_LIFE", {"amount": 10})
	var card: Dictionary = _make_valid_card()
	card["options"][0]["effects"] = [effect]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		return false
	var validated_amount: int = int(result["card"]["options"][0]["effects"][0]["amount"])
	if validated_amount != 10:
		push_error("DAMAGE_LIFE 10 should remain 10, got %d" % validated_amount)
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# TWO-OPTION CARD — auto-inserts neutral center
# ─────────────────────────────────────────────────────────────────────────────

func test_two_option_card_gets_center_inserted() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	card["options"] = [
		{"label": "Fuir",  "effects": []},
		{"label": "Braver", "effects": []},
	]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Two-option card should pass (adapter inserts center): %s" % str(result["errors"]))
		return false
	var options: Array = result["card"]["options"]
	if options.size() != 3:
		push_error("Two-option card should have center auto-inserted → 3 options, got %d" % options.size())
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# OPTION NON-DICT INPUT — graceful fallback
# ─────────────────────────────────────────────────────────────────────────────

func test_non_dict_option_replaced_with_fallback() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	card["options"] = [
		"not_a_dict",
		{"label": "Observer", "effects": []},
		{"label": "Partir",   "effects": []},
	]
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		push_error("Card with one bad option should still pass (bad option gets fallback)")
		return false
	var opt: Dictionary = result["card"]["options"][0]
	if not opt.has("label") or not opt.has("effects"):
		push_error("Fallback option must have 'label' and 'effects' keys")
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# SPEAKER DEFAULT
# ─────────────────────────────────────────────────────────────────────────────

func test_missing_speaker_defaults_to_merlin() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	# No "speaker" key
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		return false
	var speaker: String = str(result["card"].get("speaker", ""))
	if speaker != "merlin":
		push_error("Missing speaker should default to 'merlin', got '%s'" % speaker)
		return false
	return true


func test_existing_speaker_preserved() -> bool:
	var adapter := _make_adapter()
	var card: Dictionary = _make_valid_card()
	card["speaker"] = "niamh"
	var result: Dictionary = adapter.validate_faction_card(card)
	if not result["ok"]:
		return false
	var speaker: String = str(result["card"].get("speaker", ""))
	if speaker != "niamh":
		push_error("Explicit speaker 'niamh' should be preserved, got '%s'" % speaker)
		return false
	return true


# ─────────────────────────────────────────────────────────────────────────────
# RUNNER
# ─────────────────────────────────────────────────────────────────────────────

func run_all() -> Dictionary:
	var tests: Array[String] = [
		# Valid card
		"test_valid_card_passes_validation",
		"test_valid_card_result_has_card_key",
		"test_valid_card_gets_llm_generated_tag",
		"test_valid_card_gets_id_assigned",
		# Missing required fields
		"test_missing_text_field_rejected",
		"test_empty_text_field_rejected",
		"test_missing_options_array_rejected",
		"test_options_not_array_rejected",
		# Empty / wrong options count
		"test_empty_options_array_rejected",
		"test_one_option_rejected",
		"test_four_options_rejected",
		# ADD_REPUTATION — valid factions
		"test_add_reputation_valid_faction_accepted",
		"test_add_reputation_all_factions_accepted",
		# ADD_REPUTATION — invalid faction
		"test_add_reputation_invalid_faction_rejected",
		"test_add_reputation_empty_faction_stripped",
		# ADD_REPUTATION — amount cap ±20
		"test_add_reputation_amount_capped_positive",
		"test_add_reputation_amount_capped_negative",
		"test_add_reputation_amount_within_bounds_unchanged",
		# UNLOCK_OGHAM — valid
		"test_unlock_ogham_valid_key_accepted",
		"test_unlock_ogham_non_starter_key_accepted",
		# UNLOCK_OGHAM — invalid
		"test_unlock_ogham_invalid_key_rejected",
		"test_unlock_ogham_empty_key_stripped",
		# Effects count
		"test_effects_exactly_3_all_kept",
		"test_four_valid_effects_all_survive_adapter",
		# Unknown effect types
		"test_unknown_effect_type_stripped",
		"test_triade_effect_type_stripped",
		"test_decay_rep_effect_stripped",
		# DAMAGE_LIFE / HEAL_LIFE clamping
		"test_damage_life_amount_clamped_to_max",
		"test_damage_life_amount_clamped_to_min",
		"test_heal_life_amount_clamped_to_max",
		"test_heal_life_amount_clamped_to_min",
		"test_damage_life_amount_within_bounds_unchanged",
		# Two-option auto-center
		"test_two_option_card_gets_center_inserted",
		# Non-dict option fallback
		"test_non_dict_option_replaced_with_fallback",
		# Speaker
		"test_missing_speaker_defaults_to_merlin",
		"test_existing_speaker_preserved",
	]

	var passed := 0
	var failed := 0
	var failures: Array = []

	print("\n[TestLlmCardValidation] Running %d tests..." % tests.size())

	for test_name in tests:
		var ok: bool = call(test_name)
		if ok:
			passed += 1
		else:
			failed += 1
			failures.append(test_name)
			push_error("[FAIL] %s" % test_name)

	print("[TestLlmCardValidation] %d/%d passed" % [passed, tests.size()])
	if failures.size() > 0:
		print("[TestLlmCardValidation] FAILURES: %s" % str(failures))

	return {"passed": passed, "failed": failed, "total": tests.size(), "failures": failures}
