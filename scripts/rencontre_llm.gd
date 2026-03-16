## ═══════════════════════════════════════════════════════════════════════════════
## RencontreLLM — LLM generation logic for SceneRencontreMerlin
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted module: handles RAG-based narrative generation and response parsing.
## ═══════════════════════════════════════════════════════════════════════════════

class_name RencontreLLM
extends RefCounted

## RAG system prompts for LLM-guided intro phases
const RAG_INTRO_CONTEXT := "Tu es Merlin le druide. Un voyageur (%s) arrive a Broceliande. 2 phrases maximum: accueille-le. Ton bienveillant. Francais."
const RAG_OGHAM_REVEAL := "Tu es Merlin. Tu reveles 3 Oghams sacres au voyageur. 2 phrases maximum, ton amuse. Francais."
const RAG_MISSION_HUB := "Tu es Merlin. Explique au voyageur: Carte du Monde, Oghams, sauvegardes. 2 phrases maximum, ton encourageant. Francais."

const LLM_STEP_TIMEOUT := 3.2
const LLM_POLL_INTERVAL := 0.12

var _scene: Control


func _init(scene: Control) -> void:
	_scene = scene


## LLM generate from RAG prompt — returns full narrative text or "" on failure
func generate_from_rag(rag_prompt: String) -> String:
	var merlin_ai: Node = _scene.merlin_ai
	if merlin_ai == null or not merlin_ai.is_ready:
		return ""
	if not merlin_ai.has_method("generate_narrative"):
		return ""

	_scene._dialogue_module.show_llm_waiting()
	var result: Dictionary = await merlin_ai.generate_narrative(rag_prompt, "Genere le texte.", {"max_tokens": 80, "temperature": 0.7})
	_scene._dialogue_module.hide_llm_waiting()

	if result.has("error"):
		return ""
	var text: String = str(result.get("text", "")).strip_edges()
	if text.length() < 15:
		return ""
	return text


## LLM generate 3 player responses to a Merlin line
func generate_responses(context_line: String, line_index: int) -> Array[String]:
	var merlin_ai: Node = _scene.merlin_ai
	if merlin_ai == null or not merlin_ai.is_ready:
		_scene._last_response_source = "fallback"
		return get_fallback_responses(line_index)

	var system := "Tu es l'assistant d'un jeu narratif. Genere 3 reponses courtes (5-10 mots chacune) du joueur a Merlin. JSON array de 3 strings. Francais."
	var user_input := "Merlin dit: \"%s\"" % context_line

	# Use Dictionary (reference type) — lambdas capture locals by value in GDScript 4
	var state := {"done": false, "result": {}}
	var _do := func():
		state["result"] = await merlin_ai.generate_narrative(system, user_input, {"max_tokens": 60, "temperature": 0.6})
		state["done"] = true
	_do.call()

	var elapsed := 0.0
	while not state["done"] and elapsed < LLM_STEP_TIMEOUT:
		if not _scene.is_inside_tree():
			return get_fallback_responses(line_index)
		await _scene.get_tree().create_timer(LLM_POLL_INTERVAL).timeout
		elapsed += LLM_POLL_INTERVAL

	if not state["done"] or state["result"].has("error"):
		_scene._last_response_source = "fallback"
		return get_fallback_responses(line_index)

	var raw_text: String = str(state["result"].get("text", ""))
	var parsed: Array[String] = _parse_response_array(raw_text)
	if parsed.size() >= 3:
		_scene._last_response_source = "llm"
		return parsed

	_scene._last_response_source = "fallback"
	return get_fallback_responses(line_index)


func _parse_response_array(raw_text: String) -> Array[String]:
	var json := JSON.new()
	# Try direct parse
	if json.parse(raw_text) == OK and json.data is Array:
		var arr: Array = json.data
		if arr.size() >= 3:
			var out: Array[String] = []
			for i in range(3):
				out.append(str(arr[i]).strip_edges())
			return out

	# Try extracting JSON from mixed output (LLM may wrap in text)
	var bracket_start := raw_text.find("[")
	var bracket_end := raw_text.rfind("]")
	if bracket_start >= 0 and bracket_end > bracket_start:
		var json_slice := raw_text.substr(bracket_start, bracket_end - bracket_start + 1)
		if json.parse(json_slice) == OK and json.data is Array:
			var arr: Array = json.data
			if arr.size() >= 3:
				var out: Array[String] = []
				for i in range(3):
					out.append(str(arr[i]).strip_edges())
				return out

	return []


func get_fallback_responses(line_index: int) -> Array[String]:
	if line_index == 1:
		return [
			"Je suis la. Que dois-je faire ?",
			"Longtemps ? Tu comptais les siecles ?",
			"La brume m'a guide jusqu'ici.",
		]
	return [
		"Je suis pret. Montre-moi ce monde.",
		"Meme dans la brume, je te fais confiance.",
		"Le bout du monde ne me fait pas peur.",
	]
