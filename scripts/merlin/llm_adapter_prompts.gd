## ═══════════════════════════════════════════════════════════════════════════════
## LLM Adapter — Prompt Building & Templates
## ═══════════════════════════════════════════════════════════════════════════════
## System/user prompt construction, arc-phase mapping, context enrichment,
## narrative motif extraction, balance hints, format instructions.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name LlmAdapterPrompts

# References set by parent adapter
var _scenario_prompts: Dictionary = {}
var _scenario_prompts_loaded: bool = false

# Track last used verb pool index to avoid repeats
var _last_verb_pool_idx: int = -1


## Map card position to a scenario arc phase template key.
func get_arc_phase(cards_played: int) -> String:
	if cards_played <= 0:
		return "mini_arc_intro"
	elif cards_played <= 2:
		return "scenario_ambient_card"
	elif cards_played <= 4:
		return "mini_arc_complication"
	elif cards_played <= 6:
		return "mini_arc_climax"
	elif cards_played <= 8:
		return "twist_climax"
	else:
		# Late game: cycle between complication and climax
		return "mini_arc_climax" if cards_played % 2 == 0 else "scenario_ambient_card"


## Get a scenario prompt template by event category key.
## Returns { system, user_template, role, max_tokens, temperature } or empty.
func get_scenario_template(event_key: String) -> Dictionary:
	if not _scenario_prompts_loaded:
		return {}
	return _scenario_prompts.get(event_key, {})


## Build balance-aware hint for system prompt (0ms, heuristic only).
func build_balance_hint(context: Dictionary, balance_evaluator: Callable) -> String:
	var balance: Dictionary = balance_evaluator.call(context)
	var score: int = int(balance.get("balance_score", 100))
	var risk: String = str(balance.get("risk_faction", "none"))
	if score < 30:
		if risk != "none":
			return "\nURGENCE: Le voyageur est en peril (%s critique). Au moins un choix doit offrir du repos ou de la guerison." % risk
		return "\nURGENCE: Le voyageur est en peril. Un choix doit offrir du repos."
	elif score < 50 and risk != "none":
		return "\nEQUILIBRE FRAGILE: %s en danger. Oriente certains choix vers la stabilite." % risk
	elif score > 80:
		return "\nEQUILIBRE STABLE: Le voyageur est en securite. Augmente les enjeux et les risques."
	return ""


## Build compact format instructions with rotating example.
## Keeps format as the LAST thing the model sees (recency bias for small models).
func format_instructions(cards_played: int) -> String:
	# RULE: "Tu" MUST be the first word and most prominent instruction.
	# Qwen 1.5B ignores buried instructions — front-load the perspective constraint.
	var s := "\n\nREGLE: Utilise TU (2eme personne). JAMAIS Je, Il, Elle, Nous, On."
	s += "\nPhrases courtes, poetiques, sensorielles. Vocabulaire celtique breton."
	s += "\nDecris ce que TU vis, puis 3 choix (A/B/C)."
	s += "\n\nFormat:\nTu [scene 3-5 phrases]\nA) VERBE — action en 1 phrase\nB) VERBE — action differente\nC) VERBE — action differente"
	# Rotate examples to prevent model from copying same verbs every time
	match cards_played % 3:
		0:
			s += "\n\nExemple:\nTu decouvres une source bouillonnante entre les racines. L'eau noircit et une voix chante depuis les profondeurs.\nA) PLONGER — Tu enfonces les mains dans l'eau sombre pour saisir ce qui appelle.\nB) ECOUTER — Tu te penches et tentes de comprendre les mots de la voix.\nC) BLOQUER — Tu empiles des pierres pour sceller la source."
		1:
			s += "\n\nExemple:\nTu atteins un cercle de pierres dressees. Au centre, un feu bleu brule sans bois. Des ombres dansent sur les menhirs.\nA) TRAVERSER — Tu franchis le cercle et tends les mains vers la flamme bleue.\nB) GRAVER — Tu traces une rune sur le menhir avec ta lame.\nC) SIFFLER — Tu imites le chant du merle pour troubler les ombres."
		2:
			s += "\n\nExemple:\nTu fais face a un pont de mousse au-dessus d'un ravin. Une creature bloque le passage et tend une main griffue.\nA) NEGOCIER — Tu offres une baie de ta besace en echange du passage.\nB) BONDIR — Tu sautes par-dessus la creature et cours vers l'autre rive.\nC) CARESSER — Tu poses la main sur sa tete moussue pour l'apaiser."
	s += "\nTu [scene] puis A) B) C). Rien d'autre."
	return s


## Build scenario injection block appended to ALL system prompts.
## Ensures scenario context always reaches the LLM regardless of template.
func build_scenario_injection(context: Dictionary) -> String:
	var parts: Array[String] = []
	var scenario_title: String = str(context.get("scenario_title", ""))
	var scenario_theme: String = str(context.get("scenario_theme", ""))
	var anchor_context: String = str(context.get("anchor_context", ""))

	if not scenario_title.is_empty():
		parts.append("\nQUETE EN COURS: \"%s\"." % scenario_title)
	if not scenario_theme.is_empty():
		parts.append("AMBIANCE: %s" % scenario_theme)
	if not anchor_context.is_empty():
		parts.append("MOMENT CLE (INTEGRE OBLIGATOIREMENT DANS TA SCENE): %s" % anchor_context)
	return "\n".join(parts) if not parts.is_empty() else ""


## Substitute template variables from context (biome, factions, scenario, etc.).
func substitute_template_vars(tpl: String, context: Dictionary, cards_played: int = 0, theme_word: String = "") -> String:
	tpl = tpl.replace("{biome}", str(context.get("biome", "foret_broceliande")))
	tpl = tpl.replace("{day}", str(context.get("day", 1)))
	tpl = tpl.replace("{tension}", str(context.get("tension", 0)))
	tpl = tpl.replace("{life}", str(context.get("life_essence", 100)))

	tpl = tpl.replace("{scenario_title}", str(context.get("scenario_title", "Voyage en Broceliande")))
	tpl = tpl.replace("{scenario_theme}", str(context.get("scenario_theme", theme_word)))
	tpl = tpl.replace("{anchor_context}", str(context.get("anchor_context", "")))
	tpl = tpl.replace("{arc_context}", str(context.get("arc_context", "")))
	tpl = tpl.replace("{recent_events}", str(context.get("recent_events", "")))
	tpl = tpl.replace("{active_tags}", str(context.get("active_tags_str", "")))
	tpl = tpl.replace("{ambient_tags}", str(context.get("ambient_tags", "")))
	tpl = tpl.replace("{sub_type}", str(context.get("sub_type", "")))
	tpl = tpl.replace("{faction_status}", str(context.get("faction_status", "")))
	tpl = tpl.replace("{flags}", str(context.get("flags", "")))
	# Faction context
	var factions: Dictionary = context.get("factions", {})
	var dominant := ""
	var best := 0.0
	for f_name in factions:
		var val: float = float(factions[f_name])
		if val > best:
			best = val
			dominant = str(f_name)
	tpl = tpl.replace("{dominant_faction}", dominant)
	# Arc-specific vars (map to scenario context)
	tpl = tpl.replace("{arc_theme}", str(context.get("scenario_theme", theme_word)))
	tpl = tpl.replace("{arc_name}", str(context.get("scenario_title", "")))
	tpl = tpl.replace("{arc_progress}", str(cards_played))
	# Duality pairs for moral dilemmas — rotate by card index
	var duality_pairs := [
		["honneur", "survie"], ["verite", "paix"], ["loyaute", "conscience"],
		["courage", "prudence"], ["memoire", "oubli"], ["justice", "misericorde"],
		["force", "ruse"], ["tradition", "changement"], ["devoir", "liberte"],
	]
	var pair: Array = duality_pairs[cards_played % duality_pairs.size()]
	tpl = tpl.replace("{duality_a}", pair[0])
	tpl = tpl.replace("{duality_b}", pair[1])

	# Faction reputation summary for templates using {faction_rep}
	var rep_parts: PackedStringArray = []
	for f_name in factions:
		rep_parts.append("%s=%d" % [str(f_name), int(factions[f_name])])
	tpl = tpl.replace("{faction_rep}", ", ".join(rep_parts) if not rep_parts.is_empty() else "equilibre")
	return tpl


## Build a structured system prompt using scenario templates when available.
func build_arc_system_prompt(cards_played: int, theme_word: String, context: Dictionary, balance_evaluator: Callable) -> String:
	var arc_phase := get_arc_phase(cards_played)
	var tpl := get_scenario_template(arc_phase)

	# Use scenario template if available
	if not tpl.is_empty() and tpl.has("system"):
		var sys: String = str(tpl["system"])
		# Replace template variables that may be in the system prompt
		var scenario_theme_val: String = str(context.get("scenario_theme", theme_word))
		sys = sys.replace("{scenario_title}", str(context.get("scenario_title", "Voyage en Broceliande")))
		sys = sys.replace("{anchor_context}", str(context.get("anchor_context", "")))
		sys = sys.replace("{scenario_theme}", scenario_theme_val)
		sys = sys.replace("{arc_theme}", scenario_theme_val)
		sys = sys.replace("{arc_name}", str(context.get("scenario_title", "")))
		# Balance intelligence: adapt narrative tone to player state
		sys += build_balance_hint(context, balance_evaluator)
		# Compact format instructions with rotating example (avoids model copying same verbs)
		sys += format_instructions(cards_played)
		return sys

	# Fallback: enriched default prompt
	var biome_name: String = str(context.get("biome", "foret_broceliande")).replace("_", " ").capitalize()
	var life: int = int(context.get("life_essence", 100))
	var karma: int = int(context.get("karma", 0))

	# MOS convergence hints aligned with MerlinConstants.MOS_CONVERGENCE thresholds
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var convergence_hint := ""
	if cards_played >= int(mos.get("soft_max_cards", 40)):
		convergence_hint = "\nURGENCE NARRATIVE: La quete doit se conclure. Oriente TOUT vers la resolution finale."
	elif cards_played >= int(mos.get("target_cards_max", 25)):
		convergence_hint = "\nLa quete approche de sa fin. Oriente la scene vers une resolution."
	elif cards_played >= int(mos.get("target_cards_min", 20)):
		convergence_hint = "\nLa tension monte. Les enjeux deviennent plus importants."
	elif cards_played >= int(mos.get("soft_min_cards", 8)):
		convergence_hint = "\nLe voyage est engage. Les choix commencent a peser."

	# Balance intelligence: adapt narrative tone to player state
	var balance_hint := build_balance_hint(context, balance_evaluator)

	return (
		"Tu es Merlin l'Enchanteur, vieux druide FOU de Broceliande. Tu PERDS LA BOULE mais tu decris brillamment. Moque-toi du voyageur ('mon pauvre ami'). Digressions courtes. TU (jamais nous/je/il). Pas de 'Voici'. Pas de meta.\n"
		+ "LIEU: %s | CARTE: %d | THEME: %s\n" % [biome_name, cards_played + 1, theme_word]
		+ "ETAT: Vie=%d/100, Karma=%d\n" % [life, karma]
		+ convergence_hint
		+ balance_hint
		+ format_instructions(cards_played)
	)


## Build user prompt with game state and arc context.
func build_arc_user_prompt(cards_played: int, biome: String, theme_word: String, context: Dictionary, balance_evaluator: Callable) -> String:
	var arc_phase := get_arc_phase(cards_played)
	var tpl := get_scenario_template(arc_phase)

	var base_prompt: String
	# Use scenario template if available — substitute variables directly
	if not tpl.is_empty() and tpl.has("user_template"):
		base_prompt = substitute_template_vars(str(tpl["user_template"]), context, cards_played, theme_word)
	else:
		# Fallback: concise prompt — small models follow short instructions better
		var balance_ctx: Dictionary = balance_evaluator.call(context)
		var verbs: Array = get_phase_verb_pool(int(balance_ctx.get("balance_score", 100)))
		# FIX 35: Rotate opening hooks to prevent "Tu marches" repetition
		var opening_hooks: Array[String] = [
			"Tu decouvres", "Tu entends", "Tu sens", "Tu apercois",
			"Tu te reveilles", "Tu tombes sur", "Tu fais face a",
			"Tu trebuches sur", "Tu reconnais", "Tu touches",
		]
		var hook: String = opening_hooks[cards_played % opening_hooks.size()]
		base_prompt = "Carte %d. Biome: %s. Theme: %s.\nCOMMENCE PAR: \"%s...\"\nDecris une SITUATION (danger, enigme, rencontre). Puis A) B) C) = ses REACTIONS. Verbes SPECIFIQUES (pas 'avancer'/'observer'/'fuir').\nInspiration verbes: %s, %s, %s." % [
			cards_played + 1, biome, theme_word, hook, str(verbs[0]), str(verbs[1]), str(verbs[2])]

	# Inject scenario context into user prompt (always)
	var scenario_title: String = str(context.get("scenario_title", ""))
	var anchor_context: String = str(context.get("anchor_context", ""))
	var arc_context: String = str(context.get("arc_context", ""))
	var recent_events: String = str(context.get("recent_events", ""))

	if not scenario_title.is_empty():
		base_prompt += "\nScenario: %s." % scenario_title
	if not anchor_context.is_empty():
		base_prompt += "\nMOMENT CLE (integre dans ta scene): %s" % anchor_context
	if not arc_context.is_empty():
		base_prompt += "\n%s" % arc_context
	if not recent_events.is_empty():
		base_prompt += "\n%s" % recent_events

	# Enrich with game intelligence context
	base_prompt += build_context_enrichment(context)
	return base_prompt


## Build enrichment string from game intelligence (tension, talents, tendency, echo memory).
func build_context_enrichment(context: Dictionary) -> String:
	var parts: Array[String] = []

	# Tension
	var tension: int = int(context.get("tension", 0))
	if tension >= 60:
		parts.append("Tension haute")
	elif tension >= 40:
		parts.append("Tension moderee")

	# MOS convergence zone — narrative pacing pressure
	var tension_zone: String = str(context.get("tension_zone", "none"))
	if tension_zone == "critical":
		parts.append("RESOLUTION IMMINENTE")
	elif tension_zone == "high":
		parts.append("Quete proche de sa fin")
	elif tension_zone == "rising":
		parts.append("Tension narrative montante")

	# Player tendency
	var tendency: String = str(context.get("player_tendency", ""))
	if tendency != "" and tendency != "neutre":
		parts.append("Joueur %s" % tendency)

	# Active talents (max 3 for token budget)
	var talent_names: Array = context.get("talent_names", [])
	if not talent_names.is_empty():
		var names: Array[String] = []
		for i in range(mini(talent_names.size(), 3)):
			names.append(str(talent_names[i]))
		parts.append("Talents: %s" % ", ".join(names))

	# Cross-run echo memory — narrative callbacks to past runs
	var echo: Dictionary = context.get("echo_memory", {})
	var total_runs: int = int(context.get("total_runs", 0))
	if total_runs >= 5:
		parts.append("Veteran (%d voyages)" % total_runs)
	var biome: String = str(context.get("biome", ""))
	var deaths_by_biome: Dictionary = echo.get("deaths_by_biome", {})
	var biome_deaths: int = int(deaths_by_biome.get(biome, 0))
	if biome_deaths >= 2:
		parts.append("Deja mort %dx ici" % biome_deaths)
	elif biome_deaths == 1:
		parts.append("Deja mort ici une fois")
	var dom_factions: Array = echo.get("dominant_factions_seen", [])
	if dom_factions.size() >= 3:
		parts.append("Factions connues: %s" % ", ".join(dom_factions.slice(0, 3)))

	if parts.is_empty():
		return ""
	return " " + ". ".join(parts) + "."


## Extract recurring motifs from the story log for narrative callback.
## Returns significant words (>5 chars, not common) seen in 2+ entries.
func extract_recurring_motifs(story_log: Array) -> Array[String]:
	var word_counts: Dictionary = {}
	var common_words := ["foret", "merlin", "chemin", "choix", "voyageur", "scene",
		"carte", "narrativ", "place", "temps", "moment", "monde", "trois",
		"avant", "apres", "autre", "comme", "cette", "entre", "encore"]

	for entry in story_log:
		var text: String = str(entry.get("text", "")).to_lower()
		var seen: Dictionary = {}
		for word in text.split(" ", false):
			# Only significant words (>5 chars, not seen in this entry yet)
			var clean: String = word.replace(",", "").replace(".", "").replace("!", "").replace("?", "")
			if clean.length() > 5 and not seen.has(clean) and not clean in common_words:
				seen[clean] = true
				word_counts[clean] = int(word_counts.get(clean, 0)) + 1

	# Return words that appear in 2+ entries (recurring motifs)
	var motifs: Array[String] = []
	for w in word_counts:
		if int(word_counts[w]) >= 2 and motifs.size() < 5:
			motifs.append(str(w))
	return motifs


## Jaccard similarity between two texts (word-level). Returns 0.0-1.0.
func jaccard_similarity(a: String, b: String) -> float:
	var words_a: Dictionary = {}
	var words_b: Dictionary = {}
	for w in a.to_lower().split(" ", false):
		words_a[w] = true
	for w in b.to_lower().split(" ", false):
		words_b[w] = true
	if words_a.is_empty() and words_b.is_empty():
		return 1.0
	var intersection := 0
	for w in words_a:
		if words_b.has(w):
			intersection += 1
	var union_size: int = words_a.size() + words_b.size() - intersection
	if union_size == 0:
		return 1.0
	return float(intersection) / float(union_size)


## Get a verb triplet [prudent, mystique, audacieux] based on balance phase.
## Rotates through the pool using a seeded random to avoid repetition.
func get_phase_verb_pool(balance_score: int) -> Array:
	var pool: Array
	if balance_score > 80:
		pool = MerlinLlmAdapter.VERB_POOL_SAFE
	elif balance_score >= 30:
		pool = MerlinLlmAdapter.VERB_POOL_FRAGILE
	else:
		pool = MerlinLlmAdapter.VERB_POOL_CRITICAL
	# Avoid repeating the same triplet as the previous card
	var hash_input: String = str(balance_score) + "_" + str(pool.size())
	var idx: int = hash_input.hash() % pool.size()
	if idx < 0:
		idx = -idx % pool.size()
	if pool.size() > 1 and idx == _last_verb_pool_idx:
		idx = (idx + 1) % pool.size()
	_last_verb_pool_idx = idx
	return pool[idx]


## Build the narrative system prompt (compact for Qwen 3.5-4B).
func build_narrative_system_prompt() -> String:
	return "Merlin druide. 1 carte JSON: texte court (2-3 phrases), exactement 3 options (1 verbe chacune, 1-3 effets chacune). Ton celtique. Factions: druides, anciens, korrigans, niamh, ankou. Effets valides: ADD_REPUTATION (faction+amount ±20 max), HEAL_LIFE, DAMAGE_LIFE, ADD_ANAM, ADD_BIOME_CURRENCY, UNLOCK_OGHAM.\n{\"text\":\"...\",\"speaker\":\"merlin\",\"options\":[{\"label\":\"...\",\"effects\":[{\"type\":\"ADD_REPUTATION\",\"faction\":\"druides\",\"amount\":10}]},{\"label\":\"...\",\"effects\":[{\"type\":\"HEAL_LIFE\",\"amount\":5}]},{\"label\":\"...\",\"effects\":[{\"type\":\"ADD_REPUTATION\",\"faction\":\"ankou\",\"amount\":8}]}],\"tags\":[\"tag\"]}"


func build_narrative_user_prompt(context: Dictionary) -> String:
	var cards_played: int = int(context.get("cards_played", 0))
	var day: int = int(context.get("day", 1))
	var tags: Array = context.get("active_tags", [])

	var prompt := "Jour:%d. Carte:%d." % [day, cards_played]

	# Faction status
	var faction_status: String = str(context.get("faction_status", ""))
	if not faction_status.is_empty():
		prompt += " Factions:%s." % faction_status

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
		var prev_text: String = str(last_entry.get("text", "")).substr(0, 50)
		if prev_text.length() > 0:
			prompt += " Precedent: %s." % prev_text

	# JSON template moved to system prompt (Phase 0C: saves ~93 tokens/gen)
	return prompt
