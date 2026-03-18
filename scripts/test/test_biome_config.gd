## =============================================================================
## Unit Tests — BiomeConfig visual presets (headless-safe, RefCounted)
## =============================================================================
## Covers: all 8 biomes have configs, color validity, fog density bounds,
##         ambient energy bounds, tree density bounds, particle types,
##         unknown biome fallback, factory immutability, display names.
## Converted from GutTest to RefCounted for headless runner compatibility.
## =============================================================================

extends RefCounted


func _fail(msg: String) -> bool:
	push_error(msg)
	return false


func _color_valid(color: Color, label: String) -> bool:
	if color.r < 0.0 or color.r > 1.0 or color.g < 0.0 or color.g > 1.0 or color.b < 0.0 or color.b > 1.0:
		return _fail("%s color channel out of [0,1]: %s" % [label, str(color)])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# ALL 8 BIOMES HAVE CONFIGS
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_8_biomes_have_configs() -> bool:
	var ids: Array[String] = BiomeConfig.get_all_biome_ids()
	if ids.size() != 8:
		return _fail("expected 8 biome IDs, got %d" % ids.size())
	return true


func test_all_biome_ids_match_constants() -> bool:
	var config_ids: Array[String] = BiomeConfig.get_all_biome_ids()
	for key: String in MerlinConstants.BIOME_KEYS:
		if key not in config_ids:
			return _fail("BiomeConfig missing preset for: %s" % key)
	return true


func test_has_config_returns_true_for_all_known() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		if not BiomeConfig.has_config(key):
			return _fail("has_config(%s) should be true" % key)
	return true


func test_get_config_returns_non_null_for_all() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		if config == null:
			return _fail("get_config(%s) returned null" % key)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME ID AND DISPLAY NAME
# ═══════════════════════════════════════════════════════════════════════════════

func test_each_config_has_matching_biome_id() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		if config.biome_id != key:
			return _fail("config biome_id '%s' != key '%s'" % [config.biome_id, key])
	return true


func test_each_config_has_non_empty_display_name() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		var config: BiomeConfig = BiomeConfig.get_config(key)
		if config.display_name.length() == 0:
			return _fail("config %s has empty display_name" % key)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# COLOR VALIDITY
# ═══════════════════════════════════════════════════════════════════════════════

func test_sky_colors_valid() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		if not _color_valid(BiomeConfig.get_config(key).sky_color, "%s sky" % key):
			return false
	return true


func test_ground_colors_valid() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		if not _color_valid(BiomeConfig.get_config(key).ground_color, "%s ground" % key):
			return false
	return true


func test_fog_colors_valid() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		if not _color_valid(BiomeConfig.get_config(key).fog_color, "%s fog" % key):
			return false
	return true


func test_ambient_light_colors_valid() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		if not _color_valid(BiomeConfig.get_config(key).ambient_light_color, "%s ambient" % key):
			return false
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FOG DENSITY BOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_fog_density_within_bounds() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		var d: float = BiomeConfig.get_config(key).fog_density
		if d < BiomeConfig.FOG_DENSITY_MIN or d > BiomeConfig.FOG_DENSITY_MAX:
			return _fail("%s fog_density %s out of bounds" % [key, str(d)])
	return true


func test_marais_has_thickest_fog() -> bool:
	var marais_fog: float = BiomeConfig.get_config("marais_korrigans").fog_density
	for key: String in MerlinConstants.BIOME_KEYS:
		if BiomeConfig.get_config(key).fog_density > marais_fog:
			return _fail("marais should have thickest fog, but %s has more" % key)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# AMBIENT ENERGY BOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_ambient_energy_within_bounds() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		var e: float = BiomeConfig.get_config(key).ambient_light_energy
		if e < BiomeConfig.AMBIENT_ENERGY_MIN or e > BiomeConfig.AMBIENT_ENERGY_MAX:
			return _fail("%s ambient_energy %s out of bounds" % [key, str(e)])
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# TREE DENSITY BOUNDS
# ═══════════════════════════════════════════════════════════════════════════════

func test_tree_density_within_bounds() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		var d: float = BiomeConfig.get_config(key).tree_density
		if d < BiomeConfig.TREE_DENSITY_MIN or d > BiomeConfig.TREE_DENSITY_MAX:
			return _fail("%s tree_density %s out of bounds" % [key, str(d)])
	return true


func test_broceliande_has_highest_tree_density() -> bool:
	var broc_d: float = BiomeConfig.get_config("foret_broceliande").tree_density
	for key: String in MerlinConstants.BIOME_KEYS:
		if BiomeConfig.get_config(key).tree_density > broc_d:
			return _fail("broceliande should have highest tree density, but %s has more" % key)
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# PARTICLE TYPES
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_particle_types_are_valid() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		var pt: String = BiomeConfig.get_config(key).particle_type
		if pt not in BiomeConfig.VALID_PARTICLE_TYPES:
			return _fail("%s particle_type '%s' not in valid types" % [key, pt])
	return true


func test_at_least_one_biome_has_rain() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		if BiomeConfig.get_config(key).particle_type == "rain":
			return true
	return _fail("no biome uses rain particles")


func test_at_least_one_biome_has_mist() -> bool:
	for key: String in MerlinConstants.BIOME_KEYS:
		if BiomeConfig.get_config(key).particle_type == "mist":
			return true
	return _fail("no biome uses mist particles")


# ═══════════════════════════════════════════════════════════════════════════════
# UNKNOWN BIOME FALLBACK
# ═══════════════════════════════════════════════════════════════════════════════

func test_unknown_biome_returns_default() -> bool:
	var config: BiomeConfig = BiomeConfig.get_config("nonexistent_biome_xyz")
	if config == null:
		return _fail("unknown biome should return default, got null")
	if config.biome_id != "foret_broceliande":
		return _fail("unknown biome should fallback to foret_broceliande, got %s" % config.biome_id)
	return true


func test_has_config_false_for_unknown() -> bool:
	if BiomeConfig.has_config("unknown_biome"):
		return _fail("has_config should be false for unknown biome")
	return true


func test_empty_string_biome_returns_default() -> bool:
	var config: BiomeConfig = BiomeConfig.get_config("")
	if config.biome_id != "foret_broceliande":
		return _fail("empty string should fallback to foret_broceliande")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# FACTORY IMMUTABILITY
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_config_returns_independent_instances() -> bool:
	var a: BiomeConfig = BiomeConfig.get_config("foret_broceliande")
	var b: BiomeConfig = BiomeConfig.get_config("foret_broceliande")
	a.fog_density = 0.999
	if b.fog_density >= 0.999:
		return _fail("modifying one config should not affect another")
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# DISTINCT CONFIGS
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_biomes_have_distinct_sky_colors() -> bool:
	var seen: Array[Color] = []
	for key: String in MerlinConstants.BIOME_KEYS:
		var c: Color = BiomeConfig.get_config(key).sky_color
		for prev: Color in seen:
			if c.is_equal_approx(prev):
				return _fail("%s has duplicate sky_color" % key)
		seen.append(c)
	return true
