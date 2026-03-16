## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — MerlinSaveSystem validation, clamping, migration, run_state
## ═══════════════════════════════════════════════════════════════════════════════
## Complements test_save_system.gd: focuses on _validate, _validate_run_state,
## migration edge cases, clamping logic, default key filling, and profile_info
## computed values. No overlap with existing tests.
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _make_valid_meta() -> Dictionary:
	return MerlinSaveSystem._get_default_profile()


func _make_valid_run_state() -> Dictionary:
	return MerlinSaveSystem._get_default_run_state()


func _make_save_instance() -> MerlinSaveSystem:
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	save.reset_profile()
	return save


# ═══════════════════════════════════════════════════════════════════════════════
# _validate — MISSING REQUIRED KEYS
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_rejects_empty_dict() -> bool:
	var result: bool = MerlinSaveSystem._validate({})
	if result:
		push_error("_validate should reject empty dictionary")
		return false
	return true


func test_validate_rejects_missing_anam() -> bool:
	var meta: Dictionary = _make_valid_meta()
	meta.erase("anam")
	var result: bool = MerlinSaveSystem._validate(meta)
	if result:
		push_error("_validate should reject meta without 'anam'")
		return false
	return true


func test_validate_rejects_missing_faction_rep() -> bool:
	var meta: Dictionary = _make_valid_meta()
	meta.erase("faction_rep")
	var result: bool = MerlinSaveSystem._validate(meta)
	if result:
		push_error("_validate should reject meta without 'faction_rep'")
		return false
	return true


func test_validate_rejects_missing_oghams() -> bool:
	var meta: Dictionary = _make_valid_meta()
	meta.erase("oghams")
	var result: bool = MerlinSaveSystem._validate(meta)
	if result:
		push_error("_validate should reject meta without 'oghams'")
		return false
	return true


func test_validate_rejects_missing_stats() -> bool:
	var meta: Dictionary = _make_valid_meta()
	meta.erase("stats")
	var result: bool = MerlinSaveSystem._validate(meta)
	if result:
		push_error("_validate should reject meta without 'stats'")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _validate — INCOMPLETE FACTION REP
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_rejects_missing_faction_in_rep() -> bool:
	var meta: Dictionary = _make_valid_meta()
	var faction_rep: Dictionary = meta["faction_rep"].duplicate()
	faction_rep.erase("ankou")
	meta["faction_rep"] = faction_rep
	var result: bool = MerlinSaveSystem._validate(meta)
	if result:
		push_error("_validate should reject faction_rep missing 'ankou'")
		return false
	return true


func test_validate_rejects_empty_faction_rep() -> bool:
	var meta: Dictionary = _make_valid_meta()
	meta["faction_rep"] = {}
	var result: bool = MerlinSaveSystem._validate(meta)
	if result:
		push_error("_validate should reject empty faction_rep")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _validate — OGHAMS STRUCTURE
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_rejects_oghams_without_owned() -> bool:
	var meta: Dictionary = _make_valid_meta()
	meta["oghams"] = {"equipped": "beith"}
	var result: bool = MerlinSaveSystem._validate(meta)
	if result:
		push_error("_validate should reject oghams without 'owned'")
		return false
	return true


func test_validate_rejects_oghams_without_equipped() -> bool:
	var meta: Dictionary = _make_valid_meta()
	meta["oghams"] = {"owned": ["beith", "luis", "quert"]}
	var result: bool = MerlinSaveSystem._validate(meta)
	if result:
		push_error("_validate should reject oghams without 'equipped'")
		return false
	return true


func test_validate_rejects_missing_starter_ogham() -> bool:
	var meta: Dictionary = _make_valid_meta()
	# Remove one starter from owned list
	meta["oghams"] = {"owned": ["beith", "luis"], "equipped": "beith"}
	var result: bool = MerlinSaveSystem._validate(meta)
	if result:
		push_error("_validate should reject owned list missing starter 'quert'")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _validate — TYPE CONSTRAINTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_rejects_string_anam() -> bool:
	var meta: Dictionary = _make_valid_meta()
	meta["anam"] = "not_a_number"
	var result: bool = MerlinSaveSystem._validate(meta)
	if result:
		push_error("_validate should reject non-numeric anam")
		return false
	return true


func test_validate_rejects_string_trust_merlin() -> bool:
	var meta: Dictionary = _make_valid_meta()
	meta["trust_merlin"] = "high"
	var result: bool = MerlinSaveSystem._validate(meta)
	if result:
		push_error("_validate should reject non-numeric trust_merlin")
		return false
	return true


func test_validate_accepts_float_anam() -> bool:
	var meta: Dictionary = _make_valid_meta()
	meta["anam"] = 5.0
	var result: bool = MerlinSaveSystem._validate(meta)
	if not result:
		push_error("_validate should accept float anam")
		return false
	return true


func test_validate_accepts_valid_profile() -> bool:
	var meta: Dictionary = _make_valid_meta()
	var result: bool = MerlinSaveSystem._validate(meta)
	if not result:
		push_error("_validate should accept a fully valid profile")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# _validate_run_state
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_run_state_rejects_empty() -> bool:
	var result: bool = MerlinSaveSystem._validate_run_state({})
	if result:
		push_error("_validate_run_state should reject empty dict")
		return false
	return true


func test_validate_run_state_rejects_missing_biome() -> bool:
	var rs: Dictionary = {"card_index": 0, "life_essence": 100}
	var result: bool = MerlinSaveSystem._validate_run_state(rs)
	if result:
		push_error("_validate_run_state should reject missing 'biome'")
		return false
	return true


func test_validate_run_state_rejects_string_card_index() -> bool:
	var rs: Dictionary = {"biome": "foret_broceliande", "card_index": "two", "life_essence": 100}
	var result: bool = MerlinSaveSystem._validate_run_state(rs)
	if result:
		push_error("_validate_run_state should reject string card_index")
		return false
	return true


func test_validate_run_state_rejects_string_life_essence() -> bool:
	var rs: Dictionary = {"biome": "foret_broceliande", "card_index": 0, "life_essence": "full"}
	var result: bool = MerlinSaveSystem._validate_run_state(rs)
	if result:
		push_error("_validate_run_state should reject string life_essence")
		return false
	return true


func test_validate_run_state_accepts_valid() -> bool:
	var rs: Dictionary = _make_valid_run_state()
	var result: bool = MerlinSaveSystem._validate_run_state(rs)
	if not result:
		push_error("_validate_run_state should accept valid run_state")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MIGRATION — ESSENCE CONVERSION
# ═══════════════════════════════════════════════════════════════════════════════

func test_migration_converts_essence_to_anam() -> bool:
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	var meta: Dictionary = _make_valid_meta()
	meta["anam"] = 10
	meta["essence"] = {"fire": 5, "water": 3, "earth": 2}
	var data: Dictionary = {"version": "0.4.0", "meta": meta}
	var migrated: Dictionary = save._migrate(data)
	var migrated_meta: Dictionary = migrated.get("meta", {})
	var anam_val: int = int(migrated_meta.get("anam", 0))
	# 10 (existing) + 5 + 3 + 2 = 20
	if anam_val != 20:
		push_error("Migration should sum essence into anam: expected 20, got %d" % anam_val)
		return false
	return true


func test_migration_removes_dead_currencies() -> bool:
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	var meta: Dictionary = _make_valid_meta()
	meta["essence"] = {"fire": 1}
	meta["ogham_fragments"] = 5
	meta["liens"] = 3
	meta["gloire_points"] = 10
	meta["bestiole_evolution"] = "advanced"
	meta["unlocked_evolutions"] = ["evo1"]
	var data: Dictionary = {"version": "0.4.0", "meta": meta}
	var migrated: Dictionary = save._migrate(data)
	var migrated_meta: Dictionary = migrated.get("meta", {})
	var dead_keys: Array = ["essence", "ogham_fragments", "liens", "gloire_points", "bestiole_evolution", "unlocked_evolutions"]
	for key in dead_keys:
		if migrated_meta.has(key):
			push_error("Migration should remove dead currency key: %s" % key)
			return false
	return true


func test_migration_fills_missing_stats_subkeys() -> bool:
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	var meta: Dictionary = _make_valid_meta()
	# Partial stats — missing some keys
	meta["stats"] = {"total_cards": 42}
	var data: Dictionary = {"version": "0.4.0", "meta": meta}
	var migrated: Dictionary = save._migrate(data)
	var migrated_stats: Dictionary = migrated.get("meta", {}).get("stats", {})
	if int(migrated_stats.get("total_cards", 0)) != 42:
		push_error("Migration should preserve existing stat value")
		return false
	if not migrated_stats.has("total_deaths"):
		push_error("Migration should fill missing stats key 'total_deaths'")
		return false
	if not migrated_stats.has("total_play_time_seconds"):
		push_error("Migration should fill missing stats key 'total_play_time_seconds'")
		return false
	return true


func test_migration_replaces_non_dict_oghams() -> bool:
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	var meta: Dictionary = _make_valid_meta()
	meta["oghams"] = "corrupted"
	var data: Dictionary = {"version": "0.4.0", "meta": meta}
	var migrated: Dictionary = save._migrate(data)
	var migrated_oghams = migrated.get("meta", {}).get("oghams")
	if not (migrated_oghams is Dictionary):
		push_error("Migration should replace non-dict oghams with default dict")
		return false
	if not migrated_oghams.has("owned"):
		push_error("Migrated oghams should have 'owned' key")
		return false
	return true


func test_migration_adds_missing_factions() -> bool:
	var save: MerlinSaveSystem = MerlinSaveSystem.new()
	var meta: Dictionary = _make_valid_meta()
	# Remove two factions to simulate old save
	var faction_rep: Dictionary = meta["faction_rep"].duplicate()
	faction_rep.erase("korrigans")
	faction_rep.erase("ankou")
	meta["faction_rep"] = faction_rep
	var data: Dictionary = {"version": "0.4.0", "meta": meta}
	var migrated: Dictionary = save._migrate(data)
	var migrated_rep: Dictionary = migrated.get("meta", {}).get("faction_rep", {})
	for faction in MerlinConstants.FACTIONS:
		if not migrated_rep.has(faction):
			push_error("Migration should add missing faction: %s" % faction)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CLAMPING — load_profile clamps anam and faction_rep
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_profile_clamps_negative_anam() -> bool:
	var save: MerlinSaveSystem = _make_save_instance()
	var meta: Dictionary = _make_valid_meta()
	meta["anam"] = -50
	save.save_profile(meta)
	var loaded: Dictionary = save.load_profile()
	var anam_val: int = int(loaded.get("anam", -1))
	if anam_val < 0:
		push_error("load_profile should clamp negative anam to 0, got %d" % anam_val)
		save.reset_profile()
		return false
	save.reset_profile()
	return true


func test_load_profile_clamps_faction_rep_over_100() -> bool:
	var save: MerlinSaveSystem = _make_save_instance()
	var meta: Dictionary = _make_valid_meta()
	meta["faction_rep"]["druides"] = 150.0
	save.save_profile(meta)
	var loaded: Dictionary = save.load_profile()
	var druides_val: float = float(loaded.get("faction_rep", {}).get("druides", 0.0))
	if druides_val > 100.0:
		push_error("load_profile should clamp faction_rep to 100, got %f" % druides_val)
		save.reset_profile()
		return false
	save.reset_profile()
	return true


func test_load_profile_clamps_faction_rep_below_zero() -> bool:
	var save: MerlinSaveSystem = _make_save_instance()
	var meta: Dictionary = _make_valid_meta()
	meta["faction_rep"]["ankou"] = -30.0
	save.save_profile(meta)
	var loaded: Dictionary = save.load_profile()
	var ankou_val: float = float(loaded.get("faction_rep", {}).get("ankou", -1.0))
	if ankou_val < 0.0:
		push_error("load_profile should clamp negative faction_rep to 0, got %f" % ankou_val)
		save.reset_profile()
		return false
	save.reset_profile()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUN STATE — DEFAULT KEY FILLING + LIFE CLAMPING
# ═══════════════════════════════════════════════════════════════════════════════

func test_run_state_fills_missing_defaults() -> bool:
	var save: MerlinSaveSystem = _make_save_instance()
	save.save_profile(_make_valid_meta())
	# Save minimal run_state — only required keys
	var minimal_rs: Dictionary = {
		"biome": "landes_bruyere",
		"card_index": 2,
		"life_essence": 80,
	}
	save.save_run_state(minimal_rs)
	var loaded: Dictionary = save.load_run_state()
	if loaded.is_empty():
		push_error("load_run_state should return data for minimal valid run_state")
		save.reset_profile()
		return false
	# Check that default keys were filled
	if not loaded.has("promises"):
		push_error("load_run_state should fill missing 'promises' from defaults")
		save.reset_profile()
		return false
	if not loaded.has("faction_rep_delta"):
		push_error("load_run_state should fill missing 'faction_rep_delta' from defaults")
		save.reset_profile()
		return false
	if not loaded.has("hidden"):
		push_error("load_run_state should fill missing 'hidden' from defaults")
		save.reset_profile()
		return false
	save.reset_profile()
	return true


func test_run_state_clamps_life_over_max() -> bool:
	var save: MerlinSaveSystem = _make_save_instance()
	save.save_profile(_make_valid_meta())
	var rs: Dictionary = {
		"biome": "foret_broceliande",
		"card_index": 0,
		"life_essence": 999,
	}
	save.save_run_state(rs)
	var loaded: Dictionary = save.load_run_state()
	var life_val: int = int(loaded.get("life_essence", 0))
	if life_val > MerlinConstants.LIFE_ESSENCE_MAX:
		push_error("load_run_state should clamp life_essence to max %d, got %d" % [MerlinConstants.LIFE_ESSENCE_MAX, life_val])
		save.reset_profile()
		return false
	save.reset_profile()
	return true


func test_run_state_clamps_life_below_zero() -> bool:
	var save: MerlinSaveSystem = _make_save_instance()
	save.save_profile(_make_valid_meta())
	var rs: Dictionary = {
		"biome": "foret_broceliande",
		"card_index": 0,
		"life_essence": -10,
	}
	save.save_run_state(rs)
	var loaded: Dictionary = save.load_run_state()
	var life_val: int = int(loaded.get("life_essence", -1))
	if life_val < 0:
		push_error("load_run_state should clamp negative life_essence to 0, got %d" % life_val)
		save.reset_profile()
		return false
	save.reset_profile()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT PROFILE/RUN_STATE — STRUCTURAL COMPLETENESS
# ═══════════════════════════════════════════════════════════════════════════════

func test_default_profile_has_tutorial_flags() -> bool:
	var meta: Dictionary = MerlinSaveSystem._get_default_profile()
	if not meta.has("tutorial_flags"):
		push_error("Default profile must have 'tutorial_flags'")
		return false
	if not (meta["tutorial_flags"] is Dictionary):
		push_error("tutorial_flags must be a Dictionary")
		return false
	return true


func test_default_profile_biomes_unlocked_starts_with_broceliande() -> bool:
	var meta: Dictionary = MerlinSaveSystem._get_default_profile()
	var unlocked: Array = meta.get("biomes_unlocked", [])
	if unlocked.size() != 1:
		push_error("biomes_unlocked should start with exactly 1 biome, got %d" % unlocked.size())
		return false
	if str(unlocked[0]) != "foret_broceliande":
		push_error("First unlocked biome should be 'foret_broceliande', got '%s'" % str(unlocked[0]))
		return false
	return true


func test_default_run_state_life_essence_equals_start() -> bool:
	var rs: Dictionary = MerlinSaveSystem._get_default_run_state()
	var life: int = int(rs.get("life_essence", 0))
	if life != MerlinConstants.LIFE_ESSENCE_START:
		push_error("Default run_state life_essence should be %d, got %d" % [MerlinConstants.LIFE_ESSENCE_START, life])
		return false
	return true


func test_default_run_state_is_active() -> bool:
	var rs: Dictionary = MerlinSaveSystem._get_default_run_state()
	var active = rs.get("active", false)
	if not active:
		push_error("Default run_state should be active=true")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROFILE INFO — COMPUTED VALUES
# ═══════════════════════════════════════════════════════════════════════════════

func test_profile_info_counts_talents() -> bool:
	var save: MerlinSaveSystem = _make_save_instance()
	var meta: Dictionary = _make_valid_meta()
	meta["talent_tree"] = {"unlocked": ["talent_a", "talent_b", "talent_c"]}
	save.save_profile(meta)
	var info: Dictionary = save.get_profile_info()
	if int(info.get("talents_unlocked", 0)) != 3:
		push_error("profile_info talents_unlocked should be 3, got %d" % int(info.get("talents_unlocked", 0)))
		save.reset_profile()
		return false
	save.reset_profile()
	return true


func test_profile_info_counts_oghams_owned() -> bool:
	var save: MerlinSaveSystem = _make_save_instance()
	var meta: Dictionary = _make_valid_meta()
	# Default has 3 starters; add 2 more
	meta["oghams"]["owned"] = ["beith", "luis", "quert", "duir", "tinne"]
	save.save_profile(meta)
	var info: Dictionary = save.get_profile_info()
	if int(info.get("oghams_owned", 0)) != 5:
		push_error("profile_info oghams_owned should be 5, got %d" % int(info.get("oghams_owned", 0)))
		save.reset_profile()
		return false
	save.reset_profile()
	return true


func test_profile_info_counts_endings() -> bool:
	var save: MerlinSaveSystem = _make_save_instance()
	var meta: Dictionary = _make_valid_meta()
	meta["endings_seen"] = ["ending_druids", "ending_ankou"]
	save.save_profile(meta)
	var info: Dictionary = save.get_profile_info()
	if int(info.get("endings_seen", 0)) != 2:
		push_error("profile_info endings_seen should be 2, got %d" % int(info.get("endings_seen", 0)))
		save.reset_profile()
		return false
	save.reset_profile()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# LOAD PROFILE — VALIDATION FAILURE RETURNS DEFAULTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_profile_returns_defaults_on_invalid_save() -> bool:
	var save: MerlinSaveSystem = _make_save_instance()
	# Save a meta with missing starter ogham to trigger validation failure
	var meta: Dictionary = _make_valid_meta()
	meta["oghams"] = {"owned": ["beith"], "equipped": "beith"}
	save.save_profile(meta)
	var loaded: Dictionary = save.load_profile()
	# On validation failure, should return _get_default_profile()
	var defaults: Dictionary = MerlinSaveSystem._get_default_profile()
	var loaded_owned: Array = loaded.get("oghams", {}).get("owned", [])
	# Default has all 3 starters
	for starter in MerlinConstants.OGHAM_STARTER_SKILLS:
		if not loaded_owned.has(starter):
			push_error("On validation failure, load_profile should return defaults with starter '%s'" % starter)
			save.reset_profile()
			return false
	save.reset_profile()
	return true
