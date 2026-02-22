## ═══════════════════════════════════════════════════════════════════════════════
## PixelEncounterTile — Pixel art illustration per encounter type (v1.0)
## ═══════════════════════════════════════════════════════════════════════════════
## 24x24 grid, cascade assembly animation (top-down).
## Types: path_choice, npc, combat, mystery, rest, merchant
## Usage: var tile = PixelEncounterTile.new(); tile.setup("combat"); parent.add_child(tile)
## ═══════════════════════════════════════════════════════════════════════════════

class_name PixelEncounterTile
extends Control

const GRID_SIZE := 24
const PIXEL_SIZE := 3.0
const CASCADE_DELAY := 0.008

var _grid: Array = []  # 2D array of Color
var _revealed_rows: int = 0
var _cascade_tween: Tween
var _encounter_type: String = "mystery"

func _init() -> void:
	custom_minimum_size = Vector2(GRID_SIZE * PIXEL_SIZE, GRID_SIZE * PIXEL_SIZE)


func setup(encounter_type: String, scale_factor: float = 3.0) -> void:
	_encounter_type = encounter_type
	custom_minimum_size = Vector2(GRID_SIZE * scale_factor, GRID_SIZE * scale_factor)
	_generate_grid(encounter_type)
	_revealed_rows = 0
	queue_redraw()


func assemble(animated: bool = true) -> void:
	if animated:
		_revealed_rows = 0
		if _cascade_tween:
			_cascade_tween.kill()
		_cascade_tween = create_tween()
		for row in range(GRID_SIZE):
			_cascade_tween.tween_callback(_reveal_row)
			_cascade_tween.tween_interval(CASCADE_DELAY)
	else:
		_revealed_rows = GRID_SIZE
		queue_redraw()


func _reveal_row() -> void:
	_revealed_rows += 1
	queue_redraw()


func _draw() -> void:
	if _grid.is_empty():
		return
	var pixel_w: float = size.x / float(GRID_SIZE)
	var pixel_h: float = size.y / float(GRID_SIZE)
	for y in range(mini(_revealed_rows, GRID_SIZE)):
		for x in range(GRID_SIZE):
			var color: Color = _grid[y][x]
			if color.a > 0.01:
				draw_rect(Rect2(x * pixel_w, y * pixel_h, pixel_w, pixel_h), color)


func _generate_grid(encounter_type: String) -> void:
	# Initialize empty grid
	_grid.clear()
	for y in range(GRID_SIZE):
		var row: Array = []
		for x in range(GRID_SIZE):
			row.append(Color.TRANSPARENT)
		_grid.append(row)

	match encounter_type:
		"path_choice":
			_draw_path_choice()
		"npc":
			_draw_npc()
		"combat":
			_draw_combat()
		"mystery":
			_draw_mystery()
		"rest":
			_draw_rest()
		"merchant":
			_draw_merchant()
		_:
			_draw_mystery()


func _set_px(x: int, y: int, color: Color) -> void:
	if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
		_grid[y][x] = color


func _draw_path_choice() -> void:
	## Y-fork in the road — two paths diverging
	var c: Color = MerlinVisual.PALETTE["celtic_gold"]
	var o: Color = MerlinVisual.PALETTE["ink"]
	var g: Color = MerlinVisual.PALETTE["celtic_green"]
	# Tree canopy top
	for x in range(8, 16):
		_set_px(x, 2, g)
		_set_px(x, 3, g)
	for x in range(6, 18):
		_set_px(x, 4, g)
	# Trunk
	for y in range(5, 10):
		_set_px(11, y, o)
		_set_px(12, y, o)
	# Ground
	for x in range(3, 21):
		_set_px(x, 14, c)
	# Left path
	for y in range(15, 22):
		var lx := 8 - (y - 15)
		_set_px(lx, y, c)
		_set_px(lx + 1, y, c)
	# Right path
	for y in range(15, 22):
		var rx := 15 + (y - 15)
		_set_px(rx, y, c)
		_set_px(rx + 1, y, c)


func _draw_npc() -> void:
	## Simple bust/figure silhouette
	var o: Color = MerlinVisual.PALETTE["ink"]
	var h: Color = MerlinVisual.PALETTE["paper"]
	var f: Color = MerlinVisual.PALETTE["celtic_gold"]
	# Head
	for x in range(10, 14):
		_set_px(x, 4, o)
		_set_px(x, 5, h)
		_set_px(x, 6, h)
		_set_px(x, 7, o)
	# Neck
	_set_px(11, 8, o)
	_set_px(12, 8, o)
	# Body
	for y in range(9, 16):
		var w := 2 + (y - 9)
		var sx := 12 - int(w / 2.0)
		for x in range(sx, sx + w):
			_set_px(x, y, f)
	# Eyes
	_set_px(10, 5, o)
	_set_px(13, 5, o)
	# Arms
	for y in range(10, 14):
		_set_px(7, y, f)
		_set_px(16, y, f)


func _draw_combat() -> void:
	## Crossed swords
	var o: Color = MerlinVisual.PALETTE["ink"]
	var d: Color = MerlinVisual.PALETTE["celtic_red"]
	var a: Color = MerlinVisual.PALETTE["celtic_gold"]
	# Sword 1 (top-left to bottom-right)
	for i in range(16):
		_set_px(4 + i, 4 + i, o)
	# Sword 2 (top-right to bottom-left)
	for i in range(16):
		_set_px(19 - i, 4 + i, o)
	# Hilts
	for dx in range(-2, 3):
		_set_px(7 + dx, 7, a)
		_set_px(16 + dx, 7, a)
	# Clash point spark
	_set_px(12, 12, d)
	_set_px(11, 11, d)
	_set_px(13, 11, d)
	_set_px(11, 13, d)
	_set_px(13, 13, d)


func _draw_mystery() -> void:
	## Question mark symbol
	var m: Color = MerlinVisual.PALETTE["celtic_purple"]
	var h: Color = MerlinVisual.PALETTE["paper"]
	# Top arc of ?
	for x in range(9, 15):
		_set_px(x, 5, m)
	_set_px(8, 6, m)
	_set_px(15, 6, m)
	_set_px(8, 7, m)
	_set_px(15, 7, m)
	_set_px(15, 8, m)
	_set_px(14, 9, m)
	_set_px(13, 10, m)
	_set_px(12, 11, m)
	_set_px(12, 12, m)
	# Dot
	_set_px(12, 15, h)
	_set_px(11, 15, h)
	_set_px(12, 16, h)
	_set_px(11, 16, h)
	# Sparkles around
	_set_px(5, 4, m)
	_set_px(19, 8, m)
	_set_px(6, 14, m)
	_set_px(18, 3, m)


func _draw_rest() -> void:
	## Campfire with flames
	var o: Color = MerlinVisual.PALETTE["ink"]
	var f: Color = MerlinVisual.PALETTE["celtic_gold"]
	var d: Color = MerlinVisual.PALETTE["celtic_red"]
	var w: Color = MerlinVisual.PALETTE["paper"]
	# Logs
	for x in range(7, 17):
		_set_px(x, 17, o)
		_set_px(x, 18, o)
	# Cross log
	_set_px(8, 16, o)
	_set_px(9, 16, o)
	_set_px(14, 16, o)
	_set_px(15, 16, o)
	# Flame base
	for x in range(10, 14):
		_set_px(x, 15, f)
		_set_px(x, 14, f)
	for x in range(10, 14):
		_set_px(x, 13, d)
	_set_px(11, 12, d)
	_set_px(12, 12, d)
	_set_px(11, 11, f)
	_set_px(12, 11, f)
	_set_px(12, 10, w)
	_set_px(11, 9, w)
	# Sparks
	_set_px(10, 7, f)
	_set_px(13, 6, f)
	_set_px(9, 5, f)


func _draw_merchant() -> void:
	## Coins/treasure
	var a: Color = MerlinVisual.PALETTE["celtic_gold"]
	var h: Color = MerlinVisual.PALETTE["paper"]
	var o: Color = MerlinVisual.PALETTE["ink"]
	# Coin 1 (center)
	for x in range(10, 14):
		_set_px(x, 8, a)
		_set_px(x, 9, a)
		_set_px(x, 10, a)
		_set_px(x, 11, o)
	_set_px(12, 9, h)
	# Coin 2 (left)
	for x in range(6, 10):
		_set_px(x, 11, a)
		_set_px(x, 12, a)
		_set_px(x, 13, a)
		_set_px(x, 14, o)
	_set_px(8, 12, h)
	# Coin 3 (right)
	for x in range(14, 18):
		_set_px(x, 11, a)
		_set_px(x, 12, a)
		_set_px(x, 13, a)
		_set_px(x, 14, o)
	_set_px(16, 12, h)
	# Bag
	for x in range(9, 15):
		_set_px(x, 15, o)
		_set_px(x, 16, o)
		_set_px(x, 17, o)
	_set_px(9, 14, o)
	_set_px(14, 14, o)


## Detect encounter type from card tags
static func detect_type(card: Dictionary) -> String:
	var tags: Array = card.get("tags", [])
	if "combat" in tags or "danger" in tags:
		return "combat"
	if "stranger" in tags or "social" in tags or "npc" in tags:
		return "npc"
	if "rest" in tags or "recovery" in tags:
		return "rest"
	if "choice" in tags or "exploration" in tags or "travel" in tags:
		return "path_choice"
	if "merchant" in tags or "trade" in tags:
		return "merchant"
	if "mystery" in tags or "magic" in tags or "lore" in tags:
		return "mystery"
	return "mystery"
