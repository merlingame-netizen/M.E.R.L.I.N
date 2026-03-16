class_name PixelBiomeBackdrop
extends Control
## Procedural pixel art animated backdrop for MerlinGame.
## Generates 5-layer parallax landscape per biome x weather.
## Renders at PIXEL_W x PIXEL_H then upscales via SubViewport (4x).
## Performance: redraws at ~10 FPS via timer, not every frame.

# ---- Constants ----
const PIXEL_W := 160
const PIXEL_H := 90
const PIXEL_SCALE := 4
const REDRAW_INTERVAL := 0.1  # ~10 FPS
const WIND_SPEED := 0.3
const MIST_SPEED := 0.15
const PARTICLE_COUNT := 24
const STAR_COUNT := 18
const GLOW_COUNT := 6  # Broceliande mysterious lights

# ---- Weather enum ----
enum Weather { CLEAR, RAIN, FOG, SNOW }

# ---- State ----
var _biome: String = "broceliande"
var _weather: int = Weather.CLEAR
var _time: float = 0.0
var _wind_offset: float = 0.0
var _mist_offset: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Cached biome colors (from MerlinVisual.BIOME_ART_PROFILES)
var _sky_color: Color = Color.BLACK
var _mist_color: Color = Color.BLACK
var _mid_color: Color = Color.BLACK
var _accent_color: Color = Color.BLACK
var _fg_color: Color = Color.BLACK
var _density: float = 0.5

# Pre-generated landscape data (regenerated on biome change)
var _terrain_far: PackedFloat32Array = PackedFloat32Array()   # Far hills height
var _terrain_mid: PackedFloat32Array = PackedFloat32Array()   # Mid trees/structures
var _terrain_near: PackedFloat32Array = PackedFloat32Array()  # Near vegetation
var _tree_positions: Array[Vector2i] = []  # Tree trunk positions (x, height)
var _stars: PackedVector2Array = PackedVector2Array()
var _glows: PackedVector2Array = PackedVector2Array()  # Broceliande lights
var _particles: PackedVector2Array = PackedVector2Array()
var _particle_speeds: PackedFloat32Array = PackedFloat32Array()

# Rendering pipeline
var _image: Image = null
var _texture: ImageTexture = null
var _texture_rect: TextureRect = null
var _redraw_timer: Timer = null


func _ready() -> void:
	_rng.seed = hash("merlin_backdrop")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Create image buffer
	_image = Image.create(PIXEL_W, PIXEL_H, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)

	# TextureRect for display (upscaled, nearest-neighbor)
	_texture_rect = TextureRect.new()
	_texture_rect.name = "PixelDisplay"
	_texture_rect.texture = _texture
	_texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texture_rect)

	# Timer for animation redraws (~10 FPS)
	_redraw_timer = Timer.new()
	_redraw_timer.name = "RedrawTimer"
	_redraw_timer.wait_time = REDRAW_INTERVAL
	_redraw_timer.autostart = true
	_redraw_timer.timeout.connect(_on_redraw)
	add_child(_redraw_timer)

	# Initialize particles
	_init_particles()
	# Generate initial landscape
	set_biome(_biome)


# ---- Public API ----

func set_biome(biome_key: String) -> void:
	_biome = biome_key
	_load_biome_colors()
	_generate_terrain()
	_generate_stars()
	_generate_glows()
	_render_frame()


func set_weather(weather_name: String) -> void:
	match weather_name.to_lower():
		"rain": _weather = Weather.RAIN
		"fog": _weather = Weather.FOG
		"snow": _weather = Weather.SNOW
		_: _weather = Weather.CLEAR


func get_current_biome() -> String:
	return _biome


func get_current_weather() -> int:
	return _weather


# ---- Biome Color Loading ----

func _load_biome_colors() -> void:
	var profile: Dictionary = MerlinVisual.BIOME_ART_PROFILES.get(
		_biome, MerlinVisual.BIOME_ART_PROFILES["broceliande"]
	)
	_sky_color = profile["sky"] as Color
	_mist_color = profile["mist"] as Color
	_mid_color = profile["mid"] as Color
	_accent_color = profile["accent"] as Color
	_fg_color = profile["foreground"] as Color
	_density = profile["feature_density"] as float


# ---- Terrain Generation (once per biome change) ----

func _generate_terrain() -> void:
	_rng.seed = hash(_biome + "_terrain")

	# Far hills: smooth rolling heights (top 40% of screen)
	_terrain_far.resize(PIXEL_W)
	for x: int in range(PIXEL_W):
		var h: float = 0.3 + 0.1 * sin(x * 0.04) + 0.05 * sin(x * 0.09 + 1.5)
		_terrain_far[x] = h

	# Mid layer heights (top 55%)
	_terrain_mid.resize(PIXEL_W)
	for x: int in range(PIXEL_W):
		var h: float = 0.45 + 0.08 * sin(x * 0.07 + 0.8) + 0.04 * sin(x * 0.15 + 2.0)
		_terrain_mid[x] = h

	# Near foreground (top 75%)
	_terrain_near.resize(PIXEL_W)
	for x: int in range(PIXEL_W):
		var h: float = 0.68 + 0.05 * sin(x * 0.1 + 1.2) + 0.03 * sin(x * 0.2 + 0.5)
		_terrain_near[x] = h

	# Trees for forested biomes
	_tree_positions.clear()
	var tree_count: int = int(_density * 14)
	if _biome == "broceliande":
		tree_count = 18  # Dense forest
	for i: int in range(tree_count):
		var tx: int = _rng.randi_range(5, PIXEL_W - 6)
		var th: int = _rng.randi_range(12, 28)
		if _biome == "broceliande":
			th = _rng.randi_range(18, 35)  # Taller trees
		_tree_positions.append(Vector2i(tx, th))


func _generate_stars() -> void:
	_stars.resize(STAR_COUNT)
	for i: int in range(STAR_COUNT):
		_stars[i] = Vector2(
			_rng.randf_range(0.0, float(PIXEL_W)),
			_rng.randf_range(2.0, float(PIXEL_H) * 0.3)
		)


func _generate_glows() -> void:
	_glows.resize(0)
	if _biome != "broceliande":
		return
	_glows.resize(GLOW_COUNT)
	for i: int in range(GLOW_COUNT):
		_glows[i] = Vector2(
			_rng.randf_range(15.0, float(PIXEL_W) - 15.0),
			_rng.randf_range(float(PIXEL_H) * 0.45, float(PIXEL_H) * 0.75)
		)


func _init_particles() -> void:
	_particles.resize(PARTICLE_COUNT)
	_particle_speeds.resize(PARTICLE_COUNT)
	for i: int in range(PARTICLE_COUNT):
		_particles[i] = Vector2(
			_rng.randf_range(0.0, float(PIXEL_W)),
			_rng.randf_range(0.0, float(PIXEL_H))
		)
		_particle_speeds[i] = _rng.randf_range(0.3, 1.2)


# ---- Animation Tick ----

func _on_redraw() -> void:
	_time += REDRAW_INTERVAL
	_wind_offset += WIND_SPEED * REDRAW_INTERVAL
	_mist_offset += MIST_SPEED * REDRAW_INTERVAL
	_update_particles()
	_render_frame()


func _update_particles() -> void:
	for i: int in range(PARTICLE_COUNT):
		var p: Vector2 = _particles[i]
		var spd: float = _particle_speeds[i]
		match _weather:
			Weather.RAIN:
				p.y += spd * 4.0
				p.x -= spd * 0.5
			Weather.SNOW:
				p.y += spd * 0.8
				p.x += sin(_time * 2.0 + float(i)) * 0.3
			Weather.FOG:
				p.x += spd * 0.4
			_:
				p.y -= spd * 0.2  # Gentle float up (fireflies)
				p.x += sin(_time * 1.5 + float(i) * 0.7) * 0.2
		# Wrap around
		if p.x < 0.0: p.x += float(PIXEL_W)
		if p.x >= float(PIXEL_W): p.x -= float(PIXEL_W)
		if p.y < 0.0: p.y += float(PIXEL_H)
		if p.y >= float(PIXEL_H): p.y -= float(PIXEL_H)
		_particles[i] = p


# ---- Rendering ----

func _render_frame() -> void:
	_image.fill(Color.BLACK)
	_draw_sky()
	_draw_far_layer()
	_draw_mid_layer()
	_draw_trees()
	_draw_near_layer()
	_draw_atmosphere()
	_draw_particles()
	if _biome == "broceliande":
		_draw_broceliande_glows()
	_texture.update(_image)


func _draw_sky() -> void:
	# Vertical gradient from dark top to sky_color
	var top_color: Color = _sky_color * 0.3
	for y: int in range(PIXEL_H):
		var t: float = float(y) / float(PIXEL_H)
		var c: Color = top_color.lerp(_sky_color, t * t)
		for x: int in range(PIXEL_W):
			_image.set_pixel(x, y, c)
	# Stars (twinkle based on time)
	for i: int in range(_stars.size()):
		var sp: Vector2 = _stars[i]
		var sx: int = int(sp.x) % PIXEL_W
		var sy: int = int(sp.y) % PIXEL_H
		var blink: float = 0.5 + 0.5 * sin(_time * 2.0 + float(i) * 1.7)
		if blink > 0.4 and _weather == Weather.CLEAR:
			var star_c: Color = Color(
				_accent_color.r * blink,
				_accent_color.g * blink,
				_accent_color.b * blink
			)
			_safe_set_pixel(sx, sy, star_c)
	# Pixelated clouds (simple horizontal bands)
	var cloud_y: int = int(PIXEL_H * 0.15)
	var cloud_offset: int = int(_wind_offset * 8.0) % PIXEL_W
	for cx: int in range(0, 20):
		var px: int = (cloud_offset + cx * 3) % PIXEL_W
		var cloud_alpha: float = 0.12 if _weather == Weather.FOG else 0.06
		var cc: Color = Color(_mist_color.r, _mist_color.g, _mist_color.b, cloud_alpha)
		_safe_blend_pixel(px, cloud_y, cc)
		_safe_blend_pixel(px, cloud_y + 1, cc)


func _draw_far_layer() -> void:
	# Rolling hills / mountains in background
	var base_y: int = int(PIXEL_H * 0.3)
	for x: int in range(PIXEL_W):
		var h_norm: float = _terrain_far[x]
		var hill_top: int = int(float(PIXEL_H) * h_norm)
		var depth_color: Color = _sky_color.lerp(_mid_color, 0.4)
		for y: int in range(hill_top, base_y + 20):
			if y >= 0 and y < PIXEL_H:
				_safe_set_pixel(x, y, depth_color)


func _draw_mid_layer() -> void:
	# Mid-ground terrain fills
	for x: int in range(PIXEL_W):
		var h_norm: float = _terrain_mid[x]
		var mid_top: int = int(float(PIXEL_H) * h_norm)
		for y: int in range(mid_top, PIXEL_H):
			if y >= 0 and y < PIXEL_H:
				_safe_set_pixel(x, y, _mid_color)


func _draw_trees() -> void:
	for tree: Vector2i in _tree_positions:
		var tx: int = tree.x
		var th: int = tree.y
		# Wind sway on tree top
		var sway: int = int(sin(_time * 1.2 + float(tx) * 0.1) * 1.5)
		# Trunk base Y (on mid terrain line)
		var mid_h: float = _terrain_mid[clampi(tx, 0, PIXEL_W - 1)]
		var base_y: int = int(float(PIXEL_H) * mid_h)
		var top_y: int = base_y - th
		# Trunk (2px wide)
		var trunk_color: Color = _fg_color.lerp(_accent_color, 0.3)
		for y: int in range(top_y + 4, base_y):
			_safe_set_pixel(tx, y, trunk_color)
			_safe_set_pixel(tx + 1, y, trunk_color)
		# Canopy (diamond shape with sway)
		var canopy_h: int = int(th * 0.6)
		for cy: int in range(canopy_h):
			var width: int = int((1.0 - abs(float(cy) / float(canopy_h) - 0.4) * 1.8) * 5.0 * _density)
			width = clampi(width, 1, 7)
			var cx_center: int = tx + sway * cy / maxi(canopy_h, 1)
			var canopy_color: Color = _mid_color.lerp(_accent_color, float(cy) / float(canopy_h) * 0.5)
			for dx: int in range(-width, width + 1):
				_safe_set_pixel(cx_center + dx, top_y + cy, canopy_color)


func _draw_near_layer() -> void:
	# Foreground vegetation — grass tufts and bushes
	for x: int in range(PIXEL_W):
		var h_norm: float = _terrain_near[x]
		var near_top: int = int(float(PIXEL_H) * h_norm)
		for y: int in range(near_top, PIXEL_H):
			_safe_set_pixel(x, y, _fg_color)
		# Grass tufts (every few pixels)
		if x % 3 == 0:
			var grass_h: int = _rng.randi_range(1, 3)
			var sway_offset: int = int(sin(_time * 2.0 + float(x) * 0.3) * 0.8)
			for gy: int in range(grass_h):
				var gx: int = x + sway_offset
				_safe_set_pixel(gx, near_top - gy - 1, _accent_color)


func _draw_atmosphere() -> void:
	# Mist bands that scroll horizontally
	var fog_intensity: float = 0.08
	if _weather == Weather.FOG:
		fog_intensity = 0.25
	elif _weather == Weather.RAIN:
		fog_intensity = 0.12
	elif _biome == "marais":
		fog_intensity = 0.18
	elif _biome == "broceliande":
		fog_intensity = 0.14

	var mist_y_start: int = int(PIXEL_H * 0.55)
	var mist_y_end: int = int(PIXEL_H * 0.80)
	for y: int in range(mist_y_start, mist_y_end):
		var band_t: float = float(y - mist_y_start) / float(mist_y_end - mist_y_start)
		var band_alpha: float = fog_intensity * sin(band_t * PI)
		for x: int in range(PIXEL_W):
			var scroll_x: float = float(x) + _mist_offset * 20.0
			var noise_val: float = sin(scroll_x * 0.08 + float(y) * 0.12) * 0.5 + 0.5
			if noise_val > 0.4:
				var mc: Color = Color(_mist_color.r, _mist_color.g, _mist_color.b, band_alpha * noise_val)
				_safe_blend_pixel(x, y, mc)


func _draw_particles() -> void:
	for i: int in range(PARTICLE_COUNT):
		var p: Vector2 = _particles[i]
		var px: int = int(p.x) % PIXEL_W
		var py: int = int(p.y) % PIXEL_H
		var pc: Color = _mist_color
		match _weather:
			Weather.RAIN:
				pc = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.6)
				# Rain streak (2px vertical)
				_safe_blend_pixel(px, py, pc)
				_safe_blend_pixel(px, (py + 1) % PIXEL_H, pc)
			Weather.SNOW:
				pc = MerlinVisual.CRT_PALETTE["snow_pixel"]
				_safe_blend_pixel(px, py, pc)
			Weather.FOG:
				pc = Color(_mist_color.r, _mist_color.g, _mist_color.b, 0.15)
				_safe_blend_pixel(px, py, pc)
				_safe_blend_pixel((px + 1) % PIXEL_W, py, pc)
			_:
				# Floating dust/fireflies
				var blink: float = 0.5 + 0.5 * sin(_time * 3.0 + float(i) * 2.1)
				pc = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.3 * blink)
				_safe_blend_pixel(px, py, pc)


func _draw_broceliande_glows() -> void:
	# Mysterious lights between trees (cyan/mist colored)
	for i: int in range(_glows.size()):
		var gp: Vector2 = _glows[i]
		var pulse: float = 0.3 + 0.7 * (0.5 + 0.5 * sin(_time * 1.8 + float(i) * 2.5))
		var glow_c: Color = Color(
			_mist_color.r * 1.5,
			_mist_color.g * 1.5,
			_mist_color.b * 1.2,
			0.15 * pulse
		)
		var gx: int = int(gp.x + sin(_time * 0.7 + float(i)) * 2.0)
		var gy: int = int(gp.y)
		# 3x3 soft glow
		for dx: int in range(-1, 2):
			for dy: int in range(-1, 2):
				var alpha_mult: float = 1.0 if (dx == 0 and dy == 0) else 0.4
				var gc: Color = Color(glow_c.r, glow_c.g, glow_c.b, glow_c.a * alpha_mult)
				_safe_blend_pixel((gx + dx) % PIXEL_W, clampi(gy + dy, 0, PIXEL_H - 1), gc)


# ---- Pixel Helpers ----

func _safe_set_pixel(x: int, y: int, c: Color) -> void:
	if x >= 0 and x < PIXEL_W and y >= 0 and y < PIXEL_H:
		_image.set_pixel(x, y, c)


func _safe_blend_pixel(x: int, y: int, c: Color) -> void:
	if x >= 0 and x < PIXEL_W and y >= 0 and y < PIXEL_H:
		var existing: Color = _image.get_pixel(x, y)
		var blended: Color = existing.lerp(Color(c.r, c.g, c.b), c.a)
		_image.set_pixel(x, y, blended)
