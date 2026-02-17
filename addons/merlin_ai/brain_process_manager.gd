## BrainProcessManager — Auto-spawn and manage llama-server.exe processes
##
## Launches one llama-server.exe per brain, each on a dedicated port.
## Monitors health, restarts crashed processes, and cleanly shuts down on exit.
## Used by merlin_ai.gd._try_init_bitnet() to auto-start the swarm.
extends RefCounted
class_name BrainProcessManager

const BitNetBackendScript = preload("res://addons/merlin_ai/bitnet_backend.gd")

# ── Configuration ─────────────────────────────────────────────────────────────
const BASE_PORT := 8081
const MAX_BRAINS := 4
const HEALTH_CHECK_INTERVAL_MS := 10000  # 10s between health polls
const HEALTH_TIMEOUT_MS := 3000
const STARTUP_TIMEOUT_MS := 30000  # 30s max to wait for model load
const RESTART_COOLDOWN_MS := 5000
const MAX_RESTART_ATTEMPTS := 3

# ── Paths (auto-detected or overridden) ───────────────────────────────────────
var llama_server_path: String = ""
var model_paths: Dictionary = {}  # role -> model_path

# ── Brain Configs ─────────────────────────────────────────────────────────────
# Each entry: {role, model, threads, n_ctx, port}
var _brain_configs: Array = []
var _brain_pids: Array = []        # PID per brain (-1 if not running)
var _brain_ports: Array = []       # Port per brain
var _brain_roles: Array = []       # Role per brain
var _restart_counts: Array = []    # Restart attempts per brain
var _last_health_ms: int = 0
var _is_running := false


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

## Configure the manager with brain definitions. Call before start().
## brain_defs: Array of {role: String, model: String, threads: int, n_ctx: int}
func configure(server_path: String, brain_defs: Array) -> void:
	llama_server_path = server_path
	_brain_configs = brain_defs.duplicate(true)
	_brain_pids.clear()
	_brain_ports.clear()
	_brain_roles.clear()
	_restart_counts.clear()
	for i in range(_brain_configs.size()):
		_brain_pids.append(-1)
		_brain_ports.append(BASE_PORT + i)
		_brain_roles.append(_brain_configs[i].get("role", "worker"))
		_restart_counts.append(0)


## Start all configured brains. Returns the number of brains successfully started.
func start_all() -> int:
	if llama_server_path == "" or not FileAccess.file_exists(llama_server_path):
		push_warning("[BrainProcessManager] llama-server.exe not found: %s" % llama_server_path)
		return 0
	_is_running = true
	var started := 0
	for i in range(_brain_configs.size()):
		if _start_brain(i):
			started += 1
	return started


## Wait for all brains to become healthy (model loaded). Returns count of healthy brains.
func wait_for_healthy(timeout_ms: int = STARTUP_TIMEOUT_MS) -> int:
	var start := Time.get_ticks_msec()
	var healthy_count := 0
	var checked := PackedByteArray()
	checked.resize(_brain_configs.size())
	checked.fill(0)

	while healthy_count < _brain_configs.size():
		if Time.get_ticks_msec() - start > timeout_ms:
			break
		for i in range(_brain_configs.size()):
			if checked[i] == 1:
				continue
			if _brain_pids[i] < 0:
				checked[i] = 1  # Skip — failed to start
				continue
			if _check_brain_health(i):
				checked[i] = 1
				healthy_count += 1
				print("[BrainProcessManager] Brain %d (%s) healthy on port %d" % [i + 1, _brain_roles[i], _brain_ports[i]])
		if healthy_count < _brain_configs.size():
			OS.delay_msec(500)
	return healthy_count


## Create a BitNetBackend connected to brain at index i.
func create_backend(brain_index: int) -> Object:
	if brain_index < 0 or brain_index >= _brain_configs.size():
		return null
	var backend := BitNetBackendScript.new()
	backend.port = _brain_ports[brain_index]
	backend.brain_role = _brain_roles[brain_index]
	return backend


## Poll health of all brains. Call periodically (e.g., from _process).
## Returns array of booleans (true = healthy).
func poll_health() -> Array:
	var now := Time.get_ticks_msec()
	if now - _last_health_ms < HEALTH_CHECK_INTERVAL_MS:
		return []  # Not time yet
	_last_health_ms = now

	var results: Array = []
	for i in range(_brain_configs.size()):
		if _brain_pids[i] < 0:
			results.append(false)
			continue
		# Check if process is still running
		if not OS.is_process_running(_brain_pids[i]):
			print("[BrainProcessManager] Brain %d (%s) crashed (PID %d)" % [i + 1, _brain_roles[i], _brain_pids[i]])
			_brain_pids[i] = -1
			_try_restart_brain(i)
			results.append(false)
			continue
		# HTTP health check
		var healthy := _check_brain_health(i)
		results.append(healthy)
	return results


## Stop all brain processes.
func stop_all() -> void:
	_is_running = false
	for i in range(_brain_pids.size()):
		_kill_brain(i)
	_brain_pids.clear()
	_brain_ports.clear()
	_brain_roles.clear()
	_restart_counts.clear()
	_brain_configs.clear()


## Get the number of configured brains.
func get_brain_count() -> int:
	return _brain_configs.size()


## Get the number of running brains (PID > 0).
func get_running_count() -> int:
	var count := 0
	for pid in _brain_pids:
		if pid > 0:
			count += 1
	return count


## Get info about all brains for diagnostics.
func get_brain_info() -> Array:
	var info: Array = []
	for i in range(_brain_configs.size()):
		info.append({
			"index": i,
			"role": _brain_roles[i] if i < _brain_roles.size() else "unknown",
			"port": _brain_ports[i] if i < _brain_ports.size() else 0,
			"pid": _brain_pids[i] if i < _brain_pids.size() else -1,
			"running": _brain_pids[i] > 0 and OS.is_process_running(_brain_pids[i]) if i < _brain_pids.size() else false,
			"restarts": _restart_counts[i] if i < _restart_counts.size() else 0,
		})
	return info


# ═══════════════════════════════════════════════════════════════════════════════
# PRIVATE — Process Management
# ═══════════════════════════════════════════════════════════════════════════════

func _start_brain(index: int) -> bool:
	var cfg: Dictionary = _brain_configs[index]
	var model_path: String = cfg.get("model", "")
	if model_path == "" or not FileAccess.file_exists(model_path):
		push_warning("[BrainProcessManager] Brain %d: model not found: %s" % [index + 1, model_path])
		return false

	var port: int = _brain_ports[index]
	var threads: int = cfg.get("threads", 2)
	var n_ctx: int = cfg.get("n_ctx", 512)

	var args := PackedStringArray([
		"-m", model_path,
		"--port", str(port),
		"--host", "127.0.0.1",
		"-t", str(threads),
		"-c", str(n_ctx),
		"--log-disable",
	])

	var pid := OS.create_process(llama_server_path, args)
	if pid <= 0:
		push_warning("[BrainProcessManager] Brain %d: failed to create process" % [index + 1])
		return false

	_brain_pids[index] = pid
	print("[BrainProcessManager] Brain %d (%s) started: PID %d, port %d, threads=%d, n_ctx=%d" % [
		index + 1, _brain_roles[index], pid, port, threads, n_ctx
	])
	return true


func _kill_brain(index: int) -> void:
	if index >= _brain_pids.size():
		return
	var pid: int = _brain_pids[index]
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
		print("[BrainProcessManager] Brain %d (%s) killed: PID %d" % [index + 1, _brain_roles[index], pid])
	_brain_pids[index] = -1


func _try_restart_brain(index: int) -> void:
	if not _is_running:
		return
	if _restart_counts[index] >= MAX_RESTART_ATTEMPTS:
		push_warning("[BrainProcessManager] Brain %d: max restart attempts (%d) reached" % [index + 1, MAX_RESTART_ATTEMPTS])
		return
	_restart_counts[index] += 1
	print("[BrainProcessManager] Brain %d: restart attempt %d/%d" % [index + 1, _restart_counts[index], MAX_RESTART_ATTEMPTS])
	OS.delay_msec(RESTART_COOLDOWN_MS)
	_start_brain(index)


func _check_brain_health(index: int) -> bool:
	var port: int = _brain_ports[index]
	var client := HTTPClient.new()
	var err := client.connect_to_host("127.0.0.1", port)
	if err != OK:
		return false
	var start := Time.get_ticks_msec()
	while client.get_status() == HTTPClient.STATUS_CONNECTING or client.get_status() == HTTPClient.STATUS_RESOLVING:
		client.poll()
		OS.delay_msec(10)
		if Time.get_ticks_msec() - start > HEALTH_TIMEOUT_MS:
			return false
	if client.get_status() != HTTPClient.STATUS_CONNECTED:
		return false
	err = client.request(HTTPClient.METHOD_GET, "/health", [])
	if err != OK:
		return false
	while client.get_status() == HTTPClient.STATUS_REQUESTING:
		client.poll()
		OS.delay_msec(10)
		if Time.get_ticks_msec() - start > HEALTH_TIMEOUT_MS:
			return false
	if not client.has_response():
		return false
	if client.get_response_code() != 200:
		return false
	var body := PackedByteArray()
	while client.get_status() == HTTPClient.STATUS_BODY:
		client.poll()
		var chunk := client.read_response_body_chunk()
		if chunk.size() > 0:
			body.append_array(chunk)
		OS.delay_msec(1)
	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		return false
	var data: Dictionary = json.data if json.data is Dictionary else {}
	return data.get("status", "") == "ok"
