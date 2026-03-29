extends SubViewport
## TapestryTalentTree — Draws the Ogham talent tree on a tapestry texture.
## Progressive reveal: only unlocked talents are visible.
## Rendered to texture, displayed on a Quad3D in the cabin.

class_name TapestryTalentTree

const TREE_SIZE := Vector2i(512, 384)
const NODE_RADIUS: float = 16.0
const LINE_WIDTH: float = 2.0

# Ogham tree layout — 3 branches from center
# Central: Beith(starter) → Coll → Ailm
# Left:    Luis(starter) → Gort → Eadhadh → Nuin → Huath → Straif
# Right:   Quert(starter) → Duir → Tinne → Onn → Ruis → Saille
# Special: Muin, Ioho, Ur (bottom)

const TREE_NODES: Array[Dictionary] = [
	# Starters (tier 0, always visible)
	{"key": "beith", "name": "Bouleau", "rune": "\u1681", "pos": Vector2(256, 50), "tier": 0, "unlocked": true},
	{"key": "luis", "name": "Sorbier", "rune": "\u1684", "pos": Vector2(120, 90), "tier": 0, "unlocked": true},
	{"key": "quert", "name": "Pommier", "rune": "\u168D", "pos": Vector2(392, 90), "tier": 0, "unlocked": true},
	# Central branch
	{"key": "coll", "name": "Noisetier", "rune": "\u1682", "pos": Vector2(256, 120), "tier": 1, "unlocked": false},
	{"key": "ailm", "name": "Sapin", "rune": "\u1683", "pos": Vector2(256, 190), "tier": 2, "unlocked": false},
	# Left branch (Protection/Narratif)
	{"key": "gort", "name": "Lierre", "rune": "\u1685", "pos": Vector2(80, 150), "tier": 1, "unlocked": false},
	{"key": "eadhadh", "name": "Tremble", "rune": "\u1686", "pos": Vector2(50, 210), "tier": 2, "unlocked": false},
	{"key": "nuin", "name": "Frene", "rune": "\u168A", "pos": Vector2(80, 270), "tier": 3, "unlocked": false},
	{"key": "huath", "name": "Aubepine", "rune": "\u168B", "pos": Vector2(120, 320), "tier": 3, "unlocked": false},
	{"key": "straif", "name": "Prunellier", "rune": "\u168C", "pos": Vector2(160, 360), "tier": 4, "unlocked": false},
	# Right branch (Boost/Recovery)
	{"key": "duir", "name": "Chene", "rune": "\u1687", "pos": Vector2(430, 150), "tier": 1, "unlocked": false},
	{"key": "tinne", "name": "Houx", "rune": "\u1688", "pos": Vector2(460, 210), "tier": 2, "unlocked": false},
	{"key": "onn", "name": "Ajonc", "rune": "\u1689", "pos": Vector2(430, 270), "tier": 3, "unlocked": false},
	{"key": "ruis", "name": "Sureau", "rune": "\u168E", "pos": Vector2(392, 320), "tier": 3, "unlocked": false},
	{"key": "saille", "name": "Saule", "rune": "\u168F", "pos": Vector2(350, 360), "tier": 4, "unlocked": false},
	# Special (bottom center)
	{"key": "muin", "name": "Vigne", "rune": "\u1690", "pos": Vector2(200, 360), "tier": 4, "unlocked": false},
	{"key": "ioho", "name": "If", "rune": "\u1691", "pos": Vector2(256, 350), "tier": 5, "unlocked": false},
	{"key": "ur", "name": "Bruyere", "rune": "\u1692", "pos": Vector2(312, 360), "tier": 5, "unlocked": false},
]

# Connections between nodes
const TREE_EDGES: Array[Array] = [
	["beith", "coll"], ["coll", "ailm"],
	["luis", "gort"], ["gort", "eadhadh"], ["eadhadh", "nuin"], ["nuin", "huath"], ["huath", "straif"],
	["quert", "duir"], ["duir", "tinne"], ["tinne", "onn"], ["onn", "ruis"], ["ruis", "saille"],
	["ailm", "muin"], ["ailm", "ioho"], ["ailm", "ur"],
	["straif", "muin"], ["saille", "ur"],
]

var _canvas: Control
var _unlocked_keys: Array[String] = ["beith", "luis", "quert"]  # Starters


func _ready() -> void:
	size = TREE_SIZE
	render_target_update_mode = SubViewport.UPDATE_ALWAYS
	transparent_bg = true

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_tree)
	add_child(_canvas)


func set_unlocked(keys: Array[String]) -> void:
	_unlocked_keys = keys
	if is_instance_valid(_canvas):
		_canvas.queue_redraw()


func _draw_tree() -> void:
	var c: Control = _canvas

	# Background tapestry texture
	c.draw_rect(Rect2(Vector2.ZERO, Vector2(TREE_SIZE)), Color(0.2, 0.15, 0.08), true)

	# Title
	c.draw_string(ThemeDB.fallback_font, Vector2(170, 25), "Arbre des Oghams", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.8, 0.7, 0.5))

	# Draw edges first
	for edge in TREE_EDGES:
		var from_node: Dictionary = _find_node(str(edge[0]))
		var to_node: Dictionary = _find_node(str(edge[1]))
		if from_node.is_empty() or to_node.is_empty():
			continue
		var from_unlocked: bool = str(edge[0]) in _unlocked_keys
		var to_unlocked: bool = str(edge[1]) in _unlocked_keys
		var color: Color = Color(0.6, 0.5, 0.3, 0.8) if (from_unlocked and to_unlocked) else Color(0.3, 0.25, 0.15, 0.3)
		c.draw_line(from_node["pos"] as Vector2, to_node["pos"] as Vector2, color, LINE_WIDTH)

	# Draw nodes
	for node in TREE_NODES:
		var pos: Vector2 = node["pos"] as Vector2
		var key: String = str(node["key"])
		var is_unlocked: bool = key in _unlocked_keys

		if is_unlocked:
			# Glowing unlocked node
			c.draw_circle(pos, NODE_RADIUS + 4, Color(0.8, 0.6, 0.2, 0.2))
			c.draw_circle(pos, NODE_RADIUS, Color(0.15, 0.5, 0.2))
			c.draw_string(ThemeDB.fallback_font, pos + Vector2(-6, 6), str(node["rune"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.9, 0.7))
			c.draw_string(ThemeDB.fallback_font, pos + Vector2(-20, NODE_RADIUS + 14), str(node["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.7, 0.6, 0.4))
		else:
			# Hidden/locked node — dim shadow
			c.draw_circle(pos, NODE_RADIUS * 0.7, Color(0.15, 0.12, 0.08, 0.4))
			c.draw_string(ThemeDB.fallback_font, pos + Vector2(-4, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.3, 0.25, 0.15, 0.5))


func _find_node(key: String) -> Dictionary:
	for n in TREE_NODES:
		if str(n["key"]) == key:
			return n
	return {}
