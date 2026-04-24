extends Control

## IntroTutorial — Deterministic onboarding scene (no LLM)
## Phase 1: Lore presentation (5 beats)
## Phase 2: Express scripted playthrough (3 cards via TutorialCardLayer)
## Phase 3: Transition to HubAntre with guided tour flag
## Only shown on first playthrough (GameManager.flags.tutorial_done == false)

# ═══════════════════════════════════════════════════════════════════════════════
# CONSTANTS
# ═══════════════════════════════════════════════════════════════════════════════

enum Phase { LORE_WORLD, TUTORIAL_PLAY, TRANSITION }

const SCENE_HUB := "res://scenes/MerlinCabinHub.tscn"
const BEAT_HEADER_SIZE := 28
const BEAT_BODY_SIZE := 20
const BREATHE_PERIOD := 4.0

# Lore beats — static text, deterministic
const LORE_BEATS: Array[Dictionary] = [
	{
		"header": "LE MONDE",
		"lines": [
			"Bretagne celtique. L'an que personne ne compte plus.",
			"La Membrane entre les mondes s'amincie.",
			"La brume monte. Les villages s'effacent.",
			"Les druides s'epuisent a repousser l'inertie.",
			"Tu es arrive au bon moment — ou au pire.",
		],
	},
	{
		"header": "MERLIN",
		"lines": [
			"Je suis Merlin. Druide, conteur, vieux fou.",
			"Je narrerai chaque choix que tu feras.",
			"Je ne te mentirai pas. Souvent.",
			"Mon role : te guider, pas te sauver.",
			"Ca, c'est ton travail.",
		],
	},
	{
		"header": "LE VOYAGEUR",
		"lines": [
			"Tu es le Voyageur. Tu n'as pas de nom. Pas encore.",
			"Tu traverses les biomes, tu fais des choix.",
			"La brume t'observe. Les arbres se souviennent.",
		],
	},
	{
		"header": "LES RUNES",
		"lines": [
			"Tu decouvriras des Runes — des symboles anciens aux pouvoirs oublies.",
			"Chaque Rune debloquee ouvre de nouvelles possibilites.",
			"Les 18 Runes sont des clefs. Tu les trouveras.",
		],
	},
]

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var _phase: Phase = Phase.LORE_WORLD
var _beat_idx: int = 0
var _advance_requested: bool = false
var _skip_all: bool = false
var _breathe_t: float = 0.0
var _hint_blink_tween: Tween

# Nodes
var _bg: ColorRect
var _mist: ColorRect
var _content_box: VBoxContainer
var _header_label: Label
var _body_labels: Array[Label] = []
var _continue_hint: Label
var _skip_button: Button
var _card_layer: TutorialCardLayer

# Ambient particles
var _particles: Array[Dictionary] = []
var _particle_t: float = 0.0
const MAX_PARTICLES := 20

# ═══════════════════════════════════════════════════════════════════════════════
# LIFECYCLE
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_build_scene()
	_run_tutorial.call_deferred()


func _process(delta: float) -> void:
	_breathe_t += delta
	# Mist breathing
	if _mist:
		_mist.modulate.a = 0.05 + sin(_breathe_t / BREATHE_PERIOD * TAU) * 0.08

	# Ambient particles
	_particle_t += delta
	if _particle_t > 0.25 and _particles.size() < MAX_PARTICLES:
		_particle_t = 0.0
		_spawn_particle()
	_update_particles(delta)
	queue_redraw()


func _draw() -> void:
	# Draw ambient particles
	for p: Dictionary in _particles:
		var pos: Vector2 = p["pos"]
		var c: Color = p["color"]
		c.a = p["alpha"]
		draw_rect(Rect2(pos.x, pos.y, 2.0, 2.0), c)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				_advance_requested = true
				get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				_skip_all = true
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_advance_requested = true
		get_viewport().set_input_as_handled()


# ═══════════════════════════════════════════════════════════════════════════════
# SCENE CONSTRUCTION
# ═══════════════════════════════════════════════════════════════════════════════

func _build_scene() -> void:
	# Background
	_bg = ColorRect.new()
	_bg.color = MerlinVisual.CRT_PALETTE.bg_deep
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	# Mist layer
	_mist = ColorRect.new()
	_mist.color = MerlinVisual.CRT_PALETTE.mist
	_mist.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mist.modulate.a = 0.0
	add_child(_mist)

	# Content box (centered)
	_content_box = VBoxContainer.new()
	_content_box.add_theme_constant_override("separation", 8)
	add_child(_content_box)

	# Header
	_header_label = Label.new()
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_override("font", MerlinVisual.get_font("title"))
	_header_label.add_theme_font_size_override("font_size", BEAT_HEADER_SIZE)
	_header_label.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.amber)
	_content_box.add_child(_header_label)

	# Separator
	var sep := Label.new()
	sep.text = "--- # ---"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sep.add_theme_font_override("font", MerlinVisual.get_font("body"))
	sep.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE)
	sep.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.border_bright)
	_content_box.add_child(sep)

	# Continue hint
	_continue_hint = Label.new()
	_continue_hint.text = "[espace] Continuer"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_continue_hint.add_theme_font_override("font", MerlinVisual.get_font("body"))
	_continue_hint.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE)
	_continue_hint.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	_continue_hint.visible = false
	add_child(_continue_hint)

	# Skip button (top-right)
	_skip_button = Button.new()
	_skip_button.text = "Passer >"
	_skip_button.add_theme_font_override("font", MerlinVisual.get_font("body"))
	_skip_button.add_theme_font_size_override("font_size", MerlinVisual.CAPTION_SIZE)
	MerlinVisual.apply_button_theme(_skip_button)
	_skip_button.pressed.connect(func() -> void: _skip_all = true)
	add_child(_skip_button)

	_layout_scene()


func _layout_scene() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var content_w: float = minf(600.0, vp.x * 0.85)

	_content_box.position = Vector2((vp.x - content_w) * 0.5, vp.y * 0.2)
	_content_box.size = Vector2(content_w, 0)

	_continue_hint.position = Vector2(0, vp.y - 50.0)
	_continue_hint.size = Vector2(vp.x, 30.0)

	_skip_button.position = Vector2(vp.x - 120.0, 16.0)
	_skip_button.size = Vector2(100.0, 32.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if _content_box:
			_layout_scene()


# ═══════════════════════════════════════════════════════════════════════════════
# TUTORIAL FLOW
# ═══════════════════════════════════════════════════════════════════════════════

func _run_tutorial() -> void:
	await get_tree().process_frame
	_layout_scene()

	# Phase 1: Lore beats
	_phase = Phase.LORE_WORLD
	for i in LORE_BEATS.size():
		if _skip_all:
			break
		_beat_idx = i
		await _present_lore_beat(LORE_BEATS[i])
		if not is_inside_tree():
			return

	# Phase 2: Express playthrough
	if not _skip_all and is_inside_tree():
		_phase = Phase.TUTORIAL_PLAY
		await _run_express_playthrough()

	# Phase 3: Transition to Hub
	if is_inside_tree():
		_transition_to_hub()


func _present_lore_beat(beat: Dictionary) -> void:
	if not is_inside_tree():
		return

	_advance_requested = false
	_continue_hint.visible = false

	# Clear previous body labels
	for lbl: Label in _body_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_body_labels.clear()

	# Header reveal
	_header_label.text = str(beat.get("header", ""))
	_header_label.modulate.a = 0.0
	var htw := create_tween()
	htw.tween_property(_header_label, "modulate:a", 1.0, 0.3)
	await htw.finished
	if not is_inside_tree():
		return

	SFXManager.play("boot_line")

	# Body lines — typewriter one by one
	var lines: Array = beat.get("lines", [])
	for line_text: String in lines:
		if _skip_all or not is_inside_tree():
			break

		var lbl := Label.new()
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_override("font", MerlinVisual.get_font("body"))
		lbl.add_theme_font_size_override("font_size", BEAT_BODY_SIZE)

		lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)

		_content_box.add_child(lbl)
		_body_labels.append(lbl)

		if line_text.length() == 0:
			# Empty line = spacer
			lbl.text = " "
			await get_tree().create_timer(0.1).timeout
		else:
			await _typewriter(lbl, line_text)

		if not is_inside_tree():
			return

	if not is_inside_tree():
		return

	# Show continue hint with blink
	_continue_hint.visible = true
	_continue_hint.modulate.a = 1.0
	_start_hint_blink()

	# Wait for advance
	await _wait_for_advance()

	# Dissolve content
	var dtw := create_tween()
	dtw.tween_property(_content_box, "modulate:a", 0.0, 0.3)
	dtw.parallel().tween_property(_continue_hint, "modulate:a", 0.0, 0.2)
	await dtw.finished
	if not is_inside_tree():
		return

	# Reset
	_content_box.modulate.a = 1.0
	_continue_hint.visible = false
	_continue_hint.modulate.a = 1.0

	await get_tree().create_timer(0.2).timeout


# ═══════════════════════════════════════════════════════════════════════════════
# EXPRESS PLAYTHROUGH (Phase 2)
# ═══════════════════════════════════════════════════════════════════════════════

func _run_express_playthrough() -> void:
	if not is_inside_tree():
		return

	# Clear lore content
	for lbl: Label in _body_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_body_labels.clear()
	_header_label.text = ""

	# Show transition text
	_header_label.text = "PARTIE EXPRESS"
	_header_label.modulate.a = 0.0
	var htw := create_tween()
	htw.tween_property(_header_label, "modulate:a", 1.0, 0.3)
	await htw.finished
	if not is_inside_tree():
		return

	var intro_lbl := Label.new()
	intro_lbl.text = "3 cartes. Tes premiers choix. Effets visibles."
	intro_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_lbl.add_theme_font_override("font", MerlinVisual.get_font("body"))
	intro_lbl.add_theme_font_size_override("font_size", MerlinVisual.BODY_SMALL)
	intro_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor_dim)
	_content_box.add_child(intro_lbl)
	_body_labels.append(intro_lbl)

	SFXManager.play("magic_reveal")

	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree():
		return

	# Dissolve intro
	var dtw := create_tween()
	dtw.tween_property(_content_box, "modulate:a", 0.0, 0.3)
	await dtw.finished
	if not is_inside_tree():
		return
	_content_box.modulate.a = 1.0
	_content_box.visible = false

	# Hide header/sep during card layer
	_header_label.visible = false

	# Create TutorialCardLayer
	_card_layer = TutorialCardLayer.new()
	_card_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_card_layer)

	# Wait for completion
	await _card_layer.playthrough_complete

	# Cleanup
	if is_instance_valid(_card_layer):
		_card_layer.queue_free()
	_card_layer = null

	# Restore content box
	_content_box.visible = true
	_header_label.visible = true

	# Show closing text
	for lbl: Label in _body_labels:
		if is_instance_valid(lbl):
			lbl.queue_free()
	_body_labels.clear()

	_header_label.text = "PRET"
	_header_label.modulate.a = 0.0
	var ctw := create_tween()
	ctw.tween_property(_header_label, "modulate:a", 1.0, 0.3)
	await ctw.finished
	if not is_inside_tree():
		return

	var ready_lbl := Label.new()
	ready_lbl.text = "Tu connais les regles. Direction l'Antre."
	ready_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ready_lbl.add_theme_font_override("font", MerlinVisual.get_font("body"))
	ready_lbl.add_theme_font_size_override("font_size", BEAT_BODY_SIZE)
	ready_lbl.add_theme_color_override("font_color", MerlinVisual.CRT_PALETTE.phosphor)
	_content_box.add_child(ready_lbl)
	_body_labels.append(ready_lbl)
	MerlinVisual.phosphor_reveal(ready_lbl, 0.5)

	_continue_hint.visible = true
	_start_hint_blink()
	await _wait_for_advance()


# ═══════════════════════════════════════════════════════════════════════════════
# TRANSITION
# ═══════════════════════════════════════════════════════════════════════════════

func _transition_to_hub() -> void:
	var gm := get_node_or_null("/root/GameManager")
	if gm:
		gm.flags["tutorial_done"] = true
		gm.flags["hub_tour_pending"] = true

	SFXManager.play("scene_transition")

	# Fade out everything
	var ftw := create_tween()
	ftw.tween_property(self, "modulate:a", 0.0, 0.4)
	await ftw.finished

	PixelTransition.transition_to(SCENE_HUB)


# ═══════════════════════════════════════════════════════════════════════════════
# HELPERS
# ═══════════════════════════════════════════════════════════════════════════════

func _typewriter(label: Label, full_text: String) -> void:
	label.text = ""
	for i in range(full_text.length()):
		if _skip_all or _advance_requested or not is_inside_tree():
			label.text = full_text
			return
		label.text += full_text[i]
		var ch: String = full_text[i]
		var delay: float = MerlinVisual.TW_DELAY
		if ch in ".!?;:,":
			delay = MerlinVisual.TW_PUNCT_DELAY
		await get_tree().create_timer(delay).timeout


func _wait_for_advance() -> void:
	_advance_requested = false
	while is_inside_tree() and not _advance_requested and not _skip_all:
		await get_tree().process_frame
	_advance_requested = false
	if is_inside_tree():
		await get_tree().process_frame


func _start_hint_blink() -> void:
	if not is_inside_tree() or not _continue_hint:
		return
	if _hint_blink_tween:
		_hint_blink_tween.kill()
	_hint_blink_tween = create_tween().set_loops()
	_hint_blink_tween.tween_property(_continue_hint, "modulate:a", 0.3, 0.6)
	_hint_blink_tween.tween_property(_continue_hint, "modulate:a", 1.0, 0.6)


func _spawn_particle() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var colors: Array[Color] = [
		MerlinVisual.CRT_PALETTE.phosphor_dim,
		MerlinVisual.CRT_PALETTE.cyan_dim,
		MerlinVisual.CRT_PALETTE.amber_dim,
	]
	_particles.append({
		"pos": Vector2(randf() * vp.x, vp.y + 4.0),
		"vel": Vector2(randf_range(-8.0, 8.0), randf_range(-25.0, -15.0)),
		"color": colors[randi() % colors.size()],
		"alpha": randf_range(0.15, 0.35),
		"life": randf_range(3.0, 6.0),
		"age": 0.0,
		"phase": randf() * TAU,
	})


func _update_particles(delta: float) -> void:
	var i := _particles.size() - 1
	while i >= 0:
		var p: Dictionary = _particles[i]
		p["age"] = float(p["age"]) + delta
		if float(p["age"]) >= float(p["life"]):
			_particles.remove_at(i)
			i -= 1
			continue
		var pos: Vector2 = p["pos"]
		var vel: Vector2 = p["vel"]
		pos.x += vel.x * delta + sin(float(p["age"]) * 2.0 + float(p["phase"])) * 0.3
		pos.y += vel.y * delta
		p["pos"] = pos
		var life_pct: float = float(p["age"]) / float(p["life"])
		p["alpha"] = float(p["alpha"]) * (1.0 - life_pct)
		i -= 1
