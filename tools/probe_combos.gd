extends SceneTree
## v10.6 (user 2026-06-06) — HARNESS DE CONTRÔLE-LECTURE batch : pour plusieurs scénarios, joue
## chaque beat avec un COMBO DE 2 CARTES et capture la prose LLM RÉELLE de résolution (toujours
## générée, pas de gating). Sortie JSON → rendu HTML par tools/render_combo_report.py.
##   godot --headless --path . --script res://tools/probe_combos.gd
## But : lire d'un coup la qualité des histoires (la combinaison se reflète-t-elle ? français propre ?)
## et itérer sur le prompt. Écriture incrémentale : un JSON valide existe même si interrompu.

const RunScript := preload("res://scripts/game/merlin_run.gd")
const OUT_PATH := "C:/Users/PGNK2128/Downloads/merlin_combos_report.json"

# Scénarios testés (titre + pitch). Couvre des tons variés pour juger la généralité de la prose.
const SCENARIOS := [
	{"title": "Le Sentier des Murmures", "pitch": "Un chemin s'ouvre sous les fougères, là où nul n'a marché."},
	{"title": "La Fontaine qui Rêve", "pitch": "Sonde la source noire où dorment les visages."},
	{"title": "Le Rite sans Fin", "pitch": "Interromps le rite que nul ne sait plus arrêter."},
]


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
		while not mn.is_ready() and (Time.get_ticks_msec() - t0) < 90000:
			await create_timer(0.2).timeout
		llm_ready = mn.is_ready()
	print("[COMBOS] llm_ready=%s" % str(llm_ready))

	var out: Dictionary = {
		"generated_at": Time.get_datetime_string_from_system(),
		"llm_ready": llm_ready,
		"model": (mn.model_info() if (mn != null and llm_ready) else {}),
		"rule": "combo de 2 cartes ; 2 tags requis/beat ; prose LLM toujours generee",
		"status": "interrupted",
		"scenarios": [],
	}
	if sc == null:
		_write(out)
		quit()
		return

	for scen in SCENARIOS:
		var scen_out: Dictionary = {"title": str(scen["title"]), "pitch": str(scen["pitch"]), "beats": []}
		out["scenarios"].append(scen_out)
		var run: Node = RunScript.new()
		var skel: Dictionary = sc.build_skeleton(str(scen["title"]), str(scen["pitch"]))
		run.new_run(skel)
		sc.invalidate_resolution()

		var guard: int = 0
		while not run.ended and guard < 12:
			guard += 1
			var beat: Dictionary = run.current_beat()
			var situ: Dictionary = sc.build_situation(beat)
			var required: Array = situ.get("required_tags", [])
			var combo: Array = _choose_two(run.hand, required)
			var res: Dictionary = MerlinResolution.resolve(required, combo, [])
			var fallback: String = sc.fallback_resolution(str(res.get("degree", "reussite")))
			var llm_reso: String = ""
			if llm_ready:
				llm_reso = await sc.narrate_resolution(situ, combo, res)  # v10.6 : toujours LLM
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
			print("[COMBOS] %s beat %d (%s) llm=%d" % [str(scen["title"]), run.beat_index + 1, str(situ.get("type", "")), llm_reso.length()])
			_write(out)  # incrémental
			run.play_and_discard(combo)
			run.apply_resolution(res)
			if not run.ended:
				run.advance_beat()
				sc.invalidate_resolution()
		run.free()

	out["status"] = "complete"
	_write(out)
	print("[COMBOS] DONE -> %s" % OUT_PATH)
	quit()


# Choisit EXACTEMENT 2 cartes (geste canonique v10.6) : la meilleure couvrant le tag 1, puis la
# meilleure couvrant le tag 2 (distincte). Fallback : 2 premières cartes de la main.
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
	# Complète à 2 si besoin (combo canonique = toujours 2 cartes).
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
		print("[COMBOS] ERREUR écriture %s (err %d)" % [OUT_PATH, FileAccess.get_open_error()])
