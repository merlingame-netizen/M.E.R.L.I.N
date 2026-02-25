class_name SpriteTemplates
extends RefCounted
## Procedural 32x32 pixel art generators organized by category.
## Each gen_* function returns a completed Image.
## Palette: [0]=outline [1]=deep_shadow [2]=shadow [3]=dark [4]=mid [5]=light [6]=highlight [7]=glow


const SIZE := 32


# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY 1: TREES / PLANTS
# ═══════════════════════════════════════════════════════════════════════════════

static func gen_oak(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Oak: wide trunk, round spreading canopy, visible branches in canopy.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var trunk_w: int = rng.randi_range(3, 5)
	var trunk_h: int = rng.randi_range(10, 14)
	var cx: float = SIZE / 2.0
	var trunk_x: int = int(cx) - trunk_w / 2
	var trunk_top: int = SIZE - trunk_h
	var seed_f: float = float(variant) * 17.3

	# Trunk with bark texture
	SpriteNoise.fill_rect(img, trunk_x, trunk_top, trunk_w, trunk_h, palette[2])
	for py in range(trunk_top, SIZE):
		if SpriteNoise.hash_2d(py * 3, int(seed_f)) > 0.5:
			SpriteNoise.set_px(img, trunk_x + 1, py, palette[3])
	SpriteNoise.draw_line_v(img, trunk_x + trunk_w - 1, trunk_top + 2, SIZE - 2, palette[1])

	# Main branches forking from trunk into canopy
	var branch_y: int = trunk_top + 2
	SpriteNoise.draw_line(img, int(cx), branch_y, int(cx) - 6, branch_y - 6, palette[2])
	SpriteNoise.draw_line(img, int(cx), branch_y, int(cx) + 7, branch_y - 5, palette[2])
	SpriteNoise.draw_line(img, int(cx), branch_y - 3, int(cx) - 3, branch_y - 9, palette[2])

	# Wide round canopy with fbm noise edges
	var canopy_rx: float = rng.randf_range(10.0, 14.0)
	var canopy_ry: float = rng.randf_range(7.0, 10.0)
	var canopy_cy: float = float(trunk_top) - canopy_ry * 0.3
	for py in range(SIZE):
		for px in range(SIZE):
			var dx: float = (float(px) - cx) / canopy_rx
			var dy: float = (float(py) - canopy_cy) / canopy_ry
			var dist: float = dx * dx + dy * dy
			var noise_val: float = SpriteNoise.fbm(float(px) * 0.3, float(py) * 0.3, 2, seed_f) * 0.45
			if dist + noise_val < 1.0:
				var shade: float = 1.0 - (float(py) - (canopy_cy - canopy_ry)) / (canopy_ry * 2.0)
				var n2: float = SpriteNoise.smooth_noise(float(px) * 0.8, float(py) * 0.8 + seed_f)
				var col_idx: int = clampi(int(shade * 3.0 + n2 * 0.8) + 3, 3, 6)
				SpriteNoise.set_px(img, px, py, palette[col_idx])

	# Leaf clusters (scattered highlights)
	SpriteNoise.scatter_pixels(img, cx, canopy_cy, canopy_rx * 0.7,
		palette[6], rng.randi_range(12, 20), rng)
	# Shadow under canopy on trunk
	SpriteNoise.fill_rect(img, trunk_x, trunk_top, trunk_w, 3, palette[1])
	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_pine(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Pine / conifer: thin trunk, triangular layered foliage, distinct pointed top.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var trunk_h: int = rng.randi_range(6, 9)
	var base_y: int = SIZE - 3
	var seed_f: float = float(variant) * 23.1

	# Thin trunk
	SpriteNoise.fill_rect(img, int(cx) - 1, base_y - trunk_h, 2, trunk_h, palette[2])
	SpriteNoise.set_px(img, int(cx), base_y - trunk_h + 1, palette[3])

	# Layered triangular tiers (3-4 layers, each wider than the one above)
	var tiers: int = rng.randi_range(3, 4)
	var tier_top: int = 2
	var total_h: int = base_y - trunk_h - tier_top
	for tier in range(tiers):
		var t0: float = float(tier) / float(tiers)
		var t1: float = float(tier + 1) / float(tiers)
		var y0: int = tier_top + int(t0 * float(total_h))
		var y1: int = tier_top + int(t1 * float(total_h)) + 2  # overlap
		var max_w: float = 3.0 + float(tier) * 3.5
		for py in range(y0, y1):
			var local_t: float = float(py - y0) / maxf(float(y1 - y0), 1.0)
			var w: float = local_t * max_w
			var noise_disp: float = SpriteNoise.smooth_noise(float(py) * 0.6, seed_f + float(tier) * 10.0) * 1.5
			for px in range(int(cx - w + noise_disp), int(cx + w - noise_disp) + 1):
				var shade: float = 1.0 - absf(float(px) - cx) / maxf(w, 1.0)
				var col_idx: int = clampi(int(shade * 2.0) + 3, 3, 5)
				SpriteNoise.set_px(img, px, py, palette[col_idx])
		# Tier bottom edge highlight
		SpriteNoise.draw_line_h(img, int(cx - max_w + 1.0), int(cx + max_w - 1.0), y1 - 1, palette[6])

	# Pointed tip
	SpriteNoise.set_px(img, int(cx), tier_top - 1, palette[5])
	SpriteNoise.set_px(img, int(cx), tier_top, palette[4])
	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_willow(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Willow: curved trunk, drooping branches forming a curtain of foliage.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var base_y: int = SIZE - 3
	var trunk_h: int = rng.randi_range(12, 16)
	var trunk_top: int = base_y - trunk_h
	var seed_f: float = float(variant) * 31.7

	# Curved trunk (slight lean)
	var lean: float = rng.randf_range(-1.5, 1.5)
	for py in range(trunk_top, base_y):
		var t: float = float(py - trunk_top) / float(trunk_h)
		var tx: int = int(cx + lean * (1.0 - t))
		SpriteNoise.set_px(img, tx - 1, py, palette[2])
		SpriteNoise.set_px(img, tx, py, palette[3])
		SpriteNoise.set_px(img, tx + 1, py, palette[2])

	# Crown origin (top of trunk)
	var crown_y: float = float(trunk_top) - 1.0
	# Small canopy mass at top
	SpriteNoise.fill_ellipse(img, cx + lean, crown_y, 6.0, 4.0, palette[4])
	SpriteNoise.fill_ellipse(img, cx + lean, crown_y - 1.0, 4.0, 2.5, palette[5])

	# Drooping branches (8-12 hanging strands)
	var num_branches: int = rng.randi_range(8, 12)
	for b in range(num_branches):
		var bx: float = cx + lean + rng.randf_range(-7.0, 7.0)
		var by: float = crown_y + rng.randf_range(-2.0, 1.0)
		var branch_len: int = rng.randi_range(10, 18)
		var sway: float = rng.randf_range(-2.0, 2.0)
		for i in range(branch_len):
			var t: float = float(i) / float(branch_len)
			var px: int = int(bx + sway * sin(t * PI))
			var py: int = int(by + float(i))
			var n: float = SpriteNoise.smooth_noise(float(px) * 0.5, float(py) * 0.3 + seed_f + float(b))
			var col_idx: int = 4 if n > 0.5 else 3
			SpriteNoise.set_px(img, px, py, palette[col_idx])
			# Leaf scatter on branch
			if n > 0.65:
				SpriteNoise.set_px(img, px + 1, py, palette[5])
				SpriteNoise.set_px(img, px - 1, py, palette[5])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_undergrowth(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Undergrowth: low tangled mass of moss, ferns, ivy — no trunk.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0 + rng.randf_range(-2.0, 2.0)
	var cy: float = SIZE - 7.0
	var rx: float = rng.randf_range(10.0, 14.0)
	var ry: float = rng.randf_range(5.0, 7.0)
	var seed_f: float = float(variant) * 19.7

	# Base mass with fbm distortion
	for py in range(SIZE):
		for px in range(SIZE):
			var dx: float = (float(px) - cx) / rx
			var dy: float = (float(py) - cy) / ry
			var dist: float = dx * dx + dy * dy
			var noise_val: float = SpriteNoise.fbm(float(px) * 0.35, float(py) * 0.35, 2, seed_f) * 0.5
			if dist + noise_val < 1.0:
				var n: float = SpriteNoise.smooth_noise(float(px) * 0.6, float(py) * 0.6 + seed_f)
				var col_idx: int = 3 + clampi(int(n * 3.0), 0, 2)
				SpriteNoise.set_px(img, px, py, palette[col_idx])

	# Fern fronds poking up (small vertical strokes)
	for f in range(rng.randi_range(4, 7)):
		var fx: int = int(cx + rng.randf_range(-rx * 0.7, rx * 0.7))
		var fy: int = int(cy - ry * 0.5 + rng.randf_range(-2.0, 2.0))
		var frond_h: int = rng.randi_range(3, 6)
		for i in range(frond_h):
			SpriteNoise.set_px(img, fx, fy - i, palette[5])
			if i > 1:
				SpriteNoise.set_px(img, fx - 1, fy - i, palette[4])
				SpriteNoise.set_px(img, fx + 1, fy - i, palette[4])

	# Ground shadow at bottom
	SpriteNoise.draw_line_h(img, int(cx - rx), int(cx + rx), SIZE - 4, palette[1])
	# Highlight spots
	SpriteNoise.scatter_pixels(img, cx, cy, rx * 0.6, palette[6], rng.randi_range(6, 12), rng)
	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_bush(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Bush / fern: low foliage with visible branch structure and leaf scatter.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0 + rng.randf_range(-2.0, 2.0)
	var cy: float = SIZE - 7.0
	var rx: float = rng.randf_range(9.0, 13.0)
	var ry: float = rng.randf_range(5.0, 8.0)
	var seed_f: float = float(variant) * 11.3

	# Base mass with noise edge
	for py in range(SIZE):
		for px in range(SIZE):
			var dx: float = (float(px) - cx) / rx
			var dy: float = (float(py) - cy) / ry
			var dist: float = dx * dx + dy * dy
			var noise_val: float = SpriteNoise.fbm(float(px) * 0.4, float(py) * 0.4, 2, seed_f) * 0.35
			if dist + noise_val < 1.0:
				var shade: float = clampf(1.0 - dist, 0.0, 1.0)
				var col_idx: int = clampi(int(shade * 2.5) + 3, 3, 5)
				SpriteNoise.set_px(img, px, py, palette[col_idx])

	# Branch skeleton (3-4 forking lines from base center)
	for b in range(rng.randi_range(3, 4)):
		var angle: float = rng.randf_range(-1.2, 1.2)
		var blen: int = rng.randi_range(5, 8)
		var bx: int = int(cx + cos(angle - PI / 2.0) * float(blen))
		var by: int = int(cy + sin(angle - PI / 2.0) * float(blen))
		SpriteNoise.draw_line(img, int(cx), int(cy) + 1, bx, by, palette[2])

	# Leaf highlights
	SpriteNoise.scatter_pixels(img, cx, cy - 1.0, rx * 0.6, palette[6], rng.randi_range(10, 16), rng)
	# Ground shadow
	SpriteNoise.draw_line_h(img, int(cx - rx * 0.8), int(cx + rx * 0.8), SIZE - 3, palette[1])
	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_mushroom(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Mushroom: textured stem, spotted cap, grass at base.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var stem_w: int = rng.randi_range(2, 4)
	var stem_h: int = rng.randi_range(7, 11)
	var cap_rx: float = rng.randf_range(6.0, 11.0)
	var cap_ry: float = rng.randf_range(4.0, 7.0)
	var cx: float = SIZE / 2.0
	var base_y: int = SIZE - 4
	var seed_f: float = float(variant) * 13.7

	# Grass at base
	for g in range(rng.randi_range(5, 8)):
		var gx: int = int(cx + rng.randf_range(-6.0, 6.0))
		var gh: int = rng.randi_range(2, 4)
		for i in range(gh):
			SpriteNoise.set_px(img, gx, base_y - i, palette[4])

	# Stem with texture
	var stem_x: int = int(cx) - stem_w / 2
	SpriteNoise.fill_rect(img, stem_x, base_y - stem_h, stem_w, stem_h, palette[5])
	# Stem stripe/texture
	for py in range(base_y - stem_h, base_y):
		if SpriteNoise.hash_2d(py * 5, int(seed_f)) > 0.6:
			SpriteNoise.set_px(img, stem_x + stem_w / 2, py, palette[6])
	SpriteNoise.draw_line_v(img, stem_x, base_y - stem_h, base_y - 1, palette[3])

	# Cap with fbm spots
	var cap_cy: float = float(base_y - stem_h) - cap_ry * 0.2
	for py in range(SIZE):
		for px in range(SIZE):
			var dx: float = (float(px) - cx) / cap_rx
			var dy: float = (float(py) - cap_cy) / cap_ry
			var dist: float = dx * dx + dy * dy
			if dist < 1.0:
				var shade: float = 1.0 - float(py - int(cap_cy - cap_ry)) / (cap_ry * 2.0)
				var col_idx: int = clampi(int(shade * 2.5) + 2, 2, 4)
				SpriteNoise.set_px(img, px, py, palette[col_idx])
	# Spots on cap (fbm-driven)
	for py in range(int(cap_cy - cap_ry), int(cap_cy + cap_ry)):
		for px in range(int(cx - cap_rx), int(cx + cap_rx)):
			var dx: float = (float(px) - cx) / cap_rx
			var dy: float = (float(py) - cap_cy) / cap_ry
			if dx * dx + dy * dy < 0.7:
				var n: float = SpriteNoise.fbm(float(px) * 0.6, float(py) * 0.6, 2, seed_f)
				if n > 0.6:
					SpriteNoise.set_px(img, px, py, palette[7])

	# Cap underside (gill line)
	SpriteNoise.draw_line_h(img, int(cx - cap_rx * 0.8), int(cx + cap_rx * 0.8),
		int(cap_cy + cap_ry * 0.6), palette[1])
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


static func gen_dolmen(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Dolmen: two textured stone pillars + rough capstone, moss, shadow.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var base_y: int = SIZE - 3
	var pillar_h: int = rng.randi_range(12, 18)
	var pillar_w: int = rng.randi_range(3, 5)
	var gap: int = rng.randi_range(6, 12)
	var cap_overhang: int = 2
	var cx: int = SIZE / 2
	var seed_f: float = float(variant) * 29.3

	# Ground shadow
	SpriteNoise.draw_line_h(img, cx - gap / 2 - pillar_w - 2,
		cx + gap / 2 + pillar_w + 2, base_y, palette[1])

	# Left pillar with texture
	var lx: int = cx - gap / 2 - pillar_w
	for py in range(base_y - pillar_h, base_y):
		for px in range(lx, lx + pillar_w):
			var n: float = SpriteNoise.smooth_noise(float(px) * 0.7, float(py) * 0.5 + seed_f)
			var col_idx: int = 3 if n < 0.5 else 4
			SpriteNoise.set_px(img, px, py, palette[col_idx])
	SpriteNoise.draw_line_v(img, lx + pillar_w - 1, base_y - pillar_h + 1, base_y - 1, palette[5])

	# Right pillar with texture
	var rx: int = cx + gap / 2
	for py in range(base_y - pillar_h, base_y):
		for px in range(rx, rx + pillar_w):
			var n: float = SpriteNoise.smooth_noise(float(px) * 0.7, float(py) * 0.5 + seed_f + 50.0)
			var col_idx: int = 3 if n < 0.5 else 4
			SpriteNoise.set_px(img, px, py, palette[col_idx])
	SpriteNoise.draw_line_v(img, rx + pillar_w - 1, base_y - pillar_h + 1, base_y - 1, palette[5])

	# Capstone with rough texture
	var cap_y: int = base_y - pillar_h - 3
	var cap_x: int = lx - cap_overhang
	var cap_w: int = (rx + pillar_w + cap_overhang) - cap_x
	for py in range(cap_y, cap_y + 4):
		for px in range(cap_x, cap_x + cap_w):
			var n: float = SpriteNoise.fbm(float(px) * 0.5, float(py) * 0.8, 2, seed_f + 20.0)
			var col_idx: int = 4 if n > 0.5 else 3
			SpriteNoise.set_px(img, px, py, palette[col_idx])
	SpriteNoise.draw_line_h(img, cap_x + 1, cap_x + cap_w - 2, cap_y, palette[5])

	# Moss/lichen scatter on pillars and cap
	SpriteNoise.scatter_pixels(img, float(lx + 1), float(base_y - pillar_h / 2),
		float(pillar_w), palette[5], 3, rng)
	SpriteNoise.scatter_pixels(img, float(rx + 1), float(base_y - pillar_h / 2),
		float(pillar_w), palette[5], 3, rng)

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_cairn(palette: Array[Color], rng: RandomNumberGenerator, variant: int = 0) -> Image:
	## Cairn: pile of individual rough stones (not smooth ellipses), with gaps.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var base_y: int = SIZE - 4
	var cx: float = SIZE / 2.0
	var seed_f: float = float(variant) * 37.1

	# Draw individual stones as small noise-distorted ellipses
	var stones: Array[Dictionary] = []
	var cur_y: float = float(base_y)
	var layer_w: float = rng.randf_range(12.0, 16.0)

	for layer in range(rng.randi_range(3, 5)):
		var stones_in_layer: int = maxi(1, int(layer_w / 5.0))
		var stone_h: float = rng.randf_range(3.0, 5.0)
		for s in range(stones_in_layer):
			var sx: float = cx - layer_w * 0.4 + float(s) * (layer_w * 0.8 / maxf(float(stones_in_layer), 1.0))
			sx += rng.randf_range(-1.0, 1.0)
			var stone_rx: float = rng.randf_range(2.5, 4.0)
			var stone_ry: float = stone_h * 0.5
			stones.append({"x": sx, "y": cur_y - stone_h * 0.5, "rx": stone_rx, "ry": stone_ry, "layer": layer})
		cur_y -= stone_h - 0.5
		layer_w *= rng.randf_range(0.6, 0.8)

	# Draw each stone with texture
	for stone in stones:
		var col_base: int = 3 + (stone["layer"] as int % 3)
		# Stone body
		SpriteNoise.fill_ellipse(img, stone["x"] as float, stone["y"] as float,
			stone["rx"] as float, stone["ry"] as float, palette[col_base])
		# Surface noise on stone
		var srx: float = stone["rx"] as float
		var sry: float = stone["ry"] as float
		for py in range(int(stone["y"] as float - sry), int(stone["y"] as float + sry) + 1):
			for px in range(int(stone["x"] as float - srx), int(stone["x"] as float + srx) + 1):
				var dx: float = (float(px) - (stone["x"] as float)) / srx
				var dy: float = (float(py) - (stone["y"] as float)) / sry
				if dx * dx + dy * dy < 0.8:
					var n: float = SpriteNoise.fbm(float(px) * 0.6, float(py) * 0.6, 2,
						seed_f + stone["x"] as float)
					if n > 0.55:
						SpriteNoise.set_px(img, px, py, palette[mini(col_base + 1, 6)])

	# Top stone highlight
	if not stones.is_empty():
		var top: Dictionary = stones[stones.size() - 1]
		SpriteNoise.set_px(img, int(top["x"] as float), int(top["y"] as float) - 1, palette[6])

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


static func gen_spear(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Spear / lance: long straight shaft with triangular pointed head.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: int = SIZE / 2
	var shaft_top: int = 5
	var shaft_bot: int = SIZE - 3
	var shaft_h: int = shaft_bot - shaft_top

	# Long straight shaft
	SpriteNoise.draw_line_v(img, cx, shaft_top + 4, shaft_bot, palette[2])
	SpriteNoise.draw_line_v(img, cx + 1, shaft_top + 4, shaft_bot, palette[3])
	# Wood grain texture
	for py in range(shaft_top + 6, shaft_bot, 3):
		SpriteNoise.set_px(img, cx, py, palette[3])

	# Butt cap
	SpriteNoise.fill_rect(img, cx - 1, shaft_bot - 1, 3, 2, palette[1])

	# Pointed head (elongated diamond)
	var head_h: int = rng.randi_range(8, 12)
	for py in range(shaft_top, shaft_top + head_h):
		var t: float = float(py - shaft_top) / float(head_h)
		var w: float
		if t < 0.5:
			w = t * 2.0 * 3.0  # widen
		else:
			w = (1.0 - t) * 2.0 * 3.0  # taper
		var hw: int = maxi(0, int(w))
		SpriteNoise.draw_line_h(img, cx - hw, cx + hw, py, palette[4])
	# Blade edge highlights
	SpriteNoise.draw_line_v(img, cx, shaft_top, shaft_top + head_h / 2, palette[6])
	# Tip
	SpriteNoise.set_px(img, cx, shaft_top - 1, palette[5])

	# Binding where head meets shaft
	SpriteNoise.fill_rect(img, cx - 1, shaft_top + head_h - 1, 3, 2, palette[5])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_dagger(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Dagger / knife: short curved blade, no crossguard, leather grip.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: int = SIZE / 2
	var blade_h: int = rng.randi_range(10, 14)
	var tip_y: int = 6
	var blade_bot: int = tip_y + blade_h

	# Short curved blade (wider on one side)
	for py in range(tip_y, blade_bot):
		var t: float = float(py - tip_y) / float(blade_h)
		var w_left: int = clampi(int(t * 2.5), 0, 2)
		var w_right: int = clampi(int(sin(t * PI) * 3.0), 0, 3)
		for px in range(cx - w_left, cx + w_right + 1):
			var shade: Color = palette[5] if px <= cx else palette[4]
			SpriteNoise.set_px(img, px, py, shade)
	# Blade edge (curved, right side)
	for py in range(tip_y + 2, blade_bot - 1):
		var t: float = float(py - tip_y) / float(blade_h)
		var edge_x: int = cx + clampi(int(sin(t * PI) * 3.0), 0, 3)
		SpriteNoise.set_px(img, edge_x, py, palette[6])
	# Tip
	SpriteNoise.set_px(img, cx, tip_y - 1, palette[5])

	# Leather grip (wrapped pattern)
	var grip_h: int = rng.randi_range(6, 9)
	for py in range(blade_bot + 1, blade_bot + 1 + grip_h):
		var wrap: bool = (py - blade_bot) % 2 == 0
		SpriteNoise.draw_line_h(img, cx - 1, cx + 1, py, palette[2] if wrap else palette[3])
	# Pommel
	SpriteNoise.fill_rect(img, cx - 1, blade_bot + 1 + grip_h, 3, 2, palette[4])
	SpriteNoise.set_px(img, cx, blade_bot + 2 + grip_h, palette[6])

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
	## Lantern: ornate frame, glass panes with glow, chain, light halo.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var body_w: int = rng.randi_range(8, 12)
	var body_h: int = rng.randi_range(10, 16)
	var body_top: int = int(SIZE / 2.0) - int(body_h / 2.0) + 3
	var body_left: int = int(cx) - int(body_w / 2.0)

	# Light halo (drawn first, behind everything)
	var halo_r: float = float(maxi(body_w, body_h)) * 0.7
	for py in range(SIZE):
		for px in range(SIZE):
			var dx: float = float(px) - cx
			var dy: float = float(py) - float(body_top + body_h / 2)
			var dist: float = sqrt(dx * dx + dy * dy)
			if dist < halo_r and dist > halo_r * 0.6:
				var alpha: float = 1.0 - (dist - halo_r * 0.6) / (halo_r * 0.4)
				var col: Color = palette[6]
				col.a = clampf(alpha * 0.25, 0.0, 0.3)
				SpriteNoise.set_px(img, px, py, col)

	# Decorative hook (curved ring)
	SpriteNoise.draw_arc(img, cx, float(body_top) - 4.0, 3.0, -PI, 0.0, palette[3], 8)
	# Chain links (alternating sizes)
	for i in range(3):
		var cy: int = body_top - 3 + i
		SpriteNoise.set_px(img, int(cx), cy, palette[2] if i % 2 == 0 else palette[3])

	# Metal frame (dark)
	SpriteNoise.fill_rect(img, body_left, body_top, body_w, body_h, palette[2])
	# Frame corner rivets
	SpriteNoise.set_px(img, body_left + 1, body_top + 1, palette[4])
	SpriteNoise.set_px(img, body_left + body_w - 2, body_top + 1, palette[4])
	SpriteNoise.set_px(img, body_left + 1, body_top + body_h - 2, palette[4])
	SpriteNoise.set_px(img, body_left + body_w - 2, body_top + body_h - 2, palette[4])

	# Glass panes (glowing, with gradient)
	for py in range(body_top + 2, body_top + body_h - 2):
		for px in range(body_left + 2, body_left + body_w - 2):
			var dx: float = absf(float(px) - cx) / float(body_w / 2 - 2)
			var dy: float = absf(float(py) - float(body_top + body_h / 2)) / float(body_h / 2 - 2)
			var glow: float = 1.0 - (dx * dx + dy * dy) * 0.5
			var col_idx: int = 6 if glow < 0.6 else 7
			SpriteNoise.set_px(img, px, py, palette[col_idx])
	# Glass reflection streak (left side)
	SpriteNoise.draw_line_v(img, body_left + 3, body_top + 3, body_top + body_h - 4,
		Color(palette[7].r, palette[7].g, palette[7].b, 0.7))

	# Frame bars (cross pattern)
	SpriteNoise.draw_line_v(img, int(cx), body_top + 1, body_top + body_h - 2, palette[1])
	SpriteNoise.draw_line_h(img, body_left + 1, body_left + body_w - 2,
		body_top + body_h / 2, palette[1])

	# Top and bottom caps (ornamental)
	SpriteNoise.fill_rect(img, body_left - 1, body_top, body_w + 2, 1, palette[3])
	SpriteNoise.fill_rect(img, body_left, body_top + body_h - 1, body_w, 2, palette[3])
	SpriteNoise.set_px(img, int(cx), body_top + body_h + 1, palette[2])  # bottom finial

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


static func gen_bard(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Bard: musician with feathered cap, holding a lyre/harp. Lighter build than druid.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_draw_humanoid_body(img, palette, rng, 3.5, 7, false)  # lighter build, no robe
	var cx: float = SIZE / 2.0

	# Feathered cap (tilted beret + plume)
	SpriteNoise.fill_ellipse(img, cx, 5.0, 5.0, 3.0, palette[4])
	SpriteNoise.fill_ellipse(img, cx, 4.5, 4.0, 2.5, palette[5])
	# Plume feather (arcing up-right)
	SpriteNoise.draw_line(img, int(cx) + 3, 5, int(cx) + 6, 1, palette[6])
	SpriteNoise.draw_line(img, int(cx) + 6, 1, int(cx) + 8, 0, palette[7])
	SpriteNoise.set_px(img, int(cx) + 7, 1, palette[6])

	# Face
	SpriteNoise.fill_circle(img, cx, 7.0, 3.0, palette[5])
	SpriteNoise.set_px(img, int(cx) - 1, 7, palette[1])  # eyes
	SpriteNoise.set_px(img, int(cx) + 1, 7, palette[1])
	# Smile
	SpriteNoise.set_px(img, int(cx) - 1, 9, palette[2])
	SpriteNoise.set_px(img, int(cx), 9, palette[2])
	SpriteNoise.set_px(img, int(cx) + 1, 9, palette[2])

	# Tunic collar (V-shape)
	SpriteNoise.draw_line(img, int(cx) - 2, 11, int(cx), 13, palette[6])
	SpriteNoise.draw_line(img, int(cx) + 2, 11, int(cx), 13, palette[6])

	# Belt with pouch
	SpriteNoise.draw_line_h(img, int(cx) - 4, int(cx) + 4, 20, palette[2])
	SpriteNoise.fill_rect(img, int(cx) + 2, 19, 3, 3, palette[3])  # belt pouch

	# Lyre held in left hand
	var lyre_x: int = int(cx) - 8
	var lyre_y: int = 14
	# Lyre frame (U-shape)
	SpriteNoise.draw_line_v(img, lyre_x, lyre_y, lyre_y + 8, palette[5])
	SpriteNoise.draw_line_v(img, lyre_x + 4, lyre_y, lyre_y + 8, palette[5])
	SpriteNoise.draw_line_h(img, lyre_x, lyre_x + 4, lyre_y + 8, palette[5])
	# Crossbar
	SpriteNoise.draw_line_h(img, lyre_x, lyre_x + 4, lyre_y, palette[6])
	# Strings (3 vertical lines)
	for s in range(3):
		SpriteNoise.draw_line_v(img, lyre_x + 1 + s, lyre_y + 1, lyre_y + 7, palette[7])

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
	## Wolf: lean, low-slung predator, pointed ears, long snout, tail down.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_draw_quadruped(img, palette, rng, 18, 7, 4.0)

	var head_cx: float = SIZE / 2.0 - 6.0
	var head_cy: float = SIZE / 2.0 + 0.5
	# Pointed ears (tall, triangular)
	for i in range(4):
		SpriteNoise.set_px(img, int(head_cx) - 2, int(head_cy) - 4 - i, palette[4])
		SpriteNoise.set_px(img, int(head_cx) + 1, int(head_cy) - 4 - i, palette[4])
	SpriteNoise.set_px(img, int(head_cx) - 2, int(head_cy) - 5, palette[5])  # inner ear
	SpriteNoise.set_px(img, int(head_cx) + 1, int(head_cy) - 5, palette[5])

	# Long narrow snout
	SpriteNoise.fill_rect(img, int(head_cx) - 5, int(head_cy) - 1, 4, 2, palette[5])
	SpriteNoise.set_px(img, int(head_cx) - 5, int(head_cy) - 1, palette[1])  # nose
	# Jaw line
	SpriteNoise.draw_line_h(img, int(head_cx) - 4, int(head_cx), int(head_cy) + 1, palette[2])

	# Back fur ridge
	var body_cx: float = SIZE / 2.0 + 1.0
	for i in range(8):
		SpriteNoise.set_px(img, int(body_cx) - 4 + i, int(SIZE / 2.0) - 2, palette[3])

	# Tail drooping low
	var tail_bx: int = int(SIZE / 2.0) + 10
	var tail_by: int = int(SIZE / 2.0) + 2
	for i in range(7):
		SpriteNoise.set_px(img, tail_bx + i, tail_by + int(float(i) * 0.4), palette[3])
		SpriteNoise.set_px(img, tail_bx + i, tail_by + int(float(i) * 0.4) + 1, palette[2])

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


static func gen_boar(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Boar / wild pig: squat, massive, wide shoulders, tusks, bristled back.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0 + 1.0
	var cy: float = SIZE / 2.0 + 3.0

	# Massive barrel body (wider than tall)
	SpriteNoise.fill_ellipse(img, cx, cy, 10.0, 6.0, palette[2])
	SpriteNoise.fill_ellipse(img, cx, cy - 1.0, 9.0, 5.0, palette[3])

	# Heavy head (wedge-shaped, lower than body)
	var head_cx: float = cx - 10.0
	var head_cy: float = cy + 1.0
	SpriteNoise.fill_ellipse(img, head_cx, head_cy, 5.0, 4.0, palette[3])
	SpriteNoise.fill_ellipse(img, head_cx - 1.0, head_cy, 4.0, 3.0, palette[4])
	# Snout (flat front)
	SpriteNoise.fill_rect(img, int(head_cx) - 6, int(head_cy) - 1, 3, 3, palette[4])
	SpriteNoise.set_px(img, int(head_cx) - 6, int(head_cy), palette[1])  # nostril
	SpriteNoise.set_px(img, int(head_cx) - 6, int(head_cy) - 1, palette[1])
	# Small angry eye
	SpriteNoise.set_px(img, int(head_cx) - 2, int(head_cy) - 2, palette[7])
	# Tusks (curving up from jaw)
	SpriteNoise.set_px(img, int(head_cx) - 4, int(head_cy) + 2, palette[6])
	SpriteNoise.set_px(img, int(head_cx) - 5, int(head_cy) + 1, palette[6])

	# Bristled back ridge (jagged line along spine)
	for i in range(12):
		var bx: int = int(cx) - 6 + i
		SpriteNoise.set_px(img, bx, int(cy) - 6, palette[2])
		if i % 2 == 0:
			SpriteNoise.set_px(img, bx, int(cy) - 7, palette[1])

	# Short thick legs
	var leg_y: int = int(cy) + 5
	var leg_h: int = rng.randi_range(5, 7)
	SpriteNoise.fill_rect(img, int(cx) - 7, leg_y, 3, leg_h, palette[2])
	SpriteNoise.fill_rect(img, int(cx) - 3, leg_y, 3, leg_h, palette[2])
	SpriteNoise.fill_rect(img, int(cx) + 3, leg_y, 3, leg_h, palette[2])
	SpriteNoise.fill_rect(img, int(cx) + 7, leg_y, 3, leg_h, palette[2])
	# Hooves
	for lx in [int(cx) - 7, int(cx) - 3, int(cx) + 3, int(cx) + 7]:
		SpriteNoise.fill_rect(img, lx, leg_y + leg_h, 3, 1, palette[1])

	# Short curly tail
	SpriteNoise.set_px(img, int(cx) + 11, int(cy) - 1, palette[3])
	SpriteNoise.set_px(img, int(cx) + 12, int(cy) - 2, palette[3])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_fox(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Fox: slender, elegant, pointy face, large bushy tail, dainty legs.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0 + 1.0
	var cy: float = SIZE / 2.0 + 2.0

	# Slender body (elongated oval)
	SpriteNoise.fill_ellipse(img, cx, cy, 7.0, 4.0, palette[4])
	SpriteNoise.fill_ellipse(img, cx, cy - 0.5, 6.0, 3.0, palette[5])

	# Slim pointed head (triangular profile)
	var head_cx: float = cx - 8.0
	var head_cy: float = cy - 1.0
	SpriteNoise.fill_circle(img, head_cx, head_cy, 3.0, palette[5])
	SpriteNoise.fill_circle(img, head_cx - 0.5, head_cy, 2.5, palette[6])
	# Long narrow snout
	SpriteNoise.set_px(img, int(head_cx) - 4, int(head_cy), palette[6])
	SpriteNoise.set_px(img, int(head_cx) - 5, int(head_cy), palette[5])
	SpriteNoise.set_px(img, int(head_cx) - 5, int(head_cy), palette[1])  # nose tip
	# Alert eye
	SpriteNoise.set_px(img, int(head_cx) - 1, int(head_cy) - 1, palette[0])
	# Large pointed ears
	for i in range(3):
		SpriteNoise.set_px(img, int(head_cx) - 1, int(head_cy) - 3 - i, palette[4])
		SpriteNoise.set_px(img, int(head_cx) + 2, int(head_cy) - 3 - i, palette[4])
	SpriteNoise.set_px(img, int(head_cx) - 1, int(head_cy) - 4, palette[6])  # inner ear
	SpriteNoise.set_px(img, int(head_cx) + 2, int(head_cy) - 4, palette[6])

	# White chest/belly
	SpriteNoise.fill_ellipse(img, cx - 2.0, cy + 1.0, 3.0, 2.0, palette[6])

	# Large bushy tail (THE distinguishing feature)
	var tail_x: float = cx + 7.0
	var tail_y: float = cy - 2.0
	SpriteNoise.fill_ellipse(img, tail_x + 3.0, tail_y, 5.0, 3.5, palette[5])
	SpriteNoise.fill_ellipse(img, tail_x + 4.0, tail_y - 0.5, 4.0, 2.5, palette[6])
	# White tail tip
	SpriteNoise.fill_circle(img, tail_x + 7.0, tail_y - 1.0, 1.5, palette[7])

	# Dainty thin legs
	var leg_y: int = int(cy) + 3
	var leg_h: int = rng.randi_range(6, 8)
	SpriteNoise.draw_line_v(img, int(cx) - 4, leg_y, leg_y + leg_h, palette[3])
	SpriteNoise.draw_line_v(img, int(cx) - 2, leg_y, leg_y + leg_h, palette[3])
	SpriteNoise.draw_line_v(img, int(cx) + 3, leg_y, leg_y + leg_h, palette[3])
	SpriteNoise.draw_line_v(img, int(cx) + 5, leg_y, leg_y + leg_h, palette[3])
	# Dark paws
	for lx in [int(cx) - 4, int(cx) - 2, int(cx) + 3, int(cx) + 5]:
		SpriteNoise.set_px(img, lx, leg_y + leg_h, palette[1])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_bear(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Bear: massive, hulking, high shoulders, round ears, powerful build.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0 + 1.0
	var cy: float = SIZE / 2.0 + 2.0

	# Massive body (very wide, high)
	SpriteNoise.fill_ellipse(img, cx, cy, 10.0, 7.0, palette[2])
	SpriteNoise.fill_ellipse(img, cx, cy - 1.0, 9.0, 6.0, palette[3])

	# Shoulder hump (raised above body line)
	SpriteNoise.fill_ellipse(img, cx - 2.0, cy - 6.0, 5.0, 3.0, palette[3])
	SpriteNoise.fill_ellipse(img, cx - 2.0, cy - 6.5, 4.0, 2.0, palette[4])

	# Round head (lower than shoulder hump)
	var head_cx: float = cx - 10.0
	var head_cy: float = cy - 1.0
	SpriteNoise.fill_circle(img, head_cx, head_cy, 4.5, palette[3])
	SpriteNoise.fill_circle(img, head_cx, head_cy - 0.5, 3.5, palette[4])
	# Round ears (small, round — not pointed)
	SpriteNoise.fill_circle(img, head_cx - 3.0, head_cy - 4.0, 2.0, palette[3])
	SpriteNoise.fill_circle(img, head_cx + 3.0, head_cy - 4.0, 2.0, palette[3])
	SpriteNoise.set_px(img, int(head_cx) - 3, int(head_cy) - 4, palette[5])  # inner ear
	SpriteNoise.set_px(img, int(head_cx) + 3, int(head_cy) - 4, palette[5])
	# Snout
	SpriteNoise.fill_rect(img, int(head_cx) - 5, int(head_cy), 3, 2, palette[5])
	SpriteNoise.set_px(img, int(head_cx) - 5, int(head_cy), palette[1])  # nose
	# Small eyes
	SpriteNoise.set_px(img, int(head_cx) - 2, int(head_cy) - 2, palette[0])
	SpriteNoise.set_px(img, int(head_cx) + 1, int(head_cy) - 2, palette[0])

	# Thick powerful legs
	var leg_y: int = int(cy) + 6
	var leg_h: int = rng.randi_range(5, 7)
	SpriteNoise.fill_rect(img, int(cx) - 8, leg_y, 4, leg_h, palette[2])
	SpriteNoise.fill_rect(img, int(cx) - 3, leg_y, 4, leg_h, palette[2])
	SpriteNoise.fill_rect(img, int(cx) + 2, leg_y, 4, leg_h, palette[2])
	SpriteNoise.fill_rect(img, int(cx) + 7, leg_y, 4, leg_h, palette[2])
	# Wide paws
	for lx in [int(cx) - 9, int(cx) - 4, int(cx) + 1, int(cx) + 6]:
		SpriteNoise.fill_rect(img, lx, leg_y + leg_h, 5, 2, palette[1])

	# Short stubby tail
	SpriteNoise.set_px(img, int(cx) + 11, int(cy) - 1, palette[3])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_raven(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Raven / crow: dark, bulky body, large thick beak, wide spread wings.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var cy: float = SIZE / 2.0 + 2.0

	# Bulky body (large oval, dark tones)
	SpriteNoise.fill_ellipse(img, cx, cy, 6.0, 5.0, palette[1])
	SpriteNoise.fill_ellipse(img, cx, cy - 0.5, 5.0, 4.0, palette[2])

	# Head (round, forward)
	SpriteNoise.fill_circle(img, cx - 6.0, cy - 2.0, 3.5, palette[1])
	SpriteNoise.fill_circle(img, cx - 6.0, cy - 2.5, 3.0, palette[2])
	# Glinting eye
	SpriteNoise.set_px(img, int(cx) - 7, int(cy) - 3, palette[7])
	# Large thick beak
	SpriteNoise.fill_rect(img, int(cx) - 11, int(cy) - 2, 3, 2, palette[3])
	SpriteNoise.set_px(img, int(cx) - 12, int(cy) - 2, palette[2])  # hooked tip

	# Wide spread wings (filled, not just outlines)
	var wing_span: int = rng.randi_range(10, 13)
	for i in range(wing_span):
		var t: float = float(i) / float(wing_span)
		var wy: float = cy - 3.0 + t * 2.0
		var w: float = sin(t * PI) * 3.0 + 1.0
		var wx_l: int = int(cx - 3.0 - float(i) * 1.1)
		var wx_r: int = int(cx + 3.0 + float(i) * 1.1)
		for j in range(int(w)):
			SpriteNoise.set_px(img, wx_l, int(wy) - j, palette[1])
			SpriteNoise.set_px(img, wx_r, int(wy) - j, palette[1])
		# Feather edge
		SpriteNoise.set_px(img, wx_l, int(wy) - int(w), palette[2])
		SpriteNoise.set_px(img, wx_r, int(wy) - int(w), palette[2])

	# Fan tail
	for i in range(5):
		SpriteNoise.draw_line(img, int(cx) + 5, int(cy) + 1,
			int(cx) + 8 + i, int(cy) + 4 + absi(i - 2), palette[1])
	# Legs
	SpriteNoise.draw_line_v(img, int(cx) - 1, int(cy) + 5, int(cy) + 8, palette[2])
	SpriteNoise.draw_line_v(img, int(cx) + 1, int(cy) + 5, int(cy) + 8, palette[2])
	# Talons
	SpriteNoise.set_px(img, int(cx) - 2, int(cy) + 8, palette[2])
	SpriteNoise.set_px(img, int(cx) + 2, int(cy) + 8, palette[2])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_raptor(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Raptor (eagle/falcon): swept-back pointed wings, hooked beak, powerful talons.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var cy: float = SIZE / 2.0 + 1.0

	# Streamlined body
	SpriteNoise.fill_ellipse(img, cx, cy, 5.0, 3.5, palette[3])
	SpriteNoise.fill_ellipse(img, cx, cy - 0.5, 4.0, 2.5, palette[4])

	# Head (smaller, angular)
	SpriteNoise.fill_circle(img, cx - 5.0, cy - 1.5, 2.5, palette[4])
	SpriteNoise.fill_circle(img, cx - 5.0, cy - 2.0, 2.0, palette[5])
	# Fierce eye
	SpriteNoise.set_px(img, int(cx) - 6, int(cy) - 2, palette[7])
	# Hooked beak
	SpriteNoise.set_px(img, int(cx) - 8, int(cy) - 1, palette[6])
	SpriteNoise.set_px(img, int(cx) - 8, int(cy), palette[5])

	# Pointed swept-back wings (angular, aggressive)
	var wing_len: int = rng.randi_range(10, 13)
	for i in range(wing_len):
		var t: float = float(i) / float(wing_len)
		var w: float = (1.0 - t) * 3.5  # narrow at tips, wide at base
		var angle: float = -0.4 + t * 0.6  # sweep angle
		var wx: float = cx + float(i) * cos(angle) * 0.8
		var wy_l: float = cy - 3.0 - float(i) * 0.7
		var wy_r: float = cy - 3.0 + float(i) * 0.2
		for j in range(int(w)):
			SpriteNoise.set_px(img, int(wx) - int(float(i) * 1.0), int(wy_l) + j, palette[3])
			SpriteNoise.set_px(img, int(wx) + int(float(i) * 0.8), int(wy_r) - j, palette[3])
		# Wing tip highlight
		if t > 0.7:
			SpriteNoise.set_px(img, int(wx) - int(float(i) * 1.0), int(wy_l), palette[5])

	# Tail (narrow V-shape)
	for i in range(4):
		SpriteNoise.set_px(img, int(cx) + 5 + i, int(cy) + i, palette[3])
		SpriteNoise.set_px(img, int(cx) + 5 + i, int(cy) - i + 1, palette[3])

	# Powerful talons
	SpriteNoise.draw_line_v(img, int(cx) - 1, int(cy) + 4, int(cy) + 7, palette[2])
	SpriteNoise.draw_line_v(img, int(cx) + 1, int(cy) + 4, int(cy) + 7, palette[2])
	# Curved talons
	SpriteNoise.set_px(img, int(cx) - 2, int(cy) + 7, palette[6])
	SpriteNoise.set_px(img, int(cx), int(cy) + 8, palette[6])
	SpriteNoise.set_px(img, int(cx) + 2, int(cy) + 7, palette[6])

	SpriteNoise.outline_existing(img, palette[0])
	return img


static func gen_owl(palette: Array[Color], rng: RandomNumberGenerator, _variant: int = 0) -> Image:
	## Owl: very round body, enormous eyes with pupils, ear tufts, compact.
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var cx: float = SIZE / 2.0
	var cy: float = SIZE / 2.0 + 2.0

	# Round chunky body
	SpriteNoise.fill_ellipse(img, cx, cy + 2.0, 7.0, 8.0, palette[3])
	SpriteNoise.fill_ellipse(img, cx, cy + 1.5, 6.0, 7.0, palette[4])

	# Very large round head (nearly same size as body)
	SpriteNoise.fill_circle(img, cx, cy - 5.0, 6.0, palette[4])
	SpriteNoise.fill_circle(img, cx, cy - 5.5, 5.0, palette[5])

	# Facial disc (lighter ring around eyes)
	SpriteNoise.fill_circle(img, cx, cy - 5.0, 4.5, palette[6])

	# Enormous eyes (the defining feature)
	SpriteNoise.fill_circle(img, cx - 2.5, cy - 5.0, 2.5, palette[7])
	SpriteNoise.fill_circle(img, cx + 2.5, cy - 5.0, 2.5, palette[7])
	# Dark pupils
	SpriteNoise.fill_circle(img, cx - 2.5, cy - 5.0, 1.5, palette[0])
	SpriteNoise.fill_circle(img, cx + 2.5, cy - 5.0, 1.5, palette[0])
	# Pupil glints
	SpriteNoise.set_px(img, int(cx) - 3, int(cy) - 6, palette[7])
	SpriteNoise.set_px(img, int(cx) + 2, int(cy) - 6, palette[7])

	# Small beak
	SpriteNoise.set_px(img, int(cx), int(cy) - 3, palette[6])
	SpriteNoise.set_px(img, int(cx), int(cy) - 2, palette[5])

	# Ear tufts
	SpriteNoise.set_px(img, int(cx) - 4, int(cy) - 10, palette[3])
	SpriteNoise.set_px(img, int(cx) - 3, int(cy) - 11, palette[3])
	SpriteNoise.set_px(img, int(cx) + 4, int(cy) - 10, palette[3])
	SpriteNoise.set_px(img, int(cx) + 3, int(cy) - 11, palette[3])

	# Breast feather pattern (chevrons)
	for row in range(4):
		var ry: int = int(cy) + row * 2
		var hw: int = 4 - row
		SpriteNoise.draw_line_h(img, int(cx) - hw, int(cx) + hw, ry, palette[5])

	# Short legs with talons
	SpriteNoise.draw_line_v(img, int(cx) - 2, int(cy) + 9, int(cy) + 11, palette[2])
	SpriteNoise.draw_line_v(img, int(cx) + 2, int(cy) + 9, int(cy) + 11, palette[2])
	SpriteNoise.set_px(img, int(cx) - 3, int(cy) + 11, palette[3])
	SpriteNoise.set_px(img, int(cx) + 3, int(cy) + 11, palette[3])

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
