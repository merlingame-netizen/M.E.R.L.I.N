## =============================================================================
## Unit Tests — MerlinBiomeSystem
## =============================================================================
## Tests: biome access, faction affinity, passive effects, ogham bonuses,
## difficulty, season affinity, unlock conditions, LLM context, tuning, edges.
## Pattern: extends RefCounted, methods return false on failure.
## =============================================================================

extends RefCounted


func _make_system() -> MerlinBiomeSystem:
	var sys: MerlinBiomeSystem = MerlinBiomeSystem.new()
	return sys


func _make_meta(overrides: Dictionary = {}) -> Dictionary:
	var meta: Dictionary = {
		"total_runs": 0,
		"endings_seen": [],
	}
	for key in overrides:
		meta[key] = overrides[key]
	return meta


# =============================================================================
# BIOME ACCESS — get_biome, get_all_biome_keys, get_biome_name, get_biome_color
# =============================================================================

func test_get_biome_returns_valid_dict() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var biome: Dictionary = sys.get_biome("foret_broceliande")
	if biome.is_empty():
		push_error("get_biome: foret_broceliande should not be empty")
		return false
	if str(biome.get("name", "")) != "Foret de Broceliande":
		push_error("get_biome: name mismatch, got '%s'" % str(biome.get("name", "")))
		return false
	return true


func test_get_biome_unknown_returns_empty() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var biome: Dictionary = sys.get_biome("nonexistent_biome")
	if not biome.is_empty():
		push_error("get_biome: unknown key should return empty dict")
		return false
	return true


func test_get_all_biome_keys_returns_8() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var keys: Array = sys.get_all_biome_keys()
	if keys.size() != 8:
		push_error("get_all_biome_keys: expected 8, got %d" % keys.size())
		return false
	if not "foret_broceliande" in keys:
		push_error("get_all_biome_keys: missing foret_broceliande")
		return false
	if not "iles_mystiques" in keys:
		push_error("get_all_biome_keys: missing iles_mystiques")
		return false
	return true


func test_get_biome_name_valid() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var name: String = sys.get_biome_name("cotes_sauvages")
	if name != "Cotes Sauvages":
		push_error("get_biome_name: expected 'Cotes Sauvages', got '%s'" % name)
		return false
	return true


func test_get_biome_name_unknown_returns_key() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var name: String = sys.get_biome_name("unknown_biome")
	if name != "unknown_biome":
		push_error("get_biome_name: unknown should return key, got '%s'" % name)
		return false
	return true


func test_get_biome_color_valid() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var color: Color = sys.get_biome_color("foret_broceliande")
	# Expected Color(0.30, 0.50, 0.28)
	if absf(color.r - 0.30) > 0.01 or absf(color.g - 0.50) > 0.01 or absf(color.b - 0.28) > 0.01:
		push_error("get_biome_color: foret_broceliande color mismatch: %s" % str(color))
		return false
	return true


func test_get_biome_color_unknown_returns_white() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var color: Color = sys.get_biome_color("unknown_biome")
	if color != Color.WHITE:
		push_error("get_biome_color: unknown should return WHITE, got %s" % str(color))
		return false
	return true


# =============================================================================
# FACTION AFFINITY
# =============================================================================

func test_faction_affinity_foret() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var aff: Dictionary = sys.get_faction_affinity("foret_broceliande")
	if not aff.has("korrigans"):
		push_error("faction_affinity: foret should have korrigans key")
		return false
	if absf(float(aff["korrigans"]) - 1.2) > 0.01:
		push_error("faction_affinity: foret korrigans should be 1.2, got %f" % float(aff["korrigans"]))
		return false
	if absf(float(aff["anciens"]) - 0.8) > 0.01:
		push_error("faction_affinity: foret anciens should be 0.8, got %f" % float(aff["anciens"]))
		return false
	return true


func test_faction_affinity_unknown_returns_default() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var aff: Dictionary = sys.get_faction_affinity("unknown_biome")
	# Default: all 1.0
	if not aff.has("korrigans") or not aff.has("druides") or not aff.has("anciens"):
		push_error("faction_affinity: unknown should return default with 3 factions")
		return false
	if absf(float(aff["korrigans"]) - 1.0) > 0.01:
		push_error("faction_affinity: default korrigans should be 1.0")
		return false
	return true


# =============================================================================
# PASSIVE EFFECTS — should_trigger_passive, get_passive_effect
# =============================================================================

func test_passive_triggers_at_correct_interval() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# foret_broceliande: every_n = 5
	if sys.should_trigger_passive("foret_broceliande", 5) != true:
		push_error("passive: should trigger at 5 cards for foret (every_n=5)")
		return false
	if sys.should_trigger_passive("foret_broceliande", 10) != true:
		push_error("passive: should trigger at 10 cards for foret (every_n=5)")
		return false
	if sys.should_trigger_passive("foret_broceliande", 3) != false:
		push_error("passive: should NOT trigger at 3 cards for foret (every_n=5)")
		return false
	return true


func test_passive_no_trigger_at_zero() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	if sys.should_trigger_passive("foret_broceliande", 0) != false:
		push_error("passive: should NOT trigger at 0 cards")
		return false
	return true


func test_passive_no_trigger_unknown_biome() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# Unknown biome: every_n defaults to 0
	if sys.should_trigger_passive("unknown_biome", 5) != false:
		push_error("passive: should NOT trigger for unknown biome")
		return false
	return true


func test_passive_effect_heal_for_up_direction() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# foret_broceliande: direction = "up" → HEAL_LIFE
	var effect: Dictionary = sys.get_passive_effect("foret_broceliande", 5)
	if effect.is_empty():
		push_error("passive_effect: foret at 5 should return effect")
		return false
	if str(effect.get("type", "")) != "HEAL_LIFE":
		push_error("passive_effect: foret direction=up should be HEAL_LIFE, got '%s'" % str(effect.get("type", "")))
		return false
	if int(effect.get("amount", 0)) != 5:
		push_error("passive_effect: amount should be 5, got %d" % int(effect.get("amount", 0)))
		return false
	return true


func test_passive_effect_damage_for_down_direction() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# landes_bruyere: direction = "down" → DAMAGE_LIFE, every_n = 6
	var effect: Dictionary = sys.get_passive_effect("landes_bruyere", 6)
	if effect.is_empty():
		push_error("passive_effect: landes at 6 should return effect")
		return false
	if str(effect.get("type", "")) != "DAMAGE_LIFE":
		push_error("passive_effect: landes direction=down should be DAMAGE_LIFE, got '%s'" % str(effect.get("type", "")))
		return false
	return true


func test_passive_effect_empty_when_not_triggered() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var effect: Dictionary = sys.get_passive_effect("foret_broceliande", 3)
	if not effect.is_empty():
		push_error("passive_effect: should return empty when not triggered")
		return false
	return true


func test_passive_effect_random_direction_deterministic() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# collines_dolmens: direction = "random", every_n = 7
	var effect: Dictionary = sys.get_passive_effect("collines_dolmens", 7)
	if effect.is_empty():
		push_error("passive_effect: collines at 7 should return effect")
		return false
	var effect_type: String = str(effect.get("type", ""))
	if effect_type != "HEAL_LIFE" and effect_type != "DAMAGE_LIFE":
		push_error("passive_effect: random direction should produce HEAL or DAMAGE, got '%s'" % effect_type)
		return false
	# Same inputs should produce same output (deterministic hash)
	var effect2: Dictionary = sys.get_passive_effect("collines_dolmens", 7)
	if str(effect2.get("type", "")) != effect_type:
		push_error("passive_effect: random direction should be deterministic for same inputs")
		return false
	return true


# =============================================================================
# OGHAM COOLDOWN BONUS
# =============================================================================

func test_ogham_bonus_in_list() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# foret_broceliande: ogham_bonus = ["quert", "huath", "coll"], reduction = 1
	var bonus: int = sys.get_ogham_cooldown_bonus("foret_broceliande", "quert")
	if bonus != 1:
		push_error("ogham_bonus: quert in foret should be 1, got %d" % bonus)
		return false
	return true


func test_ogham_bonus_not_in_list() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var bonus: int = sys.get_ogham_cooldown_bonus("foret_broceliande", "beith")
	if bonus != 0:
		push_error("ogham_bonus: beith NOT in foret list, should be 0, got %d" % bonus)
		return false
	return true


func test_ogham_bonus_cercles_pierres_double_reduction() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# cercles_pierres: ogham_cooldown_reduction = 2
	var bonus: int = sys.get_ogham_cooldown_bonus("cercles_pierres", "ioho")
	if bonus != 2:
		push_error("ogham_bonus: ioho in cercles_pierres should be 2, got %d" % bonus)
		return false
	return true


func test_ogham_bonus_unknown_biome() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var bonus: int = sys.get_ogham_cooldown_bonus("unknown_biome", "quert")
	if bonus != 0:
		push_error("ogham_bonus: unknown biome should return 0, got %d" % bonus)
		return false
	return true


# =============================================================================
# DIFFICULTY MODIFIER
# =============================================================================

func test_difficulty_foret_zero() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var diff: int = sys.get_difficulty_modifier("foret_broceliande")
	if diff != 0:
		push_error("difficulty: foret should be 0, got %d" % diff)
		return false
	return true


func test_difficulty_iles_mystiques_three() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var diff: int = sys.get_difficulty_modifier("iles_mystiques")
	if diff != 3:
		push_error("difficulty: iles_mystiques should be 3, got %d" % diff)
		return false
	return true


func test_difficulty_villages_minus_one() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var diff: int = sys.get_difficulty_modifier("villages_celtes")
	if diff != -1:
		push_error("difficulty: villages_celtes should be -1, got %d" % diff)
		return false
	return true


func test_difficulty_unknown_biome_zero() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var diff: int = sys.get_difficulty_modifier("unknown_biome")
	if diff != 0:
		push_error("difficulty: unknown biome should default to 0, got %d" % diff)
		return false
	return true


# =============================================================================
# SEASON AFFINITY
# =============================================================================

func test_favored_season_foret() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var season: String = sys.get_favored_season("foret_broceliande")
	if season != "spring":
		push_error("favored_season: foret should be 'spring', got '%s'" % season)
		return false
	return true


func test_is_in_favored_season_true() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	if sys.is_in_favored_season("foret_broceliande", "spring") != true:
		push_error("is_in_favored_season: foret + spring should be true")
		return false
	return true


func test_is_in_favored_season_false() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	if sys.is_in_favored_season("foret_broceliande", "winter") != false:
		push_error("is_in_favored_season: foret + winter should be false")
		return false
	return true


func test_favored_season_unknown_biome_empty() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var season: String = sys.get_favored_season("unknown_biome")
	if season != "":
		push_error("favored_season: unknown biome should be empty, got '%s'" % season)
		return false
	return true


# =============================================================================
# UNLOCK CONDITIONS
# =============================================================================

func test_unlock_foret_always_unlocked() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# foret_broceliande: unlock = null → always available
	if sys.is_unlocked("foret_broceliande", _make_meta()) != true:
		push_error("unlock: foret should always be unlocked")
		return false
	return true


func test_unlock_landes_needs_2_runs() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# landes_bruyere: min_runs = 2
	if sys.is_unlocked("landes_bruyere", _make_meta({"total_runs": 1})) != false:
		push_error("unlock: landes should be locked with 1 run")
		return false
	if sys.is_unlocked("landes_bruyere", _make_meta({"total_runs": 2})) != true:
		push_error("unlock: landes should be unlocked with 2 runs")
		return false
	return true


func test_unlock_cercles_needs_runs_and_endings() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# cercles_pierres: min_runs = 8, min_endings = 2
	if sys.is_unlocked("cercles_pierres", _make_meta({"total_runs": 8, "endings_seen": ["a"]})) != false:
		push_error("unlock: cercles should be locked with only 1 ending")
		return false
	if sys.is_unlocked("cercles_pierres", _make_meta({"total_runs": 8, "endings_seen": ["a", "b"]})) != true:
		push_error("unlock: cercles should be unlocked with 8 runs and 2 endings")
		return false
	return true


func test_unlock_marais_needs_required_ending() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# marais_korrigans: min_runs = 10, required_ending = "harmonie"
	var meta_no_ending: Dictionary = _make_meta({"total_runs": 10, "endings_seen": ["other"]})
	if sys.is_unlocked("marais_korrigans", meta_no_ending) != false:
		push_error("unlock: marais should be locked without 'harmonie' ending")
		return false
	var meta_with_ending: Dictionary = _make_meta({"total_runs": 10, "endings_seen": ["harmonie"]})
	if sys.is_unlocked("marais_korrigans", meta_with_ending) != true:
		push_error("unlock: marais should be unlocked with 'harmonie' ending and 10 runs")
		return false
	return true


func test_unlock_iles_full_requirements() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# iles_mystiques: min_runs = 20, min_endings = 5, required_ending = "transcendance"
	var partial: Dictionary = _make_meta({
		"total_runs": 20,
		"endings_seen": ["a", "b", "c", "d", "transcendance"],
	})
	if sys.is_unlocked("iles_mystiques", partial) != true:
		push_error("unlock: iles should be unlocked with 20 runs, 5 endings incl. transcendance")
		return false
	var missing_runs: Dictionary = _make_meta({
		"total_runs": 19,
		"endings_seen": ["a", "b", "c", "d", "transcendance"],
	})
	if sys.is_unlocked("iles_mystiques", missing_runs) != false:
		push_error("unlock: iles should be locked with only 19 runs")
		return false
	return true


func test_unlock_unknown_biome_always_true() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	# Unknown biome: empty dict → unlock = null → true
	if sys.is_unlocked("unknown_biome", _make_meta()) != true:
		push_error("unlock: unknown biome should default to unlocked")
		return false
	return true


# =============================================================================
# UNLOCK HINT
# =============================================================================

func test_unlock_hint_foret_empty() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var hint: String = sys.get_unlock_hint("foret_broceliande")
	if hint != "":
		push_error("unlock_hint: foret should be empty, got '%s'" % hint)
		return false
	return true


func test_unlock_hint_marais_contains_ending() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var hint: String = sys.get_unlock_hint("marais_korrigans")
	if hint.is_empty():
		push_error("unlock_hint: marais should not be empty")
		return false
	if hint.find("harmonie") == -1:
		push_error("unlock_hint: marais should mention 'harmonie', got '%s'" % hint)
		return false
	if hint.find("10 runs") == -1:
		push_error("unlock_hint: marais should mention '10 runs', got '%s'" % hint)
		return false
	return true


# =============================================================================
# LLM CONTEXT
# =============================================================================

func test_llm_context_contains_biome_name() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var ctx: String = sys.get_biome_context_for_llm("foret_broceliande")
	if ctx.is_empty():
		push_error("llm_context: foret should not be empty")
		return false
	if ctx.find("Foret de Broceliande") == -1:
		push_error("llm_context: should contain biome name, got '%s'" % ctx)
		return false
	return true


func test_llm_context_contains_theme_and_atmosphere() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var ctx: String = sys.get_biome_context_for_llm("foret_broceliande")
	if ctx.find("Theme:") == -1:
		push_error("llm_context: should contain 'Theme:'")
		return false
	if ctx.find("Ambiance:") == -1:
		push_error("llm_context: should contain 'Ambiance:'")
		return false
	if ctx.find("Creatures:") == -1:
		push_error("llm_context: should contain 'Creatures:'")
		return false
	return true


func test_llm_context_unknown_biome_empty() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var ctx: String = sys.get_biome_context_for_llm("unknown_biome")
	if not ctx.is_empty():
		push_error("llm_context: unknown biome should return empty, got '%s'" % ctx)
		return false
	return true


# =============================================================================
# TUNING — get_tuning (no tuning file loaded)
# =============================================================================

func test_tuning_nonexistent_section_returns_null() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var val: Variant = sys.get_tuning("nonexistent_section_xyz")
	if val != null:
		push_error("get_tuning: nonexistent section should return null, got %s" % str(val))
		return false
	return true


func test_tuning_nonexistent_key_returns_null() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var val: Variant = sys.get_tuning("biomes", "nonexistent_biome_xyz")
	if val != null:
		push_error("get_tuning: nonexistent key should return null, got %s" % str(val))
		return false
	return true


# =============================================================================
# EDGE CASES
# =============================================================================

func test_all_8_biomes_have_required_keys() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	var required_keys: Array = ["name", "theme", "color", "faction_affinity", "passive",
		"difficulty", "ogham_bonus", "ogham_cooldown_reduction", "favored_season"]
	var keys: Array = sys.get_all_biome_keys()
	for biome_key in keys:
		var biome: Dictionary = sys.get_biome(str(biome_key))
		for rk in required_keys:
			if not biome.has(str(rk)):
				push_error("biome '%s' missing required key '%s'" % [str(biome_key), str(rk)])
				return false
	return true


func test_passive_negative_cards_no_trigger() -> bool:
	var sys: MerlinBiomeSystem = _make_system()
	if sys.should_trigger_passive("foret_broceliande", -1) != false:
		push_error("passive: negative cards_played should not trigger")
		return false
	return true
