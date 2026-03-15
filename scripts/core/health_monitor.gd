## ═══════════════════════════════════════════════════════════════════════════════
## HealthMonitor — Subsystem health tracking via ErrorHandler integration
## ═══════════════════════════════════════════════════════════════════════════════
## Polls ErrorHandler periodically to classify each subsystem as HEALTHY,
## DEGRADED, or FAILING based on accumulated error counts.
## In headless mode, no timer is created — use poll() manually.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node
class_name HealthMonitor

signal health_changed(system: String, old_status: int, new_status: int)

# ═══════════════════════════════════════════════════════════════════════════════
# HEALTH STATUS
# ═══════════════════════════════════════════════════════════════════════════════

enum Status {
	HEALTHY = 0,
	DEGRADED = 1,
	FAILING = 2,
	UNKNOWN = 3,
}

const STATUS_NAMES: Dictionary = {
	Status.HEALTHY: "HEALTHY",
	Status.DEGRADED: "DEGRADED",
	Status.FAILING: "FAILING",
	Status.UNKNOWN: "UNKNOWN",
}

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

const MONITORED_SYSTEMS: Array[String] = [
	"card_system", "llm_adapter", "save_system", "effect_engine",
	"game_flow", "audio", "store", "reputation", "minigame",
	"ogham", "biome",
]

const POLL_INTERVAL: float = 30.0
const ERROR_THRESHOLD_DEGRADED: int = 3
const ERROR_THRESHOLD_FAILING: int = 10

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _error_handler: ErrorHandler = null
var _statuses: Dictionary = {}
var _last_error_counts: Dictionary = {}
var _timer: Timer = null
var _poll_count: int = 0


# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	for sys in MONITORED_SYSTEMS:
		_statuses[sys] = Status.UNKNOWN
		_last_error_counts[sys] = 0

	var is_headless: bool = DisplayServer.get_name() == "headless"
	if not is_headless:
		_timer = Timer.new()
		_timer.wait_time = POLL_INTERVAL
		_timer.one_shot = false
		_timer.autostart = false
		_timer.timeout.connect(_on_poll_timer)
		add_child(_timer)


## Wire to an ErrorHandler instance and start polling (if not headless).
func initialize(error_handler: ErrorHandler) -> void:
	_error_handler = error_handler
	if _timer:
		_timer.start()
	poll()


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Returns the Status enum value for a single system.
func get_system_status(system: String) -> int:
	return int(_statuses.get(system, Status.UNKNOWN))


## Returns a Dictionary mapping each system name to its Status int.
func get_all_status() -> Dictionary:
	return _statuses.duplicate()


## Returns counts per status category.
func get_health_summary() -> Dictionary:
	var summary: Dictionary = {
		"healthy": 0,
		"degraded": 0,
		"failing": 0,
		"unknown": 0,
	}
	for sys in MONITORED_SYSTEMS:
		var st: int = int(_statuses.get(sys, Status.UNKNOWN))
		match st:
			Status.HEALTHY:
				summary["healthy"] += 1
			Status.DEGRADED:
				summary["degraded"] += 1
			Status.FAILING:
				summary["failing"] += 1
			_:
				summary["unknown"] += 1
	return summary


## True if every monitored system is HEALTHY.
func is_all_healthy() -> bool:
	for sys in MONITORED_SYSTEMS:
		if int(_statuses.get(sys, Status.UNKNOWN)) != Status.HEALTHY:
			return false
	return true


## Human-readable health report.
func get_report() -> String:
	var lines: Array[String] = ["=== Health Report (poll #%d) ===" % _poll_count]
	for sys in MONITORED_SYSTEMS:
		var st: int = int(_statuses.get(sys, Status.UNKNOWN))
		var label: String = STATUS_NAMES.get(st, "UNKNOWN")
		var errs: int = int(_last_error_counts.get(sys, 0))
		lines.append("  %s: %s (errors: %d)" % [sys, label, errs])
	var summary: Dictionary = get_health_summary()
	lines.append("--- Summary: %d healthy, %d degraded, %d failing, %d unknown ---" % [
		summary["healthy"], summary["degraded"],
		summary["failing"], summary["unknown"],
	])
	return "\n".join(lines)


## Reset tracking for a single system back to UNKNOWN with zero errors.
func reset_system(system: String) -> void:
	if system in _statuses:
		_statuses[system] = Status.UNKNOWN
		_last_error_counts[system] = 0


## Manual poll — use in headless mode or for immediate refresh.
func poll() -> void:
	_on_poll_timer()


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════

func _on_poll_timer() -> void:
	_poll_count += 1

	if _error_handler == null:
		return

	for sys in MONITORED_SYSTEMS:
		var error_count: int = _error_handler.get_system_error_count(sys)
		_last_error_counts[sys] = error_count

		var new_status: int = _classify(error_count)
		var old_status: int = int(_statuses.get(sys, Status.UNKNOWN))

		if new_status != old_status:
			_statuses[sys] = new_status
			health_changed.emit(sys, old_status, new_status)
		else:
			_statuses[sys] = new_status


## Classify a system based on its cumulative error count.
func _classify(error_count: int) -> int:
	if error_count >= ERROR_THRESHOLD_FAILING:
		return Status.FAILING
	if error_count >= ERROR_THRESHOLD_DEGRADED:
		return Status.DEGRADED
	return Status.HEALTHY
