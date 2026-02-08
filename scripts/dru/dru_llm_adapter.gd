## ═══════════════════════════════════════════════════════════════════════════════
## DRU LLM Adapter — Reigns-Style Card Contract
## ═══════════════════════════════════════════════════════════════════════════════
## Handles communication with LLM for generating narrative cards.
## Updated 2026-02-05 for Reigns-style gameplay.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name DruLlmAdapter

const VERSION := "2.0.0"

# ═══════════════════════════════════════════════════════════════════════════════
# WHITELIST — Only these effect types are allowed from LLM
# ═══════════════════════════════════════════════════════════════════════════════

const ALLOWED_EFFECT_TYPES := [
	"ADD_GAUGE",
	"REMOVE_GAUGE",
	"SET_FLAG",
	"ADD_TAG",
	"REMOVE_TAG",
	"QUEUE_CARD",
	"TRIGGER_ARC",
	"CREATE_PROMISE",
	"MODIFY_BOND",
]

const REQUIRED_CARD_KEYS := ["text", "options"]
const REQUIRED_OPTION_KEYS := ["direction", "label", "effects"]
const VALID_DIRECTIONS := ["left", "right"]
const VALID_GAUGES := ["Vigueur", "Esprit", "Faveur", "Ressources"]

# Effect value limits
const MAX_GAUGE_DELTA := 40
const MIN_GAUGE_DELTA := -40


# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXT BUILDING — Prepare state for LLM
# ═══════════════════════════════════════════════════════════════════════════════

func build_context(state: Dictionary) -> Dictionary:
	"""Build the context object sent to LLM for card generation."""
	var run = state.get("run", {})
	var bestiole = state.get("bestiole", {})
	var gauges = run.get("gauges", {})

	# Identify critical gauges (near 0 or 100)
	var critical_gauges := []
	for gauge_name in VALID_GAUGES:
		var value = int(gauges.get(gauge_name, 50))
		if value <= DruConstants.REIGNS_GAUGE_CRITICAL_LOW:
			critical_gauges.append({"name": gauge_name, "value": value, "direction": "low"})
		elif value >= DruConstants.REIGNS_GAUGE_CRITICAL_HIGH:
			critical_gauges.append({"name": gauge_name, "value": value, "direction": "high"})

	# Get available bestiole skills (not on cooldown)
	var skills_ready := []
	var cooldowns = bestiole.get("skill_cooldowns", {})
	var equipped = bestiole.get("skills_equipped", [])
	for skill_id in equipped:
		if int(cooldowns.get(skill_id, 0)) <= 0:
			skills_ready.append(skill_id)

	# Determine bestiole mood based on needs
	var needs = bestiole.get("needs", {})
	var mood := "neutral"
	var avg_needs = (int(needs.get("Hunger", 50)) + int(needs.get("Energy", 50)) +
					int(needs.get("Mood", 50)) - int(needs.get("Stress", 0))) / 4.0
	if avg_needs >= 70:
		mood = "happy"
	elif avg_needs >= 40:
		mood = "content"
	elif avg_needs >= 20:
		mood = "tired"
	else:
		mood = "distressed"

	return {
		"gauges": gauges.duplicate(),
		"critical_gauges": critical_gauges,
		"bestiole": {
			"name": bestiole.get("name", "Bestiole"),
			"mood": mood,
			"bond": int(bestiole.get("bond", 50)),
			"skills_ready": skills_ready,
		},
		"day": int(run.get("day", 1)),
		"cards_played": int(run.get("cards_played", 0)),
		"active_promises": run.get("active_promises", []),
		"story_log": _get_recent_story_log(run.get("story_log", []), 10),
		"active_tags": run.get("active_tags", []),
		"current_arc": run.get("current_arc", ""),
		"flags": state.get("flags", {}),
	}


func generate_card(context: Dictionary) -> Dictionary:
	"""Generate a card via LLM if available. Returns {ok: bool, card: Dictionary, error: String}."""
	if context.is_empty():
		return {"ok": false, "card": {}, "error": "Empty context"}

	# LLM integration not wired in this adapter yet.
	# Return not-ok so callers can fall back to scripted cards.
	return {"ok": false, "card": {}, "error": "LLM adapter not connected"}


func _get_recent_story_log(log: Array, count: int) -> Array:
	"""Get the most recent entries from story log."""
	if log.size() <= count:
		return log.duplicate()
	return log.slice(log.size() - count, log.size())


# ═══════════════════════════════════════════════════════════════════════════════
# CARD VALIDATION — Ensure LLM response is safe
# ═══════════════════════════════════════════════════════════════════════════════

func validate_card(card: Dictionary, effect_engine: DruEffectEngine = null) -> Dictionary:
	"""Validate a card from LLM and sanitize effects."""
	var result := {"ok": false, "errors": [], "card": {}}

	# Check required keys
	for key in REQUIRED_CARD_KEYS:
		if not card.has(key):
			result["errors"].append("Missing required key: %s" % key)
			return result

	# Validate text
	if typeof(card["text"]) != TYPE_STRING or card["text"].is_empty():
		result["errors"].append("Card text must be a non-empty string")
		return result

	# Validate options array
	if typeof(card["options"]) != TYPE_ARRAY:
		result["errors"].append("Options must be an array")
		return result

	if card["options"].size() != 2:
		result["errors"].append("Card must have exactly 2 options (left/right)")
		return result

	# Validate each option
	var sanitized_card := card.duplicate(true)
	var has_left := false
	var has_right := false

	for i in range(sanitized_card["options"].size()):
		var option = sanitized_card["options"][i]
		var opt_result = _validate_option(option, effect_engine)
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

	# Validate optional fields
	if card.has("speaker") and typeof(card["speaker"]) != TYPE_STRING:
		sanitized_card.erase("speaker")

	if card.has("tags"):
		if typeof(card["tags"]) != TYPE_ARRAY:
			sanitized_card["tags"] = []
		else:
			# Filter to strings only
			var valid_tags := []
			for tag in card["tags"]:
				if typeof(tag) == TYPE_STRING:
					valid_tags.append(tag)
			sanitized_card["tags"] = valid_tags
	else:
		sanitized_card["tags"] = []

	if card.has("type"):
		if not card["type"] in DruConstants.REIGNS_CARD_TYPES:
			sanitized_card["type"] = "narrative"
	else:
		sanitized_card["type"] = "narrative"

	result["ok"] = true
	result["card"] = sanitized_card
	return result


func _validate_option(option: Dictionary, effect_engine: DruEffectEngine) -> Dictionary:
	"""Validate a single option and its effects."""
	var result := {"ok": false, "errors": [], "option": {}}

	# Check required keys
	for key in REQUIRED_OPTION_KEYS:
		if not option.has(key):
			result["errors"].append("Option missing key: %s" % key)
			return result

	# Validate direction
	if not option["direction"] in VALID_DIRECTIONS:
		result["errors"].append("Invalid direction: %s" % option["direction"])
		return result

	# Validate label
	if typeof(option["label"]) != TYPE_STRING or option["label"].is_empty():
		result["errors"].append("Option label must be non-empty string")
		return result

	# Validate and filter effects
	if typeof(option["effects"]) != TYPE_ARRAY:
		result["errors"].append("Effects must be an array")
		return result

	var sanitized_option := option.duplicate(true)
	sanitized_option["effects"] = _filter_effects(option["effects"], effect_engine)

	# Ensure at least one effect (prevent no-op cards)
	if sanitized_option["effects"].is_empty():
		# Add a minimal neutral effect
		sanitized_option["effects"] = [{"type": "ADD_GAUGE", "target": "Vigueur", "value": 0}]

	# Validate optional preview_hint
	if option.has("preview_hint") and typeof(option["preview_hint"]) != TYPE_STRING:
		sanitized_option.erase("preview_hint")

	result["ok"] = true
	result["option"] = sanitized_option
	return result


func _filter_effects(effects: Array, effect_engine: DruEffectEngine) -> Array:
	"""Filter effects to only allow whitelisted types with valid values."""
	var filtered := []

	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue

		var effect_type = effect.get("type", "")
		if not effect_type in ALLOWED_EFFECT_TYPES:
			continue

		var validated = _validate_effect(effect, effect_engine)
		if validated != null:
			filtered.append(validated)

	return filtered


func _validate_effect(effect: Dictionary, effect_engine: DruEffectEngine) -> Variant:
	"""Validate a single effect and return sanitized version or null."""
	var effect_type = effect.get("type", "")

	match effect_type:
		"ADD_GAUGE", "REMOVE_GAUGE":
			var target = effect.get("target", "")
			if not target in VALID_GAUGES:
				return null
			var value = int(effect.get("value", 0))
			value = clampi(value, MIN_GAUGE_DELTA, MAX_GAUGE_DELTA)
			if effect_type == "REMOVE_GAUGE":
				value = -abs(value)
			return {"type": effect_type, "target": target, "value": value}

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

		"MODIFY_BOND":
			var value = int(effect.get("value", 0))
			value = clampi(value, -20, 20)
			return {"type": "MODIFY_BOND", "value": value}

	return null


# ═══════════════════════════════════════════════════════════════════════════════
# EFFECT CONVERSION — Convert dict effects to string codes
# ═══════════════════════════════════════════════════════════════════════════════

func effects_to_codes(effects: Array) -> Array:
	"""Convert validated effect dictionaries to string codes for effect engine."""
	var codes := []

	for effect in effects:
		if typeof(effect) != TYPE_DICTIONARY:
			continue
		var code = _effect_to_code(effect)
		if not code.is_empty():
			codes.append(code)

	return codes


func _effect_to_code(effect: Dictionary) -> String:
	"""Convert a single effect dict to a string code."""
	var effect_type = effect.get("type", "")

	match effect_type:
		"ADD_GAUGE":
			return "ADD_GAUGE:%s:%d" % [effect.get("target", ""), effect.get("value", 0)]
		"REMOVE_GAUGE":
			return "REMOVE_GAUGE:%s:%d" % [effect.get("target", ""), abs(effect.get("value", 0))]
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
		"MODIFY_BOND":
			return "MODIFY_BOND:%d" % effect.get("value", 0)

	return ""


# ═══════════════════════════════════════════════════════════════════════════════
# SYSTEM PROMPT GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func get_system_prompt() -> String:
	"""Get the system prompt for the LLM to generate cards."""
	return """Tu es Merlin, l'IA qui dirige le monde du jeu DRU.
Tu generes des cartes narratives style Reigns pour le joueur.

REGLES ABSOLUES:
1. Chaque carte a exactement 2 choix: gauche et droite
2. Chaque choix affecte au moins une des 4 jauges: Vigueur, Esprit, Faveur, Ressources
3. La plupart des cartes sont des tradeoffs (+ sur une jauge, - sur une autre)
4. Les valeurs d'effet sont entre -40 et +40, typiquement -15 a +15
5. Si une jauge est critique (basse ou haute), propose des choix qui peuvent l'equilibrer

FORMAT DE REPONSE (JSON strict):
{
  "text": "Texte narratif de la carte...",
  "speaker": "MERLIN",
  "type": "narrative",
  "options": [
    {
      "direction": "left",
      "label": "Texte court du bouton",
      "effects": [
        {"type": "ADD_GAUGE", "target": "Vigueur", "value": 10},
        {"type": "REMOVE_GAUGE", "target": "Ressources", "value": 5}
      ],
      "preview_hint": "[+Vigueur, -Ressources]"
    },
    {
      "direction": "right",
      "label": "Autre choix",
      "effects": [
        {"type": "REMOVE_GAUGE", "target": "Vigueur", "value": 5},
        {"type": "ADD_GAUGE", "target": "Faveur", "value": 15}
      ],
      "preview_hint": "[-Vigueur, +Faveur]"
    }
  ],
  "tags": ["tag1", "tag2"]
}

TYPES D'EFFETS AUTORISES:
- ADD_GAUGE / REMOVE_GAUGE: Modifier une jauge
- SET_FLAG: Definir un flag narratif
- ADD_TAG / REMOVE_TAG: Gerer les tags actifs
- CREATE_PROMISE: Creer une promesse avec deadline
- MODIFY_BOND: Modifier le lien avec Bestiole

CONTEXTE IMPORTANT:
- Si une jauge est critique basse (<15), propose des choix qui peuvent la remonter
- Si une jauge est critique haute (>85), propose des choix qui peuvent la baisser
- Fais reference aux tags actifs et aux promesses en cours
- Maintiens la coherence narrative avec le story_log"""


# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY SUPPORT — Old scene validation (DEPRECATED)
# ═══════════════════════════════════════════════════════════════════════════════

const LEGACY_REQUIRED_KEYS := ["scene_id", "biome", "backdrop", "text_pages", "choices"]
const LEGACY_VERBS := ["FORCE", "LOGIQUE", "FINESSE"]

func validate_scene(scene: Dictionary, effect_engine: DruEffectEngine) -> Dictionary:
	"""DEPRECATED: Legacy scene validation for old combat system."""
	push_warning("DruLlmAdapter.validate_scene() is deprecated. Use validate_card() instead.")
	var result := {"ok": false, "errors": [], "scene": {}}
	if typeof(scene) != TYPE_DICTIONARY:
		result["errors"].append("Scene is not a dictionary")
		return result
	for key in LEGACY_REQUIRED_KEYS:
		if not scene.has(key):
			result["errors"].append("Missing key: %s" % key)
			return result
	result["ok"] = true
	result["scene"] = scene.duplicate(true)
	return result
