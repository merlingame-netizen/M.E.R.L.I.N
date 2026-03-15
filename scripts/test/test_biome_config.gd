# test_biome_config.gd
# GUT Unit Tests for BiomeConfig visual presets
# Covers: all 8 biomes have configs, color validity, fog density bounds,
#         ambient energy bounds, tree density bounds, particle types,
#         unknown biome fallback, factory immutability, display names.

extends GutTest


# ═══════════════════════════════════════════════════════════════════════════════
# ALL 8 BIOMES HAVE CONFIGS
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_8_biomes_have_configs():
	var biome_ids: Array[String] = BiomeConfig.get_all_biome_ids()
	assert_eq(biome_ids.size(), 8, "BiomeConfig defines exactly 8 biome IDs")


func test_all_biome_ids_match_constants():
	var config_ids: Array[String] = BiomeConfig.get_all_biome_ids()
	for key: String in MerlinConstants.BIOME_KEYS:
		assert_true(key in config_ids, "BiomeConfig has preset for: " + key)


func test_has_config_returns_true_for_all_known():
	for key: String in MerlinConstants.BIOME_KEYS:
		assert_true(BiomeConfig.has_config(key), "has_config(%s) is true" % key)


func test_get_config_returns_non_null_for_all():
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		assert_not_null(config, "get_config(%s) returns non-null" % key)


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME ID AND DISPLAY NAME
# ═══════════════════════════════════════════════════════════════════════════════

func test_each_config_has_matching_biome_id():
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		assert_eq(config.biome_id, key, "Config biome_id matches key: " + key)


func test_each_config_has_non_empty_display_name():
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		assert_true(config.display_name.length() > 0,
			"Config %s has non-empty display_name" % key)


# ═══════════════════════════════════════════════════════════════════════════════
# COLOR VALIDITY — All color channels in [0.0, 1.0]
# ═══════════════════════════════════════════════════════════════════════════════

func _assert_color_valid(color: Color, label: String) -> void:
	assert_true(color.r >= 0.0 and color.r <= 1.0,
		"%s red channel in [0,1] (got %s)" % [label, color.r])
	assert_true(color.g >= 0.0 and color.g <= 1.0,
		"%s green channel in [0,1] (got %s)" % [label, color.g])
	assert_true(color.b >= 0.0 and color.b <= 1.0,
		"%s blue channel in [0,1] (got %s)" % [label, color.b])


func test_sky_colors_valid():
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		_assert_color_valid(config.sky_color, "%s sky_color" % key)


func test_ground_colors_valid():
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		_assert_color_valid(config.ground_color, "%s ground_color" % key)


func test_fog_colors_valid():
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		_assert_color_valid(config.fog_color, "%s fog_color" % key)


func test_ambient_light_colors_valid():
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		_assert_color_valid(config.ambient_light_color, "%s ambient_light_color" % key)


# ═══════════════════════════════════════════════════════════════════════════════
# FOG DENSITY BOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_fog_density_within_bounds():
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		assert_true(config.fog_density >= BiomeConfig.FOG_DENSITY_MIN,
			"%s fog_density >= %s (got %s)" % [key, BiomeConfig.FOG_DENSITY_MIN, config.fog_density])
		assert_true(config.fog_density <= BiomeConfig.FOG_DENSITY_MAX,
			"%s fog_density <= %s (got %s)" % [key, BiomeConfig.FOG_DENSITY_MAX, config.fog_density])


func test_marais_has_thickest_fog():
	var marais: BiomeConfig = BiomeConfig.get_config("marais_korrigans")
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		assert_true(marais.fog_density >= config.fog_density,
			"Marais fog >= %s fog (marais=%s, other=%s)" % [key, marais.fog_density, config.fog_density])


# ═══════════════════════════════════════════════════════════════════════════════
# AMBIENT ENERGY BOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_ambient_energy_within_bounds():
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		assert_true(config.ambient_light_energy >= BiomeConfig.AMBIENT_ENERGY_MIN,
			"%s ambient_energy >= %s (got %s)" % [key, BiomeConfig.AMBIENT_ENERGY_MIN, config.ambient_light_energy])
		assert_true(config.ambient_light_energy <= BiomeConfig.AMBIENT_ENERGY_MAX,
			"%s ambient_energy <= %s (got %s)" % [key, BiomeConfig.AMBIENT_ENERGY_MAX, config.ambient_light_energy])


# ═══════════════════════════════════════════════════════════════════════════════
# TREE DENSITY BOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_tree_density_within_bounds():
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		assert_true(config.tree_density >= BiomeConfig.TREE_DENSITY_MIN,
			"%s tree_density >= %s (got %s)" % [key, BiomeConfig.TREE_DENSITY_MIN, config.tree_density])
		assert_true(config.tree_density <= BiomeConfig.TREE_DENSITY_MAX,
			"%s tree_density <= %s (got %s)" % [key, BiomeConfig.TREE_DENSITY_MAX, config.tree_density])


func test_broceliande_has_highest_tree_density():
	var broc: BiomeConfig = BiomeConfig.get_config("foret_broceliande")
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		assert_true(broc.tree_density >= config.tree_density,
			"Broceliande tree_density >= %s (broc=%s, other=%s)" % [key, broc.tree_density, config.tree_density])


# ═══════════════════════════════════════════════════════════════════════════════
# PARTICLE TYPES
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_particle_types_are_valid():
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		assert_true(config.particle_type in BiomeConfig.VALID_PARTICLE_TYPES,
			"%s particle_type '%s' is valid" % [key, config.particle_type])


func test_at_least_one_biome_has_rain():
	var found_rain: bool = false
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		if config.particle_type == "rain":
			found_rain = true
			break
	assert_true(found_rain, "At least one biome uses rain particles")


func test_at_least_one_biome_has_mist():
	var found_mist: bool = false
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		if config.particle_type == "mist":
			found_mist = true
			break
	assert_true(found_mist, "At least one biome uses mist particles")


# ═══════════════════════════════════════════════════════════════════════════════
# UNKNOWN BIOME FALLBACK
# ═══════════════════════════════════════════════════════════════════════════════

func test_unknown_biome_returns_default():
	var config: BiomeConfig = BiomeConfig.get_config("nonexistent_biome_xyz")
	assert_not_null(config, "Unknown biome returns a config (not null)")
	assert_eq(config.biome_id, "foret_broceliande",
		"Unknown biome falls back to foret_broceliande")


func test_has_config_false_for_unknown():
	assert_false(BiomeConfig.has_config("unknown_biome"),
		"has_config returns false for unknown biome")


func test_empty_string_biome_returns_default():
	var config: BiomeConfig = BiomeConfig.get_config("")
	assert_eq(config.biome_id, "foret_broceliande",
		"Empty string biome falls back to foret_broceliande")


# ═══════════════════════════════════════════════════════════════════════════════
# FACTORY IMMUTABILITY — Two calls return independent instances
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_config_returns_independent_instances():
	var config_a: BiomeConfig = BiomeConfig.get_config("foret_broceliande")
	var config_b: BiomeConfig = BiomeConfig.get_config("foret_broceliande")
	# Modify one, verify the other is unaffected
	config_a.fog_density = 0.999
	assert_true(config_b.fog_density < 0.999,
		"Modifying one config does not affect another (immutable factory)")


# ═══════════════════════════════════════════════════════════════════════════════
# DISTINCT CONFIGS — Each biome is visually unique
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_biomes_have_distinct_sky_colors():
	var seen: Array[Color] = []
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		for prev: Color in seen:
			assert_true(not config.sky_color.is_equal_approx(prev),
				"%s has distinct sky_color" % key)
		seen.append(config.sky_color)
