class_name SpriteTemplates
extends RefCounted
## Procedural 32x32 pixel art generators organized by category.
## Each gen_* function returns a completed Image.
## Palette: [0]=outline [1]=deep_shadow [2]=shadow [3]=dark [4]=mid [5]=light [6]=highlight [7]=glow


const SIZE := 32


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 1: TREES / PLANTS
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_tree(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Generic tree: trunk + canopy with noise edges.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var trunk_w: int = rng.randi_range(2, 4)
	var trunk_h: int = rng.randi_range(8, 14)
	var canopy_rx: float = rng.randf_range(7.0, 13.0)
	var canopy_ry: float = rng.randf_range(6.0, 10.0)
	var trunk_x: int = SIZE / 2 - trunk_w / 2
	var trunk_top: int = SIZE - trunk_h

	# Trunk
	SpriteNoise.fill_rect(img, trunk_x, trunk_top, trunk_w, trunk_h, palette[2])
	# Trunk highlight (left side)
	SpriteNoise.draw_line_v(img, trunk_x + 1, trunk_top + 1, SIZE - 2, palette[3])

	# Canopy center
	var canopy_cy: float = float(trunk_top) - canopy_ry * 0.4
	var canopy_cx: float = SIZE / 2.0

	# Draw canopy with noise displacement
	var seed_f: float = float(variant) * 17.3
	for py in range(SIZE):
		for px in range(SIZE):
			var dx: float = (float(px) - canopy_cx) / canopy_rx
			var dy: float = (float(py) - canopy_cy) / canopy_ry
			var dist: float = dx * dx + dy * dy
			var noise_val: float = SpriteNoise.fbm(float(px) * 0.3, float(py) * 0.3, 2, seed_f) * 0.4
			if dist + noise_val < 1.0:
				# Depth shading: darker at bottom, lighter at top
				var shade: float = 1.0 - (float(py) - (canopy_cy - canopy_ry)) / (canopy_ry * 2.0)
				var col_idx: int = clampi(int(shade * 3.0) + 3, 3, 6)
				SpriteNoise.set_px(img, px, py, palette[col_idx])

	# Leaf detail scatter
	SpriteNoise.scatter_pixels(img, canopy_cx, canopy_cy, canopy_rx * 0.7,
		palette[6], rng.randi_range(8, 16), rng)

	# Outline
	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_bush(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Low bush / fern — no trunk, ground-level foliage.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0 + rng.randf_range(-2.0, 2.0)
	var cy: float = SIZE - 8.0 + rng.randf_range(-2.0, 2.0)
	var rx: float = rng.randf_range(8.0, 14.0)
	var ry: float = rng.randf_range(5.0, 8.0)
	SpriteNoise.fill_ellipse(img, cx, cy, rx, ry, palette[4])
	SpriteNoise.fill_ellipse(img, cx, cy - 1.0, rx * 0.7, ry * 0.6, palette[5])
	SpriteNoise.scatter_pixels(img, cx, cy, rx * 0.6, palette[6], 10, rng)
	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_mushroom(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Mushroom: stem + cap.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var stem_w: int = rng.randi_range(2, 4)
	var stem_h: int = rng.randi_range(6, 10)
	var cap_rx: float = rng.randf_range(5.0, 10.0)
	var cap_ry: float = rng.randf_range(3.0, 6.0)
	var cx: float = SIZE / 2.0
	var base_y: int = SIZE - 4
	# Stem
	SpriteNoise.fill_rect(img, int(cx) - stem_w / 2, base_y - stem_h, stem_w, stem_h, palette[5])
	# Cap
	var cap_cy: float = float(base_y - stem_h) - cap_ry * 0.3
	SpriteNoise.fill_ellipse(img, cx, cap_cy, cap_rx, cap_ry, palette[3])
	SpriteNoise.fill_ellipse(img, cx, cap_cy - 1.0, cap_rx * 0.7, cap_ry * 0.5, palette[4])
	# Spots
	SpriteNoise.scatter_pixels(img, cx, cap_cy, cap_rx * 0.5, palette[7], 4, rng)
	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 2: STONES / MINERALS
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_standing_stone(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Menhir / standing stone: tall, slightly tapered, rough edges.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var base_w: int = rng.randi_range(8, 14)
	var top_w: int = rng.randi_range(4, base_w - 2)
	var height: int = rng.randi_range(18, 28)
	var base_y: int = SIZE - 3
	var top_y: int = base_y - height
	var cx: float = SIZE / 2.0
	var seed_f: float = float(variant) * 23.7

	for py in range(top_y, base_y + 1):
		var t: float = float(py - top_y) / float(base_y - top_y)
		var w: float = lerpf(float(top_w), float(base_w), t) * 0.5
		# Noise displacement on edges
		var noise_l: float = SpriteNoise.smooth_noise(float(py) * 0.4, seed_f) * 2.0
		var noise_r: float = SpriteNoise.smooth_noise(float(py) * 0.4, seed_f + 50.0) * 2.0
		var x0: int = int(cx - w + noise_l)
		var x1: int = int(cx + w + noise_r)
		for px in range(x0, x1 + 1):
			# Shading: lighter on right, darker on left
			var shade_t: float = float(px - x0) / maxf(float(x1 - x0), 1.0)
			var col_idx: int = clampi(int(shade_t * 3.0) + 2, 2, 5)
			SpriteNoise.set_px(img, px, py, palette[col_idx])

	# Surface texture noise
	for py in range(top_y, base_y + 1):
		for px in range(SIZE):
			if SpriteNoise.get_px(img, px, py).a > 0.5:
				var n: float = SpriteNoise.fbm(float(px) * 0.5, float(py) * 0.5, 2, seed_f + 100.0)
				if n > 0.6:
					SpriteNoise.set_px(img, px, py, palette[6])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_dolmen(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Dolmen: two pillars + capstone.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var base_y: int = SIZE - 3
	var pillar_h: int = rng.randi_range(12, 18)
	var pillar_w: int = rng.randi_range(3, 5)
	var gap: int = rng.randi_range(6, 12)
	var cap_overhang: int = 2
	var cx: int = SIZE / 2

	# Left pillar
	var lx: int = cx - gap / 2 - pillar_w
	SpriteNoise.fill_rect(img, lx, base_y - pillar_h, pillar_w, pillar_h, palette[3])
	# Right pillar
	var rx: int = cx + gap / 2
	SpriteNoise.fill_rect(img, rx, base_y - pillar_h, pillar_w, pillar_h, palette[3])
	# Capstone
	var cap_y: int = base_y - pillar_h - 3
	var cap_x: int = lx - cap_overhang
	var cap_w: int = (rx + pillar_w + cap_overhang) - cap_x
	SpriteNoise.fill_rect(img, cap_x, cap_y, cap_w, 3, palette[4])
	# Highlight on cap top
	SpriteNoise.draw_line_h(img, cap_x + 1, cap_x + cap_w - 2, cap_y, palette[5])
	# Pillar highlights
	SpriteNoise.draw_line_v(img, lx + pillar_w - 1, base_y - pillar_h + 1, base_y - 1, palette[4])
	SpriteNoise.draw_line_v(img, rx + pillar_w - 1, base_y - pillar_h + 1, base_y - 1, palette[4])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_cairn(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Cairn: pile of stacked stones.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var base_y: int = SIZE - 4
	var cx: float = SIZE / 2.0
	var layers: int = rng.randi_range(3, 5)
	var cur_y: int = base_y
	var cur_w: float = rng.randf_range(12.0, 18.0)

	for i in range(layers):
		var stone_h: int = rng.randi_range(3, 5)
		var col: Color = palette[3 + (i % 3)]
		SpriteNoise.fill_ellipse(img, cx + rng.randf_range(-1.0, 1.0),
			float(cur_y) - float(stone_h) * 0.5, cur_w * 0.5, float(stone_h) * 0.5, col)
		cur_y -= stone_h - 1
		cur_w *= rng.randf_range(0.65, 0.85)

	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 3: WEAPONS / COMBAT
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_sword(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Sword: symmetric blade + crossguard + handle. Drawn left half then mirrored.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var blade_len: int = rng.randi_range(14, 20)
	var blade_w: int = rng.randi_range(2, 3)
	var cx: int = SIZE / 2
	var tip_y: int = 3
	var guard_y: int = tip_y + blade_len

	# Blade (left half, will mirror)
	for py in range(tip_y, guard_y):
		var t: float = float(py - tip_y) / float(blade_len)
		var w: int = clampi(int(t * float(blade_w)), 1, blade_w)
		for px in range(cx - w, cx + 1):
			var shade: Color = palette[5] if px == cx else palette[4]
			SpriteNoise.set_px(img, px, py, shade)

	# Crossguard
	var guard_w: int = rng.randi_range(4, 7)
	SpriteNoise.fill_rect(img, cx - guard_w, guard_y, guard_w * 2 + 1, 2, palette[3])
	SpriteNoise.draw_line_h(img, cx - guard_w, cx + guard_w, guard_y, palette[4])

	# Handle
	var handle_len: int = rng.randi_range(4, 7)
	SpriteNoise.fill_rect(img, cx - 1, guard_y + 2, 3, handle_len, palette[2])
	# Pommel
	SpriteNoise.fill_rect(img, cx - 1, guard_y + 2 + handle_len, 3, 2, palette[3])

	# Mirror left to right for symmetry
	SpriteNoise.mirror_h(img)
	# Blade edge highlight
	SpriteNoise.draw_line_v(img, cx, tip_y + 1, guard_y - 1, palette[6])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_axe(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Axe: handle + curved blade head.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var handle_h: int = rng.randi_range(16, 22)
	var handle_x: int = SIZE / 2
	var handle_top: int = SIZE - handle_h - 2

	# Handle
	SpriteNoise.fill_rect(img, handle_x - 1, handle_top, 3, handle_h, palette[2])

	# Axe head (right side of handle)
	var head_top: int = handle_top + 1
	var head_h: int = rng.randi_range(8, 12)
	var head_w: int = rng.randi_range(6, 10)
	for py in range(head_top, head_top + head_h):
		var t: float = float(py - head_top) / float(head_h)
		# Curved blade: wider in middle
		var w: float = sin(t * PI) * float(head_w)
		for px in range(handle_x + 1, handle_x + 1 + int(w)):
			var shade: Color = palette[4] if px < handle_x + int(w) - 1 else palette[5]
			SpriteNoise.set_px(img, px, py, shade)

	# Edge highlight
	for py in range(head_top + 1, head_top + head_h - 1):
		var t: float = float(py - head_top) / float(head_h)
		var edge_x: int = handle_x + int(sin(t * PI) * float(head_w))
		SpriteNoise.set_px(img, edge_x, py, palette[6])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_shield(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Shield: rounded rectangle with emblem.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var cy: float = SIZE / 2.0 + 2.0
	var rx: float = rng.randf_range(8.0, 12.0)
	var ry: float = rng.randf_range(10.0, 14.0)

	# Main body
	SpriteNoise.fill_ellipse(img, cx, cy, rx, ry, palette[3])
	# Inner lighter area
	SpriteNoise.fill_ellipse(img, cx, cy, rx * 0.75, ry * 0.75, palette[4])
	# Central emblem (based on variant)
	match variant % 3:
		0:  # Cross
			SpriteNoise.fill_rect(img, int(cx) - 1, int(cy) - 4, 3, 9, palette[6])
			SpriteNoise.fill_rect(img, int(cx) - 4, int(cy) - 1, 9, 3, palette[6])
		1:  # Diamond
			SpriteNoise.fill_rect(img, int(cx), int(cy) - 3, 1, 7, palette[6])
			SpriteNoise.fill_rect(img, int(cx) - 1, int(cy) - 2, 3, 5, palette[6])
			SpriteNoise.fill_rect(img, int(cx) - 2, int(cy) - 1, 5, 3, palette[6])
		2:  # Circle
			SpriteNoise.fill_circle(img, cx, cy, 3.0, palette[6])

	# Boss (center dot)
	SpriteNoise.set_px(img, int(cx), int(cy), palette[7])

	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 4: FIRE / LIGHT
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_fire(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Flame: teardrop shape with flickering edges, warm glow at core.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var base_y: int = SIZE - 5
	var flame_h: int = rng.randi_range(16, 24)
	var flame_w: float = rng.randf_range(5.0, 9.0)
	var seed_f: float = float(variant) * 13.1

	# Log base
	SpriteNoise.fill_rect(img, int(cx) - 4, base_y, 9, 3, palette[1])
	SpriteNoise.fill_rect(img, int(cx) - 3, base_y + 1, 7, 2, palette[2])

	# Flame body (teardrop: wide at bottom, pointed at top)
	for py in range(base_y - flame_h, base_y):
		var t: float = float(py - (base_y - flame_h)) / float(flame_h)
		# Teardrop: sin curve wider near base
		var w: float = sin(t * PI * 0.8 + 0.2) * flame_w
		var noise_l: float = SpriteNoise.smooth_noise(float(py) * 0.5, seed_f) * 2.5
		var noise_r: float = SpriteNoise.smooth_noise(float(py) * 0.5, seed_f + 40.0) * 2.5
		var x0: int = int(cx - w + noise_l)
		var x1: int = int(cx + w + noise_r)
		for px in range(x0, x1 + 1):
			# Inner core is brightest (palette[7]), outer is darker
			var dx: float = absf(float(px) - cx) / maxf(w, 1.0)
			var dy: float = 1.0 - t
			var heat: float = (1.0 - dx) * (0.5 + dy * 0.5)
			var col_idx: int
			if heat > 0.7:
				col_idx = 7  # glow / white-hot core
			elif heat > 0.4:
				col_idx = 6  # highlight / yellow
			elif heat > 0.2:
				col_idx = 5  # light / orange
			else:
				col_idx = 4  # mid / red-orange
			SpriteNoise.set_px(img, px, py, palette[col_idx])

	# Spark particles above flame
	SpriteNoise.scatter_pixels(img, cx, float(base_y - flame_h) - 2.0,
		flame_w * 0.6, palette[7], rng.randi_range(3, 7), rng)

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_lantern(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Lantern: rectangular frame with glowing center, hook on top.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var body_w: int = rng.randi_range(8, 12)
	var body_h: int = rng.randi_range(10, 16)
	var body_top: int = int(SIZE / 2.0) - int(body_h / 2.0) + 3
	var body_left: int = int(cx) - int(body_w / 2.0)

	# Hook / hanging ring
	SpriteNoise.fill_rect(img, int(cx) - 1, body_top - 4, 3, 2, palette[2])
	SpriteNoise.set_px(img, int(cx), body_top - 5, palette[3])
	# Chain
	SpriteNoise.draw_line_v(img, int(cx), body_top - 3, body_top, palette[2])

	# Frame (dark metal)
	SpriteNoise.fill_rect(img, body_left, body_top, body_w, body_h, palette[2])
	# Glass interior (glowing)
	SpriteNoise.fill_rect(img, body_left + 2, body_top + 2,
		body_w - 4, body_h - 4, palette[6])
	# Bright center
	SpriteNoise.fill_rect(img, body_left + 3, body_top + 3,
		body_w - 6, body_h - 6, palette[7])
	# Frame bars (vertical)
	SpriteNoise.draw_line_v(img, int(cx), body_top + 1, body_top + body_h - 2, palette[1])
	# Bottom cap
	SpriteNoise.fill_rect(img, body_left + 1, body_top + body_h - 1, body_w - 2, 2, palette[3])

	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 5: WATER
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_water(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Water pool / source: elliptical surface with ripple rings.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0 + rng.randf_range(-2.0, 2.0)
	var cy: float = SIZE / 2.0 + 4.0
	var rx: float = rng.randf_range(10.0, 14.0)
	var ry: float = rng.randf_range(5.0, 8.0)
	var _seed_f: float = float(variant) * 19.3

	# Water body (dark base)
	SpriteNoise.fill_ellipse(img, cx, cy, rx, ry, palette[2])
	# Mid-tone layer
	SpriteNoise.fill_ellipse(img, cx, cy - 0.5, rx * 0.85, ry * 0.85, palette[3])

	# Ripple rings (concentric lighter ellipses)
	for ring in range(3):
		var r_scale: float = 0.3 + float(ring) * 0.2
		var ring_ry: float = ry * r_scale
		var ring_rx: float = rx * r_scale
		var ring_cy: float = cy - float(ring) * 0.5
		# Draw ring outline (not filled)
		for angle_step in range(32):
			var angle: float = float(angle_step) * TAU / 32.0
			var px: int = int(cx + cos(angle) * ring_rx)
			var py: int = int(ring_cy + sin(angle) * ring_ry)
			SpriteNoise.set_px(img, px, py, palette[5])

	# Specular highlights
	SpriteNoise.scatter_pixels(img, cx - 2.0, cy - 2.0, rx * 0.4, palette[7],
		rng.randi_range(3, 6), rng)

	# Shore edge (lighter pixels at rim)
	SpriteNoise.scatter_pixels(img, cx, cy, rx * 0.9, palette[4],
		rng.randi_range(6, 10), rng)

	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 6: MAGIC / ARCANE
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_potion(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Potion bottle: narrow neck, round body, colored liquid.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var body_ry: float = rng.randf_range(7.0, 10.0)
	var body_rx: float = rng.randf_range(6.0, 9.0)
	var body_cy: float = SIZE - 5.0 - body_ry
	var neck_h: int = rng.randi_range(4, 7)
	var neck_w: int = 3

	# Bottle body (glass)
	SpriteNoise.fill_ellipse(img, cx, body_cy, body_rx, body_ry, palette[3])
	# Liquid fill (bottom 60%)
	var liquid_top: float = body_cy - body_ry * 0.2
	for py in range(int(liquid_top), int(body_cy + body_ry)):
		for px in range(int(cx - body_rx), int(cx + body_rx) + 1):
			var dx: float = (float(px) - cx) / body_rx
			var dy: float = (float(py) - body_cy) / body_ry
			if dx * dx + dy * dy < 0.9:
				SpriteNoise.set_px(img, px, py, palette[5])
	# Liquid surface line
	SpriteNoise.draw_line_h(img, int(cx - body_rx * 0.6), int(cx + body_rx * 0.6),
		int(liquid_top), palette[6])

	# Neck
	var neck_top: int = int(body_cy - body_ry) - neck_h
	SpriteNoise.fill_rect(img, int(cx) - int(neck_w / 2.0), neck_top,
		neck_w, neck_h + 2, palette[2])
	# Cork
	SpriteNoise.fill_rect(img, int(cx) - 2, neck_top - 2, 4, 3, palette[4])

	# Glass highlight
	SpriteNoise.draw_line_v(img, int(cx) - int(body_rx * 0.4),
		int(body_cy - body_ry * 0.5), int(body_cy + body_ry * 0.3), palette[7])

	# Glow bubble
	SpriteNoise.set_px(img, int(cx) + 1, int(body_cy) + 2, palette[7])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_grimoire(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Grimoire / spell book: thick rectangle with clasp and rune.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var book_w: int = rng.randi_range(16, 22)
	var book_h: int = rng.randi_range(12, 18)
	var book_x: int = int(cx) - int(book_w / 2.0)
	var book_y: int = int(SIZE / 2.0) - int(book_h / 2.0) + 2

	# Cover (dark)
	SpriteNoise.fill_rect(img, book_x, book_y, book_w, book_h, palette[2])
	# Front panel (slightly lighter)
	SpriteNoise.fill_rect(img, book_x + 1, book_y + 1, book_w - 2, book_h - 2, palette[3])
	# Spine (left edge, darkest)
	SpriteNoise.fill_rect(img, book_x, book_y, 3, book_h, palette[1])
	# Pages (visible at bottom edge)
	SpriteNoise.fill_rect(img, book_x + 3, book_y + book_h - 2, book_w - 4, 2, palette[6])

	# Central emblem / rune
	var emblem_cx: int = int(cx) + 1
	var emblem_cy: int = book_y + int(book_h / 2.0)
	match variant % 3:
		0:  # Circle rune
			SpriteNoise.fill_circle(img, float(emblem_cx), float(emblem_cy), 3.0, palette[5])
			SpriteNoise.set_px(img, emblem_cx, emblem_cy, palette[7])
		1:  # Diamond
			for d in range(-2, 3):
				var w: int = 2 - absi(d)
				SpriteNoise.draw_line_h(img, emblem_cx - w, emblem_cx + w, emblem_cy + d, palette[5])
			SpriteNoise.set_px(img, emblem_cx, emblem_cy, palette[7])
		2:  # Triple dot
			SpriteNoise.set_px(img, emblem_cx - 2, emblem_cy, palette[7])
			SpriteNoise.set_px(img, emblem_cx, emblem_cy, palette[7])
			SpriteNoise.set_px(img, emblem_cx + 2, emblem_cy, palette[7])

	# Clasp (right edge)
	SpriteNoise.fill_rect(img, book_x + book_w - 2, book_y + int(book_h / 2.0) - 1, 3, 3, palette[4])

	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 7: BUILDINGS
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_hut(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Hut / house: rectangular body with peaked thatch roof.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var body_w: int = rng.randi_range(14, 20)
	var body_h: int = rng.randi_range(8, 12)
	var base_y: int = SIZE - 4
	var body_x: int = int(cx) - int(body_w / 2.0)

	# Walls
	SpriteNoise.fill_rect(img, body_x, base_y - body_h, body_w, body_h, palette[4])
	# Wall shading (left darker)
	SpriteNoise.fill_rect(img, body_x, base_y - body_h, 2, body_h, palette[3])

	# Door
	SpriteNoise.fill_rect(img, int(cx) - 2, base_y - 6, 4, 6, palette[1])
	SpriteNoise.set_px(img, int(cx) + 1, base_y - 3, palette[5])  # doorknob

	# Peaked roof (triangle)
	var roof_top: int = base_y - body_h - rng.randi_range(6, 10)
	var roof_base: int = base_y - body_h + 1
	var roof_overhang: int = 2
	for py in range(roof_top, roof_base):
		var t: float = float(py - roof_top) / float(roof_base - roof_top)
		var half_w: int = int(t * float(int(body_w / 2.0) + roof_overhang))
		SpriteNoise.draw_line_h(img, int(cx) - half_w, int(cx) + half_w, py, palette[2])
	# Roof highlight ridge
	SpriteNoise.draw_line_v(img, int(cx), roof_top, roof_base - 2, palette[3])
	# Thatch texture
	for py in range(roof_top + 1, roof_base - 1):
		if py % 2 == 0:
			var t: float = float(py - roof_top) / float(roof_base - roof_top)
			var half_w: int = int(t * float(int(body_w / 2.0) + roof_overhang))
			SpriteNoise.draw_line_h(img, int(cx) - half_w + 1, int(cx) + half_w - 1, py, palette[3])

	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 8: SACRED / RITUAL
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_altar(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Altar: flat stone platform with central glow / offering.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var base_y: int = SIZE - 5
	var platform_w: int = rng.randi_range(18, 26)
	var platform_h: int = rng.randi_range(4, 6)
	var leg_h: int = rng.randi_range(4, 8)

	# Legs
	var leg_w: int = 3
	SpriteNoise.fill_rect(img, int(cx) - int(platform_w / 2.0) + 1, base_y - leg_h,
		leg_w, leg_h, palette[2])
	SpriteNoise.fill_rect(img, int(cx) + int(platform_w / 2.0) - leg_w - 1, base_y - leg_h,
		leg_w, leg_h, palette[2])

	# Platform slab
	var slab_y: int = base_y - leg_h - platform_h
	SpriteNoise.fill_rect(img, int(cx) - int(platform_w / 2.0), slab_y,
		platform_w, platform_h, palette[3])
	# Top surface highlight
	SpriteNoise.draw_line_h(img, int(cx) - int(platform_w / 2.0) + 1,
		int(cx) + int(platform_w / 2.0) - 1, slab_y, palette[5])

	# Central offering / glow
	var glow_y: float = float(slab_y) - 2.0
	SpriteNoise.fill_circle(img, cx, glow_y, 3.0, palette[6])
	SpriteNoise.set_px(img, int(cx), int(glow_y), palette[7])

	# Surface rune marks (variant-dependent)
	if variant % 2 == 0:
		SpriteNoise.set_px(img, int(cx) - 4, slab_y + 1, palette[5])
		SpriteNoise.set_px(img, int(cx) + 4, slab_y + 1, palette[5])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_crown(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Crown / torc: circular band with pointed tips, central gem.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var cy: float = SIZE / 2.0 + 2.0
	var band_rx: float = rng.randf_range(8.0, 12.0)
	var band_ry: float = rng.randf_range(3.0, 5.0)
	var band_h: int = rng.randi_range(4, 6)

	# Band (elliptical ring)
	SpriteNoise.fill_ellipse(img, cx, cy, band_rx, band_ry + float(band_h) * 0.5, palette[4])
	# Hollow inside
	SpriteNoise.fill_ellipse(img, cx, cy + 1.0, band_rx - 2.0,
		band_ry + float(band_h) * 0.5 - 2.0, Color(0, 0, 0, 0))

	# Points / prongs (3 or 5)
	var num_points: int = 3 + (rng.randi() % 2) * 2
	var point_h: int = rng.randi_range(4, 7)
	for i in range(num_points):
		var t: float = float(i) / float(num_points - 1)
		var px: int = int(cx - band_rx + 2.0 + t * (band_rx * 2.0 - 4.0))
		var tip_y: int = int(cy - band_ry) - point_h
		# Point triangle
		for py in range(tip_y, int(cy - band_ry) + 1):
			var pt: float = float(py - tip_y) / float(int(cy - band_ry) - tip_y + 1)
			var half_w: int = maxi(0, int(pt * 1.5))
			SpriteNoise.draw_line_h(img, px - half_w, px + half_w, py, palette[5])
		# Tip gem
		SpriteNoise.set_px(img, px, tip_y, palette[7])

	# Central gem (largest)
	SpriteNoise.fill_circle(img, cx, cy - band_ry - 1.0, 2.0, palette[6])
	SpriteNoise.set_px(img, int(cx), int(cy - band_ry) - 1, palette[7])

	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# CHARACTER HELPERS — shared body-part drawing
# ═══════════════════════════════════════════════════════════════════════════════

static func _draw_humanoid_body(img: Image, palette: Array[Color], rng: RandomNumberGenerator,
		head_r: float = 4.0, body_h: int = 8, robe: bool = false) -> void:
	## Draw a basic humanoid: head + torso + legs. Caller adds details on top.
	var cx: float = SIZE / 2.0
	var head_cy: float = 7.0
	var torso_top: int = int(head_cy + head_r) + 1
	var torso_w: int = rng.randi_range(6, 10)

	# Head
	SpriteNoise.fill_circle(img, cx, head_cy, head_r, palette[5])
	# Eyes (2 dark dots)
	SpriteNoise.set_px(img, int(cx) - 1, int(head_cy), palette[1])
	SpriteNoise.set_px(img, int(cx) + 1, int(head_cy), palette[1])

	# Torso
	SpriteNoise.fill_rect(img, int(cx) - int(torso_w / 2.0), torso_top,
		torso_w, body_h, palette[3])
	# Torso shading (lighter center)
	SpriteNoise.fill_rect(img, int(cx) - int(torso_w / 2.0) + 2, torso_top + 1,
		torso_w - 4, body_h - 2, palette[4])

	# Arms (thin rectangles on sides)
	var arm_w: int = 2
	var arm_h: int = body_h - 1
	SpriteNoise.fill_rect(img, int(cx) - int(torso_w / 2.0) - arm_w, torso_top + 1,
		arm_w, arm_h, palette[4])
	SpriteNoise.fill_rect(img, int(cx) + int(torso_w / 2.0), torso_top + 1,
		arm_w, arm_h, palette[4])

	var legs_top: int = torso_top + body_h
	if robe:
		# Flowing robe (triangular, wider at bottom)
		var robe_h: int = rng.randi_range(8, 12)
		for py in range(legs_top, legs_top + robe_h):
			var t: float = float(py - legs_top) / float(robe_h)
			var half_w: int = int(float(torso_w) * 0.5 + t * 4.0)
			SpriteNoise.draw_line_h(img, int(cx) - half_w, int(cx) + half_w, py, palette[2])
		# Robe highlight folds
		SpriteNoise.draw_line_v(img, int(cx) - 2, legs_top + 2, legs_top + robe_h - 2, palette[3])
		SpriteNoise.draw_line_v(img, int(cx) + 2, legs_top + 2, legs_top + robe_h - 2, palette[3])
	else:
		# Legs (two columns)
		var leg_h: int = rng.randi_range(6, 10)
		var leg_w: int = int(torso_w / 2.0) - 1
		SpriteNoise.fill_rect(img, int(cx) - leg_w - 1, legs_top, leg_w, leg_h, palette[2])
		SpriteNoise.fill_rect(img, int(cx) + 1, legs_top, leg_w, leg_h, palette[2])
		# Boots / feet
		SpriteNoise.fill_rect(img, int(cx) - leg_w - 2, legs_top + leg_h, leg_w + 2, 2, palette[1])
		SpriteNoise.fill_rect(img, int(cx), legs_top + leg_h, leg_w + 2, 2, palette[1])


static func _draw_quadruped(img: Image, palette: Array[Color], rng: RandomNumberGenerator,
		body_len: int = 16, body_h: int = 8, head_r: float = 4.0) -> void:
	## Draw a basic 4-legged beast: body ellipse + head circle + 4 legs.
	var body_cx: float = SIZE / 2.0 + 1.0
	var body_cy: float = SIZE / 2.0 + 2.0
	var body_rx: float = float(body_len) * 0.5
	var body_ry: float = float(body_h) * 0.5

	# Body
	SpriteNoise.fill_ellipse(img, body_cx, body_cy, body_rx, body_ry, palette[3])
	SpriteNoise.fill_ellipse(img, body_cx, body_cy - 1.0, body_rx * 0.8, body_ry * 0.7, palette[4])

	# Head (forward of body)
	var head_cx: float = body_cx - body_rx + head_r * 0.5
	var head_cy: float = body_cy - body_ry * 0.3
	SpriteNoise.fill_circle(img, head_cx, head_cy, head_r, palette[4])
	SpriteNoise.fill_circle(img, head_cx, head_cy, head_r * 0.7, palette[5])
	# Eye
	SpriteNoise.set_px(img, int(head_cx) - 1, int(head_cy) - 1, palette[0])

	# 4 Legs
	var leg_w: int = 2
	var leg_h: int = rng.randi_range(5, 8)
	var leg_y: int = int(body_cy + body_ry) - 1
	# Front legs
	SpriteNoise.fill_rect(img, int(body_cx - body_rx * 0.5), leg_y, leg_w, leg_h, palette[2])
	SpriteNoise.fill_rect(img, int(body_cx - body_rx * 0.5) + 3, leg_y, leg_w, leg_h, palette[2])
	# Back legs
	SpriteNoise.fill_rect(img, int(body_cx + body_rx * 0.3), leg_y, leg_w, leg_h, palette[2])
	SpriteNoise.fill_rect(img, int(body_cx + body_rx * 0.3) + 3, leg_y, leg_w, leg_h, palette[2])


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 9: CHARACTERS — HUMANOIDS
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_druid(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Druid: robed figure with staff and hood. Wise silhouette.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_draw_humanoid_body(img, palette, rng, 4.0, 8, true)  # robed
	var cx: float = SIZE / 2.0

	# Hood (dark semi-circle over head)
	SpriteNoise.fill_circle(img, cx, 6.0, 5.0, palette[2])
	SpriteNoise.fill_circle(img, cx, 5.5, 4.0, palette[3])
	# Face visible underneath
	SpriteNoise.fill_circle(img, cx, 7.0, 3.0, palette[5])
	SpriteNoise.set_px(img, int(cx) - 1, 7, palette[1])
	SpriteNoise.set_px(img, int(cx) + 1, 7, palette[1])

	# Staff (right side, tall)
	var staff_x: int = int(cx) + 7
	SpriteNoise.draw_line_v(img, staff_x, 2, SIZE - 4, palette[2])
	SpriteNoise.draw_line_v(img, staff_x, 2, SIZE - 4, palette[3])
	# Staff orb
	SpriteNoise.fill_circle(img, float(staff_x), 2.0, 2.0, palette[6])
	SpriteNoise.set_px(img, staff_x, 1, palette[7])

	# Beard (variant-dependent)
	if variant % 2 == 0:
		SpriteNoise.fill_rect(img, int(cx) - 1, 10, 3, 4, palette[6])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_warrior(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Warrior: armored figure with weapon. Strong silhouette.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_draw_humanoid_body(img, palette, rng, 4.0, 9, false)
	var cx: float = SIZE / 2.0

	# Helmet (pointed or round)
	if variant % 2 == 0:
		# Pointed helmet
		SpriteNoise.fill_circle(img, cx, 6.0, 5.0, palette[3])
		SpriteNoise.fill_rect(img, int(cx) - 1, 1, 3, 3, palette[4])
		SpriteNoise.set_px(img, int(cx), 0, palette[5])
	else:
		# Round helmet with nose guard
		SpriteNoise.fill_circle(img, cx, 6.0, 5.0, palette[3])
		SpriteNoise.draw_line_v(img, int(cx), 3, 9, palette[4])

	# Shoulder armor (wider than arms)
	SpriteNoise.fill_rect(img, int(cx) - 8, 12, 3, 3, palette[4])
	SpriteNoise.fill_rect(img, int(cx) + 6, 12, 3, 3, palette[4])

	# Belt
	SpriteNoise.draw_line_h(img, int(cx) - 4, int(cx) + 4, 20, palette[5])
	SpriteNoise.set_px(img, int(cx), 20, palette[6])  # buckle

	# Sword on side
	var sword_x: int = int(cx) - 8
	SpriteNoise.draw_line_v(img, sword_x, 14, 26, palette[5])
	SpriteNoise.draw_line_h(img, sword_x - 1, sword_x + 1, 20, palette[4])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_villager(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Villager / peasant: simple clothes, tool in hand.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_draw_humanoid_body(img, palette, rng, 3.5, 8, false)
	var cx: float = SIZE / 2.0

	# Simple hat (flat rectangle)
	SpriteNoise.fill_rect(img, int(cx) - 4, 2, 9, 2, palette[3])
	SpriteNoise.fill_rect(img, int(cx) - 2, 1, 5, 2, palette[4])

	# Apron / front cloth
	SpriteNoise.fill_rect(img, int(cx) - 3, 15, 6, 6, palette[5])

	# Tool in hand (right side — pitchfork or broom)
	var tool_x: int = int(cx) + 7
	SpriteNoise.draw_line_v(img, tool_x, 8, SIZE - 4, palette[2])
	# Fork tines
	SpriteNoise.set_px(img, tool_x - 1, 7, palette[3])
	SpriteNoise.set_px(img, tool_x, 6, palette[3])
	SpriteNoise.set_px(img, tool_x + 1, 7, palette[3])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_noble(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Noble / lord: rich robes, crown or circlet, upright posture.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_draw_humanoid_body(img, palette, rng, 4.0, 8, true)  # long robes
	var cx: float = SIZE / 2.0

	# Crown / circlet
	SpriteNoise.draw_line_h(img, int(cx) - 3, int(cx) + 3, 2, palette[6])
	SpriteNoise.set_px(img, int(cx) - 2, 1, palette[7])
	SpriteNoise.set_px(img, int(cx), 1, palette[7])
	SpriteNoise.set_px(img, int(cx) + 2, 1, palette[7])

	# Rich robe overlay (lighter center stripe)
	for py in range(16, 28):
		SpriteNoise.set_px(img, int(cx), py, palette[5])
		SpriteNoise.set_px(img, int(cx) - 1, py, palette[4])
		SpriteNoise.set_px(img, int(cx) + 1, py, palette[4])

	# Medallion / pendant
	SpriteNoise.fill_circle(img, cx, 14.0, 2.0, palette[6])
	SpriteNoise.set_px(img, int(cx), 14, palette[7])

	# Cape (behind, variant-dependent)
	if variant % 2 == 0:
		for py in range(12, 26):
			var cape_w: int = int(float(py - 12) * 0.5) + 1
			SpriteNoise.set_px(img, int(cx) - 6 - cape_w, py, palette[2])
			SpriteNoise.set_px(img, int(cx) + 6 + cape_w, py, palette[2])

	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 10: CHARACTERS — BEASTS
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_wolf(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Wolf: low, elongated quadruped with pointed ears and tail.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_draw_quadruped(img, palette, rng, 18, 8, 4.0)

	# Pointed ears
	var head_cx: float = SIZE / 2.0 - 6.0
	var head_cy: float = SIZE / 2.0 + 0.5
	SpriteNoise.set_px(img, int(head_cx) - 2, int(head_cy) - 5, palette[4])
	SpriteNoise.set_px(img, int(head_cx) + 1, int(head_cy) - 5, palette[4])
	SpriteNoise.set_px(img, int(head_cx) - 2, int(head_cy) - 4, palette[4])
	SpriteNoise.set_px(img, int(head_cx) + 1, int(head_cy) - 4, palette[4])

	# Snout
	SpriteNoise.fill_rect(img, int(head_cx) - 4, int(head_cy), 3, 2, palette[5])
	SpriteNoise.set_px(img, int(head_cx) - 4, int(head_cy), palette[1])  # nose

	# Tail (curved upward from back)
	var tail_base_x: int = int(SIZE / 2.0) + 10
	var tail_base_y: int = int(SIZE / 2.0)
	for i in range(6):
		SpriteNoise.set_px(img, tail_base_x + i, tail_base_y - i, palette[3])
		SpriteNoise.set_px(img, tail_base_x + i, tail_base_y - i - 1, palette[4])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_deer(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Deer / stag: tall legs, slender body, antlers (variant-dependent).
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_draw_quadruped(img, palette, rng, 14, 6, 3.5)
	var cx: float = SIZE / 2.0

	# Longer legs (overwrite shorter ones)
	var body_cy: float = cx + 3.0
	var leg_y: int = int(body_cy + 3.0)
	var leg_h: int = 10
	SpriteNoise.fill_rect(img, int(cx) - 5, leg_y, 2, leg_h, palette[3])
	SpriteNoise.fill_rect(img, int(cx) - 2, leg_y, 2, leg_h, palette[3])
	SpriteNoise.fill_rect(img, int(cx) + 4, leg_y, 2, leg_h, palette[3])
	SpriteNoise.fill_rect(img, int(cx) + 7, leg_y, 2, leg_h, palette[3])

	# Antlers (branching lines from head)
	if variant % 3 != 2:  # 2/3 have antlers
		var head_x: int = int(cx) - 5
		var head_y: int = int(body_cy) - 5
		# Left antler
		for i in range(5):
			SpriteNoise.set_px(img, head_x - 1 - i, head_y - 2 - i, palette[2])
			if i == 2 or i == 4:
				SpriteNoise.set_px(img, head_x - i, head_y - 3 - i, palette[2])
		# Right antler
		for i in range(5):
			SpriteNoise.set_px(img, head_x + 1 + i, head_y - 2 - i, palette[2])
			if i == 2 or i == 4:
				SpriteNoise.set_px(img, head_x + i, head_y - 3 - i, palette[2])

	# Tail (short flick)
	SpriteNoise.set_px(img, int(cx) + 9, int(body_cy) - 2, palette[5])
	SpriteNoise.set_px(img, int(cx) + 10, int(body_cy) - 3, palette[5])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_bird(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Bird / raven: compact body with spread wings, beak, tail feathers.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var cy: float = SIZE / 2.0 + 2.0

	# Body (compact oval)
	SpriteNoise.fill_ellipse(img, cx, cy, 5.0, 4.0, palette[2])
	SpriteNoise.fill_ellipse(img, cx, cy - 0.5, 4.0, 3.0, palette[3])

	# Head (small circle, forward)
	SpriteNoise.fill_circle(img, cx - 5.0, cy - 2.0, 3.0, palette[3])
	SpriteNoise.fill_circle(img, cx - 5.0, cy - 2.5, 2.5, palette[4])
	# Eye
	SpriteNoise.set_px(img, int(cx) - 6, int(cy) - 3, palette[7])
	# Beak
	SpriteNoise.set_px(img, int(cx) - 8, int(cy) - 2, palette[5])
	SpriteNoise.set_px(img, int(cx) - 9, int(cy) - 2, palette[5])

	# Wings (spread)
	var wing_span: int = rng.randi_range(8, 12)
	for i in range(wing_span):
		var wy: float = cy - 4.0 + float(i) * 0.3
		var wx_l: float = cx - 2.0 - float(i) * 1.2
		var wx_r: float = cx + 2.0 + float(i) * 1.2
		SpriteNoise.set_px(img, int(wx_l), int(wy), palette[2])
		SpriteNoise.set_px(img, int(wx_l), int(wy) - 1, palette[3])
		SpriteNoise.set_px(img, int(wx_r), int(wy), palette[2])
		SpriteNoise.set_px(img, int(wx_r), int(wy) - 1, palette[3])

	# Tail feathers
	for i in range(4):
		SpriteNoise.set_px(img, int(cx) + 5 + i, int(cy) + 1 + i, palette[2])
		SpriteNoise.set_px(img, int(cx) + 5 + i, int(cy) + 2 + i, palette[1])

	# Legs (thin)
	SpriteNoise.draw_line_v(img, int(cx) - 1, int(cy) + 4, int(cy) + 7, palette[2])
	SpriteNoise.draw_line_v(img, int(cx) + 1, int(cy) + 4, int(cy) + 7, palette[2])

	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 11: CHARACTERS — FAE / MYTHICAL
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_korrigan(palette: Array[Color], _rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Korrigan: small impish figure, large head, pointed ears, mischievous.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0

	# Large head (disproportionate)
	var head_cy: float = 10.0
	SpriteNoise.fill_circle(img, cx, head_cy, 6.0, palette[4])
	SpriteNoise.fill_circle(img, cx, head_cy - 0.5, 5.0, palette[5])

	# Pointed ears (large, sideways)
	SpriteNoise.fill_rect(img, int(cx) - 8, int(head_cy) - 2, 3, 2, palette[5])
	SpriteNoise.set_px(img, int(cx) - 9, int(head_cy) - 1, palette[5])
	SpriteNoise.fill_rect(img, int(cx) + 6, int(head_cy) - 2, 3, 2, palette[5])
	SpriteNoise.set_px(img, int(cx) + 9, int(head_cy) - 1, palette[5])

	# Big eyes (wide apart)
	SpriteNoise.fill_rect(img, int(cx) - 3, int(head_cy) - 1, 2, 2, palette[7])
	SpriteNoise.fill_rect(img, int(cx) + 2, int(head_cy) - 1, 2, 2, palette[7])
	SpriteNoise.set_px(img, int(cx) - 2, int(head_cy), palette[0])
	SpriteNoise.set_px(img, int(cx) + 3, int(head_cy), palette[0])

	# Grin
	SpriteNoise.draw_line_h(img, int(cx) - 2, int(cx) + 2, int(head_cy) + 3, palette[1])

	# Small body
	SpriteNoise.fill_rect(img, int(cx) - 3, 17, 7, 5, palette[3])
	# Stubby legs
	SpriteNoise.fill_rect(img, int(cx) - 3, 22, 3, 4, palette[2])
	SpriteNoise.fill_rect(img, int(cx) + 1, 22, 3, 4, palette[2])
	# Stubby arms
	SpriteNoise.fill_rect(img, int(cx) - 5, 17, 2, 4, palette[3])
	SpriteNoise.fill_rect(img, int(cx) + 4, 17, 2, 4, palette[3])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_spirit(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Spirit / ghost / spectre: translucent floating figure, trailing wisps.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var seed_f: float = float(variant) * 29.1

	# Main body (elongated, tapering downward with noise edges)
	for py in range(4, SIZE - 2):
		var t: float = float(py - 4) / float(SIZE - 6)
		var base_w: float = 5.0 + (1.0 - t) * 6.0  # wider at top, narrower at bottom
		var noise_offset: float = SpriteNoise.smooth_noise(float(py) * 0.4, seed_f) * 3.0
		var x0: int = int(cx - base_w + noise_offset)
		var x1: int = int(cx + base_w - noise_offset)
		for px in range(x0, x1 + 1):
			var dx: float = absf(float(px) - cx) / maxf(base_w, 1.0)
			# Semi-transparent with inner glow
			var alpha: float = (1.0 - dx * 0.5) * (1.0 - t * 0.4)
			var col: Color = palette[5]
			if dx < 0.3:
				col = palette[7]  # inner glow
			elif dx < 0.6:
				col = palette[6]
			col.a = clampf(alpha, 0.3, 0.9)
			SpriteNoise.set_px(img, px, py, col)

	# Face (hollow eyes, no mouth)
	SpriteNoise.fill_circle(img, cx - 3.0, 9.0, 2.0, palette[0])  # left eye socket
	SpriteNoise.fill_circle(img, cx + 3.0, 9.0, 2.0, palette[0])  # right eye socket
	# Glowing pupils
	SpriteNoise.set_px(img, int(cx) - 3, 9, palette[7])
	SpriteNoise.set_px(img, int(cx) + 3, 9, palette[7])

	# Trailing wisps at bottom
	for i in range(5):
		var wisp_x: float = cx + rng.randf_range(-6.0, 6.0)
		var wisp_y: int = SIZE - rng.randi_range(1, 5)
		SpriteNoise.set_px(img, int(wisp_x), wisp_y, Color(palette[6].r, palette[6].g, palette[6].b, 0.4))

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_fae(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Fae / fairy creature: small glowing figure with wings.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var cy: float = SIZE / 2.0

	# Small body (luminous)
	SpriteNoise.fill_ellipse(img, cx, cy, 3.0, 4.0, palette[6])
	SpriteNoise.fill_ellipse(img, cx, cy - 0.5, 2.0, 3.0, palette[7])

	# Head (tiny, bright)
	SpriteNoise.fill_circle(img, cx, cy - 5.0, 2.5, palette[6])
	SpriteNoise.fill_circle(img, cx, cy - 5.5, 2.0, palette[7])
	# Eyes
	SpriteNoise.set_px(img, int(cx) - 1, int(cy) - 6, palette[0])
	SpriteNoise.set_px(img, int(cx) + 1, int(cy) - 6, palette[0])

	# Wings (butterfly-like, left and right)
	var wing_h: int = rng.randi_range(8, 12)
	for i in range(wing_h):
		var t: float = float(i) / float(wing_h)
		var wing_w: float = sin(t * PI) * 8.0
		var wy: int = int(cy) - int(wing_h / 2.0) + i
		# Left wing
		SpriteNoise.draw_line_h(img, int(cx - 3.0 - wing_w), int(cx) - 3, wy, palette[5])
		# Right wing
		SpriteNoise.draw_line_h(img, int(cx) + 3, int(cx + 3.0 + wing_w), wy, palette[5])

	# Wing details (veins)
	SpriteNoise.draw_line_v(img, int(cx) - 7, int(cy) - 3, int(cy) + 3, palette[6])
	SpriteNoise.draw_line_v(img, int(cx) + 7, int(cy) - 3, int(cy) + 3, palette[6])

	# Glow aura
	SpriteNoise.scatter_pixels(img, cx, cy, 10.0,
		Color(palette[7].r, palette[7].g, palette[7].b, 0.3), rng.randi_range(8, 14), rng)

	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 12: CHARACTERS — UNDEAD / DARK
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_undead(palette: Array[Color], _rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Undead / skeleton: gaunt humanoid, visible bones, ragged cloth.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0

	# Skull (slightly elongated)
	SpriteNoise.fill_ellipse(img, cx, 7.0, 4.0, 5.0, palette[6])
	SpriteNoise.fill_ellipse(img, cx, 6.5, 3.5, 4.5, palette[7])
	# Dark eye sockets
	SpriteNoise.fill_rect(img, int(cx) - 2, 5, 2, 2, palette[0])
	SpriteNoise.fill_rect(img, int(cx) + 1, 5, 2, 2, palette[0])
	# Jaw / teeth
	SpriteNoise.draw_line_h(img, int(cx) - 2, int(cx) + 2, 10, palette[6])
	SpriteNoise.set_px(img, int(cx) - 1, 10, palette[0])
	SpriteNoise.set_px(img, int(cx) + 1, 10, palette[0])

	# Ribcage / torso (thin lines)
	for i in range(5):
		var ry: int = 13 + i * 2
		SpriteNoise.draw_line_h(img, int(cx) - 3, int(cx) + 3, ry, palette[5])
	# Spine
	SpriteNoise.draw_line_v(img, int(cx), 12, 24, palette[6])

	# Ragged cloth (variant-dependent)
	if variant % 2 == 0:
		var seed_f: float = float(variant) * 41.3
		for py in range(14, 26):
			var noise_w: float = SpriteNoise.smooth_noise(float(py) * 0.6, seed_f) * 4.0
			SpriteNoise.set_px(img, int(cx) - 4 - int(noise_w), py, palette[2])
			SpriteNoise.set_px(img, int(cx) + 4 + int(noise_w), py, palette[2])

	# Arms (bone thin)
	SpriteNoise.draw_line_v(img, int(cx) - 5, 14, 22, palette[5])
	SpriteNoise.draw_line_v(img, int(cx) + 5, 14, 22, palette[5])

	# Legs (thin)
	SpriteNoise.draw_line_v(img, int(cx) - 2, 24, SIZE - 3, palette[5])
	SpriteNoise.draw_line_v(img, int(cx) + 2, 24, SIZE - 3, palette[5])

	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 13: EXTRA OBJECTS — TORCH, WELL, BOAT, TENT, HARP, SKULL
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_torch(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Torch: wooden handle + flame tip. Distinct from gen_fire (hand-held).
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var handle_h: int = rng.randi_range(14, 18)
	var handle_top: int = SIZE - handle_h - 2

	# Handle (tapered wood)
	for py in range(handle_top, SIZE - 2):
		var t: float = float(py - handle_top) / float(handle_h)
		var w: float = 1.5 + t * 0.5
		SpriteNoise.draw_line_h(img, int(cx - w), int(cx + w), py, palette[2])
	# Handle highlight
	SpriteNoise.draw_line_v(img, int(cx), handle_top + 2, SIZE - 4, palette[3])

	# Wrapping at top (cloth/pitch)
	SpriteNoise.fill_rect(img, int(cx) - 2, handle_top - 1, 5, 3, palette[1])

	# Flame on top (small, intense)
	var flame_base: int = handle_top - 2
	var flame_h: int = rng.randi_range(6, 10)
	var seed_f: float = float(variant) * 17.9
	for py in range(flame_base - flame_h, flame_base):
		var t: float = float(py - (flame_base - flame_h)) / float(flame_h)
		var w: float = sin(t * PI * 0.7 + 0.3) * 3.5
		var noise_disp: float = SpriteNoise.smooth_noise(float(py) * 0.7, seed_f) * 1.5
		for px in range(int(cx - w + noise_disp), int(cx + w - noise_disp) + 1):
			var heat: float = 1.0 - absf(float(px) - cx) / maxf(w, 1.0)
			var col_idx: int = 5 if heat < 0.4 else (6 if heat < 0.7 else 7)
			SpriteNoise.set_px(img, px, py, palette[col_idx])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_well(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Well: circular stone wall, wooden frame, bucket.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var well_r: float = rng.randf_range(7.0, 10.0)
	var well_cy: float = SIZE - 8.0

	# Stone wall (ellipse, perspective top-down)
	SpriteNoise.fill_ellipse(img, cx, well_cy, well_r, well_r * 0.5, palette[3])
	# Inner darkness
	SpriteNoise.fill_ellipse(img, cx, well_cy, well_r - 2.0, well_r * 0.5 - 1.5, palette[0])
	# Rim highlight
	for angle_step in range(24):
		var angle: float = float(angle_step) * TAU / 24.0
		if angle < PI:  # only top half
			var px: int = int(cx + cos(angle) * well_r)
			var py: int = int(well_cy + sin(angle) * well_r * 0.5)
			SpriteNoise.set_px(img, px, py, palette[5])

	# Wooden frame (A-frame above well)
	var frame_top: int = int(well_cy) - rng.randi_range(12, 16)
	# Left post
	SpriteNoise.draw_line_v(img, int(cx - well_r) + 1, frame_top, int(well_cy) - 2, palette[2])
	# Right post
	SpriteNoise.draw_line_v(img, int(cx + well_r) - 1, frame_top, int(well_cy) - 2, palette[2])
	# Crossbar
	SpriteNoise.draw_line_h(img, int(cx - well_r) + 1, int(cx + well_r) - 1, frame_top, palette[3])
	# Rope
	SpriteNoise.draw_line_v(img, int(cx), frame_top + 1, frame_top + 6, palette[4])
	# Bucket
	SpriteNoise.fill_rect(img, int(cx) - 2, frame_top + 6, 4, 3, palette[3])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_boat(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Boat / currach: curved hull, mast, sail.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0

	# Hull (curved bottom, wide top)
	var hull_top: int = SIZE - 10
	var hull_bot: int = SIZE - 4
	var hull_w: float = rng.randf_range(12.0, 16.0)
	for py in range(hull_top, hull_bot + 1):
		var t: float = float(py - hull_top) / float(hull_bot - hull_top)
		var w: float = hull_w * (1.0 - t * 0.4)
		SpriteNoise.draw_line_h(img, int(cx - w), int(cx + w), py, palette[2])
	# Hull planks
	SpriteNoise.draw_line_h(img, int(cx - hull_w * 0.8), int(cx + hull_w * 0.8), hull_top + 2, palette[3])
	SpriteNoise.draw_line_h(img, int(cx - hull_w * 0.6), int(cx + hull_w * 0.6), hull_top + 4, palette[3])
	# Keel highlight
	SpriteNoise.draw_line_h(img, int(cx - hull_w * 0.3), int(cx + hull_w * 0.3), hull_bot, palette[1])

	# Mast
	var mast_top: int = 3
	SpriteNoise.draw_line_v(img, int(cx), mast_top, hull_top, palette[2])

	# Sail (triangle)
	for py in range(mast_top + 1, hull_top - 1):
		var t: float = float(py - mast_top) / float(hull_top - mast_top - 2)
		var sail_w: int = int(t * 8.0)
		SpriteNoise.draw_line_h(img, int(cx) + 1, int(cx) + sail_w, py, palette[5])
	# Sail highlight
	SpriteNoise.draw_line_v(img, int(cx) + 3, mast_top + 3, hull_top - 3, palette[6])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_tent(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Tent / camp: triangular shelter with pole, ground line.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var tent_w: float = rng.randf_range(12.0, 16.0)
	var tent_h: int = rng.randi_range(14, 20)
	var base_y: int = SIZE - 5
	var peak_y: int = base_y - tent_h

	# Tent body (triangle)
	for py in range(peak_y, base_y):
		var t: float = float(py - peak_y) / float(base_y - peak_y)
		var half_w: int = int(t * tent_w)
		# Left half darker, right half lighter
		SpriteNoise.draw_line_h(img, int(cx) - half_w, int(cx), py, palette[3])
		SpriteNoise.draw_line_h(img, int(cx), int(cx) + half_w, py, palette[4])

	# Ridge pole
	SpriteNoise.draw_line_v(img, int(cx), peak_y - 1, base_y, palette[2])

	# Entrance (dark triangle at base center)
	var door_h: int = int(float(tent_h) * 0.4)
	for py in range(base_y - door_h, base_y):
		var t: float = float(py - (base_y - door_h)) / float(door_h)
		var dw: int = int(t * 3.0)
		SpriteNoise.draw_line_h(img, int(cx) - dw, int(cx) + dw, py, palette[1])

	# Ground line
	SpriteNoise.draw_line_h(img, int(cx - tent_w) - 1, int(cx + tent_w) + 1, base_y, palette[2])

	# Pole tip
	SpriteNoise.set_px(img, int(cx), peak_y - 2, palette[5])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_harp(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Harp / lyre: curved frame with strings. Musical instrument.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0

	# Frame — curved left pillar
	var pillar_x: int = int(cx) - 6
	var frame_top: int = 4
	var frame_bot: int = SIZE - 5
	SpriteNoise.draw_line_v(img, pillar_x, frame_top, frame_bot, palette[2])
	SpriteNoise.draw_line_v(img, pillar_x + 1, frame_top, frame_bot, palette[3])

	# Top curve (connecting pillar to string bar)
	var bar_x: int = int(cx) + 5
	for i in range(8):
		var t: float = float(i) / 7.0
		var x: int = pillar_x + int(t * float(bar_x - pillar_x))
		var y: int = frame_top - int(sin(t * PI) * 3.0)
		SpriteNoise.set_px(img, x, y, palette[3])
		SpriteNoise.set_px(img, x, y + 1, palette[2])

	# String bar (right diagonal)
	for py in range(frame_top + 2, frame_bot - 2):
		var t: float = float(py - frame_top - 2) / float(frame_bot - frame_top - 4)
		var sx: int = bar_x - int(t * 3.0)
		SpriteNoise.set_px(img, sx, py, palette[3])

	# Strings (vertical lines between pillar and bar)
	var num_strings: int = rng.randi_range(4, 6)
	for s in range(num_strings):
		var t: float = float(s + 1) / float(num_strings + 1)
		var sy: int = frame_top + 4 + int(t * float(frame_bot - frame_top - 8))
		var sx_start: int = pillar_x + 2
		var sx_end: int = bar_x - int(t * 3.0) - 1
		SpriteNoise.draw_line_h(img, sx_start, sx_end, sy, palette[5])

	# Base (wider foot)
	SpriteNoise.fill_rect(img, pillar_x - 1, frame_bot, 4, 2, palette[2])

	# Decorative head
	SpriteNoise.fill_circle(img, float(pillar_x), float(frame_top) - 1.0, 2.0, palette[4])
	SpriteNoise.set_px(img, pillar_x, frame_top - 2, palette[6])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_skull(palette: Array[Color], _rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Skull: human/animal skull, macabre object. Death symbol.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var cy: float = SIZE / 2.0

	# Cranium (large rounded top)
	SpriteNoise.fill_ellipse(img, cx, cy - 2.0, 8.0, 9.0, palette[5])
	SpriteNoise.fill_ellipse(img, cx, cy - 3.0, 7.0, 8.0, palette[6])

	# Eye sockets (large, dark, triangular-ish)
	SpriteNoise.fill_circle(img, cx - 3.0, cy - 2.0, 2.5, palette[0])
	SpriteNoise.fill_circle(img, cx + 3.0, cy - 2.0, 2.5, palette[0])
	# Dim glow in eyes
	SpriteNoise.set_px(img, int(cx) - 3, int(cy) - 2, palette[2])
	SpriteNoise.set_px(img, int(cx) + 3, int(cy) - 2, palette[2])

	# Nose hole (inverted triangle)
	SpriteNoise.set_px(img, int(cx), int(cy) + 2, palette[1])
	SpriteNoise.set_px(img, int(cx) - 1, int(cy) + 1, palette[1])
	SpriteNoise.set_px(img, int(cx) + 1, int(cy) + 1, palette[1])

	# Jaw / teeth
	var jaw_y: int = int(cy) + 5
	SpriteNoise.fill_rect(img, int(cx) - 5, jaw_y, 11, 3, palette[4])
	# Teeth (alternating dark/light)
	for tx in range(-4, 5):
		var tooth_col: Color = palette[6] if tx % 2 == 0 else palette[3]
		SpriteNoise.set_px(img, int(cx) + tx, jaw_y, tooth_col)
	# Jaw gap
	SpriteNoise.draw_line_h(img, int(cx) - 4, int(cx) + 4, jaw_y + 1, palette[1])

	# Cheekbones
	SpriteNoise.set_px(img, int(cx) - 6, int(cy), palette[4])
	SpriteNoise.set_px(img, int(cx) + 6, int(cy), palette[4])

	# Cracks on cranium (subtle)
	SpriteNoise.set_px(img, int(cx) + 2, int(cy) - 7, palette[3])
	SpriteNoise.set_px(img, int(cx) + 3, int(cy) - 6, palette[3])
	SpriteNoise.set_px(img, int(cx) + 3, int(cy) - 5, palette[3])

	SpriteNoise.outline_existing(img, palette[0])
	return img


# ═══════════════════════════════════════════════════════════════════════════════
# GENERIC FALLBACK
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_generic(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Fallback: noise-based blob with biome colors. Used for unknown tags.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var cy: float = SIZE / 2.0 + 2.0
	var base_r: float = rng.randf_range(8.0, 13.0)
	var seed_f: float = float(variant) * 31.7

	for py in range(SIZE):
		for px in range(SIZE):
			var dx: float = (float(px) - cx) / base_r
			var dy: float = (float(py) - cy) / base_r
			var dist: float = dx * dx + dy * dy
			var noise_val: float = SpriteNoise.fbm(float(px) * 0.25, float(py) * 0.25, 3, seed_f) * 0.5
			if dist + noise_val < 1.0:
				var shade: float = 1.0 - dist
				var col_idx: int = clampi(int(shade * 4.0) + 2, 2, 6)
				img.set_pixel(px, py, palette[col_idx])

	SpriteNoise.outline_existing(img, palette[0])
	return img
