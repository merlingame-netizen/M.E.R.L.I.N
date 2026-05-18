## ═══════════════════════════════════════════════════════════════════════════════
## RunCompletionHook v7.7.32 — Sprint 12.4(d) post-run XP + trait sidecar
## ═══════════════════════════════════════════════════════════════════════════════
## Standalone helper that wires "run ended" into:
##   1. MerlinProfile.grant_xp_from_run(state)  -> XP, level-up, signals
##   2. (Optional) Spawn Python adaptive_trait_emergence sidecar via OS.create_process
##      Gated by MERLIN_ADAPTIVE_TRAITS=1 env var (off by default).
##
## Designed to leave the existing 3 400-line BoardNarration script untouched.
## The hook attaches to its `narration_done` signal externally.
##
## Public API:
##   process_run_end(run_state_dict)   -> Array[Dictionary] of events
##   connect_to_board_narration(board) -> bool
##   build_run_dict_from_store(store)  -> Dictionary (v7.7.31 schema)
##   set_profile_path(path)            -> void (test helper)
##
## Signals:
##   run_recorded(events: Array)
##   sidecar_spawned(pid: int)
##   sidecar_error(message: String)
##
## Caller graph (Sprint 12.4(d)+):
##   - project.godot autoload (planned)
##   - scenes/TestRunCompletionHook.tscn (this turn)
##   - Future : BoardNarration.narration_done -> _on_narration_done
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name RunCompletionHook

const VERSION := "7.7.32"
const ProfileSystemScript = preload("res://addons/merlin_ai/profile_system.gd")

const ADAPTIVE_TRAITS_ENV := "MERLIN_ADAPTIVE_TRAITS"
const ADAPTIVE_TRAITS_SCRIPT := "tools/adaptive_trait_emergence.py"
const DEFAULT_PROFILE_PATH := "user://profile.json"

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _profile = null
var _profile_path: String = DEFAULT_PROFILE_PATH

signal run_recorded(events: Array)
signal sidecar_spawned(pid: int)
signal sidecar_error(message: String)


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Set the profile path before the first process_run_end. Useful for tests.
func set_profile_path(path: String) -> void:
	_profile_path = path
	_profile = null  # force reload on next call


## Process the end of a run. `run_state_dict` should match v7.7.31 schema :
##   { cards_played: Array, final_state: { faction_rep, tags, karma, life_essence } }
##
## Returns the events Array from MerlinProfile.grant_xp_from_run (includes
## run_completed, xp_gain, level_up entries).
func process_run_end(run_state_dict: Dictionary) -> Array:
	var profile = _get_or_create_profile()
	if profile == null:
		push_error("RunCompletionHook: profile unavailable")
		return []
	var events: Array = profile.grant_xp_from_run(run_state_dict)
	var saved: bool = profile.save_profile()
	if not saved:
		push_warning("RunCompletionHook: profile save failed (continuing anyway)")
	emit_signal("run_recorded", events)
	if _adaptive_traits_enabled():
		_maybe_spawn_adaptive_sidecar(run_state_dict)
	return events


## Convenience : connect to a BoardNarration's narration_done signal.
## The board doesn't pass its state through the signal, so the hook reads
## MerlinStore on connection's _on_narration_done.
func connect_to_board_narration(board: Node) -> bool:
	if board == null or not board.has_signal("narration_done"):
		push_warning("RunCompletionHook: board has no narration_done signal")
		return false
	if board.narration_done.is_connected(_on_narration_done):
		return true  # already connected
	board.narration_done.connect(_on_narration_done)
	return true


## Build a v7.7.31-compatible run dictionary from a MerlinStore-like object.
## Tries store.get_state() first (typed accessor), then falls back to direct
## field access. Returns an empty dict on failure.
func build_run_dict_from_store(store) -> Dictionary:
	if store == null:
		return {}
	var faction_rep := {}
	var life := 80
	var karma := 0
	var tags: Array = []
	var cards_played: Array = []

	if store.has_method("get_state"):
		var s = store.get_state()
		if s is Dictionary:
			faction_rep = s.get("faction_rep", {})
			life = int(s.get("life_essence", s.get("life", 80)))
			karma = int(s.get("karma", 0))
			tags = s.get("tags", [])
			cards_played = s.get("cards_played", [])
	# Fallback : pull common field names directly.
	if faction_rep.is_empty() and "faction_rep" in store:
		faction_rep = store.faction_rep
	if "life_essence" in store:
		life = int(store.life_essence)
	if "karma" in store:
		karma = int(store.karma)
	if tags.is_empty() and "tags" in store:
		tags = store.tags
	if cards_played.is_empty() and "cards_played" in store:
		cards_played = store.cards_played

	return {
		"cards_played": cards_played,
		"final_state": {
			"faction_rep": faction_rep,
			"life_essence": life,
			"karma": karma,
			"tags": tags,
		},
	}


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════

func _on_narration_done() -> void:
	# Pull the live state from MerlinStore autoload if available.
	var store = _get_merlin_store()
	if store == null:
		push_warning("RunCompletionHook: MerlinStore not found in autoloads")
		return
	var run_dict := build_run_dict_from_store(store)
	if run_dict.is_empty():
		push_warning("RunCompletionHook: empty run_dict, skipping XP grant")
		return
	process_run_end(run_dict)


func _get_merlin_store():
	# MerlinStore is the canonical autoload name (per project.godot).
	if Engine.has_singleton("MerlinStore"):
		return Engine.get_singleton("MerlinStore")
	if get_tree() and get_tree().root:
		var node := get_tree().root.get_node_or_null("MerlinStore")
		if node:
			return node
	return null


func _get_or_create_profile():
	if _profile == null:
		_profile = ProfileSystemScript.new()
		add_child(_profile)
		_profile.load_profile(_profile_path)
	return _profile


func _adaptive_traits_enabled() -> bool:
	return OS.get_environment(ADAPTIVE_TRAITS_ENV) == "1"


## Fire the Python adaptive_trait_emergence sidecar in a separate process.
## Returns true on successful spawn (pid > 0), false otherwise.
func _maybe_spawn_adaptive_sidecar(run_state_dict: Dictionary) -> bool:
	# Write the run dict to a temp file so the sidecar can read it.
	var temp_path := "user://adaptive_traits_input_%d.json" % Time.get_ticks_msec()
	var f := FileAccess.open(temp_path, FileAccess.WRITE)
	if f == null:
		emit_signal("sidecar_error", "cannot write temp file %s" % temp_path)
		return false
	f.store_string(JSON.stringify(run_state_dict))
	f.close()

	var python_path := _resolve_python_path()
	if python_path.is_empty():
		emit_signal("sidecar_error", "no python interpreter found")
		return false

	var globalised_temp := ProjectSettings.globalize_path(temp_path)
	var globalised_profile := ProjectSettings.globalize_path(_profile_path)
	var args := [
		ADAPTIVE_TRAITS_SCRIPT,
		"--runs", globalised_temp,
		"--profile", globalised_profile,
	]
	var pid := OS.create_process(python_path, args)
	if pid > 0:
		emit_signal("sidecar_spawned", pid)
		return true
	else:
		emit_signal("sidecar_error", "OS.create_process returned %d" % pid)
		return false


func _resolve_python_path() -> String:
	# Honour explicit MERLIN_PYTHON override, else use OS default.
	var override := OS.get_environment("MERLIN_PYTHON")
	if not override.is_empty() and FileAccess.file_exists(override):
		return override
	for candidate in [
		"C:/Users/PGNK2128/AppData/Local/Programs/Python/Python312/python.exe",
		"C:/Python312/python.exe",
		"/usr/bin/python3",
		"/usr/local/bin/python3",
	]:
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


# ═══════════════════════════════════════════════════════════════════════════════
# INTROSPECTION (tests)
# ═══════════════════════════════════════════════════════════════════════════════

func get_profile():
	return _profile


func get_profile_summary() -> Dictionary:
	if _profile == null:
		return {}
	return _profile.summary()
