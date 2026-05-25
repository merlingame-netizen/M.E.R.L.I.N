extends SceneTree
## Probe logique de run (sans LLM) — prouve que la boucle se termine TOUJOURS (DoD R93).
## Exerce MerlinRun + MerlinResolution + MerlinCard + MerlinTags de bout en bout.
##   Godot --headless --script res://tools/probe_run.gd

const RunScript := preload("res://scripts/game/merlin_run.gd")
const Scenario := preload("res://scripts/llm/merlin_scenario.gd")

func _init() -> void:
	_run_case("REUSSITE (joue la meilleure carte)", false)
	_run_case("ECHEC FORCE (mauvaises cartes)", true)
	print("[PROBE_RUN] DONE")
	quit()


func _build_skeleton() -> Dictionary:
	var beats: Array = []
	var types: Array = ["Exploration", "Rencontre", "Epreuve", "Dilemme", "Climax"]
	var diffs: Array = [1, 2, 2, 2, 3]
	for i in types.size():
		beats.append({"n": i + 1, "type": types[i], "difficulte": diffs[i]})
	return {"title": "Probe", "synopsis": "Test", "beats": beats, "total": beats.size()}


func _run_case(label: String, force_fail: bool) -> void:
	var run: Node = RunScript.new()
	run.new_run(_build_skeleton())
	var guard: int = 0
	while not run.ended and guard < 50:
		guard += 1
		var beat: Dictionary = run.current_beat()
		var btype: String = str(beat.get("type", "Exploration"))
		var diff: int = int(beat.get("difficulte", 1))
		var required: Array = Scenario.TYPE_TAG_BIAS.get(btype, ["Sens"]).slice(0, diff)
		var combo: Array = _choose(run.hand, required, force_fail)
		var res: Dictionary = MerlinResolution.resolve(required, combo, [])
		run.play_and_discard(combo)
		run.apply_resolution(res)
		print("[PROBE_RUN] %s | beat %d %s diff%d | req=%s | %s | PV=%d Corr=%d" % [
			label, run.beat_index + 1, btype, diff, str(required), str(res["label"]), run.integrite, run.corruption])
		if not run.ended:
			run.advance_beat()
	print("[PROBE_RUN] %s => FIN: %s (PV=%d Corr=%d, beats=%d)" % [label, run.end_type, run.integrite, run.corruption, run.beat_index])
	run.free()


func _choose(hand: Array, required: Array, force_fail: bool) -> Array:
	var scored: Array = []
	for card in hand:
		var cov: Dictionary = MerlinTags.coverage(required, card.tags)
		scored.append({"card": card, "score": cov["covered"].size()})
	scored.sort_custom(func(a, b): return a["score"] > b["score"])
	var combo: Array = []
	if force_fail:
		scored.reverse()
		for i in min(2, scored.size()):
			combo.append(scored[i]["card"])
	else:
		for i in min(3, scored.size()):
			if scored[i]["score"] > 0 or combo.is_empty():
				combo.append(scored[i]["card"])
	return combo
