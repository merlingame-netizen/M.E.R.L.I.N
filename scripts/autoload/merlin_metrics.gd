extends Node
## MerlinMetrics — Run telemetry autoload. Captures the 5 dimensions of the
## adherence matrix (see docs/PLAYER_ADHERENCE_MATRIX.md) and emits a JSON file
## at run end in tools/autodev/captures/run_metrics_<timestamp>.json
##
## Public API:
##   MerlinMetrics.run_started(biome, is_tutorial)
##   MerlinMetrics.card_shown(text_length, has_risk_hint, axis_diversity)
##   MerlinMetrics.choice_made(option_index, latency_s, axis)
##   MerlinMetrics.test_resolved(axis, result, dc, roll, xp_gained)
##   MerlinMetrics.trait_unlocked(key)
##   MerlinMetrics.run_ended(reason)  # writes JSON
##
## FPS + frame_time sampled in _process at 1Hz.

const OUTPUT_DIR := "user://run_metrics/"
const FPS_SAMPLE_INTERVAL_S := 1.0

var _active: bool = false
var _run_data: Dictionary = {}
var _fps_samples: Array[float] = []
var _frame_time_samples: Array[float] = []
var _last_sample_time: float = 0.0
var _last_card_shown_time: float = 0.0
var _last_encounter_time: float = 0.0


func _ready() -> void:
	# Ensure user output dir exists.
	if not DirAccess.dir_exists_absolute(OUTPUT_DIR):
		DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)


func _process(_delta: float) -> void:
	if not _active:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_sample_time < FPS_SAMPLE_INTERVAL_S:
		return
	_last_sample_time = now
	_fps_samples.append(Engine.get_frames_per_second())
	# Frame time max in ms (engine reports approximate)
	var frame_ms: float = 1000.0 / max(1.0, Engine.get_frames_per_second())
	_frame_time_samples.append(frame_ms)


# ─────────────────────────────────────────────────────────────────────────────
# Public API
# ─────────────────────────────────────────────────────────────────────────────

func run_started(biome: String, is_tutorial: bool) -> void:
	_active = true
	_fps_samples.clear()
	_frame_time_samples.clear()
	_last_sample_time = 0.0
	_last_card_shown_time = 0.0
	_last_encounter_time = Time.get_ticks_msec() / 1000.0
	_run_data = {
		"run_id": _gen_run_id(),
		"timestamp": Time.get_datetime_string_from_system(true),
		"started_unix": int(Time.get_unix_time_from_system()),
		"biome": biome,
		"tutorial": is_tutorial,
		"cards_played": 0,
		"cards_with_risk_hint": 0,
		"axis_diversity_samples": [],
		"choice_latencies_s": [],
		"card_durations_s": [],
		"encounter_intervals_s": [],
		"resolutions": {"critical": 0, "success": 0, "failure": 0, "critical_failure": 0},
		"xp_gained_total": 0,
		"traits_unlocked": [],
		"end_reason": "",
	}
	print("[MerlinMetrics] run_started biome=%s tutorial=%s id=%s" % [biome, str(is_tutorial), _run_data["run_id"]])


func card_shown(text_length: int, has_risk_hint: bool, axis_diversity: int) -> void:
	if not _active:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if _last_card_shown_time > 0.0:
		_run_data["card_durations_s"].append(now - _last_card_shown_time)
	if _last_encounter_time > 0.0:
		_run_data["encounter_intervals_s"].append(now - _last_encounter_time)
	_last_card_shown_time = now
	_last_encounter_time = now
	_run_data["cards_played"] = int(_run_data["cards_played"]) + 1
	if has_risk_hint:
		_run_data["cards_with_risk_hint"] = int(_run_data["cards_with_risk_hint"]) + 1
	_run_data["axis_diversity_samples"].append(axis_diversity)


func choice_made(_option_index: int, latency_s: float, _axis: String) -> void:
	if not _active:
		return
	_run_data["choice_latencies_s"].append(latency_s)


func test_resolved(_axis: String, result: String, _dc: int, _roll: int, xp_gained: int) -> void:
	if not _active:
		return
	var resolutions: Dictionary = _run_data.get("resolutions", {}) as Dictionary
	if resolutions.has(result):
		resolutions[result] = int(resolutions[result]) + 1
	_run_data["resolutions"] = resolutions
	_run_data["xp_gained_total"] = int(_run_data["xp_gained_total"]) + xp_gained


func trait_unlocked(key: String) -> void:
	if not _active:
		return
	var traits: Array = _run_data.get("traits_unlocked", []) as Array
	if not traits.has(key):
		traits.append(key)
	_run_data["traits_unlocked"] = traits


func run_ended(reason: String) -> void:
	if not _active:
		return
	_active = false
	_run_data["end_reason"] = reason
	_run_data["duration_s"] = (Time.get_ticks_msec() / 1000.0) - 0.0
	_finalize_and_write()


# ─────────────────────────────────────────────────────────────────────────────
# Internals
# ─────────────────────────────────────────────────────────────────────────────

func _finalize_and_write() -> void:
	# Compute aggregates
	var fps_avg: float = _avg(_fps_samples)
	var fps_p99: float = _percentile(_fps_samples, 0.01)  # worst 1%
	var frame_max: float = _max(_frame_time_samples)
	var summary := {
		"run_id": _run_data["run_id"],
		"timestamp": _run_data["timestamp"],
		"biome": _run_data["biome"],
		"tutorial": _run_data["tutorial"],
		"duration_s": _run_data.get("duration_s", 0),
		"cards_played": _run_data["cards_played"],
		"rythm": {
			"avg_card_duration_s": round(_avg(_run_data["card_durations_s"]) * 10) / 10.0,
			"avg_encounter_interval_s": round(_avg(_run_data["encounter_intervals_s"]) * 10) / 10.0,
		},
		"clarity": {
			"avg_choice_latency_s": round(_avg(_run_data["choice_latencies_s"]) * 10) / 10.0,
			"axis_diversity_avg": round(_avg_int(_run_data["axis_diversity_samples"]) * 10) / 10.0,
			"cards_with_risk_hint_pct": _pct(_run_data["cards_with_risk_hint"], _run_data["cards_played"]),
		},
		"tension": {
			"resolution_distribution": _normalize_distribution(_run_data["resolutions"]),
			"resolution_counts": _run_data["resolutions"],
		},
		"progression": {
			"xp_gained_total": _run_data["xp_gained_total"],
			"traits_unlocked": _run_data["traits_unlocked"],
		},
		"performance": {
			"fps_avg": round(fps_avg * 10) / 10.0,
			"fps_p99": round(fps_p99 * 10) / 10.0,
			"frame_time_max_ms": round(frame_max * 10) / 10.0,
			"sample_count": _fps_samples.size(),
		},
		"end_reason": _run_data["end_reason"],
	}
	# Write
	var path: String = "%srun_metrics_%d.json" % [OUTPUT_DIR, int(Time.get_unix_time_from_system())]
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(summary, "\t"))
		f.close()
		print("[MerlinMetrics] run JSON written: %s" % path)
	# Reset
	_run_data = {}
	_fps_samples.clear()
	_frame_time_samples.clear()


func _gen_run_id() -> String:
	# Compact pseudo-uuid (timestamp + 4 hex chars)
	var ts: int = int(Time.get_unix_time_from_system())
	var suffix: String = "%04x" % (randi() & 0xFFFF)
	return "%d-%s" % [ts, suffix]


func _avg(arr: Array) -> float:
	if arr.is_empty(): return 0.0
	var sum: float = 0.0
	for v in arr: sum += float(v)
	return sum / float(arr.size())


func _avg_int(arr: Array) -> float:
	if arr.is_empty(): return 0.0
	var sum: float = 0.0
	for v in arr: sum += float(v)
	return sum / float(arr.size())


func _max(arr: Array) -> float:
	if arr.is_empty(): return 0.0
	var m: float = float(arr[0])
	for v in arr:
		if float(v) > m: m = float(v)
	return m


func _percentile(arr: Array, pct: float) -> float:
	if arr.is_empty(): return 0.0
	var sorted: Array = arr.duplicate()
	sorted.sort()
	var idx: int = clampi(int(float(sorted.size()) * pct), 0, sorted.size() - 1)
	return float(sorted[idx])


func _pct(num: int, denom: int) -> float:
	if denom == 0: return 0.0
	return round(float(num) / float(denom) * 100.0)


func _normalize_distribution(counts: Dictionary) -> Dictionary:
	var total: int = 0
	for k in counts: total += int(counts[k])
	if total == 0: return {}
	var out: Dictionary = {}
	for k in counts:
		out[k] = round(float(counts[k]) / float(total) * 100.0) / 100.0
	return out
