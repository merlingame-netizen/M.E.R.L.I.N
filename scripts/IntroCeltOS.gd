extends Control

## IntroCeltOS - Animation d'intro stylisee
## Phase 1: Boot rapide (lignes qui apparaissent vite puis fondu)
## Phase 2: Logo CeltOS forme par blocs Tetris tombants
## Phase 3: Blocs se reorganisent en pixels formant des yeux amande,
##          ouverture progressive smooth, flash lumineux

signal boot_complete

# PALETTE constant removed — using MerlinVisual.GBC for this retro-styled intro

const BOOT_LINES := [
	"BIOS POST check...",
	"Memory: 4096 MB",
	"Loading druid_core.ko",
	"Loading ogham_driver.ko",
	"Ley line scan... FOUND",
	"LLM: Qwen2.5-3B",
	"Warmup inference...",
	"Systems ready",
]

const LOGO_GRID := [
	[1,1,1,0,1,1,1,0,1,0,0,0,1,1,1,0,1,1,1,0,1,1,1],
	[1,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,1,0,1,0,1,0,0],
	[1,0,0,0,1,1,0,0,1,0,0,0,0,1,0,0,1,0,1,0,1,1,1],
	[1,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,1,0,1,0,0,0,1],
	[1,1,1,0,1,1,1,0,1,1,1,0,0,1,0,0,1,1,1,0,1,1,1],
]

# --- UI nodes ---
var background: ColorRect
var boot_container: Control
var boot_labels: Array[Label] = []
var logo_container: Control
var logo_blocks: Array[ColorRect] = []
var pixel_container: Control
var pixel_blocks: Array[ColorRect] = []
var eye_drawer: Control

# --- State ---
var _warmup_done := false
var _phase := 0
var _open_progress := 0.0
var _glow_intensity := 0.0

# --- Eye geometry (set in Phase 3 based on viewport) ---
var _eye_width := 0.0
var _eye_height := 0.0
var _left_center := Vector2.ZERO
var _right_center := Vector2.ZERO

# --- VFX state ---
var _eye_particles: Array[Dictionary] = []
var _particle_container: Control
var _shake_offset := Vector2.ZERO
var _shake_intensity := 0.0
var _ray_rotation := 0.0
var _pupil_pulse := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_build_ui()
	_warmup_llm_async()
	MusicManager.play_intro_music()
	_start_phase_1()


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _process(delta: float) -> void:
	# Rotate light rays slowly
	_ray_rotation += delta * 0.15
	# Pupil pulsation (sine wave)
	_pupil_pulse = sin(Time.get_ticks_msec() * 0.004) * 0.15

	# Screen shake decay
	if _shake_intensity > 0.001:
		_shake_offset = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
		_shake_intensity *= 0.92
		if eye_drawer:
			eye_drawer.position = _shake_offset
	elif _shake_offset != Vector2.ZERO:
		_shake_offset = Vector2.ZERO
		if eye_drawer:
			eye_drawer.position = Vector2.ZERO

	# Update eye particles
	_update_eye_particles(delta)

	# Trigger redraw for animated rays/pulse
	if _open_progress > 0.1 and eye_drawer:
		eye_drawer.queue_redraw()


func _build_ui() -> void:
	background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = MerlinVisual.GBC.black
	add_child(background)

	boot_container = Control.new()
	boot_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(boot_container)

	logo_container = Control.new()
	logo_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo_container.modulate.a = 0.0
	add_child(logo_container)

	pixel_container = Control.new()
	pixel_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	pixel_container.modulate.a = 0.0
	add_child(pixel_container)

	eye_drawer = Control.new()
	eye_drawer.set_anchors_preset(Control.PRESET_FULL_RECT)
	eye_drawer.modulate.a = 0.0
	eye_drawer.draw.connect(_on_draw_eyes.bind(eye_drawer))
	add_child(eye_drawer)

	_particle_container = Control.new()
	_particle_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_particle_container)


func _warmup_llm_async() -> void:
	# LLM warmup is triggered by MenuPrincipal, not here.
	# Just wait for the intro animation duration then proceed.
	await get_tree().create_timer(2.0).timeout
	_warmup_done = true


# ============================================================
# PHASE 1 — Boot rapide
# ============================================================

func _start_phase_1() -> void:
	_phase = 1
	var vp := get_viewport().get_visible_rect().size
	var start_y := vp.y * 0.3
	var line_height := 22.0
	var line_spacing := 6.0

	for i in range(BOOT_LINES.size()):
		var label := Label.new()
		label.text = BOOT_LINES[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		label.position.y = start_y + i * (line_height + line_spacing)
		label.position.x = -200
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", MerlinVisual.GBC.grass_dark)
		label.modulate.a = 0.0
		boot_container.add_child(label)
		boot_labels.append(label)

	var tween := create_tween()
	for i in range(boot_labels.size()):
		var delay := i * 0.06
		tween.tween_property(boot_labels[i], "modulate:a", 0.8, 0.08).set_delay(delay)
		# SFX: each boot line blip with pitch variation
		tween.tween_callback(func() -> void: SFXManager.play_varied("boot_line", 0.1)).set_delay(delay)

	tween.tween_interval(0.15)
	# SFX: boot confirmed — all lines lit up
	tween.tween_callback(func() -> void: SFXManager.play("boot_confirm"))
	for label in boot_labels:
		tween.parallel().tween_property(label, "modulate:a", 1.0, 0.1)
		tween.parallel().tween_property(label, "theme_override_colors/font_color", MerlinVisual.PALETTE.accent, 0.1)

	tween.tween_interval(0.3)
	tween.tween_property(boot_container, "modulate:a", 0.0, 0.4)
	tween.tween_callback(_start_phase_2)


# ============================================================
# PHASE 2 — Logo CeltOS Tetris
# ============================================================

func _start_phase_2() -> void:
	_phase = 2
	var vp := get_viewport().get_visible_rect().size
	var center := vp / 2

	var block_size := 12.0
	var block_gap := 2.0
	var total_block := block_size + block_gap

	var grid_width: int = LOGO_GRID[0].size()
	var grid_height: int = LOGO_GRID.size()
	var logo_width := grid_width * total_block
	var logo_height := grid_height * total_block

	var start_x := center.x - logo_width / 2
	var start_y := center.y - logo_height / 2

	for row in range(grid_height):
		for col in range(grid_width):
			if LOGO_GRID[row][col] == 1:
				var block := ColorRect.new()
				block.size = Vector2(block_size, block_size)

				var final_x := start_x + col * total_block
				var final_y := start_y + row * total_block
				block.position = Vector2(final_x, -50 - randf() * 200)

				if (row + col) % 2 == 0:
					block.color = MerlinVisual.PALETTE.block
				else:
					block.color = MerlinVisual.PALETTE.block_alt

				block.set_meta("final_pos", Vector2(final_x, final_y))
				block.set_meta("col", col)
				logo_container.add_child(block)
				logo_blocks.append(block)

	var tween := create_tween()
	tween.tween_property(logo_container, "modulate:a", 1.0, 0.2)

	logo_blocks.sort_custom(func(a: ColorRect, b: ColorRect) -> bool:
		return a.get_meta("col") < b.get_meta("col")
	)

	for i in range(logo_blocks.size()):
		var block: ColorRect = logo_blocks[i]
		var final_pos: Vector2 = block.get_meta("final_pos")
		var delay := i * 0.015 + randf() * 0.02
		tween.parallel().tween_property(
			block, "position", final_pos, 0.35
		).set_delay(delay).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		# SFX: each block landing with pitch variation
		tween.parallel().tween_callback(
			func() -> void: SFXManager.play_varied("block_land", 0.1)
		).set_delay(delay + 0.35)

	tween.tween_interval(0.6)

	# Flash du logo puis transition vers cyan
	# SFX: logo flash
	tween.tween_callback(func() -> void: SFXManager.play("flash_boom"))
	for block in logo_blocks:
		tween.parallel().tween_property(block, "color", MerlinVisual.PALETTE.accent, 0.15)
	tween.tween_interval(0.1)
	for block in logo_blocks:
		tween.parallel().tween_property(block, "color", MerlinVisual.PALETTE.eye_cyan, 0.2)

	tween.tween_interval(0.3)
	tween.tween_callback(_start_phase_3)


# ============================================================
# PHASE 3 — Pixels → Yeux amande → Ouverture → Flash
# ============================================================

func _start_phase_3() -> void:
	_phase = 3
	var vp := get_viewport().get_visible_rect().size

	# Eye dimensions — screen-filling
	_eye_width = vp.x * 0.28
	_eye_height = min(vp.y * 0.32, _eye_width * 0.7)
	_left_center = Vector2(vp.x * 0.33, vp.y * 0.47)
	_right_center = Vector2(vp.x * 0.67, vp.y * 0.47)

	_phase_3a_converge()


## 3a — Blocs CELTOS convergent vers les deux formes d'yeux
func _phase_3a_converge() -> void:
	# SFX: convergence drone
	SFXManager.play("convergence")
	var mid: int = int(logo_blocks.size() / 2.0)
	var left_targets := _random_eye_positions(_left_center, _eye_width, _eye_height, mid)
	var right_targets := _random_eye_positions(_right_center, _eye_width, _eye_height, logo_blocks.size() - mid)

	var tween := create_tween()

	for i in range(logo_blocks.size()):
		var block: ColorRect = logo_blocks[i]
		var target: Vector2
		if i < mid:
			target = left_targets[min(i, left_targets.size() - 1)]
		else:
			target = right_targets[min(i - mid, right_targets.size() - 1)]

		tween.parallel().tween_property(
			block, "position", target, 0.9
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.parallel().tween_property(block, "size", Vector2(5, 5), 0.7)
		tween.parallel().tween_property(block, "color", MerlinVisual.PALETTE.eye_cyan, 0.6)

	tween.tween_interval(0.15)
	tween.tween_callback(_phase_3b_spawn_pixels)


## 3b — Pixels supplementaires volent depuis les bords pour remplir les yeux
func _phase_3b_spawn_pixels() -> void:
	# SFX: pixel cascade as batch spawns
	SFXManager.play("pixel_cascade")
	var extra_per_eye := 55
	var left_positions := _random_eye_positions(_left_center, _eye_width, _eye_height, extra_per_eye)
	var right_positions := _random_eye_positions(_right_center, _eye_width, _eye_height, extra_per_eye)
	var all_positions: Array[Vector2] = []
	all_positions.append_array(left_positions)
	all_positions.append_array(right_positions)

	pixel_container.modulate.a = 1.0
	var vp := get_viewport().get_visible_rect().size

	for pos in all_positions:
		var px := ColorRect.new()
		px.size = Vector2(4, 4)
		px.color = Color(MerlinVisual.PALETTE.eye_cyan.r, MerlinVisual.PALETTE.eye_cyan.g, MerlinVisual.PALETTE.eye_cyan.b, 0.0)
		# Spawn depuis un bord aleatoire
		var edge := randi() % 4
		match edge:
			0: px.position = Vector2(randf() * vp.x, -10)
			1: px.position = Vector2(randf() * vp.x, vp.y + 10)
			2: px.position = Vector2(-10, randf() * vp.y)
			3: px.position = Vector2(vp.x + 10, randf() * vp.y)
		px.set_meta("target", pos)
		pixel_container.add_child(px)
		pixel_blocks.append(px)

	var tween := create_tween()

	# Pixels volent vers leurs positions
	for px in pixel_blocks:
		var target: Vector2 = px.get_meta("target")
		var delay := randf() * 0.35
		tween.parallel().tween_property(
			px, "position", target, 0.7
		).set_delay(delay).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(px, "color:a", 0.8, 0.35).set_delay(delay)

	# Flash bref — tous les pixels passent blanc puis reviennent
	tween.tween_interval(0.2)
	# SFX: white flash
	tween.tween_callback(func() -> void: SFXManager.play("flash_boom"))
	for block in logo_blocks:
		tween.parallel().tween_property(block, "color", MerlinVisual.PALETTE.eye_white, 0.1)
	for px in pixel_blocks:
		tween.parallel().tween_property(
			px, "color",
			Color(MerlinVisual.PALETTE.eye_white.r, MerlinVisual.PALETTE.eye_white.g, MerlinVisual.PALETTE.eye_white.b, 0.9),
			0.1
		)
	tween.tween_interval(0.08)
	for block in logo_blocks:
		tween.parallel().tween_property(block, "color", MerlinVisual.PALETTE.eye_cyan, 0.15)
	for px in pixel_blocks:
		tween.parallel().tween_property(
			px, "color",
			Color(MerlinVisual.PALETTE.eye_cyan.r, MerlinVisual.PALETTE.eye_cyan.g, MerlinVisual.PALETTE.eye_cyan.b, 0.8),
			0.15
		)

	tween.tween_interval(0.25)
	tween.tween_callback(_phase_3c_transition_to_smooth)


## 3c — Pixels fondent, yeux lisses apparaissent (fente fermee)
func _phase_3c_transition_to_smooth() -> void:
	# SFX: eye slit starting to glow
	SFXManager.play("slit_glow")
	_open_progress = 0.02
	_glow_intensity = 0.3
	eye_drawer.modulate.a = 1.0
	eye_drawer.queue_redraw()

	var tween := create_tween()

	# Fondu des pixels
	tween.tween_property(logo_container, "modulate:a", 0.0, 0.6)
	tween.parallel().tween_property(pixel_container, "modulate:a", 0.0, 0.6)

	# Glow monte autour de la fente
	tween.parallel().tween_method(_set_glow_intensity, 0.3, 0.6, 0.6)

	tween.tween_interval(0.4)
	tween.tween_callback(_phase_3d_open_eyes)


## 3d — Ouverture progressive des yeux (hero animation)
func _phase_3d_open_eyes() -> void:
	# SFX: deep rising drone for eye opening
	SFXManager.play("eye_open")
	var tween := create_tween()

	# Ouverture smooth — 2.2 secondes avec cubic ease
	tween.tween_method(
		_set_open_progress, _open_progress, 1.0, 2.2
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

	# Glow monte progressivement
	tween.parallel().tween_method(
		_set_glow_intensity, _glow_intensity, 1.0, 2.0
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Subtle shake as eyes reach full open
	tween.parallel().tween_callback(_trigger_shake.bind(2.5)).set_delay(1.8)

	# Hold a pleine ouverture
	tween.tween_interval(0.5)

	if not _warmup_done:
		tween.tween_callback(_wait_for_warmup)
	else:
		tween.tween_callback(_phase_3e_flash)


## 3e — Flash lumineux puis transition
func _phase_3e_flash() -> void:
	# SFX: final blinding flash
	SFXManager.play("flash_boom")
	# Burst of particles on flash
	_spawn_flash_burst()
	_trigger_shake(5.0)
	var tween := create_tween()

	# Pulse de glow intense
	tween.tween_method(_set_glow_intensity, 1.0, 1.6, 0.12)
	tween.tween_method(_set_glow_intensity, 1.6, 2.2, 0.08)

	# Flash blanc plein ecran
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.WHITE
	flash.modulate.a = 0.0
	add_child(flash)

	tween.tween_property(
		flash, "modulate:a", 1.0, 0.2
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)

	tween.tween_interval(0.3)
	tween.tween_callback(_transition_to_menu)


# ============================================================
# Drawing — yeux amande avec glow multicouche
# ============================================================

func _on_draw_eyes(node: Control) -> void:
	if _open_progress < 0.005:
		return
	_draw_single_eye(node, _left_center, _eye_width, _eye_height, _open_progress, _glow_intensity)
	_draw_single_eye(node, _right_center, _eye_width, _eye_height, _open_progress, _glow_intensity)


func _draw_single_eye(node: Control, center: Vector2, w: float, h: float, open: float, glow: float) -> void:
	# --- Fente lumineuse quand presque ferme ---
	if open < 0.15:
		var slit_alpha := (1.0 - open / 0.15) * 0.8
		var slit_color := Color(MerlinVisual.PALETTE.slit_glow.r, MerlinVisual.PALETTE.slit_glow.g, MerlinVisual.PALETTE.slit_glow.b, slit_alpha)
		node.draw_line(
			center + Vector2(-w / 2.0, 0),
			center + Vector2(w / 2.0, 0),
			slit_color, 2.5, true
		)

	# --- Outer glow layers (large, semi-transparent) ---
	var glow_layers := 10
	for i in range(glow_layers, 0, -1):
		var glow_scale := 1.0 + float(i) * 0.12
		var alpha := 0.022 * float(glow_layers - i + 1) * glow
		if alpha < 0.003:
			continue
		var glow_color := Color(MerlinVisual.PALETTE.eye_cyan.r, MerlinVisual.PALETTE.eye_cyan.g, MerlinVisual.PALETTE.eye_cyan.b, alpha)
		var pts := _almond_points(center, w * glow_scale, h * open * glow_scale)
		if pts.size() >= 3:
			node.draw_polygon(pts, PackedColorArray([glow_color]))

	# --- Eye base fill (deep blue) ---
	var main_pts := _almond_points(center, w, h * open)
	if main_pts.size() >= 3:
		node.draw_polygon(main_pts, PackedColorArray([MerlinVisual.PALETTE.eye_deep]))

	# --- Mid layer (outer cyan) ---
	var mid_pts := _almond_points(center, w * 0.85, h * open * 0.82)
	if mid_pts.size() >= 3:
		node.draw_polygon(mid_pts, PackedColorArray([MerlinVisual.PALETTE.eye_outer]))

	# --- Inner cyan ---
	var inner_pts := _almond_points(center, w * 0.68, h * open * 0.65)
	if inner_pts.size() >= 3:
		node.draw_polygon(inner_pts, PackedColorArray([MerlinVisual.PALETTE.eye_cyan]))

	# --- Bright center ---
	var bright_pts := _almond_points(center, w * 0.45, h * open * 0.45)
	if bright_pts.size() >= 3:
		node.draw_polygon(bright_pts, PackedColorArray([MerlinVisual.PALETTE.eye_bright]))

	# --- White hot core ---
	var white_pts := _almond_points(center, w * 0.22, h * open * 0.25)
	if white_pts.size() >= 3:
		node.draw_polygon(white_pts, PackedColorArray([MerlinVisual.PALETTE.eye_white]))

	# --- Eye outline ---
	if main_pts.size() >= 3:
		var outline := PackedVector2Array(main_pts)
		outline.append(main_pts[0])
		node.draw_polyline(outline, MerlinVisual.PALETTE.eye_bright, 1.5, true)

	# --- Radial light rays (visible when opening > 30%) ---
	if open > 0.3:
		var ray_alpha := clampf((open - 0.3) / 0.4, 0.0, 1.0) * glow * 0.35
		var ray_count := 12
		var ray_length := w * (0.6 + glow * 0.3)
		for r in range(ray_count):
			var angle := (TAU / ray_count) * r + _ray_rotation
			var inner_r := w * 0.15
			var start_pt := center + Vector2(cos(angle), sin(angle)) * inner_r
			var end_pt := center + Vector2(cos(angle), sin(angle)) * ray_length
			var ray_col := Color(MerlinVisual.PALETTE.eye_cyan.r, MerlinVisual.PALETTE.eye_cyan.g, MerlinVisual.PALETTE.eye_cyan.b, ray_alpha * (0.5 + 0.5 * sin(angle * 3.0 + _ray_rotation * 4.0)))
			node.draw_line(start_pt, end_pt, ray_col, 1.5, true)

	# --- Iris ring (visible quand ouvert > 40%) ---
	if open > 0.4:
		var iris_alpha := clampf((open - 0.4) / 0.3, 0.0, 1.0)
		var iris_radius: float = min(w * 0.16, h * open * 0.32)
		var iris_color := Color(
			MerlinVisual.PALETTE.eye_white.r, MerlinVisual.PALETTE.eye_white.g, MerlinVisual.PALETTE.eye_white.b,
			iris_alpha * 0.5
		)
		node.draw_arc(center, iris_radius, 0, TAU, 48, iris_color, 2.0)

		# --- Inner iris luminescence ring ---
		var inner_iris_r := iris_radius * (0.6 + _pupil_pulse)
		var lum_color := Color(MerlinVisual.PALETTE.eye_bright.r, MerlinVisual.PALETTE.eye_bright.g, MerlinVisual.PALETTE.eye_bright.b, iris_alpha * 0.3)
		node.draw_arc(center, inner_iris_r, 0, TAU, 32, lum_color, 1.0)

	# --- Specular highlight (primary — large white dot) ---
	if open > 0.6:
		var spec_alpha := clampf((open - 0.6) / 0.25, 0.0, 1.0)
		var spec_offset := Vector2(-w * 0.07, -h * open * 0.09)
		var spec_radius: float = max(w * 0.025, 3.0)
		node.draw_circle(
			center + spec_offset, spec_radius,
			Color(1, 1, 1, spec_alpha * 0.75)
		)

		# --- Secondary specular highlights ---
		var spec2_offset := Vector2(w * 0.05, -h * open * 0.05)
		node.draw_circle(
			center + spec2_offset, spec_radius * 0.5,
			Color(1, 1, 1, spec_alpha * 0.4)
		)
		var spec3_offset := Vector2(-w * 0.03, h * open * 0.04)
		node.draw_circle(
			center + spec3_offset, spec_radius * 0.35,
			Color(MerlinVisual.PALETTE.eye_bright.r, MerlinVisual.PALETTE.eye_bright.g, MerlinVisual.PALETTE.eye_bright.b, spec_alpha * 0.3)
		)

	# --- Pulsating white core (enhanced with pupil beat) ---
	if open > 0.5:
		var pulse_size := w * (0.08 + _pupil_pulse * 0.02) * open
		var pulse_alpha := clampf((open - 0.5) / 0.3, 0.0, 1.0) * 0.4
		node.draw_circle(center, pulse_size, Color(1, 1, 1, pulse_alpha))


# ============================================================
# Helpers
# ============================================================

## Genere les points d'une forme amande (paupiere)
func _almond_points(center: Vector2, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if w < 1.0 or h < 1.0:
		return pts
	var steps := 36
	# Courbe superieure: pointe gauche → pointe droite
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := -w / 2.0 + t * w
		var y := -h / 2.0 * sin(t * PI)
		pts.append(center + Vector2(x, y))
	# Courbe inferieure: pointe droite → pointe gauche (sans doublons)
	for i in range(steps - 1, 0, -1):
		var t := float(i) / float(steps)
		var x := -w / 2.0 + t * w
		var y := h / 2.0 * sin(t * PI)
		pts.append(center + Vector2(x, y))
	return pts


## Genere des positions aleatoires a l'interieur d'une forme amande
func _random_eye_positions(center: Vector2, w: float, h: float, count: int) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	var attempts := 0
	while positions.size() < count and attempts < count * 20:
		attempts += 1
		var px := randf_range(-w / 2.0, w / 2.0)
		var py := randf_range(-h / 2.0, h / 2.0)
		var norm_x := (px + w / 2.0) / w
		if norm_x <= 0.03 or norm_x >= 0.97:
			continue
		var max_y := h / 2.0 * sin(norm_x * PI)
		if abs(py) <= max_y * 0.9:
			positions.append(center + Vector2(px, py))
	# Fallback si pas assez de positions
	while positions.size() < count:
		positions.append(center + Vector2(randf_range(-15, 15), randf_range(-8, 8)))
	return positions


func _set_open_progress(value: float) -> void:
	_open_progress = value
	if eye_drawer:
		eye_drawer.queue_redraw()
	# Spawn particles as eye opens (every ~5% progress)
	if value > 0.15 and _particle_container:
		_maybe_spawn_eye_particles(value)


func _set_glow_intensity(value: float) -> void:
	_glow_intensity = value
	if eye_drawer:
		eye_drawer.queue_redraw()


# ============================================================
# VFX — Eye Particles
# ============================================================

var _last_particle_progress := 0.0

func _maybe_spawn_eye_particles(progress: float) -> void:
	if progress - _last_particle_progress < 0.04:
		return
	_last_particle_progress = progress

	var count := 2 if progress < 0.6 else 4
	for eye_center in [_left_center, _right_center]:
		for i in range(count):
			_spawn_eye_particle(eye_center, progress)


func _spawn_eye_particle(eye_center: Vector2, progress: float) -> void:
	var p := ColorRect.new()
	var sz := randf_range(2.0, 5.0)
	p.size = Vector2(sz, sz)
	p.color = MerlinVisual.PALETTE.eye_cyan if randf() > 0.3 else MerlinVisual.PALETTE.eye_white
	p.color.a = randf_range(0.4, 0.8)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Start inside the eye shape
	var angle := randf_range(0, TAU)
	var dist := randf_range(0, _eye_width * 0.2)
	p.position = eye_center + Vector2(cos(angle), sin(angle)) * dist

	_particle_container.add_child(p)

	# Fly outward with fade
	var fly_dist := randf_range(60, 180) * (0.5 + progress)
	var target := p.position + Vector2(cos(angle), sin(angle)) * fly_dist
	var duration := randf_range(0.6, 1.4)

	var data := {"node": p, "life": duration, "age": 0.0}
	_eye_particles.append(data)

	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(p, "position", target, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "modulate:a", 0.0, duration * 0.8).set_delay(duration * 0.2)
	tw.tween_property(p, "size", Vector2(sz * 0.3, sz * 0.3), duration)


func _update_eye_particles(delta: float) -> void:
	var to_remove: Array[int] = []
	for i in range(_eye_particles.size()):
		_eye_particles[i].age += delta
		if _eye_particles[i].age >= _eye_particles[i].life:
			to_remove.append(i)
	for i in range(to_remove.size() - 1, -1, -1):
		var idx := to_remove[i]
		var node: ColorRect = _eye_particles[idx].node
		if is_instance_valid(node):
			node.queue_free()
		_eye_particles.remove_at(idx)


func _trigger_shake(intensity: float) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)


func _spawn_flash_burst() -> void:
	## Explosive burst of particles from both eyes on final flash.
	for eye_center in [_left_center, _right_center]:
		for i in range(16):
			var p := ColorRect.new()
			var sz := randf_range(3.0, 8.0)
			p.size = Vector2(sz, sz)
			p.color = MerlinVisual.PALETTE.eye_white if randf() > 0.4 else MerlinVisual.PALETTE.eye_bright
			p.color.a = randf_range(0.6, 1.0)
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.position = eye_center + Vector2(randf_range(-10, 10), randf_range(-10, 10))
			_particle_container.add_child(p)

			var angle := randf_range(0, TAU)
			var fly_dist := randf_range(120, 350)
			var target := p.position + Vector2(cos(angle), sin(angle)) * fly_dist
			var duration := randf_range(0.3, 0.8)

			var tw := create_tween()
			tw.set_parallel(true)
			tw.tween_property(p, "position", target, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			tw.tween_property(p, "modulate:a", 0.0, duration * 0.7).set_delay(duration * 0.3)
			tw.tween_property(p, "size", Vector2.ZERO, duration)
			tw.chain().tween_callback(p.queue_free)


func _wait_for_warmup() -> void:
	# Pulsation douce en attendant le warmup
	var pulse_tween := create_tween().set_loops()
	pulse_tween.tween_method(_set_glow_intensity, 1.0, 1.3, 0.5)
	pulse_tween.tween_method(_set_glow_intensity, 1.3, 1.0, 0.5)

	while not _warmup_done:
		await get_tree().create_timer(0.1).timeout

	pulse_tween.kill()
	_phase_3e_flash()


func _transition_to_menu() -> void:
	boot_complete.emit()
	PixelTransition.transition_to("res://scenes/MenuPrincipal.tscn")
