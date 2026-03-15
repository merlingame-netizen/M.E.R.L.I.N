# test_biome_maturity.gd
# GUT Unit Tests for Biome Maturity Scoring System
# Covers: score formula (runs×2 + fins×5 + oghams×3 + max_rep×1),
#         initial state, all 8 biomes, unlock conditions, increments, edge cases

extends GutTest


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

## Build a profile meta dict — all fields used by maturity and unlock checks.
func _make_meta(
		total_runs: int = 0,
		fins_vues: int = 0,
		oghams_debloques: int = 0,
		max_faction_rep: float = 0.0,
		endings_seen: Array = []
) -> Dictionary:
	return {
		"total_runs": total_runs,
		"fins_vues": fins_vues,
		"oghams_debloques": oghams_debloques,
		"max_faction_rep": max_faction_rep,
		"endings_seen": endings_seen,
	}


## Compute the maturity score using the canonical formula from MerlinConstants.MATURITY_WEIGHTS.
## Score = runs×2 + fins×5 + oghams×3 + max_rep×1
func _compute_maturity(meta: Dictionary) -> float:
	var w: Dictionary = MerlinConstants.MATURITY_WEIGHTS
	return (
		float(meta.get("total_runs", 0)) * float(w.get("total_runs", 2))
		+ float(meta.get("fins_vues", 0)) * float(w.get("fins_vues", 5))
		+ float(meta.get("oghams_debloques", 0)) * float(w.get("oghams_debloques", 3))
		+ float(meta.get("max_faction_rep", 0.0)) * float(w.get("max_faction_rep", 1))
	)


# ═══════════════════════════════════════════════════════════════════════════════
# MATURITY WEIGHTS — constants sanity check
# ═══════════════════════════════════════════════════════════════════════════════

func test_maturity_weights_exist():
	assert_true(MerlinConstants.MATURITY_WEIGHTS.has("total_runs"), "MATURITY_WEIGHTS has total_runs")
	assert_true(MerlinConstants.MATURITY_WEIGHTS.has("fins_vues"), "MATURITY_WEIGHTS has fins_vues")
	assert_true(MerlinConstants.MATURITY_WEIGHTS.has("oghams_debloques"), "MATURITY_WEIGHTS has oghams_debloques")
	assert_true(MerlinConstants.MATURITY_WEIGHTS.has("max_faction_rep"), "MATURITY_WEIGHTS has max_faction_rep")


func test_maturity_weights_values():
	var w: Dictionary = MerlinConstants.MATURITY_WEIGHTS
	assert_eq(int(w["total_runs"]), 2, "Runs weight = 2")
	assert_eq(int(w["fins_vues"]), 5, "Fins weight = 5")
	assert_eq(int(w["oghams_debloques"]), 3, "Oghams weight = 3")
	assert_eq(int(w["max_faction_rep"]), 1, "Max rep weight = 1")


# ═══════════════════════════════════════════════════════════════════════════════
# INITIAL STATE — New biome / fresh profile
# ═══════════════════════════════════════════════════════════════════════════════

func test_initial_maturity_is_zero():
	var meta: Dictionary = _make_meta(0, 0, 0, 0.0)
	var score: float = _compute_maturity(meta)
	assert_eq(score, 0.0, "New profile: maturity score should be 0")


func test_initial_maturity_each_biome_threshold():
	# foret_broceliande threshold is 0 — score 0 meets it
	var meta: Dictionary = _make_meta(0, 0, 0, 0.0)
	var score: float = _compute_maturity(meta)
	var threshold: int = MerlinConstants.BIOME_MATURITY_THRESHOLDS["foret_broceliande"]
	assert_true(score >= threshold, "New profile unlocks foret_broceliande (threshold 0)")


# ═══════════════════════════════════════════════════════════════════════════════
# SCORE FORMULA — Each component contribution
# ═══════════════════════════════════════════════════════════════════════════════

func test_score_runs_only():
	# 10 runs × 2 = 20
	var meta: Dictionary = _make_meta(10, 0, 0, 0.0)
	assert_eq(_compute_maturity(meta), 20.0, "10 runs = 20 points")


func test_score_fins_only():
	# 3 fins × 5 = 15
	var meta: Dictionary = _make_meta(0, 3, 0, 0.0)
	assert_eq(_compute_maturity(meta), 15.0, "3 fins = 15 points")


func test_score_oghams_only():
	# 6 oghams × 3 = 18
	var meta: Dictionary = _make_meta(0, 0, 6, 0.0)
	assert_eq(_compute_maturity(meta), 18.0, "6 oghams = 18 points")


func test_score_max_rep_only():
	# max_faction_rep 45 × 1 = 45
	var meta: Dictionary = _make_meta(0, 0, 0, 45.0)
	assert_eq(_compute_maturity(meta), 45.0, "max_rep 45 = 45 points")


func test_score_combined_formula():
	# 5 runs×2 + 2 fins×5 + 4 oghams×3 + 30 rep×1 = 10+10+12+30 = 62
	var meta: Dictionary = _make_meta(5, 2, 4, 30.0)
	assert_eq(_compute_maturity(meta), 62.0, "Combined: 10+10+12+30 = 62")


func test_score_immutability():
	# Computing maturity from meta must not mutate it
	var meta: Dictionary = _make_meta(3, 1, 2, 10.0)
	var before_runs: int = meta["total_runs"]
	_compute_maturity(meta)
	assert_eq(meta["total_runs"], before_runs, "Meta dict not mutated after maturity computation")


# ═══════════════════════════════════════════════════════════════════════════════
# ALL 8 BIOMES — Presence and valid structure
# ═══════════════════════════════════════════════════════════════════════════════

func test_eight_biome_keys_exist():
	var keys: Array = MerlinConstants.BIOME_KEYS
	assert_eq(keys.size(), 8, "Exactly 8 biome keys defined")


func test_all_biome_keys_in_biomes_dict():
	for key in MerlinConstants.BIOME_KEYS:
		assert_true(MerlinConstants.BIOMES.has(key), "BIOMES contains key: " + key)


func test_all_biome_keys_in_maturity_thresholds():
	for key in MerlinConstants.BIOME_KEYS:
		assert_true(
			MerlinConstants.BIOME_MATURITY_THRESHOLDS.has(key),
			"BIOME_MATURITY_THRESHOLDS contains key: " + key
		)


func test_all_biomes_have_name():
	for key in MerlinConstants.BIOME_KEYS:
		var biome: Dictionary = MerlinConstants.BIOMES[key]
		var name_val: String = str(biome.get("name", ""))
		assert_true(name_val.length() > 0, "Biome %s has non-empty name" % key)


func test_all_biome_thresholds_are_non_negative():
	for key in MerlinConstants.BIOME_KEYS:
		var threshold: int = MerlinConstants.BIOME_MATURITY_THRESHOLDS[key]
		assert_true(threshold >= 0, "Biome %s threshold >= 0 (got %d)" % [key, threshold])


func test_foret_broceliande_threshold_is_zero():
	# Always-available starter biome
	assert_eq(MerlinConstants.BIOME_MATURITY_THRESHOLDS["foret_broceliande"], 0,
		"Foret de Broceliande has maturity threshold 0")


func test_iles_mystiques_threshold_is_highest():
	# Endgame biome must require the highest maturity
	var max_threshold: int = 0
	for key in MerlinConstants.BIOME_KEYS:
		var t: int = MerlinConstants.BIOME_MATURITY_THRESHOLDS[key]
		if t > max_threshold:
			max_threshold = t
	assert_eq(
		MerlinConstants.BIOME_MATURITY_THRESHOLDS["iles_mystiques"],
		max_threshold,
		"Iles Mystiques has the highest maturity threshold"
	)


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME UNLOCK CONDITIONS — MerlinBiomeSystem.is_unlocked()
# ═══════════════════════════════════════════════════════════════════════════════

var _biome_sys: MerlinBiomeSystem


func before_each() -> void:
	_biome_sys = MerlinBiomeSystem.new()


func after_each() -> void:
	_biome_sys = null


func test_foret_broceliande_always_unlocked():
	var meta: Dictionary = _make_meta(0, 0, 0, 0.0, [])
	assert_true(_biome_sys.is_unlocked("foret_broceliande", meta),
		"foret_broceliande has no unlock condition — always available")


func test_landes_bruyere_requires_min_runs():
	# unlock: {min_runs: 2}
	var locked_meta: Dictionary = _make_meta(1, 0, 0, 0.0, [])
	assert_false(_biome_sys.is_unlocked("landes_bruyere", locked_meta),
		"landes_bruyere locked with 1 run (needs 2)")
	var unlocked_meta: Dictionary = _make_meta(2, 0, 0, 0.0, [])
	assert_true(_biome_sys.is_unlocked("landes_bruyere", unlocked_meta),
		"landes_bruyere unlocked with 2 runs")


func test_cotes_sauvages_requires_min_runs():
	# unlock: {min_runs: 3}
	var locked_meta: Dictionary = _make_meta(2, 0, 0, 0.0, [])
	assert_false(_biome_sys.is_unlocked("cotes_sauvages", locked_meta),
		"cotes_sauvages locked with 2 runs (needs 3)")
	var unlocked_meta: Dictionary = _make_meta(3, 0, 0, 0.0, [])
	assert_true(_biome_sys.is_unlocked("cotes_sauvages", unlocked_meta),
		"cotes_sauvages unlocked with 3 runs")


func test_cercles_pierres_requires_runs_and_endings():
	# unlock: {min_runs: 8, min_endings: 2}
	var locked_runs_only: Dictionary = _make_meta(8, 0, 0, 0.0, [])
	assert_false(_biome_sys.is_unlocked("cercles_pierres", locked_runs_only),
		"cercles_pierres locked: 8 runs but 0 endings (needs 2)")
	var locked_endings_only: Dictionary = _make_meta(0, 0, 0, 0.0, ["harmonie", "equilibre"])
	assert_false(_biome_sys.is_unlocked("cercles_pierres", locked_endings_only),
		"cercles_pierres locked: 2 endings but 0 runs (needs 8)")
	var unlocked_meta: Dictionary = _make_meta(8, 0, 0, 0.0, ["harmonie", "equilibre"])
	assert_true(_biome_sys.is_unlocked("cercles_pierres", unlocked_meta),
		"cercles_pierres unlocked: 8 runs + 2 endings")


func test_marais_korrigans_requires_specific_ending():
	# unlock: {min_runs: 10, required_ending: "harmonie"}
	var meta_no_ending: Dictionary = _make_meta(10, 0, 0, 0.0, ["transcendance"])
	assert_false(_biome_sys.is_unlocked("marais_korrigans", meta_no_ending),
		"marais_korrigans locked: missing 'harmonie' ending")
	var meta_with_ending: Dictionary = _make_meta(10, 0, 0, 0.0, ["harmonie"])
	assert_true(_biome_sys.is_unlocked("marais_korrigans", meta_with_ending),
		"marais_korrigans unlocked: 10 runs + harmonie ending")


func test_iles_mystiques_requires_runs_endings_and_specific_ending():
	# unlock: {min_runs: 20, min_endings: 5, required_ending: "transcendance"}
	var meta_partial: Dictionary = _make_meta(20, 0, 0, 0.0, ["transcendance"])
	assert_false(_biome_sys.is_unlocked("iles_mystiques", meta_partial),
		"iles_mystiques locked: only 1 ending (needs 5)")
	var meta_full: Dictionary = _make_meta(
		20, 0, 0, 0.0,
		["transcendance", "harmonie", "equilibre", "chaos", "extinction"]
	)
	assert_true(_biome_sys.is_unlocked("iles_mystiques", meta_full),
		"iles_mystiques unlocked: 20 runs + 5 endings including transcendance")


# ═══════════════════════════════════════════════════════════════════════════════
# MATURITY INCREMENTS — Score grows correctly after events
# ═══════════════════════════════════════════════════════════════════════════════

func test_score_increments_after_run():
	var base_meta: Dictionary = _make_meta(5, 2, 3, 20.0)
	var after_run: Dictionary = _make_meta(6, 2, 3, 20.0)
	var diff: float = _compute_maturity(after_run) - _compute_maturity(base_meta)
	assert_eq(diff, 2.0, "Adding 1 run increases score by exactly 2")


func test_score_increments_after_fin():
	var base_meta: Dictionary = _make_meta(5, 2, 3, 20.0)
	var after_fin: Dictionary = _make_meta(5, 3, 3, 20.0)
	var diff: float = _compute_maturity(after_fin) - _compute_maturity(base_meta)
	assert_eq(diff, 5.0, "Adding 1 fin increases score by exactly 5")


func test_score_increments_after_ogham():
	var base_meta: Dictionary = _make_meta(5, 2, 3, 20.0)
	var after_ogham: Dictionary = _make_meta(5, 2, 4, 20.0)
	var diff: float = _compute_maturity(after_ogham) - _compute_maturity(base_meta)
	assert_eq(diff, 3.0, "Discovering 1 ogham increases score by exactly 3")


func test_score_increments_after_rep_gain():
	var base_meta: Dictionary = _make_meta(5, 2, 3, 20.0)
	var after_rep: Dictionary = _make_meta(5, 2, 3, 30.0)
	var diff: float = _compute_maturity(after_rep) - _compute_maturity(base_meta)
	assert_eq(diff, 10.0, "max_faction_rep +10 increases score by exactly 10")


func test_score_reaches_landes_threshold():
	# landes_bruyere threshold = 15, achievable with e.g. 3 fins
	var meta: Dictionary = _make_meta(0, 3, 0, 0.0)
	var score: float = _compute_maturity(meta)
	var threshold: int = MerlinConstants.BIOME_MATURITY_THRESHOLDS["landes_bruyere"]
	assert_true(score >= float(threshold),
		"3 fins (score=15) meets landes_bruyere threshold (%d)" % threshold)


func test_score_does_not_reach_iles_mystiques_with_few_runs():
	# iles_mystiques threshold = 75
	var meta: Dictionary = _make_meta(5, 1, 2, 10.0)
	# 10 + 5 + 6 + 10 = 31
	var score: float = _compute_maturity(meta)
	var threshold: int = MerlinConstants.BIOME_MATURITY_THRESHOLDS["iles_mystiques"]
	assert_true(score < float(threshold),
		"Low-progress profile (score=%s) does not reach iles_mystiques (%d)" % [score, threshold])


# ═══════════════════════════════════════════════════════════════════════════════
# EDGE CASES
# ═══════════════════════════════════════════════════════════════════════════════

func test_large_values_do_not_overflow():
	# Godot 4 floats can handle large values without practical overflow here
	var meta: Dictionary = _make_meta(1000, 200, 18, 100.0)
	# 2000 + 1000 + 54 + 100 = 3154
	var score: float = _compute_maturity(meta)
	assert_eq(score, 3154.0, "Large values: 1000 runs + 200 fins + 18 oghams + 100 rep = 3154")


func test_zero_values_all_fields():
	var meta: Dictionary = _make_meta(0, 0, 0, 0.0)
	assert_eq(_compute_maturity(meta), 0.0, "All-zero meta produces score 0")


func test_negative_max_rep_contribution():
	# max_faction_rep should not be negative in practice, but the formula is linear
	# A value of 0 is the floor enforced by the game; we test 0 produces nothing extra.
	var meta: Dictionary = _make_meta(2, 0, 0, 0.0)
	assert_eq(_compute_maturity(meta), 4.0, "2 runs, zero rep = 4 points (no negative rep)")


func test_single_run_meets_no_gated_biomes():
	# With only 1 run and nothing else, only foret_broceliande (threshold=0) is met
	var score: float = _compute_maturity(_make_meta(1, 0, 0, 0.0))
	# Check all biomes with threshold > 2 are NOT met
	for key in MerlinConstants.BIOME_KEYS:
		var t: int = MerlinConstants.BIOME_MATURITY_THRESHOLDS[key]
		if t > 2:
			assert_true(score < float(t),
				"1 run (score=2) should not reach %s (threshold=%d)" % [key, t])


func test_high_ogham_count_boosts_score_significantly():
	# 18 oghams × 3 = 54 points — enough for villages_celtes (25) and cercles_pierres (30)
	var meta: Dictionary = _make_meta(0, 0, 18, 0.0)
	var score: float = _compute_maturity(meta)
	assert_eq(score, 54.0, "18 oghams = 54 score")
	assert_true(score >= float(MerlinConstants.BIOME_MATURITY_THRESHOLDS["cercles_pierres"]),
		"18 oghams meets cercles_pierres threshold (%d)" % MerlinConstants.BIOME_MATURITY_THRESHOLDS["cercles_pierres"])
