extends RefCounted
class_name MerlinSaveSystem

const CURRENT_VERSION := "0.4.0"
const SLOT_COUNT := 3
const SLOT_PATH := "user://merlin_save_slot_%d.json"
const AUTOSAVE_PATH := "user://merlin_autosave.json"
const BACKUP_SUFFIX := ".bak"


# ═══════════════════════════════════════════════════════════════════════════════
# SAVE
# ═══════════════════════════════════════════════════════════════════════════════

func save_slot(slot: int, payload: Dictionary) -> bool:
	if not _is_valid_slot(slot):
		return false
	var path := SLOT_PATH % slot
	return _save_to_path(path, payload)


func save_autosave(payload: Dictionary) -> bool:
	var data := payload.duplicate(true)
	data["_is_autosave"] = true
	return _save_to_path(AUTOSAVE_PATH, data)


func _save_to_path(path: String, payload: Dictionary) -> bool:
	_backup_file(path)
	var data := payload.duplicate(true)
	data["version"] = CURRENT_VERSION
	data["timestamp"] = int(Time.get_unix_time_from_system())
	var json_text := JSON.stringify(data, "\t")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[MerlinSave] Cannot write to %s" % path)
		return false
	file.store_string(json_text)
	file.close()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# LOAD
# ═══════════════════════════════════════════════════════════════════════════════

func load_slot(slot: int, default_state: Dictionary = {}) -> Dictionary:
	if not _is_valid_slot(slot):
		return {}
	return _load_from_path(SLOT_PATH % slot, default_state)


func load_autosave(default_state: Dictionary = {}) -> Dictionary:
	return _load_from_path(AUTOSAVE_PATH, default_state)


func _load_from_path(path: String, default_state: Dictionary = {}) -> Dictionary:
	var data := _try_load_file(path)
	if data.is_empty():
		var bak_path := path + BACKUP_SUFFIX
		if FileAccess.file_exists(bak_path):
			data = _try_load_file(bak_path)
			if not data.is_empty():
				push_warning("[MerlinSave] Primary corrupted, loaded from backup: %s" % bak_path)
	if data.is_empty():
		return {}
	return migrate(data, default_state)


func _try_load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json_text := file.get_as_text()
	file.close()
	if json_text.strip_edges().is_empty():
		return {}
	var json := JSON.new()
	if json.parse(json_text) != OK:
		push_warning("[MerlinSave] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	var data = json.get_data()
	if not _validate_save_json(data):
		push_warning("[MerlinSave] Invalid save structure in %s" % path)
		return {}
	return data


# ═══════════════════════════════════════════════════════════════════════════════
# SLOT MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

func delete_slot(slot: int) -> void:
	if not _is_valid_slot(slot):
		return
	var path := SLOT_PATH % slot
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var bak_path := path + BACKUP_SUFFIX
	if FileAccess.file_exists(bak_path):
		DirAccess.remove_absolute(bak_path)


func slot_exists(slot: int) -> bool:
	if not _is_valid_slot(slot):
		return false
	return FileAccess.file_exists(SLOT_PATH % slot)


func autosave_exists() -> bool:
	return FileAccess.file_exists(AUTOSAVE_PATH)


func get_slot_info(slot: int) -> Dictionary:
	var data := load_slot(slot)
	if data.is_empty():
		return {}
	return {
		"version": data.get("version", ""),
		"timestamp": data.get("timestamp", 0),
		"phase": data.get("phase", ""),
		"cards_played": data.get("run", {}).get("cards_played", 0),
		"mode": data.get("mode", ""),
	}


func get_autosave_info() -> Dictionary:
	var data := load_autosave()
	if data.is_empty():
		return {}
	return {
		"version": data.get("version", ""),
		"timestamp": data.get("timestamp", 0),
		"phase": data.get("phase", ""),
		"cards_played": data.get("run", {}).get("cards_played", 0),
		"mode": data.get("mode", ""),
		"_is_autosave": true,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

func _validate_save_json(data) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if not data.has("version"):
		return false
	if not data.has("run") or typeof(data.get("run")) != TYPE_DICTIONARY:
		return false
	return true


func _backup_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var src := FileAccess.open(path, FileAccess.READ)
	if src == null:
		return
	var content := src.get_as_text()
	src.close()
	var dst := FileAccess.open(path + BACKUP_SUFFIX, FileAccess.WRITE)
	if dst:
		dst.store_string(content)
		dst.close()


# ═══════════════════════════════════════════════════════════════════════════════
# MIGRATION
# ═══════════════════════════════════════════════════════════════════════════════

func migrate(payload: Dictionary, default_state: Dictionary = {}) -> Dictionary:
	var data := payload.duplicate(true)
	var version := str(data.get("version", "0.1.0"))

	if version == "0.1.0":
		data = _migrate_0_1_to_0_2(data)
		version = "0.2.0"
	if version == "0.2.0":
		data = _migrate_0_2_to_0_3(data)
		version = "0.3.0"
	if version == "0.3.0":
		data = _migrate_0_3_to_0_4(data)
		version = "0.4.0"

	data["version"] = CURRENT_VERSION
	if not default_state.is_empty():
		data = _merge_missing(default_state, data)
	return data


func _migrate_0_1_to_0_2(data: Dictionary) -> Dictionary:
	var run: Dictionary = data.get("run", {})
	if not run.has("aspects"):
		run["aspects"] = {"Corps": 0, "Ame": 0, "Monde": 0}
	if not run.has("souffle"):
		run["souffle"] = MerlinConstants.SOUFFLE_START
	if not run.has("souffle_used_once"):
		run["souffle_used_once"] = false
	if not run.has("cards_played"):
		run["cards_played"] = 0
	if not run.has("day"):
		run["day"] = 1
	if not run.has("hidden"):
		run["hidden"] = {"karma": 0, "tension": 0, "player_profile": {}, "resonances_active": [], "narrative_debt": []}
	data["run"] = run
	if not data.has("mode"):
		data["mode"] = "merlin"
	data["version"] = "0.2.0"
	return data


func _migrate_0_2_to_0_3(data: Dictionary) -> Dictionary:
	var run: Dictionary = data.get("run", {})
	if not run.has("mission"):
		run["mission"] = {"type": "", "target": "", "progress": 0, "total": 0, "revealed": false}
	if not run.has("active_tags"):
		run["active_tags"] = []
	if not run.has("active_promises"):
		run["active_promises"] = []
	if not run.has("effect_modifier"):
		run["effect_modifier"] = {}
	if not run.has("story_log"):
		run["story_log"] = []
	data["run"] = run
	var bestiole: Dictionary = data.get("bestiole", {})
	if not bestiole.has("awen"):
		bestiole["awen"] = 3
	if not bestiole.has("awen_regen_counter"):
		bestiole["awen_regen_counter"] = 0
	if not bestiole.has("skills_unlocked"):
		bestiole["skills_unlocked"] = ["beith", "luis", "quert"]
	if not bestiole.has("skills_equipped"):
		bestiole["skills_equipped"] = bestiole.get("skills_unlocked", []).duplicate()
	if not bestiole.has("skill_cooldowns"):
		bestiole["skill_cooldowns"] = {}
	data["bestiole"] = bestiole
	var meta: Dictionary = data.get("meta", {})
	if not meta.has("talent_tree"):
		meta["talent_tree"] = {"unlocked": []}
	if not meta.has("bestiole_evolution"):
		meta["bestiole_evolution"] = {"stage": 1, "path": ""}
	if not meta.has("total_runs"):
		meta["total_runs"] = 0
	if not meta.has("total_cards_played"):
		meta["total_cards_played"] = 0
	if not meta.has("endings_seen"):
		meta["endings_seen"] = []
	if not meta.has("gloire_points"):
		meta["gloire_points"] = 0
	data["meta"] = meta
	data["version"] = "0.3.0"
	return data


func _migrate_0_3_to_0_4(data: Dictionary) -> Dictionary:
	if not data.has("map_progression"):
		data["map_progression"] = {
			"gauges": {"esprit": 30, "vigueur": 50, "faveur": 40, "logique": 35, "ressources": 45},
			"current_biome": "foret_broceliande",
			"completed_biomes": [],
			"visited_biomes": ["foret_broceliande"],
			"items_collected": [],
			"reputations": [],
			"tier_progress": 1,
		}
	data["version"] = "0.4.0"
	return data


func _merge_missing(default_state: Dictionary, data: Dictionary) -> Dictionary:
	var merged := default_state.duplicate(true)
	for key in data:
		merged[key] = data[key]
	return merged


func _is_valid_slot(slot: int) -> bool:
	return slot >= 1 and slot <= SLOT_COUNT
