extends SceneTree
## probe_scenario.gd (user 2026-06-07) — Génère UN scénario COMPLET via le moteur gemma du jeu :
## arc narratif LLM (5 situations liées) + issue LLM par beat (combo de 2 cartes). Sortie JSON au
## format render_combo_report.py → merlin_combos_report.html (contrôle de la prose attendue).
##   "C:/.../Godot_v4.5.1-stable_win64_console.exe" --headless --path . --script res://tools/probe_scenario.gd > log.txt 2>&1
## (REDIRECT vers fichier obligatoire : pas de pipe — SIGPIPE tue Godot ; cf. leçon #19/#117.)

const RunScript := preload("res://scripts/game/merlin_run.gd")
const OUT_PATH := "C:/Users/PGNK2128/Downloads/merlin_combos_report.json"

const TITLE := "Le Sentier des Murmures"
const PITCH := "Un chemin s'ouvre sous les fougères, là où nul n'a marché."


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

	var llm_ready: bool = false
	if mn != null:
		var t0: int = Time.get_ticks_msec()
		while not mn.is_ready() and (Time.get_ticks_msec() - t0) < 120000:
			await create_timer(0.2).timeout
		llm_ready = mn.is_ready()
	print("[SCEN] llm_ready=%s" % str(llm_ready))

	var out: Dictionary = {
		"generated_at": Time.get_datetime_string_from_system(),
		"llm_ready": llm_ready,
		"model": (mn.model_info() if (mn != null and llm_ready) else {}),
		"rule": "1 scenario gemma : arc LLM (5 situations liees) + issue LLM par beat (combo 2 cartes)",
		"status": "interrupted",
		"scenarios": [],
	}
	if sc == null:
		_write(out)
		quit()
		return

	# 1) Squelette + ARC narratif LLM. On pré-pick les 2 tags par beat (comme prepare_arc) pour que la
	# scene soit ecrite AUTOUR (scene ⇄ tags alignes), puis on les stocke dans arc_tags.
	var skel: Dictionary = sc.build_skeleton(TITLE, PITCH)
	var picked: Array = []
	for b in skel.get("beats", []):
		picked.append(sc._pick_tags(str(b.get("type", "Exploration")), int(b.get("difficulte", 1))))
	var arc: Array = []
	if llm_ready:
		arc = await sc.narrate_arc(skel, picked)
	var arc_source: String = "llm"
	if arc.size() == 5:
		sc._run_thread["arc"] = arc
		sc._run_thread["arc_tags"] = picked
	else:
		arc_source = "fallback"  # build_skeleton a deja pose arc + arc_tags alignes
		arc = sc._run_thread.get("arc", [])
	sc._run_thread["arc_locked"] = false
	print("[SCEN] arc source=%s (%d etapes)" % [arc_source, arc.size()])

	var run: Node = RunScript.new()
	run.new_run(skel)
	sc.invalidate_resolution()

	var scen_out: Dictionary = {"title": TITLE, "pitch": PITCH, "arc_source": arc_source, "beats": []}
	out["scenarios"].append(scen_out)

	# 2) Beats : situation (= etape de l'arc) + issue LLM (toujours generee).
	var guard: int = 0
	while not run.ended and guard < 12:
		guard += 1
		var beat: Dictionary = run.current_beat()
		var situ: Dictionary = sc.build_situation(beat)
		var required: Array = situ.get("required_tags", [])
		var combo: Array = _choose_two(run.hand, required)
		var res: Dictionary = MerlinResolution.resolve(required, combo, [])
		var fallback: String = sc.fallback_resolution(str(res.get("degree", "reussite")), str(situ.get("type", "")))
		var llm_reso: String = ""
		if llm_ready:
			llm_reso = await sc.narrate_resolution(situ, combo, res)
		var combo_arr: Array = []
		for c in combo:
			combo_arr.append({
				"name": str(c.card_name), "evocation": str(c.evocation),
				"tags": c.tags, "archetype": c.archetype(), "rarity": str(c.rarity),
			})
		scen_out["beats"].append({
			"n": run.beat_index + 1,
			"type": str(situ.get("type", "")),
			"required": required,
			"situation": str(situ.get("narration", "")),
			"combo": combo_arr,
			"degree": str(res.get("degree", "")),
			"label": str(res.get("label", "")),
			"synergy": int(res.get("synergy", 0)),
			"coverage": "%d/%d" % [res["coverage"]["covered"].size(), required.size()],
			"resolution_procedural": fallback,
			"resolution_llm": llm_reso,
		})
		print("[SCEN] beat %d (%s/%s) llm=%d" % [run.beat_index + 1, str(situ.get("type", "")), str(res.get("degree", "")), llm_reso.length()])
		_write(out)  # incrémental
		run.play_and_discard(combo)
		run.apply_resolution(res)
		if not run.ended:
			run.advance_beat()
			sc.invalidate_resolution()
	run.free()

	out["status"] = "complete"
	_write(out)
	print("[SCEN] DONE -> %s" % OUT_PATH)
	quit()


func _choose_two(hand: Array, required: Array) -> Array:
	var picked: Array = []
	for req in required:
		var best: MerlinCard = null
		var best_score: int = -1
		for c in hand:
			if picked.has(c):
				continue
			var cov: Dictionary = MerlinTags.coverage([req], c.tags)
			var sc_i: int = cov["covered"].size()
			if sc_i > best_score:
				best_score = sc_i
				best = c
		if best != null:
			picked.append(best)
		if picked.size() >= 2:
			break
	for c in hand:
		if picked.size() >= 2:
			break
		if not picked.has(c):
			picked.append(c)
	return picked.slice(0, 2)


func _write(out: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	else:
		print("[SCEN] ERREUR écriture %s (err %d)" % [OUT_PATH, FileAccess.get_open_error()])
