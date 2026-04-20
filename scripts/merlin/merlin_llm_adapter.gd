## Merlin LLM Adapter — Card Contract (Faction-based)
## v3.3.0 — Delegates to: JsonRepair, Prompts, TextSanitizer, Validation, GameMaster

extends RefCounted
class_name MerlinLlmAdapter

const VERSION := "3.3.0"

# --- CONSTANTS ---

const ALLOWED_EFFECT_TYPES := [
	"ADD_REPUTATION", "PROGRESS_MISSION", "ADD_KARMA", "ADD_TENSION",
	"ADD_NARRATIVE_DEBT", "DAMAGE_LIFE", "HEAL_LIFE", "SET_FLAG",
	"ADD_TAG", "REMOVE_TAG", "TRIGGER_EVENT", "CREATE_PROMISE",
	"FULFILL_PROMISE", "BREAK_PROMISE", "ADD_ANAM", "ADD_BIOME_CURRENCY",
	"UNLOCK_OGHAM",
]

const FACTIONS := ["druides", "anciens", "korrigans", "niamh", "ankou"]

const LLM_PARAMS := {
	"max_tokens": 180,
	"temperature": 0.65,
	"top_p": 0.88,
	"top_k": 35,
	"repetition_penalty": 1.4,
}

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

const GENERIC_LABELS: Array = ["Agir", "Observer", "Continuer"]

const VERB_POOL_SAFE: Array = [
	["Escalader", "Dechiffrer", "Contourner"],
	["Plonger", "Cueillir", "Provoquer"],
	["Traverser", "Invoquer", "Deraciner"],
	["Soulever", "Gouter", "Enjamber"],
	["Creuser", "Siffler", "Toucher"],
	["Nager", "Graver", "Arracher"],
	["Grimper", "Renifler", "Briser"],
]
const VERB_POOL_FRAGILE: Array = [
	["Panser", "Negocier", "Braver"],
	["Enraciner", "Dechiffrer", "Frapper"],
	["Trancher", "Pardonner", "Defier"],
	["Barricader", "Calmer", "Provoquer"],
	["Secourir", "Marchander", "Forcer"],
	["Desarmer", "Reciter", "Pieger"],
	["Bloquer", "Apaiser", "Bousculer"],
]
const VERB_POOL_CRITICAL: Array = [
	["Cautériser", "Ramper", "Sacrifier"],
	["Reparer", "Ancrer", "Amputer"],
	["Consolider", "Implorer", "Resister"],
	["Harmoniser", "Absorber", "Abandonner"],
	["Guerir", "Sceller", "Bruler"],
	["Recoudre", "Supplier", "Trancher"],
]

const NARRATIVE_FALLBACKS: Array[String] = [
	"La brume s'epaissit entre les chenes centenaires. Un murmure ancien resonne depuis les pierres moussues.",
	"Un sentier oublie s'ouvre devant toi, borde de fougeres argentees. L'air vibre d'une magie ancienne.",
	"Les pierres dressees bourdonnent d'une energie invisible. Le vent porte l'echo d'un chant druidique.",
	"Une clairiere baignee de lumiere doree apparait. Au centre, un cercle de champignons luminescents pulse doucement.",
	"Le cri d'un corbeau dechire le silence. Entre les branches, une silhouette spectrale t'observe.",
	"Les racines du vieux chene forment un passage vers les profondeurs. Une lueur bleutee en emerge.",
	"Un ruisseau chante entre les rochers couverts de runes. Ses eaux semblent reflechir un ciel different.",
	"Le brouillard se leve, revelant un dolmen que personne n'a vu depuis des siecles.",
]

const SCENARIO_PROMPTS_PATH := "res://data/ai/config/scenario_prompts.json"

const REQUIRED_CARD_KEYS := ["text", "options"]
const REQUIRED_OPTION_KEYS := ["direction", "label", "effects"]
const VALID_DIRECTIONS := ["left", "right"]

# Legacy constants (deprecated)
const LEGACY_REQUIRED_KEYS := ["scene_id", "biome", "backdrop", "text_pages", "choices"]
const LEGACY_VERBS := ["FORCE", "LOGIQUE", "FINESSE"]

# --- MODULE INSTANCES ---

var _json_repair: LlmAdapterJsonRepair = LlmAdapterJsonRepair.new()
var _prompts: LlmAdapterPrompts = LlmAdapterPrompts.new()
var _sanitizer: LlmAdapterTextSanitizer = LlmAdapterTextSanitizer.new()
var _validator: LlmAdapterValidation = LlmAdapterValidation.new()
var _game_master: LlmAdapterGameMaster = LlmAdapterGameMaster.new()

# --- STATE ---

var _merlin_ai: Node = null
var _last_narrative_fallback_idx: int = -1

# --- SETUP ---

## Connect to MerlinAI autoload for LLM inference.
func set_merlin_ai(ai_node: Node) -> void:
	if ai_node == null:
		push_warning("[MerlinLlmAdapter] set_merlin_ai called with null node")
		return
	_merlin_ai = ai_node
	print("[MerlinLlmAdapter] MerlinAI wired (ready=%s)" % str(_merlin_ai.is_ready))
	_load_scenario_prompts()

## Load scenario prompt templates for per-category LLM generation.
func _load_scenario_prompts() -> void:
	if not FileAccess.file_exists(SCENARIO_PROMPTS_PATH):
		_prompts._scenario_prompts_loaded = false
		print("[MerlinLlmAdapter] No scenario prompts found at %s" % SCENARIO_PROMPTS_PATH)
		return

	var file := FileAccess.open(SCENARIO_PROMPTS_PATH, FileAccess.READ)
	if not file:
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()

	if data is Dictionary:
		_prompts._scenario_prompts = data
		_prompts._scenario_prompts_loaded = true
		var count := _prompts._scenario_prompts.size() - (1 if _prompts._scenario_prompts.has("_meta") else 0)
		print("[MerlinLlmAdapter] Loaded %d scenario prompt templates" % count)

## Check if the LLM is available and ready.
func is_llm_ready() -> bool:
	return _merlin_ai != null and _merlin_ai.is_ready

# --- PUBLIC API — Prompt templates (delegates to _prompts)
# ═══════════════════════════════════════════════════════════════════════════════

func get_scenario_template(event_key: String) -> Dictionary:
	return _prompts.get_scenario_template(event_key)

func build_category_system_prompt(event_category: String) -> String:
	var template_key := "event_" + event_category
	var template := get_scenario_template(template_key)
	if template.is_empty():
		return _prompts.build_narrative_system_prompt()
	return str(template.get("system", _prompts.build_narrative_system_prompt()))

func build_category_user_prompt(event_category: String, context: Dictionary) -> String:
	var template_key := "event_" + event_category
	var template := get_scenario_template(template_key)
	if template.is_empty():
		return _prompts.build_narrative_user_prompt(context)
	var user_tpl: String = str(template.get("user_template", ""))
	if user_tpl.is_empty():
		return _prompts.build_narrative_user_prompt(context)
	return _prompts.substitute_template_vars(user_tpl, context)

func get_category_llm_params(event_category: String) -> Dictionary:
	var template_key := "event_" + event_category
	var template := get_scenario_template(template_key)
	if template.is_empty():
		return LLM_PARAMS.duplicate()

	var params := LLM_PARAMS.duplicate()
	if template.has("temperature"):
		params["temperature"] = float(template["temperature"])
	if template.has("max_tokens"):
		params["max_tokens"] = int(template["max_tokens"])
	return params

# --- PUBLIC API — Card Generation
# ═══════════════════════════════════════════════════════════════════════════════

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
		+ "Vocabulaire celtique: nemeton, rune, brume, menhir, korrigan. "
		+ "Ton grave et poetique, comme un conteur au coin du feu. "
		+ "JAMAIS de meta-commentaire. JAMAIS d'anglais."
	)
	var faction_str: String = str(context.get("faction_status", ""))
	var user := "Biome: %s. Etat: Vie=%d/100." % [biome, int(context.get("life_essence", 100))]
	if not faction_str.is_empty():
		user += " %s." % faction_str
	user += " Ecris le prologue."
	if not scenario_title.is_empty():
		user += " Quete: %s." % scenario_title

	var params := {"max_tokens": 400, "temperature": 0.75, "top_p": 0.92, "top_k": 40, "repetition_penalty": 1.3}
	var result: Dictionary = await _merlin_ai.generate_with_system(system, user, params)
	if result.has("error"):
		return {"ok": false, "text": "", "error": str(result.error)}
	var text: String = str(result.get("text", "")).strip_edges()
	text = text.replace("**", "").replace("*", "")
	return {"ok": true, "text": text}


func generate_epilogue(context: Dictionary, story_log: Array) -> Dictionary:
	if not is_llm_ready():
		return {"ok": false, "text": "", "error": "LLM not ready"}

	var b_score: int = int(_game_master.evaluate_balance_heuristic(context).get("balance_score", 100))
	var cards: int = int(context.get("cards_played", 0))
	var life: int = int(context.get("life_essence", 100))

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
		+ "1) Ce que le voyageur a appris de sa quete (lecon liee aux factions et allegiances). "
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

	print("[MerlinLlmAdapter] generate_card: using two-stage (free text + wrap)")
	var two_stage_result := await _generate_card_two_stage(context)
	if two_stage_result["ok"]:
		return two_stage_result

	return {"ok": false, "card": {}, "error": "Two-stage generation failed"}

# ═══════════════════════════════════════════════════════════════════════════════
# TWO-STAGE GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

func _generate_card_two_stage(context: Dictionary) -> Dictionary:
	if not is_llm_ready():
		return {"ok": false, "card": {}, "error": "LLM not ready"}

	# Stage 1: Free text generation with rich context
	var cards_played: int = int(context.get("cards_played", 0))
	var biome: String = str(context.get("biome", "foret_broceliande"))
	var theme_hash: int = (str(cards_played) + biome).hash() % CELTIC_THEMES.size()
	if theme_hash < 0:
		theme_hash = -theme_hash % CELTIC_THEMES.size()
	var theme_idx: int = theme_hash
	var theme_word: String = CELTIC_THEMES[theme_idx]
	var karma: int = int(context.get("karma", 0))

	context["_celtic_theme"] = theme_word

	var balance_callable := Callable(_game_master, "evaluate_balance_heuristic")
	var system_prompt := _prompts.build_arc_system_prompt(cards_played, theme_word, context, balance_callable)
	var user_prompt := _prompts.build_arc_user_prompt(cards_played, biome, theme_word, context, balance_callable)

	# Include RAG context if available
	var rag_ctx := ""
	if _merlin_ai and _merlin_ai.get("rag_manager"):
		var rag_mgr = _merlin_ai.rag_manager
		if rag_mgr and rag_mgr.has_method("get_prioritized_context"):
			rag_ctx = rag_mgr.get_prioritized_context(context, "narrator")
	if not rag_ctx.is_empty():
		user_prompt += " Contexte: %s." % rag_ctx

	# Include story log for narrative continuity
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
		var motifs: Array[String] = _prompts.extract_recurring_motifs(story_log)
		if not motifs.is_empty():
			user_prompt += "MOTIFS RECURRENTS (reutilise-les subtilement): %s.\n" % ", ".join(motifs)

	# Karma-driven narrative influence
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
		else:
			karma_tone = "TENDU et MEFIANT"
			karma_hint = "Atmosphere oppressante. Options mefiantes et agressives."
		if not karma_tone.is_empty():
			user_prompt += "\nKARMA=%d: Ton %s. %s" % [karma, karma_tone, karma_hint]

	var free_params := LLM_PARAMS.duplicate()
	free_params.erase("grammar")
	free_params["max_tokens"] = 400
	free_params["temperature"] = 0.72

	var arc_phase := _prompts.get_arc_phase(cards_played)
	var tpl := _prompts.get_scenario_template(arc_phase)
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
	var card := await _wrap_text_as_card(raw_text, context)

	# Stage 2.5: Smart effects from Game Master (dual brain only)
	var has_dual: bool = _merlin_ai != null and _merlin_ai.brain_count >= 2
	if has_dual:
		var sm_labels: Array[String] = []
		for opt in card.get("options", []):
			sm_labels.append(str(opt.get("label", "?")))
		var smart: Array = await _game_master.calculate_smart_effects(context, raw_text, sm_labels, _merlin_ai)
		if smart.size() == 3:
			var options: Array = card.get("options", [])
			for i in range(mini(3, options.size())):
				if i < smart.size():
					var orig_effects: Array = options[i].get("effects", [])
					var rep_effects: Array = []
					for orig_e in orig_effects:
						if orig_e is Dictionary and str(orig_e.get("type", "")) == "ADD_REPUTATION":
							rep_effects.append(orig_e)
					options[i]["effects"] = rep_effects + smart[i]
					options[i]["reward_type"] = MerlinConstants.infer_reward_type(options[i]["effects"])
			if not card.has("tags"):
				card["tags"] = []
			card["tags"].append("smart_effects")

	# Stage 2.6: Extract visual tags
	context["_card_tags"] = card.get("tags", [])
	if has_dual:
		var vtags := await _game_master.extract_visual_tags(str(card.get("text", "")), context, _merlin_ai)
		card["visual_tags"] = vtags
	else:
		card["visual_tags"] = _game_master.derive_fallback_visual_tags(context)

	# Stage 3: Generate narrative consequences
	var card_text: String = str(card.get("text", ""))
	var card_options: Array = card.get("options", [])
	var consequences: Array[String] = await _game_master.generate_consequences(
		card_text, card_options, context, _merlin_ai)
	if consequences.size() == 3:
		for ci in range(mini(3, card_options.size())):
			card_options[ci]["result_success"] = consequences[ci]
			card_options[ci]["result_failure"] = _game_master.build_failure_from_success(consequences[ci])
		if not card.has("tags"):
			card["tags"] = []
		card["tags"].append("llm_consequences")

	var validated := validate_faction_card(card)
	if not validated["ok"]:
		return {"ok": false, "card": {}, "error": "Two-stage validation: " + ", ".join(validated["errors"])}

	validated["card"]["tags"].append("two_stage")
	validated["card"]["_generated_by"] = "merlin_llm_adapter_two_stage"
	return {"ok": true, "card": validated["card"]}


## Wrap free text into a valid narrative card JSON.
func _wrap_text_as_card(raw_text: String, context: Dictionary) -> Dictionary:
	# Sanitize text through pipeline
	var text := _sanitizer.strip_meta_and_leakage(raw_text)

	# Extract labels from CLEANED text (prompt instructions already stripped)
	var labels: Array[Dictionary] = _sanitizer.extract_labels_from_text(text)

	# Remove ALL choice/option lines from the narrative text
	text = _sanitizer.strip_choice_lines(text)

	# Strip scenario echo from first 2 lines
	text = _sanitizer.strip_scenario_echo(text)

	# Strip markdown artifacts
	text = _sanitizer.strip_markdown(text)

	# Length enforcement
	text = _sanitizer.enforce_length(text)

	# Pronoun enforcement
	text = _sanitizer.enforce_pronouns(text)

	# REPAIR: If < 2 labels extracted, try a short focused LLM call for verb options
	if labels.size() < 2 and _merlin_ai and text.length() >= 20:
		print("[MerlinLlmAdapter] %d labels — attempting repair call for verbs..." % labels.size())
		var situation_excerpt: String = text.substr(0, 100).replace("\n", " ")
		var repair_prompt := "Un loup hurle.\n1) Fuir\n2) Combattre\n3) Observer\n\nLe vent souffle.\n1) Resister\n2) S'abriter\n3) Avancer\n\n%s\n1)" % situation_excerpt
		var repair_params := {"max_tokens": 20, "temperature": 0.2, "top_p": 0.80, "repeat_penalty": 1.5}
		var repair_result: Dictionary = await _merlin_ai.generate_with_system(
			"3 verbes infinitifs. Rien d'autre.", repair_prompt, repair_params
		)
		if not repair_result.has("error"):
			var repair_text: String = str(repair_result.get("text", ""))
			print("[MerlinLlmAdapter] Repair raw: '%s'" % repair_text.substr(0, 200))
			if repair_text.length() >= 3:
				var repair_labels: Array[Dictionary] = _sanitizer.extract_labels_from_text(repair_text)
				if repair_labels.size() < 2:
					repair_labels = _sanitizer.extract_verbs_relaxed(repair_text)
				var existing_verbs: Array[String] = []
				for lbl in labels:
					existing_verbs.append(str(lbl["verb"]))
				for rl in repair_labels:
					if labels.size() >= 3:
						break
					if str(rl["verb"]) not in existing_verbs:
						labels.append(rl)
						existing_verbs.append(str(rl["verb"]))
				print("[MerlinLlmAdapter] After repair: %d labels total" % labels.size())
		else:
			print("[MerlinLlmAdapter] Repair call failed: %s" % str(repair_result.get("error", "")))

	# Pad to 3 labels with phase-aware verb fallbacks
	if labels.size() < 3:
		print("[MerlinLlmAdapter] Only %d labels extracted, padding with fallbacks" % labels.size())
		var balance_fb := _game_master.evaluate_balance_heuristic(context)
		var b_score_fb: int = int(balance_fb.get("balance_score", 100))
		var pool: Array
		if b_score_fb > 80:
			pool = VERB_POOL_SAFE
		elif b_score_fb >= 30:
			pool = VERB_POOL_FRAGILE
		else:
			pool = VERB_POOL_CRITICAL
		var used: Array[String] = []
		for lbl in labels:
			used.append(str(lbl["verb"]).to_upper())
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

	# Generate context-appropriate effects
	var effects := _game_master.generate_contextual_effects(context)

	# DC hints: dramatic balance-adaptive difficulty
	var balance := _game_master.evaluate_balance_heuristic(context)
	var b_score: int = int(balance.get("balance_score", 100))

	var balance_offset: int = 0
	if b_score < 20:
		balance_offset = -4
	elif b_score < 40:
		balance_offset = -2
	elif b_score > 90:
		balance_offset = 3
	elif b_score > 70:
		balance_offset = 1

	var faction_offset: int = 0
	var factions: Dictionary = context.get("factions", {})
	var extremes_count: int = 0
	for faction in FACTIONS:
		var rep: float = float(factions.get(faction, 50.0))
		if rep < 20.0 or rep > 80.0:
			extremes_count += 1
	if extremes_count >= 3:
		faction_offset = -3
	elif extremes_count >= 2:
		faction_offset = -1

	var dc_offset: int = clampi(balance_offset + faction_offset, -6, 4)
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
		var v_check: String = verb_str.replace(")", "").replace("(", "").strip_edges()
		if v_check.length() < 3 or v_check.to_upper() in ["LA", "LE", "LES", "UN", "UNE", "DES", "VOTRE", "NOTRE"]:
			var fb_pool: Array = _prompts.get_phase_verb_pool(b_score)
			verb_str = str(fb_pool[clampi(i, 0, fb_pool.size() - 1)])
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
		if i == 2:
			opt["effects"].append({"type": "ADD_KARMA", "amount": 2})
		opt["result_success"] = _sanitizer.build_result_text(verb_str, verb_str, effects[i], true)
		opt["result_failure"] = _sanitizer.build_result_text(verb_str, verb_str, effects[i], false)
		options_out.append(opt)

	# Jaccard similarity check
	var story_log_check: Array = context.get("story_log", [])
	if text.length() > 15 and story_log_check.size() > 0:
		var prev_text: String = str(story_log_check[-1].get("text", ""))
		if not prev_text.is_empty() and _prompts.jaccard_similarity(text, prev_text) > 0.7:
			print("[MerlinLlmAdapter] Jaccard > 0.7 — using narrative fallback")
			var fb_hash: int = text.hash() % NARRATIVE_FALLBACKS.size()
			if fb_hash < 0:
				fb_hash = -fb_hash % NARRATIVE_FALLBACKS.size()
			var fb_idx: int = fb_hash
			if NARRATIVE_FALLBACKS.size() > 1 and fb_idx == _last_narrative_fallback_idx:
				fb_idx = (fb_idx + 1) % NARRATIVE_FALLBACKS.size()
			_last_narrative_fallback_idx = fb_idx
			text = NARRATIVE_FALLBACKS[fb_idx]

	# Cap text length
	if text.length() > 250:
		var cut_back := text.rfind(".", 250)
		if cut_back > 80:
			text = text.substr(0, cut_back + 1)
		else:
			var cut_fwd := text.find(".", 250)
			if cut_fwd > 0:
				text = text.substr(0, cut_fwd + 1)

	var final_text: String = text
	if text.length() <= 15:
		var fb_hash2: int = final_text.hash() % NARRATIVE_FALLBACKS.size()
		if fb_hash2 < 0:
			fb_hash2 = -fb_hash2 % NARRATIVE_FALLBACKS.size()
		var fb_idx2: int = fb_hash2
		if NARRATIVE_FALLBACKS.size() > 1 and fb_idx2 == _last_narrative_fallback_idx:
			fb_idx2 = (fb_idx2 + 1) % NARRATIVE_FALLBACKS.size()
		_last_narrative_fallback_idx = fb_idx2
		final_text = NARRATIVE_FALLBACKS[fb_idx2]

	# Path B auto-tag: scan final_text for faction keywords (max 1 ADD_REPUTATION per card)
	# Guard: never push effects array beyond 3 items — _validate_card rejects cards with >3 effects
	var scan_text: String = final_text.to_lower()
	var faction_tagged: bool = false
	for faction_id in MerlinConstants.FACTION_KEYWORDS:
		if faction_tagged:
			break
		var keywords: Array = MerlinConstants.FACTION_KEYWORDS[faction_id]
		for kw in keywords:
			if scan_text.find(str(kw)) >= 0:
				if options_out[2]["effects"].size() < 3:
					options_out[2]["effects"].append({
						"type": "ADD_REPUTATION",
						"faction": faction_id,
						"amount": MerlinConstants.FACTION_DELTA_MINOR,
					})
				faction_tagged = true
				break

	# Detect minigame from narrative text and option verbs
	var all_verbs: Array[String] = []
	for ld in labels:
		all_verbs.append(str(ld.get("verb", "")))
	var minigame: Dictionary = _sanitizer.detect_minigame(final_text, all_verbs)

	var card_out := {
		"text": final_text,
		"speaker": "merlin",
		"options": options_out,
		"tags": ["llm_generated"],
		"result_success": "Merlin acquiesce. Votre choix s'avere judicieux.",
		"result_failure": "Merlin secoue la tete. Les consequences se font sentir...",
		"biome": str(context.get("biome", "foret_broceliande")),
		"season": str(context.get("season", "automne")),
		"celtic_theme": str(context.get("_celtic_theme", "")),
		"arc_phase": _prompts.get_arc_phase(int(context.get("cards_played", 0))),
		"visual_tags": [],
	}
	if not minigame.is_empty():
		card_out["minigame"] = minigame
	return card_out

# --- PUBLIC API — Game Master (delegates to _game_master)
# ═══════════════════════════════════════════════════════════════════════════════

func evaluate_balance(context: Dictionary) -> Dictionary:
	return await _game_master.evaluate_balance(context, _merlin_ai)

func suggest_rule_change(context: Dictionary, player_tendency: String = "neutral") -> Dictionary:
	return await _game_master.suggest_rule_change(context, player_tendency, _merlin_ai)

func calculate_smart_effects(context: Dictionary, scenario_text: String, labels: Array[String]) -> Array:
	return await _game_master.calculate_smart_effects(context, scenario_text, labels, _merlin_ai)

# --- PUBLIC API — Validation (delegates to _validator)
# ═══════════════════════════════════════════════════════════════════════════════

func validate_faction_card(card: Dictionary) -> Dictionary:
	return _validator.validate_faction_card(card, ALLOWED_EFFECT_TYPES, FACTIONS)

func validate_card(card: Dictionary, effect_engine: MerlinEffectEngine = null) -> Dictionary:
	return _validator.validate_card(card, effect_engine, REQUIRED_CARD_KEYS, REQUIRED_OPTION_KEYS, VALID_DIRECTIONS, ALLOWED_EFFECT_TYPES)

func effects_to_codes(effects: Array) -> Array:
	return _validator.effects_to_codes(effects)

# --- PUBLIC API — JSON Repair (delegates to _json_repair)
# ═══════════════════════════════════════════════════════════════════════════════

func _extract_json_from_response(raw: String) -> Dictionary:
	return _json_repair.extract_json_from_response(raw)

# ═══════════════════════════════════════════════════════════════════════════════
# NARRATIVE CONTEXT BUILDING
# ═══════════════════════════════════════════════════════════════════════════════

func build_narrative_context(state: Dictionary) -> Dictionary:
	var run: Dictionary = state.get("run", {})
	var hidden: Dictionary = run.get("hidden", {})
	var meta: Dictionary = state.get("meta", {})

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

	var player_tendency := _get_player_tendency(hidden)

	var cards_played: int = int(run.get("cards_played", 0))
	var mos: Dictionary = MerlinConstants.MOS_CONVERGENCE
	var tension_zone: String = "none"
	var convergence_zone: bool = false
	if cards_played >= int(mos.get("soft_max_cards", 40)):
		tension_zone = "critical"
		convergence_zone = true
	elif cards_played >= int(mos.get("target_cards_max", 25)):
		tension_zone = "high"
		convergence_zone = true
	elif cards_played >= int(mos.get("target_cards_min", 20)):
		tension_zone = "rising"
		convergence_zone = true
	elif cards_played >= int(mos.get("soft_min_cards", 8)):
		tension_zone = "low"

	return {
		"factions": meta.get("faction_rep", {}).duplicate(),
		"cards_played": cards_played,
		"day": int(run.get("day", 1)),
		"active_tags": run.get("active_tags", []),
		"active_promises": run.get("active_promises", []),
		"story_log": _get_recent_story_log(run.get("story_log", []), 2),
		"biome": str(run.get("current_biome", "foret_broceliande")),
		"life_essence": int(run.get("life_essence", MerlinConstants.LIFE_ESSENCE_START)),
		"karma": int(hidden.get("karma", 0)),
		"tension": int(hidden.get("tension", 0)),
		"talent_names": talent_names,
		"player_tendency": player_tendency,
		"flags": state.get("flags", {}),
		"faction_status": _build_faction_status_string(state),
		"typology": str(run.get("typology", "classique")),
		"echo_memory": meta.get("echo_memory", {}),
		"tension_zone": tension_zone,
		"convergence_zone": convergence_zone,
		"total_runs": int(meta.get("total_runs", 0)),
	}

func build_context(state: Dictionary) -> Dictionary:
	var run = state.get("run", {})
	var meta: Dictionary = state.get("meta", {})
	return {
		"life_essence": int(run.get("life_essence", 100)),
		"factions": meta.get("faction_rep", {}),
		"day": int(run.get("day", 1)),
		"cards_played": int(run.get("cards_played", 0)),
		"active_promises": run.get("active_promises", []),
		"story_log": _get_recent_story_log(run.get("story_log", []), 2),
		"active_tags": run.get("active_tags", []),
		"current_arc": run.get("current_arc", ""),
		"flags": state.get("flags", {}),
	}

func _build_faction_status_string(state: Dictionary) -> String:
	var run: Dictionary = state.get("run", {})
	var faction_context: Dictionary = run.get("faction_context", {})
	var tiers: Dictionary = faction_context.get("tiers", {})
	if tiers.is_empty():
		return ""
	var parts: Array[String] = []
	for faction in MerlinConstants.FACTIONS:
		var tier: String = str(tiers.get(faction, "neutre"))
		if tier == "neutre":
			continue
		var info: Dictionary = MerlinConstants.FACTION_INFO.get(faction, {})
		var name: String = str(info.get("name", faction)).split(" ")[0]
		parts.append("%s:%s" % [name, tier])
	if parts.is_empty():
		return ""
	return "Relations: %s." % ", ".join(parts)

func _get_player_tendency(hidden: Dictionary) -> String:
	var profile: Dictionary = hidden.get("player_profile", {})
	var audace: int = int(profile.get("audace", 0))
	var prudence: int = int(profile.get("prudence", 0))
	if audace > prudence + 3:
		return "agressif"
	elif prudence > audace + 3:
		return "prudent"
	return "neutre"

func _get_recent_story_log(story_log: Array, count: int) -> Array:
	if story_log.size() <= count:
		return story_log.duplicate()
	return story_log.slice(story_log.size() - count, story_log.size())

# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL COMPAT — Test-accessible delegation to modules
# ═══════════════════════════════════════════════════════════════════════════════

func _evaluate_balance_heuristic(context: Dictionary) -> Dictionary:
	return _game_master.evaluate_balance_heuristic(context)

func _generate_contextual_effects(context_or_aspects: Dictionary) -> Array:
	return _game_master.generate_contextual_effects(context_or_aspects)

func _build_balance_hint(context: Dictionary) -> String:
	return _prompts.build_balance_hint(context, Callable(_game_master, "evaluate_balance_heuristic"))

# ═══════════════════════════════════════════════════════════════════════════════
# LEGACY — Deprecated (kept for backward compat)
# ═══════════════════════════════════════════════════════════════════════════════

func get_system_prompt() -> String:
	push_warning("MerlinLlmAdapter.get_system_prompt() is deprecated. Use _build_arc_system_prompt() instead.")
	return _prompts.build_narrative_system_prompt()

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
