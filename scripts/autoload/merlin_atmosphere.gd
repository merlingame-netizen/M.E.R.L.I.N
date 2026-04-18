## MerlinAtmosphere — Global Celtic atmospheric particle system
## Autoload CanvasLayer (layer 97) that renders mystical particles across all scenes.
## Seasonal, time-aware. Floating Ogham runes, wisps, motes, and weather particles.

extends CanvasLayer

const MAX_RUNES := 4
const MAX_WISPS := 6
const MAX_MOTES := 18
const MAX_SEASONAL := 12

const OGHAM_GLYPHS: Array[String] = [
	"\u1681", "\u1682", "\u1683", "\u1684", "\u1685",
	"\u1686", "\u1687", "\u1688", "\u1689", "\u168A",
	"\u168B", "\u168C", "\u168D", "\u168E", "\u168F",
	"\u1690", "\u1691", "\u1692",
]

const SPAWN_RATES := {
	"night":     { "rune": 0.012, "wisp": 0.025, "mote": 0.06, "seasonal": 0.03 },
	"dawn":      { "rune": 0.008, "wisp": 0.015, "mote": 0.05, "seasonal": 0.04 },
	"morning":   { "rune": 0.005, "wisp": 0.010, "mote": 0.04, "seasonal": 0.03 },
	"midday":    { "rune": 0.003, "wisp": 0.006, "mote": 0.03, "seasonal": 0.02 },
	"afternoon": { "rune": 0.004, "wisp": 0.008, "mote": 0.035, "seasonal": 0.025 },
	"dusk":      { "rune": 0.010, "wisp": 0.020, "mote": 0.055, "seasonal": 0.04 },
	"evening":   { "rune": 0.010, "wisp": 0.018, "mote": 0.05, "seasonal": 0.035 },
}

var _runes: Array[Dictionary] = []
var _wisps: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _seasonal: Array[Dictionary] = []

var _canvas: Control
var _time: float = 0.0
var _season: String = "spring"
var _period: String = "midday"
var _enabled: bool = true
var _celtic_font: Font


func _ready() -> void:
	layer = 97
	_canvas = Control.new()
	_canvas.name = "AtmosphereCanvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_on_draw)
	add_child(_canvas)

	var font_path := "res://resources/fonts/celtic_bit/celtic-bit.ttf"
	if ResourceLoader.exists(font_path):
		_celtic_font = load(font_path)

	var mv: Node = get_node_or_null("/root/MerlinVisual")
	if mv and mv.has_method("get_current_season"):
		_season = mv.get_current_season()

	var dnm: Node = get_node_or_null("/root/DayNightManager")
	if dnm:
		if dnm.has_signal("period_changed"):
			dnm.period_changed.connect(_on_period_changed)
		if dnm.has_method("get_time_of_day"):
			_period = dnm.get_time_of_day()


func _process(delta: float) -> void:
	if not _enabled:
		return
	_time += delta
	var vp: Vector2 = get_viewport().get_visible_rect().size
	if vp.x < 1.0 or vp.y < 1.0:
		return

	var rates: Dictionary = SPAWN_RATES.get(_period, SPAWN_RATES["midday"])

	_update_runes(delta, vp)
	_update_wisps(delta, vp)
	_update_motes(delta, vp)
	_update_seasonal(delta, vp)

	if randf() < rates["rune"] and _runes.size() < MAX_RUNES:
		_spawn_rune(vp)
	if randf() < rates["wisp"] and _wisps.size() < MAX_WISPS:
		_spawn_wisp(vp)
	if randf() < rates["mote"] and _motes.size() < MAX_MOTES:
		_spawn_mote(vp)
	if randf() < rates["seasonal"] and _seasonal.size() < MAX_SEASONAL:
		_spawn_seasonal(vp)

	_canvas.queue_redraw()


# ═══════════════════════════════════════════════════════════════
# PUBLIC API
# ═══════════════════════════════════════════════════════════════

func enable() -> void:
	_enabled = true
	_canvas.visible = true


func disable() -> void:
	_enabled = false
	_canvas.visible = false


func set_season(s: String) -> void:
	_season = s


func clear_all() -> void:
	_runes.clear()
	_wisps.clear()
	_motes.clear()
	_seasonal.clear()


# ═══════════════════════════════════════════════════════════════
# RUNES — Floating Ogham glyphs that fade in/out and drift
# ═══════════════════════════════════════════════════════════════

func _spawn_rune(vp: Vector2) -> void:
	_runes.append({
		"x": randf() * vp.x,
		"y": randf() * vp.y,
		"glyph": OGHAM_GLYPHS[randi() % OGHAM_GLYPHS.size()],
		"life": randf_range(6.0, 14.0),
		"max_life": 0.0,
		"drift_x": randf_range(-3.0, 3.0),
		"drift_y": randf_range(-8.0, -2.0),
		"rotation": randf() * TAU,
		"rot_speed": randf_range(-0.15, 0.15),
		"size": randf_range(16.0, 28.0),
		"color_idx": randi() % 3,
	})
	_runes[-1]["max_life"] = _runes[-1]["life"]


func _update_runes(delta: float, _vp: Vector2) -> void:
	var i: int = _runes.size() - 1
	while i >= 0:
		var r: Dictionary = _runes[i]
		r["x"] += r["drift_x"] * delta
		r["y"] += r["drift_y"] * delta
		r["rotation"] += r["rot_speed"] * delta
		r["life"] -= delta
		if r["life"] <= 0.0:
			_runes.remove_at(i)
		i -= 1


# ═══════════════════════════════════════════════════════════════
# WISPS — Curved flowing light trails
# ═══════════════════════════════════════════════════════════════

func _spawn_wisp(vp: Vector2) -> void:
	var start_x: float = randf() * vp.x
	var start_y: float = randf() * vp.y
	_wisps.append({
		"x": start_x,
		"y": start_y,
		"vx": randf_range(-20.0, 20.0),
		"vy": randf_range(-15.0, -5.0),
		"freq": randf_range(1.5, 4.0),
		"amp": randf_range(15.0, 40.0),
		"phase": randf() * TAU,
		"life": randf_range(3.0, 7.0),
		"max_life": 0.0,
		"trail": [] as Array[Vector2],
		"color_idx": randi() % 3,
	})
	_wisps[-1]["max_life"] = _wisps[-1]["life"]


func _update_wisps(delta: float, _vp: Vector2) -> void:
	var i: int = _wisps.size() - 1
	while i >= 0:
		var w: Dictionary = _wisps[i]
		w["x"] += w["vx"] * delta
		w["y"] += w["vy"] * delta
		w["x"] += sin(_time * w["freq"] + w["phase"]) * w["amp"] * delta
		w["life"] -= delta

		var trail: Array = w["trail"]
		trail.append(Vector2(w["x"], w["y"]))
		if trail.size() > 8:
			trail.remove_at(0)

		if w["life"] <= 0.0:
			_wisps.remove_at(i)
		i -= 1


# ═══════════════════════════════════════════════════════════════
# MOTES — Tiny ambient glowing dots
# ═══════════════════════════════════════════════════════════════

func _spawn_mote(vp: Vector2) -> void:
	_motes.append({
		"x": randf() * vp.x,
		"y": randf() * vp.y,
		"speed_y": randf_range(-6.0, -1.0),
		"freq": randf_range(0.8, 3.0),
		"phase": randf() * TAU,
		"life": randf_range(3.0, 8.0),
		"max_life": 0.0,
		"radius": randf_range(1.0, 2.5),
		"color_idx": randi() % 4,
	})
	_motes[-1]["max_life"] = _motes[-1]["life"]


func _update_motes(delta: float, _vp: Vector2) -> void:
	var i: int = _motes.size() - 1
	while i >= 0:
		var m: Dictionary = _motes[i]
		m["y"] += m["speed_y"] * delta
		m["x"] += sin(_time * m["freq"] + m["phase"]) * 6.0 * delta
		m["life"] -= delta
		if m["life"] <= 0.0:
			_motes.remove_at(i)
		i -= 1


# ═══════════════════════════════════════════════════════════════
# SEASONAL — Weather particles based on current season
# ═══════════════════════════════════════════════════════════════

func _spawn_seasonal(vp: Vector2) -> void:
	var p: Dictionary = {}
	match _season:
		"spring":
			p = {
				"x": randf() * vp.x,
				"y": vp.y + 4.0,
				"vx": randf_range(-5.0, 5.0),
				"vy": randf_range(-12.0, -6.0),
				"life": randf_range(4.0, 8.0),
				"size": randf_range(1.5, 3.0),
				"type": "pollen",
			}
		"summer":
			var is_firefly: bool = _period in ["dusk", "evening", "night"]
			p = {
				"x": randf() * vp.x,
				"y": randf() * vp.y,
				"vx": randf_range(-4.0, 4.0),
				"vy": randf_range(-3.0, 3.0),
				"life": randf_range(2.0, 5.0),
				"size": randf_range(1.5, 2.5),
				"type": "firefly" if is_firefly else "pollen",
				"blink_phase": randf() * TAU,
			}
		"autumn":
			p = {
				"x": randf() * vp.x,
				"y": -4.0,
				"vx": randf_range(8.0, 20.0),
				"vy": randf_range(10.0, 25.0),
				"life": randf_range(4.0, 10.0),
				"size": randf_range(2.0, 4.0),
				"type": "leaf",
				"rot": randf() * TAU,
				"rot_speed": randf_range(-2.0, 2.0),
			}
		"winter":
			p = {
				"x": randf() * vp.x,
				"y": -4.0,
				"vx": randf_range(-3.0, 3.0),
				"vy": randf_range(8.0, 18.0),
				"life": randf_range(5.0, 12.0),
				"size": randf_range(1.0, 3.0),
				"type": "snow",
				"wobble_phase": randf() * TAU,
			}
	if p.size() > 0:
		p["max_life"] = p["life"]
		_seasonal.append(p)


func _update_seasonal(delta: float, vp: Vector2) -> void:
	var i: int = _seasonal.size() - 1
	while i >= 0:
		var p: Dictionary = _seasonal[i]
		p["x"] += p["vx"] * delta
		p["y"] += p["vy"] * delta
		p["life"] -= delta

		match p.get("type", ""):
			"leaf":
				p["rot"] += p["rot_speed"] * delta
				p["vx"] += sin(_time * 0.8) * 3.0 * delta
			"snow":
				p["x"] += sin(_time * 1.2 + p["wobble_phase"]) * 10.0 * delta

		var oob: bool = p["x"] < -20.0 or p["x"] > vp.x + 20.0 or p["y"] < -20.0 or p["y"] > vp.y + 20.0
		if p["life"] <= 0.0 or oob:
			_seasonal.remove_at(i)
		i -= 1


# ═══════════════════════════════════════════════════════════════
# DRAWING
# ═══════════════════════════════════════════════════════════════

func _get_particle_color(idx: int, alpha: float) -> Color:
	var palette: Dictionary = MerlinVisual.CRT_PALETTE
	var base: Color
	match idx:
		0: base = palette.get("phosphor_glow", Color(0.2, 1.0, 0.4))
		1: base = palette.get("cyan_dim", Color(0.1, 0.5, 0.5))
		2: base = palette.get("amber_dim", Color(0.6, 0.4, 0.1))
		_: base = palette.get("phosphor_dim", Color(0.1, 0.4, 0.2))
	return Color(base.r, base.g, base.b, alpha)


func _life_alpha(life: float, max_life: float) -> float:
	var ratio: float = life / maxf(max_life, 0.01)
	var fade_in: float = clampf((1.0 - ratio) * 5.0, 0.0, 1.0)
	var fade_out: float = clampf(ratio * 4.0, 0.0, 1.0)
	return fade_in * fade_out


func _on_draw() -> void:
	_draw_motes()
	_draw_wisps()
	_draw_runes()
	_draw_seasonal()


func _draw_motes() -> void:
	for m: Dictionary in _motes:
		var alpha: float = _life_alpha(m["life"], m["max_life"]) * 0.15
		var c: Color = _get_particle_color(m["color_idx"], alpha)
		_canvas.draw_circle(Vector2(m["x"], m["y"]), m["radius"], c)
		var glow_c: Color = Color(c.r, c.g, c.b, alpha * 0.3)
		_canvas.draw_circle(Vector2(m["x"], m["y"]), m["radius"] * 3.0, glow_c)


func _draw_wisps() -> void:
	for w: Dictionary in _wisps:
		var trail: Array = w["trail"]
		if trail.size() < 2:
			continue
		var base_alpha: float = _life_alpha(w["life"], w["max_life"]) * 0.12
		var c: Color = _get_particle_color(w["color_idx"], base_alpha)
		for j: int in range(1, trail.size()):
			var seg_alpha: float = float(j) / float(trail.size()) * base_alpha
			var seg_c: Color = Color(c.r, c.g, c.b, seg_alpha)
			_canvas.draw_line(trail[j - 1], trail[j], seg_c, 1.5)
		var head: Vector2 = trail[-1]
		_canvas.draw_circle(head, 2.0, Color(c.r, c.g, c.b, base_alpha * 1.5))


func _draw_runes() -> void:
	if _celtic_font == null:
		return
	for r: Dictionary in _runes:
		var alpha: float = _life_alpha(r["life"], r["max_life"]) * 0.08
		var c: Color = _get_particle_color(r["color_idx"], alpha)
		var pos := Vector2(r["x"], r["y"])
		var font_size: int = int(r["size"])
		_canvas.draw_set_transform(pos, r["rotation"], Vector2.ONE)
		_canvas.draw_string(_celtic_font, Vector2.ZERO, r["glyph"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, c)
		var glow_c: Color = Color(c.r, c.g, c.b, alpha * 0.4)
		_canvas.draw_string(_celtic_font, Vector2(1, 1), r["glyph"], HORIZONTAL_ALIGNMENT_CENTER, -1, font_size + 4, glow_c)
		_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_seasonal() -> void:
	for p: Dictionary in _seasonal:
		var alpha: float = _life_alpha(p["life"], p["max_life"])
		var pos := Vector2(p["x"], p["y"])

		match p.get("type", ""):
			"pollen":
				var c := Color(0.5, 0.8, 0.3, alpha * 0.12)
				_canvas.draw_circle(pos, p["size"], c)

			"firefly":
				var blink: float = (sin(_time * 6.0 + p.get("blink_phase", 0.0)) + 1.0) * 0.5
				var c := Color(0.9, 0.8, 0.2, alpha * 0.2 * blink)
				_canvas.draw_circle(pos, p["size"], c)
				var glow_c := Color(0.9, 0.8, 0.2, alpha * 0.06 * blink)
				_canvas.draw_circle(pos, p["size"] * 4.0, glow_c)

			"leaf":
				var c := Color(0.7, 0.4, 0.1, alpha * 0.1)
				_canvas.draw_set_transform(pos, p.get("rot", 0.0), Vector2.ONE)
				_canvas.draw_rect(Rect2(-p["size"], -p["size"] * 0.5, p["size"] * 2.0, p["size"]), c)
				_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

			"snow":
				var c := Color(0.85, 0.88, 0.92, alpha * 0.15)
				_canvas.draw_circle(pos, p["size"], c)


func _on_period_changed(new_period: String) -> void:
	_period = new_period
