## ═══════════════════════════════════════════════════════════════════════════════
## TRIADE Game UI — Main Gameplay Interface (v0.3.0)
## ═══════════════════════════════════════════════════════════════════════════════
## UI for TRIADE system: 3 Aspects, 3 States, 3 Options per card.
## Celtic symbols: Sanglier (Corps), Corbeau (Ame), Cerf (Monde)
## ═══════════════════════════════════════════════════════════════════════════════

extends Control
class_name TriadeGameUI

signal option_chosen(option: int)  # 0=LEFT, 1=CENTER, 2=RIGHT
signal skill_activated(skill_id: String)
signal pause_requested

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

const ASPECT_COLORS := {
	"Corps": Color(0.8, 0.4, 0.2),   # Orange-brown (earth)
	"Ame": Color(0.5, 0.3, 0.7),     # Purple (spirit)
	"Monde": Color(0.3, 0.6, 0.4),   # Green (nature)
}

const STATE_LABELS := {
	MerlinConstants.AspectState.BAS: "\u25BC",
	MerlinConstants.AspectState.EQUILIBRE: "\u25CF",
	MerlinConstants.AspectState.HAUT: "\u25B2",
}

const SOUFFLE_ICON := "\u0DA7"  # Celtic spiral (Sinhala character shaped like a spiral)
const SOUFFLE_EMPTY := "\u25CB"

const OPTION_KEYS := {
	MerlinConstants.CardOption.LEFT: "A",
	MerlinConstants.CardOption.CENTER: "B",
	MerlinConstants.CardOption.RIGHT: "C",
}

const INTRO_PIXEL_COLS := 84
const INTRO_PIXEL_ROWS := 48
const INTRO_STACK_BATCH := 26
const INTRO_STACK_STEP := 0.02
const INTRO_DECK_COUNT := 12
const LIVE_DECK_VISIBLE_COUNT := 5
const DISCARD_VISIBLE_COUNT := 5
const RUN_DECK_ESTIMATE := 24
const TOP_ZONE_RATIO := 0.15
const CARD_ZONE_RATIO := 0.70
const BOTTOM_ZONE_RATIO := 0.15
const CARD_FLOAT_OFFSET := 7.0
const CARD_FLOAT_DURATION := 1.6
const CARD_PORTRAIT_RATIO := 0.74
const ACTION_VERB_FALLBACK := ["Observer", "Canaliser", "Braver"]

const BIOME_SHORT_NAMES := {
	"foret_broceliande": "broceliande",
	"landes_bruyere": "landes",
	"cotes_sauvages": "cotes",
	"villages_celtes": "villages",
	"cercles_pierres": "cercles",
	"marais_korrigans": "marais",
	"collines_dolmens": "collines",
}

const BIOME_ART_PROFILES := {
	"broceliande": {"sky": Color(0.16, 0.24, 0.14), "mist": Color(0.30, 0.38, 0.24), "mid": Color(0.14, 0.30, 0.16), "accent": Color(0.42, 0.56, 0.30), "foreground": Color(0.08, 0.16, 0.10), "feature_density": 0.64},
	"landes": {"sky": Color(0.28, 0.22, 0.34), "mist": Color(0.44, 0.36, 0.52), "mid": Color(0.36, 0.24, 0.34), "accent": Color(0.64, 0.46, 0.62), "foreground": Color(0.24, 0.17, 0.23), "feature_density": 0.48},
	"cotes": {"sky": Color(0.20, 0.28, 0.36), "mist": Color(0.34, 0.42, 0.50), "mid": Color(0.30, 0.34, 0.36), "accent": Color(0.54, 0.66, 0.74), "foreground": Color(0.16, 0.21, 0.24), "feature_density": 0.50},
	"villages": {"sky": Color(0.30, 0.23, 0.16), "mist": Color(0.48, 0.37, 0.26), "mid": Color(0.38, 0.28, 0.20), "accent": Color(0.74, 0.52, 0.30), "foreground": Color(0.22, 0.16, 0.12), "feature_density": 0.55},
	"cercles": {"sky": Color(0.23, 0.24, 0.27), "mist": Color(0.36, 0.38, 0.41), "mid": Color(0.28, 0.29, 0.30), "accent": Color(0.66, 0.70, 0.76), "foreground": Color(0.18, 0.18, 0.20), "feature_density": 0.42},
	"marais": {"sky": Color(0.17, 0.24, 0.22), "mist": Color(0.26, 0.36, 0.33), "mid": Color(0.20, 0.30, 0.25), "accent": Color(0.52, 0.66, 0.50), "foreground": Color(0.10, 0.17, 0.15), "feature_density": 0.60},
	"collines": {"sky": Color(0.26, 0.29, 0.19), "mist": Color(0.42, 0.45, 0.30), "mid": Color(0.34, 0.39, 0.22), "accent": Color(0.70, 0.56, 0.34), "foreground": Color(0.20, 0.22, 0.13), "feature_density": 0.52},
}

const SEASON_TINTS := {
	"printemps": Color(1.02, 1.07, 1.00),
	"ete": Color(1.08, 1.04, 0.95),
	"automne": Color(1.10, 0.92, 0.82),
	"hiver": Color(0.84, 0.90, 1.08),
}

const BIOME_DEFAULT_SEASON := {
	"broceliande": "automne",
	"landes": "hiver",
	"cotes": "hiver",
	"villages": "ete",
	"cercles": "printemps",
	"marais": "printemps",
	"collines": "automne",
}

# ═══════════════════════════════════════════════════════════════════════════════
# REFERENCES (set by scene or dynamically created)
# ═══════════════════════════════════════════════════════════════════════════════

var aspect_panel: Control
var aspect_displays: Dictionary = {}  # {"Corps": {container, icon, state_indicator}}

var souffle_panel: Control
var souffle_display: HBoxContainer
var _souffle_counter: Label

# Life essence (Phase 43)
var life_panel: Control
var _life_counter: Label
var _life_bar: ProgressBar

var card_container: Control
var card_panel: Panel
var card_text: RichTextLabel
var card_speaker: Label
var _card_source_badge: PanelContainer
var _encounter_tile: PixelEncounterTile

var options_container: HBoxContainer
var option_buttons: Array[Button] = []
var option_labels: Array[Label] = []
var _effect_preview_panel: Panel
var _effect_preview_label: RichTextLabel
var _preview_visible_for: int = -1  # Which option index is previewed

var _resource_bar: HBoxContainer
var _tool_label: Label
var _day_label: Label
var _mission_progress_label: Label
var _essence_counter: Label
var _status_clock_panel: PanelContainer
var _status_clock_label: Label
var _status_clock_timer: Timer

var info_panel: Control
var mission_label: Label
var cards_label: Label

var bestiole_wheel: BestioleWheelSystem
var _pixel_portrait: PixelCharacterPortrait
var _current_speaker_key: String = ""
var biome_indicator: Label

# ═══════════════════════════════════════════════════════════════════════════════
# STATE
# ═══════════════════════════════════════════════════════════════════════════════

var current_card: Dictionary = {}
var current_aspects: Dictionary = {}
var _previous_aspects: Dictionary = {}
var current_souffle: int = MerlinConstants.SOUFFLE_START
var _previous_souffle: int = -1
var _blip_pool: Array[AudioStreamPlayer] = []
var _blip_idx: int = 0
const BLIP_POOL_SIZE := 4

# Card stacking
var _card_shadows: Array[Panel] = []
const MAX_CARD_SHADOWS := 3

# Ambient VFX
var _ambient_timer: Timer
var _ambient_particles: Array[ColorRect] = []
const MAX_AMBIENT_PARTICLES := 10
var _ambient_biome_key: String = ""
var _opening_sequence_done := false
var _ui_blocks_for_intro: Array[Control] = []
var _biome_art_pixels: Array[ColorRect] = []
var _top_status_bar: HBoxContainer
var _card_visual_split: VBoxContainer
var _card_illustration_panel: PanelContainer
var _card_body_panel: PanelContainer
var _text_pixel_fx_layer: Control
var _card_float_tween: Tween
var _card_entry_tween: Tween
var _card_base_pos: Vector2 = Vector2.ZERO
var _remaining_deck_root: Control
var _remaining_deck_cards: Array[Panel] = []
var _remaining_deck_label: Label
var _remaining_deck_estimate: int = RUN_DECK_ESTIMATE
var _discard_root: Control
var _discard_cards: Array[Panel] = []
var _discard_label: Label
var _discard_total: int = 0

# ═══════════════════════════════════════════════════════════════════════════════
# INITIALIZATION
# ═══════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_setup_ui()
	_init_blip_pool()
	_update_aspects({
		"Corps": MerlinConstants.AspectState.EQUILIBRE,
		"Ame": MerlinConstants.AspectState.EQUILIBRE,
		"Monde": MerlinConstants.AspectState.EQUILIBRE,
	})
	_update_souffle(MerlinConstants.SOUFFLE_START)
	update_life_essence(MerlinConstants.LIFE_ESSENCE_START)
	update_essences_collected(0)
	reset_run_visuals()


func _process(delta: float) -> void:
	_update_low_poly_background(delta)


func _init_blip_pool() -> void:
	## Pre-create a pool of AudioStreamPlayers to avoid per-character allocation.
	for i in range(BLIP_POOL_SIZE):
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.02
		var player := AudioStreamPlayer.new()
		player.stream = gen
		player.volume_db = linear_to_db(0.04)
		add_child(player)
		_blip_pool.append(player)


const PALETTE := {
	"paper": Color(0.965, 0.945, 0.905),
	"paper_dark": Color(0.935, 0.905, 0.855),
	"ink": Color(0.22, 0.18, 0.14),
	"ink_soft": Color(0.38, 0.32, 0.26),
	"ink_faded": Color(0.50, 0.44, 0.38, 0.35),
	"accent": Color(0.58, 0.44, 0.26),
	"shadow": Color(0.25, 0.20, 0.16, 0.18),
	"line": Color(0.40, 0.34, 0.28, 0.12),
}

var title_font: Font
var body_font: Font
var _bg3d_container: SubViewportContainer
var _bg3d_viewport: SubViewport
var _bg3d_root: Node3D
var _bg3d_geometry_root: Node3D
var _bg3d_environment: Environment
var _bg3d_camera: Camera3D
var _bg3d_sun: DirectionalLight3D
var _bg3d_fill: DirectionalLight3D
var _bg3d_rain: GPUParticles3D
var _bg3d_snow: GPUParticles3D
var _bg3d_leaves: GPUParticles3D
var _bg3d_clouds: Array[MeshInstance3D] = []
var _bg3d_animals: Array[Node3D] = []
var _bg3d_rng := RandomNumberGenerator.new()
var _bg3d_weather_mode: String = "clear"
var _bg3d_weather_timer: float = 0.0
var _bg3d_light_factor: float = 1.0
var _active_biome_visual: String = "broceliande"
var _active_season_visual: String = "automne"
var _active_hour_visual: int = -1
var parchment_bg: ColorRect
var biome_art_layer: Control
var _deck_fx_layer: Control
var main_vbox: VBoxContainer
var _bottom_zone: VBoxContainer
var _bottom_push_spacer: Control
var _run_stack_bar: HBoxContainer
var narrator_overlay: Control  # For narrator intro + NPC pixel cascade


func _setup_ui() -> void:
	_load_fonts()
	_build_low_poly_background()

	# Parchment background
	parchment_bg = ColorRect.new()
	parchment_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parchment_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper_shader := load("res://shaders/reigns_paper.gdshader")
	if paper_shader:
		var mat := ShaderMaterial.new()
		mat.shader = paper_shader
		mat.set_shader_parameter("paper_tint", PALETTE.paper)
		mat.set_shader_parameter("grain_strength", 0.025)
		mat.set_shader_parameter("vignette_strength", 0.08)
		mat.set_shader_parameter("vignette_softness", 0.65)
		mat.set_shader_parameter("grain_scale", 1200.0)
		mat.set_shader_parameter("grain_speed", 0.08)
		mat.set_shader_parameter("warp_strength", 0.001)
		parchment_bg.material = mat
	else:
		parchment_bg.color = PALETTE.paper
	add_child(parchment_bg)
	parchment_bg.modulate = Color(1.0, 1.0, 1.0, 0.16)

	# Pixel-art biome background built at run start.
	biome_art_layer = Control.new()
	biome_art_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	biome_art_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	biome_art_layer.visible = false
	add_child(biome_art_layer)

	# Main layout
	main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	add_child(main_vbox)

	# Deck animation layer (used during opening sequence).
	_deck_fx_layer = Control.new()
	_deck_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deck_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deck_fx_layer.visible = false
	add_child(_deck_fx_layer)

	# Top HUD: only health, souffle, essences.
	_top_status_bar = HBoxContainer.new()
	_top_status_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_top_status_bar.add_theme_constant_override("separation", 26)
	main_vbox.add_child(_top_status_bar)
	_create_life_display(_top_status_bar)
	_create_souffle_display(_top_status_bar)
	_create_essence_display(_top_status_bar)
	_create_clock_status_panel()

	# Optional biome indicator kept hidden; artwork already conveys biome.
	biome_indicator = Label.new()
	biome_indicator.visible = false

	# Card area (70% viewport target)
	_create_card_display(main_vbox)

	# Bottom zone (15%): choices aligned low + run stacks.
	_bottom_zone = VBoxContainer.new()
	_bottom_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_zone.size_flags_vertical = Control.SIZE_FILL
	_bottom_zone.add_theme_constant_override("separation", 6)
	main_vbox.add_child(_bottom_zone)

	_bottom_push_spacer = Control.new()
	_bottom_push_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom_zone.add_child(_bottom_push_spacer)

	_create_options_bar(_bottom_zone)
	_create_run_stack_bar(_bottom_zone)

	# Effect preview tooltip (floating, added to self so it overlays everything)
	_create_effect_preview_panel()

	# Optional info bar kept hidden in the revamp UX.
	_create_info_bar(_bottom_zone)
	if info_panel and is_instance_valid(info_panel):
		info_panel.visible = false

	# Bestiole Ogham Wheel (overlay, self-positioned bottom-right)
	bestiole_wheel = BestioleWheelSystem.new()
	bestiole_wheel.name = "BestioleWheel"
	add_child(bestiole_wheel)
	bestiole_wheel.ogham_selected.connect(func(_skill_id: String):
		SFXManager.play("skill_activate")
	)

	# Narrator overlay (for Merlin intro + NPC pixel cascade)
	narrator_overlay = Control.new()
	narrator_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	narrator_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	narrator_overlay.visible = false
	add_child(narrator_overlay)

	_build_remaining_deck_stack()
	_build_discard_stack()
	_ui_blocks_for_intro = [_top_status_bar, options_container, _run_stack_bar]
	_layout_run_zones()
	_layout_card_stage()


func _load_fonts() -> void:
	title_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.otf")
	if title_font == null:
		title_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlack.ttf")
	body_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.otf")
	if body_font == null:
		body_font = _try_load_font("res://resources/fonts/morris/MorrisRomanBlackAlt.ttf")
	if body_font == null:
		body_font = title_font


func _try_load_font(path: String) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var f: Resource = load(path)
	if f is Font:
		return f
	return null


func _is_forward_plus_renderer() -> bool:
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "forward_plus"))
	return method == "forward_plus"


func _build_low_poly_background() -> void:
	if _bg3d_container and is_instance_valid(_bg3d_container):
		return

	_bg3d_rng.seed = int(Time.get_unix_time_from_system())
	_bg3d_container = SubViewportContainer.new()
	_bg3d_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg3d_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg3d_container.stretch = false
	_bg3d_container.modulate = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_bg3d_container)

	_bg3d_viewport = SubViewport.new()
	_bg3d_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_bg3d_viewport.msaa_3d = Viewport.MSAA_2X
	_bg3d_container.add_child(_bg3d_viewport)

	_bg3d_root = Node3D.new()
	_bg3d_viewport.add_child(_bg3d_root)

	_bg3d_geometry_root = Node3D.new()
	_bg3d_root.add_child(_bg3d_geometry_root)

	_setup_low_poly_environment()
	_build_low_poly_weather_emitters()
	_resize_low_poly_background()


func _setup_low_poly_environment() -> void:
	var world_env := WorldEnvironment.new()
	_bg3d_environment = Environment.new()
	_bg3d_environment.background_mode = Environment.BG_COLOR
	_bg3d_environment.background_color = Color(0.03, 0.06, 0.08)
	_bg3d_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_bg3d_environment.ambient_light_color = Color(0.24, 0.30, 0.32)
	_bg3d_environment.ambient_light_energy = 0.64
	_bg3d_environment.fog_enabled = true
	_bg3d_environment.fog_density = 0.016
	_bg3d_environment.fog_light_color = Color(0.24, 0.34, 0.30)
	if _is_forward_plus_renderer():
		_bg3d_environment.set("volumetric_fog_enabled", true)
		_bg3d_environment.set("volumetric_fog_density", 0.036)
		_bg3d_environment.set("volumetric_fog_albedo", Color(0.26, 0.36, 0.31))
		_bg3d_environment.set("volumetric_fog_emission", Color(0.03, 0.04, 0.05))
	world_env.environment = _bg3d_environment
	_bg3d_root.add_child(world_env)

	_bg3d_camera = Camera3D.new()
	_bg3d_camera.current = true
	_bg3d_camera.fov = 56.0
	_bg3d_camera.position = Vector3(0.0, 24.0, 72.0)
	_bg3d_camera.look_at_from_position(_bg3d_camera.position, Vector3(0.0, 8.0, 0.0), Vector3.UP)
	_bg3d_root.add_child(_bg3d_camera)

	_bg3d_sun = DirectionalLight3D.new()
	_bg3d_sun.light_color = Color(0.30, 0.62, 1.0)
	_bg3d_sun.light_energy = 1.35
	_bg3d_sun.shadow_enabled = true
	_bg3d_sun.shadow_blur = 0.8
	_bg3d_root.add_child(_bg3d_sun)

	_bg3d_fill = DirectionalLight3D.new()
	_bg3d_fill.light_color = Color(0.44, 0.28, 0.56)
	_bg3d_fill.light_energy = 0.28
	_bg3d_fill.rotation_degrees = Vector3(-20.0, -120.0, 0.0)
	_bg3d_root.add_child(_bg3d_fill)


func _build_low_poly_weather_emitters() -> void:
	_bg3d_rain = GPUParticles3D.new()
	_bg3d_rain.amount = 3600
	_bg3d_rain.lifetime = 2.0
	_bg3d_rain.preprocess = 1.0
	_bg3d_rain.one_shot = false
	_bg3d_rain.emitting = false
	_bg3d_rain.position = Vector3(0.0, 55.0, 0.0)
	_bg3d_rain.visibility_aabb = AABB(Vector3(-120.0, -20.0, -120.0), Vector3(240.0, 130.0, 240.0))
	var rain_mesh := QuadMesh.new()
	rain_mesh.size = Vector2(0.06, 0.64)
	_bg3d_rain.draw_pass_1 = rain_mesh
	var rain_process := ParticleProcessMaterial.new()
	rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_process.emission_box_extents = Vector3(110.0, 1.0, 110.0)
	rain_process.direction = Vector3(0.0, -1.0, 0.0)
	rain_process.spread = 8.0
	rain_process.gravity = Vector3(0.0, -34.0, 0.0)
	rain_process.initial_velocity_min = 20.0
	rain_process.initial_velocity_max = 34.0
	rain_process.scale_min = 0.2
	rain_process.scale_max = 0.46
	rain_process.color = Color(0.58, 0.78, 1.0, 0.55)
	_bg3d_rain.process_material = rain_process
	_bg3d_root.add_child(_bg3d_rain)

	_bg3d_snow = GPUParticles3D.new()
	_bg3d_snow.amount = 1800
	_bg3d_snow.lifetime = 5.8
	_bg3d_snow.preprocess = 1.0
	_bg3d_snow.one_shot = false
	_bg3d_snow.emitting = false
	_bg3d_snow.position = Vector3(0.0, 55.0, 0.0)
	_bg3d_snow.visibility_aabb = AABB(Vector3(-120.0, -20.0, -120.0), Vector3(240.0, 130.0, 240.0))
	var snow_mesh := SphereMesh.new()
	snow_mesh.radius = 0.07
	snow_mesh.height = 0.14
	snow_mesh.radial_segments = 6
	snow_mesh.rings = 4
	_bg3d_snow.draw_pass_1 = snow_mesh
	var snow_process := ParticleProcessMaterial.new()
	snow_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	snow_process.emission_box_extents = Vector3(110.0, 1.0, 110.0)
	snow_process.direction = Vector3(0.0, -1.0, 0.0)
	snow_process.spread = 28.0
	snow_process.gravity = Vector3(0.0, -4.0, 0.0)
	snow_process.initial_velocity_min = 2.4
	snow_process.initial_velocity_max = 5.0
	snow_process.scale_min = 0.22
	snow_process.scale_max = 0.52
	snow_process.color = Color(0.90, 0.96, 1.0, 0.78)
	_bg3d_snow.process_material = snow_process
	_bg3d_root.add_child(_bg3d_snow)

	_bg3d_leaves = GPUParticles3D.new()
	_bg3d_leaves.amount = 1200
	_bg3d_leaves.lifetime = 5.0
	_bg3d_leaves.preprocess = 0.8
	_bg3d_leaves.one_shot = false
	_bg3d_leaves.emitting = false
	_bg3d_leaves.position = Vector3(0.0, 40.0, 0.0)
	_bg3d_leaves.visibility_aabb = AABB(Vector3(-120.0, -20.0, -120.0), Vector3(240.0, 120.0, 240.0))
	var leaf_mesh := QuadMesh.new()
	leaf_mesh.size = Vector2(0.22, 0.14)
	_bg3d_leaves.draw_pass_1 = leaf_mesh
	var leaf_process := ParticleProcessMaterial.new()
	leaf_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	leaf_process.emission_box_extents = Vector3(90.0, 1.0, 90.0)
	leaf_process.direction = Vector3(0.0, -1.0, 0.0)
	leaf_process.spread = 52.0
	leaf_process.gravity = Vector3(0.0, -1.9, 0.0)
	leaf_process.initial_velocity_min = 1.0
	leaf_process.initial_velocity_max = 3.4
	leaf_process.angular_velocity_min = -1.8
	leaf_process.angular_velocity_max = 1.8
	leaf_process.color = Color(0.70, 0.52, 0.24, 0.72)
	_bg3d_leaves.process_material = leaf_process
	_bg3d_root.add_child(_bg3d_leaves)


func _resize_low_poly_background() -> void:
	if not _bg3d_viewport or not is_instance_valid(_bg3d_viewport):
		return
	var vp_size := get_viewport_rect().size
	_bg3d_viewport.size = Vector2i(maxi(1, int(vp_size.x)), maxi(1, int(vp_size.y)))


func _configure_low_poly_background(biome_key: String, season_key: String, hour: int) -> void:
	if not _bg3d_geometry_root or not is_instance_valid(_bg3d_geometry_root):
		return

	_active_biome_visual = biome_key
	_active_season_visual = season_key
	_active_hour_visual = clampi(hour, 0, 23)
	_bg3d_light_factor = 1.0

	for child in _bg3d_geometry_root.get_children():
		child.queue_free()
	_bg3d_clouds.clear()
	_bg3d_animals.clear()

	var profile: Dictionary = BIOME_ART_PROFILES.get(biome_key, BIOME_ART_PROFILES.broceliande)
	var season_tint: Color = SEASON_TINTS.get(season_key, Color.WHITE)
	var hour_light: Color = _hour_light_color(hour)
	var ground_color := _tone_color(profile.foreground, hour_light, season_tint)
	var hill_color := _tone_color(profile.mid, hour_light, season_tint)
	var accent_color := _tone_color(profile.accent, hour_light, season_tint)

	var ground := MeshInstance3D.new()
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(460.0, 460.0)
	ground.mesh = ground_mesh
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = ground_color.darkened(0.14)
	ground_mat.roughness = 1.0
	ground.material_override = ground_mat
	_bg3d_geometry_root.add_child(ground)

	for i in range(34):
		var hill := MeshInstance3D.new()
		var hill_mesh := BoxMesh.new()
		hill_mesh.size = Vector3(_bg3d_rng.randf_range(8.0, 24.0), _bg3d_rng.randf_range(6.0, 18.0), _bg3d_rng.randf_range(10.0, 26.0))
		hill.mesh = hill_mesh
		var hill_mat := StandardMaterial3D.new()
		hill_mat.albedo_color = hill_color.darkened(_bg3d_rng.randf_range(0.08, 0.26))
		hill_mat.roughness = 1.0
		hill.material_override = hill_mat
		var angle := _bg3d_rng.randf_range(0.0, TAU)
		var radius := _bg3d_rng.randf_range(90.0, 170.0)
		hill.position = Vector3(cos(angle) * radius, hill_mesh.size.y * 0.35, sin(angle) * radius)
		hill.rotation_degrees.y = _bg3d_rng.randf_range(0.0, 360.0)
		_bg3d_geometry_root.add_child(hill)

	_build_low_poly_forest(accent_color)
	_build_low_poly_clouds()
	_spawn_low_poly_animals()
	_apply_low_poly_weather(_weather_mode_for_hour(hour), true)
	_update_low_poly_solar(Time.get_time_dict_from_system())


func _build_low_poly_forest(accent_color: Color) -> void:
	var tree_count := 220 if _active_biome_visual == "broceliande" else 130
	for i in range(tree_count):
		var angle := _bg3d_rng.randf_range(0.0, TAU)
		var radius := _bg3d_rng.randf_range(18.0, 160.0)
		var pos := Vector3(cos(angle) * radius, _bg3d_rng.randf_range(-0.1, 0.4), sin(angle) * radius)
		var scale_factor := _bg3d_rng.randf_range(0.78, 1.48)
		var ancient := _active_biome_visual == "broceliande" and _bg3d_rng.randf() < 0.24
		_spawn_low_poly_tree(pos, scale_factor, ancient, accent_color)


func _spawn_low_poly_tree(base_pos: Vector3, scale_factor: float, ancient: bool, accent_color: Color) -> void:
	var tree_root := Node3D.new()
	tree_root.position = base_pos
	tree_root.rotation_degrees.y = _bg3d_rng.randf_range(0.0, 360.0)
	_bg3d_geometry_root.add_child(tree_root)

	var trunk := MeshInstance3D.new()
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.height = (2.4 if ancient else 1.9) * scale_factor
	trunk_mesh.bottom_radius = (0.22 if ancient else 0.15) * scale_factor
	trunk_mesh.top_radius = (0.17 if ancient else 0.11) * scale_factor
	trunk_mesh.radial_segments = 5
	trunk.mesh = trunk_mesh
	trunk.position.y = trunk_mesh.height * 0.5
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.20, 0.13, 0.09)
	trunk_mat.roughness = 1.0
	trunk.material_override = trunk_mat
	tree_root.add_child(trunk)

	for layer in range(4 if ancient else 3):
		var crown := MeshInstance3D.new()
		var crown_mesh := CylinderMesh.new()
		crown_mesh.height = (1.2 - float(layer) * 0.14) * scale_factor
		crown_mesh.bottom_radius = (1.18 - float(layer) * 0.18) * scale_factor
		crown_mesh.top_radius = 0.0
		crown_mesh.radial_segments = 5
		crown.mesh = crown_mesh
		crown.position.y = trunk_mesh.height + 0.28 + float(layer) * 0.52
		var crown_mat := StandardMaterial3D.new()
		var tint := _bg3d_rng.randf_range(-0.10, 0.08)
		crown_mat.albedo_color = Color(
			clampf(accent_color.r + tint, 0.0, 1.0),
			clampf(accent_color.g + tint * 0.6, 0.0, 1.0),
			clampf(accent_color.b + tint * 0.2, 0.0, 1.0)
		).darkened(0.32)
		crown_mat.roughness = 1.0
		crown.material_override = crown_mat
		tree_root.add_child(crown)


func _build_low_poly_clouds() -> void:
	for i in range(16):
		var cloud := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = _bg3d_rng.randf_range(1.4, 3.1)
		mesh.height = mesh.radius * 1.2
		mesh.radial_segments = 8
		mesh.rings = 4
		cloud.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.80, 0.88, 0.96, 0.36)
		cloud.material_override = mat
		cloud.position = Vector3(
			_bg3d_rng.randf_range(-180.0, 180.0),
			_bg3d_rng.randf_range(34.0, 58.0),
			_bg3d_rng.randf_range(-130.0, 120.0)
		)
		cloud.scale = Vector3(_bg3d_rng.randf_range(2.4, 6.8), _bg3d_rng.randf_range(0.35, 1.0), _bg3d_rng.randf_range(1.8, 3.4))
		cloud.set_meta("speed", _bg3d_rng.randf_range(0.6, 1.5))
		_bg3d_geometry_root.add_child(cloud)
		_bg3d_clouds.append(cloud)


func _spawn_low_poly_animals() -> void:
	for i in range(3):
		var animal := Node3D.new()
		animal.position = Vector3(_bg3d_rng.randf_range(-120.0, 120.0), 0.35, _bg3d_rng.randf_range(24.0, 68.0))
		animal.set_meta("speed", _bg3d_rng.randf_range(3.8, 6.8))
		animal.set_meta("dir", -1.0 if _bg3d_rng.randf() < 0.5 else 1.0)

		var body := MeshInstance3D.new()
		var body_mesh := BoxMesh.new()
		body_mesh.size = Vector3(1.2, 0.7, 0.5)
		body.mesh = body_mesh
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = Color(0.28, 0.20, 0.14)
		body_mat.roughness = 1.0
		body.material_override = body_mat
		animal.add_child(body)

		var head := MeshInstance3D.new()
		var head_mesh := SphereMesh.new()
		head_mesh.radius = 0.22
		head_mesh.height = 0.44
		head.mesh = head_mesh
		head.position = Vector3(0.76, 0.16, 0.0)
		head.material_override = body_mat
		animal.add_child(head)

		_bg3d_geometry_root.add_child(animal)
		_bg3d_animals.append(animal)


func _animate_low_poly_background_reveal() -> void:
	if not _bg3d_container or not is_instance_valid(_bg3d_container):
		return
	var tw := create_tween()
	tw.tween_property(_bg3d_container, "modulate:a", 1.0, 0.30).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _weather_mode_for_hour(hour: int) -> String:
	if hour >= 0 and hour < 5:
		return "mist"
	if hour >= 5 and hour < 9:
		return "clear"
	if hour >= 9 and hour < 13:
		return "cloudy"
	if hour >= 13 and hour < 17:
		return "rain"
	if hour >= 17 and hour < 21:
		return "storm"
	if hour >= 21 and hour < 23:
		return "cloudy"
	return "snow"


func _apply_low_poly_weather(mode: String, instant: bool) -> void:
	_bg3d_weather_mode = mode
	var fog_density := 0.016
	var fog_color := Color(0.24, 0.34, 0.30)
	var volumetric_density := 0.036
	var enable_rain := false
	var enable_snow := false
	var enable_leaves := _active_biome_visual == "broceliande"
	_bg3d_light_factor = 1.0

	match mode:
		"clear":
			fog_density = 0.010
			fog_color = Color(0.28, 0.40, 0.38)
			volumetric_density = 0.022
			_bg3d_light_factor = 1.0
		"cloudy":
			fog_density = 0.015
			fog_color = Color(0.23, 0.34, 0.40)
			volumetric_density = 0.032
			_bg3d_light_factor = 0.84
		"rain":
			fog_density = 0.022
			fog_color = Color(0.18, 0.28, 0.36)
			volumetric_density = 0.050
			enable_rain = true
			_bg3d_light_factor = 0.70
		"storm":
			fog_density = 0.028
			fog_color = Color(0.13, 0.20, 0.30)
			volumetric_density = 0.065
			enable_rain = true
			_bg3d_light_factor = 0.56
		"mist":
			fog_density = 0.031
			fog_color = Color(0.22, 0.34, 0.36)
			volumetric_density = 0.075
			_bg3d_light_factor = 0.62
		"snow":
			fog_density = 0.024
			fog_color = Color(0.34, 0.44, 0.54)
			volumetric_density = 0.052
			enable_snow = true
			enable_leaves = false
			_bg3d_light_factor = 0.76

	if _bg3d_environment and is_instance_valid(_bg3d_environment):
		if instant:
			_bg3d_environment.fog_density = fog_density
			_bg3d_environment.fog_light_color = fog_color
			_bg3d_environment.set("volumetric_fog_density", volumetric_density)
			_bg3d_environment.set("volumetric_fog_albedo", fog_color)
		else:
			var tw := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tw.tween_property(_bg3d_environment, "fog_density", fog_density, 1.4)
			tw.parallel().tween_property(_bg3d_environment, "fog_light_color", fog_color, 1.4)

	if _bg3d_rain and is_instance_valid(_bg3d_rain):
		_bg3d_rain.emitting = enable_rain
	if _bg3d_snow and is_instance_valid(_bg3d_snow):
		_bg3d_snow.emitting = enable_snow
	if _bg3d_leaves and is_instance_valid(_bg3d_leaves):
		_bg3d_leaves.emitting = enable_leaves


func _update_low_poly_solar(now_time: Dictionary) -> void:
	if not _bg3d_sun or not is_instance_valid(_bg3d_sun):
		return
	var hour := float(now_time.get("hour", 12))
	var minute := float(now_time.get("minute", 0))
	var second := float(now_time.get("second", 0))
	var time_float := hour + minute / 60.0 + second / 3600.0
	var orbit := (time_float / 24.0) * TAU
	var altitude := sin(orbit - PI * 0.5)
	var daylight := clampf((altitude + 0.22) / 1.22, 0.0, 1.0)
	var azimuth := wrapf((time_float / 24.0) * 360.0 + 32.0, 0.0, 360.0)

	_bg3d_sun.rotation_degrees = Vector3(lerpf(24.0, -84.0, daylight), azimuth, 0.0)
	_bg3d_sun.light_color = Color(0.08, 0.16, 0.40).lerp(Color(0.28, 0.62, 1.0), daylight)
	_bg3d_sun.light_energy = lerpf(0.08, 1.62, daylight) * _bg3d_light_factor

	if _bg3d_fill and is_instance_valid(_bg3d_fill):
		_bg3d_fill.light_color = Color(0.46, 0.28, 0.62).lerp(Color(0.24, 0.30, 0.40), daylight)
		_bg3d_fill.light_energy = lerpf(0.34, 0.08, daylight)

	if _bg3d_environment and is_instance_valid(_bg3d_environment):
		_bg3d_environment.background_color = Color(0.02, 0.04, 0.10).lerp(Color(0.12, 0.26, 0.34), daylight)
		_bg3d_environment.ambient_light_energy = lerpf(0.28, 0.92, daylight) * _bg3d_light_factor


func _update_low_poly_background(delta: float) -> void:
	if not _bg3d_geometry_root or not is_instance_valid(_bg3d_geometry_root):
		return

	for cloud in _bg3d_clouds:
		if not cloud or not is_instance_valid(cloud):
			continue
		var speed := float(cloud.get_meta("speed", 0.9))
		var pos := cloud.position
		pos.x += speed * delta * 4.0
		if pos.x > 190.0:
			pos.x = -190.0
		cloud.position = pos

	for animal in _bg3d_animals:
		if not animal or not is_instance_valid(animal):
			continue
		var speed := float(animal.get_meta("speed", 4.5))
		var direction := float(animal.get_meta("dir", 1.0))
		var pos := animal.position
		pos.x += speed * direction * delta
		if pos.x > 140.0:
			pos.x = -140.0
			pos.z = _bg3d_rng.randf_range(24.0, 68.0)
		elif pos.x < -140.0:
			pos.x = 140.0
			pos.z = _bg3d_rng.randf_range(24.0, 68.0)
		animal.position = pos
		animal.rotation_degrees.y = 0.0 if direction > 0.0 else 180.0

	_bg3d_weather_timer += delta
	if _bg3d_weather_timer >= 1.0:
		_bg3d_weather_timer = 0.0
		var now := Time.get_time_dict_from_system()
		var hour := int(now.get("hour", 12))
		var target_mode := _weather_mode_for_hour(hour)
		if target_mode != _bg3d_weather_mode:
			_apply_low_poly_weather(target_mode, false)

	_update_low_poly_solar(Time.get_time_dict_from_system())


func _create_clock_status_panel() -> void:
	_status_clock_panel = PanelContainer.new()
	_status_clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_clock_panel.z_index = 8
	_status_clock_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status_clock_panel.position = Vector2(18, 14)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(PALETTE.paper_dark.r, PALETTE.paper_dark.g, PALETTE.paper_dark.b, 0.92)
	panel_style.border_color = PALETTE.accent
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.content_margin_left = 10
	panel_style.content_margin_right = 10
	panel_style.content_margin_top = 5
	panel_style.content_margin_bottom = 4
	_status_clock_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_status_clock_panel)

	_status_clock_label = Label.new()
	_status_clock_label.text = "00:00"
	_status_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_clock_label.add_theme_font_size_override("font_size", 15)
	_status_clock_label.add_theme_color_override("font_color", PALETTE.ink)
	if body_font:
		_status_clock_label.add_theme_font_override("font", body_font)
	_status_clock_panel.add_child(_status_clock_label)
	_update_clock_status()

	_status_clock_timer = Timer.new()
	_status_clock_timer.wait_time = 1.0
	_status_clock_timer.autostart = true
	_status_clock_timer.timeout.connect(_update_clock_status)
	add_child(_status_clock_timer)


func _update_clock_status() -> void:
	if not _status_clock_label or not is_instance_valid(_status_clock_label):
		return
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var hour := int(now.get("hour", 0))
	var minute := int(now.get("minute", 0))
	_status_clock_label.text = "%02d:%02d" % [hour, minute]


func _create_aspect_displays(parent: Control) -> void:
	aspect_panel = HBoxContainer.new()
	aspect_panel.add_theme_constant_override("separation", 16)
	parent.add_child(aspect_panel)

	for aspect in MerlinConstants.TRIADE_ASPECTS:
		var container := VBoxContainer.new()
		container.alignment = BoxContainer.ALIGNMENT_CENTER

		# Drawn Celtic animal icon (custom Control with _draw)
		var icon := _create_animal_icon(aspect)
		container.add_child(icon)

		# Aspect name
		var name_label := Label.new()
		name_label.text = aspect
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", ASPECT_COLORS.get(aspect, Color.WHITE))
		if title_font:
			name_label.add_theme_font_override("font", title_font)
		name_label.add_theme_font_size_override("font_size", 13)
		container.add_child(name_label)

		# State indicator (3 dots)
		var state_container := HBoxContainer.new()
		state_container.alignment = BoxContainer.ALIGNMENT_CENTER
		state_container.add_theme_constant_override("separation", 4)

		for i in range(3):
			var circle := Label.new()
			circle.text = "\u25CB"
			circle.add_theme_font_size_override("font_size", 14)
			circle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			state_container.add_child(circle)

		container.add_child(state_container)

		# State name + shift arrow (inline)
		var state_row := HBoxContainer.new()
		state_row.alignment = BoxContainer.ALIGNMENT_CENTER
		state_row.add_theme_constant_override("separation", 3)

		var state_name := Label.new()
		state_name.text = "Equilibre"
		state_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if body_font:
			state_name.add_theme_font_override("font", body_font)
		state_name.add_theme_font_size_override("font_size", 11)
		state_name.add_theme_color_override("font_color", PALETTE.ink_soft)
		state_row.add_child(state_name)

		var shift_arrow := Label.new()
		shift_arrow.text = ""
		shift_arrow.add_theme_font_size_override("font_size", 11)
		shift_arrow.add_theme_color_override("font_color", Color.GRAY)
		state_row.add_child(shift_arrow)
		container.add_child(state_row)

		aspect_panel.add_child(container)

		aspect_displays[aspect] = {
			"container": container,
			"icon": icon,
			"state_container": state_container,
			"state_name": state_name,
			"shift_arrow": shift_arrow,
		}


func _create_animal_icon(aspect: String) -> Control:
	## Creates a custom-drawn Celtic animal icon for each aspect.
	var icon := Control.new()
	icon.custom_minimum_size = Vector2(56, 48)
	var aspect_color: Color = ASPECT_COLORS.get(aspect, Color.WHITE)
	var animal: String = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect, {}).get("animal", "")
	icon.draw.connect(_draw_animal.bind(icon, animal, aspect_color))
	return icon


func _draw_animal(ctrl: Control, animal: String, color: Color) -> void:
	## Draw Celtic-style animal silhouettes using vector shapes.
	var sz := ctrl.size
	var cx := sz.x * 0.5
	var cy := sz.y * 0.5
	var r := mini(int(sz.x), int(sz.y)) * 0.4

	match animal:
		"sanglier":  # Boar — Corps (strength)
			_draw_sanglier(ctrl, cx, cy, r, color)
		"corbeau":  # Raven — Ame (spirit)
			_draw_corbeau(ctrl, cx, cy, r, color)
		"cerf":  # Stag — Monde (world)
			_draw_cerf(ctrl, cx, cy, r, color)
		_:
			# Fallback: Celtic spiral
			ctrl.draw_arc(Vector2(cx, cy), r, 0.0, TAU, 24, color, 2.0)


func _draw_sanglier(ctrl: Control, cx: float, cy: float, r: float, color: Color) -> void:
	## Sanglier (boar) — stocky body with tusks, Celtic knotwork style.
	var body := PackedVector2Array()
	# Body shape (rounded rectangle-ish)
	body.append(Vector2(cx - r * 0.9, cy + r * 0.2))
	body.append(Vector2(cx - r * 0.7, cy - r * 0.5))
	body.append(Vector2(cx - r * 0.2, cy - r * 0.7))
	body.append(Vector2(cx + r * 0.3, cy - r * 0.6))
	body.append(Vector2(cx + r * 0.8, cy - r * 0.3))
	body.append(Vector2(cx + r * 1.0, cy + r * 0.1))
	body.append(Vector2(cx + r * 0.8, cy + r * 0.5))
	body.append(Vector2(cx + r * 0.3, cy + r * 0.7))
	body.append(Vector2(cx - r * 0.4, cy + r * 0.6))
	body.append(Vector2(cx - r * 0.9, cy + r * 0.2))
	ctrl.draw_polyline(body, color, 2.0, true)
	# Tusks
	ctrl.draw_line(Vector2(cx + r * 0.85, cy - r * 0.1), Vector2(cx + r * 1.1, cy - r * 0.5), color, 2.0)
	ctrl.draw_line(Vector2(cx + r * 0.85, cy + r * 0.0), Vector2(cx + r * 1.1, cy + r * 0.1), color, 1.5)
	# Eye
	ctrl.draw_circle(Vector2(cx + r * 0.5, cy - r * 0.2), r * 0.12, color)
	# Legs (front + back)
	ctrl.draw_line(Vector2(cx - r * 0.5, cy + r * 0.6), Vector2(cx - r * 0.5, cy + r * 1.0), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.4, cy + r * 0.65), Vector2(cx + r * 0.4, cy + r * 1.0), color, 1.5)


func _draw_corbeau(ctrl: Control, cx: float, cy: float, r: float, color: Color) -> void:
	## Corbeau (raven) — wings spread, Celtic knot-style.
	# Body
	var body := PackedVector2Array()
	body.append(Vector2(cx + r * 0.8, cy + r * 0.1))
	body.append(Vector2(cx + r * 0.5, cy - r * 0.3))
	body.append(Vector2(cx + r * 0.1, cy - r * 0.2))
	body.append(Vector2(cx - r * 0.3, cy + r * 0.1))
	body.append(Vector2(cx - r * 0.5, cy + r * 0.4))
	body.append(Vector2(cx + r * 0.2, cy + r * 0.5))
	body.append(Vector2(cx + r * 0.8, cy + r * 0.1))
	ctrl.draw_polyline(body, color, 2.0, true)
	# Beak
	ctrl.draw_line(Vector2(cx + r * 0.8, cy + r * 0.1), Vector2(cx + r * 1.2, cy - r * 0.05), color, 2.0)
	ctrl.draw_line(Vector2(cx + r * 1.2, cy - r * 0.05), Vector2(cx + r * 0.8, cy + r * 0.2), color, 1.5)
	# Eye
	ctrl.draw_circle(Vector2(cx + r * 0.55, cy - r * 0.1), r * 0.1, color)
	# Left wing (spread)
	var wing := PackedVector2Array()
	wing.append(Vector2(cx - r * 0.1, cy - r * 0.1))
	wing.append(Vector2(cx - r * 0.7, cy - r * 0.8))
	wing.append(Vector2(cx - r * 1.0, cy - r * 0.5))
	wing.append(Vector2(cx - r * 0.8, cy - r * 0.2))
	wing.append(Vector2(cx - r * 0.3, cy + r * 0.1))
	ctrl.draw_polyline(wing, color, 1.5, true)
	# Tail feathers
	ctrl.draw_line(Vector2(cx - r * 0.5, cy + r * 0.4), Vector2(cx - r * 0.9, cy + r * 0.7), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.5, cy + r * 0.4), Vector2(cx - r * 0.7, cy + r * 0.8), color, 1.5)


func _draw_cerf(ctrl: Control, cx: float, cy: float, r: float, color: Color) -> void:
	## Cerf (stag) — proud head with antlers, Celtic knotwork style.
	# Head
	var head := PackedVector2Array()
	head.append(Vector2(cx, cy + r * 0.8))
	head.append(Vector2(cx - r * 0.3, cy + r * 0.3))
	head.append(Vector2(cx - r * 0.25, cy - r * 0.2))
	head.append(Vector2(cx, cy - r * 0.4))
	head.append(Vector2(cx + r * 0.25, cy - r * 0.2))
	head.append(Vector2(cx + r * 0.3, cy + r * 0.3))
	head.append(Vector2(cx, cy + r * 0.8))
	ctrl.draw_polyline(head, color, 2.0, true)
	# Eye
	ctrl.draw_circle(Vector2(cx, cy), r * 0.1, color)
	# Left antler (branching)
	ctrl.draw_line(Vector2(cx - r * 0.25, cy - r * 0.2), Vector2(cx - r * 0.6, cy - r * 0.8), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.4, cy - r * 0.5), Vector2(cx - r * 0.8, cy - r * 0.6), color, 1.5)
	ctrl.draw_line(Vector2(cx - r * 0.55, cy - r * 0.7), Vector2(cx - r * 0.9, cy - r * 0.9), color, 1.5)
	# Right antler (mirrored)
	ctrl.draw_line(Vector2(cx + r * 0.25, cy - r * 0.2), Vector2(cx + r * 0.6, cy - r * 0.8), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.4, cy - r * 0.5), Vector2(cx + r * 0.8, cy - r * 0.6), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.55, cy - r * 0.7), Vector2(cx + r * 0.9, cy - r * 0.9), color, 1.5)
	# Ears
	ctrl.draw_line(Vector2(cx - r * 0.2, cy - r * 0.3), Vector2(cx - r * 0.35, cy - r * 0.45), color, 1.5)
	ctrl.draw_line(Vector2(cx + r * 0.2, cy - r * 0.3), Vector2(cx + r * 0.35, cy - r * 0.45), color, 1.5)


func _create_life_display(parent: Control) -> void:
	life_panel = VBoxContainer.new()
	life_panel.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := Label.new()
	title.text = "Vie"
	if title_font:
		title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", PALETTE.ink_soft)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	life_panel.add_child(title)

	_life_bar = ProgressBar.new()
	_life_bar.custom_minimum_size = Vector2(168, 12)
	_life_bar.min_value = 0
	_life_bar.max_value = MerlinConstants.LIFE_ESSENCE_MAX
	_life_bar.step = 1
	_life_bar.show_percentage = false
	_life_bar.value = MerlinConstants.LIFE_ESSENCE_START

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.78, 0.18, 0.16)
	fill_style.set_corner_radius_all(3)
	_life_bar.add_theme_stylebox_override("fill", fill_style)
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.08, 0.08, 0.08, 0.55)
	background_style.set_corner_radius_all(3)
	_life_bar.add_theme_stylebox_override("background", background_style)
	life_panel.add_child(_life_bar)

	_life_counter = Label.new()
	_life_counter.text = "%d/%d" % [MerlinConstants.LIFE_ESSENCE_START, MerlinConstants.LIFE_ESSENCE_MAX]
	_life_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body_font:
		_life_counter.add_theme_font_override("font", body_font)
	_life_counter.add_theme_font_size_override("font_size", 12)
	_life_counter.add_theme_color_override("font_color", Color(0.82, 0.24, 0.22))
	life_panel.add_child(_life_counter)

	parent.add_child(life_panel)


func _create_souffle_display(parent: Control) -> void:
	souffle_panel = VBoxContainer.new()
	souffle_panel.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := Label.new()
	title.text = "Souffle unique"
	if title_font:
		title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", PALETTE.ink_soft)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	souffle_panel.add_child(title)

	souffle_display = HBoxContainer.new()
	souffle_display.alignment = BoxContainer.ALIGNMENT_CENTER
	souffle_display.add_theme_constant_override("separation", 4)

	for i in range(MerlinConstants.SOUFFLE_MAX):
		var icon := Label.new()
		icon.text = SOUFFLE_EMPTY
		icon.add_theme_font_size_override("font_size", 28)
		souffle_display.add_child(icon)

	souffle_panel.add_child(souffle_display)

	# Numeric counter "3/7"
	_souffle_counter = Label.new()
	_souffle_counter.text = "%d/%d" % [MerlinConstants.SOUFFLE_START, MerlinConstants.SOUFFLE_MAX]
	_souffle_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if body_font:
		_souffle_counter.add_theme_font_override("font", body_font)
	_souffle_counter.add_theme_font_size_override("font_size", 12)
	_souffle_counter.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))
	souffle_panel.add_child(_souffle_counter)

	parent.add_child(souffle_panel)


func _create_essence_display(parent: Control) -> void:
	var essence_panel := VBoxContainer.new()
	essence_panel.alignment = BoxContainer.ALIGNMENT_CENTER

	var title := Label.new()
	title.text = "Essences"
	if title_font:
		title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", PALETTE.ink_soft)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	essence_panel.add_child(title)

	_essence_counter = Label.new()
	_essence_counter.text = "0"
	if body_font:
		_essence_counter.add_theme_font_override("font", body_font)
	_essence_counter.add_theme_font_size_override("font_size", 22)
	_essence_counter.add_theme_color_override("font_color", Color(0.68, 0.56, 0.30))
	_essence_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	essence_panel.add_child(_essence_counter)

	var caption := Label.new()
	caption.text = "a collecter"
	if body_font:
		caption.add_theme_font_override("font", body_font)
	caption.add_theme_font_size_override("font_size", 10)
	caption.add_theme_color_override("font_color", PALETTE.ink_soft)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	essence_panel.add_child(caption)

	parent.add_child(essence_panel)


func _create_resource_bar(parent: Control) -> void:
	_resource_bar = HBoxContainer.new()
	_resource_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_resource_bar.add_theme_constant_override("separation", 20)

	# Tool equipped
	_tool_label = Label.new()
	_tool_label.text = ""
	if body_font:
		_tool_label.add_theme_font_override("font", body_font)
	_tool_label.add_theme_font_size_override("font_size", 11)
	_tool_label.add_theme_color_override("font_color", PALETTE.accent)
	_resource_bar.add_child(_tool_label)

	# Day counter
	_day_label = Label.new()
	_day_label.text = "Jour 1"
	if body_font:
		_day_label.add_theme_font_override("font", body_font)
	_day_label.add_theme_font_size_override("font_size", 11)
	_day_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	_resource_bar.add_child(_day_label)

	# Mission progress
	_mission_progress_label = Label.new()
	_mission_progress_label.text = ""
	if body_font:
		_mission_progress_label.add_theme_font_override("font", body_font)
	_mission_progress_label.add_theme_font_size_override("font_size", 11)
	_mission_progress_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	_resource_bar.add_child(_mission_progress_label)

	parent.add_child(_resource_bar)


func _create_card_display(parent: Control) -> void:
	card_container = Control.new()
	card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_container.size_flags_vertical = Control.SIZE_FILL
	card_container.clip_contents = false
	parent.add_child(card_container)

	card_panel = Panel.new()
	card_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_panel.z_index = 2
	card_panel.pivot_offset = Vector2(320, 200)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = PALETTE.paper_dark
	card_style.border_color = PALETTE.accent
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(10)
	card_style.shadow_color = PALETTE.shadow
	card_style.shadow_size = 12
	card_style.shadow_offset = Vector2(0, 5)
	card_panel.add_theme_stylebox_override("panel", card_style)
	card_container.add_child(card_panel)

	_card_visual_split = VBoxContainer.new()
	_card_visual_split.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_visual_split.add_theme_constant_override("separation", 0)
	card_panel.add_child(_card_visual_split)

	_card_illustration_panel = PanelContainer.new()
	_card_illustration_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var illo_style := StyleBoxFlat.new()
	illo_style.bg_color = Color(0.12, 0.14, 0.18, 0.78)
	illo_style.border_color = Color(PALETTE.accent.r, PALETTE.accent.g, PALETTE.accent.b, 0.5)
	illo_style.set_border_width_all(1)
	illo_style.set_corner_radius_all(8)
	illo_style.content_margin_left = 6
	illo_style.content_margin_right = 6
	illo_style.content_margin_top = 6
	illo_style.content_margin_bottom = 6
	_card_illustration_panel.add_theme_stylebox_override("panel", illo_style)
	_card_visual_split.add_child(_card_illustration_panel)

	var illo_layer := Control.new()
	illo_layer.custom_minimum_size = Vector2(0, 220)
	illo_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_card_illustration_panel.add_child(illo_layer)

	var illo_bg := ColorRect.new()
	illo_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	illo_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	illo_bg.color = Color(0.10, 0.12, 0.15, 0.95)
	illo_layer.add_child(illo_bg)

	var tile_center := CenterContainer.new()
	tile_center.name = "TileCenter"
	tile_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	illo_layer.add_child(tile_center)

	_encounter_tile = PixelEncounterTile.new()
	_encounter_tile.name = "EncounterTile"
	_encounter_tile.setup("mystery", 7.2)
	tile_center.add_child(_encounter_tile)

	var portrait_center := CenterContainer.new()
	portrait_center.name = "PortraitCenter"
	portrait_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	portrait_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	illo_layer.add_child(portrait_center)

	_pixel_portrait = PixelCharacterPortrait.new()
	_pixel_portrait.name = "PixelPortrait"
	_pixel_portrait.setup("merlin", 5.8)
	portrait_center.add_child(_pixel_portrait)

	_card_body_panel = PanelContainer.new()
	_card_body_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var body_style := StyleBoxFlat.new()
	body_style.bg_color = Color(PALETTE.paper.r, PALETTE.paper.g, PALETTE.paper.b, 0.96)
	body_style.border_color = Color(PALETTE.ink_faded.r, PALETTE.ink_faded.g, PALETTE.ink_faded.b, 0.6)
	body_style.set_border_width_all(1)
	body_style.set_corner_radius_all(8)
	body_style.content_margin_left = 18
	body_style.content_margin_right = 18
	body_style.content_margin_top = 12
	body_style.content_margin_bottom = 12
	_card_body_panel.add_theme_stylebox_override("panel", body_style)
	_card_visual_split.add_child(_card_body_panel)

	var body_vbox := VBoxContainer.new()
	body_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	body_vbox.add_theme_constant_override("separation", 8)
	_card_body_panel.add_child(body_vbox)

	card_speaker = Label.new()
	card_speaker.text = "MERLIN"
	if title_font:
		card_speaker.add_theme_font_override("font", title_font)
	card_speaker.add_theme_font_size_override("font_size", 20)
	card_speaker.add_theme_color_override("font_color", PALETTE.accent)
	card_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_vbox.add_child(card_speaker)

	card_text = RichTextLabel.new()
	card_text.text = "Le vent souffle sur les landes..."
	card_text.bbcode_enabled = true
	card_text.fit_content = true
	card_text.scroll_active = false
	card_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if body_font:
		card_text.add_theme_font_override("normal_font", body_font)
	card_text.add_theme_font_size_override("normal_font_size", 18)
	card_text.add_theme_color_override("default_color", PALETTE.ink)
	body_vbox.add_child(card_text)

	_card_source_badge = LLMSourceBadge.create("static")
	_card_source_badge.visible = false
	body_vbox.add_child(_card_source_badge)

	_text_pixel_fx_layer = Control.new()
	_text_pixel_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text_pixel_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_pixel_fx_layer.z_index = 5
	card_panel.add_child(_text_pixel_fx_layer)


func _build_remaining_deck_stack() -> void:
	if not _remaining_deck_root or not is_instance_valid(_remaining_deck_root):
		return
	for child in _remaining_deck_root.get_children():
		child.queue_free()
	_remaining_deck_cards.clear()

	for i in range(LIVE_DECK_VISIBLE_COUNT):
		var deck_card := Panel.new()
		deck_card.size = Vector2(68, 94)
		deck_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		deck_card.modulate.a = 0.95 - float(i) * 0.1
		deck_card.pivot_offset = deck_card.size * 0.5
		var deck_style := StyleBoxFlat.new()
		deck_style.bg_color = Color(0.14, 0.18, 0.25, 0.96)
		deck_style.border_color = Color(0.42, 0.62, 0.84, 0.72)
		deck_style.set_border_width_all(2)
		deck_style.set_corner_radius_all(7)
		deck_style.shadow_color = Color(0, 0, 0, 0.3)
		deck_style.shadow_size = 6
		deck_style.shadow_offset = Vector2(0, 2)
		deck_card.add_theme_stylebox_override("panel", deck_style)
		_remaining_deck_root.add_child(deck_card)
		_remaining_deck_cards.append(deck_card)

	_update_remaining_deck_visual()


func _update_remaining_deck_visual() -> void:
	if _remaining_deck_cards.is_empty():
		return
	var visible_count := clampi(_remaining_deck_estimate, 0, LIVE_DECK_VISIBLE_COUNT)
	for i in range(_remaining_deck_cards.size()):
		var card := _remaining_deck_cards[i]
		if not card or not is_instance_valid(card):
			continue
		card.position = Vector2(10.0 + float(i) * 3.0, 12.0 - float(i) * 2.0)
		card.rotation_degrees = -8.0 + float(i) * 2.4
		card.scale = Vector2(1.0, 1.0)
		card.modulate.a = clampf(0.92 - float(i) * 0.12, 0.18, 1.0) if i < visible_count else 0.0

	if _remaining_deck_label and is_instance_valid(_remaining_deck_label):
		_remaining_deck_label.text = "Run: %d restantes" % maxi(_remaining_deck_estimate, 0)


func _build_discard_stack() -> void:
	if not _discard_root or not is_instance_valid(_discard_root):
		return
	for child in _discard_root.get_children():
		child.queue_free()
	_discard_cards.clear()

	for i in range(DISCARD_VISIBLE_COUNT):
		var discard_card := Panel.new()
		discard_card.size = Vector2(44, 62)
		discard_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		discard_card.pivot_offset = discard_card.size * 0.5
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.16, 0.14, 0.12, 0.70)
		style.border_color = Color(0.64, 0.56, 0.42, 0.82)
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.shadow_color = Color(0, 0, 0, 0.24)
		style.shadow_size = 4
		style.shadow_offset = Vector2(0, 1)
		discard_card.add_theme_stylebox_override("panel", style)
		_discard_root.add_child(discard_card)
		_discard_cards.append(discard_card)

	_update_discard_visual()


func _update_discard_visual() -> void:
	if _discard_cards.is_empty():
		return
	var visible_count := clampi(_discard_total, 0, DISCARD_VISIBLE_COUNT)
	for i in range(_discard_cards.size()):
		var card := _discard_cards[i]
		if not card or not is_instance_valid(card):
			continue
		card.position = Vector2(6.0 + float(i) * 3.0, 14.0 - float(i) * 1.6)
		card.rotation_degrees = 2.0 + float(i) * 1.8
		card.modulate.a = clampf(0.86 - float(i) * 0.14, 0.18, 1.0) if i < visible_count else 0.08
	if _discard_label and is_instance_valid(_discard_label):
		_discard_label.text = "Cimetiere: %d" % maxi(_discard_total, 0)


func reset_run_visuals() -> void:
	_remaining_deck_estimate = RUN_DECK_ESTIMATE
	_discard_total = 0
	_update_remaining_deck_visual()
	_update_discard_visual()


func mark_card_completed() -> void:
	if current_card.is_empty():
		return
	if bool(current_card.get("_placeholder", false)):
		return
	_discard_total += 1
	_update_discard_visual()


func _layout_run_zones() -> void:
	var vp_size := get_viewport_rect().size
	if vp_size.y <= 0.0:
		return
	var top_h := maxf(68.0, vp_size.y * TOP_ZONE_RATIO)
	var card_h := maxf(260.0, vp_size.y * CARD_ZONE_RATIO)
	var bottom_h := maxf(94.0, vp_size.y * BOTTOM_ZONE_RATIO)
	var total := top_h + card_h + bottom_h
	if total > vp_size.y:
		var overflow := total - vp_size.y
		card_h = maxf(220.0, card_h - overflow)

	if _top_status_bar and is_instance_valid(_top_status_bar):
		_top_status_bar.custom_minimum_size = Vector2(0.0, top_h)
	if card_container and is_instance_valid(card_container):
		card_container.custom_minimum_size = Vector2(0.0, card_h)
	if _bottom_zone and is_instance_valid(_bottom_zone):
		_bottom_zone.custom_minimum_size = Vector2(0.0, bottom_h)


func _layout_card_stage() -> void:
	if not card_container or not is_instance_valid(card_container):
		return
	var stage_size := card_container.size
	if stage_size.x <= 40.0 or stage_size.y <= 40.0:
		stage_size = get_viewport_rect().size

	var target_h := clampf(stage_size.y, 260.0, 1080.0)
	var max_w := minf(stage_size.x * 0.80, 920.0)
	var target_w := clampf(target_h * CARD_PORTRAIT_RATIO, 220.0, max_w)
	var target_size := Vector2(target_w, target_h)
	card_panel.size = target_size
	card_panel.custom_minimum_size = target_size
	var centered_y := (stage_size.y - target_size.y) * 0.50
	var max_y := maxf(6.0, stage_size.y - target_size.y - 6.0)
	_card_base_pos = Vector2(
		(stage_size.x - target_size.x) * 0.50,
		clampf(centered_y, 6.0, max_y)
	)
	card_panel.position = _card_base_pos
	card_panel.pivot_offset = target_size * 0.5

	if _card_illustration_panel and is_instance_valid(_card_illustration_panel):
		_card_illustration_panel.custom_minimum_size = Vector2(0.0, target_size.y * 0.72)
	if _card_body_panel and is_instance_valid(_card_body_panel):
		_card_body_panel.custom_minimum_size = Vector2(0.0, target_size.y * 0.28)
	_update_remaining_deck_visual()
	_update_discard_visual()


func _get_deck_draw_origin() -> Vector2:
	if not _remaining_deck_root or not is_instance_valid(_remaining_deck_root):
		return _card_base_pos + Vector2(200.0, 40.0)
	var source_global := _remaining_deck_root.global_position
	var local_in_card := card_container.get_global_transform().affine_inverse() * (source_global + Vector2(18.0, 16.0))
	return local_in_card


func _animate_remaining_deck_draw() -> void:
	if _remaining_deck_cards.is_empty():
		return
	var top_card: Panel = _remaining_deck_cards.pop_front()
	if not top_card or not is_instance_valid(top_card):
		return
	_remaining_deck_cards.append(top_card)
	_update_remaining_deck_visual()

	if not _deck_fx_layer or not is_instance_valid(_deck_fx_layer):
		return
	var draw_target := card_container.global_position + _card_base_pos + Vector2(card_panel.size.x * 0.22, card_panel.size.y * 0.24)
	var to_fx := _deck_fx_layer.get_global_transform().affine_inverse()
	var start_fx: Vector2 = to_fx * top_card.global_position
	var target_fx: Vector2 = to_fx * draw_target

	var ghost := Panel.new()
	ghost.size = top_card.size
	ghost.position = start_fx
	ghost.rotation_degrees = top_card.rotation_degrees
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.z_index = 14
	var base_style := top_card.get_theme_stylebox("panel")
	if base_style:
		ghost.add_theme_stylebox_override("panel", base_style.duplicate())
	_deck_fx_layer.add_child(ghost)
	_deck_fx_layer.visible = true

	var tw := create_tween()
	tw.tween_property(ghost, "position", target_fx, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ghost, "rotation_degrees", randf_range(-13.0, 13.0), 0.16)
	tw.parallel().tween_property(ghost, "scale", Vector2(1.08, 1.08), 0.16)
	tw.tween_property(ghost, "scale:x", 0.02, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(ghost, "modulate:a", 0.0, 0.08)
	tw.tween_callback(func():
		if is_instance_valid(ghost):
			ghost.queue_free()
		if _deck_fx_layer and is_instance_valid(_deck_fx_layer) and _deck_fx_layer.get_child_count() == 0:
			_deck_fx_layer.visible = false
	)


func _start_card_float_motion() -> void:
	if not card_panel or not is_instance_valid(card_panel):
		return
	if _card_float_tween:
		_card_float_tween.kill()
	_card_panel_safe_reset_transform()
	_card_float_tween = create_tween().set_loops()
	_card_float_tween.tween_property(card_panel, "position:y", _card_base_pos.y - CARD_FLOAT_OFFSET, CARD_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_card_float_tween.tween_property(card_panel, "position:y", _card_base_pos.y + CARD_FLOAT_OFFSET * 0.6, CARD_FLOAT_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _card_panel_safe_reset_transform() -> void:
	if not card_panel or not is_instance_valid(card_panel):
		return
	card_panel.scale = Vector2.ONE
	card_panel.rotation_degrees = 0.0
	card_panel.position = _card_base_pos


func _create_options_bar(parent: Control) -> void:
	options_container = HBoxContainer.new()
	options_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	options_container.add_theme_constant_override("separation", 14)
	parent.add_child(options_container)

	var option_configs := [
		{"key": "A", "pos": "left", "color": Color(0.35, 0.55, 0.72)},
		{"key": "B", "pos": "center", "color": PALETTE.accent},
		{"key": "C", "pos": "right", "color": Color(0.72, 0.35, 0.32)},
	]

	for i in range(3):
		var config = option_configs[i]
		var option_vbox := VBoxContainer.new()
		option_vbox.alignment = BoxContainer.ALIGNMENT_CENTER

		# Option label
		var label := Label.new()
		label.text = "Action"
		if body_font:
			label.add_theme_font_override("font", body_font)
		label.add_theme_font_size_override("font_size", 12)
		label.add_theme_color_override("font_color", PALETTE.ink_soft)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		option_labels.append(label)
		option_vbox.add_child(label)

		# Button with parchment style
		var btn := Button.new()
		btn.text = "[%s] Agir" % config["key"]
		btn.custom_minimum_size = Vector2(232, 52)
		if title_font:
			btn.add_theme_font_override("font", title_font)
		btn.add_theme_font_size_override("font_size", 17)

		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = PALETTE.paper
		btn_style.border_color = config["color"]
		btn_style.set_border_width_all(2)
		btn_style.set_corner_radius_all(6)
		btn_style.content_margin_left = 14
		btn_style.content_margin_right = 14
		btn_style.content_margin_top = 11
		btn_style.content_margin_bottom = 11
		btn_style.shadow_color = PALETTE.shadow
		btn_style.shadow_size = 5
		btn_style.shadow_offset = Vector2(0, 2)
		btn.add_theme_stylebox_override("normal", btn_style)

		var btn_hover := btn_style.duplicate()
		btn_hover.bg_color = PALETTE.paper_dark
		btn.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed := btn_style.duplicate()
		btn_pressed.bg_color = Color(config["color"].r, config["color"].g, config["color"].b, 0.15)
		btn.add_theme_stylebox_override("pressed", btn_pressed)

		btn.add_theme_color_override("font_color", config["color"])
		btn.add_theme_color_override("font_hover_color", config["color"])
		btn.pressed.connect(_on_option_pressed.bind(i))
		btn.mouse_entered.connect(_on_option_hover_enter.bind(i))
		btn.mouse_exited.connect(_on_option_hover_exit)
		option_buttons.append(btn)
		option_vbox.add_child(btn)

		options_container.add_child(option_vbox)


func _create_run_stack_bar(parent: Control) -> void:
	_run_stack_bar = HBoxContainer.new()
	_run_stack_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_stack_bar.add_theme_constant_override("separation", 18)
	parent.add_child(_run_stack_bar)

	var deck_wrap := VBoxContainer.new()
	deck_wrap.custom_minimum_size = Vector2(180, 82)
	deck_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	_run_stack_bar.add_child(deck_wrap)

	_remaining_deck_label = Label.new()
	_remaining_deck_label.text = "Run: 24 restantes"
	if body_font:
		_remaining_deck_label.add_theme_font_override("font", body_font)
	_remaining_deck_label.add_theme_font_size_override("font_size", 11)
	_remaining_deck_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	deck_wrap.add_child(_remaining_deck_label)

	_remaining_deck_root = Control.new()
	_remaining_deck_root.custom_minimum_size = Vector2(154, 102)
	_remaining_deck_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_remaining_deck_root.z_index = 0
	deck_wrap.add_child(_remaining_deck_root)

	var center_gap := Control.new()
	center_gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run_stack_bar.add_child(center_gap)

	var discard_wrap := VBoxContainer.new()
	discard_wrap.custom_minimum_size = Vector2(128, 82)
	discard_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	_run_stack_bar.add_child(discard_wrap)

	_discard_label = Label.new()
	_discard_label.text = "Cimetiere: 0"
	if body_font:
		_discard_label.add_theme_font_override("font", body_font)
	_discard_label.add_theme_font_size_override("font_size", 11)
	_discard_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	_discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	discard_wrap.add_child(_discard_label)

	_discard_root = Control.new()
	_discard_root.custom_minimum_size = Vector2(112, 78)
	_discard_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	discard_wrap.add_child(_discard_root)


func _create_effect_preview_panel() -> void:
	_effect_preview_panel = Panel.new()
	_effect_preview_panel.visible = false
	_effect_preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_effect_preview_panel.z_index = 10
	var style := StyleBoxFlat.new()
	style.bg_color = Color(PALETTE.paper_dark.r, PALETTE.paper_dark.g, PALETTE.paper_dark.b, 0.95)
	style.border_color = PALETTE.accent
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	_effect_preview_panel.add_theme_stylebox_override("panel", style)

	_effect_preview_label = RichTextLabel.new()
	_effect_preview_label.bbcode_enabled = true
	_effect_preview_label.fit_content = true
	_effect_preview_label.scroll_active = false
	_effect_preview_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if body_font:
		_effect_preview_label.add_theme_font_override("normal_font", body_font)
	_effect_preview_label.add_theme_font_size_override("normal_font_size", 12)
	_effect_preview_label.add_theme_color_override("default_color", PALETTE.ink)
	_effect_preview_panel.add_child(_effect_preview_label)

	add_child(_effect_preview_panel)


func _on_option_hover_enter(option_index: int) -> void:
	SFXManager.play("hover")
	_show_effect_preview(option_index)


func _on_option_hover_exit() -> void:
	_hide_effect_preview()


func _show_effect_preview(option_index: int) -> void:
	if current_card.is_empty():
		return
	var options: Array = current_card.get("options", [])
	if option_index >= options.size():
		return

	var option: Dictionary = options[option_index] if options[option_index] is Dictionary else {}
	var effects: Array = option.get("effects", [])

	# Build preview text
	var lines: Array[String] = []

	# DC info
	var dc_values := [6, 10, 14]  # LEFT, CENTER, RIGHT
	var dc: int = dc_values[clampi(option_index, 0, 2)]
	var dc_color: String = "green" if dc <= 6 else ("yellow" if dc <= 10 else "red")
	lines.append("[color=%s]DC %d[/color]" % [dc_color, dc])

	# Aspect effects
	if effects.is_empty():
		lines.append("[color=gray]Pas d'effet direct[/color]")
	else:
		for e in effects:
			if not (e is Dictionary):
				continue
			var etype: String = str(e.get("type", ""))
			if etype == "SHIFT_ASPECT":
				var aspect: String = str(e.get("aspect", ""))
				var dir: String = str(e.get("direction", ""))
				var arrow: String = "\u2191" if dir == "up" else "\u2193"
				var preview_text := _format_aspect_shift_preview(aspect, dir)
				var shift_color: String = _get_shift_color(aspect, dir)
				lines.append("[color=%s]%s %s %s[/color]" % [shift_color, aspect, arrow, preview_text])
			elif etype == "ADD_KARMA":
				lines.append("[color=#c0a030]+%d Karma[/color]" % int(e.get("amount", 0)))
			elif etype == "ADD_SOUFFLE":
				lines.append("[color=#40a060]+%d Souffle[/color]" % int(e.get("amount", 0)))
			elif etype == "PROGRESS_MISSION":
				lines.append("[color=#6080c0]+%d Mission[/color]" % int(e.get("step", 1)))

	# Build BBCode
	_effect_preview_label.text = "\n".join(lines)

	# Position above the hovered button
	_preview_visible_for = option_index
	_effect_preview_panel.visible = true
	_effect_preview_panel.custom_minimum_size = Vector2(180, 0)
	_effect_preview_panel.size = Vector2(180, 0)

	# Wait one frame for the label to compute its size
	await get_tree().process_frame
	_position_preview_above_button(option_index)


func _position_preview_above_button(option_index: int) -> void:
	if option_index >= option_buttons.size():
		return
	if not _effect_preview_panel or not _effect_preview_panel.visible:
		return
	var btn: Button = option_buttons[option_index]
	if not is_instance_valid(btn):
		return

	var btn_global := btn.global_position
	var panel_h: float = maxf(_effect_preview_label.get_content_height() + 16.0, 40.0)
	_effect_preview_panel.size.y = panel_h
	_effect_preview_panel.global_position = Vector2(
		btn_global.x + btn.size.x * 0.5 - 90.0,
		btn_global.y - panel_h - 6.0
	)


func _hide_effect_preview() -> void:
	_preview_visible_for = -1
	if _effect_preview_panel:
		_effect_preview_panel.visible = false


func _format_aspect_shift_preview(aspect: String, direction: String) -> String:
	## Returns "(Robuste → Surmené)" based on current state + shift direction.
	var current_state: int = int(current_aspects.get(aspect, MerlinConstants.AspectState.EQUILIBRE))
	var new_state: int = current_state + (1 if direction == "up" else -1)
	new_state = clampi(new_state, MerlinConstants.AspectState.BAS, MerlinConstants.AspectState.HAUT)
	var info: Dictionary = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect, {})
	var states: Dictionary = info.get("states", {})
	var current_name: String = states.get(current_state, "?")
	var new_name: String = states.get(new_state, "?")
	if current_state == new_state:
		return "(%s, max)" % current_name
	return "(%s \u2192 %s)" % [current_name, new_name]


func _get_shift_color(aspect: String, direction: String) -> String:
	## Returns a color hex for the shift preview. Red if dangerous (toward extreme), green if safe.
	var current_state: int = int(current_aspects.get(aspect, MerlinConstants.AspectState.EQUILIBRE))
	var new_state: int = current_state + (1 if direction == "up" else -1)
	new_state = clampi(new_state, MerlinConstants.AspectState.BAS, MerlinConstants.AspectState.HAUT)
	# BAS or HAUT = dangerous
	if new_state == MerlinConstants.AspectState.BAS or new_state == MerlinConstants.AspectState.HAUT:
		return "#c04040"  # Red — dangerous
	return "#40a060"  # Green — safe (toward equilibre)


func _create_info_bar(parent: Control) -> void:
	info_panel = HBoxContainer.new()
	info_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	info_panel.add_theme_constant_override("separation", 30)

	mission_label = Label.new()
	mission_label.text = "Mission: ???"
	if body_font:
		mission_label.add_theme_font_override("font", body_font)
	mission_label.add_theme_font_size_override("font_size", 13)
	mission_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	info_panel.add_child(mission_label)

	cards_label = Label.new()
	cards_label.text = "Cartes: 0"
	if body_font:
		cards_label.add_theme_font_override("font", body_font)
	cards_label.add_theme_font_size_override("font_size", 13)
	cards_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	info_panel.add_child(cards_label)

	parent.add_child(info_panel)


# ═══════════════════════════════════════════════════════════════════════════════
# THINKING ANIMATION — Shown while LLM generates next card
# ═══════════════════════════════════════════════════════════════════════════════

var _thinking_active := false
var _thinking_dots := 0
var _thinking_timer: Timer = null
var _thinking_spiral: Control = null

func show_thinking() -> void:
	## Show "Merlin is thinking" animation on the card area.
	if _thinking_active:
		return
	_thinking_active = true

	# Dim options
	if options_container and is_instance_valid(options_container):
		var tw := create_tween()
		tw.tween_property(options_container, "modulate:a", 0.3, 0.2)

	# Update card text with animated dots
	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = "Merlin"
		card_speaker.visible = true

	# Show Celtic spiral animation (reuse if already created)
	if card_panel and is_instance_valid(card_panel):
		if _thinking_spiral != null and is_instance_valid(_thinking_spiral):
			_thinking_spiral.visible = true
		else:
			_thinking_spiral = Control.new()
			_thinking_spiral.name = "ThinkingSpiral"
			_thinking_spiral.custom_minimum_size = Vector2(60, 60)
			_thinking_spiral.set_anchors_preset(Control.PRESET_CENTER)
			var panel_size: Vector2 = card_panel.size if card_panel.size.length() > 0 else Vector2(460, 360)
			_thinking_spiral.position = panel_size * 0.5 - Vector2(30, 50)
			_thinking_spiral.draw.connect(_draw_thinking_spiral.bind(_thinking_spiral))
			card_panel.add_child(_thinking_spiral)

	# Start dot animation timer
	_thinking_dots = 0
	if _thinking_timer == null:
		_thinking_timer = Timer.new()
		_thinking_timer.wait_time = 0.4
		_thinking_timer.timeout.connect(_on_thinking_tick)
		add_child(_thinking_timer)
	_thinking_timer.start()
	_on_thinking_tick()  # First tick immediately


func hide_thinking() -> void:
	## Hide thinking animation and restore UI.
	if not _thinking_active:
		return
	_thinking_active = false

	# Stop timer
	if _thinking_timer:
		_thinking_timer.stop()

	# Hide spiral (keep for reuse — avoids node leak)
	if _thinking_spiral and is_instance_valid(_thinking_spiral):
		_thinking_spiral.visible = false

	# Restore options opacity
	if options_container:
		var tw := create_tween()
		tw.tween_property(options_container, "modulate:a", 1.0, 0.2)


func _on_thinking_tick() -> void:
	## Animate thinking dots on the card text.
	_thinking_dots = (_thinking_dots + 1) % 4
	var dots := ".".repeat(_thinking_dots)
	if card_text:
		card_text.text = "Merlin reflechit" + dots

	# Rotate spiral
	if _thinking_spiral and is_instance_valid(_thinking_spiral):
		var tw := create_tween()
		tw.tween_property(_thinking_spiral, "rotation", _thinking_spiral.rotation + PI * 0.5, 0.35)
		_thinking_spiral.queue_redraw()


func _draw_thinking_spiral(ctrl: Control) -> void:
	## Draw an animated Celtic triple spiral (triskelion).
	var cx := ctrl.size.x * 0.5
	var cy := ctrl.size.y * 0.5
	var r := mini(int(ctrl.size.x), int(ctrl.size.y)) * 0.35

	# Draw 3 spiraling arms (triskelion)
	for arm in range(3):
		var angle_offset := TAU * arm / 3.0
		var points := PackedVector2Array()
		for i in range(20):
			var t := float(i) / 19.0
			var spiral_r := r * t
			var angle := angle_offset + t * TAU * 0.75
			points.append(Vector2(
				cx + cos(angle) * spiral_r,
				cy + sin(angle) * spiral_r
			))
		if points.size() >= 2:
			ctrl.draw_polyline(points, PALETTE.accent, 2.0, true)

	# Center dot
	ctrl.draw_circle(Vector2(cx, cy), 3.0, PALETTE.accent)


# ═══════════════════════════════════════════════════════════════════════════════
# UPDATE METHODS
# ═══════════════════════════════════════════════════════════════════════════════

func update_biome_indicator(biome_name: String, biome_color: Color) -> void:
	if biome_indicator:
		biome_indicator.text = "\u25C6 %s \u25C6" % biome_name
		biome_indicator.add_theme_color_override("font_color", Color(biome_color.r, biome_color.g, biome_color.b, 0.7))


func update_aspects(aspects: Dictionary) -> void:
	_update_aspects(aspects)


func _update_aspects(aspects: Dictionary) -> void:
	# Play SFX based on aspect changes (skip on first call when _previous_aspects is empty)
	if not _previous_aspects.is_empty():
		for aspect_name in MerlinConstants.TRIADE_ASPECTS:
			var old_state: int = int(_previous_aspects.get(aspect_name, MerlinConstants.AspectState.EQUILIBRE))
			var new_state: int = int(aspects.get(aspect_name, MerlinConstants.AspectState.EQUILIBRE))
			if new_state != old_state:
				if new_state > old_state:
					SFXManager.play("aspect_up")
				else:
					SFXManager.play("aspect_down")

	_previous_aspects = aspects.duplicate()
	current_aspects = aspects

	for aspect in MerlinConstants.TRIADE_ASPECTS:
		var display = aspect_displays.get(aspect, {})
		if display.is_empty():
			continue

		var aspect_state: int = int(aspects.get(aspect, MerlinConstants.AspectState.EQUILIBRE))

		# Update state indicator circles
		var state_container: HBoxContainer = display.get("state_container")
		if state_container:
			for i in range(3):
				var circle: Label = state_container.get_child(i) as Label
				if circle:
					var target_state: int = i - 1  # -1, 0, 1
					if target_state == aspect_state:
						circle.text = "●"
						circle.add_theme_color_override("font_color", ASPECT_COLORS.get(aspect, Color.WHITE))
					else:
						circle.text = "○"
						circle.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))

		# Update state name
		var state_name: Label = display.get("state_name")
		if state_name:
			var info = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect, {})
			var states = info.get("states", {})
			state_name.text = str(states.get(aspect_state, "???"))

			# Color based on extreme state
			if aspect_state == MerlinConstants.AspectState.EQUILIBRE:
				state_name.add_theme_color_override("font_color", PALETTE.ink_soft)
			else:
				state_name.add_theme_color_override("font_color", Color(0.78, 0.25, 0.22))

		# Shift arrow (shows last change direction)
		var shift_arrow: Label = display.get("shift_arrow")
		if shift_arrow and not _previous_aspects.is_empty():
			var old_st: int = int(_previous_aspects.get(aspect, MerlinConstants.AspectState.EQUILIBRE))
			if aspect_state > old_st:
				shift_arrow.text = "\u2191"
				shift_arrow.add_theme_color_override("font_color", Color(0.78, 0.25, 0.22))
			elif aspect_state < old_st:
				shift_arrow.text = "\u2193"
				shift_arrow.add_theme_color_override("font_color", Color(0.25, 0.45, 0.72))
			else:
				shift_arrow.text = ""

		# Animate icon if extreme (now a Control, not Label)
		var icon: Control = display.get("icon")
		if icon:
			if aspect_state != MerlinConstants.AspectState.EQUILIBRE:
				var tween := create_tween()
				tween.set_loops(2)
				tween.tween_property(icon, "modulate:a", 0.5, 0.3)
				tween.tween_property(icon, "modulate:a", 1.0, 0.3)


func update_souffle(souffle: int) -> void:
	_update_souffle(souffle)


func _update_souffle(souffle: int) -> void:
	var old_souffle := _previous_souffle
	_previous_souffle = souffle
	current_souffle = souffle

	# Update numeric counter
	if _souffle_counter and is_instance_valid(_souffle_counter):
		_souffle_counter.text = "%d/%d" % [souffle, MerlinConstants.SOUFFLE_MAX]
		if souffle == 0:
			_souffle_counter.add_theme_color_override("font_color", Color(0.78, 0.25, 0.22))
		elif souffle <= 2:
			_souffle_counter.add_theme_color_override("font_color", Color(0.72, 0.50, 0.10))
		else:
			_souffle_counter.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))

	if not souffle_display:
		return

	for i in range(MerlinConstants.SOUFFLE_MAX):
		var icon: Label = souffle_display.get_child(i) as Label
		if icon:
			if i < souffle:
				icon.text = SOUFFLE_ICON
				icon.add_theme_color_override("font_color", Color(0.3, 0.7, 0.9))
			else:
				icon.text = SOUFFLE_EMPTY
				icon.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))

	# VFX: Regen animation (gained souffle)
	if old_souffle >= 0 and souffle > old_souffle:
		for i in range(old_souffle, mini(souffle, MerlinConstants.SOUFFLE_MAX)):
			var icon: Label = souffle_display.get_child(i) as Label
			if icon:
				icon.scale = Vector2(0.3, 0.3)
				icon.pivot_offset = icon.size * 0.5
				var tw := create_tween()
				tw.tween_property(icon, "scale", Vector2(1.2, 1.2), 0.25) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.1 * (i - old_souffle))
				tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.15)
		SFXManager.play("souffle_regen")

	# VFX: Consumption animation (lost souffle)
	if old_souffle >= 0 and souffle < old_souffle:
		for i in range(souffle, mini(old_souffle, MerlinConstants.SOUFFLE_MAX)):
			var icon: Label = souffle_display.get_child(i) as Label
			if icon:
				var tw := create_tween()
				tw.tween_property(icon, "scale", Vector2(0.5, 0.5), 0.2) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				tw.tween_property(icon, "scale", Vector2(1.0, 1.0), 0.1)

	# VFX: Full souffle glow (7/7)
	if souffle >= MerlinConstants.SOUFFLE_MAX:
		for i in range(MerlinConstants.SOUFFLE_MAX):
			var icon: Label = souffle_display.get_child(i) as Label
			if icon:
				icon.add_theme_color_override("font_color", Color(0.85, 0.75, 0.3))
		if old_souffle >= 0 and old_souffle < MerlinConstants.SOUFFLE_MAX:
			SFXManager.play("souffle_full")

	# VFX: Empty souffle blink (0/7)
	if souffle <= 0:
		for i in range(MerlinConstants.SOUFFLE_MAX):
			var icon: Label = souffle_display.get_child(i) as Label
			if icon:
				var tw := create_tween()
				tw.set_loops(3)
				tw.tween_property(icon, "modulate:a", 0.3, 0.4)
				tw.tween_property(icon, "modulate:a", 1.0, 0.4)

	# Center is now free (Phase 43) — no risk indicator needed


func update_life_essence(life: int) -> void:
	## Update the life essence display (Phase 43).
	if _life_counter and is_instance_valid(_life_counter):
		_life_counter.text = "%d/%d" % [life, MerlinConstants.LIFE_ESSENCE_MAX]
		if life <= 0:
			_life_counter.add_theme_color_override("font_color", Color(0.90, 0.12, 0.12))
		elif life <= MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD:
			_life_counter.add_theme_color_override("font_color", Color(0.86, 0.38, 0.10))
		else:
			_life_counter.add_theme_color_override("font_color", Color(0.82, 0.24, 0.22))
	if _life_bar and is_instance_valid(_life_bar):
		_life_bar.value = life
		if life <= MerlinConstants.LIFE_ESSENCE_LOW_THRESHOLD:
			var tw := create_tween()
			tw.set_loops(2)
			tw.tween_property(_life_bar, "modulate:a", 0.5, 0.3)
			tw.tween_property(_life_bar, "modulate:a", 1.0, 0.3)


func update_essences_collected(value: int) -> void:
	if _essence_counter and is_instance_valid(_essence_counter):
		_essence_counter.text = str(maxi(value, 0))


func update_resource_bar(tool_id: String, day: int, mission_current: int, mission_total: int, essences_collected: int = 0) -> void:
	if _tool_label:
		if tool_id != "" and MerlinConstants.EXPEDITION_TOOLS.has(tool_id):
			var tool_info: Dictionary = MerlinConstants.EXPEDITION_TOOLS[tool_id]
			_tool_label.text = "%s %s" % [str(tool_info.get("icon", "")), str(tool_info.get("name", tool_id))]
		else:
			_tool_label.text = ""
	if _day_label:
		_day_label.text = "Jour %d" % day
	if _mission_progress_label:
		if mission_total > 0:
			_mission_progress_label.text = "Mission %d/%d" % [mission_current, mission_total]
		else:
			_mission_progress_label.text = ""
	update_essences_collected(essences_collected)


func display_card(card: Dictionary) -> void:
	if card.is_empty():
		push_warning("[TriadeUI] display_card called with empty card")
		return
	current_card = card

	_layout_card_stage()
	_push_card_shadow()
	_animate_remaining_deck_draw()

	SFXManager.play("card_draw")

	# Resolve speaker and pixel portrait
	var speaker: String = str(card.get("speaker", ""))
	var speaker_key := PixelCharacterPortrait.resolve_character_key(speaker) if speaker != "" else ""
	var is_new_speaker := speaker_key != "" and speaker_key != _current_speaker_key

	# Update speaker label
	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = PixelCharacterPortrait.get_character_name(speaker_key) if speaker_key != "" else ""
		card_speaker.visible = not speaker.is_empty()

	# Pixel portrait: assemble new character if speaker changed
	if is_new_speaker and _pixel_portrait and is_instance_valid(_pixel_portrait):
		_current_speaker_key = speaker_key
		_pixel_portrait.setup(speaker_key, 5.8)
		_pixel_portrait.assemble(false)  # Animated assembly

	# Animate card entrance — flip + scale + fade
	if card_panel and is_instance_valid(card_panel):
		if _card_float_tween:
			_card_float_tween.kill()
		if _card_entry_tween:
			_card_entry_tween.kill()
		var draw_origin := _get_deck_draw_origin()
		card_panel.position = draw_origin
		card_panel.modulate.a = 0.0
		card_panel.scale = Vector2(0.12, 0.12)
		card_panel.rotation_degrees = randf_range(-10.0, 10.0)
		_card_entry_tween = create_tween()
		_card_entry_tween.set_parallel(true)
		_card_entry_tween.tween_property(card_panel, "modulate:a", 1.0, 0.10)
		_card_entry_tween.tween_property(card_panel, "position", _card_base_pos, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_card_entry_tween.tween_property(card_panel, "rotation_degrees", 0.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_card_entry_tween.tween_property(card_panel, "scale", Vector2(1.06, 1.06), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_card_entry_tween.set_parallel(false)
		_card_entry_tween.tween_property(card_panel, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_card_entry_tween.finished.connect(_start_card_float_motion, CONNECT_ONE_SHOT)

	# Update text with typewriter
	if card_text and is_instance_valid(card_text):
		_typewriter_card_text(card.get("text", "..."))

	# Update source badge (dev indicator)
	if _card_source_badge and is_instance_valid(_card_source_badge):
		var card_source := _detect_card_source(card)
		LLMSourceBadge.update_badge(_card_source_badge, card_source)
		_card_source_badge.visible = true

	# Update encounter tile (pixel art per card type)
	if _encounter_tile and is_instance_valid(_encounter_tile):
		var enc_type := PixelEncounterTile.detect_type(card)
		_encounter_tile.setup(enc_type, 7.2)
		_encounter_tile.assemble(true)

	# Update options — always show all 3 buttons in action-verb style.
	var options: Array = card.get("options", [])
	for i in range(3):
		var has_option: bool = i < options.size() and options[i] is Dictionary
		var option: Dictionary = options[i] if has_option else {}
		var action_label := _actionize_option_label(str(option.get("label", "")), i)
		if i < option_labels.size() and is_instance_valid(option_labels[i]):
			option_labels[i].text = action_label if has_option else "..."
			option_labels[i].modulate.a = 1.0 if has_option else 0.4
		if i < option_buttons.size() and is_instance_valid(option_buttons[i]):
			var key: String = OPTION_KEYS.get(i, "?")
			option_buttons[i].text = "[%s] %s" % [key, action_label] if has_option else "[%s] —" % key
			option_buttons[i].disabled = not has_option
			option_buttons[i].modulate.a = 1.0 if has_option else 0.35


func _actionize_option_label(raw_label: String, option_index: int) -> String:
	var clean := raw_label.strip_edges()
	if clean == "":
		return ACTION_VERB_FALLBACK[clampi(option_index, 0, ACTION_VERB_FALLBACK.size() - 1)]
	var words: PackedStringArray = clean.replace(":", " ").replace(",", " ").replace(".", " ").split(" ", false)
	if words.is_empty():
		return ACTION_VERB_FALLBACK[clampi(option_index, 0, ACTION_VERB_FALLBACK.size() - 1)]
	var verb := words[0].capitalize()
	var detail := ""
	if words.size() > 1:
		var max_words := mini(words.size(), 4)
		for i in range(1, max_words):
			detail += (" " if i > 1 else "") + words[i]
	return "%s %s" % [verb, detail] if detail != "" else verb


func _detect_card_source(card: Dictionary) -> String:
	## Detect whether a card was generated by LLM, fallback pool, or static.
	var tags: Array = card.get("tags", [])
	if "llm_generated" in tags:
		return "llm"
	if "emergency_fallback" in tags:
		return "fallback"
	var gen_by: String = str(card.get("_generated_by", ""))
	if gen_by.contains("llm"):
		return "llm"
	if gen_by != "":
		return "llm"  # Any _generated_by means LLM pipeline
	# Check if card has omniscient pipeline marker
	if card.has("_omniscient"):
		return "llm"
	return "fallback"


# ═══════════════════════════════════════════════════════════════════════════════
# CARD STACKING — Shadow cards pile up behind the active card
# ═══════════════════════════════════════════════════════════════════════════════

func _push_card_shadow() -> void:
	if not card_panel or not is_instance_valid(card_panel) or not card_container:
		return
	# Remove oldest shadow if at max
	if _card_shadows.size() >= MAX_CARD_SHADOWS:
		var oldest: Panel = _card_shadows.pop_front()
		if is_instance_valid(oldest):
			var fade_tw := create_tween()
			fade_tw.tween_property(oldest, "modulate:a", 0.0, 0.2)
			fade_tw.tween_callback(oldest.queue_free)

	# Create shadow from current card position
	var shadow := Panel.new()
	shadow.custom_minimum_size = card_panel.custom_minimum_size
	shadow.size = card_panel.size
	shadow.position = card_panel.position + Vector2(2, 2) * float(_card_shadows.size() + 1)
	shadow.modulate.a = maxf(0.06, 0.18 - 0.04 * float(_card_shadows.size()))
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base_style = card_panel.get_theme_stylebox("panel")
	if base_style:
		var style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
		if style:
			style.bg_color = style.bg_color.darkened(0.15)
			shadow.add_theme_stylebox_override("panel", style)

	card_container.add_child(shadow)
	card_container.move_child(shadow, 0)  # Behind main card
	_card_shadows.append(shadow)


# ═══════════════════════════════════════════════════════════════════════════════
# PROGRESSIVE INDICATORS — Reveal aspects and souffle one by one
# ═══════════════════════════════════════════════════════════════════════════════

func show_progressive_indicators() -> void:
	## Animate only the top HUD metrics (health, souffle, essences).
	var essence_panel: Control = _essence_counter.get_parent() if _essence_counter and is_instance_valid(_essence_counter) else null
	if _top_status_bar and is_instance_valid(_top_status_bar):
		_top_status_bar.modulate.a = 1.0
	if life_panel and is_instance_valid(life_panel):
		life_panel.modulate.a = 0.0
	if souffle_panel and is_instance_valid(souffle_panel):
		souffle_panel.modulate.a = 0.0
	if essence_panel and is_instance_valid(essence_panel):
		essence_panel.modulate.a = 0.0

	await get_tree().create_timer(0.15).timeout
	if not is_inside_tree():
		return

	if life_panel and is_instance_valid(life_panel):
		var life_tw := create_tween()
		life_tw.tween_property(life_panel, "modulate:a", 1.0, 0.26).set_trans(Tween.TRANS_SINE)
		await life_tw.finished

	if souffle_panel and is_instance_valid(souffle_panel):
		SFXManager.play("ogham_chime")
		var tw := create_tween()
		tw.tween_property(souffle_panel, "modulate:a", 1.0, 0.32).set_trans(Tween.TRANS_SINE)
		await tw.finished

	if essence_panel and is_instance_valid(essence_panel):
		var essence_tw := create_tween()
		essence_tw.tween_property(essence_panel, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE)
		await essence_tw.finished


# ═══════════════════════════════════════════════════════════════════════════════
# AMBIENT VFX — Biome-themed simple particles behind the card
# ═══════════════════════════════════════════════════════════════════════════════

func start_ambient_vfx(biome_key: String) -> void:
	## Start subtle ambient particle effects based on biome.
	_ambient_biome_key = biome_key
	if _ambient_timer:
		_ambient_timer.queue_free()
	_ambient_timer = Timer.new()
	_ambient_timer.wait_time = 1.2
	_ambient_timer.autostart = true
	_ambient_timer.timeout.connect(_spawn_ambient_particle)
	add_child(_ambient_timer)


func _spawn_ambient_particle() -> void:
	if _ambient_particles.size() >= MAX_AMBIENT_PARTICLES or not is_inside_tree():
		return
	var vp: Vector2 = get_viewport_rect().size
	var px := ColorRect.new()
	px.size = Vector2(randf_range(3.0, 5.0), randf_range(3.0, 5.0))
	px.mouse_filter = Control.MOUSE_FILTER_IGNORE
	px.z_index = -1
	px.modulate.a = randf_range(0.15, 0.35)

	var start_pos := Vector2.ZERO
	var end_pos := Vector2.ZERO
	var duration: float = randf_range(4.0, 7.0)

	var key: String = _ambient_biome_key.replace("foret_", "").replace("landes_", "") \
		.replace("cotes_", "").replace("villages_", "").replace("cercles_", "") \
		.replace("marais_", "").replace("collines_", "")

	match key:
		"broceliande":
			# Falling leaves (green/brown)
			px.color = [Color(0.35, 0.55, 0.28), Color(0.55, 0.40, 0.25)][randi() % 2]
			start_pos = Vector2(randf_range(0, vp.x), -10)
			end_pos = start_pos + Vector2(randf_range(-60, 60), vp.y + 20)
		"bruyere":
			# Wind dust (horizontal)
			px.color = Color(0.55, 0.40, 0.55, 0.5)
			start_pos = Vector2(-10, randf_range(vp.y * 0.3, vp.y * 0.8))
			end_pos = Vector2(vp.x + 10, start_pos.y + randf_range(-30, 30))
			duration = randf_range(3.0, 5.0)
		"sauvages":
			# Rising mist (blue)
			px.color = Color(0.38, 0.58, 0.75, 0.4)
			start_pos = Vector2(randf_range(0, vp.x), vp.y + 10)
			end_pos = start_pos + Vector2(randf_range(-20, 20), -vp.y * 0.4)
		"celtes":
			# Rising smoke (gray)
			px.color = Color(0.5, 0.48, 0.45, 0.3)
			start_pos = Vector2(randf_range(vp.x * 0.3, vp.x * 0.7), vp.y + 10)
			end_pos = start_pos + Vector2(randf_range(-15, 15), -vp.y * 0.5)
		"pierres":
			# Fireflies (warm yellow glow)
			px.color = Color(0.85, 0.75, 0.30, 0.6)
			px.size = Vector2(3, 3)
			start_pos = Vector2(randf_range(vp.x * 0.1, vp.x * 0.9), randf_range(vp.y * 0.2, vp.y * 0.8))
			end_pos = start_pos + Vector2(randf_range(-40, 40), randf_range(-40, 40))
			duration = randf_range(2.0, 4.0)
		"korrigans":
			# Phosphorescence (dark green)
			px.color = Color(0.20, 0.45, 0.25, 0.4)
			start_pos = Vector2(randf_range(0, vp.x), vp.y * randf_range(0.6, 0.95))
			end_pos = start_pos + Vector2(randf_range(-25, 25), randf_range(-20, -50))
			duration = randf_range(3.0, 5.0)
		"dolmens":
			# Grass swaying (green tufts)
			px.color = Color(0.40, 0.60, 0.30, 0.3)
			start_pos = Vector2(randf_range(0, vp.x), vp.y * randf_range(0.7, 0.95))
			end_pos = start_pos + Vector2(randf_range(-20, 20), randf_range(-10, 10))
			duration = randf_range(2.0, 4.0)
		_:
			# Default: gentle floating motes
			px.color = Color(0.6, 0.55, 0.45, 0.2)
			start_pos = Vector2(randf_range(0, vp.x), randf_range(0, vp.y))
			end_pos = start_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))

	px.position = start_pos
	add_child(px)
	_ambient_particles.append(px)

	var tw := create_tween()
	tw.tween_property(px, "position", end_pos, duration).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(px, "modulate:a", 0.0, duration * 0.8).set_delay(duration * 0.2)
	tw.tween_callback(func():
		_ambient_particles.erase(px)
		if is_instance_valid(px):
			px.queue_free()
	)


func show_opening_sequence(biome_key: String, season_hint: String = "", hour_hint: int = -1) -> void:
	if _opening_sequence_done:
		return
	_opening_sequence_done = true
	_layout_run_zones()
	_layout_card_stage()
	_set_intro_hidden_state()
	await get_tree().process_frame

	var key := _normalize_biome_key(biome_key)
	var season := _normalize_season(season_hint, key)
	var hour := hour_hint
	if hour < 0 or hour > 23:
		var now: Dictionary = Time.get_datetime_dict_from_system()
		hour = int(now.get("hour", 12))

	_configure_low_poly_background(key, season, hour)
	await _animate_low_poly_background_reveal()
	await _animate_deck_assembly(key)
	_set_empty_center_card_state()
	await _reveal_empty_center_card()
	await _reveal_intro_blocks()


func _set_intro_hidden_state() -> void:
	var essence_panel: Control = _essence_counter.get_parent() if _essence_counter and is_instance_valid(_essence_counter) else null
	var hide_targets: Array = [
		_top_status_bar,
		life_panel,
		souffle_panel,
		essence_panel,
		card_container,
		_bottom_zone,
		_run_stack_bar,
		options_container,
		info_panel,
	]
	for node in hide_targets:
		var target: Control = node as Control
		if target and is_instance_valid(target):
			target.modulate.a = 0.0


func _set_empty_center_card_state() -> void:
	current_card = {
		"id": "intro_placeholder",
		"_placeholder": true,
	}
	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = ""
		card_speaker.visible = false
	if card_text and is_instance_valid(card_text):
		card_text.text = " "
	if _card_source_badge and is_instance_valid(_card_source_badge):
		_card_source_badge.visible = false
	if card_panel and is_instance_valid(card_panel):
		card_panel.modulate.a = 1.0
		card_panel.scale = Vector2.ONE
		card_panel.rotation_degrees = 0.0
		card_panel.position = _card_base_pos


func _reveal_empty_center_card() -> void:
	if not card_container or not is_instance_valid(card_container):
		return
	var tw := create_tween()
	tw.tween_property(card_container, "modulate:a", 1.0, 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw.finished


func _reveal_intro_blocks() -> void:
	var reveal_targets: Array = [_top_status_bar, _bottom_zone, _run_stack_bar]
	for i in range(reveal_targets.size()):
		var target: Control = reveal_targets[i] as Control
		if not target or not is_instance_valid(target):
			continue
		var tw := create_tween()
		tw.tween_property(target, "modulate:a", 1.0, 0.22).set_trans(Tween.TRANS_SINE).set_delay(0.05 * float(i))
	await get_tree().create_timer(0.45).timeout


func _normalize_biome_key(biome_key: String) -> String:
	var key := str(biome_key).strip_edges().to_lower()
	if BIOME_ART_PROFILES.has(key):
		return key
	if BIOME_SHORT_NAMES.has(key):
		return str(BIOME_SHORT_NAMES[key])
	return "broceliande"


func _normalize_season(season_hint: String, biome_key: String) -> String:
	var season := str(season_hint).strip_edges().to_lower()
	if season == "automn":
		season = "automne"
	if SEASON_TINTS.has(season):
		return season
	return str(BIOME_DEFAULT_SEASON.get(biome_key, "automne"))


func _tone_color(base: Color, hour_light: Color, season_tint: Color) -> Color:
	return Color(
		clampf(base.r * hour_light.r * season_tint.r, 0.0, 1.0),
		clampf(base.g * hour_light.g * season_tint.g, 0.0, 1.0),
		clampf(base.b * hour_light.b * season_tint.b, 0.0, 1.0),
		1.0
	)


func _hour_light_color(hour: int) -> Color:
	var h := clampi(hour, 0, 23)
	var daylight := (cos((float(h) - 12.0) * PI / 12.0) + 1.0) * 0.5
	var base := lerpf(0.38, 1.0, daylight)
	var blue_boost := lerpf(1.09, 0.96, daylight)
	return Color(base, base * 0.98, base * blue_boost, 1.0)


func _build_biome_artwork(biome_key: String, season_key: String, hour: int) -> void:
	if not biome_art_layer or not is_instance_valid(biome_art_layer):
		return
	for child in biome_art_layer.get_children():
		child.queue_free()
	_biome_art_pixels.clear()

	var profile: Dictionary = BIOME_ART_PROFILES.get(biome_key, BIOME_ART_PROFILES.broceliande)
	var season_tint: Color = SEASON_TINTS.get(season_key, Color.WHITE)
	var hour_light: Color = _hour_light_color(hour)
	var sky_color := _tone_color(profile.sky, hour_light, season_tint)
	var mist_color := _tone_color(profile.mist, hour_light, season_tint)
	var mid_color := _tone_color(profile.mid, hour_light, season_tint)
	var accent_color := _tone_color(profile.accent, hour_light, season_tint)
	var foreground_color := _tone_color(profile.foreground, hour_light, season_tint)

	var vp := get_viewport_rect().size
	var pixel_size: float = floor(minf(vp.x / float(INTRO_PIXEL_COLS), vp.y / float(INTRO_PIXEL_ROWS)))
	pixel_size = clampf(pixel_size, 6.0, 20.0)
	var total_w: float = float(INTRO_PIXEL_COLS) * pixel_size
	var total_h: float = float(INTRO_PIXEL_ROWS) * pixel_size
	var origin: Vector2 = Vector2((vp.x - total_w) * 0.5, (vp.y - total_h) * 0.46)

	_add_biome_block(0, 0, INTRO_PIXEL_COLS, 18, sky_color, origin, pixel_size)
	_add_biome_block(0, 18, INTRO_PIXEL_COLS, 10, mist_color, origin, pixel_size)
	_add_biome_block(0, 28, INTRO_PIXEL_COLS, INTRO_PIXEL_ROWS - 28, mid_color.darkened(0.10), origin, pixel_size)

	for x in range(INTRO_PIXEL_COLS):
		var wave := sin(float(x) * 0.21) * 2.6 + cos(float(x) * 0.09) * 1.7
		var ridge_h := 5 + int(abs(wave))
		_add_biome_block(x, 30 - ridge_h, 1, ridge_h + 1, mid_color, origin, pixel_size)

	for x in range(INTRO_PIXEL_COLS):
		var ground_h := 6 + int(abs(sin(float(x) * 0.19)) * 2.0)
		_add_biome_block(x, INTRO_PIXEL_ROWS - ground_h, 1, ground_h, foreground_color, origin, pixel_size)

	_add_biome_feature_blocks(biome_key, origin, pixel_size, accent_color, foreground_color)
	biome_art_layer.modulate = Color.WHITE


func _add_biome_feature_blocks(
	biome_key: String,
	origin: Vector2,
	pixel_size: float,
	accent_color: Color,
	foreground_color: Color
) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash("%s_%d" % [biome_key, int(Time.get_unix_time_from_system() / 1800)]))
	var trunk_color := foreground_color.lightened(0.08)
	var detail_color := accent_color.darkened(0.12)

	match biome_key:
		"broceliande":
			for i in range(28):
				var col := rng.randi_range(2, INTRO_PIXEL_COLS - 3)
				var trunk_h := rng.randi_range(5, 10)
				var canopy_w := rng.randi_range(3, 5)
				_add_biome_block(col, INTRO_PIXEL_ROWS - 6 - trunk_h, 1, trunk_h, trunk_color, origin, pixel_size)
				_add_biome_block(col - int(canopy_w / 2), INTRO_PIXEL_ROWS - 8 - trunk_h, canopy_w, 2, detail_color, origin, pixel_size)
		"landes":
			for i in range(40):
				var col := rng.randi_range(1, INTRO_PIXEL_COLS - 2)
				var h := rng.randi_range(1, 3)
				_add_biome_block(col, INTRO_PIXEL_ROWS - 7 - h, 1, h, detail_color, origin, pixel_size)
		"cotes":
			_add_biome_block(0, INTRO_PIXEL_ROWS - 7, INTRO_PIXEL_COLS, 2, accent_color.lightened(0.08), origin, pixel_size)
			for i in range(20):
				var col := rng.randi_range(4, INTRO_PIXEL_COLS - 6)
				var cliff_h := rng.randi_range(4, 9)
				_add_biome_block(col, INTRO_PIXEL_ROWS - 9 - cliff_h, 1, cliff_h, trunk_color, origin, pixel_size)
		"villages":
			for i in range(8):
				var col := 4 + i * 9
				_add_biome_block(col, INTRO_PIXEL_ROWS - 12, 5, 4, trunk_color, origin, pixel_size)
				_add_biome_block(col + 1, INTRO_PIXEL_ROWS - 14, 3, 2, detail_color, origin, pixel_size)
		"cercles":
			for i in range(12):
				var angle := TAU * float(i) / 12.0
				var col := int(INTRO_PIXEL_COLS * 0.5 + cos(angle) * 14.0)
				var row := int(INTRO_PIXEL_ROWS * 0.68 + sin(angle) * 4.0)
				_add_biome_block(col, row, 1, 4, trunk_color.lightened(0.12), origin, pixel_size)
		"marais":
			for i in range(10):
				var col := rng.randi_range(2, INTRO_PIXEL_COLS - 8)
				var row := rng.randi_range(INTRO_PIXEL_ROWS - 9, INTRO_PIXEL_ROWS - 5)
				_add_biome_block(col, row, rng.randi_range(4, 8), 1, accent_color.lightened(0.12), origin, pixel_size)
		"collines":
			for i in range(3):
				var base_col := 8 + i * 22
				_add_biome_block(base_col, INTRO_PIXEL_ROWS - 12, 8, 4, trunk_color, origin, pixel_size)
				_add_biome_block(base_col + 2, INTRO_PIXEL_ROWS - 14, 4, 2, detail_color, origin, pixel_size)
		_:
			for i in range(24):
				_add_biome_block(rng.randi_range(1, INTRO_PIXEL_COLS - 2), INTRO_PIXEL_ROWS - rng.randi_range(5, 12), 1, rng.randi_range(2, 5), detail_color, origin, pixel_size)


func _add_biome_block(col: int, row: int, width: int, height: int, color: Color, origin: Vector2, pixel_size: float) -> void:
	var c := maxi(col, 0)
	var r := maxi(row, 0)
	var w := mini(width, INTRO_PIXEL_COLS - c)
	var h := mini(height, INTRO_PIXEL_ROWS - r)
	if w <= 0 or h <= 0:
		return
	var block := ColorRect.new()
	block.size = Vector2(float(w) * pixel_size, float(h) * pixel_size)
	block.position = origin + Vector2(float(c) * pixel_size, float(r) * pixel_size)
	block.color = color
	block.modulate.a = 0.0
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	biome_art_layer.add_child(block)
	_biome_art_pixels.append(block)


func _animate_biome_artwork_stack() -> void:
	if _biome_art_pixels.is_empty():
		return
	var ordered: Array = _biome_art_pixels.duplicate()
	ordered.sort_custom(func(a: ColorRect, b: ColorRect) -> bool:
		return a.position.y > b.position.y
	)

	for i in range(ordered.size()):
		var px: ColorRect = ordered[i]
		if not is_instance_valid(px):
			continue
		var target := px.position
		px.position = target + Vector2(randf_range(-3.0, 3.0), randf_range(10.0, 24.0))
		px.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(px, "modulate:a", 1.0, 0.16)
		tw.parallel().tween_property(px, "position", target, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if i % INTRO_STACK_BATCH == INTRO_STACK_BATCH - 1:
			await get_tree().create_timer(INTRO_STACK_STEP).timeout

	var pulse := create_tween()
	pulse.tween_property(biome_art_layer, "modulate", Color(1.06, 1.06, 1.06), 0.14)
	pulse.tween_property(biome_art_layer, "modulate", Color.WHITE, 0.14)
	await pulse.finished


func _animate_deck_assembly(biome_key: String) -> void:
	if not _deck_fx_layer or not is_instance_valid(_deck_fx_layer):
		return
	for child in _deck_fx_layer.get_children():
		child.queue_free()
	_deck_fx_layer.visible = true

	var profile: Dictionary = BIOME_ART_PROFILES.get(biome_key, BIOME_ART_PROFILES.broceliande)
	var edge_color: Color = Color(profile.accent)
	var vp := get_viewport_rect().size
	var center := Vector2(vp.x * 0.5, vp.y * 0.60)
	var reveal_center := center
	if card_panel and is_instance_valid(card_panel):
		var rect := card_panel.get_global_rect()
		reveal_center = rect.position + rect.size * 0.5
	var cards: Array[Panel] = []

	for i in range(INTRO_DECK_COUNT):
		var card := Panel.new()
		card.size = Vector2(92, 128)
		card.position = Vector2(center.x + randf_range(-240.0, 240.0), vp.y + 70.0 + randf_range(0.0, 120.0))
		card.rotation_degrees = randf_range(-36.0, 36.0)
		card.modulate.a = 0.0
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(PALETTE.paper_dark.r, PALETTE.paper_dark.g, PALETTE.paper_dark.b, 0.96)
		style.border_color = edge_color
		style.set_border_width_all(2)
		style.set_corner_radius_all(5)
		style.shadow_color = Color(0, 0, 0, 0.22)
		style.shadow_size = 5
		style.shadow_offset = Vector2(0, 2)
		card.add_theme_stylebox_override("panel", style)
		_deck_fx_layer.add_child(card)
		cards.append(card)

	# Phase 1: Cards crash into a central stack.
	for i in range(cards.size()):
		var card: Panel = cards[i]
		var stack_pos := Vector2(center.x - 46.0 + randf_range(-7.0, 7.0), center.y - 70.0 - float(i) * 1.4)
		var tw := create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.09).set_delay(0.015 * float(i))
		tw.parallel().tween_property(card, "position", stack_pos, 0.27 + 0.01 * float(i)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(card, "rotation_degrees", randf_range(-4.0, 4.0), 0.27).set_delay(0.02 * float(i))
	await get_tree().create_timer(0.46).timeout

	# Phase 2: Riffle split and interleave.
	var left_stack: Array[Panel] = []
	var right_stack: Array[Panel] = []
	for i in range(cards.size()):
		if i % 2 == 0:
			left_stack.append(cards[i])
		else:
			right_stack.append(cards[i])
	for i in range(left_stack.size()):
		var lc := left_stack[i]
		var ltw := create_tween()
		ltw.tween_property(lc, "position", Vector2(center.x - 132.0, center.y - 84.0 + float(i) * 3.0), 0.18)
		ltw.parallel().tween_property(lc, "rotation_degrees", -15.0 + float(i), 0.18)
	for i in range(right_stack.size()):
		var rc := right_stack[i]
		var rtw := create_tween()
		rtw.tween_property(rc, "position", Vector2(center.x + 52.0, center.y - 84.0 + float(i) * 3.0), 0.18)
		rtw.parallel().tween_property(rc, "rotation_degrees", 15.0 - float(i), 0.18)
	await get_tree().create_timer(0.22).timeout

	var interleave: Array[Panel] = []
	for i in range(maxi(left_stack.size(), right_stack.size())):
		if i < left_stack.size():
			interleave.append(left_stack[i])
		if i < right_stack.size():
			interleave.append(right_stack[i])
	for i in range(interleave.size()):
		var ic := interleave[i]
		var itw := create_tween()
		itw.tween_property(ic, "position", Vector2(center.x - 46.0 + randf_range(-4.0, 4.0), center.y - 72.0 - float(i) * 1.3), 0.18)
		itw.parallel().tween_property(ic, "rotation_degrees", randf_range(-3.0, 3.0), 0.18)
		if i % 4 == 3:
			await get_tree().create_timer(0.015).timeout
	await get_tree().create_timer(0.16).timeout

	# Phase 3: Fan spread.
	var mid := (float(cards.size()) - 1.0) * 0.5
	for i in range(cards.size()):
		var card2: Panel = cards[i]
		var offset := float(i) - mid
		var fan_pos := Vector2(center.x - 46.0 + offset * 17.0, center.y - 74.0 + abs(offset) * 3.0)
		var tw2 := create_tween()
		tw2.tween_property(card2, "position", fan_pos, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw2.parallel().tween_property(card2, "rotation_degrees", offset * 4.8, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.22).timeout

	# Phase 4: Merge stack and keep only top few cards.
	for i in range(cards.size()):
		var card3: Panel = cards[i]
		var merge_pos := Vector2(center.x - 46.0 + randf_range(-3.0, 3.0), center.y - 70.0 - float(i) * 1.1)
		var tw3 := create_tween()
		tw3.tween_property(card3, "position", merge_pos, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tw3.parallel().tween_property(card3, "rotation_degrees", randf_range(-2.0, 2.0), 0.20)
		tw3.parallel().tween_property(card3, "modulate:a", 0.0 if i < cards.size() - 3 else 1.0, 0.22)
	await get_tree().create_timer(0.18).timeout

	# Phase 5: Top card zoom reveal to the active-card center.
	var lead_card: Panel = cards.back()
	if lead_card and is_instance_valid(lead_card):
		lead_card.z_index = 9
		var reveal_tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		reveal_tw.tween_property(lead_card, "position", reveal_center - lead_card.size * 0.5, 0.24)
		reveal_tw.parallel().tween_property(lead_card, "rotation_degrees", 0.0, 0.24)
		reveal_tw.parallel().tween_property(lead_card, "scale", Vector2(3.9, 3.9), 0.24)
		reveal_tw.tween_property(lead_card, "modulate:a", 0.0, 0.12)
		await reveal_tw.finished

	for i in range(cards.size()):
		var card4: Panel = cards[i]
		if not is_instance_valid(card4):
			continue
		var tw4 := create_tween()
		tw4.tween_property(card4, "position:y", card4.position.y - randf_range(14.0, 44.0), 0.18).set_delay(0.01 * float(i))
		tw4.parallel().tween_property(card4, "modulate:a", 0.0, 0.15).set_delay(0.05 + 0.01 * float(i))
	await get_tree().create_timer(0.30).timeout
	_deck_fx_layer.visible = false


# ═══════════════════════════════════════════════════════════════════════════════
# MERLIN NARRATOR INTRO — Run opening narration
# ═══════════════════════════════════════════════════════════════════════════════

signal narrator_intro_finished

const NARRATOR_INTROS := [
	"Les brumes de Bretagne s'ouvrent devant toi... Le chemin serpente, et l'avenir est incertain.",
	"La foret murmure ton nom. Merlin veille... mais pour combien de temps encore?",
	"Le vent porte des echos anciens. Un nouveau cycle commence, voyageur.",
	"Les pierres se souviennent de chaque pas. Pret a ecrire un nouveau chapitre?",
	"L'aube se leve sur les landes. Quelque chose attend au bout du sentier.",
]

var _narrator_active := false
var _typewriter_active := false
var _typewriter_abort := false


func show_narrator_intro() -> void:
	## Show Merlin as narrator before the first card of a run.
	print("[TriadeUI] show_narrator_intro()")
	SFXManager.play("whoosh")
	_narrator_active = true
	var should_dim_ui := not _opening_sequence_done

	# Hide game UI during intro
	if should_dim_ui and options_container and is_instance_valid(options_container):
		options_container.modulate.a = 0.0
	if should_dim_ui and info_panel and is_instance_valid(info_panel):
		info_panel.modulate.a = 0.0

	# Show Merlin as speaker
	if card_speaker and is_instance_valid(card_speaker):
		card_speaker.text = "Merlin"
		card_speaker.visible = true

	# Pick intro text
	var intro_text: String = NARRATOR_INTROS[randi() % NARRATOR_INTROS.size()]

	# Static badge for narrator intro
	if _card_source_badge and is_instance_valid(_card_source_badge):
		LLMSourceBadge.update_badge(_card_source_badge, "static")
		_card_source_badge.visible = true

	# Typewriter the intro
	await _typewriter_card_text(intro_text)

	# Wait for player to acknowledge
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.65).timeout

	# Fade in game UI
	if should_dim_ui and options_container and is_instance_valid(options_container):
		var tw := create_tween()
		tw.tween_property(options_container, "modulate:a", 1.0, 0.4)
	if should_dim_ui and info_panel and is_instance_valid(info_panel):
		var tw2 := create_tween()
		tw2.tween_property(info_panel, "modulate:a", 1.0, 0.4)

	_narrator_active = false
	narrator_intro_finished.emit()
	print("[TriadeUI] narrator intro finished")


func _typewriter_card_text(full_text: String) -> void:
	## Typewriter effect for card text with procedural blip sound.
	if card_text == null or not is_instance_valid(card_text):
		return

	_typewriter_active = true
	_typewriter_abort = false
	card_text.text = ""
	card_text.visible_characters = 0
	if _text_pixel_fx_layer and is_instance_valid(_text_pixel_fx_layer):
		for child in _text_pixel_fx_layer.get_children():
			child.queue_free()

	# Set full text but reveal character by character
	card_text.text = full_text
	var total := full_text.length()
	var max_index := maxi(total - 1, 1)

	for i in range(total):
		if _typewriter_abort or not is_inside_tree():
			if is_instance_valid(card_text):
				card_text.visible_characters = -1
			break
		card_text.visible_characters = i + 1
		var ch := full_text[i]
		# Procedural blip
		if ch != " " and ch != "\n":
			_play_blip()
			_spawn_text_pixel_drop(float(i) / float(max_index))
		# Punctuation pause
		if ch in [".", ",", "!", "?", ":"]:
			await get_tree().create_timer(0.036).timeout
		else:
			await get_tree().create_timer(0.012).timeout

	if is_instance_valid(card_text):
		card_text.visible_characters = -1
	_typewriter_active = false


func _spawn_text_pixel_drop(progress_ratio: float) -> void:
	if not _text_pixel_fx_layer or not is_instance_valid(_text_pixel_fx_layer):
		return
	if not card_panel or not is_instance_valid(card_panel):
		return

	var px := ColorRect.new()
	var size_px := randf_range(2.0, 4.0)
	px.size = Vector2(size_px, size_px)
	px.mouse_filter = Control.MOUSE_FILTER_IGNORE
	px.color = Color(0.70, 0.86, 1.0, 0.90)
	px.position = Vector2(
		lerpf(card_panel.size.x * 0.12, card_panel.size.x * 0.88, clampf(progress_ratio, 0.0, 1.0)) + randf_range(-6.0, 6.0),
		card_panel.size.y * 0.58 + randf_range(-24.0, -8.0)
	)
	_text_pixel_fx_layer.add_child(px)

	var tw := create_tween()
	tw.tween_property(px, "position:y", px.position.y + randf_range(12.0, 24.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(px, "modulate:a", 0.0, 0.18)
	tw.tween_callback(px.queue_free)


func _play_blip() -> void:
	## Procedural keyboard click sound (pooled — no node leak).
	if _blip_pool.is_empty():
		return
	var player: AudioStreamPlayer = _blip_pool[_blip_idx]
	_blip_idx = (_blip_idx + 1) % BLIP_POOL_SIZE
	if player.playing:
		player.stop()
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
	var freq := randf_range(280.0, 380.0)
	var samples := int(22050.0 * 0.015)
	for s in range(samples):
		var t := float(s) / 22050.0
		var envelope := exp(-t * 200.0)
		var val := sin(TAU * freq * t) * envelope * 0.3
		val += randf_range(-0.05, 0.05) * envelope
		playback.push_frame(Vector2(val, val))


func update_mission(mission: Dictionary) -> void:
	if mission_label:
		if mission.get("revealed", false):
			var progress: int = int(mission.get("progress", 0))
			var total: int = int(mission.get("total", 0))
			mission_label.text = "Mission: %d/%d" % [progress, total]
		else:
			mission_label.text = "Mission: ???"


func update_cards_count(count: int) -> void:
	if cards_label:
		cards_label.text = "Cartes: %d" % count
	_remaining_deck_estimate = maxi(RUN_DECK_ESTIMATE - maxi(count, 0), 0)
	_update_remaining_deck_visual()


# ═══════════════════════════════════════════════════════════════════════════════
# INPUT HANDLING
# ═══════════════════════════════════════════════════════════════════════════════

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_resize_low_poly_background()
		_layout_run_zones()
		_layout_card_stage()
		if _preview_visible_for >= 0:
			_position_preview_above_button(_preview_visible_for)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		SFXManager.play("click")
		pause_requested.emit()
		return

	# Skip typewriter on click/tap
	if _typewriter_active and event is InputEventMouseButton and event.pressed:
		_typewriter_abort = true
		return

	# Keyboard shortcuts for options
	if event is InputEventKey and event.pressed:
		# Skip typewriter on any key
		if _typewriter_active:
			_typewriter_abort = true
			return
		match event.keycode:
			KEY_A, KEY_LEFT, KEY_1, KEY_KP_1:
				_on_option_pressed(MerlinConstants.CardOption.LEFT)
			KEY_B, KEY_UP, KEY_2, KEY_KP_2:
				_on_option_pressed(MerlinConstants.CardOption.CENTER)
			KEY_C, KEY_RIGHT, KEY_3, KEY_KP_3:
				_on_option_pressed(MerlinConstants.CardOption.RIGHT)


func _on_option_pressed(option: int) -> void:
	if current_card.is_empty():
		return

	SFXManager.play("choice_select")

	# Animate button
	if option < option_buttons.size():
		var btn := option_buttons[option]
		var tween := create_tween()
		tween.tween_property(btn, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		tween.tween_property(btn, "modulate", Color.WHITE, 0.1)

	option_chosen.emit(option)


# ═══════════════════════════════════════════════════════════════════════════════
# END SCREEN
# ═══════════════════════════════════════════════════════════════════════════════

func show_end_screen(ending: Dictionary) -> void:
	# Hide main UI
	if card_container:
		card_container.visible = false
	if options_container:
		options_container.visible = false

	# Create parchment overlay
	var overlay := ColorRect.new()
	overlay.color = Color(PALETTE.paper.r, PALETTE.paper.g, PALETTE.paper.b, 0.95)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.modulate.a = 0.0
	add_child(overlay)

	# Fade in
	var fade_tw := create_tween()
	fade_tw.tween_property(overlay, "modulate:a", 1.0, 0.8)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)

	# Celtic ornament top
	var orn_top := Label.new()
	orn_top.text = "\u2500\u2500\u2500 \u25C6 \u2500\u2500\u2500"
	orn_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn_top.add_theme_font_size_override("font_size", 14)
	orn_top.add_theme_color_override("font_color", PALETTE.accent)
	vbox.add_child(orn_top)

	# Ending title
	var title := Label.new()
	var ending_data: Dictionary = ending.get("ending", {})
	title.text = ending_data.get("title", "Fin")
	if title_font:
		title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if ending.get("victory", false):
		title.add_theme_color_override("font_color", Color(0.32, 0.58, 0.28))
	else:
		title.add_theme_color_override("font_color", Color(0.72, 0.28, 0.22))

	vbox.add_child(title)

	# Ending text
	if ending_data.has("text"):
		var text := Label.new()
		text.text = ending_data.get("text", "")
		if body_font:
			text.add_theme_font_override("font", body_font)
		text.add_theme_font_size_override("font_size", 16)
		text.add_theme_color_override("font_color", PALETTE.ink)
		text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size.x = 400
		vbox.add_child(text)

	# Score
	var score := Label.new()
	score.text = "Gloire: %d" % ending.get("score", 0)
	if title_font:
		score.add_theme_font_override("font", title_font)
	score.add_theme_font_size_override("font_size", 22)
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_color_override("font_color", PALETTE.accent)
	vbox.add_child(score)

	# Life depleted indicator
	if ending.get("life_depleted", false):
		var life_lbl := Label.new()
		life_lbl.text = "Essences de vie epuisees"
		if body_font:
			life_lbl.add_theme_font_override("font", body_font)
		life_lbl.add_theme_font_size_override("font_size", 14)
		life_lbl.add_theme_color_override("font_color", Color(0.78, 0.35, 0.22))
		life_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(life_lbl)

	# Stats
	var stats_lbl := Label.new()
	stats_lbl.text = "Cartes: %d  \u2502  Jours: %d" % [
		ending.get("cards_played", 0),
		ending.get("days_survived", 1)
	]
	if body_font:
		stats_lbl.add_theme_font_override("font", body_font)
	stats_lbl.add_theme_font_size_override("font_size", 14)
	stats_lbl.add_theme_color_override("font_color", PALETTE.ink_soft)
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stats_lbl)

	# Rewards section
	var rewards: Dictionary = ending.get("rewards", {})
	if rewards.size() > 0:
		var rewards_title := Label.new()
		rewards_title.text = "Recompenses obtenues"
		if title_font:
			rewards_title.add_theme_font_override("font", title_font)
		rewards_title.add_theme_font_size_override("font_size", 18)
		rewards_title.add_theme_color_override("font_color", PALETTE.accent)
		rewards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(rewards_title)

		# Essences earned
		var ess: Dictionary = rewards.get("essence", {})
		if ess.size() > 0:
			var parts: PackedStringArray = []
			for elem in ess:
				if int(ess[elem]) > 0:
					parts.append("%s +%d" % [str(elem).left(4), int(ess[elem])])
			if parts.size() > 0:
				var ess_lbl := Label.new()
				ess_lbl.text = "Essences: " + " | ".join(parts)
				if body_font:
					ess_lbl.add_theme_font_override("font", body_font)
				ess_lbl.add_theme_font_size_override("font_size", 13)
				ess_lbl.add_theme_color_override("font_color", PALETTE.ink)
				ess_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				ess_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
				ess_lbl.custom_minimum_size.x = 400
				vbox.add_child(ess_lbl)

		# Fragments, Liens, Gloire
		var currency_parts: PackedStringArray = []
		var frag: int = int(rewards.get("fragments", 0))
		var liens: int = int(rewards.get("liens", 0))
		var gloire_r: int = int(rewards.get("gloire", 0))
		if frag > 0:
			currency_parts.append("Fragments +%d" % frag)
		if liens > 0:
			currency_parts.append("Liens +%d" % liens)
		if gloire_r > 0:
			currency_parts.append("Gloire +%d" % gloire_r)
		if currency_parts.size() > 0:
			var cur_lbl := Label.new()
			cur_lbl.text = " | ".join(currency_parts)
			if body_font:
				cur_lbl.add_theme_font_override("font", body_font)
			cur_lbl.add_theme_font_size_override("font_size", 14)
			cur_lbl.add_theme_color_override("font_color", PALETTE.accent)
			cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vbox.add_child(cur_lbl)

	# Celtic ornament bottom
	var orn_bot := Label.new()
	orn_bot.text = "\u2500\u2500\u2500 \u25C6 \u2500\u2500\u2500"
	orn_bot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	orn_bot.add_theme_font_size_override("font_size", 14)
	orn_bot.add_theme_color_override("font_color", PALETTE.accent)
	vbox.add_child(orn_bot)

	# Aspects final state
	var aspects_label := Label.new()
	var aspects_text := "Aspects finaux: "
	for aspect in MerlinConstants.TRIADE_ASPECTS:
		var state_val: int = current_aspects.get(aspect, 0)
		var info = MerlinConstants.TRIADE_ASPECT_INFO.get(aspect, {})
		var states = info.get("states", {})
		var animal: Dictionary = {"Corps": "Sanglier", "Ame": "Corbeau", "Monde": "Cerf"}
		aspects_text += "%s %s (%s) | " % [animal.get(aspect, "?"), aspect, states.get(state_val, "?")]
	aspects_label.text = aspects_text.trim_suffix(" | ")
	aspects_label.add_theme_font_size_override("font_size", 12)
	aspects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(aspects_label)

	# Action buttons
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 16
	vbox.add_child(spacer)

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 20)
	vbox.add_child(btn_box)

	var btn_hub := Button.new()
	btn_hub.text = "Retour au Hub"
	btn_hub.custom_minimum_size = Vector2(200, 50)
	btn_hub.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/HubAntre.tscn"))
	btn_box.add_child(btn_hub)

	var btn_new := Button.new()
	btn_new.text = "Nouvelle Aventure"
	btn_new.custom_minimum_size = Vector2(200, 50)
	btn_new.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/TransitionBiome.tscn"))
	btn_box.add_child(btn_new)


# ═══════════════════════════════════════════════════════════════════════════════
# D20 DICE UI (Phase 37 — Fusion)
# ═══════════════════════════════════════════════════════════════════════════════

var _dice_overlay: Control = null
var _dice_display: Label = null
var _dice_dc_label: Label = null
var _dice_result_label: Label = null

func show_dice_roll(dc: int, target: int) -> void:
	## Show D20 dice animation (2.2s deceleration + bounce). Await this.
	_ensure_dice_overlay()
	_dice_overlay.visible = true
	_dice_overlay.modulate.a = 0.0
	_dice_dc_label.text = "Difficulte: %d" % dc
	_dice_result_label.text = ""
	_dice_display.text = "?"
	_dice_display.add_theme_color_override("font_color", PALETTE.ink)
	_dice_display.scale = Vector2.ONE
	_dice_display.rotation = 0.0

	# Fade in dice area
	var tw_in := create_tween()
	tw_in.tween_property(_dice_overlay, "modulate:a", 1.0, 0.2)
	await tw_in.finished

	# Dice roll animation: decelerate over 2.2s
	var duration := 2.2
	var elapsed := 0.0
	while elapsed < duration and is_inside_tree():
		var progress: float = elapsed / duration
		var cycle_speed: float = lerpf(0.07, 0.35, progress * progress)
		_dice_display.text = str(randi_range(1, 20))
		_dice_display.rotation = randf_range(-0.08, 0.08) * (1.0 - progress)
		await get_tree().create_timer(cycle_speed).timeout
		elapsed += cycle_speed

	# Land on target
	_dice_display.text = str(target)
	_dice_display.rotation = 0.0
	# Bounce elastic
	_dice_display.pivot_offset = _dice_display.size / 2.0
	var tw_bounce := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw_bounce.tween_property(_dice_display, "scale", Vector2(1.3, 1.3), 0.15)
	tw_bounce.tween_property(_dice_display, "scale", Vector2(1.0, 1.0), 0.25)
	await tw_bounce.finished


func show_dice_instant(dc: int, value: int) -> void:
	## Show dice result instantly (after minigame).
	_ensure_dice_overlay()
	_dice_overlay.visible = true
	_dice_overlay.modulate.a = 1.0
	_dice_dc_label.text = "Difficulte: %d" % dc
	_dice_result_label.text = ""
	_dice_display.text = str(value)
	_dice_display.rotation = 0.0
	var glow: Color = _dice_outcome_color(value, dc)
	_dice_display.add_theme_color_override("font_color", glow)
	# Bounce
	_dice_display.pivot_offset = _dice_display.size / 2.0
	var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(_dice_display, "scale", Vector2(1.3, 1.3), 0.15)
	tw.tween_property(_dice_display, "scale", Vector2(1.0, 1.0), 0.25)


func show_dice_result(roll: int, dc: int, outcome: String) -> void:
	## Show final dice result text + color.
	_ensure_dice_overlay()
	var glow: Color = _dice_outcome_color(roll, dc)
	_dice_display.add_theme_color_override("font_color", glow)

	match outcome:
		"critical_success":
			_dice_result_label.text = "Coup Critique !"
			_dice_result_label.add_theme_color_override("font_color", Color(0.85, 0.72, 0.2))
		"success":
			_dice_result_label.text = "Reussite ! (%d >= %d)" % [roll, dc]
			_dice_result_label.add_theme_color_override("font_color", Color(0.3, 0.7, 0.3))
		"failure":
			_dice_result_label.text = "Echec... (%d < %d)" % [roll, dc]
			_dice_result_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
		"critical_failure":
			_dice_result_label.text = "Echec Critique !"
			_dice_result_label.add_theme_color_override("font_color", Color(0.7, 0.2, 0.2))


func _dice_outcome_color(roll: int, dc: int) -> Color:
	if roll == 20:
		return Color(0.85, 0.72, 0.2)  # Gold
	elif roll == 1:
		return Color(0.7, 0.2, 0.2)  # Dark red
	elif roll >= dc:
		return Color(0.3, 0.7, 0.3)  # Green
	else:
		return Color(0.7, 0.3, 0.3)  # Red


func _ensure_dice_overlay() -> void:
	## Create dice UI elements if not yet built.
	if _dice_overlay and is_instance_valid(_dice_overlay):
		return
	_dice_overlay = Control.new()
	_dice_overlay.name = "DiceOverlay"
	_dice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dice_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dice_overlay.visible = false
	add_child(_dice_overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dice_overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	center.add_child(vbox)

	_dice_dc_label = Label.new()
	_dice_dc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_dc_label.add_theme_font_size_override("font_size", 14)
	_dice_dc_label.add_theme_color_override("font_color", PALETTE.ink_soft)
	if body_font:
		_dice_dc_label.add_theme_font_override("font", body_font)
	vbox.add_child(_dice_dc_label)

	_dice_display = Label.new()
	_dice_display.text = "?"
	_dice_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		_dice_display.add_theme_font_override("font", title_font)
	_dice_display.add_theme_font_size_override("font_size", 72)
	_dice_display.add_theme_color_override("font_color", PALETTE.ink)
	vbox.add_child(_dice_display)

	_dice_result_label = Label.new()
	_dice_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice_result_label.add_theme_font_size_override("font_size", 16)
	if body_font:
		_dice_result_label.add_theme_font_override("font", body_font)
	vbox.add_child(_dice_result_label)


func _hide_dice_overlay() -> void:
	if _dice_overlay and is_instance_valid(_dice_overlay):
		var tw := create_tween()
		tw.tween_property(_dice_overlay, "modulate:a", 0.0, 0.3)
		tw.tween_callback(func(): _dice_overlay.visible = false)


# ═══════════════════════════════════════════════════════════════════════════════
# MINIGAME INTRO & SCORE DISPLAY
# ═══════════════════════════════════════════════════════════════════════════════

const MINIGAME_FIELD_ICONS := {
	"combat": "\u2694",
	"exploration": "\uD83D\uDD0D",
	"mysticisme": "\u2728",
	"survie": "\u2605",
	"diplomatie": "\u2696",
}

func show_minigame_intro(field: String, tool_bonus_text: String, tool_bonus: int) -> void:
	## Brief overlay announcing the minigame type and any tool bonus.
	var overlay := ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.05, 0.04, 0.03, 0.75)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.modulate.a = 0.0
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	center.add_child(vbox)

	# Field icon
	var icon_label := Label.new()
	var field_icon: String = MINIGAME_FIELD_ICONS.get(field, "\u2726")
	icon_label.text = field_icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 48)
	vbox.add_child(icon_label)

	# Field name
	var name_label := Label.new()
	name_label.text = "Epreuve: %s" % field.capitalize()
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font:
		name_label.add_theme_font_override("font", title_font)
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", PALETTE.paper)
	vbox.add_child(name_label)

	# Tool bonus
	if tool_bonus != 0 and tool_bonus_text != "":
		var bonus_label := Label.new()
		bonus_label.text = "%s DC %d" % [tool_bonus_text, tool_bonus]
		bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if body_font:
			bonus_label.add_theme_font_override("font", body_font)
		bonus_label.add_theme_font_size_override("font_size", 16)
		bonus_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))
		vbox.add_child(bonus_label)

	# Animate in then auto-remove
	var tw := create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.2)
	tw.tween_interval(0.8)
	tw.tween_property(overlay, "modulate:a", 0.0, 0.2)
	tw.tween_callback(overlay.queue_free)


func show_score_to_d20(score: int, d20: int, tool_bonus: int) -> void:
	## Brief display: "Score: 78 → D20: 17" (optional tool bonus shown).
	_ensure_dice_overlay()
	_dice_overlay.visible = true
	_dice_overlay.modulate.a = 1.0
	var bonus_text: String = ""
	if tool_bonus != 0:
		bonus_text = " (bonus %d)" % tool_bonus
	_dice_dc_label.text = "Score: %d \u2192 D20: %d%s" % [score, d20, bonus_text]
	_dice_dc_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_dice_display.text = str(d20)
	_dice_result_label.text = ""


# ═══════════════════════════════════════════════════════════════════════════════
# TRAVEL ANIMATION (fog overlay between cards)
# ═══════════════════════════════════════════════════════════════════════════════

func show_travel_animation(text: String) -> void:
	## Full-screen fog overlay with contextual text. Awaitable.
	_hide_dice_overlay()
	SFXManager.play("mist_breath")

	var fog := ColorRect.new()
	fog.name = "TravelFog"
	fog.set_anchors_preset(Control.PRESET_FULL_RECT)
	fog.color = Color(0.08, 0.06, 0.04, 0.0)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fog)

	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	if body_font:
		lbl.add_theme_font_override("font", body_font)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.85, 0.80, 0.70, 0.0))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	fog.add_child(lbl)

	# Fade in
	var tw_in := create_tween()
	tw_in.set_parallel(true)
	tw_in.tween_property(fog, "color:a", 0.85, 0.6)
	tw_in.tween_property(lbl, "theme_override_colors/font_color:a", 1.0, 0.6)
	await tw_in.finished

	# Hold
	if is_inside_tree():
		await get_tree().create_timer(1.2).timeout

	# Fade out
	var tw_out := create_tween()
	tw_out.set_parallel(true)
	tw_out.tween_property(fog, "color:a", 0.0, 0.6)
	tw_out.tween_property(lbl, "theme_override_colors/font_color:a", 0.0, 0.6)
	await tw_out.finished

	if is_instance_valid(fog):
		fog.queue_free()


# ═══════════════════════════════════════════════════════════════════════════════
# REACTION TEXT + CRITICAL BADGE + BIOME PASSIVE
# ═══════════════════════════════════════════════════════════════════════════════

func show_reaction_text(text: String, outcome: String) -> void:
	## Show narrative reaction on the card text area.
	if not card_text or not is_instance_valid(card_text):
		return
	var color: Color = Color(0.3, 0.65, 0.3) if outcome.contains("success") else Color(0.7, 0.3, 0.3)
	card_text.text = "[color=#%s]%s[/color]" % [color.to_html(false), text]
	card_text.visible_characters = -1


func show_critical_badge() -> void:
	## Pulse gold border on the card panel to indicate critical choice.
	if not card_panel or not is_instance_valid(card_panel):
		return
	var base_style = card_panel.get_theme_stylebox("panel")
	if not base_style:
		return
	var style: StyleBoxFlat = base_style.duplicate() as StyleBoxFlat
	if style:
		style.border_color = Color(0.85, 0.72, 0.2)
		style.set_border_width_all(3)
		card_panel.add_theme_stylebox_override("panel", style)
	# Pulse animation (infinite, stop on next card display)
	var tw := create_tween().set_loops(0)
	tw.tween_property(card_panel, "modulate", Color(1.15, 1.1, 0.9), 0.3)
	tw.tween_property(card_panel, "modulate", Color.WHITE, 0.3)


func show_biome_passive(passive: Dictionary) -> void:
	## Brief notification for biome passive effect.
	var text: String = str(passive.get("text", "Force du biome..."))
	var notif := Label.new()
	notif.text = text
	notif.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	notif.add_theme_font_size_override("font_size", 14)
	notif.add_theme_color_override("font_color", Color(0.4, 0.7, 0.5))
	if body_font:
		notif.add_theme_font_override("font", body_font)
	notif.modulate.a = 0.0
	add_child(notif)
	var tw := create_tween()
	tw.tween_property(notif, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.5)
	tw.tween_property(notif, "modulate:a", 0.0, 0.3)
	tw.tween_callback(notif.queue_free)


# ═══════════════════════════════════════════════════════════════════════════════
# CARD OUTCOME ANIMATIONS (shake, pulse, particles)
# ═══════════════════════════════════════════════════════════════════════════════

func animate_card_outcome(outcome: String) -> void:
	## Animate card panel based on D20 outcome.
	if not card_panel or not is_instance_valid(card_panel):
		return
	match outcome:
		"critical_success":
			# Gold pulse
			var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card_panel, "scale", Vector2(1.08, 1.08), 0.2)
			tw.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.3)
		"success":
			var tw := create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tw.tween_property(card_panel, "scale", Vector2(1.04, 1.04), 0.15)
			tw.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.2)
		"failure":
			# Shake horizontal x3
			var tw := create_tween()
			for i in range(3):
				tw.tween_property(card_panel, "position:x", card_panel.position.x + 8, 0.05).set_trans(Tween.TRANS_SINE)
				tw.tween_property(card_panel, "position:x", card_panel.position.x - 8, 0.05).set_trans(Tween.TRANS_SINE)
			tw.tween_property(card_panel, "position:x", card_panel.position.x, 0.05)
		"critical_failure":
			# Violent shake x5 + shrink
			var tw := create_tween()
			for i in range(5):
				tw.tween_property(card_panel, "position:x", card_panel.position.x + 14, 0.04).set_trans(Tween.TRANS_SINE)
				tw.tween_property(card_panel, "position:x", card_panel.position.x - 14, 0.04).set_trans(Tween.TRANS_SINE)
			tw.tween_property(card_panel, "position:x", card_panel.position.x, 0.04)
			tw.tween_property(card_panel, "scale", Vector2(0.97, 0.97), 0.1)
			tw.tween_property(card_panel, "scale", Vector2(1.0, 1.0), 0.15)


func _exit_tree() -> void:
	## Cleanup to prevent orphaned nodes and dangling signals.
	_typewriter_abort = true
	if _thinking_timer and is_instance_valid(_thinking_timer):
		_thinking_timer.stop()
