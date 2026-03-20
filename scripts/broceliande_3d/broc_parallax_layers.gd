## BrocParallaxLayers — 2D parallax forest depth layers behind/in front of 3D
## 3 CanvasLayers with procedural pixel-art treelines that scroll with player movement.
## Near-zero GPU cost: Image rendered once per zone change, scroll = UV offset.

extends RefCounted

const PIXEL_W: int = 320
const PIXEL_H: int = 180

var _parent: Node
var _layers: Array[CanvasLayer] = []
var _textures: Array[TextureRect] = []
var _images: Array[Image] = []
var _scroll_offsets: Array[float] = [0.0, 0.0, 0.0]
var _parallax_speeds: Array[float] = [0.05, 0.15, 0.6]  # far, mid, near
var _current_zone: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Colors per layer (set from biome config)
var _far_color: Color = Color(0.08, 0.14, 0.06)
var _mid_color: Color = Color(0.10, 0.20, 0.08)
var _near_color: Color = Color(0.04, 0.08, 0.03)
var _sky_color: Color = Color(0.0, 0.0, 0.0, 0.0)


func setup(parent: Node, biome_key: String) -> void:
	_parent = parent
	_rng.seed = hash(biome_key + "_parallax")

	# Load biome colors
	var profile: Dictionary = MerlinVisual.BIOME_ART_PROFILES.get(
		biome_key.replace("foret_", "").replace("landes_", "").replace("cotes_", "").replace("villages_", "").replace("cercles_", "").replace("marais_", "").replace("collines_", "").replace("iles_", ""),
		MerlinVisual.BIOME_ART_PROFILES.get("broceliande", {})
	)
	if not profile.is_empty():
		_far_color = (profile.get("mist", Color(0.08, 0.14, 0.06)) as Color) * 0.4
		_mid_color = (profile.get("mid", Color(0.10, 0.20, 0.08)) as Color) * 0.6
		_near_color = (profile.get("foreground", Color(0.04, 0.08, 0.03)) as Color) * 0.8

	# Create 3 layers: far (-2), mid (-1), foreground (20)
	var layer_indices: Array[int] = [-2, -1, 20]
	for i in 3:
		var cl: CanvasLayer = CanvasLayer.new()
		cl.layer = layer_indices[i]
		cl.follow_viewport_enabled = false
		parent.add_child(cl)

		var img: Image = Image.create(PIXEL_W, PIXEL_H, false, Image.FORMAT_RGBA8)
		_images.append(img)

		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i == 2:  # foreground layer: semi-transparent
			tex_rect.modulate.a = 0.6
		cl.add_child(tex_rect)

		_layers.append(cl)
		_textures.append(tex_rect)

	# Initial render
	_render_all_layers()


func update(player_z: float, _player_x: float) -> void:
	# Scroll each layer based on player Z movement
	for i in 3:
		_scroll_offsets[i] = player_z * _parallax_speeds[i]
		if _textures[i] and is_instance_valid(_textures[i]):
			_textures[i].position.x = fmod(_scroll_offsets[i] * 2.0, 40.0) - 20.0
			if i < 2:  # far/mid layers: slight vertical parallax
				_textures[i].position.y = sin(player_z * 0.02 + float(i)) * 3.0


func set_zone(zone_idx: int) -> void:
	if zone_idx == _current_zone:
		return
	_current_zone = zone_idx
	_render_all_layers()


func _render_all_layers() -> void:
	_render_far_layer()
	_render_mid_layer()
	_render_near_layer()


func _render_far_layer() -> void:
	var img: Image = _images[0]
	img.fill(Color(0, 0, 0, 0))  # Transparent base

	# Treeline silhouettes — rolling sine hills with tree spikes
	var base_y: int = int(PIXEL_H * 0.55)
	for x in PIXEL_W:
		var hill_h: int = int(sin(float(x) * 0.03 + _rng.randf() * 0.01) * 12.0 + 8.0)
		# Tree spikes on hills
		var tree_h: int = 0
		if _rng.randf() < 0.15:
			tree_h = _rng.randi_range(8, 25)
		var top_y: int = base_y - hill_h - tree_h
		for y in range(maxi(top_y, 0), PIXEL_H):
			var c: Color = _far_color
			if y < base_y - hill_h:
				c.a = 0.7  # Tree trunk area slightly transparent
			else:
				c.a = 0.85
			_safe_set(img, x, y, c)

	_apply_image_to_texture(0)


func _render_mid_layer() -> void:
	var img: Image = _images[1]
	img.fill(Color(0, 0, 0, 0))

	var base_y: int = int(PIXEL_H * 0.65)
	_rng.seed = hash("mid_layer")
	for x in PIXEL_W:
		var hill_h: int = int(sin(float(x) * 0.05 + 1.7) * 8.0 + 5.0)
		var tree_h: int = 0
		if _rng.randf() < 0.2:
			tree_h = _rng.randi_range(10, 35)
		var top_y: int = base_y - hill_h - tree_h
		for y in range(maxi(top_y, 0), PIXEL_H):
			var c: Color = _mid_color
			if y < base_y - hill_h:
				c.a = 0.6
			else:
				c.a = 0.75
			_safe_set(img, x, y, c)

	_apply_image_to_texture(1)


func _render_near_layer() -> void:
	var img: Image = _images[2]
	img.fill(Color(0, 0, 0, 0))

	# Foreground: dark foliage at screen edges (vignette-like)
	_rng.seed = hash("near_layer")
	for x in PIXEL_W:
		# Edge darkening: more foliage near left/right edges
		var edge_factor: float = 1.0 - absf(float(x) / float(PIXEL_W) - 0.5) * 2.0
		edge_factor = clampf(edge_factor, 0.0, 1.0)
		var foliage_start: int = PIXEL_H  # default: no foliage in center

		if edge_factor < 0.3:  # Near edges
			foliage_start = int(PIXEL_H * _rng.randf_range(0.1, 0.4))
			# Add hanging vine/branch shapes
			if _rng.randf() < 0.3:
				foliage_start -= _rng.randi_range(5, 20)
		elif edge_factor < 0.5:
			foliage_start = int(PIXEL_H * _rng.randf_range(0.6, 0.85))

		# Bottom foliage (grass/undergrowth)
		var bottom_start: int = int(PIXEL_H * 0.88)

		for y in range(0, PIXEL_H):
			if y >= foliage_start or y >= bottom_start:
				var c: Color = _near_color
				c.a = 0.5 if y >= bottom_start else 0.35
				_safe_set(img, x, y, c)

	_apply_image_to_texture(2)


func _safe_set(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < PIXEL_W and y >= 0 and y < PIXEL_H:
		img.set_pixel(x, y, c)


func _apply_image_to_texture(idx: int) -> void:
	var tex: ImageTexture = ImageTexture.create_from_image(_images[idx])
	if _textures[idx] and is_instance_valid(_textures[idx]):
		_textures[idx].texture = tex
