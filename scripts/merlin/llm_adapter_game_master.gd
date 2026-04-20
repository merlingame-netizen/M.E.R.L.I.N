## ═══════════════════════════════════════════════════════════════════════════════
## LLM Adapter — Game Master & Balance Evaluation
## ═══════════════════════════════════════════════════════════════════════════════
## Balance heuristics, smart effect generation, rule change suggestions,
## contextual effect generation, visual tag extraction.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name LlmAdapterGameMaster

const FACTIONS := ["druides", "anciens", "korrigans", "niamh", "ankou"]

const GM_GRAMMAR_PATH := "res://data/ai/gamemaster_effects.gbnf"
var _gm_grammar: String = ""


func load_gm_grammar() -> void:
	if FileAccess.file_exists(GM_GRAMMAR_PATH):
		var file := FileAccess.open(GM_GRAMMAR_PATH, FileAccess.READ)
		_gm_grammar = file.get_as_text()
		file.close()


## Heuristic balance evaluation based on faction reputation (no LLM needed).
func evaluate_balance_heuristic(context: Dictionary) -> Dictionary:
	var factions: Dictionary = context.get("factions", {})
	var extremes := 0
	var risk_faction := "none"
	var most_extreme_val: float = 50.0
	for faction in FACTIONS:
		var rep: float = float(factions.get(faction, 50.0))
		if rep < 20.0 or rep > 80.0:
			extremes += 1
		var dist: float = absf(rep - 50.0)
		if dist > absf(most_extreme_val - 50.0):
			most_extreme_val = rep
			risk_faction = faction

	var score: int = 100 - (extremes * 20)
	score = clampi(score, 0, 100)

	var suggestion := "Equilibre stable"
	if extremes >= 3:
		suggestion = "Danger: %d factions extremes, proposer des cartes equilibrantes" % extremes
	elif extremes >= 2:
		suggestion = "Attention: %d factions en zone extreme" % extremes

	return {"balance_score": score, "risk_faction": risk_faction, "suggestion": suggestion}


## Evaluate game balance using Game Master LLM instance.
## Returns {"balance_score": 0-100, "risk_faction": String, "suggestion": String}
func evaluate_balance(context: Dictionary, merlin_ai: Node) -> Dictionary:
	if merlin_ai == null or not merlin_ai.is_ready:
		return evaluate_balance_heuristic(context)

	if not merlin_ai.has_method("generate_structured"):
		return evaluate_balance_heuristic(context)

	var factions: Dictionary = context.get("factions", {})
	var system := "Tu es le Maitre du Jeu. Evalue l'equilibre des factions. Reponds en JSON: {\"balance_score\": 0-100, \"risk_faction\": \"druides/anciens/korrigans/niamh/ankou/none\", \"suggestion\": \"...\"}"
	var faction_parts: Array[String] = []
	for f in FACTIONS:
		faction_parts.append("%s=%.0f" % [f, float(factions.get(f, 0.0))])
	var user_input := "%s Jour=%d Cartes=%d" % [
		", ".join(faction_parts), int(context.get("day", 1)), int(context.get("cards_played", 0))
	]

	var result: Dictionary = await merlin_ai.generate_structured(system, user_input)
	if result.has("error") or not result.has("text"):
		return evaluate_balance_heuristic(context)

	var text: String = str(result.text)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) == TYPE_DICTIONARY and parsed.has("balance_score"):
		return parsed

	return evaluate_balance_heuristic(context)


## Suggest a dynamic rule change based on game state.
## Returns {"type": String, "adjustment": int, "reason": String}
func suggest_rule_change(context: Dictionary, player_tendency: String, merlin_ai: Node) -> Dictionary:
	if merlin_ai == null or not merlin_ai.is_ready or not merlin_ai.has_method("generate_structured"):
		return _suggest_rule_heuristic(context, player_tendency)

	var factions: Dictionary = context.get("factions", {})
	var balance: Dictionary = await evaluate_balance(context, merlin_ai)
	var system := "Tu es le Maitre du Jeu. Propose un ajustement. Reponds en JSON: {\"type\": \"tension/difficulty/karma\", \"adjustment\": number, \"reason\": \"...\"}"
	var balance_text := "equilibre" if balance.balance_score > 60 else ("desequilibre" if balance.balance_score > 30 else "critique")
	var faction_parts: Array[String] = []
	for f in FACTIONS:
		faction_parts.append("%s=%.0f" % [f, float(factions.get(f, 0.0))])
	var user_input := "%s. Joueur %s. Equilibre: %s." % [
		", ".join(faction_parts), player_tendency, balance_text
	]

	var result: Dictionary = await merlin_ai.generate_structured(system, user_input)
	if result.has("text"):
		var parsed = JSON.parse_string(str(result.text))
		if typeof(parsed) == TYPE_DICTIONARY and parsed.has("type"):
			return parsed

	return _suggest_rule_heuristic(context, player_tendency)


## Heuristic rule change suggestion.
func _suggest_rule_heuristic(context: Dictionary, player_tendency: String) -> Dictionary:
	var balance: Dictionary = evaluate_balance_heuristic(context)
	var score: int = int(balance.balance_score)

	if score < 30:
		return {"type": "difficulty", "adjustment": -10, "reason": "Joueur en danger critique, reduire la pression"}
	elif score > 80 and player_tendency == "prudent":
		return {"type": "tension", "adjustment": 15, "reason": "Equilibre trop stable, augmenter la tension narrative"}
	elif player_tendency == "agressif":
		return {"type": "karma", "adjustment": -5, "reason": "Joueur agressif, consequences karmiques"}

	return {"type": "none", "adjustment": 0, "reason": "Aucun ajustement necessaire"}


## Generate smart effects using Game Master — context-aware, balance-informed.
## Returns Array of 3 Arrays: [[effects_left], [effects_center], [effects_right]]
## Returns empty Array on failure (caller should use heuristic effects).
func calculate_smart_effects(context: Dictionary, scenario_text: String, labels: Array[String], merlin_ai: Node) -> Array:
	if merlin_ai == null or not merlin_ai.is_ready or not merlin_ai.has_method("generate_structured"):
		return []

	# Build GM prompt with balance awareness (no GBNF — Ollama-compatible)
	var balance := evaluate_balance_heuristic(context)
	var score: int = int(balance.get("balance_score", 100))
	var risk: String = str(balance.get("risk_faction", "none"))
	var life: int = int(context.get("life_essence", 100))

	# GM system prompt: JSON-schema few-shot block (Ollama-compatible, replaces GBNF grammar).
	# Three examples enforce format + faction/amount constraints without grammar support.
	var system: String = "Reponds UNIQUEMENT en JSON valide. AUCUN texte avant ou apres.\n"
	system += "Schema: {\"effects\":[[option_gauche],[option_centre],[option_droite]]}\n"
	system += "Types: HEAL_LIFE,DAMAGE_LIFE,ADD_KARMA,ADD_REPUTATION,ADD_ANAM,ADD_BIOME_CURRENCY.\n"
	system += "ADD_REPUTATION requis: {\"type\":\"ADD_REPUTATION\",\"faction\":F,\"amount\":N} (F=druides/anciens/korrigans/niamh/ankou, N=-20..20)\n"
	system += "Autres: {\"type\":T,\"amount\":N} (N=1..20). 1-3 effets par option. 3 options obligatoires.\n"
	system += "Ex1 danger: {\"effects\":[[{\"type\":\"HEAL_LIFE\",\"amount\":8}],[{\"type\":\"ADD_REPUTATION\",\"faction\":\"druides\",\"amount\":10}],[{\"type\":\"DAMAGE_LIFE\",\"amount\":5}]]}\n"
	system += "Ex2 stable: {\"effects\":[[{\"type\":\"ADD_REPUTATION\",\"faction\":\"anciens\",\"amount\":12}],[{\"type\":\"HEAL_LIFE\",\"amount\":4}],[{\"type\":\"ADD_REPUTATION\",\"faction\":\"korrigans\",\"amount\":-8}]]}\n"
	system += "Ex3 fin: {\"effects\":[[{\"type\":\"PROGRESS_MISSION\",\"amount\":1},{\"type\":\"ADD_REPUTATION\",\"faction\":\"niamh\",\"amount\":15}],[{\"type\":\"ADD_ANAM\",\"amount\":8}],[{\"type\":\"ADD_REPUTATION\",\"faction\":\"ankou\",\"amount\":18},{\"type\":\"DAMAGE_LIFE\",\"amount\":6}]]}"

	var balance_hint := ""
	if score < 30:
		balance_hint = " URGENCE: Vie=%d. Choix 1 DOIT etre HEAL_LIFE." % life
	elif score < 50 and risk != "none":
		balance_hint = " Faction %s en danger. Favorise guerison." % risk
	elif score > 80:
		balance_hint = " Joueur stable. Plus de risques."

	var user_input := "Scene: %s\nChoix: %s\nVie=%d%s" % [
		scenario_text.substr(0, 120),
		", ".join(labels),
		life, balance_hint
	]

	# GM brain, low temp, no grammar (Ollama-compatible)
	# max_tokens 200: two-example prompt + 3-option effects JSON needs ~170 chars
	var gm_params: Dictionary = {"max_tokens": 200, "temperature": 0.15}
	var result: Dictionary = await merlin_ai.generate_structured(system, user_input, "", gm_params)

	if result.has("text"):
		var parsed_effects := _parse_smart_effects_json(str(result.text))
		if parsed_effects.size() == 3:
			return parsed_effects

	return []


## Parse Game Master effects JSON with repair logic.
## Returns Array of 3 Arrays on success, empty Array on failure.
func _parse_smart_effects_json(raw: String) -> Array:
	var json_start := raw.find("{")
	var json_end := raw.rfind("}")
	if json_start < 0 or json_end <= json_start:
		# Try repair: maybe truncated without closing brace
		if json_start >= 0:
			# Try multiple closing patterns for different truncation depths
			var partial: String = raw.substr(json_start)
			var repair_suffixes: Array[String] = ["]}]}", "}]}]}", "]}"]
			for suffix: String in repair_suffixes:
				var attempt: Array = _try_parse_effects_dict(partial + suffix)
				if attempt.size() == 3:
					return attempt
		return []

	var json_str := raw.substr(json_start, json_end - json_start + 1)
	var result := _try_parse_effects_dict(json_str)
	if result.size() == 3:
		return result

	# Repair pass: fix common Qwen 2.5-1.5B JSON issues
	var repaired := json_str
	# Single quotes → double quotes
	repaired = repaired.replace("'", "\"")
	# Trailing commas before ] or }
	var rx := RegEx.new()
	rx.compile(",\\s*([\\]\\}])")
	repaired = rx.sub(repaired, "$1", true)
	result = _try_parse_effects_dict(repaired)
	if result.size() == 3:
		return result

	return []


## Internal: attempt to parse a JSON string as effects dict, validate, return 3-array or empty.
func _try_parse_effects_dict(json_str: String) -> Array:
	var parsed = JSON.parse_string(json_str)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("effects"):
		return []

	var effects_raw = parsed["effects"]
	if not effects_raw is Array or effects_raw.size() != 3:
		return []

	var allowed_effects := MerlinLlmAdapter.ALLOWED_EFFECT_TYPES
	var result: Array = []
	for option_effects in effects_raw:
		if not option_effects is Array:
			return []
		var validated: Array = []
		for eff in option_effects:
			if not eff is Dictionary or not eff.has("type"):
				continue
			var eff_type: String = str(eff["type"])
			if eff_type == "ADD_REPUTATION":
				var faction: String = str(eff.get("faction", ""))
				# SEC-3: Cap matches MerlinReputationSystem.CAP_PER_CARD (±20)
				var amount: float = clampf(float(eff.get("amount", 0.0)), -20.0, 20.0)
				if faction in FACTIONS:
					validated.append({"type": "ADD_REPUTATION", "faction": faction, "amount": amount})
			elif eff_type in allowed_effects and eff.has("amount"):
				var eff_amount: int = clampi(int(eff["amount"]), 1, 10)
				validated.append({"type": eff_type, "amount": eff_amount})
		if validated.is_empty():
			validated.append({"type": "HEAL_LIFE", "amount": 3})
		result.append(validated)

	return result


## Generate effects that vary based on game state and quest position.
## Each option affects a different faction's reputation (1-4 options, variable).
func generate_contextual_effects(context_or_aspects: Dictionary) -> Array:
	var factions: Dictionary = {}
	var life: int = 100
	var cards_played: int = 0

	if context_or_aspects.has("life_essence"):
		life = int(context_or_aspects.get("life_essence", 100))
		cards_played = int(context_or_aspects.get("cards_played", 0))
		factions = context_or_aspects.get("factions", {})
	elif context_or_aspects.has("factions"):
		factions = context_or_aspects.get("factions", {})

	# Balance intelligence: adapt effects to player state (0ms heuristic)
	var balance := evaluate_balance_heuristic(context_or_aspects)
	var balance_score: int = int(balance.get("balance_score", 100))
	var risk_faction: String = str(balance.get("risk_faction", "none"))

	# Scale amounts based on quest position
	var base_amount: float = 5.0 + minf(float(cards_played) / 2.0, 10.0)

	var effects: Array = []

	# FACTION SYSTEM: Each option shifts a faction's reputation.
	# Pick 3 factions for the 3 options, prioritizing the risk faction.
	var option_factions: Array[String] = []
	if risk_faction != "none" and risk_faction in FACTIONS:
		option_factions.append(risk_faction)

	for f in FACTIONS:
		if option_factions.size() >= 3:
			break
		if f not in option_factions:
			option_factions.append(f)

	# Option 1: positive rep toward first faction
	var f1_rep: float = float(factions.get(option_factions[0], 0.0))
	var f1_amount: float = base_amount if f1_rep < 50.0 else -base_amount * 0.5
	effects.append({"type": "ADD_REPUTATION", "faction": option_factions[0], "amount": f1_amount})

	# Option 2: positive rep toward second faction
	var f2_rep: float = float(factions.get(option_factions[1], 0.0))
	var f2_amount: float = base_amount if f2_rep < 50.0 else -base_amount * 0.5
	effects.append({"type": "ADD_REPUTATION", "faction": option_factions[1], "amount": f2_amount})

	# Option 3: positive rep toward third faction (or PROGRESS_MISSION late game)
	if cards_played >= 10:
		effects.append({"type": "PROGRESS_MISSION", "step": 1})
	else:
		var f3_rep: float = float(factions.get(option_factions[2], 0.0))
		var f3_amount: float = base_amount if f3_rep < 50.0 else -base_amount * 0.5
		effects.append({"type": "ADD_REPUTATION", "faction": option_factions[2], "amount": f3_amount})

	return effects


## Extract visual tags from narrative text for scene illustration.
## Uses Game Master brain (T=0.15, max_tokens=40) for fast keyword extraction.
## Fallback: derive tags from biome + card tags if LLM extraction fails.
func extract_visual_tags(narrative: String, context: Dictionary, merlin_ai: Node) -> Array:
	if narrative.is_empty():
		return derive_fallback_visual_tags(context)

	if merlin_ai == null or not merlin_ai.is_ready:
		return derive_fallback_visual_tags(context)

	var biome: String = str(context.get("biome", "foret_broceliande"))
	var sys := "Extrais les elements visuels de cette scene celtique. " + \
		"Reponds UNIQUEMENT par des mots-cles en francais separes par des virgules. " + \
		"Categories: lieu (1 mot), elements (2-3 mots), moment (1 mot), meteo (0-1 mot). " + \
		"Exemple: clairiere, chene, brume, torche, crepuscule"
	var usr := "Scene: %s\nBiome: %s" % [narrative.substr(0, 250), biome]

	var params := {
		"temperature": 0.15,
		"top_p": 0.8,
		"max_tokens": 40,
		"top_k": 15,
		"repetition_penalty": 1.0,
	}

	# Use generate_structured (routed to GM brain, low temp) for keyword extraction
	var result: Dictionary = await merlin_ai.generate_structured(sys, usr, "", params)
	if result.has("error") or not result.has("text"):
		return derive_fallback_visual_tags(context)

	var raw: String = str(result.get("text", "")).strip_edges()
	if raw.length() < 3:
		return derive_fallback_visual_tags(context)

	# Parse comma-separated tags, clean whitespace and normalize
	var tags: Array = []
	for part in raw.split(","):
		var clean: String = part.strip_edges().to_lower()
		# Remove non-alphabetic chars, keep accented letters
		clean = clean.replace(".", "").replace(":", "").replace(";", "")
		if clean.length() >= 2 and clean.length() <= 30:
			tags.append(clean)

	if tags.size() < 2:
		return derive_fallback_visual_tags(context)
	return tags


## Derive visual tags from biome metadata and card tags (100% reliable fallback).
func derive_fallback_visual_tags(context: Dictionary) -> Array:
	var biome: String = str(context.get("biome", "foret_broceliande"))
	var base_tags: Array = PixelSceneData.BIOME_DEFAULT_TAGS.get(biome, ["foret", "arbres"])
	var result: Array = base_tags.duplicate()

	# Add modifier-based tags from card tags
	var card_tags: Array = context.get("_card_tags", [])
	for card_tag in card_tags:
		var modifier_tags: Array = PixelSceneData.MODIFIER_TAGS.get(str(card_tag), [])
		for mt in modifier_tags:
			if mt not in result:
				result.append(mt)

	# Add celtic theme if it maps to a known element
	var celtic_theme: String = str(context.get("_celtic_theme", ""))
	if not celtic_theme.is_empty():
		for word in celtic_theme.split(" "):
			var w: String = word.strip_edges().to_lower()
			if w.length() >= 4:
				result.append(w)

	return result


## Generate narrative consequences for 3 options via LLM (Narrator brain).
## Returns 3 success-consequence strings (2-3 phrases each).
## Falls back to template-based consequences if LLM unavailable.
func generate_consequences(card_text: String, options: Array, context: Dictionary, merlin_ai: Node) -> Array[String]:
	if merlin_ai == null or not merlin_ai.is_ready or card_text.length() < 20:
		return []

	var labels: Array[String] = []
	for opt in options:
		labels.append(str(opt.get("label", "?")))
	if labels.size() < 3:
		return []

	var balance := evaluate_balance_heuristic(context)
	var b_score: int = int(balance.get("balance_score", 100))
	var tone_hint := ""
	if b_score < 30:
		tone_hint = " Le voyageur est en peril — les consequences sont graves."
	elif b_score < 50:
		tone_hint = " Le voyageur est fragile — les consequences comptent."
	elif b_score > 80:
		tone_hint = " Le voyageur est en confiance — les consequences sont plus legeres."

	var system := (
		"Tu ecris les CONSEQUENCES de choix dans un jeu narratif celtique. "
		+ "Pour chaque choix, ecris 2 phrases: ce qui se passe quand le voyageur fait ce choix. "
		+ "Style sensoriel (sons, odeurs, douleur, soulagement). Deuxieme personne (tu). "
		+ "JAMAIS de meta-commentaire. JAMAIS d'anglais."
		+ tone_hint
		+ "\nReponds EXACTEMENT au format:\n"
		+ "A: [consequence 2 phrases]\nB: [consequence 2 phrases]\nC: [consequence 2 phrases]"
	)
	var user := "Scene: \"%s\"\nChoix: A) %s | B) %s | C) %s\nEcris les 3 consequences." % [
		card_text.substr(0, 150), labels[0], labels[1], labels[2]]

	var params := {"max_tokens": 200, "temperature": 0.7, "top_p": 0.9, "top_k": 40, "repetition_penalty": 1.3}
	var result: Dictionary = await merlin_ai.generate_with_system(system, user, params)
	if result.has("error"):
		return []

	var raw: String = str(result.get("text", ""))
	return parse_consequences(raw)


## Parse LLM consequence output into 3 strings.
func parse_consequences(raw: String) -> Array[String]:
	var out: Array[String] = []
	var rx := RegEx.new()
	rx.compile("(?mi)^\\s*[ABC][):.]\\s*(.+)")
	var matches := rx.search_all(raw)
	for m in matches:
		var line: String = m.get_string(1).strip_edges()
		# Clean markdown artifacts
		line = line.replace("**", "").replace("*", "")
		if line.length() > 10:
			out.append(line)
		if out.size() >= 3:
			break

	# Fallback: split by double newlines if regex fails
	if out.size() < 3:
		var parts := raw.split("\n\n", false)
		for p in parts:
			var clean: String = p.strip_edges().replace("**", "").replace("*", "")
			if clean.length() > 15 and out.size() < 3:
				# Strip leading "A:" etc
				var strip_rx := RegEx.new()
				strip_rx.compile("^[ABC][):.\\s]+")
				clean = strip_rx.sub(clean, "", false)
				out.append(clean.strip_edges())

	if out.size() < 3:
		return []
	return out


## Build a failure variant from a success consequence by inverting the tone.
func build_failure_from_success(success_text: String) -> String:
	# Simple inversion: add failure prefix, keep sensory language
	var failure_prefixes: Array[String] = [
		"Le geste echoue. ",
		"Le destin se retourne. ",
		"L'effort ne suffit pas. ",
		"La foret refuse. ",
	]
	var prefix_hash: int = success_text.hash() % failure_prefixes.size()
	if prefix_hash < 0:
		prefix_hash = -prefix_hash % failure_prefixes.size()
	var prefix: String = failure_prefixes[prefix_hash]
	# Take the second sentence from success if available, or truncate
	var sentences := success_text.split(". ")
	if sentences.size() > 1:
		return prefix + sentences[-1].strip_edges()
	return prefix + "Les consequences se font sentir sans merci."
