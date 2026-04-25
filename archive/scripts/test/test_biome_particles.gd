# test_biome_particles.gd
# GUT Unit Tests for BiomeParticles procedural particle system
# Covers: biome mapping, intensity clamping, stop behavior, unknown biome
#         fallback, valid types, multi-particle biomes, factory output.

extends GutTest


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

var _particles: BiomeParticles = null


func before_each() -> void:
	_particles = BiomeParticles.new()
	add_child(_particles)


func after_each() -> void:
	if is_instance_valid(_particles):
		_particles.queue_free()
	_particles = null


# ═══════════════════════════════════════════════════════════════════════════════
# ALL BIOMES GET VALID CONFIG
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_biomes_have_particle_mapping():
	for key: String in MerlinConstants.BIOME_KEYS:
		var types: Array = BiomeParticles.get_particle_types_for_biome(key)
		assert_true(types.size() > 0,
			"Biome '%s' has at least one particle type mapping" % key)


func test_all_mapped_types_are_valid():
	for key: String in MerlinConstants.BIOME_KEYS:
		var types: Array = BiomeParticles.get_particle_types_for_biome(key)
		for particle_type in types:
			assert_true(BiomeParticles.is_valid_particle_type(particle_type),
				"Biome '%s' particle type '%s' is valid" % [key, str(particle_type)])


func test_setup_creates_particles_for_each_biome():
	for key: String in MerlinConstants.BIOME_KEYS:
		_particles.setup_for_biome(key)
		var active_type: String = _particles.get_active_type()
		# villages_celtes has "leaves" (optional), all others have at least one
		assert_true(active_type != "" ,
			"Biome '%s' produces non-empty active_type: '%s'" % [key, active_type])
		assert_eq(_particles.get_current_biome_id(), key,
			"Current biome ID matches for '%s'" % key)


# ═══════════════════════════════════════════════════════════════════════════════
# MULTI-PARTICLE BIOMES
# ═══════════════════════════════════════════════════════════════════════════════

func test_foret_broceliande_has_two_particle_types():
	var types: Array = BiomeParticles.get_particle_types_for_biome("foret_broceliande")
	assert_eq(types.size(), 2, "foret_broceliande has 2 particle types")
	assert_true("mist" in types, "foret_broceliande includes mist")
	assert_true("fireflies" in types, "foret_broceliande includes fireflies")


func test_iles_mystiques_has_two_particle_types():
	var types: Array = BiomeParticles.get_particle_types_for_biome("iles_mystiques")
	assert_eq(types.size(), 2, "iles_mystiques has 2 particle types")
	assert_true("rain" in types, "iles_mystiques includes rain")
	assert_true("mist" in types, "iles_mystiques includes mist")


func test_setup_foret_creates_two_systems():
	_particles.setup_for_biome("foret_broceliande")
	var active: String = _particles.get_active_type()
	assert_true(active.contains("mist"), "Active types contain mist")
	assert_true(active.contains("fireflies"), "Active types contain fireflies")


# ═══════════════════════════════════════════════════════════════════════════════
# INTENSITY CLAMPING
# ═══════════════════════════════════════════════════════════════════════════════

func test_intensity_default_is_one():
	_particles.setup_for_biome("cotes_sauvages")
	assert_eq(_particles.get_intensity(), 1.0,
		"Default intensity is 1.0")


func test_intensity_clamps_above_one():
	_particles.setup_for_biome("cotes_sauvages")
	_particles.set_intensity(2.5)
	assert_eq(_particles.get_intensity(), 1.0,
		"Intensity clamped to 1.0 when set above max")


func test_intensity_clamps_below_zero():
	_particles.setup_for_biome("cotes_sauvages")
	_particles.set_intensity(-0.5)
	assert_eq(_particles.get_intensity(), 0.0,
		"Intensity clamped to 0.0 when set below min")


func test_intensity_valid_value():
	_particles.setup_for_biome("cotes_sauvages")
	_particles.set_intensity(0.5)
	assert_eq(_particles.get_intensity(), 0.5,
		"Intensity set to 0.5 correctly")


func test_intensity_zero_stops_emitting():
	_particles.setup_for_biome("cotes_sauvages")
	_particles.set_intensity(0.0)
	assert_false(_particles.is_active(),
		"Setting intensity to 0 stops emission")


func test_intensity_restore_after_zero():
	_particles.setup_for_biome("cotes_sauvages")
	_particles.set_intensity(0.0)
	_particles.set_intensity(0.8)
	assert_true(_particles.is_active(),
		"Restoring intensity re-enables emission")


# ═══════════════════════════════════════════════════════════════════════════════
# STOP BEHAVIOR
# ═══════════════════════════════════════════════════════════════════════════════

func test_stop_on_empty_emits_signal():
	# No biome setup, stop should still emit signal
	watch_signals(_particles)
	_particles.stop()
	assert_signal_emitted(_particles, "particles_stopped",
		"stop() emits particles_stopped even with no active particles")


func test_stop_begins_fade():
	_particles.setup_for_biome("landes_bruyere")
	assert_true(_particles.is_active(), "Particles active before stop")
	_particles.stop()
	# After stop() is called, fade tween is created but particles still exist
	# until tween completes. We verify stop was initiated.
	assert_eq(_particles.get_current_biome_id(), "landes_bruyere",
		"Biome ID still set during fade")


# ═══════════════════════════════════════════════════════════════════════════════
# UNKNOWN BIOME FALLBACK
# ═══════════════════════════════════════════════════════════════════════════════

func test_unknown_biome_returns_default_particles():
	var types: Array = BiomeParticles.get_particle_types_for_biome("nonexistent_biome")
	assert_eq(types.size(), 1, "Unknown biome gets 1 default particle type")
	assert_eq(types[0], "mist", "Unknown biome defaults to mist")


func test_empty_string_biome_returns_default():
	var types: Array = BiomeParticles.get_particle_types_for_biome("")
	assert_eq(types[0], "mist", "Empty string biome defaults to mist")


func test_setup_unknown_biome_still_works():
	_particles.setup_for_biome("totally_unknown")
	assert_true(_particles.get_active_type() != "none",
		"Unknown biome still creates particles (default fallback)")


# ═══════════════════════════════════════════════════════════════════════════════
# VALID PARTICLE TYPES
# ═══════════════════════════════════════════════════════════════════════════════

func test_all_seven_effect_types_are_valid():
	var expected: Array[String] = ["rain", "fireflies", "mist", "snow", "leaves", "embers", "spores"]
	for t: String in expected:
		assert_true(BiomeParticles.is_valid_particle_type(t),
			"'%s' is a valid particle type" % t)


func test_none_is_valid_type():
	assert_true(BiomeParticles.is_valid_particle_type("none"),
		"'none' is a valid particle type")


func test_invalid_type_rejected():
	assert_false(BiomeParticles.is_valid_particle_type("lightning"),
		"'lightning' is not a valid particle type")


# ═══════════════════════════════════════════════════════════════════════════════
# SPECIFIC BIOME MAPPINGS
# ═══════════════════════════════════════════════════════════════════════════════

func test_cercles_pierres_has_embers():
	var types: Array = BiomeParticles.get_particle_types_for_biome("cercles_pierres")
	assert_true("embers" in types, "cercles_pierres uses embers")


func test_collines_dolmens_has_leaves():
	var types: Array = BiomeParticles.get_particle_types_for_biome("collines_dolmens")
	assert_true("leaves" in types, "collines_dolmens uses leaves")


func test_marais_korrigans_has_mist():
	var types: Array = BiomeParticles.get_particle_types_for_biome("marais_korrigans")
	assert_true("mist" in types, "marais_korrigans uses mist")


# ═══════════════════════════════════════════════════════════════════════════════
# SETUP REPLACES PREVIOUS
# ═══════════════════════════════════════════════════════════════════════════════

func test_setup_replaces_previous_biome():
	_particles.setup_for_biome("cotes_sauvages")
	assert_eq(_particles.get_current_biome_id(), "cotes_sauvages")

	_particles.setup_for_biome("landes_bruyere")
	assert_eq(_particles.get_current_biome_id(), "landes_bruyere",
		"Setup replaces previous biome")
	assert_false(_particles.get_active_type().contains("rain"),
		"Previous rain particles cleared")


# ═══════════════════════════════════════════════════════════════════════════════
# SIGNAL EMISSION
# ═══════════════════════════════════════════════════════════════════════════════

func test_setup_emits_particles_started():
	watch_signals(_particles)
	_particles.setup_for_biome("cercles_pierres")
	assert_signal_emitted_with_parameters(
		_particles, "particles_started", ["cercles_pierres"],
		"setup_for_biome emits particles_started with biome_id")
