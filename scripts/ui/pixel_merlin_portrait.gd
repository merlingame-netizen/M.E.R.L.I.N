## PixelMerlinPortrait — Chunky pixel art Merlin bust (12x14 grid)
## Style: Reigns / retro pixel — bold colors, big pixels, simple shapes.
## Only head + hat + upper body. CeltOS cascade assembly animation.

class_name PixelMerlinPortrait
extends Control

signal assembly_complete
signal disassembly_complete

const GRID_W := 12
const GRID_H := 14
const DEFAULT_TARGET_SIZE := 192.0

# ═══════════════════════════════════════════════════════════════════
# PALETTE — Bold, flat, high-contrast (Reigns style)
# 0=empty 1=hat(blue) 2=skin(gray) 3=dark(brim) 4=robe(black)
# 5=robe_accent 6=crystal(gold) 7=beard 8=eyes(bright blue)
# ═══════════════════════════════════════════════════════════════════

var _palette: Array[Color] = [
	Color.TRANSPARENT,                     # 0 = empty
	Color(0.18, 0.28, 0.58),              # 1 = hat blue
	Color(0.62, 0.60, 0.56),              # 2 = skin gray
	Color(0.06, 0.05, 0.08),              # 3 = dark (brim, nose)
	Color(0.08, 0.07, 0.10),              # 4 = robe black
	Color(0.14, 0.13, 0.18),              # 5 = robe accent / collar
	Color(0.85, 0.65, 0.20),              # 6 = crystal gold
	Color(0.72, 0.70, 0.66),              # 7 = beard silver
	Color(0.30, 0.65, 1.0),               # 8 = eyes bright blue
]

const SEASON_CRYSTAL := {
	"hiver": Color(0.80, 0.70, 0.30),
	"printemps": Color(0.75, 0.80, 0.25),
	"ete": Color(0.90, 0.70, 0.15),
	"automne": Color(0.85, 0.55, 0.15),
}

# ═══════════════════════════════════════════════════════════════════
# 12x14 MERLIN BUST — Wizard hat + face + upper body
# ═══════════════════════════════════════════════════════════════════
#     Col: 0  1  2  3  4  5  6  7  8  9  10 11

const MERLIN_GRID := [
	# Row 0: Crystal at hat tip
	[0, 0, 0, 0, 0, 6, 6, 0, 0, 0, 0, 0],
	# Row 1: Hat tip
	[0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0],
	# Row 2: Hat wider
	[0, 0, 0, 1, 1, 1, 1, 1, 1, 0, 0, 0],
	# Row 3: Hat mid
	[0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0],
	# Row 4: Hat base
	[0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
	# Row 5: Brim (dark band)
	[3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3],
	# Row 6: Forehead
	[0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0],
	# Row 7: Eyes (2x1 bright blue blocks)
	[0, 2, 8, 8, 2, 2, 2, 8, 8, 2, 2, 0],
	# Row 8: Nose (single dark pixel)
	[0, 2, 2, 2, 2, 3, 2, 2, 2, 2, 2, 0],
	# Row 9: Beard top
	[0, 2, 7, 7, 7, 7, 7, 7, 7, 7, 2, 0],
	# Row 10: Beard bottom
	[0, 0, 7, 7, 7, 7, 7, 7, 7, 7, 0, 0],
	# Row 11: Collar
	[0, 0, 5, 5, 5, 5, 5, 5, 5, 5, 0, 0],
	# Row 12: Robe
	[0, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 0],
	# Row 13: Robe bottom + belt accent
	[4, 4, 4, 4, 4, 5, 5, 4, 4, 4, 4, 4],
]

# Eye pixel coordinates for blink
const EYE_COORDS := [
	[7, 2], [7, 3],   # left eye
	[7, 7], [7, 8],   # right eye
]

# Crystal pixel coordinates for glow
const CRYSTAL_COORDS := [[0, 5], [0, 6]]


# ═══════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════

var pixel_size: float = 14.0
var pixels: Array[ColorRect] = []
var _eye_pixels: Array[ColorRect] = []
var _crystal_pixels: Array[ColorRect] = []
var assembled: bool = false
var _idle_active: bool = false
var _container: Control
var _season: String = ""

# Idle animation state
var _blink_timer: float = 0.0
var _blink_interval: float = 3.5
var _is_blinking: bool = false
var _breathe_time: float = 0.0
var _glow_time: float = 0.0


# ═══════════════════════════════════════════════════════════════════
# SETUP
# ═══════════════════════════════════════════════════════════════════

func setup(target_size: float = DEFAULT_TARGET_SIZE, season: String = "") -> void:
	pixel_size = target_size / float(GRID_H)
	_season = season if not season.is_empty() else _detect_season()
	_apply_season()

	var display_w: float = GRID_W * pixel_size
	var display_h: float = GRID_H * pixel_size
	custom_minimum_size = Vector2(display_w, display_h)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_container = Control.new()
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_container)


func _detect_season() -> String:
	var m: int = Time.get_date_dict_from_system().month
	if m >= 3 and m <= 5: return "printemps"
	if m >= 6 and m <= 8: return "ete"
	if m >= 9 and m <= 11: return "automne"
	return "hiver"


func _apply_season() -> void:
	if SEASON_CRYSTAL.has(_season):
		_palette[6] = SEASON_CRYSTAL[_season]


func set_season(s: String) -> void:
	_season = s
	_apply_season()


# ═══════════════════════════════════════════════════════════════════
# ASSEMBLY — CeltOS cascade: each pixel falls from above
# ═══════════════════════════════════════════════════════════════════

func assemble(instant: bool = false) -> void:
	_clear_pixels()
	assembled = false
	_idle_active = false

	# Build lookup sets for eye/crystal tracking
	var eye_set := {}
	for coord in EYE_COORDS:
		eye_set[Vector2i(coord[0], coord[1])] = true
	var crystal_set := {}
	for coord in CRYSTAL_COORDS:
		crystal_set[Vector2i(coord[0], coord[1])] = true

	# Collect non-empty pixels
	var targets: Array[Dictionary] = []
	for row in range(GRID_H):
		var row_data: Array = MERLIN_GRID[row]
		for col in range(GRID_W):
			var color_idx: int = int(row_data[col])
			if color_idx <= 0 or color_idx >= _palette.size():
				continue
			var coord := Vector2i(row, col)
			targets.append({
				"row": row, "col": col,
				"color": _palette[color_idx],
				"pos": Vector2(col * pixel_size, row * pixel_size),
				"is_eye": eye_set.has(coord),
				"is_crystal": crystal_set.has(coord),
			})

	if instant:
		for t in targets:
			var px := _make_pixel(t)
			px.position = t.pos
			px.modulate.a = 1.0
		assembled = true
		_idle_active = true
		assembly_complete.emit()
		return

	# Shuffle for random arrival
	targets.shuffle()

	for i in range(targets.size()):
		var t: Dictionary = targets[i]
		var target_pos: Vector2 = t.pos

		var px := _make_pixel(t)
		# Start above with scatter
		px.position = Vector2(
			target_pos.x + randf_range(-30, 30),
			target_pos.y - randf_range(60, 160),
		)
		px.modulate.a = 0.0

		# Cascade tween — fall into place with bounce
		var tw := create_tween()
		tw.tween_property(px, "modulate:a", 1.0, 0.04)
		tw.parallel().tween_property(px, "position", target_pos, randf_range(0.15, 0.3)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

		# Stagger: 6 pixels per batch (~120 pixels total → ~0.4s)
		if i % 6 == 5:
			if not is_inside_tree():
				return
			await get_tree().create_timer(0.02).timeout

	assembled = true
	_idle_active = true
	assembly_complete.emit()


func _make_pixel(t: Dictionary) -> ColorRect:
	var px := ColorRect.new()
	px.size = Vector2(pixel_size, pixel_size)
	px.color = t.color
	px.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_child(px)
	pixels.append(px)

	if t.is_eye:
		_eye_pixels.append(px)
	if t.is_crystal:
		_crystal_pixels.append(px)

	return px


func disassemble() -> void:
	_idle_active = false
	for px in pixels:
		if not is_instance_valid(px):
			continue
		var scatter := px.position + Vector2(
			randf_range(-40, 40),
			randf_range(-60, -15),
		)
		var tw := create_tween()
		tw.tween_property(px, "position", scatter, 0.3).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(px, "modulate:a", 0.0, 0.25)

	var done_tw := create_tween()
	done_tw.tween_interval(0.4)
	done_tw.tween_callback(func():
		_clear_pixels()
		assembled = false
		disassembly_complete.emit()
	)


func _clear_pixels() -> void:
	for px in pixels:
		if is_instance_valid(px):
			px.queue_free()
	pixels.clear()
	_eye_pixels.clear()
	_crystal_pixels.clear()


# ═══════════════════════════════════════════════════════════════════
# IDLE ANIMATIONS — Breathe, Blink, Crystal Glow
# ═══════════════════════════════════════════════════════════════════

func _process(delta: float) -> void:
	if not _idle_active or not assembled:
		return

	# Breathing — gentle vertical oscillation
	_breathe_time += delta
	_container.position.y = sin(_breathe_time * 1.4) * 1.5

	# Crystal glow pulse
	_glow_time += delta
	for px in _crystal_pixels:
		if is_instance_valid(px):
			var g := 0.7 + sin(_glow_time * 3.0) * 0.3
			px.self_modulate = Color(g, g, g + 0.1)

	# Blink timer
	_blink_timer += delta
	if not _is_blinking and _blink_timer >= _blink_interval:
		_do_blink()
		_blink_timer = 0.0
		_blink_interval = randf_range(2.5, 5.0)


func _do_blink() -> void:
	_is_blinking = true
	for px in _eye_pixels:
		if is_instance_valid(px):
			px.self_modulate.a = 0.0
	if not is_inside_tree():
		_is_blinking = false
		return
	var tw := create_tween()
	tw.tween_interval(0.12)
	tw.tween_callback(func():
		for px in _eye_pixels:
			if is_instance_valid(px):
				px.self_modulate.a = 1.0
		_is_blinking = false
	)


# ═══════════════════════════════════════════════════════════════════
# MOOD
# ═══════════════════════════════════════════════════════════════════

func set_mood(mood: String) -> void:
	var tint: Color
	match mood:
		"amuse": tint = Color(1.05, 1.0, 0.95)
		"pensif": tint = Color(0.92, 0.92, 1.0)
		"serieux": tint = Color(0.88, 0.88, 0.95)
		"warm": tint = Color(1.0, 0.98, 0.92)
		_: tint = Color.WHITE
	if _container:
		_container.self_modulate = tint
