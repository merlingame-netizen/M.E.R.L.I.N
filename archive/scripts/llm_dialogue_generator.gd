## ═══════════════════════════════════════════════════════════════════════════════
## LLM Dialogue Generator — Template-Guided Rephrasing (85% Similarity)
## ═══════════════════════════════════════════════════════════════════════════════
## Uses the LLM to rephrase pre-written dialogue lines while maintaining
## ~85% similarity with the original text. Falls back to the template if
## the LLM is unavailable or produces invalid output.
## ═══════════════════════════════════════════════════════════════════════════════

class_name LLMDialogueGenerator
extends RefCounted

signal line_ready(index: int, text: String)
signal batch_complete

const MAX_RETRIES := 1
const MAX_OUTPUT_RATIO := 1.4  # Generated text must not exceed 140% of template length
const MIN_OUTPUT_RATIO := 0.5  # Generated text must be at least 50% of template length

var _llm_manager: Node = null
var _results: Dictionary = {}  # index -> generated text
var _pending: int = 0
var _tree: SceneTree = null


func setup(scene_tree: SceneTree) -> void:
	_tree = scene_tree
	_llm_manager = scene_tree.root.get_node_or_null("LLMManager")


func is_llm_available() -> bool:
	return _llm_manager != null and _llm_manager.get("is_ready") == true


func get_result(index: int, fallback: String) -> String:
	return _results.get(index, fallback)


func generate_line_async(index: int, template_text: String, emotion: String, lang: String = "fr") -> void:
	if not is_llm_available():
		_results[index] = template_text
		line_ready.emit(index, template_text)
		_check_batch()
		return

	_pending += 1
	var prompt: String = _build_prompt(template_text, emotion, lang)

	var llm: Object = _llm_manager.get_llm()
	if llm == null or not llm.has_method("generate_async"):
		_results[index] = template_text
		line_ready.emit(index, template_text)
		_pending -= 1
		_check_batch()
		return

	# Set conservative sampling for high similarity
	if llm.has_method("set_sampling_params"):
		llm.set_sampling_params(0.3, 0.8, 80)
	if llm.has_method("set_advanced_sampling"):
		llm.set_advanced_sampling(30, 1.5)

	var state := {"done": false, "result": {}}
	llm.generate_async(prompt, func(res):
		state.result = res
		state.done = true
	)

	# Poll until complete (non-blocking via await)
	while not state.done:
		if llm.has_method("poll_result"):
			llm.poll_result()
		await _tree.process_frame

	var generated: String = _extract_text(state.result)
	var validated: String = _validate_output(generated, template_text)

	_results[index] = validated
	line_ready.emit(index, validated)
	_pending -= 1
	_check_batch()


func generate_batch(lines: Array, lang: String = "fr") -> void:
	if lines.is_empty():
		batch_complete.emit()
		return

	for i in range(lines.size()):
		var line: Dictionary = lines[i]
		var text: String = line.get("text", "")
		var emotion: String = line.get("emotion", "neutre")
		if text.is_empty():
			_results[i] = text
			continue
		# Generate each line - they run sequentially since the LLM is single-threaded
		generate_line_async(i, text, emotion, lang)


func _build_prompt(template: String, emotion: String, lang: String) -> String:
	var lang_instruction: String = ""
	match lang:
		"en": lang_instruction = "Respond in English."
		"es": lang_instruction = "Responde en espanol."
		"it": lang_instruction = "Rispondi in italiano."
		"pt": lang_instruction = "Responda em portugues."
		"zh": lang_instruction = "用简体中文回答。"
		"ja": lang_instruction = "日本語で答えてください。"
		_: lang_instruction = "Reponds en francais."

	return "Rephrase: keep same meaning, same tone (%s). Change a few words. 1-2 sentences max. %s\nOriginal: %s\nRephrased:" % [emotion, lang_instruction, template]


func _extract_text(result) -> String:
	if typeof(result) == TYPE_DICTIONARY:
		if result.has("text"):
			return str(result.text).strip_edges()
		if result.has("lines") and result.lines.size() > 0:
			return str(result.lines[0]).strip_edges()
		if result.has("error"):
			return ""
	if typeof(result) == TYPE_STRING:
		return result.strip_edges()
	return str(result).strip_edges()


func _validate_output(generated: String, template: String) -> String:
	# Empty or error → fallback
	if generated.is_empty():
		return template

	# Remove any leading quotes or "Rephrased:" prefix the LLM might echo
	generated = generated.strip_edges()
	if generated.begins_with("\"") and generated.ends_with("\""):
		generated = generated.substr(1, generated.length() - 2)
	if generated.begins_with("Rephrased:"):
		generated = generated.substr(10).strip_edges()

	# Length validation
	var template_len: int = template.length()
	if template_len > 0:
		var ratio: float = float(generated.length()) / float(template_len)
		if ratio > MAX_OUTPUT_RATIO or ratio < MIN_OUTPUT_RATIO:
			return template

	# Clean tags that might have been added
	generated = generated.replace("[beat]", "").replace("[pause]", "").replace("[long_pause]", "")
	while generated.find("  ") != -1:
		generated = generated.replace("  ", " ")

	return generated.strip_edges()


func _check_batch() -> void:
	if _pending <= 0:
		_pending = 0
		batch_complete.emit()
