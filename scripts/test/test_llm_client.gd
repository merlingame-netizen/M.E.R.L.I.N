## =============================================================================
## Unit Tests — LLMClient (headless-safe)
## =============================================================================
## Tests: _extract_text (all branches), ping logic, _get_or_load_model guard,
## model cache behavior, input validation paths.
## Skipped: complete() (requires await/scene tree), signal emission (requires Node).
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted

var _script_ref: GDScript = null


func _init() -> void:
	_script_ref = preload("res://addons/merlin_ai/llm_client.gd")


# =============================================================================
# HELPER — instantiate script for direct method testing
# We cannot call instance methods on a Node without scene tree, so we
# test static-like logic by calling the script's internal functions where
# possible. For _extract_text, we create a temporary instance and call it
# since it has no Node dependencies.
# =============================================================================

func _make_client() -> Object:
	# LLMClient extends Node — we can instantiate but not add to tree
	var client: Object = _script_ref.new()
	return client


# =============================================================================
# _extract_text — TYPE_DICTIONARY with "text" key
# =============================================================================

func test_extract_text_dict_with_text_key() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text({"text": "Hello world"})
	if result != "Hello world":
		push_error("Expected 'Hello world', got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_with_empty_text() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text({"text": ""})
	if result != "":
		push_error("Expected empty string, got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_text_integer() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text({"text": 42})
	if result != "42":
		push_error("Expected '42' (str coercion), got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_text_float() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text({"text": 3.14})
	# str(3.14) in GDScript
	var expected: String = str(3.14)
	if result != expected:
		push_error("Expected '%s', got '%s'" % [expected, result])
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_text_bool() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text({"text": true})
	if result != "true":
		push_error("Expected 'true', got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_text_null() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text({"text": null})
	if result != "<null>":
		push_error("Expected '<null>' (str of null), got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_multiline() -> bool:
	var client: Object = _make_client()
	var multiline: String = "Line 1\nLine 2\nLine 3"
	var result: String = client._extract_text({"text": multiline})
	if result != multiline:
		push_error("Multiline text should be preserved")
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_unicode() -> bool:
	var client: Object = _make_client()
	var unicode_text: String = "Foret de Broceliande"
	var result: String = client._extract_text({"text": unicode_text})
	if result != unicode_text:
		push_error("Unicode text should be preserved")
		client.free()
		return false
	client.free()
	return true


# =============================================================================
# _extract_text — TYPE_DICTIONARY with "lines" key (fallback)
# =============================================================================

func test_extract_text_dict_with_lines_array() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text({"lines": ["First line", "Second line"]})
	if result != "First line":
		push_error("Expected 'First line' (first element), got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_with_empty_lines_array() -> bool:
	var client: Object = _make_client()
	# lines exists but is empty — falls through to str(result)
	var input: Dictionary = {"lines": []}
	var result: String = client._extract_text(input)
	# Should fall through to str(result) since lines.size() == 0
	var expected: String = str(input)
	if result != expected:
		push_error("Expected str(dict), got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_lines_single_element() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text({"lines": ["only line"]})
	if result != "only line":
		push_error("Expected 'only line', got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_lines_integer_elements() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text({"lines": [99, 100]})
	if result != "99":
		push_error("Expected '99' (str coercion of first element), got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_text_takes_priority_over_lines() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text({"text": "from text", "lines": ["from lines"]})
	if result != "from text":
		push_error("'text' key should take priority over 'lines', got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


# =============================================================================
# _extract_text — Non-dictionary inputs (str fallback)
# =============================================================================

func test_extract_text_string_input() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text("plain string")
	if result != "plain string":
		push_error("String input should pass through, got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_integer_input() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text(123)
	if result != "123":
		push_error("Integer input should be str-coerced to '123', got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_float_input() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text(2.718)
	var expected: String = str(2.718)
	if result != expected:
		push_error("Float input should be str-coerced, got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_bool_input() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text(false)
	if result != "false":
		push_error("Bool input should be str-coerced to 'false', got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_null_input() -> bool:
	var client: Object = _make_client()
	var result: String = client._extract_text(null)
	if result != "<null>":
		push_error("Null input should be str-coerced to '<null>', got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_array_input() -> bool:
	var client: Object = _make_client()
	var input: Array = [1, 2, 3]
	var result: String = client._extract_text(input)
	var expected: String = str(input)
	if result != expected:
		push_error("Array input should be str-coerced, got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_empty_dict() -> bool:
	var client: Object = _make_client()
	var input: Dictionary = {}
	var result: String = client._extract_text(input)
	# No "text" key, no "lines" key → falls through to str(result)
	var expected: String = str(input)
	if result != expected:
		push_error("Empty dict should be str-coerced, got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_with_other_keys_only() -> bool:
	var client: Object = _make_client()
	var input: Dictionary = {"status": "ok", "code": 200}
	var result: String = client._extract_text(input)
	var expected: String = str(input)
	if result != expected:
		push_error("Dict without text/lines should be str-coerced, got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


# =============================================================================
# _extract_text — Edge cases
# =============================================================================

func test_extract_text_dict_text_with_special_chars() -> bool:
	var client: Object = _make_client()
	var special: String = "\"quotes\" and 'apostrophes' and \ttabs"
	var result: String = client._extract_text({"text": special})
	if result != special:
		push_error("Special characters should be preserved")
		client.free()
		return false
	client.free()
	return true


func test_extract_text_dict_text_very_long() -> bool:
	var client: Object = _make_client()
	var long_text: String = ""
	for i in range(1000):
		long_text += "word "
	var result: String = client._extract_text({"text": long_text})
	if result != long_text:
		push_error("Long text should be preserved fully")
		client.free()
		return false
	client.free()
	return true


func test_extract_text_nested_dict_in_text() -> bool:
	var client: Object = _make_client()
	var nested: Dictionary = {"inner": "value"}
	var result: String = client._extract_text({"text": nested})
	# str(nested) since text value is a dict
	var expected: String = str(nested)
	if result != expected:
		push_error("Nested dict as text should be str-coerced, got '%s'" % result)
		client.free()
		return false
	client.free()
	return true


# =============================================================================
# Model cache (_models dictionary)
# =============================================================================

func test_models_cache_starts_empty() -> bool:
	var client: Object = _make_client()
	if client._models.size() != 0:
		push_error("_models should start empty, got %d entries" % client._models.size())
		client.free()
		return false
	client.free()
	return true


# =============================================================================
# ping — logic validation (ClassDB.class_exists + FileAccess.file_exists)
# =============================================================================

func test_ping_nonexistent_class_returns_false() -> bool:
	# MerlinLLM class likely does not exist in test environment (GDExtension)
	var client: Object = _make_client()
	var result: bool = client.ping("res://nonexistent_model.gguf")
	# If MerlinLLM class does not exist, ping returns false
	if ClassDB.class_exists("MerlinLLM"):
		# Class exists — result depends on file existence
		client.free()
		return true  # Cannot test further without knowing file state
	if result:
		push_error("ping should return false when MerlinLLM class does not exist")
		client.free()
		return false
	client.free()
	return true


func test_ping_nonexistent_file_returns_false() -> bool:
	var client: Object = _make_client()
	var result: bool = client.ping("res://absolutely_nonexistent_path_12345.gguf")
	# Even if MerlinLLM exists, file does not — should be false
	if result:
		push_error("ping should return false for nonexistent file")
		client.free()
		return false
	client.free()
	return true


# =============================================================================
# Script structure validation
# =============================================================================

func test_script_has_complete_method() -> bool:
	var client: Object = _make_client()
	if not client.has_method("complete"):
		push_error("LLMClient should have 'complete' method")
		client.free()
		return false
	client.free()
	return true


func test_script_has_ping_method() -> bool:
	var client: Object = _make_client()
	if not client.has_method("ping"):
		push_error("LLMClient should have 'ping' method")
		client.free()
		return false
	client.free()
	return true


func test_script_has_extract_text_method() -> bool:
	var client: Object = _make_client()
	if not client.has_method("_extract_text"):
		push_error("LLMClient should have '_extract_text' method")
		client.free()
		return false
	client.free()
	return true


func test_script_has_get_or_load_model_method() -> bool:
	var client: Object = _make_client()
	if not client.has_method("_get_or_load_model"):
		push_error("LLMClient should have '_get_or_load_model' method")
		client.free()
		return false
	client.free()
	return true


func test_script_has_to_fs_path_method() -> bool:
	var client: Object = _make_client()
	if not client.has_method("_to_fs_path"):
		push_error("LLMClient should have '_to_fs_path' method")
		client.free()
		return false
	client.free()
	return true


func test_script_has_request_completed_signal() -> bool:
	var client: Object = _make_client()
	if not client.has_signal("request_completed"):
		push_error("LLMClient should have 'request_completed' signal")
		client.free()
		return false
	client.free()
	return true


func test_script_has_request_failed_signal() -> bool:
	var client: Object = _make_client()
	if not client.has_signal("request_failed"):
		push_error("LLMClient should have 'request_failed' signal")
		client.free()
		return false
	client.free()
	return true


# =============================================================================
# Multiple instances are independent
# =============================================================================

func test_two_clients_independent_caches() -> bool:
	var client_a: Object = _make_client()
	var client_b: Object = _make_client()
	client_a._models["test_key"] = "test_value"
	if client_b._models.has("test_key"):
		push_error("Client B should not share _models cache with Client A")
		client_a.free()
		client_b.free()
		return false
	client_a.free()
	client_b.free()
	return true
