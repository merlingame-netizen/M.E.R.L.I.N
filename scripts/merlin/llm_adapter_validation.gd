## ═══════════════════════════════════════════════════════════════════════════════
## LLM Adapter — Card & Effect Validation
## ═══════════════════════════════════════════════════════════════════════════════
## Validates and sanitizes faction-based cards, legacy cards, options, effects.
## Converts effects to string codes. Enforces whitelists and caps.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name LlmAdapterValidation


## Validate and sanitize a faction-based card from LLM response.
func validate_faction_card(card: Dictionary, allowed_effects: Array, factions: Array) -> Dictionary:
	var result := {"ok": false, "errors": [], "card": {}}

	# Check text
	if not card.has("text") or typeof(card["text"]) != TYPE_STRING or str(card["text"]).is_empty():
		result["errors"].append("Missing or empty text")
		return result

	# Check options
	if not card.has("options") or typeof(card["options"]) != TYPE_ARRAY:
		result["errors"].append("Missing options array")
		return result

	var options_arr: Array = card["options"]
	if options_arr.size() < 2 or options_arr.size() > 3:
		result["errors"].append("Need 2-3 options, got %d" % options_arr.size())
		return result

	# Sanitize card
	var sanitized := card.duplicate(true)

	# Validate each option
	for i in range(sanitized["options"].size()):
		sanitized["options"][i] = _validate_faction_option(sanitized["options"][i], allowed_effects, factions)

	# If only 2 options, insert a neutral center option
	if sanitized["options"].size() == 2:
		sanitized["options"].insert(1, {
			"label": "Mediter",
			"cost": 1,
			"effects": [{"type": "ADD_KARMA", "amount": 1}],
		})

	# Ensure speaker
	if not sanitized.has("speaker") or typeof(sanitized["speaker"]) != TYPE_STRING:
		sanitized["speaker"] = "merlin"

	# Ensure tags
	if not sanitized.has("tags") or typeof(sanitized["tags"]) != TYPE_ARRAY:
		sanitized["tags"] = ["llm_generated"]
	else:
		var valid_tags: Array = []
		for tag in sanitized["tags"]:
			if typeof(tag) == TYPE_STRING:
				valid_tags.append(tag)
		valid_tags.append("llm_generated")
		sanitized["tags"] = valid_tags

	# Add metadata
	sanitized["id"] = "llm_%d" % Time.get_ticks_msec()
	sanitized["_generated_by"] = "merlin_llm_adapter"

	result["ok"] = true
	result["card"] = sanitized
	return result


func _validate_faction_option(option, allowed_effects: Array, factions: Array) -> Dictionary:
	if typeof(option) != TYPE_DICTIONARY:
		return {"label": "...", "effects": []}

	var sanitized := {}
	sanitized["label"] = str(option.get("label", "..."))
	if sanitized["label"].is_empty():
		sanitized["label"] = "..."

	# Preserve cost if present (center option)
	if option.has("cost"):
		sanitized["cost"] = int(option["cost"])

	# Validate effects
	var effects_raw = option.get("effects", [])
	if typeof(effects_raw) != TYPE_ARRAY:
		effects_raw = []

	var valid_effects: Array = []
	for effect in effects_raw:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var validated := validate_faction_effect(effect, allowed_effects, factions)
		if not validated.is_empty():
			valid_effects.append(validated)

	sanitized["effects"] = valid_effects

	# Preserve gameplay keys set by _wrap_text_as_card and Stage 3
	for key in ["dc_hint", "risk_level", "reward_type", "result_success", "result_failure", "action_desc", "verb_source"]:
		if option.has(key):
			sanitized[key] = option[key]

	return sanitized


func validate_faction_effect(effect: Dictionary, allowed_effects: Array, factions: Array) -> Dictionary:
	var effect_type := str(effect.get("type", ""))
	if not effect_type in allowed_effects:
		return {}

	match effect_type:
		"ADD_REPUTATION":
			var faction: String = str(effect.get("faction", ""))
			# SEC-3: Cap matches MerlinReputationSystem.CAP_PER_CARD (±20)
			var amount: float = clampf(float(effect.get("amount", 0.0)), -20.0, 20.0)
			if faction in factions:
				return {"type": "ADD_REPUTATION", "faction": faction, "amount": amount}
			return {}

		"DAMAGE_LIFE", "HEAL_LIFE":
			var amount := clampi(int(effect.get("amount", 5)), 1, 20)
			return {"type": effect_type, "amount": amount}

		"UNLOCK_OGHAM":
			var ogham := str(effect.get("ogham", ""))
			# SEC-5: Only accept known oghams from the full specs list
			if ogham.is_empty() or ogham not in MerlinConstants.OGHAM_FULL_SPECS:
				return {}
			return {"type": "UNLOCK_OGHAM", "ogham": ogham}

		"PROGRESS_MISSION":
			return {"type": "PROGRESS_MISSION", "step": clampi(int(effect.get("step", 1)), 0, 3)}

		"ADD_KARMA", "ADD_TENSION":
			return {"type": effect_type, "amount": clampi(int(effect.get("amount", 0)), -20, 20)}

		"ADD_NARRATIVE_DEBT":
			var debt_type := str(effect.get("debt_type", ""))
			var desc := str(effect.get("description", ""))
			if debt_type.is_empty():
				return {}
			return {"type": "ADD_NARRATIVE_DEBT", "debt_type": debt_type, "description": desc}

		"SET_FLAG":
			var flag := str(effect.get("flag", ""))
			if flag.is_empty():
				return {}
			return {"type": "SET_FLAG", "flag": flag, "value": bool(effect.get("value", true))}

		"ADD_TAG", "REMOVE_TAG":
			var tag := str(effect.get("tag", ""))
			if tag.is_empty():
				return {}
			return {"type": effect_type, "tag": tag}

		"TRIGGER_EVENT":
			var event_id := str(effect.get("event_id", ""))
			if event_id.is_empty():
				return {}
			return {"type": "TRIGGER_EVENT", "event_id": event_id}

		"CREATE_PROMISE", "FULFILL_PROMISE", "BREAK_PROMISE":
			var promise_id := str(effect.get("promise_id", ""))
			if not promise_id.is_empty():
				return {"type": effect_type, "promise_id": promise_id}
			return {}

		"ADD_ANAM":
			var amount := clampi(int(effect.get("amount", 1)), 1, 10)
			return {"type": "ADD_ANAM", "amount": amount}

		"ADD_BIOME_CURRENCY":
			var amount := clampi(int(effect.get("amount", 1)), 1, int(MerlinConstants.EFFECT_CAPS.get("ADD_BIOME_CURRENCY", {}).get("max", 10)))
			return {"type": "ADD_BIOME_CURRENCY", "amount": amount}

	return {}


## Legacy card validation (2-option left/right format).
func validate_card(card: Dictionary, effect_engine: MerlinEffectEngine, required_keys: Array, required_option_keys: Array, valid_directions: Array, allowed_effects: Array) -> Dictionary:
	var result := {"ok": false, "errors": [], "card": {}}

	for key in required_keys:
		if not card.has(key):
			result["errors"].append("Missing required key: %s" % key)
			return result

	if typeof(card["text"]) != TYPE_STRING or card["text"].is_empty():
		result["errors"].append("Card text must be a non-empty string")
		return result

	if typeof(card["options"]) != TYPE_ARRAY:
		result["errors"].append("Options must be an array")
		return result

	if card["options"].size() != 2:
		result["errors"].append("Card must have exactly 2 options (left/right)")
		return result

	var sanitized_card := card.duplicate(true)
	var has_left := false
	var has_right := false

	for i in range(sanitized_card["options"].size()):
		var option = sanitized_card["options"][i]
		var opt_result = _validate_option(option, effect_engine, required_option_keys, valid_directions, allowed_effects)
		if not opt_result["ok"]:
			result["errors"].append_array(opt_result["errors"])
			return result
		sanitized_card["options"][i] = opt_result["option"]
		if option["direction"] == "left":
			has_left = true
		elif option["direction"] == "right":
			has_right = true

	if not has_left or not has_right:
		result["errors"].append("Card must have one 'left' and one 'right' option")
		return result

	if card.has("speaker") and typeof(card["speaker"]) != TYPE_STRING:
		sanitized_card.erase("speaker")

	if card.has("tags"):
		if typeof(card["tags"]) != TYPE_ARRAY:
			sanitized_card["tags"] = []
		else:
			var valid_tags := []
			for tag in card["tags"]:
				if typeof(tag) == TYPE_STRING:
					valid_tags.append(tag)
			sanitized_card["tags"] = valid_tags
	else:
		sanitized_card["tags"] = []

	# Validate card type (inline list, legacy constants removed)
	var valid_card_types := ["narrative", "event", "promise", "merlin_direct"]
	if card.has("type"):
		if not card["type"] in valid_card_types:
			sanitized_card["type"] = "narrative"
	else:
		sanitized_card["type"] = "narrative"

	result["ok"] = true
	result["card"] = sanitized_card
	return result


func _validate_option(option: Dictionary, effect_engine: MerlinEffectEngine, required_option_keys: Array, valid_directions: Array, allowed_effects: Array) -> Dictionary:
	var result := {"ok": false, "errors": [], "option": {}}

	for key in required_option_keys:
		if not option.has(key):
			result["errors"].append("Option missing key: %s" % key)
			return result

	if not option["direction"] in valid_directions:
		result["errors"].append("Invalid direction: %s" % option["direction"])
		return result

	if typeof(option["label"]) != TYPE_STRING or option["label"].is_empty():
		result["errors"].append("Option label must be non-empty string")
		return result

	if typeof(option["effects"]) != TYPE_ARRAY:
		result["errors"].append("Effects must be an array")
		return result

	var sanitized_option := option.duplicate(true)
	sanitized_option["effects"] = _filter_effects(option["effects"], effect_engine, allowed_effects)

	if sanitized_option["effects"].is_empty():
		sanitized_option["effects"] = [{"type": "HEAL_LIFE", "amount": 3}]

	if option.has("preview_hint") and typeof(option["preview_hint"]) != TYPE_STRING:
		sanitized_option.erase("preview_hint")

	result["ok"] = true
	result["option"] = sanitized_option
	return result


func _filter_effects(effects: Array, effect_engine: MerlinEffectEngine, allowed_effects: Array) -> Array:
	var filtered := []
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var effect_type = effect.get("type", "")
		if not effect_type in allowed_effects:
			continue
		var validated = _validate_effect(effect, effect_engine)
		if validated != null:
			filtered.append(validated)
	return filtered


func _validate_effect(effect: Dictionary, _effect_engine: MerlinEffectEngine) -> Variant:
	var effect_type = effect.get("type", "")

	match effect_type:
		"SET_FLAG":
			var flag = effect.get("flag", "")
			if flag.is_empty():
				return null
			var value = effect.get("value", false)
			return {"type": "SET_FLAG", "flag": flag, "value": bool(value)}

		"ADD_TAG", "REMOVE_TAG":
			var tag = effect.get("tag", "")
			if tag.is_empty():
				return null
			return {"type": effect_type, "tag": tag}

		"QUEUE_CARD":
			var card_id = effect.get("card_id", "")
			if card_id.is_empty():
				return null
			return {"type": "QUEUE_CARD", "card_id": card_id}

		"TRIGGER_ARC":
			var arc_id = effect.get("arc_id", "")
			if arc_id.is_empty():
				return null
			return {"type": "TRIGGER_ARC", "arc_id": arc_id}

		"CREATE_PROMISE":
			var id = effect.get("id", "")
			var deadline = int(effect.get("deadline_days", 5))
			var desc = effect.get("description", "")
			if id.is_empty():
				return null
			deadline = clampi(deadline, 1, 30)
			return {"type": "CREATE_PROMISE", "id": id, "deadline_days": deadline, "description": desc}

	return null


## Convert dict effects to string codes.
func effects_to_codes(effects: Array) -> Array:
	var codes := []
	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var code = _effect_to_code(effect)
		if not code.is_empty():
			codes.append(code)
	return codes


func _effect_to_code(effect: Dictionary) -> String:
	var effect_type = effect.get("type", "")

	match effect_type:
		"ADD_REPUTATION":
			return "ADD_REPUTATION:%s:%d" % [effect.get("faction", ""), int(effect.get("amount", 0))]
		"HEAL_LIFE":
			return "HEAL_LIFE:%d" % int(effect.get("amount", 0))
		"DAMAGE_LIFE":
			return "DAMAGE_LIFE:%d" % int(effect.get("amount", 0))
		"ADD_ANAM":
			return "ADD_ANAM:%d" % int(effect.get("amount", 0))
		"ADD_BIOME_CURRENCY":
			return "ADD_BIOME_CURRENCY:%d" % int(effect.get("amount", 0))
		"UNLOCK_OGHAM":
			return "UNLOCK_OGHAM:%s" % effect.get("ogham", "")
		"SET_FLAG":
			var val = "true" if effect.get("value", false) else "false"
			return "SET_FLAG:%s:%s" % [effect.get("flag", ""), val]
		"ADD_TAG":
			return "ADD_TAG:%s" % effect.get("tag", "")
		"REMOVE_TAG":
			return "REMOVE_TAG:%s" % effect.get("tag", "")
		"QUEUE_CARD":
			return "QUEUE_CARD:%s" % effect.get("card_id", "")
		"TRIGGER_ARC":
			return "TRIGGER_ARC:%s" % effect.get("arc_id", "")
		"CREATE_PROMISE":
			return "CREATE_PROMISE:%s:%d:%s" % [
				effect.get("id", ""),
				effect.get("deadline_days", 5),
				effect.get("description", "")
			]
	return ""
