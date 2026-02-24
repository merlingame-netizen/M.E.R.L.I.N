class_name SpritePalette
extends RefCounted
## Biome-aware color palettes for procedural sprite generation.
## 8 functional color slots per biome, with season and weather modifiers.
## Reuses MerlinVisual.BIOME_CRT_PALETTES as base (8 colors, dark→bright).

## Palette index roles:
## 0 = outline (darkest)
## 1 = deep shadow
## 2 = shadow
## 3 = dark fill
## 4 = mid fill
## 5 = light fill
## 6 = highlight
## 7 = brightest / glow


# ═══════════════════════════════════════════════════════════════════════════════
# BIOME PALETTES — functional 8-color arrays (override CRT for better sprites)
# ═══════════════════════════════════════════════════════════════════════════════

static var BIOME_SPRITE_PALETTES := {
	"broceliande": [
		Color(0.04, 0.06, 0.03),  Color(0.08, 0.14, 0.06),
		Color(0.14, 0.24, 0.10),  Color(0.20, 0.36, 0.16),
		Color(0.28, 0.48, 0.22),  Color(0.40, 0.62, 0.30),
		Color(0.55, 0.78, 0.38),  Color(0.72, 0.92, 0.50),
	],
	"landes": [
		Color(0.08, 0.04, 0.08),  Color(0.16, 0.08, 0.18),
		Color(0.26, 0.14, 0.30),  Color(0.40, 0.22, 0.44),
		Color(0.54, 0.32, 0.58),  Color(0.68, 0.44, 0.72),
		Color(0.80, 0.58, 0.84),  Color(0.92, 0.72, 0.96),
	],
	"cotes": [
		Color(0.04, 0.06, 0.10),  Color(0.08, 0.12, 0.20),
		Color(0.14, 0.22, 0.34),  Color(0.22, 0.34, 0.48),
		Color(0.32, 0.48, 0.62),  Color(0.46, 0.62, 0.76),
		Color(0.62, 0.78, 0.88),  Color(0.80, 0.92, 0.98),
	],
	"villages": [
		Color(0.08, 0.06, 0.03),  Color(0.18, 0.12, 0.06),
		Color(0.30, 0.20, 0.10),  Color(0.46, 0.30, 0.14),
		Color(0.62, 0.42, 0.20),  Color(0.78, 0.56, 0.28),
		Color(0.90, 0.70, 0.36),  Color(0.98, 0.84, 0.46),
	],
	"cercles": [
		Color(0.05, 0.05, 0.06),  Color(0.12, 0.12, 0.14),
		Color(0.22, 0.22, 0.26),  Color(0.34, 0.34, 0.40),
		Color(0.48, 0.48, 0.56),  Color(0.62, 0.62, 0.72),
		Color(0.78, 0.78, 0.88),  Color(0.92, 0.92, 1.00),
	],
	"marais": [
		Color(0.03, 0.06, 0.04),  Color(0.08, 0.14, 0.10),
		Color(0.14, 0.24, 0.18),  Color(0.22, 0.36, 0.26),
		Color(0.30, 0.48, 0.36),  Color(0.42, 0.62, 0.48),
		Color(0.56, 0.78, 0.60),  Color(0.72, 0.92, 0.76),
	],
	"collines": [
		Color(0.06, 0.06, 0.03),  Color(0.14, 0.14, 0.08),
		Color(0.24, 0.26, 0.14),  Color(0.36, 0.40, 0.20),
		Color(0.50, 0.54, 0.28),  Color(0.64, 0.68, 0.36),
		Color(0.78, 0.82, 0.46),  Color(0.92, 0.94, 0.58),
	],
	"iles": [
		Color(0.03, 0.05, 0.08),  Color(0.06, 0.10, 0.18),
		Color(0.10, 0.18, 0.32),  Color(0.16, 0.28, 0.48),
		Color(0.24, 0.40, 0.62),  Color(0.38, 0.56, 0.76),
		Color(0.55, 0.72, 0.88),  Color(0.75, 0.88, 0.96),
	],
}

## Short biome key mapping (full name → palette key)
static var BIOME_KEY_MAP := {
	"foret_broceliande": "broceliande",
	"landes_bruyere": "landes",
	"cotes_sauvages": "cotes",
	"villages_celtes": "villages",
	"cercles_pierres": "cercles",
	"marais_korrigans": "marais",
	"collines_dolmens": "collines",
	"iles_mystiques": "iles",
}


# ═══════════════════════════════════════════════════════════════════════════════
# SEASON MODIFIERS (multiply with base palette)
# ═══════════════════════════════════════════════════════════════════════════════

static var SEASON_MODS := {
	"printemps": Color(1.02, 1.08, 1.00),
	"ete":       Color(1.10, 1.05, 0.94),
	"automne":   Color(1.12, 0.90, 0.80),
	"hiver":     Color(0.82, 0.88, 1.10),
}


# ═══════════════════════════════════════════════════════════════════════════════
# WEATHER MODIFIERS
# ═══════════════════════════════════════════════════════════════════════════════

static var WEATHER_MODS := {
	"clair":  {"saturation": 1.0, "brightness": 1.0, "fog_blend": 0.0},
	"brume":  {"saturation": 0.7, "brightness": 0.9, "fog_blend": 0.15},
	"pluie":  {"saturation": 0.6, "brightness": 0.8, "fog_blend": 0.10},
	"orage":  {"saturation": 0.5, "brightness": 0.65, "fog_blend": 0.08},
	"neige":  {"saturation": 0.4, "brightness": 1.05, "fog_blend": 0.20},
}


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

static func get_palette(biome: String, season: String = "automne",
		weather: String = "clair") -> Array[Color]:
	## Returns an 8-color palette adapted to biome + season + weather.
	var key: String = BIOME_KEY_MAP.get(biome, biome)
	var base: Array = BIOME_SPRITE_PALETTES.get(key, BIOME_SPRITE_PALETTES["broceliande"])
	var season_mod: Color = SEASON_MODS.get(season, Color(1, 1, 1))
	var weather_data: Dictionary = WEATHER_MODS.get(weather, WEATHER_MODS["clair"])
	var sat: float = float(weather_data.get("saturation", 1.0))
	var bright: float = float(weather_data.get("brightness", 1.0))
	var fog: float = float(weather_data.get("fog_blend", 0.0))
	var fog_color := Color(0.6, 0.6, 0.65)

	var result: Array[Color] = []
	for c: Color in base:
		# Apply season tint
		var tinted := Color(
			clampf(c.r * season_mod.r, 0.0, 1.0),
			clampf(c.g * season_mod.g, 0.0, 1.0),
			clampf(c.b * season_mod.b, 0.0, 1.0), c.a)
		# Desaturate for weather
		if sat < 1.0:
			var gray: float = tinted.r * 0.3 + tinted.g * 0.59 + tinted.b * 0.11
			tinted = tinted.lerp(Color(gray, gray, gray, tinted.a), 1.0 - sat)
		# Brightness
		tinted = Color(
			clampf(tinted.r * bright, 0.0, 1.0),
			clampf(tinted.g * bright, 0.0, 1.0),
			clampf(tinted.b * bright, 0.0, 1.0), tinted.a)
		# Fog blend
		if fog > 0.0:
			tinted = tinted.lerp(fog_color, fog)
		result.append(tinted)
	return result


static func get_accent_color(biome: String) -> Color:
	## Returns a warm accent color for special highlights (fire, magic glow).
	var key: String = BIOME_KEY_MAP.get(biome, biome)
	match key:
		"broceliande": return Color(0.45, 0.80, 0.35)
		"landes": return Color(0.75, 0.45, 0.80)
		"cotes": return Color(0.40, 0.65, 0.90)
		"villages": return Color(0.90, 0.65, 0.30)
		"cercles": return Color(0.70, 0.70, 0.90)
		"marais": return Color(0.40, 0.80, 0.55)
		"collines": return Color(0.80, 0.75, 0.40)
		"iles": return Color(0.50, 0.75, 0.90)
		_: return Color(0.80, 0.70, 0.40)
