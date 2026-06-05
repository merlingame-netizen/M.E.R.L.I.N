extends Node
## TweaksOverlay — hot-reload des constantes gameplay + persona Merlin depuis le Dashboard
## « Gameplay Live » de mission-control (tools/autodev/mission-control). Polling fichier
## `user://merlin_tweaks.json` à 500 ms (changement détecté par mtime, pas de re-parse inutile).
## Écrit aussi l'état run vers `user://dashboard_state.json` toutes les 1000 ms pour lecture par
## le bridge mission-control. (v10 dashboard, user 2026-05-31 /goal)

signal tweaks_reloaded(tweaks: Dictionary)

const TWEAKS_PATH: String = "user://merlin_tweaks.json"
const STATE_PATH: String = "user://dashboard_state.json"
const POLL_INTERVAL_S: float = 0.5
const STATE_INTERVAL_S: float = 1.0

var _tweaks: Dictionary = {}
var _last_mtime: int = -1
# v10 : _process-based accumulators (Timer nodes did not tick reliably as autoload children during
# headless smoke). Garantie : 1 frame = 1 _process call → cadence respectée à ±1 frame.
var _accum_poll: float = 0.0
var _accum_state: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # tick même si la scène est en pause
	set_process(true)
	_load_tweaks(true)  # initial silencieux : pas de signal au démarrage
	# Baseline immédiat : écrit l'état au moment où l'autoload est prêt, même si la scène vient de
	# démarrer (utile pour le smoke court + dashboard qui doit afficher quelque chose dès la connexion).
	call_deferred("_write_dashboard_state")


func _process(delta: float) -> void:
	_accum_poll += delta
	if _accum_poll >= POLL_INTERVAL_S:
		_accum_poll = 0.0
		_load_tweaks(false)
	_accum_state += delta
	if _accum_state >= STATE_INTERVAL_S:
		_accum_state = 0.0
		_write_dashboard_state()


func _load_tweaks(silent: bool) -> void:
	if not FileAccess.file_exists(TWEAKS_PATH):
		if _tweaks.size() > 0:
			_tweaks = {}
			_last_mtime = -1
			if not silent:
				emit_signal("tweaks_reloaded", _tweaks)
		return
	var mtime: int = int(FileAccess.get_modified_time(TWEAKS_PATH))
	if mtime == _last_mtime:
		return
	_last_mtime = mtime
	var f: FileAccess = FileAccess.open(TWEAKS_PATH, FileAccess.READ)
	if f == null:
		return
	var raw: String = f.get_as_text()
	f.close()
	var data: Variant = JSON.parse_string(raw)
	if data is Dictionary:
		_tweaks = data
		if not silent:
			emit_signal("tweaks_reloaded", _tweaks)
	else:
		push_warning("TweaksOverlay: %s parsed but is not a Dictionary." % TWEAKS_PATH)


func _write_dashboard_state() -> void:
	var run: Node = get_node_or_null("/root/MerlinRun")
	if run == null:
		return
	# Lit les constantes effectives via get_run_constants() (cf. merlin_run.gd) — évite l'accès
	# direct aux const de classe via instance (non garanti pour autoload sans class_name).
	var consts: Dictionary = run.get_run_constants() if run.has_method("get_run_constants") else {}
	var state: Dictionary = {
		"timestamp": Time.get_datetime_string_from_system(),
		"run": {
			"integrite": int(run.integrite),
			"max_integrite": int(consts.get("MAX_INTEGRITE", 10)),
			"corruption": int(run.corruption),
			"corruption_cap": int(consts.get("CORRUPTION_CAP", 18)),
			"beat_index": int(run.beat_index),
			"scenario": {
				"title": str(run.scenario.get("title", "")) if run.scenario is Dictionary else "",
				"total": int(run.scenario.get("total", 0)) if run.scenario is Dictionary else 0,
				"pitch": str(run.scenario.get("pitch", "")) if run.scenario is Dictionary else "",
			},
			"hand": _serialize_hand(run.hand if run.hand is Array else []),
			"discard_count": int(run.discard.size()) if run.discard is Array else 0,
			"deck_count": int(run.deck.size()) if run.deck is Array else 0,
			"ended": bool(run.ended),
			"end_type": str(run.end_type),
			"faits_marquants": (run.faits_marquants if run.faits_marquants is Array else []),
			"cartes_notables": (run.cartes_notables if run.cartes_notables is Array else []),
		},
		"tweaks_active": _tweaks,
	}
	var f: FileAccess = FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("TweaksOverlay: impossible d'écrire %s (FileAccess null)" % STATE_PATH)
		return
	f.store_string(JSON.stringify(state, "  "))
	f.close()


func _serialize_hand(hand: Array) -> Array:
	var out: Array = []
	for c in hand:
		if c != null and c.has_method("to_dict"):
			out.append(c.to_dict())
	return out


# === API publique consommée par les autoloads (MerlinRun, MerlinScenario, MerlinCard) ===

func get_int(key: String, default_value: int) -> int:
	var constants: Variant = _tweaks.get("constants", {})
	if constants is Dictionary and (constants as Dictionary).has(key):
		return int((constants as Dictionary)[key])
	return default_value


func get_str(key: String, default_value: String) -> String:
	var constants: Variant = _tweaks.get("constants", {})
	if constants is Dictionary and (constants as Dictionary).has(key):
		return str((constants as Dictionary)[key])
	return default_value


func get_persona_overlay() -> Dictionary:
	var p: Variant = _tweaks.get("persona_overlay", {})
	return (p as Dictionary).duplicate(true) if p is Dictionary else {}


func get_scenario_force() -> Dictionary:
	var s: Variant = _tweaks.get("scenario_force", {})
	return (s as Dictionary).duplicate(true) if s is Dictionary else {}


func get_tweaks() -> Dictionary:
	return _tweaks.duplicate(true)
