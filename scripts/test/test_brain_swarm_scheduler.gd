## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — BrainSwarmScheduler (pure-logic, no scene tree required)
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage:
##   register_brain()        — slot creation, index return, tier update, model_size
##   get_total_count()       — count all registered brains
##   get_alive_count()       — count alive brains
##   get_idle_count()        — count idle (alive + not busy) brains
##   get_current_tier()      — int tier value
##   get_tier_name()         — tier string from alive count
##   _count_to_tier()        — static boundary mapping (0-5+)
##   _get_compatible_roles() — fallback chains per role (all known roles)
##   request_brain()         — exact match, compat match, any-idle, null when full,
##                             CRITICAL preemption (cancel_generation called)
##   release_brain()         — busy=false, stats updated, unknown llm no-op
##   mark_brain_dead()       — alive=false + tier degradation, idle count
##   mark_brain_alive()      — alive=true + tier recovery, idempotent
##   get_stats()             — shape and required fields
##   check_timeouts()        — returns empty Array when no brains timed out
##   clear()                 — reset all state
##
## Pattern: extends RefCounted, NO class_name, test_xxx() -> bool
## 42 tests total.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ─── Stub LLM object ──────────────────────────────────────────────────────────
# BrainSwarmScheduler stores Object references in slots.
# We use RefCounted stubs — no scene tree needed.
class StubLLM extends RefCounted:
	var cancelled := false
	func cancel_generation() -> void:
		cancelled = true


# ─── Helper ───────────────────────────────────────────────────────────────────

func _fail(msg: String) -> bool:
	push_error(msg)
	return false


# ─── Factory ──────────────────────────────────────────────────────────────────

func _make_scheduler() -> BrainSwarmScheduler:
	return BrainSwarmScheduler.new()


func _make_llm() -> StubLLM:
	return StubLLM.new()


# ═══════════════════════════════════════════════════════════════════════════════
# register_brain() — slot creation
# ═══════════════════════════════════════════════════════════════════════════════

func test_register_returns_index_zero_for_first_brain() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	var idx: int = sched.register_brain(llm, "narrator", "small")
	if idx != 0:
		return _fail("register first: expected index 0, got %d" % idx)
	return true


func test_register_increments_index() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var idx0: int = sched.register_brain(_make_llm(), "narrator", "small")
	var idx1: int = sched.register_brain(_make_llm(), "gamemaster", "small")
	if idx0 != 0 or idx1 != 1:
		return _fail("register index: expected 0,1 — got %d,%d" % [idx0, idx1])
	return true


func test_register_large_model_gets_large_model_size_in_stats() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	sched.register_brain(llm, "narrator", "large")
	var stats: Array = sched.get_stats()
	if stats.is_empty():
		return _fail("register large: stats empty")
	if str(stats[0].get("model_size", "")) != "large":
		return _fail("register large: model_size should be 'large', got '%s'" % str(stats[0].get("model_size", "")))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_total_count() / get_alive_count() / get_idle_count()
# ═══════════════════════════════════════════════════════════════════════════════

func test_total_count_after_registration() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	sched.register_brain(_make_llm(), "gamemaster", "small")
	if sched.get_total_count() != 2:
		return _fail("total_count: expected 2, got %d" % sched.get_total_count())
	return true


func test_alive_count_all_alive_after_register() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	sched.register_brain(_make_llm(), "worker", "small")
	if sched.get_alive_count() != 2:
		return _fail("alive_count initial: expected 2, got %d" % sched.get_alive_count())
	return true


func test_idle_count_all_idle_initially() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	sched.register_brain(_make_llm(), "worker", "small")
	if sched.get_idle_count() != 2:
		return _fail("idle_count initial: expected 2, got %d" % sched.get_idle_count())
	return true


func test_idle_count_decreases_after_request() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	sched.register_brain(llm, "narrator", "small")
	var _acquired: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.NORMAL)
	if sched.get_idle_count() != 0:
		return _fail("idle_count after request: expected 0, got %d" % sched.get_idle_count())
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_current_tier() — integer tier value
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_current_tier_returns_single_int_for_one_brain() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	var tier: int = sched.get_current_tier()
	if tier != BrainSwarmScheduler.Tier.SINGLE:
		return _fail("get_current_tier: expected SINGLE (%d), got %d" % [BrainSwarmScheduler.Tier.SINGLE, tier])
	return true


func test_get_current_tier_returns_full_int_for_four_brains() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	for _i in range(4):
		sched.register_brain(_make_llm(), "worker", "small")
	var tier: int = sched.get_current_tier()
	if tier != BrainSwarmScheduler.Tier.FULL:
		return _fail("get_current_tier full: expected FULL (%d), got %d" % [BrainSwarmScheduler.Tier.FULL, tier])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_tier_name() — tier string after various alive counts
# ═══════════════════════════════════════════════════════════════════════════════

func test_tier_single_with_one_brain() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	var name: String = sched.get_tier_name()
	if name != "SINGLE":
		return _fail("tier single: expected SINGLE, got '%s'" % name)
	return true


func test_tier_dual_with_two_brains() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	sched.register_brain(_make_llm(), "gamemaster", "small")
	var name: String = sched.get_tier_name()
	if name != "DUAL":
		return _fail("tier dual: expected DUAL, got '%s'" % name)
	return true


func test_tier_slim_with_three_brains() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	for _i in range(3):
		sched.register_brain(_make_llm(), "worker", "small")
	var name: String = sched.get_tier_name()
	if name != "SLIM":
		return _fail("tier slim: expected SLIM, got '%s'" % name)
	return true


func test_tier_full_with_four_brains() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	for _i in range(4):
		sched.register_brain(_make_llm(), "worker", "small")
	var name: String = sched.get_tier_name()
	if name != "FULL":
		return _fail("tier full: expected FULL, got '%s'" % name)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _count_to_tier() — static boundary mapping
# ═══════════════════════════════════════════════════════════════════════════════

func test_count_to_tier_zero_is_single() -> bool:
	var tier: int = BrainSwarmScheduler._count_to_tier(0)
	if tier != BrainSwarmScheduler.Tier.SINGLE:
		return _fail("count_to_tier 0: expected SINGLE (%d), got %d" % [BrainSwarmScheduler.Tier.SINGLE, tier])
	return true


func test_count_to_tier_one_is_single() -> bool:
	var tier: int = BrainSwarmScheduler._count_to_tier(1)
	if tier != BrainSwarmScheduler.Tier.SINGLE:
		return _fail("count_to_tier 1: expected SINGLE, got %d" % tier)
	return true


func test_count_to_tier_two_is_dual() -> bool:
	var tier: int = BrainSwarmScheduler._count_to_tier(2)
	if tier != BrainSwarmScheduler.Tier.DUAL:
		return _fail("count_to_tier 2: expected DUAL, got %d" % tier)
	return true


func test_count_to_tier_three_is_slim() -> bool:
	var tier: int = BrainSwarmScheduler._count_to_tier(3)
	if tier != BrainSwarmScheduler.Tier.SLIM:
		return _fail("count_to_tier 3: expected SLIM, got %d" % tier)
	return true


func test_count_to_tier_four_is_full() -> bool:
	var tier: int = BrainSwarmScheduler._count_to_tier(4)
	if tier != BrainSwarmScheduler.Tier.FULL:
		return _fail("count_to_tier 4: expected FULL, got %d" % tier)
	return true


func test_count_to_tier_five_is_still_full() -> bool:
	var tier: int = BrainSwarmScheduler._count_to_tier(5)
	if tier != BrainSwarmScheduler.Tier.FULL:
		return _fail("count_to_tier 5: expected FULL (boundary >=4), got %d" % tier)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _get_compatible_roles() — fallback chains
# ═══════════════════════════════════════════════════════════════════════════════

func test_compatible_roles_narrator_fallback_chain() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var roles: Array = sched._get_compatible_roles("narrator")
	if not roles.has("worker"):
		return _fail("compatible narrator: expected 'worker' in chain, got %s" % str(roles))
	if not roles.has("gamemaster"):
		return _fail("compatible narrator: expected 'gamemaster' in chain, got %s" % str(roles))
	return true


func test_compatible_roles_gamemaster_fallback_chain() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var roles: Array = sched._get_compatible_roles("gamemaster")
	if not roles.has("worker"):
		return _fail("compatible gamemaster: expected 'worker', got %s" % str(roles))
	return true


func test_compatible_roles_judge_has_analytical_fallbacks() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var roles: Array = sched._get_compatible_roles("judge")
	if not roles.has("worker"):
		return _fail("compatible judge: expected 'worker', got %s" % str(roles))
	if not roles.has("gamemaster"):
		return _fail("compatible judge: expected 'gamemaster', got %s" % str(roles))
	return true


func test_compatible_roles_voice_has_worker_fallback() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var roles: Array = sched._get_compatible_roles("voice")
	if not roles.has("worker"):
		return _fail("compatible voice: expected 'worker', got %s" % str(roles))
	return true


func test_compatible_roles_unknown_returns_all() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var roles: Array = sched._get_compatible_roles("unknown_role")
	if roles.size() < 3:
		return _fail("compatible unknown: expected >= 3 roles, got %d" % roles.size())
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# request_brain() — allocation strategies
# ═══════════════════════════════════════════════════════════════════════════════

func test_request_brain_returns_exact_role_match_first() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var narrator_llm: StubLLM = _make_llm()
	var worker_llm: StubLLM = _make_llm()
	sched.register_brain(narrator_llm, "narrator", "small")
	sched.register_brain(worker_llm, "worker", "small")
	var acquired: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.NORMAL)
	if acquired != narrator_llm:
		return _fail("request exact role: expected narrator_llm, got different object")
	return true


func test_request_brain_falls_back_to_compatible_role() -> bool:
	# narrator busy — request for narrator should fall back to worker
	var sched: BrainSwarmScheduler = _make_scheduler()
	var narrator_llm: StubLLM = _make_llm()
	var worker_llm: StubLLM = _make_llm()
	sched.register_brain(narrator_llm, "narrator", "small")
	sched.register_brain(worker_llm, "worker", "small")
	# Occupy the narrator
	var _first: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.NORMAL)
	# Now request narrator again — narrator is busy, should fall back to worker
	var fallback: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.NORMAL)
	if fallback == null:
		return _fail("request fallback: expected a compatible brain, got null")
	if fallback == narrator_llm:
		return _fail("request fallback: narrator was busy, should not be returned again")
	return true


func test_request_brain_returns_null_when_all_busy() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	sched.register_brain(llm, "narrator", "small")
	# Occupy the only brain
	var _first: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.NORMAL)
	# Request again with non-CRITICAL priority — no preemption, must return null
	var second: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.NORMAL)
	if second != null:
		return _fail("request null when busy: expected null for NORMAL priority when all busy, got non-null")
	return true


func test_request_brain_critical_preempts_low_priority_and_calls_cancel() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var stub: StubLLM = _make_llm()
	sched.register_brain(stub, "narrator", "small")
	# Occupy with LOW priority
	var _first: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.LOW)
	# CRITICAL request should preempt and call cancel_generation on the stub
	var critical: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.CRITICAL)
	if critical == null:
		return _fail("critical preempt: expected non-null from preemption, got null")
	if not stub.cancelled:
		return _fail("critical preempt: cancel_generation() was not called on the preempted stub")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# mark_brain_dead() / mark_brain_alive() — tier degradation and recovery
# ═══════════════════════════════════════════════════════════════════════════════

func test_mark_brain_dead_reduces_alive_count() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	sched.register_brain(llm, "narrator", "small")
	sched.register_brain(_make_llm(), "gamemaster", "small")
	sched.mark_brain_dead(llm)
	if sched.get_alive_count() != 1:
		return _fail("mark_dead: expected alive_count=1, got %d" % sched.get_alive_count())
	return true


func test_mark_brain_dead_degrades_tier() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm1: StubLLM = _make_llm()
	var llm2: StubLLM = _make_llm()
	sched.register_brain(llm1, "narrator", "small")
	sched.register_brain(llm2, "gamemaster", "small")
	sched.mark_brain_dead(llm1)
	if sched.get_tier_name() != "SINGLE":
		return _fail("mark_dead degrade: expected SINGLE after killing one of two, got '%s'" % sched.get_tier_name())
	return true


func test_mark_brain_dead_excludes_dead_brain_from_idle_count() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	sched.register_brain(llm, "narrator", "small")
	sched.mark_brain_dead(llm)
	# Dead brain must not appear as idle even though it is not busy
	if sched.get_idle_count() != 0:
		return _fail("mark_dead idle: dead brain should not count as idle, got idle_count=%d" % sched.get_idle_count())
	return true


func test_mark_brain_alive_recovers_tier() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm1: StubLLM = _make_llm()
	var llm2: StubLLM = _make_llm()
	sched.register_brain(llm1, "narrator", "small")
	sched.register_brain(llm2, "gamemaster", "small")
	sched.mark_brain_dead(llm1)
	sched.mark_brain_alive(llm1)
	if sched.get_tier_name() != "DUAL":
		return _fail("mark_alive recover: expected DUAL, got '%s'" % sched.get_tier_name())
	return true


func test_mark_brain_alive_on_already_alive_is_idempotent() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	sched.register_brain(llm, "narrator", "small")
	# Brain is already alive — calling mark_alive again must not change count
	sched.mark_brain_alive(llm)
	if sched.get_alive_count() != 1:
		return _fail("mark_alive idempotent: expected alive_count=1, got %d" % sched.get_alive_count())
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# release_brain() — busy flag cleared, stats updated
# ═══════════════════════════════════════════════════════════════════════════════

func test_release_brain_makes_idle() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	sched.register_brain(llm, "narrator", "small")
	var _acquired: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.NORMAL)
	sched.release_brain(llm)
	if sched.get_idle_count() != 1:
		return _fail("release_brain: expected idle_count=1 after release, got %d" % sched.get_idle_count())
	return true


func test_release_brain_increments_tasks_completed() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	sched.register_brain(llm, "narrator", "small")
	var _acquired: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.NORMAL)
	sched.release_brain(llm)
	var stats: Array = sched.get_stats()
	if int(stats[0].get("tasks_completed", 0)) != 1:
		return _fail("release tasks_completed: expected 1, got %d" % int(stats[0].get("tasks_completed", 0)))
	return true


func test_release_brain_on_unknown_llm_is_noop() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var registered: StubLLM = _make_llm()
	var unregistered: StubLLM = _make_llm()
	sched.register_brain(registered, "narrator", "small")
	# Release an object that was never registered — must not crash and must not alter state
	sched.release_brain(unregistered)
	if sched.get_total_count() != 1:
		return _fail("release unknown: total_count changed after releasing unknown llm")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_stats() — shape and required fields
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_stats_returns_one_entry_per_brain() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	sched.register_brain(_make_llm(), "worker", "large")
	var stats: Array = sched.get_stats()
	if stats.size() != 2:
		return _fail("get_stats size: expected 2, got %d" % stats.size())
	return true


func test_get_stats_entry_has_required_fields() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	var stats: Array = sched.get_stats()
	if stats.is_empty():
		return _fail("get_stats fields: stats empty")
	var entry: Dictionary = stats[0]
	var required: Array = ["index", "role", "busy", "alive", "model_size", "tasks_completed", "total_busy_ms"]
	for field in required:
		if not entry.has(field):
			return _fail("get_stats fields: missing field '%s' in stats entry" % field)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# check_timeouts() — returns empty when no brains have timed out
# ═══════════════════════════════════════════════════════════════════════════════

func test_check_timeouts_returns_empty_when_no_brains_registered() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var released: Array = sched.check_timeouts()
	if not released.is_empty():
		return _fail("check_timeouts empty: expected [] with no brains, got %d items" % released.size())
	return true


func test_check_timeouts_returns_empty_for_freshly_acquired_brain() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	sched.register_brain(llm, "narrator", "small")
	var _acquired: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.NORMAL)
	# Timeout for small brain is 30 000 ms — just acquired, so no timeout yet
	var released: Array = sched.check_timeouts()
	if not released.is_empty():
		return _fail("check_timeouts fresh: expected [] for just-acquired brain, got %d items" % released.size())
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# clear() — full reset
# ═══════════════════════════════════════════════════════════════════════════════

func test_clear_empties_brains() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	sched.register_brain(_make_llm(), "worker", "small")
	sched.clear()
	if sched.get_total_count() != 0:
		return _fail("clear: expected total_count=0, got %d" % sched.get_total_count())
	return true


func test_clear_resets_tier_to_single() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	for _i in range(4):
		sched.register_brain(_make_llm(), "worker", "small")
	sched.clear()
	if sched.get_tier_name() != "SINGLE":
		return _fail("clear tier: expected SINGLE after clear, got '%s'" % sched.get_tier_name())
	return true
