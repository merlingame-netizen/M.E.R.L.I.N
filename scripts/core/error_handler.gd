## ═══════════════════════════════════════════════════════════════════════════════
## ErrorHandler — Centralized error handling and graceful degradation
## ═══════════════════════════════════════════════════════════════════════════════
## Reports, tracks, and logs errors across all game systems.
## Provides recovery strategies for known failure modes.
## Persists error log to user://error_log.json for debugging.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name ErrorHandler

signal error_reported(system: String, severity: int, message: String)

# ═══════════════════════════════════════════════════════════════════════════════
# SEVERITY LEVELS
# ═══════════════════════════════════════════════════════════════════════════════

enum Severity {
	INFO = 0,
	WARNING = 1,
	ERROR = 2,
	CRITICAL = 3,
}

const SEVERITY_NAMES: Dictionary = {
	Severity.INFO: "INFO",
	Severity.WARNING: "WARNING",
	Severity.ERROR: "ERROR",
	Severity.CRITICAL: "CRITICAL",
}

# ═══════════════════════════════════════════════════════════════════════════════
# KNOWN SYSTEMS — for validation
# ═══════════════════════════════════════════════════════════════════════════════

const KNOWN_SYSTEMS: Array[String] = [
	"card_system", "llm_adapter", "save_system", "effect_engine",
	"game_flow", "audio", "store", "reputation", "minigame",
	"ogham", "biome", "scenario", "health_monitor", "unknown",
]

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

const LOG_PATH: String = "user://error_log.json"
const MAX_ERRORS: int = 500
const MAX_LOG_ENTRIES: int = 200

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _errors: Array = []
var _recovery_strategies: Dictionary = {}


# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_register_default_strategies()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API — Reporting
# ═══════════════════════════════════════════════════════════════════════════════

## Report an error from any game system.
## system: identifier of the reporting subsystem (e.g. "card_system")
## severity: Severity enum value
## message: human-readable description of what went wrong
## context: optional dictionary with extra diagnostic data
func report(system: String, severity: int, message: String, context: Dictionary = {}) -> void:
	var clamped_severity: int = clampi(severity, Severity.INFO, Severity.CRITICAL)
	var severity_name: String = SEVERITY_NAMES.get(clamped_severity, "UNKNOWN")
	var timestamp: int = int(Time.get_unix_time_from_system())

	var entry: Dictionary = {
		"system": system,
		"severity": clamped_severity,
		"severity_name": severity_name,
		"message": message,
		"context": context.duplicate(true),
		"timestamp": timestamp,
	}

	_errors.append(entry)

	# Trim oldest if over capacity
	if _errors.size() > MAX_ERRORS:
		_errors = _errors.slice(-MAX_ERRORS)

	# Emit signal for listeners
	error_reported.emit(system, clamped_severity, message)

	# Log to Godot console based on severity
	var log_line: String = "[ErrorHandler] [%s] %s: %s" % [severity_name, system, message]
	match clamped_severity:
		Severity.INFO:
			print(log_line)
		Severity.WARNING:
			push_warning(log_line)
		Severity.ERROR:
			push_error(log_line)
		Severity.CRITICAL:
			push_error(log_line)

	# Persist critical/error to disk
	if clamped_severity >= Severity.ERROR:
		_persist_log()


## Get all errors at or above a minimum severity.
func get_errors(severity_min: int = Severity.WARNING) -> Array:
	var result: Array = []
	for entry in _errors:
		if entry is Dictionary and int(entry.get("severity", 0)) >= severity_min:
			result.append(entry)
	return result


## Get total count of recorded errors (all severities).
func get_error_count() -> int:
	return _errors.size()


## Check if any CRITICAL error has been recorded.
func has_critical() -> bool:
	for entry in _errors:
		if entry is Dictionary and int(entry.get("severity", 0)) >= Severity.CRITICAL:
			return true
	return false


## Get count of errors for a specific system.
func get_system_error_count(system: String) -> int:
	var count: int = 0
	for entry in _errors:
		if entry is Dictionary and str(entry.get("system", "")) == system:
			count += 1
	return count


## Clear all recorded errors.
func clear() -> void:
	_errors.clear()


## Get the most recent error entry, or empty dict if none.
func get_last_error() -> Dictionary:
	if _errors.is_empty():
		return {}
	return _errors[-1]


# ═══════════════════════════════════════════════════════════════════════════════
# RECOVERY STRATEGIES
# ═══════════════════════════════════════════════════════════════════════════════

## Register a recovery strategy for a specific failure type.
## failure_type: string key identifying the failure (e.g. "card_loading_failure")
## strategy: Dictionary with keys: description, action (String)
func register_strategy(failure_type: String, strategy: Dictionary) -> void:
	_recovery_strategies[failure_type] = strategy.duplicate(true)


## Get the recovery strategy for a failure type.
func get_strategy(failure_type: String) -> Dictionary:
	return _recovery_strategies.get(failure_type, {})


## Get all registered recovery strategy keys.
func get_strategy_keys() -> Array:
	return _recovery_strategies.keys()


## Attempt recovery for a known failure type.
## Returns a Dictionary with: recovered (bool), action (String), description (String).
func attempt_recovery(failure_type: String, context: Dictionary = {}) -> Dictionary:
	var strategy: Dictionary = _recovery_strategies.get(failure_type, {})
	if strategy.is_empty():
		report("error_handler", Severity.WARNING,
			"No recovery strategy for failure type: %s" % failure_type, context)
		return {"recovered": false, "action": "none", "description": "No strategy registered"}

	var action: String = str(strategy.get("action", "none"))
	var description: String = str(strategy.get("description", ""))

	report("error_handler", Severity.INFO,
		"Attempting recovery for '%s': %s" % [failure_type, action], context)

	return {"recovered": true, "action": action, "description": description}


# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT STRATEGIES — Graceful degradation for known failure modes
# ═══════════════════════════════════════════════════════════════════════════════

func _register_default_strategies() -> void:
	register_strategy("card_loading_failure", {
		"description": "Card pool JSON failed to load; use fallback pool",
		"action": "use_fallback_pool",
	})

	register_strategy("llm_timeout", {
		"description": "LLM generation timed out; use FastRoute cards",
		"action": "use_fastroute",
	})

	register_strategy("llm_not_ready", {
		"description": "LLM backend not available; use FastRoute cards",
		"action": "use_fastroute",
	})

	register_strategy("save_corruption", {
		"description": "Save file corrupted; restore defaults from backup or fresh profile",
		"action": "restore_defaults",
	})

	register_strategy("effect_overflow", {
		"description": "Effect value exceeds valid range; clamp silently and log",
		"action": "clamp_and_log",
	})

	register_strategy("scene_transition_failure", {
		"description": "Scene transition failed; return to hub as safe fallback",
		"action": "return_to_hub",
	})

	register_strategy("audio_failure", {
		"description": "Audio system error; continue gameplay without sound",
		"action": "continue_without_sound",
	})

	register_strategy("card_validation_failure", {
		"description": "LLM-generated card failed validation; use emergency card",
		"action": "use_emergency_card",
	})

	register_strategy("reputation_out_of_bounds", {
		"description": "Faction reputation exceeded 0-100 range; clamp to bounds",
		"action": "clamp_and_log",
	})

	register_strategy("invalid_phase_transition", {
		"description": "Invalid game phase transition attempted; stay in current phase",
		"action": "ignore_transition",
	})

	register_strategy("ogham_not_found", {
		"description": "Referenced ogham does not exist; skip ogham effect",
		"action": "skip_effect",
	})

	register_strategy("json_parse_error", {
		"description": "JSON data failed to parse; use empty defaults",
		"action": "use_defaults",
	})


# ═══════════════════════════════════════════════════════════════════════════════
# PERSISTENCE — Write error log to disk
# ═══════════════════════════════════════════════════════════════════════════════

func _persist_log() -> void:
	var entries_to_write: Array = _errors.duplicate()
	if entries_to_write.size() > MAX_LOG_ENTRIES:
		entries_to_write = entries_to_write.slice(-MAX_LOG_ENTRIES)

	var data: Dictionary = {
		"version": "1.0.0",
		"timestamp": int(Time.get_unix_time_from_system()),
		"entries": entries_to_write,
	}

	var json_text: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[ErrorHandler] Cannot write error log to %s" % LOG_PATH)
		return
	file.store_string(json_text)
	file.close()


## Load persisted error log from disk (for diagnostics).
func load_persisted_log() -> Array:
	if not FileAccess.file_exists(LOG_PATH):
		return []
	var file: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ)
	if file == null:
		return []
	var json_text: String = file.get_as_text()
	file.close()
	if json_text.strip_edges().is_empty():
		return []
	var json: JSON = JSON.new()
	if json.parse(json_text) != OK:
		return []
	var data = json.get_data()
	if not (data is Dictionary):
		return []
	return data.get("entries", [])


## Clear the persisted error log file.
func clear_persisted_log() -> void:
	if FileAccess.file_exists(LOG_PATH):
		DirAccess.remove_absolute(LOG_PATH)
