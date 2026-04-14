## ═══════════════════════════════════════════════════════════════════════════════
## LLM Adapter — Map Skeleton Prompt Builder
## ═══════════════════════════════════════════════════════════════════════════════
## Builds system + user prompts for pre-run skeleton generation.
## The LLM produces a JSON graph of nodes (main path + detours).
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted
class_name LlmAdapterMapPrompt


## Build the system prompt for skeleton generation.
static func build_system_prompt() -> String:
	return (
		"Tu es le Maitre de l'Ogham, architecte des chemins de Broceliande.\n"
		+ "Tu generes le SQUELETTE d'un scenario sous forme de graphe JSON.\n"
		+ "Tu ne generes PAS le contenu des cartes — seulement la structure du chemin.\n"
		+ "Chaque noeud = 1 lieu/evenement que le joueur traversera.\n"
		+ "Les detours sont optionnels : le joueur peut les ignorer.\n\n"
		+ "TYPES DE NOEUDS DISPONIBLES:\n"
		+ "- narrative : scene de recit (le plus frequent)\n"
		+ "- event : evenement special (combat, enigme, apparition)\n"
		+ "- promise : le joueur fait un serment a une faction\n"
		+ "- rest : lieu de repos (soin)\n"
		+ "- merchant : marchand (echange Anam/objets)\n"
		+ "- mystery : lieu mysterieux (recompense aleatoire)\n"
		+ "- merlin : apparition de Merlin (UNIQUEMENT en dernier noeud)\n"
		+ "- detour_start : entree dans un chemin optionnel\n"
		+ "- detour_end : sortie du detour, reconnecte au chemin principal\n\n"
		+ "REGLES STRUCTURELLES:\n"
		+ "- Premier noeud : TOUJOURS type 'narrative' (introduction)\n"
		+ "- Dernier noeud : TOUJOURS type 'merlin' (conclusion)\n"
		+ "- Noeud a ~50% du parcours : type 'rest' ou 'merchant'\n"
		+ "- Chaque detour_start DOIT avoir un detour_end qui reconnecte au chemin principal\n"
		+ "- Un detour contient 2-4 noeuds (start inclus, end inclus)\n"
		+ "- Les detours offrent une recompense (ogham_hint, anam_bonus, lore_fragment, reputation_boost)\n"
		+ "- Les tons suivent un arc : mystere → exploration → tension → climax → resolution → sagesse\n\n"
		+ "SORTIE : JSON strict. Pas de commentaires. Pas de markdown. Pas de ```.\n"
		+ "Respecte EXACTEMENT le schema fourni dans le prompt utilisateur."
	)


## Build the user prompt with all context for skeleton generation.
## context keys: biome_id, ogham_id, faction_rep, previous_runs, festival, trust_tier, trust_value
static func build_user_prompt(context: Dictionary) -> String:
	var biome_id: String = str(context.get("biome_id", "foret_broceliande"))
	var biome_data: Dictionary = MerlinConstants.BIOMES.get(biome_id, {})
	var biome_name: String = str(biome_data.get("name", biome_id.replace("_", " ").capitalize()))
	var season: String = str(biome_data.get("season", "printemps"))

	# Node range from constants.
	var ranges: Dictionary = MerlinConstants.BIOME_NODE_RANGES.get(biome_id, {"main_min": 10, "main_max": 15, "detours_min": 1, "detours_max": 2})
	var main_min: int = int(ranges["main_min"])
	var main_max: int = int(ranges["main_max"])
	var det_min: int = int(ranges["detours_min"])
	var det_max: int = int(ranges["detours_max"])

	# Reputation modifier.
	var faction_biome: String = str(biome_data.get("arc_condition_faction", "druides"))
	var rep_value: int = int(context.get("faction_rep", 20))
	if rep_value >= MerlinConstants.MAP_REP_SECRET_THRESHOLD:
		main_max = maxi(main_min, main_max - MerlinConstants.MAP_REP_SECRET_NODES)
		det_max += 1  # Secret detour bonus
	elif rep_value >= MerlinConstants.MAP_REP_SHORTCUT_THRESHOLD:
		main_max = maxi(main_min, main_max - MerlinConstants.MAP_REP_SHORTCUT_NODES)

	# Ogham info.
	var ogham_id: String = str(context.get("ogham_id", ""))
	var ogham_name: String = ""
	var ogham_effect: String = ""
	if ogham_id != "" and MerlinConstants.OGHAM_FULL_SPECS.has(ogham_id):
		var ogham: Dictionary = MerlinConstants.OGHAM_FULL_SPECS[ogham_id]
		ogham_name = str(ogham.get("name", ogham_id))
		ogham_effect = str(ogham.get("description", ""))

	# Previous runs history.
	var previous_runs: int = int(context.get("previous_runs", 0))
	var explored_detours: Array = context.get("explored_detours", [])

	# Weather (pre-selected by caller).
	var weather: String = str(context.get("weather", "clair"))
	var weather_data: Dictionary = MerlinConstants.WEATHER_TYPES.get(weather, {})
	var weather_tone: String = str(weather_data.get("tone", "serein"))

	# Festival.
	var festival: String = str(context.get("festival", ""))

	# Trust.
	var trust_tier: int = int(context.get("trust_tier", 0))
	var trust_value: int = int(context.get("trust_value", 50))

	# Arc info — evaluate arc_condition_type correctly (bible v2.4 s.8).
	var arc_name: String = str(biome_data.get("arc", ""))
	var arc_cards: int = int(biome_data.get("arc_cards", 3))
	var arc_condition_type: String = str(biome_data.get("arc_condition_type", "faction_rep"))
	var arc_condition_value: int = int(biome_data.get("arc_condition_value", 30))
	var arc_actual_value: int = rep_value  # default: faction_rep
	if arc_condition_type == "runs_in_biome":
		arc_actual_value = int(context.get("previous_runs", 0))
	elif arc_condition_type == "fins_vues":
		arc_actual_value = int(context.get("fins_vues", 0))
	elif arc_condition_type == "oghams_owned":
		arc_actual_value = int(context.get("oghams_owned", 0))
	var arc_unlocked: bool = arc_actual_value >= arc_condition_value

	# Build prompt.
	var prompt: String = ""
	prompt += "Genere le squelette du scenario pour le biome \"%s\".\n\n" % biome_name
	prompt += "PARAMETRES:\n"
	prompt += "- Chemin principal : %d-%d noeuds\n" % [main_min, main_max]
	prompt += "- Detours optionnels : %d-%d (chacun 2-4 noeuds)\n" % [det_min, det_max]
	prompt += "- Saison : %s | Meteo : %s (ton dominant : %s)\n" % [season, weather, weather_tone]

	if ogham_name != "":
		prompt += "- Ogham actif : %s (%s)\n" % [ogham_name, ogham_effect]

	prompt += "\nCONTEXTE JOUEUR:\n"
	prompt += "- Reputation %s : %d/100" % [faction_biome, rep_value]
	if rep_value >= MerlinConstants.MAP_REP_SECRET_THRESHOLD:
		prompt += " (HONORE — integre un chemin secret avec recompense rare)\n"
	elif rep_value >= MerlinConstants.MAP_REP_SHORTCUT_THRESHOLD:
		prompt += " (SYMPATHISANT — raccourci disponible)\n"
	else:
		prompt += "\n"
	prompt += "- Runs precedents dans ce biome : %d\n" % previous_runs
	if not explored_detours.is_empty():
		prompt += "- Detours deja explores : %s (propose des chemins DIFFERENTS)\n" % str(explored_detours)
	prompt += "- Confiance Merlin : T%d (%d/100)\n" % [trust_tier, trust_value]

	if festival != "":
		prompt += "- Festival actif : %s (+1 detour thematique bonus)\n" % festival

	if arc_unlocked:
		prompt += "\nARC NARRATIF : \"%s\" (debloque, %d cartes d'arc a integrer)\n" % [arc_name, arc_cards]
	else:
		prompt += "\nARC NARRATIF : \"%s\" (verrouille, %s %d < %d)\n" % [arc_name, arc_condition_type, arc_actual_value, arc_condition_value]

	prompt += "\nSCHEMA JSON ATTENDU:\n"
	prompt += _json_schema_example(biome_id, season, weather)

	return prompt


## Minimal JSON schema example for the LLM.
static func _json_schema_example(biome: String, season: String, weather: String) -> String:
	return (
		'{"scenario_title":"...","scenario_synopsis":"...2 phrases max...",'
		+ '"biome":"%s","season":"%s","weather":"%s",' % [biome, season, weather]
		+ '"total_main_nodes":N,"total_detour_nodes":N,"estimated_cards":N,'
		+ '"nodes":[{"id":"n0","type":"narrative","label":"...","tone":"mystere",'
		+ '"next":["n1"],"is_detour":false,"detour_entry":null,"floor":0},'
		+ '{"id":"n1","type":"event","label":"...","tone":"tension",'
		+ '"next":["n2"],"is_detour":false,"detour_entry":"d0","floor":1},'
		+ '{"id":"d0","type":"detour_start","label":"...","tone":"emerveillement",'
		+ '"next":["d1"],"is_detour":true,"reward_hint":"ogham_hint","floor":1},'
		+ '{"id":"d1","type":"detour_end","label":"...","tone":"soulagement",'
		+ '"next":["n2"],"is_detour":true,"floor":1},'
		+ '...,'
		+ '{"id":"nN","type":"merlin","label":"...","tone":"sagesse",'
		+ '"next":[],"is_detour":false,"floor":N}],'
		+ '"arc_events":[{"node_id":"n4","arc_type":"intro_arc","arc_name":"..."}],'
		+ '"metadata":{"difficulty_modifier":0,"faction_shortcuts_applied":0,'
		+ '"previous_runs_in_biome":0,"active_festival":null}}'
	)
