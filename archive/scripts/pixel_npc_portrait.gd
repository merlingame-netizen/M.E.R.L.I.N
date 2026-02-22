## ═══════════════════════════════════════════════════════════════════════════════
## PixelNpcPortrait — 32x32 pixel art NPC portraits (Parchemin+ palette)
## ═══════════════════════════════════════════════════════════════════════════════
## 8 archetypes: villageois, druide, guerrier, barde, marchand, ermite, noble, sorciere
## Pixel art rules: 1px outline, max 7 colors, no jaggies, consistent light source (top-left)
## Animation: eye blink + breathing bob
## Rendering: _draw() with packed arrays for 9000+ pixel performance
## ═══════════════════════════════════════════════════════════════════════════════

class_name PixelNpcPortrait
extends Control

signal assembly_complete
signal disassembly_complete

const GRID_SIZE := 32
const DEFAULT_TARGET_SIZE := 128.0

# ═══════════════════════════════════════════════════════════════════════════════
# NPC PALETTES (from PARCHMENT_PLUS / JUGDRAL21)
# ═══════════════════════════════════════════════════════════════════════════════
# Each palette: [transparent, outline, primary, secondary, skin, accent, highlight]

const NPC_PALETTES := {
	"villageois": [
		Color.TRANSPARENT,
		Color("#1a120e"),  # 1: outline (deep_bark)
		Color("#764535"),  # 2: tunic (rust)
		Color("#c49256"),  # 3: belt/gold (honey)
		Color("#a88d7b"),  # 4: skin (sand)
		Color("#552320"),  # 5: hair (blood)
		Color("#c0b8ad"),  # 6: shirt (parchment)
	],
	"druide": [
		Color.TRANSPARENT,
		Color("#1a120e"),  # 1: outline
		Color("#3f6f46"),  # 2: robe (forest)
		Color("#53693d"),  # 3: robe detail (leaf)
		Color("#a88d7b"),  # 4: skin (sand)
		Color("#5c947c"),  # 5: mistletoe (jade)
		Color("#c0b8ad"),  # 6: beard (parchment)
	],
	"guerrier": [
		Color.TRANSPARENT,
		Color("#1a120e"),  # 1: outline
		Color("#4c4651"),  # 2: armor (stone)
		Color("#363339"),  # 3: dark armor (slate)
		Color("#a88d7b"),  # 4: skin (sand)
		Color("#944a42"),  # 5: crest/accent (ember)
		Color("#785f39"),  # 6: chainmail (bronze)
	],
	"barde": [
		Color.TRANSPARENT,
		Color("#1a120e"),  # 1: outline
		Color("#2c1c22"),  # 2: robe (shadow_plum)
		Color("#374351"),  # 3: cloak (storm)
		Color("#a88d7b"),  # 4: skin (sand)
		Color("#98aad8"),  # 5: feather/accent (sky_wash)
		Color("#c49256"),  # 6: lyre (honey)
	],
	"marchand": [
		Color.TRANSPARENT,
		Color("#1a120e"),  # 1: outline
		Color("#785f39"),  # 2: apron (bronze)
		Color("#c49256"),  # 3: gold/coins (honey)
		Color("#e3dbe0"),  # 4: skin light (cloud)
		Color("#d8ce98"),  # 5: coins bright (wheat)
		Color("#764535"),  # 6: vest (rust)
	],
	"ermite": [
		Color.TRANSPARENT,
		Color("#1a120e"),  # 1: outline
		Color("#4c4651"),  # 2: cloak (stone)
		Color("#363339"),  # 3: cloak dark (slate)
		Color("#a88d7b"),  # 4: skin (sand)
		Color("#98aad8"),  # 5: lantern (sky_wash)
		Color("#c0b8ad"),  # 6: beard (parchment)
	],
	"noble": [
		Color.TRANSPARENT,
		Color("#1a120e"),  # 1: outline
		Color("#212a64"),  # 2: garment (deep_blue)
		Color("#374351"),  # 3: dark trim (storm)
		Color("#e3dbe0"),  # 4: skin pale (cloud)
		Color("#c49256"),  # 5: crown (honey)
		Color("#d8ce98"),  # 6: ermine/gold (wheat)
	],
	"sorciere": [
		Color.TRANSPARENT,
		Color("#1a120e"),  # 1: outline
		Color("#2c1c22"),  # 2: robe (shadow_plum)
		Color("#552320"),  # 3: robe dark (blood)
		Color("#c0b8ad"),  # 4: skin pale (parchment)
		Color("#5c947c"),  # 5: magic eye (jade)
		Color("#944a42"),  # 6: runes (ember)
	],
}


# ═══════════════════════════════════════════════════════════════════════════════
# 32x32 PIXEL ART GRIDS — hand-designed, pixel by pixel
# ═══════════════════════════════════════════════════════════════════════════════
# Format: PackedStringArray, each string = 32 chars, each char = palette index
# '0' = transparent, '1'-'6' = palette colors
# Rules: 1px outline (#1), no orphan pixels, top-left light source

const NPC_GRIDS := {
	"villageois": [
		#--- col ruler: 0----5----0----5----0----5----0-
		"00000000000000000000000000000000",  # 00
		"00000000000000000000000000000000",  # 01
		"00000000000011111100000000000000",  # 02 hair top
		"00000000001555555510000000000000",  # 03
		"00000000015555555551000000000000",  # 04
		"00000000155555555555100000000000",  # 05
		"00000000155544444555100000000000",  # 06 forehead
		"00000000154444444445100000000000",  # 07
		"00000000154444444445100000000000",  # 08
		"00000000154414441445100000000000",  # 09 eyes (1s at 12,16)
		"00000000154444444445100000000000",  # 10
		"00000000154444144445100000000000",  # 11 nose
		"00000000154444444445100000000000",  # 12
		"00000000015444144451000000000000",  # 13 mouth
		"00000000001544444510000000000000",  # 14 chin
		"00000000000154445100000000000000",  # 15 jawline
		"00000000000014441000000000000000",  # 16 neck
		"00000000000014441000000000000000",  # 17 neck
		"00000000001122221100000000000000",  # 18 shoulders
		"00000000012222222210000000000000",  # 19
		"00000000122266662222100000000000",  # 20 tunic + shirt
		"00000000122266662222100000000000",  # 21
		"00000000122266662222100000000000",  # 22
		"00000000122233332222100000000000",  # 23 belt
		"00000000122222222222100000000000",  # 24
		"00000000122222222222100000000000",  # 25
		"00000000012222222221000000000000",  # 26
		"00000000012222222221000000000000",  # 27
		"00000000001111111110000000000000",  # 28 bottom outline
		"00000000000000000000000000000000",  # 29
		"00000000000000000000000000000000",  # 30
		"00000000000000000000000000000000",  # 31
	],
	"druide": [
		"00000000000000000000000000000000",  # 00
		"00000000000000000000000000000000",  # 01
		"00000000000001551000000000000000",  # 02 leaf crown
		"00000000000015225100000000000000",  # 03
		"00000000000155225510000000000000",  # 04 hood top
		"00000000001222222221000000000000",  # 05 hood
		"00000000012222222222100000000000",  # 06
		"00000000012244444222100000000000",  # 07 face in hood
		"00000000012244444422100000000000",  # 08
		"00000000012241444142100000000000",  # 09 eyes
		"00000000012244444422100000000000",  # 10
		"00000000012244414422100000000000",  # 11 nose
		"00000000012244444422100000000000",  # 12
		"00000000001266666621000000000000",  # 13 beard starts
		"00000000001266666621000000000000",  # 14 beard
		"00000000000166666610000000000000",  # 15 beard
		"00000000000016661000000000000000",  # 16 beard tip
		"00000000000012221000000000000000",  # 17 neck/robe
		"00000000001222222210000000000000",  # 18 shoulders
		"00000000012222522222100000000000",  # 19 robe + mistletoe
		"00000000122225522222210000000000",  # 20
		"00000000122222222222210000000000",  # 21
		"00000000122223322222210000000000",  # 22 rope belt
		"00000000122222222222210000000000",  # 23
		"00000001222222222222221000000000",  # 24 robe wide
		"00000001222222222222221000000000",  # 25
		"00000012222222222222222100000000",  # 26 robe bottom
		"00000012222222222222222100000000",  # 27
		"00000011111111111111111100000000",  # 28
		"00000000000000000000000000000000",  # 29
		"00000000000000000000000000000000",  # 30
		"00000000000000000000000000000000",  # 31
	],
	"guerrier": [
		"00000000000000000000000000000000",  # 00
		"00000000000001111000000000000000",  # 01 helmet crest
		"00000000000115555110000000000000",  # 02 helmet crest
		"00000000001222222221000000000000",  # 03 helmet
		"00000000012222222222100000000000",  # 04
		"00000000012233333222100000000000",  # 05 visor slit
		"00000000012244344422100000000000",  # 06 face visible
		"00000000012244444422100000000000",  # 07
		"00000000012241444142100000000000",  # 08 eyes
		"00000000012244444422100000000000",  # 09
		"00000000012244414422100000000000",  # 10 nose
		"00000000012244444422100000000000",  # 11
		"00000000001244444421000000000000",  # 12 chin guard
		"00000000001233333321000000000000",  # 13 gorget
		"00000000000122222210000000000000",  # 14 neck
		"00000000001222222221000000000000",  # 15 shoulders
		"00000000012266666222100000000000",  # 16 pauldrons
		"00000000122266666222210000000000",  # 17 broad shoulders
		"00000000122226662222210000000000",  # 18 chest plate
		"00000000122226662222210000000000",  # 19
		"00000000122225552222210000000000",  # 20 center emblem
		"00000000122222222222210000000000",  # 21
		"00000000122233332222210000000000",  # 22 belt
		"00000000122222222222210000000000",  # 23
		"00000000122222222222210000000000",  # 24
		"00000000012222222222100000000000",  # 25
		"00000000012222222222100000000000",  # 26
		"00000000001222222221000000000000",  # 27
		"00000000001111111111000000000000",  # 28
		"00000000000000000000000000000000",  # 29
		"00000000000000000000000000000000",  # 30
		"00000000000000000000000000000000",  # 31
	],
	"barde": [
		"00000000000000000000000000000000",  # 00
		"00000000000000050000000000000000",  # 01 feather tip
		"00000000000001550000000000000000",  # 02 feather
		"00000000000113331100000000000000",  # 03 beret
		"00000000001333333310000000000000",  # 04
		"00000000013333333331000000000000",  # 05
		"00000000013344444331000000000000",  # 06 forehead
		"00000000013444444433100000000000",  # 07
		"00000000013444444443100000000000",  # 08
		"00000000013441444143100000000000",  # 09 eyes
		"00000000013444444443100000000000",  # 10
		"00000000013444414443100000000000",  # 11 nose
		"00000000013444444443100000000000",  # 12
		"00000000001344414431000000000000",  # 13 mouth
		"00000000000134444310000000000000",  # 14 chin
		"00000000000013443100000000000000",  # 15
		"00000000000013431000000000000000",  # 16 neck
		"00000000000012221000000000000000",  # 17
		"00000000001222222210000000000000",  # 18 shoulders
		"00000000012222222222100000000000",  # 19 cloak
		"00000000022222222222200000000000",  # 20
		"00000000022222222222206000000000",  # 21 lyre starts
		"00000000022222222222066000000000",  # 22
		"00000000022223322222066000000000",  # 23 sash
		"00000000022222222222060000000000",  # 24
		"00000000012222222222100000000000",  # 25
		"00000000012222222222100000000000",  # 26
		"00000000001222222221000000000000",  # 27
		"00000000001111111111000000000000",  # 28
		"00000000000000000000000000000000",  # 29
		"00000000000000000000000000000000",  # 30
		"00000000000000000000000000000000",  # 31
	],
	"marchand": [
		"00000000000000000000000000000000",  # 00
		"00000000000000000000000000000000",  # 01
		"00000000000011111100000000000000",  # 02 bald head top
		"00000000001144444411000000000000",  # 03
		"00000000014444444444100000000000",  # 04
		"00000000014444444444100000000000",  # 05
		"00000000014444444444100000000000",  # 06
		"00000000014441444144100000000000",  # 07 eyes
		"00000000014444444444100000000000",  # 08
		"00000000014444414444100000000000",  # 09 nose (big)
		"00000000014444414444100000000000",  # 10
		"00000000014444444444100000000000",  # 11
		"00000000001444144410000000000000",  # 12 mouth (smile)
		"00000000001144444411000000000000",  # 13 round chin
		"00000000000114444110000000000000",  # 14 double chin
		"00000000000014441000000000000000",  # 15 neck (thick)
		"00000000000014441000000000000000",  # 16
		"00000000001222222210000000000000",  # 17 shoulders
		"00000000012222222222100000000000",  # 18
		"00000001222266662222221000000000",  # 19 wide apron
		"00000001222266662222221000000000",  # 20
		"00000001222266662222221000000000",  # 21
		"00000001222233332222221000000000",  # 22 belt
		"00000001222222222222221000000000",  # 23 round belly
		"00000001222222522222221000000000",  # 24 coin pouch
		"00000001222225552222221000000000",  # 25
		"00000000122222222222210000000000",  # 26
		"00000000012222222222100000000000",  # 27
		"00000000011111111111100000000000",  # 28
		"00000000000000000000000000000000",  # 29
		"00000000000000000000000000000000",  # 30
		"00000000000000000000000000000000",  # 31
	],
	"ermite": [
		"00000000000000000000000000000000",  # 00
		"00000000000000000000000000000000",  # 01
		"00000000000122222100000000000000",  # 02 hood top
		"00000000001222222210000000000000",  # 03
		"00000000012222222221000000000000",  # 04
		"00000000012233332221000000000000",  # 05 hood shadow
		"00000000012344443221000000000000",  # 06 face in shadow
		"00000000012344443221000000000000",  # 07
		"00000000012341443121000000000000",  # 08 eyes (one bright)
		"00000000012344443221000000000000",  # 09
		"00000000012344143221000000000000",  # 10 nose
		"00000000012344443221000000000000",  # 11
		"00000000001266662210000000000000",  # 12 beard
		"00000000001266666210000000000000",  # 13
		"00000000000166666100000000000000",  # 14 long beard
		"00000000000016666100000000000000",  # 15
		"00000000000001661000000000000000",  # 16 beard tip
		"00000000000012221000000000000000",  # 17 robe
		"00000000001222222100000000000000",  # 18 hunched
		"00000000012222222210000000000000",  # 19
		"00000000022222222220000000000000",  # 20
		"00000000022222222220050000000000",  # 21 lantern glow
		"00000000022222222220555000000000",  # 22 lantern
		"00000000022233322220050000000000",  # 23 rope belt
		"00000000022222222220000000000000",  # 24
		"00000000122222222222100000000000",  # 25
		"00000001222222222222210000000000",  # 26
		"00000001222222222222210000000000",  # 27
		"00000001111111111111110000000000",  # 28
		"00000000000000000000000000000000",  # 29
		"00000000000000000000000000000000",  # 30
		"00000000000000000000000000000000",  # 31
	],
	"noble": [
		"00000000000000000000000000000000",  # 00
		"00000000000005550000000000000000",  # 01 crown jewel
		"00000000000155555100000000000000",  # 02 crown
		"00000000001565656510000000000000",  # 03 crown gems
		"00000000015555555551000000000000",  # 04
		"00000000014444444441000000000000",  # 05 forehead
		"00000000014444444444100000000000",  # 06
		"00000000014444444444100000000000",  # 07
		"00000000014441444144100000000000",  # 08 eyes
		"00000000014444444444100000000000",  # 09
		"00000000014444414444100000000000",  # 10 nose (thin)
		"00000000014444444444100000000000",  # 11
		"00000000001444414441000000000000",  # 12 mouth
		"00000000001144444411000000000000",  # 13 jaw
		"00000000000114444110000000000000",  # 14 chin
		"00000000000014441000000000000000",  # 15 neck
		"00000000000012221000000000000000",  # 16
		"00000000001222222210000000000000",  # 17 shoulders
		"00000000312222222221300000000000",  # 18 cape drape
		"00000003312266662213300000000000",  # 19
		"00000033122266662222133000000000",  # 20 rich garment
		"00000033122266662222133000000000",  # 21
		"00000033122255552222133000000000",  # 22 gold trim
		"00000003312222222221330000000000",  # 23
		"00000003312222222221330000000000",  # 24
		"00000000312222222221300000000000",  # 25 cape ends
		"00000000012222222222100000000000",  # 26
		"00000000012222222222100000000000",  # 27
		"00000000001111111111000000000000",  # 28
		"00000000000000000000000000000000",  # 29
		"00000000000000000000000000000000",  # 30
		"00000000000000000000000000000000",  # 31
	],
	"sorciere": [
		"00000000000000100000000000000000",  # 00 hat tip
		"00000000000001210000000000000000",  # 01
		"00000000000012221000000000000000",  # 02 hat
		"00000000000122222100000000000000",  # 03
		"00000000001222222210000000000000",  # 04
		"00000000012222222221000000000000",  # 05
		"00000000122222222222100000000000",  # 06 hat brim
		"00000001133333333331100000000000",  # 07 brim wide
		"00000000014444444441000000000000",  # 08 face
		"00000000014444444444100000000000",  # 09
		"00000000014451444144100000000000",  # 10 eyes (5=green eye)
		"00000000014444444444100000000000",  # 11
		"00000000014444414444100000000000",  # 12 nose
		"00000000014444444444100000000000",  # 13
		"00000000001444414441000000000000",  # 14 mouth
		"00000000000144444410000000000000",  # 15 chin
		"00000000000014441000000000000000",  # 16 neck
		"00000000000012221000000000000000",  # 17
		"00000000001222222210000000000000",  # 18 shoulders
		"00000000012222222222100000000000",  # 19 dark robe
		"00000000022222622222200000000000",  # 20 rune glow
		"00000000022226662222200000000000",  # 21
		"00000000022222622222200000000000",  # 22
		"00000000022222222222200000000000",  # 23
		"00000000022233322222200000000000",  # 24 sash
		"00000000122222222222210000000000",  # 25 robe widens
		"00000001222222222222221000000000",  # 26
		"00000001222222222222221000000000",  # 27
		"00000001111111111111111000000000",  # 28
		"00000000000000000000000000000000",  # 29
		"00000000000000000000000000000000",  # 30
		"00000000000000000000000000000000",  # 31
	],
}

# Eye positions per NPC (row, col pairs) for blink animation
const NPC_EYE_POSITIONS := {
	"villageois": [Vector2i(9, 12), Vector2i(9, 16)],
	"druide":     [Vector2i(9, 12), Vector2i(9, 16)],
	"guerrier":   [Vector2i(8, 12), Vector2i(8, 16)],
	"barde":      [Vector2i(9, 12), Vector2i(9, 16)],
	"marchand":   [Vector2i(7, 12), Vector2i(7, 16)],
	"ermite":     [Vector2i(8, 12), Vector2i(8, 16)],
	"noble":      [Vector2i(8, 12), Vector2i(8, 16)],
	"sorciere":   [Vector2i(10, 12), Vector2i(10, 16)],
}


# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _npc_key: String = ""
var _pixel_size: float = 4.0
var _grid: Array = []        # Parsed 2D int array
var _palette: Array = []     # Color array
var _eye_positions: Array[Vector2i] = []

# Pixel data (packed for _draw performance)
var _positions := PackedVector2Array()
var _colors := PackedColorArray()
var _base_colors := PackedColorArray()  # Stored for blink restore
var _eye_indices: Array[int] = []       # Indices into _positions/_colors for eyes

# Animation state
var _assembled: bool = false
var _blink_timer: float = 3.0
var _blink_duration: float = 0.0
var _bob_time: float = 0.0
var _bob_offset: float = 0.0

# Assembly animation
var _assembling: bool = false
var _assembly_progress: float = 0.0
var _pixel_delays := PackedFloat32Array()
var _pixel_targets := PackedVector2Array()
var _pixel_start_positions := PackedVector2Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# ═══════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════════════════════

func setup(npc_key: String, target_size: float = DEFAULT_TARGET_SIZE) -> void:
	_npc_key = npc_key
	_pixel_size = target_size / float(GRID_SIZE)
	custom_minimum_size = Vector2(target_size, target_size)
	size = custom_minimum_size

	_palette = NPC_PALETTES.get(npc_key, NPC_PALETTES["villageois"])
	_eye_positions = []
	var eye_pos_raw: Array = NPC_EYE_POSITIONS.get(npc_key, [])
	for ep in eye_pos_raw:
		_eye_positions.append(ep as Vector2i)

	_parse_grid(npc_key)
	_build_pixel_data()


func assemble(instant: bool = false) -> void:
	if instant:
		_assembled = true
		_assembling = false
		_blink_timer = randf_range(2.0, 5.0)
		_bob_time = randf_range(0.0, TAU)
		queue_redraw()
		assembly_complete.emit()
		return

	_assembled = false
	_assembling = true
	_assembly_progress = 0.0

	# Compute random start positions and staggered delays
	_pixel_start_positions.resize(_positions.size())
	_pixel_delays.resize(_positions.size())
	_pixel_targets = _positions.duplicate()

	# Shuffle order via random delays
	for i in range(_positions.size()):
		_pixel_start_positions[i] = Vector2(
			_positions[i].x + randf_range(-30.0, 30.0),
			_positions[i].y - randf_range(50.0, 120.0)
		)
		_pixel_delays[i] = randf_range(0.0, 0.6)

	_blink_timer = randf_range(2.0, 5.0)
	_bob_time = 0.0
	queue_redraw()


func disassemble() -> void:
	if not _assembled:
		return
	_assembled = false
	_assembling = true
	_assembly_progress = 1.0

	# Reverse: scatter outward
	_pixel_start_positions = _positions.duplicate()
	_pixel_targets.resize(_positions.size())
	_pixel_delays.resize(_positions.size())

	for i in range(_positions.size()):
		_pixel_targets[i] = Vector2(
			_positions[i].x + randf_range(-40.0, 40.0),
			_positions[i].y - randf_range(30.0, 80.0)
		)
		_pixel_delays[i] = randf_range(0.0, 0.4)

	var tw := create_tween()
	tw.tween_method(_set_disassembly_progress, 0.0, 1.0, 0.5).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void:
		_assembling = false
		disassembly_complete.emit()
	)


func get_npc_key() -> String:
	return _npc_key


# ═══════════════════════════════════════════════════════════════════════════════
# INTERNALS
# ═══════════════════════════════════════════════════════════════════════════════

func _parse_grid(npc_key: String) -> void:
	_grid.clear()
	var string_grid: Array = NPC_GRIDS.get(npc_key, [])
	if string_grid.is_empty():
		return
	for row_str: String in string_grid:
		var row: Array[int] = []
		for i: int in range(mini(row_str.length(), GRID_SIZE)):
			var c: int = row_str.unicode_at(i) - 48  # '0'=0, '1'=1, etc.
			row.append(clampi(c, 0, 9))
		# Pad to GRID_SIZE if shorter
		while row.size() < GRID_SIZE:
			row.append(0)
		_grid.append(row)
	# Pad rows
	while _grid.size() < GRID_SIZE:
		var empty_row: Array[int] = []
		empty_row.resize(GRID_SIZE)
		_grid.append(empty_row)


func _build_pixel_data() -> void:
	_positions.clear()
	_colors.clear()
	_base_colors.clear()
	_eye_indices.clear()

	for row: int in range(GRID_SIZE):
		for col: int in range(GRID_SIZE):
			var idx: int = _grid[row][col]
			if idx <= 0 or idx >= _palette.size():
				continue
			_positions.append(Vector2(col * _pixel_size, row * _pixel_size))
			var color: Color = _palette[idx]
			_colors.append(color)
			_base_colors.append(color)

			# Track eye pixels
			for eye_pos: Vector2i in _eye_positions:
				if eye_pos.x == row and eye_pos.y == col:
					_eye_indices.append(_positions.size() - 1)


func _process(delta: float) -> void:
	if _assembling and not _assembled:
		_assembly_progress += delta * 2.0  # ~0.5s total
		if _assembly_progress >= 1.0:
			_assembly_progress = 1.0
			_assembling = false
			_assembled = true
			assembly_complete.emit()
		queue_redraw()
		return

	if not _assembled:
		return

	# Breathing bob
	_bob_time += delta
	var new_bob: float = sin(_bob_time * 1.8) * 1.2
	if not is_equal_approx(_bob_offset, new_bob):
		_bob_offset = new_bob
		queue_redraw()

	# Eye blink
	_blink_timer -= delta
	if _blink_duration > 0.0:
		_blink_duration -= delta
		if _blink_duration <= 0.0:
			# Restore eye colors
			for eye_idx: int in _eye_indices:
				if eye_idx < _colors.size():
					_colors[eye_idx] = _base_colors[eye_idx]
			queue_redraw()
	elif _blink_timer <= 0.0:
		_blink_duration = 0.12
		_blink_timer = randf_range(2.5, 5.5)
		# Dim eye colors
		for eye_idx: int in _eye_indices:
			if eye_idx < _colors.size():
				var skin_color: Color = _palette[4] if _palette.size() > 4 else Color(0.7, 0.6, 0.5)
				_colors[eye_idx] = skin_color
		queue_redraw()


func _draw() -> void:
	if _positions.is_empty():
		return

	var ps: float = _pixel_size

	if _assembling and not _assembled:
		# Assembly animation: interpolate positions
		for i: int in range(_positions.size()):
			var delay: float = _pixel_delays[i] if i < _pixel_delays.size() else 0.0
			var t: float = clampf((_assembly_progress - delay) / maxf(1.0 - delay, 0.01), 0.0, 1.0)
			# Back ease out
			var ease_t: float = 1.0 + 2.70158 * pow(t - 1.0, 3.0) + 1.70158 * pow(t - 1.0, 2.0)
			ease_t = clampf(ease_t, 0.0, 1.5)
			var start_pos: Vector2 = _pixel_start_positions[i] if i < _pixel_start_positions.size() else _positions[i]
			var target_pos: Vector2 = _pixel_targets[i] if i < _pixel_targets.size() else _positions[i]
			var pos: Vector2 = start_pos.lerp(target_pos, ease_t)
			var alpha: float = clampf(t * 3.0, 0.0, 1.0)
			var color: Color = _colors[i]
			draw_rect(Rect2(pos, Vector2(ps, ps)), Color(color.r, color.g, color.b, alpha))
		return

	if not _assembled:
		return

	# Normal rendering with breathing bob
	for i: int in range(_positions.size()):
		var pos: Vector2 = _positions[i] + Vector2(0.0, _bob_offset)
		draw_rect(Rect2(pos, Vector2(ps, ps)), _colors[i])


func _set_disassembly_progress(progress: float) -> void:
	_assembly_progress = 1.0 - progress
	queue_redraw()


# ═══════════════════════════════════════════════════════════════════════════════
# UTILITY
# ═══════════════════════════════════════════════════════════════════════════════

static func get_available_npcs() -> PackedStringArray:
	return PackedStringArray(NPC_GRIDS.keys())


static func get_npc_display_name(key: String) -> String:
	var names := {
		"villageois": "Villageois",
		"druide": "Druide",
		"guerrier": "Guerrier",
		"barde": "Barde",
		"marchand": "Marchand",
		"ermite": "Ermite",
		"noble": "Noble",
		"sorciere": "Sorciere",
	}
	return names.get(key, key.capitalize())


## Resolve a speaker string to an NPC archetype key (or "" if not an NPC).
static func resolve_npc_key(speaker: String) -> String:
	if speaker.is_empty():
		return ""
	var lower := speaker.to_lower()
	# Direct match first
	if NPC_GRIDS.has(lower):
		return lower
	# Keyword-based matching
	var keywords := {
		"villageois": "villageois", "paysan": "villageois", "fermier": "villageois",
		"druide": "druide", "sage": "druide", "druidesse": "druide",
		"guerrier": "guerrier", "soldat": "guerrier", "chevalier": "guerrier",
		"barde": "barde", "poete": "barde", "musicien": "barde",
		"marchand": "marchand", "commercant": "marchand", "artisan": "marchand",
		"ermite": "ermite", "hermite": "ermite", "ancien": "ermite",
		"noble": "noble", "roi": "noble", "reine": "noble", "seigneur": "noble",
		"sorciere": "sorciere", "sorcier": "sorciere", "enchanteresse": "sorciere",
	}
	for keyword: String in keywords:
		if lower.find(keyword) >= 0:
			return keywords[keyword]
	return ""
