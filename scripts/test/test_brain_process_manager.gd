## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — BrainProcessManager (pure-logic, no process spawning)
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage:
##   configure()           — populates _brain_configs, ports, roles, restart counts
##   get_brain_count()     — returns _brain_configs.size()
##   get_running_count()   — counts PIDs > 0
##   get_brain_info()      — correct index/role/port/pid/restarts fields
##   create_backend()      — returns null for out-of-range index
##   poll_health()         — returns [] when called too soon (interval guard)
##   stop_all()            — clears all arrays after call
##
## Pattern: extends RefCounted, NO class_name, test_xxx() -> bool
## Note: start_all() and wait_for_healthy() are NOT tested here because they
##       require FileAccess.file_exists() + OS.create_process() (system calls).
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ─── Factory helpers ──────────────────────────────────────────────────────────

func _make_manager() -> BrainProcessManager:
	return BrainProcessManager.new()


func _make_brain_defs(count: int) -> Array:
	var defs: Array = []
	for i in range(count):
		defs.append({
			"role": ["narrator", "gamemaster", "worker", "worker"][i % 4],
			"model": "/fake/model_%d.gguf" % i,
			"threads": 2,
			"n_ctx": 512,
		})
	return defs


# ═══════════════════════════════════════════════════════════════════════════════
# configure() — state initialisation
# ═══════════════════════════════════════════════════════════════════════════════

func test_configure_sets_brain_count() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/llama-server.exe", _make_brain_defs(3))
	if mgr.get_brain_count() != 3:
		push_error("configure brain_count: expected 3, got %d" % mgr.get_brain_count())
		return false
	return true


func test_configure_assigns_sequential_ports() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/llama-server.exe", _make_brain_defs(3))
	var info: Array = mgr.get_brain_info()
	for i in range(3):
		var expected_port: int = BrainProcessManager.BASE_PORT + i
		var actual_port: int = int(info[i].get("port", 0))
		if actual_port != expected_port:
			push_error("configure ports: brain %d expected port %d, got %d" % [i, expected_port, actual_port])
			return false
	return true


func test_configure_assigns_roles_from_defs() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	var defs: Array = [
		{"role": "narrator", "model": "/m.gguf", "threads": 2, "n_ctx": 512},
		{"role": "gamemaster", "model": "/m.gguf", "threads": 2, "n_ctx": 512},
	]
	mgr.configure("/fake/server.exe", defs)
	var info: Array = mgr.get_brain_info()
	if str(info[0].get("role", "")) != "narrator":
		push_error("configure role[0]: expected narrator, got '%s'" % str(info[0].get("role", "")))
		return false
	if str(info[1].get("role", "")) != "gamemaster":
		push_error("configure role[1]: expected gamemaster, got '%s'" % str(info[1].get("role", "")))
		return false
	return true


func test_configure_initialises_pids_to_minus_one() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(2))
	var info: Array = mgr.get_brain_info()
	for i in range(2):
		if int(info[i].get("pid", 0)) != -1:
			push_error("configure pid[%d]: expected -1, got %d" % [i, int(info[i].get("pid", 0))])
			return false
	return true


func test_configure_initialises_restart_counts_to_zero() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(2))
	var info: Array = mgr.get_brain_info()
	for i in range(2):
		if int(info[i].get("restarts", 1)) != 0:
			push_error("configure restarts[%d]: expected 0, got %d" % [i, int(info[i].get("restarts", 1))])
			return false
	return true


func test_configure_with_empty_defs_sets_zero_count() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", [])
	if mgr.get_brain_count() != 0:
		push_error("configure empty: expected 0, got %d" % mgr.get_brain_count())
		return false
	return true


func test_configure_reconfigures_cleanly() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(3))
	# Reconfigure with different count — previous state must be replaced
	mgr.configure("/fake/server.exe", _make_brain_defs(1))
	if mgr.get_brain_count() != 1:
		push_error("reconfigure: expected 1 after second configure, got %d" % mgr.get_brain_count())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_running_count() — counts PIDs > 0
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_running_count_zero_before_start() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(2))
	if mgr.get_running_count() != 0:
		push_error("running_count before start: expected 0, got %d" % mgr.get_running_count())
		return false
	return true


func test_get_running_count_reflects_pids() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(3))
	# Manually inject fake PIDs to simulate two started brains
	mgr._brain_pids[0] = 1234
	mgr._brain_pids[1] = 5678
	# _brain_pids[2] stays -1
	if mgr.get_running_count() != 2:
		push_error("running_count pids: expected 2, got %d" % mgr.get_running_count())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_brain_info() — diagnostic snapshot
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_brain_info_has_required_keys() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(2))
	var info: Array = mgr.get_brain_info()
	var required_keys: Array = ["index", "role", "port", "pid", "running", "restarts"]
	for entry in info:
		for key in required_keys:
			if not entry.has(key):
				push_error("get_brain_info missing key '%s'" % key)
				return false
	return true


func test_get_brain_info_index_matches_position() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(3))
	var info: Array = mgr.get_brain_info()
	for i in range(3):
		if int(info[i].get("index", -1)) != i:
			push_error("brain_info index[%d]: expected %d, got %d" % [i, i, int(info[i].get("index", -1))])
			return false
	return true


func test_get_brain_info_running_false_when_pid_minus_one() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(1))
	var info: Array = mgr.get_brain_info()
	if info[0].get("running", true) != false:
		push_error("brain_info running: expected false for pid=-1")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# create_backend() — bounds checking
# ═══════════════════════════════════════════════════════════════════════════════

func test_create_backend_out_of_range_returns_null() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(2))
	var backend: Object = mgr.create_backend(99)
	if backend != null:
		push_error("create_backend oob: expected null for index 99")
		return false
	return true


func test_create_backend_negative_index_returns_null() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(2))
	var backend: Object = mgr.create_backend(-1)
	if backend != null:
		push_error("create_backend negative: expected null for index -1")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# poll_health() — interval guard returns [] when too soon
# ═══════════════════════════════════════════════════════════════════════════════

func test_poll_health_returns_empty_when_called_immediately() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(1))
	# _last_health_ms starts at 0, but first call sets it to now.
	# Second call within HEALTH_CHECK_INTERVAL_MS returns [].
	var _first: Array = mgr.poll_health()
	var second: Array = mgr.poll_health()
	if second.size() != 0:
		push_error("poll_health interval: expected [] on second immediate call, got size %d" % second.size())
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# stop_all() — clears all arrays
# ═══════════════════════════════════════════════════════════════════════════════

func test_stop_all_clears_brain_count() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(3))
	# Inject fake PIDs to avoid OS.kill() on real PIDs (pid=-1 is skipped in _kill_brain)
	# We leave pids at -1 so _kill_brain() is a no-op, then stop_all() clears arrays.
	mgr.stop_all()
	if mgr.get_brain_count() != 0:
		push_error("stop_all: expected brain_count=0, got %d" % mgr.get_brain_count())
		return false
	return true


func test_stop_all_clears_running_count() -> bool:
	var mgr: BrainProcessManager = _make_manager()
	mgr.configure("/fake/server.exe", _make_brain_defs(2))
	mgr.stop_all()
	if mgr.get_running_count() != 0:
		push_error("stop_all running: expected 0, got %d" % mgr.get_running_count())
		return false
	return true
