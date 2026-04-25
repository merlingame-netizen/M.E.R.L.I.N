## =============================================================================
## Unit Tests -- SFXEngine Phase 9 (Enum-Based Procedural Audio)
## =============================================================================
## Tests: enum coverage, volume clamping, enable/disable, pool management,
## play API, positional fallback, varied pitch, category mapping.
## Pattern: extends RefCounted, each test returns bool, run_all() aggregates.
## =============================================================================

extends RefCounted


# =============================================================================
# HELPERS
# =============================================================================

func _make_manager() -> SFXEngine:
	var mgr: SFXEngine = SFXEngine.new()
	# Simulate _ready by calling internal init (pool + sounds)
	mgr._create_player_pool()
	mgr._generate_all_sounds()
	return mgr


func _cleanup(mgr: SFXEngine) -> void:
	mgr.stop_all()
	# Free pool players
	for child in mgr.get_children():
		child.queue_free()
	mgr.queue_free()


# =============================================================================
# TEST: All SFX enum values have generated sounds
# =============================================================================

func test_enum_coverage() -> bool:
	var mgr: SFXEngine = _make_manager()
	var all_sfx: Array[int] = [
		SFXEngine.SFX.CARD_DRAW, SFXEngine.SFX.CARD_FLIP,
		SFXEngine.SFX.OPTION_SELECT, SFXEngine.SFX.MINIGAME_START,
		SFXEngine.SFX.MINIGAME_END, SFXEngine.SFX.SCORE_REVEAL,
		SFXEngine.SFX.EFFECT_POSITIVE, SFXEngine.SFX.EFFECT_NEGATIVE,
		SFXEngine.SFX.OGHAM_ACTIVATE, SFXEngine.SFX.OGHAM_COOLDOWN,
		SFXEngine.SFX.LIFE_DRAIN, SFXEngine.SFX.LIFE_HEAL,
		SFXEngine.SFX.DEATH, SFXEngine.SFX.VICTORY,
		SFXEngine.SFX.REP_UP, SFXEngine.SFX.REP_DOWN,
		SFXEngine.SFX.ANAM_GAIN, SFXEngine.SFX.WALK_STEP,
		SFXEngine.SFX.BIOME_TRANSITION, SFXEngine.SFX.MENU_CLICK,
		SFXEngine.SFX.MENU_HOVER, SFXEngine.SFX.PROMISE_CREATE,
		SFXEngine.SFX.PROMISE_FULFILL, SFXEngine.SFX.PROMISE_BREAK,
		SFXEngine.SFX.KARMA_SHIFT, SFXEngine.SFX.HUB_AMBIENT,
		SFXEngine.SFX.RUN_AMBIENT,
	]

	var pass_count: int = 0
	for sfx_val in all_sfx:
		if mgr.has_sound(sfx_val):
			pass_count += 1
		else:
			push_error("[test_enum_coverage] Missing sound for SFX %d" % sfx_val)

	var expected: int = all_sfx.size()
	if pass_count != expected:
		push_error("[test_enum_coverage] %d/%d sounds generated" % [pass_count, expected])
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Volume clamping works correctly
# =============================================================================

func test_volume_clamping() -> bool:
	var mgr: SFXEngine = _make_manager()

	# Set extreme positive volume
	mgr.set_master_volume(100.0)
	if mgr.get_master_volume() != SFXEngine.VOLUME_DB_MAX:
		push_error("[test_volume_clamping] Expected max %f, got %f" % [SFXEngine.VOLUME_DB_MAX, mgr.get_master_volume()])
		_cleanup(mgr)
		return false

	# Set extreme negative volume
	mgr.set_master_volume(-200.0)
	if mgr.get_master_volume() != SFXEngine.VOLUME_DB_MIN:
		push_error("[test_volume_clamping] Expected min %f, got %f" % [SFXEngine.VOLUME_DB_MIN, mgr.get_master_volume()])
		_cleanup(mgr)
		return false

	# Set normal volume
	mgr.set_master_volume(-6.0)
	if not is_equal_approx(mgr.get_master_volume(), -6.0):
		push_error("[test_volume_clamping] Expected -6.0, got %f" % mgr.get_master_volume())
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Enable/disable SFX
# =============================================================================

func test_enable_disable() -> bool:
	var mgr: SFXEngine = _make_manager()

	# Default should be enabled
	if not mgr.is_sfx_enabled():
		push_error("[test_enable_disable] SFX should be enabled by default")
		_cleanup(mgr)
		return false

	# Disable
	mgr.set_sfx_enabled(false)
	if mgr.is_sfx_enabled():
		push_error("[test_enable_disable] SFX should be disabled after set_sfx_enabled(false)")
		_cleanup(mgr)
		return false

	# Re-enable
	mgr.set_sfx_enabled(true)
	if not mgr.is_sfx_enabled():
		push_error("[test_enable_disable] SFX should be enabled after set_sfx_enabled(true)")
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Pool size matches configuration
# =============================================================================

func test_pool_size() -> bool:
	var mgr: SFXEngine = _make_manager()

	if mgr.get_pool_size() != SFXEngine.POOL_SIZE:
		push_error("[test_pool_size] Expected %d, got %d" % [SFXEngine.POOL_SIZE, mgr.get_pool_size()])
		_cleanup(mgr)
		return false

	# Pool children count should match
	var player_count: int = 0
	for child in mgr.get_children():
		if child is AudioStreamPlayer:
			player_count += 1

	if player_count != SFXEngine.POOL_SIZE:
		push_error("[test_pool_size] Expected %d AudioStreamPlayers, got %d" % [SFXEngine.POOL_SIZE, player_count])
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: Active count starts at zero
# =============================================================================

func test_active_count_initial() -> bool:
	var mgr: SFXEngine = _make_manager()

	if mgr.get_active_count() != 0:
		push_error("[test_active_count_initial] Expected 0 active, got %d" % mgr.get_active_count())
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: has_sound returns false for invalid SFX
# =============================================================================

func test_has_sound_invalid() -> bool:
	var mgr: SFXEngine = _make_manager()

	# Use a value outside the enum range
	if mgr.has_sound(9999):
		push_error("[test_has_sound_invalid] Should return false for invalid SFX value")
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# TEST: SFX volume map covers all enum values
# =============================================================================

func test_volume_map_coverage() -> bool:
	var all_sfx: Array[int] = [
		SFXEngine.SFX.CARD_DRAW, SFXEngine.SFX.CARD_FLIP,
		SFXEngine.SFX.OPTION_SELECT, SFXEngine.SFX.MINIGAME_START,
		SFXEngine.SFX.MINIGAME_END, SFXEngine.SFX.SCORE_REVEAL,
		SFXEngine.SFX.EFFECT_POSITIVE, SFXEngine.SFX.EFFECT_NEGATIVE,
		SFXEngine.SFX.OGHAM_ACTIVATE, SFXEngine.SFX.OGHAM_COOLDOWN,
		SFXEngine.SFX.LIFE_DRAIN, SFXEngine.SFX.LIFE_HEAL,
		SFXEngine.SFX.DEATH, SFXEngine.SFX.VICTORY,
		SFXEngine.SFX.REP_UP, SFXEngine.SFX.REP_DOWN,
		SFXEngine.SFX.ANAM_GAIN, SFXEngine.SFX.WALK_STEP,
		SFXEngine.SFX.BIOME_TRANSITION, SFXEngine.SFX.MENU_CLICK,
		SFXEngine.SFX.MENU_HOVER, SFXEngine.SFX.PROMISE_CREATE,
		SFXEngine.SFX.PROMISE_FULFILL, SFXEngine.SFX.PROMISE_BREAK,
		SFXEngine.SFX.KARMA_SHIFT, SFXEngine.SFX.HUB_AMBIENT,
		SFXEngine.SFX.RUN_AMBIENT,
	]

	for sfx_val in all_sfx:
		if not SFXEngine.SFX_VOLUME_MAP.has(sfx_val):
			push_error("[test_volume_map_coverage] Missing volume mapping for SFX %d" % sfx_val)
			return false

	return true


# =============================================================================
# TEST: Stop all clears active players
# =============================================================================

func test_stop_all() -> bool:
	var mgr: SFXEngine = _make_manager()

	# stop_all on clean manager should not error
	mgr.stop_all()
	if mgr.get_active_count() != 0:
		push_error("[test_stop_all] Expected 0 active after stop_all, got %d" % mgr.get_active_count())
		_cleanup(mgr)
		return false

	_cleanup(mgr)
	return true


# =============================================================================
# RUN ALL
# =============================================================================

func run_all() -> bool:
	var tests: Array[Callable] = [
		test_enum_coverage,
		test_volume_clamping,
		test_enable_disable,
		test_pool_size,
		test_active_count_initial,
		test_has_sound_invalid,
		test_volume_map_coverage,
		test_stop_all,
	]

	var passed: int = 0
	var failed: int = 0

	for test_fn in tests:
		var result: bool = test_fn.call()
		if result:
			passed += 1
		else:
			failed += 1
			push_error("[SFXEngine Tests] FAILED: %s" % test_fn.get_method())

	print("[SFXEngine Tests] %d passed, %d failed out of %d" % [passed, failed, tests.size()])
	return failed == 0
