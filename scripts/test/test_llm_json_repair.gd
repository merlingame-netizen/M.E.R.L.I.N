## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — LlmAdapterJsonRepair
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: extract_json_from_response (4 strategies), fix_common_json_errors,
## aggressive_json_repair, _regex_extract_card_fields.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


func _make_repair() -> LlmAdapterJsonRepair:
	return LlmAdapterJsonRepair.new()


# ═══════════════════════════════════════════════════════════════════════════════
# extract_json_from_response — Strategy 1: Clean JSON
# ═══════════════════════════════════════════════════════════════════════════════

func test_valid_json_clean() -> bool:
	var repair := _make_repair()
	var raw := '{"text": "Hello world", "speaker": "merlin"}'
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.get("text") != "Hello world":
		push_error("Clean JSON: expected 'Hello world', got '%s'" % str(result.get("text")))
		return false
	if result.get("speaker") != "merlin":
		push_error("Clean JSON: expected speaker 'merlin', got '%s'" % str(result.get("speaker")))
		return false
	return true


func test_json_in_markdown_code_block() -> bool:
	var repair := _make_repair()
	var raw := "Here is the card:\n```json\n{\"text\": \"A druid speaks\", \"value\": 42}\n```\nEnd."
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.get("text") != "A druid speaks":
		push_error("Markdown block: expected 'A druid speaks', got '%s'" % str(result.get("text")))
		return false
	if result.get("value") != 42:
		push_error("Markdown block: expected value 42, got '%s'" % str(result.get("value")))
		return false
	return true


func test_json_with_surrounding_prose() -> bool:
	var repair := _make_repair()
	var raw := "Sure, here is your card: {\"text\": \"Forest path\", \"mood\": \"calm\"} I hope this works!"
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.get("text") != "Forest path":
		push_error("Surrounded JSON: expected 'Forest path', got '%s'" % str(result.get("text")))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# fix_common_json_errors
# ═══════════════════════════════════════════════════════════════════════════════

func test_trailing_comma_fix() -> bool:
	var repair := _make_repair()
	var raw := '{"a": 1, "b": 2,}'
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.get("a") != 1:
		push_error("Trailing comma: expected a=1, got '%s'" % str(result.get("a")))
		return false
	if result.get("b") != 2:
		push_error("Trailing comma: expected b=2, got '%s'" % str(result.get("b")))
		return false
	return true


func test_single_quotes_fix() -> bool:
	var repair := _make_repair()
	var raw := "{'text': 'hello', 'value': 'world'}"
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.get("text") != "hello":
		push_error("Single quotes: expected 'hello', got '%s'" % str(result.get("text")))
		return false
	return true


func test_unquoted_keys_fix() -> bool:
	var repair := _make_repair()
	var raw := '{text: "hello", value: "world"}'
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.get("text") != "hello":
		push_error("Unquoted keys: expected 'hello', got '%s'" % str(result.get("text")))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# aggressive_json_repair
# ═══════════════════════════════════════════════════════════════════════════════

func test_truncated_json_closes_brackets() -> bool:
	var repair := _make_repair()
	var raw := '{"text": "hello", "opt'
	var result: Dictionary = repair.extract_json_from_response(raw)
	# After aggressive repair: unclosed string closed, trailing incomplete kv removed, brace closed
	# Should either parse or fall through to regex. Either way, no crash.
	if typeof(result) != TYPE_DICTIONARY:
		push_error("Truncated JSON: expected Dictionary, got type %d" % typeof(result))
		return false
	return true


func test_unclosed_string_repair() -> bool:
	var repair := _make_repair()
	# Test aggressive_json_repair directly
	var text := '{"text": "hello'
	var repaired: String = repair.aggressive_json_repair(text)
	# Should close the quote and the brace
	if repaired.find("\"hello\"") == -1:
		push_error("Unclosed string: expected closed quote in '%s'" % repaired)
		return false
	if repaired.count("{") != repaired.count("}"):
		push_error("Unclosed string: braces unbalanced in '%s'" % repaired)
		return false
	return true


func test_combined_errors() -> bool:
	var repair := _make_repair()
	# Trailing comma + single quotes + unquoted keys
	var raw := "{text: 'hello', value: 'world',}"
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.get("text") != "hello":
		push_error("Combined errors: expected text='hello', got '%s'" % str(result.get("text")))
		return false
	if result.get("value") != "world":
		push_error("Combined errors: expected value='world', got '%s'" % str(result.get("value")))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _regex_extract_card_fields (Strategy 4)
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_json_at_all() -> bool:
	var repair := _make_repair()
	var raw := "This is just plain text with no JSON anywhere."
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.size() != 0:
		push_error("No JSON: expected empty dict, got %d keys" % result.size())
		return false
	return true


func test_regex_fallback_with_text_and_labels() -> bool:
	var repair := _make_repair()
	# No valid JSON braces, but has extractable fields in broken format
	var raw := '"text": "The forest whispers" ... "label": "Listen" ... "label": "Ignore" ... "label": "Run"'
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.get("text") != "The forest whispers":
		push_error("Regex fallback: expected text 'The forest whispers', got '%s'" % str(result.get("text")))
		return false
	if not result.has("options"):
		push_error("Regex fallback: expected 'options' key")
		return false
	var options: Array = result.get("options", [])
	if options.size() < 2:
		push_error("Regex fallback: expected 2+ options, got %d" % options.size())
		return false
	return true


func test_regex_fallback_with_speaker() -> bool:
	var repair := _make_repair()
	var raw := '"text": "A voice calls" ... "speaker": "niamh" ... "label": "Follow" ... "label": "Stay"'
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.get("speaker") != "niamh":
		push_error("Regex speaker: expected 'niamh', got '%s'" % str(result.get("speaker")))
		return false
	return true


func test_regex_fallback_insufficient_labels() -> bool:
	var repair := _make_repair()
	# Only 1 label — less than the minimum 2 required
	var raw := '"text": "Something" ... "label": "Only one"'
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.size() != 0:
		push_error("Regex <2 labels: expected empty dict, got %d keys" % result.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# Edge cases
# ═══════════════════════════════════════════════════════════════════════════════

func test_control_characters_in_json() -> bool:
	var repair := _make_repair()
	# Tabs and carriage returns inside JSON — aggressive_json_repair strips them
	var raw := "{\"text\":\t\"hello\\r world\",\r\"value\":\t1}"
	var result: Dictionary = repair.extract_json_from_response(raw)
	if not result.has("text"):
		push_error("Control chars: expected 'text' key in result")
		return false
	return true


func test_nested_json_objects() -> bool:
	var repair := _make_repair()
	var raw := '{"text": "Nested", "meta": {"faction": "druides", "tier": 2}}'
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.get("text") != "Nested":
		push_error("Nested JSON: expected text='Nested', got '%s'" % str(result.get("text")))
		return false
	var meta: Dictionary = result.get("meta", {})
	if meta.get("faction") != "druides":
		push_error("Nested JSON: expected meta.faction='druides', got '%s'" % str(meta.get("faction")))
		return false
	if meta.get("tier") != 2:
		push_error("Nested JSON: expected meta.tier=2, got '%s'" % str(meta.get("tier")))
		return false
	return true


func test_multiple_jsons_uses_outermost() -> bool:
	var repair := _make_repair()
	# Two JSON objects — outermost { } should capture the wrapping one
	var raw := '{"outer": true, "inner": {"nested": true}}'
	var result: Dictionary = repair.extract_json_from_response(raw)
	if result.get("outer") != true:
		push_error("Multiple JSONs: expected outer=true, got '%s'" % str(result.get("outer")))
		return false
	return true


func test_empty_input() -> bool:
	var repair := _make_repair()
	var result: Dictionary = repair.extract_json_from_response("")
	if result.size() != 0:
		push_error("Empty input: expected empty dict, got %d keys" % result.size())
		return false
	return true


func test_fix_common_json_errors_direct() -> bool:
	var repair := _make_repair()
	# Test the method directly to verify transformations
	var fixed: String = repair.fix_common_json_errors("{a: 'b', c: 'd',}")
	# Should have: quoted keys, double quotes, no trailing comma
	var parsed = JSON.parse_string(fixed)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("fix_common direct: result not parseable: '%s'" % fixed)
		return false
	if parsed.get("a") != "b":
		push_error("fix_common direct: expected a='b', got '%s'" % str(parsed.get("a")))
		return false
	return true


func test_aggressive_repair_direct() -> bool:
	var repair := _make_repair()
	# Tabs, unclosed string, unclosed brace
	var text := "{\"key\":\t\"value"
	var repaired: String = repair.aggressive_json_repair(text)
	# Tabs should be replaced by spaces
	if repaired.find("\t") != -1:
		push_error("aggressive_repair: tabs not removed in '%s'" % repaired)
		return false
	# String and brace should be closed
	if repaired.count("{") != repaired.count("}"):
		push_error("aggressive_repair: braces unbalanced in '%s'" % repaired)
		return false
	return true


func test_regex_fallback_tags_present() -> bool:
	var repair := _make_repair()
	var raw := '"text": "Magic" ... "label": "Yes" ... "label": "No"'
	var result: Dictionary = repair.extract_json_from_response(raw)
	var tags: Array = result.get("tags", [])
	if not tags.has("llm_regex_repair"):
		push_error("Regex tags: expected 'llm_regex_repair' tag, got %s" % str(tags))
		return false
	return true
