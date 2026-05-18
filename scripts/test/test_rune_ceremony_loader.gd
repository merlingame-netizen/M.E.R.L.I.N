## ═══════════════════════════════════════════════════════════════════════════════
## Test harness for RuneCeremonyLoader (Sprint 12.4(c) validation)
## ═══════════════════════════════════════════════════════════════════════════════
## Validates the parallel pre-fetch + ceremony-floor pattern using Callable
## stubs that sleep N ms (no LLM, no kNN required).
##
## Phases:
##   1. prepare + start with no work : ceremony still completes
##   2. parallel pre-fetch reduces wall time vs sequential baseline
##   3. ceremony-floor : if work finishes early, ready waits for ceremony
##   4. ceremony-floor : if work finishes late, ready waits for work
##   5. error propagation : a worker returning {error:"..."} fires error signal
##   6. outro pre-fetch : optional 3rd thread runs in parallel
##
## Usage: godot --headless --quit-after 30 res://scenes/TestRuneCeremonyLoader.tscn
## ═══════════════════════════════════════════════════════════════════════════════

extends Node

const LoaderScript = preload("res://scripts/rune_ceremony_loader.gd")

var _failures: int = 0


func _ready() -> void:
	print("[TEST] RuneCeremonyLoader harness starting...")
	await _phase_1_zero_work()
	await _phase_2_parallel_reduces_wall_time()
	await _phase_3_ceremony_floor_floor()
	await _phase_4_ceremony_floor_ceiling()
	await _phase_5_error_propagation()
	await _phase_6_outro_prefetch()

	if _failures == 0:
		print("[TEST] ALL PHASES PASSED")
		get_tree().quit(0)
	else:
		printerr("[TEST] %d FAILURES" % _failures)
		get_tree().quit(1)


func _assert(cond: bool, msg: String) -> void:
	if cond:
		print("  PASS  %s" % msg)
	else:
		printerr("  FAIL  %s" % msg)
		_failures += 1


# ═══════════════════════════════════════════════════════════════════════════════
# CALLABLE STUBS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_sleep_stub(ms: int, result_value) -> Callable:
	return func():
		OS.delay_msec(ms)
		return result_value


func _make_loader() -> Control:
	var loader: Control = LoaderScript.new()
	add_child(loader)
	return loader


func _wait_for_ready(loader: Control, timeout_s: float = 15.0) -> Dictionary:
	# Use Time.get_ticks_msec rather than get_process_delta_time : the latter
	# returns 0 on Nodes without _process declared, which would spin forever.
	var t_start_ms := Time.get_ticks_msec()
	var timeout_ms := int(timeout_s * 1000)
	while not loader.is_done() and (Time.get_ticks_msec() - t_start_ms) < timeout_ms:
		await get_tree().process_frame
	return loader.get_results_snapshot()


# ═══════════════════════════════════════════════════════════════════════════════
# PHASES
# ═══════════════════════════════════════════════════════════════════════════════

func _phase_1_zero_work() -> void:
	print("[TEST] Phase 1 - instant stubs + minimal ceremony")
	var loader := _make_loader()
	loader.prepare(
		_make_sleep_stub(0, "intro_OK"),
		_make_sleep_stub(0, []),
		Callable(),
		0.3,
	)
	loader.start()
	var snap := await _wait_for_ready(loader, 5.0)
	_assert(snap["emitted_done"], "run_ready emitted within timeout")
	_assert(snap["ceremony_done"], "ceremony reached its floor")
	_assert(snap["intro_done"], "intro worker completed")
	_assert(snap["skeleton_done"], "skeleton worker completed")
	# SceneTreeTimer can fire ~50ms early in headless. Accept 250ms +/- 50ms.
	_assert(snap["total_wall_ms"] >= 200, "wall time >= ceremony floor minus timer jitter (got %d, target >=200)" % snap["total_wall_ms"])
	loader.queue_free()
	await get_tree().process_frame


func _phase_2_parallel_reduces_wall_time() -> void:
	print("[TEST] Phase 2 - parallel pre-fetch < sequential baseline")
	var loader := _make_loader()
	loader.prepare(
		_make_sleep_stub(500, "intro"),
		_make_sleep_stub(600, [{"card_uid": "stub"}]),
		Callable(),
		0.3,
	)
	loader.start()
	var snap := await _wait_for_ready(loader, 5.0)
	_assert(snap["emitted_done"], "run_ready emitted")
	_assert(snap["total_wall_ms"] < 900, "parallel wall < 900 ms (got %d)" % snap["total_wall_ms"])
	_assert(snap["total_wall_ms"] >= 550, "parallel wall >= max(500,600) (got %d)" % snap["total_wall_ms"])
	loader.queue_free()
	await get_tree().process_frame


func _phase_3_ceremony_floor_floor() -> void:
	print("[TEST] Phase 3 - ceremony floor enforced when work finishes early")
	var loader := _make_loader()
	loader.prepare(
		_make_sleep_stub(100, "fast"),
		_make_sleep_stub(100, []),
		Callable(),
		0.8,
	)
	loader.start()
	var snap := await _wait_for_ready(loader, 5.0)
	_assert(snap["emitted_done"], "run_ready emitted")
	_assert(snap["total_wall_ms"] >= 700, "ceremony floor respected with jitter (got %d, target >=700)" % snap["total_wall_ms"])
	loader.queue_free()
	await get_tree().process_frame


func _phase_4_ceremony_floor_ceiling() -> void:
	print("[TEST] Phase 4 - work-bounded wall when work exceeds ceremony")
	var loader := _make_loader()
	loader.prepare(
		_make_sleep_stub(1200, "slow_intro"),
		_make_sleep_stub(200, []),
		Callable(),
		0.3,
	)
	loader.start()
	var snap := await _wait_for_ready(loader, 5.0)
	_assert(snap["emitted_done"], "run_ready emitted")
	_assert(snap["total_wall_ms"] >= 1100, "wall waits for slow worker (got %d)" % snap["total_wall_ms"])
	loader.queue_free()
	await get_tree().process_frame


func _phase_5_error_propagation() -> void:
	print("[TEST] Phase 5 - error result propagates via error signal")
	var loader := _make_loader()
	loader.prepare(
		_make_sleep_stub(100, "ok_intro"),
		_make_sleep_stub(150, {"error": "kNN unavailable"}),
		Callable(),
		0.3,
	)
	var caught_errors: Array = []
	loader.error.connect(func(phase, msg): caught_errors.append({"phase": phase, "msg": msg}))
	loader.start()
	var snap := await _wait_for_ready(loader, 5.0)
	_assert(snap["emitted_done"], "ready still fires despite worker error")
	_assert(snap["skeleton_done"], "skeleton marked done (with error)")
	_assert(caught_errors.size() == 1, "exactly 1 error signal fired (got %d)" % caught_errors.size())
	if caught_errors.size() >= 1:
		_assert(caught_errors[0]["phase"] == "skeleton", "error phase = skeleton")
		_assert(caught_errors[0]["msg"] == "kNN unavailable", "error msg propagates")
	loader.queue_free()
	await get_tree().process_frame


func _phase_6_outro_prefetch() -> void:
	print("[TEST] Phase 6 - optional outro prefetch runs in parallel")
	var loader := _make_loader()
	loader.prepare(
		_make_sleep_stub(300, "intro"),
		_make_sleep_stub(300, []),
		_make_sleep_stub(400, "outro_prewarmed"),
		0.3,
	)
	loader.start()
	var snap := await _wait_for_ready(loader, 5.0)
	_assert(snap["emitted_done"], "run_ready emitted")
	_assert(snap["outro_done"], "outro worker also completed")
	_assert(snap["outro_text"] == "outro_prewarmed", "outro text captured")
	_assert(snap["total_wall_ms"] < 700, "outro parallelism kept wall < 700 (got %d)" % snap["total_wall_ms"])
	loader.queue_free()
	await get_tree().process_frame
