## ═══════════════════════════════════════════════════════════════════════════════
## Pixel Character Portrait — Micro-pixel character assembly system
## ═══════════════════════════════════════════════════════════════════════════════
## Renders characters as 16x16 pixel art grids with cascade assembly animation.
## Art Direction: Celtic knotwork meets pixel art, parchment-toned palette.
## ═══════════════════════════════════════════════════════════════════════════════

class_name PixelCharacterPortrait
extends Control

signal assembly_complete

const GRID_SIZE := 16
const DEFAULT_PIXEL_SIZE := 4.0

# ═══════════════════════════════════════════════════════════════════════════════
# CHARACTER TEMPLATES — 16x16 pixel grids
# ═══════════════════════════════════════════════════════════════════════════════
# Legend: 0=empty, 1=primary, 2=secondary, 3=accent, 4=highlight, 5=dark

const CHARACTERS := {
	"merlin": {
		"name": "Merlin",
		"palette": [
			Color.TRANSPARENT,                    # 0 = empty
			Color(0.07, 0.12, 0.29),              # 1 = hat dark blue
			Color(0.12, 0.20, 0.42),              # 2 = hat medium blue
			Color(0.34, 0.73, 1.0),               # 3 = orb glow
			Color(0.38, 0.82, 1.0),               # 4 = eyes glow
			Color(0.04, 0.05, 0.08),              # 5 = face dark
		],
		"grid": [
			[0,0,0,0,0,0,0,0,0,3,0,0,0,0,0,0],
			[0,0,0,0,0,0,0,0,1,1,0,0,0,0,0,0],
			[0,0,0,0,0,0,0,1,1,1,1,0,0,0,0,0],
			[0,0,0,0,0,0,1,1,1,2,2,0,0,0,0,0],
			[0,0,0,0,0,1,1,1,2,2,2,2,0,0,0,0],
			[0,0,0,5,5,5,5,5,5,5,5,5,5,0,0,0],
			[0,0,0,0,5,5,2,2,2,2,5,5,0,0,0,0],
			[0,0,0,0,5,4,2,2,2,4,5,5,0,0,0,0],
			[0,0,0,0,5,5,2,5,5,5,5,0,0,0,0,0],
			[0,0,0,0,0,5,5,5,5,5,0,0,0,0,0,0],
			[0,0,0,0,0,0,5,5,5,0,0,0,0,0,0,0],
			[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
			[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
			[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
			[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
			[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		],
	},
	"villager": {
		"name": "Villageois",
		"palette": [
			Color.TRANSPARENT,
			Color(0.55, 0.38, 0.22),              # 1 = brown tunic
			Color(0.68, 0.52, 0.32),              # 2 = light tunic
			Color(0.82, 0.65, 0.42),              # 3 = skin
			Color(0.38, 0.28, 0.18),              # 4 = hair dark
			Color(0.22, 0.18, 0.14),              # 5 = shadow
		],
		"grid": [
			[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
			[0,0,0,0,0,0,4,4,4,0,0,0,0,0,0,0],
			[0,0,0,0,0,4,4,4,4,4,0,0,0,0,0,0],
			[0,0,0,0,0,4,3,3,3,4,0,0,0,0,0,0],
			[0,0,0,0,0,3,5,3,5,3,0,0,0,0,0,0],
			[0,0,0,0,0,3,3,3,3,3,0,0,0,0,0,0],
			[0,0,0,0,0,0,3,3,3,0,0,0,0,0,0,0],
			[0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0],
			[0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
			[0,0,0,0,1,1,2,2,2,1,1,0,0,0,0,0],
			[0,0,0,0,3,1,2,2,2,1,3,0,0,0,0,0],
			[0,0,0,0,0,1,2,2,2,1,0,0,0,0,0,0],
			[0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
			[0,0,0,0,0,0,5,0,5,0,0,0,0,0,0,0],
			[0,0,0,0,0,5,5,0,5,5,0,0,0,0,0,0],
			[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		],
	},
	"druid": {
		"name": "Druide",
		"palette": [
			Color.TRANSPARENT,
			Color(0.22, 0.42, 0.18),              # 1 = green robe
			Color(0.35, 0.55, 0.28),              # 2 = light green
			Color(0.82, 0.72, 0.58),              # 3 = skin/wood
			Color(0.62, 0.78, 0.42),              # 4 = leaf accent
			Color(0.15, 0.12, 0.10),              # 5 = shadow
		],
		"grid": [
			[0,0,0,0,0,4,4,4,4,4,0,0,0,0,0,0],
			[0,0,0,0,4,2,2,4,2,2,4,0,0,0,0,0],
			[0,0,0,0,0,3,3,3,3,3,0,0,0,0,0,0],
			[0,0,0,0,0,3,3,3,3,3,0,0,0,0,0,0],
			[0,0,0,0,3,5,3,3,5,3,0,0,0,0,0,0],
			[0,0,0,0,0,3,3,5,3,3,0,0,0,0,0,0],
			[0,0,0,0,0,0,3,3,3,0,0,0,0,0,0,0],
			[0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
			[0,0,0,3,1,1,2,2,2,1,1,3,0,0,0,0],
			[0,0,0,0,1,2,2,2,2,2,1,0,0,0,0,0],
			[0,0,0,0,1,2,2,4,2,2,1,0,0,0,0,0],
			[0,0,0,0,1,2,2,2,2,2,1,0,0,0,0,0],
			[0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
			[0,0,0,0,0,0,5,0,5,0,0,0,0,0,0,0],
			[0,0,0,0,0,5,5,0,5,5,0,0,0,0,0,0],
			[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		],
	},
	"warrior": {
		"name": "Guerrier",
		"palette": [
			Color.TRANSPARENT,
			Color(0.45, 0.42, 0.38),              # 1 = armor
			Color(0.62, 0.58, 0.52),              # 2 = light armor
			Color(0.82, 0.68, 0.52),              # 3 = skin
			Color(0.72, 0.22, 0.18),              # 4 = red accent
			Color(0.18, 0.15, 0.12),              # 5 = shadow
		],
		"grid": [
			[0,0,0,0,0,0,1,1,1,0,0,0,0,0,0,0],
			[0,0,0,0,0,1,2,2,2,1,0,0,0,0,0,0],
			[0,0,0,0,0,1,3,3,3,1,0,0,0,0,0,0],
			[0,0,0,0,0,3,3,3,3,3,0,0,0,0,0,0],
			[0,0,0,0,3,5,3,3,5,3,0,0,0,0,0,0],
			[0,0,0,0,0,3,3,3,3,0,0,0,0,0,0,0],
			[0,0,0,0,0,0,3,3,3,0,0,0,0,0,0,0],
			[0,0,0,0,1,1,1,1,1,1,1,0,0,0,0,0],
			[0,0,0,1,2,1,2,2,2,1,2,1,0,0,0,0],
			[0,0,0,3,1,1,2,4,2,1,1,3,0,0,0,0],
			[0,0,0,0,1,2,2,2,2,2,1,0,0,0,0,0],
			[0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
			[0,0,0,0,0,1,5,0,5,1,0,0,0,0,0,0],
			[0,0,0,0,0,5,5,0,5,5,0,0,0,0,0,0],
			[0,0,0,0,5,5,0,0,0,5,5,0,0,0,0,0],
			[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		],
	},
	"bard": {
		"name": "Barde",
		"palette": [
			Color.TRANSPARENT,
			Color(0.52, 0.22, 0.42),              # 1 = purple robe
			Color(0.68, 0.38, 0.55),              # 2 = light purple
			Color(0.82, 0.72, 0.58),              # 3 = skin
			Color(0.82, 0.65, 0.22),              # 4 = gold (lyre)
			Color(0.18, 0.12, 0.15),              # 5 = shadow
		],
		"grid": [
			[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
			[0,0,0,0,0,0,4,4,4,0,0,0,0,0,0,0],
			[0,0,0,0,0,4,3,3,3,4,0,0,0,0,0,0],
			[0,0,0,0,0,3,3,3,3,3,0,0,0,0,0,0],
			[0,0,0,0,3,5,3,3,5,3,0,0,0,0,0,0],
			[0,0,0,0,0,3,3,3,3,3,0,0,0,0,0,0],
			[0,0,0,0,0,0,3,3,3,0,0,0,0,0,0,0],
			[0,0,0,0,0,1,1,1,1,1,0,0,0,0,0,0],
			[0,0,0,0,1,2,2,2,2,2,1,0,0,0,0,0],
			[0,0,0,3,1,2,2,2,2,2,1,3,0,0,0,0],
			[0,0,0,0,1,2,2,4,2,2,1,4,4,0,0,0],
			[0,0,0,0,1,2,2,2,2,2,1,4,4,0,0,0],
			[0,0,0,0,0,1,1,1,1,1,0,4,0,0,0,0],
			[0,0,0,0,0,0,5,0,5,0,0,0,0,0,0,0],
			[0,0,0,0,0,5,5,0,5,5,0,0,0,0,0,0],
			[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
		],
	},
}

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var pixel_size: float = DEFAULT_PIXEL_SIZE
var character_key: String = ""
var pixels: Array[ColorRect] = []
var assembled: bool = false


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func setup(char_key: String, px_size: float = DEFAULT_PIXEL_SIZE) -> void:
	## Configure the portrait for a specific character.
	character_key = char_key
	pixel_size = px_size
	custom_minimum_size = Vector2(GRID_SIZE * pixel_size, GRID_SIZE * pixel_size)
	size = custom_minimum_size


func assemble(instant: bool = false) -> void:
	## Play the cascade assembly animation (or set instantly).
	_clear_pixels()
	assembled = false

	var char_data: Dictionary = CHARACTERS.get(character_key, {})
	if char_data.is_empty():
		# Generate from name hash
		char_data = _generate_from_hash(character_key)

	var grid: Array = char_data.get("grid", [])
	var palette: Array = char_data.get("palette", [Color.TRANSPARENT, Color.WHITE])

	# Collect target positions
	var targets: Array[Dictionary] = []
	for row in range(mini(grid.size(), GRID_SIZE)):
		var row_data: Array = grid[row]
		for col in range(mini(row_data.size(), GRID_SIZE)):
			var color_idx: int = int(row_data[col])
			if color_idx <= 0 or color_idx >= palette.size():
				continue
			targets.append({
				"row": row, "col": col,
				"color": palette[color_idx],
				"pos": Vector2(col * pixel_size, row * pixel_size),
			})

	if instant:
		for t in targets:
			var px := ColorRect.new()
			px.size = Vector2(pixel_size, pixel_size)
			px.position = t.pos
			px.color = t.color
			px.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(px)
			pixels.append(px)
		assembled = true
		assembly_complete.emit()
		return

	# Shuffle for random arrival
	targets.shuffle()

	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		var target_pos: Vector2 = t.pos

		var px := ColorRect.new()
		px.size = Vector2(pixel_size, pixel_size)
		# Start from random position above
		px.position = Vector2(
			target_pos.x + randf_range(-20, 20),
			target_pos.y - randf_range(40, 100)
		)
		px.color = t.color
		px.modulate.a = 0.0
		px.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(px)
		pixels.append(px)

		# Cascade tween
		var tw := create_tween()
		tw.tween_property(px, "modulate:a", 1.0, 0.04)
		tw.parallel().tween_property(px, "position", target_pos, randf_range(0.15, 0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# Stagger: 4 pixels per batch
		if i % 4 == 3:
			await get_tree().create_timer(0.02).timeout

	assembled = true
	assembly_complete.emit()


func disassemble() -> void:
	## Scatter pixels outward and fade.
	for px in pixels:
		var tw := create_tween()
		var scatter := px.position + Vector2(randf_range(-30, 30), randf_range(-50, -10))
		tw.tween_property(px, "position", scatter, 0.3).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(px, "modulate:a", 0.0, 0.25)
	await get_tree().create_timer(0.35).timeout
	_clear_pixels()
	assembled = false


func _clear_pixels() -> void:
	for px in pixels:
		if is_instance_valid(px):
			px.queue_free()
	pixels.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# PROCEDURAL CHARACTER GENERATION (from name hash)
# ═══════════════════════════════════════════════════════════════════════════════

func _generate_from_hash(name_str: String) -> Dictionary:
	## Generate a unique character portrait from a name hash.
	## Creates a vertically-symmetric humanoid shape.
	var h := name_str.hash()

	# Generate palette from hash
	var hue := fmod(float(h & 0xFF) / 255.0, 1.0)
	var primary := Color.from_hsv(hue, 0.5, 0.4)
	var secondary := Color.from_hsv(hue, 0.4, 0.55)
	var accent := Color.from_hsv(fmod(hue + 0.15, 1.0), 0.6, 0.7)
	var skin := Color(0.82, 0.72, 0.58)
	var dark := Color(0.15, 0.12, 0.10)

	var palette := [Color.TRANSPARENT, primary, secondary, skin, accent, dark]

	# Generate symmetric 16x16 grid (humanoid template)
	var grid: Array = []
	for _r in range(GRID_SIZE):
		var row: Array = []
		for _c in range(GRID_SIZE):
			row.append(0)
		grid.append(row)

	# Head (rows 1-5, cols 5-10)
	for r in range(2, 6):
		for c in range(6, 10):
			grid[r][c] = 3  # skin

	# Eyes
	grid[3][7] = 5
	grid[3][9] = 5

	# Hair (from hash)
	var hair_style := (h >> 8) % 3
	if hair_style == 0:  # Short
		for c in range(6, 10):
			grid[1][c] = 4
	elif hair_style == 1:  # Medium
		for c in range(5, 11):
			grid[1][c] = 4
		grid[2][5] = 4
		grid[2][10] = 4
	else:  # Hat
		for c in range(5, 11):
			grid[0][c] = 1
			grid[1][c] = 1

	# Body (rows 7-12)
	for r in range(7, 13):
		var half_width: int = 2 + mini(r - 7, 3)
		for c in range(8 - half_width, 8 + half_width):
			if c >= 0 and c < GRID_SIZE:
				grid[r][c] = 1 if r < 9 else 2

	# Arms
	grid[8][4] = 3
	grid[8][11] = 3
	grid[9][4] = 3
	grid[9][11] = 3

	# Belt/accent
	for c in range(6, 10):
		grid[10][c] = 4

	# Legs (rows 13-14)
	grid[13][6] = 5
	grid[13][9] = 5
	grid[14][6] = 5
	grid[14][9] = 5

	return {"name": name_str, "palette": palette, "grid": grid}


# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY
# ═══════════════════════════════════════════════════════════════════════════════

static func get_character_name(key: String) -> String:
	var data: Dictionary = CHARACTERS.get(key, {})
	return data.get("name", key.capitalize())


static func resolve_character_key(speaker: String) -> String:
	## Map speaker names to character template keys.
	var lower := speaker.to_lower().strip_edges()
	if lower in ["merlin", "m.e.r.l.i.n.", "m.e.r.l.i.n"]:
		return "merlin"
	if lower in ["villageois", "paysan", "habitant", "villager"]:
		return "villager"
	if lower in ["druide", "druid", "sage"]:
		return "druid"
	if lower in ["guerrier", "warrior", "chevalier", "knight"]:
		return "warrior"
	if lower in ["barde", "bard", "poete", "conteur"]:
		return "bard"
	# Unknown: generate from hash
	return lower
