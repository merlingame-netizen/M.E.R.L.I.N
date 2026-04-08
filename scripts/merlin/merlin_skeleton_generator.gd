## ═══════════════════════════════════════════════════════════════════════════════
## Merlin Skeleton Generator — Pre-run map graph orchestrator
## ═══════════════════════════════════════════════════════════════════════════════
## Calculates generation parameters from game state, calls LLM via MOS,
## parses + validates the JSON graph, falls back to procedural if LLM fails.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name MerlinSkeletonGenerator

signal skeleton_ready(graph: MerlinRunGraph)
signal skeleton_failed(reason: String)


# ── Public API ──────────────────────────────────────────────────────────────

## Generate a run skeleton for the given biome, ogham, and game state.
## Returns MerlinRunGraph (valid) or null on failure.
## llm_interface: reference to MerlinAI autoload (has generate_structured).
## save_data: player save for biome history lookup.
static func generate(biome_id: String, ogham_id: String, game_state: Dictionary,
		llm_interface: Node, save_data: Dictionary) -> MerlinRunGraph:

	var context: Dictionary = _build_context(biome_id, ogham_id, game_state, save_data)

	# Try LLM generation.
	var graph: MerlinRunGraph = await _try_llm_generation(context, llm_interface)
	if graph != null:
		return graph

	# Fallback: procedural graph.
	print("[SkeletonGen] LLM failed, using procedural fallback")
	return _generate_procedural(context)


# ── Context building ────────────────────────────────────────────────────────

static func _build_context(biome_id: String, ogham_id: String,
		game_state: Dictionary, save_data: Dictionary) -> Dictionary:

	var biome_data: Dictionary = MerlinConstants.BIOMES.get(biome_id, {})
	var faction_biome: String = str(biome_data.get("arc_condition_faction", "druides"))

	# Faction reputation for this biome's faction.
	var faction_rep: Dictionary = game_state.get("faction_rep", {})
	var rep_value: int = int(faction_rep.get(faction_biome, MerlinConstants.FACTION_SCORE_START))

	# Biome history from save.
	var biome_history: Dictionary = save_data.get("biome_history", {}).get(biome_id, {})
	var previous_runs: int = int(biome_history.get("total_runs", 0))
	var explored_detours: Array = biome_history.get("explored_detours", [])

	# Weather selection based on biome season.
	var season: String = str(biome_data.get("season", "printemps"))
	var weather: String = _pick_weather(season)

	# Festival detection.
	var festival: String = _detect_festival()

	# Trust tier.
	var trust_value: int = int(game_state.get("merlin_trust", 50))
	var trust_tier: int = _trust_to_tier(trust_value)

	return {
		"biome_id": biome_id,
		"ogham_id": ogham_id,
		"faction_rep": rep_value,
		"previous_runs": previous_runs,
		"explored_detours": explored_detours,
		"weather": weather,
		"festival": festival,
		"trust_tier": trust_tier,
		"trust_value": trust_value,
	}


# ── LLM generation ─────────────────────────────────────────────────────────

static func _try_llm_generation(context: Dictionary, llm_interface: Node) -> MerlinRunGraph:
	if llm_interface == null:
		return null
	if not llm_interface.get("is_ready"):
		print("[SkeletonGen] LLM not ready")
		return null

	var system_prompt: String = LlmAdapterMapPrompt.build_system_prompt()
	var user_prompt: String = LlmAdapterMapPrompt.build_user_prompt(context)

	# Use structured generation (GM brain, low temp) for reliable JSON.
	var params: Dictionary = {
		"temperature": 0.4,
		"max_tokens": 1500,
		"skip_scene_contract": true,
	}

	print("[SkeletonGen] Requesting skeleton from LLM (%d char prompt)" % user_prompt.length())
	var result: Dictionary = await llm_interface.generate_structured(system_prompt, user_prompt, "", params)

	if result.has("error"):
		print("[SkeletonGen] LLM error: %s" % str(result["error"]))
		return null

	var raw_text: String = str(result.get("text", ""))
	if raw_text.is_empty():
		print("[SkeletonGen] LLM returned empty text")
		return null

	# Parse JSON.
	var parsed: Dictionary = _parse_json_response(raw_text)
	if parsed.is_empty():
		print("[SkeletonGen] Failed to parse LLM JSON response")
		return null

	# Build graph.
	var graph: MerlinRunGraph = MerlinRunGraph.from_dict(parsed)

	# Validate.
	var validation: Dictionary = graph.validate()
	if not validation["valid"]:
		print("[SkeletonGen] Graph validation failed:")
		for err in validation["errors"]:
			print("  - %s" % err)
		return null

	print("[SkeletonGen] LLM skeleton ready: %d main nodes, %d detour nodes" % [
		graph.total_main_nodes, graph.total_detour_nodes])
	return graph


static func _parse_json_response(raw: String) -> Dictionary:
	# Strip markdown fences if present.
	var text: String = raw.strip_edges()
	if text.begins_with("```"):
		var first_newline: int = text.find("\n")
		if first_newline >= 0:
			text = text.substr(first_newline + 1)
		if text.ends_with("```"):
			text = text.substr(0, text.length() - 3)
		text = text.strip_edges()

	# Find JSON object boundaries.
	var start: int = text.find("{")
	var end: int = text.rfind("}")
	if start < 0 or end < 0 or end <= start:
		return {}
	text = text.substr(start, end - start + 1)

	var json: JSON = JSON.new()
	var err: Error = json.parse(text)
	if err != OK:
		print("[SkeletonGen] JSON parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return {}

	var data: Variant = json.data
	if data is Dictionary:
		return data
	return {}


# ── Procedural fallback ────────────────────────────────────────────────────

static func _generate_procedural(context: Dictionary) -> MerlinRunGraph:
	var biome_id: String = str(context.get("biome_id", "foret_broceliande"))
	var ranges: Dictionary = MerlinConstants.BIOME_NODE_RANGES.get(biome_id,
		{"main_min": 10, "main_max": 15, "detours_min": 1, "detours_max": 2})

	var main_min: int = int(ranges["main_min"])
	var main_max: int = int(ranges["main_max"])
	var det_min: int = int(ranges["detours_min"])
	var det_max: int = int(ranges["detours_max"])

	# Rep modifiers.
	var rep: int = int(context.get("faction_rep", 20))
	if rep >= MerlinConstants.MAP_REP_SECRET_THRESHOLD:
		main_max = maxi(main_min, main_max - MerlinConstants.MAP_REP_SECRET_NODES)
	elif rep >= MerlinConstants.MAP_REP_SHORTCUT_THRESHOLD:
		main_max = maxi(main_min, main_max - MerlinConstants.MAP_REP_SHORTCUT_NODES)

	var main_count: int = randi_range(main_min, main_max)
	var detour_count: int = randi_range(det_min, det_max)

	var biome_data: Dictionary = MerlinConstants.BIOMES.get(biome_id, {})
	var season: String = str(biome_data.get("season", "printemps"))
	var weather: String = str(context.get("weather", "clair"))

	# Build nodes.
	var nodes_array: Array[Dictionary] = []
	var tones: Array[String] = MerlinConstants.TONE_ARC.duplicate()

	# Main path nodes.
	for i in range(main_count):
		var ntype: String = _procedural_node_type(i, main_count)
		var tone_idx: int = clampi(int(float(i) / float(maxi(main_count - 1, 1)) * float(tones.size() - 1)), 0, tones.size() - 1)
		var node: Dictionary = {
			"id": "n%d" % i,
			"type": ntype,
			"label": _procedural_label(ntype, i),
			"tone": tones[tone_idx],
			"next": ["n%d" % (i + 1)] if i < main_count - 1 else [],
			"is_detour": false,
			"detour_entry": null,
			"floor": i,
		}
		nodes_array.append(node)

	# Insert detours at evenly spaced main nodes (not first or last).
	var detour_positions: Array[int] = []
	if main_count > 4 and detour_count > 0:
		var spacing: int = maxi(1, (main_count - 2) / (detour_count + 1))
		for d in range(detour_count):
			var pos: int = clampi(spacing * (d + 1), 2, main_count - 3)
			if not detour_positions.has(pos):
				detour_positions.append(pos)

	var reward_keys: Array = MerlinConstants.DETOUR_REWARDS.keys()
	for d_idx in range(detour_positions.size()):
		var main_idx: int = detour_positions[d_idx]
		var d_start_id: String = "d%d" % (d_idx * 2)
		var d_end_id: String = "d%d" % (d_idx * 2 + 1)
		var reconnect_id: String = "n%d" % (main_idx + 1)

		# Mark main node as having detour entry.
		for node in nodes_array:
			if str(node["id"]) == "n%d" % main_idx:
				node["detour_entry"] = d_start_id
				break

		# Detour start.
		var reward: String = reward_keys[d_idx % reward_keys.size()]
		nodes_array.append({
			"id": d_start_id,
			"type": "detour_start",
			"label": "Detour %d" % (d_idx + 1),
			"tone": "emerveillement",
			"next": [d_end_id],
			"is_detour": true,
			"reward_hint": reward,
			"floor": main_idx,
		})

		# Detour end.
		nodes_array.append({
			"id": d_end_id,
			"type": "detour_end",
			"label": "Retour au sentier",
			"tone": "soulagement",
			"next": [reconnect_id],
			"is_detour": true,
			"floor": main_idx,
		})

	var biome_name: String = str(biome_data.get("name", biome_id))
	var synopsis_result: Dictionary = _procedural_synopsis(biome_id, biome_name, weather, season, nodes_array)
	var data: Dictionary = {
		"scenario_title": "Voyage en %s" % biome_name,
		"scenario_synopsis": str(synopsis_result.get("text", "")),
		"biome": biome_id,
		"season": season,
		"weather": weather,
		"total_main_nodes": main_count,
		"total_detour_nodes": detour_positions.size() * 2,
		"estimated_cards": main_count + detour_positions.size() * MerlinConstants.DETOUR_CARDS_MIN,
		"chapter_breaks": synopsis_result.get("chapter_breaks", []),
		"nodes": nodes_array,
		"arc_events": [],
		"metadata": {
			"difficulty_modifier": 0,
			"faction_shortcuts_applied": 0,
			"previous_runs_in_biome": int(context.get("previous_runs", 0)),
			"active_festival": context.get("festival", null),
			"procedural_fallback": true,
		},
	}

	return MerlinRunGraph.from_dict(data)


static func _procedural_node_type(index: int, total: int) -> String:
	if index == 0:
		return "narrative"
	if index == total - 1:
		return "merlin"
	if index == int(total / 2.0):
		return ["rest", "merchant"][randi() % 2]

	# Weighted random for middle nodes.
	var roll: float = randf()
	if roll < 0.45:
		return "narrative"
	elif roll < 0.60:
		return "event"
	elif roll < 0.72:
		return "mystery"
	elif roll < 0.82:
		return "promise"
	elif roll < 0.90:
		return "rest"
	else:
		return "merchant"


static func _procedural_label(ntype: String, index: int) -> String:
	match ntype:
		"narrative":
			return "Recit %d" % (index + 1)
		"event":
			return "Evenement %d" % (index + 1)
		"promise":
			return "Promesse %d" % (index + 1)
		"rest":
			return "Repos"
		"merchant":
			return "Marchand"
		"mystery":
			return "Mystere %d" % (index + 1)
		"merlin":
			return "Apparition de Merlin"
	return "Noeud %d" % (index + 1)


# ── Utility ─────────────────────────────────────────────────────────────────

static func _pick_weather(season: String) -> String:
	var candidates: Array[Dictionary] = []
	for weather_id in MerlinConstants.WEATHER_TYPES:
		var w: Dictionary = MerlinConstants.WEATHER_TYPES[weather_id]
		var weight: int = int(w.get("season_weight", {}).get(season, 1))
		if weight > 0:
			candidates.append({"id": weather_id, "weight": weight})
	if candidates.is_empty():
		return "clair"

	var total_weight: int = 0
	for c in candidates:
		total_weight += int(c["weight"])
	var roll: int = randi() % maxi(total_weight, 1)
	var cumulative: int = 0
	for c in candidates:
		cumulative += int(c["weight"])
		if roll < cumulative:
			return str(c["id"])
	return str(candidates[0]["id"])


static func _detect_festival() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var month: int = int(now.get("month", 1))
	var day: int = int(now.get("day", 1))
	for fest_id in MerlinConstants.FESTIVALS:
		var f: Dictionary = MerlinConstants.FESTIVALS[fest_id]
		var ms: int = int(f.get("month_start", 0))
		var ds: int = int(f.get("day_start", 0))
		var me: int = int(f.get("month_end", 0))
		var de: int = int(f.get("day_end", 0))
		if (month == ms and day >= ds) or (month == me and day <= de):
			return fest_id
	return ""


static func _trust_to_tier(trust_value: int) -> int:
	if trust_value >= 80:
		return 3
	elif trust_value >= 50:
		return 2
	elif trust_value >= 20:
		return 1
	return 0


static func _procedural_synopsis(biome_id: String, biome_name: String,
		weather: String, season: String, _nodes: Array = []) -> Dictionary:
	# Synopsis = BACKSTORY: what happened before the journey, why the player
	# is setting out. NOT a description of what will happen on the trail.
	# 6-10 sentences, one paragraph.

	# ── Inciting incidents (biome-specific) ───────────────────────────────
	var backstories: Dictionary = {
		"foret_broceliande": [
			"Depuis trois nuits, les chenes de %s emettent une lueur pale que les anciens n'avaient jamais vue. Les druides du cercle interieur se sont reunis en urgence — leurs divinations convergent toutes vers un meme presage : l'equilibre ancien vacille. Les oiseaux ont cesse de chanter a l'aube, et les sources sacrees coulent a rebours. Merlin lui-meme a envoye un message grave par les racines du Grand Arbre. Quelqu'un doit parcourir le sentier oublie avant que les signes ne s'eteignent pour toujours.",
			"Un voyageur est arrive au village hier, le souffle court et les yeux hagards. Il a parle d'ombres mouvantes dans les profondeurs de %s, de pierres qui bougent la nuit et de murmures dans une langue morte. Les anciens ont reconnu les symptomes : le Voile s'amincit, comme chaque fois que les Oghams appellent un nouveau gardien. Il faut repondre a l'appel avant que l'ouverture ne se referme.",
			"Ce matin, en puisant l'eau au puits sacre, vous avez trouve un symbole oghamique grave dans la glace qui recouvrait la surface. Le symbole de Beith — le commencement. Les anciens de %s disent que cela n'est arrive que trois fois en mille ans. Chaque fois, celui qui a suivi le signe est revenu transforme. Ou n'est pas revenu du tout.",
		],
		"landes_bruyere": [
			"Les megalithes de %s se sont deplaces pendant la nuit. Pas beaucoup — quelques pouces a peine — mais suffisamment pour briser l'alignement millennaire. Les gardiens des landes n'ont aucune explication. La derniere fois que les pierres ont bouge, les chroniques parlent d'un voyage initiatique dont seul un elu est revenu. Le vent porte desormais des fragments de melodies impossibles.",
			"Depuis l'equinoxe, la bruyere de %s pousse dans des motifs que personne ne comprend. Vus du ciel, les lignes forment des lettres oghams. Le message est incomplet, mais les deux premiers mots sont clairs : 'Viens maintenant'. Les druides tremblent, car les landes n'avaient pas parle depuis six generations.",
		],
		"cotes_sauvages": [
			"La mer a rejete quelque chose sur les rivages de %s : un coffre de bois noir, incruste de symboles oghams, impossible a ouvrir. Les pecheurs qui l'ont touche rapportent des visions — un sentier lumineux sous les vagues, une voix ancienne qui appelle. Le coffre pulse doucement, comme un coeur qui bat. Il faut suivre la piste avant que la maree ne l'emporte a nouveau.",
		],
		"villages_celtes": [
			"Le feu sacre de %s s'est eteint pour la premiere fois en quatre cents ans. Aucun souffle, aucune pluie — il s'est simplement arrete de bruler. Les villageois sont terrifies. L'Oracle a vu dans les cendres le tracage d'un chemin, et au bout, la silhouette de Merlin. Le feu ne se rallumera que quand quelqu'un aura parcouru ce chemin jusqu'au bout.",
		],
		"cercles_pierres": [
			"A l'aube, les pierres de %s ont commence a resonner. Un son grave, continu, que l'on ressent plus qu'on ne l'entend. Les animaux fuient, les oiseaux tournent en cercle sans se poser. Les druides affirment que le cercle appelle son prochain gardien — et que le temps presse, car le son s'affaiblit de jour en jour.",
		],
		"marais_korrigans": [
			"Les korrigans de %s ont cesse leurs farces habituelles. Depuis une semaine, ils restent immobiles a la surface des eaux, le regard fixe vers le nord. Les anciens n'ont jamais vu cela. Quelque chose de puissant remue dans les profondeurs du marais, et les petits gardiens semblent attendre que quelqu'un vienne repondre a l'appel.",
		],
		"collines_dolmens": [
			"Un nouveau dolmen est apparu cette nuit sur les collines de %s. Pas construit — apparu, comme pousse du sol. La terre autour est encore chaude. Les inscriptions sur ses flancs parlent d'un chemin qui ne s'ouvrira qu'une fois, pour un seul voyageur. Le message est clair, meme si sa signification reste voilee.",
		],
		"iles_mystiques": [
			"Les ponts de lumiere qui relient les iles de %s ont change de couleur pendant la nuit — du blanc nacre au rouge sang. Les gardiens des iles n'osent plus les traverser. Un message est apparu dans le sable de la premiere ile, ecrit dans l'alphabet des arbres : 'Le Voile se dechire. Un gardien doit venir.'",
		],
	}

	var story_list: Array = backstories.get(biome_id, [
		"Les signes se multiplient a travers %s. Les druides parlent d'un desequilibre ancien, d'un chemin qui doit etre parcouru avant que tout ne bascule. Merlin a ete apercu pour la premiere fois depuis des lunes, et son regard portait l'urgence de celui qui sait. Il est temps de repondre a l'appel.",
	])
	var text: String = story_list[randi() % story_list.size()] % biome_name

	# ── Weather color (short, sets the mood) ──────────────────────────────
	var weather_mood: Dictionary = {
		"pluie": " La pluie n'a pas cesse depuis.",
		"orage": " L'orage qui menace semble confirmer l'urgence.",
		"brouillard_epais": " Depuis, un brouillard inhabituel refuse de se lever.",
		"neige": " Une neige hors saison recouvre le sentier.",
	}
	text += str(weather_mood.get(weather, ""))

	# Chapter breaks = just start and end for backstory (map draws independently).
	var chapter_breaks: Array[int] = [0]
	var main_count: int = 0
	for node in _nodes:
		if not node.get("is_detour", false):
			main_count += 1
	if main_count > 0:
		chapter_breaks.append(main_count - 1)

	return {"text": text, "chapter_breaks": chapter_breaks}
