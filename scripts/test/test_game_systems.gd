## ═══════════════════════════════════════════════════════════════════════════════
## Test Game Systems — 6 subsystems, ~100 tests, headless-compatible
## ═══════════════════════════════════════════════════════════════════════════════
## Systems under test:
##   1. MerlinSaveSystem      — validation, defaults, run_state validation
##   2. MerlinBiomeSystem     — biome specs, unlock, passive, ogham bonus
##   3. MerlinScenarioManager — state lifecycle, anchors, conditions, branches
##   4. MerlinMiniGameSystem  — field scoring, thresholds, difficulty curve
##   5. MerlinReputationSystem — factions, tiers, caps, delta, dominance
##   6. MerlinActionResolver  — resolve, modifiers, hidden tests, chance/risk
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error on fail
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# 1. SAVE SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════


func test_save_default_profile_has_all_keys() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	var expected_keys: Array = [
		"anam", "total_runs", "faction_rep", "trust_merlin",
		"talent_tree", "oghams", "endings_seen", "arc_tags",
		"biome_runs", "biomes_unlocked", "tutorial_flags", "stats",
	]
	for key in expected_keys:
		if not profile.has(key):
			push_error("Default profile missing key: %s" % key)
			return false
	return true


func test_save_default_profile_starter_oghams() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	var owned: Array = profile.get("oghams", {}).get("owned", [])
	for starter in MerlinConstants.OGHAM_STARTER_SKILLS:
		if not owned.has(starter):
			push_error("Default profile missing starter ogham: %s" % starter)
			return false
	return true


func test_save_default_profile_factions() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	var faction_rep: Dictionary = profile.get("faction_rep", {})
	for faction in MerlinConstants.FACTIONS:
		if not faction_rep.has(faction):
			push_error("Default profile missing faction: %s" % faction)
			return false
		if float(faction_rep[faction]) != 0.0:
			push_error("Default faction_rep should be 0.0 for %s" % faction)
			return false
	return true


func test_save_default_profile_initial_values() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	if int(profile.get("anam", -1)) != 0:
		push_error("Default anam should be 0")
		return false
	if int(profile.get("total_runs", -1)) != 0:
		push_error("Default total_runs should be 0")
		return false
	if int(profile.get("trust_merlin", -1)) != 0:
		push_error("Default trust_merlin should be 0")
		return false
	return true


func test_save_default_biomes_unlocked() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	var unlocked: Array = profile.get("biomes_unlocked", [])
	if unlocked.size() != 1:
		push_error("Default should have exactly 1 biome unlocked, got %d" % unlocked.size())
		return false
	if unlocked[0] != "foret_broceliande":
		push_error("Default unlocked biome should be foret_broceliande")
		return false
	return true


func test_save_validate_valid_profile() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	if not MerlinSaveSystem._validate(profile):
		push_error("Default profile should pass validation")
		return false
	return true


func test_save_validate_missing_key() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	profile.erase("anam")
	if MerlinSaveSystem._validate(profile):
		push_error("Profile missing 'anam' should fail validation")
		return false
	return true


func test_save_validate_missing_faction() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	var faction_rep: Dictionary = profile.get("faction_rep", {}).duplicate()
	faction_rep.erase("korrigans")
	profile["faction_rep"] = faction_rep
	if MerlinSaveSystem._validate(profile):
		push_error("Profile missing faction 'korrigans' should fail validation")
		return false
	return true


func test_save_validate_missing_oghams_structure() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	profile["oghams"] = {}
	if MerlinSaveSystem._validate(profile):
		push_error("Profile with empty oghams should fail validation")
		return false
	return true


func test_save_validate_missing_starter_ogham() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	var oghams: Dictionary = profile.get("oghams", {}).duplicate(true)
	oghams["owned"] = ["beith", "luis"]  # missing quert
	profile["oghams"] = oghams
	if MerlinSaveSystem._validate(profile):
		push_error("Profile missing starter ogham 'quert' should fail validation")
		return false
	return true


func test_save_validate_non_numeric_anam() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	profile["anam"] = "not_a_number"
	if MerlinSaveSystem._validate(profile):
		push_error("Profile with string anam should fail validation")
		return false
	return true


func test_save_validate_non_numeric_trust() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	profile["trust_merlin"] = "bad"
	if MerlinSaveSystem._validate(profile):
		push_error("Profile with string trust_merlin should fail validation")
		return false
	return true


func test_save_validate_float_anam_accepted() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	profile["anam"] = 5.0
	if not MerlinSaveSystem._validate(profile):
		push_error("Profile with float anam should pass validation")
		return false
	return true


func test_save_default_run_state_has_required_keys() -> bool:
	var rs: Dictionary = MerlinSaveSystem._get_default_run_state()
	var required: Array = ["biome", "card_index", "life_essence"]
	for key in required:
		if not rs.has(key):
			push_error("Default run_state missing key: %s" % key)
			return false
	return true


func test_save_default_run_state_life_values() -> bool:
	var rs: Dictionary = MerlinSaveSystem._get_default_run_state()
	if int(rs.get("life_essence", 0)) != MerlinConstants.LIFE_ESSENCE_START:
		push_error("Default life_essence should be %d" % MerlinConstants.LIFE_ESSENCE_START)
		return false
	if int(rs.get("life_max", 0)) != MerlinConstants.LIFE_ESSENCE_MAX:
		push_error("Default life_max should be %d" % MerlinConstants.LIFE_ESSENCE_MAX)
		return false
	return true


func test_save_validate_run_state_valid() -> bool:
	var rs: Dictionary = MerlinSaveSystem._get_default_run_state()
	if not MerlinSaveSystem._validate_run_state(rs):
		push_error("Default run_state should pass validation")
		return false
	return true


func test_save_validate_run_state_missing_key() -> bool:
	var rs: Dictionary = MerlinSaveSystem._get_default_run_state()
	rs.erase("life_essence")
	if MerlinSaveSystem._validate_run_state(rs):
		push_error("Run state missing life_essence should fail validation")
		return false
	return true


func test_save_validate_run_state_non_numeric_card_index() -> bool:
	var rs: Dictionary = MerlinSaveSystem._get_default_run_state()
	rs["card_index"] = "bad"
	if MerlinSaveSystem._validate_run_state(rs):
		push_error("Run state with string card_index should fail validation")
		return false
	return true


func test_save_default_run_state_factions_delta() -> bool:
	var rs: Dictionary = MerlinSaveSystem._get_default_run_state()
	var delta: Dictionary = rs.get("faction_rep_delta", {})
	for faction in MerlinConstants.FACTIONS:
		if not delta.has(faction):
			push_error("Default run_state missing faction_rep_delta for: %s" % faction)
			return false
	return true


func test_save_default_stats_keys() -> bool:
	var profile: Dictionary = MerlinSaveSystem._get_default_profile()
	var stats: Dictionary = profile.get("stats", {})
	var expected: Array = [
		"total_cards", "total_minigames_won", "total_deaths",
		"consecutive_deaths", "oghams_discovered_in_runs",
		"total_anam_earned", "total_play_time_seconds", "total_minigames_played",
	]
	for key in expected:
		if not stats.has(key):
			push_error("Default stats missing key: %s" % key)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 2. BIOME SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════


func test_biome_all_8_biomes_defined() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var keys: Array = bs.get_all_biome_keys()
	if keys.size() != 8:
		push_error("Expected 8 biomes, got %d" % keys.size())
		return false
	return true


func test_biome_lookup_valid() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var biome: Dictionary = bs.get_biome("foret_broceliande")
	if biome.is_empty():
		push_error("foret_broceliande biome should not be empty")
		return false
	if str(biome.get("name", "")) != "Foret de Broceliande":
		push_error("foret_broceliande name mismatch")
		return false
	return true


func test_biome_lookup_invalid_returns_empty() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var biome: Dictionary = bs.get_biome("nonexistent_biome")
	if not biome.is_empty():
		push_error("Invalid biome key should return empty dict")
		return false
	return true


func test_biome_name_lookup() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var name_str: String = bs.get_biome_name("landes_bruyere")
	if name_str != "Landes de Bruyere":
		push_error("Expected 'Landes de Bruyere', got '%s'" % name_str)
		return false
	return true


func test_biome_color_not_white_for_valid() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var color: Color = bs.get_biome_color("foret_broceliande")
	if color == Color.WHITE:
		push_error("Valid biome should not return Color.WHITE")
		return false
	return true


func test_biome_color_white_for_invalid() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var color: Color = bs.get_biome_color("nonexistent")
	if color != Color.WHITE:
		push_error("Invalid biome should return Color.WHITE")
		return false
	return true


func test_biome_faction_affinity_has_entries() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var affinity: Dictionary = bs.get_faction_affinity("foret_broceliande")
	if affinity.is_empty():
		push_error("Biome faction_affinity should not be empty")
		return false
	if not affinity.has("korrigans"):
		push_error("foret_broceliande should have korrigans affinity")
		return false
	return true


func test_biome_passive_trigger_at_n() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	# foret_broceliande has every_n=5
	if not bs.should_trigger_passive("foret_broceliande", 5):
		push_error("Passive should trigger at card 5 (every_n=5)")
		return false
	if not bs.should_trigger_passive("foret_broceliande", 10):
		push_error("Passive should trigger at card 10 (every_n=5)")
		return false
	return true


func test_biome_passive_no_trigger_off_n() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	if bs.should_trigger_passive("foret_broceliande", 3):
		push_error("Passive should NOT trigger at card 3 (every_n=5)")
		return false
	if bs.should_trigger_passive("foret_broceliande", 0):
		push_error("Passive should NOT trigger at card 0")
		return false
	return true


func test_biome_passive_effect_heal_type() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	# foret_broceliande direction="up" => HEAL_LIFE
	var effect: Dictionary = bs.get_passive_effect("foret_broceliande", 5)
	if effect.is_empty():
		push_error("Passive effect should not be empty at trigger point")
		return false
	if str(effect.get("type", "")) != "HEAL_LIFE":
		push_error("foret_broceliande passive direction=up should produce HEAL_LIFE, got %s" % str(effect.get("type", "")))
		return false
	return true


func test_biome_passive_effect_damage_type() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	# landes_bruyere direction="down" every_n=6
	var effect: Dictionary = bs.get_passive_effect("landes_bruyere", 6)
	if effect.is_empty():
		push_error("Passive effect should not be empty at trigger point")
		return false
	if str(effect.get("type", "")) != "DAMAGE_LIFE":
		push_error("landes_bruyere passive direction=down should produce DAMAGE_LIFE")
		return false
	return true


func test_biome_passive_effect_empty_off_trigger() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var effect: Dictionary = bs.get_passive_effect("foret_broceliande", 3)
	if not effect.is_empty():
		push_error("Passive effect should be empty when not at trigger point")
		return false
	return true


func test_biome_ogham_cooldown_bonus_aligned() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	# foret_broceliande bonus oghams: quert, huath, coll — reduction 1
	var bonus: int = bs.get_ogham_cooldown_bonus("foret_broceliande", "quert")
	if bonus != 1:
		push_error("Expected cooldown bonus 1 for aligned ogham, got %d" % bonus)
		return false
	return true


func test_biome_ogham_cooldown_bonus_unaligned() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var bonus: int = bs.get_ogham_cooldown_bonus("foret_broceliande", "ailm")
	if bonus != 0:
		push_error("Expected cooldown bonus 0 for unaligned ogham, got %d" % bonus)
		return false
	return true


func test_biome_ogham_cooldown_bonus_cercles_pierres() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	# cercles_pierres has ogham_cooldown_reduction=2
	var bonus: int = bs.get_ogham_cooldown_bonus("cercles_pierres", "ioho")
	if bonus != 2:
		push_error("Expected cooldown bonus 2 for cercles_pierres aligned ogham, got %d" % bonus)
		return false
	return true


func test_biome_difficulty_modifier() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	if bs.get_difficulty_modifier("foret_broceliande") != 0:
		push_error("foret_broceliande difficulty should be 0")
		return false
	if bs.get_difficulty_modifier("landes_bruyere") != 1:
		push_error("landes_bruyere difficulty should be 1")
		return false
	if bs.get_difficulty_modifier("villages_celtes") != -1:
		push_error("villages_celtes difficulty should be -1")
		return false
	if bs.get_difficulty_modifier("iles_mystiques") != 3:
		push_error("iles_mystiques difficulty should be 3")
		return false
	return true


func test_biome_unlock_foret_always() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	# foret_broceliande has unlock=null => always unlocked
	var meta: Dictionary = {"total_runs": 0, "endings_seen": []}
	if not bs.is_unlocked("foret_broceliande", meta):
		push_error("foret_broceliande should always be unlocked")
		return false
	return true


func test_biome_unlock_landes_requires_runs() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	# landes_bruyere requires min_runs=2
	var meta_low: Dictionary = {"total_runs": 1, "endings_seen": []}
	if bs.is_unlocked("landes_bruyere", meta_low):
		push_error("landes_bruyere should be locked with 1 run")
		return false
	var meta_ok: Dictionary = {"total_runs": 2, "endings_seen": []}
	if not bs.is_unlocked("landes_bruyere", meta_ok):
		push_error("landes_bruyere should be unlocked with 2 runs")
		return false
	return true


func test_biome_unlock_cercles_requires_runs_and_endings() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	# cercles_pierres: min_runs=8, min_endings=2
	var meta_no: Dictionary = {"total_runs": 8, "endings_seen": ["harmonie"]}
	if bs.is_unlocked("cercles_pierres", meta_no):
		push_error("cercles_pierres should be locked with only 1 ending")
		return false
	var meta_ok: Dictionary = {"total_runs": 8, "endings_seen": ["harmonie", "destruction"]}
	if not bs.is_unlocked("cercles_pierres", meta_ok):
		push_error("cercles_pierres should be unlocked with 8 runs and 2 endings")
		return false
	return true


func test_biome_unlock_marais_requires_specific_ending() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	# marais_korrigans: min_runs=10, required_ending=harmonie
	var meta_wrong_ending: Dictionary = {"total_runs": 10, "endings_seen": ["destruction"]}
	if bs.is_unlocked("marais_korrigans", meta_wrong_ending):
		push_error("marais_korrigans should be locked without 'harmonie' ending")
		return false
	var meta_ok: Dictionary = {"total_runs": 10, "endings_seen": ["harmonie"]}
	if not bs.is_unlocked("marais_korrigans", meta_ok):
		push_error("marais_korrigans should be unlocked with 10 runs and harmonie ending")
		return false
	return true


func test_biome_unlock_hint_empty_for_foret() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var hint: String = bs.get_unlock_hint("foret_broceliande")
	if not hint.is_empty():
		push_error("foret_broceliande should have empty unlock hint")
		return false
	return true


func test_biome_unlock_hint_nonempty_for_locked() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var hint: String = bs.get_unlock_hint("landes_bruyere")
	if hint.is_empty():
		push_error("landes_bruyere should have non-empty unlock hint")
		return false
	if not hint.contains("2 runs"):
		push_error("landes_bruyere hint should mention 2 runs")
		return false
	return true


func test_biome_favored_season() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	if bs.get_favored_season("foret_broceliande") != "spring":
		push_error("foret_broceliande favored season should be spring")
		return false
	if bs.get_favored_season("cercles_pierres") != "winter":
		push_error("cercles_pierres favored season should be winter")
		return false
	return true


func test_biome_is_in_favored_season() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	if not bs.is_in_favored_season("foret_broceliande", "spring"):
		push_error("foret_broceliande should be in favored season during spring")
		return false
	if bs.is_in_favored_season("foret_broceliande", "winter"):
		push_error("foret_broceliande should NOT be in favored season during winter")
		return false
	return true


func test_biome_llm_context_valid() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var ctx: String = bs.get_biome_context_for_llm("foret_broceliande")
	if ctx.is_empty():
		push_error("LLM context for valid biome should not be empty")
		return false
	if not ctx.contains("BIOME:"):
		push_error("LLM context should contain 'BIOME:' prefix")
		return false
	return true


func test_biome_llm_context_empty_for_invalid() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	var ctx: String = bs.get_biome_context_for_llm("nonexistent")
	if not ctx.is_empty():
		push_error("LLM context for invalid biome should be empty")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 3. SCENARIO MANAGER
# ═══════════════════════════════════════════════════════════════════════════════


func test_scenario_initial_state_inactive() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	if sm.is_scenario_active():
		push_error("Scenario should be inactive on init")
		return false
	return true


func test_scenario_start_activates() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	var scenario: Dictionary = {"id": "test_sc", "title": "Test Scenario", "anchors": []}
	sm.start_scenario(scenario)
	if not sm.is_scenario_active():
		push_error("Scenario should be active after start")
		return false
	return true


func test_scenario_start_empty_does_nothing() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({})
	if sm.is_scenario_active():
		push_error("Empty scenario should not activate")
		return false
	return true


func test_scenario_title_when_active() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({"id": "t", "title": "The Trial"})
	if sm.get_scenario_title() != "The Trial":
		push_error("Scenario title should be 'The Trial'")
		return false
	return true


func test_scenario_title_when_inactive() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	if sm.get_scenario_title() != "":
		push_error("Inactive scenario title should be empty")
		return false
	return true


func test_scenario_tone_when_active() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({"id": "t", "tone": "sombre"})
	if sm.get_scenario_tone() != "sombre":
		push_error("Scenario tone should be 'sombre'")
		return false
	return true


func test_scenario_tone_when_inactive() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	if sm.get_scenario_tone() != "":
		push_error("Inactive scenario tone should be empty")
		return false
	return true


func test_scenario_theme_injection() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({"id": "t", "theme_injection": "Darkness falls"})
	if sm.get_theme_injection() != "Darkness falls":
		push_error("Theme injection mismatch")
		return false
	return true


func test_scenario_theme_injection_inactive() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	if sm.get_theme_injection() != "":
		push_error("Inactive theme injection should be empty")
		return false
	return true


func test_scenario_ambient_tags() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({"id": "t", "ambient_tags": ["fog", "danger"]})
	var tags: Array = sm.get_ambient_tags()
	if tags.size() != 2:
		push_error("Expected 2 ambient tags, got %d" % tags.size())
		return false
	return true


func test_scenario_ambient_tags_inactive() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	if sm.get_ambient_tags().size() != 0:
		push_error("Inactive ambient tags should be empty")
		return false
	return true


func test_scenario_triggered_count_initial() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	if sm.get_triggered_count() != 0:
		push_error("Initial triggered count should be 0")
		return false
	return true


func test_scenario_total_anchors() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({"id": "t", "anchors": [
		{"id": "a1", "position": 5},
		{"id": "a2", "position": 10},
	]})
	if sm.get_total_anchors() != 2:
		push_error("Expected 2 total anchors, got %d" % sm.get_total_anchors())
		return false
	return true


func test_scenario_total_anchors_inactive() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	if sm.get_total_anchors() != 0:
		push_error("Inactive total anchors should be 0")
		return false
	return true


func test_scenario_anchor_triggers_at_position() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({"id": "t", "anchors": [
		{"id": "a1", "position": 5, "position_flex": 1},
	]})
	var anchor: Dictionary = sm.get_anchor_for_card(5, {})
	if anchor.is_empty():
		push_error("Anchor should trigger at exact position")
		return false
	if str(anchor.get("anchor_id", "")) != "a1":
		push_error("Triggered anchor should be a1")
		return false
	return true


func test_scenario_anchor_triggers_within_flex() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({"id": "t", "anchors": [
		{"id": "a1", "position": 5, "position_flex": 2},
	]})
	# Should trigger at position 3 (5-2)
	var anchor: Dictionary = sm.get_anchor_for_card(3, {})
	if anchor.is_empty():
		push_error("Anchor should trigger within flex range")
		return false
	return true


func test_scenario_anchor_no_trigger_outside_flex() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({"id": "t", "anchors": [
		{"id": "a1", "position": 5, "position_flex": 1},
	]})
	var anchor: Dictionary = sm.get_anchor_for_card(10, {})
	if not anchor.is_empty():
		push_error("Anchor should NOT trigger outside flex range")
		return false
	return true


func test_scenario_anchor_no_trigger_when_inactive() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	var anchor: Dictionary = sm.get_anchor_for_card(5, {})
	if not anchor.is_empty():
		push_error("No anchor should trigger when scenario is inactive")
		return false
	return true


func test_scenario_resolve_anchor_marks_triggered() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({"id": "t", "anchors": [
		{"id": "a1", "position": 5, "position_flex": 1},
	]})
	sm.resolve_anchor("a1", 0)
	if sm.get_triggered_count() != 1:
		push_error("Triggered count should be 1 after resolve")
		return false
	# Should not trigger again
	var anchor: Dictionary = sm.get_anchor_for_card(5, {})
	if not anchor.is_empty():
		push_error("Already-triggered anchor should not trigger again")
		return false
	return true


func test_scenario_condition_empty_passes() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	# _check_condition with empty condition should return true
	if not sm._check_condition({}, {}):
		push_error("Empty condition should pass")
		return false
	return true


func test_scenario_condition_flag_check() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	# flag check with missing flag should fail
	if sm._check_condition({"flag": "rescued"}, {}):
		push_error("Missing flag should fail condition")
		return false
	# With flag present
	if not sm._check_condition({"flag": "rescued"}, {"rescued": true}):
		push_error("Present flag should pass condition")
		return false
	return true


func test_scenario_condition_any_flag() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	if sm._check_condition({"any_flag": ["a", "b"]}, {}):
		push_error("No flags present should fail any_flag condition")
		return false
	if not sm._check_condition({"any_flag": ["a", "b"]}, {"b": true}):
		push_error("One matching flag should pass any_flag condition")
		return false
	return true


func test_scenario_condition_all_flags() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	if sm._check_condition({"all_flags": ["a", "b"]}, {"a": true}):
		push_error("Missing one flag should fail all_flags condition")
		return false
	if not sm._check_condition({"all_flags": ["a", "b"]}, {"a": true, "b": true}):
		push_error("All flags present should pass all_flags condition")
		return false
	return true


func test_scenario_resolve_branch_no_branches() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	var anchor: Dictionary = {"prompt_override": "Do something", "flags_set": ["did_it"]}
	var resolved: Dictionary = sm._resolve_branch(anchor, {})
	if str(resolved.get("prompt_override", "")) != "Do something":
		push_error("Branch without branches dict should return anchor prompt_override")
		return false
	return true


func test_scenario_resolve_branch_default() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	var anchor: Dictionary = {
		"branches": {
			"default": {"prompt_override": "default path", "flags_set": []},
			"if_flag_rescued": {"prompt_override": "rescue path", "flags_set": []},
		}
	}
	var resolved: Dictionary = sm._resolve_branch(anchor, {})
	if str(resolved.get("prompt_override", "")) != "default path":
		push_error("Should resolve to default branch when no flags match")
		return false
	return true


func test_scenario_resolve_branch_flag_match() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	var anchor: Dictionary = {
		"branches": {
			"default": {"prompt_override": "default path", "flags_set": []},
			"if_flag_rescued": {"prompt_override": "rescue path", "flags_set": []},
		}
	}
	var resolved: Dictionary = sm._resolve_branch(anchor, {"rescued": true})
	if str(resolved.get("prompt_override", "")) != "rescue path":
		push_error("Should resolve to flag-matched branch")
		return false
	return true


func test_scenario_save_state() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({"id": "sc1", "title": "Test", "anchors": [{"id": "a1", "position": 5}]})
	sm.resolve_anchor("a1", 0)
	var state: Dictionary = sm.save_state()
	if str(state.get("active_scenario_id", "")) != "sc1":
		push_error("Saved state should have scenario id")
		return false
	var ta: Array = state.get("triggered_anchors", [])
	if ta.size() != 1 or str(ta[0]) != "a1":
		push_error("Saved state should have triggered anchors")
		return false
	return true


func test_scenario_load_state_empty_clears() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({"id": "sc1", "title": "Test"})
	sm.load_state({})
	if sm.is_scenario_active():
		push_error("Loading empty state should deactivate scenario")
		return false
	return true


func test_scenario_dealer_intro_override_inactive() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	var intro: Dictionary = sm.get_dealer_intro_override()
	if not intro.is_empty():
		push_error("Inactive scenario should return empty dealer intro")
		return false
	return true


func test_scenario_dealer_intro_override_active() -> bool:
	var sm: MerlinScenarioManager = MerlinScenarioManager.new()
	sm.start_scenario({"id": "t", "dealer_intro_context": "The mist thickens", "tone": "dark", "title": "Fog"})
	var intro: Dictionary = sm.get_dealer_intro_override()
	if intro.is_empty():
		push_error("Active scenario with dealer_intro_context should return override")
		return false
	if str(intro.get("context", "")) != "The mist thickens":
		push_error("Dealer intro context mismatch")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 4. MINIGAME SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════


func test_minigame_valid_fields_count() -> bool:
	var mg: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	if MerlinMiniGameSystem.VALID_FIELDS.size() != 8:
		push_error("Expected 8 valid fields, got %d" % MerlinMiniGameSystem.VALID_FIELDS.size())
		return false
	return true


func test_minigame_success_threshold() -> bool:
	if MerlinMiniGameSystem.SUCCESS_THRESHOLD != 80:
		push_error("Success threshold should be 80")
		return false
	return true


func test_minigame_run_returns_required_keys() -> bool:
	var mg: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(42)
	mg.set_rng(rng)
	var result: Dictionary = mg.run("esprit", 5)
	var required: Array = ["type", "success", "score", "time_ms"]
	for key in required:
		if not result.has(key):
			push_error("Minigame result missing key: %s" % key)
			return false
	return true


func test_minigame_run_type_preserved() -> bool:
	var mg: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(42)
	mg.set_rng(rng)
	var result: Dictionary = mg.run("Vigueur", 3)
	if str(result.get("type", "")) != "vigueur":
		push_error("Type should be lowercased: 'vigueur', got '%s'" % str(result.get("type", "")))
		return false
	return true


func test_minigame_score_clamped_0_100() -> bool:
	var mg: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	var rng: MerlinRng = MerlinRng.new()
	mg.set_rng(rng)
	# Run multiple times with different seeds
	for seed_val in range(1, 50):
		rng.set_seed(seed_val)
		for field in MerlinMiniGameSystem.VALID_FIELDS:
			var result: Dictionary = mg.run(field, 5)
			var score: int = int(result.get("score", -1))
			if score < 0 or score > 100:
				push_error("Score out of range [0,100]: %d for field %s seed %d" % [score, field, seed_val])
				return false
	return true


func test_minigame_success_matches_threshold() -> bool:
	var mg: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	var rng: MerlinRng = MerlinRng.new()
	mg.set_rng(rng)
	for seed_val in range(1, 30):
		rng.set_seed(seed_val)
		var result: Dictionary = mg.run("esprit", 5)
		var score: int = int(result.get("score", 0))
		var success: bool = result.get("success", false)
		if (score >= 80) != success:
			push_error("Success flag should match score >= 80 (score=%d, success=%s)" % [score, str(success)])
			return false
	return true


func test_minigame_difficulty_affects_hit_chance() -> bool:
	var mg: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	# _difficulty_to_hit_chance: diff 1 -> 0.95, diff 10 -> 0.40
	var easy: float = mg._difficulty_to_hit_chance(1)
	var hard: float = mg._difficulty_to_hit_chance(10)
	if absf(easy - 0.95) > 0.001:
		push_error("Difficulty 1 hit chance should be ~0.95, got %f" % easy)
		return false
	if absf(hard - 0.40) > 0.001:
		push_error("Difficulty 10 hit chance should be ~0.40, got %f" % hard)
		return false
	if easy <= hard:
		push_error("Easy difficulty should have higher hit chance than hard")
		return false
	return true


func test_minigame_difficulty_clamped() -> bool:
	var mg: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(42)
	mg.set_rng(rng)
	# Difficulty out of range should be clamped
	var result_low: Dictionary = mg.run("esprit", -5)
	var result_high: Dictionary = mg.run("esprit", 99)
	# Should not crash — that is the test
	if not result_low.has("score") or not result_high.has("score"):
		push_error("Extreme difficulty values should still produce valid results")
		return false
	return true


func test_minigame_bonus_modifier_applied() -> bool:
	var mg: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(100)
	mg.set_rng(rng)
	var result_no_bonus: Dictionary = mg.run("esprit", 5)
	rng.set_seed(100)
	var result_with_bonus: Dictionary = mg.run("esprit", 5, {"bonus": 0.5})
	var score_no: int = int(result_no_bonus.get("score", 0))
	var score_yes: int = int(result_with_bonus.get("score", 0))
	# Bonus of 0.5 should add 50 to score (capped at 100)
	var expected: int = mini(score_no + 50, 100)
	if score_yes != expected:
		push_error("Bonus modifier should add to score: expected %d, got %d" % [expected, score_yes])
		return false
	return true


func test_minigame_time_ms_in_range() -> bool:
	var mg: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	var rng: MerlinRng = MerlinRng.new()
	mg.set_rng(rng)
	for seed_val in range(1, 20):
		rng.set_seed(seed_val)
		var result: Dictionary = mg.run("chance", 5)
		var time_ms: int = int(result.get("time_ms", 0))
		# Allowing some variance: 4000 to 18000 ms
		if time_ms < 3000 or time_ms > 20000:
			push_error("Time_ms out of expected range: %d" % time_ms)
			return false
	return true


func test_minigame_unknown_field_uses_generic() -> bool:
	var mg: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(42)
	mg.set_rng(rng)
	var result: Dictionary = mg.run("unknown_field", 5)
	if not result.has("score"):
		push_error("Unknown field should still produce a score via generic fallback")
		return false
	return true


func test_minigame_deterministic_with_same_seed() -> bool:
	var mg: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	var rng: MerlinRng = MerlinRng.new()
	mg.set_rng(rng)
	rng.set_seed(12345)
	var result1: Dictionary = mg.run("logique", 7)
	rng.set_seed(12345)
	var result2: Dictionary = mg.run("logique", 7)
	if int(result1.get("score", -1)) != int(result2.get("score", -2)):
		push_error("Same seed should produce same score")
		return false
	return true


func test_minigame_all_fields_produce_results() -> bool:
	var mg: MerlinMiniGameSystem = MerlinMiniGameSystem.new()
	var rng: MerlinRng = MerlinRng.new()
	rng.set_seed(42)
	mg.set_rng(rng)
	for field in MerlinMiniGameSystem.VALID_FIELDS:
		var result: Dictionary = mg.run(field, 5)
		if result.is_empty():
			push_error("Field '%s' produced empty result" % field)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 5. REPUTATION SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════


func test_rep_factions_count() -> bool:
	if MerlinReputationSystem.FACTIONS.size() != 5:
		push_error("Expected 5 factions, got %d" % MerlinReputationSystem.FACTIONS.size())
		return false
	return true


func test_rep_faction_names() -> bool:
	var expected: Array = ["druides", "anciens", "korrigans", "niamh", "ankou"]
	for f in expected:
		if not MerlinReputationSystem.FACTIONS.has(f):
			push_error("Missing faction: %s" % f)
			return false
	return true


func test_rep_is_valid_faction() -> bool:
	if not MerlinReputationSystem.is_valid_faction("druides"):
		push_error("druides should be valid")
		return false
	if MerlinReputationSystem.is_valid_faction("orcs"):
		push_error("orcs should not be valid")
		return false
	return true


func test_rep_build_default_factions() -> bool:
	var defaults: Dictionary = MerlinReputationSystem.build_default_factions()
	if defaults.size() != 5:
		push_error("Default factions should have 5 entries")
		return false
	var expected: float = float(MerlinConstants.FACTION_SCORE_START)
	for f in MerlinReputationSystem.FACTIONS:
		if float(defaults.get(f, -1.0)) != expected:
			push_error("Default faction value should be %s for %s" % [str(expected), f])
			return false
	return true


func test_rep_initial_state_all_at_start() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	var expected: float = float(MerlinConstants.FACTION_SCORE_START)
	for f in MerlinReputationSystem.FACTIONS:
		if rs.get_reputation(f) != expected:
			push_error("Initial reputation for %s should be %s" % [f, str(expected)])
			return false
	return true


func test_rep_add_reputation_basic() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	var new_val: float = rs.add_reputation("druides", 15.0)
	if absf(new_val - 15.0) > 0.001:
		push_error("After adding 15, rep should be 15.0, got %f" % new_val)
		return false
	return true


func test_rep_add_reputation_capped_per_card() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	# CAP_PER_CARD = 20 — adding 30 should cap to 20
	var new_val: float = rs.add_reputation("korrigans", 30.0)
	if absf(new_val - 20.0) > 0.001:
		push_error("Adding 30 should be capped to 20, got %f" % new_val)
		return false
	return true


func test_rep_add_reputation_negative_cap() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	rs.add_reputation("ankou", 50.0)  # First set to some value (capped to 20)
	# Now try negative beyond cap
	var new_val: float = rs.add_reputation("ankou", -30.0)
	# -30 capped to -20, so 20 - 20 = 0
	if absf(new_val - 0.0) > 0.001:
		push_error("Negative cap should work: expected 0.0, got %f" % new_val)
		return false
	return true


func test_rep_add_reputation_clamped_to_0() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	# Start at 0, subtract
	var new_val: float = rs.add_reputation("niamh", -10.0)
	if new_val < 0.0:
		push_error("Reputation should not go below 0, got %f" % new_val)
		return false
	return true


func test_rep_add_reputation_clamped_to_100() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	# Add multiple times to approach 100
	for i in range(6):
		rs.add_reputation("druides", 20.0)
	var val: float = rs.get_reputation("druides")
	if val > 100.0:
		push_error("Reputation should not exceed 100, got %f" % val)
		return false
	if absf(val - 100.0) > 0.001:
		push_error("After 6x20, rep should be 100.0, got %f" % val)
		return false
	return true


func test_rep_add_reputation_invalid_faction() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	var result: float = rs.add_reputation("invalid", 10.0)
	if result != -1.0:
		push_error("Invalid faction should return -1.0, got %f" % result)
		return false
	return true


func test_rep_get_reputation_invalid() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	if rs.get_reputation("invalid") != 0.0:
		push_error("Invalid faction get should return 0.0")
		return false
	return true


func test_rep_get_all_reputations() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	rs.add_reputation("druides", 10.0)
	var all: Dictionary = rs.get_all_reputations()
	if all.size() != 5:
		push_error("get_all_reputations should have 5 entries")
		return false
	if absf(float(all.get("druides", 0.0)) - 10.0) > 0.001:
		push_error("Druides should be 10.0 in all reputations")
		return false
	return true


func test_rep_has_content_threshold() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	# Need 50+ for content threshold, add 3x20=60
	rs.add_reputation("anciens", 20.0)
	rs.add_reputation("anciens", 20.0)
	rs.add_reputation("anciens", 20.0)
	if not rs.has_content_threshold("anciens"):
		push_error("60 rep should meet content threshold (50)")
		return false
	return true


func test_rep_not_content_threshold() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	rs.add_reputation("anciens", 20.0)
	if rs.has_content_threshold("anciens"):
		push_error("20 rep should NOT meet content threshold (50)")
		return false
	return true


func test_rep_has_ending_threshold() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	for i in range(4):
		rs.add_reputation("niamh", 20.0)
	if not rs.has_ending_threshold("niamh"):
		push_error("80 rep should meet ending threshold")
		return false
	return true


func test_rep_not_ending_threshold() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	for i in range(3):
		rs.add_reputation("niamh", 20.0)
	if rs.has_ending_threshold("niamh"):
		push_error("60 rep should NOT meet ending threshold (80)")
		return false
	return true


func test_rep_get_dominant_faction() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	rs.add_reputation("korrigans", 20.0)
	rs.add_reputation("druides", 10.0)
	if rs.get_dominant() != "korrigans":
		push_error("Korrigans (20) should be dominant over druides (10)")
		return false
	return true


func test_rep_get_dominant_empty() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	if rs.get_dominant() != "":
		push_error("All-zero factions should return empty dominant")
		return false
	return true


func test_rep_apply_delta_immutable() -> bool:
	var factions: Dictionary = MerlinReputationSystem.build_default_factions()
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "druides", 15.0)
	# Original should be unchanged
	if float(factions.get("druides", -1.0)) != 0.0:
		push_error("apply_delta should not mutate original")
		return false
	if absf(float(result.get("druides", 0.0)) - 15.0) > 0.001:
		push_error("Result should have druides at 15.0")
		return false
	return true


func test_rep_apply_delta_clamped() -> bool:
	var factions: Dictionary = MerlinReputationSystem.build_default_factions()
	var result: Dictionary = MerlinReputationSystem.apply_delta(factions, "ankou", -10.0)
	if float(result.get("ankou", -1.0)) < 0.0:
		push_error("apply_delta should clamp to 0.0")
		return false
	var result2: Dictionary = MerlinReputationSystem.apply_delta(factions, "ankou", 200.0)
	if float(result2.get("ankou", -1.0)) > 100.0:
		push_error("apply_delta should clamp to 100.0")
		return false
	return true


func test_rep_get_available_endings() -> bool:
	var factions: Dictionary = {"druides": 85.0, "anciens": 40.0, "korrigans": 80.0, "niamh": 10.0, "ankou": 0.0}
	var endings: Array[String] = MerlinReputationSystem.get_available_endings(factions)
	if endings.size() != 2:
		push_error("Expected 2 available endings (druides 85, korrigans 80), got %d" % endings.size())
		return false
	if not endings.has("druides") or not endings.has("korrigans"):
		push_error("Available endings should include druides and korrigans")
		return false
	return true


func test_rep_get_unlocked_content() -> bool:
	var factions: Dictionary = {"druides": 55.0, "anciens": 40.0, "korrigans": 50.0, "niamh": 10.0, "ankou": 0.0}
	var content: Array[String] = MerlinReputationSystem.get_unlocked_content(factions)
	if content.size() != 2:
		push_error("Expected 2 unlocked content (druides 55, korrigans 50), got %d" % content.size())
		return false
	return true


func test_rep_get_dominant_faction_static() -> bool:
	var factions: Dictionary = {"druides": 10.0, "anciens": 50.0, "korrigans": 30.0, "niamh": 20.0, "ankou": 5.0}
	var dominant: String = MerlinReputationSystem.get_dominant_faction(factions)
	if dominant != "anciens":
		push_error("Dominant should be anciens (50), got %s" % dominant)
		return false
	return true


func test_rep_describe_factions() -> bool:
	var factions: Dictionary = {"druides": 10.0, "anciens": 50.0, "korrigans": 0.0, "niamh": 100.0, "ankou": 5.0}
	var desc: String = MerlinReputationSystem.describe_factions(factions)
	if desc.is_empty():
		push_error("describe_factions should not be empty")
		return false
	if not desc.contains("Niamh:100"):
		push_error("Description should contain 'Niamh:100'")
		return false
	return true


func test_rep_get_tier_label_hostile() -> bool:
	if MerlinReputationSystem.get_tier_label(0.0) != "Hostile":
		push_error("0 rep should be 'Hostile'")
		return false
	return true


func test_rep_get_tier_label_mefiant() -> bool:
	if MerlinReputationSystem.get_tier_label(5.0) != "Mefiant":
		push_error("5 rep should be 'Mefiant'")
		return false
	return true


func test_rep_get_tier_label_neutre() -> bool:
	if MerlinReputationSystem.get_tier_label(20.0) != "Neutre":
		push_error("20 rep should be 'Neutre'")
		return false
	return true


func test_rep_get_tier_label_sympathisant() -> bool:
	if MerlinReputationSystem.get_tier_label(50.0) != "Sympathisant":
		push_error("50 rep should be 'Sympathisant'")
		return false
	return true


func test_rep_get_tier_label_honore() -> bool:
	if MerlinReputationSystem.get_tier_label(80.0) != "Honore":
		push_error("80 rep should be 'Honore'")
		return false
	if MerlinReputationSystem.get_tier_label(100.0) != "Honore":
		push_error("100 rep should be 'Honore'")
		return false
	return true


func test_rep_reset() -> bool:
	var rs: MerlinReputationSystem = MerlinReputationSystem.new()
	rs.add_reputation("druides", 20.0)
	rs.reset()
	if rs.get_reputation("druides") != 0.0:
		push_error("After reset, rep should be 0.0")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 6. ACTION RESOLVER
# ═══════════════════════════════════════════════════════════════════════════════


func test_action_resolve_returns_required_keys() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var result: Dictionary = ar.resolve("FORCE", "attack", {"state": {}})
	var required: Array = ["verb", "subchoice", "score", "chance", "risk", "hidden_test"]
	for key in required:
		if not result.has(key):
			push_error("Resolve result missing key: %s" % key)
			return false
	return true


func test_action_resolve_verb_preserved() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var result: Dictionary = ar.resolve("LOGIQUE", "think", {"state": {}})
	if str(result.get("verb", "")) != "LOGIQUE":
		push_error("Verb should be preserved in result")
		return false
	if str(result.get("subchoice", "")) != "think":
		push_error("Subchoice should be preserved in result")
		return false
	return true


func test_action_attr_for_verb_force() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	if ar._attr_for_verb("FORCE") != "power":
		push_error("FORCE should map to 'power'")
		return false
	return true


func test_action_attr_for_verb_logique() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	if ar._attr_for_verb("LOGIQUE") != "spirit":
		push_error("LOGIQUE should map to 'spirit'")
		return false
	return true


func test_action_attr_for_verb_finesse() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	if ar._attr_for_verb("FINESSE") != "finesse":
		push_error("FINESSE should map to 'finesse'")
		return false
	return true


func test_action_attr_for_verb_unknown_defaults_power() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	if ar._attr_for_verb("UNKNOWN") != "power":
		push_error("Unknown verb should default to 'power'")
		return false
	return true


func test_action_chance_from_score_low() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	if ar._chance_from_score(10) != "Low":
		push_error("Score 10 should be Low chance")
		return false
	if ar._chance_from_score(34) != "Low":
		push_error("Score 34 should be Low chance")
		return false
	return true


func test_action_chance_from_score_medium() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	if ar._chance_from_score(35) != "Medium":
		push_error("Score 35 should be Medium chance")
		return false
	if ar._chance_from_score(64) != "Medium":
		push_error("Score 64 should be Medium chance")
		return false
	return true


func test_action_chance_from_score_high() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	if ar._chance_from_score(65) != "High":
		push_error("Score 65 should be High chance")
		return false
	if ar._chance_from_score(100) != "High":
		push_error("Score 100 should be High chance")
		return false
	return true


func test_action_risk_from_score_severe() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	if ar._risk_from_score(10) != "Severe":
		push_error("Score 10 should be Severe risk")
		return false
	return true


func test_action_risk_from_score_moderate() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	if ar._risk_from_score(50) != "Moderate":
		push_error("Score 50 should be Moderate risk")
		return false
	return true


func test_action_risk_from_score_light() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	if ar._risk_from_score(65) != "Light":
		push_error("Score 65 should be Light risk")
		return false
	return true


func test_action_score_clamped_0_100() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var result: Dictionary = ar.resolve("FORCE", "x", {"state": {}, "bonus": 200})
	var score: int = int(result.get("score", -1))
	if score < 0 or score > 100:
		push_error("Score should be clamped to [0,100], got %d" % score)
		return false
	return true


func test_action_posture_modifier_prudence() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var ctx: Dictionary = {"state": {"run": {"posture": "Prudence"}}}
	var result: Dictionary = ar.resolve("LOGIQUE", "x", ctx)
	# Prudence adds LOGIQUE: +2, base_attr=10, total should be 12
	var score: int = int(result.get("score", 0))
	if score != 12:
		push_error("Prudence + LOGIQUE should give score 12, got %d" % score)
		return false
	return true


func test_action_posture_modifier_agressif() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var ctx: Dictionary = {"state": {"run": {"posture": "Agressif"}}}
	var result: Dictionary = ar.resolve("FORCE", "x", ctx)
	# Agressif adds FORCE: +3, base=10, total=13
	var score: int = int(result.get("score", 0))
	if score != 13:
		push_error("Agressif + FORCE should give score 13, got %d" % score)
		return false
	return true


func test_action_style_modifier() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var ctx: Dictionary = {"state": {}, "merlin_style": "aventureux"}
	var result: Dictionary = ar.resolve("FORCE", "x", ctx)
	# AVENTUREUX FORCE: +2, base=10, total=12
	var score: int = int(result.get("score", 0))
	if score != 12:
		push_error("Aventureux + FORCE should give score 12, got %d" % score)
		return false
	return true


func test_action_fail_streak_bonus() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var ctx: Dictionary = {"state": {"run": {"fail_streak": 2}}}
	var result: Dictionary = ar.resolve("FORCE", "x", ctx)
	# fail_streak 2 * 5 = +10, base=10, total=20
	var score: int = int(result.get("score", 0))
	if score != 20:
		push_error("fail_streak 2 should give score 20, got %d" % score)
		return false
	return true


func test_action_bonus_penalty_extra() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var ctx: Dictionary = {"state": {}, "bonus": 5, "penalty": 3}
	var result: Dictionary = ar.resolve("FORCE", "x", ctx)
	# extra = 5 - 3 = 2, base=10, total=12
	var score: int = int(result.get("score", 0))
	if score != 12:
		push_error("bonus 5, penalty 3 should give score 12, got %d" % score)
		return false
	return true


func test_action_hidden_test_default_types() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var force_res: Dictionary = ar.resolve("FORCE", "x", {"state": {}})
	var force_ht: Dictionary = force_res.get("hidden_test", {})
	if str(force_ht.get("type", "")) != "TIMING":
		push_error("FORCE default hidden_test type should be TIMING, got %s" % str(force_ht.get("type", "")))
		return false

	var logique_res: Dictionary = ar.resolve("LOGIQUE", "x", {"state": {}})
	var logique_ht: Dictionary = logique_res.get("hidden_test", {})
	if str(logique_ht.get("type", "")) != "MEMORY":
		push_error("LOGIQUE default hidden_test type should be MEMORY")
		return false

	var finesse_res: Dictionary = ar.resolve("FINESSE", "x", {"state": {}})
	var finesse_ht: Dictionary = finesse_res.get("hidden_test", {})
	if str(finesse_ht.get("type", "")) != "AIM":
		push_error("FINESSE default hidden_test type should be AIM")
		return false
	return true


func test_action_hidden_test_provided_override() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var ctx: Dictionary = {"state": {}, "hidden_test": {"type": "CUSTOM"}}
	var result: Dictionary = ar.resolve("FORCE", "x", ctx)
	var ht: Dictionary = result.get("hidden_test", {})
	if str(ht.get("type", "")) != "CUSTOM":
		push_error("Provided hidden_test type should override default")
		return false
	return true


func test_action_hidden_test_difficulty_range() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var result: Dictionary = ar.resolve("FORCE", "x", {"state": {}})
	var ht: Dictionary = result.get("hidden_test", {})
	var diff: int = int(ht.get("difficulty", 0))
	if diff < 1 or diff > 10:
		push_error("Hidden test difficulty should be in [1,10], got %d" % diff)
		return false
	return true


func test_action_hidden_test_difficulty_mod() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	# Without mod
	var result1: Dictionary = ar.resolve("FORCE", "x", {"state": {"run": {}}})
	var diff1: int = int(result1.get("hidden_test", {}).get("difficulty", 0))
	# With difficulty_mod_next = 3 (easier)
	var result2: Dictionary = ar.resolve("FORCE", "x", {"state": {"run": {"difficulty_mod_next": 3}}})
	var diff2: int = int(result2.get("hidden_test", {}).get("difficulty", 0))
	if diff2 >= diff1:
		push_error("difficulty_mod_next should reduce difficulty: %d >= %d" % [diff2, diff1])
		return false
	return true


func test_action_costs_and_gain_passthrough() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var ctx: Dictionary = {"state": {}, "costs": {"anam": 5}, "gain": ["item1"]}
	var result: Dictionary = ar.resolve("FORCE", "x", ctx)
	var costs: Dictionary = result.get("costs", {})
	if int(costs.get("anam", 0)) != 5:
		push_error("Costs should pass through from context")
		return false
	var gain: Array = result.get("gain", [])
	if gain.size() != 1 or str(gain[0]) != "item1":
		push_error("Gain should pass through from context")
		return false
	return true


func test_action_momentum_modifier() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var ctx: Dictionary = {"state": {"run": {"momentum": 40}}}
	var result: Dictionary = ar.resolve("FORCE", "x", ctx)
	# momentum 40 / 20.0 = +2, base=10, total=12
	var score: int = int(result.get("score", 0))
	if score != 12:
		push_error("Momentum 40 should give +2, score 12, got %d" % score)
		return false
	return true


func test_action_combined_modifiers() -> bool:
	var ar: MerlinActionResolver = MerlinActionResolver.new()
	var ctx: Dictionary = {
		"state": {
			"run": {
				"posture": "Ruse",
				"momentum": 20,
				"fail_streak": 1,
			}
		},
		"merlin_style": "sombre",
		"bonus": 2,
		"penalty": 1,
	}
	# FINESSE: base=10
	# Ruse FINESSE: +3
	# momentum 20/20 = +1
	# fail_streak 1*5 = +5
	# SOMBRE FINESSE: +2
	# extra: 2-1 = +1
	# Total: 10 + 3 + 1 + 5 + 2 + 1 = 22
	var result: Dictionary = ar.resolve("FINESSE", "sneak", ctx)
	var score: int = int(result.get("score", 0))
	if score != 22:
		push_error("Combined modifiers should give score 22, got %d" % score)
		return false
	return true
