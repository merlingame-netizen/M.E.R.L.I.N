class_name AmbianceData
extends RefCounted
## Parametric ambiance system for card illustrations.
## Computes sky, terrain, and atmosphere from biome + period + weather + season.
## Replaces 160 static entries (8 biomes x 4 periods x 5 weathers) with ~30 parametric bases.
## Usage: AmbianceData.compute_sky("foret_broceliande", "jour", "clair", "automne")


# ═══════════════════════════════════════════════════════════════════════════════
# SKY BASES — day/clear gradient per biome (top, mid, bottom, mid_position)
# ═══════════════════════════════════════════════════════════════════════════════

static var SKY_BASES := {
	"broceliande": {"top": Color(0.06, 0.14, 0.08), "mid": Color(0.12, 0.28, 0.14), "bottom": Color(0.18, 0.40, 0.20), "mid_pos": 0.45},
	"landes":      {"top": Color(0.10, 0.06, 0.12), "mid": Color(0.22, 0.14, 0.26), "bottom": Color(0.34, 0.22, 0.38), "mid_pos": 0.42},
	"cotes":       {"top": Color(0.06, 0.10, 0.18), "mid": Color(0.14, 0.24, 0.36), "bottom": Color(0.22, 0.36, 0.48), "mid_pos": 0.48},
	"villages":    {"top": Color(0.12, 0.08, 0.04), "mid": Color(0.26, 0.18, 0.10), "bottom": Color(0.38, 0.28, 0.16), "mid_pos": 0.45},
	"cercles":     {"top": Color(0.06, 0.06, 0.08), "mid": Color(0.16, 0.16, 0.22), "bottom": Color(0.26, 0.26, 0.34), "mid_pos": 0.43},
	"marais":      {"top": Color(0.06, 0.10, 0.08), "mid": Color(0.14, 0.22, 0.18), "bottom": Color(0.22, 0.34, 0.28), "mid_pos": 0.50},
	"collines":    {"top": Color(0.08, 0.10, 0.04), "mid": Color(0.20, 0.24, 0.12), "bottom": Color(0.32, 0.38, 0.20), "mid_pos": 0.44},
	"iles":        {"top": Color(0.04, 0.08, 0.16), "mid": Color(0.10, 0.20, 0.36), "bottom": Color(0.18, 0.32, 0.50), "mid_pos": 0.46},
}


# ═══════════════════════════════════════════════════════════════════════════════
# PERIOD MODIFIERS — aube / jour / crepuscule / nuit
# ═══════════════════════════════════════════════════════════════════════════════

static var PERIOD_MODS := {
	"aube":        {"tint": Color(1.15, 0.90, 0.75), "brightness": 0.80, "mid_shift": 0.05},
	"jour":        {"tint": Color(1.00, 1.00, 1.00), "brightness": 1.00, "mid_shift": 0.00},
	"crepuscule":  {"tint": Color(1.20, 0.80, 0.65), "brightness": 0.70, "mid_shift": 0.03},
	"nuit":        {"tint": Color(0.85, 0.90, 1.00), "brightness": 0.65, "mid_shift": -0.02},
}


# ═══════════════════════════════════════════════════════════════════════════════
# WEATHER MODIFIERS — clair / brume / pluie / orage / neige
# ═══════════════════════════════════════════════════════════════════════════════

static var WEATHER_SKY_MODS := {
	"clair":  {"fog_density": 0.00, "cloud_cover": 0.00, "rain_intensity": 0.00, "brightness": 1.00, "desaturation": 0.00, "fog_color": Color(0.60, 0.60, 0.65)},
	"brume":  {"fog_density": 0.25, "cloud_cover": 0.30, "rain_intensity": 0.00, "brightness": 0.85, "desaturation": 0.20, "fog_color": Color(0.55, 0.58, 0.55)},
	"pluie":  {"fog_density": 0.10, "cloud_cover": 0.60, "rain_intensity": 0.60, "brightness": 0.70, "desaturation": 0.30, "fog_color": Color(0.45, 0.48, 0.52)},
	"orage":  {"fog_density": 0.08, "cloud_cover": 0.85, "rain_intensity": 0.90, "brightness": 0.50, "desaturation": 0.40, "fog_color": Color(0.30, 0.32, 0.38)},
	"neige":  {"fog_density": 0.30, "cloud_cover": 0.50, "rain_intensity": 0.00, "brightness": 1.05, "desaturation": 0.35, "fog_color": Color(0.72, 0.72, 0.75)},
}


# ═══════════════════════════════════════════════════════════════════════════════
# TERRAIN BASES — silhouette shape per biome
# ═══════════════════════════════════════════════════════════════════════════════

static var TERRAIN_BASES := {
	"broceliande": {"silhouette_color": Color(0.08, 0.16, 0.10), "height_base": 0.55, "height_variation": 0.20, "roughness": 0.65, "density": 0.80},
	"landes":      {"silhouette_color": Color(0.14, 0.10, 0.16), "height_base": 0.62, "height_variation": 0.12, "roughness": 0.35, "density": 0.45},
	"cotes":       {"silhouette_color": Color(0.10, 0.14, 0.18), "height_base": 0.68, "height_variation": 0.18, "roughness": 0.50, "density": 0.35},
	"villages":    {"silhouette_color": Color(0.16, 0.12, 0.08), "height_base": 0.60, "height_variation": 0.10, "roughness": 0.25, "density": 0.55},
	"cercles":     {"silhouette_color": Color(0.10, 0.10, 0.12), "height_base": 0.70, "height_variation": 0.12, "roughness": 0.30, "density": 0.35},
	"marais":      {"silhouette_color": Color(0.08, 0.14, 0.12), "height_base": 0.72, "height_variation": 0.08, "roughness": 0.20, "density": 0.90},
	"collines":    {"silhouette_color": Color(0.12, 0.14, 0.08), "height_base": 0.58, "height_variation": 0.22, "roughness": 0.55, "density": 0.50},
	"iles":        {"silhouette_color": Color(0.06, 0.10, 0.16), "height_base": 0.65, "height_variation": 0.15, "roughness": 0.40, "density": 0.40},
}


# ═══════════════════════════════════════════════════════════════════════════════
# ATMOSPHERE BASES — default particle config per biome
# ═══════════════════════════════════════════════════════════════════════════════

static var ATMO_BASES := {
	"broceliande": {"type": "particles", "count": 25, "color": Color(0.30, 0.40, 0.28, 0.12), "speed_range": Vector2(2.0, 8.0), "size_range": Vector2(20.0, 50.0), "direction": Vector2(1.0, 0.2)},
	"landes":      {"type": "particles", "count": 20, "color": Color(0.40, 0.30, 0.42, 0.10), "speed_range": Vector2(4.0, 12.0), "size_range": Vector2(10.0, 30.0), "direction": Vector2(1.5, 0.3)},
	"cotes":       {"type": "particles", "count": 30, "color": Color(0.50, 0.55, 0.60, 0.10), "speed_range": Vector2(6.0, 18.0), "size_range": Vector2(8.0, 25.0), "direction": Vector2(2.0, 0.5)},
	"villages":    {"type": "particles", "count": 15, "color": Color(0.45, 0.35, 0.25, 0.08), "speed_range": Vector2(1.0, 5.0), "size_range": Vector2(15.0, 35.0), "direction": Vector2(0.5, -0.3)},
	"cercles":     {"type": "particles", "count": 10, "color": Color(0.60, 0.60, 0.70, 0.15), "speed_range": Vector2(2.0, 6.0), "size_range": Vector2(4.0, 10.0), "direction": Vector2(0.0, -0.8)},
	"marais":      {"type": "particles", "count": 35, "color": Color(0.26, 0.36, 0.33, 0.18), "speed_range": Vector2(1.0, 5.0), "size_range": Vector2(25.0, 60.0), "direction": Vector2(0.5, -0.1)},
	"collines":    {"type": "particles", "count": 18, "color": Color(0.40, 0.42, 0.30, 0.10), "speed_range": Vector2(3.0, 10.0), "size_range": Vector2(12.0, 35.0), "direction": Vector2(1.0, 0.1)},
	"iles":        {"type": "particles", "count": 22, "color": Color(0.40, 0.55, 0.65, 0.12), "speed_range": Vector2(3.0, 10.0), "size_range": Vector2(15.0, 40.0), "direction": Vector2(1.0, 0.0)},
}


# ═══════════════════════════════════════════════════════════════════════════════
# WEATHER ATMOSPHERE OVERRIDES — rain/snow/storm replace biome default
# ═══════════════════════════════════════════════════════════════════════════════

static var WEATHER_ATMO := {
	"clair":  {},
	"brume":  {"count_mult": 1.5, "size_mult": 1.4, "speed_mult": 0.6, "alpha_mult": 1.5},
	"pluie":  {"override": {"type": "particles", "count": 35, "color": Color(0.50, 0.60, 0.70, 0.15), "speed_range": Vector2(80.0, 140.0), "size_range": Vector2(1.0, 2.0), "direction": Vector2(0.15, 1.0)}},
	"orage":  {"override": {"type": "particles", "count": 50, "color": Color(0.50, 0.55, 0.65, 0.20), "speed_range": Vector2(100.0, 180.0), "size_range": Vector2(1.0, 3.0), "direction": Vector2(0.25, 1.0)}},
	"neige":  {"override": {"type": "particles", "count": 40, "color": Color(0.80, 0.82, 0.85, 0.25), "speed_range": Vector2(5.0, 15.0), "size_range": Vector2(2.0, 5.0), "direction": Vector2(0.3, 0.8)}},
}


# ═══════════════════════════════════════════════════════════════════════════════
# SEASON OVERLAY — night vignette and period-specific atmosphere hints
# ═══════════════════════════════════════════════════════════════════════════════

static var PERIOD_ATMO_HINTS := {
	"aube":        {"overlay_color": Color(1.0, 0.70, 0.50, 0.06), "type": "overlay", "pulse_period": 0.0, "pulse_amplitude": 0.0},
	"jour":        {},
	"crepuscule":  {"overlay_color": Color(1.0, 0.55, 0.35, 0.08), "type": "overlay", "pulse_period": 0.0, "pulse_amplitude": 0.0},
	"nuit":        {"overlay_color": Color(0.02, 0.04, 0.02, 0.25), "type": "overlay", "pulse_period": 0.0, "pulse_amplitude": 0.0},
}


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

static func compute_sky(biome: String, period: String = "jour",
		weather: String = "clair", season: String = "automne") -> Dictionary:
	## Returns sky gradient parameters: top_color, mid_color, bottom_color, mid_position,
	## plus weather uniforms: fog_density, cloud_cover, rain_intensity, fog_color.
	var key: String = SpritePalette.BIOME_KEY_MAP.get(biome, biome)
	var base: Dictionary = SKY_BASES.get(key, SKY_BASES["broceliande"])
	var p_mod: Dictionary = PERIOD_MODS.get(period, PERIOD_MODS["jour"])
	var w_mod: Dictionary = WEATHER_SKY_MODS.get(weather, WEATHER_SKY_MODS["clair"])
	var s_tint: Color = SpritePalette.SEASON_MODS.get(season, Color(1, 1, 1))

	var p_tint: Color = p_mod.get("tint", Color(1, 1, 1))
	var p_bright: float = float(p_mod.get("brightness", 1.0))
	var w_bright: float = float(w_mod.get("brightness", 1.0))
	var w_desat: float = float(w_mod.get("desaturation", 0.0))
	var w_fog: float = float(w_mod.get("fog_density", 0.0))
	var fog_col: Color = w_mod.get("fog_color", Color(0.6, 0.6, 0.65))

	var top: Color = _apply_color_mods(
		base.get("top", Color.BLACK), p_tint, p_bright, w_bright, w_desat, w_fog, fog_col, s_tint)
	var mid: Color = _apply_color_mods(
		base.get("mid", Color.BLACK), p_tint, p_bright, w_bright, w_desat, w_fog, fog_col, s_tint)
	var bottom: Color = _apply_color_mods(
		base.get("bottom", Color.BLACK), p_tint, p_bright, w_bright, w_desat, w_fog, fog_col, s_tint)

	var mid_pos: float = float(base.get("mid_pos", 0.45)) + float(p_mod.get("mid_shift", 0.0))

	return {
		"top_color": top,
		"mid_color": mid,
		"bottom_color": bottom,
		"mid_position": clampf(mid_pos, 0.2, 0.8),
		"fog_density": w_fog,
		"fog_color": fog_col,
		"cloud_cover": float(w_mod.get("cloud_cover", 0.0)),
		"rain_intensity": float(w_mod.get("rain_intensity", 0.0)),
	}


static func compute_terrain(biome: String, period: String = "jour",
		weather: String = "clair") -> Dictionary:
	## Returns terrain silhouette parameters: silhouette_color, height_base,
	## height_variation, roughness, density.
	var key: String = SpritePalette.BIOME_KEY_MAP.get(biome, biome)
	var base: Dictionary = TERRAIN_BASES.get(key, TERRAIN_BASES["broceliande"]).duplicate()
	var p_mod: Dictionary = PERIOD_MODS.get(period, PERIOD_MODS["jour"])

	# Darken silhouette at night / dusk
	var p_bright: float = float(p_mod.get("brightness", 1.0))
	var dark_factor: float = clampf(p_bright * 0.8 + 0.2, 0.20, 1.0)
	var sil_c: Color = base.get("silhouette_color", Color(0.08, 0.16, 0.10))
	base["silhouette_color"] = Color(
		sil_c.r * dark_factor, sil_c.g * dark_factor,
		sil_c.b * dark_factor, sil_c.a)

	# Weather: fog blends silhouette toward muted fog tone
	var w_mod: Dictionary = WEATHER_SKY_MODS.get(weather, WEATHER_SKY_MODS["clair"])
	var fog: float = float(w_mod.get("fog_density", 0.0))
	if fog > 0.0:
		var c: Color = base["silhouette_color"]
		var fog_col: Color = w_mod.get("fog_color", Color(0.6, 0.6, 0.65))
		base["silhouette_color"] = c.lerp(fog_col * 0.3, fog)

	return base


static func compute_atmosphere(biome: String, period: String = "jour",
		weather: String = "clair") -> Dictionary:
	## Returns atmosphere config: type, count, color, speed_range, size_range, direction.
	## May include "night_overlay" sub-dict for period vignette.
	var key: String = SpritePalette.BIOME_KEY_MAP.get(biome, biome)
	var base: Dictionary = ATMO_BASES.get(key, ATMO_BASES["broceliande"]).duplicate(true)
	var w_atmo: Dictionary = WEATHER_ATMO.get(weather, {})

	# Weather override replaces biome default entirely (rain, snow, storm)
	if w_atmo.has("override"):
		base = w_atmo["override"].duplicate(true)
	elif not w_atmo.is_empty():
		# Multiplicative mods (brume thickens existing particles)
		var count_m: float = float(w_atmo.get("count_mult", 1.0))
		var size_m: float = float(w_atmo.get("size_mult", 1.0))
		var speed_m: float = float(w_atmo.get("speed_mult", 1.0))
		var alpha_m: float = float(w_atmo.get("alpha_mult", 1.0))
		base["count"] = int(float(base.get("count", 25)) * count_m)
		var sr: Vector2 = base.get("size_range", Vector2(20, 50))
		base["size_range"] = sr * size_m
		var spr: Vector2 = base.get("speed_range", Vector2(2, 8))
		base["speed_range"] = spr * speed_m
		var c: Color = base.get("color", Color(0.3, 0.4, 0.3, 0.12))
		base["color"] = Color(c.r, c.g, c.b, clampf(c.a * alpha_m, 0.0, 0.50))

	# Period overlay (dawn/dusk tint, night vignette)
	var period_hint: Dictionary = PERIOD_ATMO_HINTS.get(period, {})
	if not period_hint.is_empty():
		base["period_overlay"] = period_hint.duplicate()

	return base


# ═══════════════════════════════════════════════════════════════════════════════
# CONVENIENCE — full ambiance bundle
# ═══════════════════════════════════════════════════════════════════════════════

static func compute_all(biome: String, period: String = "jour",
		weather: String = "clair", season: String = "automne") -> Dictionary:
	## Returns all three components in a single call.
	return {
		"sky": compute_sky(biome, period, weather, season),
		"terrain": compute_terrain(biome, period, weather),
		"atmosphere": compute_atmosphere(biome, period, weather),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════

static func _apply_color_mods(base_color: Color, period_tint: Color,
		period_bright: float, weather_bright: float, desaturation: float,
		fog_blend: float, fog_color: Color, season_tint: Color) -> Color:
	## Apply period + weather + season modifiers to a sky color band.
	var c: Color = base_color
	# Period tint + brightness
	c = Color(c.r * period_tint.r * period_bright,
		c.g * period_tint.g * period_bright,
		c.b * period_tint.b * period_bright, c.a)
	# Weather brightness
	c = Color(c.r * weather_bright, c.g * weather_bright, c.b * weather_bright, c.a)
	# Desaturation
	if desaturation > 0.0:
		var gray: float = c.r * 0.299 + c.g * 0.587 + c.b * 0.114
		c = c.lerp(Color(gray, gray, gray, c.a), desaturation)
	# Fog blend
	if fog_blend > 0.0:
		c = c.lerp(fog_color, fog_blend)
	# Season tint (multiplicative)
	c = Color(
		clampf(c.r * season_tint.r, 0.0, 1.0),
		clampf(c.g * season_tint.g, 0.0, 1.0),
		clampf(c.b * season_tint.b, 0.0, 1.0), c.a)
	return c
