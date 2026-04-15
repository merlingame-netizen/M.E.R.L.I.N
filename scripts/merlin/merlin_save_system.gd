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
# DEFAULT PROFILE — bible 13.4 schema (source of truth)
# ═══════════════════════════════════════════════════════════════════════════════

static func _get_default_profile() -> Dictionary:
	return {
		"anam": 0,
		"total_runs": 0,
		"fins_vues": 0,
		"faction_rep": {
			"druides": 0.0, "anciens": 0.0, "korrigans": 0.0,
			"niamh": 0.0, "ankou": 0.0,
		},
		"trust_merlin": 0,
		"talent_tree": {"unlocked": []},
		"oghams": {
			"owned": ["beith", "luis", "quert"],
			"equipped": "beith",
		},
		"ogham_discounts": {},
		"endings_seen": [],
		"arc_tags": [],
		"biome_runs": {
			"foret_broceliande": 0, "landes_bruyere": 0,
			"cotes_sauvages": 0, "villages_celtes": 0,
			"cercles_pierres": 0, "marais_korrigans": 0,
			"collines_dolmens": 0, "iles_mystiques": 0,
		},
		"biomes_unlocked": ["foret_broceliande"],
		"whispers_seen": [],
		"run_history": [],
		"echo_memory": {
			"deaths_by_biome": {},
			"dominant_factions_seen": [],
			"choices_log": [],
		},
		"tutorial_flags": {},
		"stats": {
			"total_cards": 0, "total_minigames_won": 0,
			"total_deaths": 0, "consecutive_deaths": 0,
			"oghams_discovered_in_runs": 0, "total_anam_earned": 0,
			"total_play_time_seconds": 0, "total_minigames_played": 0,
		},
	}


static func _get_default_run_state() -> Dictionary:
	return {
		"biome": "foret_broceliande",
		"card_index": 0,
		"life_essence": MerlinConstants.LIFE_ESSENCE_START,
		"life_max": MerlinConstants.LIFE_ESSENCE_MAX,
		"biome_currency": 0,
		"equipped_oghams": ["beith"],
		"active_ogham": "beith",
		"cooldowns": {},
		"promises": [],
		"faction_rep_delta": {
			"druides": 0.0, "anciens": 0.0, "korrigans": 0.0,
			"niamh": 0.0, "ankou": 0.0,
		},
		"trust_delta": 0,
		"narrative_summary": "",
		"arc_tags_this_run": [],
		"period": "aube",
		"buffs": [],
		"events_log": [],
		"active": true,
		"anam": 0,
		"anam_accumulated": 0,
		"cards_played": 0,
		"day": 1,
		"story_log": [],
		"active_tags": [],
		"active_promises": [],
		"hidden": {
			"karma": 0,
			"tension": 0,
			"narrative_debt": [],
		},
		"power_bonuses": {},
		"active_scenario": "",
	}


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func save_profile(meta: Dictionary) -> bool:
	_backup_file(PROFILE_PATH)
	var data: Dictionary = {
		"version": CURRENT_VERSION,
		"timestamp": int(Time.get_unix_time_from_system()),
		"meta": meta.duplicate(true),
		"run_state": null,
	}
	# Preserve run_state if it exists in current save
	var existing: Dictionary = _try_load_file(PROFILE_PATH)
	if not existing.is_empty() and existing.has("run_state") and existing["run_state"] != null:
		data["run_state"] = existing["run_state"]
	return _write_file(PROFILE_PATH, data)


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
	var meta: Dictionary = data.get("meta", {})
	# Ensure all default keys exist
	var defaults: Dictionary = _get_default_profile()
	for key in defaults:
		if not meta.has(key):
			meta[key] = defaults[key]
	# SEC-2: Validate structure before returning loaded data
	if not _validate(meta):
		push_warning("[MerlinSave] Validation failed, returning defaults")
		return _get_default_profile()
	# SEC-2: Clamp numeric fields to prevent save-file tampering
	meta["anam"] = maxi(int(meta.get("anam", 0)), 0)
	meta["fins_vues"] = maxi(int(meta.get("fins_vues", 0)), 0)
	meta["total_runs"] = maxi(int(meta.get("total_runs", 0)), 0)
	meta["trust_merlin"] = clampi(int(meta.get("trust_merlin", 0)), 0, 100)
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	for faction in faction_rep:
		faction_rep[faction] = clampf(float(faction_rep[faction]), 0.0, 100.0)
	meta["faction_rep"] = faction_rep
	return meta


func load_or_create_profile() -> Dictionary:
	var meta: Dictionary = load_profile()
	if meta.is_empty():
		meta = _get_default_profile()
		save_profile(meta)
	return meta


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
		"oghams_owned": meta.get("oghams", {}).get("owned", []).size(),
		"trust_merlin": int(meta.get("trust_merlin", 0)),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# RUN STATE — Saved alongside profile for mid-run resume
# ═══════════════════════════════════════════════════════════════════════════════

func save_run_state(run_state: Dictionary) -> void:
	var data: Dictionary = _try_load_file(PROFILE_PATH)
	if data.is_empty():
		push_warning("[MerlinSave] No profile found, cannot save run_state")
		return
	data["run_state"] = run_state.duplicate(true)
	data["timestamp"] = int(Time.get_unix_time_from_system())
	_backup_file(PROFILE_PATH)
	_write_file(PROFILE_PATH, data)


func load_run_state() -> Dictionary:
	var data: Dictionary = _try_load_file(PROFILE_PATH)
	if data.is_empty():
		return {}
	var run_state = data.get("run_state")
	if run_state == null or not (run_state is Dictionary):
		return {}
	var rs: Dictionary = run_state as Dictionary
	# Fill missing keys from default run_state
	var defaults: Dictionary = _get_default_run_state()
	for key in defaults:
		if not rs.has(key):
			rs[key] = defaults[key]
	# Validate structure
	if not _validate_run_state(rs):
		push_warning("[MerlinSave] run_state validation failed, discarding")
		return {}
	# Clamp life to valid range
	rs["life_essence"] = clampi(int(rs.get("life_essence", 0)), 0, MerlinConstants.LIFE_ESSENCE_MAX)
	return rs


func clear_run_state() -> void:
	var data: Dictionary = _try_load_file(PROFILE_PATH)
	if data.is_empty():
		return
	data["run_state"] = null
	data["timestamp"] = int(Time.get_unix_time_from_system())
	_write_file(PROFILE_PATH, data)


func has_active_run() -> bool:
	return not load_run_state().is_empty()


# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

static func _validate(meta: Dictionary) -> bool:
	var required_keys: Array = [
		"anam", "total_runs", "faction_rep", "trust_merlin",
		"talent_tree", "oghams", "endings_seen", "arc_tags",
		"biome_runs", "biomes_unlocked", "tutorial_flags", "stats",
		"fins_vues", "echo_memory", "run_history", "whispers_seen",
	]
	for key in required_keys:
		if not meta.has(key):
			push_warning("[MerlinSave] Missing required key: %s" % key)
			return false
	# Validate faction_rep has all 5 factions
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	for faction in MerlinConstants.FACTIONS:
		if not faction_rep.has(faction):
			push_warning("[MerlinSave] Missing faction in faction_rep: %s" % faction)
			return false
	# Validate oghams structure
	var oghams: Dictionary = meta.get("oghams", {})
	if not oghams.has("owned") or not oghams.has("equipped"):
		push_warning("[MerlinSave] Invalid oghams structure")
		return false
	# Validate starter oghams present (bible: corrupted profile if missing)
	var owned: Array = oghams.get("owned", [])
	for starter in MerlinConstants.OGHAM_STARTER_SKILLS:
		if not owned.has(starter):
			push_warning("[MerlinSave] Missing starter ogham: %s — forcing reset" % starter)
			return false
	# Validate numeric type constraints
	if typeof(meta.get("anam")) != TYPE_INT and typeof(meta.get("anam")) != TYPE_FLOAT:
		push_warning("[MerlinSave] anam must be numeric")
		return false
	if typeof(meta.get("trust_merlin")) != TYPE_INT and typeof(meta.get("trust_merlin")) != TYPE_FLOAT:
		push_warning("[MerlinSave] trust_merlin must be numeric")
		return false
	if typeof(meta.get("fins_vues")) != TYPE_INT and typeof(meta.get("fins_vues")) != TYPE_FLOAT:
		push_warning("[MerlinSave] fins_vues must be numeric")
		return false
	# Validate array fields
	for arr_key: String in ["whispers_seen", "run_history", "endings_seen", "arc_tags"]:
		if not (meta.get(arr_key) is Array):
			push_warning("[MerlinSave] %s must be Array" % arr_key)
			return false
	# Validate echo_memory is a Dictionary
	if not (meta.get("echo_memory") is Dictionary):
		push_warning("[MerlinSave] echo_memory must be Dictionary")
		return false
	return true


static func _validate_run_state(run_state: Dictionary) -> bool:
	var required_keys: Array = [
		"biome", "card_index", "life_essence", "anam_accumulated",
		"life_max", "faction_rep_delta", "cards_played",
	]
	for key in required_keys:
		if not run_state.has(key):
			push_warning("[MerlinSave] run_state missing key: %s" % key)
			return false
	if typeof(run_state.get("card_index")) != TYPE_INT and typeof(run_state.get("card_index")) != TYPE_FLOAT:
		push_warning("[MerlinSave] run_state card_index must be numeric")
		return false
	if typeof(run_state.get("life_essence")) != TYPE_INT and typeof(run_state.get("life_essence")) != TYPE_FLOAT:
		push_warning("[MerlinSave] run_state life_essence must be numeric")
		return false
	var life_max: int = int(run_state.get("life_max", 0))
	if life_max < 1:
		push_warning("[MerlinSave] run_state life_max must be >= 1, got: %d" % life_max)
		return false
	if typeof(run_state.get("cards_played")) != TYPE_INT and typeof(run_state.get("cards_played")) != TYPE_FLOAT:
		push_warning("[MerlinSave] run_state cards_played must be numeric")
		return false
	if int(run_state.get("cards_played", -1)) < 0:
		push_warning("[MerlinSave] run_state cards_played must be >= 0")
		return false
	var rep_delta: Dictionary = run_state.get("faction_rep_delta", {})
	if not (rep_delta is Dictionary):
		push_warning("[MerlinSave] run_state faction_rep_delta must be Dictionary")
		return false
	for faction: String in MerlinConstants.FACTIONS:
		if not rep_delta.has(faction):
			push_warning("[MerlinSave] run_state faction_rep_delta missing faction: %s" % faction)
			return false
	return true


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
	meta.erase("bestiole_evolution")  # Legacy cleanup
	meta.erase("unlocked_evolutions")

	# Rename humains → niamh in faction_rep (if not already done)
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	if faction_rep.has("humains") and not faction_rep.has("niamh"):
		faction_rep["niamh"] = faction_rep["humains"]
		faction_rep.erase("humains")
		meta["faction_rep"] = faction_rep

	# Ensure all default keys exist (new in v1.0.0)
	var defaults: Dictionary = _get_default_profile()
	for key in defaults:
		if not meta.has(key):
			meta[key] = defaults[key]

	# Ensure faction_rep has all 5 factions
	for faction in MerlinConstants.FACTIONS:
		if not faction_rep.has(faction):
			faction_rep[faction] = 0.0
	meta["faction_rep"] = faction_rep

	# Migrate old oghams format if needed
	if not meta.has("oghams") or not (meta["oghams"] is Dictionary):
		meta["oghams"] = defaults["oghams"]

	# Ensure stats has all expected sub-keys
	var stats: Dictionary = meta.get("stats", {})
	var default_stats: Dictionary = defaults.get("stats", {})
	for stat_key in default_stats:
		if not stats.has(stat_key):
			stats[stat_key] = default_stats[stat_key]
	meta["stats"] = stats

	migrated["meta"] = meta
	migrated["version"] = CURRENT_VERSION
	migrated["run_state"] = migrated.get("run_state")
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


func _write_file(path: String, data: Dictionary) -> bool:
	var json_text: String = JSON.stringify(data, "\t")
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("[MerlinSave] Cannot write to %s" % path)
		return false
	file.store_string(json_text)
	file.close()
	return true


func _backup_file(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var src: FileAccess = FileAccess.open(path, FileAccess.READ)
	if src == null:
		push_warning("[MerlinSave] Cannot read %s for backup" % path)
		return
	var content: String = src.get_as_text()
	src.close()
	var dst: FileAccess = FileAccess.open(path + BACKUP_SUFFIX, FileAccess.WRITE)
	if dst:
		dst.store_string(content)
		dst.close()
	else:
		push_warning("[MerlinSave] Cannot write backup to %s" % (path + BACKUP_SUFFIX))
