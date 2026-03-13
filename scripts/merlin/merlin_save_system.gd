extends RefCounted
class_name MerlinSaveSystem

const CURRENT_VERSION := "1.0.0"
const PROFILE_PATH := "user://merlin_profile.json"
const BACKUP_SUFFIX := ".bak"

# Legacy paths (for migration cleanup)
const LEGACY_SLOT_PATH := "user://merlin_save_slot_%d.json"
const LEGACY_AUTOSAVE_PATH := "user://merlin_autosave.json"
const LEGACY_SLOT_COUNT := 3


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func save_profile(meta: Dictionary) -> bool:
	_backup_file(PROFILE_PATH)
	var data: Dictionary = {
		"version": CURRENT_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"meta": meta.duplicate(true),
	}
	var json_text: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("[MerlinSave] Cannot write to %s" % PROFILE_PATH)
		return false
	file.store_string(json_text)
	file.close()
	return true


func load_profile() -> Dictionary:
	var data: Dictionary = _try_load_file(PROFILE_PATH)
	if data.is_empty():
		# Try backup
		var bak_path: String = PROFILE_PATH + BACKUP_SUFFIX
		if FileAccess.file_exists(bak_path):
			data = _try_load_file(bak_path)
			if not data.is_empty():
				push_warning("[MerlinSave] Primary corrupted, loaded from backup")
	if data.is_empty():
		# Try migrating from legacy slot 1
		data = _try_migrate_from_legacy()
	if data.is_empty():
		return {}
	# Migrate if needed
	var version: String = str(data.get("version", "0.4.0"))
	if version != CURRENT_VERSION:
		data = _migrate(data)
	return data.get("meta", {})


func profile_exists() -> bool:
	return FileAccess.file_exists(PROFILE_PATH)


func reset_profile() -> void:
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	var bak_path: String = PROFILE_PATH + BACKUP_SUFFIX
	if FileAccess.file_exists(bak_path):
		DirAccess.remove_absolute(bak_path)


func get_profile_info() -> Dictionary:
	var meta: Dictionary = load_profile()
	if meta.is_empty():
		return {}
	return {
		"anam": int(meta.get("anam", 0)),
		"total_runs": int(meta.get("total_runs", 0)),
		"talents_unlocked": meta.get("talent_tree", {}).get("unlocked", []).size(),
		"endings_seen": meta.get("endings_seen", []).size(),
		"faction_rep": meta.get("faction_rep", {}),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# MIGRATION — 0.4.0 → 1.0.0
# ═══════════════════════════════════════════════════════════════════════════════

func _migrate(data: Dictionary) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	var meta: Dictionary = migrated.get("meta", {})

	# Convert essence sum to anam
	var essence: Dictionary = meta.get("essence", {})
	var essence_total: int = 0
	for element in essence:
		essence_total += int(essence[element])
	meta["anam"] = int(meta.get("anam", 0)) + essence_total

	# Remove dead currencies
	meta.erase("essence")
	meta.erase("ogham_fragments")
	meta.erase("liens")
	meta.erase("gloire_points")
	meta.erase("bestiole_evolution")
	meta.erase("unlocked_evolutions")

	# Rename humains → niamh in faction_rep (if not already done)
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	if faction_rep.has("humains") and not faction_rep.has("niamh"):
		faction_rep["niamh"] = faction_rep["humains"]
		faction_rep.erase("humains")
		meta["faction_rep"] = faction_rep

	# Ensure required keys
	if not meta.has("talent_tree"):
		meta["talent_tree"] = {"unlocked": []}
	if not meta.has("total_runs"):
		meta["total_runs"] = 0
	if not meta.has("endings_seen"):
		meta["endings_seen"] = []
	if not meta.has("faction_rep"):
		meta["faction_rep"] = {
			"druides": 50.0, "anciens": 50.0, "korrigans": 50.0,
			"niamh": 50.0, "ankou": 50.0,
		}

	migrated["meta"] = meta
	migrated["version"] = CURRENT_VERSION
	return migrated


func _try_migrate_from_legacy() -> Dictionary:
	# Try loading from legacy slot 1, then autosave
	var legacy_data: Dictionary = {}
	for slot in range(1, LEGACY_SLOT_COUNT + 1):
		var path: String = LEGACY_SLOT_PATH % slot
		if FileAccess.file_exists(path):
			legacy_data = _try_load_file(path)
			if not legacy_data.is_empty():
				break
	if legacy_data.is_empty() and FileAccess.file_exists(LEGACY_AUTOSAVE_PATH):
		legacy_data = _try_load_file(LEGACY_AUTOSAVE_PATH)
	if legacy_data.is_empty():
		return {}
	# Wrap in profile format and migrate
	var profile_data: Dictionary = {
		"version": str(legacy_data.get("version", "0.4.0")),
		"meta": legacy_data.get("meta", {}),
	}
	var migrated: Dictionary = _migrate(profile_data)
	# Save as new profile and cleanup legacy
	save_profile(migrated.get("meta", {}))
	_cleanup_legacy_files()
	push_warning("[MerlinSave] Migrated legacy save to profile v1.0.0")
	return migrated


func _cleanup_legacy_files() -> void:
	for slot in range(1, LEGACY_SLOT_COUNT + 1):
		var path: String = LEGACY_SLOT_PATH % slot
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		var bak: String = path + BACKUP_SUFFIX
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(bak)
	if FileAccess.file_exists(LEGACY_AUTOSAVE_PATH):
		DirAccess.remove_absolute(LEGACY_AUTOSAVE_PATH)
	var autosave_bak: String = LEGACY_AUTOSAVE_PATH + BACKUP_SUFFIX
	if FileAccess.file_exists(autosave_bak):
		DirAccess.remove_absolute(autosave_bak)


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════

func _try_load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json_text: String = file.get_as_text()
	file.close()
	if json_text.strip_edges().is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(json_text) != OK:
		push_warning("[MerlinSave] JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
	var data = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("[MerlinSave] Invalid save structure in %s" % path)
		return {}
	return data


func _backup_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var src: FileAccess = FileAccess.open(path, FileAccess.READ)
	if src == null:
		return
	var content: String = src.get_as_text()
	src.close()
	var dst: FileAccess = FileAccess.open(path + BACKUP_SUFFIX, FileAccess.WRITE)
	if dst:
		dst.store_string(content)
		dst.close()
