extends RefCounted
class_name MerlinAmbientSystem

## Pure-function ambient calculator. Blends biome + season + time-of-day into a
## unified color set for scene rendering. No internal state — call compute_ambient()
## from any scene controller with current context values.
##
## Uses MerlinVisualPalettes.BIOME_ART_PROFILES, SEASONAL_PALETTES,
## TIME_OF_DAY_COLORS, and BIOME_CRT_PROFILES as data sources.


# ═══════════════════════════════════════════��═══════════════════════════════════
# BIOME KEY MAPPING (full biome key → short palette key)
# ══════════════════════���════════════════════════════════════════════════════════

const BIOME_KEY_MAP: Dictionary = {
	"foret_broceliande": "broceliande",
	"landes_bruyere": "landes",
	"cotes_sauvages": "cotes",
	"villages_celtes": "villages",
	"cercles_pierres": "cercles",
	"marais_korrigans": "marais",
	"collines_dolmens": "collines",
	"iles_mystiques": "iles",
}


# ═══════════════════════════════════════════════════════��═══════════════════════
# WEATHER TABLES — Probability per season×biome (0.0 = never, 1.0 = always)
# ═════════��═══════════════════════════════════════════════���═════════════════════

const WEATHER_TYPES: Array[String] = ["clear", "mist", "rain", "storm", "snow"]

const WEATHER_SEASON_BIAS: Dictionary = {
	"printemps": {"clear": 0.40, "mist": 0.25, "rain": 0.30, "storm": 0.05, "snow": 0.00},
	"ete":       {"clear": 0.55, "mist": 0.10, "rain": 0.20, "storm": 0.15, "snow": 0.00},
	"automne":   {"clear": 0.25, "mist": 0.35, "rain": 0.30, "storm": 0.10, "snow": 0.00},
	"hiver":     {"clear": 0.20, "mist": 0.25, "rain": 0.20, "storm": 0.05, "snow": 0.30},
}

const WEATHER_BIOME_MODIFIER: Dictionary = {
	"broceliande": {"mist": 0.15, "rain": 0.05},
	"landes":      {"mist": 0.10, "storm": 0.05},
	"cotes":       {"storm": 0.10, "rain": 0.10},
	"villages":    {},
	"cercles":     {"mist": 0.20},
	"marais":      {"mist": 0.25, "rain": 0.10},
	"collines":    {"mist": 0.05},
	"iles":        {"storm": 0.15, "mist": 0.10},
}


# ════════════��═════════════��════════════════════════════════════════════════════
# TIME-OF-DAY INTENSITY CURVES
# ═════════���═════════════════════════════════════════════���═══════════════════════

const PERIOD_LIGHT: Dictionary = {
	"nuit":        0.08,
	"aube":        0.35,
	"matin":       0.75,
	"midi":        1.00,
	"apres-midi":  0.85,
	"crepuscule":  0.40,
}

const PERIOD_FOG_DENSITY: Dictionary = {
	"nuit":        0.45,
	"aube":        0.55,
	"matin":       0.20,
	"midi":        0.10,
	"apres-midi":  0.15,
	"crepuscule":  0.40,
}

const PERIOD_TINT: Dictionary = {
	"nuit":        Color(0.15, 0.18, 0.35),
	"aube":        Color(0.55, 0.35, 0.25),
	"matin":       Color(0.95, 0.92, 0.85),
	"midi":        Color(1.00, 1.00, 0.97),
	"apres-midi":  Color(0.95, 0.88, 0.75),
	"crepuscule":  Color(0.65, 0.30, 0.20),
}


# ═══════════════════���════════════════════════════��══════════════════════════════
# MAIN API
# ════════════���════════════════════════════════════════════���═════════════════════


static func compute_ambient(biome_key: String, season: String, period: String, light_normalized: float) -> Dictionary:
	var short_biome: String = BIOME_KEY_MAP.get(biome_key, biome_key)

	var art: Dictionary = MerlinVisualPalettes.BIOME_ART_PROFILES.get(short_biome, MerlinVisualPalettes.BIOME_ART_PROFILES["broceliande"])
	var season_en: String = _season_to_english(season)
	var season_pal: Dictionary = MerlinVisualPalettes.SEASONAL_PALETTES.get(season_en, MerlinVisualPalettes.SEASONAL_PALETTES["winter"])

	var p_tint: Color = PERIOD_TINT.get(period, PERIOD_TINT["midi"])
	var p_light: float = PERIOD_LIGHT.get(period, 1.0)
	var p_fog: float = PERIOD_FOG_DENSITY.get(period, 0.15)

	var season_mod: Color = season_pal.get("bg_modulate", Color(1, 1, 1))
	var season_fog: Color = season_pal.get("fog_tint", Color(0.9, 0.9, 0.9, 0.3))

	var sky_top: Color = _blend_ambient(art["sky"], p_tint, season_mod, p_light)
	var sky_mid: Color = _blend_ambient(art["mist"], p_tint, season_mod, p_light)
	var sky_bottom: Color = _blend_ambient(art["mid"], p_tint, season_mod, p_light)

	var fog_color: Color = _blend_fog(art["mist"], season_fog, p_tint, p_light)
	var fog_density: float = clampf(p_fog + float(art.get("feature_density", 0.5)) * 0.15, 0.0, 1.0)

	var particle_color: Color = season_pal.get("particle_color", Color(0.5, 0.5, 0.5, 0.15))
	particle_color = Color(
		particle_color.r * season_mod.r,
		particle_color.g * season_mod.g,
		particle_color.b * season_mod.b,
		particle_color.a * clampf(p_light * 1.2, 0.3, 1.0)
	)

	var silhouette: Color = Color(
		art["foreground"].r * p_light,
		art["foreground"].g * p_light,
		art["foreground"].b * p_light,
	)

	var weather: String = _pick_weather(short_biome, season)
	var weather_mod: Dictionary = _weather_modifiers(weather)

	fog_density = clampf(fog_density + float(weather_mod.get("fog_add", 0.0)), 0.0, 1.0)
	var final_light: float = clampf(light_normalized * p_light * float(weather_mod.get("light_mult", 1.0)), 0.0, 1.0)

	var crt_profile: Dictionary = MerlinVisualPalettes.BIOME_CRT_PROFILES.get(short_biome, MerlinVisualPalettes.BIOME_CRT_PROFILES["broceliande"])

	return {
		"sky_top": sky_top,
		"sky_mid": sky_mid,
		"sky_bottom": sky_bottom,
		"fog_color": fog_color,
		"fog_density": fog_density,
		"particle_color": particle_color,
		"silhouette_color": silhouette,
		"light_intensity": final_light,
		"weather": weather,
		"weather_intensity": float(weather_mod.get("intensity", 0.0)),
		"ambient_tint": Color(p_tint.r * season_mod.r, p_tint.g * season_mod.g, p_tint.b * season_mod.b),
		"season_modulate": season_mod,
		"crt_noise": float(crt_profile.get("noise", 0.015)),
		"crt_scanline": float(crt_profile.get("scanline_opacity", 0.08)),
		"crt_glitch": float(crt_profile.get("glitch_probability", 0.003)),
		"biome_short": short_biome,
		"period": period,
		"season": season,
	}


static func compute_ambient_from_time_manager(biome_key: String, time_manager: Node) -> Dictionary:
	var season: String = str(time_manager.get("current_season")) if time_manager else "printemps"
	var period: String = time_manager.get_time_of_day() if time_manager and time_manager.has_method("get_time_of_day") else "midi"
	var light: float = time_manager.get_light_intensity() if time_manager and time_manager.has_method("get_light_intensity") else 0.8
	return compute_ambient(biome_key, season, period, light)


# ════════���═══════════════════════���══════════════════════════════════════════════
# PRIVATE HELPERS
# ══════════���════════════════════════════════════════════════════════════════════


static func _blend_ambient(base: Color, time_tint: Color, season_mod: Color, light: float) -> Color:
	var blended: Color = Color(
		base.r * time_tint.r * season_mod.r,
		base.g * time_tint.g * season_mod.g,
		base.b * time_tint.b * season_mod.b,
	)
	return Color(
		clampf(blended.r * light, 0.0, 1.0),
		clampf(blended.g * light, 0.0, 1.0),
		clampf(blended.b * light, 0.0, 1.0),
	)


static func _blend_fog(biome_mist: Color, season_fog: Color, time_tint: Color, light: float) -> Color:
	var fog_r: float = (biome_mist.r * 0.4 + season_fog.r * 0.3 + time_tint.r * 0.3)
	var fog_g: float = (biome_mist.g * 0.4 + season_fog.g * 0.3 + time_tint.g * 0.3)
	var fog_b: float = (biome_mist.b * 0.4 + season_fog.b * 0.3 + time_tint.b * 0.3)
	return Color(
		clampf(fog_r * (0.6 + light * 0.4), 0.0, 1.0),
		clampf(fog_g * (0.6 + light * 0.4), 0.0, 1.0),
		clampf(fog_b * (0.6 + light * 0.4), 0.0, 1.0),
		clampf(season_fog.a + (1.0 - light) * 0.15, 0.0, 0.8),
	)


static func _pick_weather(short_biome: String, season: String) -> String:
	var base: Dictionary = WEATHER_SEASON_BIAS.get(season, WEATHER_SEASON_BIAS["printemps"])
	var biome_mod: Dictionary = WEATHER_BIOME_MODIFIER.get(short_biome, {})
	var weights: Dictionary = base.duplicate()
	for w_type: String in biome_mod:
		weights[w_type] = float(weights.get(w_type, 0.0)) + float(biome_mod[w_type])
	var total: float = 0.0
	for w_type: String in weights:
		total += float(weights[w_type])
	if total <= 0.0:
		return "clear"
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for w_type in WEATHER_TYPES:
		cumulative += float(weights.get(w_type, 0.0))
		if roll <= cumulative:
			return w_type
	return "clear"


static func _weather_modifiers(weather: String) -> Dictionary:
	match weather:
		"mist":
			return {"fog_add": 0.25, "light_mult": 0.80, "intensity": 0.5}
		"rain":
			return {"fog_add": 0.15, "light_mult": 0.65, "intensity": 0.7}
		"storm":
			return {"fog_add": 0.20, "light_mult": 0.45, "intensity": 1.0}
		"snow":
			return {"fog_add": 0.20, "light_mult": 0.70, "intensity": 0.6}
		_:
			return {"fog_add": 0.0, "light_mult": 1.0, "intensity": 0.0}


static func _season_to_english(season_fr: String) -> String:
	match season_fr:
		"printemps": return "spring"
		"ete": return "summer"
		"automne": return "autumn"
		"hiver": return "winter"
		_: return season_fr
