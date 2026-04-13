## ParchmentPreRun — Pre-run scene: generates skeleton + shows parchment + enter button.
## Flow: Menu → this scene → generates run → parchment animates → player clicks "Enter" → game.
## Scene: standalone, loaded via PixelTransition from Menu3DPC or MenuPrincipal.

extends Control

const SCENE_FOREST := "res://scenes/BroceliandeForest3D.tscn"
const BIOME_DEFAULT := "foret_broceliande"

## Parchment instance.
var _parchment: ParchmentDisplay = null
var _graph: MerlinRunGraph = null

## Enter button (shown after parchment animation complete).
var _enter_btn: Button = null
var _enter_visible: bool = false

## Generation state.
var _generating: bool = false
var _generation_done: bool = false

## Fonts.
var _font_title: Font = null
var _font_body: Font = null

## Loading indicator.
var _loading_label: Label = null


func _ready() -> void:
	_load_fonts()
	_build_ui()
	_start_generation()


func _load_fonts() -> void:
	if ResourceLoader.exists("res://resources/fonts/morris/MorrisRomanBlack.ttf"):
		_font_title = load("res://resources/fonts/morris/MorrisRomanBlack.ttf") as Font
	if ResourceLoader.exists("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf"):
		_font_body = load("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf") as Font
	if _font_title == null:
		_font_title = ThemeDB.fallback_font
	if _font_body == null:
		_font_body = ThemeDB.fallback_font


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# Dark background.
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.06, 0.04, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Parchment display (fills the screen).
	_parchment = ParchmentDisplay.new()
	_parchment.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_parchment)
	_parchment.animation_finished.connect(_on_parchment_finished)

	# Loading indicator (shown during generation).
	_loading_label = Label.new()
	_loading_label.text = I18nRegistry.t("ui.parchment.loading_message")
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.anchor_left = 0.2
	_loading_label.anchor_right = 0.8
	_loading_label.anchor_top = 0.45
	_loading_label.anchor_bottom = 0.55
	_loading_label.add_theme_color_override("font_color", Color(0.75, 0.60, 0.25, 0.8))
	_loading_label.add_theme_font_size_override("font_size", 22)
	if _font_body:
		_loading_label.add_theme_font_override("font", _font_body)
	add_child(_loading_label)

	# "Entrer la Quête" button (hidden until parchment finishes).
	_enter_btn = Button.new()
	_enter_btn.text = I18nRegistry.t("ui.parchment.enter_quest")
	_enter_btn.anchor_left = 0.3
	_enter_btn.anchor_right = 0.7
	_enter_btn.anchor_top = 0.88
	_enter_btn.anchor_bottom = 0.95
	_enter_btn.visible = false
	_enter_btn.add_theme_font_size_override("font_size", 24)
	if _font_title:
		_enter_btn.add_theme_font_override("font", _font_title)

	# Style the button — wood/parchment aesthetic.
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.45, 0.32, 0.12, 0.85)
	btn_style.border_color = Color(0.70, 0.55, 0.25)
	btn_style.set_border_width_all(2)
	btn_style.set_corner_radius_all(6)
	btn_style.set_content_margin_all(12)
	_enter_btn.add_theme_stylebox_override("normal", btn_style)

	var btn_hover: StyleBoxFlat = btn_style.duplicate()
	btn_hover.bg_color = Color(0.55, 0.40, 0.15, 0.95)
	btn_hover.border_color = Color(0.85, 0.65, 0.30)
	_enter_btn.add_theme_stylebox_override("hover", btn_hover)

	var btn_pressed: StyleBoxFlat = btn_style.duplicate()
	btn_pressed.bg_color = Color(0.35, 0.25, 0.10, 0.9)
	_enter_btn.add_theme_stylebox_override("pressed", btn_pressed)

	_enter_btn.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	_enter_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.60))
	_enter_btn.pressed.connect(_on_enter_pressed)
	add_child(_enter_btn)


func _start_generation() -> void:
	_generating = true
	_loading_label.visible = true

	# Get store and generate the run skeleton.
	var store: Node = _get_store()
	var biome_key: String = _get_biome_key()

	# Initialize MerlinAI models if needed.
	var merlin_ai: Node = get_node_or_null("/root/MerlinAI")
	if merlin_ai and merlin_ai.has_method("_init_local_models"):
		merlin_ai._init_local_models()

	# Dispatch START_RUN to store.
	if store and store.has_method("dispatch"):
		var gm: Node = get_node_or_null("/root/GameManager")
		var seed_val: int = randi()
		if gm:
			# Set biome in GameManager run data.
			var run_data: Dictionary = gm.get("run") if gm.get("run") is Dictionary else {}
			run_data["biome"] = {"id": biome_key, "name": "Foret de Broceliande"}
			run_data["current_biome"] = biome_key
			gm.set("run", run_data)

		await store.dispatch({
			"type": "START_RUN",
			"seed": seed_val,
			"biome": biome_key,
		})

	# Generate skeleton graph.
	_graph = await _generate_skeleton(biome_key, store)

	if _graph == null:
		print("[ParchmentPreRun] ERROR: skeleton generation failed")
		_loading_label.text = "Erreur de generation..."
		_generating = false
		return

	# Store graph in run state.
	if store and store.has_method("dispatch"):
		await store.dispatch({"type": "SET_RUN_GRAPH", "graph": _graph.to_dict()})

	print("[ParchmentPreRun] Skeleton ready: %d main + %d detour nodes" % [
		_graph.total_main_nodes, _graph.total_detour_nodes])

	# Hide loading, show parchment.
	_loading_label.visible = false
	_generating = false
	_generation_done = true
	_parchment.reveal(_graph)


func _generate_skeleton(biome_key: String, store: Node) -> MerlinRunGraph:
	var game_state: Dictionary = {}
	var ogham_id: String = ""
	var save_data: Dictionary = {}

	if store:
		game_state = store.state.get("meta", {}) if "state" in store else {}
		ogham_id = str(store.state.get("run", {}).get("ogham_actif", "")) if "state" in store else ""
		if store.has_method("get_save_data"):
			save_data = store.get_save_data()

	# Try LLM generation via MOS.
	var mos: Node = null
	if store and store.has_method("get_mos"):
		mos = store.get_mos()

	if mos and mos.has_method("generate_run_skeleton"):
		var graph: MerlinRunGraph = await mos.generate_run_skeleton(biome_key, ogham_id, game_state, save_data)
		if graph != null:
			return graph

	# Fallback: procedural generation.
	print("[ParchmentPreRun] Using procedural fallback")
	var ctx: Dictionary = MerlinSkeletonGenerator._build_context(biome_key, ogham_id, game_state, save_data)
	return MerlinSkeletonGenerator._generate_procedural(ctx)


func _on_parchment_finished() -> void:
	# Parchment animation done — show enter button with fade-in.
	_enter_btn.visible = true
	_enter_btn.modulate = Color(1, 1, 1, 0)
	_enter_visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_enter_btn, "modulate", Color(1, 1, 1, 1), 0.6)


func _on_enter_pressed() -> void:
	if not _generation_done or _graph == null:
		return
	_enter_btn.disabled = true

	# Play SFX if available.
	var sfx: Node = get_node_or_null("/root/SFXManager")
	if sfx and sfx.has_method("play"):
		sfx.play("partir_fanfare")

	# Transition to game scene.
	var pt: Node = get_node_or_null("/root/PixelTransition")
	if pt and pt.has_method("transition_to"):
		pt.transition_to(SCENE_FOREST)
	else:
		get_tree().change_scene_to_file(SCENE_FOREST)


func _get_store() -> Node:
	return get_node_or_null("/root/MerlinStore")


func _get_biome_key() -> String:
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm:
		var run: Dictionary = gm.get("run") if gm.get("run") is Dictionary else {}
		var biome: Dictionary = run.get("biome", {}) if run.get("biome") is Dictionary else {}
		var biome_id: String = str(biome.get("id", ""))
		if biome_id != "":
			return biome_id
	return BIOME_DEFAULT
