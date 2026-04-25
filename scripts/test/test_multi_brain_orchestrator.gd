## =============================================================================
## Unit Tests — MultiBrainOrchestrator (backend-agnostic multi-instance dispatch)
## =============================================================================
## Validates:
##   - Construction / signals exist
##   - register_brain() registers a Callable provider
##   - dispatch_parallel() runs registered providers concurrently via WorkerThreadPool
##   - all_brains_done emitted after all providers complete
##   - empty result triggers brain_failed signal
##   - cancel() aborts pending dispatch
## =============================================================================

extends RefCounted

const MultiBrainOrchestrator = preload("res://scripts/merlin/multi_brain_orchestrator.gd")


func _fail(msg: String) -> bool:
	push_error(msg)
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# CONSTRUCTION & SIGNALS
# ═══════════════════════════════════════════════════════════════════════════════

func test_orchestrator_construct() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	if orch == null:
		return _fail("MultiBrainOrchestrator.new() returned null")
	return true


func test_signal_brain_ready_exists() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	if not orch.has_signal("brain_ready"):
		return _fail("signal brain_ready missing")
	return true


func test_signal_brain_failed_exists() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	if not orch.has_signal("brain_failed"):
		return _fail("signal brain_failed missing")
	return true


func test_signal_all_brains_done_exists() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	if not orch.has_signal("all_brains_done"):
		return _fail("signal all_brains_done missing")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# REGISTER & STATE
# ═══════════════════════════════════════════════════════════════════════════════

func test_register_brain_stores_callable() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	var dummy := func(_p: String) -> String: return "ok"
	orch.register_brain(&"narrator", dummy)
	if not orch.has_brain(&"narrator"):
		return _fail("has_brain(narrator) should return true after register")
	return true


func test_has_brain_returns_false_for_unregistered() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	if orch.has_brain(&"nonexistent"):
		return _fail("has_brain(nonexistent) should return false")
	return true


func test_unregister_brain_removes() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	var dummy := func(_p: String) -> String: return "ok"
	orch.register_brain(&"narrator", dummy)
	orch.unregister_brain(&"narrator")
	if orch.has_brain(&"narrator"):
		return _fail("has_brain(narrator) should be false after unregister")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DISPATCH RESULT (sync provider — no WorkerThreadPool actual concurrency tested)
# ═══════════════════════════════════════════════════════════════════════════════

func test_dispatch_calls_provider() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	var called := [false]
	var prov := func(_p: String) -> String:
		called[0] = true
		return "narrator-output"
	orch.register_brain(&"narrator", prov)
	var results: Dictionary = orch.dispatch_blocking({"narrator": "test prompt"})
	if not called[0]:
		return _fail("provider was never called by dispatch_blocking")
	if str(results.get("narrator", "")) != "narrator-output":
		return _fail("expected 'narrator-output', got '" + str(results.get("narrator", "")) + "'")
	return true


func test_dispatch_multiple_brains_returns_all_results() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	orch.register_brain(&"narrator", func(_p: String) -> String: return "story")
	orch.register_brain(&"gamemaster", func(_p: String) -> String: return "effects")
	var results: Dictionary = orch.dispatch_blocking({"narrator": "p1", "gamemaster": "p2"})
	if results.size() != 2:
		return _fail("expected 2 results, got " + str(results.size()))
	if str(results.get("narrator", "")) != "story":
		return _fail("narrator result wrong")
	if str(results.get("gamemaster", "")) != "effects":
		return _fail("gamemaster result wrong")
	return true


func test_dispatch_unknown_role_skipped() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	orch.register_brain(&"narrator", func(_p: String) -> String: return "story")
	var results: Dictionary = orch.dispatch_blocking({"narrator": "p1", "unknown_role": "p2"})
	if results.size() != 1:
		return _fail("expected 1 result (unknown skipped), got " + str(results.size()))
	if results.has("unknown_role"):
		return _fail("unknown_role should not be in results")
	return true


func test_dispatch_empty_prompts_returns_empty() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	var results: Dictionary = orch.dispatch_blocking({})
	if not results.is_empty():
		return _fail("empty prompts should yield empty results")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CANCEL & CLEANUP
# ═══════════════════════════════════════════════════════════════════════════════

func test_cancel_clears_pending() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	orch.register_brain(&"narrator", func(_p: String) -> String: return "x")
	orch.cancel()
	if orch.is_dispatching():
		return _fail("is_dispatching should be false after cancel")
	return true


func test_get_registered_roles_returns_array() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	orch.register_brain(&"narrator", func(_p: String) -> String: return "a")
	orch.register_brain(&"gamemaster", func(_p: String) -> String: return "b")
	var roles: Array = orch.get_registered_roles()
	if roles.size() != 2:
		return _fail("expected 2 registered roles, got " + str(roles.size()))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DISPATCH_THREADED (true concurrency via WorkerThreadPool)
# ═══════════════════════════════════════════════════════════════════════════════

func test_dispatch_threaded_method_exists() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	if not orch.has_method("dispatch_threaded"):
		return _fail("MultiBrainOrchestrator.dispatch_threaded() not implemented")
	return true


func test_dispatch_threaded_returns_results() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	orch.register_brain(&"a", func(_p: String) -> String: return "result_a")
	orch.register_brain(&"b", func(_p: String) -> String: return "result_b")
	var results: Dictionary = orch.dispatch_threaded({"a": "p1", "b": "p2"})
	if results.size() != 2:
		return _fail("expected 2 results, got " + str(results.size()))
	if str(results.get("a", "")) != "result_a":
		return _fail("a wrong: " + str(results.get("a", "")))
	if str(results.get("b", "")) != "result_b":
		return _fail("b wrong: " + str(results.get("b", "")))
	return true


func test_dispatch_threaded_unregistered_role_skipped() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	orch.register_brain(&"a", func(_p: String) -> String: return "x")
	var results: Dictionary = orch.dispatch_threaded({"a": "p", "missing": "q"})
	if results.size() != 1:
		return _fail("expected 1 result (missing skipped), got " + str(results.size()))
	return true


func test_dispatch_threaded_clears_is_dispatching_after() -> bool:
	var orch: MultiBrainOrchestrator = MultiBrainOrchestrator.new()
	orch.register_brain(&"a", func(_p: String) -> String: return "ok")
	orch.dispatch_threaded({"a": "p"})
	if orch.is_dispatching():
		return _fail("is_dispatching should be false after dispatch_threaded completes")
	return true
