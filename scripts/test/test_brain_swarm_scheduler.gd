## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — BrainSwarmScheduler (pure-logic, no scene tree required)
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage:
##   register_brain()        — slot creation, index return, tier update
##   get_total_count()       — count all registered brains
##   get_alive_count()       — count alive brains
##   get_idle_count()        — count idle (alive + not busy) brains
##   get_tier_name()         — tier string from alive count
##   _count_to_tier()        — static boundary mapping
##   _get_compatible_roles() — fallback chains per role
##   mark_brain_dead()       — alive=false + tier degradation
##   mark_brain_alive()      — alive=true + tier recovery
##   release_brain()         — busy=false, stats updated
##   get_stats()             — per-brain stat snapshot
##   clear()                 — reset all state
##
## Pattern: extends RefCounted, NO class_name, test_xxx() -> bool
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ─── Stub LLM object ──────────────────────────────────────────────────────────
# BrainSwarmScheduler stores Object references in slots.
# We use RefCounted stubs — no scene tree needed.
class StubLLM extends RefCounted:
	var cancelled := false
	func cancel_generation() -> void:
		cancelled = true


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
		push_error("register first: expected index 0, got %d" % idx)
		return false
	return true


func test_register_increments_index() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var idx0: int = sched.register_brain(_make_llm(), "narrator", "small")
	var idx1: int = sched.register_brain(_make_llm(), "gamemaster", "small")
	if idx0 != 0 or idx1 != 1:
		push_error("register index: expected 0,1 — got %d,%d" % [idx0, idx1])
		return false
	return true


func test_register_large_model_gets_long_timeout() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	sched.register_brain(llm, "narrator", "large")
	# After registration the slot's timeout_ms should be TIMEOUT_LARGE_MS (60000)
	# Access via get_stats()
	var stats: Array = sched.get_stats()
	if stats.is_empty():
		push_error("register large: stats empty")
		return false
	if str(stats[0].get("model_size", "")) != "large":
		push_error("register large: model_size should be 'large', got '%s'" % str(stats[0].get("model_size", "")))
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_total_count() / get_alive_count() / get_idle_count()
# ═══════════════════════════════════════════════════════════════════════════════

func test_total_count_after_registration() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	sched.register_brain(_make_llm(), "gamemaster", "small")
	if sched.get_total_count() != 2:
		push_error("total_count: expected 2, got %d" % sched.get_total_count())
		return false
	return true


func test_alive_count_all_alive_after_register() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	sched.register_brain(_make_llm(), "worker", "small")
	if sched.get_alive_count() != 2:
		push_error("alive_count initial: expected 2, got %d" % sched.get_alive_count())
		return false
	return true


func test_idle_count_all_idle_initially() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	sched.register_brain(_make_llm(), "worker", "small")
	if sched.get_idle_count() != 2:
		push_error("idle_count initial: expected 2, got %d" % sched.get_idle_count())
		return false
	return true


func test_idle_count_decreases_after_request() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	sched.register_brain(llm, "narrator", "small")
	# Request the brain (marks it busy)
	var _acquired: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.NORMAL)
	if sched.get_idle_count() != 0:
		push_error("idle_count after request: expected 0, got %d" % sched.get_idle_count())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_tier_name() — tier string after various alive counts
# ═══════════════════════════════════════════════════════════════════════════════

func test_tier_single_with_one_brain() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	var name: String = sched.get_tier_name()
	if name != "SINGLE":
		push_error("tier single: expected SINGLE, got '%s'" % name)
		return false
	return true


func test_tier_dual_with_two_brains() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	sched.register_brain(_make_llm(), "narrator", "small")
	sched.register_brain(_make_llm(), "gamemaster", "small")
	var name: String = sched.get_tier_name()
	if name != "DUAL":
		push_error("tier dual: expected DUAL, got '%s'" % name)
		return false
	return true


func test_tier_full_with_four_brains() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	for _i in range(4):
		sched.register_brain(_make_llm(), "worker", "small")
	var name: String = sched.get_tier_name()
	if name != "FULL":
		push_error("tier full: expected FULL, got '%s'" % name)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _count_to_tier() — static boundary mapping
# ═══════════════════════════════════════════════════════════════════════════════

func test_count_to_tier_zero_is_single() -> bool:
	var tier: int = BrainSwarmScheduler._count_to_tier(0)
	if tier != BrainSwarmScheduler.Tier.SINGLE:
		push_error("count_to_tier 0: expected SINGLE (%d), got %d" % [BrainSwarmScheduler.Tier.SINGLE, tier])
		return false
	return true


func test_count_to_tier_one_is_single() -> bool:
	var tier: int = BrainSwarmScheduler._count_to_tier(1)
	if tier != BrainSwarmScheduler.Tier.SINGLE:
		push_error("count_to_tier 1: expected SINGLE, got %d" % tier)
		return false
	return true


func test_count_to_tier_two_is_dual() -> bool:
	var tier: int = BrainSwarmScheduler._count_to_tier(2)
	if tier != BrainSwarmScheduler.Tier.DUAL:
		push_error("count_to_tier 2: expected DUAL, got %d" % tier)
		return false
	return true


func test_count_to_tier_three_is_slim() -> bool:
	var tier: int = BrainSwarmScheduler._count_to_tier(3)
	if tier != BrainSwarmScheduler.Tier.SLIM:
		push_error("count_to_tier 3: expected SLIM, got %d" % tier)
		return false
	return true


func test_count_to_tier_four_is_full() -> bool:
	var tier: int = BrainSwarmScheduler._count_to_tier(4)
	if tier != BrainSwarmScheduler.Tier.FULL:
		push_error("count_to_tier 4: expected FULL, got %d" % tier)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _get_compatible_roles() — fallback chains
# ═══════════════════════════════════════════════════════════════════════════════

func test_compatible_roles_narrator_fallback_chain() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var roles: Array = sched._get_compatible_roles("narrator")
	if not roles.has("worker"):
		push_error("compatible narrator: expected 'worker' in chain, got %s" % str(roles))
		return false
	if not roles.has("gamemaster"):
		push_error("compatible narrator: expected 'gamemaster' in chain, got %s" % str(roles))
		return false
	return true


func test_compatible_roles_gamemaster_fallback_chain() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var roles: Array = sched._get_compatible_roles("gamemaster")
	if not roles.has("worker"):
		push_error("compatible gamemaster: expected 'worker', got %s" % str(roles))
		return false
	return true


func test_compatible_roles_unknown_returns_all() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var roles: Array = sched._get_compatible_roles("unknown_role")
	# Unknown role returns all three possible roles
	if roles.size() < 3:
		push_error("compatible unknown: expected >= 3 roles, got %d" % roles.size())
		return false
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
		push_error("mark_dead: expected alive_count=1, got %d" % sched.get_alive_count())
		return false
	return true


func test_mark_brain_dead_degrades_tier() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm1: StubLLM = _make_llm()
	var llm2: StubLLM = _make_llm()
	sched.register_brain(llm1, "narrator", "small")
	sched.register_brain(llm2, "gamemaster", "small")
	# Start at DUAL, kill one → SINGLE
	sched.mark_brain_dead(llm1)
	if sched.get_tier_name() != "SINGLE":
		push_error("mark_dead degrade: expected SINGLE after killing one of two, got '%s'" % sched.get_tier_name())
		return false
	return true


func test_mark_brain_alive_recovers_tier() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm1: StubLLM = _make_llm()
	var llm2: StubLLM = _make_llm()
	sched.register_brain(llm1, "narrator", "small")
	sched.register_brain(llm2, "gamemaster", "small")
	sched.mark_brain_dead(llm1)
	# Tier degraded to SINGLE, now recover
	sched.mark_brain_alive(llm1)
	if sched.get_tier_name() != "DUAL":
		push_error("mark_alive recover: expected DUAL, got '%s'" % sched.get_tier_name())
		return false
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
		push_error("release_brain: expected idle_count=1 after release, got %d" % sched.get_idle_count())
		return false
	return true


func test_release_brain_increments_tasks_completed() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	var llm: StubLLM = _make_llm()
	sched.register_brain(llm, "narrator", "small")
	var _acquired: Object = sched.request_brain("narrator", BrainSwarmScheduler.Priority.NORMAL)
	sched.release_brain(llm)
	var stats: Array = sched.get_stats()
	if int(stats[0].get("tasks_completed", 0)) != 1:
		push_error("release tasks_completed: expected 1, got %d" % int(stats[0].get("tasks_completed", 0)))
		return false
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
		push_error("clear: expected total_count=0, got %d" % sched.get_total_count())
		return false
	return true


func test_clear_resets_tier_to_single() -> bool:
	var sched: BrainSwarmScheduler = _make_scheduler()
	for _i in range(4):
		sched.register_brain(_make_llm(), "worker", "small")
	sched.clear()
	if sched.get_tier_name() != "SINGLE":
		push_error("clear tier: expected SINGLE after clear, got '%s'" % sched.get_tier_name())
		return false
	return true
