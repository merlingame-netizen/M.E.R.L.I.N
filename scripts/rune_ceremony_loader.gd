## ═══════════════════════════════════════════════════════════════════════════════
## RuneCeremonyLoader v7.7.32 — Sprint 12.4(c) hybride async loading screen
## ═══════════════════════════════════════════════════════════════════════════════
## Port of the lookahead pattern proven in tools/async_lookahead_runner.py
## (commit 6e3139e0). Three Threads run in parallel while the player watches
## a fixed-duration ogham ceremony animation. When all background work is
## done AND the ceremony minimum is reached, emit `run_ready` and let the
## game proceed.
##
## Generic orchestrator: caller passes Callables, this file knows nothing
## about MerlinAI or CardsRAG. Sprint 12.4(d) wires real production work;
## tests pass timing stubs.
##
## Public API:
##   prepare(intro_work, skeleton_work, outro_prefetch_work=null,
##           min_ceremony_seconds=8.0)
##   start()                                        -> kicks off the parallel
##                                                     work + animation
##   on results :
##     signal run_ready(intro_text, skeleton_hits)
##     signal phase_done(phase_name, duration_ms)
##     signal error(phase_name, message)
##
## Threading model:
##   - Thread A : intro_work.call()      typically a LLM intro generation
##   - Thread B : skeleton_work.call()   typically kNN retrieval of N cards
##   - Thread C : (optional) outro_prefetch_work.call() pre-warms the outro
##   - Main thread : ceremony animation + result aggregation
##   Mutex on _results dict ; main thread polls in _process for completion.
##
## Caller graph:
##   - scenes/RuneCeremonyLoader.tscn (this script attached)
##   - scenes/TestRuneCeremonyLoader.tscn (Sprint 12.4(c) test)
##   - scripts/board_narration/board_narration.gd (Sprint 12.4(d), planned)
## ═══════════════════════════════════════════════════════════════════════════════

extends Control

const VERSION := "7.7.32"

## Three ogham letters drawn as text - default visible during ceremony.
const DEFAULT_RUNES := ["ᚁ", "ᚂ", "ᚃ"]  # beith, luis, fearn ogham letters

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION  (set via prepare())
# ═══════════════════════════════════════════════════════════════════════════════

var _intro_work: Callable = Callable()
var _skeleton_work: Callable = Callable()
var _outro_prefetch_work: Callable = Callable()
var _min_ceremony_seconds: float = 8.0

# ═══════════════════════════════════════════════════════════════════════════════
# RUNTIME STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _t_start_ms: int = 0
var _ceremony_done: bool = false
var _intro_thread: Thread = null
var _skeleton_thread: Thread = null
var _outro_thread: Thread = null
var _results_mutex: Mutex = Mutex.new()
var _results: Dictionary = {
	"intro_done": false, "intro_text": "", "intro_ms": 0,
	"skeleton_done": false, "skeleton_hits": [], "skeleton_ms": 0,
	"outro_done": false, "outro_text": "", "outro_ms": 0,
	"intro_error": "", "skeleton_error": "", "outro_error": "",
}
var _emitted_done: bool = false
var _emitted_phases: Dictionary = {}

## Tween for the rune animation (lifecycle managed by Godot).
var _tween: Tween = null

# Three Label nodes that show the ogham letters during the ceremony.
@onready var _rune_labels: Array[Label] = []

# ═══════════════════════════════════════════════════════════════════════════════
# SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

signal run_ready(intro_text: String, skeleton_hits: Array)
signal phase_done(phase_name: String, duration_ms: int)
signal error(phase_name: String, message: String)


# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_rune_labels()


func _setup_rune_labels() -> void:
	# Build 3 labels in a centered HBox if the scene didn't already provide them.
	if has_node("RuneRow"):
		var row := $RuneRow as HBoxContainer
		for child in row.get_children():
			if child is Label:
				_rune_labels.append(child)
	if _rune_labels.size() < 3:
		# Create them programmatically as a fallback for the test harness.
		var row := HBoxContainer.new()
		row.name = "RuneRow"
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.anchor_left = 0.5
		row.anchor_top = 0.5
		row.anchor_right = 0.5
		row.anchor_bottom = 0.5
		row.offset_left = -150
		row.offset_top = -50
		row.offset_right = 150
		row.offset_bottom = 50
		add_child(row)
		_rune_labels.clear()
		for i in 3:
			var lab := Label.new()
			lab.text = DEFAULT_RUNES[i]
			lab.add_theme_font_size_override("font_size", 72)
			lab.custom_minimum_size = Vector2(80, 80)
			lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			row.add_child(lab)
			_rune_labels.append(lab)


# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

func prepare(
	intro_work: Callable,
	skeleton_work: Callable,
	outro_prefetch_work: Callable = Callable(),
	min_ceremony_seconds: float = 8.0,
) -> void:
	_intro_work = intro_work
	_skeleton_work = skeleton_work
	_outro_prefetch_work = outro_prefetch_work
	_min_ceremony_seconds = min_ceremony_seconds


# ═══════════════════════════════════════════════════════════════════════════════
# START - kicks off the parallel work + ceremony animation
# ═══════════════════════════════════════════════════════════════════════════════

func start() -> void:
	if not _intro_work.is_valid() or not _skeleton_work.is_valid():
		push_error("RuneCeremonyLoader.start(): prepare() must be called first with valid Callables")
		return
	_t_start_ms = Time.get_ticks_msec()
	_ceremony_done = false
	_emitted_done = false
	_emitted_phases.clear()

	# Reset state under mutex
	_results_mutex.lock()
	_results = {
		"intro_done": false, "intro_text": "", "intro_ms": 0,
		"skeleton_done": false, "skeleton_hits": [], "skeleton_ms": 0,
		"outro_done": false, "outro_text": "", "outro_ms": 0,
		"intro_error": "", "skeleton_error": "", "outro_error": "",
	}
	_results_mutex.unlock()

	# Spawn the worker threads.
	_intro_thread = Thread.new()
	_intro_thread.start(_run_intro_worker)
	_skeleton_thread = Thread.new()
	_skeleton_thread.start(_run_skeleton_worker)
	if _outro_prefetch_work.is_valid():
		_outro_thread = Thread.new()
		_outro_thread.start(_run_outro_worker)

	# Start the ceremony animation (8s default).
	_animate_ceremony()


# ═══════════════════════════════════════════════════════════════════════════════
# CEREMONY ANIMATION
# ═══════════════════════════════════════════════════════════════════════════════

func _animate_ceremony() -> void:
	# Reset rune visual state.
	for i in _rune_labels.size():
		var lab: Label = _rune_labels[i]
		lab.modulate.a = 0.3
		lab.rotation = 0.0
	# Authoritative ceremony-done signal : tied to wall time, not render frames.
	# Visual tween left to a separate _start_visual_flourish() call so the
	# headless path stays deterministic and the in-game scene can opt in.
	get_tree().create_timer(_min_ceremony_seconds).timeout.connect(_on_ceremony_done)
	_start_visual_flourish()


## Optional visual flourish - safe in headless (no-op when there is no
## rendering server). Called by _animate_ceremony but separate so the in-game
## scene can override or extend it.
func _start_visual_flourish() -> void:
	if Engine.is_editor_hint():
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_parallel(true)
	for i in _rune_labels.size():
		var lab: Label = _rune_labels[i]
		var per_rune := _min_ceremony_seconds / 3.0
		var t0 := per_rune * i
		_tween.tween_property(lab, "modulate:a", 1.0, per_rune).set_delay(t0)
		_tween.tween_property(lab, "rotation", TAU, per_rune * 3).set_delay(t0)


func _on_ceremony_done() -> void:
	_ceremony_done = true


# ═══════════════════════════════════════════════════════════════════════════════
# WORKER THREADS  (must not touch the scene tree directly - use the mutex)
# ═══════════════════════════════════════════════════════════════════════════════

func _run_intro_worker() -> void:
	var t0 := Time.get_ticks_msec()
	var result_text := ""
	var err_msg := ""
	if _intro_work.is_valid():
		var result = _intro_work.call()
		if result is String:
			result_text = result
		elif result is Dictionary:
			result_text = String(result.get("text", ""))
			err_msg = String(result.get("error", ""))
		else:
			err_msg = "intro_work returned unexpected type"
	var dur := Time.get_ticks_msec() - t0
	_results_mutex.lock()
	_results["intro_done"] = true
	_results["intro_text"] = result_text
	_results["intro_ms"] = dur
	_results["intro_error"] = err_msg
	_results_mutex.unlock()


func _run_skeleton_worker() -> void:
	var t0 := Time.get_ticks_msec()
	var hits: Array = []
	var err_msg := ""
	if _skeleton_work.is_valid():
		var result = _skeleton_work.call()
		if result is Array:
			hits = result
		elif result is Dictionary:
			hits = result.get("hits", [])
			err_msg = String(result.get("error", ""))
		else:
			err_msg = "skeleton_work returned unexpected type"
	var dur := Time.get_ticks_msec() - t0
	_results_mutex.lock()
	_results["skeleton_done"] = true
	_results["skeleton_hits"] = hits
	_results["skeleton_ms"] = dur
	_results["skeleton_error"] = err_msg
	_results_mutex.unlock()


func _run_outro_worker() -> void:
	var t0 := Time.get_ticks_msec()
	var result_text := ""
	var err_msg := ""
	if _outro_prefetch_work.is_valid():
		var result = _outro_prefetch_work.call()
		if result is String:
			result_text = result
		elif result is Dictionary:
			result_text = String(result.get("text", ""))
			err_msg = String(result.get("error", ""))
	var dur := Time.get_ticks_msec() - t0
	_results_mutex.lock()
	_results["outro_done"] = true
	_results["outro_text"] = result_text
	_results["outro_ms"] = dur
	_results["outro_error"] = err_msg
	_results_mutex.unlock()


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN-THREAD POLLING (Godot will call _process every frame)
# ═══════════════════════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	if _emitted_done:
		return
	_results_mutex.lock()
	var intro_done: bool = _results["intro_done"]
	var skeleton_done: bool = _results["skeleton_done"]
	var intro_text: String = _results["intro_text"]
	var skeleton_hits: Array = _results["skeleton_hits"]
	var intro_ms: int = _results["intro_ms"]
	var skeleton_ms: int = _results["skeleton_ms"]
	var intro_err: String = _results["intro_error"]
	var skeleton_err: String = _results["skeleton_error"]
	_results_mutex.unlock()

	# Emit per-phase completion (idempotent via _emitted_phases tracking)
	if intro_done and not _emitted_phases.has("intro"):
		_emitted_phases["intro"] = true
		if intro_err.is_empty():
			emit_signal("phase_done", "intro", intro_ms)
		else:
			emit_signal("error", "intro", intro_err)
	if skeleton_done and not _emitted_phases.has("skeleton"):
		_emitted_phases["skeleton"] = true
		if skeleton_err.is_empty():
			emit_signal("phase_done", "skeleton", skeleton_ms)
		else:
			emit_signal("error", "skeleton", skeleton_err)

	# Hold the ready signal until BOTH (a) the ceremony minimum elapsed
	# AND (b) the two required workers completed.
	if intro_done and skeleton_done and _ceremony_done:
		_emitted_done = true
		# Defer the thread-cleanup wait to a separate idle callback : calling
		# Thread.wait_to_finish from within _process can stall the main loop
		# even when the worker already terminated.
		call_deferred("_clean_threads")
		emit_signal("run_ready", intro_text, skeleton_hits)


# ═══════════════════════════════════════════════════════════════════════════════
# CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════

func _clean_threads() -> void:
	if _intro_thread and _intro_thread.is_started():
		_intro_thread.wait_to_finish()
		_intro_thread = null
	if _skeleton_thread and _skeleton_thread.is_started():
		_skeleton_thread.wait_to_finish()
		_skeleton_thread = null
	if _outro_thread and _outro_thread.is_started():
		_outro_thread.wait_to_finish()
		_outro_thread = null


func _exit_tree() -> void:
	_clean_threads()


# ═══════════════════════════════════════════════════════════════════════════════
# INTROSPECTION (for tests)
# ═══════════════════════════════════════════════════════════════════════════════

func get_results_snapshot() -> Dictionary:
	_results_mutex.lock()
	var snap := _results.duplicate(true)
	_results_mutex.unlock()
	snap["ceremony_done"] = _ceremony_done
	snap["emitted_done"] = _emitted_done
	snap["total_wall_ms"] = Time.get_ticks_msec() - _t_start_ms
	return snap


func is_done() -> bool:
	return _emitted_done
