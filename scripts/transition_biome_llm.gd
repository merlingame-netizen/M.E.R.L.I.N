## ═══════════════════════════════════════════════════════════════════════════════
## Transition Biome — LLM Context & Prefetch Module
## ═══════════════════════════════════════════════════════════════════════════════
## LLM context builders, dealer monologue, prefetch, validation, fallbacks.
## ═══════════════════════════════════════════════════════════════════════════════

class_name TransitionBiomeLLM
extends RefCounted

const LLM_POLL_INTERVAL := 0.12
const PREFETCH_WAIT_MAX := 6.0

var _last_monologue_text: String = ""
var _seen_variants: Dictionary = {}

const FALLBACK_MONOLOGUES := {
	"foret_broceliande": "Les cartes s'agitent sous mes doigts, Voyageur. La foret de Broceliande murmure ton nom entre ses chenes centenaires. L'odeur de mousse et de terre humide monte deja vers toi, comme un souvenir que tu n'as pas encore vecu. Les racines anciennes savent des choses que les pierres ont oubliees. Ton chemin commence ou la brume se dechire.",
	"landes_bruyere": "Ecoute le vent, Voyageur. Les landes de bruyere s'etendent devant toi comme un ocean de solitude violette. Ici les pierres dressees comptent les siecles en silence, et chaque pas crisse sur un secret enterre. Le gardien Talwen observe depuis les hauteurs. Ton ame sera mise a l'epreuve dans cette immensity.",
	"cotes_sauvages": "Sens-tu le sel sur tes levres, Voyageur ? Les cotes sauvages grondent de l'autre cote du voile. Les vagues frappent les falaises comme les battements d'un coeur ancien. Bran le gardien attend au bord de l'ecume. Le monde marin a ses propres regles, et tu devras les apprendre vite.",
	"villages_celtes": "Les flammes dansent dans les villages celtes, Voyageur. L'odeur de tourbe et de pain chaud porte jusqu'ici. Azenor la gardienne veille sur les siens avec une fermete douce. Chaque foyer raconte une histoire, chaque porte cache un choix. Le printemps reveille les esperances et les vieilles querelles.",
	"cercles_pierres": "Le temps hesite entre ces pierres dressees, Voyageur. Les cercles de pierres sont des portes que seuls les inities franchissent. Keridwen la gardienne tisse ses sortileges dans la brume du samhain. Ici l'ame se reflete dans le granit poli par les ages. Choisis bien tes pas.",
	"marais_enchantes": "Les eaux dormantes cachent bien des verites, Voyageur. Les marais enchantes brillent d'une lumiere trompeuse sous la lune. Gwydion le gardien connait chaque sentier entre les roseaux. Le corps s'alourdit dans ces brumes, mais l'esprit s'affute. N'oublie pas de regarder sous la surface.",
	"monts_arree": "Les monts d'Arree se dressent comme les dents d'un monde oublie, Voyageur. Le vent hurle entre les cretes et porte les echos du Yeun Elez. Dahut la gardienne regne sur ces hauteurs ou les nuages rampent comme des serpents. Ici tout est vertical : la montee, la chute, le choix.",
}


func build_llm_biome_context(biome_data: Dictionary) -> String:
	var parts: PackedStringArray = []
	parts.append("Tu es le narrateur poetique d'un jeu celtique breton.")
	parts.append("Biome: %s (%s)." % [biome_data.get("name", ""), biome_data.get("subtitle", "")])
	parts.append("Gardien: %s. Rune: %s. Saison: %s." % [
		biome_data.get("gardien", ""), biome_data.get("ogham", ""), biome_data.get("saison", "")])
	var atmo: Dictionary = biome_data.get("atmosphere", {})
	if not atmo.is_empty():
		parts.append("Ambiance: sons=%s, odeurs=%s, lumiere=%s, mood=%s." % [
			atmo.get("sounds", ""), atmo.get("smell", ""), atmo.get("light", ""), atmo.get("mood", "")])
	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm and "run" in gm:
		var run: Dictionary = gm.run if gm.run is Dictionary else {}
		var day: int = int(run.get("day", 1))
		parts.append("Jour %d de l'expedition." % day)
	parts.append("Ecris 1-2 phrases poetiques en francais. Pas de guillemets.")
	return "\n".join(parts)


func build_merlin_comment_context(biome_data: Dictionary) -> String:
	var parts: PackedStringArray = []
	parts.append("Tu es Merlin le druide, guide amuse et un peu cynique.")
	parts.append("Biome: %s. Gardien: %s." % [biome_data.get("name", ""), biome_data.get("gardien", "")])
	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm and "run" in gm:
		var run: Dictionary = gm.run if gm.run is Dictionary else {}
		var day: int = int(run.get("day", 1))
		parts.append("Jour %d." % day)
	parts.append("Commente en 1 phrase avec ton amuse. Francais uniquement.")
	return "\n".join(parts)


func build_dealer_monologue_prompt(biome_data: Dictionary) -> Dictionary:
	var template: Dictionary = {}
	var store: Node = Engine.get_main_loop().root.get_node_or_null("MerlinStore")
	if store and store.get("llm") and store.llm.has_method("get_scenario_template"):
		template = store.llm.get_scenario_template("dealer_monologue")

	var system_prompt: String = str(template.get("system", ""))
	var user_template: String = str(template.get("user_template", ""))

	if system_prompt.is_empty():
		system_prompt = "Tu es Merlin l'Enchanteur, conteur et maitre des cartes. Decris le biome avec tes sens de druide. 4-6 phrases en francais, ton grave et theatral. Pas de guillemets."
	if user_template.is_empty():
		user_template = "Biome: {biome_name}. Gardien: {guardian}. Saison: {season}. Jour {day}. Genere le monologue du dealer."

	var vars := {}
	vars["biome_name"] = str(biome_data.get("name", "Inconnu"))
	vars["biome_subtitle"] = str(biome_data.get("subtitle", ""))
	vars["guardian"] = str(biome_data.get("gardien", ""))
	vars["ogham"] = str(biome_data.get("ogham", ""))
	vars["season"] = str(biome_data.get("saison", biome_data.get("season_forte", "")))

	var gm: Node = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm and "run" in gm:
		var run: Dictionary = gm.run if gm.run is Dictionary else {}
		vars["day"] = str(int(run.get("day", 1)))
	else:
		vars["day"] = "1"

	var user_prompt := user_template
	for key in vars:
		user_prompt = user_prompt.replace("{%s}" % key, str(vars[key]))

	if store and store.has_method("get_scenario_manager"):
		var scenario_mgr = store.get_scenario_manager()
		if scenario_mgr and scenario_mgr.is_scenario_active():
			var override: Dictionary = scenario_mgr.get_dealer_intro_override()
			if not override.is_empty():
				user_prompt += "\nQUETE EN COURS: %s. %s" % [
					str(override.get("title", "")),
					str(override.get("context", ""))
				]
				var scenario_tone: String = str(override.get("tone", ""))
				if not scenario_tone.is_empty():
					user_prompt += " Ton dominant: %s." % scenario_tone

	return {"system": system_prompt, "user": user_prompt}


func get_fallback_monologue(biome_key: String) -> String:
	var text: String = str(FALLBACK_MONOLOGUES.get(biome_key, ""))
	if text.is_empty():
		text = "Les cartes du destin s'etalent devant toi, Voyageur. Merlin observe la brume qui se dissipe lentement. Chaque chemin mene quelque part, mais aucun ne ramene au meme endroit. Ton histoire s'ecrit a chaque pas."
	return text


func get_fallback_text(bkey: String, biome_data: Dictionary) -> Dictionary:
	var category := "balanced"
	var variants_dict: Dictionary = biome_data.get("variants", {})
	var variants: Array = variants_dict.get(category, [])
	if variants.is_empty():
		variants = variants_dict.get("balanced", [])
	if variants.is_empty():
		return {"arrival": biome_data.get("arrival_text", ""), "merlin": biome_data.get("merlin_comment", "")}
	var idx: int = _pick_unseen_variant(bkey, category, variants.size())
	var v: Dictionary = variants[idx]
	return {"arrival": str(v.get("arrival", "")), "merlin": str(v.get("merlin", ""))}


func _pick_unseen_variant(bkey: String, category: String, total: int) -> int:
	var seen_key := "%s_%s" % [bkey, category]
	if not _seen_variants.has(seen_key):
		_seen_variants[seen_key] = []
	var seen: Array = _seen_variants[seen_key]
	var unseen: Array = []
	for i in range(total):
		if i not in seen:
			unseen.append(i)
	if unseen.is_empty():
		seen.clear()
		for i in range(total):
			unseen.append(i)
	var idx: int = unseen[randi() % unseen.size()]
	seen.append(idx)
	return idx


func start_llm_prefetch(prefetch_state: Dictionary, merlin_ai: Node, biome_data: Dictionary, biome_key: String) -> void:
	if merlin_ai == null or not merlin_ai.is_ready:
		prefetch_state["done"] = true
		prefetch_state["text"] = ""
		prefetch_state["source"] = "fallback"
		return
	var prompt_data: Dictionary = build_dealer_monologue_prompt(biome_data)
	async_generate(prefetch_state, merlin_ai, prompt_data["system"], prompt_data["user"], 250)


func async_generate(state: Dictionary, merlin_ai: Node, system_prompt: String, user_input: String, max_tokens: int = 80) -> void:
	state["done"] = false
	state["text"] = ""
	state["source"] = "fallback"

	if merlin_ai == null or not merlin_ai.is_ready:
		state["done"] = true
		return

	var result: Dictionary = await merlin_ai.generate_narrative(system_prompt, user_input, {"max_tokens": max_tokens})
	if result.has("error"):
		state["done"] = true
		return

	var text: String = str(result.get("text", ""))
	text = validate_llm_text(text)
	if not text.is_empty():
		state["text"] = text
		state["source"] = "llm"

	state["done"] = true


func consume_prefetch(state: Dictionary, fallback_type: String, biome_key: String, biome_data: Dictionary, host: Control) -> Dictionary:
	var wait := 0.0
	while not state.get("done", false) and wait < PREFETCH_WAIT_MAX:
		if not host.is_inside_tree():
			break
		await host.get_tree().create_timer(maxf(0.01, LLM_POLL_INTERVAL)).timeout
		wait += LLM_POLL_INTERVAL
	var text: String = str(state.get("text", ""))
	var source: String = str(state.get("source", "fallback"))
	if source != "llm" or text.is_empty():
		if fallback_type == "monologue":
			text = get_fallback_monologue(biome_key)
		else:
			var fb := get_fallback_text(biome_key, biome_data)
			var legacy_key := "arrival_text" if fallback_type == "arrival" else "merlin_comment"
			text = str(fb.get(fallback_type, biome_data.get(legacy_key, "")))
		source = "fallback"
	return {"text": text, "source": source}


func validate_llm_text(text: String) -> String:
	if text.length() < 10 or text.length() > 800:
		return ""
	var lower := text.to_lower()
	for eng_word in ["the ", " and ", " you ", " are ", " this ", " that "]:
		if eng_word in lower:
			return ""
	if _last_monologue_text != "" and text != "":
		var sim := _jaccard_similarity(text, _last_monologue_text)
		if sim > 0.7:
			return ""
	return text


func _jaccard_similarity(a: String, b: String) -> float:
	var words_a: PackedStringArray = a.to_lower().split(" ", false)
	var words_b: PackedStringArray = b.to_lower().split(" ", false)
	if words_a.is_empty() or words_b.is_empty():
		return 0.0
	var set_a: Dictionary = {}
	for w in words_a:
		set_a[w] = true
	var set_b: Dictionary = {}
	for w in words_b:
		set_b[w] = true
	var intersection: int = 0
	for w in set_a:
		if set_b.has(w):
			intersection += 1
	var union_size: int = set_a.size() + set_b.size() - intersection
	if union_size == 0:
		return 0.0
	return float(intersection) / float(union_size)


func generate_run_intro(merlin_ai: Node, biome_data: Dictionary, biome_key: String) -> void:
	if merlin_ai == null or not merlin_ai.is_ready:
		return

	var biome_name: String = str(biome_data.get("name", "Broceliande"))
	var biome_subtitle_text: String = str(biome_data.get("sous_titre", ""))
	var guardian: String = str(biome_data.get("gardien", ""))
	var ogham: String = str(biome_data.get("ogham", ""))

	var sys := (
		"Tu es Merlin l'Enchanteur, conteur et maitre des cartes. "
		+ "Tu poses les cartes du destin sur la table de pierre devant le Voyageur. "
		+ "Decris le biome avec tes sens de druide (odeurs, sons, lumiere, textures). "
		+ "Mentionne l'etat du voyageur sans nommer les mecaniques. "
		+ "Termine par un pressentiment enigmatique sur ce qui attend. "
		+ "4-6 phrases en francais, ton grave et theatral, comme un conteur au coin du feu. "
		+ "Pas de guillemets. Vocabulaire celtique: nemeton, rune, sidhe, dolmen, brume, racines, pierre dressee."
	)
	var usr := "Biome: %s (%s). Gardien: %s. Rune: %s. Genere le monologue du dealer." % [
		biome_name, biome_subtitle_text, guardian, ogham
	]

	var store: Node = Engine.get_main_loop().root.get_node_or_null("MerlinStore")
	if store and store.has_method("get_scenario_manager"):
		var scenario_mgr = store.get_scenario_manager()
		if scenario_mgr and scenario_mgr.is_scenario_active():
			var title: String = scenario_mgr.get_scenario_title()
			var tone: String = scenario_mgr.get_scenario_tone()
			if not title.is_empty():
				usr += " Scenario: %s. Ton: %s." % [title, tone]

	var result: Dictionary = await merlin_ai.generate_narrative(sys, usr, {"max_tokens": 250})
	var text: String = str(result.get("text", "")).strip_edges()

	if text.length() < 10 or text.length() > 800:
		return
	var lower := text.to_lower()
	for eng_word in ["the ", " and ", " you "]:
		if eng_word in lower:
			return

	var intro_data := {
		"text": text,
		"biome": biome_key,
		"source": "llm",
		"timestamp": Time.get_ticks_msec()
	}
	var f := FileAccess.open("user://temp_run_intro.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(intro_data))
		f.close()
		print("[TransitionBiome] Run intro saved: %s" % text.left(60))
