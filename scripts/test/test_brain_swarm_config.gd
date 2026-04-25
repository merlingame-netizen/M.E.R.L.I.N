## ═══════════════════════════════════════════════════════════════════════════════
## Unit Tests — BrainSwarmConfig (static methods + PROFILES data integrity)
## ═══════════════════════════════════════════════════════════════════════════════
## Coverage:
##   detect_profile()      — RAM/thread thresholds, fallback to NANO
##   get_profile()         — valid IDs, invalid ID fallback
##   get_prefetch_depth()  — per-profile values, invalid ID fallback
##   get_profile_name()    — string result, invalid ID fallback
##   is_time_sharing()     — SINGLE_PLUS vs parallel modes
##   get_model_for_role()  — exact role match, fallback to first brain, missing role
##   get_brain_config()    — exact match, missing role returns {}
##   get_required_models() — deduplication (QUAD has two 0.8b brains)
##   get_peak_ram_mb()     — per-profile values, invalid ID fallback
##   PROFILES integrity    — all profiles have required keys, brain arrays valid
##
## Pattern: extends RefCounted, no class_name, test_xxx() -> bool
## ═══════════════════════════════════════════════════════════════════════════════

extends RefCounted


# ─── Convenience aliases ───────────────────────────────────────────────────────

const NANO: int = BrainSwarmConfig.Profile.NANO
const SINGLE: int = BrainSwarmConfig.Profile.SINGLE
const SINGLE_PLUS: int = BrainSwarmConfig.Profile.SINGLE_PLUS
const DUAL: int = BrainSwarmConfig.Profile.DUAL
const TRIPLE: int = BrainSwarmConfig.Profile.TRIPLE
const QUAD: int = BrainSwarmConfig.Profile.QUAD
const MOBILE_LOW: int = BrainSwarmConfig.Profile.MOBILE_LOW
const MOBILE_MID: int = BrainSwarmConfig.Profile.MOBILE_MID
const MOBILE_HIGH: int = BrainSwarmConfig.Profile.MOBILE_HIGH


# ═══════════════════════════════════════════════════════════════════════════════
# detect_profile() — RAM + thread gate logic
# ═══════════════════════════════════════════════════════════════════════════════

func test_detect_profile_quad_on_high_resources() -> bool:
	# QUAD: min_ram_mb=16000, min_threads=8
	var result: int = BrainSwarmConfig.detect_profile(20000, 12)
	if result != QUAD:
		push_error("detect_profile quad: expected QUAD (%d), got %d" % [QUAD, result])
		return false
	return true


func test_detect_profile_triple_below_quad_ram() -> bool:
	# TRIPLE: min_ram_mb=14000, min_threads=8 — just below QUAD threshold
	var result: int = BrainSwarmConfig.detect_profile(15000, 8)
	if result != TRIPLE:
		push_error("detect_profile triple: expected TRIPLE (%d), got %d" % [TRIPLE, result])
		return false
	return true


func test_detect_profile_dual_on_12gb_6threads() -> bool:
	# DUAL: min_ram_mb=12000, min_threads=6
	var result: int = BrainSwarmConfig.detect_profile(12000, 6)
	if result != DUAL:
		push_error("detect_profile dual: expected DUAL (%d), got %d" % [DUAL, result])
		return false
	return true


func test_detect_profile_single_plus_on_7gb_4threads() -> bool:
	# SINGLE_PLUS: min_ram_mb=7000, min_threads=4
	var result: int = BrainSwarmConfig.detect_profile(7000, 4)
	if result != SINGLE_PLUS:
		push_error("detect_profile single_plus: expected SINGLE_PLUS (%d), got %d" % [SINGLE_PLUS, result])
		return false
	return true


func test_detect_profile_single_on_6gb_4threads() -> bool:
	# SINGLE: min_ram_mb=6000, min_threads=4 — just below SINGLE_PLUS
	var result: int = BrainSwarmConfig.detect_profile(6000, 4)
	if result != SINGLE:
		push_error("detect_profile single: expected SINGLE (%d), got %d" % [SINGLE, result])
		return false
	return true


func test_detect_profile_nano_on_low_ram() -> bool:
	# Below every threshold
	var result: int = BrainSwarmConfig.detect_profile(2000, 2)
	if result != NANO:
		push_error("detect_profile nano low ram: expected NANO (%d), got %d" % [NANO, result])
		return false
	return true


func test_detect_profile_nano_on_zero_resources() -> bool:
	var result: int = BrainSwarmConfig.detect_profile(0, 0)
	if result != NANO:
		push_error("detect_profile nano zero: expected NANO (%d), got %d" % [NANO, result])
		return false
	return true


func test_detect_profile_thread_bottleneck_prevents_upgrade() -> bool:
	# Enough RAM for QUAD but only 2 threads → should fall back to NANO (no profile passes threads=2)
	var result: int = BrainSwarmConfig.detect_profile(32000, 2)
	if result != NANO:
		push_error("detect_profile thread bottleneck: expected NANO (%d), got %d" % [NANO, result])
		return false
	return true


func test_detect_profile_ram_bottleneck_prevents_upgrade() -> bool:
	# Enough threads for QUAD but only 3000 MB RAM → NANO
	var result: int = BrainSwarmConfig.detect_profile(3000, 16)
	if result != NANO:
		push_error("detect_profile ram bottleneck: expected NANO (%d), got %d" % [NANO, result])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_profile() — valid IDs and invalid ID fallback
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_profile_returns_dict_for_every_valid_id() -> bool:
	var valid_ids: Array[int] = [NANO, SINGLE, SINGLE_PLUS, DUAL, TRIPLE, QUAD, MOBILE_LOW, MOBILE_MID, MOBILE_HIGH]
	for pid in valid_ids:
		var profile: Dictionary = BrainSwarmConfig.get_profile(pid)
		if profile.is_empty():
			push_error("get_profile: profile %d returned empty dict" % pid)
			return false
	return true


func test_get_profile_invalid_id_returns_nano_fallback() -> bool:
	var profile: Dictionary = BrainSwarmConfig.get_profile(9999)
	var nano_profile: Dictionary = BrainSwarmConfig.get_profile(NANO)
	if str(profile.get("name", "")) != str(nano_profile.get("name", "_")):
		push_error("get_profile invalid: should fall back to NANO profile, got name '%s'" % str(profile.get("name", "")))
		return false
	return true


func test_get_profile_has_required_keys() -> bool:
	var required: Array[String] = ["name", "mode", "brains", "total_ram_mb", "min_threads", "min_ram_mb", "prefetch_depth"]
	var valid_ids: Array[int] = [NANO, SINGLE, SINGLE_PLUS, DUAL, TRIPLE, QUAD, MOBILE_LOW, MOBILE_MID, MOBILE_HIGH]
	for pid in valid_ids:
		var profile: Dictionary = BrainSwarmConfig.get_profile(pid)
		for key in required:
			if not profile.has(key):
				push_error("get_profile required keys: profile %d missing key '%s'" % [pid, key])
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_prefetch_depth() — per-profile values
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_prefetch_depth_nano_is_zero() -> bool:
	var depth: int = BrainSwarmConfig.get_prefetch_depth(NANO)
	if depth != 0:
		push_error("get_prefetch_depth NANO: expected 0, got %d" % depth)
		return false
	return true


func test_get_prefetch_depth_single_is_one() -> bool:
	var depth: int = BrainSwarmConfig.get_prefetch_depth(SINGLE)
	if depth != 1:
		push_error("get_prefetch_depth SINGLE: expected 1, got %d" % depth)
		return false
	return true


func test_get_prefetch_depth_triple_is_two() -> bool:
	var depth: int = BrainSwarmConfig.get_prefetch_depth(TRIPLE)
	if depth != 2:
		push_error("get_prefetch_depth TRIPLE: expected 2, got %d" % depth)
		return false
	return true


func test_get_prefetch_depth_quad_is_three() -> bool:
	var depth: int = BrainSwarmConfig.get_prefetch_depth(QUAD)
	if depth != 3:
		push_error("get_prefetch_depth QUAD: expected 3, got %d" % depth)
		return false
	return true


func test_get_prefetch_depth_invalid_id_returns_zero() -> bool:
	# Falls back to NANO which has prefetch_depth = 0
	var depth: int = BrainSwarmConfig.get_prefetch_depth(9999)
	if depth != 0:
		push_error("get_prefetch_depth invalid: expected 0, got %d" % depth)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_profile_name() — string result per profile
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_profile_name_returns_non_empty_string_for_all() -> bool:
	var valid_ids: Array[int] = [NANO, SINGLE, SINGLE_PLUS, DUAL, TRIPLE, QUAD]
	for pid in valid_ids:
		var name: String = BrainSwarmConfig.get_profile_name(pid)
		if name.is_empty():
			push_error("get_profile_name: profile %d returned empty name" % pid)
			return false
	return true


func test_get_profile_name_nano_contains_nano() -> bool:
	var name: String = BrainSwarmConfig.get_profile_name(NANO)
	if not name.to_lower().contains("nano"):
		push_error("get_profile_name NANO: name should contain 'nano', got '%s'" % name)
		return false
	return true


func test_get_profile_name_quad_contains_quad() -> bool:
	var name: String = BrainSwarmConfig.get_profile_name(QUAD)
	if not name.to_lower().contains("quad"):
		push_error("get_profile_name QUAD: name should contain 'quad', got '%s'" % name)
		return false
	return true


func test_get_profile_name_invalid_falls_back_to_nano_name() -> bool:
	var invalid_name: String = BrainSwarmConfig.get_profile_name(9999)
	var nano_name: String = BrainSwarmConfig.get_profile_name(NANO)
	if invalid_name != nano_name:
		push_error("get_profile_name invalid: expected NANO name '%s', got '%s'" % [nano_name, invalid_name])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# is_time_sharing() — mode detection
# ═══════════════════════════════════════════════════════════════════════════════

func test_is_time_sharing_true_only_for_single_plus() -> bool:
	if not BrainSwarmConfig.is_time_sharing(SINGLE_PLUS):
		push_error("is_time_sharing SINGLE_PLUS: should be true")
		return false
	return true


func test_is_time_sharing_false_for_nano() -> bool:
	if BrainSwarmConfig.is_time_sharing(NANO):
		push_error("is_time_sharing NANO: should be false")
		return false
	return true


func test_is_time_sharing_false_for_parallel_profiles() -> bool:
	var parallel_ids: Array[int] = [DUAL, TRIPLE, QUAD]
	for pid in parallel_ids:
		if BrainSwarmConfig.is_time_sharing(pid):
			push_error("is_time_sharing: profile %d should NOT be time_sharing" % pid)
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_model_for_role() — exact match, fallback to first brain
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_model_for_role_narrator_in_dual() -> bool:
	var tag: String = BrainSwarmConfig.get_model_for_role(DUAL, "narrator")
	if tag != BrainSwarmConfig.MODEL_QWEN35_4B:
		push_error("get_model_for_role DUAL narrator: expected '%s', got '%s'" % [BrainSwarmConfig.MODEL_QWEN35_4B, tag])
		return false
	return true


func test_get_model_for_role_gamemaster_in_dual() -> bool:
	var tag: String = BrainSwarmConfig.get_model_for_role(DUAL, "gamemaster")
	if tag != BrainSwarmConfig.MODEL_QWEN35_2B:
		push_error("get_model_for_role DUAL gamemaster: expected '%s', got '%s'" % [BrainSwarmConfig.MODEL_QWEN35_2B, tag])
		return false
	return true


func test_get_model_for_role_worker_in_triple() -> bool:
	var tag: String = BrainSwarmConfig.get_model_for_role(TRIPLE, "worker")
	if tag != BrainSwarmConfig.MODEL_QWEN35_08B:
		push_error("get_model_for_role TRIPLE worker: expected '%s', got '%s'" % [BrainSwarmConfig.MODEL_QWEN35_08B, tag])
		return false
	return true


func test_get_model_for_role_judge_in_quad() -> bool:
	var tag: String = BrainSwarmConfig.get_model_for_role(QUAD, "judge")
	if tag != BrainSwarmConfig.MODEL_QWEN35_08B:
		push_error("get_model_for_role QUAD judge: expected '%s', got '%s'" % [BrainSwarmConfig.MODEL_QWEN35_08B, tag])
		return false
	return true


func test_get_model_for_role_missing_role_falls_back_to_first_brain() -> bool:
	# NANO has only one brain (narrator); asking for "gamemaster" → first brain's model
	var tag: String = BrainSwarmConfig.get_model_for_role(NANO, "gamemaster")
	if tag != BrainSwarmConfig.MODEL_QWEN35_08B:
		push_error("get_model_for_role NANO missing role: expected first brain '%s', got '%s'" % [BrainSwarmConfig.MODEL_QWEN35_08B, tag])
		return false
	return true


func test_get_model_for_role_narrator_in_nano_is_08b() -> bool:
	var tag: String = BrainSwarmConfig.get_model_for_role(NANO, "narrator")
	if tag != BrainSwarmConfig.MODEL_QWEN35_08B:
		push_error("get_model_for_role NANO narrator: expected '%s', got '%s'" % [BrainSwarmConfig.MODEL_QWEN35_08B, tag])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_brain_config() — exact match and missing role
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_brain_config_narrator_in_quad() -> bool:
	var cfg: Dictionary = BrainSwarmConfig.get_brain_config(QUAD, "narrator")
	if cfg.is_empty():
		push_error("get_brain_config QUAD narrator: should not be empty")
		return false
	if str(cfg.get("role", "")) != "narrator":
		push_error("get_brain_config QUAD narrator: role mismatch '%s'" % str(cfg.get("role", "")))
		return false
	if int(cfg.get("n_ctx", 0)) != 8192:
		push_error("get_brain_config QUAD narrator: n_ctx should be 8192, got %d" % int(cfg.get("n_ctx", 0)))
		return false
	return true


func test_get_brain_config_missing_role_returns_empty_dict() -> bool:
	var cfg: Dictionary = BrainSwarmConfig.get_brain_config(NANO, "judge")
	if not cfg.is_empty():
		push_error("get_brain_config NANO judge: should return empty dict, got %s" % str(cfg))
		return false
	return true


func test_get_brain_config_all_brains_have_required_keys() -> bool:
	var required: Array[String] = ["role", "model_key", "ollama_tag", "n_ctx", "ram_mb", "thinking"]
	var valid_ids: Array[int] = [NANO, SINGLE, SINGLE_PLUS, DUAL, TRIPLE, QUAD]
	for pid in valid_ids:
		var profile: Dictionary = BrainSwarmConfig.get_profile(pid)
		var brain_list: Array = profile.get("brains", [])
		for brain in brain_list:
			for key in required:
				if not brain.has(key):
					push_error("get_brain_config keys: profile %d brain '%s' missing '%s'" % [pid, str(brain.get("role", "?")), key])
					return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_required_models() — unique model tags, QUAD deduplication
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_required_models_nano_returns_one_model() -> bool:
	var models: Array = BrainSwarmConfig.get_required_models(NANO)
	if models.size() != 1:
		push_error("get_required_models NANO: expected 1 model, got %d" % models.size())
		return false
	if str(models[0]) != BrainSwarmConfig.MODEL_QWEN35_08B:
		push_error("get_required_models NANO: expected '%s', got '%s'" % [BrainSwarmConfig.MODEL_QWEN35_08B, str(models[0])])
		return false
	return true


func test_get_required_models_dual_returns_two_models() -> bool:
	var models: Array = BrainSwarmConfig.get_required_models(DUAL)
	if models.size() != 2:
		push_error("get_required_models DUAL: expected 2 unique models, got %d" % models.size())
		return false
	if str(models[0]) != BrainSwarmConfig.MODEL_QWEN35_4B:
		push_error("get_required_models DUAL: first model should be 4B, got '%s'" % str(models[0]))
		return false
	if str(models[1]) != BrainSwarmConfig.MODEL_QWEN35_2B:
		push_error("get_required_models DUAL: second model should be 2B, got '%s'" % str(models[1]))
		return false
	return true


func test_get_required_models_quad_deduplicates_08b() -> bool:
	# QUAD has 4 brains but judge+worker both use 0.8b → only 3 unique tags
	var models: Array = BrainSwarmConfig.get_required_models(QUAD)
	if models.size() != 3:
		push_error("get_required_models QUAD: expected 3 unique models (4B, 2B, 0.8B), got %d" % models.size())
		return false
	# Verify 0.8b appears exactly once
	var tracker: Dictionary = {"count": 0}
	for m in models:
		if str(m) == BrainSwarmConfig.MODEL_QWEN35_08B:
			tracker["count"] = int(tracker["count"]) + 1
	if int(tracker["count"]) != 1:
		push_error("get_required_models QUAD: 0.8b should appear exactly once, got %d" % int(tracker["count"]))
		return false
	return true


func test_get_required_models_no_empty_strings() -> bool:
	var valid_ids: Array[int] = [NANO, SINGLE, SINGLE_PLUS, DUAL, TRIPLE, QUAD]
	for pid in valid_ids:
		var models: Array = BrainSwarmConfig.get_required_models(pid)
		for m in models:
			if str(m).is_empty():
				push_error("get_required_models: profile %d contains empty model tag" % pid)
				return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_peak_ram_mb() — per-profile values
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_peak_ram_mb_nano_is_800() -> bool:
	var ram: int = BrainSwarmConfig.get_peak_ram_mb(NANO)
	if ram != 800:
		push_error("get_peak_ram_mb NANO: expected 800, got %d" % ram)
		return false
	return true


func test_get_peak_ram_mb_single_plus_reflects_time_sharing() -> bool:
	# SINGLE_PLUS total_ram_mb = 3200 (peak = largest model only, time-sharing)
	var ram: int = BrainSwarmConfig.get_peak_ram_mb(SINGLE_PLUS)
	if ram != 3200:
		push_error("get_peak_ram_mb SINGLE_PLUS: expected 3200 (time-sharing peak), got %d" % ram)
		return false
	return true


func test_get_peak_ram_mb_dual_is_5000() -> bool:
	# DUAL: both models loaded simultaneously → 3200 + 1800 = 5000
	var ram: int = BrainSwarmConfig.get_peak_ram_mb(DUAL)
	if ram != 5000:
		push_error("get_peak_ram_mb DUAL: expected 5000, got %d" % ram)
		return false
	return true


func test_get_peak_ram_mb_quad_is_6600() -> bool:
	var ram: int = BrainSwarmConfig.get_peak_ram_mb(QUAD)
	if ram != 6600:
		push_error("get_peak_ram_mb QUAD: expected 6600, got %d" % ram)
		return false
	return true


func test_get_peak_ram_mb_invalid_id_returns_800_fallback() -> bool:
	# Falls back to NANO (800 MB)
	var ram: int = BrainSwarmConfig.get_peak_ram_mb(9999)
	if ram != 800:
		push_error("get_peak_ram_mb invalid: expected 800 (NANO fallback), got %d" % ram)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PROFILES data integrity
# ═══════════════════════════════════════════════════════════════════════════════

func test_profiles_min_ram_increases_with_tier() -> bool:
	# Larger profiles must require at least as much RAM as smaller ones (within group).
	# Desktop and mobile groups are tested separately because they target different
	# hardware classes (mobile RAM 3000-7000 overlaps with desktop NANO 4000).
	var desktop: Array[int] = [NANO, SINGLE, SINGLE_PLUS, DUAL, TRIPLE, QUAD]
	var prev_min_ram: int = -1
	for pid in desktop:
		var profile: Dictionary = BrainSwarmConfig.get_profile(pid)
		var min_ram: int = int(profile.get("min_ram_mb", 0))
		if min_ram < prev_min_ram:
			push_error("PROFILES desktop min_ram_mb: profile %d min_ram %d < previous %d (not ascending)" % [pid, min_ram, prev_min_ram])
			return false
		prev_min_ram = min_ram
	# Mobile tier ascending check (independent group)
	var mobile: Array[int] = [MOBILE_LOW, MOBILE_MID, MOBILE_HIGH]
	prev_min_ram = -1
	for pid in mobile:
		var profile: Dictionary = BrainSwarmConfig.get_profile(pid)
		var min_ram: int = int(profile.get("min_ram_mb", 0))
		if min_ram < prev_min_ram:
			push_error("PROFILES mobile min_ram_mb: profile %d min_ram %d < previous %d (not ascending)" % [pid, min_ram, prev_min_ram])
			return false
		prev_min_ram = min_ram
	return true


func test_profiles_brain_count_matches_tier_expectations() -> bool:
	# NANO=1, SINGLE=1, SINGLE_PLUS=2, DUAL=2, TRIPLE=3, QUAD=4
	var expected_brain_counts: Dictionary = {
		NANO: 1,
		SINGLE: 1,
		SINGLE_PLUS: 2,
		DUAL: 2,
		TRIPLE: 3,
		QUAD: 4,
	}
	for pid in expected_brain_counts.keys():
		var profile: Dictionary = BrainSwarmConfig.get_profile(pid)
		var brain_list: Array = profile.get("brains", [])
		var expected: int = int(expected_brain_counts[pid])
		if brain_list.size() != expected:
			push_error("PROFILES brain count: profile %d expected %d brains, got %d" % [pid, expected, brain_list.size()])
			return false
	return true


func test_model_constants_are_non_empty_strings() -> bool:
	var tags: Array[String] = [
		BrainSwarmConfig.MODEL_QWEN35_4B,
		BrainSwarmConfig.MODEL_QWEN35_2B,
		BrainSwarmConfig.MODEL_QWEN35_08B,
		BrainSwarmConfig.MODEL_QWEN25_1_5B,
	]
	for tag in tags:
		if tag.is_empty():
			push_error("MODEL constant: empty string found")
			return false
	return true


func test_ram_by_model_keys_are_non_empty() -> bool:
	var ram_map: Dictionary = BrainSwarmConfig.RAM_BY_MODEL
	if ram_map.is_empty():
		push_error("RAM_BY_MODEL: should not be empty")
		return false
	for key in ram_map.keys():
		var value: int = int(ram_map[key])
		if value <= 0:
			push_error("RAM_BY_MODEL['%s']: value must be > 0, got %d" % [str(key), value])
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RUNNER
# ═══════════════════════════════════════════════════════════════════════════════

func run_all() -> Dictionary:
	var tests: Array[String] = [
		# detect_profile (9)
		"test_detect_profile_quad_on_high_resources",
		"test_detect_profile_triple_below_quad_ram",
		"test_detect_profile_dual_on_12gb_6threads",
		"test_detect_profile_single_plus_on_7gb_4threads",
		"test_detect_profile_single_on_6gb_4threads",
		"test_detect_profile_nano_on_low_ram",
		"test_detect_profile_nano_on_zero_resources",
		"test_detect_profile_thread_bottleneck_prevents_upgrade",
		"test_detect_profile_ram_bottleneck_prevents_upgrade",
		# get_profile (3)
		"test_get_profile_returns_dict_for_every_valid_id",
		"test_get_profile_invalid_id_returns_nano_fallback",
		"test_get_profile_has_required_keys",
		# get_prefetch_depth (5)
		"test_get_prefetch_depth_nano_is_zero",
		"test_get_prefetch_depth_single_is_one",
		"test_get_prefetch_depth_triple_is_two",
		"test_get_prefetch_depth_quad_is_three",
		"test_get_prefetch_depth_invalid_id_returns_zero",
		# get_profile_name (4)
		"test_get_profile_name_returns_non_empty_string_for_all",
		"test_get_profile_name_nano_contains_nano",
		"test_get_profile_name_quad_contains_quad",
		"test_get_profile_name_invalid_falls_back_to_nano_name",
		# is_time_sharing (3)
		"test_is_time_sharing_true_only_for_single_plus",
		"test_is_time_sharing_false_for_nano",
		"test_is_time_sharing_false_for_parallel_profiles",
		# get_model_for_role (6)
		"test_get_model_for_role_narrator_in_dual",
		"test_get_model_for_role_gamemaster_in_dual",
		"test_get_model_for_role_worker_in_triple",
		"test_get_model_for_role_judge_in_quad",
		"test_get_model_for_role_missing_role_falls_back_to_first_brain",
		"test_get_model_for_role_narrator_in_nano_is_08b",
		# get_brain_config (3)
		"test_get_brain_config_narrator_in_quad",
		"test_get_brain_config_missing_role_returns_empty_dict",
		"test_get_brain_config_all_brains_have_required_keys",
		# get_required_models (4)
		"test_get_required_models_nano_returns_one_model",
		"test_get_required_models_dual_returns_two_models",
		"test_get_required_models_quad_deduplicates_08b",
		"test_get_required_models_no_empty_strings",
		# get_peak_ram_mb (5)
		"test_get_peak_ram_mb_nano_is_800",
		"test_get_peak_ram_mb_single_plus_reflects_time_sharing",
		"test_get_peak_ram_mb_dual_is_5000",
		"test_get_peak_ram_mb_quad_is_6600",
		"test_get_peak_ram_mb_invalid_id_returns_800_fallback",
		# PROFILES data integrity (4)
		"test_profiles_min_ram_increases_with_tier",
		"test_profiles_brain_count_matches_tier_expectations",
		"test_model_constants_are_non_empty_strings",
		"test_ram_by_model_keys_are_non_empty",
	]
	var passed: int = 0
	var failed: int = 0
	var failures: Array[String] = []
	for test_name in tests:
		if call(test_name):
			passed += 1
		else:
			failed += 1
			failures.append(test_name)
	var total: int = passed + failed
	print("[BrainSwarmConfigUnit] %d/%d passed (%d failed)" % [passed, total, failed])
	for f in failures:
		print("  FAIL: %s" % f)
	return {"passed": passed, "failed": failed, "total": total, "failures": failures}
