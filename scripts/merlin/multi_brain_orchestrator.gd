## MultiBrainOrchestrator — Backend-agnostic multi-instance dispatcher.
##
## Provides a unified interface for running N brains (LLM instances) in parallel
## with isolated state. Backend-agnostic: brains are injected as Callables, so
## the orchestrator works with Ollama HTTP, llama.cpp GDExtension, Groq Cloud,
## or any other backend.
##
## Use cases:
##   - Desktop: 2-3 Ollama instances narrator(N+1) || gamemaster(N) || judge
##   - Mobile: single brain, but uniform API for swap/migration
##   - Tests: mock providers via plain lambdas
##
## Pattern:
##   1. orch.register_brain(&"narrator", my_narrator_callable)
##   2. orch.dispatch_blocking({"narrator": "prompt..."}) -> Dictionary
##   3. (optional) connect to brain_ready / brain_failed / all_brains_done signals
##
## NOTE: dispatch_blocking() runs providers sequentially on the calling thread
## for simplicity and test determinism. For true concurrency on desktop, see
## dispatch_parallel() (TODO Phase 1.3.2 — uses WorkerThreadPool).
extends Node
class_name MultiBrainOrchestrator

signal brain_ready(role: StringName, text: String)
signal brain_failed(role: StringName, error: String)
signal all_brains_done(results: Dictionary)


# role -> Callable(prompt: String) -> String
var _brains: Dictionary = {}

# Track in-flight dispatch (to prevent re-entrancy + support cancel)
var _is_dispatching: bool = false


## Register a brain provider for a given role.
## The callable receives a prompt string and must return a String (response).
## Replaces any previously-registered provider for the same role.
func register_brain(role: StringName, provider: Callable) -> void:
	if not provider.is_valid():
		push_warning("[MultiBrain] Invalid Callable for role: " + str(role))
		return
	_brains[role] = provider


## Remove a brain provider. No-op if role not registered.
func unregister_brain(role: StringName) -> void:
	_brains.erase(role)


## True if a provider is registered for the given role.
func has_brain(role: StringName) -> bool:
	return _brains.has(role)


## Returns an array of all registered roles (StringNames).
func get_registered_roles() -> Array:
	return _brains.keys()


## True while a dispatch is in progress.
func is_dispatching() -> bool:
	return _is_dispatching


## Cancel any in-flight dispatch. Best-effort: providers already started
## will run to completion but their results will be ignored.
func cancel() -> void:
	_is_dispatching = false


## Synchronous dispatch — calls each registered brain provider for the keys
## present in `prompts`. Roles in `prompts` that are NOT registered are silently
## skipped. Roles registered but NOT in `prompts` are also skipped.
##
## Emits `brain_ready` for each successful generation, `brain_failed` if a
## provider returns an empty string, and `all_brains_done` once all are done.
##
## Returns: Dictionary {role: text} with all completed results (empty roles excluded).
func dispatch_blocking(prompts: Dictionary) -> Dictionary:
	_is_dispatching = true
	var results: Dictionary = {}
	for role_v in prompts.keys():
		if not _is_dispatching:
			break  # cancelled mid-dispatch
		var role: StringName = role_v if role_v is StringName else StringName(str(role_v))
		if not _brains.has(role):
			continue  # unregistered role: skip silently
		var prompt: String = str(prompts.get(role_v, ""))
		var provider: Callable = _brains[role]
		var output: String = str(provider.call(prompt))
		results[role] = output
		if output.is_empty():
			brain_failed.emit(role, "empty response")
		else:
			brain_ready.emit(role, output)
	_is_dispatching = false
	all_brains_done.emit(results.duplicate())
	return results


## Threaded dispatch — providers run on Godot's WorkerThreadPool concurrently.
## Blocks the calling thread until all tasks complete (similar to Promise.all).
## True parallel inference on desktop (limited by WorkerThreadPool worker count).
##
## Use this for I/O-bound or compute-heavy providers (LLM inference, HTTP calls).
## For sync/cheap providers, prefer dispatch_blocking() to avoid thread overhead.
##
## Returns: Dictionary {role: text} after all threads have finished.
func dispatch_threaded(prompts: Dictionary) -> Dictionary:
	if _is_dispatching:
		push_warning("[MultiBrain] dispatch_threaded called while already dispatching")
		return {}
	_is_dispatching = true
	var results: Dictionary = {}
	var task_ids: Dictionary = {}  # StringName(role) -> int(task_id)
	var mutex := Mutex.new()
	for role_v in prompts.keys():
		var role: StringName = role_v if role_v is StringName else StringName(str(role_v))
		if not _brains.has(role):
			continue
		var prompt: String = str(prompts.get(role_v, ""))
		var provider: Callable = _brains[role]
		var task := func() -> void:
			var output: String = str(provider.call(prompt))
			mutex.lock()
			results[role] = output
			mutex.unlock()
		var tid: int = WorkerThreadPool.add_task(task, true, "merlin_brain_" + str(role))
		task_ids[role] = tid
	for tid_role in task_ids.keys():
		WorkerThreadPool.wait_for_task_completion(task_ids[tid_role])
	_is_dispatching = false
	# Emit signals on main thread (after all workers complete, no race)
	for role in results.keys():
		var output: String = str(results[role])
		if output.is_empty():
			brain_failed.emit(role, "empty response")
		else:
			brain_ready.emit(role, output)
	all_brains_done.emit(results.duplicate())
	return results
