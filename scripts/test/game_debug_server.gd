extends Node
## GameDebugServer v2 — Full Game Observer for Claude Code orchestration.
## Auto-actif quand OS.is_debug_build() = true (jamais en build exporte).
##
## DOUBLE ECRITURE :
##   user://debug/          — pour VS Code AUTODEV Monitor Live View
##   {project}/tools/autodev/captures/ — pour Claude Code (analyse visuelle + state)
##
## Fichiers produits (dans les DEUX dossiers) :
##   latest.png             — dernier frame capture
##   state.json             — etat run complet + perf metrics + timestamp
##   perf.json              — metriques de latence cumulees
##   log.json               — buffer circulaire 100 lignes
##   snap_{ts}_{event}.png  — historique par evenement
##   command.json           — (captures/ uniquement) lu par observer, ecrit par Claude
##   command_result.json    — (captures/ uniquement) resultat de la derniere commande

# --- Paths: user://debug/ (VS Code) ---
const USERDATA_DIR := "user://debug"
const USERDATA_SCREENSHOT := "user://debug/latest_screenshot.png"
const USERDATA_STATE := "user://debug/latest_state.json"
const USERDATA_LOG := "user://debug/log_buffer.json"

# --- Config ---
const LOG_CAPACITY := 100
const SCREENSHOT_INTERVAL := 1.0  ## 1fps pour Claude Code (reduit de 10fps)
const COMMAND_POLL_INTERVAL := 1.0  ## Poll command.json chaque seconde
const STATE_WRITE_INTERVAL := 5.0  ## Periodic state+perf write (backup if no signals)
const CONNECT_MAX_RETRIES := 120  ## ~2s a 60fps

# --- Runtime state ---
var _log_buffer: Array = []
var _screenshot_timer: float = 0.0
var _command_timer: float = 0.0
var _state_write_timer: float = 0.0
var _active: bool = false
var _capturing: bool = false
var _connect_retries: int = 0
var _project_captures_dir: String = ""
var _last_command_id: String = ""
var _burst_mode: bool = false
var _burst_remaining: int = 0
var _burst_interval: float = 0.2  ## 5fps during burst
var _burst_timer: float = 0.0
var _burst_counter: int = 0

# --- Perf tracking ---
var _perf_data: Dictionary = {
	"fps_samples": [],
	"frame_times": [],
	"card_gen_times": [],
	"card_count": 0,
	"fallback_count": 0,
	"llm_count": 0,
	"last_card_gen_start_ms": 0,
	"session_start_ms": 0,
}


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		return

	if DisplayServer.get_name() == "headless":
		set_process(false)
		set_process_input(false)
		return

	_active = true
	_perf_data["session_start_ms"] = Time.get_ticks_msec()

	# Init user://debug/ (VS Code Live View)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USERDATA_DIR))

	# Init project captures dir (Claude Code)
	var project_root: String = ProjectSettings.globalize_path("res://")
	_project_captures_dir = project_root.path_join("tools").path_join("autodev").path_join("captures")
	DirAccess.make_dir_recursive_absolute(_project_captures_dir)

	_append_log("[GameObserver] v2 started — dual write active")
	_append_log("[GameObserver] user://debug/ + %s" % _project_captures_dir)
	_connect_store_signals()
	_write_state()
	_write_perf()
	_capture_screenshot("startup")


func _process(delta: float) -> void:
	if not _active:
		return

	# Track FPS + frame time
	_track_frame_perf(delta)

	# Screenshot timer (1fps)
	_screenshot_timer += delta
	if _screenshot_timer >= SCREENSHOT_INTERVAL:
		_screenshot_timer = 0.0
		_capture_screenshot("timer", false)

	# Command poll (1Hz)
	_command_timer += delta
	if _command_timer >= COMMAND_POLL_INTERVAL:
		_command_timer = 0.0
		_poll_commands()

	# Periodic state + perf write (every 5s — backup if signals don't fire)
	_state_write_timer += delta
	if _state_write_timer >= STATE_WRITE_INTERVAL:
		_state_write_timer = 0.0
		_write_state()
		_write_perf()

	# Burst screenshot mode (high-frequency capture for animations)
	if _burst_mode and _burst_remaining > 0:
		_burst_timer += delta
		if _burst_timer >= _burst_interval:
			_burst_timer = 0.0
			_burst_counter += 1
			_burst_remaining -= 1
			_capture_screenshot("burst_%03d" % _burst_counter)
			if _burst_remaining <= 0:
				_burst_mode = false
				_append_log("[GameObserver] Burst capture complete: %d frames" % _burst_counter)


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.keycode == KEY_F11 and event.pressed:
		_capture_screenshot("manual_f11")
		_append_log("[GameObserver] Manual capture F11")


# ---------------------------------------------------------------------------
# Connexion aux signaux MerlinStore
# ---------------------------------------------------------------------------

func _connect_store_signals() -> void:
	var store: Node = get_node_or_null("/root/MerlinStore")
	if not store:
		_connect_retries += 1
		if _connect_retries >= CONNECT_MAX_RETRIES:
			_append_log("[GameObserver] MerlinStore not found after %d frames" % CONNECT_MAX_RETRIES)
			return
		call_deferred("_connect_store_signals")
		return

	_safe_connect(store, "card_resolved", _on_card_resolved)
	_safe_connect(store, "life_changed", _on_life_changed)
	_safe_connect(store, "run_ended", _on_run_ended)
	_safe_connect(store, "phase_changed", _on_phase_changed)
	_append_log("[GameObserver] MerlinStore signals connected")


func _safe_connect(source: Object, sig: String, callable: Callable) -> void:
	if source.has_signal(sig) and not source.is_connected(sig, callable):
		source.connect(sig, callable)


func _on_card_resolved(_card_id: String, _option: int) -> void:
	# Track card generation time
	var gen_start: int = _perf_data.get("last_card_gen_start_ms", 0)
	if gen_start > 0:
		var gen_time: int = Time.get_ticks_msec() - gen_start
		_perf_data["card_gen_times"].append(gen_time)
		_perf_data["last_card_gen_start_ms"] = 0
	_perf_data["card_count"] = int(_perf_data.get("card_count", 0)) + 1
	_write_state()
	_write_perf()
	_capture_screenshot("card_resolved")


func _on_life_changed(_old: int, _new_val: int) -> void:
	_write_state()
	_capture_screenshot("life_changed")


func _on_run_ended(_ending: Dictionary) -> void:
	_write_state()
	_write_perf()
	_capture_screenshot("run_ended")


func _on_phase_changed(_phase: String) -> void:
	_write_state()


# ---------------------------------------------------------------------------
# Frame perf tracking
# ---------------------------------------------------------------------------

func _track_frame_perf(delta: float) -> void:
	var fps_samples: Array = _perf_data.get("fps_samples", [])
	var frame_times: Array = _perf_data.get("frame_times", [])

	fps_samples.append(Engine.get_frames_per_second())
	frame_times.append(delta * 1000.0)

	# Keep last 60 samples (~1s at 60fps)
	if fps_samples.size() > 60:
		_perf_data["fps_samples"] = fps_samples.slice(fps_samples.size() - 60)
	if frame_times.size() > 60:
		_perf_data["frame_times"] = frame_times.slice(frame_times.size() - 60)


# ---------------------------------------------------------------------------
# Capture screenshot (DUAL WRITE)
# ---------------------------------------------------------------------------

func _capture_screenshot(trigger: String, save_history: bool = true) -> void:
	if _capturing:
		return
	_capturing = true
	await RenderingServer.frame_post_draw

	var vp: Viewport = get_viewport()
	if not vp:
		_capturing = false
		return

	var tex: ViewportTexture = vp.get_texture()
	if not tex:
		_capturing = false
		return

	var img: Image = tex.get_image()
	if not img or img.is_empty():
		_capturing = false
		return

	# Write to user://debug/ (VS Code Live View)
	img.save_png(USERDATA_SCREENSHOT)

	# Write to project captures/ (Claude Code)
	if not _project_captures_dir.is_empty():
		var project_latest: String = _project_captures_dir.path_join("latest.png")
		img.save_png(project_latest)

	# History snapshots for significant events
	if save_history:
		var ts: String = str(int(Time.get_unix_time_from_system()))
		var snap_name: String = "snap_%s_%s.png" % [ts, trigger]
		img.save_png("user://debug/%s" % snap_name)
		if not _project_captures_dir.is_empty():
			img.save_png(_project_captures_dir.path_join(snap_name))
		_append_log("[GameObserver] Screenshot: %s (%s)" % [trigger, ts])

	_capturing = false


# ---------------------------------------------------------------------------
# Card data helper (shared by _write_state and get_card_data command)
# ---------------------------------------------------------------------------

func _build_card_data() -> Dictionary:
	var ctrl: Node = _find_node_by_script_suffix("merlin_game_controller.gd")
	if ctrl and ctrl.get("current_card") is Dictionary:
		var c: Dictionary = ctrl.current_card
		if not c.is_empty():
			var opts: Array = []
			for o in c.get("options", []):
				if o is Dictionary:
					opts.append({
						"label": str(o.get("label", "")),
						"effects": o.get("effects", []),
					})
			return {
				"text": str(c.get("text", "")),
				"speaker": str(c.get("speaker", "")),
				"type": str(c.get("type", "")),
				"options": opts,
			}
	return {}


# ---------------------------------------------------------------------------
# Export state (DUAL WRITE)
# ---------------------------------------------------------------------------

func _write_state() -> void:
	var run: Dictionary = {}
	var store: Node = get_node_or_null("/root/MerlinStore")
	if store and store.get("state") != null:
		var s: Dictionary = store.state
		var run_data: Dictionary = s.get("run", {})
		var hidden: Dictionary = run_data.get("hidden", {})
		var mission: Dictionary = run_data.get("mission", {})
		var map_prog: Dictionary = s.get("map_progression", {})

		run = {
			"phase": s.get("phase", ""),
			"life": run_data.get("life_essence", 0),
			"essences": run_data.get("essences", 0),
			"cards_played": run_data.get("cards_played", 0),
			"biome": map_prog.get("current_biome", ""),
			"typology": run_data.get("typology", "classique"),
			"factions": run_data.get("faction_rep_delta", {}),
			"tension": hidden.get("tension", 0),
			"mission_progress": mission.get("progress", 0),
			"mission_total": mission.get("total", 0),
			"mission_type": mission.get("type", ""),
		}

	# Current card data for AI Playtester
	var card_data: Dictionary = _build_card_data()

	# Inline perf snapshot
	var fps_avg: float = 0.0
	var fps_samples: Array = _perf_data.get("fps_samples", [])
	if not fps_samples.is_empty():
		var total: float = 0.0
		for s in fps_samples:
			total += float(s)
		fps_avg = total / float(fps_samples.size())

	var data: Dictionary = {
		"timestamp": int(Time.get_unix_time_from_system()),
		"datetime": Time.get_datetime_string_from_system(),
		"run": run,
		"card": card_data,
		"perf": {
			"fps": fps_avg,
			"cards_generated": _perf_data.get("card_count", 0),
		},
		"log_tail": _log_buffer.slice(-10),
	}

	# Write to user://debug/
	var f1: FileAccess = FileAccess.open(USERDATA_STATE, FileAccess.WRITE)
	if f1:
		f1.store_string(JSON.stringify(data, "\t"))
		f1.close()

	# Write to project captures/
	if not _project_captures_dir.is_empty():
		var f2: FileAccess = FileAccess.open(
			_project_captures_dir.path_join("state.json"), FileAccess.WRITE)
		if f2:
			f2.store_string(JSON.stringify(data, "\t"))
			f2.close()


# ---------------------------------------------------------------------------
# Export perf metrics
# ---------------------------------------------------------------------------

func _write_perf() -> void:
	var card_gen_times: Array = _perf_data.get("card_gen_times", [])
	var fps_samples: Array = _perf_data.get("fps_samples", [])

	# Compute card gen stats
	var avg_gen: int = 0
	var p50_gen: int = 0
	var p90_gen: int = 0
	var min_gen: int = 0
	var max_gen: int = 0
	if not card_gen_times.is_empty():
		var sorted_times: Array = card_gen_times.duplicate()
		sorted_times.sort()
		var total_gen: int = 0
		for t in sorted_times:
			total_gen += int(t)
		@warning_ignore("integer_division")
		avg_gen = total_gen / sorted_times.size()
		min_gen = int(sorted_times[0])
		max_gen = int(sorted_times[sorted_times.size() - 1])
		p50_gen = int(sorted_times[int(sorted_times.size() * 0.5)])
		p90_gen = int(sorted_times[mini(int(sorted_times.size() * 0.9), sorted_times.size() - 1)])

	# Compute FPS stats
	var fps_avg: float = 0.0
	var fps_min: float = 999.0
	if not fps_samples.is_empty():
		var total: float = 0.0
		for s in fps_samples:
			total += float(s)
			fps_min = minf(fps_min, float(s))
		fps_avg = total / float(fps_samples.size())

	var card_total: int = int(_perf_data.get("card_count", 0))
	var llm_count: int = int(_perf_data.get("llm_count", 0))
	var fallback_count: int = int(_perf_data.get("fallback_count", 0))
	var fallback_rate: float = 0.0
	if card_total > 0:
		fallback_rate = float(fallback_count) / float(card_total)

	var perf: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"session_uptime_ms": Time.get_ticks_msec() - int(_perf_data.get("session_start_ms", 0)),
		"fps_avg": fps_avg,
		"fps_min": fps_min if fps_min < 999.0 else 0.0,
		"cards_generated": card_total,
		"llm_count": llm_count,
		"fallback_count": fallback_count,
		"fallback_rate": fallback_rate,
		"card_gen_avg_ms": avg_gen,
		"card_gen_p50_ms": p50_gen,
		"card_gen_p90_ms": p90_gen,
		"card_gen_min_ms": min_gen,
		"card_gen_max_ms": max_gen,
	}

	# Write to project captures/ only (perf is for Claude Code)
	if not _project_captures_dir.is_empty():
		var f: FileAccess = FileAccess.open(
			_project_captures_dir.path_join("perf.json"), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(perf, "\t"))
			f.close()


# ---------------------------------------------------------------------------
# Command polling (input injection from Claude Code)
# ---------------------------------------------------------------------------

func _poll_commands() -> void:
	if _project_captures_dir.is_empty():
		return

	var cmd_path: String = _project_captures_dir.path_join("command.json")
	if not FileAccess.file_exists(cmd_path):
		return

	var f: FileAccess = FileAccess.open(cmd_path, FileAccess.READ)
	if not f:
		return
	var text: String = f.get_as_text()
	f.close()

	var json: JSON = JSON.new()
	if json.parse(text) != OK or not (json.data is Dictionary):
		return

	var cmd: Dictionary = json.data
	var cmd_id: String = str(cmd.get("id", ""))
	if cmd_id == _last_command_id:
		return  # Already processed
	_last_command_id = cmd_id

	var action: String = str(cmd.get("action", ""))
	var params: Dictionary = cmd.get("params", {}) if cmd.get("params") is Dictionary else {}
	_append_log("[GameObserver] Command received: %s (id=%s)" % [action, cmd_id])

	var result: Dictionary = _execute_command(action, params)
	result["command_id"] = cmd_id
	result["timestamp"] = Time.get_datetime_string_from_system()

	# Write result
	var rf: FileAccess = FileAccess.open(
		_project_captures_dir.path_join("command_result.json"), FileAccess.WRITE)
	if rf:
		rf.store_string(JSON.stringify(result, "\t"))
		rf.close()

	# Delete command file after processing
	DirAccess.remove_absolute(cmd_path)


func _execute_command(action: String, params: Dictionary) -> Dictionary:
	match action:
		"screenshot":
			var label: String = str(params.get("label", "cmd"))
			_capture_screenshot("cmd_%s" % label)
			return {"status": "ok", "action": action}

		"click_option":
			var option: int = int(params.get("option", 0))
			var ui: Node = _find_node_by_script_suffix("merlin_game_ui.gd")
			if ui and ui.has_signal("option_chosen"):
				ui.option_chosen.emit(option)
				_append_log("[GameObserver] Emitted option_chosen(%d)" % option)
				return {"status": "ok", "action": action, "option": option}
			return {"status": "error", "action": action, "error": "UI node not found"}

		"set_property":
			var node_path: String = str(params.get("node_path", ""))
			var property: String = str(params.get("property", ""))
			var value: Variant = params.get("value")
			var target: Node = get_node_or_null(node_path)
			if target:
				target.set(property, value)
				return {"status": "ok", "action": action, "node": node_path, "property": property}
			return {"status": "error", "action": action, "error": "Node not found: %s" % node_path}

		"get_tree_snapshot":
			var snapshot: Array = _snapshot_tree(get_tree().root, 0, 3)
			return {"status": "ok", "action": action, "tree": snapshot}

		"get_state":
			_write_state()
			return {"status": "ok", "action": action}

		"mark_card_gen_start":
			_perf_data["last_card_gen_start_ms"] = Time.get_ticks_msec()
			return {"status": "ok", "action": action}

		"click_button":
			var button_name: String = str(params.get("name", ""))
			var btn: BaseButton = _find_button_by_name(get_tree().root, button_name)
			if btn:
				btn.emit_signal("pressed")
				_append_log("[GameObserver] Pressed button: %s (%s)" % [button_name, str(btn.get_path())])
				return {"status": "ok", "action": action, "button": str(btn.get_path())}
			return {"status": "error", "action": action, "error": "Button not found: %s" % button_name}

		"change_scene":
			var scene_path: String = str(params.get("scene", ""))
			if scene_path.is_empty():
				return {"status": "error", "action": action, "error": "Missing scene path"}
			if not ResourceLoader.exists(scene_path):
				return {"status": "error", "action": action, "error": "Scene not found: %s" % scene_path}
			get_tree().change_scene_to_file(scene_path)
			_append_log("[GameObserver] Scene changed to: %s" % scene_path)
			_connect_retries = 0
			call_deferred("_connect_store_signals")
			return {"status": "ok", "action": action, "scene": scene_path}

		"list_buttons":
			var buttons: Array = _list_all_buttons(get_tree().root)
			return {"status": "ok", "action": action, "buttons": buttons}

		"burst_screenshot":
			var count: int = int(params.get("count", 10))
			var interval: float = float(params.get("interval", 0.2))
			count = clampi(count, 1, 60)
			interval = clampf(interval, 0.05, 2.0)
			_burst_mode = true
			_burst_remaining = count
			_burst_interval = interval
			_burst_timer = 0.0
			_burst_counter = 0
			_append_log("[GameObserver] Burst started: %d frames @ %.1ffps" % [count, 1.0 / interval])
			return {"status": "ok", "action": action, "count": count, "interval": interval}

		"simulate_click":
			var x: float = float(params.get("x", 400))
			var y: float = float(params.get("y", 300))
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_LEFT
			ev.pressed = true
			ev.position = Vector2(x, y)
			ev.global_position = Vector2(x, y)
			Input.parse_input_event(ev)
			# Release after a frame
			var ev_up := InputEventMouseButton.new()
			ev_up.button_index = MOUSE_BUTTON_LEFT
			ev_up.pressed = false
			ev_up.position = Vector2(x, y)
			ev_up.global_position = Vector2(x, y)
			Input.parse_input_event(ev_up)
			_append_log("[GameObserver] Simulated click at (%d, %d)" % [int(x), int(y)])
			return {"status": "ok", "action": action, "x": x, "y": y}

		"simulate_key":
			var key_name: String = str(params.get("key", "space"))
			var keycode: Key = _resolve_keycode(key_name)
			var ev := InputEventKey.new()
			ev.keycode = keycode
			ev.pressed = true
			Input.parse_input_event(ev)
			var ev_up := InputEventKey.new()
			ev_up.keycode = keycode
			ev_up.pressed = false
			Input.parse_input_event(ev_up)
			_append_log("[GameObserver] Simulated key: %s" % key_name)
			return {"status": "ok", "action": action, "key": key_name}

		"get_card_data":
			var cd: Dictionary = _build_card_data()
			return {"status": "ok", "action": action, "card": cd}

		_:
			return {"status": "error", "action": action, "error": "Unknown action: %s" % action}


func _snapshot_tree(node: Node, depth: int, max_depth: int) -> Array:
	var result: Array = []
	var entry: Dictionary = {
		"name": node.name,
		"type": node.get_class(),
		"path": str(node.get_path()),
		"visible": node.get("visible") if "visible" in node else true,
	}
	result.append(entry)
	if depth < max_depth:
		for child in node.get_children():
			result.append_array(_snapshot_tree(child, depth + 1, max_depth))
	return result


func _find_node_by_script_suffix(suffix: String) -> Node:
	return _search_script_suffix(get_tree().root, suffix)


func _find_button_by_name(node: Node, button_name: String) -> BaseButton:
	if node is BaseButton:
		if str(node.name).to_lower().contains(button_name.to_lower()):
			return node as BaseButton
	for child in node.get_children():
		var found: BaseButton = _find_button_by_name(child, button_name)
		if found:
			return found
	return null


func _list_all_buttons(node: Node) -> Array:
	var result: Array = []
	if node is BaseButton:
		result.append({
			"name": str(node.name),
			"path": str(node.get_path()),
			"text": str(node.text) if "text" in node else "",
			"visible": node.visible if "visible" in node else true,
			"disabled": node.disabled if "disabled" in node else false,
		})
	for child in node.get_children():
		result.append_array(_list_all_buttons(child))
	return result


func _search_script_suffix(node: Node, suffix: String) -> Node:
	var script: Script = node.get_script()
	if script and str(script.resource_path).ends_with(suffix):
		return node
	for child in node.get_children():
		var found: Node = _search_script_suffix(child, suffix)
		if found:
			return found
	return null


# ---------------------------------------------------------------------------
# Key name to keycode resolver
# ---------------------------------------------------------------------------

func _resolve_keycode(key_name: String) -> Key:
	match key_name.to_lower():
		"space": return KEY_SPACE
		"enter": return KEY_ENTER
		"escape", "esc": return KEY_ESCAPE
		"a": return KEY_A
		"b": return KEY_B
		"c": return KEY_C
		"up": return KEY_UP
		"down": return KEY_DOWN
		"left": return KEY_LEFT
		"right": return KEY_RIGHT
		"tab": return KEY_TAB
		"1": return KEY_1
		"2": return KEY_2
		"3": return KEY_3
		"f11": return KEY_F11
		_: return KEY_SPACE


# ---------------------------------------------------------------------------
# Buffer log (DUAL WRITE)
# ---------------------------------------------------------------------------

func _append_log(line: String) -> void:
	var entry: String = "[%s] %s" % [Time.get_time_string_from_system(), line]
	_log_buffer.append(entry)
	if _log_buffer.size() > LOG_CAPACITY:
		_log_buffer = _log_buffer.slice(_log_buffer.size() - LOG_CAPACITY)

	var json_text: String = JSON.stringify(_log_buffer)

	# Write to user://debug/
	var f1: FileAccess = FileAccess.open(USERDATA_LOG, FileAccess.WRITE)
	if f1:
		f1.store_string(json_text)
		f1.close()

	# Write to project captures/
	if not _project_captures_dir.is_empty():
		var f2: FileAccess = FileAccess.open(
			_project_captures_dir.path_join("log.json"), FileAccess.WRITE)
		if f2:
			f2.store_string(json_text)
			f2.close()
