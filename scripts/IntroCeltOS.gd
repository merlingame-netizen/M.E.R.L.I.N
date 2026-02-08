extends Control

## IntroCeltOS - Animation d'intro stylisee
## Phase 1: Boot rapide (lignes qui apparaissent vite puis fondu)
## Phase 2: Logo CeltOS forme par blocs Tetris tombants
## Phase 3: Logo se deforme en lignes bleues puis yeux ronds bleus

signal boot_complete

const PALETTE := {
	"bg": Color(0.02, 0.025, 0.035),
	"bg_warm": Color(0.04, 0.045, 0.06),
	"text": Color(0.6, 0.7, 0.65),
	"text_dim": Color(0.25, 0.35, 0.30),
	"accent": Color(0.4, 0.85, 0.55),
	"blue": Color(0.35, 0.55, 0.95),
	"blue_light": Color(0.5, 0.7, 1.0),
	"blue_glow": Color(0.4, 0.65, 1.0, 0.4),
	"block": Color(0.25, 0.75, 0.45),
	"block_alt": Color(0.3, 0.6, 0.85),
}

# Lignes de boot rapides (apparaissent vite)
const BOOT_LINES := [
	"BIOS POST check...",
	"Memory: 4096 MB",
	"Loading druid_core.ko",
	"Loading ogham_driver.ko",
	"Ley line scan... FOUND",
	"LLM: Trinity-Nano",
	"Warmup inference...",
	"Systems ready",
]

# Forme du logo en blocs (grille 7x5 pour "CELTOS")
# 1 = bloc present, 0 = vide
const LOGO_GRID := [
	[1,1,1,0,1,1,1,0,1,0,0,0,1,1,1,0,1,1,1,0,1,1,1],
	[1,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,1,0,1,0,1,0,0],
	[1,0,0,0,1,1,0,0,1,0,0,0,0,1,0,0,1,0,1,0,1,1,1],
	[1,0,0,0,1,0,0,0,1,0,0,0,0,1,0,0,1,0,1,0,0,0,1],
	[1,1,1,0,1,1,1,0,1,1,1,0,0,1,0,0,1,1,1,0,1,1,1],
]

var background: ColorRect
var boot_container: Control
var boot_labels: Array[Label] = []
var logo_container: Control
var logo_blocks: Array[ColorRect] = []
var eyes_container: Control
var left_eye: Control
var right_eye: Control
var left_pupil: ColorRect
var right_pupil: ColorRect
var left_glow: ColorRect
var right_glow: ColorRect

var _warmup_done := false
var _phase := 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_warmup_llm_async()
	_start_phase_1()


func _build_ui() -> void:
	# Background sombre
	background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = PALETTE.bg
	add_child(background)

	# Container pour le boot
	boot_container = Control.new()
	boot_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(boot_container)

	# Container pour le logo tetris
	logo_container = Control.new()
	logo_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo_container.modulate.a = 0.0
	add_child(logo_container)

	# Container pour les yeux
	eyes_container = Control.new()
	eyes_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	eyes_container.modulate.a = 0.0
	add_child(eyes_container)


func _warmup_llm_async() -> void:
	var llm_bar = get_node_or_null("/root/LLMStatusBar")
	if llm_bar and llm_bar.has_method("is_ready"):
		while not llm_bar.is_ready():
			await get_tree().create_timer(0.1).timeout
		_warmup_done = true
	else:
		await get_tree().create_timer(2.0).timeout
		_warmup_done = true


## PHASE 1: Boot rapide - lignes qui apparaissent vite puis fondu
func _start_phase_1() -> void:
	_phase = 1
	var viewport_size := get_viewport().get_visible_rect().size
	var start_y := viewport_size.y * 0.3
	var line_height := 22.0
	var line_spacing := 6.0

	# Creer les labels de boot
	for i in range(BOOT_LINES.size()):
		var label := Label.new()
		label.text = BOOT_LINES[i]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		label.position.y = start_y + i * (line_height + line_spacing)
		label.position.x = -200
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", PALETTE.text_dim)
		label.modulate.a = 0.0
		boot_container.add_child(label)
		boot_labels.append(label)

	# Animation: apparition rapide echelonnee
	var tween := create_tween()
	for i in range(boot_labels.size()):
		var delay := i * 0.06
		tween.tween_property(boot_labels[i], "modulate:a", 0.8, 0.08).set_delay(delay)

	# Toutes les lignes deviennent plus visibles brievement
	tween.tween_interval(0.15)
	for label in boot_labels:
		tween.parallel().tween_property(label, "modulate:a", 1.0, 0.1)
		tween.parallel().tween_property(label, "theme_override_colors/font_color", PALETTE.accent, 0.1)

	# Puis fondu rapide
	tween.tween_interval(0.3)
	tween.tween_property(boot_container, "modulate:a", 0.0, 0.4)

	# Transition vers phase 2
	tween.tween_callback(_start_phase_2)


## PHASE 2: Logo CeltOS forme par blocs Tetris tombants
func _start_phase_2() -> void:
	_phase = 2
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size / 2

	# Parametres des blocs
	var block_size := 12.0
	var block_gap := 2.0
	var total_block := block_size + block_gap

	var grid_width: int = LOGO_GRID[0].size()
	var grid_height: int = LOGO_GRID.size()
	var logo_width := grid_width * total_block
	var logo_height := grid_height * total_block

	var start_x := center.x - logo_width / 2
	var start_y := center.y - logo_height / 2

	# Creer les blocs (initialement au-dessus de l'ecran)
	for row in range(grid_height):
		for col in range(grid_width):
			if LOGO_GRID[row][col] == 1:
				var block := ColorRect.new()
				block.size = Vector2(block_size, block_size)

				# Position finale
				var final_x := start_x + col * total_block
				var final_y := start_y + row * total_block

				# Position initiale (au-dessus, hors ecran)
				block.position = Vector2(final_x, -50 - randf() * 200)

				# Couleur alternee pour effet tetris
				if (row + col) % 2 == 0:
					block.color = PALETTE.block
				else:
					block.color = PALETTE.block_alt

				# Stocker la position finale
				block.set_meta("final_pos", Vector2(final_x, final_y))
				block.set_meta("col", col)

				logo_container.add_child(block)
				logo_blocks.append(block)

	# Fade in du container
	var tween := create_tween()
	tween.tween_property(logo_container, "modulate:a", 1.0, 0.2)

	# Animation Tetris: blocs tombent colonne par colonne
	# Trier les blocs par colonne pour un effet de cascade
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

	# Pause pour admirer le logo
	tween.tween_interval(0.6)

	# Flash du logo
	for block in logo_blocks:
		tween.parallel().tween_property(block, "color", PALETTE.accent, 0.15)
	tween.tween_interval(0.1)
	for block in logo_blocks:
		tween.parallel().tween_property(block, "color", PALETTE.blue_light, 0.2)

	# Transition vers phase 3
	tween.tween_interval(0.3)
	tween.tween_callback(_start_phase_3)


## PHASE 3: Logo se deforme en lignes bleues puis yeux ronds
func _start_phase_3() -> void:
	_phase = 3
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size / 2

	# Transformer les blocs en deux groupes (gauche/droite) qui vont former les yeux
	var left_blocks: Array[ColorRect] = []
	var right_blocks: Array[ColorRect] = []

	var mid_col: int = LOGO_GRID[0].size() / 2
	for block in logo_blocks:
		var col: int = block.get_meta("col")
		if col < mid_col:
			left_blocks.append(block)
		else:
			right_blocks.append(block)

	# Positions des yeux
	var eye_spacing := 160.0
	var eye_radius := 45.0
	var left_center := Vector2(center.x - eye_spacing / 2, center.y)
	var right_center := Vector2(center.x + eye_spacing / 2, center.y)

	var tween := create_tween()

	# Les blocs se contractent vers les centres des yeux
	for block in left_blocks:
		var angle := randf() * TAU
		var dist := randf_range(10, 40)
		var target := left_center + Vector2(cos(angle), sin(angle)) * dist
		tween.parallel().tween_property(block, "position", target, 0.5).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(block, "color", PALETTE.blue, 0.4)
		tween.parallel().tween_property(block, "size", Vector2(4, 4), 0.4)

	for block in right_blocks:
		var angle := randf() * TAU
		var dist := randf_range(10, 40)
		var target := right_center + Vector2(cos(angle), sin(angle)) * dist
		tween.parallel().tween_property(block, "position", target, 0.5).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(block, "color", PALETTE.blue, 0.4)
		tween.parallel().tween_property(block, "size", Vector2(4, 4), 0.4)

	# Pause
	tween.tween_interval(0.2)

	# Fade out les blocs, fade in les yeux ronds
	tween.tween_property(logo_container, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_callback(_create_round_eyes.bind(left_center, right_center, eye_radius))
	tween.parallel().tween_property(eyes_container, "modulate:a", 1.0, 0.4)

	# Animation des yeux
	tween.tween_interval(0.3)
	tween.tween_callback(_animate_eyes_open)


func _create_round_eyes(left_pos: Vector2, right_pos: Vector2, radius: float) -> void:
	# Glow gauche
	left_glow = ColorRect.new()
	left_glow.size = Vector2(radius * 4, radius * 4)
	left_glow.position = left_pos - left_glow.size / 2
	left_glow.color = PALETTE.blue_glow
	left_glow.modulate.a = 0.0
	eyes_container.add_child(left_glow)

	# Glow droit
	right_glow = ColorRect.new()
	right_glow.size = Vector2(radius * 4, radius * 4)
	right_glow.position = right_pos - right_glow.size / 2
	right_glow.color = PALETTE.blue_glow
	right_glow.modulate.a = 0.0
	eyes_container.add_child(right_glow)

	# Oeil gauche (cercle simule avec Control + draw)
	left_eye = Control.new()
	left_eye.position = left_pos
	left_eye.set_meta("radius", 0.0)
	left_eye.set_meta("target_radius", radius)
	left_eye.set_meta("color", PALETTE.blue)
	left_eye.connect("draw", _draw_eye.bind(left_eye))
	eyes_container.add_child(left_eye)

	# Pupille gauche
	left_pupil = ColorRect.new()
	left_pupil.size = Vector2(12, 12)
	left_pupil.position = left_pos - left_pupil.size / 2
	left_pupil.color = PALETTE.bg
	left_pupil.modulate.a = 0.0
	eyes_container.add_child(left_pupil)

	# Oeil droit
	right_eye = Control.new()
	right_eye.position = right_pos
	right_eye.set_meta("radius", 0.0)
	right_eye.set_meta("target_radius", radius)
	right_eye.set_meta("color", PALETTE.blue)
	right_eye.connect("draw", _draw_eye.bind(right_eye))
	eyes_container.add_child(right_eye)

	# Pupille droite
	right_pupil = ColorRect.new()
	right_pupil.size = Vector2(12, 12)
	right_pupil.position = right_pos - right_pupil.size / 2
	right_pupil.color = PALETTE.bg
	right_pupil.modulate.a = 0.0
	eyes_container.add_child(right_pupil)


func _draw_eye(eye: Control) -> void:
	var radius: float = eye.get_meta("radius", 0.0)
	var color: Color = eye.get_meta("color", PALETTE.blue)
	if radius > 0:
		eye.draw_circle(Vector2.ZERO, radius, color)
		# Bordure plus claire
		eye.draw_arc(Vector2.ZERO, radius, 0, TAU, 64, PALETTE.blue_light, 2.0)


func _animate_eyes_open() -> void:
	var target_radius: float = left_eye.get_meta("target_radius", 45.0)

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_ELASTIC)
	tween.set_ease(Tween.EASE_OUT)

	# Animer le rayon des yeux
	tween.tween_method(_set_eye_radius.bind(left_eye), 0.0, target_radius, 0.6)
	tween.parallel().tween_method(_set_eye_radius.bind(right_eye), 0.0, target_radius, 0.6)

	# Glow s'intensifie
	tween.parallel().tween_property(left_glow, "modulate:a", 0.6, 0.5)
	tween.parallel().tween_property(right_glow, "modulate:a", 0.6, 0.5)

	# Pupilles apparaissent
	tween.tween_property(left_pupil, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(right_pupil, "modulate:a", 1.0, 0.2)

	# Pulsation du glow
	tween.tween_property(left_glow, "modulate:a", 0.8, 0.15)
	tween.parallel().tween_property(right_glow, "modulate:a", 0.8, 0.15)
	tween.tween_property(left_glow, "modulate:a", 0.5, 0.15)
	tween.parallel().tween_property(right_glow, "modulate:a", 0.5, 0.15)

	# Hold
	tween.tween_interval(0.5)

	# Attendre le warmup si necessaire
	if not _warmup_done:
		tween.tween_callback(_wait_for_warmup)
	else:
		tween.tween_callback(_finish_intro)


func _set_eye_radius(value: float, eye: Control) -> void:
	eye.set_meta("radius", value)
	eye.queue_redraw()


func _wait_for_warmup() -> void:
	# Pulsation en attendant
	var tween := create_tween()
	tween.set_loops()
	tween.tween_property(left_glow, "modulate:a", 0.7, 0.4)
	tween.parallel().tween_property(right_glow, "modulate:a", 0.7, 0.4)
	tween.tween_property(left_glow, "modulate:a", 0.4, 0.4)
	tween.parallel().tween_property(right_glow, "modulate:a", 0.4, 0.4)

	while not _warmup_done:
		await get_tree().create_timer(0.1).timeout

	tween.kill()
	_finish_intro()


func _finish_intro() -> void:
	# Flash blanc
	var flash := ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color.WHITE
	flash.modulate.a = 0.0
	add_child(flash)

	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 1.0, 0.15)
	tween.tween_callback(_transition_to_menu)


func _transition_to_menu() -> void:
	boot_complete.emit()
	get_tree().change_scene_to_file("res://scenes/MenuPrincipal.tscn")
