## ═══════════════════════════════════════════════════════════════════════════════
## MerlinPaletteSwap — Palette Texture Generator for palette_swap.gdshader
## ═══════════════════════════════════════════════════════════════════════════════
## Creates ImageTexture palettes from MerlinVisual color dictionaries.
## Use with ShaderMaterial + shaders/palette_swap.gdshader
##
## Usage:
##   var mat := MerlinPaletteSwap.create_seasonal_material(reference_colors)
##   sprite.material = mat
##
##   # Manual season control:
##   mat.set_shader_parameter("target_row", 2)  # 1=spring, 2=summer, 3=autumn, 4=winter
##
##   # Animated cycling:
##   mat.set_shader_parameter("animation_fps", 0.5)  # Cycle every 2s per season
## ═══════════════════════════════════════════════════════════════════════════════
class_name MerlinPaletteSwap
extends RefCounted


static var _shader_cache: Shader = null


## Load and cache the palette swap shader.
static func _get_shader() -> Shader:
	if _shader_cache == null:
		_shader_cache = load("res://shaders/palette_swap.gdshader")
	return _shader_cache


## Create a palette ImageTexture from arrays of Color.
## palette_rows[0] = reference colors, palette_rows[1..n] = target rows.
## All rows must have the same length.
static func create_palette_texture(palette_rows: Array[PackedColorArray]) -> ImageTexture:
	if palette_rows.is_empty():
		return null
	var width: int = palette_rows[0].size()
	var height: int = palette_rows.size()
	if width == 0 or height < 2:
		return null

	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for row_idx: int in range(height):
		var row: PackedColorArray = palette_rows[row_idx]
		for col_idx: int in range(mini(row.size(), width)):
			img.set_pixel(col_idx, row_idx, row[col_idx])

	var tex := ImageTexture.create_from_image(img)
	return tex


## Create a ShaderMaterial with palette swap, ready to assign to a CanvasItem.
static func create_material(palette_rows: Array[PackedColorArray], animated: bool = false, fps: float = 0.5) -> ShaderMaterial:
	var shader := _get_shader()
	if shader == null:
		return null

	var mat := ShaderMaterial.new()
	mat.shader = shader

	var tex := create_palette_texture(palette_rows)
	if tex:
		mat.set_shader_parameter("palette", tex)
	mat.set_shader_parameter("animation_fps", fps if animated else 0.0)
	mat.set_shader_parameter("target_row", 1)
	mat.set_shader_parameter("tolerance", 0.01)
	mat.set_shader_parameter("blend", 1.0)
	return mat


## Create a seasonal palette material.
## reference_colors: the original sprite colors as PackedColorArray.
## Each season row applies a tint from MerlinVisual.SEASON_TINTS.
static func create_seasonal_material(reference_colors: PackedColorArray) -> ShaderMaterial:
	var season_keys: Array[String] = ["printemps", "ete", "automne", "hiver"]
	var rows: Array[PackedColorArray] = []
	rows.append(reference_colors)

	for season_key: String in season_keys:
		var tint: Color = MerlinVisual.SEASON_TINTS.get(season_key, Color(1, 1, 1))
		var tinted := PackedColorArray()
		for color: Color in reference_colors:
			var c := Color(
				clampf(color.r * tint.r, 0.0, 1.0),
				clampf(color.g * tint.g, 0.0, 1.0),
				clampf(color.b * tint.b, 0.0, 1.0),
				color.a
			)
			tinted.append(c)
		rows.append(tinted)

	return create_material(rows, false, 0.0)


## Create a biome palette material.
## reference_colors: original sprite colors.
## Generates a target row per biome from BIOME_ART_PROFILES accent shifts.
static func create_biome_material(reference_colors: PackedColorArray) -> ShaderMaterial:
	var biome_keys: Array[String] = [
		"broceliande", "landes", "cotes", "villages",
		"cercles", "marais", "collines"
	]
	var rows: Array[PackedColorArray] = []
	rows.append(reference_colors)

	for biome_key: String in biome_keys:
		var profile: Dictionary = MerlinVisual.BIOME_ART_PROFILES.get(biome_key, {})
		var accent: Color = profile.get("accent", Color(0.5, 0.5, 0.5))
		var shifted := PackedColorArray()
		for color: Color in reference_colors:
			# Subtle shift toward biome accent (20% blend)
			var c := Color(
				lerpf(color.r, accent.r, 0.2),
				lerpf(color.g, accent.g, 0.2),
				lerpf(color.b, accent.b, 0.2),
				color.a
			)
			shifted.append(c)
		rows.append(shifted)

	return create_material(rows, false, 0.0)


## Create an aspect palette material (Corps/Ame/Monde tinting).
## reference_colors: original sprite colors.
## 3 rows: Corps warm, Ame ethereal, Monde forest.
static func create_aspect_material(reference_colors: PackedColorArray) -> ShaderMaterial:
	var aspect_keys: Array[String] = ["Corps", "Ame", "Monde"]
	var rows: Array[PackedColorArray] = []
	rows.append(reference_colors)

	for aspect_key: String in aspect_keys:
		var aspect_color: Color = MerlinVisual.ASPECT_COLORS.get(aspect_key, Color(0.5, 0.5, 0.5))
		var tinted := PackedColorArray()
		for color: Color in reference_colors:
			# Tint toward aspect color (15% blend, preserve luminance)
			var lum: float = color.r * 0.299 + color.g * 0.587 + color.b * 0.114
			var c := Color(
				lerpf(color.r, aspect_color.r * (lum + 0.5), 0.15),
				lerpf(color.g, aspect_color.g * (lum + 0.5), 0.15),
				lerpf(color.b, aspect_color.b * (lum + 0.5), 0.15),
				color.a
			)
			c.r = clampf(c.r, 0.0, 1.0)
			c.g = clampf(c.g, 0.0, 1.0)
			c.b = clampf(c.b, 0.0, 1.0)
			tinted.append(c)
		rows.append(tinted)

	return create_material(rows, false, 0.0)


## Extract unique colors from an Image (for building reference palette row).
## Returns a PackedColorArray of unique opaque colors found in the image.
static func extract_palette_from_image(img: Image) -> PackedColorArray:
	var seen: Dictionary = {}
	var colors := PackedColorArray()
	for y: int in range(img.get_height()):
		for x: int in range(img.get_width()):
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			# Key by integer RGB to avoid float precision issues
			var key: int = (int(c.r * 255.0) << 16) | (int(c.g * 255.0) << 8) | int(c.b * 255.0)
			if not seen.has(key):
				seen[key] = true
				colors.append(Color(c.r, c.g, c.b, 1.0))
	return colors


## Convenience: set the current season on a palette swap material.
## season: "printemps", "ete", "automne", "hiver" (or English via mapping).
static func set_season(material: ShaderMaterial, season: String) -> void:
	var fr_key: String = MerlinVisual.SEASON_KEY_MAP.get(season, season)
	var season_map := {"printemps": 1, "ete": 2, "automne": 3, "hiver": 4}
	var row: int = season_map.get(fr_key, 1)
	material.set_shader_parameter("target_row", row)
	material.set_shader_parameter("animation_fps", 0.0)


## Convenience: set the current biome on a biome palette swap material.
static func set_biome(material: ShaderMaterial, biome_key: String) -> void:
	var biome_map := {
		"broceliande": 1, "landes": 2, "cotes": 3, "villages": 4,
		"cercles": 5, "marais": 6, "collines": 7
	}
	var row: int = biome_map.get(biome_key, 1)
	material.set_shader_parameter("target_row", row)


## Convenience: set the current aspect on an aspect palette swap material.
static func set_aspect(material: ShaderMaterial, aspect_key: String) -> void:
	var aspect_map := {"Corps": 1, "Ame": 2, "Monde": 3}
	var row: int = aspect_map.get(aspect_key, 1)
	material.set_shader_parameter("target_row", row)


## Animate smooth transition between current and target palette row.
## Uses blend to crossfade. Call this in _process or with a Tween.
static func tween_to_row(material: ShaderMaterial, row: int, duration: float = 0.5) -> Tween:
	material.set_shader_parameter("target_row", row)
	material.set_shader_parameter("blend", 0.0)
	var tween := material.create_tween()
	tween.tween_method(func(val: float) -> void:
		material.set_shader_parameter("blend", val)
	, 0.0, 1.0, duration).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	return tween
