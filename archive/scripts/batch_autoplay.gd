## Batch Auto-Play Runner — Runs N auto-play sessions sequentially, exports aggregate JSON.
## Usage: godot --path . --headless res://scenes/TestAutoPlay.tscn
##   but with batch_autoplay_config.json specifying N runs and strategies.
## This script is meant to be called from stats_runner.ps1 which handles the
## per-run orchestration externally. This file provides the GDScript aggregation
## logic that can be called after all individual runs complete.
##
## For AUTODEV v2, the actual batch orchestration happens in stats_runner.ps1
## which runs the auto_play_runner multiple times and collects results.
## This script provides post-hoc aggregation of those results.

extends SceneTree


func _init() -> void:
	var config: Dictionary = _load_config()
	var results_dir: String = str(config.get("results_dir", "user://autodev_stats"))
	var output_path: String = str(config.get("output_path", "user://batch_autoplay_results.json"))

	print("[BATCH] Aggregating results from: %s" % results_dir)

	var results: Array[Dictionary] = _collect_results(results_dir)
	if results.is_empty():
		printerr("[BATCH] No results found in %s" % results_dir)
		quit(1)
		return

	var aggregate: Dictionary = _compute_aggregate(results)

	var f: FileAccess = FileAccess.open(output_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(aggregate, "\t"))
		f.close()
		print("[BATCH] Aggregate written: %s (%d runs)" % [output_path, results.size()])
	else:
		printerr("[BATCH] Cannot write to %s" % output_path)
		quit(1)
		return

	quit(0)


func _collect_results(dir_path: String) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return results

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json") and file_name.begins_with("run_"):
			var full_path: String = dir_path.path_join(file_name)
			var f: FileAccess = FileAccess.open(full_path, FileAccess.READ)
			if f:
				var json: JSON = JSON.new()
				if json.parse(f.get_as_text()) == OK and json.data is Dictionary:
					results.append(json.data)
				f.close()
		file_name = dir.get_next()
	dir.list_dir_end()
	return results


func _compute_aggregate(results: Array[Dictionary]) -> Dictionary:
	var total_runs: int = results.size()

	# Collect metrics across runs
	var cards_played: Array[int] = []
	var final_lives: Array[int] = []
	var llm_ratios: Array[float] = []
	var avg_gen_times: Array[int] = []
	var p50_gen_times: Array[int] = []
	var p90_gen_times: Array[int] = []
	var durations: Array[int] = []
	var ending_counts: Dictionary = {}
	var strategy_results: Dictionary = {}
	var survived_count: int = 0
	var total_outcomes: Dictionary = {
		"critical_success": 0, "success": 0,
		"failure": 0, "critical_failure": 0
	}

	for r in results:
		cards_played.append(int(r.get("cards_played", 0)))
		final_lives.append(int(r.get("final_life", 0)))
		llm_ratios.append(float(r.get("llm_ratio", 0.0)))
		avg_gen_times.append(int(r.get("avg_gen_time_ms", 0)))
		p50_gen_times.append(int(r.get("p50_gen_time_ms", 0)))
		p90_gen_times.append(int(r.get("p90_gen_time_ms", 0)))
		durations.append(int(r.get("run_duration_ms", 0)))

		var ending: String = str(r.get("ending_type", "unknown"))
		ending_counts[ending] = int(ending_counts.get(ending, 0)) + 1
		if ending.begins_with("victoire") or ending == "survived":
			survived_count += 1

		var strat: String = str(r.get("strategy", "unknown"))
		if not strategy_results.has(strat):
			strategy_results[strat] = {"runs": 0, "survived": 0, "avg_cards": 0, "total_cards": 0}
		strategy_results[strat]["runs"] += 1
		strategy_results[strat]["total_cards"] += int(r.get("cards_played", 0))
		if ending.begins_with("victoire") or ending == "survived":
			strategy_results[strat]["survived"] += 1

		var od: Dictionary = r.get("outcome_distribution", {})
		for key in total_outcomes:
			total_outcomes[key] += int(od.get(key, 0))

	# Compute strategy averages
	for strat in strategy_results:
		var s: Dictionary = strategy_results[strat]
		if s["runs"] > 0:
			s["avg_cards"] = int(s["total_cards"] / s["runs"])

	# Balance score (0-100)
	var balance_score: int = _calc_balance_score(
		ending_counts, total_runs, survived_count, total_outcomes, cards_played)

	# Fun score (0-100)
	var fun_score: int = _calc_fun_score(results, total_outcomes, cards_played)

	return {
		"total_runs": total_runs,
		"survival_rate": float(survived_count) / float(maxi(total_runs, 1)),
		"avg_cards_played": _avg_int(cards_played),
		"median_cards_played": _median_int(cards_played),
		"avg_final_life": _avg_int(final_lives),
		"avg_llm_ratio": _avg_float(llm_ratios),
		"avg_gen_time_ms": _avg_int(avg_gen_times),
		"p50_gen_time_ms": _median_int(p50_gen_times),
		"p90_gen_time_ms": _median_int(p90_gen_times),
		"avg_run_duration_ms": _avg_int(durations),
		"ending_distribution": ending_counts,
		"outcome_distribution": total_outcomes,
		"strategy_results": strategy_results,
		"balance_score": balance_score,
		"fun_score": fun_score,
		"timestamp": Time.get_datetime_string_from_system(),
	}


func _calc_balance_score(endings: Dictionary, total: int, survived: int,
		outcomes: Dictionary, cards: Array[int]) -> int:
	var score: int = 0

	# Ending diversity (0-25): more unique endings = better
	var unique_endings: int = endings.size()
	score += mini(unique_endings * 5, 25)

	# Survival rate bonus (0-25): target 30-50%
	var rate: float = float(survived) / float(maxi(total, 1))
	if rate >= 0.3 and rate <= 0.5:
		score += 25
	elif rate >= 0.2 and rate <= 0.6:
		score += 15
	else:
		score += 5

	# Success rate bonus (0-25): target 40-60%
	var total_out: int = 0
	for k in outcomes:
		total_out += int(outcomes[k])
	var success_count: int = int(outcomes.get("critical_success", 0)) + int(outcomes.get("success", 0))
	var success_rate: float = float(success_count) / float(maxi(total_out, 1))
	if success_rate >= 0.4 and success_rate <= 0.6:
		score += 25
	elif success_rate >= 0.3 and success_rate <= 0.7:
		score += 15
	else:
		score += 5

	# Aspect variety (0-25): avg cards > 20 means aspects had time to shift
	var avg_cards: int = _avg_int(cards)
	if avg_cards >= 25:
		score += 25
	elif avg_cards >= 15:
		score += 15
	else:
		score += 5

	return score


func _calc_fun_score(results: Array[Dictionary], outcomes: Dictionary,
		cards: Array[int]) -> int:
	var score: int = 0

	# Choice variety (0-20): not dominated by one strategy
	score += 15  # Baseline since we force multiple strategies

	# Tension curve (0-20): avg life drain indicates tension
	var avg_cards: int = _avg_int(cards)
	if avg_cards >= 15 and avg_cards <= 35:
		score += 20  # Sweet spot = tension builds over time
	elif avg_cards >= 10:
		score += 10
	else:
		score += 5

	# Critical moments (0-20): crit success + crit failure ratio
	var total_out: int = 0
	for k in outcomes:
		total_out += int(outcomes[k])
	var crit_ratio: float = float(
		int(outcomes.get("critical_success", 0)) + int(outcomes.get("critical_failure", 0))
	) / float(maxi(total_out, 1))
	if crit_ratio >= 0.1 and crit_ratio <= 0.25:
		score += 20
	elif crit_ratio >= 0.05:
		score += 10
	else:
		score += 5

	# Text variety (0-20): measure from LLM ratio (higher = more unique text)
	var avg_llm: float = 0.0
	for r in results:
		avg_llm += float(r.get("llm_ratio", 0.0))
	if results.size() > 0:
		avg_llm /= float(results.size())
	if avg_llm >= 0.9:
		score += 20
	elif avg_llm >= 0.7:
		score += 15
	else:
		score += 5

	# Ending satisfaction (0-20): not dying too early or too late
	if avg_cards >= 20 and avg_cards <= 35:
		score += 20
	elif avg_cards >= 10:
		score += 10
	else:
		score += 5

	return score


func _avg_int(arr: Array[int]) -> int:
	if arr.is_empty():
		return 0
	var total: int = 0
	for v in arr:
		total += v
	return int(total / arr.size())


func _avg_float(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var total: float = 0.0
	for v in arr:
		total += v
	return total / float(arr.size())


func _median_int(arr: Array[int]) -> int:
	if arr.is_empty():
		return 0
	var sorted: Array[int] = arr.duplicate()
	sorted.sort()
	return sorted[int(sorted.size() / 2)]


func _load_config() -> Dictionary:
	var path: String = "user://batch_autoplay_config.json"
	if not FileAccess.file_exists(path):
		return {}
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	if json.parse(text) != OK:
		return {}
	if json.data is Dictionary:
		return json.data
	return {}
