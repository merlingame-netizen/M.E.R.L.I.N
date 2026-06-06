extends SceneTree
## GOAL session — Simulateur de BALANCE (logique pure, ZÉRO LLM). Lance N runs avec un joueur
## "correct" (meilleur combo 2 cartes par couverture) et un joueur "aléatoire", puis agrège la
## distribution des degrés, le taux de mort/corruption/complétion, et les moyennes PV/Corruption/beats.
## But : objectiver l'axe ÉQUILIBRAGE de la boucle /goal (2026-06-07).
##   godot --headless --path . --script res://tools/goal_balance_sim.gd
## N'attend PAS le modèle (is_ready ignoré) : exerce MerlinRun + MerlinResolution + MerlinTags + MerlinCard.

const RunScript := preload("res://scripts/game/merlin_run.gd")
const Scenario := preload("res://scripts/llm/merlin_scenario.gd")
const OUT_PATH := "C:/Users/PGNK2128/Downloads/goal_balance_sim.json"
const N_RUNS := 200


func _init() -> void:
	_run()


func _build_skeleton() -> Dictionary:
	# Squelette canonique 5 beats (cf. probe_run / build_skeleton réel).
	var beats: Array = []
	var types: Array = ["Exploration", "Rencontre", "Epreuve", "Dilemme", "Climax"]
	var diffs: Array = [1, 2, 2, 2, 3]
	for i in types.size():
		beats.append({"n": i + 1, "type": types[i], "difficulte": diffs[i]})
	return {"title": "BalanceSim", "synopsis": "Test", "beats": beats, "total": beats.size()}


func _choose_two(hand: Array, required: Array, random_player: bool) -> Array:
	# Joueur "correct" : 2 meilleures cartes par couverture des tags requis.
	# Joueur "aléatoire" : 2 cartes au hasard (borne basse de skill).
	if random_player:
		var pool: Array = hand.duplicate()
		pool.shuffle()
		return pool.slice(0, min(2, pool.size()))
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


func _simulate_cohort(label: String, random_player: bool) -> Dictionary:
	var degrees: Dictionary = {"echec": 0, "partiel": 0, "reussite": 0, "eclatante": 0}
	var ends: Dictionary = {"accomplissement": 0, "mort": 0, "corrompu": 0, "": 0}
	var sum_integrite: int = 0
	var sum_corruption: int = 0
	var sum_beats: int = 0
	var n_total_beats: int = 0
	for _i in N_RUNS:
		var run: Node = RunScript.new()
		run.new_run(_build_skeleton())
		var guard: int = 0
		while not run.ended and guard < 30:
			guard += 1
			var beat: Dictionary = run.current_beat()
			var btype: String = str(beat.get("type", "Exploration"))
			var required: Array = Scenario.TYPE_TAG_BIAS.get(btype, ["Sens"]).duplicate()
			required.shuffle()
			required = required.slice(0, 2)  # v10.6 : 2 tags requis/beat
			var combo: Array = _choose_two(run.hand, required, random_player)
			var res: Dictionary = MerlinResolution.resolve(required, combo, [])
			var deg: String = str(res.get("degree", "reussite"))
			if degrees.has(deg):
				degrees[deg] += 1
			n_total_beats += 1
			run.play_and_discard(combo)
			run.apply_resolution(res)
			if not run.ended:
				run.advance_beat()
		var et: String = str(run.end_type)
		if ends.has(et):
			ends[et] += 1
		else:
			ends[et] = 1
		sum_integrite += run.integrite
		sum_corruption += run.corruption
		sum_beats += run.beat_index + 1
		run.free()
	# Pourcentages degrés (sur l'ensemble des beats joués).
	var deg_pct: Dictionary = {}
	for k in degrees:
		deg_pct[k] = (round(float(degrees[k]) * 1000.0 / max(n_total_beats, 1)) / 10.0)
	return {
		"label": label,
		"random_player": random_player,
		"n_runs": N_RUNS,
		"degrees_count": degrees,
		"degrees_pct": deg_pct,
		"end_types": ends,
		"death_rate_pct": round(float(ends.get("mort", 0)) * 1000.0 / N_RUNS) / 10.0,
		"corrupted_rate_pct": round(float(ends.get("corrompu", 0)) * 1000.0 / N_RUNS) / 10.0,
		"completion_rate_pct": round(float(ends.get("accomplissement", 0)) * 1000.0 / N_RUNS) / 10.0,
		"avg_final_integrite": round(float(sum_integrite) * 10.0 / N_RUNS) / 10.0,
		"avg_final_corruption": round(float(sum_corruption) * 10.0 / N_RUNS) / 10.0,
		"avg_beats_survived": round(float(sum_beats) * 10.0 / N_RUNS) / 10.0,
	}


func _run() -> void:
	var out: Dictionary = {
		"generated_at": Time.get_datetime_string_from_system(),
		"n_runs_per_cohort": N_RUNS,
		"note": "logique pure (zero LLM) ; required=2 tags/beat ; skeleton 5 beats diff 1/2/2/2/3",
		"cohorts": [],
	}
	out["cohorts"].append(_simulate_cohort("joueur correct (meilleur combo)", false))
	out["cohorts"].append(_simulate_cohort("joueur aleatoire (borne basse)", true))
	var f: FileAccess = FileAccess.open(OUT_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	# Résumé console.
	for co in out["cohorts"]:
		print("[BALANCE] %s : mort=%.1f%% corrompu=%.1f%% complet=%.1f%% | PVmoy=%.1f Corrmoy=%.1f beatsMoy=%.1f" % [
			co["label"], co["death_rate_pct"], co["corrupted_rate_pct"], co["completion_rate_pct"],
			co["avg_final_integrite"], co["avg_final_corruption"], co["avg_beats_survived"]])
		print("[BALANCE]   degres%% : echec=%.1f partiel=%.1f reussite=%.1f eclatante=%.1f" % [
			co["degrees_pct"]["echec"], co["degrees_pct"]["partiel"], co["degrees_pct"]["reussite"], co["degrees_pct"]["eclatante"]])
	print("[BALANCE] DONE -> %s" % OUT_PATH)
	quit()
