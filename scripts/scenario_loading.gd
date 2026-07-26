## ═══════════════════════════════════════════════════════════════════════════════
## ScenarioLoading — Phase 2.1 scenario pre-game flow (v7.7, 2026-05-15 part 23)
## ═══════════════════════════════════════════════════════════════════════════════
## Scène dédiée chargée entre BoardNarration biome-pick et le démarrage du run.
## Réf spec : task_plan.md v7.7 Phase 2.1 SPEC (8 AskUserQuestion answers locked).
##
## Flow runtime :
##   1. _ready : lit biome_id depuis MerlinStore.state.run.current_biome
##   2. ScenarioPlanner.generate_titles(biome_id) → 3 titres + ogham glyphs
##   3. Affiche 3 parchemins 3D (unfurl + ink-write) — placeholder 2D pour foundation
##   4. Player click → planner.generate_skeleton(biome_id, chosen_title)
##   5. Quill phase : CPUParticles3D + Merlin speech-bar + TTS robot voice (sub-iter)
##   6. Skeleton complete → Store dispatch SET_SCENARIO_SKELETON
##   7. change_scene_to_file → res://scenes/BoardNarration.tscn
##
## Cascade fallback : si LLM indisponible, planner retombe sur FALLBACK_SKELETONS
## (8 biomes shipped Phase 2.6). User flow never blocks.
##
## Phase 2.1.1 + 2.1.2 + 2.1.8 + 2.1.9 livrés ici (foundation).
## Phase 2.1.3-2.1.7 (parchemins 3D, speech-bar shader, TTS, particles) en sub-iter.
## ═══════════════════════════════════════════════════════════════════════════════

extends Node3D

## v7.7.2 — Can run in two modes :
##   - Standalone (legacy) : scene-changed via change_scene_to_file. _return_to_board
##     fires another change_scene_to_file back to BoardNarration.
##   - Sub-scene (v7.7.2)  : instantiated as child of BoardNarration. The parent
##     listens to skeleton_dispatched signal, queue_frees this child, and continues
##     its own flow. Detected via skeleton_dispatched.get_connections().
signal skeleton_dispatched  ## Emitted right before _return_to_board when skeleton is ready (Store.dispatch done)

const FALLBACK_BIOME := "foret_broceliande"

# v7.7.21 — Unified DigitalPickerCard replaces 3D parchments.
const DIGITAL_PICKER_CARD_SCRIPT := preload("res://scripts/ui/digital_picker_card.gd")

# v7.7.23 — Parchment scroll for lore-aware intro display (LLM #2 output).
const PARCHMENT_SCROLL_SCRIPT := preload("res://scripts/ui/parchment_scroll.gd")

# v7.7.21 — Fallback body teasers per scenario tier when the LLM doesn't provide
# a `body` field (the planner currently returns only {title, ogham}). Ordered to
# evoke ascending tension : discovery → revelation → climax.
const SCENARIO_BODY_FALLBACKS: Array = [
	"Un premier pas, un présage léger.\nLa voie s'ouvre sans bruit.",
	"Le sentier se trouble. Les Oghams\nmurmurent un avertissement.",
	"Le seuil est là. Tu n'en reviendras\npas le même, druide.",
]

var _planner: ScenarioPlanner = null
var _merlin_ai: Node = null
var _rag: Node = null
var _store: Node = null
var _biome_id: String = ""
var _titles: Array = []           # [{title: String, ogham: String, body?: String}, ×3]
var _chosen_title: String = ""
var _skeleton: Dictionary = {}

var _ui_layer: CanvasLayer = null
var _info_label: Label = null     # foundation : displays current step textually
var _camera: Camera3D = null
# v7.7.17 — Merlin sound bar appears during LLM writing (user request).
const MERLIN_SOUND_BAR_SCRIPT := preload("res://scripts/board_narration/merlin_sound_bar.gd")
var _merlin_sound_bar: Node3D = null

# v7.7.21 — Unified 2D picker cards (3 instances) replace 3D parchment meshes.
# DigitalPickerCard handles its own hover/click/animation — no per-frame unproject.
var _picker_cards: Array = []     # Array of DigitalPickerCard
var _picker_container: HBoxContainer = null
var _pending_pick: int = -1       # set by _on_scenario_card_picked, polled by _run_flow
var _aborted: bool = false        # v7.7.1 C4 — set by back button to break the pick wait loop


func _ready() -> void:
	_resolve_autoloads()
	_biome_id = _read_biome_from_store()
	_setup_world()
	_setup_ui()
	_planner = ScenarioPlanner.new(_merlin_ai, _rag)
	# Foundation flow : titles → auto-pick first → skeleton → dispatch → scene change.
	# Sub-iteration 2.1.3+ replaces auto-pick with parchemin UI player interaction.
	_run_flow()


func _resolve_autoloads() -> void:
	_merlin_ai = get_node_or_null("/root/MerlinAI")
	_rag = get_node_or_null("/root/RAGManager")
	_store = get_node_or_null("/root/MerlinStore")


func _read_biome_from_store() -> String:
	if _store == null or not (_store.get("state") is Dictionary):
		push_warning("[ScenarioLoading] No store available — fallback biome '%s'" % FALLBACK_BIOME)
		return FALLBACK_BIOME
	var state: Dictionary = _store.state
	var run: Dictionary = state.get("run", {})
	var b: String = str(run.get("current_biome", FALLBACK_BIOME))
	if b == "":
		b = FALLBACK_BIOME
	return b


func _setup_world() -> void:
	# Minimal 3D world : key light + camera. Parchemins 3D land here in 2.1.3.
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.light_color = Color("#f0c878")  # warm amber per bible §23 mood
	key.light_energy = 1.4
	add_child(key)
	# look_at_from_position requires the node to be inside the tree (reads
	# global transform). Call AFTER add_child to avoid "Node not inside tree" ERROR.
	key.look_at_from_position(Vector3(0.5, 4.5, 1.5), Vector3.ZERO, Vector3.UP)

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.current = true
	_camera.position = Vector3(0.0, 2.0, 4.5)
	add_child(_camera)
	# look_at requires the node to be inside the tree — call AFTER add_child.
	_camera.look_at(Vector3(0.0, 1.0, 0.0), Vector3.UP)


func _setup_ui() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	_ui_layer.layer = 110
	add_child(_ui_layer)

	_info_label = Label.new()
	_info_label.name = "InfoLabel"
	_info_label.anchor_left = 0.0
	_info_label.anchor_right = 1.0
	_info_label.anchor_top = 0.4
	_info_label.anchor_bottom = 0.6
	_info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 28)
	_info_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.82))
	_info_label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.02, 1.0))
	_info_label.add_theme_constant_override("outline_size", 4)   # v7.7.18 charter : was 8, max 4
	_info_label.text = "Le sage Merlin consulte les Oghams…"
	_ui_layer.add_child(_info_label)

	# v7.7.19 — Charter-compliant back button via MerlinVisual.digital_button factory.
	# Was bare Button.new() + manual color overrides (no border, no panel structure).
	var back_btn: Button = MerlinVisual.digital_button("← Retour Hub", "secondary")
	back_btn.name = "BackBtn"
	back_btn.anchor_left = 0.02
	back_btn.anchor_top = 0.02
	back_btn.offset_right = 220.0
	back_btn.offset_bottom = 56.0
	back_btn.pressed.connect(_on_back_to_hub_pressed)
	_ui_layer.add_child(back_btn)


# ═════════ Foundation flow (Phase 2.1.1+2.1.2+2.1.8+2.1.9) ═══════════════════

func _run_flow() -> void:
	# v7.7.24 STRICT MODE — Pre-flight check : the LLM brain MUST be available.
	# Per user mandate « si LLM down, on bloque » : no silent fallback. If the
	# brain is unreachable, show an offline parchment + back to Hub (clean UX
	# rather than degraded LLM-less content).
	if _merlin_ai == null or not _merlin_ai.has_method("is_brain_ready") or not _merlin_ai.is_brain_ready():
		# Allow capture/smoke tests to bypass via env var (CI doesn't have Ollama).
		var capture_mode: bool = OS.get_environment("MERLIN_CAPTURE_DIR") != "" \
			or OS.get_environment("MERLIN_AUTOPLAY") == "1"
		if not capture_mode:
			_show_brain_offline_and_return()
			return
		# Capture/smoke : fall through to legacy fallback path.
	# v7.7.17 — Spawn Merlin BEFORE the LLM call so the player sees him
	# "thinking" / "writing" during the wait (user request : « M.E.R.L.I.N qui
	# doit apparaitre à ce moment (la bouche qui parle etc) »).
	_spawn_merlin_for_writing()
	# Step 1 : generate 3 titles
	_info_label.text = "Le sage Merlin consulte les Oghams…\n(génération des titres)"
	_titles = await _planner.generate_titles(_biome_id)
	if _aborted:
		return
	if _titles.is_empty():
		# v7.7.1 C4 — LLM cascade fully exhausted (Ollama down + fallback bug).
		# Dispatch a minimal skeleton so BoardNarration's idempotency guard prevents
		# infinite ScenarioLoading re-entry (board would otherwise see no skeleton
		# and re-launch this scene, looping forever).
		push_warning("[ScenarioLoading] No titles returned — using fallback skeleton")
		_dispatch_fallback_skeleton()
		_return_to_board()
		return

	# v7.7.21 — Build 3 unified DigitalPickerCard (replaces 3D parchments).
	# Cards self-handle hover/click/animations — no per-frame unproject loop.
	_info_label.text = "Choisis ta voie…"
	_build_scenario_cards(_titles)
	# Wait for click — _on_scenario_card_picked sets _pending_pick to chosen index.
	# v7.7.1 C4 — also break on _aborted (back button) to prevent infinite poll.
	_pending_pick = -1
	# Autoplay (MERLIN_AUTOPLAY=1) : en headless personne ne clique, et cette
	# boucle d'attente ne se termine jamais — le flow restait bloque ici, avant
	# meme d'atteindre la boucle de run. On choisit le premier titre apres un
	# court delai, comme le fait deja `_run_live_loop` pour les options de carte.
	if OS.get_environment("MERLIN_AUTOPLAY") == "1" and not _titles.is_empty():
		await get_tree().create_timer(1.0).timeout
		if _pending_pick < 0:
			_pending_pick = 0
			push_warning("[ScenarioLoading] AUTOPLAY — titre auto-choisi : %s"
				% str((_titles[0] as Dictionary).get("title", "")))
	while _pending_pick < 0 and not _aborted:
		await get_tree().process_frame
	if _aborted:
		return
	# Record choice — chosen card already played its own selection animation
	# (mark_chosen → pulse + crimson flash) via DigitalPickerCard internal logic.
	var chosen: Dictionary = _titles[_pending_pick] as Dictionary
	_chosen_title = str(chosen.get("title", ""))
	# Dim unselected cards so the chosen one stands out before scene transition.
	for i in range(_picker_cards.size()):
		var card: Control = _picker_cards[i] as Control
		if card == null or not is_instance_valid(card):
			continue
		if i != _pending_pick and card.has_method("dim_unselected"):
			card.call("dim_unselected")
	await get_tree().create_timer(0.6).timeout

	# v7.7.23 — Step 2.5 : LLM #2 generates lore intro, parchment unrolls + typewriter.
	# Sequential : intro → parchment cycle (~12s read) → skeleton. The player's
	# read-time naturally absorbs the next LLM call's latency without juggling
	# parallel awaits in GDScript.
	_info_label.text = "Merlin rédige une page de ton chemin…"
	var intro_text: String = await _planner.generate_intro(_biome_id, _chosen_title)
	if _aborted:
		return
	# Spawn parchment overlay (anchored center).
	var parchment: PanelContainer = PARCHMENT_SCROLL_SCRIPT.new()
	parchment.anchor_left = 0.5
	parchment.anchor_right = 0.5
	parchment.anchor_top = 0.5
	parchment.anchor_bottom = 0.5
	parchment.offset_left = -340
	parchment.offset_right = 340
	parchment.offset_top = -200
	parchment.offset_bottom = 200
	_ui_layer.add_child(parchment)
	parchment.call("display", intro_text)
	await parchment.closed
	if _aborted:
		return
	_info_label.text = "Titre choisi : %s\n(Merlin écrit le scénario…)" % _chosen_title

	# Step 3 : generate skeleton (LLM #3, RAG-augmented via v7.7.23 Phase 5).
	_skeleton = await _planner.generate_skeleton(_biome_id, _chosen_title)
	if _skeleton.is_empty():
		push_warning("[ScenarioLoading] Empty skeleton — using planner fallback")

	# Step 4 : write skeleton into Store + return to BoardNarration
	_dispatch_skeleton()
	_info_label.text = "Le scénario est écrit. La forêt t'attend…"
	# Small pause for the player to see the transition message.
	await get_tree().create_timer(1.2).timeout
	_return_to_board()


func _dispatch_skeleton() -> void:
	if _store == null or not _store.has_method("dispatch"):
		return
	# Save the skeleton into Store so BoardNarration can pick it up on next _ready.
	# Uses a new SET_SCENARIO_SKELETON action ; if merlin_store has no handler yet,
	# the dispatch falls through harmlessly per Redux-like no-op semantics.
	_store.dispatch({
		"type": "SET_SCENARIO_SKELETON",
		"skeleton": _skeleton,
		"chosen_title": _chosen_title,
	})


func _return_to_board() -> void:
	# v7.7.2 — emit skeleton_dispatched first. If a parent (BoardNarration in
	# sub-scene mode) is listening, it will handle our cleanup + continue its flow.
	# If no listener (standalone legacy mode), fall back to change_scene_to_file.
	if skeleton_dispatched.get_connections().size() > 0:
		skeleton_dispatched.emit()
		return
	# v7.7.19 — PixelTransition fade for harmonized cross-scene transitions.
	var pt: Node = get_node_or_null("/root/PixelTransition")
	if pt != null and pt.has_method("transition_to"):
		pt.call("transition_to", "res://scenes/BoardNarration.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/BoardNarration.tscn")


# ═════════ v7.7.1 C4 — back button + fallback skeleton helpers ═══════════════

## v7.7.24 STRICT MODE — Show a parchment with offline message + back to Hub.
## Triggered when MerlinAI.is_brain_ready() returns false. Hides the LLM-dependent
## flow entirely rather than degrading silently.
func _show_brain_offline_and_return() -> void:
	push_warning("[ScenarioLoading] v7.7.24 strict mode : LLM brain not ready — blocking scene")
	_info_label.text = "Merlin médite…"
	# Parchment with offline message.
	const PARCHMENT_SCRIPT := preload("res://scripts/ui/parchment_scroll.gd")
	var parchment: PanelContainer = PARCHMENT_SCRIPT.new()
	parchment.anchor_left = 0.5
	parchment.anchor_right = 0.5
	parchment.anchor_top = 0.5
	parchment.anchor_bottom = 0.5
	parchment.offset_left = -340
	parchment.offset_right = 340
	parchment.offset_top = -200
	parchment.offset_bottom = 200
	_ui_layer.add_child(parchment)
	var offline_msg: String = (
		"Merlin médite dans son cabinet de pierres. " +
		"Sa voix est absente du vent ce matin, et les Oghams ne s'allument pas. " +
		"Retourne au foyer du clan, jeune druide, et attends que la forêt te rappelle. " +
		"Quand Merlin sera prêt à te guider, tu sauras. " +
		"Pour l'instant, le bois reste un mystère qu'il vaut mieux ne pas brusquer."
	)
	parchment.call("display", offline_msg)
	await parchment.closed
	# Route back to Hub via PixelTransition (v7.7.19 pattern).
	var pt: Node = get_node_or_null("/root/PixelTransition")
	if pt != null and pt.has_method("transition_to"):
		pt.call("transition_to", "res://scenes/MerlinCabinHub.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/MerlinCabinHub.tscn")


func _on_back_to_hub_pressed() -> void:
	# Set abort flag to break the pick wait loop, then route to Hub. The flag
	# also short-circuits the post-await _aborted checks in _run_flow.
	# v7.7.19 — PixelTransition fade per user request « aucune transition ».
	_aborted = true
	if not is_inside_tree():
		return
	var pt: Node = get_node_or_null("/root/PixelTransition")
	if pt != null and pt.has_method("transition_to"):
		pt.call("transition_to", "res://scenes/MerlinCabinHub.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/MerlinCabinHub.tscn")


func _dispatch_fallback_skeleton() -> void:
	# Minimal hardcoded skeleton — non-empty so the board's idempotency guard
	# (Store.state.run.scenario_skeleton presence) prevents ScenarioLoading re-entry.
	# fallback=true lets BoardNarration log/treat this as a degraded run if needed.
	if _store == null or not _store.has_method("dispatch"):
		return
	var fallback: Dictionary = {
		"title": "Un voyage sans nom",
		"biome": _biome_id,
		"beats": [],
		"fallback": true,
	}
	_store.dispatch({
		"type": "SET_SCENARIO_SKELETON",
		"skeleton": fallback,
		"chosen_title": "Un voyage sans nom",
	})


# ═════════ v7.7.21 — Unified DigitalPickerCard (replaces 3D parchments) ══════

# 8 ogham glyphs per scenario index (cycled if more than 8 titles).
const SCENARIO_GLYPHS: Array = ["ᚁ", "ᚂ", "ᚃ", "ᚄ", "ᚅ", "ᚆ", "ᚇ", "ᚈ"]

## v7.7.21 — Build 3 DigitalPickerCard horizontally on the UI layer (replaces
## the 3D parchments + the per-frame unproject Button sync). Cards self-handle
## hover/click + animations via DigitalPickerCard internal logic. Staggered
## animate_in at 0s / 2.5s / 5.0s preserves the v7.7.17 10s cascade budget.
func _build_scenario_cards(titles: Array) -> void:
	_picker_cards.clear()
	# HBoxContainer centered on screen, with breathing room above for sound bar.
	if _picker_container != null and is_instance_valid(_picker_container):
		_picker_container.queue_free()
	_picker_container = HBoxContainer.new()
	_picker_container.name = "ScenarioCards"
	_picker_container.add_theme_constant_override("separation", 28)
	_picker_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_picker_container.anchor_left = 0.5
	_picker_container.anchor_right = 0.5
	_picker_container.anchor_top = 0.5
	_picker_container.anchor_bottom = 0.5
	# Card 320 × 400 ; 3 cards + 2 gaps of 28 = 1016 px wide centered.
	# v7.7.21 — Vertical offsets bumped ±220 (was ±200) to give cards breathing
	# room without overlapping the InfoLabel anchored at y=0.4-0.6.
	_picker_container.offset_left = -508
	_picker_container.offset_right = 508
	_picker_container.offset_top = -220
	_picker_container.offset_bottom = 220
	_ui_layer.add_child(_picker_container)

	for i in range(min(3, titles.size())):
		var entry: Dictionary = titles[i] as Dictionary
		var title_text: String = str(entry.get("title", "?"))
		var ogham_id: String = str(entry.get("ogham", ""))
		# LLM may include a body field ; fallback to SCENARIO_BODY_FALLBACKS[i].
		var body_text: String = str(entry.get("body", ""))
		if body_text == "":
			body_text = SCENARIO_BODY_FALLBACKS[clampi(i, 0, SCENARIO_BODY_FALLBACKS.size() - 1)]
		# Glyph : prefer LLM-provided ogham (with celtic brackets) else cycle.
		var glyph_text: String = ""
		if ogham_id != "":
			glyph_text = "᚛" + ogham_id.substr(0, 1).to_upper() + "᚜"
		else:
			glyph_text = SCENARIO_GLYPHS[i % SCENARIO_GLYPHS.size()]
		# Instantiate via preload + set_script (avoids class_name first-pass race).
		var card := PanelContainer.new()
		card.set_script(DIGITAL_PICKER_CARD_SCRIPT)
		card.name = "ScenarioCard_%d" % i
		_picker_container.add_child(card)
		if card.has_method("setup"):
			card.call("setup", "scenario_%d" % i, title_text, body_text, glyph_text, MerlinVisual.UI_GOLD, false, "")
		# Connect selected signal — captured idx via inline bind to avoid closure.
		var captured_idx: int = i
		if card.has_signal("selected"):
			card.connect("selected", _on_scenario_card_picked.bind(captured_idx))
		# Stagger reveal : card i animates in at t = i × 2.5s, preserving 10s budget.
		if card.has_method("animate_in"):
			card.call("animate_in", float(i) * 2.5)
		# Pulse Merlin sound bar when each card lands (simulates "writing").
		get_tree().create_timer(float(i) * 2.5 + 0.55).timeout.connect(_pulse_merlin_sound_bar_for_card)
		_picker_cards.append(card)


## v7.7.21 — DigitalPickerCard click handler. Sets _pending_pick to the chosen
## index ; _run_flow polls this value to break its wait loop. The card itself
## already played its mark_chosen() pulse + crimson flash before emitting.
## The `_card_id` arg is unused (we use captured_idx) but kept for signal sig.
func _on_scenario_card_picked(_card_id: String, idx: int) -> void:
	if _pending_pick >= 0:
		return  # already picked, ignore subsequent clicks
	_pending_pick = clampi(idx, 0, _picker_cards.size() - 1)


## v7.7.17 — Pulse the MerlinSoundBar (if spawned) for ~0.6s simulating Merlin
## speaking while a parchment is being written. Idempotent — safe if no bar.
## v7.7.21 — Early-return if scene already exited (back button during stagger).
## SceneTreeTimer callbacks scheduled via _build_scenario_cards may fire after
## the scene is freed ; this guard prevents dangling-self method calls.
func _pulse_merlin_sound_bar_for_card() -> void:
	if not is_inside_tree() or _aborted:
		return
	if _merlin_sound_bar == null or not is_instance_valid(_merlin_sound_bar):
		return
	if _merlin_sound_bar.has_method("start_speaking"):
		_merlin_sound_bar.call("start_speaking")
	# Fire 5 pulses over 0.6s (one per ~120ms)
	for i in range(5):
		var delay: float = float(i) * 0.12
		get_tree().create_timer(delay).timeout.connect(func() -> void:
			if is_instance_valid(_merlin_sound_bar) and _merlin_sound_bar.has_method("pulse"):
				_merlin_sound_bar.call("pulse", randf_range(0.5, 0.9))
		)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if is_instance_valid(_merlin_sound_bar) and _merlin_sound_bar.has_method("stop_speaking"):
			_merlin_sound_bar.call("stop_speaking")
	)


## v7.7.17 — Instantiate the Merlin sound bar above the parchments,
## positioned in front of the camera. Idempotent : safe to call twice.
func _spawn_merlin_for_writing() -> void:
	if _merlin_sound_bar != null and is_instance_valid(_merlin_sound_bar):
		return
	_merlin_sound_bar = Node3D.new()
	_merlin_sound_bar.set_script(MERLIN_SOUND_BAR_SCRIPT)
	_merlin_sound_bar.name = "MerlinWritingSoundBar"
	# Position : above the parchments (y=2.6, behind them z=1.8), facing camera.
	_merlin_sound_bar.position = Vector3(0.0, 2.6, 1.8)
	_merlin_sound_bar.rotation = Vector3(deg_to_rad(-8.0), 0.0, 0.0)
	# Slight scale-up for visibility from camera distance.
	_merlin_sound_bar.scale = Vector3.ONE * 1.5
	add_child(_merlin_sound_bar)
	# Initial speaking state — pulses for ~1.5s simulating "Merlin begins to weave"
	if _merlin_sound_bar.has_method("start_speaking"):
		_merlin_sound_bar.call("start_speaking")
	for i in range(8):
		var d: float = float(i) * 0.15
		get_tree().create_timer(d).timeout.connect(func() -> void:
			if is_instance_valid(_merlin_sound_bar) and _merlin_sound_bar.has_method("pulse"):
				_merlin_sound_bar.call("pulse", randf_range(0.4, 0.85))
		)


# v7.7.21 — _build_pick_buttons / _clear_pick_buttons / _on_parchemin_clicked /
# _process unproject sync REMOVED. DigitalPickerCard handles its own mouse_filter
# + hover/click directly on the 2D UI layer ; no per-frame camera unproject needed.
