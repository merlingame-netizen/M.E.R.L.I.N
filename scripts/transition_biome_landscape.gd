## ═══════════════════════════════════════════════════════════════════════════════
## Transition Biome — Landscape Generation Module
## ═══════════════════════════════════════════════════════════════════════════════
## Procedural pixel-art grid generation + delegation to stages module.
## ═══════════════════════════════════════════════════════════════════════════════

class_name TransitionBiomeLandscape
extends RefCounted

const GRID_W := 32
const GRID_H := 16

var _stages_mod: TransitionBiomeLandscapeStages = TransitionBiomeLandscapeStages.new()


# ═══════════════════════════════════════════════════════════════════════════════
# GRID HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func make_empty_grid() -> Array:
	var g: Array = []
	for y in range(GRID_H):
		var row: Array = []
		for x in range(GRID_W):
			row.append(0)
		g.append(row)
	return g


func grid_set(g: Array, x: int, y: int, c: int) -> void:
	if y >= 0 and y < GRID_H and x >= 0 and x < GRID_W:
		g[y][x] = c


func grid_rect(g: Array, x0: int, y0: int, w: int, h: int, c: int) -> void:
	for dy in range(h):
		for dx in range(w):
			grid_set(g, x0 + dx, y0 + dy, c)


func grid_triangle(g: Array, cx: int, top_y: int, base_y: int, max_w: int, c: int) -> void:
	if base_y <= top_y:
		return
	var height := base_y - top_y
	for dy in range(height + 1):
		var y := top_y + dy
		var t := float(dy) / float(height)
		var half := int(t * float(max_w) / 2.0)
		for dx in range(-half, half + 1):
			grid_set(g, cx + dx, y, c)


func grid_hill(g: Array, cx: int, base_y: int, rx: int, ry: int, c: int) -> void:
	for dx in range(-rx, rx + 1):
		var norm := float(dx) / float(rx)
		var val := 1.0 - norm * norm
		if val <= 0.0:
			continue
		var h := int(float(ry) * sqrt(val))
		for dy in range(h):
			grid_set(g, cx + dx, base_y - dy, c)


func grid_dots(g: Array, positions: Array, c: int) -> void:
	for pos in positions:
		grid_set(g, pos[0], pos[1], c)


# ═══════════════════════════════════════════════════════════════════════════════
# LANDSCAPE GENERATION — Full grid (used for _current_grid)
# ═══════════════════════════════════════════════════════════════════════════════

func generate_landscape(biome: String) -> Array:
	var g := make_empty_grid()
	match biome:
		"broceliande":
			_gen_broceliande(g)
		"landes":
			_gen_landes(g)
		"cotes":
			_gen_cotes(g)
		"villages":
			_gen_villages(g)
		"cercles":
			_gen_cercles(g)
		"marais":
			_gen_marais(g)
		"collines":
			_gen_collines(g)
		"iles":
			_gen_iles(g)
		_:
			_gen_broceliande(g)
	return g


func _gen_broceliande(g: Array) -> void:
	for row in range(GRID_H):
		for col in range(GRID_W):
			var c: int
			if row <= 1:
				c = 3 if (col * 3 + row * 7) % 11 == 0 else 1
			elif row <= 5:
				c = 3 if (col + row * 2) % 9 == 0 else 1
			elif row <= 9:
				if col in [5, 12, 13, 17, 22, 23, 29]:
					c = 2
				else:
					c = 1 if (col * 2 + row) % 7 != 0 else 3
			elif row <= 11:
				c = 2 if col % 3 == 0 else 1
			elif row <= 13:
				c = 3 if (col * 2 + row * 5) % 13 == 0 else 2
			else:
				c = 2
			grid_set(g, col, row, c)


func _gen_landes(g: Array) -> void:
	grid_set(g, 15, 2, 1)
	grid_set(g, 16, 2, 1)
	grid_rect(g, 14, 3, 3, 6, 1)
	grid_hill(g, 11, 11, 13, 3, 2)
	grid_hill(g, 25, 11, 10, 2, 2)
	grid_rect(g, 0, 12, GRID_W, 2, 1)
	grid_dots(g, [[1, 14], [4, 14], [7, 14], [10, 14], [13, 14],
		[16, 14], [19, 14], [22, 14], [25, 14], [28, 14], [31, 14]], 3)


func _gen_cotes(g: Array) -> void:
	grid_rect(g, 0, 2, 7, 10, 1)
	grid_rect(g, 7, 4, 3, 8, 1)
	grid_rect(g, 10, 6, 2, 6, 1)
	grid_rect(g, 12, 8, 2, 4, 1)
	grid_dots(g, [[17, 8], [18, 8], [23, 7], [24, 7], [29, 8], [30, 8]], 3)
	grid_dots(g, [[16, 9], [17, 9], [21, 9], [22, 9], [27, 9], [28, 9]], 3)
	grid_rect(g, 14, 10, 18, 2, 3)
	grid_rect(g, 0, 12, GRID_W, 2, 2)
	grid_dots(g, [[3, 14], [8, 14], [15, 14], [21, 14], [27, 14]], 3)


func _gen_villages(g: Array) -> void:
	grid_dots(g, [[8, 0], [24, 0], [9, 1], [23, 1]], 3)
	grid_triangle(g, 8, 2, 5, 10, 1)
	grid_rect(g, 4, 6, 8, 3, 2)
	grid_set(g, 7, 7, 3)
	grid_set(g, 7, 8, 3)
	grid_triangle(g, 23, 2, 5, 10, 1)
	grid_rect(g, 19, 6, 8, 3, 2)
	grid_set(g, 22, 7, 3)
	grid_set(g, 22, 8, 3)
	grid_rect(g, 0, 9, GRID_W, 2, 2)
	grid_dots(g, [[2, 11], [6, 11], [10, 11], [14, 11],
		[18, 11], [22, 11], [26, 11], [30, 11]], 3)


func _gen_cercles(g: Array) -> void:
	grid_dots(g, [[3, 0], [9, 1], [15, 0], [22, 1], [28, 0],
		[6, 1], [19, 0], [26, 1], [12, 0], [30, 1]], 3)
	grid_dots(g, [[15, 2], [16, 2], [14, 3], [15, 3], [16, 3], [17, 3]], 3)
	grid_rect(g, 3, 5, 2, 6, 1)
	grid_rect(g, 9, 4, 2, 7, 1)
	grid_rect(g, 15, 3, 2, 8, 1)
	grid_rect(g, 21, 4, 2, 7, 1)
	grid_rect(g, 27, 5, 2, 6, 1)
	grid_rect(g, 0, 11, GRID_W, 2, 2)
	grid_dots(g, [[6, 12], [12, 12], [18, 12], [24, 12]], 3)


func _gen_marais(g: Array) -> void:
	grid_dots(g, [[4, 0], [12, 1], [20, 0], [28, 1], [8, 0], [24, 1]], 3)
	grid_rect(g, 5, 4, 2, 5, 1)
	grid_dots(g, [[4, 2], [5, 2], [7, 2], [3, 3], [4, 3], [5, 3],
		[6, 3], [7, 3], [8, 3]], 1)
	grid_rect(g, 22, 5, 2, 4, 1)
	grid_dots(g, [[21, 3], [22, 3], [24, 3], [20, 4], [21, 4],
		[22, 4], [23, 4], [24, 4], [25, 4]], 1)
	grid_rect(g, 0, 9, GRID_W, 3, 2)
	grid_dots(g, [[5, 10], [6, 10], [22, 10], [23, 10],
		[10, 11], [15, 11], [28, 11]], 3)
	grid_rect(g, 0, 12, GRID_W, 2, 1)
	grid_dots(g, [[2, 13], [8, 13], [14, 13], [19, 13], [26, 13]], 3)


func _gen_collines(g: Array) -> void:
	grid_dots(g, [[5, 0], [12, 0], [20, 0], [27, 0], [16, 1],
		[8, 1], [24, 1]], 3)
	grid_rect(g, 11, 4, 10, 2, 1)
	grid_rect(g, 12, 6, 2, 4, 1)
	grid_rect(g, 18, 6, 2, 4, 1)
	grid_hill(g, 8, 11, 10, 3, 2)
	grid_hill(g, 24, 11, 10, 4, 2)
	grid_rect(g, 0, 12, GRID_W, 2, 2)
	grid_dots(g, [[2, 14], [7, 14], [14, 14], [21, 14], [26, 14], [30, 14]], 1)


func _gen_iles(g: Array) -> void:
	grid_rect(g, 0, 10, GRID_W, 6, 2)
	grid_rect(g, 10, 6, 12, 4, 1)
	grid_rect(g, 12, 4, 8, 2, 1)
	grid_rect(g, 14, 3, 4, 1, 1)
	grid_rect(g, 15, 0, 2, 3, 1)
	grid_dots(g, [[4, 9], [5, 9], [8, 10], [24, 9], [25, 9], [28, 10]], 3)
	grid_dots(g, [[2, 0], [6, 1], [10, 0], [22, 0], [28, 1]], 3)


# ═══════════════════════════════════════════════════════════════════════════════
# STAGED GROWTH — Delegated to TransitionBiomeLandscapeStages
# ═══════════════════════════════════════════════════════════════════════════════

func get_biome_stages(biome: String) -> Array:
	return _stages_mod.get_biome_stages(biome)


func get_quest_tree_stages() -> Array:
	return _stages_mod.get_quest_tree_stages()
