extends Control

## IntroCeltOS - CRT Terminal Boot Sequence
## Phase 1: Boot lines (rapid terminal output)
## Phase 2: CeltOS logo (Tetris blocks falling)
## Phase 3: Loading bar + transition to MenuPrincipal

const BOOT_LINES := [
	"BIOS POST check...",
	"Memory: 4096 MB",
	"Loading druid_core.ko",
	"Loading ogham_driver.ko",
	"Ley line scan... FOUND",
	"LLM: M.E.R.L.I.N.-3B",
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
var loading_container: Control
var loading_bar: ColorRect
var loading_bg: ColorRect
var loading_label: Label

# --- State ---
var _warmup_done := false
var _phase := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_build_ui()
	_warmup_llm_async()
	MusicManager.play_intro_music()
	_start_phase_1()


func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _build_ui() -> void:
	background = ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = MerlinVisual.CRT_PALETTE.bg_deep
	add_child(background)

	boot_container = Control.new()
	boot_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(boot_container)

	logo_container = Control.new()
	logo_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo_container.modulate.a = 0.0
	add_child(logo_container)

	loading_container = Control.new()
	loading_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	loading_container.modulate.a = 0.0
	add_child(loading_container)


func _warmup_llm_async() -> void:
	await get_tree().create_timer(2.0).timeout
	_warmup_done = true


# ============================================================
# PHASE 1 — Boot rapide (CRT terminal lines)
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
		label.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SMALL)
		label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
		label.add_theme_constant_override("outline_size", MerlinVisual.OUTLINE_SIZE)
		label.add_theme_color_override("font_outline_color", MerlinVisual.OUTLINE_COLOR)
		label.modulate.a = 0.0
		boot_container.add_child(label)
		boot_labels.append(label)

	var tween := create_tween()
	for i in range(boot_labels.size()):
		var delay := i * 0.06
		tween.tween_property(boot_labels[i], "modulate:a", 0.8, 0.08).set_delay(delay)
		tween.tween_callback(func() -> void: SFXManager.play_varied("boot_line", 0.1)).set_delay(delay)

	tween.tween_interval(0.15)
	tween.tween_callback(func() -> void: SFXManager.play("boot_confirm"))
	for label in boot_labels:
		tween.parallel().tween_property(label, "modulate:a", 1.0, 0.1)
		tween.parallel().tween_property(label, "theme_override_colors/font_color", MerlinVisual.CRT_PALETTE.amber, 0.1)

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
					block.color = MerlinVisual.CRT_PALETTE.phosphor
				else:
					block.color = MerlinVisual.CRT_PALETTE.phosphor_bright

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
		tween.parallel().tween_callback(
			func() -> void: SFXManager.play_varied("block_land", 0.1)
		).set_delay(delay + 0.35)

	tween.tween_interval(0.6)

	# Flash du logo puis transition vers amber
	tween.tween_callback(func() -> void: SFXManager.play("flash_boom"))
	for block in logo_blocks:
		tween.parallel().tween_property(block, "color", MerlinVisual.CRT_PALETTE.amber, 0.15)
	tween.tween_interval(0.1)
	for block in logo_blocks:
		tween.parallel().tween_property(block, "color", MerlinVisual.CRT_PALETTE.phosphor, 0.2)

	tween.tween_interval(0.5)
	tween.tween_callback(_start_phase_3)


# ============================================================
# PHASE 3 — Loading bar + transition to MenuPrincipal
# ============================================================

func _start_phase_3() -> void:
	_phase = 3
	var vp := get_viewport().get_visible_rect().size
	var center := vp / 2

	# Fade logo up slightly
	var logo_tween := create_tween()
	logo_tween.tween_property(logo_container, "position:y", -40.0, 0.4).set_trans(Tween.TRANS_SINE)

	# Build loading bar UI
	var bar_width := 320.0
	var bar_height := 12.0
	var bar_x := center.x - bar_width / 2.0
	var bar_y := center.y + 60.0

	# Label "Initialisation..."
	loading_label = Label.new()
	loading_label.text = "Initialisation du systeme druidique..."
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	loading_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	loading_label.position = Vector2(-160, bar_y - 30)
	loading_label.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE)
	loading_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	loading_label.add_theme_constant_override("outline_size", MerlinVisual.OUTLINE_SIZE)
	loading_label.add_theme_color_override("font_outline_color", MerlinVisual.OUTLINE_COLOR)
	loading_container.add_child(loading_label)

	# Background bar
	loading_bg = ColorRect.new()
	loading_bg.position = Vector2(bar_x, bar_y)
	loading_bg.size = Vector2(bar_width, bar_height)
	loading_bg.color = MerlinVisual.CRT_PALETTE.bg_dark
	loading_container.add_child(loading_bg)

	# Border
	var border := ColorRect.new()
	border.position = Vector2(bar_x - 1, bar_y - 1)
	border.size = Vector2(bar_width + 2, bar_height + 2)
	border.color = MerlinVisual.CRT_PALETTE.border
	loading_container.add_child(border)
	loading_container.move_child(border, 0)

	# Fill bar (starts at 0 width)
	loading_bar = ColorRect.new()
	loading_bar.position = Vector2(bar_x, bar_y)
	loading_bar.size = Vector2(0, bar_height)
	loading_bar.color = MerlinVisual.CRT_PALETTE.phosphor
	loading_container.add_child(loading_bar)

	# Show loading container
	var tween := create_tween()
	tween.tween_property(loading_container, "modulate:a", 1.0, 0.3)

	# Animate loading bar fill
	tween.tween_property(loading_bar, "size:x", bar_width * 0.3, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		loading_label.text = "Chargement des runes oghamiques..."
	)
	tween.tween_property(loading_bar, "size:x", bar_width * 0.6, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		loading_label.text = "Connexion aux lignes de ley..."
	)
	tween.tween_property(loading_bar, "size:x", bar_width * 0.85, 0.4).set_trans(Tween.TRANS_SINE)

	# Wait for warmup if needed
	tween.tween_callback(_wait_then_complete.bind(bar_width))


func _wait_then_complete(bar_width: float) -> void:
	if not _warmup_done:
		loading_label.text = "Eveil de M.E.R.L.I.N. ..."
		while not _warmup_done:
			await get_tree().create_timer(0.1).timeout

	# Complete the bar
	loading_label.text = "Systeme pret."
	var tween := create_tween()
	tween.tween_property(loading_bar, "size:x", bar_width, 0.3).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		loading_bar.color = MerlinVisual.CRT_PALETTE.amber
		SFXManager.play("boot_confirm")
	)
	tween.tween_interval(0.4)

	# Fade out everything
	tween.tween_property(loading_container, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(logo_container, "modulate:a", 0.0, 0.3)
	tween.tween_interval(0.2)
	tween.tween_callback(_transition_to_menu)


func _transition_to_menu() -> void:
	PixelTransition.transition_to("res://scenes/MenuPrincipal.tscn")
