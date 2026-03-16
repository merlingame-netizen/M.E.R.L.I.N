## ═══════════════════════════════════════════════════════════════════════════════
## Transition Biome — Landscape Staged Growth Module
## ═══════════════════════════════════════════════════════════════════════════════
## 5-stage progressive emergence pixel data for all biomes + quest tree.
## Extracted from TransitionBiomeLandscape to keep files under 800 lines.
## ═══════════════════════════════════════════════════════════════════════════════

class_name TransitionBiomeLandscapeStages
extends RefCounted

const GRID_W := 32
const GRID_H := 16


# ═══════════════════════════════════════════════════════════════════════════════
# STAGED GROWTH — 5-stage progressive emergence for all biomes
# ═══════════════════════════════════════════════════════════════════════════════

func get_biome_stages(biome: String) -> Array:
	match biome:
		"broceliande": return _get_broceliande_stages()
		"landes": return _get_landes_stages()
		"cotes": return _get_cotes_stages()
		"villages": return _get_villages_stages()
		"cercles": return _get_cercles_stages()
		"marais": return _get_marais_stages()
		"collines": return _get_collines_stages()
		"iles": return _get_iles_stages()
		_: return _get_broceliande_stages()
	return []


# ── BROCELIANDE ──────────────────────────────────────────────────────────────

func _get_broceliande_stages() -> Array:
	return [
		_broceliande_stage_ground(),
		_broceliande_stage_trunks(),
		_broceliande_stage_branches(),
		_broceliande_stage_canopy(),
		_broceliande_stage_details(),
	]


func _broceliande_stage_ground() -> Array:
	var px: Array = []
	for x in range(GRID_W):
		for y in range(12, 16):
			px.append([x, y, "s"])
	for pos in [[3, 12], [10, 12], [19, 12], [27, 12]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _broceliande_stage_trunks() -> Array:
	var px: Array = []
	for y in range(5, 12):
		px.append([12, y, "s"])
		px.append([13, y, "s"])
	for y in range(4, 12):
		px.append([22, y, "s"])
		px.append([23, y, "s"])
	for y in range(6, 12):
		px.append([5, y, "s"])
	for y in range(7, 12):
		px.append([29, y, "s"])
	for y in range(8, 12):
		px.append([17, y, "s"])
	for y in range(9, 12):
		px.append([1, y, "s"])
	for pos in [[11, 11], [14, 11], [21, 11], [24, 11], [4, 11], [6, 11], [28, 11], [30, 11]]:
		px.append([pos[0], pos[1], "s"])
	return px


func _broceliande_stage_branches() -> Array:
	var px: Array = []
	for x in range(9, 16):
		px.append([x, 5, "p"])
		px.append([x, 6, "p"])
	for x in range(19, 27):
		px.append([x, 4, "p"])
		px.append([x, 5, "p"])
	for x in range(3, 8):
		px.append([x, 6, "p"])
		px.append([x, 7, "p"])
	for x in range(27, 31):
		px.append([x, 7, "p"])
	for x in range(7, 11):
		px.append([x, 10, "p"])
		px.append([x, 11, "p"])
	for x in range(15, 19):
		px.append([x, 10, "p"])
		px.append([x, 11, "p"])
	for x in range(25, 28):
		px.append([x, 10, "p"])
	return px


func _broceliande_stage_canopy() -> Array:
	var px: Array = []
	var trunk_cols: Array = [1, 5, 12, 13, 17, 22, 23, 29]
	for x in range(2, 30):
		px.append([x, 2, "p"])
		px.append([x, 3, "p"])
	for x in range(1, 31):
		px.append([x, 4, "p"])
	for x in range(0, GRID_W):
		if not trunk_cols.has(x):
			px.append([x, 5, "p"])
	for x in range(0, GRID_W):
		for y in range(6, 10):
			if not trunk_cols.has(x) and (x + y) % 3 != 0:
				px.append([x, y, "p"])
	for pos in [[8, 1], [9, 1], [14, 0], [15, 0], [20, 1], [21, 1], [25, 1]]:
		px.append([pos[0], pos[1], "p"])
	return px


func _broceliande_stage_details() -> Array:
	var px: Array = []
	for pos in [[2, 13], [9, 14], [16, 13], [24, 14], [30, 13]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[6, 12], [14, 12], [20, 12], [26, 12]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[4, 3], [11, 2], [18, 1], [25, 3], [7, 5], [22, 4], [15, 3], [28, 2]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[8, 8], [8, 9], [16, 8], [16, 9], [26, 8]]:
		px.append([pos[0], pos[1], "p"])
	return px


# ── LANDES ───────────────────────────────────────────────────────────────────

func _get_landes_stages() -> Array:
	return [
		_landes_stage_ground(),
		_landes_stage_menhirs(),
		_landes_stage_hills(),
		_landes_stage_heather(),
		_landes_stage_details(),
	]


func _landes_stage_ground() -> Array:
	var px: Array = []
	for x in range(GRID_W):
		for y in range(13, 16):
			px.append([x, y, "s"])
	for pos in [[3, 13], [10, 13], [19, 13], [27, 13], [7, 14], [23, 14]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _landes_stage_menhirs() -> Array:
	var px: Array = []
	for y in range(2, 13):
		px.append([15, y, "p"])
		px.append([16, y, "p"])
	px.append([15, 1, "p"])
	for x in [14, 17]:
		for y in [11, 12]:
			px.append([x, y, "p"])
	for y in range(6, 13):
		px.append([6, y, "p"])
	for y in range(8, 13):
		px.append([28, y, "p"])
	return px


func _landes_stage_hills() -> Array:
	var px: Array = []
	for x in range(4, 13):
		px.append([x, 10, "s"])
	for x in range(2, 14):
		px.append([x, 11, "s"])
	for x in range(0, 14):
		px.append([x, 12, "s"])
	for x in range(22, 30):
		px.append([x, 10, "s"])
	for x in range(20, 31):
		px.append([x, 11, "s"])
	for x in range(18, GRID_W):
		px.append([x, 12, "s"])
	return px


func _landes_stage_heather() -> Array:
	var px: Array = []
	for pos in [[1, 12], [4, 11], [7, 10], [10, 10], [5, 12], [9, 11],
		[12, 11], [20, 12], [22, 11], [25, 10], [28, 11], [30, 12],
		[2, 14], [8, 14], [13, 14], [18, 14], [24, 14], [29, 14]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[3, 12], [4, 12], [11, 10], [12, 10], [23, 10], [24, 10],
		[26, 11], [27, 11]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _landes_stage_details() -> Array:
	var px: Array = []
	for pos in [[2, 1], [3, 1], [4, 1], [20, 2], [21, 2], [22, 2],
		[10, 3], [11, 3], [12, 3]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[8, 0], [9, 0], [25, 1], [26, 1]]:
		px.append([pos[0], pos[1], "p"])
	for pos in [[15, 12], [16, 12]]:
		px.append([pos[0], pos[1], "a"])
	return px


# ── COTES ────────────────────────────────────────────────────────────────────

func _get_cotes_stages() -> Array:
	return [
		_cotes_stage_shore(),
		_cotes_stage_cliff(),
		_cotes_stage_waves(),
		_cotes_stage_spray(),
		_cotes_stage_details(),
	]


func _cotes_stage_shore() -> Array:
	var px: Array = []
	for x in range(14, GRID_W):
		for y in [10, 11]:
			px.append([x, y, "s"])
	for x in range(GRID_W):
		for y in range(12, 16):
			px.append([x, y, "s"])
	return px


func _cotes_stage_cliff() -> Array:
	var px: Array = []
	for x in range(0, 7):
		for y in range(2, 12):
			px.append([x, y, "p"])
	for x in range(7, 10):
		for y in range(4, 12):
			px.append([x, y, "p"])
	for x in range(10, 12):
		for y in range(6, 12):
			px.append([x, y, "p"])
	for x in range(12, 14):
		for y in range(8, 12):
			px.append([x, y, "p"])
	for x in range(0, 7):
		px.append([x, 1, "a"])
	return px


func _cotes_stage_waves() -> Array:
	var px: Array = []
	for pos in [[17, 8], [18, 8], [23, 7], [24, 7], [29, 8], [30, 8]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[16, 9], [17, 9], [21, 9], [22, 9], [27, 9], [28, 9]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[15, 10], [19, 10], [25, 10], [31, 10]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _cotes_stage_spray() -> Array:
	var px: Array = []
	for pos in [[13, 9], [14, 9], [14, 8], [12, 10], [13, 10]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[3, 14], [8, 14], [15, 14], [21, 14], [27, 14]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[14, 6], [15, 7], [11, 7]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _cotes_stage_details() -> Array:
	var px: Array = []
	for pos in [[18, 1], [19, 1], [24, 0], [25, 0], [28, 2], [29, 2]]:
		px.append([pos[0], pos[1], "a"])
	for y in range(3, 8):
		px.append([31, y, "p"])
	px.append([31, 2, "a"])
	for pos in [[2, 5], [4, 7], [1, 9], [5, 4], [3, 8]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[6, 13], [10, 13]]:
		px.append([pos[0], pos[1], "a"])
	return px


# ── VILLAGES ─────────────────────────────────────────────────────────────────

func _get_villages_stages() -> Array:
	return [
		_villages_stage_ground(),
		_villages_stage_walls(),
		_villages_stage_roofs(),
		_villages_stage_smoke(),
		_villages_stage_details(),
	]


func _villages_stage_ground() -> Array:
	var px: Array = []
	for x in range(GRID_W):
		for y in range(10, 16):
			px.append([x, y, "s"])
	return px


func _villages_stage_walls() -> Array:
	var px: Array = []
	for x in range(4, 12):
		for y in range(6, 10):
			px.append([x, y, "s"])
	for x in range(19, 27):
		for y in range(6, 10):
			px.append([x, y, "s"])
	for y in range(8, 10):
		px.append([15, y, "p"])
		px.append([16, y, "p"])
	return px


func _villages_stage_roofs() -> Array:
	var px: Array = []
	for x in range(5, 11):
		px.append([x, 4, "p"])
	for x in range(4, 12):
		px.append([x, 5, "p"])
	px.append([7, 3, "p"])
	px.append([8, 3, "p"])
	for x in range(20, 26):
		px.append([x, 4, "p"])
	for x in range(19, 27):
		px.append([x, 5, "p"])
	px.append([22, 3, "p"])
	px.append([23, 3, "p"])
	for x in [14, 15, 16, 17]:
		px.append([x, 7, "p"])
	return px


func _villages_stage_smoke() -> Array:
	var px: Array = []
	for pos in [[8, 2], [7, 1], [8, 0], [9, 1]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[23, 2], [22, 1], [23, 0], [24, 1]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _villages_stage_details() -> Array:
	var px: Array = []
	for pos in [[7, 8], [7, 9], [22, 8], [22, 9]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[5, 7], [10, 7], [20, 7], [25, 7]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[2, 11], [6, 11], [10, 11], [13, 11], [14, 11],
		[15, 11], [16, 11], [17, 11], [18, 11], [22, 11], [26, 11], [30, 11]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[1, 10], [2, 10], [29, 10], [30, 10]]:
		px.append([pos[0], pos[1], "p"])
	for pos in [[3, 9], [12, 9], [18, 9], [27, 9]]:
		px.append([pos[0], pos[1], "p"])
	return px


# ── CERCLES ──────────────────────────────────────────────────────────────────

func _get_cercles_stages() -> Array:
	return [
		_cercles_stage_ground(),
		_cercles_stage_stones(),
		_cercles_stage_moon(),
		_cercles_stage_stars(),
		_cercles_stage_details(),
	]


func _cercles_stage_ground() -> Array:
	var px: Array = []
	for x in range(GRID_W):
		for y in range(11, 16):
			px.append([x, y, "s"])
	return px


func _cercles_stage_stones() -> Array:
	var px: Array = []
	for y in range(5, 11):
		px.append([3, y, "p"])
		px.append([4, y, "p"])
	for y in range(4, 11):
		px.append([9, y, "p"])
		px.append([10, y, "p"])
	for y in range(3, 11):
		px.append([15, y, "p"])
		px.append([16, y, "p"])
	for y in range(4, 11):
		px.append([21, y, "p"])
		px.append([22, y, "p"])
	for y in range(5, 11):
		px.append([27, y, "p"])
		px.append([28, y, "p"])
	for x in range(13, 19):
		px.append([x, 10, "p"])
	return px


func _cercles_stage_moon() -> Array:
	var px: Array = []
	for pos in [[22, 0], [23, 0], [24, 0],
		[21, 1], [22, 1], [23, 1], [24, 1], [25, 1],
		[22, 2], [23, 2], [24, 2]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _cercles_stage_stars() -> Array:
	var px: Array = []
	for pos in [[3, 0], [7, 1], [12, 0], [17, 1], [28, 0],
		[5, 2], [10, 1], [14, 2], [19, 0], [26, 2],
		[1, 1], [30, 1], [8, 0], [20, 2]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _cercles_stage_details() -> Array:
	var px: Array = []
	for pos in [[3, 7], [9, 6], [15, 5], [21, 6], [27, 7],
		[4, 8], [10, 7], [16, 6], [22, 7], [28, 8]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[6, 12], [12, 12], [18, 12], [24, 12]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[0, 11], [5, 11], [11, 11], [20, 11], [26, 11], [31, 11]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[14, 9], [15, 9], [16, 9], [17, 9], [18, 9]]:
		px.append([pos[0], pos[1], "a"])
	return px


# ── MARAIS ───────────────────────────────────────────────────────────────────

func _get_marais_stages() -> Array:
	return [
		_marais_stage_water(),
		_marais_stage_trunks(),
		_marais_stage_branches(),
		_marais_stage_mist(),
		_marais_stage_details(),
	]


func _marais_stage_water() -> Array:
	var px: Array = []
	for x in range(GRID_W):
		for y in range(9, 13):
			px.append([x, y, "s"])
	for x in range(GRID_W):
		for y in range(13, 16):
			px.append([x, y, "p"])
	return px


func _marais_stage_trunks() -> Array:
	var px: Array = []
	for y in range(4, 9):
		px.append([5, y, "p"])
		px.append([6, y, "p"])
	for pos in [[3, 9], [4, 9], [7, 9]]:
		px.append([pos[0], pos[1], "p"])
	for y in range(5, 9):
		px.append([22, y, "p"])
		px.append([23, y, "p"])
	for pos in [[21, 9], [24, 9]]:
		px.append([pos[0], pos[1], "p"])
	for y in range(7, 9):
		px.append([14, y, "p"])
	return px


func _marais_stage_branches() -> Array:
	var px: Array = []
	for pos in [[3, 2], [4, 2], [5, 2], [7, 2], [8, 2],
		[2, 3], [3, 3], [4, 3], [5, 3], [6, 3], [7, 3], [8, 3], [9, 3],
		[3, 4], [4, 4], [7, 4], [8, 4]]:
		px.append([pos[0], pos[1], "p"])
	for pos in [[20, 3], [21, 3], [22, 3], [24, 3], [25, 3],
		[19, 4], [20, 4], [21, 4], [22, 4], [23, 4], [24, 4], [25, 4], [26, 4],
		[20, 5], [21, 5], [24, 5], [25, 5]]:
		px.append([pos[0], pos[1], "p"])
	for pos in [[3, 5], [8, 4], [20, 6], [25, 6]]:
		px.append([pos[0], pos[1], "s"])
	return px


func _marais_stage_mist() -> Array:
	var px: Array = []
	for pos in [[4, 0], [12, 1], [16, 0], [20, 0], [28, 1], [8, 0], [24, 1]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[5, 10], [6, 10], [22, 10], [23, 10],
		[10, 11], [15, 11], [28, 11]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _marais_stage_details() -> Array:
	var px: Array = []
	for pos in [[2, 13], [8, 13], [11, 12], [17, 13], [19, 12], [26, 13], [30, 12]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[10, 6], [13, 3], [18, 5], [27, 2]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[11, 7], [12, 7], [29, 6], [30, 6]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[7, 9], [8, 9], [16, 9], [17, 9], [25, 9], [26, 9]]:
		px.append([pos[0], pos[1], "a"])
	return px


# ── COLLINES ─────────────────────────────────────────────────────────────────

func _get_collines_stages() -> Array:
	return [
		_collines_stage_hills(),
		_collines_stage_pillars(),
		_collines_stage_capstone(),
		_collines_stage_sunset(),
		_collines_stage_details(),
	]


func _collines_stage_hills() -> Array:
	var px: Array = []
	for x in range(3, 15):
		px.append([x, 10, "s"])
	for x in range(1, 16):
		px.append([x, 11, "s"])
	for x in range(20, 30):
		px.append([x, 10, "s"])
	for x in range(18, 31):
		px.append([x, 11, "s"])
	for x in range(GRID_W):
		for y in range(12, 16):
			px.append([x, y, "s"])
	return px


func _collines_stage_pillars() -> Array:
	var px: Array = []
	for y in range(6, 11):
		px.append([12, y, "p"])
		px.append([13, y, "p"])
	for y in range(6, 11):
		px.append([18, y, "p"])
		px.append([19, y, "p"])
	return px


func _collines_stage_capstone() -> Array:
	var px: Array = []
	for x in range(11, 21):
		px.append([x, 4, "p"])
		px.append([x, 5, "p"])
	return px


func _collines_stage_sunset() -> Array:
	var px: Array = []
	for pos in [[5, 0], [8, 0], [12, 0], [16, 0], [20, 0], [24, 0], [27, 0],
		[3, 1], [7, 1], [11, 1], [15, 1], [19, 1], [23, 1], [27, 1],
		[6, 2], [10, 2], [14, 2], [18, 2], [22, 2], [26, 2]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[14, 3], [15, 3], [16, 3], [17, 3]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _collines_stage_details() -> Array:
	var px: Array = []
	for pos in [[2, 14], [7, 14], [14, 14], [21, 14], [26, 14], [30, 14],
		[4, 12], [9, 12], [22, 12], [28, 12]]:
		px.append([pos[0], pos[1], "p"])
	for pos in [[1, 9], [2, 9], [29, 9], [30, 9]]:
		px.append([pos[0], pos[1], "s"])
	for y in range(8, 11):
		px.append([0, y, "p"])
	for pos in [[10, 12], [11, 12], [15, 12], [16, 12], [20, 12], [21, 12]]:
		px.append([pos[0], pos[1], "a"])
	return px


# ── ILES ─────────────────────────────────────────────────────────────────────

func _get_iles_stages() -> Array:
	return [
		_iles_stage_ocean(),
		_iles_stage_island(),
		_iles_stage_tower(),
		_iles_stage_aurora(),
		_iles_stage_details(),
	]


func _iles_stage_ocean() -> Array:
	var px: Array = []
	for x in range(GRID_W):
		for y in range(10, 16):
			px.append([x, y, "s"])
	for x in range(0, GRID_W, 2):
		px.append([x, 9, "s"])
	return px


func _iles_stage_island() -> Array:
	var px: Array = []
	for x in range(10, 22):
		px.append([x, 9, "p"])
	for x in range(9, 23):
		px.append([x, 8, "p"])
	for x in range(11, 21):
		px.append([x, 7, "p"])
	for x in range(12, 20):
		px.append([x, 6, "p"])
	for x in range(13, 19):
		px.append([x, 5, "p"])
	for x in range(14, 18):
		px.append([x, 4, "p"])
	return px


func _iles_stage_tower() -> Array:
	var px: Array = []
	for y in range(1, 4):
		px.append([15, y, "p"])
		px.append([16, y, "p"])
	px.append([15, 0, "p"])
	px.append([16, 0, "p"])
	for pos in [[12, 5], [13, 5], [11, 6], [12, 6]]:
		px.append([pos[0], pos[1], "p"])
	for pos in [[19, 5], [20, 5], [19, 6], [20, 6]]:
		px.append([pos[0], pos[1], "p"])
	px.append([15, 3, "a"])
	px.append([16, 3, "a"])
	return px


func _iles_stage_aurora() -> Array:
	var px: Array = []
	for pos in [[3, 0], [4, 0], [5, 0], [7, 1], [8, 1],
		[24, 0], [25, 0], [26, 0], [28, 1], [29, 1],
		[1, 2], [2, 2], [29, 2], [30, 2]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[7, 8], [8, 8], [23, 8], [24, 8],
		[6, 9], [7, 9], [24, 9], [25, 9]]:
		px.append([pos[0], pos[1], "a"])
	return px


func _iles_stage_details() -> Array:
	var px: Array = []
	for pos in [[3, 11], [4, 11], [9, 12], [10, 12],
		[22, 11], [23, 11], [27, 12], [28, 12],
		[1, 13], [14, 14], [18, 14], [30, 13]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[2, 14], [6, 15], [12, 15], [20, 15], [26, 14]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[14, 2], [17, 1], [13, 3]]:
		px.append([pos[0], pos[1], "a"])
	for pos in [[0, 8], [1, 8], [0, 9]]:
		px.append([pos[0], pos[1], "p"])
	return px


# ═══════════════════════════════════════════════════════════════════════════════
# QUEST TREE — Growing oak tree pixel data (for quest preparation)
# ═══════════════════════════════════════════════════════════════════════════════

func get_quest_tree_stages() -> Array:
	return [
		# Stage 1: Roots + ground
		[
			[0,13,"s"],[1,13,"s"],[2,13,"s"],[3,13,"s"],[4,13,"s"],
			[5,13,"s"],[6,13,"s"],[7,13,"s"],[8,13,"s"],[9,13,"s"],
			[3,12,"s"],[4,12,"s"],[5,12,"s"],[6,12,"s"],
			[2,12,"s"],[7,12,"s"],
		],
		# Stage 2: Trunk
		[
			[4,11,"s"],[5,11,"s"],
			[4,10,"s"],[5,10,"s"],
			[4,9,"s"],[5,9,"s"],
			[4,8,"s"],[5,8,"s"],
			[4,7,"s"],[5,7,"s"],
		],
		# Stage 3: Lower branches
		[
			[2,7,"p"],[3,7,"p"],[6,7,"p"],[7,7,"p"],
			[2,6,"p"],[3,6,"p"],[4,6,"p"],[5,6,"p"],[6,6,"p"],[7,6,"p"],
			[1,6,"p"],[8,6,"p"],
			[3,5,"p"],[4,5,"p"],[5,5,"p"],[6,5,"p"],
		],
		# Stage 4: Upper canopy
		[
			[2,5,"p"],[7,5,"p"],
			[2,4,"p"],[3,4,"p"],[4,4,"p"],[5,4,"p"],[6,4,"p"],[7,4,"p"],
			[3,3,"p"],[4,3,"p"],[5,3,"p"],[6,3,"p"],
			[4,2,"p"],[5,2,"p"],
		],
		# Stage 5: Crown + golden accents
		[
			[3,2,"p"],[6,2,"p"],
			[3,1,"a"],[4,1,"p"],[5,1,"p"],[6,1,"a"],
			[4,0,"a"],[5,0,"a"],
			[1,5,"a"],[8,5,"a"],[2,3,"a"],
		],
	]
