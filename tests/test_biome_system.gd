extends RefCounted
## Unit Tests — MerlinBiomeSystem
## Tests: 8 biomes, unlock conditions, passive triggers, ogham bonus, difficulty.

const BiomeSystem = preload("res://scripts/merlin/merlin_biome_system.gd")


func _make_biome_system() -> RefCounted:
	return BiomeSystem.new()


func _make_meta(runs: int = 0, endings: Array = []) -> Dictionary:
	return {"total_runs": runs, "endings_seen": endings}


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME DATA — All 8 biomes present
# ═══════════════════════════════════════════════════════════════════════════════

func test_8_biomes_defined() -> bool:
	if BiomeSystem.BIOMES.size() != 8:
		push_error("Expected 8 biomes, got %d" % BiomeSystem.BIOMES.size())
		return false
	return true


func test_all_biomes_have_required_keys() -> bool:
	var required: Array = ["name", "theme", "color", "faction_affinity", "passive", "difficulty", "ogham_bonus"]
	for key in BiomeSystem.BIOMES:
		var biome: Dictionary = BiomeSystem.BIOMES[key]
		for req in required:
			if not biome.has(req):
				push_error("Biome '%s' missing key '%s'" % [key, req])
				return false
	return true


func test_all_biomes_have_color() -> bool:
	for key in BiomeSystem.BIOMES:
		var biome: Dictionary = BiomeSystem.BIOMES[key]
		if not biome.has("color"):
			push_error("Biome '%s' missing color" % key)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# UNLOCK CONDITIONS
# ═══════════════════════════════════════════════════════════════════════════════

func test_foret_always_unlocked() -> bool:
	var bs: RefCounted = _make_biome_system()
	if not bs.is_unlocked("foret_broceliande", _make_meta(0)):
		push_error("Foret should always be unlocked")
		return false
	return true


func test_landes_requires_2_runs() -> bool:
	var bs: RefCounted = _make_biome_system()
	if bs.is_unlocked("landes_bruyere", _make_meta(1)):
		push_error("Landes should be locked with 1 run")
		return false
	if not bs.is_unlocked("landes_bruyere", _make_meta(2)):
		push_error("Landes should be unlocked with 2 runs")
		return false
	return true


func test_cercles_requires_runs_and_endings() -> bool:
	var bs: RefCounted = _make_biome_system()
	if bs.is_unlocked("cercles_pierres", _make_meta(8, [])):
		push_error("Cercles should be locked without endings")
		return false
	if bs.is_unlocked("cercles_pierres", _make_meta(5, ["harmonie", "mort"])):
		push_error("Cercles should be locked with only 5 runs")
		return false
	if not bs.is_unlocked("cercles_pierres", _make_meta(8, ["harmonie", "mort"])):
		push_error("Cercles should be unlocked with 8 runs + 2 endings")
		return false
	return true


func test_marais_requires_specific_ending() -> bool:
	var bs: RefCounted = _make_biome_system()
	if bs.is_unlocked("marais_korrigans", _make_meta(10, ["mort"])):
		push_error("Marais should be locked without 'harmonie' ending")
		return false
	if not bs.is_unlocked("marais_korrigans", _make_meta(10, ["harmonie"])):
		push_error("Marais should be unlocked with 'harmonie' ending + 10 runs")
		return false
	return true


func test_iles_hardest_unlock() -> bool:
	var bs: RefCounted = _make_biome_system()
	# Locked: 20 runs but missing 'transcendance' ending
	if bs.is_unlocked("iles_mystiques", _make_meta(20, ["mort", "harmonie", "domination", "sacrifice", "extra"])):
		push_error("Iles should be locked without 'transcendance' ending")
		return false
	# Locked: has transcendance but not enough runs
	if bs.is_unlocked("iles_mystiques", _make_meta(10, ["mort", "harmonie", "transcendance", "domination", "sacrifice"])):
		push_error("Iles should be locked with only 10 runs")
		return false
	# Unlocked: 20 runs + 5 endings including transcendance
	if not bs.is_unlocked("iles_mystiques", _make_meta(20, ["mort", "harmonie", "transcendance", "domination", "sacrifice"])):
		push_error("Iles should be unlocked with 20 runs + 5 endings + transcendance")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PASSIVE EFFECTS — Periodic triggers
# ═══════════════════════════════════════════════════════════════════════════════

func test_passive_triggers_at_correct_interval() -> bool:
	var bs: RefCounted = _make_biome_system()
	# Foret: every_n = 5
	if bs.should_trigger_passive("foret_broceliande", 4):
		push_error("Should NOT trigger at card 4 (every 5)")
		return false
	if not bs.should_trigger_passive("foret_broceliande", 5):
		push_error("Should trigger at card 5 (every 5)")
		return false
	if not bs.should_trigger_passive("foret_broceliande", 10):
		push_error("Should trigger at card 10 (every 5)")
		return false
	return true


func test_passive_no_trigger_at_zero() -> bool:
	var bs: RefCounted = _make_biome_system()
	if bs.should_trigger_passive("foret_broceliande", 0):
		push_error("Should NOT trigger at card 0")
		return false
	return true


func test_passive_effect_returns_heal_or_damage() -> bool:
	var bs: RefCounted = _make_biome_system()
	var effect: Dictionary = bs.get_passive_effect("foret_broceliande", 5)
	if effect.is_empty():
		push_error("Passive effect should not be empty at trigger card")
		return false
	var etype: String = str(effect.get("type", ""))
	if etype != "HEAL_LIFE" and etype != "DAMAGE_LIFE":
		push_error("Passive type should be HEAL_LIFE or DAMAGE_LIFE, got %s" % etype)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# OGHAM COOLDOWN BONUS
# ═══════════════════════════════════════════════════════════════════════════════

func test_ogham_bonus_in_matching_biome() -> bool:
	var bs: RefCounted = _make_biome_system()
	# Foret: ogham_bonus includes quert
	var bonus: int = bs.get_ogham_cooldown_bonus("foret_broceliande", "quert")
	if bonus <= 0:
		push_error("quert should have cooldown bonus in foret, got %d" % bonus)
		return false
	return true


func test_ogham_no_bonus_wrong_biome() -> bool:
	var bs: RefCounted = _make_biome_system()
	var bonus: int = bs.get_ogham_cooldown_bonus("foret_broceliande", "ioho")
	if bonus != 0:
		push_error("ioho should have no bonus in foret, got %d" % bonus)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DIFFICULTY
# ═══════════════════════════════════════════════════════════════════════════════

func test_foret_difficulty_zero() -> bool:
	var bs: RefCounted = _make_biome_system()
	var d: int = bs.get_difficulty_modifier("foret_broceliande")
	if d != 0:
		push_error("Foret difficulty should be 0, got %d" % d)
		return false
	return true


func test_iles_highest_difficulty() -> bool:
	var bs: RefCounted = _make_biome_system()
	var d: int = bs.get_difficulty_modifier("iles_mystiques")
	if d < 2:
		push_error("Iles should have highest difficulty (>=2), got %d" % d)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# LLM CONTEXT
# ═══════════════════════════════════════════════════════════════════════════════

func test_biome_context_not_empty() -> bool:
	var bs: RefCounted = _make_biome_system()
	for key in BiomeSystem.BIOMES:
		var ctx: String = bs.get_biome_context_for_llm(key)
		if ctx.is_empty():
			push_error("LLM context empty for biome '%s'" % key)
			return false
	return true


func test_unknown_biome_returns_empty_context() -> bool:
	var bs: RefCounted = _make_biome_system()
	var ctx: String = bs.get_biome_context_for_llm("nonexistent_biome")
	if not ctx.is_empty():
		push_error("Unknown biome should return empty context")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SEASON
# ═══════════════════════════════════════════════════════════════════════════════

func test_foret_favors_spring() -> bool:
	var bs: RefCounted = _make_biome_system()
	if not bs.is_in_favored_season("foret_broceliande", "spring"):
		push_error("Foret should favor spring")
		return false
	if bs.is_in_favored_season("foret_broceliande", "winter"):
		push_error("Foret should not favor winter")
		return false
	return true


func test_unlock_hint_format() -> bool:
	var bs: RefCounted = _make_biome_system()
	var hint: String = bs.get_unlock_hint("marais_korrigans")
	if hint.is_empty():
		push_error("Marais should have unlock hint")
		return false
	if not hint.begins_with("Requiert:"):
		push_error("Hint should start with 'Requiert:', got '%s'" % hint)
		return false
	return true
