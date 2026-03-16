class_name MenuPrincipalSeasonal
extends RefCounted

## Seasonal particle effects: falling snow/leaves/petals, accumulation grid,
## fireflies, and summer sun rays.

# ---------------------------------------------------------------------------
# Season-specific tuning
# ---------------------------------------------------------------------------

const SEASON_CONFIG := {
	"HIVER": {
		"spawn_interval": 0.22,
		"max_particles": 90,
		"size_min": 3.0, "size_max": 7.0,
		"speed_min": 12.0, "speed_max": 35.0,
		"drift": 10.0,
		"color_base": Color(0.95, 0.96, 1.0, 0.92),
		"color_var": 0.05,
		"accum_color": Color(0.94, 0.95, 1.0, 0.9),
		"accum_grow": 0.12,
		"round": true,
	},
	"AUTOMNE": {
		"spawn_interval": 0.6,
		"max_particles": 35,
		"size_min": 5.0, "size_max": 11.0,
		"speed_min": 15.0, "speed_max": 40.0,
		"drift": 25.0,
		"color_base": MerlinVisual.CRT_PALETTE["season_autumn_leaf"],
		"color_var": 0.25,
		"accum_color": MerlinVisual.CRT_PALETTE["season_autumn_pile"],
		"accum_grow": 0.10,
		"round": false,
	},
	"PRINTEMPS": {
		"spawn_interval": 0.5,
		"max_particles": 40,
		"size_min": 3.0, "size_max": 7.0,
		"speed_min": 10.0, "speed_max": 28.0,
		"drift": 18.0,
		"color_base": MerlinVisual.CRT_PALETTE["season_spring_petal"],
		"color_var": 0.15,
		"accum_color": MerlinVisual.CRT_PALETTE["season_spring_pile"],
		"accum_grow": 0.08,
		"round": true,
	},
}

const ACCUM_CELL_WIDTH := 12
const ACCUM_MAX_HEIGHT := 600.0
const FIREFLY_COUNT := 12

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _host: Control  # reference to MenuPrincipalMerlin node
var _card: PanelContainer

var _falling_particles: Array[Dictionary] = []
var _fall_timer: float = 0.0

var _accum_grid: Array[float] = []
var _accum_nodes: Array[ColorRect] = []
var _accum_container: Control

var _fireflies: Array[Dictionary] = []

var _sun_rays: Array[ColorRect] = []
var _sun_ray_timer: float = 0.0

var _particle_land_count: int = 0

var current_season: String = "HIVER"

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func init(host: Control, card_node: PanelContainer, season: String) -> void:
	_host = host
	_card = card_node
	current_season = season


func build() -> void:
	_build_fireflies()
	if current_season == "ETE":
		_build_sun_rays()
		return
	_build_accum_grid()


func process(delta: float) -> void:
	_process_fireflies(delta)
	if current_season == "ETE":
		_process_sun_rays(delta)
		return
	if not SEASON_CONFIG.has(current_season):
		return
	_process_falling_particles(delta)


func on_resized() -> void:
	_rebuild_accum_visuals()

# ---------------------------------------------------------------------------
# Fireflies
# ---------------------------------------------------------------------------

func _build_fireflies() -> void:
	var vs: Vector2 = _host.get_viewport_rect().size
	if vs.x < 1.0:
		vs = Vector2(1152, 648)
	var glow_color: Color = MerlinVisual.CRT_PALETTE.get("phosphor", Color(0.2, 1.0, 0.4))
	for i in range(FIREFLY_COUNT):
		var dot := ColorRect.new()
		var sz := randf_range(2.0, 4.0)
		dot.size = Vector2(sz, sz)
		var base_pos := Vector2(randf_range(40, vs.x - 40), randf_range(40, vs.y - 40))
		dot.position = base_pos
		dot.color = Color(glow_color.r, glow_color.g, glow_color.b, 0.0)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dot.z_index = 0
		_host.add_child(dot)
		if _card:
			_host.move_child(dot, _card.get_index())
		_fireflies.append({
			"node": dot, "phase": randf_range(0, TAU),
			"speed": randf_range(0.3, 0.8),
			"drift_x": randf_range(15.0, 40.0), "drift_y": randf_range(10.0, 25.0),
			"base_pos": base_pos,
		})


func _process_fireflies(delta: float) -> void:
	for ff in _fireflies:
		var node: ColorRect = ff.node
		if not is_instance_valid(node):
			continue
		ff.phase += delta * ff.speed
		var t: float = ff.phase
		node.position = ff.base_pos + Vector2(
			sin(t * 1.3) * ff.drift_x,
			cos(t * 0.9) * ff.drift_y
		)
		var alpha: float = maxf(0.0, sin(t) * 0.5 + 0.1)
		node.color.a = alpha

# ---------------------------------------------------------------------------
# Falling Particles + Accumulation (HIVER / AUTOMNE / PRINTEMPS)
# ---------------------------------------------------------------------------

func _process_falling_particles(delta: float) -> void:
	var viewport_size: Vector2 = _host.get_viewport().get_visible_rect().size
	var cfg: Dictionary = SEASON_CONFIG[current_season]

	_fall_timer += delta
	if _fall_timer >= cfg.spawn_interval and _falling_particles.size() < cfg.max_particles:
		_fall_timer = 0.0
		_spawn_falling_particle(viewport_size, cfg)

	var to_remove: Array[int] = []
	for i in range(_falling_particles.size()):
		var p: Dictionary = _falling_particles[i]
		var node: ColorRect = p.node
		if not is_instance_valid(node):
			to_remove.append(i)
			continue

		node.position.y += p.speed * delta
		node.position.x += sin((node.position.y * 0.015) + p.time_offset) * p.drift * delta
		if not cfg.round:
			node.rotation += p.drift * 0.02 * delta

		var col := int(clampf(node.position.x / ACCUM_CELL_WIDTH, 0, _accum_grid.size() - 1))
		var surface_y: float = viewport_size.y - _accum_grid[col]
		if node.position.y >= surface_y:
			_particle_land_count += 1
			if _particle_land_count % 10 == 0:
				var sfx := _host.get_node_or_null("/root/SFXManager")
				if sfx and sfx.has_method("play_varied"):
					sfx.play_varied("pixel_land", 0.2)
			_accum_grid[col] = minf(_accum_grid[col] + cfg.accum_grow, ACCUM_MAX_HEIGHT)
			if col > 0:
				_accum_grid[col - 1] = minf(_accum_grid[col - 1] + cfg.accum_grow * 0.3, ACCUM_MAX_HEIGHT)
			if col < _accum_grid.size() - 1:
				_accum_grid[col + 1] = minf(_accum_grid[col + 1] + cfg.accum_grow * 0.3, ACCUM_MAX_HEIGHT)
			_update_accum_column(col, viewport_size)
			if col > 0:
				_update_accum_column(col - 1, viewport_size)
			if col < _accum_grid.size() - 1:
				_update_accum_column(col + 1, viewport_size)
			to_remove.append(i)
			continue

		if node.position.x < -20 or node.position.x > viewport_size.x + 20:
			to_remove.append(i)

	for i in range(to_remove.size() - 1, -1, -1):
		var idx: int = to_remove[i]
		if is_instance_valid(_falling_particles[idx].node):
			_falling_particles[idx].node.queue_free()
		_falling_particles.remove_at(idx)


func _spawn_falling_particle(viewport_size: Vector2, cfg: Dictionary) -> void:
	var node := ColorRect.new()
	var s: float = randf_range(cfg.size_min, cfg.size_max)

	if cfg.round:
		node.size = Vector2(s, s)
	else:
		node.size = Vector2(s, s * randf_range(0.5, 0.8))

	node.position = Vector2(randf_range(-10, viewport_size.x + 10), randf_range(-20, -5))

	var base: Color = cfg.color_base
	var v: float = cfg.color_var
	if current_season == "AUTOMNE":
		var autumn_colors: Array[Color] = [
			MerlinVisual.GBC.fire_light,
			MerlinVisual.GBC.fire_dark,
			MerlinVisual.CRT_ASPECT_COLORS["Corps"],
			MerlinVisual.GBC.thunder,
			MerlinVisual.SEASON_COLORS["automne"],
		]
		base = autumn_colors[randi() % autumn_colors.size()]
	node.color = Color(
		clampf(base.r + randf_range(-v, v), 0, 1),
		clampf(base.g + randf_range(-v, v), 0, 1),
		clampf(base.b + randf_range(-v, v), 0, 1),
		base.a
	)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var data := {
		"node": node,
		"speed": randf_range(cfg.speed_min, cfg.speed_max),
		"drift": randf_range(-cfg.drift, cfg.drift),
		"time_offset": randf_range(0, TAU),
	}

	_host.add_child(node)
	if _card:
		_host.move_child(node, _card.get_index())
	_falling_particles.append(data)

# ---------------------------------------------------------------------------
# Accumulation Grid
# ---------------------------------------------------------------------------

func _build_accum_grid() -> void:
	var viewport_size: Vector2 = _host.get_viewport().get_visible_rect().size
	var col_count := int(ceilf(viewport_size.x / ACCUM_CELL_WIDTH)) + 1
	_accum_grid.resize(col_count)
	_accum_grid.fill(0.0)

	_accum_container = Control.new()
	_accum_container.name = "AccumContainer"
	_accum_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_accum_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_host.add_child(_accum_container)
	if _card:
		_host.move_child(_accum_container, _card.get_index())

	_accum_nodes.clear()
	var cfg: Dictionary = SEASON_CONFIG[current_season]
	for i in range(col_count):
		var col_node := ColorRect.new()
		col_node.name = "AccumCol_%d" % i
		col_node.color = cfg.accum_color
		col_node.size = Vector2(ACCUM_CELL_WIDTH, 0)
		col_node.position = Vector2(i * ACCUM_CELL_WIDTH, viewport_size.y)
		col_node.mouse_filter = Control.MOUSE_FILTER_STOP
		col_node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var col_idx := i
		col_node.gui_input.connect(func(event: InputEvent): _on_accum_clicked(event, col_idx))
		_accum_container.add_child(col_node)
		_accum_nodes.append(col_node)


func _update_accum_column(col: int, viewport_size: Vector2) -> void:
	if col < 0 or col >= _accum_nodes.size():
		return
	var node: ColorRect = _accum_nodes[col]
	if not is_instance_valid(node):
		return
	var h: float = _accum_grid[col]
	node.size = Vector2(ACCUM_CELL_WIDTH, h)
	node.position = Vector2(col * ACCUM_CELL_WIDTH, viewport_size.y - h)


func _rebuild_accum_visuals() -> void:
	var viewport_size: Vector2 = _host.get_viewport().get_visible_rect().size
	if _accum_nodes.is_empty():
		return
	var needed := int(ceilf(viewport_size.x / ACCUM_CELL_WIDTH)) + 1
	while _accum_grid.size() < needed:
		_accum_grid.append(0.0)
	for i in range(_accum_nodes.size()):
		_update_accum_column(i, viewport_size)


func _on_accum_clicked(event: InputEvent, col: int) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _accum_grid[col] < 2.0:
		return
	var sfx := _host.get_node_or_null("/root/SFXManager")
	if sfx:
		sfx.play("accum_explode")
	_explode_accum_area(col)


func _explode_accum_area(center_col: int) -> void:
	var viewport_size: Vector2 = _host.get_viewport().get_visible_rect().size
	var cfg: Dictionary = SEASON_CONFIG[current_season]

	var blast_radius := 5
	var total_height := 0.0
	for c in range(maxi(0, center_col - blast_radius), mini(_accum_grid.size(), center_col + blast_radius + 1)):
		total_height += _accum_grid[c]

	var burst_count := int(total_height * 0.4) + 8
	burst_count = mini(burst_count, 40)
	var center_x: float = center_col * ACCUM_CELL_WIDTH + ACCUM_CELL_WIDTH * 0.5
	var center_y: float = viewport_size.y - _accum_grid[center_col]

	for i in range(burst_count):
		var particle := ColorRect.new()
		var s: float = randf_range(2, 6)
		particle.size = Vector2(s, s)
		particle.position = Vector2(
			center_x + randf_range(-blast_radius * ACCUM_CELL_WIDTH * 0.5, blast_radius * ACCUM_CELL_WIDTH * 0.5),
			center_y + randf_range(-5, 5)
		)
		particle.color = cfg.accum_color
		particle.color.a = randf_range(0.5, 1.0)
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_host.add_child(particle)

		var angle := randf_range(0, TAU)
		var dist := randf_range(25, 80)
		var target_pos := particle.position + Vector2(cos(angle), sin(angle) - 0.6) * dist
		var tween := _host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(particle, "position", target_pos, randf_range(0.3, 0.6))
		tween.parallel().tween_property(particle, "modulate:a", 0.0, randf_range(0.4, 0.8))
		tween.tween_callback(particle.queue_free)

	for c in range(maxi(0, center_col - blast_radius), mini(_accum_grid.size(), center_col + blast_radius + 1)):
		_accum_grid[c] = 0.0
		_update_accum_column(c, viewport_size)

# ---------------------------------------------------------------------------
# Summer Sun Rays
# ---------------------------------------------------------------------------

func _build_sun_rays() -> void:
	var viewport_size: Vector2 = _host.get_viewport().get_visible_rect().size
	var ray_count := randi_range(4, 6)
	for i in range(ray_count):
		var ray := ColorRect.new()
		ray.name = "SunRay_%d" % i
		ray.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var w: float = randf_range(30, 80)
		var h: float = viewport_size.y * randf_range(1.2, 1.6)
		ray.size = Vector2(w, h)
		ray.pivot_offset = Vector2(w * 0.5, 0)

		var x_spread: float = viewport_size.x / ray_count
		ray.position = Vector2(
			x_spread * i + randf_range(-30, 30),
			randf_range(-h * 0.3, -h * 0.1)
		)
		ray.rotation = randf_range(deg_to_rad(10), deg_to_rad(35))

		var sun_gold: Color = MerlinVisual.GBC.light
		ray.color = Color(sun_gold.r, sun_gold.g, sun_gold.b, randf_range(0.03, 0.07))

		_host.add_child(ray)
		if _card:
			_host.move_child(ray, _card.get_index())

		_sun_rays.append(ray)
		ray.set_meta("base_alpha", ray.color.a)
		ray.set_meta("phase", randf_range(0, TAU))
		ray.set_meta("speed", randf_range(0.15, 0.4))


func _process_sun_rays(delta: float) -> void:
	_sun_ray_timer += delta
	for ray in _sun_rays:
		if not is_instance_valid(ray):
			continue
		var base_a: float = ray.get_meta("base_alpha")
		var phase: float = ray.get_meta("phase")
		var spd: float = ray.get_meta("speed")
		ray.color.a = base_a * (0.5 + 0.5 * sin(_sun_ray_timer * spd + phase))
