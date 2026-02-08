extends RefCounted
class_name DruLlmAdapter

const REQUIRED_KEYS := ["scene_id", "biome", "backdrop", "text_pages", "choices"]
const VERBS := ["FORCE", "LOGIQUE", "FINESSE"]

func validate_scene(scene: Dictionary, effect_engine: DruEffectEngine) -> Dictionary:
	var result := {"ok": false, "errors": [], "scene": {}}
	if typeof(scene) != TYPE_DICTIONARY:
		result["errors"].append("Scene is not a dictionary")
		return result
	for key in REQUIRED_KEYS:
		if not scene.has(key):
			result["errors"].append("Missing key: %s" % key)
			return result
	if typeof(scene["text_pages"]) != TYPE_ARRAY:
		result["errors"].append("text_pages must be array")
		return result
	if typeof(scene["choices"]) != TYPE_DICTIONARY:
		result["errors"].append("choices must be dictionary")
		return result

	var sanitized := scene.duplicate(true)
	for verb in VERBS:
		if not sanitized["choices"].has(verb):
			result["errors"].append("Missing choices for %s" % verb)
			return result
		var entries = sanitized["choices"][verb]
		if typeof(entries) != TYPE_ARRAY:
			result["errors"].append("Choices for %s must be array" % verb)
			return result
		if entries.size() < 1 or entries.size() > 2:
			result["errors"].append("Choices for %s must have 1-2 entries" % verb)
			return result
		for i in range(entries.size()):
			var entry = entries[i]
			if typeof(entry) != TYPE_DICTIONARY:
				result["errors"].append("Choice entry must be dictionary")
				return result
			if not entry.has("hidden_test"):
				result["errors"].append("Missing hidden_test for %s choice" % verb)
				return result
			entry["on_success"] = _filter_effects(entry.get("on_success", []), effect_engine)
			entry["on_fail"] = _filter_effects(entry.get("on_fail", []), effect_engine)
			entries[i] = entry
		sanitized["choices"][verb] = entries

	result["ok"] = true
	result["scene"] = sanitized
	return result


func _filter_effects(effects: Array, effect_engine: DruEffectEngine) -> Array:
	if typeof(effects) != TYPE_ARRAY:
		return []
	var filtered := []
	for effect in effects:
		if typeof(effect) != TYPE_STRING:
			continue
		if effect_engine != null and effect_engine.validate_effect(effect):
			filtered.append(effect)
	return filtered
