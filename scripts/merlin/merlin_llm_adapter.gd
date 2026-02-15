## ═══════════════════════════════════════════════════════════════════════════════
## Merlin LLM Adapter — Card Contract (TRIADE + Legacy REIGNS)
## ═══════════════════════════════════════════════════════════════════════════════
## Handles communication with LLM for generating narrative cards.
## v3.0.0 — TRIADE system wired to MerlinAI autoload.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name MerlinLlmAdapter

const VERSION := "3.0.0"

# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE WHITELIST — Effects allowed from LLM in TRIADE mode
# ═══════════════════════════════════════════════════════════════════════════════

const TRIADE_EFFECT_TYPES := [
	"USE_SOUFFLE",
	"ADD_SOUFFLE",
	"PROGRESS_MISSION",
	"ADD_KARMA",
	"ADD_TENSION",
	"ADD_NARRATIVE_DEBT",
	"DAMAGE_LIFE",
	"HEAL_LIFE",
	"SET_FLAG",
	"ADD_TAG",
	"CREATE_PROMISE",
	"FULFILL_PROMISE",
	"BREAK_PROMISE",
]

const TRIADE_ASPECTS := ["Corps", "Ame", "Monde"]
const TRIADE_DIRECTIONS := ["up", "down"]
const TRIADE_STATES := [-1, 0, 1]

# LLM generation params tuned for Qwen 2.5-3B-Instruct
const TRIADE_LLM_PARAMS := {
	"max_tokens": 250,  # ~60s on CPU (was 480 = 120s timeout)
	"temperature": 0.6,
	"top_p": 0.85,
	"top_k": 30,
	"repetition_penalty": 1.5,
}

const GENERATION_TIMEOUT_MS := 8000

# Rotating celtic theme keywords — injected into prompts for variety
const CELTIC_THEMES: Array[String] = [
	"nemeton sacre", "brume matinale", "dolmen ancien", "sources enchantees",
	"korrigans farceurs", "cercle de pierres", "chene millénaire", "sidhe lumineux",
	"lande sauvage", "torque d'or", "chaudron de Dagda", "harpe de Taliesin",
	"gui sacre", "serment de sang", "barque de verre", "fontaine de Barenton",
	"cavalier spectral", "feu de Beltaine", "nuit de Samhain", "aurore druidique",
	"marais brumeux", "grotte aux cristaux", "sentier des fées", "île d'Avalon",
	"loup blanc", "cerf aux bois d'argent", "corbeau prophete", "saumon de sagesse",
	"racines du monde", "vent du nord", "tonnerre lointain", "pluie d'étoiles",
]

# Multiple fallback label sets — rotated by cards_played to avoid repetition
const FALLBACK_LABEL_SETS: Array = [
	["Agir avec prudence", "Mediter en silence", "Foncer tete baissee"],
	["Explorer les alentours", "Invoquer les esprits", "Defier le danger"],
	["Offrir un present", "Ecouter attentivement", "Poursuivre sans hesiter"],
	["Contourner l'obstacle", "Consulter les oghams", "Affronter directement"],
	["Chercher un abri", "Observer les signes", "Avancer coute que coute"],
	["Poser une question", "Rester immobile", "Saisir l'opportunite"],
	["Faire demi-tour", "Attendre un signe", "Plonger dans l'inconnu"],
	["Partager tes vivres", "Dechiffrer les runes", "Briser le silence"],
]

# GBNF Grammar for constrained JSON generation (Phase 30)
const TRIADE_GRAMMAR_PATH := "res://data/ai/triade_card.gbnf"
var _triade_grammar: String = ""

# Scenario prompts — per-category templates (Phase 44)
const SCENARIO_PROMPTS_PATH := "res://data/ai/config/scenario_prompts.json"
var _scenario_prompts: Dictionary = {}
var _scenario_prompts_loaded := false

# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY REIGNS WHITELIST (kept for backward compatibility)
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

const MAX_GAUGE_DELTA := 40
const MIN_GAUGE_DELTA := -40

# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN AI REFERENCE
# ═══════════════════════════════════════════════════════════════════════════════

var _merlin_ai: Node = null

## Connect to MerlinAI autoload for LLM inference.
func set_merlin_ai(ai_node: Node) -> void:
	_merlin_ai = ai_node
	if _merlin_ai:
		print("[MerlinLlmAdapter] MerlinAI wired (ready=%s)" % str(_merlin_ai.is_ready))
	_load_triade_grammar()
	_load_scenario_prompts()

## Load GBNF grammar for constrained JSON decoding (Phase 30).
func _load_triade_grammar() -> void:
	if FileAccess.file_exists(TRIADE_GRAMMAR_PATH):
		var file := FileAccess.open(TRIADE_GRAMMAR_PATH, FileAccess.READ)
		_triade_grammar = file.get_as_text()
		file.close()
		print("[MerlinLlmAdapter] GBNF grammar loaded (%d chars)" % _triade_grammar.length())
	else:
		_triade_grammar = ""
		print("[MerlinLlmAdapter] No GBNF grammar found, using post-processing fallback")

## Load scenario prompt templates for per-category LLM generation (Phase 44).
func _load_scenario_prompts() -> void:
	if not FileAccess.file_exists(SCENARIO_PROMPTS_PATH):
		_scenario_prompts_loaded = false
		print("[MerlinLlmAdapter] No scenario prompts found at %s" % SCENARIO_PROMPTS_PATH)
		return

	var file := FileAccess.open(SCENARIO_PROMPTS_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if data is Dictionary:
		_scenario_prompts = data
		_scenario_prompts_loaded = true
		var count := _scenario_prompts.size() - (1 if _scenario_prompts.has("_meta") else 0)
		print("[MerlinLlmAdapter] Loaded %d scenario prompt templates" % count)


## Get a scenario prompt template by event category key.
## Returns { system, user_template, role, max_tokens, temperature } or empty.
func get_scenario_template(event_key: String) -> Dictionary:
	if not _scenario_prompts_loaded:
		return {}
	return _scenario_prompts.get(event_key, {})


## Build a category-specific system prompt from scenario_prompts.json.
## Falls back to generic prompt if template not found.
func build_category_system_prompt(event_category: String) -> String:
	var template_key := "event_" + event_category
	var template := get_scenario_template(template_key)
	if template.is_empty():
		return _build_triade_system_prompt()
	return str(template.get("system", _build_triade_system_prompt()))


## Build a category-specific user prompt, replacing variables from context.
func build_category_user_prompt(event_category: String, context: Dictionary) -> String:
	var template_key := "event_" + event_category
	var template := get_scenario_template(template_key)
	if template.is_empty():
		return _build_triade_user_prompt(context)

	var user_tpl: String = str(template.get("user_template", ""))
	if user_tpl.is_empty():
		return _build_triade_user_prompt(context)

	# Replace variables in template
	var aspects: Dictionary = context.get("aspects", {})
	user_tpl = user_tpl.replace("{biome}", str(context.get("biome", "foret_broceliande")))
	user_tpl = user_tpl.replace("{day}", str(context.get("day", 1)))
	user_tpl = user_tpl.replace("{season}", str(context.get("season", "spring")))
	user_tpl = user_tpl.replace("{souffle}", str(context.get("souffle", 3)))
	user_tpl = user_tpl.replace("{karma}", str(context.get("karma", 0)))
	user_tpl = user_tpl.replace("{tension}", str(context.get("tension", 40)))
	user_tpl = user_tpl.replace("{life}", str(context.get("life_essence", 100)))
	user_tpl = user_tpl.replace("{bestiole_bond}", str(context.get("bestiole_bond", 50)))

	# Aspect states
	for aspect in ["Corps", "Ame", "Monde"]:
		var val: int = int(aspects.get(aspect, 0))
		var state_name := "equilibre"
		if val < 0: state_name = "bas"
		elif val > 0: state_name = "haut"
		user_tpl = user_tpl.replace("{%s_state}" % aspect.to_lower(), state_name)

	# Sub-type and arc context (optional)
	user_tpl = user_tpl.replace("{sub_type}", str(context.get("sub_type", "")))
	user_tpl = user_tpl.replace("{arc_context}", str(context.get("arc_context", "")))
	user_tpl = user_tpl.replace("{recent_events}", str(context.get("recent_events", "")))
	user_tpl = user_tpl.replace("{active_tags}", str(context.get("active_tags_str", "")))
	user_tpl = user_tpl.replace("{faction_status}", str(context.get("faction_status", "")))

	return user_tpl


## Get LLM params tuned for a specific event category.
func get_category_llm_params(event_category: String) -> Dictionary:
	var template_key := "event_" + event_category
	var template := get_scenario_template(template_key)
	if template.is_empty():
		return TRIADE_LLM_PARAMS.duplicate()

	var params := TRIADE_LLM_PARAMS.duplicate()
	if template.has("temperature"):
		params["temperature"] = float(template["temperature"])
	if template.has("max_tokens"):
		params["max_tokens"] = int(template["max_tokens"])
	return params


## Check if the LLM is available and ready.
func is_llm_ready() -> bool:
	return _merlin_ai != null and _merlin_ai.is_ready


# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE CARD GENERATION — The main entry point
# ═══════════════════════════════════════════════════════════════════════════════

## Generate a TRIADE card via LLM. Async — must be awaited.
## Returns {ok: bool, card: Dictionary, error: String, raw: String}
## Uses two-stage approach directly: free text + programmatic JSON wrap.
## JSON primary generation skipped — Qwen 3B CPU always produces malformed JSON
## and wastes 120s before falling back anyway.
func generate_card(context: Dictionary) -> Dictionary:
	if context.is_empty():
		return {"ok": false, "card": {}, "error": "Empty context"}

	if not is_llm_ready():
		return {"ok": false, "card": {}, "error": "LLM not ready"}

	# Go directly to two-stage (free text → programmatic wrap).
	# Skips JSON generation which always fails with Qwen 3B on CPU.
	print("[MerlinLlmAdapter] generate_card: using two-stage (free text + wrap)")
	var two_stage_result := await _generate_card_two_stage(context)
	if two_stage_result["ok"]:
		return two_stage_result

	return {"ok": false, "card": {}, "error": "Two-stage generation failed"}


# ═══════════════════════════════════════════════════════════════════════════════
# TWO-STAGE GENERATION — Fallback when JSON fails (Phase 30)
# ═══════════════════════════════════════════════════════════════════════════════

## Generate a card in two stages:
## Stage 1: LLM generates a narrative scenario text (free text, no JSON)
## Stage 2: Programmatically wrap into card JSON with context-appropriate effects
func _generate_card_two_stage(context: Dictionary) -> Dictionary:
	if not is_llm_ready():
		return {"ok": false, "card": {}, "error": "LLM not ready"}

	# Stage 1: Free text generation (what nano models do well)
	# Inject a random celtic theme word to force narrative variety
	var cards_played: int = int(context.get("cards_played", 0))
	var theme_idx: int = (cards_played + randi()) % CELTIC_THEMES.size()
	var theme_word: String = CELTIC_THEMES[theme_idx]

	var system_prompt := "Tu es Merlin l'Enchanteur, druide de Broceliande. Ecris une situation UNIQUE riche et evocatrice (5-7 phrases, 420-620 caracteres) pour un jeu de cartes celtique. Theme impose: %s. INTERDIT de repeter une scene precedente. Propose exactement 3 choix (A/B/C) avec des verbes d'action DISTINCTS et une consequence implicite." % theme_word
	var aspects: Dictionary = context.get("aspects", {})
	var souffle: int = int(context.get("souffle", 3))
	var day: int = int(context.get("day", 1))
	var biome: String = str(context.get("biome", "foret_broceliande"))
	var life: int = int(context.get("life_essence", 100))
	var karma: int = int(context.get("karma", 0))
	var user_prompt := "Carte %d du voyage. Jour %d. Souffle: %d. Vie: %d. Karma: %d. Biome: %s." % [cards_played + 1, day, souffle, life, karma, biome]
	for aspect_name in TRIADE_ASPECTS:
		var s: int = int(aspects.get(aspect_name, 0))
		var state_name := "equilibre"
		if s < 0: state_name = "bas"
		elif s > 0: state_name = "haut"
		user_prompt += " %s=%s." % [aspect_name, state_name]

	# Include previous card text for continuity (avoid repetition)
	var story_log: Array = context.get("story_log", [])
	if story_log.size() > 0:
		var last_entry = story_log[-1]
		var prev_text: String = str(last_entry.get("text", "")).substr(0, 100)
		if prev_text.length() > 10:
			user_prompt += " Scene precedente (NE PAS REPETER): '%s'." % prev_text

	user_prompt += " Theme: %s. Genere une scene DIFFERENTE des precedentes, avec 3 choix (A/B/C) relies a la situation." % theme_word

	# No grammar for free text generation
	var free_params := TRIADE_LLM_PARAMS.duplicate()
	free_params.erase("grammar")
	free_params["max_tokens"] = 250
	free_params["temperature"] = 0.7

	var result: Dictionary = await _merlin_ai.generate_with_system(
		system_prompt, user_prompt, free_params
	)
	if result.has("error"):
		return {"ok": false, "card": {}, "error": "Two-stage: " + str(result.error)}

	var raw_text: String = str(result.get("text", ""))
	if raw_text.length() < 10:
		return {"ok": false, "card": {}, "error": "Two-stage: text too short"}

	# Stage 2: Programmatic JSON wrapping
	var card := _wrap_text_as_card(raw_text, context)
	var validated := validate_triade_card(card)
	if not validated["ok"]:
		return {"ok": false, "card": {}, "error": "Two-stage validation: " + ", ".join(validated["errors"])}

	validated["card"]["tags"].append("two_stage")
	validated["card"]["_generated_by"] = "merlin_llm_adapter_two_stage"
	return {"ok": true, "card": validated["card"]}


## Wrap free text into a valid TRIADE card JSON.
## Extracts labels from text if possible, otherwise generates contextual defaults.
func _wrap_text_as_card(raw_text: String, context: Dictionary) -> Dictionary:
	var text := raw_text.strip_edges()

	# Try to extract option labels from text patterns like "A) ...", "1. ...", "- ..."
	var labels: Array[String] = _extract_labels_from_text(text)

	# Remove extracted choices from the main text
	if labels.size() >= 2:
		# Find where the choices start and use only the narrative part
		var rx := RegEx.new()
		rx.compile("(?m)^\\s*(?:[A-C]\\)|[1-3][.)]|[-*])\\s+")
		var first_choice := rx.search(text)
		if first_choice:
			text = text.substr(0, first_choice.get_start()).strip_edges()

	# Fallback labels if extraction failed — rotate by cards_played for variety
	if labels.size() < 3:
		var cp: int = int(context.get("cards_played", 0))
		var set_idx: int = cp % FALLBACK_LABEL_SETS.size()
		var chosen_set: Array = FALLBACK_LABEL_SETS[set_idx]
		labels = [str(chosen_set[0]), str(chosen_set[1]), str(chosen_set[2])]

	# Generate context-appropriate effects
	var aspects: Dictionary = context.get("aspects", {})
	var effects := _generate_contextual_effects(aspects)

	var options_out: Array = [
		{"label": labels[0], "reward_type": MerlinConstants.infer_reward_type([effects[0]]), "effects": [effects[0]]},
		{"label": labels[1], "reward_type": MerlinConstants.infer_reward_type([effects[1]]), "cost": 1, "effects": [effects[1]]},
		{"label": labels[2], "reward_type": MerlinConstants.infer_reward_type([effects[2]]), "effects": [effects[2]]},
	]
	return {
		"text": text if text.length() > 5 else raw_text.substr(0, mini(raw_text.length(), 200)),
		"speaker": "merlin",
		"options": options_out,
		"tags": ["llm_generated"],
	}


## Extract choice labels from LLM free text output.
func _extract_labels_from_text(text: String) -> Array[String]:
	var labels: Array[String] = []
	var rx := RegEx.new()

	# Pattern: "A) label" or "A. label" or "1) label" or "1. label" or "- label"
	rx.compile("(?m)^\\s*(?:[A-C]\\)|[1-3][.)]|[-*])\\s+(.+)")
	var matches := rx.search_all(text)
	for m in matches:
		var label := m.get_string(1).strip_edges()
		if label.length() > 2 and label.length() < 80:
			labels.append(label)

	return labels


## Generate effects that make sense given current aspect states.
func _generate_contextual_effects(_aspects: Dictionary) -> Array:
	## Generate Vie/Karma/Souffle effects for 3 options.
	var effects: Array = []
	# Option 1 (left): Heal life (prudent)
	effects.append({"type": "HEAL_LIFE", "amount": 5})
	# Option 2 (center): Add karma (balanced)
	effects.append({"type": "ADD_KARMA", "amount": 1})
	# Option 3 (right): Risk damage (audacious)
	effects.append({"type": "DAMAGE_LIFE", "amount": 3})
	return effects


# ═══════════════════════════════════════════════════════════════════════════════
# GAME MASTER ADVANCED CAPABILITIES (Phase 32)
# ═══════════════════════════════════════════════════════════════════════════════

const GM_GRAMMAR_PATH := "res://data/ai/gamemaster_effects.gbnf"
var _gm_grammar: String = ""

func _load_gm_grammar() -> void:
	if FileAccess.file_exists(GM_GRAMMAR_PATH):
		var file := FileAccess.open(GM_GRAMMAR_PATH, FileAccess.READ)
		_gm_grammar = file.get_as_text()
		file.close()

## Evaluate game balance using Game Master instance.
## Returns {"balance_score": 0-100, "risk_aspect": String, "suggestion": String}
func evaluate_balance(context: Dictionary) -> Dictionary:
	if not is_llm_ready():
		return _evaluate_balance_heuristic(context)

	if _merlin_ai == null or not _merlin_ai.has_method("generate_structured"):
		return _evaluate_balance_heuristic(context)

	var aspects: Dictionary = context.get("aspects", {})
	var system := "Tu es le Maitre du Jeu. Evalue l'equilibre. Reponds en JSON: {\"balance_score\": 0-100, \"risk_aspect\": \"Corps/Ame/Monde/none\", \"suggestion\": \"...\"}"
	var user_input := "Corps=%d Ame=%d Monde=%d Souffle=%d Jour=%d Cartes=%d" % [
		int(aspects.get("Corps", 0)), int(aspects.get("Ame", 0)), int(aspects.get("Monde", 0)),
		int(context.get("souffle", 3)), int(context.get("day", 1)), int(context.get("cards_played", 0))
	]

	var result: Dictionary = await _merlin_ai.generate_structured(system, user_input)
	if result.has("error") or not result.has("text"):
		return _evaluate_balance_heuristic(context)

	var text: String = str(result.text)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("balance_score"):
		return parsed

	return _evaluate_balance_heuristic(context)


## Heuristic balance evaluation (no LLM needed).
func _evaluate_balance_heuristic(context: Dictionary) -> Dictionary:
	var aspects: Dictionary = context.get("aspects", {})
	var extremes := 0
	var risk_aspect := "none"
	var lowest_val := 0
	for aspect in TRIADE_ASPECTS:
		var v: int = int(aspects.get(aspect, 0))
		if v != 0:
			extremes += 1
		if abs(v) > abs(lowest_val):
			lowest_val = v
			risk_aspect = aspect

	var souffle: int = int(context.get("souffle", 3))
	var score: int = 100 - (extremes * 25) - (max(0, 3 - souffle) * 10)
	score = clampi(score, 0, 100)

	var suggestion := "Equilibre stable"
	if extremes >= 2:
		suggestion = "Danger: %d aspects extremes, proposer des cartes equilibrantes" % extremes
	elif souffle <= 1:
		suggestion = "Souffle critique, proposer des cartes ADD_SOUFFLE"

	return {"balance_score": score, "risk_aspect": risk_aspect, "suggestion": suggestion}


## Suggest a dynamic rule change based on game state.
## Returns {"type": String, "adjustment": int, "reason": String}
func suggest_rule_change(context: Dictionary, player_tendency: String = "neutral") -> Dictionary:
	if not is_llm_ready() or _merlin_ai == null or not _merlin_ai.has_method("generate_structured"):
		return _suggest_rule_heuristic(context, player_tendency)

	var aspects: Dictionary = context.get("aspects", {})
	var balance: Dictionary = await evaluate_balance(context)
	var system := "Tu es le Maitre du Jeu. Propose un ajustement. Reponds en JSON: {\"type\": \"tension/difficulty/karma\", \"adjustment\": number, \"reason\": \"...\"}"
	var balance_text := "equilibre" if balance.balance_score > 60 else ("desequilibre" if balance.balance_score > 30 else "critique")
	var user_input := "Corps=%d Ame=%d Monde=%d. Joueur %s. Equilibre: %s." % [
		int(aspects.get("Corps", 0)), int(aspects.get("Ame", 0)), int(aspects.get("Monde", 0)),
		player_tendency, balance_text
	]

	var result: Dictionary = await _merlin_ai.generate_structured(system, user_input)
	if result.has("text"):
		var parsed = JSON.parse_string(str(result.text))
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("type"):
			return parsed

	return _suggest_rule_heuristic(context, player_tendency)


## Heuristic rule change suggestion.
func _suggest_rule_heuristic(context: Dictionary, player_tendency: String) -> Dictionary:
	var balance: Dictionary = _evaluate_balance_heuristic(context)
	var score: int = int(balance.balance_score)

	if score < 30:
		return {"type": "difficulty", "adjustment": -10, "reason": "Joueur en danger critique, reduire la pression"}
	elif score > 80 and player_tendency == "prudent":
		return {"type": "tension", "adjustment": 15, "reason": "Equilibre trop stable, augmenter la tension narrative"}
	elif player_tendency == "agressif":
		return {"type": "karma", "adjustment": -5, "reason": "Joueur agressif, consequences karmiques"}

	return {"type": "none", "adjustment": 0, "reason": "Aucun ajustement necessaire"}


## Generate smart effects using Game Master — context-aware, multi-effect.
func calculate_smart_effects(context: Dictionary, scenario_text: String, labels: Array[String]) -> Array:
	if not is_llm_ready() or _merlin_ai == null or not _merlin_ai.has_method("generate_structured"):
		return _generate_contextual_effects(context.get("aspects", {}))

	if _gm_grammar == "":
		_load_gm_grammar()

	var system := "Tu es le Maitre du Jeu. Genere les effets JSON pour 3 options. Effets: DAMAGE_LIFE, HEAL_LIFE, ADD_KARMA, ADD_SOUFFLE."
	var user_input := "Scenario: %s\nChoix: %s\nSouffle=%d" % [
		scenario_text.substr(0, 100),
		", ".join(labels),
		int(context.get("souffle", 3))
	]
	user_input += "\n{\"options\":[{\"label\":\"...\",\"effects\":[{\"type\":\"HEAL_LIFE\",\"amount\":5}]},{\"label\":\"...\",\"effects\":[{\"type\":\"ADD_KARMA\",\"amount\":1}]},{\"label\":\"...\",\"effects\":[{\"type\":\"DAMAGE_LIFE\",\"amount\":3}]}]}"

	var result: Dictionary = await _merlin_ai.generate_structured(system, user_input, _gm_grammar)
	if result.has("text"):
		var text: String = str(result.text)
		var json_start := text.find("{")
		var json_end := text.rfind("}")
		if json_start >= 0 and json_end > json_start:
			var parsed = JSON.parse_string(text.substr(json_start, json_end - json_start + 1))
			if typeof(parsed) == TYPE_DICTIONARY and parsed.has("options"):
				var effects: Array = []
				for opt in parsed.options:
					if opt is Dictionary and opt.has("effects"):
						effects.append_array(opt.effects)
					else:
						effects.append({"type": "HEAL_LIFE", "amount": 5})
				return effects

	# Fallback to heuristic
	return _generate_contextual_effects({})


# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE SYSTEM PROMPT — Compact for Qwen 2.5-3B-Instruct
# ═══════════════════════════════════════════════════════════════════════════════

func _build_triade_system_prompt() -> String:
	return "Tu es Merlin l'Enchanteur, druide ancestral des forets de Broceliande. Genere 1 carte JSON pour un jeu de cartes celtique. La carte contient une situation narrative dense et developpee (5-7 phrases, 420-620 caracteres) et 3 options basees sur des verbes d'action avec consequences sur Vie/Karma/Souffle. Chaque option a un reward_type parmi: vie, essence, souffle, karma, mystere. Effets possibles: HEAL_LIFE, DAMAGE_LIFE, ADD_KARMA, ADD_SOUFFLE. Ajoute result_success (2-3 phrases si reussite) et result_failure (2-3 phrases si echec). Vocabulaire: nemeton, ogham, sidhe, dolmen, korrigans, brume, mousse, serment. Ton: poetique, concret et mysterieux. Reponds UNIQUEMENT en JSON valide."


func _build_triade_user_prompt(context: Dictionary) -> String:
	var souffle: int = int(context.get("souffle", 3))
	var cards_played: int = int(context.get("cards_played", 0))
	var day: int = int(context.get("day", 1))
	var tags: Array = context.get("active_tags", [])

	var prompt := "Souffle:%d. Jour:%d. Carte:%d." % [souffle, day, cards_played]

	var biome: String = str(context.get("biome", "foret_broceliande"))
	prompt += " Biome:%s." % biome

	var life: int = int(context.get("life_essence", 5))
	prompt += " Vie:%d." % life

	if tags.size() > 0:
		var tag_slice: Array = tags.slice(0, mini(tags.size(), 3))
		var tag_strs: Array[String] = []
		for t in tag_slice:
			tag_strs.append(str(t))
		prompt += " Tags:" + ",".join(tag_strs)

	var story_log: Array = context.get("story_log", [])
	if story_log.size() > 0:
		var last_entry = story_log[-1]
		var prev_text: String = str(last_entry.get("text", "")).substr(0, 80)
		if prev_text.length() > 0:
			prompt += " Precedent: %s." % prev_text

	# JSON template at end of user prompt (anti-hallucination: model sees template last)
	prompt += "\nEffets: HEAL_LIFE amount=N, DAMAGE_LIFE amount=N, ADD_KARMA amount=N, ADD_SOUFFLE amount=N."
	prompt += "\nLe champ text doit etre detaille (5-7 phrases, 420-620 caracteres), les labels doivent commencer par un verbe d'action."
	prompt += "\n{\"text\":\"...\",\"speaker\":\"merlin\",\"options\":[{\"label\":\"...\",\"reward_type\":\"vie\",\"effects\":[{\"type\":\"HEAL_LIFE\",\"amount\":5}]},{\"label\":\"...\",\"reward_type\":\"karma\",\"effects\":[{\"type\":\"ADD_KARMA\",\"amount\":1}]},{\"label\":\"...\",\"reward_type\":\"vie\",\"effects\":[{\"type\":\"DAMAGE_LIFE\",\"amount\":3}]}],\"result_success\":\"...\",\"result_failure\":\"...\",\"tags\":[\"tag\"]}"

	return prompt


# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE CONTEXT BUILDING — From game state to LLM context
# ═══════════════════════════════════════════════════════════════════════════════

## Build TRIADE context from full game state.
func build_triade_context(state: Dictionary) -> Dictionary:
	var run: Dictionary = state.get("run", {})
	var bestiole: Dictionary = state.get("bestiole", {})

	var hidden: Dictionary = run.get("hidden", {})
	return {
		"aspects": run.get("aspects", {}).duplicate(),
		"souffle": int(run.get("souffle", MerlinConstants.SOUFFLE_START)),
		"cards_played": int(run.get("cards_played", 0)),
		"day": int(run.get("day", 1)),
		"active_tags": run.get("active_tags", []),
		"active_promises": run.get("active_promises", []),
		"story_log": _get_recent_story_log(run.get("story_log", []), 5),
		"biome": str(run.get("current_biome", "foret_broceliande")),
		"life_essence": int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START)),
		"karma": int(hidden.get("karma", 0)),
		"bestiole": {
			"mood": _get_bestiole_mood(bestiole),
			"bond": int(bestiole.get("bond", 50)),
		},
		"flags": state.get("flags", {}),
	}


func _get_bestiole_mood(bestiole: Dictionary) -> String:
	var needs: Dictionary = bestiole.get("needs", {})
	var avg_needs := (int(needs.get("Hunger", 50)) + int(needs.get("Energy", 50))
		+ int(needs.get("Mood", 50)) - int(needs.get("Stress", 0))) / 4.0
	if avg_needs >= 70:
		return "happy"
	elif avg_needs >= 40:
		return "content"
	elif avg_needs >= 20:
		return "tired"
	return "distressed"


# ═══════════════════════════════════════════════════════════════════════════════
# JSON EXTRACTION — Robust parsing of LLM output
# ═══════════════════════════════════════════════════════════════════════════════

func _extract_json_from_response(raw: String) -> Dictionary:
	# Strategy 1: Find outermost { }
	var json_start := raw.find("{")
	var json_end := raw.rfind("}")
	if json_start == -1 or json_end == -1 or json_end <= json_start:
		# Strategy 4: Regex field extraction (no braces found)
		return _regex_extract_card_fields(raw)

	var json_text := raw.substr(json_start, json_end - json_start + 1)
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed

	# Strategy 2: Fix common LLM JSON errors then retry
	json_text = _fix_common_json_errors(json_text)
	parsed = JSON.parse_string(json_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed

	# Strategy 3: Aggressive repair (truncation, nesting, escaping)
	json_text = _aggressive_json_repair(json_text)
	parsed = JSON.parse_string(json_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed

	# Strategy 4: Regex field extraction (last resort)
	return _regex_extract_card_fields(raw)


func _fix_common_json_errors(text: String) -> String:
	# Fix trailing commas before } or ]
	var rx := RegEx.new()
	rx.compile(",\\s*([}\\]])")
	text = rx.sub(text, "$1", true)

	# Fix single quotes to double quotes
	text = text.replace("'", "\"")

	# Fix unquoted keys: word: -> "word":
	rx = RegEx.new()
	rx.compile("([{,])\\s*([a-zA-Z_][a-zA-Z_0-9]*)\\s*:")
	text = rx.sub(text, "$1\"$2\":", true)

	return text


func _aggressive_json_repair(text: String) -> String:
	## Step 3: Handle truncated JSON, bad nesting, escape issues.

	# Fix unescaped quotes inside strings (common nano-model error)
	# Replace \" inside values that have unmatched quotes
	var rx := RegEx.new()

	# Remove control characters that break JSON
	text = text.replace("\t", " ").replace("\r", "")

	# Fix truncated JSON: count brackets and close them
	var open_braces := text.count("{") - text.count("}")
	var open_brackets := text.count("[") - text.count("]")

	# Remove trailing incomplete key-value pairs (e.g., "key": )
	rx.compile(",\\s*\"[^\"]*\"\\s*:\\s*$")
	text = rx.sub(text, "", true)

	# Close any unclosed strings (odd number of unescaped quotes)
	var in_string := false
	var clean := ""
	var i := 0
	while i < text.length():
		var ch := text[i]
		if ch == "\\" and in_string and i + 1 < text.length():
			clean += ch + text[i + 1]
			i += 2
			continue
		if ch == "\"":
			in_string = not in_string
		clean += ch
		i += 1
	if in_string:
		clean += "\""
	text = clean

	# Close unclosed brackets and braces
	for _j in range(open_brackets):
		text += "]"
	for _j in range(open_braces):
		text += "}"

	# Remove trailing commas added by closure
	rx.compile(",\\s*([}\\]])")
	text = rx.sub(text, "$1", true)

	return text


func _regex_extract_card_fields(raw: String) -> Dictionary:
	## Step 4: Extract card fields using regex when JSON parsing fails entirely.
	## Builds a card from detected text and option labels.
	var rx := RegEx.new()

	# Try to find "text" field value
	rx.compile("\"text\"\\s*:\\s*\"([^\"]+)\"")
	var text_match := rx.search(raw)
	if text_match == null:
		return {}

	var card_text: String = text_match.get_string(1)

	# Try to find option labels
	var labels: Array[String] = []
	rx.compile("\"label\"\\s*:\\s*\"([^\"]+)\"")
	var label_matches := rx.search_all(raw)
	for m in label_matches:
		labels.append(m.get_string(1))

	if labels.size() < 2:
		return {}

	# Try to find speaker
	rx.compile("\"speaker\"\\s*:\\s*\"([^\"]+)\"")
	var speaker_match := rx.search(raw)
	var speaker: String = speaker_match.get_string(1) if speaker_match else "merlin"

	var options: Array = []

	for idx in range(labels.size()):
		var opt: Dictionary = {"label": labels[idx], "effects": []}
		if idx == 1:
			opt["cost"] = 1
		# Try to pair with an effect
		# Default Vie/Karma/Souffle effects based on position
		var default_effects: Array = [
			{"type": "HEAL_LIFE", "amount": 5},
			{"type": "ADD_KARMA", "amount": 1},
			{"type": "DAMAGE_LIFE", "amount": 3},
		]
		opt["effects"].append(default_effects[idx % 3])
		options.append(opt)

	return {
		"text": card_text,
		"speaker": speaker,
		"options": options.slice(0, 3),
		"tags": ["llm_regex_repair"],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE CARD VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

## Validate and sanitize a TRIADE card from LLM response.
func validate_triade_card(card: Dictionary) -> Dictionary:
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
		sanitized["options"][i] = _validate_triade_option(sanitized["options"][i])

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


func _validate_triade_option(option) -> Dictionary:
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
		var validated := _validate_triade_effect(effect)
		if not validated.is_empty():
			valid_effects.append(validated)

	sanitized["effects"] = valid_effects
	return sanitized


func _validate_triade_effect(effect: Dictionary) -> Dictionary:
	var effect_type := str(effect.get("type", ""))
	if not effect_type in TRIADE_EFFECT_TYPES:
		return {}

	match effect_type:
		"SHIFT_ASPECT", "SET_ASPECT":
			# Aspect system removed — convert to HEAL_LIFE
			return {"type": "HEAL_LIFE", "amount": 5}

		"DAMAGE_LIFE", "HEAL_LIFE":
			var amount := clampi(int(effect.get("amount", 5)), 1, 20)
			return {"type": effect_type, "amount": amount}

		"USE_SOUFFLE", "ADD_SOUFFLE":
			var amount := clampi(int(effect.get("amount", 1)), 1, 3)
			return {"type": effect_type, "amount": amount}

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

		"ADD_TAG":
			var tag := str(effect.get("tag", ""))
			if tag.is_empty():
				return {}
			return {"type": "ADD_TAG", "tag": tag}

	return {}


# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY REIGNS — Context building (kept for backward compatibility)
# ═══════════════════════════════════════════════════════════════════════════════

func build_context(state: Dictionary) -> Dictionary:
	var run = state.get("run", {})
	var bestiole = state.get("bestiole", {})
	var gauges = run.get("gauges", {})

	var critical_gauges := []
	for gauge_name in VALID_GAUGES:
		var value = int(gauges.get(gauge_name, 50))
		# Legacy Reigns gauge thresholds (deprecated — inline defaults)
		if value <= 15:
			critical_gauges.append({"name": gauge_name, "value": value, "direction": "low"})
		elif value >= 85:
			critical_gauges.append({"name": gauge_name, "value": value, "direction": "high"})

	var skills_ready := []
	var cooldowns = bestiole.get("skill_cooldowns", {})
	var equipped = bestiole.get("skills_equipped", [])
	for skill_id in equipped:
		if int(cooldowns.get(skill_id, 0)) <= 0:
			skills_ready.append(skill_id)

	var mood := _get_bestiole_mood(bestiole)

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


func _get_recent_story_log(story_log: Array, count: int) -> Array:
	if story_log.size() <= count:
		return story_log.duplicate()
	return story_log.slice(story_log.size() - count, story_log.size())


# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY REIGNS — Card validation
# ═══════════════════════════════════════════════════════════════════════════════

func validate_card(card: Dictionary, effect_engine: MerlinEffectEngine = null) -> Dictionary:
	var result := {"ok": false, "errors": [], "card": {}}

	for key in REQUIRED_CARD_KEYS:
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

	# Validate card type (inline list, Reigns constants removed)
	var valid_card_types := ["narrative", "event", "promise", "merlin_direct"]
	if card.has("type"):
		if not card["type"] in valid_card_types:
			sanitized_card["type"] = "narrative"
	else:
		sanitized_card["type"] = "narrative"

	result["ok"] = true
	result["card"] = sanitized_card
	return result


func _validate_option(option: Dictionary, effect_engine: MerlinEffectEngine) -> Dictionary:
	var result := {"ok": false, "errors": [], "option": {}}

	for key in REQUIRED_OPTION_KEYS:
		if not option.has(key):
			result["errors"].append("Option missing key: %s" % key)
			return result

	if not option["direction"] in VALID_DIRECTIONS:
		result["errors"].append("Invalid direction: %s" % option["direction"])
		return result

	if typeof(option["label"]) != TYPE_STRING or option["label"].is_empty():
		result["errors"].append("Option label must be non-empty string")
		return result

	if typeof(option["effects"]) != TYPE_ARRAY:
		result["errors"].append("Effects must be an array")
		return result

	var sanitized_option := option.duplicate(true)
	sanitized_option["effects"] = _filter_effects(option["effects"], effect_engine)

	if sanitized_option["effects"].is_empty():
		sanitized_option["effects"] = [{"type": "ADD_GAUGE", "target": "Vigueur", "value": 0}]

	if option.has("preview_hint") and typeof(option["preview_hint"]) != TYPE_STRING:
		sanitized_option.erase("preview_hint")

	result["ok"] = true
	result["option"] = sanitized_option
	return result


func _filter_effects(effects: Array, effect_engine: MerlinEffectEngine) -> Array:
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


func _validate_effect(effect: Dictionary, _effect_engine: MerlinEffectEngine) -> Variant:
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
# SYSTEM PROMPT — Legacy REIGNS (kept for backward compat)
# ═══════════════════════════════════════════════════════════════════════════════

func get_system_prompt() -> String:
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
}"""


# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY SUPPORT — Old scene validation (DEPRECATED)
# ═══════════════════════════════════════════════════════════════════════════════

const LEGACY_REQUIRED_KEYS := ["scene_id", "biome", "backdrop", "text_pages", "choices"]
const LEGACY_VERBS := ["FORCE", "LOGIQUE", "FINESSE"]

func validate_scene(scene: Dictionary, _effect_engine: MerlinEffectEngine) -> Dictionary:
	push_warning("MerlinLlmAdapter.validate_scene() is deprecated. Use validate_card() instead.")
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
