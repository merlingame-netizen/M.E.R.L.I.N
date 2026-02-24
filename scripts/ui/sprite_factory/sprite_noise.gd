class_name SpriteNoise
extends RefCounted
## Noise and pixel drawing utilities for procedural 32x32 sprite generation.
## Deterministic: same inputs always produce same outputs.


# ═══════════════════════════════════════════════════════════════════════════════
# HASH & NOISE
# ═══════════════════════════════════════════════════════════════════════════════

static func hash_2d(x: int, y: int) -> float:
	## Deterministic hash returning 0.0-1.0 from integer coordinates.
	var h: int = x * 374761393 + y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


static func smooth_noise(x: float, y: float) -> float:
	## Value noise with bilinear interpolation and smoothstep.
	var ix: int = int(floor(x))
	var iy: int = int(floor(y))
	var fx: float = x - floor(x)
	var fy: float = y - floor(y)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	var a: float = hash_2d(ix, iy)
	var b: float = hash_2d(ix + 1, iy)
	var c: float = hash_2d(ix, iy + 1)
	var d: float = hash_2d(ix + 1, iy + 1)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fy)


static func fbm(x: float, y: float, octaves: int = 3, seed_offset: float = 0.0) -> float:
	## Fractal Brownian Motion — layered noise for organic textures.
	var value: float = 0.0
	var amplitude: float = 0.5
	var frequency: float = 1.0
	var px: float = x + seed_offset
	var py: float = y + seed_offset * 0.7
	for i in range(octaves):
		value += amplitude * smooth_noise(px * frequency, py * frequency)
		amplitude *= 0.5
		frequency *= 2.0
	return value


# ═══════════════════════════════════════════════════════════════════════════════
# PIXEL DRAWING HELPERS (operate on Image)
# ═══════════════════════════════════════════════════════════════════════════════

static func set_px(img: Image, x: int, y: int, color: Color) -> void:
	## Safe pixel set with bounds check.
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		img.set_pixel(x, y, color)


static func get_px(img: Image, x: int, y: int) -> Color:
	## Safe pixel get with bounds check.
	if x >= 0 and x < img.get_width() and y >= 0 and y < img.get_height():
		return img.get_pixel(x, y)
	return Color.TRANSPARENT


static func fill_rect(img: Image, rx: int, ry: int, rw: int, rh: int, color: Color) -> void:
	## Fill a rectangle region.
	for py in range(maxi(0, ry), mini(img.get_height(), ry + rh)):
		for px in range(maxi(0, rx), mini(img.get_width(), rx + rw)):
			img.set_pixel(px, py, color)


static func fill_ellipse(img: Image, cx: float, cy: float, rx: float, ry: float, color: Color) -> void:
	## Fill an axis-aligned ellipse.
	var x0: int = maxi(0, int(cx - rx))
	var x1: int = mini(img.get_width() - 1, int(cx + rx))
	var y0: int = maxi(0, int(cy - ry))
	var y1: int = mini(img.get_height() - 1, int(cy + ry))
	for py in range(y0, y1 + 1):
		for px in range(x0, x1 + 1):
			var dx: float = (float(px) - cx) / rx
			var dy: float = (float(py) - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(px, py, color)


static func fill_circle(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
	## Fill a circle (shorthand for equal-radius ellipse).
	fill_ellipse(img, cx, cy, r, r, color)


static func draw_line_h(img: Image, x0: int, x1: int, y: int, color: Color) -> void:
	## Horizontal line.
	if y < 0 or y >= img.get_height():
		return
	for px in range(maxi(0, mini(x0, x1)), mini(img.get_width(), maxi(x0, x1) + 1)):
		img.set_pixel(px, y, color)


static func draw_line_v(img: Image, x: int, y0: int, y1: int, color: Color) -> void:
	## Vertical line.
	if x < 0 or x >= img.get_width():
		return
	for py in range(maxi(0, mini(y0, y1)), mini(img.get_height(), maxi(y0, y1) + 1)):
		img.set_pixel(x, py, color)


static func outline_existing(img: Image, outline_color: Color) -> void:
	## Add 1px outline around all non-transparent pixels.
	var w: int = img.get_width()
	var h: int = img.get_height()
	var outline_pixels: Array[Vector2i] = []
	for py in range(h):
		for px in range(w):
			if img.get_pixel(px, py).a < 0.01:
				# Check if any neighbor is opaque
				for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					var nx: int = px + d.x
					var ny: int = py + d.y
					if nx >= 0 and nx < w and ny >= 0 and ny < h:
						if img.get_pixel(nx, ny).a > 0.5:
							outline_pixels.append(Vector2i(px, py))
							break
	for p in outline_pixels:
		img.set_pixel(p.x, p.y, outline_color)


static func mirror_h(img: Image) -> void:
	## Mirror left half to right half (for symmetric sprites).
	var w: int = img.get_width()
	var h: int = img.get_height()
	var mid: int = w / 2
	for py in range(h):
		for px in range(mid):
			var mirror_x: int = w - 1 - px
			img.set_pixel(mirror_x, py, img.get_pixel(px, py))


static func scatter_pixels(img: Image, cx: float, cy: float, radius: float,
		color: Color, count: int, rng: RandomNumberGenerator) -> void:
	## Scatter random pixels in a circular area.
	for i in range(count):
		var angle: float = rng.randf() * TAU
		var dist: float = rng.randf() * radius
		var px: int = int(cx + cos(angle) * dist)
		var py: int = int(cy + sin(angle) * dist)
		set_px(img, px, py, color)
