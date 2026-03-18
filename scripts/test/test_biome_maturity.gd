## =============================================================================
## Unit Tests — Biome Maturity Scoring System (headless-safe, RefCounted)
## =============================================================================
## Covers: score formula (runs*2 + fins*5 + oghams*3 + max_rep*1),
##         initial state, all 8 biomes, unlock conditions, increments, edge cases.
## Converted from GutTest to RefCounted for headless runner compatibility.
## =============================================================================

extends RefCounted


func _fail(msg: String) -> bool:
	push_error(msg)
	return false


func _make_meta(total_runs: int = 0, fins_vues: int = 0, oghams_debloques: int = 0, max_faction_rep: float = 0.0, endings_seen: Array = []) -> Dictionary:
	return {"total_runs": total_runs, "fins_vues": fins_vues, "oghams_debloques": oghams_debloques, "max_faction_rep": max_faction_rep, "endings_seen": endings_seen}


func _compute_maturity(meta: Dictionary) -> float:
	var w: Dictionary = MerlinConstants.MATURITY_WEIGHTS
	return float(meta.get("total_runs", 0)) * float(w.get("total_runs", 2)) + float(meta.get("fins_vues", 0)) * float(w.get("fins_vues", 5)) + float(meta.get("oghams_debloques", 0)) * float(w.get("oghams_debloques", 3)) + float(meta.get("max_faction_rep", 0.0)) * float(w.get("max_faction_rep", 1))


# ═══════════════════════════════════════════════════════════════════════════════
# MATURITY WEIGHTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_maturity_weights_exist() -> bool:
	for key in ["total_runs", "fins_vues", "oghams_debloques", "max_faction_rep"]:
		if not MerlinConstants.MATURITY_WEIGHTS.has(key):
			return _fail("MATURITY_WEIGHTS missing: %s" % key)
	return true

func test_maturity_weights_values() -> bool:
	var w: Dictionary = MerlinConstants.MATURITY_WEIGHTS
	if int(w["total_runs"]) != 2: return _fail("runs weight should be 2")
	if int(w["fins_vues"]) != 5: return _fail("fins weight should be 5")
	if int(w["oghams_debloques"]) != 3: return _fail("oghams weight should be 3")
	if int(w["max_faction_rep"]) != 1: return _fail("rep weight should be 1")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# INITIAL STATE
# ═══════════════════════════════════════════════════════════════════════════════

func test_initial_maturity_is_zero() -> bool:
	if _compute_maturity(_make_meta()) != 0.0:
		return _fail("new profile maturity should be 0")
	return true

func test_initial_maturity_unlocks_broceliande() -> bool:
	var threshold: int = MerlinConstants.BIOME_MATURITY_THRESHOLDS["foret_broceliande"]
	if _compute_maturity(_make_meta()) < float(threshold):
		return _fail("new profile should unlock foret_broceliande")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SCORE FORMULA
# ═══════════════════════════════════════════════════════════════════════════════

func test_score_runs_only() -> bool:
	if _compute_maturity(_make_meta(10)) != 20.0:
		return _fail("10 runs should = 20 points")
	return true

func test_score_fins_only() -> bool:
	if _compute_maturity(_make_meta(0, 3)) != 15.0:
		return _fail("3 fins should = 15 points")
	return true

func test_score_oghams_only() -> bool:
	if _compute_maturity(_make_meta(0, 0, 6)) != 18.0:
		return _fail("6 oghams should = 18 points")
	return true

func test_score_max_rep_only() -> bool:
	if _compute_maturity(_make_meta(0, 0, 0, 45.0)) != 45.0:
		return _fail("rep 45 should = 45 points")
	return true

func test_score_combined_formula() -> bool:
	if _compute_maturity(_make_meta(5, 2, 4, 30.0)) != 62.0:
		return _fail("combined should = 62")
	return true

func test_score_immutability() -> bool:
	var meta: Dictionary = _make_meta(3, 1, 2, 10.0)
	var before: int = meta["total_runs"]
	_compute_maturity(meta)
	if meta["total_runs"] != before:
		return _fail("meta mutated by compute_maturity")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ALL 8 BIOMES
# ═══════════════════════════════════════════════════════════════════════════════

func test_eight_biome_keys_exist() -> bool:
	if MerlinConstants.BIOME_KEYS.size() != 8:
		return _fail("expected 8 biome keys, got %d" % MerlinConstants.BIOME_KEYS.size())
	return true

func test_all_biome_keys_in_biomes_dict() -> bool:
	for key in MerlinConstants.BIOME_KEYS:
		if not MerlinConstants.BIOMES.has(key):
			return _fail("BIOMES missing: %s" % key)
	return true

func test_all_biome_keys_in_maturity_thresholds() -> bool:
	for key in MerlinConstants.BIOME_KEYS:
		if not MerlinConstants.BIOME_MATURITY_THRESHOLDS.has(key):
			return _fail("MATURITY_THRESHOLDS missing: %s" % key)
	return true

func test_all_biomes_have_name() -> bool:
	for key in MerlinConstants.BIOME_KEYS:
		if str(MerlinConstants.BIOMES[key].get("name", "")).is_empty():
			return _fail("biome %s has empty name" % key)
	return true

func test_all_biome_thresholds_non_negative() -> bool:
	for key in MerlinConstants.BIOME_KEYS:
		if MerlinConstants.BIOME_MATURITY_THRESHOLDS[key] < 0:
			return _fail("biome %s has negative threshold" % key)
	return true

func test_foret_broceliande_threshold_is_zero() -> bool:
	if MerlinConstants.BIOME_MATURITY_THRESHOLDS["foret_broceliande"] != 0:
		return _fail("broceliande threshold should be 0")
	return true

func test_iles_mystiques_threshold_is_highest() -> bool:
	var max_t: int = 0
	for key in MerlinConstants.BIOME_KEYS:
		max_t = maxi(max_t, MerlinConstants.BIOME_MATURITY_THRESHOLDS[key])
	if MerlinConstants.BIOME_MATURITY_THRESHOLDS["iles_mystiques"] != max_t:
		return _fail("iles_mystiques should have highest threshold")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME UNLOCK CONDITIONS
# ═══════════════════════════════════════════════════════════════════════════════

func test_foret_broceliande_always_unlocked() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	if not bs.is_unlocked("foret_broceliande", _make_meta()):
		return _fail("broceliande should always be unlocked")
	return true

func test_landes_bruyere_requires_min_runs() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	if bs.is_unlocked("landes_bruyere", _make_meta(1)):
		return _fail("landes should be locked at 1 run")
	if not bs.is_unlocked("landes_bruyere", _make_meta(2)):
		return _fail("landes should be unlocked at 2 runs")
	return true

func test_cotes_sauvages_requires_min_runs() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	if bs.is_unlocked("cotes_sauvages", _make_meta(2)):
		return _fail("cotes should be locked at 2 runs")
	if not bs.is_unlocked("cotes_sauvages", _make_meta(3)):
		return _fail("cotes should be unlocked at 3 runs")
	return true

func test_cercles_pierres_requires_runs_and_endings() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	if bs.is_unlocked("cercles_pierres", _make_meta(8)):
		return _fail("cercles should be locked: 8 runs but 0 endings")
	if not bs.is_unlocked("cercles_pierres", _make_meta(8, 0, 0, 0.0, ["harmonie", "equilibre"])):
		return _fail("cercles should be unlocked: 8 runs + 2 endings")
	return true

func test_iles_mystiques_requires_full_progression() -> bool:
	var bs: MerlinBiomeSystem = MerlinBiomeSystem.new()
	if bs.is_unlocked("iles_mystiques", _make_meta(20, 0, 0, 0.0, ["transcendance"])):
		return _fail("iles should be locked: only 1 ending")
	if not bs.is_unlocked("iles_mystiques", _make_meta(20, 0, 0, 0.0, ["transcendance", "harmonie", "equilibre", "chaos", "extinction"])):
		return _fail("iles should be unlocked: 20 runs + 5 endings")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MATURITY INCREMENTS
# ═══════════════════════════════════════════════════════════════════════════════

func test_score_increments_after_run() -> bool:
	var diff: float = _compute_maturity(_make_meta(6, 2, 3, 20.0)) - _compute_maturity(_make_meta(5, 2, 3, 20.0))
	if diff != 2.0: return _fail("+1 run should add 2, got %s" % str(diff))
	return true

func test_score_increments_after_fin() -> bool:
	var diff: float = _compute_maturity(_make_meta(5, 3, 3, 20.0)) - _compute_maturity(_make_meta(5, 2, 3, 20.0))
	if diff != 5.0: return _fail("+1 fin should add 5, got %s" % str(diff))
	return true

func test_score_increments_after_ogham() -> bool:
	var diff: float = _compute_maturity(_make_meta(5, 2, 4, 20.0)) - _compute_maturity(_make_meta(5, 2, 3, 20.0))
	if diff != 3.0: return _fail("+1 ogham should add 3, got %s" % str(diff))
	return true

func test_score_increments_after_rep_gain() -> bool:
	var diff: float = _compute_maturity(_make_meta(5, 2, 3, 30.0)) - _compute_maturity(_make_meta(5, 2, 3, 20.0))
	if diff != 10.0: return _fail("+10 rep should add 10, got %s" % str(diff))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# EDGE CASES
# ═══════════════════════════════════════════════════════════════════════════════

func test_large_values_do_not_overflow() -> bool:
	if _compute_maturity(_make_meta(1000, 200, 18, 100.0)) != 3154.0:
		return _fail("large values should produce 3154")
	return true

func test_zero_values_all_fields() -> bool:
	if _compute_maturity(_make_meta()) != 0.0:
		return _fail("all-zero should produce 0")
	return true

func test_single_run_meets_no_gated_biomes() -> bool:
	var score: float = _compute_maturity(_make_meta(1))
	for key in MerlinConstants.BIOME_KEYS:
		var t: int = MerlinConstants.BIOME_MATURITY_THRESHOLDS[key]
		if t > 2 and score >= float(t):
			return _fail("1 run (score=2) should not reach %s (threshold=%d)" % [key, t])
	return true

func test_high_ogham_count_boosts_score() -> bool:
	var score: float = _compute_maturity(_make_meta(0, 0, 18))
	if score != 54.0:
		return _fail("18 oghams should = 54, got %s" % str(score))
	return true
