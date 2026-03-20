## BrainSwarmScheduler — Intelligent brain allocation with priority, affinity, and degradation
##
## Replaces the simple _lease_bg_brain() / _release_bg_brain() with:
## - Priority levels: CRITICAL > HIGH > NORMAL > LOW
## - Role affinity: prefer narrator for text, gamemaster for JSON
## - Busy timeout: auto-release stuck brains (30s for 2B, 60s for 7B)
## - Graceful degradation: FULL → SLIM → DUAL → SINGLE
extends RefCounted
class_name BrainSwarmScheduler

# ── Priority Levels ───────────────────────────────────────────────────────────
enum Priority { CRITICAL = 0, HIGH = 1, NORMAL = 2, LOW = 3 }

# ── Degradation Tiers ─────────────────────────────────────────────────────────
enum Tier { SINGLE = 1, DUAL = 2, SLIM = 3, FULL = 4 }

# ── Timeouts per model type (ms) ─────────────────────────────────────────────
const TIMEOUT_SMALL_MS := 30000   # BitNet-2B4T: 30s
const TIMEOUT_LARGE_MS := 60000   # Falcon3-7B: 60s
const TIMEOUT_DEFAULT_MS := 25000

# ── Brain Registration ────────────────────────────────────────────────────────
# Each brain slot: {llm: Object, role: String, busy: bool, busy_since: int,
#                   priority_lock: int, timeout_ms: int, alive: bool, model_size: String}
var _brains: Array = []
var _current_tier: int = Tier.FULL
var _max_tier: int = Tier.FULL  # Set at init based on brain count


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Register a brain with the scheduler.
## model_size: "small" (2B) or "large" (7B) — determines timeout.
func register_brain(llm: Object, role: String, model_size: String = "small") -> int:
	var timeout: int = TIMEOUT_LARGE_MS if model_size == "large" else TIMEOUT_SMALL_MS
	var slot := {
		"llm": llm,
		"role": role,
		"busy": false,
		"busy_since": 0,
		"priority_lock": -1,  # Priority of current task (-1 = idle)
		"timeout_ms": timeout,
		"alive": true,
		"model_size": model_size,
		"tasks_completed": 0,
		"total_busy_ms": 0,
	}
	_brains.append(slot)
	_update_tier()
	return _brains.size() - 1


## Request an idle brain. Returns the brain Object, or null if none available.
## preferred_role: hint for affinity (e.g., "narrator" for creative text).
## priority: higher priority tasks can preempt lower-priority brain locks.
func request_brain(preferred_role: String = "", priority: int = Priority.NORMAL) -> Object:
	_check_timeouts()

	# 1. Exact role match + idle
	for slot in _brains:
		if slot.alive and not slot.busy and slot.role == preferred_role:
			_mark_busy(slot, priority)
			return slot.llm

	# 2. Compatible role + idle (affinity rules)
	var compatible_roles: Array = _get_compatible_roles(preferred_role)
	for slot in _brains:
		if slot.alive and not slot.busy and slot.role in compatible_roles:
			_mark_busy(slot, priority)
			return slot.llm

	# 3. Any idle brain
	for slot in _brains:
		if slot.alive and not slot.busy:
			_mark_busy(slot, priority)
			return slot.llm

	# 4. Preemption: if CRITICAL, steal from LOW priority
	if priority == Priority.CRITICAL:
		for slot in _brains:
			if slot.alive and slot.busy and slot.priority_lock >= Priority.LOW:
				# Cancel existing work and reassign
				if slot.llm.has_method("cancel_generation"):
					slot.llm.cancel_generation()
				_mark_busy(slot, priority)
				return slot.llm

	return null


## Release a brain back to idle state.
func release_brain(llm: Object) -> void:
	for slot in _brains:
		if slot.llm == llm:
			var now := Time.get_ticks_msec()
			if slot.busy and slot.busy_since > 0:
				slot.total_busy_ms += now - slot.busy_since
			slot.busy = false
			slot.busy_since = 0
			slot.priority_lock = -1
			slot.tasks_completed += 1
			return


## Mark a brain as dead (crashed, unresponsive). Triggers degradation.
func mark_brain_dead(llm: Object) -> void:
	for slot in _brains:
		if slot.llm == llm:
			slot.alive = false
			slot.busy = false
			_update_tier()
			return


## Mark a brain as alive (restarted successfully).
func mark_brain_alive(llm: Object) -> void:
	for slot in _brains:
		if slot.llm == llm:
			slot.alive = true
			_update_tier()
			return


## Get current degradation tier.
func get_current_tier() -> int:
	return _current_tier


## Get tier name for display.
func get_tier_name() -> String:
	match _current_tier:
		Tier.FULL: return "FULL"
		Tier.SLIM: return "SLIM"
		Tier.DUAL: return "DUAL"
		Tier.SINGLE: return "SINGLE"
		_: return "UNKNOWN"


## Get the number of idle brains.
func get_idle_count() -> int:
	var count := 0
	for slot in _brains:
		if slot.alive and not slot.busy:
			count += 1
	return count


## Get the number of alive brains.
func get_alive_count() -> int:
	var count := 0
	for slot in _brains:
		if slot.alive:
			count += 1
	return count


## Get the total number of registered brains.
func get_total_count() -> int:
	return _brains.size()


## Check for timed-out brains and auto-release them. Call from _process().
func check_timeouts() -> Array:
	return _check_timeouts()


## Get utilization stats per brain.
func get_stats() -> Array:
	var stats: Array = []
	for i in range(_brains.size()):
		var slot: Dictionary = _brains[i]
		stats.append({
			"index": i,
			"role": slot.role,
			"busy": slot.busy,
			"alive": slot.alive,
			"model_size": slot.model_size,
			"tasks_completed": slot.tasks_completed,
			"total_busy_ms": slot.total_busy_ms,
		})
	return stats


## Clear all brains.
func clear() -> void:
	_brains.clear()
	_current_tier = Tier.SINGLE
	_max_tier = Tier.SINGLE


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE
# ═══════════════════════════════════════════════════════════════════════════════

func _mark_busy(slot: Dictionary, priority: int) -> void:
	slot.busy = true
	slot.busy_since = Time.get_ticks_msec()
	slot.priority_lock = priority


func _check_timeouts() -> Array:
	## Returns list of auto-released brain Objects.
	var released: Array = []
	var now := Time.get_ticks_msec()
	for slot in _brains:
		if slot.busy and slot.busy_since > 0:
			if now - slot.busy_since > slot.timeout_ms:
				print("[Scheduler] Brain '%s' timed out after %dms — force release" % [slot.role, slot.timeout_ms])
				if slot.llm.has_method("cancel_generation"):
					slot.llm.cancel_generation()
				slot.busy = false
				slot.busy_since = 0
				slot.priority_lock = -1
				released.append(slot.llm)
	return released


func _get_compatible_roles(preferred: String) -> Array:
	## Role affinity: which roles can handle which task types.
	match preferred:
		"narrator":
			return ["worker", "gamemaster"]  # Fallback chain for creative text
		"gamemaster":
			return ["worker", "narrator"]    # Fallback chain for structured/JSON
		"worker":
			return ["gamemaster", "narrator"] # Workers are generic
		"judge":
			return ["worker", "gamemaster"]   # Judging needs analytical brain
		"voice":
			return ["worker"]                 # Voice enrichment is lightweight
		_:
			return ["worker", "gamemaster", "narrator"]


func _update_tier() -> void:
	var alive := get_alive_count()
	_max_tier = _count_to_tier(_brains.size())
	_current_tier = _count_to_tier(alive)


static func _count_to_tier(count: int) -> int:
	if count >= 4:
		return Tier.FULL
	elif count >= 3:
		return Tier.SLIM
	elif count >= 2:
		return Tier.DUAL
	else:
		return Tier.SINGLE
