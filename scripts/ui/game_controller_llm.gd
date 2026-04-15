## ═══════════════════════════════════════════════════════════════════════════════
## Game Controller — LLM Integration Module
## ═══════════════════════════════════════════════════════════════════════════════
## Extracted from merlin_game_controller.gd.
## Handles LLM retry, sequel cards, NPC encounters, card buffer, prefetch,
## prerun loading, and intro speech building.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name GameControllerLLM

var _ctrl: Node  # MerlinGameController reference


func _init(controller: Node) -> void:
	_ctrl = controller


func retry_llm_generation(max_retries: int) -> Dictionary:
	## Retry LLM generation with escalating temperature. Returns card or {}.
	var merlin_ai: Node = _ctrl.merlin_ai
	if merlin_ai == null or not merlin_ai.get("is_ready"):
		if merlin_ai and merlin_ai.has_method("ensure_ready"):
			merlin_ai.ensure_ready()
		return {}
	if not merlin_ai.has_method("generate_with_system"):
		return {}
	if merlin_ai.has_method("is_llm_busy") and merlin_ai.is_llm_busy():
		print("[Merlin] _retry_llm_generation: LLM busy, skipping retry")
		return {}

	var temperatures := [0.6, 0.7, 0.8]
	var system_prompt := "Tu es Merlin, druide FOU de Broceliande. Decris une SITUATION que le voyageur VIT (danger, enigme, rencontre). PAS ce que Merlin fait. Les 3 choix = REACTIONS du voyageur. Verbes SPECIFIQUES (jamais 'avancer'/'observer'/'fuir'/'suivre'). TU (jamais nous/je). Phrases courtes. Pas de 'Voici'. Pas de meta.\nExemple:\nHa! Un dolmen fissure bloque le sentier... Des runes pulsent sur la pierre, voyageur. Quelque chose gratte de l'autre cote.\nA) Escalader\nB) Dechiffrer\nC) Contourner\n4-5 phrases puis A) B) C). RIEN d'autre."
	var cards_this_run: int = _ctrl._cards_this_run

	for i in range(mini(max_retries, temperatures.size())):
		var temp: float = temperatures[i]
		var user_prompt := "Carte %d. Decris une SITUATION que le voyageur vit. Puis A) B) C) = ses REACTIONS. Verbes SPECIFIQUES lies a la scene." % cards_this_run

		var result: Dictionary = await merlin_ai.generate_with_system(
			system_prompt, user_prompt,
			{"max_tokens": 180, "temperature": temp}
		)

		if result.has("error") or str(result.get("text", "")).length() < 20:
			print("[Merlin] LLM retry %d failed (temp=%.1f, err=%s)" % [i + 1, temp, str(result.get("error", "short"))])
			continue

		var raw_text: String = str(result.get("text", ""))
		print("[Merlin] LLM retry %d got %d chars" % [i + 1, raw_text.length()])

		var parsed: Dictionary = _parse_llm_labels(raw_text)
		var labels: Array[String] = parsed.get("labels", [] as Array[String])
		var narrative: String = parsed.get("narrative", "")

		if narrative.length() < 10:
			print("[Merlin] LLM retry %d: narrative too short, skipping" % (i + 1))
			continue

		# Pad labels to 3 if needed
		var fallback_labels := [tr("FALLBACK_CAUTIOUS"), tr("FALLBACK_OBSERVE"), tr("FALLBACK_ACT")]
		while labels.size() < 3:
			labels.append(fallback_labels[labels.size()])
		print("[Merlin] LLM retry %d: %d labels extracted" % [i + 1, parsed.get("match_count", 0)])

		# Build card with Vie/Reputation effects
		var effect_sets: Array = [
			[{"type": "HEAL_LIFE", "amount": 5}],
			[{"type": "ADD_KARMA", "amount": 1}],
			[{"type": "DAMAGE_LIFE", "amount": 3}],
		]
		var options: Array = []
		var directions := ["left", "center", "right"]
		for j in range(3):
			var opt: Dictionary = {
				"direction": directions[j],
				"label": labels[j],
				"effects": effect_sets[j],
			}
			if j == 1:
				opt["cost"] = 1
			options.append(opt)

		print("[Merlin] LLM retry %d succeeded (temp=%.1f)" % [i + 1, temp])
		return {
			"id": "retry_%d_%d" % [cards_this_run, i],
			"text": narrative if narrative.length() > 20 else raw_text.substr(0, mini(raw_text.length(), 400)),
			"speaker": "Merlin",
			"type": "narrative",
			"options": options,
			"tags": ["llm_generated", "retry"],
		}

	print("[Merlin] All %d LLM retries exhausted" % max_retries)
	return {}


func try_sequel_card() -> Dictionary:
	## Generate a sequel card referencing a previous prerun choice.
	var merlin_ai: Node = _ctrl.merlin_ai
	var prerun_choices: Array[Dictionary] = _ctrl._prerun_choices
	if prerun_choices.is_empty() or not merlin_ai or not merlin_ai.get("is_ready"):
		return {}
	if not merlin_ai.has_method("generate_with_system"):
		return {}

	var candidates: Array[Dictionary] = []
	for pc in prerun_choices:
		if not str(pc.get("sequel_hook", "")).is_empty():
			candidates.append(pc)
	if candidates.is_empty():
		candidates.assign(prerun_choices)

	var chosen: Dictionary = candidates[randi() % candidates.size()]
	var context: String = _build_prerun_context_string(chosen)
	var cards_this_run: int = _ctrl._cards_this_run

	var system_prompt := "Tu es Merlin l'Enchanteur. Le joueur a fait un choix plus tot dans son voyage. Ecris une scene (5-7 phrases, 420-620 caracteres) qui est une CONSEQUENCE directe de ce choix passe. Propose 3 options (A/B/C) avec verbes d'action."
	var user_prompt := "Contexte du choix passe: %s. Carte %d du run. Genere une suite narrative coherente avec ce qui s'est passe avant." % [context, cards_this_run]

	var result: Dictionary = await merlin_ai.generate_with_system(system_prompt, user_prompt, {"max_tokens": 380, "temperature": 0.72})
	if result.has("error") or str(result.get("text", "")).length() < 20:
		return {}

	var raw_text: String = str(result.get("text", ""))

	var labels: Array[String] = []
	var rx := RegEx.new()
	rx.compile("(?m)^\\s*(?:[A-C]\\)|[1-3][.)]|[-*])\\s+(.+)")
	var matches := rx.search_all(raw_text)
	for m in matches:
		var label: String = m.get_string(1).strip_edges()
		if label.length() > 2 and label.length() < 80:
			labels.append(label)

	var narrative: String = raw_text
	if labels.size() >= 2:
		var rx2 := RegEx.new()
		rx2.compile("(?m)^\\s*(?:[A-C]\\)|[1-3][.)]|[-*])\\s+")
		var first_choice := rx2.search(raw_text)
		if first_choice:
			narrative = raw_text.substr(0, first_choice.get_start()).strip_edges()

	if labels.size() < 3:
		return {}

	var sequel_effects: Array = [
		[{"type": "HEAL_LIFE", "amount": 5}],
		[{"type": "ADD_KARMA", "amount": 1}],
		[{"type": "DAMAGE_LIFE", "amount": 3}],
	]
	var options: Array = []
	for j in range(3):
		var opt: Dictionary = {
			"direction": ["left", "center", "right"][j],
			"label": labels[j] if j < labels.size() else I18nRegistry.tf("ui.llm.choice_fallback", [j + 1]),
			"effects": sequel_effects[j],
		}
		options.append(opt)

	return {
		"id": "sequel_%d_%s" % [cards_this_run, chosen.get("thread_id", "")],
		"text": narrative if narrative.length() > 20 else raw_text.substr(0, mini(raw_text.length(), 300)),
		"speaker": "Merlin",
		"type": "narrative",
		"options": options,
		"result_success": I18nRegistry.t("ui.llm.sequel_success"),
		"result_failure": I18nRegistry.t("ui.llm.sequel_failure"),
		"tags": ["sequel", "llm_generated"],
		"source_prerun": chosen.get("thread_id", ""),
	}


func try_npc_encounter(store: Node) -> Dictionary:
	## Try to generate an NPC encounter card (LLM first, then fallback pool).
	if not store:
		return {}
	var merlin_mos: MerlinOmniscient = store.get_merlin()
	if merlin_mos and merlin_mos.has_method("generate_npc_card"):
		var npc_card: Dictionary = await merlin_mos.generate_npc_card(store.state)
		if not npc_card.is_empty():
			return npc_card
	return {}


func trigger_prefetch(store: Node) -> void:
	## Start pre-generating the next card in background.
	if not store or not store.is_merlin_active():
		return
	var merlin_mos: MerlinOmniscient = store.get_merlin()
	if merlin_mos:
		merlin_mos.prefetch_next_card(store.state)


func load_prerun_cards(card_buffer: Array[Dictionary]) -> void:
	## Load pre-generated cards from TransitionBiome temp file into buffer.
	var prerun_path := "user://temp_run_cards.json"
	if not FileAccess.file_exists(prerun_path):
		print("[Merlin] No prerun cards file found at %s" % prerun_path)
		print("[Merlin] Card buffer empty, LLM will generate on demand")
		return
	var file := FileAccess.open(prerun_path, FileAccess.READ)
	if not file:
		print("[Merlin] Failed to open prerun cards file")
		return
	var raw_text: String = file.get_as_text()
	file.close()
	DirAccess.remove_absolute(prerun_path)
	var data = JSON.parse_string(raw_text)
	if not data is Array:
		print("[Merlin] Prerun cards file invalid (not Array): %s" % raw_text.left(100))
		return
	for card in data:
		if card is Dictionary and card.has("text") and card.has("options"):
			card_buffer.append(card)
	if not card_buffer.is_empty():
		print("[Merlin] Loaded %d pre-generated cards from TransitionBiome" % card_buffer.size())
	else:
		print("[Merlin] Prerun file had %d entries but none valid" % data.size())


func ensure_card_buffer_ready(card_buffer: Array[Dictionary], store: Node, tree: SceneTree) -> bool:
	## Verify that the card buffer has at least one card ready.
	## Returns true if at least one card is available, false otherwise.
	if not card_buffer.is_empty():
		return true
	# Try consuming a prefetched card from MerlinOmniscient
	if store and store.has_method("get_merlin"):
		var merlin_mos = store.get_merlin()
		if merlin_mos and merlin_mos.has_method("try_consume_prefetch"):
			var prefetched: Dictionary = merlin_mos.try_consume_prefetch(store.state)
			if not prefetched.is_empty():
				card_buffer.append(prefetched)
				return true
	# Wait up to 5 seconds for a prefetched card
	var wait_deadline: int = Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < wait_deadline:
		if not _ctrl.is_inside_tree():
			return false
		if store and store.has_method("get_merlin"):
			var merlin_mos = store.get_merlin()
			if merlin_mos and merlin_mos.has_method("try_consume_prefetch"):
				var prefetched: Dictionary = merlin_mos.try_consume_prefetch(store.state)
				if not prefetched.is_empty():
					card_buffer.append(prefetched)
					return true
		await tree.process_frame
	return false


func build_merlin_intro_speech(biome_key: String, season_hint: String,
		biome_display_names: Dictionary, intro_speeches: Array[String],
		season_flavor: Dictionary) -> String:
	## Build a contextual Merlin intro speech from templates.
	var biome_display: String = biome_display_names.get(biome_key, "")
	if biome_display.is_empty():
		biome_display = biome_key.replace("_", " ")
	var template: String = intro_speeches[randi() % intro_speeches.size()]
	var speech: String = template % biome_display
	var season_lower: String = season_hint.strip_edges().to_lower()
	if not season_lower.is_empty():
		var flavor: String = str(season_flavor.get(season_lower, ""))
		if not flavor.is_empty():
			speech += flavor
	return speech


func _build_prerun_context_string(choice: Dictionary) -> String:
	## Build a context string from a prerun choice for sequel prompt.
	var parts: Array[String] = []
	var label: String = str(choice.get("chosen_label", ""))
	if not label.is_empty():
		parts.append("Le joueur a choisi: '%s'" % label)
	var hook: String = str(choice.get("sequel_hook", ""))
	if not hook.is_empty():
		parts.append("Consequence annoncee: '%s'" % hook)
	var outcome: String = str(choice.get("outcome", ""))
	if not outcome.is_empty():
		parts.append("Resultat: %s" % outcome)
	var card_text: String = str(choice.get("card_text", ""))
	if not card_text.is_empty():
		parts.append("Scene d'origine: '%s'" % card_text)
	return ". ".join(parts) if not parts.is_empty() else "Un choix anterieur"


func _parse_llm_labels(raw_text: String) -> Dictionary:
	## Parse LLM output for A/B/C labels and narrative text.
	var labels: Array[String] = []
	var rx := RegEx.new()
	rx.compile("(?m)^\\s*(?:[-*]\\s*)?\\*{0,2}(?:(?:Action\\s+)?[A-C][):.\\]]|[1-3][.)]|[-*])\\*{0,2}[:\\s]+(.+)")
	var matches := rx.search_all(raw_text)
	for m in matches:
		var label: String = m.get_string(1).strip_edges().replace("**", "").replace("*", "")
		if label.length() > 2 and label.length() < 120:
			labels.append(label)

	var narrative: String = raw_text
	var rx2 := RegEx.new()
	rx2.compile("(?m)^\\s*(?:[-*]\\s*)?\\*{0,2}(?:(?:Action\\s+)?[A-C][):.\\]]|[1-3][.)]|[-*])\\*{0,2}[:\\s]+")
	var first_choice := rx2.search(raw_text)
	if first_choice:
		narrative = raw_text.substr(0, first_choice.get_start()).strip_edges()
	narrative = narrative.replace("**", "").replace("*", "")

	return {"labels": labels, "narrative": narrative, "match_count": matches.size()}
