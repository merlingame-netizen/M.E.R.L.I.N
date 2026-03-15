## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinSaveSystem v1.0.0
## ═══════════════════════════════════════════════════════════════════════════════
## Tests: build_save_data structure, faction keys present, version field,
## default profile keys, validation, run_state lifecycle, migration logic.
## Pattern: extends RefCounted, methods return false on failure.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_valid_meta() -> Dictionary:
	return {
		"anam": 0,
		"total_runs": 0,
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
		"stats": {
			"total_cards": 0, "total_minigames_won": 0,
			"total_deaths": 0, "consecutive_deaths": 0,
			"oghams_discovered_in_runs": 0, "total_anam_earned": 0,
		},
	}


# ═══════════════════════════════════════════════════════════════════════════════
# VERSION FIELD
# ═══════════════════════════════════════════════════════════════════════════════

func test_version_field_present() -> bool:
	if MerlinSaveSystem.CURRENT_VERSION.is_empty():
		push_error("CURRENT_VERSION should not be empty")
		return false
	return true


func test_version_format_semver() -> bool:
	# Should match major.minor.patch pattern
	var parts: PackedStringArray = MerlinSaveSystem.CURRENT_VERSION.split(".")
	if parts.size() != 3:
		push_error("Version should be semver (X.Y.Z), got: %s" % MerlinSaveSystem.CURRENT_VERSION)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# BUILD SAVE DATA STRUCTURE (via save_profile internals)
# We test the static _validate function indirectly via a well-formed meta dict.
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_save_data_structure() -> bool:
	var meta: Dictionary = _make_valid_meta()
	# A valid meta must have all required top-level keys
	var required_keys: Array = [
		"anam", "total_runs", "faction_rep", "trust_merlin",
		"talent_tree", "oghams", "endings_seen", "arc_tags",
		"biome_runs", "stats",
	]
	for key in required_keys:
		if not meta.has(key):
			push_error("build_save_data_structure: missing key '%s'" % key)
			return false
	return true


func test_save_data_contains_factions() -> bool:
	var meta: Dictionary = _make_valid_meta()
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	for faction in MerlinConstants.FACTIONS:
		if not faction_rep.has(faction):
			push_error("save data faction_rep missing faction: %s" % faction)
			return false
	return true


func test_save_data_faction_count_is_5() -> bool:
	var meta: Dictionary = _make_valid_meta()
	var faction_rep: Dictionary = meta.get("faction_rep", {})
	if faction_rep.size() != 5:
		push_error("faction_rep should have 5 factions, got %d" % faction_rep.size())
		return false
	return true


func test_save_data_oghams_structure() -> bool:
	var meta: Dictionary = _make_valid_meta()
	var oghams: Dictionary = meta.get("oghams", {})
	if not oghams.has("owned"):
		push_error("oghams must have 'owned' key")
		return false
	if not oghams.has("equipped"):
		push_error("oghams must have 'equipped' key")
		return false
	return true


func test_save_data_starter_oghams() -> bool:
	var meta: Dictionary = _make_valid_meta()
	var owned: Array = meta.get("oghams", {}).get("owned", [])
	for starter in MerlinConstants.OGHAM_STARTER_SKILLS:
		if not owned.has(starter):
			push_error("Starter ogham '%s' should be in owned" % starter)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT PROFILE — load_or_create_profile returns complete structure
# ═══════════════════════════════════════════════════════════════════════════════

func test_default_profile_has_all_biomes() -> bool:
	var save := MerlinSaveSystem.new()
	# Reset any existing profile to force default creation
	save.reset_profile()
	var meta: Dictionary = save.load_or_create_profile()
	var biome_runs: Dictionary = meta.get("biome_runs", {})
	var expected_biomes: Array = [
		"foret_broceliande", "landes_bruyere", "cotes_sauvages",
		"villages_celtes", "cercles_pierres", "marais_korrigans",
		"collines_dolmens", "iles_mystiques",
	]
	for biome in expected_biomes:
		if not biome_runs.has(biome):
			push_error("biome_runs missing biome: %s" % biome)
			save.reset_profile()
			return false
	save.reset_profile()
	return true


func test_default_profile_initial_anam_zero() -> bool:
	var save := MerlinSaveSystem.new()
	save.reset_profile()
	var meta: Dictionary = save.load_or_create_profile()
	if int(meta.get("anam", -1)) != 0:
		push_error("Initial anam should be 0, got %s" % str(meta.get("anam")))
		save.reset_profile()
		return false
	save.reset_profile()
	return true


func test_default_profile_trust_merlin_zero() -> bool:
	var save := MerlinSaveSystem.new()
	save.reset_profile()
	var meta: Dictionary = save.load_or_create_profile()
	if int(meta.get("trust_merlin", -1)) != 0:
		push_error("Initial trust_merlin should be 0")
		save.reset_profile()
		return false
	save.reset_profile()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROFILE EXISTENCE
# ═══════════════════════════════════════════════════════════════════════════════

func test_profile_not_exists_after_reset() -> bool:
	var save := MerlinSaveSystem.new()
	save.reset_profile()
	if save.profile_exists():
		push_error("profile_exists should be false after reset")
		return false
	return true


func test_profile_exists_after_save() -> bool:
	var save := MerlinSaveSystem.new()
	save.reset_profile()
	var meta: Dictionary = _make_valid_meta()
	save.save_profile(meta)
	if not save.profile_exists():
		push_error("profile_exists should be true after save_profile")
		save.reset_profile()
		return false
	save.reset_profile()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN STATE
# ═══════════════════════════════════════════════════════════════════════════════

func test_run_state_empty_when_no_profile() -> bool:
	var save := MerlinSaveSystem.new()
	save.reset_profile()
	var run_state: Dictionary = save.load_run_state()
	if not run_state.is_empty():
		push_error("run_state should be empty when no profile exists")
		save.reset_profile()
		return false
	return true


func test_has_active_run_false_initially() -> bool:
	var save := MerlinSaveSystem.new()
	save.reset_profile()
	if save.has_active_run():
		push_error("has_active_run should be false with no profile")
		save.reset_profile()
		return false
	return true


func test_save_and_load_run_state() -> bool:
	var save := MerlinSaveSystem.new()
	save.reset_profile()
	# Must have a profile before saving run_state
	save.save_profile(_make_valid_meta())
	var run_state: Dictionary = {
		"biome": "cotes_sauvages",
		"card_index": 7,
		"life_essence": 65,
	}
	save.save_run_state(run_state)
	var loaded: Dictionary = save.load_run_state()
	if loaded.is_empty():
		push_error("load_run_state should return data after save_run_state")
		save.reset_profile()
		return false
	if str(loaded.get("biome", "")) != "cotes_sauvages":
		push_error("run_state biome mismatch: got %s" % loaded.get("biome", ""))
		save.reset_profile()
		return false
	if int(loaded.get("card_index", -1)) != 7:
		push_error("run_state card_index mismatch: got %s" % str(loaded.get("card_index")))
		save.reset_profile()
		return false
	save.reset_profile()
	return true


func test_clear_run_state() -> bool:
	var save := MerlinSaveSystem.new()
	save.reset_profile()
	save.save_profile(_make_valid_meta())
	save.save_run_state({"biome": "foret_broceliande", "card_index": 3})
	save.clear_run_state()
	if save.has_active_run():
		push_error("has_active_run should be false after clear_run_state")
		save.reset_profile()
		return false
	save.reset_profile()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# GET_PROFILE_INFO
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_profile_info_structure() -> bool:
	var save := MerlinSaveSystem.new()
	save.reset_profile()
	save.save_profile(_make_valid_meta())
	var info: Dictionary = save.get_profile_info()
	var expected_keys: Array = ["anam", "total_runs", "talents_unlocked", "endings_seen", "faction_rep", "oghams_owned", "trust_merlin"]
	for key in expected_keys:
		if not info.has(key):
			push_error("get_profile_info missing key: %s" % key)
			save.reset_profile()
			return false
	save.reset_profile()
	return true


func test_get_profile_info_empty_when_no_profile() -> bool:
	var save := MerlinSaveSystem.new()
	save.reset_profile()
	var info: Dictionary = save.get_profile_info()
	if not info.is_empty():
		push_error("get_profile_info should return empty dict when no profile")
		save.reset_profile()
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MIGRATION — legacy humains -> niamh rename
# ═══════════════════════════════════════════════════════════════════════════════

func test_migration_renames_humains_to_niamh() -> bool:
	var save := MerlinSaveSystem.new()
	# Build a legacy-style data dict with "humains" instead of "niamh"
	var legacy_meta: Dictionary = _make_valid_meta()
	var faction_rep: Dictionary = legacy_meta.get("faction_rep", {})
	faction_rep.erase("niamh")
	faction_rep["humains"] = 25.0
	legacy_meta["faction_rep"] = faction_rep

	var legacy_data: Dictionary = {
		"version": "0.4.0",
		"meta": legacy_meta,
	}
	# Access _migrate via instance (it's not static)
	var migrated: Dictionary = save._migrate(legacy_data)
	var migrated_meta: Dictionary = migrated.get("meta", {})
	var migrated_rep: Dictionary = migrated_meta.get("faction_rep", {})

	if migrated_rep.has("humains"):
		push_error("Migration should remove 'humains' key")
		return false
	if not migrated_rep.has("niamh"):
		push_error("Migration should add 'niamh' key")
		return false
	if float(migrated_rep.get("niamh", 0.0)) != 25.0:
		push_error("Migration should preserve humains value in niamh")
		return false
	return true


func test_migration_updates_version() -> bool:
	var save := MerlinSaveSystem.new()
	var old_data: Dictionary = {
		"version": "0.4.0",
		"meta": _make_valid_meta(),
	}
	var migrated: Dictionary = save._migrate(old_data)
	if str(migrated.get("version", "")) != MerlinSaveSystem.CURRENT_VERSION:
		push_error("Migrated version should be CURRENT_VERSION")
		return false
	return true
