extends RefCounted
class_name MerlinTraitRegistry
## Trait unlock detection + announce-line lookup for the RPG progression system.
## Call check_unlocks(state) after each test outcome OR post-run; returns trait keys
## newly unlocked. Mutates state.player.traits to append them.
##
## Data: data/traits/druidic_traits.json

const TRAITS_PATH := "res://data/traits/druidic_traits.json"

static var _cache: Array = []
static var _loaded: bool = false


static func _load_traits() -> void:
	if _loaded:
		return
	if not FileAccess.file_exists(TRAITS_PATH):
		_loaded = true
		return
	var f: FileAccess = FileAccess.open(TRAITS_PATH, FileAccess.READ)
	if f == null:
		_loaded = true
		return
	var raw: String = f.get_as_text()
	f.close()
	var json := JSON.new()
	if json.parse(raw) != OK or not (json.data is Dictionary):
		_loaded = true
		return
	_cache = (json.data as Dictionary).get("traits", []) as Array
	_loaded = true


## Check all traits and return keys newly unlocked (not already in state.player.traits).
## Mutates state.player.traits to include new ones.
static func check_unlocks(state: Dictionary) -> Array:
	_load_traits()
	if _cache.is_empty():
		return []
	if not state.has("player"):
		return []
	var player: Dictionary = state["player"] as Dictionary
	var owned: Array = player.get("traits", []) as Array
	var newly: Array = []
	for trait_def in _cache:
		var t: Dictionary = trait_def as Dictionary
		var key: String = String(t.get("key", ""))
		if key.is_empty() or owned.has(key):
			continue
		if _evaluate_unlock(state, t.get("unlock", {}) as Dictionary):
			owned.append(key)
			newly.append(key)
	if not newly.is_empty():
		player["traits"] = owned
	return newly


## Get the announce line for a trait key (Merlin voice, displayed post-run).
static func get_announce(key: String) -> String:
	_load_traits()
	for t in _cache:
		if String(t.get("key", "")) == key:
			return String(t.get("announce", ""))
	return ""


## Get the human label for a trait (UI display).
static func get_label(key: String) -> String:
	_load_traits()
	for t in _cache:
		if String(t.get("key", "")) == key:
			return String(t.get("label", key))
	return key


## Evaluate a single unlock condition against state.
static func _evaluate_unlock(state: Dictionary, cond: Dictionary) -> bool:
	var u_type: String = String(cond.get("type", ""))
	var player: Dictionary = state.get("player", {}) as Dictionary
	match u_type:
		"stat_threshold":
			var axis: String = String(cond.get("axis", "esprit"))
			var threshold: int = int(cond.get("value", 7))
			var stats: Dictionary = player.get("stats", {}) as Dictionary
			return int(stats.get(axis, 0)) >= threshold
		"critical_streak":
			var axis_s: String = String(cond.get("axis", "esprit"))
			var streak: int = int(cond.get("value", 3))
			var mem: Array = player.get("memory_log", []) as Array
			# Last `streak` memory entries must all be critical on the matching axis
			if mem.size() < streak:
				return false
			for i in range(mem.size() - streak, mem.size()):
				var entry: Dictionary = mem[i] as Dictionary
				if String(entry.get("axis", "")) != axis_s:
					return false
				if String(entry.get("result", "")) != "critical":
					return false
			return true
		"critical_failure_survival":
			var count: int = int(cond.get("value", 3))
			var mem2: Array = player.get("memory_log", []) as Array
			var failures: int = 0
			for entry2 in mem2:
				if String((entry2 as Dictionary).get("result", "")) == "critical_failure":
					failures += 1
			return failures >= count
		"faction_max":
			var faction: String = String(cond.get("faction", ""))
			var threshold_f: float = float(cond.get("value", 60))
			var meta: Dictionary = state.get("meta", {}) as Dictionary
			var rep: Dictionary = meta.get("faction_rep", {}) as Dictionary
			return float(rep.get(faction, 0)) >= threshold_f
		"memory_count":
			var threshold_m: int = int(cond.get("value", 12))
			# Use total cards played as proxy for memory volume (memory_log is rolling 5).
			var run: Dictionary = state.get("run", {}) as Dictionary
			var played: int = int(run.get("cards_played", 0))
			return played >= threshold_m
	return false


## Build the post-run announce text — listing all newly unlocked traits.
## Returns "" if none.
static func build_post_run_announce(unlocked_keys: Array) -> String:
	if unlocked_keys.is_empty():
		return ""
	_load_traits()
	var lines: Array[String] = []
	for key in unlocked_keys:
		var line: String = get_announce(String(key))
		if not line.is_empty():
			lines.append("✦ " + line)
	return "\n\n".join(lines)
