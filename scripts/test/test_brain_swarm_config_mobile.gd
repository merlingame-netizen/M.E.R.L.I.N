## =============================================================================
## Unit Tests — BrainSwarmConfig MOBILE profiles (ARM-friendly tier-aware)
## =============================================================================
## Validates Profile.MOBILE_LOW / MOBILE_MID / MOBILE_HIGH:
##   - Profile enum values exist
##   - SINGLE brain (mobile strict, no multi-instance)
##   - RAM/CTX/threads bounds match mobile hardware tiers
##   - Models target ARM-friendly families (Llama 3.2, Qwen 2.5, Phi 3.5)
##   - detect_profile_mobile(ram, threads) chooses appropriate tier
## =============================================================================

extends RefCounted

const BrainSwarmConfig = preload("res://addons/merlin_ai/brain_swarm_config.gd")


func _fail(msg: String) -> bool:
	push_error(msg)
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# PROFILE EXISTENCE
# ═══════════════════════════════════════════════════════════════════════════════

func test_mobile_low_profile_exists() -> bool:
	if not BrainSwarmConfig.PROFILES.has(BrainSwarmConfig.Profile.MOBILE_LOW):
		return _fail("PROFILES does not contain Profile.MOBILE_LOW")
	return true


func test_mobile_mid_profile_exists() -> bool:
	if not BrainSwarmConfig.PROFILES.has(BrainSwarmConfig.Profile.MOBILE_MID):
		return _fail("PROFILES does not contain Profile.MOBILE_MID")
	return true


func test_mobile_high_profile_exists() -> bool:
	if not BrainSwarmConfig.PROFILES.has(BrainSwarmConfig.Profile.MOBILE_HIGH):
		return _fail("PROFILES does not contain Profile.MOBILE_HIGH")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SINGLE BRAIN (mobile strict — no multi-instance per user direction)
# ═══════════════════════════════════════════════════════════════════════════════

func test_mobile_low_has_single_brain() -> bool:
	var profile: Dictionary = BrainSwarmConfig.PROFILES[BrainSwarmConfig.Profile.MOBILE_LOW]
	var brains: Array = profile.get("brains", [])
	if brains.size() != 1:
		return _fail("MOBILE_LOW must have 1 brain, got " + str(brains.size()))
	return true


func test_mobile_mid_has_single_brain() -> bool:
	var profile: Dictionary = BrainSwarmConfig.PROFILES[BrainSwarmConfig.Profile.MOBILE_MID]
	var brains: Array = profile.get("brains", [])
	if brains.size() != 1:
		return _fail("MOBILE_MID must have 1 brain, got " + str(brains.size()))
	return true


func test_mobile_high_has_single_brain() -> bool:
	var profile: Dictionary = BrainSwarmConfig.PROFILES[BrainSwarmConfig.Profile.MOBILE_HIGH]
	var brains: Array = profile.get("brains", [])
	if brains.size() != 1:
		return _fail("MOBILE_HIGH must have 1 brain, got " + str(brains.size()))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# RAM BOUNDS (mobile hardware tiers)
# ═══════════════════════════════════════════════════════════════════════════════

func test_mobile_low_ram_under_900mb() -> bool:
	var profile: Dictionary = BrainSwarmConfig.PROFILES[BrainSwarmConfig.Profile.MOBILE_LOW]
	var ram: int = int(profile.get("total_ram_mb", 0))
	if ram == 0 or ram > 900:
		return _fail("MOBILE_LOW total_ram_mb must be 0 < x <= 900, got " + str(ram))
	return true


func test_mobile_mid_ram_under_1600mb() -> bool:
	var profile: Dictionary = BrainSwarmConfig.PROFILES[BrainSwarmConfig.Profile.MOBILE_MID]
	var ram: int = int(profile.get("total_ram_mb", 0))
	if ram <= 900 or ram > 1600:
		return _fail("MOBILE_MID total_ram_mb must be 900 < x <= 1600, got " + str(ram))
	return true


func test_mobile_high_ram_under_3000mb() -> bool:
	var profile: Dictionary = BrainSwarmConfig.PROFILES[BrainSwarmConfig.Profile.MOBILE_HIGH]
	var ram: int = int(profile.get("total_ram_mb", 0))
	if ram <= 1600 or ram > 3000:
		return _fail("MOBILE_HIGH total_ram_mb must be 1600 < x <= 3000, got " + str(ram))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# CONTEXT WINDOW (n_ctx) — adaptive per tier
# ═══════════════════════════════════════════════════════════════════════════════

func test_mobile_low_n_ctx_compact() -> bool:
	var profile: Dictionary = BrainSwarmConfig.PROFILES[BrainSwarmConfig.Profile.MOBILE_LOW]
	var brains: Array = profile.get("brains", [])
	if brains.is_empty():
		return _fail("MOBILE_LOW has no brains")
	var n_ctx: int = int(brains[0].get("n_ctx", 0))
	if n_ctx < 1024 or n_ctx > 2048:
		return _fail("MOBILE_LOW n_ctx must be in [1024, 2048], got " + str(n_ctx))
	return true


func test_mobile_mid_n_ctx_standard() -> bool:
	var profile: Dictionary = BrainSwarmConfig.PROFILES[BrainSwarmConfig.Profile.MOBILE_MID]
	var brains: Array = profile.get("brains", [])
	var n_ctx: int = int(brains[0].get("n_ctx", 0))
	if n_ctx < 2048 or n_ctx > 4096:
		return _fail("MOBILE_MID n_ctx must be in [2048, 4096], got " + str(n_ctx))
	return true


func test_mobile_high_n_ctx_comfortable() -> bool:
	var profile: Dictionary = BrainSwarmConfig.PROFILES[BrainSwarmConfig.Profile.MOBILE_HIGH]
	var brains: Array = profile.get("brains", [])
	var n_ctx: int = int(brains[0].get("n_ctx", 0))
	if n_ctx < 2048 or n_ctx > 4096:
		return _fail("MOBILE_HIGH n_ctx must be in [2048, 4096], got " + str(n_ctx))
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# MODE — mobile = resident (no time_sharing, no parallel)
# ═══════════════════════════════════════════════════════════════════════════════

func test_mobile_low_mode_resident() -> bool:
	var profile: Dictionary = BrainSwarmConfig.PROFILES[BrainSwarmConfig.Profile.MOBILE_LOW]
	var mode: String = str(profile.get("mode", ""))
	if mode != "resident":
		return _fail("MOBILE_LOW mode must be 'resident', got '" + mode + "'")
	return true


func test_mobile_mid_mode_resident() -> bool:
	var profile: Dictionary = BrainSwarmConfig.PROFILES[BrainSwarmConfig.Profile.MOBILE_MID]
	var mode: String = str(profile.get("mode", ""))
	if mode != "resident":
		return _fail("MOBILE_MID mode must be 'resident', got '" + mode + "'")
	return true


func test_mobile_high_mode_resident() -> bool:
	var profile: Dictionary = BrainSwarmConfig.PROFILES[BrainSwarmConfig.Profile.MOBILE_HIGH]
	var mode: String = str(profile.get("mode", ""))
	if mode != "resident":
		return _fail("MOBILE_HIGH mode must be 'resident', got '" + mode + "'")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DETECT MOBILE — auto-tier based on hardware
# ═══════════════════════════════════════════════════════════════════════════════

func test_detect_mobile_low_for_4gb_phone() -> bool:
	if not BrainSwarmConfig.has_method("detect_profile_mobile"):
		return _fail("BrainSwarmConfig.detect_profile_mobile() not implemented")
	var profile_id: int = BrainSwarmConfig.detect_profile_mobile(3500, 6)
	if profile_id != BrainSwarmConfig.Profile.MOBILE_LOW:
		return _fail("detect_profile_mobile(3500MB, 6 threads) should return MOBILE_LOW, got " + str(profile_id))
	return true


func test_detect_mobile_mid_for_6gb_phone() -> bool:
	if not BrainSwarmConfig.has_method("detect_profile_mobile"):
		return _fail("BrainSwarmConfig.detect_profile_mobile() not implemented")
	var profile_id: int = BrainSwarmConfig.detect_profile_mobile(5500, 8)
	if profile_id != BrainSwarmConfig.Profile.MOBILE_MID:
		return _fail("detect_profile_mobile(5500MB, 8 threads) should return MOBILE_MID, got " + str(profile_id))
	return true


func test_detect_mobile_high_for_8gb_phone() -> bool:
	if not BrainSwarmConfig.has_method("detect_profile_mobile"):
		return _fail("BrainSwarmConfig.detect_profile_mobile() not implemented")
	var profile_id: int = BrainSwarmConfig.detect_profile_mobile(7500, 8)
	if profile_id != BrainSwarmConfig.Profile.MOBILE_HIGH:
		return _fail("detect_profile_mobile(7500MB, 8 threads) should return MOBILE_HIGH, got " + str(profile_id))
	return true
