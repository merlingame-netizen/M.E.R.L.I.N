extends Node
## GameDebugServer — Observation runtime en mode développement.
## Auto-actif quand OS.is_debug_build() = true (jamais en build exporté).
## Capture screenshots + état + log buffer dans user://debug/
## Lu directement par l'extension VS Code AUTODEV Monitor v4.2 (Live View panel).
##
## Fichiers produits :
##   user://debug/latest_screenshot.png — dernier frame capturé
##   user://debug/latest_state.json     — état run complet + timestamp
##   user://debug/log_buffer.json       — circulaire 100 lignes
##   user://debug/snap_{ts}_{event}.png — historique par événement

const DEBUG_DIR := "user://debug"
const SCREENSHOT_PATH := "user://debug/latest_screenshot.png"
const STATE_PATH := "user://debug/latest_state.json"
const LOG_PATH := "user://debug/log_buffer.json"
const LOG_CAPACITY := 100
const SCREENSHOT_INTERVAL := 30.0  ## Secondes entre screenshots auto (ambiant)

var _log_buffer: Array = []
var _screenshot_timer: float = 0.0
var _active: bool = false


func _ready() -> void:
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		return

	_active = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEBUG_DIR))
	_append_log("[GameDebugServer] Démarré — user://debug/ actif")
	_connect_store_signals()
	_write_state()
	_capture_screenshot("startup")


func _process(delta: float) -> void:
	if not _active:
		return
	_screenshot_timer += delta
	if _screenshot_timer >= SCREENSHOT_INTERVAL:
		_screenshot_timer = 0.0
		_capture_screenshot("timer")


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey and event.keycode == KEY_F11 and event.pressed:
		_capture_screenshot("manual_f11")
		_append_log("[GameDebugServer] Capture manuelle F11")


# ---------------------------------------------------------------------------
# Connexion aux signaux MerlinStore
# ---------------------------------------------------------------------------

func _connect_store_signals() -> void:
	## Attend que MerlinStore soit disponible (singleton autoload).
	if not Engine.has_singleton("MerlinStore"):
		# Retry via call_deferred si pas encore prêt
		call_deferred("_connect_store_signals")
		return

	var store: Node = Engine.get_singleton("MerlinStore")
	if not store:
		return

	_safe_connect(store, "card_resolved", _on_card_resolved)
	_safe_connect(store, "life_changed", _on_life_changed)
	_safe_connect(store, "run_ended", _on_run_ended)
	_safe_connect(store, "phase_changed", _on_phase_changed)
	_safe_connect(store, "souffle_changed", _on_souffle_changed)
	_append_log("[GameDebugServer] Signaux MerlinStore connectés")


func _safe_connect(source: Object, sig: String, callable: Callable) -> void:
	if source.has_signal(sig) and not source.is_connected(sig, callable):
		source.connect(sig, callable)


func _on_card_resolved(_card_id: String, _option: int) -> void:
	_write_state()
	_capture_screenshot("card_resolved")


func _on_life_changed(_old: int, _new_val: int) -> void:
	_write_state()
	_capture_screenshot("life_changed")


func _on_run_ended(_ending: Dictionary) -> void:
	_write_state()
	_capture_screenshot("run_ended")


func _on_phase_changed(_phase: String) -> void:
	_write_state()


func _on_souffle_changed(_old: int, _new_val: int) -> void:
	_write_state()


# ---------------------------------------------------------------------------
# Capture screenshot
# ---------------------------------------------------------------------------

func _capture_screenshot(trigger: String) -> void:
	## Capture le viewport courant. Ne fonctionne pas en mode headless.
	await RenderingServer.frame_post_draw

	var vp: Viewport = get_viewport()
	if not vp:
		return

	var tex: ViewportTexture = vp.get_texture()
	if not tex:
		return

	var img: Image = tex.get_image()
	if not img or img.is_empty():
		return

	# Screenshot courant (écrase)
	var err: int = img.save_png(SCREENSHOT_PATH)
	if err != OK:
		return

	# Screenshot historique (horodaté)
	var ts: String = str(int(Time.get_unix_time_from_system()))
	img.save_png("user://debug/snap_%s_%s.png" % [ts, trigger])

	_append_log("[GameDebugServer] Screenshot: %s (%s)" % [trigger, ts])


# ---------------------------------------------------------------------------
# Export état
# ---------------------------------------------------------------------------

func _write_state() -> void:
	## Sérialise l'état run courant depuis MerlinStore dans latest_state.json.
	var run: Dictionary = {}

	if Engine.has_singleton("MerlinStore"):
		var store: Node = Engine.get_singleton("MerlinStore")
		if store and store.get("state") != null:
			var s: Dictionary = store.state
			var run_data: Dictionary = s.get("run", {})
			var hidden: Dictionary = run_data.get("hidden", {})
			var mission: Dictionary = run_data.get("mission", {})
			var map_prog: Dictionary = s.get("map_progression", {})

			run = {
				"phase": s.get("phase", ""),
				"life": run_data.get("life_essence", 0),
				"souffle": run_data.get("souffle", 0),
				"essences": run_data.get("essences", 0),
				"cards_played": run_data.get("cards_played", 0),
				"biome": map_prog.get("current_biome", ""),
				"typology": run_data.get("typology", "classique"),
				"aspects": run_data.get("aspects", {}),
				"karma": hidden.get("karma", 0),
				"tension": hidden.get("tension", 0),
				"mission_progress": mission.get("progress", 0),
				"mission_total": mission.get("total", 0),
				"mission_type": mission.get("type", ""),
			}

	var data: Dictionary = {
		"timestamp": int(Time.get_unix_time_from_system()),
		"datetime": Time.get_datetime_string_from_system(),
		"run": run,
		"log_tail": _log_buffer.slice(-10),
	}

	var f: FileAccess = FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()


# ---------------------------------------------------------------------------
# Buffer log
# ---------------------------------------------------------------------------

func _append_log(line: String) -> void:
	## Ajoute une ligne au buffer circulaire et met à jour log_buffer.json.
	var entry: String = "[%s] %s" % [Time.get_time_string_from_system(), line]
	_log_buffer.append(entry)
	if _log_buffer.size() > LOG_CAPACITY:
		_log_buffer = _log_buffer.slice(_log_buffer.size() - LOG_CAPACITY)

	var f: FileAccess = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(_log_buffer))
		f.close()
