## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — LlmAdapterValidation
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: validate_faction_card, validate_faction_effect, validate_card,
## effects_to_codes. Covers sanitization, clamping, whitelists, edge cases.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


const ALLOWED_EFFECTS: Array = [
	"ADD_REPUTATION", "DAMAGE_LIFE", "HEAL_LIFE", "UNLOCK_OGHAM",
	"PROGRESS_MISSION", "ADD_KARMA", "ADD_TENSION", "ADD_NARRATIVE_DEBT",
	"SET_FLAG", "ADD_TAG", "REMOVE_TAG", "TRIGGER_EVENT",
	"CREATE_PROMISE", "FULFILL_PROMISE", "BREAK_PROMISE",
	"ADD_ANAM", "ADD_BIOME_CURRENCY",
]

const FACTIONS: Array = ["druides", "anciens", "korrigans", "niamh", "ankou"]

const LEGACY_REQUIRED_KEYS: Array = ["text", "options"]
const LEGACY_REQUIRED_OPTION_KEYS: Array = ["label", "direction", "effects"]
const LEGACY_VALID_DIRECTIONS: Array = ["left", "right"]
const LEGACY_ALLOWED_EFFECTS: Array = [
	"SET_FLAG", "ADD_TAG", "REMOVE_TAG", "QUEUE_CARD",
	"TRIGGER_ARC", "CREATE_PROMISE", "HEAL_LIFE", "DAMAGE_LIFE",
]


func _make_validator() -> LlmAdapterValidation:
	return LlmAdapterValidation.new()


func _make_valid_faction_card() -> Dictionary:
	return {
		"text": "The druid speaks of ancient wisdom.",
		"speaker": "merlin",
		"tags": ["forest"],
		"options": [
			{"label": "Listen", "effects": [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 5}]},
			{"label": "Mediter", "cost": 1, "effects": [{"type": "ADD_KARMA", "amount": 1}]},
			{"label": "Ignore", "effects": [{"type": "DAMAGE_LIFE", "amount": 3}]},
		]
	}


# ═══════════════════════════════════════════════════════════════════════════════
# validate_faction_card — Happy path
# ═══════════════════════════════════════════════════════════════════════════════

func test_faction_card_valid_3_options() -> bool:
	var v := _make_validator()
	var card: Dictionary = _make_valid_faction_card()
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if not result["ok"]:
		push_error("Valid 3-option card rejected: %s" % str(result["errors"]))
		return false
	if result["card"]["options"].size() != 3:
		push_error("Expected 3 options, got %d" % result["card"]["options"].size())
		return false
	return true


func test_faction_card_2_options_inserts_neutral() -> bool:
	var v := _make_validator()
	var card: Dictionary = {
		"text": "A fork in the path.",
		"options": [
			{"label": "Left", "effects": [{"type": "HEAL_LIFE", "amount": 5}]},
			{"label": "Right", "effects": [{"type": "DAMAGE_LIFE", "amount": 3}]},
		]
	}
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if not result["ok"]:
		push_error("2-option card rejected: %s" % str(result["errors"]))
		return false
	var opts: Array = result["card"]["options"]
	if opts.size() != 3:
		push_error("Expected 3 options after neutral insert, got %d" % opts.size())
		return false
	if opts[1]["label"] != "Mediter":
		push_error("Neutral option label should be 'Mediter', got '%s'" % opts[1]["label"])
		return false
	return true


func test_faction_card_adds_metadata() -> bool:
	var v := _make_validator()
	var card: Dictionary = _make_valid_faction_card()
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if not result["ok"]:
		push_error("Card rejected: %s" % str(result["errors"]))
		return false
	var c: Dictionary = result["card"]
	if not c.has("id") or not str(c["id"]).begins_with("llm_"):
		push_error("Missing or invalid id: %s" % str(c.get("id")))
		return false
	if c.get("_generated_by") != "merlin_llm_adapter":
		push_error("Missing _generated_by metadata")
		return false
	return true


func test_faction_card_adds_llm_generated_tag() -> bool:
	var v := _make_validator()
	var card: Dictionary = _make_valid_faction_card()
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if not result["ok"]:
		push_error("Card rejected: %s" % str(result["errors"]))
		return false
	var tags: Array = result["card"].get("tags", [])
	if not tags.has("llm_generated"):
		push_error("Missing 'llm_generated' tag, got %s" % str(tags))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# validate_faction_card — Error cases
# ═══════════════════════════════════════════════════════════════════════════════

func test_faction_card_missing_text() -> bool:
	var v := _make_validator()
	var card: Dictionary = {"options": [{"label": "A"}, {"label": "B"}, {"label": "C"}]}
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if result["ok"]:
		push_error("Card without text should fail")
		return false
	return true


func test_faction_card_empty_text() -> bool:
	var v := _make_validator()
	var card: Dictionary = {"text": "", "options": []}
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if result["ok"]:
		push_error("Card with empty text should fail")
		return false
	return true


func test_faction_card_missing_options() -> bool:
	var v := _make_validator()
	var card: Dictionary = {"text": "Hello"}
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if result["ok"]:
		push_error("Card without options should fail")
		return false
	return true


func test_faction_card_too_few_options() -> bool:
	var v := _make_validator()
	var card: Dictionary = {"text": "Hello", "options": [{"label": "Solo"}]}
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if result["ok"]:
		push_error("Card with 1 option should fail")
		return false
	return true


func test_faction_card_too_many_options() -> bool:
	var v := _make_validator()
	var card: Dictionary = {
		"text": "Hello",
		"options": [{"label": "A"}, {"label": "B"}, {"label": "C"}, {"label": "D"}]
	}
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if result["ok"]:
		push_error("Card with 4 options should fail")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# validate_faction_card — Sanitization
# ═══════════════════════════════════════════════════════════════════════════════

func test_faction_card_default_speaker() -> bool:
	var v := _make_validator()
	var card: Dictionary = {
		"text": "No speaker set.",
		"options": [
			{"label": "A", "effects": []},
			{"label": "B", "effects": []},
			{"label": "C", "effects": []},
		]
	}
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if not result["ok"]:
		push_error("Card rejected: %s" % str(result["errors"]))
		return false
	if result["card"]["speaker"] != "merlin":
		push_error("Default speaker should be 'merlin', got '%s'" % result["card"]["speaker"])
		return false
	return true


func test_faction_card_invalid_speaker_type_defaults() -> bool:
	var v := _make_validator()
	var card: Dictionary = {
		"text": "Bad speaker type.",
		"speaker": 42,
		"options": [
			{"label": "A", "effects": []},
			{"label": "B", "effects": []},
			{"label": "C", "effects": []},
		]
	}
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if not result["ok"]:
		push_error("Card rejected: %s" % str(result["errors"]))
		return false
	if result["card"]["speaker"] != "merlin":
		push_error("Non-string speaker should default to 'merlin', got '%s'" % str(result["card"]["speaker"]))
		return false
	return true


func test_faction_card_invalid_tags_defaults() -> bool:
	var v := _make_validator()
	var card: Dictionary = {
		"text": "Bad tags.",
		"tags": "not_an_array",
		"options": [
			{"label": "A", "effects": []},
			{"label": "B", "effects": []},
			{"label": "C", "effects": []},
		]
	}
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if not result["ok"]:
		push_error("Card rejected: %s" % str(result["errors"]))
		return false
	var tags: Array = result["card"].get("tags", [])
	if not tags.has("llm_generated"):
		push_error("Invalid tags should be replaced, expected 'llm_generated'")
		return false
	return true


func test_faction_card_non_dict_option_becomes_placeholder() -> bool:
	var v := _make_validator()
	var card: Dictionary = {
		"text": "Mixed options.",
		"options": [
			"not_a_dict",
			{"label": "Valid", "effects": []},
			{"label": "Also valid", "effects": []},
		]
	}
	var result: Dictionary = v.validate_faction_card(card, ALLOWED_EFFECTS, FACTIONS)
	if not result["ok"]:
		push_error("Card with non-dict option rejected: %s" % str(result["errors"]))
		return false
	var first_opt: Dictionary = result["card"]["options"][0]
	if first_opt["label"] != "...":
		push_error("Non-dict option should become placeholder '...', got '%s'" % first_opt["label"])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# validate_faction_effect — Individual effects
# ═══════════════════════════════════════════════════════════════════════════════

func test_effect_add_reputation_valid() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "ADD_REPUTATION", "faction": "druides", "amount": 10}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if result.is_empty():
		push_error("Valid ADD_REPUTATION rejected")
		return false
	if result["faction"] != "druides" or result["amount"] != 10.0:
		push_error("ADD_REPUTATION: unexpected values %s" % str(result))
		return false
	return true


func test_effect_add_reputation_clamped() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "ADD_REPUTATION", "faction": "ankou", "amount": 50}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if result.is_empty():
		push_error("ADD_REPUTATION with high amount rejected")
		return false
	if result["amount"] > 20.0:
		push_error("ADD_REPUTATION amount should be clamped to 20, got %s" % str(result["amount"]))
		return false
	return true


func test_effect_add_reputation_negative_clamped() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "ADD_REPUTATION", "faction": "korrigans", "amount": -50}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if result.is_empty():
		push_error("ADD_REPUTATION with negative amount rejected")
		return false
	if result["amount"] < -20.0:
		push_error("ADD_REPUTATION negative amount should clamp to -20, got %s" % str(result["amount"]))
		return false
	return true


func test_effect_add_reputation_invalid_faction() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "ADD_REPUTATION", "faction": "goblins", "amount": 5}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if not result.is_empty():
		push_error("ADD_REPUTATION with invalid faction should return empty")
		return false
	return true


func test_effect_heal_life_clamped() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "HEAL_LIFE", "amount": 99}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if result.is_empty():
		push_error("HEAL_LIFE rejected")
		return false
	if result["amount"] > 20:
		push_error("HEAL_LIFE should clamp to 20, got %d" % result["amount"])
		return false
	if result["amount"] < 1:
		push_error("HEAL_LIFE should clamp minimum to 1, got %d" % result["amount"])
		return false
	return true


func test_effect_damage_life_clamped() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "DAMAGE_LIFE", "amount": 0}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if result.is_empty():
		push_error("DAMAGE_LIFE rejected")
		return false
	if result["amount"] < 1:
		push_error("DAMAGE_LIFE should clamp minimum to 1, got %d" % result["amount"])
		return false
	return true


func test_effect_unlock_ogham_valid() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "UNLOCK_OGHAM", "ogham": "beith"}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if result.is_empty():
		push_error("UNLOCK_OGHAM with valid ogham rejected")
		return false
	if result["ogham"] != "beith":
		push_error("UNLOCK_OGHAM ogham should be 'beith', got '%s'" % result["ogham"])
		return false
	return true


func test_effect_unlock_ogham_invalid() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "UNLOCK_OGHAM", "ogham": "fake_ogham"}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if not result.is_empty():
		push_error("UNLOCK_OGHAM with invalid ogham should return empty")
		return false
	return true


func test_effect_unknown_type_rejected() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "EXPLODE_WORLD", "amount": 999}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if not result.is_empty():
		push_error("Unknown effect type should return empty")
		return false
	return true


func test_effect_set_flag_valid() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "SET_FLAG", "flag": "met_druid", "value": true}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if result.is_empty():
		push_error("Valid SET_FLAG rejected")
		return false
	if result["flag"] != "met_druid" or result["value"] != true:
		push_error("SET_FLAG unexpected values: %s" % str(result))
		return false
	return true


func test_effect_set_flag_empty_flag_rejected() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "SET_FLAG", "flag": "", "value": true}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if not result.is_empty():
		push_error("SET_FLAG with empty flag should return empty")
		return false
	return true


func test_effect_add_anam_clamped() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "ADD_ANAM", "amount": 50}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if result.is_empty():
		push_error("ADD_ANAM rejected")
		return false
	if result["amount"] > 10:
		push_error("ADD_ANAM should clamp to 10, got %d" % result["amount"])
		return false
	return true


func test_effect_promise_valid() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "CREATE_PROMISE", "promise_id": "p_druid_quest"}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if result.is_empty():
		push_error("Valid CREATE_PROMISE rejected")
		return false
	if result["promise_id"] != "p_druid_quest":
		push_error("CREATE_PROMISE unexpected id: %s" % str(result))
		return false
	return true


func test_effect_promise_empty_id_rejected() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "CREATE_PROMISE", "promise_id": ""}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if not result.is_empty():
		push_error("CREATE_PROMISE with empty id should return empty")
		return false
	return true


func test_effect_add_narrative_debt_valid() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "ADD_NARRATIVE_DEBT", "debt_type": "betrayal", "description": "broke oath"}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if result.is_empty():
		push_error("Valid ADD_NARRATIVE_DEBT rejected")
		return false
	if result["debt_type"] != "betrayal":
		push_error("ADD_NARRATIVE_DEBT unexpected type: %s" % str(result))
		return false
	return true


func test_effect_add_narrative_debt_empty_type_rejected() -> bool:
	var v := _make_validator()
	var effect: Dictionary = {"type": "ADD_NARRATIVE_DEBT", "debt_type": ""}
	var result: Dictionary = v.validate_faction_effect(effect, ALLOWED_EFFECTS, FACTIONS)
	if not result.is_empty():
		push_error("ADD_NARRATIVE_DEBT with empty debt_type should return empty")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# effects_to_codes
# ═══════════════════════════════════════════════════════════════════════════════

func test_effects_to_codes_reputation() -> bool:
	var v := _make_validator()
	var effects: Array = [{"type": "ADD_REPUTATION", "faction": "druides", "amount": 10}]
	var codes: Array = v.effects_to_codes(effects)
	if codes.size() != 1:
		push_error("Expected 1 code, got %d" % codes.size())
		return false
	if codes[0] != "ADD_REPUTATION:druides:10":
		push_error("Expected 'ADD_REPUTATION:druides:10', got '%s'" % codes[0])
		return false
	return true


func test_effects_to_codes_heal_life() -> bool:
	var v := _make_validator()
	var effects: Array = [{"type": "HEAL_LIFE", "amount": 7}]
	var codes: Array = v.effects_to_codes(effects)
	if codes.size() != 1 or codes[0] != "HEAL_LIFE:7":
		push_error("Expected 'HEAL_LIFE:7', got %s" % str(codes))
		return false
	return true


func test_effects_to_codes_set_flag() -> bool:
	var v := _make_validator()
	var effects: Array = [{"type": "SET_FLAG", "flag": "quest_done", "value": true}]
	var codes: Array = v.effects_to_codes(effects)
	if codes.size() != 1 or codes[0] != "SET_FLAG:quest_done:true":
		push_error("Expected 'SET_FLAG:quest_done:true', got %s" % str(codes))
		return false
	return true


func test_effects_to_codes_skips_non_dict() -> bool:
	var v := _make_validator()
	var effects: Array = ["not_a_dict", 42, {"type": "HEAL_LIFE", "amount": 3}]
	var codes: Array = v.effects_to_codes(effects)
	if codes.size() != 1:
		push_error("Expected 1 code (skipping non-dicts), got %d" % codes.size())
		return false
	return true


func test_effects_to_codes_unknown_type_empty() -> bool:
	var v := _make_validator()
	var effects: Array = [{"type": "NONEXISTENT", "amount": 1}]
	var codes: Array = v.effects_to_codes(effects)
	if codes.size() != 0:
		push_error("Unknown effect type should produce no code, got %d" % codes.size())
		return false
	return true


func test_effects_to_codes_multiple() -> bool:
	var v := _make_validator()
	var effects: Array = [
		{"type": "DAMAGE_LIFE", "amount": 5},
		{"type": "ADD_TAG", "tag": "cursed"},
		{"type": "ADD_ANAM", "amount": 2},
	]
	var codes: Array = v.effects_to_codes(effects)
	if codes.size() != 3:
		push_error("Expected 3 codes, got %d" % codes.size())
		return false
	if codes[0] != "DAMAGE_LIFE:5":
		push_error("First code wrong: %s" % codes[0])
		return false
	if codes[1] != "ADD_TAG:cursed":
		push_error("Second code wrong: %s" % codes[1])
		return false
	if codes[2] != "ADD_ANAM:2":
		push_error("Third code wrong: %s" % codes[2])
		return false
	return true
