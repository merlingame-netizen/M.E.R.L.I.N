extends SceneTree
## Capture de TOUTE la prose d'un run 5 beats (procédurale + LLM réel) → JSON, pour rapport HTML.
##   godot --headless --path . --script res://tools/probe_prose.gd
## Exerce le vrai pipeline MerlinScenario + MerlinNative (Gemma) + MerlinResolution (synergie).
## Robuste : si le LLM n'est pas prêt / échoue, ne capture que le procédural (toujours un JSON écrit).

const RunScript := preload("res://scripts/game/merlin_run.gd")
const OUT_PATH := "C:/Users/PGNK2128/Downloads/merlin_prose_run.json"


func _init() -> void:
	_run()


func _await_node(path: String, max_ms: int) -> Node:
	var t0: int = Time.get_ticks_msec()
	var n: Node = root.get_node_or_null(path)
	while n == null and (Time.get_ticks_msec() - t0) < max_ms:
		await create_timer(0.05).timeout
		n = root.get_node_or_null(path)
	return n


func _run() -> void:
	var sc: Node = await _await_node("MerlinScenario", 10000)
	var mn: Node = await _await_node("MerlinNative", 10000)

	# v11-N1 (R140) — GATE PROSE déterministe (constantes seules, ZÉRO LLM) : la narration en beat est
	# au « Vous » présent, jamais 3e personne « le Voyageur », jamais « que faire » ; chaque fallback de
	# résolution s'ouvre sur une action en [i]…[/i]. Toute entorse → quit(2) immédiat (gate rapide).
	if sc != null:
		var viol: Array = _prose_gate(sc)
		if viol.is_empty():
			print("[PROSE] CATALOG_GATE pass (2e personne, [i] action, zéro filler)")
		else:
			for v in viol:
				print("[PROSE] CATALOG_GATE FAIL — %s" % str(v))
			print("[PROSE] CATALOG_GATE : %d violation(s)" % viol.size())
			quit(2)
			return

	# Attente du chargement du modèle (TEMPS réel, pas frames — headless tourne vite). Max 90s.
	var llm_ready: bool = false
	if mn != null:
		var t0: int = Time.get_ticks_msec()
		while not mn.is_ready() and (Time.get_ticks_msec() - t0) < 90000:
			await create_timer(0.2).timeout
		llm_ready = mn.is_ready()
	print("[PROSE] llm_ready=%s" % str(llm_ready))

	var out: Dictionary = {
		"generated_at": Time.get_datetime_string_from_system(),
		"llm_ready": llm_ready,
		"model": (mn.model_info() if (mn != null and llm_ready) else {}),
		"system_prefix": (str(sc.SYSTEM_PREFIX) if sc != null else ""),
		"status": "interrupted",
		"intro": {}, "beats": [], "epilogue": {}, "final": {},
	}

	if sc == null:
		_write(out)
		quit()
		return

	# Catalogue procédural COMPLET (toutes les variantes authored) — instantané, sans LLM.
	# Garantit « toute la prose » dans le rapport même si le LLM stalle.
	out["catalog"] = {
		"situations": sc.SITU_FALLBACKS_BY_BIOME,
		"resolutions": sc.RESO_FALLBACKS,
		"epilogues": {
			"accomplissement": sc.fallback_epilogue("accomplissement"),
			"mort": sc.fallback_epilogue("mort"),
			"corrompu": sc.fallback_epilogue("corrompu"),
		},
	}
	_write(out)
	print("[PROSE] catalogue procédural écrit")

	var run: Node = RunScript.new()
	var title: String = "Le Sentier des Murmures"
	var pitch: String = "Un chemin s'ouvre sous les fougères, là où nul n'a marché."
	var skel: Dictionary = sc.build_skeleton(title, pitch)
	run.new_run(skel)

	# --- Intro de quête ---
	var intro_data: Dictionary = sc.build_intro(skel)
	var intro_llm: String = ""
	if llm_ready:
		intro_llm = await sc.narrate_intro(skel)
	out["intro"] = {
		"title": title,
		"objectif": str(intro_data.get("objectif", "")),
		"procedural": str(intro_data.get("intro", "")),
		"llm": intro_llm,
	}
	_write(out)  # écriture incrémentale : on ne perd jamais ce qui est déjà capturé
	print("[PROSE] intro ok (llm=%d)" % intro_llm.length())

	# --- Beats : situation (procédurale) + résolution (procédurale + LLM combinaison) ---
	var guard: int = 0
	var prose_quest: int = 0  # v10.14 (review HIGH) : bascule le fil narratif aux frontières de quête
	while not run.ended and guard < 20:
		guard += 1
		var beat: Dictionary = run.current_beat()
		if int(beat.get("quest", 0)) != prose_quest:
			prose_quest = int(beat.get("quest", 0))
			sc.begin_quest(skel, prose_quest)  # l'arc de la nouvelle quête remplace celui de la précédente
		var situ: Dictionary = sc.build_situation(beat)
		var required: Array = situ.get("required_tags", [])
		var combo: Array = _choose(run.hand, required)
		var res: Dictionary = MerlinResolution.resolve(required, combo, [])
		var fallback: String = sc.fallback_resolution(str(res.get("degree", "reussite")))
		var llm_reso: String = ""
		# Miroir du jeu : LLM seulement aux moments forts (Climax / éclatante) → capture fiable.
		if llm_ready and sc.is_strong_moment(str(situ.get("type", "")), str(res.get("degree", ""))):
			llm_reso = await sc.narrate_resolution(situ, combo, res)
		var combo_arr: Array = []
		for c in combo:
			combo_arr.append({"name": str(c.card_name), "evocation": str(c.evocation), "tags": c.tags})
		out["beats"].append({
			"n": run.beat_index + 1,
			"type": str(situ.get("type", "")),
			"difficulte": int(beat.get("difficulte", 1)),
			"required": required,
			"situation": str(situ.get("narration", "")),
			"combo": combo_arr,
			"degree": str(res.get("degree", "")),
			"label": str(res.get("label", "")),
			"synergy": int(res.get("synergy", 0)),
			"resolution_procedural": fallback,
			"resolution_llm": llm_reso,
			"integrite": run.integrite,
			"corruption": run.corruption,
		})
		out["final"] = {"integrite": run.integrite, "corruption": run.corruption, "beats": run.beat_index + 1}
		print("[PROSE] beat %d ok (llm=%d)" % [run.beat_index + 1, llm_reso.length()])
		_write(out)  # écriture incrémentale par beat (épilogue/final toujours valides)
		run.play_and_discard(combo)
		run.apply_resolution(res)
		if not run.ended:
			run.advance_beat()

	# --- Épilogue ---
	var epi_fb: String = sc.fallback_epilogue(run.end_type)
	var epi_llm: String = ""
	if llm_ready:
		epi_llm = await sc.narrate_epilogue(run.end_type, run.to_state_dict())
	out["epilogue"] = {"end_type": str(run.end_type), "procedural": epi_fb, "llm": epi_llm}
	out["final"] = {"integrite": run.integrite, "corruption": run.corruption, "beats": run.beat_index}
	out["status"] = "complete"
	_write(out)
	print("[PROSE] DONE -> %s (llm_ready=%s, beats=%d)" % [OUT_PATH, str(llm_ready), run.beat_index])
	run.free()
	quit()


func _write(out: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	else:
		print("[PROSE] ERREUR écriture %s (err %d)" % [OUT_PATH, FileAccess.get_open_error()])


# v11-N1 (R140) — vérifie les banques de prose (constantes) : retourne la liste des violations (vide = ok).
# N2a (2026-07-05) — étendu : banques BIOME-aware (situations + arcs + conséquences par biome), résolution
# COMPOSÉE (actions par registre commençant par « Vous », conséquences non-vides), et check de compo
# falaises (zéro mot forestier + « [i]Vous » + mot de biome). Reste DÉTERMINISTE (constantes seules).
func _prose_gate(sc: Node) -> Array:
	var viol: Array = []
	var banned: Array = ["le Voyageur", "Le Voyageur", "se demandait", "que faire", "Que décida", "que décida", "décidez-vous", "vous demandez"]
	# Mots FORESTIERS interdits dans les banques FALAISES (N2a check a). Minuscule pour comparaison insensible.
	var foret_words: Array = ["forêt", "foret", "bois", "arbre", "sous les arbres", "fougère", "mousse", "sentier sous"]
	# 1) SYSTEM_PREFIX : plus de 3e personne « Voyageur » ni de directive « 3e PERSONNE ».
	var sysp: String = str(sc.SYSTEM_PREFIX)
	if sysp.find("Voyageur") != -1 or sysp.find("3e PERSONNE") != -1:
		viol.append("SYSTEM_PREFIX contient encore 'Voyageur' ou '3e PERSONNE'")
	# 2) Situations biome-aware (SITU_FALLBACKS_BY_BIOME + FALLBACK_ARCS_BY_BIOME) : aucun filler,
	#    aucune 3e personne héritée ; et pour les banques FALAISES, zéro mot forestier (check a).
	for biome_key in sc.SITU_FALLBACKS_BY_BIOME.keys():
		var situ_pools: Array = []
		for p in sc.SITU_FALLBACKS_BY_BIOME[biome_key].values():
			situ_pools.append(p)
		for arc in sc.FALLBACK_ARCS_BY_BIOME.get(biome_key, []):
			situ_pools.append(arc)
		for pool in situ_pools:
			for line in pool:
				var s: String = str(line)
				for b in banned:
					if s.find(str(b)) != -1:
						viol.append("situation [%s] « %s… » contient '%s'" % [str(biome_key), s.substr(0, 28), str(b)])
				if str(biome_key) == "falaises":
					var sl: String = s.to_lower()
					for fw in foret_words:
						if sl.find(str(fw)) != -1:
							viol.append("situation FALAISES « %s… » contient le mot forestier '%s'" % [s.substr(0, 28), str(fw)])
	# 3) Filet neutre RESO_FALLBACKS + _LONG : action en [i]…[/i], commence par [i]Vous, balises équilibrées.
	var reso_pools: Array = []
	for p2 in sc.RESO_FALLBACKS.values():
		reso_pools.append(p2)
	for p3 in sc.RESO_FALLBACKS_LONG.values():
		reso_pools.append(p3)
	for pool2 in reso_pools:
		for line2 in pool2:
			var r: String = str(line2)
			for b2 in banned:
				if r.find(str(b2)) != -1:
					viol.append("résolution « %s… » contient '%s'" % [r.substr(0, 28), str(b2)])
			if not r.begins_with("[i]Vous"):
				viol.append("résolution « %s… » ne commence pas par '[i]Vous'" % r.substr(0, 28))
			if r.count("[i]") != r.count("[/i]") or r.count("[i]") == 0:
				viol.append("résolution « %s… » : balises [i]/[/i] déséquilibrées" % r.substr(0, 28))
	# 4) Actions par registre (N2a check b) : chaque variante commence par « Vous », pas de filler.
	for reg_key in sc.RESO_ACTION_BY_REGISTRE.keys():
		for aline in sc.RESO_ACTION_BY_REGISTRE[reg_key]:
			var a: String = str(aline)
			if not a.begins_with("Vous"):
				viol.append("action [%s] « %s… » ne commence pas par 'Vous'" % [str(reg_key), a.substr(0, 28)])
			for b3 in banned:
				if a.find(str(b3)) != -1:
					viol.append("action [%s] « %s… » contient '%s'" % [str(reg_key), a.substr(0, 28), str(b3)])
	# 5) Conséquences par (degré × biome) (N2a check c) : chacune NON-VIDE ; falaises = zéro mot forestier.
	for deg_key in sc.RESO_CONSEQ_BY_DEGREE_BIOME.keys():
		for cbiome in sc.RESO_CONSEQ_BY_DEGREE_BIOME[deg_key].keys():
			var cpool: Array = sc.RESO_CONSEQ_BY_DEGREE_BIOME[deg_key][cbiome]
			if cpool.is_empty():
				viol.append("conséquence [%s|%s] : pool VIDE" % [str(deg_key), str(cbiome)])
			for cline in cpool:
				var cs: String = str(cline)
				if cs.strip_edges().is_empty():
					viol.append("conséquence [%s|%s] : entrée vide" % [str(deg_key), str(cbiome)])
				if str(cbiome) == "falaises":
					var csl: String = cs.to_lower()
					for fw2 in foret_words:
						if csl.find(str(fw2)) != -1:
							viol.append("conséquence FALAISES [%s] « %s… » contient le mot forestier '%s'" % [str(deg_key), cs.substr(0, 28), str(fw2)])
	# 6) Compo intégrée (N2a check d) : fallback_resolution(degré, "", [carte FORCE], "falaises") produit
	#    « [i]Vous … [/i] » + ≥1 mot de biome falaises. Carte factice duck-typée (archetype()="Offensif"→FORCE).
	var fake_force: Object = _FakeCard.new("Offensif")
	var sea_words: Array = ["mer", "vent", "sel", "écume", "roche", "phare", "falaise", "marée", "embrun", "côte", "vague"]
	for dtest in ["echec", "partiel", "reussite", "eclatante"]:
		var comp: String = str(sc.fallback_resolution(dtest, "", [fake_force], "falaises"))
		if not comp.begins_with("[i]Vous"):
			viol.append("compo falaises [%s] « %s… » ne commence pas par '[i]Vous'" % [dtest, comp.substr(0, 28)])
		if comp.find("[/i]") == -1:
			viol.append("compo falaises [%s] : pas de balise fermante [/i]" % dtest)
		var cl: String = comp.to_lower()
		var has_sea: bool = false
		for sw in sea_words:
			if cl.find(str(sw)) != -1:
				has_sea = true
				break
		if not has_sea:
			viol.append("compo falaises [%s] « …%s » ne contient AUCUN mot de biome falaises" % [dtest, comp.substr(maxi(0, comp.length() - 40))])
	return viol


# N2a — carte factice minimale duck-typée pour la compo du gate : expose archetype() (le seul contrat
# lu par _dominant_registre). Évite d'instancier MerlinCard (leçon soak : pas de dépendance de classe).
class _FakeCard:
	var _arch: String = "Offensif"
	func _init(arch: String) -> void:
		_arch = arch
	func archetype() -> String:
		return _arch


func _choose(hand: Array, required: Array) -> Array:
	var scored: Array = []
	for card in hand:
		var cov: Dictionary = MerlinTags.coverage(required, card.tags)
		scored.append({"card": card, "score": cov["covered"].size()})
	scored.sort_custom(func(a, b): return a["score"] > b["score"])
	var combo: Array = []
	for i in min(3, scored.size()):
		if scored[i]["score"] > 0 or combo.is_empty():
			combo.append(scored[i]["card"])
	return combo
