## =====================================================================
## BiomeParticleProfiles — Per-biome particle configurations for 3D walk
## =====================================================================
## Each biome gets a unique atmospheric personality defined by 5 layers:
##   fog, ambient_particles, accent_particles, falling, ground_mist
## Used by the walk scene particle system to spawn GPU particles.
## =====================================================================

extends RefCounted
class_name BiomeParticleProfiles


## Returns the particle profile for the given biome.
## Falls back to foret_broceliande if the key is unknown.
static func get_profile(biome_key: String) -> Dictionary:
	match biome_key:
		"foret_broceliande":
			return _foret_broceliande()
		"landes_bruyere":
			return _landes_bruyere()
		"cotes_sauvages":
			return _cotes_sauvages()
		"villages_celtes":
			return _villages_celtes()
		"cercles_pierres":
			return _cercles_pierres()
		"marais_korrigans":
			return _marais_korrigans()
		"collines_dolmens":
			return _collines_dolmens()
		"iles_mystiques":
			return _iles_mystiques()
		_:
			return _default_profile()


## Default fallback — returns foret_broceliande config.
static func _default_profile() -> Dictionary:
	return _foret_broceliande()


# ═══════════════════════════════════════════════════════════════════════════════
# HELPER — Builds a single particle layer config with all required fields.
# ═══════════════════════════════════════════════════════════════════════════════

static func _make_particle(
	color: Color,
	amount: int,
	lifetime: float,
	size_min: float,
	size_max: float,
	velocity_min: float,
	velocity_max: float,
	direction: Vector3,
	spread: float,
	gravity: Vector3,
	emission_box: Vector3,
	draw_color: Color,
	emission_glow: bool,
	emission_color: Color,
	emission_energy: float,
	billboard: bool,
) -> Dictionary:
	return {
		"color": color,
		"amount": amount,
		"lifetime": lifetime,
		"size_min": size_min,
		"size_max": size_max,
		"velocity_min": velocity_min,
		"velocity_max": velocity_max,
		"direction": direction,
		"spread": spread,
		"gravity": gravity,
		"emission_box": emission_box,
		"draw_color": draw_color,
		"emission_glow": emission_glow,
		"emission_color": emission_color,
		"emission_energy": emission_energy,
		"billboard": billboard,
	}


## Returns an empty layer dict (used when a biome has no particles for a slot).
static func _empty_layer() -> Dictionary:
	return {}


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME 1 — foret_broceliande (spring forest)
# ═══════════════════════════════════════════════════════════════════════════════

static func _foret_broceliande() -> Dictionary:
	return {
		"fog": _make_particle(
			Color(0.35, 0.45, 0.35, 0.08), 30, 8.0,
			3.0, 6.0,
			0.1, 0.4,
			Vector3(0.2, 0.0, 0.1), 45.0,
			Vector3.ZERO,
			Vector3(12.0, 2.0, 12.0),
			Color(0.35, 0.45, 0.35, 0.08),
			false, Color.WHITE, 0.0,
			true,
		),
		"ambient_particles": _make_particle(
			Color(0.90, 0.85, 0.60, 0.3), 120, 6.0,
			0.02, 0.06,
			0.1, 0.5,
			Vector3(0.3, 0.1, 0.2), 180.0,
			Vector3(0.0, -0.02, 0.0),
			Vector3(10.0, 4.0, 10.0),
			Color(0.90, 0.85, 0.60, 0.3),
			false, Color.WHITE, 0.0,
			true,
		),
		"accent_particles": _make_particle(
			Color(0.55, 0.90, 0.35, 0.8), 12, 4.0,
			0.04, 0.08,
			0.05, 0.2,
			Vector3(0.0, 0.1, 0.0), 360.0,
			Vector3.ZERO,
			Vector3(14.0, 3.0, 14.0),
			Color(0.55, 0.90, 0.35, 0.8),
			true, Color(0.55, 0.90, 0.35), 1.5,
			true,
		),
		"falling": _make_particle(
			Color(0.5, 0.35, 0.15, 1.0), 12, 5.0,
			0.05, 0.12,
			0.3, 0.8,
			Vector3(0.2, -1.0, 0.1), 25.0,
			Vector3(0.0, -0.5, 0.0),
			Vector3(14.0, 0.5, 14.0),
			Color(0.5, 0.35, 0.15, 1.0),
			false, Color.WHITE, 0.0,
			true,
		),
		"ground_mist": _make_particle(
			Color(0.3, 0.4, 0.3, 0.04), 20, 10.0,
			4.0, 8.0,
			0.05, 0.15,
			Vector3(0.1, 0.0, 0.05), 30.0,
			Vector3.ZERO,
			Vector3(14.0, 0.3, 14.0),
			Color(0.3, 0.4, 0.3, 0.04),
			false, Color.WHITE, 0.0,
			true,
		),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME 2 — landes_bruyere (autumn heathland)
# ═══════════════════════════════════════════════════════════════════════════════

static func _landes_bruyere() -> Dictionary:
	return {
		"fog": _make_particle(
			Color(0.45, 0.38, 0.30, 0.06), 20, 9.0,
			3.0, 7.0,
			0.1, 0.3,
			Vector3(0.3, 0.0, 0.15), 40.0,
			Vector3.ZERO,
			Vector3(14.0, 2.0, 14.0),
			Color(0.45, 0.38, 0.30, 0.06),
			false, Color.WHITE, 0.0,
			true,
		),
		"ambient_particles": _make_particle(
			Color(0.6, 0.5, 0.4, 0.25), 80, 5.0,
			0.01, 0.04,
			0.5, 1.5,
			Vector3(1.0, 0.05, 0.3), 60.0,
			Vector3(0.0, -0.03, 0.0),
			Vector3(16.0, 3.0, 16.0),
			Color(0.6, 0.5, 0.4, 0.25),
			false, Color.WHITE, 0.0,
			true,
		),
		"accent_particles": _empty_layer(),
		"falling": _make_particle(
			Color(0.6, 0.3, 0.5, 1.0), 8, 7.0,
			0.03, 0.08,
			0.1, 0.3,
			Vector3(0.15, -1.0, 0.1), 20.0,
			Vector3(0.0, -0.25, 0.0),
			Vector3(12.0, 0.5, 12.0),
			Color(0.6, 0.3, 0.5, 1.0),
			false, Color.WHITE, 0.0,
			true,
		),
		"ground_mist": _make_particle(
			Color(0.4, 0.35, 0.28, 0.03), 15, 12.0,
			3.0, 6.0,
			0.03, 0.1,
			Vector3(0.1, 0.0, 0.05), 25.0,
			Vector3.ZERO,
			Vector3(14.0, 0.25, 14.0),
			Color(0.4, 0.35, 0.28, 0.03),
			false, Color.WHITE, 0.0,
			true,
		),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME 3 — cotes_sauvages (summer coast)
# ═══════════════════════════════════════════════════════════════════════════════

static func _cotes_sauvages() -> Dictionary:
	return {
		"fog": _make_particle(
			Color(0.55, 0.60, 0.65, 0.07), 25, 8.0,
			3.5, 7.0,
			0.15, 0.5,
			Vector3(0.4, 0.0, 0.2), 50.0,
			Vector3.ZERO,
			Vector3(16.0, 2.5, 16.0),
			Color(0.55, 0.60, 0.65, 0.07),
			false, Color.WHITE, 0.0,
			true,
		),
		"ambient_particles": _make_particle(
			Color(0.85, 0.90, 0.95, 0.35), 150, 3.0,
			0.01, 0.03,
			1.5, 4.0,
			Vector3(1.0, 0.1, 0.5), 45.0,
			Vector3(0.0, -0.1, 0.0),
			Vector3(18.0, 3.0, 18.0),
			Color(0.85, 0.90, 0.95, 0.35),
			false, Color.WHITE, 0.0,
			true,
		),
		"accent_particles": _make_particle(
			Color(0.9, 0.95, 1.0, 0.6), 20, 2.5,
			0.02, 0.05,
			0.5, 1.5,
			Vector3(0.8, 0.0, 0.3), 70.0,
			Vector3(0.0, -0.05, 0.0),
			Vector3(16.0, 0.8, 16.0),
			Color(0.9, 0.95, 1.0, 0.6),
			false, Color.WHITE, 0.0,
			true,
		),
		"falling": _empty_layer(),
		"ground_mist": _make_particle(
			Color(0.5, 0.55, 0.6, 0.05), 18, 10.0,
			3.5, 7.0,
			0.05, 0.2,
			Vector3(0.3, 0.0, 0.1), 30.0,
			Vector3.ZERO,
			Vector3(16.0, 0.3, 16.0),
			Color(0.5, 0.55, 0.6, 0.05),
			false, Color.WHITE, 0.0,
			true,
		),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME 4 — villages_celtes (summer village)
# ═══════════════════════════════════════════════════════════════════════════════

static func _villages_celtes() -> Dictionary:
	return {
		"fog": _make_particle(
			Color(0.5, 0.45, 0.35, 0.05), 15, 10.0,
			3.0, 6.0,
			0.05, 0.2,
			Vector3(0.1, 0.0, 0.05), 35.0,
			Vector3.ZERO,
			Vector3(10.0, 2.0, 10.0),
			Color(0.5, 0.45, 0.35, 0.05),
			false, Color.WHITE, 0.0,
			true,
		),
		"ambient_particles": _make_particle(
			Color(0.9, 0.6, 0.2, 0.4), 40, 4.0,
			0.02, 0.05,
			0.3, 1.0,
			Vector3(0.1, 1.0, 0.1), 90.0,
			Vector3(0.0, 0.1, 0.0),
			Vector3(8.0, 5.0, 8.0),
			Color(0.9, 0.6, 0.2, 0.4),
			true, Color(0.95, 0.6, 0.15), 2.0,
			true,
		),
		"accent_particles": _make_particle(
			Color(0.85, 0.7, 0.3, 0.7), 8, 3.0,
			0.05, 0.10,
			0.05, 0.15,
			Vector3(0.0, 0.2, 0.0), 360.0,
			Vector3.ZERO,
			Vector3(6.0, 2.0, 6.0),
			Color(0.85, 0.7, 0.3, 0.7),
			true, Color(0.9, 0.75, 0.3), 3.0,
			true,
		),
		"falling": _make_particle(
			Color(0.4, 0.35, 0.3, 1.0), 6, 4.0,
			0.01, 0.03,
			0.2, 0.6,
			Vector3(0.1, -1.0, 0.05), 15.0,
			Vector3(0.0, -0.4, 0.0),
			Vector3(10.0, 0.5, 10.0),
			Color(0.4, 0.35, 0.3, 1.0),
			false, Color.WHITE, 0.0,
			true,
		),
		"ground_mist": _make_particle(
			Color(0.45, 0.40, 0.32, 0.02), 10, 12.0,
			3.0, 6.0,
			0.02, 0.08,
			Vector3(0.05, 0.0, 0.02), 20.0,
			Vector3.ZERO,
			Vector3(12.0, 0.2, 12.0),
			Color(0.45, 0.40, 0.32, 0.02),
			false, Color.WHITE, 0.0,
			true,
		),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME 5 — cercles_pierres (winter stone circles)
# ═══════════════════════════════════════════════════════════════════════════════

static func _cercles_pierres() -> Dictionary:
	return {
		"fog": _make_particle(
			Color(0.45, 0.45, 0.50, 0.10), 35, 10.0,
			4.0, 8.0,
			0.08, 0.3,
			Vector3(0.1, 0.0, 0.1), 50.0,
			Vector3.ZERO,
			Vector3(14.0, 3.0, 14.0),
			Color(0.45, 0.45, 0.50, 0.10),
			false, Color.WHITE, 0.0,
			true,
		),
		"ambient_particles": _make_particle(
			Color(0.6, 0.7, 0.85, 0.3), 60, 7.0,
			0.03, 0.07,
			0.08, 0.25,
			Vector3(0.0, 0.05, 0.0), 360.0,
			Vector3.ZERO,
			Vector3(12.0, 4.0, 12.0),
			Color(0.6, 0.7, 0.85, 0.3),
			false, Color.WHITE, 0.0,
			true,
		),
		"accent_particles": _make_particle(
			Color(0.5, 0.6, 0.9, 0.6), 15, 3.5,
			0.02, 0.05,
			0.05, 0.15,
			Vector3(0.0, 0.1, 0.0), 360.0,
			Vector3.ZERO,
			Vector3(8.0, 2.0, 8.0),
			Color(0.5, 0.6, 0.9, 0.6),
			true, Color(0.5, 0.6, 0.95), 2.0,
			true,
		),
		"falling": _make_particle(
			Color(0.85, 0.85, 0.90, 1.0), 20, 8.0,
			0.01, 0.04,
			0.1, 0.4,
			Vector3(0.2, -1.0, 0.15), 50.0,
			Vector3(0.0, -0.15, 0.0),
			Vector3(18.0, 0.5, 18.0),
			Color(0.85, 0.85, 0.90, 1.0),
			false, Color.WHITE, 0.0,
			true,
		),
		"ground_mist": _make_particle(
			Color(0.35, 0.35, 0.40, 0.06), 22, 12.0,
			4.0, 8.0,
			0.04, 0.12,
			Vector3(0.1, 0.0, 0.05), 30.0,
			Vector3.ZERO,
			Vector3(14.0, 0.3, 14.0),
			Color(0.35, 0.35, 0.40, 0.06),
			false, Color.WHITE, 0.0,
			true,
		),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME 6 — marais_korrigans (autumn swamp)
# ═══════════════════════════════════════════════════════════════════════════════

static func _marais_korrigans() -> Dictionary:
	return {
		"fog": _make_particle(
			Color(0.30, 0.45, 0.30, 0.12), 50, 12.0,
			5.0, 10.0,
			0.05, 0.2,
			Vector3(0.1, 0.0, 0.05), 40.0,
			Vector3.ZERO,
			Vector3(16.0, 3.0, 16.0),
			Color(0.30, 0.45, 0.30, 0.12),
			false, Color.WHITE, 0.0,
			true,
		),
		"ambient_particles": _make_particle(
			Color(0.4, 0.5, 0.3, 0.2), 40, 6.0,
			0.03, 0.08,
			0.05, 0.2,
			Vector3(0.0, 1.0, 0.0), 30.0,
			Vector3(0.0, 0.05, 0.0),
			Vector3(12.0, 2.0, 12.0),
			Color(0.4, 0.5, 0.3, 0.2),
			false, Color.WHITE, 0.0,
			true,
		),
		"accent_particles": _make_particle(
			Color(0.6, 0.85, 0.25, 0.85), 10, 5.0,
			0.06, 0.12,
			0.1, 0.6,
			Vector3(0.3, 0.2, 0.3), 360.0,
			Vector3.ZERO,
			Vector3(16.0, 3.0, 16.0),
			Color(0.6, 0.85, 0.25, 0.85),
			true, Color(0.6, 0.9, 0.2), 4.0,
			true,
		),
		"falling": _make_particle(
			Color(0.4, 0.5, 0.4, 1.0), 8, 2.0,
			0.01, 0.02,
			1.0, 2.5,
			Vector3(0.0, -1.0, 0.0), 10.0,
			Vector3(0.0, -2.0, 0.0),
			Vector3(10.0, 0.3, 10.0),
			Color(0.4, 0.5, 0.4, 1.0),
			false, Color.WHITE, 0.0,
			true,
		),
		"ground_mist": _make_particle(
			Color(0.25, 0.35, 0.25, 0.08), 30, 14.0,
			5.0, 10.0,
			0.03, 0.1,
			Vector3(0.05, 0.0, 0.03), 25.0,
			Vector3.ZERO,
			Vector3(16.0, 0.4, 16.0),
			Color(0.25, 0.35, 0.25, 0.08),
			false, Color.WHITE, 0.0,
			true,
		),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME 7 — collines_dolmens (spring/winter hills)
# ═══════════════════════════════════════════════════════════════════════════════

static func _collines_dolmens() -> Dictionary:
	return {
		"fog": _make_particle(
			Color(0.42, 0.40, 0.35, 0.07), 22, 9.0,
			3.5, 7.0,
			0.1, 0.35,
			Vector3(0.3, 0.0, 0.15), 45.0,
			Vector3.ZERO,
			Vector3(14.0, 2.5, 14.0),
			Color(0.42, 0.40, 0.35, 0.07),
			false, Color.WHITE, 0.0,
			true,
		),
		"ambient_particles": _make_particle(
			Color(0.55, 0.50, 0.42, 0.2), 50, 5.0,
			0.01, 0.04,
			0.6, 1.8,
			Vector3(1.0, 0.05, 0.4), 55.0,
			Vector3(0.0, -0.02, 0.0),
			Vector3(16.0, 3.0, 16.0),
			Color(0.55, 0.50, 0.42, 0.2),
			false, Color.WHITE, 0.0,
			true,
		),
		"accent_particles": _make_particle(
			Color(0.8, 0.75, 0.65, 0.5), 6, 4.5,
			0.04, 0.08,
			0.05, 0.2,
			Vector3(0.0, 0.15, 0.0), 360.0,
			Vector3.ZERO,
			Vector3(6.0, 2.0, 6.0),
			Color(0.8, 0.75, 0.65, 0.5),
			true, Color(0.85, 0.8, 0.7), 1.5,
			true,
		),
		"falling": _make_particle(
			Color(0.4, 0.35, 0.28, 1.0), 4, 3.0,
			0.005, 0.015,
			0.5, 1.2,
			Vector3(0.1, -1.0, 0.05), 15.0,
			Vector3(0.0, -1.0, 0.0),
			Vector3(10.0, 0.3, 10.0),
			Color(0.4, 0.35, 0.28, 1.0),
			false, Color.WHITE, 0.0,
			true,
		),
		"ground_mist": _make_particle(
			Color(0.38, 0.35, 0.30, 0.03), 12, 11.0,
			3.0, 6.0,
			0.03, 0.1,
			Vector3(0.1, 0.0, 0.05), 25.0,
			Vector3.ZERO,
			Vector3(14.0, 0.25, 14.0),
			Color(0.38, 0.35, 0.30, 0.03),
			false, Color.WHITE, 0.0,
			true,
		),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME 8 — iles_mystiques (ethereal islands)
# ═══════════════════════════════════════════════════════════════════════════════

static func _iles_mystiques() -> Dictionary:
	return {
		"fog": _make_particle(
			Color(0.5, 0.55, 0.65, 0.10), 40, 10.0,
			4.0, 8.0,
			0.08, 0.3,
			Vector3(0.15, 0.0, 0.1), 50.0,
			Vector3.ZERO,
			Vector3(16.0, 3.0, 16.0),
			Color(0.5, 0.55, 0.65, 0.10),
			false, Color.WHITE, 0.0,
			true,
		),
		"ambient_particles": _make_particle(
			Color(0.6, 0.75, 0.9, 0.3), 100, 7.0,
			0.02, 0.06,
			0.08, 0.3,
			Vector3(0.0, 1.0, 0.0), 120.0,
			Vector3(0.0, 0.03, 0.0),
			Vector3(14.0, 5.0, 14.0),
			Color(0.6, 0.75, 0.9, 0.3),
			true, Color(0.6, 0.8, 0.95), 1.5,
			true,
		),
		"accent_particles": _make_particle(
			Color(0.9, 0.8, 0.5, 0.7), 25, 4.0,
			0.03, 0.07,
			0.1, 0.4,
			Vector3(0.0, 0.1, 0.0), 360.0,
			Vector3.ZERO,
			Vector3(10.0, 3.0, 10.0),
			Color(0.9, 0.8, 0.5, 0.7),
			true, Color(0.95, 0.85, 0.5), 4.0,
			true,
		),
		"falling": _make_particle(
			Color(0.7, 0.7, 0.8, 1.0), 10, 10.0,
			0.03, 0.08,
			0.05, 0.15,
			Vector3(0.1, -1.0, 0.05), 30.0,
			Vector3(0.0, -0.08, 0.0),
			Vector3(14.0, 0.5, 14.0),
			Color(0.7, 0.7, 0.8, 1.0),
			false, Color.WHITE, 0.0,
			true,
		),
		"ground_mist": _make_particle(
			Color(0.4, 0.45, 0.55, 0.07), 25, 12.0,
			4.0, 8.0,
			0.04, 0.15,
			Vector3(0.1, 0.0, 0.05), 30.0,
			Vector3.ZERO,
			Vector3(16.0, 0.35, 16.0),
			Color(0.4, 0.45, 0.55, 0.07),
			false, Color.WHITE, 0.0,
			true,
		),
	}
