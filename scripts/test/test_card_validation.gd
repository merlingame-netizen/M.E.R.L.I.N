## ═══════════════════════════════════════════════════════════════════════════════
## Test Suite — Card Validation Guardrails (_validate_card)
## ═══════════════════════════════════════════════════════════════════════════════
## Tests effect type whitelist, effect count caps, label requirements.
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error on fail.
## NO assert(), NO await, NO := with typed array/dictionary from const.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


func _make_cs() -> MerlinCardSystem:
	return MerlinCardSystem.new()


func _make_valid_card() -> Dictionary:
	return {
		"text": "La brume enveloppe le sentier.",
		"options": [
			{"label": "Observer", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
			{"label": "Fuir", "effects": [{"type": "DAMAGE_LIFE", "amount": 2}]},
			{"label": "Attendre", "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}]},
		],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# BASIC VALIDATION (existing behavior preserved)
# ═══════════════════════════════════════════════════════════════════════════════

func test_valid_card_passes() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var result: Dictionary = cs._validate_card(_make_valid_card())
	if not result.get("valid", false):
		push_error("Expected valid=true for well-formed card, got: %s" % str(result))
		return false
	return true


func test_missing_text_rejected() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = _make_valid_card()
	card.erase("text")
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for card without text")
		return false
	return true


func test_empty_text_rejected() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {"text": "", "options": [{"label": "A"}, {"label": "B"}]}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for empty text")
		return false
	return true


func test_too_few_options_rejected() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {"text": "Texte.", "options": [{"label": "Solo"}]}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for <2 options")
		return false
	return true


func test_missing_label_rejected() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {
		"text": "Texte.",
		"options": [{"label": "A"}, {"effects": []}],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for option missing label")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT TYPE WHITELIST (new: Sprint #77)
# ═══════════════════════════════════════════════════════════════════════════════

func test_unknown_effect_type_rejected() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {
		"text": "Un druide apparait.",
		"options": [
			{"label": "Parler", "effects": [{"type": "INVALID_EFFECT", "amount": 5}]},
			{"label": "Fuir", "effects": [{"type": "HEAL_LIFE", "amount": 3}]},
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for unknown effect type 'INVALID_EFFECT'")
		return false
	if not str(result.get("error", "")).contains("INVALID_EFFECT"):
		push_error("Error message should mention the bad effect type, got: %s" % str(result.get("error", "")))
		return false
	return true


func test_empty_effect_type_rejected() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {
		"text": "Un korrigan rit.",
		"options": [
			{"label": "Rire", "effects": [{"type": "", "amount": 1}]},
			{"label": "Partir", "effects": []},
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for empty effect type")
		return false
	return true


func test_effect_missing_type_key_rejected() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {
		"text": "Le vent souffle.",
		"options": [
			{"label": "Avancer", "effects": [{"amount": 5}]},
			{"label": "Reculer", "effects": []},
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for effect without type key")
		return false
	return true


func test_all_valid_effect_types_accepted() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	# Test a card with multiple valid effect types
	var card: Dictionary = {
		"text": "Un carrefour mystique.",
		"options": [
			{"label": "Soigner", "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
			{"label": "Frapper", "effects": [{"type": "DAMAGE_LIFE", "amount": 3}]},
			{"label": "Prier", "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 10}]},
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if not result.get("valid", false):
		push_error("Expected valid=true for all-valid effect types, got: %s" % str(result))
		return false
	return true


func test_non_dict_effect_rejected() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {
		"text": "Le silence.",
		"options": [
			{"label": "Agir", "effects": ["HEAL_LIFE:5"]},
			{"label": "Attendre", "effects": []},
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for non-dict effect (string)")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT COUNT CAP (new: Sprint #77 — bible rule: 3 max per option)
# ═══════════════════════════════════════════════════════════════════════════════

func test_4_effects_per_option_rejected() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {
		"text": "Un lieu de pouvoir.",
		"options": [
			{"label": "Tout prendre", "effects": [
				{"type": "HEAL_LIFE", "amount": 5},
				{"type": "HEAL_LIFE", "amount": 3},
				{"type": "HEAL_LIFE", "amount": 2},
				{"type": "HEAL_LIFE", "amount": 1},
			]},
			{"label": "Ignorer", "effects": []},
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if result.get("valid", true):
		push_error("Expected valid=false for option with 4 effects (max 3)")
		return false
	return true


func test_3_effects_per_option_accepted() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {
		"text": "Un lieu de pouvoir.",
		"options": [
			{"label": "Agir", "effects": [
				{"type": "HEAL_LIFE", "amount": 5},
				{"type": "ADD_REPUTATION", "faction": "druides", "amount": 3},
				{"type": "ADD_KARMA", "amount": 1},
			]},
			{"label": "Ignorer", "effects": []},
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if not result.get("valid", false):
		push_error("Expected valid=true for option with exactly 3 effects, got: %s" % str(result))
		return false
	return true


func test_zero_effects_accepted() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {
		"text": "Rien ne se passe.",
		"options": [
			{"label": "Observer", "effects": []},
			{"label": "Attendre", "effects": []},
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if not result.get("valid", false):
		push_error("Expected valid=true for options with zero effects")
		return false
	return true


func test_no_effects_key_accepted() -> bool:
	var cs: MerlinCardSystem = _make_cs()
	var card: Dictionary = {
		"text": "Un moment de calme.",
		"options": [
			{"label": "Observer"},
			{"label": "Attendre"},
		],
	}
	var result: Dictionary = cs._validate_card(card)
	if not result.get("valid", false):
		push_error("Expected valid=true for options without effects key")
		return false
	return true
