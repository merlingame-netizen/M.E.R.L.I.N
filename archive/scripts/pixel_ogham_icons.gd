## PixelOghamIcon — 16x16 pixel art Ogham rune icons (Parchemin+ palette)
## 18 runes, 6 categories, _draw() rendering, pulse glow animation
## Pixel art rules: 1px outline, max 5 colors, no orphan pixels, consistent style

class_name PixelOghamIcon
extends Control

signal reveal_complete

const GRID_SIZE := 16
const DEFAULT_TARGET_SIZE := 48.0

# ═══════════════════════════════════════════════════════════════════════════════
# CATEGORY PALETTES [transparent, outline, stem, accent, highlight]
# ═══════════════════════════════════════════════════════════════════════════════

const CATEGORY_PALETTES := {
	"reveal": [
		Color.TRANSPARENT, Color("#1a120e"),
		Color("#374351"), Color("#98aad8"), Color("#e3dbe0"),
	],
	"protection": [
		Color.TRANSPARENT, Color("#1a120e"),
		Color("#3f6f46"), Color("#5c947c"), Color("#8a9c6b"),
	],
	"boost": [
		Color.TRANSPARENT, Color("#1a120e"),
		Color("#785f39"), Color("#c49256"), Color("#d8ce98"),
	],
	"narrative": [
		Color.TRANSPARENT, Color("#1a120e"),
		Color("#2c1c22"), Color("#4c4651"), Color("#c0b8ad"),
	],
	"recovery": [
		Color.TRANSPARENT, Color("#1a120e"),
		Color("#53693d"), Color("#8a9c6b"), Color("#c0b8ad"),
	],
	"special": [
		Color.TRANSPARENT, Color("#1a120e"),
		Color("#552320"), Color("#944a42"), Color("#764535"),
	],
}

const OGHAM_CATEGORY := {
	"beith": "reveal", "coll": "reveal", "ailm": "reveal",
	"luis": "protection", "gort": "protection", "eadhadh": "protection",
	"duir": "boost", "tinne": "boost", "onn": "boost",
	"nuin": "narrative", "huath": "narrative", "straif": "narrative",
	"quert": "recovery", "ruis": "recovery", "saille": "recovery",
	"muin": "special", "ioho": "special", "ur": "special",
}

# ═══════════════════════════════════════════════════════════════════════════════
# 16x16 PIXEL ART GRIDS — hand-designed Ogham runes
# ═══════════════════════════════════════════════════════════════════════════════
# '0'=transparent '1'=outline '2'=stem '3'=accent '4'=highlight
# Each rune: vertical stem (cols 7-8) + category notches + tree motif at top

const OGHAM_GRIDS := {
	# ── REVEAL (blue) ──
	"beith": [  # Bouleau — 1 right stroke + birch leaf
		"0000000000000000",
		"0000000340000000",
		"0000003430000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221330000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	"coll": [  # Noisetier — 4 left strokes + hazelnut
		"0000000000000000",
		"0000000330000000",
		"0000000440000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	"ailm": [  # Sapin — 2 cross strokes + pine silhouette
		"0000000000000000",
		"0000000340000000",
		"0000003343000000",
		"0000033343300000",
		"0000001221000000",
		"0000001221000000",
		"0000331221330000",
		"0000001221000000",
		"0000001221000000",
		"0000331221330000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	# ── PROTECTION (green) ──
	"luis": [  # Sorbier — 2 right strokes + rowan berry
		"0000000000000000",
		"0000000343000000",
		"0000000434000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221330000",
		"0000001221000000",
		"0000001221000000",
		"0000001221330000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	"gort": [  # Lierre — 2 diagonal strokes + ivy leaf
		"0000000000000000",
		"0000003430000000",
		"0000034340000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000031221300000",
		"0000001221000000",
		"0000001221000000",
		"0000031221300000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	"eadhadh": [  # Tremble — 1 cross stroke + trembling leaf
		"0000000000000000",
		"0000004340000000",
		"0000003430000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000331221330000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	# ── BOOST (gold) ──
	"duir": [  # Chene — 2 left strokes + acorn
		"0000000000000000",
		"0000000330000000",
		"0000000440000000",
		"0000001221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	"tinne": [  # Houx — 3 left strokes + holly leaf/berry
		"0000000000000000",
		"0000003430000000",
		"0000030430000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	"onn": [  # Ajonc — 4 left strokes + thorny flower
		"0000000000000000",
		"0000000430000000",
		"0000003340000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	# ── NARRATIVE (stone/plum) ──
	"nuin": [  # Frene — 5 right strokes + ash key seed
		"0000000000000000",
		"0000000340000000",
		"0000000430000000",
		"0000001221000000",
		"0000001221330000",
		"0000001221330000",
		"0000001221000000",
		"0000001221330000",
		"0000001221000000",
		"0000001221330000",
		"0000001221000000",
		"0000001221330000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	"huath": [  # Aubepine — 1 left stroke + hawthorn blossom
		"0000000000000000",
		"0000003430000000",
		"0000003330000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	"straif": [  # Prunellier — 3 diagonal + dark thorns
		"0000000000000000",
		"0000003030000000",
		"0000000320000000",
		"0000001221000000",
		"0000001221000000",
		"0000031221300000",
		"0000001221000000",
		"0000001221000000",
		"0000031221300000",
		"0000001221000000",
		"0000001221000000",
		"0000031221300000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	# ── RECOVERY (sage/green) ──
	"quert": [  # Pommier — 5 left strokes + apple fruit
		"0000000000000000",
		"0000000340000000",
		"0000003443000000",
		"0000001221000000",
		"0000331221000000",
		"0000331221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000331221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	"ruis": [  # Sureau — 5 diagonal strokes + elder flower
		"0000000000000000",
		"0000004340000000",
		"0000003430000000",
		"0000001221000000",
		"0000031221300000",
		"0000031221300000",
		"0000001221000000",
		"0000031221300000",
		"0000001221000000",
		"0000031221300000",
		"0000001221000000",
		"0000031221300000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	"saille": [  # Saule — 2 cross strokes + drooping branches
		"0000000000000000",
		"0000030030300000",
		"0000003434000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000331221330000",
		"0000001221000000",
		"0000001221000000",
		"0000331221330000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	# ── SPECIAL (red/ember) ──
	"muin": [  # Vigne — 1 diagonal stroke + grape cluster
		"0000000000000000",
		"0000003330000000",
		"0000003430000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000031221300000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	"ioho": [  # If — 5 cross strokes + yew branch
		"0000000000000000",
		"0000003430000000",
		"0000003030000000",
		"0000001221000000",
		"0000331221330000",
		"0000001221000000",
		"0000331221330000",
		"0000001221000000",
		"0000331221330000",
		"0000001221000000",
		"0000331221330000",
		"0000001221000000",
		"0000331221330000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
	"ur": [  # Bruyere — 3 cross strokes + heather sprig
		"0000000000000000",
		"0000004340000000",
		"0000003340000000",
		"0000001221000000",
		"0000001221000000",
		"0000331221330000",
		"0000001221000000",
		"0000001221000000",
		"0000331221330000",
		"0000001221000000",
		"0000001221000000",
		"0000331221330000",
		"0000001221000000",
		"0000001111000000",
		"0000000000000000",
		"0000000000000000",
	],
}


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _ogham_key: String = ""
var _pixel_size: float = 3.0
var _palette: Array = []
var _positions := PackedVector2Array()
var _colors := PackedColorArray()
var _base_colors := PackedColorArray()

# Pulse glow animation
var _active: bool = false
var _pulse_time: float = 0.0
var _glow_alpha: float = 0.0

# Cascade reveal
var _revealing: bool = false
var _reveal_progress: float = 0.0
var _pixel_delays := PackedFloat32Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func setup(ogham_key: String, target_size: float = DEFAULT_TARGET_SIZE) -> void:
	_ogham_key = ogham_key
	_pixel_size = target_size / float(GRID_SIZE)
	custom_minimum_size = Vector2(target_size, target_size)
	size = custom_minimum_size

	var cat: String = OGHAM_CATEGORY.get(ogham_key, "reveal")
	_palette = CATEGORY_PALETTES.get(cat, CATEGORY_PALETTES["reveal"])

	_parse_grid(ogham_key)
	_build_pixel_data()
	queue_redraw()


func set_active(active: bool) -> void:
	_active = active
	_pulse_time = 0.0
	set_process(active or _revealing)
	queue_redraw()


func reveal(instant: bool = false) -> void:
	if instant:
		_revealing = false
		queue_redraw()
		reveal_complete.emit()
		return
	_revealing = true
	_reveal_progress = 0.0
	_pixel_delays.resize(_positions.size())
	for i in range(_positions.size()):
		_pixel_delays[i] = randf_range(0.0, 0.5)
	set_process(true)


func get_category() -> String:
	return OGHAM_CATEGORY.get(_ogham_key, "reveal")


static func get_available_oghams() -> Array[String]:
	var keys: Array[String] = []
	for k: String in OGHAM_GRIDS:
		keys.append(k)
	return keys


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNAL
# ═══════════════════════════════════════════════════════════════════════════════

func _parse_grid(ogham_key: String) -> void:
	var raw: Array = OGHAM_GRIDS.get(ogham_key, OGHAM_GRIDS["beith"])
	_positions = PackedVector2Array()
	_colors = PackedColorArray()
	_base_colors = PackedColorArray()

	for row_idx in range(raw.size()):
		var row_str: String = raw[row_idx]
		for col_idx in range(row_str.length()):
			var ch: int = row_str.unicode_at(col_idx) - 48  # '0'=0, '1'=1...
			if ch <= 0 or ch >= _palette.size():
				continue
			var px: float = col_idx * _pixel_size
			var py: float = row_idx * _pixel_size
			_positions.append(Vector2(px, py))
			var c: Color = _palette[ch]
			_colors.append(c)
			_base_colors.append(c)


func _build_pixel_data() -> void:
	pass  # Data built in _parse_grid


func _process(delta: float) -> void:
	if _active:
		_pulse_time += delta * 2.5
		var new_alpha: float = (sin(_pulse_time) + 1.0) * 0.3
		if absf(new_alpha - _glow_alpha) > 0.01:
			_glow_alpha = new_alpha
			_update_glow_colors()
			queue_redraw()

	if _revealing:
		_reveal_progress += delta * 2.0
		if _reveal_progress >= 1.5:
			_revealing = false
			set_process(_active)
			reveal_complete.emit()
		queue_redraw()


func _update_glow_colors() -> void:
	var highlight: Color = _palette[4] if _palette.size() > 4 else Color.WHITE
	for i in range(_colors.size()):
		var base: Color = _base_colors[i]
		_colors[i] = base.lerp(highlight, _glow_alpha)


func _draw() -> void:
	if _positions.is_empty():
		return

	var ps: float = _pixel_size
	var rect_size := Vector2(ps, ps)

	for i in range(_positions.size()):
		var alpha: float = 1.0
		if _revealing:
			var delay: float = _pixel_delays[i] if i < _pixel_delays.size() else 0.0
			var t: float = clampf((_reveal_progress - delay) / 0.5, 0.0, 1.0)
			alpha = t
			if t <= 0.0:
				continue

		var c: Color = _colors[i]
		if alpha < 1.0:
			c.a = alpha
		draw_rect(Rect2(_positions[i], rect_size), c)
