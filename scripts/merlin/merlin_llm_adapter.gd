## ═══════════════════════════════════════════════════════════════════════════════
## Merlin LLM Adapter — Card Contract (TRIADE + Legacy)
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
	"ADD_ESSENCE",
]

const TRIADE_ASPECTS := ["Corps", "Ame", "Monde"]
const TRIADE_DIRECTIONS := ["up", "down"]
const TRIADE_STATES := [-1, 0, 1]

# LLM generation params tuned for Qwen 2.5-3B-Instruct
const TRIADE_LLM_PARAMS := {
	"max_tokens": 180,  # 4-5 lines + A) B) C) verbs — ~10s on CPU @ 18tok/s
	"temperature": 0.65,
	"top_p": 0.88,
	"top_k": 35,
	"repetition_penalty": 1.4,
}

const GENERATION_TIMEOUT_MS := 30000

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

# Generic labels used only when LLM label extraction fails (zero fallback policy)
const GENERIC_LABELS: Array = ["Agir", "Observer", "Continuer"]

# Phase-aware verb pools: A=prudent, B=mystique, C=audacieux
# Selected by balance score to match narrative tone
const VERB_POOL_SAFE: Array = [  # balance > 80 — exploration, curiosity
	["Escalader", "Dechiffrer", "Contourner"],
	["Plonger", "Cueillir", "Provoquer"],
	["Traverser", "Invoquer", "Deraciner"],
	["Soulever", "Gouter", "Enjamber"],
	["Creuser", "Siffler", "Toucher"],
	["Nager", "Graver", "Arracher"],
	["Grimper", "Renifler", "Briser"],
]
const VERB_POOL_FRAGILE: Array = [  # balance 30-80 — caution, dilemma
	["Panser", "Negocier", "Braver"],
	["Enraciner", "Dechiffrer", "Frapper"],
	["Trancher", "Pardonner", "Defier"],
	["Barricader", "Calmer", "Provoquer"],
	["Secourir", "Marchander", "Forcer"],
	["Desarmer", "Reciter", "Pieger"],
	["Bloquer", "Apaiser", "Bousculer"],
]
const VERB_POOL_CRITICAL: Array = [  # balance < 30 — survival, repair
	["Cautériser", "Ramper", "Sacrifier"],
	["Reparer", "Ancrer", "Amputer"],
	["Consolider", "Implorer", "Resister"],
	["Harmoniser", "Absorber", "Abandonner"],
	["Guerir", "Sceller", "Bruler"],
	["Recoudre", "Supplier", "Trancher"],
]

# Celtic narrative fallbacks when LLM generates only meta-text
const NARRATIVE_FALLBACKS: Array[String] = [
	"La brume s'epaissit entre les chenes centenaires. Un murmure ancien resonne depuis les pierres moussues.",
	"Un sentier oublie s'ouvre devant toi, borde de fougeres argentees. L'air vibre d'une magie ancienne.",
	"Les pierres dressees bourdonnent d'une energie invisible. Le vent porte l'echo d'un chant druidique.",
	"Une clairiere baignee de lumiere doree apparait. Au centre, un cercle de champignons luminescents pulse doucement.",
	"Le cri d'un corbeau dechire le silence. Entre les branches, une silhouette spectrale t'observe.",
	"Les racines du vieux chene forment un passage vers les profondeurs. Une lueur bleutee en emerge.",
	"Un ruisseau chante entre les rochers couverts d'ogham. Ses eaux semblent reflechir un ciel different.",
	"Le brouillard se leve, revelant un dolmen que personne n'a vu depuis des siecles.",
]

# GBNF Grammar for constrained JSON generation (Phase 30)
const TRIADE_GRAMMAR_PATH := "res://data/ai/merlin_card.gbnf"
var _triade_grammar: String = ""

# Scenario prompts — per-category templates (Phase 44)
const SCENARIO_PROMPTS_PATH := "res://data/ai/config/scenario_prompts.json"
var _scenario_prompts: Dictionary = {}
var _scenario_prompts_loaded := false

# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY WHITELIST (kept for backward compatibility)
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
## Generate a narrative prologue for the start of a run.
## Returns a rich atmospheric text (3-5 paragraphs) setting the scene.
func generate_prologue(context: Dictionary) -> Dictionary:
	if not is_llm_ready():
		return {"ok": false, "text": "", "error": "LLM not ready"}

	var biome: String = str(context.get("biome", "foret_broceliande")).replace("_", " ")
	var scenario_title: String = str(context.get("scenario_title", ""))
	var scenario_intro: String = str(context.get("scenario_intro", ""))

	var scenario_block := ""
	if not scenario_title.is_empty():
		scenario_block = "La quete qui commence s'intitule \"%s\". " % scenario_title
	if not scenario_intro.is_empty():
		scenario_block += "Contexte: %s " % scenario_intro

	var system := (
		"Tu es Merlin l'Enchanteur, conteur ancestral. Tu introduis le debut d'un voyage en %s. " % biome
		+ scenario_block
		+ "Ecris un prologue immersif a la deuxieme personne (tu). "
		+ "3 paragraphes: 1) L'ambiance sensorielle du lieu (sons, odeurs, lumiere). "
		+ "2) Ce que le voyageur ressent et ce qu'il pressent de sa quete. "
		+ "3) Un presage ou un detail intrigant lie a la quete qui lance l'aventure. "
		+ "Vocabulaire celtique: nemeton, ogham, brume, menhir, korrigan. "
		+ "Ton grave et poetique, comme un conteur au coin du feu. "
		+ "JAMAIS de meta-commentaire. JAMAIS d'anglais."
	)
	var user := "Biome: %s. Etat: Vie=%d, Souffle=%d. Ecris le prologue." % [
		biome, int(context.get("life_essence", 100)), int(context.get("souffle", 3))]
	if not scenario_title.is_empty():
		user += " Quete: %s." % scenario_title

	var params := {"max_tokens": 400, "temperature": 0.75, "top_p": 0.92, "top_k": 40, "repetition_penalty": 1.3}
	var result: Dictionary = await _merlin_ai.generate_with_system(system, user, params)
	if result.has("error"):
		return {"ok": false, "text": "", "error": str(result.error)}
	var text: String = str(result.get("text", "")).strip_edges()
	# Strip any prompt leakage
	text = text.replace("**", "").replace("*", "")
	return {"ok": true, "text": text}


## Generate a narrative epilogue summarizing the run.
## Takes the story log and final state to build a closing reflection.
func generate_epilogue(context: Dictionary, story_log: Array) -> Dictionary:
	if not is_llm_ready():
		return {"ok": false, "text": "", "error": "LLM not ready"}

	var b_score: int = int(_evaluate_balance_heuristic(context).get("balance_score", 100))
	var cards: int = int(context.get("cards_played", 0))
	var life: int = int(context.get("life_essence", 100))

	# Build summary of key moments from story log
	var moments: Array[String] = []
	for entry in story_log:
		var t: String = str(entry.get("text", "")).substr(0, 60)
		if not t.is_empty():
			moments.append(t)
	var moments_str := " | ".join(moments.slice(-5)) if not moments.is_empty() else "Un voyage sans trace."

	var tone := "triomphant" if b_score >= 80 else ("melancolique" if b_score >= 40 else "grave et solennel")

	var scenario_title: String = str(context.get("scenario_title", ""))
	var scenario_block := ""
	if not scenario_title.is_empty():
		scenario_block = "La quete etait \"%s\". " % scenario_title

	var system := (
		"Tu es Merlin l'Enchanteur. Tu conclus un voyage de %d epreuves. " % cards
		+ scenario_block
		+ "Ecris un epilogue de 2 paragraphes, ton %s. " % tone
		+ "1) Ce que le voyageur a appris de sa quete (lecon liee a l'Equilibre Corps/Ame/Monde). "
		+ "2) Ce qui reste apres le voyage (une image, un souvenir, un pressentiment lie a la quete). "
		+ "Deuxieme personne (tu). Vocabulaire celtique. "
		+ "JAMAIS de meta-commentaire. JAMAIS d'anglais."
	)
	var user := "Balance finale: %d. Vie: %d. Moments cles: %s. Ecris l'epilogue." % [
		b_score, life, moments_str]
	if not scenario_title.is_empty():
		user += " Quete: %s." % scenario_title

	var params := {"max_tokens": 300, "temperature": 0.75, "top_p": 0.92, "top_k": 40, "repetition_penalty": 1.3}
	var result: Dictionary = await _merlin_ai.generate_with_system(system, user, params)
	if result.has("error"):
		return {"ok": false, "text": "", "error": str(result.error)}
	var text: String = str(result.get("text", "")).strip_edges()
	text = text.replace("**", "").replace("*", "")
	return {"ok": true, "text": text}


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

	# Stage 1: Free text generation with rich context
	var cards_played: int = int(context.get("cards_played", 0))
	var theme_idx: int = (cards_played + randi()) % CELTIC_THEMES.size()
	var theme_word: String = CELTIC_THEMES[theme_idx]
	var biome: String = str(context.get("biome", "foret_broceliande"))
	var karma: int = int(context.get("karma", 0))

	# Store celtic theme in context for card visual metadata
	context["_celtic_theme"] = theme_word

	# Select scenario template based on card position in the quest arc
	var system_prompt := _build_arc_system_prompt(cards_played, theme_word, context)
	var user_prompt := _build_arc_user_prompt(cards_played, biome, theme_word, context)

	# Include RAG context if available
	var rag_ctx := ""
	if _merlin_ai and _merlin_ai.get("rag_manager"):
		var rag_mgr = _merlin_ai.rag_manager
		if rag_mgr and rag_mgr.has_method("get_prioritized_context"):
			rag_ctx = rag_mgr.get_prioritized_context(context)
	if not rag_ctx.is_empty():
		user_prompt += " Contexte: %s." % rag_ctx.substr(0, 200)

	# Include story log for narrative continuity — fil rouge between cards (expanded window)
	var story_log: Array = context.get("story_log", [])
	if story_log.size() > 0:
		var history_parts: Array[String] = []
		var log_start: int = maxi(0, story_log.size() - 10)
		for i in range(log_start, story_log.size()):
			var entry = story_log[i]
			var entry_text: String = str(entry.get("text", "")).substr(0, 200)
			var entry_choice: String = str(entry.get("choice", ""))
			var entry_consequence: String = str(entry.get("consequence", "")).substr(0, 120)
			var entry_action: String = str(entry.get("action_desc", "")).substr(0, 80)
			if not entry_text.is_empty():
				var part := entry_text
				if not entry_choice.is_empty():
					part += " → choix: %s" % entry_choice
				if not entry_action.is_empty():
					part += " (%s)" % entry_action
				elif not entry_consequence.is_empty():
					part += " (%s)" % entry_consequence
				history_parts.append(part)
		if not history_parts.is_empty():
			user_prompt += "\nDERNIERES SCENES (reprends des elements pour la continuite):\n"
			for hi in range(history_parts.size()):
				user_prompt += "- %s\n" % history_parts[hi]
		# Recurring motifs — extract key words to encourage callbacks
		var motifs: Array[String] = _extract_recurring_motifs(story_log)
		if not motifs.is_empty():
			user_prompt += "MOTIFS RECURRENTS (reutilise-les subtilement): %s.\n" % ", ".join(motifs)

	# Karma-driven narrative influence — violent karma = violent scenarios
	if abs(karma) >= 3:
		var karma_tone: String = ""
		var karma_hint: String = ""
		if karma >= 7:
			karma_tone = "LUMINEUX et BIENVEILLANT"
			karma_hint = "Allies, beaute, espoir. Options pacifiques et genereuses."
		elif karma >= 3:
			karma_tone = "PAISIBLE"
			karma_hint = "Ambiance calme, rencontres amicales. Mix d'options."
		elif karma <= -7:
			karma_tone = "VIOLENT et SOMBRE"
			karma_hint = "Ennemis, pieges, horreur. Options brutales et desesperees."
		else:  # karma <= -3
			karma_tone = "TENDU et MEFIANT"
			karma_hint = "Atmosphere oppressante. Options mefiantes et agressives."
		if not karma_tone.is_empty():
			user_prompt += "\nKARMA=%d: Ton %s. %s" % [karma, karma_tone, karma_hint]

	# No grammar for free text generation — budget tokens for rich narrative
	var free_params := TRIADE_LLM_PARAMS.duplicate()
	free_params.erase("grammar")
	free_params["max_tokens"] = 400
	free_params["temperature"] = 0.72

	# Use scenario template params if available
	var arc_phase := _get_arc_phase(cards_played)
	var tpl := get_scenario_template(arc_phase)
	if not tpl.is_empty():
		if tpl.has("temperature"):
			free_params["temperature"] = float(tpl["temperature"])
		if tpl.has("max_tokens"):
			free_params["max_tokens"] = int(tpl["max_tokens"])

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

	# Stage 2.5: Smart effects from Game Master (dual brain only, +3-5s)
	var has_dual: bool = _merlin_ai != null and _merlin_ai.brain_count >= 2
	if has_dual:
		var sm_labels: Array[String] = []
		for opt in card.get("options", []):
			sm_labels.append(str(opt.get("label", "?")))
		var smart: Array = await calculate_smart_effects(context, raw_text, sm_labels)
		if smart.size() == 3:
			var options: Array = card.get("options", [])
			for i in range(mini(3, options.size())):
				if i < smart.size():
					options[i]["effects"] = smart[i]
					options[i]["reward_type"] = MerlinConstants.infer_reward_type(smart[i])
			if not card.has("tags"):
				card["tags"] = []
			card["tags"].append("smart_effects")

	# Stage 2.6: Extract visual tags for scene illustration (Game Master brain)
	# Pass card tags to context for fallback derivation
	context["_card_tags"] = card.get("tags", [])
	if has_dual:
		var vtags := await _extract_visual_tags(str(card.get("text", "")), context)
		card["visual_tags"] = vtags
	else:
		card["visual_tags"] = _derive_fallback_visual_tags(context)

	# Stage 3: Generate narrative consequences for each option (Narrator brain)
	var card_text: String = str(card.get("text", ""))
	var card_options: Array = card.get("options", [])
	var consequences: Array[String] = await _generate_consequences(
		card_text, card_options, context)
	if consequences.size() == 3:
		for ci in range(mini(3, card_options.size())):
			card_options[ci]["result_success"] = consequences[ci]
			card_options[ci]["result_failure"] = _build_failure_from_success(consequences[ci])
		if not card.has("tags"):
			card["tags"] = []
		card["tags"].append("llm_consequences")

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

	# Step 0: Pre-split inline choice markers into separate lines.
	# The LLM often generates "...phrase. B) Choix..." or "...phrase. 1) text" inline.
	var presplit_rx := RegEx.new()
	presplit_rx.compile("([.!?\"'\\)])\\s+([A-D1-4]\\)\\s)")
	text = presplit_rx.sub(text, "$1\n$2", true)
	# Also catch numbered items after colons: "explorer: 1) text"
	var colon_presplit_rx := RegEx.new()
	colon_presplit_rx.compile("([:])\\s+([1-4]\\)\\s)")
	text = colon_presplit_rx.sub(text, "$1\n$2", true)

	# Step 1: Strip meta-commentary and prompt leakage lines (BEFORE label extraction
	# so that echoed prompt instructions like "A) VERBE —" don't get captured as labels)
	var meta_words := ["choisissez", "cliquez", "cette carte", "le joueur", "choose", "click",
		"select an option", "options possibles", "voici trois", "voici les", "voici 3",
		# Prompt echo: format/style instructions that Qwen 1.5B reproduces verbatim
		"scene narrative", "ecrivez la scene", "ecris la scene", "format obligatoire",
		"verbe a l'infinitif", "verbe + complement", "verbes :", "[verbe",
		"style obligatoire", "regle stricte", "couplet", "cheminement:",
		"choix (verbes", "options (verbes",
		"choix a)", "choix b)", "choix c)", "choix a )", "choix b )", "choix c )",
		"format:", "style:", "complement", "infinitif", "majuscules",
		"tiret long", "2e personne", "exactement 3", "4-6 phrases",
		"en majuscules", "verbe en", "mini-jeu:",
		# Meta-commentary leakage (observed in test runs)
		"chose a considerer", "choses a considerer",
		"le contexte indique", "contexte indique",
		"le joueur doit", "il faut que le joueur",
		"instructions:", "consignes:", "note:",
		"l'homme est en", "la situation est",
		# Scenario/prompt echo leakage (strip header lines only, not refusals)
		"carte ambiante basee", "basee sur le scenario", "base sur le scenario",
		"voici une carte ambiante", "voici la carte ambiante",
		# Self-referential / AI meta-text (observed in runs)
		"programmation", "mauvaise programmation", "correction",
		"correctement fournie", "je m'excuse", "je suis desole",
		"en tant qu'ia", "en tant qu'intelligence", "bug", "debug",
		"code source", "cette reponse", "cette generation",
		"defaut de generation", "erreur de generation",
		"je ne peux pas", "je suis un modele", "je suis une ia",
		# Phase 46: verb-only format leakage patterns
		"jamais de meta", "jamais de commentaire", "pas de meta",
		"un seul mot", "a l'infinitif", "suggestions de verbes", "chaque verbe",
		"narre au present", "francais uniquement", "ton celtique",
		"vocabulaire celtique", "sensations du voyageur", "pas de dialogue",
		"verbe seul", "un mot", "trois lignes", "3 lignes",
		"3-4 phrases", "meta-commentaire",
		# First-person leakage (LLM narrates as "je" instead of "tu")
		"je vais tenter", "je suis sur que", "j'ai deja vu",
		"vision poetique", "servir a ta cause", "visuelle que narrative",
		"aussi bien visuelle", "narration", "voici l'histoire",
		"voici le scenario", "voici une scene",
		# Numbered/titled header leakage (Qwen 1.5B format)
		"champs d'environnement", "champs d'", "environnement",
		"1 - a", "2 - b", "3 - c", "1- a", "2- b", "3- c",
		"option a", "option b", "option c",
		"choisis parmi", "choisis une",
		# Direct meta-text patterns (Qwen 1.5B "Voici la carte que tu as a explorer:")
		"voici la carte", "carte a explorer", "carte que tu as",
		"voici le texte", "voici les choix", "voici ta",
		"voici ton", "voici l'aventure",
		# Phase 47: additional meta-text patterns observed in test runs
		"voici mes choix", "mes choix :", "voici mes", "mes options",
		"voici tes choix", "tes choix :", "voici tes options",
		"les choix sont", "les options sont", "tu peux choisir"]
	var cleaned_lines: Array[String] = []
	for line in text.split("\n"):
		var lower := line.strip_edges().to_lower()
		if lower.is_empty():
			continue
		var is_meta := false
		for mw in meta_words:
			if lower.find(mw) >= 0:
				is_meta = true
				break
		# Also strip lines that are just labels like "A1)", "C3)", "1 -" at start
		if not is_meta:
			var label_only_rx := RegEx.new()
			label_only_rx.compile("^\\s*[a-dA-D]\\d\\)\\s*$")
			if label_only_rx.search(lower):
				is_meta = true
		# Strip short lines ending with colon (meta-text headers like "Voici mes choix :")
		if not is_meta and lower.ends_with(":") and lower.length() < 40:
			is_meta = true
		if not is_meta:
			cleaned_lines.append(line)
	text = "\n".join(cleaned_lines).strip_edges()

	# Step 1.5: Strip inline prompt leakage fragments (any bracketed content 2+ chars)
	var leak_rx := RegEx.new()
	leak_rx.compile("\\[[^\\]]{2,}\\]")
	text = leak_rx.sub(text, "", true).strip_edges()

	# Step 1.6: Strip self-referential AI sentences (apologies, meta-commentary)
	var self_ref_patterns := ["je m'excuse", "je suis desole", "en tant qu'ia",
		"en tant qu'intelligence artificielle", "je ne suis qu'un",
		"cette reponse", "cette generation", "mauvaise programmation"]
	var sr_cleaned: Array[String] = []
	for sr_line in text.split("\n"):
		var sr_lower := sr_line.strip_edges().to_lower()
		var sr_skip := false
		for srp in self_ref_patterns:
			if sr_lower.find(srp) >= 0:
				sr_skip = true
				break
		if not sr_skip:
			sr_cleaned.append(sr_line)
	text = "\n".join(sr_cleaned).strip_edges()

	# Step 2: Extract labels from CLEANED text (prompt instructions already stripped)
	var labels: Array[Dictionary] = _extract_labels_from_text(text)

	# Step 3: Remove ALL choice/option lines from the narrative text
	var choice_rx := RegEx.new()
	choice_rx.compile("(?m)^\\s*(?:[-*]\\s*)?\\*{0,2}(?:(?:Le\\s+choix\\s+|Action\\s+|Choix\\s+)?[A-D][):.\\]]|[1-3]\\s*[-.]\\s*[A-D]?[):.\\s]|[1-3][.):]|[-*]\\s+\\*{0,2}[A-D][):.\\]]).*$")
	text = choice_rx.sub(text, "", true)

	# Step 3.5: Strip "Scenario:" echo from first 2 lines (prompt leak, not narrative)
	var raw_lines := text.split("\n")
	if raw_lines.size() > 0:
		for si in mini(raw_lines.size(), 2):
			var sl := raw_lines[si].strip_edges().to_lower()
			if sl.begins_with("scenario") and (sl.find(":") >= 0 or sl.find(" :") >= 0):
				raw_lines[si] = ""
		text = "\n".join(raw_lines)

	# Step 4: Strip markdown artifacts
	text = text.replace("**", "").replace("*", "")
	# Strip markdown headers (### Title) and horizontal rules (---)
	var md_cleaned: Array[String] = []
	for md_line in text.split("\n"):
		var trimmed := md_line.strip_edges()
		if trimmed.begins_with("###") or trimmed.begins_with("---"):
			var content := trimmed.trim_prefix("####").trim_prefix("###").strip_edges()
			if not content.is_empty():
				md_cleaned.append(content)
			# else skip the line entirely (pure separator)
		else:
			md_cleaned.append(md_line)
	text = "\n".join(md_cleaned)

	# Step 4.5: Strip short header-like lines (1-3 words, no narrative verb)
	# Catches residual titles like "Champs d'Environnement" after bold stripping
	var narrative_lines: Array[String] = []
	var header_rx := RegEx.new()
	header_rx.compile("^[\\p{Lu}][\\p{Ll}']+(?:\\s+[\\p{L}']+){0,2}\\s*:?$")
	for nl in text.split("\n"):
		var nt := nl.strip_edges()
		if not nt.is_empty() and nt.length() < 40 and header_rx.search(nt):
			continue
		narrative_lines.append(nl)
	text = "\n".join(narrative_lines)

	# Step 5: Length enforcement — doc spec = 40-60 words, cap text at ~200 chars
	text = text.strip_edges()
	if text.length() > 350:
		var cut_pos := 350
		for sep in [".", "!", "?"]:
			var idx := text.rfind(sep, 350)
			if idx > 120:
				cut_pos = idx + 1
				break
		text = text.substr(0, cut_pos).strip_edges()

	# Step 6: Pronoun enforcement — replace "nous/notre/nos" with "tu/ton/tes"
	var pronoun_fixes := [
		["nos pieds", "tes pieds"], ["nos yeux", "tes yeux"], ["nos mains", "tes mains"],
		["notre chemin", "ton chemin"], ["notre route", "ta route"], ["notre quete", "ta quete"],
		[" nos ", " tes "], [" notre ", " ton "],
		[" nous ", " tu "], ["Nous ", "Tu "],
	]
	for fix in pronoun_fixes:
		text = text.replace(str(fix[0]), str(fix[1]))

	# Pad to 3 labels with phase-aware verb fallbacks if LLM didn't produce enough
	if labels.size() < 3:
		print("[MerlinLlmAdapter] Only %d labels extracted, padding with fallbacks" % labels.size())
		var balance_fb := _evaluate_balance_heuristic(context)
		var b_score_fb: int = int(balance_fb.get("balance_score", 100))
		var pool: Array
		if b_score_fb > 80:
			pool = VERB_POOL_SAFE
		elif b_score_fb >= 30:
			pool = VERB_POOL_FRAGILE
		else:
			pool = VERB_POOL_CRITICAL
		# Collect already-used verbs to avoid duplicates
		var used: Array[String] = []
		for lbl in labels:
			used.append(str(lbl["verb"]).to_upper())
		# Draw from DIFFERENT triplets (shuffled) to maximize variety
		var pool_shuffled: Array = pool.duplicate()
		pool_shuffled.shuffle()
		for triplet in pool_shuffled:
			if labels.size() >= 3:
				break
			for fb_v in triplet:
				if labels.size() >= 3:
					break
				if str(fb_v).to_upper() not in used:
					labels.append({"verb": str(fb_v).to_upper(), "desc": ""})
					used.append(str(fb_v).to_upper())

	# Generate context-appropriate effects (dynamic based on game state)
	var effects := _generate_contextual_effects(context)

	# DC hints: dramatic balance-adaptive difficulty (0ms heuristic)
	var balance := _evaluate_balance_heuristic(context)
	var b_score: int = int(balance.get("balance_score", 100))

	# Component 1: Balance score (global danger level)
	var balance_offset: int = 0
	if b_score < 20:
		balance_offset = -4  # Very easy when in critical danger
	elif b_score < 40:
		balance_offset = -2  # Easy when in danger
	elif b_score > 90:
		balance_offset = 3   # Very hard when too comfortable
	elif b_score > 70:
		balance_offset = 1   # Slightly harder when comfortable

	# Component 2: Aspect-specific modifiers (extremes = easier to help player)
	var aspect_offset: int = 0
	var aspects: Dictionary = context.get("aspects", {})
	var extremes_count: int = 0
	for aspect in TRIADE_ASPECTS:
		if int(aspects.get(aspect, 0)) != 0:
			extremes_count += 1
	if extremes_count >= 3:
		aspect_offset = -3
	elif extremes_count >= 2:
		aspect_offset = -1

	var dc_offset: int = clampi(balance_offset + aspect_offset, -6, 4)
	var dc_hints: Array = [
		{"min": maxi(4 + dc_offset, 2), "max": maxi(8 + dc_offset, 4)},
		{"min": maxi(7 + dc_offset, 4), "max": maxi(12 + dc_offset, 6)},
		{"min": maxi(10 + dc_offset, 6), "max": maxi(16 + dc_offset, 8)},
	]
	var risk_levels: Array[String] = ["faible", "moyen", "eleve"]

	var options_out: Array = []
	for i in range(3):
		var label_data: Dictionary = labels[i]
		var verb_str: String = str(label_data.get("verb", "AGIR"))
		var desc_str: String = str(label_data.get("desc", ""))
		var has_llm_desc: bool = not desc_str.is_empty()
		var opt: Dictionary = {
			"label": verb_str,
			"action_desc": desc_str,
			"verb_source": "llm" if has_llm_desc else "fallback",
			"reward_type": MerlinConstants.infer_reward_type([effects[i]]),
			"effects": [effects[i]],
			"dc_hint": dc_hints[i],
			"risk_level": risk_levels[i],
		}
		if i == 1:
			opt["cost"] = 1
		# Right option bonus: karma reward (also reversed on failure → karma loss)
		if i == 2:
			opt["effects"].append({"type": "ADD_KARMA", "amount": 2})
		# Per-option resolution texts
		opt["result_success"] = _build_result_text(verb_str, verb_str, effects[i], true)
		opt["result_failure"] = _build_result_text(verb_str, verb_str, effects[i], false)
		options_out.append(opt)

	# Jaccard similarity check: avoid repeating the previous card text
	var story_log_check: Array = context.get("story_log", [])
	if text.length() > 15 and story_log_check.size() > 0:
		var prev_text: String = str(story_log_check[-1].get("text", ""))
		if not prev_text.is_empty() and _jaccard_similarity(text, prev_text) > 0.7:
			print("[MerlinLlmAdapter] Jaccard > 0.7 — using narrative fallback")
			text = NARRATIVE_FALLBACKS[randi() % NARRATIVE_FALLBACKS.size()]

	# Cap text length: 3-5 lines max (~250 chars). Always finish the current sentence.
	if text.length() > 250:
		var cut_back := text.rfind(".", 250)
		if cut_back > 80:
			text = text.substr(0, cut_back + 1)
		else:
			var cut_fwd := text.find(".", 250)
			if cut_fwd > 0:
				text = text.substr(0, cut_fwd + 1)

	var final_text: String = text if text.length() > 15 else NARRATIVE_FALLBACKS[randi() % NARRATIVE_FALLBACKS.size()]

	# Detect minigame from narrative text and option verbs
	var all_verbs: Array[String] = []
	for ld in labels:
		all_verbs.append(str(ld.get("verb", "")))
	var minigame: Dictionary = _detect_minigame(final_text, all_verbs)

	var card_out := {
		"text": final_text,
		"speaker": "merlin",
		"options": options_out,
		"tags": ["llm_generated"],
		"result_success": "Merlin acquiesce. Votre choix s'avere judicieux.",
		"result_failure": "Merlin secoue la tete. Les consequences se font sentir...",
		# Visual metadata for PixelSceneCompositor
		"biome": str(context.get("biome", "foret_broceliande")),
		"season": str(context.get("season", "automne")),
		"celtic_theme": str(context.get("_celtic_theme", "")),
		"arc_phase": _get_arc_phase(int(context.get("cards_played", 0))),
		"visual_tags": [],
	}
	if not minigame.is_empty():
		card_out["minigame"] = minigame
	return card_out


## Extract the first verb from a label for resolution text.
func _extract_verb_from_label(label: String) -> String:
	var words := label.strip_edges().split(" ")
	if words.size() > 0:
		return words[0].to_lower()
	return "agir"


## Detect if the narrative text or option verbs suggest a minigame.
## Scans MerlinConstants.MINIGAME_CATALOGUE trigger words against text + verbs.
func _detect_minigame(text: String, verbs: Array[String]) -> Dictionary:
	var combined := text.to_lower()
	for v in verbs:
		combined += " " + v.to_lower()

	var best_id := ""
	var best_hits: int = 0
	for mg_id in MerlinConstants.MINIGAME_CATALOGUE:
		var mg: Dictionary = MerlinConstants.MINIGAME_CATALOGUE[mg_id]
		var trigger_str: String = str(mg.get("trigger", ""))
		var triggers := trigger_str.split("|")
		var hits: int = 0
		for t in triggers:
			if combined.find(t.strip_edges()) >= 0:
				hits += 1
		if hits > best_hits:
			best_hits = hits
			best_id = mg_id

	if best_hits >= 1 and not best_id.is_empty():
		var mg: Dictionary = MerlinConstants.MINIGAME_CATALOGUE[best_id]
		return {"id": best_id, "name": str(mg.get("name", "")), "desc": str(mg.get("desc", ""))}
	return {}


## Build contextual resolution text for success or failure.
func _build_result_text(verb: String, label: String, effect: Dictionary, is_success: bool) -> String:
	var effect_type: String = str(effect.get("type", ""))

	if is_success:
		var success_templates: Array[String] = [
			"Votre decision de %s porte ses fruits." % verb,
			"Vous reussissez a %s avec brio." % verb,
			"%s — un choix qui s'avere payant." % label,
			"Merlin sourit. Votre %s etait le bon choix." % verb,
		]
		var text: String = success_templates[randi() % success_templates.size()]
		if effect_type == "HEAL_LIFE":
			text += " Vous recuperez de la vigueur."
		elif effect_type == "ADD_KARMA":
			text += " L'equilibre karmique penche en votre faveur."
		elif effect_type == "ADD_SOUFFLE":
			text += " Le Souffle d'Ogham vous envahit."
		return text
	else:
		var failure_templates: Array[String] = [
			"Malgre vos efforts, %s echoue." % verb,
			"Le destin en decide autrement — %s ne suffit pas." % verb,
			"%s — les consequences sont immediates." % label,
			"Merlin grimace. Ce n'etait pas le bon moment pour %s." % verb,
		]
		var text: String = failure_templates[randi() % failure_templates.size()]
		if effect_type == "DAMAGE_LIFE":
			text += " La douleur se fait sentir."
		elif effect_type == "HEAL_LIFE":
			text += " L'esperance de guerison s'evanouit."
		return text


## Generate narrative consequences for 3 options via LLM (Narrator brain).
## Returns 3 success-consequence strings (2-3 phrases each).
## Falls back to template-based consequences if LLM unavailable.
func _generate_consequences(card_text: String, options: Array, context: Dictionary) -> Array[String]:
	if not is_llm_ready() or card_text.length() < 20:
		return []

	var labels: Array[String] = []
	for opt in options:
		labels.append(str(opt.get("label", "?")))
	if labels.size() < 3:
		return []

	var balance := _evaluate_balance_heuristic(context)
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
	var result: Dictionary = await _merlin_ai.generate_with_system(system, user, params)
	if result.has("error"):
		return []

	var raw: String = str(result.get("text", ""))
	return _parse_consequences(raw)


## Parse LLM consequence output into 3 strings.
func _parse_consequences(raw: String) -> Array[String]:
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
func _build_failure_from_success(success_text: String) -> String:
	# Simple inversion: add failure prefix, keep sensory language
	var failure_prefixes: Array[String] = [
		"Le geste echoue. ",
		"Le destin se retourne. ",
		"L'effort ne suffit pas. ",
		"La foret refuse. ",
	]
	var prefix: String = failure_prefixes[randi() % failure_prefixes.size()]
	# Take the second sentence from success if available, or truncate
	var sentences := success_text.split(". ")
	if sentences.size() > 1:
		return prefix + sentences[-1].strip_edges()
	return prefix + "Les consequences se font sentir sans merci."


## Extract visual tags from narrative text for scene illustration.
## Uses Game Master brain (T=0.15, max_tokens=40) for fast keyword extraction.
## Fallback: derive tags from biome + card tags if LLM extraction fails.
func _extract_visual_tags(narrative: String, context: Dictionary) -> Array:
	if narrative.is_empty():
		return _derive_fallback_visual_tags(context)

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
	var result: Dictionary = await _merlin_ai.generate_structured(sys, usr, "", params)
	if result.has("error") or not result.has("text"):
		return _derive_fallback_visual_tags(context)

	var raw: String = str(result.get("text", "")).strip_edges()
	if raw.length() < 3:
		return _derive_fallback_visual_tags(context)

	# Parse comma-separated tags, clean whitespace and normalize
	var tags: Array = []
	for part in raw.split(","):
		var clean: String = part.strip_edges().to_lower()
		# Remove non-alphabetic chars, keep accented letters
		clean = clean.replace(".", "").replace(":", "").replace(";", "")
		if clean.length() >= 2 and clean.length() <= 30:
			tags.append(clean)

	if tags.size() < 2:
		return _derive_fallback_visual_tags(context)
	return tags


## Derive visual tags from biome metadata and card tags (100% reliable fallback).
func _derive_fallback_visual_tags(context: Dictionary) -> Array:
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


## Extract choice labels with verb + description from LLM free text output.
## Returns Array[Dictionary] with {verb: "AVANCER", desc: "Tu franchis..."}.
## Handles formats: "A) VERBE — desc", "A) verbe - desc", "A) verbe", etc.
## Pre-split step in _wrap_text_as_card() ensures inline choices are on separate lines.
func _extract_labels_from_text(text: String) -> Array[Dictionary]:
	var labels: Array[Dictionary] = []
	var rx := RegEx.new()

	# Broad pattern covering all known 1.5B output formats (A-D supported):
	# Handles: A) text, 1. text, 1 - A) text, **1 - A** text, 1 - text, - text
	rx.compile("(?m)^\\s*(?:[-*]\\s*)?\\*{0,2}(?:(?:Le\\s+choix\\s+|Action\\s+|Choix\\s+)?[A-D][):.\\]]\\s*:?|[1-4]\\s*[-.]\\s*(?:[A-D][):.\\]]\\s*:?\\s*)?|[1-4][.)]|[-*])\\*{0,2}[:\\s]+(.*)")
	var matches := rx.search_all(text)
	for m in matches:
		var raw_label := m.get_string(1).strip_edges()
		# Strip markdown bold markers
		raw_label = raw_label.replace("**", "").replace("*", "").strip_edges()
		# Accept empty labels (e.g. bare "B)") — they will be rejected by validation below
		if raw_label.length() > 200:
			continue

		# Try to split "VERBE — description" or "VERBE - description" or "VERBE : description"
		var split_data := _split_verb_desc(raw_label)
		# Accept any non-empty verb (trust LLM creativity, no whitelist)
		var v: String = str(split_data.get("verb", "")).strip_edges()
		if not v.is_empty() and v.length() <= 20:
			# Normalize: keep only first word as verb
			var sp := v.find(" ")
			if sp > 0:
				v = v.substr(0, sp)
			# Reject determinants/prepositions (not verbs — indicates paragraph start, not choice)
			var v_upper := v.to_upper()
			if v_upper in ["LE", "LA", "LES", "UN", "UNE", "DES", "AU", "AUX",
					"DU", "DANS", "SUR", "SOUS", "PAR", "POUR", "VERS", "AVEC",
					"CE", "CET", "CETTE", "CES", "MON", "TON", "SON", "IL", "ELLE",
					"EN", "ET", "OU", "DE", "A", "Y", "QUI", "QUE", "DONT",
					# Conjunctions (not verbs — observed: "Puisque" extracted as verb)
					"PUISQUE", "CAR", "MAIS", "DONC", "OR", "NI",
					"QUAND", "LORSQUE", "SI", "COMME", "BIEN",
					"CEPENDANT", "TOUTEFOIS", "NEANMOINS", "ALORS",
					"PUIS", "AUSSI", "SURTOUT", "DEJA", "ENCORE",
					# Demonstratives / misc non-verbs
					"TOUT", "TOUS", "TOUTE", "TOUTES", "RIEN",
					"CHAQUE", "NOTRE", "VOTRE", "LEUR", "LEURS",
					"NOS", "VOS", "MES", "TES", "SES",
					# Non-action verbs / copulas
					"C'EST", "EST", "SONT", "ETRE", "AVOIR", "FAIT", "VA"]:
				print("[MerlinLlmAdapter] Rejected determinant as verb: '%s'" % v)
				continue
			# Reject only the 3 most overused verbs from Qwen 1.5B (cause 30%+ repetition).
			# All other verbs are accepted — LLM creativity over pool conformity.
			# FUIR, SUIVRE, CHERCHER, REGARDER etc. removed: used with enough variety.
			if v_upper in ["AVANCER", "OBSERVER", "CONTINUER"]:
				print("[MerlinLlmAdapter] Rejected overused verb (top-3 Qwen 1.5B): '%s'" % v)
				continue
			labels.append({"verb": v_upper, "desc": str(split_data.get("desc", ""))})
		else:
			print("[MerlinLlmAdapter] Rejected verb (empty or too long): '%s'" % v)

	# Fallback patterns when main regex finds fewer than 3 labels.
	# Handles Qwen 1.5B output formats not covered by the primary pattern.
	if labels.size() < 3:
		var rx_fallback := RegEx.new()
		# Pattern 1: markdown bold headers — **Choix A**: text | **Option 1**: text
		rx_fallback.compile("(?m)^\\s*\\*{1,2}(?:Choix|Option|Action)\\s*[A-D1-4]\\*{0,2}[:\\s]+\\*{0,2}(.*?)\\*{0,2}$")
		for m in rx_fallback.search_all(text):
			if labels.size() >= 3:
				break
			var raw: String = m.get_string(1).strip_edges().replace("**", "").replace("*", "").strip_edges()
			if raw.length() >= 2 and raw.length() <= 200:
				var sd := _split_verb_desc(raw)
				var fv: String = str(sd.get("verb", "")).strip_edges()
				if not fv.is_empty() and fv.length() <= 20:
					labels.append({"verb": fv.to_upper(), "desc": str(sd.get("desc", ""))})
					print("[MerlinLlmAdapter] Fallback bold-header label: '%s'" % fv)
		# Pattern 2: bullet lines — lines starting with - / * / > followed by content
		if labels.size() < 3:
			var rx_bullet := RegEx.new()
			rx_bullet.compile("(?m)^\\s*[-*>]\\s+(\\S[^\\n]{1,198})")
			for m in rx_bullet.search_all(text):
				if labels.size() >= 3:
					break
				var raw: String = m.get_string(1).strip_edges().replace("**", "").replace("*", "").strip_edges()
				if raw.length() >= 2:
					var sd := _split_verb_desc(raw)
					var fv: String = str(sd.get("verb", "")).strip_edges()
					if not fv.is_empty() and fv.length() <= 20:
						labels.append({"verb": fv.to_upper(), "desc": str(sd.get("desc", ""))})
						print("[MerlinLlmAdapter] Fallback bullet label: '%s'" % fv)

	# Limit to 3 labels (game uses 3 choices: Left/Center/Right)
	if labels.size() > 3:
		labels.resize(3)

	return labels


## Split a raw label into verb + description.
## Handles: "AVANCER — Tu franchis...", "Avancer - desc", "Avancer", "avancer"
func _split_verb_desc(raw: String) -> Dictionary:
	# Try em-dash first, then regular dash, then colon
	for sep in [" — ", " – ", " - ", " : "]:
		var idx := raw.find(sep)
		if idx > 0 and idx < raw.length() - 3:
			var verb := raw.substr(0, idx).strip_edges()
			var desc := raw.substr(idx + sep.length()).strip_edges()
			if verb.length() >= 2 and verb.length() <= 30:
				return {"verb": verb.to_upper(), "desc": desc}

	# No separator found — whole string is verb (old format)
	var verb_only := raw.strip_edges()
	# Capitalize if it looks like a single verb (no spaces or short phrase)
	if verb_only.find(" ") < 0 or verb_only.length() < 20:
		return {"verb": verb_only.to_upper(), "desc": ""}
	# Long phrase without separator — use first word as verb
	var first_space := verb_only.find(" ")
	if first_space > 0:
		return {"verb": verb_only.substr(0, first_space).to_upper(), "desc": verb_only.substr(first_space + 1)}
	return {"verb": verb_only.to_upper(), "desc": ""}


## Get flat array of all unique verbs across all pools (SAFE + FRAGILE + CRITICAL).
func _get_all_pool_verbs() -> Array[String]:
	var all_verbs: Array[String] = []
	for pool in [VERB_POOL_SAFE, VERB_POOL_FRAGILE, VERB_POOL_CRITICAL]:
		for triplet in pool:
			for v in triplet:
				var upper_v: String = str(v).to_upper()
				if upper_v not in all_verbs:
					all_verbs.append(upper_v)
	return all_verbs


## Check whether a label verb is in a pre-defined pool (analytics only).
## PRINCIPLE: LLM creativity over pool conformity.
## This function must NOT be used to gate label acceptance.
## Use it only for logging/metrics to track how often LLM stays within pools.
## A label is accepted if its verb passes the blocklist in _extract_labels_from_text().
func _validate_single_verb(label: Dictionary) -> bool:
	var verb: String = str(label.get("verb", "")).strip_edges().to_upper()
	if verb.is_empty():
		return false
	# Take only first word
	var space_idx := verb.find(" ")
	if space_idx > 0:
		verb = verb.substr(0, space_idx)
	var all_verbs := _get_all_pool_verbs()
	var in_pool: bool = verb in all_verbs
	# Analytics log only — never use the return value to reject a label
	if not in_pool:
		print("[MerlinLlmAdapter] Analytics: verb not in pools (creative): '%s'" % verb)
	return in_pool


## Map card position to a scenario arc phase template key.
func _get_arc_phase(cards_played: int) -> String:
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


## Build balance-aware hint for system prompt (0ms, heuristic only).
func _build_balance_hint(context: Dictionary) -> String:
	var balance := _evaluate_balance_heuristic(context)
	var score: int = int(balance.get("balance_score", 100))
	var risk: String = str(balance.get("risk_aspect", "none"))
	if score < 30:
		if risk != "none":
			return "\nURGENCE: Le voyageur est en peril (%s critique). Au moins un choix doit offrir du repos ou de la guerison." % risk
		return "\nURGENCE: Le voyageur est en peril. Un choix doit offrir du repos."
	elif score < 50 and risk != "none":
		return "\nEQUILIBRE FRAGILE: %s en danger. Oriente certains choix vers la stabilite." % risk
	elif score > 80:
		return "\nEQUILIBRE STABLE: Le voyageur est en securite. Augmente les enjeux et les risques."
	return ""


## Build scenario injection block appended to ALL system prompts.
## Ensures scenario context always reaches the LLM regardless of template.
func _build_scenario_injection(context: Dictionary) -> String:
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


## Substitute template variables from context (biome, aspects, scenario, etc.).
func _substitute_template_vars(tpl: String, context: Dictionary, cards_played: int = 0, theme_word: String = "") -> String:
	var aspects: Dictionary = context.get("aspects", {})
	tpl = tpl.replace("{biome}", str(context.get("biome", "foret_broceliande")))
	tpl = tpl.replace("{day}", str(context.get("day", 1)))
	tpl = tpl.replace("{season}", str(context.get("season", "spring")))
	tpl = tpl.replace("{souffle}", str(context.get("souffle", 1)))
	tpl = tpl.replace("{karma}", str(context.get("karma", 0)))
	tpl = tpl.replace("{tension}", str(context.get("tension", 0)))
	tpl = tpl.replace("{life}", str(context.get("life_essence", 100)))
	tpl = tpl.replace("{bestiole_bond}", str(context.get("bestiole_bond", 50)))
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
	# Aspect states
	for aspect in ["Corps", "Ame", "Monde"]:
		var val: int = int(aspects.get(aspect, 0))
		var state_name := "equilibre"
		if val < 0: state_name = "bas"
		elif val > 0: state_name = "haut"
		tpl = tpl.replace("{%s_state}" % aspect.to_lower(), state_name)
	# Arc-specific vars (map to scenario context)
	tpl = tpl.replace("{arc_theme}", str(context.get("scenario_theme", theme_word)))
	tpl = tpl.replace("{arc_name}", str(context.get("scenario_title", "")))
	tpl = tpl.replace("{arc_progress}", str(cards_played))
	tpl = tpl.replace("{duality_a}", "")
	tpl = tpl.replace("{duality_b}", "")
	return tpl


## Build a structured system prompt using scenario templates when available.
func _build_arc_system_prompt(cards_played: int, theme_word: String, context: Dictionary) -> String:
	var arc_phase := _get_arc_phase(cards_played)
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
		sys += _build_balance_hint(context)
		# Append format instructions with ONE-SHOT EXAMPLE (small models follow examples better)
		sys += "\n\nTON: Druide FOU mais BRILLANT. Moque-toi du voyageur. Digressions courtes. Poetique et sensoriel."
		sys += "\nSCENARIO: Decris une SITUATION que le voyageur VIT (danger, decouverte, rencontre, enigme). PAS ce que Merlin fait. Le texte raconte ce qui ARRIVE au voyageur."
		sys += "\nCHOIX: Les 3 options sont les REACTIONS du voyageur a cette situation. Verbes VARIES et SPECIFIQUES (jamais 'avancer', 'observer', 'fuir', 'suivre', 'chercher')."
		sys += "\nREGLES: Utilise TU. Phrases courtes. Pas de 'Voici'. Pas de meta."
		sys += "\n\nFormat EXACT:"
		sys += "\n[situation en 4-5 phrases]"
		sys += "\nA) VERBE — Ce que le voyageur fait concretement en 1 phrase"
		sys += "\nB) VERBE — Action differente en 1 phrase"
		sys += "\nC) VERBE — Action differente en 1 phrase"
		sys += "\n\nExemple:"
		sys += "\nHa! Un dolmen fissure bloque le sentier... la brume... oui. Des runes anciennes pulsent sur la pierre. Quelque chose gratte de l'autre cote, voyageur. Les korrigans chuchotent que c'est un piege... ou un tresor."
		sys += "\nA) ESCALADER — Tu grimpes la paroi moussue, les doigts dans les fissures, et tu decouvres ce qui attend de l'autre cote."
		sys += "\nB) DECHIFFRER — Tu poses les doigts sur les runes et lis leur logique avant que le dolmen ne se referme."
		sys += "\nC) CONTOURNER — Tu longes la roche par le ravin, quitte a perdre du temps et des forces."
		sys += "\nLe verbe en MAJUSCULES suivi de — puis description concrete. PAS de numerotation. PAS de titre. PAS de 'Voici'. PAS de meta. Juste la situation puis A) B) C)."
		# Inject scenario context (always, regardless of template)
		sys += _build_scenario_injection(context)
		return sys

	# Fallback: enriched default prompt
	var biome_name: String = str(context.get("biome", "foret_broceliande")).replace("_", " ").capitalize()
	var life: int = int(context.get("life_essence", 100))
	var souffle: int = int(context.get("souffle", 3))
	var karma: int = int(context.get("karma", 0))

	var convergence_hint := ""
	if cards_played >= 8:
		convergence_hint = "\nLa quete approche de sa fin. Oriente la scene vers une resolution."
	elif cards_played >= 5:
		convergence_hint = "\nLa tension monte. Les enjeux deviennent plus importants."

	# Balance intelligence: adapt narrative tone to player state
	var balance_hint := _build_balance_hint(context)

	return (
		"Tu es Merlin l'Enchanteur, vieux druide FOU de Broceliande. Tu PERDS LA BOULE mais tu decris brillamment. Moque-toi du voyageur ('mon pauvre ami'). Digressions courtes. TU (jamais nous/je/il). Pas de 'Voici'. Pas de meta.\n"
		+ "LIEU: %s | CARTE: %d | THEME: %s\n" % [biome_name, cards_played + 1, theme_word]
		+ "ETAT: Vie=%d/100, Souffle=%d/1, Karma=%d\n" % [life, souffle, karma]
		+ convergence_hint
		+ balance_hint
		+ "\n\nTON: Druide FOU mais BRILLANT. Moque-toi du voyageur. Digressions courtes. Poetique et sensoriel."
		+ "\nSCENARIO: Decris une SITUATION que le voyageur VIT (danger, decouverte, rencontre, enigme). PAS ce que Merlin fait. Le texte raconte ce qui ARRIVE au voyageur."
		+ "\nCHOIX: Les 3 options sont les REACTIONS du voyageur a cette situation. Verbes VARIES et SPECIFIQUES (jamais 'avancer', 'observer', 'fuir', 'suivre', 'chercher')."
		+ "\nREGLES: Utilise TU. Phrases courtes. Pas de 'Voici'. Pas de meta."
		+ "\n\nFormat EXACT:"
		+ "\n[situation en 4-5 phrases]"
		+ "\nA) VERBE — Ce que le voyageur fait concretement en 1 phrase"
		+ "\nB) VERBE — Action differente en 1 phrase"
		+ "\nC) VERBE — Action differente en 1 phrase"
		+ "\n\nExemple:"
		+ "\nHa! Un dolmen fissure bloque le sentier... la brume... oui. Des runes anciennes pulsent sur la pierre. Quelque chose gratte de l'autre cote, voyageur. Les korrigans chuchotent que c'est un piege... ou un tresor."
		+ "\nA) ESCALADER — Tu grimpes la paroi moussue, les doigts dans les fissures, et tu decouvres ce qui attend de l'autre cote."
		+ "\nB) DECHIFFRER — Tu poses les doigts sur les runes et lis leur logique avant que le dolmen ne se referme."
		+ "\nC) CONTOURNER — Tu longes la roche par le ravin, quitte a perdre du temps et des forces."
		+ "\nLe verbe en MAJUSCULES suivi de — puis description concrete. PAS de numerotation. PAS de titre. PAS de 'Voici'. PAS de meta. Juste la situation puis A) B) C)."
		+ _build_scenario_injection(context)
	)


## Build user prompt with game state and arc context.
func _build_arc_user_prompt(cards_played: int, biome: String, theme_word: String, context: Dictionary) -> String:
	var arc_phase := _get_arc_phase(cards_played)
	var tpl := get_scenario_template(arc_phase)

	var base_prompt: String
	# Use scenario template if available — substitute variables directly
	if not tpl.is_empty() and tpl.has("user_template"):
		base_prompt = _substitute_template_vars(str(tpl["user_template"]), context, cards_played, theme_word)
	else:
		# Fallback: concise prompt — small models follow short instructions better
		var balance_ctx := _evaluate_balance_heuristic(context)
		var verbs: Array = _get_phase_verb_pool(int(balance_ctx.get("balance_score", 100)))
		base_prompt = "Carte %d. Biome: %s. Theme: %s.\nDecris une SITUATION que le voyageur vit (danger, enigme, rencontre). Puis A) B) C) = ses REACTIONS a cette situation. Verbes SPECIFIQUES lies a la scene (pas 'avancer'/'observer'/'fuir').\nInspiration verbes: %s, %s, %s." % [
			cards_played + 1, biome, theme_word, str(verbs[0]), str(verbs[1]), str(verbs[2])]

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
	base_prompt += _build_context_enrichment(context)
	return base_prompt


## Build enrichment string from game intelligence (flux, tension, talents, tendency).
func _build_context_enrichment(context: Dictionary) -> String:
	var parts: Array[String] = []

	# Flux (only non-neutral axes)
	var flux_desc: Dictionary = context.get("flux_desc", {})
	var flux_parts: Array[String] = []
	for axis in flux_desc:
		if str(flux_desc[axis]) != "neutre":
			flux_parts.append("%s %s" % [str(axis).capitalize(), str(flux_desc[axis])])
	if not flux_parts.is_empty():
		parts.append("Flux: %s" % ", ".join(flux_parts))

	# Tension
	var tension: int = int(context.get("tension", 0))
	if tension >= 60:
		parts.append("Tension haute")
	elif tension >= 40:
		parts.append("Tension moderee")

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

	if parts.is_empty():
		return ""
	return " " + ". ".join(parts) + "."


## Extract recurring motifs from the story log for narrative callback.
## Returns significant words (>5 chars, not common) seen in 2+ entries.
func _extract_recurring_motifs(story_log: Array) -> Array[String]:
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
func _jaccard_similarity(a: String, b: String) -> float:
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
func _get_phase_verb_pool(balance_score: int) -> Array:
	var pool: Array
	if balance_score > 80:
		pool = VERB_POOL_SAFE
	elif balance_score >= 30:
		pool = VERB_POOL_FRAGILE
	else:
		pool = VERB_POOL_CRITICAL
	return pool[randi() % pool.size()]


## Generate effects that vary based on game state and quest position.
func _generate_contextual_effects(context_or_aspects: Dictionary) -> Array:
	# Accept either full context dict or just aspects dict
	var aspects: Dictionary = context_or_aspects
	var life: int = 100
	var cards_played: int = 0

	if context_or_aspects.has("life_essence"):
		life = int(context_or_aspects.get("life_essence", 100))
		cards_played = int(context_or_aspects.get("cards_played", 0))
		aspects = context_or_aspects.get("aspects", {})
	elif context_or_aspects.has("aspects"):
		aspects = context_or_aspects.get("aspects", {})

	# Balance intelligence: adapt effects to player state (0ms heuristic)
	var balance := _evaluate_balance_heuristic(context_or_aspects)
	var balance_score: int = int(balance.get("balance_score", 100))
	var risk_aspect: String = str(balance.get("risk_aspect", "none"))

	# Scale amounts based on quest position
	var base_amount: int = 3 + mini(cards_played / 2, 5)  # 3 early, up to 8 late

	var effects: Array = []

	# RISK-REWARD SCALING: All options use positive effects (HEAL_LIFE).
	# _modulate_effects reverses them on failure → bigger effect = bigger risk AND bigger reward.
	# Left=prudent (small), Center=equilibre (medium), Right=audacieux (big).

	# Option 1 (left): Prudent — low risk, low reward
	var left_amount: int = base_amount
	if life < 40 or balance_score < 30:
		left_amount = base_amount + 2  # Critical state: safer choice heals more
	effects.append({"type": "HEAL_LIFE", "amount": left_amount})

	# Option 2 (center): Balanced — medium risk, medium reward (costs Souffle)
	var center_amount: int = base_amount + 2
	if balance_score > 80:
		center_amount = base_amount + 3  # Comfortable: higher stakes
	effects.append({"type": "HEAL_LIFE", "amount": center_amount})

	# Option 3 (right): Audacious — high risk, high reward
	var right_amount: int = base_amount + 4
	if cards_played >= 8:
		right_amount = base_amount + 6  # Late game: even bigger stakes
	elif balance_score < 30:
		right_amount = base_amount + 3  # In danger: slightly reduced stakes
	effects.append({"type": "HEAL_LIFE", "amount": right_amount})

	# Late game: add PROGRESS_MISSION to right option for convergence
	if cards_played >= 10:
		effects[2] = {"type": "PROGRESS_MISSION", "step": 1}

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

	var souffle: int = int(context.get("souffle", 1))
	var score: int = 100 - (extremes * 25) - (max(0, 1 - souffle) * 10)
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


## Generate smart effects using Game Master — context-aware, balance-informed.
## Returns Array of 3 Arrays: [[effects_left], [effects_center], [effects_right]]
## Returns empty Array on failure (caller should use heuristic effects).
func calculate_smart_effects(context: Dictionary, scenario_text: String, labels: Array[String]) -> Array:
	if not is_llm_ready() or _merlin_ai == null or not _merlin_ai.has_method("generate_structured"):
		return []

	# Build GM prompt with balance awareness (no GBNF — Ollama-compatible)
	var balance := _evaluate_balance_heuristic(context)
	var score: int = int(balance.get("balance_score", 100))
	var risk: String = str(balance.get("risk_aspect", "none"))
	var life: int = int(context.get("life_essence", 100))
	var souffle: int = int(context.get("souffle", 1))

	var system := "Maitre du Jeu. Reponds UNIQUEMENT en JSON, rien d'autre.\n"
	system += "Effets: DAMAGE_LIFE, HEAL_LIFE, ADD_KARMA, ADD_SOUFFLE.\n"
	system += "Format exact: {\"effects\":[[{\"type\":\"X\",\"amount\":N}],[{\"type\":\"Y\",\"amount\":M}],[{\"type\":\"Z\",\"amount\":P}]]}\n"
	system += "3 tableaux = 3 choix. 1 effet par choix. amount entre 1 et 8."

	var balance_hint := ""
	if score < 30:
		balance_hint = " URGENCE: Vie=%d. Choix 1 DOIT etre HEAL_LIFE." % life
	elif score < 50 and risk != "none":
		balance_hint = " %s en danger. Favorise guerison." % risk
	elif score > 80:
		balance_hint = " Joueur stable. Plus de risques."

	var user_input := "Scene: %s\nChoix: %s\nVie=%d Souffle=%d%s" % [
		scenario_text.substr(0, 120),
		", ".join(labels),
		life, souffle, balance_hint
	]

	# GM brain, low temp, no grammar (Ollama-compatible)
	var gm_params := {"max_tokens": 80, "temperature": 0.15}
	var result: Dictionary = await _merlin_ai.generate_structured(system, user_input, "", gm_params)

	if result.has("text"):
		var parsed_effects := _parse_smart_effects_json(str(result.text))
		if parsed_effects.size() == 3:
			print("[LLM-Adapter] Smart effects from GM: %s" % str(parsed_effects))
			return parsed_effects

	print("[LLM-Adapter] Smart effects: GM failed, caller will use heuristic")
	return []


## Parse Game Master effects JSON with repair logic.
## Returns Array of 3 Arrays on success, empty Array on failure.
func _parse_smart_effects_json(raw: String) -> Array:
	var json_start := raw.find("{")
	var json_end := raw.rfind("}")
	if json_start < 0 or json_end <= json_start:
		return []

	var json_str := raw.substr(json_start, json_end - json_start + 1)
	var parsed = JSON.parse_string(json_str)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("effects"):
		return []

	var effects_raw = parsed["effects"]
	if not effects_raw is Array or effects_raw.size() != 3:
		return []

	var valid_types := ["DAMAGE_LIFE", "HEAL_LIFE", "ADD_KARMA", "ADD_SOUFFLE"]
	var result: Array = []
	for option_effects in effects_raw:
		if not option_effects is Array:
			return []
		var validated: Array = []
		for eff in option_effects:
			if eff is Dictionary and eff.has("type") and eff.has("amount"):
				var eff_type: String = str(eff["type"])
				var eff_amount: int = clampi(int(eff["amount"]), 1, 10)
				if eff_type in valid_types:
					validated.append({"type": eff_type, "amount": eff_amount})
		if validated.is_empty():
			validated.append({"type": "HEAL_LIFE", "amount": 3})
		result.append(validated)

	return result


# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE SYSTEM PROMPT — Compact for Qwen 2.5-3B-Instruct
# ═══════════════════════════════════════════════════════════════════════════════

func _build_triade_system_prompt() -> String:
	return "Merlin druide. 1 carte JSON: texte court (2-3 phrases), 3 options (1 verbe). Ton celtique.\n{\"text\":\"...\",\"speaker\":\"merlin\",\"options\":[{\"label\":\"...\",\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Corps\",\"direction\":\"up\"}]},{\"label\":\"...\",\"cost\":1,\"effects\":[]},{\"label\":\"...\",\"effects\":[{\"type\":\"SHIFT_ASPECT\",\"aspect\":\"Monde\",\"direction\":\"down\"}]}],\"tags\":[\"tag\"]}"


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
		var prev_text: String = str(last_entry.get("text", "")).substr(0, 50)
		if prev_text.length() > 0:
			prompt += " Precedent: %s." % prev_text

	# JSON template moved to system prompt (Phase 0C: saves ~93 tokens/gen)
	return prompt


# ═══════════════════════════════════════════════════════════════════════════════
# TRIADE CONTEXT BUILDING — From game state to LLM context
# ═══════════════════════════════════════════════════════════════════════════════

## Build TRIADE context from full game state.
func build_triade_context(state: Dictionary) -> Dictionary:
	var run: Dictionary = state.get("run", {})
	var bestiole: Dictionary = state.get("bestiole", {})
	var hidden: Dictionary = run.get("hidden", {})
	var meta: Dictionary = state.get("meta", {})

	# Flux qualitative descriptions
	var flux: Dictionary = run.get("flux", {})
	var flux_desc: Dictionary = {}
	for axis in ["terre", "esprit", "lien"]:
		var val: int = int(flux.get(axis, 50))
		if val >= 70:
			flux_desc[axis] = "fort"
		elif val <= 30:
			flux_desc[axis] = "faible"
		else:
			flux_desc[axis] = "neutre"

	# Active talent names (max 5 for prompt brevity)
	var talent_names: Array[String] = []
	var unlocked: Array = meta.get("talent_tree", {}).get("unlocked", [])
	for tid in unlocked:
		if talent_names.size() >= 5:
			break
		var tdata: Dictionary = MerlinConstants.TALENT_NODES.get(str(tid), {})
		if not tdata.is_empty():
			talent_names.append(str(tdata.get("name", tid)))
		else:
			talent_names.append(str(tid))

	# Player tendency
	var player_tendency := _get_player_tendency(hidden)

	return {
		"aspects": run.get("aspects", {}).duplicate(),
		"souffle": int(run.get("souffle", MerlinConstants.SOUFFLE_START)),
		"cards_played": int(run.get("cards_played", 0)),
		"day": int(run.get("day", 1)),
		"active_tags": run.get("active_tags", []),
		"active_promises": run.get("active_promises", []),
		"story_log": _get_recent_story_log(run.get("story_log", []), 2),
		"biome": str(run.get("current_biome", "foret_broceliande")),
		"life_essence": int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START)),
		"karma": int(hidden.get("karma", 0)),
		"tension": int(hidden.get("tension", 0)),
		"flux_desc": flux_desc,
		"talent_names": talent_names,
		"player_tendency": player_tendency,
		"bestiole": {
			"mood": _get_bestiole_mood(bestiole),
			"bond": int(bestiole.get("bond", 50)),
		},
		"flags": state.get("flags", {}),
	}


func _get_player_tendency(hidden: Dictionary) -> String:
	var profile: Dictionary = hidden.get("player_profile", {})
	var audace: int = int(profile.get("audace", 0))
	var prudence: int = int(profile.get("prudence", 0))
	if audace > prudence + 3:
		return "agressif"
	elif prudence > audace + 3:
		return "prudent"
	return "neutre"


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

	# Preserve gameplay keys set by _wrap_text_as_card and Stage 3
	for key in ["dc_hint", "risk_level", "reward_type", "result_success", "result_failure", "action_desc", "verb_source"]:
		if option.has(key):
			sanitized[key] = option[key]

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
# LEGACY — Context building (kept for backward compatibility)
# ═══════════════════════════════════════════════════════════════════════════════

func build_context(state: Dictionary) -> Dictionary:
	var run = state.get("run", {})
	var bestiole = state.get("bestiole", {})
	var gauges = run.get("gauges", {})

	var critical_gauges := []
	for gauge_name in VALID_GAUGES:
		var value = int(gauges.get(gauge_name, 50))
		# Legacy gauge thresholds (deprecated — inline defaults)
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
		"story_log": _get_recent_story_log(run.get("story_log", []), 2),
		"active_tags": run.get("active_tags", []),
		"current_arc": run.get("current_arc", ""),
		"flags": state.get("flags", {}),
	}


func _get_recent_story_log(story_log: Array, count: int) -> Array:
	if story_log.size() <= count:
		return story_log.duplicate()
	return story_log.slice(story_log.size() - count, story_log.size())


# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY — Card validation
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
# SYSTEM PROMPT — Legacy (kept for backward compat)
# ═══════════════════════════════════════════════════════════════════════════════

func get_system_prompt() -> String:
	return """Tu es Merlin, l'IA qui dirige le monde du jeu DRU.
Tu generes des cartes narratives pour le joueur.

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
