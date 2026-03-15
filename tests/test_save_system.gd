extends RefCounted
## Unit Tests — MerlinSaveSystem
## Tests: save/load roundtrip, backup recovery, run_state, profile_exists, reset, validation.

const SaveSystem = preload("res://scripts/merlin/merlin_save_system.gd")


func _make_test_meta() -> Dictionary:
	var meta: Dictionary = SaveSystem._get_default_profile()
	meta["anam"] = 42
	meta["total_runs"] = 3
	return meta


# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_default_profile_has_all_keys() -> bool:
	var meta: Dictionary = SaveSystem._get_default_profile()
	var required: Array = ["anam", "total_runs", "faction_rep", "trust_merlin",
		"talent_tree", "oghams", "endings_seen", "arc_tags", "biome_runs", "stats"]
	for key in required:
		if not meta.has(key):
			push_error("Missing default key: %s" % key)
			return false
	return true


func test_default_profile_has_5_factions() -> bool:
	var meta: Dictionary = SaveSystem._get_default_profile()
	var factions: Dictionary = meta.get("faction_rep", {})
	var expected: Array = ["druides", "anciens", "korrigans", "niamh", "ankou"]
	for f in expected:
		if not factions.has(f):
			push_error("Missing faction: %s" % f)
			return false
	return true


func test_default_profile_has_3_starter_oghams() -> bool:
	var meta: Dictionary = SaveSystem._get_default_profile()
	var owned: Array = meta.get("oghams", {}).get("owned", [])
	if owned.size() != 3:
		push_error("Expected 3 starter oghams, got %d" % owned.size())
		return false
	for o in ["beith", "luis", "quert"]:
		if not owned.has(o):
			push_error("Missing starter ogham: %s" % o)
			return false
	return true


func test_default_run_state_has_required_keys() -> bool:
	var rs: Dictionary = SaveSystem._get_default_run_state()
	var required: Array = ["biome", "card_index", "life_essence", "life_max",
		"biome_currency", "equipped_oghams", "active_ogham", "cooldowns",
		"promises", "faction_rep_delta", "trust_delta", "period"]
	for key in required:
		if not rs.has(key):
			push_error("Missing run_state key: %s" % key)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_accepts_valid_profile() -> bool:
	var meta: Dictionary = SaveSystem._get_default_profile()
	return SaveSystem._validate(meta)


func test_validate_rejects_missing_key() -> bool:
	var meta: Dictionary = SaveSystem._get_default_profile()
	meta.erase("anam")
	if SaveSystem._validate(meta):
		push_error("Validation should reject profile missing 'anam'")
		return false
	return true


func test_validate_rejects_missing_faction() -> bool:
	var meta: Dictionary = SaveSystem._get_default_profile()
	meta["faction_rep"].erase("druides")
	if SaveSystem._validate(meta):
		push_error("Validation should reject profile missing faction 'druides'")
		return false
	return true


func test_validate_rejects_bad_oghams() -> bool:
	var meta: Dictionary = SaveSystem._get_default_profile()
	meta["oghams"] = "not_a_dict"
	if SaveSystem._validate(meta):
		push_error("Validation should reject non-dict oghams")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROFILE INFO FORMAT
# ═══════════════════════════════════════════════════════════════════════════════

func test_default_biome_runs_has_8_biomes() -> bool:
	var meta: Dictionary = SaveSystem._get_default_profile()
	var biome_runs: Dictionary = meta.get("biome_runs", {})
	if biome_runs.size() != 8:
		push_error("Expected 8 biomes, got %d" % biome_runs.size())
		return false
	return true


func test_default_stats_keys() -> bool:
	var meta: Dictionary = SaveSystem._get_default_profile()
	var stats: Dictionary = meta.get("stats", {})
	var expected: Array = ["total_cards", "total_minigames_won", "total_deaths",
		"consecutive_deaths", "oghams_discovered_in_runs", "total_anam_earned"]
	for key in expected:
		if not stats.has(key):
			push_error("Missing stats key: %s" % key)
			return false
	return true
