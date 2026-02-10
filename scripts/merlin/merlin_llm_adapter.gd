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
	"SHIFT_ASPECT",
	"SET_ASPECT",
	"USE_SOUFFLE",
	"ADD_SOUFFLE",
	"PROGRESS_MISSION",
	"ADD_KARMA",
	"ADD_TENSION",
	"ADD_NARRATIVE_DEBT",
	"SET_FLAG",
	"ADD_TAG",
]

const TRIADE_ASPECTS := ["Corps", "Ame", "Monde"]
const TRIADE_DIRECTIONS := ["up", "down"]
const TRIADE_STATES := [-1, 0, 1]

# LLM generation params tuned for Qwen2.5-3B-Instruct Q4_K_M
const TRIADE_LLM_PARAMS := {
	"max_tokens": 200,
	"temperature": 0.6,
	"top_p": 0.85,
	"top_k": 30,
	"repetition_penalty": 1.5,
}

const GENERATION_TIMEOUT_MS := 8000

# GBNF Grammar for constrained JSON generation (Phase 30)
const TRIADE_GRAMMAR_PATH := "res://data/ai/triade_card.gbnf"
var _triade_grammar: String = ""

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

## Check if the LLM is available and ready.
func is_llm_ready() -> bool:
	return _merlin_ai != null and _merlin_ai.is_ready


# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE CARD GENERATION — The main entry point
# ═══════════════════════════════════════════════════════════════════════════════

## Generate a TRIADE card via LLM. Async — must be awaited.
## Returns {ok: bool, card: Dictionary, error: String, raw: String}
func generate_card(context: Dictionary) -> Dictionary:
	if context.is_empty():
		return {"ok": false, "card": {}, "error": "Empty context"}

	if not is_llm_ready():
		return {"ok": false, "card": {}, "error": "LLM not ready"}

	var system_prompt := _build_triade_system_prompt()
	var user_prompt := _build_triade_user_prompt(context)

	# Pass GBNF grammar if available (Phase 30 — constrained decoding)
	var params := TRIADE_LLM_PARAMS.duplicate()
	if _triade_grammar != "":
		params["grammar"] = _triade_grammar

	var start_time := Time.get_ticks_msec()
	var result: Dictionary = await _merlin_ai.generate_with_system(
		system_prompt, user_prompt, params
	)
	var elapsed := Time.get_ticks_msec() - start_time

	if elapsed > GENERATION_TIMEOUT_MS:
		return {"ok": false, "card": {}, "error": "Timeout: %dms" % elapsed}

	if result.has("error"):
		return {"ok": false, "card": {}, "error": str(result.error)}

	var raw_text: String = str(result.get("text", ""))
	if raw_text.is_empty():
		return {"ok": false, "card": {}, "error": "Empty LLM response"}

	var parsed := _extract_json_from_response(raw_text)
	if not parsed.is_empty():
		var validated := validate_triade_card(parsed)
		if validated["ok"]:
			return {"ok": true, "card": validated["card"]}

	# Primary generation failed — try two-stage fallback (Phase 30)
	print("[MerlinLlmAdapter] Primary generation failed, trying two-stage fallback")
	var two_stage_result := await _generate_card_two_stage(context)
	if two_stage_result["ok"]:
		return two_stage_result

	return {"ok": false, "card": {}, "error": "All generation strategies failed", "raw": raw_text}


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
	var system_prompt := "Merlin le druide. Ecris un scenario court (2 phrases) pour un jeu de cartes celtique. Propose 3 choix."
	var aspects: Dictionary = context.get("aspects", {})
	var souffle: int = int(context.get("souffle", 3))
	var day: int = int(context.get("day", 1))
	var user_prompt := "Jour %d. Souffle: %d." % [day, souffle]
	for aspect_name in TRIADE_ASPECTS:
		var s: int = int(aspects.get(aspect_name, 0))
		var state_name := "equilibre"
		if s < 0: state_name = "bas"
		elif s > 0: state_name = "haut"
		user_prompt += " %s=%s." % [aspect_name, state_name]
	user_prompt += " Format: scenario puis 3 choix (A/B/C)."

	# No grammar for free text generation
	var free_params := TRIADE_LLM_PARAMS.duplicate()
	free_params.erase("grammar")
	free_params["max_tokens"] = 150
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

	# Fallback labels if extraction failed
	if labels.size() < 3:
		labels = ["Agir avec prudence", "Mediter en silence", "Foncer tete baissee"]

	# Generate context-appropriate effects
	var aspects: Dictionary = context.get("aspects", {})
	var effects := _generate_contextual_effects(aspects)

	return {
		"text": text if text.length() > 5 else raw_text.substr(0, mini(raw_text.length(), 200)),
		"speaker": "merlin",
		"options": [
			{"label": labels[0], "effects": [effects[0]]},
			{"label": labels[1], "cost": 1, "effects": [effects[1]]},
			{"label": labels[2], "effects": [effects[2]]},
		],
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
func _generate_contextual_effects(aspects: Dictionary) -> Array:
	var aspect_names := ["Corps", "Ame", "Monde"]
	var effects: Array = []

	# Find the lowest and highest aspects for smart targeting
	var lowest_aspect := "Corps"
	var highest_aspect := "Monde"
	var lowest_val := 999
	var highest_val := -999
	for a in aspect_names:
		var v: int = int(aspects.get(a, 0))
		if v < lowest_val:
			lowest_val = v
			lowest_aspect = a
		if v > highest_val:
			highest_val = v
			highest_aspect = a

	# Option 1 (left): Boost lowest aspect
	effects.append({"type": "SHIFT_ASPECT", "aspect": lowest_aspect, "direction": "up"})
	# Option 2 (center): Balance — different aspect
	var center_aspect: String = aspect_names[1]
	if center_aspect == lowest_aspect or center_aspect == highest_aspect:
		center_aspect = aspect_names[0] if aspect_names[0] != lowest_aspect else aspect_names[2]
	effects.append({"type": "SHIFT_ASPECT", "aspect": center_aspect, "direction": "up"})
	# Option 3 (right): Risk — lower highest but different feel
	effects.append({"type": "SHIFT_ASPECT", "aspect": highest_aspect, "direction": "down"})

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

	var aspects: Dictionary = context.get("aspects", {})
	var system := "Tu es le Maitre du Jeu. Genere les effets JSON pour 3 options. Effets: SHIFT_ASPECT, ADD_KARMA, ADD_TENSION."
	var user_input := "Scenario: %s\nChoix: %s\nCorps=%d Ame=%d Monde=%d Souffle=%d" % [
		scenario_text.substr(0, 100),
		", ".join(labels),
		int(aspects.get("Corps", 0)), int(aspects.get("Ame", 0)), int(aspects.get("Monde", 0)),
		int(context.get("souffle", 3))
	]
	user_input += "\n{\"options\":[{\"label\":\"...\",\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Corps\",\"direction\":\"up\"}]},{\"label\":\"...\",\"cost\":1,\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Ame\",\"direction\":\"up\"}]},{\"label\":\"...\",\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Monde\",\"direction\":\"down\"}]}]}"

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
						effects.append({"type": "SHIFT_ASPECT", "aspect": "Corps", "direction": "up"})
				return effects

	# Fallback to heuristic
	return _generate_contextual_effects(aspects)


# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE SYSTEM PROMPT — Compact for Qwen2.5-3B-Instruct
# ═══════════════════════════════════════════════════════════════════════════════

func _build_triade_system_prompt() -> String:
	return "Merlin druide narrateur. Genere 1 carte JSON francais. 3 options avec tradeoffs. Reponds UNIQUEMENT en JSON valide."


func _build_triade_user_prompt(context: Dictionary) -> String:
	var aspects: Dictionary = context.get("aspects", {})
	var souffle: int = int(context.get("souffle", 3))
	var cards_played: int = int(context.get("cards_played", 0))
	var day: int = int(context.get("day", 1))
	var tags: Array = context.get("active_tags", [])

	var prompt := "Aspects:"
	for aspect in TRIADE_ASPECTS:
		var s: int = int(aspects.get(aspect, 0))
		var state_name := "equilibre"
		if s < 0:
			state_name = "bas"
		elif s > 0:
			state_name = "haut"
		prompt += " %s=%s" % [aspect, state_name]

	prompt += ". Souffle:%d. Jour:%d. Carte:%d." % [souffle, day, cards_played]

	if tags.size() > 0:
		var tag_slice: Array = tags.slice(0, mini(tags.size(), 3))
		var tag_strs: Array[String] = []
		for t in tag_slice:
			tag_strs.append(str(t))
		prompt += " Tags:" + ",".join(tag_strs)

	# JSON template at end of user prompt (anti-hallucination: model sees template last)
	prompt += "\nEffets: SHIFT_ASPECT aspect=Corps/Ame/Monde direction=up/down. Centre cost:1."
	prompt += "\n{\"text\":\"...\",\"speaker\":\"merlin\",\"options\":[{\"label\":\"...\",\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Corps\",\"direction\":\"up\"}]},{\"label\":\"...\",\"cost\":1,\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Ame\",\"direction\":\"up\"}]},{\"label\":\"...\",\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Monde\",\"direction\":\"down\"}]}],\"tags\":[\"tag\"]}"

	return prompt


# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE CONTEXT BUILDING — From game state to LLM context
# ═══════════════════════════════════════════════════════════════════════════════

## Build TRIADE context from full game state.
func build_triade_context(state: Dictionary) -> Dictionary:
	var run: Dictionary = state.get("run", {})
	var bestiole: Dictionary = state.get("bestiole", {})

	return {
		"aspects": run.get("aspects", {}).duplicate(),
		"souffle": int(run.get("souffle", MerlinConstants.SOUFFLE_START)),
		"cards_played": int(run.get("cards_played", 0)),
		"day": int(run.get("day", 1)),
		"active_tags": run.get("active_tags", []),
		"active_promises": run.get("active_promises", []),
		"story_log": _get_recent_story_log(run.get("story_log", []), 5),
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

	# Try to find aspect/direction pairs in effects
	var options: Array = []
	rx.compile("\"aspect\"\\s*:\\s*\"(Corps|Ame|Monde)\"")
	var aspect_matches := rx.search_all(raw)
	rx.compile("\"direction\"\\s*:\\s*\"(up|down)\"")
	var dir_matches := rx.search_all(raw)

	for idx in range(labels.size()):
		var opt: Dictionary = {"label": labels[idx], "effects": []}
		if idx == 1:
			opt["cost"] = 1
		# Try to pair with an effect
		if idx < aspect_matches.size() and idx < dir_matches.size():
			opt["effects"].append({
				"type": "SHIFT_ASPECT",
				"aspect": aspect_matches[idx].get_string(1),
				"direction": dir_matches[idx].get_string(1),
			})
		else:
			# Default effect based on position
			var aspects_list: Array[String] = ["Corps", "Ame", "Monde"]
			var aspect_idx: int = idx % 3
			opt["effects"].append({
				"type": "SHIFT_ASPECT",
				"aspect": aspects_list[aspect_idx],
				"direction": "up" if idx == 0 else "down",
			})
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
			"effects": [{"type": "SHIFT_ASPECT", "aspect": "Ame", "direction": "up"}],
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
		"SHIFT_ASPECT":
			var aspect := str(effect.get("aspect", ""))
			var direction := str(effect.get("direction", ""))
			if not aspect in TRIADE_ASPECTS or not direction in TRIADE_DIRECTIONS:
				return {}
			return {"type": "SHIFT_ASPECT", "aspect": aspect, "direction": direction}

		"SET_ASPECT":
			var aspect := str(effect.get("aspect", ""))
			var state_val := int(effect.get("state", 0))
			if not aspect in TRIADE_ASPECTS or not state_val in TRIADE_STATES:
				return {}
			return {"type": "SET_ASPECT", "aspect": aspect, "state": state_val}

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
		if value <= MerlinConstants.REIGNS_GAUGE_CRITICAL_LOW:
			critical_gauges.append({"name": gauge_name, "value": value, "direction": "low"})
		elif value >= MerlinConstants.REIGNS_GAUGE_CRITICAL_HIGH:
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

	if card.has("type"):
		if not card["type"] in MerlinConstants.REIGNS_CARD_TYPES:
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
