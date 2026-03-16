## test_pixel_transition_config.gd
## Unit tests for PixelTransitionConfig — RefCounted pattern, no GUT dependency.
## Covers: DEFAULT keys, get_profile defaults, scene overrides, unknown scene fallback,
##         immutability, CascadeOrder enum, skip flags, SFX keys, numeric bounds.
## Pattern: extends RefCounted, func test_xxx() -> bool, push_error+return false.

extends RefCounted


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

const EXPECTED_DEFAULT_KEYS: Array[String] = [
	"block_size", "exit_duration", "enter_duration",
	"exit_scatter_y_min", "exit_scatter_y_max", "exit_scatter_x",
	"enter_spawn_y_min", "enter_spawn_y_max", "enter_spawn_x",
	"batch_size", "batch_delay", "cascade_order", "cascade_mode",
	"row_stagger", "rain_jitter", "input_unlock_progress",
	"skip_exit", "skip_enter", "sfx_scatter", "sfx_assemble", "bg_color",
]


static func _approx_eq(a: float, b: float, epsilon: float = 0.001) -> bool:
	return absf(a - b) < epsilon


# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT DICTIONARY COMPLETENESS
# ═══════════════════════════════════════════════════════════════════════════════

func test_default_has_all_expected_keys() -> bool:
	for key: String in EXPECTED_DEFAULT_KEYS:
		if not PixelTransitionConfig.DEFAULT.has(key):
			push_error("DEFAULT missing key: " + key)
			return false
	return true


func test_default_key_count_matches() -> bool:
	var actual: int = PixelTransitionConfig.DEFAULT.size()
	var expected: int = EXPECTED_DEFAULT_KEYS.size()
	if actual != expected:
		push_error("DEFAULT has %d keys, expected %d" % [actual, expected])
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DEFAULT VALUES
# ═══════════════════════════════════════════════════════════════════════════════

func test_default_block_size_is_10() -> bool:
	var val: int = PixelTransitionConfig.DEFAULT["block_size"]
	if val != 10:
		push_error("Expected block_size 10, got: %d" % val)
		return false
	return true


func test_default_cascade_order_is_isometric() -> bool:
	var val: int = PixelTransitionConfig.DEFAULT["cascade_order"]
	if val != PixelTransitionConfig.CascadeOrder.ISOMETRIC:
		push_error("Expected ISOMETRIC (0), got: %d" % val)
		return false
	return true


func test_default_cascade_mode_is_rain() -> bool:
	var val: String = PixelTransitionConfig.DEFAULT["cascade_mode"]
	if val != "rain":
		push_error("Expected cascade_mode 'rain', got: " + val)
		return false
	return true


func test_default_skip_flags_are_false() -> bool:
	var skip_exit: bool = PixelTransitionConfig.DEFAULT["skip_exit"]
	var skip_enter: bool = PixelTransitionConfig.DEFAULT["skip_enter"]
	if skip_exit:
		push_error("Expected skip_exit false, got true")
		return false
	if skip_enter:
		push_error("Expected skip_enter false, got true")
		return false
	return true


func test_default_input_unlock_progress_is_0_7() -> bool:
	var val: float = PixelTransitionConfig.DEFAULT["input_unlock_progress"]
	if not _approx_eq(val, 0.7):
		push_error("Expected input_unlock_progress 0.7, got: %f" % val)
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_profile — UNKNOWN SCENE (returns DEFAULT copy)
# ═══════════════════════════════════════════════════════════════════════════════

func test_unknown_scene_returns_default_values() -> bool:
	var profile: Dictionary = PixelTransitionConfig.get_profile("res://scenes/NonExistent.tscn")
	for key: String in EXPECTED_DEFAULT_KEYS:
		if not profile.has(key):
			push_error("Profile missing default key: " + key)
			return false
	if profile["block_size"] != PixelTransitionConfig.DEFAULT["block_size"]:
		push_error("Unknown scene block_size differs from DEFAULT")
		return false
	return true


func test_unknown_scene_returns_new_dict_not_reference() -> bool:
	var p1: Dictionary = PixelTransitionConfig.get_profile("res://unknown1.tscn")
	var p2: Dictionary = PixelTransitionConfig.get_profile("res://unknown2.tscn")
	p1["block_size"] = 999
	if p2["block_size"] == 999:
		push_error("get_profile returned same reference, expected independent copies")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# get_profile — KNOWN SCENES (overrides applied)
# ═══════════════════════════════════════════════════════════════════════════════

func test_intro_celtos_skip_both() -> bool:
	var profile: Dictionary = PixelTransitionConfig.get_profile("res://scenes/IntroCeltOS.tscn")
	if not profile["skip_exit"]:
		push_error("IntroCeltOS should have skip_exit=true")
		return false
	if not profile["skip_enter"]:
		push_error("IntroCeltOS should have skip_enter=true")
		return false
	if profile["block_size"] != 8:
		push_error("IntroCeltOS block_size should be 8, got: %d" % profile["block_size"])
		return false
	return true


func test_menu_options_uses_random_cascade() -> bool:
	var profile: Dictionary = PixelTransitionConfig.get_profile("res://scenes/MenuOptions.tscn")
	if profile["cascade_order"] != PixelTransitionConfig.CascadeOrder.RANDOM:
		push_error("MenuOptions should use RANDOM cascade, got: %d" % profile["cascade_order"])
		return false
	return true


func test_menu_principal_enter_duration_override() -> bool:
	var profile: Dictionary = PixelTransitionConfig.get_profile("res://scenes/MenuPrincipal.tscn")
	if not _approx_eq(profile["enter_duration"], 1.0):
		push_error("MenuPrincipal enter_duration should be 1.0, got: %f" % profile["enter_duration"])
		return false
	return true


func test_override_preserves_non_overridden_defaults() -> bool:
	var profile: Dictionary = PixelTransitionConfig.get_profile("res://scenes/MenuPrincipal.tscn")
	# MenuPrincipal only overrides block_size and enter_duration — others should match DEFAULT
	var default_exit: float = PixelTransitionConfig.DEFAULT["exit_duration"]
	if not _approx_eq(profile["exit_duration"], default_exit):
		push_error("Non-overridden exit_duration should match DEFAULT (%f), got: %f" % [default_exit, profile["exit_duration"]])
		return false
	var default_sfx: String = PixelTransitionConfig.DEFAULT["sfx_scatter"]
	if profile["sfx_scatter"] != default_sfx:
		push_error("Non-overridden sfx_scatter should match DEFAULT")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# IMMUTABILITY — get_profile does not mutate DEFAULT
# ═══════════════════════════════════════════════════════════════════════════════

func test_mutating_profile_does_not_affect_default() -> bool:
	var original_block: int = PixelTransitionConfig.DEFAULT["block_size"]
	var profile: Dictionary = PixelTransitionConfig.get_profile("res://scenes/MerlinGame.tscn")
	profile["block_size"] = 999
	if PixelTransitionConfig.DEFAULT["block_size"] != original_block:
		push_error("Mutating profile changed DEFAULT — get_profile must return independent copy")
		return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# SCENE_PROFILES COVERAGE
# ═══════════════════════════════════════════════════════════════════════════════

func test_scene_profiles_all_have_block_size() -> bool:
	for path: String in PixelTransitionConfig.SCENE_PROFILES:
		var overrides: Dictionary = PixelTransitionConfig.SCENE_PROFILES[path]
		if not overrides.has("block_size"):
			push_error("SCENE_PROFILES[%s] missing block_size override" % path)
			return false
	return true


func test_scene_profiles_block_sizes_are_positive() -> bool:
	for path: String in PixelTransitionConfig.SCENE_PROFILES:
		var profile: Dictionary = PixelTransitionConfig.get_profile(path)
		var bs: int = profile["block_size"]
		if bs <= 0:
			push_error("Profile %s has non-positive block_size: %d" % [path, bs])
			return false
	return true
